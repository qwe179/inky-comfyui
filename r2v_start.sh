#!/bin/bash
# MiniMax H3 R2V(참조 이미지 + 참조 영상 → 영상) 시험 세트.
# RunPod(hearmeman 템플릿) Container Start Command:
#   bash -c '(curl -fsSL https://raw.githubusercontent.com/qwe179/inky-comfyui/main/r2v_start.sh | bash) > /tmp/r2v_setup.log 2>&1 & exec /start_script.sh'
# 이미 떠 있는 Pod에서는 터미널에:
#   curl -fsSL https://raw.githubusercontent.com/qwe179/inky-comfyui/main/r2v_start.sh | bash > /tmp/r2v_setup.log 2>&1 &
# 하는 일:
#   1) R2V 모델 받기 (ref2va pruned int8 21GB + 텍스트 인코더 int8 27GB + VAE 5.8GB + turbo LoRA 2GB, 약 56GB)
#   2) 워크플로 h3_r2v_leather_run_south 와 입력(가죽옷 남쪽 640px, 대머리 남쪽 달리기 9프레임)을 받기
#   3) 9프레임을 프레임당 6장씩 24fps mp4로 묶어 ComfyUI input 에 두기 (PyAV, ComfyUI가 이미 쓰는 패키지)
#   4) ComfyUI에 MiniMaxH3ReferenceToVideo 노드가 없을 때만 최신으로 올리고 재시작
# 로그 /tmp/r2v_setup.log, 마지막 줄 READY.

until [ -d /ComfyUI/models ]; do sleep 5; done
PY=$(command -v python || command -v python3); PIP="$PY -m pip"
echo "== r2v_start 시작 $(date) / python=$PY"; df -h /ComfyUI | tail -1
C=/ComfyUI; M=$C/models; WF=$C/user/default/workflows; IN=$C/input
mkdir -p $M/diffusion_models $M/text_encoders $M/vae $M/loras $WF $IN
G="wget -c -nv --tries=5 --retry-connrefused --waitretry=10"

# 1) 모델 (워크플로가 가리키는 파일 이름 그대로)
H=https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main
$G -P $M/diffusion_models $H/diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors
$G -P $M/text_encoders    $H/text_encoders/qwen3vl_32b_minimax_h3_int8_convrot.safetensors
$G -P $M/vae              $H/vae/minimax_h3_video_vae_fp16.safetensors
$G -P $M/vae              $H/vae/minimax_h3_audio_vae_fp32.safetensors
$G -P $M/loras            $H/loras/minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors

# 2) 워크플로 + 입력
R=https://raw.githubusercontent.com/qwe179/inky-comfyui/main
curl -fsSL -o $WF/h3_r2v_leather_run_south.json $R/workflows/h3_r2v_leather_run_south.json && echo "workflow ok"
curl -fsSL -o $IN/r2v_leather_south_640.png $R/inputs/r2v_leather_south_640.png && echo "ref image ok"
mkdir -p /tmp/r2v_run_south
for i in 0 1 2 3 4 5 6 7 8; do
  curl -fsSL -o /tmp/r2v_run_south/frame_00$i.png $R/inputs/r2v_run_south/frame_00$i.png || echo "frame $i 실패"
done

# 3) 프레임 → mp4 (24fps, 프레임당 6장 = 54프레임 약 2.25초)
$PY - <<'PY'
import glob, av, numpy as np
from PIL import Image
files = sorted(glob.glob('/tmp/r2v_run_south/frame_*.png'))
out = av.open('/ComfyUI/input/r2v_bald_run_south_640.mp4', 'w')
s = out.add_stream('libx264', rate=24); s.width, s.height, s.pix_fmt = 640, 640, 'yuv420p'
s.options = {'crf': '10'}
for f in files:
    img = np.array(Image.open(f).convert('RGB'))
    for _ in range(6):
        for p in s.encode(av.VideoFrame.from_ndarray(img, format='rgb24')): out.mux(p)
for p in s.encode(): out.mux(p)
out.close(); print('video ok', len(files), 'frames x6')
PY

# 4) VHS(영상 저장 노드)가 없으면 설치
[ -d $C/custom_nodes/ComfyUI-VideoHelperSuite ] || { cd $C/custom_nodes && git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite && $PIP install -r ComfyUI-VideoHelperSuite/requirements.txt; NEED_RESTART=1; }

until curl -s -o /dev/null localhost:8188; do sleep 10; done
if ! curl -s localhost:8188/object_info/MiniMaxH3ReferenceToVideo | grep -q MiniMaxH3ReferenceToVideo; then
  cd $C && git fetch origin && git checkout origin/master && $PIP install -r requirements.txt || exit 1
  NEED_RESTART=1
fi
if [ -n "$NEED_RESTART" ]; then
  # Qwen 쪽과 같은 이유로 --use-sage-attention 은 뺀다
  P=$(pgrep -f "[m]ain.py --listen" | head -1) && tr '\0' '\n' < /proc/$P/cmdline | grep -v -- '--use-sage-attention' | tr '\n' '\0' > /tmp/comfy_cmd \
    && kill $P && sleep 5 && (nohup xargs -0 -a /tmp/comfy_cmd env > /tmp/comfy_restart.log 2>&1 &)
  echo "ComfyUI 재시작함"
fi
cd $C && git log -1 --format="ComfyUI %h %cd"
echo "READY: 브라우저 F5 → 워크플로 h3_r2v_leather_run_south 열고 실행. 결과 output/h3r2v_leather_run_south_64px_*.gif"
