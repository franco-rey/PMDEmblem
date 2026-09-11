from __future__ import annotations

import argparse
import json
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image

from source_config import PROJECT_ROOT, load_config

OUTPUT_DIR = PROJECT_ROOT / "assets" / "fonts" / "pmd"
REPORT_PATH = PROJECT_ROOT / "data" / "models" / "visuals" / "import_reports" / "font_report.json"
DEFAULT_FONTS = ["text", "banner", "system", "simple", "blue", "green", "yellow"]
DEFAULT_RANGES = "0000-24FF,2600-27BF,E000-E0FF"
PADDING = 1
MAX_WIDTH = 2048


def parse_ranges(text: str) -> list[tuple[int, int]]:
    out = []
    for part in text.split(","):
        part = part.strip()
        if not part:
            continue
        low, _, high = part.partition("-")
        out.append((int(low, 16), int(high or low, 16)))
    return out


def in_ranges(code: int, ranges: list[tuple[int, int]]) -> bool:
    return any(low <= code <= high for low, high in ranges)


def read_font_data(folder: Path) -> dict:
    root = ET.parse(folder / "FontData.xml").getroot()
    colorless = [g.text.strip() for g in root.findall("./Colorless/Glyph") if g.text]
    return {
        "space_width": int(root.findtext("SpaceWidth", "4")),
        "char_height": int(root.findtext("CharHeight", "12")),
        "char_space": int(root.findtext("CharSpace", "0")),
        "line_space": int(root.findtext("LineSpace", "0")),
        "colorless": colorless,
    }


def collect_glyphs(folder: Path, ranges: list[tuple[int, int]]) -> list[tuple[int, Path]]:
    glyphs = []
    for path in sorted(folder.glob("*.png")):
        stem = path.stem
        try:
            code = int(stem, 16)
        except ValueError:
            continue
        if code == 0 or in_ranges(code, ranges):
            glyphs.append((code, path))
    return glyphs


def pack(name: str, folder: Path, ranges: list[tuple[int, int]], out_dir: Path) -> dict:
    data = read_font_data(folder)
    entries = []
    for code, path in collect_glyphs(folder, ranges):
        image = Image.open(path).convert("RGBA")
        entries.append({"code": code, "image": image, "w": image.width, "h": image.height})
    entries.sort(key=lambda e: (-e["h"], e["code"]))
    atlas_width = 256
    total_area = sum((e["w"] + PADDING) * (e["h"] + PADDING) for e in entries)
    while atlas_width * atlas_width < total_area * 1.3 and atlas_width < MAX_WIDTH:
        atlas_width *= 2
    x = PADDING
    y = PADDING
    row_height = 0
    for entry in entries:
        if x + entry["w"] + PADDING > atlas_width:
            x = PADDING
            y += row_height + PADDING
            row_height = 0
        entry["x"] = x
        entry["y"] = y
        x += entry["w"] + PADDING
        row_height = max(row_height, entry["h"])
    atlas_height = 1
    while atlas_height < y + row_height + PADDING:
        atlas_height *= 2
    atlas = Image.new("RGBA", (atlas_width, atlas_height), (0, 0, 0, 0))
    for entry in entries:
        atlas.paste(entry["image"], (entry["x"], entry["y"]))
    caps = [e["h"] for e in entries if 0x41 <= e["code"] <= 0x5A]
    base = max(set(caps), key=caps.count) if caps else data["char_height"]
    line_height = data["char_height"] + data["line_space"]
    page_name = f"pmd_{name}_0.png"
    atlas.save(out_dir / page_name, optimize=True)
    lines = [
        f'info face="pmd_{name}" size={data["char_height"]} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0 outline=0',
        f"common lineHeight={line_height} base={base} scaleW={atlas_width} scaleH={atlas_height} pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4",
        f'page id=0 file="{page_name}"',
    ]
    chars = []
    codes = {e["code"] for e in entries}
    if 0x20 not in codes:
        chars.append(f'char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance={data["space_width"]} page=0 chnl=15')
    for entry in entries:
        if entry["code"] == 0:
            continue
        chars.append(
            f'char id={entry["code"]} x={entry["x"]} y={entry["y"]} width={entry["w"]} height={entry["h"]} '
            f'xoffset=0 yoffset=0 xadvance={entry["w"] + data["char_space"]} page=0 chnl=15'
        )
    lines.append(f"chars count={len(chars)}")
    lines.extend(chars)
    (out_dir / f"pmd_{name}.fnt").write_text("\n".join(lines) + "\n")
    return {
        "font": name,
        "glyphs": len(chars),
        "atlas": [atlas_width, atlas_height],
        "char_height": data["char_height"],
        "line_height": line_height,
        "base": base,
        "space_width": data["space_width"],
        "colorless": data["colorless"],
        "fallback_glyph": 0 in codes,
        "files": [f"pmd_{name}.fnt", page_name],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Pack PMDO bitmap fonts into BMFont atlases for Godot.")
    parser.add_argument("--raw-asset-root")
    parser.add_argument("--pmdo-root")
    parser.add_argument("--sprite-collab-root")
    parser.add_argument("--fonts", default=",".join(DEFAULT_FONTS))
    parser.add_argument("--ranges", default=DEFAULT_RANGES, help="Comma list of hex codepoint ranges to include (glyph 0000 is always kept as the fallback).")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    sources = load_config(args)
    font_root = sources.raw_asset_root / "font"
    ranges = parse_ranges(args.ranges)
    names = [n.strip() for n in args.fonts.split(",") if n.strip()]
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    report = {"source": str(font_root), "ranges": args.ranges, "fonts": []}
    for name in names:
        folder = font_root / name
        if not folder.is_dir():
            print(f"missing font folder: {folder}")
            return 1
        if args.dry_run:
            glyphs = collect_glyphs(folder, ranges)
            print(f"{name}: {len(glyphs)} glyphs selected of {len(list(folder.glob('*.png')))}")
            continue
        entry = pack(name, folder, ranges, OUTPUT_DIR)
        report["fonts"].append(entry)
        print(f"{name}: {entry['glyphs']} glyphs, atlas {entry['atlas'][0]}x{entry['atlas'][1]}, line {entry['line_height']}, base {entry['base']}")
    if not args.dry_run:
        REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
        REPORT_PATH.write_text(json.dumps(report, indent=2) + "\n")
        print(f"wrote {REPORT_PATH.relative_to(PROJECT_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
