#!/bin/bash
# RunPod(hearmeman 템플릿) Container Start Command:
#   bash -c '(curl -fsSL https://raw.githubusercontent.com/qwe179/inky-comfyui/main/h3_start.sh | bash) > /tmp/extra_models.log 2>&1 & exec /start_script.sh'
# 하는 일: MiniMax H3 I2V(이미지→영상) 로컬 세트 받기 → 공식 I2V 워크플로 받기 → ComfyUI 최신으로 올리고 재시작.
# 모델 합계 약 42GB (pruned int8 + nvfp4 텍스트 인코더 + int8 VAE + 8step turbo LoRA). 디스크 60GB 이상.
# 로그 /tmp/extra_models.log, 마지막 줄에 ComfyUI 커밋.

until [ -d /ComfyUI/models ]; do sleep 5; done
M=/ComfyUI/models
mkdir -p $M/diffusion_models $M/text_encoders $M/vae $M/loras /ComfyUI/user/default/workflows

H=https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main
wget -c -P $M/diffusion_models $H/diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors
wget -c -P $M/text_encoders   $H/text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors
wget -c -P $M/vae             $H/vae/minimax_h3_video_vae_int8_convrot.safetensors
wget -c -P $M/vae             $H/vae/minimax_h3_audio_vae_fp32.safetensors
wget -c -P $M/loras           $H/loras/minimax_h3_fl2v_turbo_8step_v1.0_comfyui_bf16.safetensors

# 공식 로컬 I2V 템플릿 (위 파일 이름을 그대로 가리킨다)
wget -q -O /ComfyUI/user/default/workflows/video_minimax_h3_i2v.json \
  https://raw.githubusercontent.com/Comfy-Org/workflow_templates/main/templates/video_minimax_h3_i2v.json

# H3 노드는 ComfyUI 0.30.0 이상. 템플릿이 커밋을 고정해 둬서 fetch + checkout.
until curl -s -o /dev/null localhost:8188; do sleep 10; done
cd /ComfyUI && git fetch origin && git checkout origin/master && pip install -r requirements.txt || exit 1

P=$(pgrep -f "[m]ain.py --listen" | head -1) && cp /proc/$P/cmdline /tmp/comfy_cmd && kill $P && sleep 5 \
  && (nohup xargs -0 -a /tmp/comfy_cmd env > /tmp/comfy_restart.log 2>&1 &)
git log -1 --format="ComfyUI %h %cd"
