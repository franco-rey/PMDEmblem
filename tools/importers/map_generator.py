import argparse
import hashlib
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCENE_DIR = os.path.join(ROOT, "assets", "maps", "level", "arena")
DEFINITION_DIR = os.path.join(ROOT, "data", "models", "maps", "definitions")
ARENA_SCRIPT = "res://data/modules/tactics/level/arena/tactics_arena.gd"
DEFINITION_SCRIPT = "res://data/models/maps/resources/map_definition_resource.gd"

TILE_MESH = '''[sub_resource type="ArrayMesh" id="2"]
resource_name = "Cube005"
_surfaces = [{
"aabb": AABB(-0.5, 0, -0.5, 1.00001, 1e-05, 1),
"attribute_data": PackedByteArray("AAAAAAAA4L8AAAAAAADgvwAAAAAAAOA/AAAAAAAAAAA="),
"format": 34359742487,
"index_count": 6,
"index_data": PackedByteArray("AAACAAEAAAADAAIA"),
"primitive": 3,
"uv_scale": Vector4(0, 0, 0, 0),
"vertex_count": 4,
"vertex_data": PackedByteArray("AAAAPwAAAAAAAAC/AAAAvwAAAAAAAAC/AAAAvwAAAAAAAAA/AAAAPwAAAAAAAAA/AAD/f/9//38AAP9//394vAAA/3//f3i8AAD/f/9//38=")
}]
'''

MATERIALS = '''[sub_resource type="StandardMaterial3D" id="light"]
albedo_color = Color(0.87, 0.82, 0.68, 1)
metallic_specular = 0.0
roughness = 0.9

[sub_resource type="StandardMaterial3D" id="dark"]
albedo_color = Color(0.33, 0.45, 0.38, 1)
metallic_specular = 0.0
roughness = 0.9

[sub_resource type="StandardMaterial3D" id="frame"]
albedo_color = Color(0.22, 0.17, 0.12, 1)
metallic_specular = 0.0
roughness = 0.9
'''


def rect_tiles(cols, rows):
    return {(c, r) for c in range(cols) for r in range(rows)}


def ring_tiles(cols, rows, inner, outer):
    tiles = set()
    cx = (cols - 1) / 2.0
    cz = (rows - 1) / 2.0
    for c in range(cols):
        for r in range(rows):
            d = math.hypot(c - cx, r - cz)
            if inner <= d <= outer:
                tiles.add((c, r))
    return tiles


GRIDS_SIZE = 21
GRIDS_HOLES = (4, 12)
GRIDS_HOLE = 5


def grids_tiles():
    size = GRIDS_SIZE
    tiles = rect_tiles(size, size)
    diagonals = set()
    for hole_c in GRIDS_HOLES:
        for hole_r in GRIDS_HOLES:
            for c in range(hole_c, hole_c + GRIDS_HOLE):
                for r in range(hole_r, hole_r + GRIDS_HOLE):
                    tiles.discard((c, r))
            for corner in ((hole_c, hole_r), (hole_c + GRIDS_HOLE - 1, hole_r), (hole_c, hole_r + GRIDS_HOLE - 1), (hole_c + GRIDS_HOLE - 1, hole_r + GRIDS_HOLE - 1)):
                diagonals.add(corner)
    for corner in ((0, 0), (0, size - 1), (size - 1, 0), (size - 1, size - 1)):
        tiles.discard(corner)
        diagonals.add(corner)
    for hole in GRIDS_HOLES:
        for offset in range(GRIDS_HOLE):
            cell = hole + offset
            for spot in ((cell, 0), (cell, size - 1), (0, cell), (size - 1, cell)):
                tiles.discard(spot)
                if offset == 0 or offset == GRIDS_HOLE - 1:
                    diagonals.add(spot)
    return tiles, diagonals


WEDGE_BASES = {
    (-1, -1): "1, 0, 0, 0, 0, -1, 0, 1, 0",
    (-1, 1): "0, 1, 0, 0, 0, -1, -1, 0, 0",
    (1, 1): "-1, 0, 0, 0, 0, -1, 0, -1, 0",
    (1, -1): "0, -1, 0, 0, 0, -1, 1, 0, 0",
}


def wedge_corner(cell, tiles, diagonals=()):
    c, r = cell
    walkable_x = [ox for ox in (-1, 1) if (c + ox, r) in tiles]
    walkable_z = [oz for oz in (-1, 1) if (c, r + oz) in tiles]
    if len(walkable_x) == 1 and len(walkable_z) == 1:
        return (walkable_x[0], walkable_z[0])
    for (sx, sz) in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        if (c + sx, r + sz) not in diagonals:
            continue
        for corner in ((sx, -sz), (-sx, sz)):
            if corner[0] in walkable_x and corner[1] in walkable_z:
                return corner
    return None


