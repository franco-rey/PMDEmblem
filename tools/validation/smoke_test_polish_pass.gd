extends SmokeCase

const DRIVER := preload("res://tools/debug/notation_driver.gd")


func _run() -> void:
	GameSettings.load_settings()
	var saved_flair: bool = GameSettings.battle_flair
	var saved_danger: bool = GameSettings.danger_zone
	GameSettings.battle_flair = false
	GameSettings.danger_zone = true
	GameSettings.save_settings()
	GameSettings.battle_flair = true
	GameSettings.danger_zone = false
	GameSettings.load_settings()
	_assert_true(not GameSettings.battle_flair and GameSettings.danger_zone, "battle flair and danger zone settings round trip")
	GameSettings.battle_flair = true
	GameSettings.danger_zone = false
	GameSettings.save_settings()
	_assert_true(not BattleText.ability_description("intimidate").is_empty() and BattleText.ability_name("intimidate") == "Intimidate", "battle text carries ability descriptions from the PMDO strings")
	_assert_true(not BattleText.status_description("burn").is_empty(), "battle text carries status descriptions")
	var controls_panel := ControlsPanel.new()
	root.add_child(controls_panel)
	var rows: Array[Dictionary] = controls_panel.rows()
	var has_keys: bool = false
	for row in rows:
		if String(row["label"]) == "Danger zones" and String(row["keys"]).begins_with("Z"):
			has_keys = true
		if String(row["label"]).begins_with("Slow orbit") and not ("[" in String(row["keys"]) and "]" in String(row["keys"])):
			has_keys = false
	_assert_true(rows.size() >= 10 and has_keys, "controls page lists every action with its keys (%d rows)" % rows.size())
	controls_panel.queue_free()
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=9 mode=pvp p=0025_pikachu@50:thunderbolt,quick_attack:static:held_leftovers e=0004_charmander@50:ember,scratch:blaze|0001_bulbasaur@50:tackle:overgrow")
	_assert_true(ok, "battle launches for the polish checks")
	if not ok:
		_finish("polish_pass")
		return
	var level: TacticsLevel = driver.level
	var main: Node = driver.main
	var frames: int = 0
	while not level._scheduler_started and frames < 300:
		await process_frame
		frames += 1
	var hud: BattleHud = level.hud
	var pikachu: TacticsPawn = level.notation.pawn_for_id("P1")
	var charmander: TacticsPawn = level.notation.pawn_for_id("E1")
	var pause: PauseMenu = main.get_node("PauseMenu")
	_assert_true(pause._buttons.has("ControlsButton") and pause._controls != null, "pause menu offers a Controls page")
	_assert_true(pause._graphics.battle_flair_toggle != null and pause._graphics.controls_button != null, "options panel carries the Battle Flair toggle and a Controls button")
	_assert_true(main.get_node("UI/MapSelector/SkirmishMenu").get_node_or_null("ControlsButton") != null, "main menu has a Controls button")
	hud.inspect(charmander)
	var move_lines: Array[String] = hud.inspector_move_lines()
	var first_move_row: Node = hud._inspector_moves.get_child(0) if hud._inspector_moves.get_child_count() > 0 else null
	var move_icons: int = (first_move_row.get_child(0) as HBoxContainer).get_child_count() if first_move_row != null else 0
	_assert_true(hud._inspector.visible and hud._inspector_name.text.begins_with("Charmander") and hud._inspector_types.get_child_count() == 1 and "ATK" in hud._inspector_stats.text and move_lines.size() >= 2 and move_lines[0].begins_with("Ember") and "PP" in move_lines[0] and move_icons == 1 and hud._inspector_ability.text.begins_with("Ability: Blaze"), "inspector shows stats, moves with a type icon and PP, and the ability for any unit")
	charmander.stats.change_stat_stage("attack", 2)
	charmander.stats.apply_battle_status("burn", {"counter": 3})
	hud.inspect(charmander)
	_assert_true("ATK" in hud._inspector_stats.text and "+2" in hud._inspector_stats.text and hud._inspector_status.text.begins_with("Burn") and "(3)" in hud._inspector_status.text, "inspector shows stat stages and statuses with turns left (%s | %s)" % [hud._inspector_stats.text.replace("\n", " / "), hud._inspector_status.text])
	hud.pin(charmander)
	_assert_true(hud.pinned_pawn == charmander and not ("pinned" in hud._inspector_name.text), "a unit can be pinned in the inspector without a label")
	_assert_true(hud._inspector_close.visible, "a pinned inspector shows its close button")
	hud._inspector_close.pressed.emit()
	_assert_true(hud.pinned_pawn == null and not hud._inspector_close.visible, "the close button unpins and hides itself")
	_assert_true(TypeIconLibrary.texture_for("fire") != null and TypeIconLibrary.texture_for("nothing") == null, "type icons load from the element folder")
	_assert_true(hud.layout_size().x > 0.0, "the HUD measures its layout from the viewport")
	hud.refresh_active_panel()
	_assert_true(not hud._active_detail.tooltip_text.is_empty() and hud._active_detail.mouse_filter == Control.MOUSE_FILTER_PASS, "held item text is a tooltip on the active panel (%s)" % hud._active_detail.tooltip_text.left(40))
	var popup_events: Array = [
		["stat change", {"kind": "stat_stage_changed", "unit": pikachu, "stat": "speed", "before": 0, "after": 1, "delta": 1}, 1],
		["status applied", {"kind": "status_applied", "unit": pikachu, "status_id": "paralyze"}, 1],
		["ability callout", {"kind": "intrinsic_triggered", "unit": pikachu, "intrinsic_id": "static", "hook": "before_being_hit"}, 1],
		["repeated ability rate-limited", {"kind": "intrinsic_triggered", "unit": pikachu, "intrinsic_id": "static", "hook": "before_being_hit"}, 0],
		["held item callout", {"kind": "held_item_triggered", "unit": pikachu, "item_id": "held_leftovers", "hook": "turn_end"}, 1],
	]
	level.floating_text._recent.clear()
	for entry in popup_events:
		var before_count: int = level.floating_text.spawned_total
		level.battle_log.append(entry[1])
		var made: int = level.floating_text.spawned_total - before_count
		_assert_true(made == int(entry[2]), "%s pops %d text (%d)" % [String(entry[0]), int(entry[2]), made])
	var notices_before: int = level.banner.notices_shown
	GameSettings.battle_flair = true
	level.battle_log.append({"kind": "weather_started", "condition_id": "rain", "rounds": 5})
	_assert_true(level.banner.notices_shown == notices_before + 1 and level.banner._notice_chip.visible, "weather start shows a notice chip")
	level.banner.show_turn(3)
	_assert_true(level.banner._turn_panel.visible and level.banner._turn_label.text == "Turn 3", "turn banner shows the round")
	GameSettings.battle_flair = false
	level.banner.show_turn(4)
	_assert_true(level.banner.last_turn_shown == 3, "battle flair off skips the turn banner")
	GameSettings.battle_flair = true
	var definition := SkirmishDefinitionResource.new()
	definition.control_mode = SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER
	level.banner.show_intro(level, definition)
	_assert_true(level.intro_pending and level.banner.intro_active and level.banner._intro != null, "team intro opens and holds the scheduler")
	level.banner.finish_intro()
	_assert_true(not level.intro_pending and not level.banner.intro_active, "finishing the intro releases the scheduler")
	level.set_terrain("grassy_terrain", 5, "grassy_terrain")
	await process_frame
	_assert_true(level.terrain_overlay.current_terrain == "grassy_terrain" and level.terrain_overlay._decal != null and level.terrain_overlay._decal.visible and level.terrain_overlay._decal.size.x > 2.0, "grassy terrain paints a floor decal sized to the arena (%.1f x %.1f)" % [level.terrain_overlay._decal.size.x, level.terrain_overlay._decal.size.z])
	level.battle_conditions.erase("grassy_terrain")
	level.battle_log.append({"kind": "field_condition_ended", "condition_id": "grassy_terrain", "reason": "expired"})
	_assert_true(level.terrain_overlay.current_terrain.is_empty(), "terrain end clears the decal")
	hud.set_danger_enabled(true)
	_assert_true(hud.danger_enabled and hud.danger_tile_count > 0, "danger zone tints tiles enemies can reach and hit (%d tiles)" % hud.danger_tile_count)
	var flagged: int = 0
	for tile in level.arena.get_node("Tiles").get_children():
		if (tile as TacticsTile).danger:
			flagged += 1
	_assert_true(flagged == hud.danger_tile_count, "tile flags match the danger count")
	hud.set_danger_enabled(false)
	flagged = 0
	for tile in level.arena.get_node("Tiles").get_children():
		if (tile as TacticsTile).danger:
			flagged += 1
	_assert_true(flagged == 0, "disabling the danger zone clears every tile")
	var controls: TacticsControls = main.get_node("TacticsControls")
	controls.serv.ui_service.set_move_picker_visibility(true, pikachu, controls, level.units_on_map())
	var move_button: Button = controls.find_child("MoveSlot0", true, false) as Button
	_assert_true(move_button != null and "Pow" in move_button.tooltip_text and "Electric" in move_button.tooltip_text, "action menu move buttons carry a tooltip with power, accuracy, PP and text")
	var lobby: SkirmishLobby = main.get_node("UI/SkirmishLobby")
	var row: Button = lobby._create_chooser_row({"id": "thunderbolt", "label": "Thunderbolt", "detail": "", "icon_path": "", "type": "electric", "category": 2, "description": BattleText.move_summary(load("res://data/models/pokemon/generated/moves/thunderbolt.tres"))})
	_assert_true("Pow " in row.tooltip_text and "Acc " in row.tooltip_text, "lobby chooser rows carry move summaries in their tooltip (%s)" % row.tooltip_text.replace("\n", " / "))
	row.free()
	var before_hp: int = charmander.stats.curr_health
	var hits: Dictionary = level._ops().damage(charmander, 20, {"kind": "hit", "attacker": pikachu})
	var summary: Dictionary = level.stats_tracker.summary(pikachu)
	var taken: Dictionary = level.stats_tracker.summary(charmander)
	_assert_true(int(summary.get("dealt", 0)) >= 20 and int(taken.get("taken", 0)) >= 20, "stats tracker records damage dealt and taken (%d / %d)" % [int(summary.get("dealt", 0)), int(taken.get("taken", 0))])
	_assert_true(GameSettings.fitted_resolution(Vector2i(3840, 2160), Vector2i(1512, 950)) == Vector2i(1512, 950) and GameSettings.fitted_resolution(Vector2i(1920, 1080), Vector2i(3024, 1900)) == Vector2i(1920, 1080), "windowed resolution is clamped to the usable screen")
	_assert_true(hud.queue_scale_for(1512.0, 9) < 1.0 and hud.queue_scale_for(1512.0, 9) >= 0.6 and is_equal_approx(hud.queue_scale_for(1920.0, 9), 1.0), "queue tiles shrink on a laptop-wide window and stay full size at 1080p (%.2f)" % hud.queue_scale_for(1512.0, 9))
	hud._apply_layout(Vector2(1100, 700))
	var queue_bottom: float = hud._queue_column.offset_top + hud._queue_strip.custom_minimum_size.y
	var status_top: float = 700.0 + hud._status_dock.offset_top
	_assert_true(hud.stacked_layout_for(1100.0) and status_top >= queue_bottom + 4.0 and level.message_log.dock_height < BattleMessageLog.DOCK_SIZE.y, "a short stacked window shrinks the log so the status dock clears the queue box (%.0f >= %.0f, log %.0f)" % [status_top, queue_bottom, level.message_log.dock_height])
	_assert_true(16.0 + BattleMessageLog.dock_width_for(1100.0) + 24.0 <= 1100.0 - 16.0 - 438.0, "the log dock leaves room for the speed bar at narrow widths")
	hud._apply_layout(Vector2(1920, 1080))
	_assert_true(is_equal_approx(level.message_log.dock_height, BattleMessageLog.DOCK_SIZE.y), "a 1080p window restores the full log height")
	var results: BattleResultsScreen = main.get_node("BattleResultsScreen")
	results.show_result(1, definition, level)
	var stats_labels: Array = results.find_children("UnitStats", "Label", true, false)
	_assert_true(stats_labels.size() >= 3 and not results.notation_text().is_empty() and results._copy_button.visible, "results list per-unit damage lines and offer Copy Notation")
	results.hide_results()
	GameSettings.battle_flair = saved_flair
	GameSettings.danger_zone = saved_danger
	GameSettings.save_settings()
	_finish("polish_pass")
