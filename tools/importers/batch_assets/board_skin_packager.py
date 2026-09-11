from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image

PROJECT_ROOT = Path(__file__).resolve().parents[3]
RAW_ROOT = PROJECT_ROOT / "assets" / "visuals" / "raw_asset"
TILE_ROOT = RAW_ROOT / "TileDtef"
OBJECT_ROOT = RAW_ROOT / "Object"
BOARD_ROOT = RAW_ROOT / "Board"
MANIFEST_PATH = PROJECT_ROOT / "data" / "models" / "visuals" / "generated" / "board_skin_manifest.json"
REPORT_PATH = PROJECT_ROOT / "data" / "models" / "visuals" / "import_reports" / "board_skin_report.txt"
TILE = 24
BLOCK_WALL = 0
BLOCK_FLOOR = 2
CENTER = (1, 1)

SKINS = [
    ("amp_plains", "AmpPlains", "Amp Plains"),
    ("mt_horn", "MtHorn", "Mt. Horn"),
    ("barren_valley", "BarrenValley", "Barren Valley"),
    ("limestone_cavern", "LimestoneCavern", "Limestone Cavern"),
    ("side_path", "SidePath", "Side Path"),
    ("tiny_woods", "TinyWoods", "Tiny Woods"),
    ("treeshroud_forest", "TreeshroudForest1", "Treeshroud Forest"),
    ("grass_maze", "GrassMaze", "Grass Maze"),
    ("lush_prairie", "LushPrairie", "Lush Prairie"),
    ("apple_woods", "AppleWoods", "Apple Woods"),
    ("northern_desert", "NorthernDesert1", "Northern Desert"),
    ("howling_forest", "HowlingForest1", "Howling Forest"),
    ("steam_cave", "SteamCave", "Steam Cave"),
    ("meteor_cave", "MeteorCave", "Meteor Cave"),
    ("magma_cavern", "MagmaCavern2", "Magma Cavern"),
    ("ice_maze", "IceMaze", "Ice Maze"),
    ("snow_path", "SnowPath", "Snow Path"),
    ("crystal_cave", "CrystalCave1", "Crystal Cave"),
    ("poison_maze", "PoisonMaze", "Poison Maze"),
    ("dark_wasteland", "DarkWasteland", "Dark Wasteland"),
    ("temporal_tower", "TemporalTower", "Temporal Tower"),
    ("joyous_tower", "JoyousTower", "Joyous Tower"),
    ("northwind_field", "NorthwindField", "Northwind Field"),
    ("wish_cave", "WishCave1", "Wish Cave"),
]

OBJECTS = [
    "Tent.Flip", "Tent_Plain.Flip", "Campfire.Flip", "Logs_Stacked.Flip", "Storage.Flip", "Sign.None", "Berry_Basket_Red.None", "Pot.Flip",
    "Tree_Town.Flip", "Hedge.Flip", "Fence.Flip", "Flowers_Town_1.Flip", "Flowers_Town_2.Flip", "Flowers_Town_3.Flip", "Flowerpot_Pink.Flip", "Flowerpot_White.Flip", "Stump_Table.None", "Stump_Chair.None",
    "Trunk_Large.None", "Trunk_Small.None", "Logs_Large.Flip", "Chest.None", "Stairs_Down.None", "Portal_Small.None", "Sign_Crossroads.Flip", "Mission_Board.None",
]


