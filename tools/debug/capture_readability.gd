extends SceneTree

const MAIN_SCENE_PATH: String = "res://assets/scene/main.tscn"
const OUTPUT_DIR: String = "res://logs/debug/readability_captures"
const DRIVER := preload("res://tools/debug/notation_driver.gd")

var captured: Array[String] = []
var label_prefix: String = ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var size_arg: PackedStringArray = _arg("size").split("x", false)
	var window_size: Vector2i = Vector2i(int(size_arg[0]), int(size_arg[1])) if size_arg.size() == 2 else Vector2i(1920, 1080)
	DisplayServer.window_set_size(window_size)
	root.content_scale_size = Vector2i(0, 0)
	UiScale.override_factor = UiScale.compute(Vector2(window_size))
	label_prefix = _arg("label")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=12 mode=pvp map=chessboard p=0006_charizard@50:flamethrower,slash,fly,dig:blaze|0025_pikachu@50:thunderbolt,quick_attack:static e=0009_blastoise@50:hydro_pump,tackle:torrent|0003_venusaur@50:razor_leaf,tackle:overgrow")
	if not ok:
		print("readability: launch failed")
		quit(1)
		return
	var level: TacticsLevel = driver.level
	var main: Node = driver.main
	DisplayServer.window_set_size(window_size)
	UiScale.override_factor = UiScale.compute(Vector2(window_size))
	for i in range(6):
		await process_frame
	print("readability: viewport %s scale %.2f" % [str(root.get_viewport().get_visible_rect().size), UiScale.override_factor])
	var cam: TacticsCamera = main.find_child("TacticsCamera", true, false)
	if cam != null:
		cam.res.target_fov = 30.0
	for i in range(30):
		await process_frame
	await _snap("read_00_hp_bars_sky")
	var attacker: TacticsPawn = level.notation.pawn_for_id("P1")
	var target: TacticsPawn = level.notation.pawn_for_id("E1")
	var participant: TacticsParticipantResource = level.participant.res
	var controls: TacticsControls = main.get_node("TacticsControls")
	var camera_node: Camera3D = root.get_viewport().get_camera_3d()
	await driver._wait_for_turn(attacker)
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	var attacker_key: Vector3i = Targeting._tile_key(attacker.get_tile())
	for direction in [Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1)]:
		var neighbor: Vector3i = attacker_key + direction * 2
		if keys.has(neighbor) and (keys[neighbor] as TacticsTile).get_tile_occupier() == null:
			var ray: RayCast3D = target.get_node("Tile")
			target.global_position = (keys[neighbor] as TacticsTile).global_position + Vector3.UP * 0.05
			ray.force_raycast_update()
			target.center()
			ray.force_raycast_update()
			attacker.serv.movement.look_at_direction_8(attacker, Vector3(float(direction.x), 0.0, float(direction.z)))
			break
	await physics_frame
	await physics_frame
	_press(controls.get_act("Move"))
	for i in range(8):
		await process_frame
	var far: TacticsTile = null
	var far_clearance: float = 0.0
	for key in keys.keys():
		var tile: TacticsTile = keys[key]
		if not tile.reachable or tile.pf_distance < 3 or tile.get_tile_occupier() != null:
			continue
		var clearance: float = INF
		for pawn in level.units_on_map():
			clearance = minf(clearance, tile.global_position.distance_to(pawn.global_position))
		if clearance > far_clearance:
			far_clearance = clearance
			far = tile
	if far != null:
		attacker.res.pathfinding_tilestack = level.arena.get_pathfinding_tilestack(far)
		level.arena.mark_committed(far)
		participant.stage = participant.STAGE_MOVE_PAWN
		for i in range(10):
			await process_frame
		await _snap("read_02_committed")
		var frames: int = 0
		while frames < 300 and (attacker.res.is_moving or not attacker.res.pathfinding_tilestack.is_empty()):
			await process_frame
			frames += 1
	for i in range(10):
		await process_frame
	_press(controls.get_act("Attack"))
	for i in range(8):
		await process_frame
	var slot: Button = controls.get_node_or_null("HBox/MovePicker/MoveSlot0") as Button
	if slot != null:
		_press(slot)
	for i in range(8):
		await process_frame
	_warp_to(camera_node, target.global_position)
	for i in range(14):
		await process_frame
	await _snap("read_03_target_estimate")
	if participant.attackable_pawn == null:
		participant.attackable_pawn = target
	level.arena.mark_committed(target.get_tile())
	participant.stage = participant.STAGE_ATTACK
	var wait_frames: int = 0
	while wait_frames < 300 and level.floating_text.get_child_count() == 0:
		await process_frame
		wait_frames += 1
	for i in range(8):
		await process_frame
	await _snap("read_04_damage_popup")
	while wait_frames < 600 and level.is_presentation_busy():
		await process_frame
		wait_frames += 1
	level.message_log.set_minimized(true)
	level.hud.set_status_minimized(true)
	for i in range(6):
		await process_frame
	await _snap("read_08_docks_minimized")
	level.message_log.set_minimized(false)
	level.hud.set_status_minimized(false)
	for i in range(4):
		await process_frame
	var pause: PauseMenu = main.get_node("PauseMenu")
	pause.open()
	for i in range(4):
		await process_frame
	await _snap("read_05_pause_menu")
	pause._show_graphics()
	for i in range(4):
		await process_frame
	await _snap("read_06_graphics")
	pause.close()
	var results: BattleResultsScreen = main.get_node("BattleResultsScreen")
	var definition := SkirmishDefinitionResource.new()
	definition.control_mode = SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER
	definition.seed = 12
	results.show_result(1, definition, level)
	for i in range(4):
		await process_frame
	await _snap("read_07_results")
	results.hide_results()
	for path in captured:
		print("capture: %s" % path)
	quit(0)


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null:
		return
	var path: String = "%s/%s%s.png" % [OUTPUT_DIR, label_prefix, label]
	image.save_png(ProjectSettings.globalize_path(path))
	captured.append(path)


func _press(button: Button) -> void:
	if button != null:
		button.pressed.emit()


func _warp_to(camera_node: Camera3D, world: Vector3) -> void:
	if camera_node == null:
		return
	Input.warp_mouse(camera_node.unproject_position(world))


func _arg(name: String) -> String:
	for arg in OS.get_cmdline_user_args():
		var text: String = String(arg)
		if text.begins_with("--%s=" % name):
			return text.substr(name.length() + 3)
	return ""
