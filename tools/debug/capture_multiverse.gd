extends SceneTree

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const OUTPUT_DIR: String = "res://logs/debug/multiverse_captures"

var label_prefix: String = ""
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _arg(key: String, fallback: String = "") -> String:
	for argument in OS.get_cmdline_user_args():
		var text: String = String(argument)
		if text.begins_with("--%s=" % key):
			return text.split("=", true, 1)[1]
	return fallback


func _run() -> void:
	label_prefix = _arg("label", "")
	var size_arg: PackedStringArray = _arg("size", "1920x1080").split("x", false)
	var window: Vector2i = Vector2i(int(size_arg[0]), int(size_arg[1])) if size_arg.size() == 2 else Vector2i(1920, 1080)
	DisplayServer.window_set_size(window)
	root.content_scale_size = Vector2i(0, 0)
	var driver = DRIVER.new(self)
	var code: String = _arg("code", "match seed=7 mode=pvp map=chessboard multiverse=1 p=0483_dialga@100:roar_of_time,dragon_claw,flash_cannon,earth_power:pressure|0251_celebi@100:dimensional_hole,psychic,giga_drain,recover:natural_cure e=0484_palkia@100:spacial_rend,aqua_tail,dragon_claw,earth_power:pressure|0487_giratina@100:shadow_force,dragon_claw,shadow_sneak,will_o_wisp:pressure")
	var ok: bool = await driver._launch(code)
	if not ok:
		print("capture: launch failed")
		quit(1)
		return
	var level: TacticsLevel = driver.level
	var mv: MultiverseController = level.multiverse
	var frames: int = 0
	while frames < 6000 and level.round_index < 3:
		var active: BattleUnit = level.scheduler.get_active_unit()
		if active != null and active.pawn != null and not level.is_presentation_busy() and _is_player(active.pawn):
			await driver._end_turn(active.pawn)
		await physics_frame
		frames += 1
	var dialga: TacticsPawn = level.notation.pawn_for_id("P1")
	var palkia: TacticsPawn = level.notation.pawn_for_id("E1")
	var roar: PokemonMoveResource = PokemonLearnsetService.load_move("roar_of_time")
	level._ops().damage(palkia, 12, {"kind": "hit", "attacker": dialga, "move": roar})
	BattleMoveSpecials.new().after_hit(null, dialga, palkia, roar, 12, true, level, level.battle_log)
	if mv.pending_travel.is_empty():
		print("capture: no travel offered")
		quit(1)
		return
	mv.commit_travel(0)
	for i in range(90):
		await physics_frame
	_report_occupancy(level)
	var extra: int = int(_arg("after_turns", "0"))
	var turns_seen: int = 0
	var last_turn: int = level.notation.turn_index
	var guard: int = 0
	while turns_seen < extra and guard < 40000 and not level.battle_finished:
		guard += 1
		var active: BattleUnit = level.scheduler.get_active_unit()
		if active != null and active.pawn != null and not level.is_presentation_busy() and _is_player(active.pawn):
			await driver._end_turn(active.pawn)
		await physics_frame
		if level.notation.turn_index != last_turn:
			last_turn = level.notation.turn_index
			turns_seen += 1
		_check_settled(level, turns_seen)
	if extra > 0:
		print("capture: post-travel turns=%d collisions=%d" % [turns_seen, failures])
	await _shot("branch")
	var camera: TacticsCamera = root.find_child("TacticsCamera", true, false) as TacticsCamera
	if camera != null and camera.res != null:
		camera.res.target = null
		for i in range(int(_arg("zoom_steps", "80"))):
			camera.zoom_camera(camera.res.zoom_speed)
			await physics_frame
	for i in range(240):
		await physics_frame
	await _shot("overview")
	print("capture: done")
	quit(0)


func _check_settled(level: TacticsLevel, turn_number: int) -> void:
	for pawn in level.units_on_map():
		if pawn.res != null and (pawn.res.is_moving or not pawn.res.pathfinding_tilestack.is_empty()):
			return
	var seen: Dictionary = {}
	for pawn in level.units_on_map():
		if pawn.stats == null or not pawn.is_alive():
			continue
		var tile: TacticsTile = pawn.get_tile()
		if tile == null:
			continue
		var key: String = level.notation.tile_label(Targeting._tile_key(tile))
		var id: String = level.notation.unit_id(pawn)
		if seen.has(key):
			failures += 1
			print("capture: COLLISION after turn %d - %s and %s both on %s" % [turn_number, String(seen[key]), id, key])
		else:
			seen[key] = id


func _report_occupancy(level: TacticsLevel) -> void:
	var seen: Dictionary = {}
	for pawn in level.units_on_map():
		var ray: RayCast3D = pawn.get_node_or_null("Tile") as RayCast3D
		if ray != null:
			ray.force_raycast_update()
		var tile: TacticsTile = pawn.get_tile()
		var key: String = level.notation.tile_label(Targeting._tile_key(tile)) if tile != null else "?"
		var id: String = level.notation.unit_id(pawn)
		print("capture: %s stands on %s (world %.2f, %.2f)" % [id, key, pawn.global_position.x, pawn.global_position.z])
		if seen.has(key):
			print("capture: COLLISION %s shares %s with %s" % [id, key, String(seen[key])])
		seen[key] = id


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var image: Image = root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var path: String = "%s/%s%s.png" % [OUTPUT_DIR, label_prefix, name]
	image.save_png(ProjectSettings.globalize_path(path))
	print("capture: %s" % path)


func _is_player(pawn: TacticsPawn) -> bool:
	return pawn.stats != null and pawn.stats.pokemon_instance != null and pawn.stats.pokemon_instance.control_type == PokemonInstanceResource.ControlType.PLAYER
