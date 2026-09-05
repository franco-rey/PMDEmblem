class_name TacticsArena
extends Node3D

@export var res: TacticsArenaResource = load("res://data/models/world/combat/arena/arena.tres")
var serv: TacticsArenaService


func _ready() -> void:
	serv = TacticsArenaService.new(res)
	serv.setup(self)


func reset_all_tile_markers() -> void:
	serv.reset_all_tile_markers(self)


func configure_tiles() -> void:
	serv.configure_tiles(self)


func process_surrounding_tiles(root_tile: TacticsTile, height: float, allies_on_map: Array = []) -> void:
	serv.process_surrounding_tiles(root_tile, height, allies_on_map)


func get_pathfinding_tilestack(to: TacticsTile) -> Array:
	return serv.get_pathfinding_tilestack(to)


func get_nearest_target_adjacent_tile(pawn: TacticsPawn, target_pawns: Array) -> TacticsTile:
	return serv.get_nearest_target_adjacent_tile(pawn, target_pawns)


func get_weakest_attackable_pawn(pawn_arr: Array) -> TacticsPawn:
	return serv.get_weakest_attackable_pawn(pawn_arr)


func mark_hover_tile(tile: TacticsTile) -> void:
	serv.mark_hover_tile(self, tile)


func mark_path_preview(tile: TacticsTile) -> void:
	serv.mark_path_preview(self, tile)


func mark_committed(tile: TacticsTile) -> void:
	serv.mark_committed(self, tile)


func mark_reachable_tiles(root: TacticsTile, distance: float) -> void:
	serv.mark_reachable_tiles(self, root, distance)


func mark_attackable_tiles(root: TacticsTile, distance: float) -> void:
	serv.mark_attackable_tiles(self, root, distance)


func mark_unit_tiles_attackable(units: Array[TacticsPawn]) -> void:
	serv.mark_unit_tiles_attackable(units)


func mark_move_range_preview(unit: TacticsPawn, move: PokemonMoveResource) -> void:
	serv.mark_move_range_preview(self, unit, move)


func mark_movement_preview(unit: TacticsPawn) -> void:
	serv.mark_movement_preview(self, unit)
