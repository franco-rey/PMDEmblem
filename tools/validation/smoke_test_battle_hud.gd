extends SceneTree

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const CODE: String = "match seed=9 mode=pvp p=0006_charizard@50:flamethrower,slash,growl,ember:blaze|0025_pikachu@50:thunder_shock,quick_attack,growl,tail_whip:static e=0009_blastoise@50:water_gun,tackle,withdraw,bite:torrent|0143_snorlax@50:tackle,rest,yawn,crunch:thick_fat"

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch(CODE)
	_assert_true(ok, "2v2 launches")
	if not ok:
		_finish()
		return
	var level: TacticsLevel = driver.level
	var hud: BattleHud = level.hud
	_assert_true(hud != null and hud.get_node_or_null("HudRoot") != null, "battle HUD is attached to the level")
	var active: BattleUnit = level.scheduler.get_active_unit()
	var queue: Array[TacticsPawn] = hud.queue_pawns()
	_assert_true(queue.size() == 4 and queue[0] == active.pawn, "queue lists all four units with the active unit first (%d)" % queue.size())
	await process_frame
	var strip: HBoxContainer = hud.get_node("HudRoot/QueueColumn/QueueStrip/QueueRow")
	_assert_true(strip.get_child_count() >= 4, "queue strip shows a tile per unit (%d children)" % strip.get_child_count())
	var first_tile: Control = strip.get_child(0)
	var portrait: TextureRect = first_tile.find_child("Portrait", true, false)
	_assert_true(portrait != null and portrait.texture != null, "active tile carries a portrait texture")
	_assert_true(hud.expression_for(active.pawn) == "Determined", "active unit shows the determined portrait (%s)" % hud.expression_for(active.pawn))
	var active_panel: Control = hud.get_node("HudRoot/ActivePanel")
	_assert_true(active_panel.visible and (hud.get_node("HudRoot/ActivePanel").find_child("ActiveName", true, false) as Label).text.begins_with(level.notation.unit_name(active.pawn)), "active panel names the acting unit")
	var attacker: TacticsPawn = active.pawn
	var foes: Array = level.opponent.get_children() if attacker.get_parent() == level.player else level.player.get_children()
	var target: TacticsPawn = foes[0]
	var log_lines_before: int = level.message_log.history.size()
	await driver._approach(attacker, target) if driver.has_method("_approach") else null
	var arena: TacticsArena = level.arena
	arena.reset_all_tile_markers()
	arena.process_surrounding_tiles(attacker.get_tile(), attacker.stats.movement, attacker.get_parent().get_children())
	arena.mark_reachable_tiles(attacker.get_tile(), attacker.stats.movement)
	var tile: TacticsTile = arena.get_nearest_target_adjacent_tile(attacker, [target])
	if tile != null and tile != attacker.get_tile():
		await driver._move(attacker, level.notation.tile_label(Targeting._tile_key(tile)))
	var slot: int = 0
	for i in range(attacker.stats.move_slots.size()):
		if attacker.stats.move_slots[i] != null and attacker.stats.move_slots[i].is_damaging():
			slot = i
			break
	hud._on_event({"kind": "move_used", "attacker": attacker, "move_id": attacker.stats.move_slots[slot].move_id})
	_assert_true(hud.mood_for(attacker) == "Angry", "attacker portrait goes angry on a damaging move (%s)" % hud.mood_for(attacker))
	hud._on_event({"kind": "damage_dealt", "defender": target, "attacker": attacker, "amount": 10})
	_assert_true(hud.mood_for(target) == "Pain", "hit unit shows the pain portrait (%s)" % hud.mood_for(target))
	hud._on_event({"kind": "healed", "unit": target, "amount": 5})
	_assert_true(hud.mood_for(target) == "Happy", "healed unit shows the happy portrait")
	hud._on_event({"kind": "stat_stage_changed", "unit": attacker, "delta": -1})
	_assert_true(hud.mood_for(attacker) == "Sad", "stat drop shows the sad portrait")
	await driver._attack(attacker, slot, target)
	_assert_true(level.message_log.history.size() > log_lines_before, "log dock received the attack messages (%d -> %d)" % [log_lines_before, level.message_log.history.size()])
	var lines: VBoxContainer = level.message_log.get_node("LogDock").find_child("Lines", true, false)
	_assert_true(lines != null and lines.get_child_count() == mini(level.message_log.history.size(), BattleMessageLog.MAX_VISIBLE), "dock shows one label per message (%d)" % (lines.get_child_count() if lines != null else -1))
	hud._on_event({"kind": "weather_started", "condition_id": "rain", "rounds": 5})
	var lobby_scene: PackedScene = load("res://data/modules/skirmish/skirmish_lobby.tscn") if ResourceLoader.exists("res://data/modules/skirmish/skirmish_lobby.tscn") else null
	_assert_true(hud.get_node("HudRoot/WeatherChip").visible and (hud.get_node("HudRoot/WeatherChip/WeatherLabel") as Label).text == "Rain (5)", "weather chip shows the condition and rounds")
	target.stats.curr_health = 0
	hud._on_event({"kind": "unit_fainted", "unit": target})
	_assert_true(hud.expression_for(target) == "Crying", "fainted unit shows the crying portrait")
	_assert_true(PortraitLibrary.texture_for("0006_charizard", "Angry") != PortraitLibrary.texture_for("0006_charizard", "Normal") and PortraitLibrary.texture_for("0006_charizard", "NoSuchFace") == PortraitLibrary.texture_for("0006_charizard", "Normal"), "portrait library resolves expressions and falls back to Normal")
	_assert_true(root.theme != null and root.theme.get_stylebox("normal", "Button") is StyleBoxFlat, "root theme carries the PMD button style")
	_finish()


func _finish() -> void:
	if failures > 0:
		push_error("smoke: battle_hud failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: battle_hud clean")
	quit(0)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)
