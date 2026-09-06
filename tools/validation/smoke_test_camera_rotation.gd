extends SceneTree

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const FRAME: float = 1.0 / 60.0
const MAX_FRAMES: int = 240

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=2 mode=pvp team=2")
	_assert_true(ok, "2v2 launches")
	if not ok:
		_finish()
		return
	var rigs: Array = root.find_children("*", "TacticsCamera", true, false)
	var camera_node: TacticsCamera = rigs[0] if not rigs.is_empty() else null
	_assert_true(camera_node != null, "camera rig is in the tree")
	if camera_node == null:
		_finish()
		return
	var res: TacticsCameraResource = camera_node.res
	var start_heading: int = posmod(res.y_rot, 360)
	var stuck: Array[int] = []
	for direction in [-45, 45]:
		for step in range(8):
			camera_node.rotate_camera(FRAME, direction)
			var frames: int = 0
			while res.is_rotating and frames < MAX_FRAMES:
				camera_node.serv.rotate.rotate_camera(FRAME, camera_node.t_pivot, camera_node.p_pivot)
				frames += 1
			if res.is_rotating:
				stuck.append(res.y_rot)
	_assert_true(stuck.is_empty(), "step rotations settle at every heading in both directions (stuck at %s)" % str(stuck))
	_assert_true(res.y_rot == start_heading, "sixteen steps return to the starting heading (%d)" % res.y_rot)
	var heading_rad: float = deg_to_rad(float(res.y_rot))
	_assert_true(Quaternion.from_euler(camera_node.t_pivot.rotation).angle_to(Quaternion.from_euler(Vector3(deg_to_rad(float(res.x_rot)), heading_rad, 0.0))) < 0.01, "the pivot lands on the stored heading")
	var steps_to_270: int = posmod(res.y_rot - 270, 360) / 45
	for step in range(steps_to_270):
		camera_node.rotate_camera(FRAME, -45)
	var frames_270: int = 0
	while res.is_rotating and frames_270 < MAX_FRAMES:
		camera_node.serv.rotate.rotate_camera(FRAME, camera_node.t_pivot, camera_node.p_pivot)
		frames_270 += 1
	_assert_true(res.y_rot == 270 and not res.is_rotating, "rotating to 270 degrees clears the rotation flag (%d, rotating=%s)" % [res.y_rot, str(res.is_rotating)])
	res.toggle_perspective()
	var frames_p: int = 0
	while res.is_rotating and frames_p < MAX_FRAMES:
		camera_node.serv.rotate.rotate_camera(FRAME, camera_node.t_pivot, camera_node.p_pivot)
		frames_p += 1
	_assert_true(not res.is_rotating, "perspective toggle at 270 degrees settles too")
	res.toggle_perspective()
	res.is_rotating = true
	var controls: TacticsControls = driver.main.get_node("TacticsControls")
	Input.action_press("camera_free_look")
	controls.camera_rotation_inputs(FRAME)
	Input.action_release("camera_free_look")
	_assert_true(res.in_free_look and not res.is_rotating, "middle click starts free look even while a step rotation is in flight")
	res.in_free_look = false
	var before_orbit: float = camera_node.t_pivot.rotation_degrees.y
	res.toggle_orbit(-1)
	for i in range(60):
		camera_node.serv.process(FRAME, camera_node)
	var turned: float = wrapf(camera_node.t_pivot.rotation_degrees.y - before_orbit, -180.0, 180.0)
	_assert_true(res.orbit_direction == -1 and absf(absf(turned) - res.ORBIT_SPEED_DEGREES) < 3.0, "the left bracket orbits the camera slowly (%.1f degrees in a second)" % turned)
	var after_stop: float = fposmod(camera_node.t_pivot.rotation_degrees.y, 360.0)
	res.toggle_orbit(-1)
	_assert_true(res.orbit_direction == 0 and res.is_snapping_to_quad, "pressing the same bracket again stops the orbit and starts the settle")
	_assert_true(res.y_rot % 45 == 0, "the settle targets a 45 degree multiple (%d)" % res.y_rot)
	var committed: float = wrapf(float(res.y_rot) - after_stop, -180.0, 180.0)
	_assert_true(committed <= 0.0 and committed > -45.0, "the settle follows through in the orbit direction (%.1f degrees from %.1f)" % [committed, after_stop])
	res.toggle_orbit(-1)
	res.toggle_orbit(1)
	_assert_true(res.orbit_direction == 1, "the other bracket reverses the orbit")
	res.orbit_direction = 0
	res.in_free_look = true
	camera_node.serv.rotate.deactivate_free_look(camera_node)
	_assert_true(not res.in_free_look and res.is_snapping_to_quad, "releasing free look snaps to the nearest quadrant")
	await create_timer(res.quad_snap_duration + 0.2).timeout
	_assert_true(not res.is_snapping_to_quad, "quadrant snap finishes and releases the camera")
	_finish()


func _finish() -> void:
	if failures > 0:
		push_error("smoke: camera_rotation failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: camera_rotation clean")
	quit(0)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)
