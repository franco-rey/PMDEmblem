#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCENE_PATH = ROOT / "assets" / "maps" / "level" / "arena" / "chessboard.tscn"
DEFINITION_PATH = ROOT / "data" / "models" / "maps" / "definitions" / "chessboard.tres"
QUAD_PATH = Path(__file__).resolve().parent / "tile_quad.tres.txt"
ARENA_SCRIPT = "res://data/modules/tactics/level/arena/tactics_arena.gd"
MAP_SCRIPT = "res://data/models/maps/resources/map_definition_resource.gd"
SCENE_UID = "uid://c72yeeqi2kjrg"
SIZE = 8
ORIGIN = -4
SURFACE_Y = 0.5
ANCHOR_Y = SURFACE_Y + 0.05
BLOCK_HEIGHT = 0.5
BLOCK_TOP_GAP = 0.01
LIGHT = "Color(0.87, 0.82, 0.68, 1)"
DARK = "Color(0.33, 0.45, 0.38, 1)"
FRAME = "Color(0.22, 0.17, 0.12, 1)"


def is_light(x: int, z: int) -> bool:
    return (x + z) % 2 == 1


def coords() -> range:
    return range(ORIGIN, ORIGIN + SIZE)


def spawn_squares(rows: list[int], light: bool) -> list[tuple[int, int]]:
    squares = []
    for z in rows:
        for x in coords():
            if is_light(x, z) == light:
                squares.append((x, z))
    return squares


def material(name: str, color: str) -> str:
    return f'[sub_resource type="StandardMaterial3D" id="{name}"]\nalbedo_color = {color}\nmetallic_specular = 0.0\nroughness = 0.9\n\n'


def build_scene() -> str:
    quad = QUAD_PATH.read_text().rstrip("\n")
    out = [f'[gd_scene load_steps=7 format=3 uid="{SCENE_UID}"]\n', f'[ext_resource type="Script" path="{ARENA_SCRIPT}" id="1_arena"]\n', quad + "\n"]
    out.append(f'[sub_resource type="BoxMesh" id="block"]\nsize = Vector3(1, {BLOCK_HEIGHT}, 1)\n\n')
    out.append(f'[sub_resource type="BoxMesh" id="slab"]\nsize = Vector3({SIZE + 0.6}, 0.3, {SIZE + 0.6})\n\n')
    out.append(material("light", LIGHT))
    out.append(material("dark", DARK))
    out.append(material("frame", FRAME))
    out.append('[node name="Arena" type="Node3D"]\nscript = ExtResource("1_arena")\n\n')
    out.append('[node name="Sun" type="DirectionalLight3D" parent="."]\ntransform = Transform3D(0.707107, 0.5, -0.5, 0, 0.707107, 0.707107, 0.707107, -0.5, 0.5, 0, 4, 0)\nlight_indirect_energy = 0.0\nlight_volumetric_fog_energy = 0.0\ndirectional_shadow_mode = 0\n\n')
    out.append('[node name="Tiles" type="Node3D" parent="."]\nvisible = false\n\n')
    index = 0
    for z in coords():
        for x in coords():
            name = "Tile" if index == 0 else f"Tile{index:03d}"
            out.append(f'[node name="{name}" type="MeshInstance3D" parent="Tiles"]\ntransform = Transform3D(1.01, 0, 0, 0, 1.01, 0, 0, 0, 1.01, {x}, {SURFACE_Y}, {z})\nmesh = SubResource("2")\n\n')
            index += 1
    out.append('[node name="Terrain" type="Node3D" parent="."]\n\n')
    center = ORIGIN + (SIZE - 1) / 2.0
    out.append(f'[node name="Slab" type="MeshInstance3D" parent="Terrain"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {center}, {SURFACE_Y - BLOCK_TOP_GAP - BLOCK_HEIGHT - 0.15}, {center})\nmesh = SubResource("slab")\nsurface_material_override/0 = SubResource("frame")\n\n')
    for z in coords():
        for x in coords():
            shade = "light" if is_light(x, z) else "dark"
            out.append(f'[node name="Square_{x - ORIGIN}_{z - ORIGIN}" type="MeshInstance3D" parent="Terrain"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {SURFACE_Y - BLOCK_TOP_GAP - BLOCK_HEIGHT / 2.0}, {z})\nmesh = SubResource("block")\nsurface_material_override/0 = SubResource("{shade}")\n\n')
    out.append('[node name="SpawnPoints" type="Node3D" parent="."]\n\n')
    player_rows = [ORIGIN + 1, ORIGIN]
    enemy_rows = [ORIGIN + SIZE - 2, ORIGIN + SIZE - 1]
    player = spawn_squares(player_rows, True) + spawn_squares(player_rows, False)
    enemy = spawn_squares(enemy_rows, False) + spawn_squares(enemy_rows, True)
    for i, (x, z) in enumerate(player):
        name = "SpawnPlayer" if i == 0 else f"SpawnPlayer{i + 1}"
        out.append(f'[node name="{name}" type="Node3D" parent="SpawnPoints"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {ANCHOR_Y}, {z})\n\n')
    for i, (x, z) in enumerate(enemy):
        name = "SpawnEnemy" if i == 0 else f"SpawnEnemy{i + 1}"
        out.append(f'[node name="{name}" type="Node3D" parent="SpawnPoints"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {ANCHOR_Y}, {z})\n\n')
    return "".join(out)


def build_definition() -> str:
    return (
        '[gd_resource type="Resource" script_class="MapDefinitionResource" load_steps=2 format=3]\n\n'
        f'[ext_resource type="Script" path="{MAP_SCRIPT}" id="1_map"]\n\n'
        '[resource]\nscript = ExtResource("1_map")\nmap_id = "chessboard"\ndisplay_name = "Chessboard"\n'
        'scene_path = "res://assets/maps/level/arena/chessboard.tscn"\nbiome = "board"\nrecommended_team_size = 8\n'
        'recommended_elevation = "flat"\nmax_team_size = 16\ndefault_seed = 0\n'
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate the 8x8 chessboard arena scene and its map definition.")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    scene = build_scene()
    definition = build_definition()
    if args.dry_run:
        print(f"scene {len(scene)} bytes, definition {len(definition)} bytes")
        return 0
    SCENE_PATH.write_text(scene)
    DEFINITION_PATH.write_text(definition)
    print(f"wrote {SCENE_PATH.relative_to(ROOT)} and {DEFINITION_PATH.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
