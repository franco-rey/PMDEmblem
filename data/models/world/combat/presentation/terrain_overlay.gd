class_name TerrainOverlay
extends Node3D

const FLOOR_CULL_MASK: int = 1
const DEPTH: float = 24.0
const FADE_SECONDS: float = 0.5
const TINTS: Dictionary = {
	"grassy_terrain": Color(0.30, 0.95, 0.35, 0.42),
	"electric_terrain": Color(1.00, 0.88, 0.25, 0.42),
	"misty_terrain": Color(1.00, 0.62, 0.92, 0.42),
	"psychic_terrain": Color(0.66, 0.40, 1.00, 0.42),
}

var level: TacticsLevel = null
var current_terrain: String = ""
var _decal: Decal = null
var _tween: Tween = null


func setup(battle_level: TacticsLevel) -> void:
	name = "TerrainOverlay"
	level = battle_level
	if level != null and level.battle_log != null and not level.battle_log.event_appended.is_connected(_on_event):
		level.battle_log.event_appended.connect(_on_event)


func show_terrain(terrain_id: String) -> void:
	if not TINTS.has(terrain_id):
		hide_terrain()
		return
	current_terrain = terrain_id
	_ensure_decal()
	var tint: Color = TINTS[terrain_id]
	_decal.visible = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_decal.modulate = Color(tint.r, tint.g, tint.b, 0.0)
	_tween = create_tween()
	_tween.tween_property(_decal, "modulate", tint, FADE_SECONDS)


func hide_terrain() -> void:
	current_terrain = ""
	if _decal == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_decal, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(func() -> void: _decal.visible = false)


func _ensure_decal() -> void:
	if _decal != null:
		return
	_decal = Decal.new()
	_decal.name = "TerrainDecal"
	_decal.cull_mask = FLOOR_CULL_MASK
	_decal.albedo_mix = 1.0
	_decal.upper_fade = 0.0
	_decal.lower_fade = 0.0
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_decal.texture_albedo = ImageTexture.create_from_image(image)
	var bounds: Array = _arena_bounds()
	_decal.size = Vector3(float(bounds[1].x - bounds[0].x) + 1.0, DEPTH, float(bounds[1].z - bounds[0].z) + 1.0)
	add_child(_decal)
	_decal.global_position = Vector3((bounds[0].x + bounds[1].x) * 0.5, bounds[2], (bounds[0].z + bounds[1].z) * 0.5)


func _arena_bounds() -> Array:
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	var height_sum: float = 0.0
	var count: int = 0
	if level != null and level.arena != null:
		for tile in level.arena.get_node("Tiles").get_children():
			var pos: Vector3 = (tile as Node3D).global_position
			low = Vector3(minf(low.x, pos.x), minf(low.y, pos.y), minf(low.z, pos.z))
			high = Vector3(maxf(high.x, pos.x), maxf(high.y, pos.y), maxf(high.z, pos.z))
			height_sum += pos.y
			count += 1
	if count == 0:
		return [Vector3.ZERO, Vector3.ZERO, 0.0]
	return [low, high, height_sum / float(count)]


func _on_event(event: Dictionary) -> void:
	var kind: String = String(event.get("kind", ""))
	var condition: String = String(event.get("condition_id", ""))
	if kind == "field_condition_applied" and TINTS.has(condition):
		show_terrain(condition)
	elif kind == "field_condition_ended" and condition == current_terrain:
		hide_terrain()
