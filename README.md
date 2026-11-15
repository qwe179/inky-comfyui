# inky-comfyui

INKY WORLD 영상용 ComfyUI 워크플로와 커스텀 노드. RunPod 시작 명령이 이 저장소의 `start.sh`를 받아 실행하고, `start.sh`가 아래 파일을 설치한다.

RunPod Container Start Command:

```
bash -c '(curl -fsSL https://raw.githubusercontent.com/qwe179/inky-comfyui/main/start.sh | bash) > /tmp/extra_models.log 2>&1 & exec /start_script.sh'
```

| 파일 | 넣는 곳 |
|---|---|
| `workflows/audio_yue2_song_list.json` | `ComfyUI/user/default/workflows/` |
| `workflows/audio_stable_audio_3_song_list.json` | 같은 곳. Stable Audio 3 Medium 공식 템플릿 + 곡 목록 노드 + seed 랜덤 (다크 앰비언트 시험용) |
| `custom_nodes/inky_song_list.py` | `ComfyUI/custom_nodes/` (넣은 뒤 ComfyUI 재시작) |

`audio_yue2_song_list`는 Comfy-Org 공식 YuE2 Text to Music 템플릿에 곡 목록 노드를 붙인 것이다. 곡 목록에 한 줄씩 `곡 이름 | 스타일 | 최대 초`를 적고 Run 횟수를 곡 수만큼 넣는다.

## H3 I2V 8방향 (픽셀 캐릭터 동작)

RunPod Container Start Command:

```
bash -c '(curl -fsSL https://raw.githubusercontent.com/qwe179/inky-comfyui/main/h3_i2v_start.sh | bash) > /tmp/i2v_setup.log 2>&1 & exec /start_script.sh'
```

| 파일 | 내용 |
|---|---|
| `h3_i2v_start.sh` | I2V 모델(약 52GB)·노드·워크플로·입력을 받고 ComfyUI를 재시작. 로그 `/tmp/i2v_setup.log` 마지막 줄 READY |
| `workflows/h3_i2v_8dir.json` | H3 I2V 워크플로. 방향 목록 노드가 Run마다 다음 방향의 입력 그림·프롬프트·저장 이름을 넘긴다. Run 횟수 8 = 8방향 |
| `custom_nodes/inky_dir_list.py` | 방향 목록 노드 (Direction List Pick). `{facing}` 자리에 방향 문구를 넣는다 |
| `inputs/h3i2v/<세트>_<방향>.png` | 64px 대머리를 10배(640px, 흰 배경)로 키운 시작 그림. 세트: base(맨손), one_hand, two_hand, dual, shield |

결과는 `output/h3i2v/<motion_name>/<방향>_take<n>_*.gif`(64px)와 `.mp4`(640px).
