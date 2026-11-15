"""ComfyUI 커스텀 노드: 8방향 목록에서 index번째 방향의 입력 이미지·프롬프트·저장 이름을 꺼낸다.
H3 I2V로 한 동작을 8방향 차례로 뽑을 때 쓴다 (workflows/h3_i2v_8dir.json).

- directions: 한 줄에 "방향 | 그 방향 문구". 빈 줄과 #으로 시작하는 줄은 건너뛴다.
  방향 이름은 입력 이미지 파일 이름에 쓰인다: input/h3i2v/<image_set>_<방향>.png
- prompt: 프롬프트 틀. {facing} 자리에 그 방향 문구가 들어간다.
- index: 실행할 때마다 1씩 올라가게(increment) 두고, Run 횟수를 방향 수만큼 넣으면 대기열에 전부 들어간다.
  방향 수를 넘으면 처음부터 다시 돈다(같은 방향을 다른 seed로 한 번 더).
설치: 이 파일을 ComfyUI/custom_nodes/에 넣고 ComfyUI를 다시 켠다.
"""
import os

DEFAULT_DIRS = """south | facing down, toward the bottom of the screen
south-east | facing down-right, toward the bottom-right of the screen
east | facing right, toward the right side of the screen
north-east | facing up-right, toward the top-right of the screen, back partly to the camera
north | facing up, toward the top of the screen, back to the camera
north-west | facing up-left, toward the top-left of the screen, back partly to the camera
west | facing left, toward the left side of the screen
south-west | facing down-left, toward the bottom-left of the screen"""


def parse_dirs(text):
    rows = [[c.strip() for c in l.split("|", 1)] for l in text.splitlines()
            if l.strip() and not l.lstrip().startswith("#")]
    if not rows or any(len(r) != 2 or not r[0] for r in rows):
        raise ValueError("방향 목록은 한 줄에 '방향 | 문구' 형식이어야 해요")
    return rows


def pick(directions, prompt, image_set, motion_name, index):
    rows = parse_dirs(directions)
    i = index % len(rows)
    d, facing = rows[i]
    take = index // len(rows) + 1
    text = prompt.replace("{facing}", facing)
    image_path = os.path.join("h3i2v", f"{image_set}_{d}.png")
    prefix = f"h3i2v/{motion_name}/{d}_take{take}"
    return d, text, image_path, prefix, i, len(rows)


class AnyType(str):
    """어떤 입력에도 연결되게 하는 타입 (LoadImage의 image 칸처럼 목록 칸에 파일 이름을 넣으려고)."""

    def __ne__(self, other):
        return False


ANY = AnyType("*")


class DirectionListPick:
    @classmethod
    def INPUT_TYPES(cls):
        return {"required": {
            "image_set": ("STRING", {"default": "one_hand"}),
            "motion_name": ("STRING", {"default": "attack_one_hand"}),
            "prompt": ("STRING", {"multiline": True, "default": "{facing}"}),
            "directions": ("STRING", {"multiline": True, "default": DEFAULT_DIRS}),
            "index": ("INT", {"default": 0, "min": 0, "max": 9999, "control_after_generate": True}),
        }}

    # image_name 은 LoadImage 의 image 칸에 연결한다 (input/ 기준 경로, 예: h3i2v/one_hand_south.png)
    RETURN_TYPES = (ANY, "STRING", "STRING", "STRING")
    RETURN_NAMES = ("image_name", "prompt", "filename_prefix", "direction")
    FUNCTION = "run"
    CATEGORY = "utils"

    def run(self, image_set, motion_name, prompt, directions, index):
        import folder_paths

        d, text, rel, prefix, i, n = pick(directions, prompt, image_set, motion_name, index)
        rel = rel.replace(os.sep, "/")
        path = os.path.join(folder_paths.get_input_directory(), rel)
        if not os.path.exists(path):
            raise FileNotFoundError(f"입력 이미지가 없어요: {path}")
        print(f"[DirectionListPick] {i + 1}/{n} {d} {rel} -> {prefix}")
        return (rel, text, prefix, d)


NODE_CLASS_MAPPINGS = {"DirectionListPick": DirectionListPick}
NODE_DISPLAY_NAME_MAPPINGS = {"DirectionListPick": "Direction List Pick (INKY)"}

if __name__ == "__main__":  # 간단 확인 (torch 없이 목록 처리만)
    r = pick(DEFAULT_DIRS, "A {facing} B", "one_hand", "atk", 0)
    assert r[0] == "south" and r[1] == "A facing down, toward the bottom of the screen B", r
    assert r[2] == os.path.join("h3i2v", "one_hand_south.png") and r[3] == "h3i2v/atk/south_take1", r
    r = pick(DEFAULT_DIRS, "{facing}", "one_hand", "atk", 9)
    assert r[0] == "south-east" and r[3] == "h3i2v/atk/south-east_take2", r
    r = pick("# x\nsouth | a\n\neast | b\n", "{facing}", "base", "m", 1)
    assert r[0] == "east" and r[1] == "b" and r[5] == 2, r
    try:
        pick("south", "", "a", "b", 0)
        raise SystemExit("형식 오류를 못 잡음")
    except ValueError:
        pass
    print("ok")
