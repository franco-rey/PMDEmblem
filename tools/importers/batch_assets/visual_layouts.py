from __future__ import annotations

from pathlib import Path
from typing import Any
from xml.etree import ElementTree

try:
    from PIL import Image
except ImportError:
    Image = None


ROTATE_TYPES = ("None", "Dir1", "Dir2", "Dir5", "Dir8", "Flip")


def dir_div(rotate_type: str) -> int:
    if rotate_type == "Dir2":
        return 2
    if rotate_type == "Dir5":
        return 5
    if rotate_type == "Dir8":
        return 8
    return 1


def image_size(path: Path) -> tuple[int, int]:
    if Image is None:
        return (0, 0)
    with Image.open(path) as img:
        return img.size


def resolve_sheet_layout(path: Path) -> dict[str, Any]:
    stem = path.name[: -len(path.suffix)] if path.suffix else path.name
    components = stem.split(".")
    type_string = components[-1] if len(components) > 1 else "None"
    width, height = image_size(path)
    layout: dict[str, Any] = {
        "kind": "None",
        "rotate": "None",
        "cell": [height, height],
        "frames": (width // height) if height > 0 else 0,
        "rows": 1,
        "size": [width, height],
    }
    if type_string.isdigit():
        frames = int(type_string)
        layout.update({"kind": "frames", "cell": [width // max(1, frames), height], "frames": frames, "rows": 1})
        return layout
    grid = type_string.split("x")
    if len(grid) == 2 and grid[0].isdigit() and grid[1].isdigit():
        columns = int(grid[0])
        rows = int(grid[1])
        layout.update({"kind": "grid", "cell": [width // max(1, columns), height // max(1, rows)], "frames": columns * rows, "rows": rows, "columns": columns})
        return layout
    if type_string in ROTATE_TYPES:
        div = dir_div(type_string)
        cell = height // div if div > 0 else height
        layout.update({"kind": "rotate", "rotate": type_string, "cell": [cell, cell], "frames": (width // cell) if cell > 0 else 0, "rows": div})
        return layout
    return layout


def resolve_frame_directory_layout(directory: Path) -> dict[str, Any]:
    dir_data = directory / "DirData.xml"
    rotate = "None"
    if dir_data.exists():
        try:
            rotate = (ElementTree.parse(dir_data).getroot().findtext("DirType") or "None").strip()
        except ElementTree.ParseError:
            rotate = "None"
    frames: list[str] = []
    index = 0
    while (directory / f"{index}.png").exists():
        frames.append(f"{index}.png")
        index += 1
    width, height = image_size(directory / frames[0]) if frames else (0, 0)
    div = dir_div(rotate)
    return {
        "kind": "dir_frames",
        "rotate": rotate,
        "cell": [width, height // div if div > 0 else height],
        "frames": len(frames),
        "rows": div,
        "size": [width, height],
        "frame_files": frames,
    }


def resolve_beam_layout(directory: Path) -> dict[str, Any]:
    beam_data = directory / "BeamData.xml"
    total_frames = 1
    if beam_data.exists():
        try:
            total_frames = int((ElementTree.parse(beam_data).getroot().findtext("TotalFrames") or "1").strip())
        except (ElementTree.ParseError, ValueError):
            total_frames = 1
    components: dict[str, Any] = {}
    for name in ("Head", "Body", "Tail"):
        png = directory / f"{name}.png"
        if not png.exists():
            continue
        width, height = image_size(png)
        components[name.lower()] = {"size": [width, height], "cell": [width // max(1, total_frames), height]}
    return {"kind": "beam", "frames": total_frames, "components": components}
