class_name BoardSkin
extends RefCounted

const ROOT: String = "res://assets/visuals/raw_asset/Board/"
const MANIFEST_PATH: String = "res://data/models/visuals/generated/board_skin_manifest.json"
const DEFAULT: String = "default"
const FRAME_DUNGEON: String = "dungeon"
const DECOR_OFF: String = "off"
const SURROUND_NAME: String = "BoardSurround"
const DECOR_NAME: String = "BoardDecor"
const ORIGINAL_META: StringName = &"board_original"
const SLAB_HEIGHT: float = 0.3
const GROUND_TOP: float = -0.31
const SURROUND_MARGIN: float = 4.0
const PROP_PIXEL: float = 0.04
const SKINS: Array[Dictionary] = [
	{"id": "amp_plains", "label": "Amp Plains"}, {"id": "mt_horn", "label": "Mt. Horn"}, {"id": "barren_valley", "label": "Barren Valley"}, {"id": "limestone_cavern", "label": "Limestone Cavern"}, {"id": "side_path", "label": "Side Path"},
	{"id": "tiny_woods", "label": "Tiny Woods"}, {"id": "treeshroud_forest", "label": "Treeshroud Forest"}, {"id": "grass_maze", "label": "Grass Maze"}, {"id": "lush_prairie", "label": "Lush Prairie"}, {"id": "apple_woods", "label": "Apple Woods"},
	{"id": "northern_desert", "label": "Northern Desert"}, {"id": "howling_forest", "label": "Howling Forest"},
	{"id": "steam_cave", "label": "Steam Cave"}, {"id": "meteor_cave", "label": "Meteor Cave"}, {"id": "magma_cavern", "label": "Magma Cavern"},
	{"id": "ice_maze", "label": "Ice Maze"}, {"id": "snow_path", "label": "Snow Path"},
	{"id": "crystal_cave", "label": "Crystal Cave"}, {"id": "poison_maze", "label": "Poison Maze"}, {"id": "dark_wasteland", "label": "Dark Wasteland"},
	{"id": "temporal_tower", "label": "Temporal Tower"}, {"id": "joyous_tower", "label": "Joyous Tower"}, {"id": "northwind_field", "label": "Northwind Field"}, {"id": "wish_cave", "label": "Wish Cave"},
]
const FRAME_LABELS: Dictionary = {"default": "Default", "dungeon": "Dungeon walls"}
const DECOR_LABELS: Dictionary = {"off": "Off", "camp": "Camp", "garden": "Garden", "ruins": "Ruins"}
const DECOR_SETS: Dictionary = {
	"camp": [["Tent", "nw", 1.0], ["Tent_Plain", "ne", 1.0], ["Campfire", "n", 1.0], ["Logs_Stacked", "n2", 1.0], ["Storage", "e", 1.0], ["Sign", "w", 1.0], ["Berry_Basket_Red", "s", 1.0], ["Pot", "s2", 1.0]],
	"garden": [["Tree_Town", "nw", 1.0], ["Tree_Town", "se", 1.0], ["Hedge", "n", 1.0], ["Fence", "s", 1.0], ["Flowers_Town_1", "w", 1.0], ["Flowers_Town_2", "e", 1.0], ["Flowerpot_Pink", "n2", 1.0], ["Stump_Table", "sw", 1.0]],
	"ruins": [["Trunk_Large", "nw", 1.0], ["Trunk_Small", "se", 1.0], ["Logs_Large", "sw", 1.0], ["Chest", "e", 1.0], ["Stairs_Down", "n", 1.0], ["Portal_Small", "s", 1.0], ["Sign_Crossroads", "w", 1.0], ["Mission_Board", "ne", 1.0]],
}

static var _manifest: Dictionary = {}
static var _manifest_loaded: bool = false
static var _textures: Dictionary = {}
static var _materials: Dictionary = {}
static var _arenas: Array[WeakRef] = []


static func manifest() -> Dictionary:
	if not _manifest_loaded:
		_manifest_loaded = true
		if FileAccess.file_exists(MANIFEST_PATH):
			var text: String = FileAccess.get_file_as_string(MANIFEST_PATH)
			var parsed: Variant = JSON.parse_string(text)
			if parsed is Dictionary:
				_manifest = parsed
	return _manifest