def rotate(squares, cols, rows):
    return [(cols - 1 - c, rows - 1 - r) for (c, r) in squares]


def files(rank, *columns):
    return [(c, rank) for c in columns]


def setup_anchors(spec, cols, rows):
    player = list(spec["player"])
    enemy = list(spec.get("enemy", rotate(player, cols, rows)))
    return player, enemy


XIANGQI_SETUP = files(0, 0, 1, 2, 3, 4, 5, 6, 7, 8) + files(2, 1, 7) + files(3, 0, 2, 4, 6, 8)
JANGGI_SETUP = files(0, 0, 1, 2, 3, 5, 6, 7, 8) + files(1, 4) + files(2, 1, 7) + files(3, 0, 2, 4, 6, 8)
SHOGI_SETUP = files(0, 0, 1, 2, 3, 4, 5, 6, 7, 8) + files(1, 1, 7) + files(2, 0, 1, 2, 3, 4, 5, 6, 7, 8)
MAKRUK_SETUP = files(0, 0, 1, 2, 3, 4, 5, 6, 7) + files(2, 0, 1, 2, 3, 4, 5, 6, 7)
SITTUYIN_WHITE = files(0, 2, 4) + files(1, 3, 6, 7) + files(2, 0, 1, 2, 3, 4, 5, 6) + files(3, 4, 5, 6, 7)
SITTUYIN_BLACK = files(4, 0, 1, 2, 3) + files(5, 1, 2, 3, 4, 5, 6, 7) + files(6, 1, 2, 4) + files(7, 3, 5)


def ring_anchors(tiles, cols, rows, count):
    cx = (cols - 1) / 2.0
    ordered = sorted(tiles, key=lambda t: (t[1], abs(t[0] - cx), t[0]))
    player = ordered[:count]
    ordered = sorted(tiles, key=lambda t: (-t[1], abs(t[0] - cx), t[0]))
    enemy = ordered[:count]
    return player, enemy


def grids_anchors(tiles):
    far = GRIDS_SIZE - 4
    player = sorted([t for t in tiles if t[0] <= 3 and t[1] <= 3], key=lambda t: (t[1], t[0]))
    enemy = sorted([t for t in tiles if t[0] >= far and t[1] >= far], key=lambda t: (-t[1], -t[0]))
    return player, enemy


MAPS = {
    "xiangqi": {"name": "Xiangqi", "cols": 9, "rows": 10, "cap": 16, "player": XIANGQI_SETUP, "note": "Chinese chess: nine on the back rank, cannons on the third rank at b and h, soldiers on the fourth rank at a c e g i"},
    "shogi": {"name": "Shogi", "cols": 9, "rows": 9, "cap": 20, "player": SHOGI_SETUP, "note": "Japanese chess: nine on the back rank, bishop and rook on the second rank at b and h, nine pawns on the third rank"},
    "janggi": {"name": "Janggi", "cols": 9, "rows": 10, "cap": 16, "player": JANGGI_SETUP, "note": "Korean chess: eight on the back rank with the centre file empty, the general on the second rank in the palace, cannons at b3 and h3, soldiers at a4 c4 e4 g4 i4"},
    "makruk": {"name": "Makruk", "cols": 8, "rows": 8, "cap": 16, "player": MAKRUK_SETUP, "note": "Thai chess: eight on the back rank, eight pawns on the third rank"},
    "sittuyin": {"name": "Sittuyin", "cols": 8, "rows": 8, "cap": 16, "player": SITTUYIN_WHITE, "enemy": SITTUYIN_BLACK, "note": "Burmese chess: pawns on the a3 to d3 and e4 to h4 diagonal, the eight pieces placed behind them as in the reference diagram"},
    "circular": {"name": "Circular", "cols": 14, "rows": 14, "cap": 16, "kind": "ring", "inner": 2.9, "outer": 7.0, "note": "Circular chess: four rings of sixteen squares, sixteen pieces a side folded into the ring"},
    "grids": {"name": "Grids", "cols": 21, "rows": 21, "cap": 15, "kind": "grids", "note": "Nine rounded squares joined by three-wide bridges around four five-square holes; chamfered corners drawn as wedges nobody can stand on; fifteen a side starting in opposite corners"},
}


def uid_for(map_id):
    digest = hashlib.sha256(map_id.encode("utf-8")).digest()
    value = int.from_bytes(digest[:8], "big") & 0x7FFFFFFFFFFFFFFF
    alphabet = "0123456789abcdefghijklmnopqrstuvwxyz"
    text = ""
    while value > 0:
        value, remainder = divmod(value, 36)
        text = alphabet[remainder] + text
    return "uid://" + text[:13].rjust(13, "0")


