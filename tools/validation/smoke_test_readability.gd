extends SceneTree

const DRIVER := preload("res://tools/debug/notation_driver.gd")

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=12 mode=pvp p=0006_charizard@50:flamethrower,slash,fly,dig:blaze e=0009_blastoise@50:hydro_pump,tackle:torrent|0003_venusaur@50:razor_leaf,tackle:overgrow")
	_assert_true(ok, "battle launches")
	if not ok:
		_finish()
		return
	var level: TacticsLevel = driver.level
	var main: Node = driver.main
	var attacker: TacticsPawn = level.notation.pawn_for_id("P1")
	var target: TacticsPawn = level.notation.pawn_for_id("E1")
	_assert_true(level.get_node_or_null("SkyEnvironment") != null and level.floating_text != null, "level carries the sky environment and the floating text node")
	attacker.serv.ui.update_character_health(attacker)
	var fill: Sprite3D = attacker.get_node_or_null("Character/CharacterUI/HpBarFill") as Sprite3D
	var back: Sprite3D = attacker.get_node_or_null("Character/CharacterUI/HpBarBack") as Sprite3D
	_assert_true(fill != null and back != null and is_equal_approx(fill.region_rect.size.x, 40.0) and fill.modulate == PmdStyle.hp_color(1.0), "full-health pawn shows a full green HP bar")
	target.stats.curr_health = int(target.stats.max_health * 0.3)
	target.serv.ui.update_character_health(target)
	var target_fill: Sprite3D = target.get_node("Character/CharacterUI/HpBarFill")
	_assert_true(target_fill.region_rect.size.x <= 13.0 and target_fill.modulate == PmdStyle.hp_color(0.3), "damaged pawn shows a shortened bar in the low colour (%.0f px)" % target_fill.region_rect.size.x)
	var hud: BattleHud = level.hud
	attacker.res.selected_move_index = 0
	var hint: String = hud._effectiveness_hint(attacker, target)
	_assert_true(hint.contains("dmg") and hint.contains("%"), "target panel estimates damage for the selected move (%s)" % hint.replace("\n", " | "))
	var popups_before: int = level.floating_text.spawned_total
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	var attacker_key: Vector3i = Targeting._tile_key(attacker.get_tile())
	for direction in [Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1)]:
		if keys.has(attacker_key + direction):
			var ray: RayCast3D = target.get_node("Tile")
			target.global_position = (keys[attacker_key + direction] as TacticsTile).global_position + Vector3.UP * 0.05
			ray.force_raycast_update()
			target.center()
			ray.force_raycast_update()
			break
	await physics_frame
	await physics_frame
	await driver._wait_for_turn(attacker)
	await driver._attack(attacker, 1, target)
	_assert_true(level.floating_text.spawned_total > popups_before, "a hit spawns a floating damage number")
	var participant: TacticsParticipantResource = level.participant.res
	participant.curr_pawn = attacker
	participant.stage = participant.STAGE_SHOW_MOVEMENTS
	await physics_frame
	await physics_frame
	var far: TacticsTile = null
	for key in keys.keys():
		var tile: TacticsTile = keys[key]
		if tile.reachable and tile.pf_distance >= 2 and tile.get_tile_occupier() == null:
			far = tile
			break
	_assert_true(far != null, "a reachable tile two steps away exists")
	if far != null:
		level.arena.mark_path_preview(far)
		var path_tiles: int = 0
		for key in keys.keys():
			if (keys[key] as TacticsTile).path:
				path_tiles += 1
		_assert_true(path_tiles >= 1 and not far.path, "hovering a far tile lights the tiles along its path (%d)" % path_tiles)
		level.arena.mark_committed(far)
		_assert_true(far.committed, "clicking a destination marks it committed")
		level.arena.reset_all_tile_markers()
		_assert_true(not far.committed and not far.path, "resetting markers clears path and committed states")
	participant.stage = participant.STAGE_SHOW_ACTIONS
	level.weather_overlay.set_weather("sandstorm")
	_assert_true(level.weather_overlay._sheet_overlay != null and level.weather_overlay._tint.visible, "sandstorm shows the scrolling sand sheet with a tint")
	level.weather_overlay.set_weather("delta_stream")
	_assert_true(level.weather_overlay._sheet_overlay != null, "delta stream shows the cloud sheet")
	level.weather_overlay.set_weather("primordial_sea")
	_assert_true(level.weather_overlay._field.visible and level.weather_overlay._sheet_overlay == null, "primordial sea reuses the rain field")
	level.weather_overlay.set_weather("")
	var lobby: SkirmishLobby = main.get_node("UI/SkirmishLobby")
	var row: Button = lobby._create_chooser_row({"id": "ember", "label": "Ember", "detail": "Fire Special  Pow 40", "icon_path": "", "type": "fire", "category": PokemonMoveResource.CATEGORY_SPECIAL})
	_assert_true(row.find_child("TypeBadge", true, false) != null, "move chooser rows carry a type badge")
	row.free()
	var faded: TacticsPawn = target
	level._ops().damage(faded, 9999, {"kind": "hit", "attacker": attacker})
	_assert_true(not faded.is_alive(), "state ops knock the target out")
	await create_timer(2.4).timeout
	var visuals: PawnStateVisuals = faded.get_node("StateVisuals")
	var sprite: Sprite3D = faded.get_node("Character")
	_assert_true(visuals.faint_alpha() < 0.05 and sprite.modulate.a < 0.05, "fainted pawn fades out after its faint hold (alpha %.2f)" % sprite.modulate.a)
	_finish()


func _finish() -> void:
	if failures > 0:
		push_error("smoke: readability failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: readability clean")
	quit(0)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)
