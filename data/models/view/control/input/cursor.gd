class_name CursorService
extends RefCounted


static func set_cursor_shape_to_move() -> void:
	if Input.get_current_cursor_shape() != Input.CURSOR_MOVE:
		Input.set_default_cursor_shape(Input.CURSOR_MOVE)


static func set_cursor_shape_to_arrow() -> void:
	if Input.get_current_cursor_shape() != Input.CURSOR_ARROW:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
