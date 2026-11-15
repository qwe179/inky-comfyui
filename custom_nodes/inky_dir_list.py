"""ComfyUI 커스텀 노드: 8방향 목록에서 index번째 방향의 그림·프롬프트·저장 이름을 꺼낸다.
H3 I2V로 한 동작을 8방향 차례로 뽑을 때 쓴다 (workflows/h3_i2v_8dir_*.json).

- image_1 ~ image_8: 방향별 LoadImage를 연결한다. 순서는 directions 목록 순서와 같다.
- directions: 한 줄에 "방향 | 그 방향 문구". 빈 줄과 #으로 시작하는 줄은 건너뛴다.
- prompt: 프롬프트 틀. {facing} 자리에 그 방향 문구가 들어간다.
- index: 실행할 때마다 1씩 올라가게(increment) 두고, Run 횟수를 방향 수만큼 넣으면 대기열에 전부 들어간다.
  방향 수를 넘으면 처음부터 다시 돈다(같은 방향을 다른 seed로 한 번 더).
설치: 이 파일을 ComfyUI/custom_nodes/에 넣고 ComfyUI를 다시 켠다.
"""

DEFAULT_DIRS = """south | facing down, toward the bottom of the screen
south-east | facing down-right, toward the bottom-right of the screen
east | facing right, toward the right side of the screen
north-east | facing up-right, toward the top-right of the screen, back partly to the camera
north | facing up, toward the top of the screen, back to the camera
north-west | facing up-left, toward the top-left of the screen, back partly to the camera
west | facing left, toward the left side of the screen
south-west | facing down-left, toward the bottom-left of the screen"""

MAX_IMAGES = 8


def parse_dirs(text):
    rows = [[c.strip() for c in l.split("|", 1)] for l in text.splitlines()
            if l.strip() and not l.lstrip().startswith("#")]
    if not rows or any(len(r) != 2 or not r[0] for r in rows):
        raise ValueError("방향 목록은 한 줄에 '방향 | 문구' 형식이어야 해요")
    if len(rows) > MAX_IMAGES:
        raise ValueError(f"방향은 {MAX_IMAGES}개까지예요")
    return rows


def pick(directions, prompt, motion_name, index):
    """(목록 위치, 방향, 프롬프트, 저장 이름, 방향 수)"""
    rows = parse_dirs(directions)
    i = index % len(rows)
    d, facing = rows[i]
    take = index // len(rows) + 1
    return i, d, prompt.replace("{facing}", facing), f"h3i2v/{motion_name}/{d}_take{take}", len(rows)


class DirectionListPick:
    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "motion_name": ("STRING", {"default": "attack_one_hand"}),
                "prompt": ("STRING", {"multiline": True, "default": "{facing}"}),
                "directions": ("STRING", {"multiline": True, "default": DEFAULT_DIRS}),
                "index": ("INT", {"default": 0, "min": 0, "max": 9999, "control_after_generate": True}),
            },
            "optional": {f"image_{k}": ("IMAGE",) for k in range(1, MAX_IMAGES + 1)},
        }

    RETURN_TYPES = ("IMAGE", "STRING", "STRING", "STRING")
    RETURN_NAMES = ("image", "prompt", "filename_prefix", "direction")
    FUNCTION = "run"
    CATEGORY = "utils"

    def run(self, motion_name, prompt, directions, index, **images):
        i, d, text, prefix, n = pick(directions, prompt, motion_name, index)
        img = images.get(f"image_{i + 1}")
        if img is None:
            raise ValueError(f"image_{i + 1} ({d}) 에 LoadImage가 연결되어 있지 않아요")
        print(f"[DirectionListPick] {i + 1}/{n} {d} -> {prefix}")
        return (img, text, prefix, d)


NODE_CLASS_MAPPINGS = {"DirectionListPick": DirectionListPick}
NODE_DISPLAY_NAME_MAPPINGS = {"DirectionListPick": "Direction List Pick (INKY)"}

if __name__ == "__main__":  # 간단 확인 (torch 없이)
    r = pick(DEFAULT_DIRS, "A {facing} B", "atk", 0)
    assert r[:2] == (0, "south") and r[2] == "A facing down, toward the bottom of the screen B" and r[3] == "h3i2v/atk/south_take1", r
    r = pick(DEFAULT_DIRS, "{facing}", "atk", 9)
    assert r[:2] == (1, "south-east") and r[3] == "h3i2v/atk/south-east_take2", r
    r = pick("# x\nsouth | a\n\neast | b\n", "{facing}", "m", 1)
    assert r[1] == "east" and r[2] == "b" and r[4] == 2, r
    node = DirectionListPick()
    out = node.run("atk", "{facing}", DEFAULT_DIRS, 2, image_3="IMG3")
    assert out[0] == "IMG3" and out[3] == "east", out
    try:
        node.run("atk", "{facing}", DEFAULT_DIRS, 3)
        raise SystemExit("빈 입력을 못 잡음")
    except ValueError:
        pass
    print("ok")
