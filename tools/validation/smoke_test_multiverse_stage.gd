extends SceneTree

const DRIVER: GDScript = preload("res://tools/debug/notation_driver.gd")

var driver: RefCounted = null
var level: TacticsLevel = null
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=13 mode=pvp multiverse=1 map=chessboard p=0484_palkia@50:spacial_rend,aqua_tail:pressure|0483_dialga@50:roar_of_time,dragon_claw:pressure e=0004_charmander@50:ember,scratch:blaze|0720_hoopa@50:hyperspace_hole,psychic:magician")
	_assert_true(ok, "multiverse battle on the chessboard launches")
	if not ok:
		_finish()
		return
	level = driver.level
	var frames: int = 0
	while not level._scheduler_started and frames < 300:
		await physics_frame
		frames += 1
	var mv: MultiverseController = level.multiverse
	var stage: MultiverseStage = level.multiverse_stage
	_assert_true(stage != null and mv.stage == stage and stage.get_parent() == level, "the multiverse stage is created under the level when the rules are on")
	_assert_true(stage._templates.size() >= 2 and stage.board_size.x > 5.0 and stage.board_size.z > 5.0, "the stage copies the chessboard's visual meshes into shared multimeshes (%d templates, %s)" % [stage._templates.size(), str(stage.board_size)])
	_assert_true(MultiverseStage.slot(Vector2i(0, 1)) == Vector3.ZERO and MultiverseStage.slot(Vector2i(1, 3)) == Vector3(2.0 * MultiverseStage.pitch, 0.0, -MultiverseStage.pitch), "slots run turns along x and timelines along z")
	_assert_true(stage.offset_for(mv.state.focus) == Vector3.ZERO and stage.board_status(mv.state.focus) == MultiverseStage.STATUS_CURRENT, "the live board sits at the origin and reads as current")
	_assert_true(stage.refreshes >= 1 and not stage.field_visible and stage.bands.is_empty() and stage.boards.is_empty() and not stage._live_halo.visible, "with a single timeline the world field stays hidden and the battle looks normal")
	var fx: MultiverseFx = level.multiverse_fx
	_assert_true(fx != null and mv.fx == fx and fx.ripple != null and fx.ripple.material is ShaderMaterial, "the travel effect layer exists with its ripple shader")
	var minimap: MultiverseMinimap = level.multiverse_minimap
	var hud: BattleHud = level.hud
	_assert_true(minimap != null and mv.minimap == minimap and hud != null and hud.corner_reserve == MultiverseMinimap.DIAMETER, "the mini map sits in the HUD corner with its reserve")
	await process_frame
	await process_frame
	var expected_top: float = BattleHudLayout.MARGIN + BattleHudLayout.PANEL_HEIGHT + BattleHudLayout.GAP
	_assert_true(is_equal_approx(minimap.offset_top, expected_top) and is_equal_approx(minimap.offset_left, BattleHudLayout.MARGIN) and is_equal_approx(hud._status_dock.offset_left, BattleHudLayout.MARGIN) and is_equal_approx(level.message_log.dock_left, BattleHudLayout.MARGIN), "the mini map sits under the active unit card and the docks stay flush at the bottom left (%.0f, %.0f)" % [minimap.offset_top, hud._status_dock.offset_left])
	var short_plan: Dictionary = BattleHudLayout.solve({"size": Vector2(1280, 720), "tile_count": 8, "corner_reserve": MultiverseMinimap.DIAMETER})
	var tall_plan: Dictionary = BattleHudLayout.solve({"size": Vector2(1920, 1080), "tile_count": 8, "corner_reserve": MultiverseMinimap.DIAMETER})
	_assert_true(float(short_plan["log_height"]) < float(tall_plan["log_height"]) and float(short_plan["log_height"]) >= BattleHudLayout.LOG_MIN_HEIGHT, "on a short screen the log shrinks so the docks never overlap the mini map (%.0f vs %.0f)" % [float(short_plan["log_height"]), float(tall_plan["log_height"])])
	var camera: TacticsCamera = stage.camera_node()
	_assert_true(camera != null and camera.res.max_overview > 0.0 and camera.res.boundary_radius > 40.0, "the camera gains the overview dolly and a wider boundary under the rules")
	var before: Vector3 = camera.global_position
	stage.recentre_camera(Vector2i(0, 1), Vector2i(0, 2))
	_assert_true(camera.global_position.is_equal_approx(before), "with the field hidden a turn advance leaves the camera alone")
	stage.field_visible = true
	stage.recentre_camera(Vector2i(0, 1), Vector2i(0, 2))
	var snapped: bool = is_equal_approx(camera.global_position.x, stage.board_centre.x) and is_equal_approx(camera.global_position.z, stage.board_centre.z)
	_assert_true(snapped or camera.global_position.is_equal_approx(before - Vector3(MultiverseStage.pitch, 0.0, 0.0)), "re-centring on the next turn slides the camera back one pitch and pans it onto the live board (immediate mode snaps)")
	stage.recentre_camera(Vector2i(0, 2), Vector2i(0, 1))
	camera.global_position = before
	stage.field_visible = false
	var scale: float = minimap.layout_scale(mv.state, mv.state.timeline_ids())
	minimap.yaw = 0.0
	var right: Vector2 = minimap.project(Vector3(MultiverseStage.pitch, 0.0, 0.0), Vector2(100, 100), scale)
	var ahead: Vector2 = minimap.project(Vector3(0.0, 0.0, -MultiverseStage.pitch), Vector2(100, 100), scale)
	_assert_true(scale > 0.0 and right.x > 100.0 and is_equal_approx(right.y, 100.0) and ahead.y < 100.0, "the mini map projects the turn axis to the right and the camera's forward upward")
	await _play_rounds_until(2)
	_assert_true(level.round_index == 2 and not stage.field_visible and stage.past_markers.is_empty(), "after one round on a single timeline the field is still hidden")
	var palkia: TacticsPawn = await _wait_for_active("P1")
	_assert_true(palkia != null, "Palkia acts in round 2")
	var charmander: TacticsPawn = level.notation.pawn_for_id("E1")
	var rend: PokemonMoveResource = PokemonLearnsetService.load_move("spacial_rend")
	level._ops().damage(charmander, 9, {"kind": "hit", "attacker": palkia, "move": rend})
	BattleMoveSpecials.new().after_hit(null, palkia, charmander, rend, 9, true, level, level.battle_log)
	_assert_true(not mv.pending_travel.is_empty(), "Spacial Rend leaves a pending travel")
	mv.show_travel_preview()
	_assert_true(mv.preview_active and stage.preview_option_count == 1 and stage._preview_root != null and stage._preview_root.get_child_count() == 3, "the preview shows the torn universe's halo and one white arc per traveller (%d nodes)" % (stage._preview_root.get_child_count() if stage._preview_root != null else -1))
	mv.highlight_travel_option(0)
	var first_arc: MeshInstance3D = stage._preview_groups[0][0]
	_assert_true(is_equal_approx((first_arc.material_override as StandardMaterial3D).albedo_color.a, 0.95), "the highlighted option's arcs are bright")
	var focus_before: Vector2i = mv.state.focus
	var camera_before: Vector3 = camera.global_position
	_assert_true(mv.commit_travel(0), "the tear commits")
	await physics_frame
	await physics_frame
	_assert_true(not mv.preview_active and stage._preview_root == null, "committing clears the preview")
	_assert_true(stage.arcs.size() == 2 and stage.arcs[0]["from"] == focus_before and stage.arcs[0]["to"] == Vector2i(1, 2), "the travel leaves one persistent arc per traveller from L0 T2 to L+1 T2")
	_assert_true(fx.travels_played == 1 and fx.switches_played >= 1, "the ripple played once for the travel and the switch pulse for the return to L0 (%d, %d)" % [fx.travels_played, fx.switches_played])
	_assert_true(mv.state.focus == Vector2i(0, 2) and stage.boards.has(Vector2i(1, 2)) and stage.board_status(Vector2i(1, 2)) == MultiverseStage.STATUS_PENDING, "the new universe shows as a pending replica beside the live board")
	var replica: Node3D = stage.boards[Vector2i(1, 2)]["node"]
	_assert_true(replica.visible and replica.position.is_equal_approx(Vector3(0.0, 0.0, -MultiverseStage.pitch)) and (replica.get_node("Units") as Node3D).get_child_count() == 6, "the replica sits one row over and carries six ghost pawns, the copies plus the two arrivals")
	_assert_true(stage.field_visible and stage.connectors.has(1) and stage.bands.has(1) and stage.bands[0]["span"] == Vector2i(1, 2) and int(stage.past_markers[0]["count"]) == 1 and stage._live_halo.visible, "the first branch reveals the field: bands, the branch connector, one past marker on L0 and the live halo")
	_assert_true(camera.global_position.is_equal_approx(camera_before) or camera.global_position.distance_to(camera_before) < MultiverseStage.pitch * 2.5, "the camera stays within the compensated range after the switch there and back")
	var later: BattleUnit = await _next_active()
	_assert_true(later != null and later.pawn != null, "play continues on the origin board after the tear")
	var foe: TacticsPawn = _foe_of(later.pawn)
	level._ops().damage(foe, 3, {"kind": "hit", "attacker": later.pawn, "move": rend})
	BattleMoveSpecials.new().after_hit(null, later.pawn, foe, rend, 3, true, level, level.battle_log)
	mv.show_travel_preview()
	_assert_true(not mv.pending_travel.is_empty() and mv.preview_active and stage._preview_root != null, "a second request leaves a pending travel with its preview")
	await driver._end_turn(later.pawn)
	await physics_frame
	_assert_true(mv.pending_travel.is_empty() and not mv.preview_active and stage._preview_root == null, "ending the turn without choosing cancels the travel and removes its preview")
	var grown: float = minimap.fit_scale(mv.state, mv.state.timeline_ids())
	_assert_true(grown <= minimap.fit_scale(mv.state, [0]) and grown > 0.0 and grown <= MultiverseMinimap.CELL / MultiverseStage.pitch, "the mini map's fit never grows as the multiverse widens and never passes the cell size (%.2f)" % grown)
	var fov_saved: float = camera.res.current_fov
	var dolly_saved: float = camera.res.current_distance
	camera.res.current_fov = camera.res.min_zoom
	camera.res.current_distance = 0.0
	_assert_true(is_equal_approx(minimap.layout_scale(mv.state, mv.state.timeline_ids()), minimap.close_scale()) and minimap.close_scale() > grown, "at the camera's closest zoom the mini map zooms in past the fit, to the close scale")
	camera.res.current_fov = camera.res.max_zoom
	camera.res.current_distance = camera.res.max_overview
	_assert_true(is_equal_approx(minimap.layout_scale(mv.state, mv.state.timeline_ids()), grown), "at the camera's farthest zoom the mini map fits the whole multiverse")
	camera.res.current_fov = fov_saved
	camera.res.current_distance = dolly_saved
	var pan_before: Vector3 = camera.global_position
	var centre_before: Vector3 = minimap.view_centre(mv.state)
	camera.global_position = pan_before + Vector3(5.0, 0.0, -3.0)
	var centre_after: Vector3 = minimap.view_centre(mv.state)
	camera.global_position = pan_before
	_assert_true((centre_after - centre_before).is_equal_approx(Vector3(5.0, 0.0, -3.0)), "the mini map's centre pans with the camera")
	_finish()


