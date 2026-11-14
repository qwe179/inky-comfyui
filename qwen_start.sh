#!/bin/bash
# RunPod(hearmeman 템플릿, h3_start.sh와 같은 템플릿) Container Start Command:
#   bash -c '(curl -fsSL https://raw.githubusercontent.com/qwe179/inky-comfyui/main/qwen_start.sh | bash) > /tmp/qwen_setup.log 2>&1 & exec /start_script.sh'
# (이 파일을 qwe179/inky-comfyui 저장소 맨 위에 qwen_start.sh 이름으로 올려 둔다. h3_start.sh와 같은 곳.)
#
# 하는 일: Pixel Studio ComfyUI 워크플로(sprite-edit-2511)를 쓸 수 있게 준비한다.
#   1) Qwen-Image-Edit-2511 모델 4개 받기 (합계 약 29GB, 디스크 50GB 이상)
#   2) 워크플로 저장소를 받아 전용 노드(comfyui_workflows_utils)를 ComfyUI에 넣고 파이썬 패키지 설치
#   3) 워크플로 + "옷 참조 이미지" 칸을 하나 더 붙인 버전(sprite-edit-2511-outfit)을 워크플로 폴더에 두기
#   4) ComfyUI를 최신(origin/master)으로 올리고 재시작
# 권장 GPU: 24GB급 (RTX 4090 등). 저장소 README 기준.
# 로그 /tmp/qwen_setup.log, 마지막 줄에 ComfyUI 커밋과 준비 완료 표시.
#
# 이미 확인한 것: 저장소 MIT. 모델 Qwen-Image-Edit-2511·Lightning LoRA·Qwen-Image VAE·텍스트 인코더(Comfy-Org/Qwen-Image)는
#   Hugging Face 페이지 표기가 모두 apache-2.0 (2026-11-14 확인, Apache 본문 전문은 안 읽음).
# 아직 확인 안 한 것: 이 스크립트를 실제 Pod에서 돌려 본 적 없다. 옷 참조 칸을 붙인 워크플로가
#   ComfyUI에서 정상으로 열리고 옷이 따라오는지는 시험 전이다. (docs/4_제작운영/아트/캐릭터애니메이션.md 미정)

until [ -d /ComfyUI/models ]; do sleep 5; done
PY=$(command -v python || command -v python3); PIP="$PY -m pip"
echo "== qwen_start 시작 $(date) / python=$PY"; df -h /ComfyUI | tail -1
C=/ComfyUI
M=$C/models
mkdir -p $M/diffusion_models $M/loras $M/text_encoders $M/vae $C/user/default/workflows $C/input

# 1) 모델 (-c 이어받기)
wget -c -nv --tries=5 --retry-connrefused --waitretry=10 -P $M/diffusion_models https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2511_int8_convrot.safetensors
wget -c -nv --tries=5 --retry-connrefused --waitretry=10 -P $M/loras            https://huggingface.co/lightx2v/Qwen-Image-Edit-2511-Lightning/resolve/main/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors
# 텍스트 인코더는 라이선스가 apache-2.0으로 표기된 Comfy-Org/Qwen-Image 저장소에서 받는다
# (워크플로가 가리키는 HunyuanVideo_1.5_repackaged는 tencent-hunyuan-community 표기). 파일 이름·크기(9.38GB)는 같다.
wget -c -nv --tries=5 --retry-connrefused --waitretry=10 -P $M/text_encoders    https://huggingface.co/Comfy-Org/Qwen-Image/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors
wget -c -nv --tries=5 --retry-connrefused --waitretry=10 -P $M/vae              https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors

# 2) 워크플로 저장소 + 전용 노드
W=/workspace; [ -d $W ] || W=/root
cd $W
[ -d pixel-studio-comfyui-workflows ] || git clone --depth 1 https://github.com/bunnyUFO-lab/pixel-studio-comfyui-workflows
rm -rf $C/custom_nodes/comfyui_workflows_utils
cp -r $W/pixel-studio-comfyui-workflows/custom_nodes/comfyui_workflows_utils $C/custom_nodes/
# 전용 노드가 쓰는 패키지: scipy, opencv, kornia는 템플릿에 보통 있지만 없으면 설치. pixeloe는 --no-deps (저장소 안내).
$PY -c "import scipy, cv2, kornia" || $PIP install scipy opencv-python-headless kornia
$PIP install --no-deps pixeloe==1.0.0
# layered.py가 import potrace를 쓴다. 순수 파이썬 포트 패키지 이름은 potracer. 없으면 전용 노드 묶음 전체가 IMPORT FAILED가 된다.
$PIP install potracer

# 3) 워크플로 복사 + 옷 참조 칸 붙인 버전 만들기
WF=$C/user/default/workflows
SRC=$W/pixel-studio-comfyui-workflows/workflows/pixel-art/sprite-edit-2511.json
cp $SRC $WF/sprite-edit-2511.json
# 직접 고쳐 둔 워크플로가 inky-comfyui 저장소에 있으면(workflows/sprite-edit-2511-outfit.json) 그걸 쓴다. 없으면 아래에서 새로 만든다.
curl -fsSL -o $WF/sprite-edit-2511-outfit.json https://raw.githubusercontent.com/qwe179/inky-comfyui/main/workflows/sprite-edit-2511-outfit.json \
  && echo "workflow: inky-comfyui 저장소의 사본 사용" \
  || $PY - "$SRC" "$WF/sprite-edit-2511-outfit.json" <<'PY'