static func available() -> bool:
	return ResourceLoader.exists(ROOT + "amp_plains/floor_0.png")


static func skin_ids() -> Array[String]:
	var out: Array[String] = []
	for entry in SKINS:
		out.append(String(entry["id"]))
	return out


static func floor_options() -> Array[String]:
	var out: Array[String] = [DEFAULT]
	out.append_array(skin_ids())
	return out


static func frame_options() -> Array[String]:
	var out: Array[String] = []
	for key in FRAME_LABELS.keys():
		out.append(String(key))
	return out


static func decor_options() -> Array[String]:
	var out: Array[String] = []
	for key in DECOR_LABELS.keys():
		out.append(String(key))
	return out


static func is_floor(id: String) -> bool:
	return floor_options().has(id)


static func is_frame(id: String) -> bool:
	return FRAME_LABELS.has(id)


static func is_decor(id: String) -> bool:
	return DECOR_LABELS.has(id)


static func floor_label(id: String) -> String:
	if id == DEFAULT:
		return "Default"
	for entry in SKINS:
		if String(entry["id"]) == id:
			return String(entry["label"])
	return id.capitalize()


static func frame_label(id: String) -> String:
	return String(FRAME_LABELS.get(id, id.capitalize()))


static func decor_label(id: String) -> String:
	return String(DECOR_LABELS.get(id, id.capitalize()))


static func skin_entry(id: String) -> Dictionary:
	var skins: Dictionary = manifest().get("skins", {})
	return skins.get(id, {})


static func has_skin(id: String) -> bool:
	return id != DEFAULT and is_floor(id) and ResourceLoader.exists("%s%s/floor_0.png" % [ROOT, id])


static func floor_variants(id: String) -> int:
	return maxi(1, int(skin_entry(id).get("floor_variants", 1)))


static func tint(id: String, dark: bool) -> Color:
	var entry: Dictionary = skin_entry(id)
	var factor: float = float(entry.get("dark", 0.72)) if dark else float(entry.get("light", 1.08))
	return Color(factor, factor, factor, 1.0)


static func texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	if not ResourceLoader.exists(path):
		return null
	var loaded: Texture2D = load(path) as Texture2D
	if loaded != null:
		_textures[path] = loaded
	return loaded


static func floor_texture(id: String, variant: int = 0) -> Texture2D:
	return texture("%s%s/floor_%d.png" % [ROOT, id, posmod(variant, floor_variants(id))])


static func wall_texture(id: String) -> Texture2D:
	return texture("%s%s/wall.png" % [ROOT, id])


static func object_texture(name: String) -> Texture2D:
	return texture("%sobjects/%s.png" % [ROOT, name])


static func floor_material(id: String, dark: bool, variant: int = 0) -> StandardMaterial3D:
	var key: String = "floor:%s:%s:%d" % [id, "dark" if dark else "light", posmod(variant, floor_variants(id))]
	if _materials.has(key):
		return _materials[key]
	var material: StandardMaterial3D = _material(floor_texture(id, variant), tint(id, dark), 1.0, Vector3(0.5, 0.0, 0.5))
	_materials[key] = material
	return material


static func wall_material(id: String, repeats_per_unit: float = 1.0, shade: float = 1.0) -> StandardMaterial3D:
	var key: String = "wall:%s:%.3f:%.2f" % [id, repeats_per_unit, shade]
	if _materials.has(key):
		return _materials[key]
	var material: StandardMaterial3D = _material(wall_texture(id), Color(shade, shade, shade, 1.0), repeats_per_unit, Vector3(0.5, 0.0, 0.5))
	_materials[key] = material
	return material


static func ground_material(id: String) -> StandardMaterial3D:
	var key: String = "ground:%s" % id
	if _materials.has(key):
		return _materials[key]
	var base: Color = tint(id, true)
	var material: StandardMaterial3D = _material(floor_texture(id, 0), Color(base.r * 0.8, base.g * 0.8, base.b * 0.8, 1.0), 1.0, Vector3(0.5, 0.0, 0.5))
	_materials[key] = material
	return material


