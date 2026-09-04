from __future__ import annotations

import json
from pathlib import Path
from typing import Any

try:
    from PIL import Image
except ImportError:
    Image = None


ANCHOR_SCHEMA_VERSION = 1
ANCHORS_FILENAME = "anchors.json"


def pil_available() -> bool:
    return Image is not None


def decode_state_anchors(source_dir: Path, source_name: str, frame_width: int, frame_height: int) -> dict[str, Any] | None:
    if Image is None or frame_width <= 0 or frame_height <= 0:
        return None
    anim_path = source_dir / f"{source_name}-Anim.png"
    offsets_path = source_dir / f"{source_name}-Offsets.png"
    shadow_path = source_dir / f"{source_name}-Shadow.png"
    if not anim_path.exists() or not offsets_path.exists() or not shadow_path.exists():
        return None
    with Image.open(anim_path) as anim_img:
        width, height = anim_img.size
    with Image.open(offsets_path) as offsets_img, Image.open(shadow_path) as shadow_img:
        if offsets_img.size != (width, height) or shadow_img.size != (width, height):
            return None
        if width % frame_width != 0 or height % frame_height != 0:
            return None
        offsets_px = offsets_img.convert("RGBA").load()
        shadow_px = shadow_img.convert("RGBA").load()
        columns = width // frame_width
        rows = height // frame_height
        half_w = frame_width // 2
        half_h = frame_height // 2
        dirs: list[list[list[int | None]]] = []
        for row in range(rows):
            frames: list[list[int | None]] = []
            for column in range(columns):
                head = center = left = right = shadow = None
                base_x = column * frame_width
                base_y = row * frame_height
                for y in range(frame_height):
                    for x in range(frame_width):
                        r, g, b, a = offsets_px[base_x + x, base_y + y]
                        if a == 0:
                            pass
                        else:
                            if r == 0 and g == 0 and b == 0:
                                head = (x, y)
                            if r == 255:
                                left = (x, y)
                            if g == 255:
                                center = (x, y)
                            if b == 255:
                                right = (x, y)
                        sr, sg, sb, sa = shadow_px[base_x + x, base_y + y]
                        if sa != 0 and sr == 255 and sg == 255 and sb == 255:
                            shadow = (x, y)
                frames.append(_pack_frame(center, head, left, right, shadow, half_w, half_h))
            dirs.append(frames)
    return {
        "cell": [frame_width, frame_height],
        "rows": rows,
        "frames": columns,
        "dirs": dirs,
    }


def _pack_frame(center, head, left, right, shadow, half_w: int, half_h: int) -> list[int | None]:
    def rel(point):
        if point is None:
            return [None, None]
        return [point[0] - half_w, point[1] - half_h]

    if center is not None and head is None:
        head = center
    packed: list[int | None] = []
    for point in (center, head, left, right, shadow):
        packed.extend(rel(point))
    return packed


def write_anchor_file(
    *,
    destination: Path,
    states: dict[str, dict[str, Any]],
    shadow_size: int,
    source_repo: str,
    source_dir: str,
    source_revision: str,
    dry_run: bool,
) -> dict[str, Any]:
    payload = {
        "schema_version": ANCHOR_SCHEMA_VERSION,
        "coordinates": "pixels_from_cell_center_x_right_y_down",
        "frame_layout": "center_x,center_y,head_x,head_y,left_hand_x,left_hand_y,right_hand_x,right_hand_y,shadow_x,shadow_y",
        "row_order": "Down,DownRight,Right,UpRight,Up,UpLeft,Left,DownLeft",
        "shadow_size": shadow_size,
        "source": {
            "repo": source_repo,
            "dir": source_dir,
            "revision": source_revision,
        },
        "states": {name: states[name] for name in sorted(states)},
    }
    text = json.dumps(payload, separators=(",", ":"), sort_keys=True) + "\n"
    changed = True
    if destination.exists():
        changed = destination.read_text(encoding="utf-8") != text
    if not dry_run and changed:
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(text, encoding="utf-8")
    return {"path": destination, "changed": changed, "state_count": len(states)}
