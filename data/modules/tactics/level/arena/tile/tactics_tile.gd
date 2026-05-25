class_name TacticsTile
extends StaticBody3D

var tile_raycast: Resource = load("res://data/modules/tactics/level/arena/tile/raycast/tile_raycasting.tscn")

var reachable: bool = false
var attackable: bool = false
var hover: bool = false

var pf_root: TacticsTile
var pf_distance: float

var hover_mat: StandardMaterial3D = TacticsConfig.mat_color.hover
var reachable_mat: StandardMaterial3D = TacticsConfig.mat_color.reachable
var hover_reachable_mat: StandardMaterial3D = TacticsConfig.mat_color.reachable_hover
var attackable_mat: StandardMaterial3D = TacticsConfig.mat_color.attackable
var hover_attackable_mat: StandardMaterial3D = TacticsConfig.mat_color.hover_attackable

func _process(_delta: float) -> void:
	var tile: MeshInstance3D = get_node_or_null("Tile") as MeshInstance3D
	if not tile:
		return

	tile.visible = attackable or reachable or hover

	match hover:
		true:
			if reachable:
				tile.material_override = hover_reachable_mat
			elif attackable:
				tile.material_override = hover_attackable_mat
			else:
				tile.material_override = hover_mat
		false:
			if reachable:
				tile.material_override = reachable_mat
			elif attackable:
				tile.material_override = attackable_mat

func get_neighbors(height: float) -> Array:
	return $RayCasting.get_all_neighbors(height)


func get_tile_occupier() -> Object:
	return $RayCasting.get_object_above()


func is_taken() -> bool:
	return get_tile_occupier() != null


func reset_markers() -> void:
	pf_root = null
	pf_distance = 0
	reachable = false
	attackable = false
	hover = false


func configure_tile() -> void:
	hover = false
	var instance: Node = tile_raycast.instantiate()
	add_child(instance)
	reset_markers()
