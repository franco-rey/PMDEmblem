class_name TacticsArenaResource
extends Resource

signal called_reset_all_tile_markers
signal called_get_pathfinding_tilestack(tile: TacticsTile)
signal called_mark_hover_tile(tile: TacticsTile)
signal called_mark_path_preview(tile: TacticsTile)
signal called_mark_committed(tile: TacticsTile)

var path_tiles_stack: Array = []


func reset_all_tile_markers() -> void:
	called_reset_all_tile_markers.emit()


func get_pathfinding_tilestack(tile: TacticsTile) -> Array:
	called_get_pathfinding_tilestack.emit(tile)
	return path_tiles_stack


func mark_hover_tile(tile: TacticsTile) -> void:
	called_mark_hover_tile.emit(tile)


func mark_path_preview(tile: TacticsTile) -> void:
	called_mark_path_preview.emit(tile)


func mark_committed(tile: TacticsTile) -> void:
	called_mark_committed.emit(tile)
