class_name TacticsControlsCameraService
extends RefCounted

var t_cam: TacticsCameraResource


func _init(_t_cam: TacticsCameraResource) -> void:
	t_cam = _t_cam


func move_camera(delta: float, is_joystick: bool) -> void:
	var h: float = -Input.get_action_strength("camera_left") + Input.get_action_strength("camera_right")
	var v: float = Input.get_action_strength("camera_forward") - Input.get_action_strength("camera_backwards")

	t_cam.move_camera(h, v, is_joystick, delta)


const ROTATE_STEP_DEGREES: int = 45


func handle_rotation_inputs(delta: float) -> void:
	if Input.is_action_just_pressed("camera_zoom_in"):
		t_cam.zoom_step(-1)
	elif Input.is_action_just_pressed("camera_zoom_out"):
		t_cam.zoom_step(1)
	if Input.is_action_just_pressed("camera_perspective"):
		if not t_cam.in_free_look:
			t_cam.toggle_perspective()
			t_cam.rotate_camera(delta, 0)
		return
	if Input.is_action_just_pressed("camera_rotate_left"):
		if not t_cam.in_free_look:
			t_cam.rotate_camera(delta, -ROTATE_STEP_DEGREES)
	elif Input.is_action_just_pressed("camera_rotate_right"):
		if not t_cam.in_free_look:
			t_cam.rotate_camera(delta, ROTATE_STEP_DEGREES)
	elif Input.is_action_just_pressed("camera_free_look"):
		if not t_cam.is_rotating:
			t_cam.in_free_look = true
