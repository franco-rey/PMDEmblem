class_name TacticsCameraService
extends RefCounted

var res: TacticsCameraResource
var controls: TacticsControlsResource
var move: TacticsCameraMovementService
var zoom: TacticsCameraZoomService
var rotate: TacticsCameraRotationService
var pan: TacticsCameraPanningService

const DELTA_SMOOTHING: int = 10
const MIN_VEL: float = 0.01
const FL_ROT_SPEED_DIVIDER: float = 0.25


func _init(_res: TacticsCameraResource, _controls: TacticsControlsResource) -> void:
	res = _res
	controls = _controls
	move = TacticsCameraMovementService.new(res, controls)
	zoom = TacticsCameraZoomService.new(res)
	rotate = TacticsCameraRotationService.new(res, controls)
	pan = TacticsCameraPanningService.new(res)


func setup(camera: TacticsCamera, cam_node: Camera3D) -> void:
	if not controls:
		push_error("TacticsControls needs a ControlResource from /data/models/view/control/tactics/")
	if not res:
		push_error("TacticsCamera needs a CameraResource (T Cam) from /data/models/view/camera/tactics/")
	else:
		res.target_fov = cam_node.fov
		res.viewport_size = camera.get_viewport().size


func process(delta: float, camera: TacticsCamera) -> void:
	rotate.check_free_look_activation(delta, camera)

	if res.in_free_look:
		rotate.free_look(delta, camera.t_pivot, camera.p_pivot)
	elif not res.is_snapping_to_quad:
		rotate.rotate_camera(delta, camera.t_pivot, camera.p_pivot)

	var input_dir: Vector2 = Input.get_vector(
			"camera_left", "camera_right", "camera_forward", "camera_backwards")
	if pan.is_pressing_wasd(input_dir):
		pan.wasd_pan(delta, camera, input_dir)
	elif res.edge_pan_enabled and pan.is_cursor_near_edge(camera) and not controls.is_joystick:
		pan.edge_pan(delta, camera)
	else:
		res.panning_timer = 0.0
		move.stabilize_camera(delta, camera)

	if camera.velocity.length() < MIN_VEL:
		camera.velocity = Vector3.ZERO

	move.focus_on_target(camera)
	zoom.apply_zoom_smoothing(camera, delta)


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_edge_pan"):
		res.edge_pan_enabled = not res.edge_pan_enabled
		res.edge_pan_toggled.emit(res.edge_pan_enabled)
		return
	if event is InputEventMouseMotion:
		if res.in_free_look:
			res.twist_input = -event.relative.x * (FL_ROT_SPEED_DIVIDER * res.rot_speed)
			res.pitch_input = -event.relative.y * (FL_ROT_SPEED_DIVIDER * res.rot_speed)

	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom.zoom_camera(-res.zoom_speed)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom.zoom_camera(res.zoom_speed)