def main() -> int:
    args = _parse_args()
    if not args.dry_run and not args.write:
        args.dry_run = True
    if not TILE_ROOT.is_dir() or not OBJECT_ROOT.is_dir():
        print(f"error: run raw_visual_packager.py first; expected {TILE_ROOT} and {OBJECT_ROOT}")
        return 2
    skins: dict[str, dict] = {}
    problems: list[str] = []
    for skin_id, folder, label in SKINS:
        source = TILE_ROOT / folder / "tileset_0.png"
        if not source.exists():
            problems.append(f"{skin_id}: missing {source.relative_to(PROJECT_ROOT)}")
            continue
        floors = [_slot(Image.open(source).convert("RGBA"), BLOCK_FLOOR)]
        for variant in (1, 2):
            path = TILE_ROOT / folder / f"tileset_{variant}.png"
            if path.exists():
                tile = _slot(Image.open(path).convert("RGBA"), BLOCK_FLOOR)
                if not _blank(tile):
                    floors.append(tile)
        wall = _slot(Image.open(source).convert("RGBA"), BLOCK_WALL)
        if _blank(floors[0]):
            problems.append(f"{skin_id}: floor tile is empty")
            continue
        if _blank(wall):
            wall = floors[0]
        luminance = _luminance(floors[0])
        light = min(1.5, 1.08 + max(0.0, 120.0 - luminance) / 250.0)
        dark = max(0.5, 0.72 - max(0.0, luminance - 150.0) / 350.0)
        dest = BOARD_ROOT / skin_id
        if args.write:
            dest.mkdir(parents=True, exist_ok=True)
            for index, tile in enumerate(floors):
                tile.save(dest / f"floor_{index}.png")
            wall.save(dest / "wall.png")
        skins[skin_id] = {
            "label": label,
            "folder": folder,
            "floor_variants": len(floors),
            "luminance": round(luminance, 1),
            "light": round(light, 3),
            "dark": round(dark, 3),
        }
    objects: dict[str, dict] = {}
    for name in OBJECTS:
        source = OBJECT_ROOT / f"{name}.png"
        if not source.exists():
            problems.append(f"object {name}: missing")
            continue
        image = Image.open(source).convert("RGBA")
        cell = image.height
        frames = max(1, image.width // cell) if image.width >= cell else 1
        short = name.split(".")[0]
        if args.write:
            (BOARD_ROOT / "objects").mkdir(parents=True, exist_ok=True)
            image.save(BOARD_ROOT / "objects" / f"{short}.png")
        objects[short] = {"frames": frames, "cell": [cell, cell], "source": name}
    generated_at = datetime.now(timezone.utc).isoformat()
    manifest = {"schema_version": 1, "generated_at": generated_at, "root": "res://assets/visuals/raw_asset/Board", "skins": skins, "objects": objects}
    if args.write:
        MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
        MANIFEST_PATH.write_text(json.dumps(manifest, indent=1, sort_keys=True) + "\n", encoding="utf-8")
        REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
        lines = [f"skins: {len(skins)} of {len(SKINS)}", f"objects: {len(objects)} of {len(OBJECTS)}", ""]
        for skin_id, entry in skins.items():
            lines.append(f"{skin_id:20s} {entry['folder']:20s} variants={entry['floor_variants']} luminance={entry['luminance']:6.1f} light={entry['light']:.3f} dark={entry['dark']:.3f}")
        lines.append("")
        for name, entry in objects.items():
            lines.append(f"{name:22s} frames={entry['frames']} cell={entry['cell'][0]}")
        if problems:
            lines.append("")
            lines.extend(f"problem: {problem}" for problem in problems)
        REPORT_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    mode = "write" if args.write else "dry-run"
    print(f"board skin packager {mode}: skins={len(skins)} objects={len(objects)} problems={len(problems)}")
    for problem in problems:
        print(f"warning: {problem}")
    return 0


def _slot(image: Image.Image, block: int) -> Image.Image:
    x = (block * 6 + CENTER[0]) * TILE
    y = CENTER[1] * TILE
    return image.crop((x, y, x + TILE, y + TILE))


def _blank(tile: Image.Image) -> bool:
    alpha = tile.getchannel("A")
    return alpha.getbbox() is None or max(alpha.getdata()) == 0


def _luminance(tile: Image.Image) -> float:
    rgb = tile.convert("RGB")
    values = list(rgb.getdata())
    return sum(0.299 * r + 0.587 * g + 0.114 * b for r, g, b in values) / max(1, len(values))


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Bake the board floor, wall and decoration sheets from the imported PMDO dungeon tilesets and hub objects.")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--write", action="store_true")
    return parser.parse_args()


if __name__ == "__main__":
    sys.exit(main())
