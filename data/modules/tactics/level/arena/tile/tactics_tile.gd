class_name TacticsTile
extends StaticBody3D

var tile_raycast: Resource = load("res://data/modules/tactics/level/arena/tile/raycast/tile_raycasting.tscn")

var reachable: bool = false
var attackable: bool = false
var hover: bool = false
var path: bool = false
var committed: bool = false
var danger: bool = false

var pf_root: TacticsTile
var pf_distance: float

var hover_mat: StandardMaterial3D = TacticsConfig.mat_color.hover
var reachable_mat: StandardMaterial3D = TacticsConfig.mat_color.reachable
var hover_reachable_mat: StandardMaterial3D = TacticsConfig.mat_color.reachable_hover
var attackable_mat: StandardMaterial3D = TacticsConfig.mat_color.attackable
var hover_attackable_mat: StandardMaterial3D = TacticsConfig.mat_color.hover_attackable
var path_mat: StandardMaterial3D = TacticsConfig.mat_color.path
var committed_mat: StandardMaterial3D = TacticsConfig.mat_color.committed
var danger_mat: StandardMaterial3D = TacticsConfig.mat_color.danger

func _process(_delta: float) -> void:
	var tile: MeshInstance3D = get_node_or_null("Tile") as MeshInstance3D
	if not tile:
		return

	tile.visible = attackable or reachable or hover or path or committed or danger

	if committed:
		tile.material_override = committed_mat
		return
	match hover:
		true:
			if reachable:
				tile.material_override = hover_reachable_mat
			elif attackable:
				tile.material_override = hover_attackable_mat
			else:
				tile.material_override = hover_mat
		false:
			if path:
				tile.material_override = path_mat
			elif reachable:
				tile.material_override = reachable_mat
			elif attackable:
				tile.material_override = attackable_mat
			elif danger:
				tile.material_override = danger_mat

func get_neighbors(height: float) -> Array:
	return $RayCasting.get_all_neighbors(height)


func get_tile_occupier() -> Object:
	var above: Object = $RayCasting.get_object_above()
	if above is TacticsPawn and not (above as TacticsPawn).is_alive():
		return null
	return above


func is_taken() -> bool:
	return get_tile_occupier() != null


func reset_markers() -> void:
	pf_root = null
	pf_distance = 0
	reachable = false
	attackable = false
	hover = false
	path = false
	committed = false


func configure_tile() -> void:
	hover = false
	var instance: Node = tile_raycast.instantiate()
	add_child(instance)
	reset_markers()