def build(map_id, spec):
    cols = spec["cols"]
    rows = spec["rows"]
    kind = spec.get("kind", "rect")
    diagonals = set()
    if kind == "ring":
        tiles = ring_tiles(cols, rows, spec["inner"], spec["outer"])
        player, enemy = ring_anchors(tiles, cols, rows, spec["cap"])
    elif kind == "grids":
        tiles, diagonals = grids_tiles()
        player, enemy = grids_anchors(tiles)
    else:
        tiles = rect_tiles(cols, rows)
        player, enemy = setup_anchors(spec, cols, rows)
    assert len(player) == spec["cap"] and len(enemy) == spec["cap"], (map_id, len(player), len(enemy))
    assert all(t in tiles for t in player + enemy), map_id
    assert len(set(player)) == len(player) and len(set(enemy)) == len(enemy) and not set(player) & set(enemy), map_id
    origin_x = -(cols // 2)
    origin_z = -(rows // 2)

    def world(t):
        return (t[0] + origin_x, t[1] + origin_z)

    ordered = sorted(tiles, key=lambda t: (t[1], t[0]))
    lines = []
    load_steps = 7 + (2 if diagonals else 0)
    lines.append('[gd_scene load_steps=%d format=3 uid="%s"]' % (load_steps, uid_for(map_id)))
    lines.append('[ext_resource type="Script" path="%s" id="1_arena"]' % ARENA_SCRIPT)
    lines.append(TILE_MESH)
    lines.append('[sub_resource type="BoxMesh" id="block"]')
    lines.append('size = Vector3(1, 0.5, 1)')
    lines.append('')
    if diagonals:
        lines.append('[sub_resource type="PrismMesh" id="wedge"]')
        lines.append('left_to_right = 0.0')
        lines.append('size = Vector3(1, 1, 0.5)')
        lines.append('')
        lines.append('[sub_resource type="PrismMesh" id="wedge_under"]')
        lines.append('left_to_right = 0.0')
        lines.append('size = Vector3(1.6, 1.6, 0.3)')
        lines.append('')
    if kind == "rect":
        lines.append('[sub_resource type="BoxMesh" id="slab"]')
        lines.append('size = Vector3(%s, 0.3, %s)' % (fmt(cols + 0.6), fmt(rows + 0.6)))
    else:
        lines.append('[sub_resource type="BoxMesh" id="slab"]')
        lines.append('size = Vector3(1.6, 0.3, 1.6)')
    lines.append('')
    lines.append(MATERIALS)
    lines.append('[node name="Arena" type="Node3D"]')
    lines.append('script = ExtResource("1_arena")')
    lines.append('')
    lines.append('[node name="Sun" type="DirectionalLight3D" parent="."]')
    lines.append('transform = Transform3D(0.707107, 0.5, -0.5, 0, 0.707107, 0.707107, 0.707107, -0.5, 0.5, 0, 4, 0)')
    lines.append('light_indirect_energy = 0.0')
    lines.append('light_volumetric_fog_energy = 0.0')
    lines.append('directional_shadow_mode = 0')
    lines.append('')
    lines.append('[node name="Tiles" type="Node3D" parent="."]')
    lines.append('visible = false')
    lines.append('')
    for index, t in enumerate(ordered):
        x, z = world(t)
        name = "Tile" if index == 0 else "Tile%03d" % index
        lines.append('[node name="%s" type="MeshInstance3D" parent="Tiles"]' % name)
        lines.append('transform = Transform3D(1.01, 0, 0, 0, 1.01, 0, 0, 0, 1.01, %s, 0.5, %s)' % (fmt(x), fmt(z)))
        lines.append('mesh = SubResource("2")')
        lines.append('')
    lines.append('[node name="Terrain" type="Node3D" parent="."]')
    lines.append('')
    if kind == "rect":
        centre_x = (origin_x + origin_x + cols - 1) / 2.0
        centre_z = (origin_z + origin_z + rows - 1) / 2.0
        lines.append('[node name="Slab" type="MeshInstance3D" parent="Terrain"]')
        lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, -0.16, %s)' % (fmt(centre_x), fmt(centre_z)))
        lines.append('mesh = SubResource("slab")')
        lines.append('surface_material_override/0 = SubResource("frame")')
        lines.append('')
    for index, t in enumerate(ordered):
        x, z = world(t)
        shade = "dark" if (x + z) % 2 == 0 else "light"
        lines.append('[node name="Square_%d_%d" type="MeshInstance3D" parent="Terrain"]' % (t[0], t[1]))
        lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, 0.24, %s)' % (fmt(x), fmt(z)))
        lines.append('mesh = SubResource("block")')
        lines.append('surface_material_override/0 = SubResource("%s")' % shade)
        lines.append('')
        if kind != "rect":
            lines.append('[node name="Under_%d_%d" type="MeshInstance3D" parent="Terrain"]' % (t[0], t[1]))
            lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)' % (fmt(x), fmt(-0.16 - 0.00005 * index), fmt(z)))
            lines.append('mesh = SubResource("slab")')
            lines.append('surface_material_override/0 = SubResource("frame")')
            lines.append('')
    for cell in sorted(diagonals, key=lambda t: (t[1], t[0])):
        corner = wedge_corner(cell, tiles, diagonals)
        if corner is None:
            continue
        x, z = world(cell)
        shade = "dark" if (x + z) % 2 == 0 else "light"
        basis = WEDGE_BASES[corner]
        lines.append('[node name="Wedge_%d_%d" type="MeshInstance3D" parent="Terrain"]' % (cell[0], cell[1]))
        lines.append('transform = Transform3D(%s, %s, 0.24, %s)' % (basis, fmt(x), fmt(z)))
        lines.append('mesh = SubResource("wedge")')
        lines.append('surface_material_override/0 = SubResource("%s")' % shade)
        lines.append('')
        lines.append('[node name="WedgeUnder_%d_%d" type="MeshInstance3D" parent="Terrain"]' % (cell[0], cell[1]))
        lines.append('transform = Transform3D(%s, %s, %s, %s)' % (basis, fmt(x), fmt(-0.16 - 0.00005 * (len(ordered) + cell[0] + cell[1] * cols)), fmt(z)))
        lines.append('mesh = SubResource("wedge_under")')
        lines.append('surface_material_override/0 = SubResource("frame")')
        lines.append('')
    lines.append('[node name="SpawnPoints" type="Node3D" parent="."]')
    lines.append('')
    for prefix, anchors in (("SpawnPlayer", player), ("SpawnEnemy", enemy)):
        for index, t in enumerate(anchors):
            x, z = world(t)
            name = prefix if index == 0 else "%s%d" % (prefix, index + 1)
            lines.append('[node name="%s" type="Node3D" parent="SpawnPoints"]' % name)
            lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, 0.55, %s)' % (fmt(x), fmt(z)))
            lines.append('')
    scene = "\n".join(lines).rstrip("\n") + "\n"
    definition = "\n".join([
        '[gd_resource type="Resource" script_class="MapDefinitionResource" load_steps=2 format=3]',
        '',
        '[ext_resource type="Script" path="%s" id="1_map"]' % DEFINITION_SCRIPT,
        '',
        '[resource]',
        'script = ExtResource("1_map")',
        'map_id = "%s"' % map_id,
        'display_name = "%s"' % spec["name"],
        'scene_path = "res://assets/maps/level/arena/%s.tscn"' % map_id,
        'biome = "board"',
        'recommended_team_size = %d' % spec["cap"],
        'recommended_elevation = "flat"',
        'max_team_size = %d' % spec["cap"],
        'default_seed = 0',
        '',
    ])
    return scene, definition, len(tiles), len(player), len(enemy)


