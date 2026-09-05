class_name TacticsCameraMovementService
extends RefCounted

const DELTA_SMOOTHING: int = 8
const FAST_SMOOTHING: int = 100
const VELOCITY_SMOOTHING: int = 8
const MIN_THRESHOLD: float = 0.1
const MIN_DISTANCE: float = 0.25
const SPEED_DIVIDER: int = 4

var res: TacticsCameraResource
var controls: TacticsControlsResource


func _init(_res: TacticsCameraResource, _controls: TacticsControlsResource) -> void:
	res = _res
	controls = _controls


func move_camera(h: float, v: float, joystick: bool, delta: float, camera: TacticsCamera) -> void:
	if res.target or (h == 0 and v == 0):
		return

	var angle: float = (atan2(-h, v)) + camera.t_pivot.get_rotation().y
	var dir: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, angle)

	var speed_multiplier: float = res.joy_pan_speed if joystick else res.mouse_pan_speed
	res.target_velocity = dir * res.move_speed * speed_multiplier

	if joystick:
		res.target_velocity *= sqrt(h * h + v * v)

	camera.velocity = camera.velocity.lerp(res.target_velocity * VELOCITY_SMOOTHING, (res.smoothing * DELTA_SMOOTHING) * delta)

	if camera.velocity.length() > MIN_THRESHOLD:
		var new_position: Vector3 = camera.global_position + camera.velocity * delta
		var distance_from_center: Vector3 = new_position - res.boundary_center

		if distance_from_center.length() > res.boundary_radius:
			var clamped_position: Vector3 = res.boundary_center + distance_from_center.normalized() * res.boundary_radius
			camera.global_position = clamped_position
			camera.velocity = Vector3.ZERO
		else:
			_slide(camera)


func focus_on_target(camera: TacticsCamera) -> void:
	if not res.target or res.target == null:
		return
	if not GameSettings.camera_track:
		res.target = null
		return

	var from: Vector3 = camera.global_position
	var to: Vector3 = res.target.global_position
	if from.distance_to(to) <= MIN_DISTANCE:
		res.target = null
		return

	var vel: Vector3 = (to-from) * res.move_speed / SPEED_DIVIDER

	var distance_from_center: Vector3 = to - res.boundary_center
	if distance_from_center.length() > res.boundary_radius:
		to = res.boundary_center + distance_from_center.normalized() * res.boundary_radius
		vel = (to-from) * res.move_speed / SPEED_DIVIDER

	camera.set_velocity(vel)
	camera.set_up_direction(Vector3.UP)
	_slide(camera)

	camera.velocity = camera.velocity


func stabilize_camera(delta: float, camera: TacticsCamera) -> void:
	if res.target:
		return

	res.target_velocity = Vector3.ZERO
	camera.velocity = camera.velocity.lerp(Vector3.ZERO, (res.smoothing * FAST_SMOOTHING) * delta)
	if camera.velocity.length() > MIN_THRESHOLD:
		_slide(camera)


static func _slide(camera: TacticsCamera) -> void:
	var scale: float = maxf(Engine.time_scale, 0.001)
	if is_equal_approx(scale, 1.0):
		camera.move_and_slide()
		return
	camera.velocity /= scale
	camera.move_and_slide()
	camera.velocity *= scale

