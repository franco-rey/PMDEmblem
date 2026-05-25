class_name TacticsControlsInputService
extends RefCounted
## Service class for managing input-related functionalities in the Tactics game.

## Reference to the TacticsControlsResource.
var controls: TacticsControlsResource
## Node for capturing mouse clicks.
var mouse_click_capture: Node


## Initializes the TacticsControlsInputService with necessary resources and nodes.
func _init(_controls: TacticsControlsResource, _mouse_click_capture: Node) -> void:
	controls = _controls
	mouse_click_capture = _mouse_click_capture


## Updates the mouse mode based on whether a joystick is being used.
func update_mouse_mode() -> void:
	Input.set_mouse_mode(int(controls.is_joystick))


## Handles input events and updates the joystick status.
func handle_input(event: InputEvent) -> void:
	controls.is_joystick = event is InputEventJoypadButton or event is InputEventJoypadMotion


## Gets the 3D position of the mouse in the game world.
## Returns null if hovering over a UI element or if mouse_click_capture is not set.
func get_3d_canvas_mouse_position(collision_mask: int, ctrl: TacticsControls) -> Object:
	if is_mouse_hovering_ui_elem(ctrl):
		return null
	
	if mouse_click_capture:
		return mouse_click_capture.project_mouse_position(collision_mask, controls.is_joystick)
	else:
		push_error("MouseClickCapture node not found")
		return null


## Checks if the mouse is hovering over a UI element.
## Returns true if the mouse is over any of the specified UI elements.
func is_mouse_hovering_ui_elem(
		ctrl: TacticsControls, elm: Array[String] = TacticsConfig.ui_elem) -> bool:
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
				"%MovePicker":
					for action: Node in elem.get_children():
						if not (action is Button):
							continue
						var move_button: Button = action as Button
						if move_button.get_global_rect().has_point(ctrl.get_viewport().get_mouse_position()):
							return true
				"%Hints":
					for hint: Node in elem.get_children():
						if not (hint is TextureRect):
							continue
						var hint_texture: TextureRect = hint as TextureRect
						if hint_texture.get_global_rect().has_point(ctrl.get_viewport().get_mouse_position()):
							return true
	return false


func _ui_elem(ctrl: TacticsControls, path: String) -> Control:
	if ctrl == null:
		return null
	var node: Node = ctrl.get_node_or_null(path)
	if node == null and path == "%MovePicker":
		node = ctrl.get_node_or_null("HBox/MovePicker")
	if node == null and path == "%Actions":
		node = ctrl.get_node_or_null("HBox/Actions")
	if node == null and path == "%Hints":
		node = ctrl.get_node_or_null("Hints")
	return node as Control