def fmt(value):
    if float(value).is_integer():
        return str(int(value))
    return ("%.5f" % value).rstrip("0").rstrip(".")


def main():
    parser = argparse.ArgumentParser(description="Generate chessboard-styled arena scenes and map definitions for the chess-variant boards")
    parser.add_argument("--write", action="store_true", help="write the scenes and definitions (default prints a summary)")
    parser.add_argument("--only", default="", help="comma separated map ids")
    args = parser.parse_args()
    wanted = [m for m in args.only.split(",") if m] or list(MAPS.keys())
    for map_id in wanted:
        spec = MAPS[map_id]
        scene, definition, tiles, player, enemy = build(map_id, spec)
        print("%-9s %2dx%-2d tiles=%-3d cap=%-2d anchors=%d/%d  %s" % (map_id, spec["cols"], spec["rows"], tiles, spec["cap"], player, enemy, spec["note"]))
        if args.write:
            with open(os.path.join(SCENE_DIR, "%s.tscn" % map_id), "w", encoding="utf-8") as handle:
                handle.write(scene)
            with open(os.path.join(DEFINITION_DIR, "%s.tres" % map_id), "w", encoding="utf-8") as handle:
                handle.write(definition)
    return 0


if __name__ == "__main__":
    sys.exit(main())