import json, sys
src, dst = sys.argv[1], sys.argv[2]
d = json.load(open(src))
N = {n["id"]: n for n in d["nodes"]}
assert N[70]["type"] == "TextEncodeQwenImageEditPlus" and N[1]["type"] == "LoadImage"
nid, lid = d["last_node_id"], d["last_link_id"]
ref, join, prep = nid + 1, nid + 2, nid + 3
l1, l2, l3, l4 = lid + 1, lid + 2, lid + 3, lid + 4
d["nodes"] += [
 {"id": ref, "type": "LoadImage", "pos": [0, 560], "size": [380, 400], "flags": {}, "order": 0, "mode": 0,
  "inputs": [], "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [l1], "slot_index": 0},
                            {"name": "MASK", "type": "MASK", "links": [l2], "slot_index": 1}],
  "properties": {"Node name for S&R": "LoadImage"}, "widgets_values": ["leather_refer.png", "image"],
  "title": "Outfit reference (picture 2)", "color": "#432", "bgcolor": "#653"},
 {"id": join, "type": "JoinImageWithAlpha", "pos": [420, 560], "size": [380, 46], "flags": {}, "order": 1, "mode": 0,
  "inputs": [{"name": "image", "type": "IMAGE", "link": l1}, {"name": "alpha", "type": "MASK", "link": l2}],
  "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [l3], "slot_index": 0}],
  "properties": {"Node name for S&R": "JoinImageWithAlpha"}, "title": "Keep reference transparency"},
 {"id": prep, "type": "PrepareSpriteForVideo", "pos": [420, 640], "size": [340, 130], "flags": {}, "order": 2, "mode": 0,
  "inputs": [{"name": "sprite", "type": "IMAGE", "link": l3}],
  "outputs": [{"name": "image", "type": "IMAGE", "links": [l4], "slot_index": 0},
              {"name": "pixel_spec", "type": "PIXEL_SPEC", "links": [], "slot_index": 1},
              {"name": "width", "type": "INT", "links": []}, {"name": "height", "type": "INT", "links": []},
              {"name": "info", "type": "STRING", "links": []}],
  "properties": {"Node name for S&R": "PrepareSpriteForVideo"}, "widgets_values": [1024, 0.25, "auto"],
  "title": "Prepare reference (integer upscale)"},
]
d["links"] += [[l1, ref, 0, join, 0, "IMAGE"], [l2, ref, 1, join, 1, "MASK"],
               [l3, join, 0, prep, 0, "IMAGE"], [l4, prep, 0, 70, 3, "IMAGE"]]
N[70]["inputs"].append({"name": "image2", "type": "IMAGE", "link": l4})
N[70]["widgets_values"] = ["Dress the character in picture 1 in the same outfit as the character in picture 2. "
  "Copy the clothes from picture 2 exactly. Keep the face, skin, body, pose, facing direction, "
  "proportions and pixel-art style of picture 1 exactly the same."]
d["last_node_id"], d["last_link_id"] = prep, l4
json.dump(d, open(dst, "w"), ensure_ascii=False)
print("patched workflow ->", dst)
PY

# 크기·위치가 밀리는 문제를 줄인 버전(인코더의 VAE 입력을 끊고 ReferenceLatent로 원본 크기 latent를 넣음)
curl -fsSL -o $WF/sprite-edit-2511-outfit-reflatent.json https://raw.githubusercontent.com/qwe179/inky-comfyui/main/workflows/sprite-edit-2511-outfit-reflatent.json \
  && echo "workflow: reflatent 버전 받음" || echo "workflow: reflatent 버전 못 받음(무시하고 진행)"

# 4) 템플릿이 ComfyUI를 특정 커밋에 고정해 둬서 git pull은 실패한다. fetch + checkout으로 올린다.
#    (inky-comfyui/start.sh와 같은 방식. 워크플로가 ComfyUI 0.41 이상을 요구한다.)
until curl -s -o /dev/null localhost:8188; do sleep 10; done
cd $C && git fetch origin && git checkout origin/master && $PIP install -r requirements.txt || exit 1

# "[m]ain.py --listen"으로 찾는다. 그냥 main.py로 찾으면 시작 명령 문자열을 가진 1번 프로세스가 잡혀 컨테이너가 통째로 재시작된다.
# 템플릿은 --use-sage-attention 으로 띄우는데, Qwen-Image-Edit-2511은 이 옵션에서 결과가 NaN(검은 이미지)이 된다.
# 2026-11-14 A40에서 확인: 옵션을 빼고 재시작하자 정상 출력. 그래서 재시작할 때 이 옵션만 뺀다.
P=$(pgrep -f "[m]ain.py --listen" | head -1) && tr '\0' '\n' < /proc/$P/cmdline | grep -v -- '--use-sage-attention' | tr '\n' '\0' > /tmp/comfy_cmd \
  && kill $P && sleep 5 && (nohup xargs -0 -a /tmp/comfy_cmd env > /tmp/comfy_restart.log 2>&1 &)
git log -1 --format="ComfyUI %h %cd"
echo "READY: 워크플로 sprite-edit-2511-outfit 를 열고, ComfyUI input 칸에 대머리 로테이션 PNG와 leather_refer.png 를 올린다."