static func _material(albedo: Texture2D, color: Color, repeats_per_unit: float, offset: Vector3) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = albedo
	material.albedo_color = color
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 1.0
	material.metallic = 0.0
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(repeats_per_unit, repeats_per_unit, repeats_per_unit)
	material.uv1_offset = offset
	return material


static func apply(arena: Node3D) -> void:
	if arena == null:
		return
	var known: bool = false
	for ref in _arenas:
		if ref.get_ref() == arena:
			known = true
			break
	if not known:
		_arenas.append(weakref(arena))
	_apply_to(arena, GameSettings.board_floor, GameSettings.board_frame, GameSettings.board_decor)


static func refresh_all() -> void:
	var keep: Array[WeakRef] = []
	for ref in _arenas:
		var arena: Node3D = ref.get_ref() as Node3D
		if arena != null and is_instance_valid(arena) and arena.is_inside_tree():
			keep.append(ref)
			_apply_to(arena, GameSettings.board_floor, GameSettings.board_frame, GameSettings.board_decor)
	_arenas = keep


static func _apply_to(arena: Node3D, floor_id: String, frame_id: String, decor_id: String) -> void:
	var terrain: Node3D = arena.get_node_or_null("Terrain") as Node3D
	if terrain == null:
		return
	var skin: String = floor_id if has_skin(floor_id) else DEFAULT
	var frame_skin: String = skin if frame_id == FRAME_DUNGEON and skin != DEFAULT else DEFAULT
	var bounds: Rect2 = _bounds(terrain)
	for child in terrain.get_children():
		if not (child is MeshInstance3D):
			continue
		var mesh: MeshInstance3D = child
		var name: String = String(mesh.name)
		if name.begins_with("Square_") or name.begins_with("Wedge_"):
			if not mesh.has_meta(ORIGINAL_META):
				mesh.set_meta(ORIGINAL_META, mesh.get_surface_override_material(0))
			if skin == DEFAULT:
				mesh.set_surface_override_material(0, mesh.get_meta(ORIGINAL_META))
			else:
				var x: int = roundi(mesh.transform.origin.x)
				var z: int = roundi(mesh.transform.origin.z)
				mesh.set_surface_override_material(0, floor_material(skin, posmod(x + z, 2) == 0, posmod(x * 7 + z * 13, floor_variants(skin))))
		elif name == "Slab" or name.begins_with("Under_") or name.begins_with("WedgeUnder_"):
			if not mesh.has_meta(ORIGINAL_META):
				mesh.set_meta(ORIGINAL_META, mesh.get_surface_override_material(0))
			if frame_skin == DEFAULT:
				mesh.set_surface_override_material(0, mesh.get_meta(ORIGINAL_META))
			else:
				mesh.set_surface_override_material(0, wall_material(frame_skin, 1.0 / SLAB_HEIGHT, 0.9))
	var surround: Node3D = terrain.get_node_or_null(SURROUND_NAME) as Node3D
	if surround != null:
		terrain.remove_child(surround)
		surround.queue_free()
	if frame_skin != DEFAULT:
		terrain.add_child(_build_surround(frame_skin, bounds))
	var decor: Node3D = terrain.get_node_or_null(DECOR_NAME) as Node3D
	if decor != null:
		terrain.remove_child(decor)
		decor.queue_free()
	if decor_id != DECOR_OFF and DECOR_SETS.has(decor_id) and available():
		terrain.add_child(_build_decor(decor_id, bounds))


static func _bounds(terrain: Node3D) -> Rect2:
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	for child in terrain.get_children():
		if child is MeshInstance3D and String(child.name).begins_with("Square_"):
			var origin: Vector3 = (child as MeshInstance3D).transform.origin
			min_x = minf(min_x, origin.x)
			max_x = maxf(max_x, origin.x)
			min_z = minf(min_z, origin.z)
			max_z = maxf(max_z, origin.z)
	if min_x == INF:
		return Rect2(-4.0, -4.0, 8.0, 8.0)
	return Rect2(min_x - 0.5, min_z - 0.5, max_x - min_x + 1.0, max_z - min_z + 1.0)


