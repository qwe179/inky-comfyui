#!/bin/bash
# MiniMax H3 I2V(이미지 → 영상)로 한 동작을 8방향 차례로 뽑는 세트.
# RunPod(hearmeman 템플릿) Container Start Command:
#   bash -c '(curl -fsSL https://raw.githubusercontent.com/qwe179/inky-comfyui/main/h3_i2v_start.sh | bash) > /tmp/i2v_setup.log 2>&1 & exec /start_script.sh'
# 이미 떠 있는 Pod에서는 터미널에:
#   curl -fsSL https://raw.githubusercontent.com/qwe179/inky-comfyui/main/h3_i2v_start.sh | bash > /tmp/i2v_setup.log 2>&1 &
# 하는 일:
#   1) I2V 모델 받기 (fl2va pruned int8 21GB + 텍스트 인코더 int8 27GB + 영상 VAE + 8step turbo LoRA 2GB, 약 52GB)
#   2) 방향 목록 노드(custom_nodes/inky_dir_list.py), 워크플로 h3_i2v_8dir_<세트> 5개, 입력 그림 40장(5세트 × 8방향, 640px) 받기
#   3) VHS가 없으면 설치, ComfyUI에 MiniMaxH3ImageToVideo가 없으면 최신으로 올리기, 재시작(--use-sage-attention 뺌)
# 로그 /tmp/i2v_setup.log, 마지막 줄 READY.

until [ -d /ComfyUI/models ]; do sleep 5; done
PY=$(command -v python || command -v python3); PIP="$PY -m pip"
echo "== h3_i2v_start 시작 $(date) / python=$PY"; df -h /ComfyUI | tail -1
C=/ComfyUI; M=$C/models; WF=$C/user/default/workflows; IN=$C/input/h3i2v
mkdir -p $M/diffusion_models $M/text_encoders $M/vae $M/loras $WF $IN $C/custom_nodes
G="wget -c -nv --tries=5 --retry-connrefused --waitretry=10"

# 1) 모델 (워크플로가 가리키는 파일 이름 그대로)
H=https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main
$G -P $M/diffusion_models $H/diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors
$G -P $M/text_encoders    $H/text_encoders/qwen3vl_32b_minimax_h3_int8_convrot.safetensors
$G -P $M/vae              $H/vae/minimax_h3_video_vae_fp16.safetensors
$G -P $M/loras            $H/loras/minimax_h3_fl2v_turbo_8step_v1.0_comfyui_bf16.safetensors

# 2) 노드 + 워크플로 + 입력 (base / one_hand / two_hand / dual / shield × 8방향)
R=https://raw.githubusercontent.com/qwe179/inky-comfyui/main
curl -fsSL -o $C/custom_nodes/inky_dir_list.py $R/custom_nodes/inky_dir_list.py && echo "node ok"
for s in one_hand two_hand dual shield base; do
  curl -fsSL -o $WF/h3_i2v_8dir_$s.json $R/workflows/h3_i2v_8dir_$s.json && echo "workflow $s ok"
done
n=0
for s in base one_hand two_hand dual shield; do
  for d in south south-east east north-east north north-west west south-west; do
    curl -fsSL -o $IN/${s}_$d.png $R/inputs/h3i2v/${s}_$d.png && n=$((n+1)) || echo "입력 실패 ${s}_$d"
  done
done
echo "inputs $n/40"

# 3) VHS, ComfyUI 업데이트, 재시작 (새 노드를 읽으려면 재시작은 항상 한다)
[ -d $C/custom_nodes/ComfyUI-VideoHelperSuite ] || { cd $C/custom_nodes && git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite && $PIP install -r ComfyUI-VideoHelperSuite/requirements.txt; }
until curl -s -o /dev/null localhost:8188; do sleep 10; done
if ! curl -s localhost:8188/object_info/MiniMaxH3ImageToVideo | grep -q MiniMaxH3ImageToVideo; then
  cd $C && git fetch origin && git checkout origin/master && $PIP install -r requirements.txt || exit 1
fi
P=$(pgrep -f "[m]ain.py --listen" | head -1) && tr '\0' '\n' < /proc/$P/cmdline | grep -v -- '--use-sage-attention' | tr '\n' '\0' > /tmp/comfy_cmd \
  && kill $P && sleep 5 && (nohup xargs -0 -a /tmp/comfy_cmd env > /tmp/comfy_restart.log 2>&1 &)
echo "ComfyUI 재시작함"
until curl -s -o /dev/null localhost:8188; do sleep 5; done
for t in MiniMaxH3ImageToVideo DirectionListPick VHS_VideoCombine PrimitiveInt; do
  curl -s localhost:8188/object_info/$t | grep -q "\"$t\"" && echo "노드 $t ok" || echo "노드 $t 없음!"
done
cd $C && git log -1 --format="ComfyUI %h %cd"
echo "READY: 브라우저 F5 → 워크플로 h3_i2v_8dir_<세트> 열기 → 방향 목록 노드 확인 → Run 횟수 8로 실행. 결과 output/h3i2v/<motion_name>/"
