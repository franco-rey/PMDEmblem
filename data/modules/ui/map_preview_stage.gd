class_name MapPreviewStage
extends ShowcaseStage

const SPAWN_PLAYER_PREFIX: String = "SpawnPlayer"
const SPAWN_ENEMY_PREFIX: String = "SpawnEnemy"
const EXTENT_TO_ORTHO: float = 0.032
const EXTENT_TO_RADIUS: float = 1.6

var map_path: String = ""
var player_tiles: int = 0
var enemy_tiles: int = 0
var _arena: Node3D = null


func show_map(path: String) -> void:
	if _arena != null and is_instance_valid(_arena):
		_arena.queue_free()
		_arena = null
	map_path = path
	player_tiles = 0
	enemy_tiles = 0
	var definition: MapDefinitionResource = load(path) as MapDefinitionResource
	if definition == null or definition.scene_path.is_empty():
		return
	var scene: PackedScene = load(definition.scene_path) as PackedScene
	if scene == null:
		return
	var arena: Node3D = scene.instantiate() as Node3D
	if arena == null:
		return
	arena.set_script(null)
	arena.name = "PreviewArena"
	var sun: Node = arena.get_node_or_null("Sun")
	if sun != null:
		arena.remove_child(sun)
		sun.queue_free()
	_stage.add_child(arena)
	_arena = arena
	_paint_spawns(arena)
	_frame_arena(arena)
	_orbit = 1
	set_zoom(DEFAULT_ZOOM)


func _paint_spawns(arena: Node3D) -> void:
	var tiles: Node3D = arena.get_node_or_null("Tiles") as Node3D
	var spawns: Node = arena.get_node_or_null("SpawnPoints")
	if tiles == null or spawns == null:
		return
	var by_cell: Dictionary = {}
	for child in tiles.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
			by_cell[_cell_key((child as Node3D).position)] = child
	for marker in spawns.get_children():
		if not (marker is Node3D):
			continue
		var is_player: bool = marker.name.begins_with(SPAWN_PLAYER_PREFIX)
		var is_enemy: bool = marker.name.begins_with(SPAWN_ENEMY_PREFIX)
		if not is_player and not is_enemy:
			continue
		var tile: MeshInstance3D = by_cell.get(_cell_key((marker as Node3D).position), null) as MeshInstance3D
		if tile == null:
			continue
		tile.visible = true
		tile.material_override = TacticsConfig.mat_color.reachable if is_player else TacticsConfig.mat_color.attackable
		if is_player:
			player_tiles += 1
		else:
			enemy_tiles += 1
	tiles.visible = true


func _cell_key(position: Vector3) -> Vector2i:
	return Vector2i(int(round(position.x)), int(round(position.z)))


func _frame_arena(arena: Node3D) -> void:
	var bounds: AABB = AABB()
	var seen: bool = false
	for mesh in arena.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = mesh
		if instance.get_parent() != null and instance.get_parent().name == "Tiles":
			continue
		if instance.mesh == null:
			continue
		var box: AABB = instance.transform * instance.mesh.get_aabb()
		var parent: Node = instance.get_parent()
		while parent != null and parent != arena and parent is Node3D:
			box = (parent as Node3D).transform * box
			parent = parent.get_parent()
		bounds = box if not seen else bounds.merge(box)
		seen = true
	if not seen:
		_focus = Vector3(0.0, 0.05, 0.0)
		_radius = 3.4
		_ortho_per_fov = ORTHO_PER_FOV
		return
	var centre: Vector3 = bounds.get_center()
	var extent: float = maxf(bounds.size.x, bounds.size.z)
	_focus = Vector3(centre.x, bounds.position.y + bounds.size.y, centre.z)
	_radius = maxf(3.4, extent * EXTENT_TO_RADIUS)
	_ortho_per_fov = maxf(ORTHO_PER_FOV, extent * EXTENT_TO_ORTHO)
