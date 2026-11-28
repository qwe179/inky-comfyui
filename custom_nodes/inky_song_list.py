"""ComfyUI 커스텀 노드: 곡 목록에서 index번째 곡의 이름과 스타일을 꺼낸다.
곡 목록은 한 줄에 "곡 이름 | 스타일 | 최대 초(생략하면 240)". 빈 줄과 #으로 시작하는 줄은 건너뛴다.
SongListPick: index는 실행할 때마다 1씩 올라가게(increment) 두고, Run 횟수를 곡 수만큼 넣으면 대기열에 전부 들어간다.
SongListAll: 목록 전체를 리스트로 내보내서 Run 한 번에 모든 곡이 나온다(영상 한 편용 워크플로 audio_stable_audio_3_video.json).
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


class SongListAll:
    """곡 목록 전체를 리스트로 내보낸다. 뒤 노드들이 곡마다 한 번씩 돌아서 Run 한 번에 모든 곡이 나온다.
    seed는 실행마다 랜덤(randomize)이고, 곡마다 이 seed에서 다른 seed를 만든다."""
    @classmethod
    def INPUT_TYPES(cls):
        return {"required": {
            "songs": ("STRING", {"multiline": True, "default": "Door Code | Dark ambient, low drone | 240"}),
            "seed": ("INT", {"default": 0, "min": 0, "max": 0xffffffffffffffff, "control_after_generate": True}),
        }}

    RETURN_TYPES = ("STRING", "STRING", "STRING", "FLOAT", "INT")
    RETURN_NAMES = ("title", "style", "filename_prefix", "max_duration", "seed")
    OUTPUT_IS_LIST = (True, True, True, True, True)
    FUNCTION = "pick_all"
    CATEGORY = "utils"

    def pick_all(self, songs, seed):
        import random
        rows = [[c.strip() for c in l.split("|")] for l in songs.splitlines() if l.strip() and not l.lstrip().startswith("#")]
        if not rows or any(len(r) not in (2, 3) for r in rows):
            raise ValueError("곡 목록은 한 줄에 '곡 이름 | 스타일 | 최대 초' 형식이어야 해요")
        rng = random.Random(seed)
        titles = [r[0] for r in rows]
        styles = [r[1] for r in rows]
        secs = [float(r[2]) if len(r) == 3 else 240.0 for r in rows]
        seeds = [rng.randrange(0, 2**63) for _ in rows]
        print(f"[SongListAll] {len(rows)}곡, 합계 {sum(secs)/60:.0f}분")
        return (titles, styles, ["audio/" + t for t in titles], secs, seeds)


NODE_CLASS_MAPPINGS = {"SongListPick": SongListPick, "SongListAll": SongListAll}
NODE_DISPLAY_NAME_MAPPINGS = {"SongListPick": "Song List Pick (INKY)", "SongListAll": "Song List All (INKY, Run 한 번에 전부)"}

if __name__ == "__main__":  # 간단 확인
    t = "# 주석\nA | x, y\n\nB | z | 200\n"
    assert SongListPick().pick(t, 0) == ("A", "x, y", "audio/A", 240.0)
    assert SongListPick().pick(t, 1)[3] == 200.0
    assert SongListPick().pick(t, 3)[0] == "B"
    a = SongListAll().pick_all(t, 7)
    assert a[0] == ["A", "B"] and a[3] == [240.0, 200.0] and a[2] == ["audio/A", "audio/B"]
    assert a[4] == SongListAll().pick_all(t, 7)[4] and a[4][0] != a[4][1]
    print("ok")
