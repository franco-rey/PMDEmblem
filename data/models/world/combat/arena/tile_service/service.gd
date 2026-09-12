class_name TacticsTileService
extends Node3D

const TILE_SRC: String = "res://data/modules/tactics/level/arena/tile/tactics_tile.gd"


static func tiles_into_staticbodies(tiles_obj: Node3D) -> void:
	for _t: MeshInstance3D in tiles_obj.get_children():
		_t.create_trimesh_collision()
		var _static_body: StaticBody3D = _t.get_child(0)
		_static_body.set_position(_t.get_position())

		_t.set_position(Vector3.ZERO)
		_t.set_name("Tile")
		_t.remove_child(_static_body)
		tiles_obj.remove_child(_t)
		_static_body.add_child(_t)
		_static_body.set_script(load(TILE_SRC))

		_static_body.configure_tile()
		_static_body.set_process(true)

		tiles_obj.add_child(_static_body)
