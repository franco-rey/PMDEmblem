class_name TacticsCameraRotationService
extends RefCounted

const DELTA_SMOOTHING: int = 10
const MAX_VERT_ROT: int = 20
const MIN_VERT_ROT: int = -45
const FREE_LOOK_ROT_FACTOR: int = 2
const ROTATION_DONE_RADIANS: float = 0.002
const SNAP_STEP_DEGREES: float = 45.0
const QUADRANT_EPSILON: float = 0.001

var res: TacticsCameraResource
var controls: TacticsControlsResource
var quad_tween: Tween


func _init(_res: TacticsCameraResource, _controls: TacticsControlsResource) -> void:
	res = _res
	controls = _controls


func free_look(delta: float, t_pivot: Node3D, p_pivot: Node3D) -> void:
	controls.set_cursor_shape_to_move()

	var input: Vector2 = get_free_look_input()
	apply_free_look_rotation(input, delta, t_pivot, p_pivot)

	reset_twist_pitch_inputs()


func orbit(delta: float, t_pivot: Node3D) -> void:
	if res.orbit_direction == 0:
		return
	t_pivot.rotate_y(deg_to_rad(res.ORBIT_SPEED_DEGREES * float(res.orbit_direction)) * delta)
	res.y_rot = int(round(fposmod(t_pivot.rotation_degrees.y, 360.0)))


func rotate_camera(delta: float, t_pivot: Node3D, p_pivot: Node3D) -> void:
	var curr_quat_t: Quaternion = Quaternion.from_euler(t_pivot.rotation)
	var curr_quat_p: Quaternion = Quaternion.from_euler(p_pivot.rotation)
	var destination_t: Vector3 = Vector3(deg_to_rad(res.x_rot), deg_to_rad(res.y_rot), 0)
	var destination_p: Vector3 = Vector3(0, 0, res.z_rot)
	var target_quat_t: Quaternion = Quaternion.from_euler(destination_t)
	var target_quat_p: Quaternion = Quaternion.from_euler(destination_p)

	var weight: float = clampf((res.rot_speed * DELTA_SMOOTHING) * delta, 0.0, 1.0)
	var new_quat_t: Quaternion = curr_quat_t.slerp(target_quat_t, weight)
	var new_quat_p: Quaternion = curr_quat_p.slerp(target_quat_p, weight)

	t_pivot.rotation = new_quat_t.get_euler()
	p_pivot.rotation = new_quat_p.get_euler()

	if new_quat_t.angle_to(target_quat_t) <= ROTATION_DONE_RADIANS and new_quat_p.angle_to(target_quat_p) <= ROTATION_DONE_RADIANS:
		t_pivot.rotation = destination_t
		p_pivot.rotation = destination_p
		res.is_rotating = false


func check_free_look_activation(delta: float, camera: TacticsCamera) -> void:
	if controls.is_joystick:
		if is_joystick_input_active():
			DebugLog.debug_nospam("joystick_free_look", true)
			res.in_free_look = true
			res.free_look_timer = 0.0
		elif res.in_free_look:
			update_free_look_timer(delta, camera)
		else:
			DebugLog.debug_nospam("joystick_free_look", false)
	else:
		if not Input.is_action_pressed("camera_free_look") and res.in_free_look:
			deactivate_free_look(camera)


func deactivate_free_look(camera: TacticsCamera) -> void:
	res.in_free_look = false
	controls.set_cursor_shape_to_arrow()
	snap_to_nearest_quadrant(camera)


func update_free_look_timer(delta: float, camera: TacticsCamera) -> void:
	res.free_look_timer += delta
	if res.free_look_timer >= res.FREE_LOOK_TIMEOUT and res.in_free_look:
		deactivate_free_look(camera)


func add_angle_to_horiz_rotation(twist: int) -> void:
	if twist != 0:
		res.y_rot = int(fmod(res.y_rot + twist, 360))
		if res.y_rot < 0:
			res.y_rot += 360


func get_free_look_input() -> Vector2:
	return get_free_look_joystick_input() if controls.is_joystick else get_free_look_mouse_input()


func get_free_look_joystick_input() -> Vector2:
	var right_stick_x: float = -Input.get_joy_axis(0, res.R_JOYSTICK_X)
	var right_stick_y: float = Input.get_joy_axis(0, res.R_JOYSTICK_Y)

	var input: Vector2 = Vector2.ZERO
	if abs(right_stick_x) > res.CONTROLLER_DEADZONE:
		input.x = -right_stick_x * res.rot_speed * res.RIGHT_STICK_SENSITIVITY
	if abs(right_stick_y) > res.CONTROLLER_DEADZONE:
		input.y = right_stick_y * res.rot_speed * res.RIGHT_STICK_SENSITIVITY

	return input


