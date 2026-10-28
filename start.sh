#!/bin/bash
# RunPod(hearmeman 템플릿) 시작 때 Container Start Command가 이 파일을 받아 백그라운드로 실행한다.
# 하는 일: 곡 목록 워크플로·노드 받기 → YuE2 체크포인트 받기 → ComfyUI가 켜지면 최신으로 업데이트 → ComfyUI 재시작.
# 로그는 /tmp/extra_models.log, 마지막 줄에 업데이트된 ComfyUI 커밋이 남는다.

until [ -d /ComfyUI/models ]; do sleep 5; done
mkdir -p /ComfyUI/models/checkpoints /ComfyUI/models/loras /ComfyUI/user/default/workflows /ComfyUI/custom_nodes

R=https://raw.githubusercontent.com/qwe179/inky-comfyui/main
for w in audio_yue2_song_list audio_yue2_song_list_mothersuperior; do
  wget -q -O /ComfyUI/user/default/workflows/$w.json $R/workflows/$w.json
done
wget -q -O /ComfyUI/custom_nodes/inky_song_list.py $R/custom_nodes/inky_song_list.py

# Mothersuperior 연주곡 LoRA (CLIP 쪽, 213MB). CC BY-NC 4.0 비상업이라 비교·시험용.
wget -c -P /ComfyUI/models/loras https://huggingface.co/Mothersuperior/YuE2-instrumental-cot-full-loras/resolve/main/ar_lora_inst_v3abc_comfyui.safetensors

wget -c -P /ComfyUI/models/checkpoints https://huggingface.co/Comfy-Org/YuE2/resolve/main/checkpoints/yue2_3b_bf16.safetensors
wget -c -P /ComfyUI/models/checkpoints https://huggingface.co/Comfy-Org/YuE2/resolve/main/checkpoints/yue2_3b_int8_convrot.safetensors

# 템플릿이 ComfyUI를 특정 커밋에 고정해 둬서 git pull은 실패한다. fetch + checkout으로 올린다.
until curl -s -o /dev/null localhost:8188; do sleep 10; done
cd /ComfyUI && git fetch origin && git checkout origin/master && pip install -r requirements.txt || exit 1

# "[m]ain.py --listen"으로 찾는다. 그냥 main.py로 찾으면 시작 명령 문자열을 가진 1번 프로세스가 잡혀 컨테이너가 통째로 재시작된다.
P=$(pgrep -f "[m]ain.py --listen" | head -1) && cp /proc/$P/cmdline /tmp/comfy_cmd && kill $P && sleep 5 \
  && (nohup xargs -0 -a /tmp/comfy_cmd env > /tmp/comfy_restart.log 2>&1 &)
git log -1 --format="ComfyUI %h %cd"
