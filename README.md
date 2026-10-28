# inky-comfyui

INKY WORLD 영상용 ComfyUI 워크플로와 커스텀 노드. RunPod 시작 명령이 이 저장소의 `start.sh`를 받아 실행하고, `start.sh`가 아래 파일을 설치한다.

RunPod Container Start Command:

```
bash -c '(curl -fsSL https://raw.githubusercontent.com/qwe179/inky-comfyui/main/start.sh | bash) > /tmp/extra_models.log 2>&1 & exec /start_script.sh'
```

| 파일 | 넣는 곳 |
|---|---|
| `workflows/audio_yue2_song_list.json` | `ComfyUI/user/default/workflows/` |
| `workflows/audio_yue2_song_list_mothersuperior.json` | 같은 곳. 곡 목록 + Mothersuperior 연주곡 LoRA(CC BY-NC 4.0, 비상업 시험용) |
| `custom_nodes/inky_song_list.py` | `ComfyUI/custom_nodes/` (넣은 뒤 ComfyUI 재시작) |

`audio_yue2_song_list`는 Comfy-Org 공식 YuE2 Text to Music 템플릿에 곡 목록 노드를 붙인 것이다. 곡 목록에 한 줄씩 `곡 이름 | 스타일 | 최대 초`를 적고 Run 횟수를 곡 수만큼 넣는다.
