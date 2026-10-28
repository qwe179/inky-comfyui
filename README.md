# inky-comfyui

INKY WORLD 영상용 ComfyUI 워크플로와 커스텀 노드. RunPod 시작 명령이 이 저장소에서 파일을 받아 간다.

| 파일 | 넣는 곳 |
|---|---|
| `workflows/audio_yue2_song_list.json` | `ComfyUI/user/default/workflows/` |
| `custom_nodes/inky_song_list.py` | `ComfyUI/custom_nodes/` (넣은 뒤 ComfyUI 재시작) |

`audio_yue2_song_list`는 Comfy-Org 공식 YuE2 Text to Music 템플릿에 곡 목록 노드를 붙인 것이다. 곡 목록에 한 줄씩 `곡 이름 | 스타일 | 최대 초`를 적고 Run 횟수를 곡 수만큼 넣는다.