static func _build_surround(skin: String, bounds: Rect2) -> Node3D:
	var root := Node3D.new()
	root.name = SURROUND_NAME
	var centre: Vector2 = bounds.get_center()
	var width: float = bounds.size.x + SURROUND_MARGIN * 2.0
	var depth: float = bounds.size.y + SURROUND_MARGIN * 2.0
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(width, 0.2, depth)
	ground.mesh = ground_mesh
	ground.position = Vector3(centre.x, GROUND_TOP - 0.1, centre.y)
	ground.set_surface_override_material(0, ground_material(skin))
	root.add_child(ground)
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(1.0, 1.0, 1.0)
	var material: StandardMaterial3D = wall_material(skin, 1.0, 1.0)
	var half_w: float = width * 0.5
	var half_d: float = depth * 0.5
	var index: int = 0
	var x: float = centre.x - half_w + 0.5
	while x <= centre.x + half_w - 0.5 + 0.001:
		for z in [centre.y - half_d + 0.5, centre.y + half_d - 0.5]:
			root.add_child(_wall_block(wall_mesh, material, Vector3(x, GROUND_TOP + 0.5, z), index))
			index += 1
		x += 1.0
	var z: float = centre.y - half_d + 1.5
	while z <= centre.y + half_d - 1.5 + 0.001:
		for wx in [centre.x - half_w + 0.5, centre.x + half_w - 0.5]:
			root.add_child(_wall_block(wall_mesh, material, Vector3(wx, GROUND_TOP + 0.5, z), index))
			index += 1
		z += 1.0
	return root


static func _wall_block(mesh: BoxMesh, material: StandardMaterial3D, position: Vector3, index: int) -> MeshInstance3D:
	var block := MeshInstance3D.new()
	block.name = "Wall%03d" % index
	block.mesh = mesh
	block.position = position
	block.set_surface_override_material(0, material)
	return block


static func _build_decor(set_id: String, bounds: Rect2) -> Node3D:
	var root := Node3D.new()
	root.name = DECOR_NAME
	var objects: Dictionary = manifest().get("objects", {})
	var slots: Dictionary = _slots(bounds)
	for item in DECOR_SETS[set_id]:
		var name: String = String(item[0])
		var slot: String = String(item[1])
		var entry: Dictionary = objects.get(name, {})
		var sheet: Texture2D = object_texture(name)
		if sheet == null or not slots.has(slot):
			continue
		var frames: int = maxi(1, int(entry.get("frames", 1)))
		var cell: Array = entry.get("cell", [sheet.get_height(), sheet.get_height()])
		var prop := BoardProp.new()
		prop.setup(sheet, frames, int(cell[1]), PROP_PIXEL * float(item[2]))
		var at: Vector2 = slots[slot]
		prop.position = Vector3(at.x, GROUND_TOP + prop.half_height(), at.y)
		prop.name = "%s_%s" % [name, slot]
		root.add_child(prop)
	return root


static func _slots(bounds: Rect2) -> Dictionary:
	var c: Vector2 = bounds.get_center()
	var hx: float = bounds.size.x * 0.5
	var hz: float = bounds.size.y * 0.5
	var gap: float = 2.0
	return {
		"nw": Vector2(c.x - hx - gap, c.y - hz - gap),
		"ne": Vector2(c.x + hx + gap, c.y - hz - gap),
		"sw": Vector2(c.x - hx - gap, c.y + hz + gap),
		"se": Vector2(c.x + hx + gap, c.y + hz + gap),
		"n": Vector2(c.x - 1.0, c.y - hz - gap - 0.5),
		"n2": Vector2(c.x + 1.5, c.y - hz - gap - 0.5),
		"s": Vector2(c.x + 1.0, c.y + hz + gap + 0.5),
		"s2": Vector2(c.x - 1.5, c.y + hz + gap + 0.5),
		"w": Vector2(c.x - hx - gap - 0.5, c.y),
		"e": Vector2(c.x + hx + gap + 0.5, c.y),
	}
