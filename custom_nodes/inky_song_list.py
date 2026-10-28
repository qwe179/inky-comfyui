"""ComfyUI 커스텀 노드: 곡 목록에서 index번째 곡의 이름과 스타일을 꺼낸다.
곡 목록은 한 줄에 "곡 이름 | 스타일 | 최대 초(생략하면 240)". 빈 줄과 #으로 시작하는 줄은 건너뛴다.
index는 실행할 때마다 1씩 올라가게(increment) 두고, Run 횟수를 곡 수만큼 넣으면 대기열에 전부 들어간다.
설치: 이 파일을 ComfyUI/custom_nodes/에 넣고 ComfyUI를 다시 켠다.
"""


class SongListPick:
    @classmethod
    def INPUT_TYPES(cls):
        return {"required": {
            "songs": ("STRING", {"multiline": True, "default": "Door Code | Darksynth, slow, synth pads, club, instrumental"}),
            "index": ("INT", {"default": 0, "min": 0, "max": 9999, "control_after_generate": True}),
        }}

    RETURN_TYPES = ("STRING", "STRING", "STRING", "FLOAT")
    RETURN_NAMES = ("title", "style", "filename_prefix", "max_duration")
    FUNCTION = "pick"
    CATEGORY = "utils"

    def pick(self, songs, index):
        rows = [[c.strip() for c in l.split("|")] for l in songs.splitlines() if l.strip() and not l.lstrip().startswith("#")]
        if not rows or any(len(r) not in (2, 3) for r in rows):
            raise ValueError("곡 목록은 한 줄에 '곡 이름 | 스타일 | 최대 초' 형식이어야 해요")
        row = rows[index % len(rows)]  # 곡 수를 넘으면 처음부터 다시
        title, style, sec = row[0], row[1], float(row[2]) if len(row) == 3 else 240.0
        print(f"[SongListPick] {index % len(rows) + 1}/{len(rows)} {title} ({sec:.0f}s)")
        return (title, style, "audio/" + title, sec)


NODE_CLASS_MAPPINGS = {"SongListPick": SongListPick}
NODE_DISPLAY_NAME_MAPPINGS = {"SongListPick": "Song List Pick (INKY)"}

if __name__ == "__main__":  # 간단 확인
    t = "# 주석\nA | x, y\n\nB | z | 200\n"
    assert SongListPick().pick(t, 0) == ("A", "x, y", "audio/A", 240.0)
    assert SongListPick().pick(t, 1)[3] == 200.0
    assert SongListPick().pick(t, 3)[0] == "B"
    print("ok")
