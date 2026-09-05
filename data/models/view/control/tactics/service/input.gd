class_name TacticsControlsInputService
extends RefCounted

var controls: TacticsControlsResource
var mouse_click_capture: Node


func _init(_controls: TacticsControlsResource, _mouse_click_capture: Node) -> void:
	controls = _controls
	mouse_click_capture = _mouse_click_capture


func update_mouse_mode() -> void:
	Input.set_mouse_mode(int(controls.is_joystick))


func handle_input(event: InputEvent) -> void:
	controls.is_joystick = event is InputEventJoypadButton or event is InputEventJoypadMotion


func get_3d_canvas_mouse_position(collision_mask: int, ctrl: TacticsControls) -> Object:
	if is_mouse_hovering_ui_elem(ctrl):
		return null

	if mouse_click_capture:
		return mouse_click_capture.project_mouse_position(collision_mask, controls.is_joystick)
	else:
		push_error("MouseClickCapture node not found")
		return null


func is_mouse_hovering_ui_elem(
		ctrl: TacticsControls, elm: Array[String] = TacticsConfig.ui_elem) -> bool:
	if ctrl == null or not ctrl.is_inside_tree() or ctrl.get_viewport() == null:
		return false
	if TacticsConfig.hover_controls_contain(ctrl.get_viewport().get_mouse_position()):
		return true
	for e: String in elm:
		var elem: Control = _ui_elem(ctrl, e)
		if elem != null and elem.visible:
			match e:
				"%Actions":
					for action: Node in elem.get_children():
						if not (action is Button):
							continue
						var action_button: Button = action as Button
						if action_button.get_global_rect().has_point(ctrl.get_viewport().get_mouse_position()):
							return true
				"%MovePicker", "%ItemPicker":
					for action: Node in elem.get_children():
						if not (action is Button):
							continue
						var move_button: Button = action as Button
						if move_button.get_global_rect().has_point(ctrl.get_viewport().get_mouse_position()):
							return true
	return false


func _ui_elem(ctrl: TacticsControls, path: String) -> Control:
	if ctrl == null:
		return null
	var node: Node = ctrl.get_node_or_null(path)
	if node == null and path == "%MovePicker":
		node = ctrl.get_node_or_null("HBox/MovePicker")
	if node == null and path == "%ItemPicker":
		node = ctrl.get_node_or_null("HBox/ItemPicker")
	if node == null and path == "%Actions":
		node = ctrl.get_node_or_null("HBox/Actions")
	return node as Control