func get_free_look_mouse_input() -> Vector2:
	return Vector2(res.twist_input, res.pitch_input)


func apply_free_look_rotation(input: Vector2, delta: float, t_pivot: Node3D, p_pivot: Node3D) -> void:
	t_pivot.rotate_y((input.x * FREE_LOOK_ROT_FACTOR) * delta)
	p_pivot.rotate_x((input.y * FREE_LOOK_ROT_FACTOR) * delta)
	p_pivot.rotation.x = clamp(p_pivot.rotation.x, deg_to_rad(MIN_VERT_ROT), deg_to_rad(MAX_VERT_ROT))


func reset_twist_pitch_inputs() -> void:
	res.twist_input = 0.0
	res.pitch_input = 0.0


func is_joystick_input_active() -> bool:
	var right_stick_x: float = -Input.get_joy_axis(0, res.R_JOYSTICK_X)
	var right_stick_y: float = Input.get_joy_axis(0, res.R_JOYSTICK_Y)
	return abs(right_stick_x) > res.CONTROLLER_DEADZONE or abs(right_stick_y) > res.CONTROLLER_DEADZONE


func snap_to_nearest_quadrant(camera: TacticsCamera) -> void:
	snap_to_quadrant(camera, calculate_nearest_quadrant(camera))


func snap_orbit_to_quadrant(camera: TacticsCamera, direction: int) -> void:
	if direction == 0:
		cancel_quadrant_snap()
		return
	snap_to_quadrant(camera, Vector3(res.x_rot, calculate_next_quadrant(camera, direction), 0))


func cancel_quadrant_snap() -> void:
	if quad_tween != null and quad_tween.is_valid():
		quad_tween.kill()
	quad_tween = null
	res.is_snapping_to_quad = false


func calculate_next_quadrant(camera: TacticsCamera, direction: int) -> float:
	var current: float = fposmod(camera.t_pivot.rotation_degrees.y, 360.0)
	var index: float = current / SNAP_STEP_DEGREES
	var stepped: float = ceilf(index - QUADRANT_EPSILON) if direction > 0 else floorf(index + QUADRANT_EPSILON)
	return stepped * SNAP_STEP_DEGREES


func snap_to_quadrant(camera: TacticsCamera, quadrant: Vector3) -> void:
	cancel_quadrant_snap()
	res.is_snapping_to_quad = true

	var current_rotation: Vector3 = camera.t_pivot.rotation_degrees
	var target_rotation: Vector3 = quadrant

	var rotation_difference: float = target_rotation.y - current_rotation.y
	if abs(rotation_difference) > 180:
		if rotation_difference > 0:
			target_rotation.y -= 360
		else:
			target_rotation.y += 360

	var tween: Tween = camera.create_tween()
	quad_tween = tween
	tween.tween_property(camera.t_pivot, "rotation_degrees", target_rotation, res.quad_snap_duration).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(camera.p_pivot, "rotation_degrees:x", res.z_rot, res.quad_snap_duration).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(
		func() -> void:
		camera.t_pivot.rotation_degrees.y = fmod(camera.t_pivot.rotation_degrees.y, 360)
		if camera.t_pivot.rotation_degrees.y < 0:
			camera.t_pivot.rotation_degrees.y += 360
		res.is_snapping_to_quad = false
	)

	res.y_rot = int(fmod(target_rotation.y, 360))
	if res.y_rot < 0:
		res.y_rot += 360


const SNAP_ANGLES: Array[int] = [0, 45, 90, 135, 180, 225, 270, 315]


func calculate_nearest_quadrant(camera: TacticsCamera) -> Vector3:
	var current_rotation: float = camera.t_pivot.rotation_degrees.y
	var quadrants: Array = SNAP_ANGLES

	current_rotation = fmod(current_rotation, 360)
	if current_rotation < 0:
		current_rotation += 360

	var nearest_quadrant: int = 0
	var smallest_difference: int = 360

	for quadrant: int in quadrants:
		var difference: float = abs(current_rotation - quadrant)
		difference = min(difference, 360 - difference)
		if difference < smallest_difference:
			smallest_difference = round(difference)
			nearest_quadrant = round(quadrant)

	return Vector3(res.x_rot, nearest_quadrant, 0)
