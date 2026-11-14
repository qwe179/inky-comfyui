#!/bin/bash
# R2V 시험 하나를 Pod에 준비한다. 모델은 r2v_start.sh 로 이미 받아 둔 상태여야 한다.
# 사용 (Pod 터미널):
#   curl -fsSL https://raw.githubusercontent.com/qwe179/inky-comfyui/main/r2v_prep.sh | bash -s r2v_traveler_run_se
# 저장소 inputs/<이름>/ 에 ref.png(옷 참조, 10배 640px) 와 frame_000.png… (대머리 동작, 10배) 가 있어야 하고,
# workflows/h3_<이름 앞의 r2v_ 를 뗀 것>.json 이 아니라 workflows/h3_<이름>.json 형태로 워크플로가 있다.
#   예) 이름 r2v_traveler_run_se → workflows/h3_r2v_traveler_run_se.json
# 결과: /ComfyUI/input/<이름>_ref.png, /ComfyUI/input/<이름>.mp4 (24fps, 프레임당 6장), 워크플로 목록에 h3_<이름>
N=${1:?이름을 주세요 (예: r2v_traveler_run_se)}
PY=$(command -v python || command -v python3)
R=https://raw.githubusercontent.com/qwe179/inky-comfyui/main
C=/ComfyUI; T=/tmp/$N; mkdir -p $T $C/input $C/user/default/workflows
curl -fsSL -o $C/input/${N}_ref.png $R/inputs/$N/ref.png && echo "ref ok" || { echo "ref 없음"; exit 1; }
i=0
while curl -fsSL -o $T/$(printf "frame_%03d.png" $i) $R/inputs/$N/$(printf "frame_%03d.png" $i) 2>/dev/null; do i=$((i+1)); done
rm -f $T/$(printf "frame_%03d.png" $i); echo "frames $i"
[ $i -gt 0 ] || exit 1
curl -fsSL -o $C/user/default/workflows/h3_$N.json $R/workflows/h3_$N.json && echo "workflow ok"
$PY - "$T" "$C/input/$N.mp4" <<'PY'
import glob, sys, av, numpy as np
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
files = sorted(glob.glob(src + '/frame_*.png'))
w, h = Image.open(files[0]).size
out = av.open(dst, 'w')
s = out.add_stream('libx264', rate=24); s.width, s.height, s.pix_fmt = w, h, 'yuv420p'
s.options = {'crf': '10'}
for f in files:
    img = np.array(Image.open(f).convert('RGB'))
    for _ in range(6):
        for p in s.encode(av.VideoFrame.from_ndarray(img, format='rgb24')): out.mux(p)
for p in s.encode(): out.mux(p)
out.close(); print('video ok', len(files), 'frames x6 ->', dst)
PY
echo "READY: 브라우저 F5 → 워크플로 h3_$N 열고 실행"