func _wait_for_active(id: String) -> TacticsPawn:
	var guard: int = 0
	while guard < 40:
		var active: BattleUnit = await _next_active()
		if active == null:
			return null
		if level.notation.unit_id(active.pawn) == id:
			return active.pawn
		await _play_turn(active.pawn)
		guard += 1
	return null


func _play_rounds_until(round_target: int) -> void:
	var guard: int = 0
	while level.round_index < round_target and guard < 60:
		var active: BattleUnit = await _next_active()
		if active == null:
			break
		await _play_turn(active.pawn)
		guard += 1


func _next_active() -> BattleUnit:
	var frames: int = 0
	while frames < 600:
		var active: BattleUnit = level.scheduler.get_active_unit()
		if active != null and active.pawn != null and is_instance_valid(active.pawn) and not level.is_presentation_busy():
			return active
		if level.battle_finished:
			return null
		await physics_frame
		frames += 1
	return null


func _play_turn(pawn: TacticsPawn) -> void:
	var target: TacticsPawn = _foe_of(pawn)
	if target != null and pawn.stats.move_slots.size() > 1 and pawn.stats.has_pp(1) and Targeting.legal_targets_for_move(pawn, pawn.stats.move_slots[1], level.units_on_map()).has(target):
		await driver._attack(pawn, 1, target)
	await driver._end_turn(pawn)


func _foe_of(pawn: TacticsPawn) -> TacticsPawn:
	var foes: Node = level.opponent if pawn.get_parent() == level.player else level.player
	for child in foes.get_children():
		if child is TacticsPawn and (child as TacticsPawn).is_alive():
			return child
	return null


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)


func _finish() -> void:
	if failures > 0:
		push_error("smoke: multiverse_stage failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: multiverse_stage clean")
	quit(0)
