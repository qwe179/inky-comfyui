#!/bin/bash
# push_batch.sh가 만든 파일. Pod이 뜰 때 자동으로: 배치 zip 받기 -> / 에 풀기 -> /run.sh 만들기. 실행은 상진이 bash /run.sh
set -e
cd /
echo '== 배치 받기: plate_batch.zip'
curl -fsSL -H 'Accept: application/vnd.github.raw' -o '/plate_batch.zip' 'https://api.github.com/repos/qwe179/inky-comfyui/contents/plate_batch.zip?ref=batch'
python3 -m zipfile -e '/plate_batch.zip' /
printf '%s\n' '#!/bin/bash' 'set -e' 'cd /' 'python3 run_batch.py work/plate/jobs_fix.json --redo work/plate/redo.json --workflow h3_r2v_template_api.json' 'tar -czf /plate_results.tar.gz work/plate/results' 'echo "== 끝: /plate_results.tar.gz 를 받아 온다"' > /run.sh
echo '== 준비 끝. 실행: bash /run.sh'
