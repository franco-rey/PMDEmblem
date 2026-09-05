extends SceneTree

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const REPORT_PATH: String = "res://data/models/visuals/import_reports/vfx_coverage_report.json"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"
const VISUAL_KINDS: Array[String] = ["vfx_spawned", "vfx_after_image_scheduled", "vfx_column_spawned", "vfx_overlay", "vfx_screen_shake", "vfx_beam_spawned", "vfx_projectile_spawned"]

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=5 mode=pvp p=0006_charizard@50:flamethrower,earthquake,brick_break,extreme_speed:blaze e=0009_blastoise@50:hydro_pump,ice_beam,absorb,protect:torrent")
	_assert_true(ok, "coverage battle launches")
	if not ok:
		_finish()
		return
	var level: TacticsLevel = driver.level
	var runner: BattlePresentationRunner = level.presentation_runner
	var player: BattleVFXPlayer = level.vfx_player
	var log: BattleLog = level.battle_log
	var attacker: TacticsPawn = level.player.get_child(0)
	var target: TacticsPawn = level.opponent.get_child(0)
	var catalog: ActionPresentationCatalog = ActionPresentationCatalog.shared()
	_assert_true(runner != null and player != null and runner.immediate_mode, "runner and player present in immediate mode")
	var missing_moves: Array[String] = []
	var dir: DirAccess = DirAccess.open(GENERATED_MOVES_DIR)
	dir.list_dir_begin()
	var file: String = dir.get_next()
	while file != "":
		if file.ends_with(".tres") and not catalog.has_skill(file.trim_suffix(".tres")):
			missing_moves.append(file.trim_suffix(".tres"))
		file = dir.get_next()
	_assert_true(missing_moves.is_empty(), "every generated move has a presentation entry (%s)" % str(missing_moves.slice(0, 5)))
	var report: Dictionary = {"skills": {}, "summary": {}}
	var played: int = 0
	var silent_by_data: int = 0
	var silent_with_data: Array[String] = []
	var approximated: Dictionary = {}
	var skipped: Dictionary = {}
	var emitter_kinds: Dictionary = {}
	for skill_id in catalog.skill_ids():
		var entry: Dictionary = catalog.skill(skill_id)
		var move: PokemonMoveResource = load(GENERATED_MOVES_DIR + skill_id + ".tres") as PokemonMoveResource if ResourceLoader.exists(GENERATED_MOVES_DIR + skill_id + ".tres") else null
		if move == null:
			move = PokemonMoveResource.new()
			move.move_id = skill_id
		var start: int = log.events.size()
		BattleActionPresentation.enqueue_move_start(runner, attacker, target, [target], move, entry, "", log)
		BattleActionPresentation.enqueue_hit_fx(runner, entry, attacker, target, skill_id)
		BattleActionPresentation.enqueue_move_end(runner)
		runner.drain_immediately()
		var counts: Dictionary = {}
		for i in range(start, log.events.size()):
			var event: Dictionary = log.events[i]
			var kind: String = String(event.get("kind", ""))
			if kind.begins_with("vfx_"):
				counts[kind] = int(counts.get(kind, 0)) + 1
				if kind == "vfx_emitter_approximated":
					var name: String = String(event.get("emitter", ""))
					approximated[name] = int(approximated.get(name, 0)) + 1
				if kind == "vfx_skipped":
					var reason: String = String(event.get("reason", ""))
					skipped[reason] = int(skipped.get(reason, 0)) + 1
		var visual: int = 0
		for kind in VISUAL_KINDS:
			visual += int(counts.get(kind, 0))
		var has_data: bool = _entry_has_visual_data(entry, emitter_kinds)
		var status: String = "played" if visual > 0 else ("no_visual_data" if not has_data else "silent")
		if status == "played":
			played += 1
		elif status == "no_visual_data":
			silent_by_data += 1
		else:
			silent_with_data.append(skill_id)
		report["skills"][skill_id] = {"status": status, "hitbox": String((entry.get("hitbox", {}) as Dictionary).get("type", "")), "events": counts}
		for child in player.get_children():
			child.free()
		player._spawners.clear()
		log.events.resize(start)
	report["summary"] = {
		"skills": catalog.skill_ids().size(),
		"played": played,
		"no_visual_data": silent_by_data,
		"silent_with_data": silent_with_data,
		"approximated_emitters": approximated,
		"skipped": skipped,
		"emitter_types_seen": emitter_kinds,
	}
	_assert_true(_write_text(REPORT_PATH, JSON.stringify(report, "\t") + "\n"), "coverage report written to %s" % REPORT_PATH)
	_assert_true(approximated.is_empty(), "no emitter type falls back to the approximated path (%s)" % str(approximated))
	_assert_true(int(skipped.get("missing_asset", 0)) == 0, "no animation skipped for a missing asset (%s)" % str(skipped))
	_assert_true(silent_with_data.is_empty(), "every skill with visual data plays something (%d silent: %s)" % [silent_with_data.size(), str(silent_with_data.slice(0, 8))])
	_assert_true(played >= 500, "at least 500 skills play visuals (%d played, %d have no visual data)" % [played, silent_by_data])
	print("smoke: vfx coverage played=%d no_data=%d silent=%d approximated=%s skipped=%s" % [played, silent_by_data, silent_with_data.size(), str(approximated), str(skipped)])
	_finish()


func _entry_has_visual_data(entry: Dictionary, emitter_kinds: Dictionary) -> bool:
	var found: Array[bool] = [false]
	_scan(entry, found, emitter_kinds)
	return found[0]


func _scan(node: Variant, found: Array[bool], emitter_kinds: Dictionary) -> void:
	if node is Dictionary:
		var dict: Dictionary = node
		var type_name: String = String(dict.get("type", ""))
		if type_name.ends_with("Emitter") and not type_name.begins_with("Empty"):
			emitter_kinds[type_name] = int(emitter_kinds.get(type_name, 0)) + 1
			found[0] = true
		if dict.has("index") and dict.has("frame_time") and not String(dict.get("index", "")).is_empty():
			found[0] = true
		var movement: Variant = dict.get("screen_movement", null)
		if movement is Dictionary and float((movement as Dictionary).get("max_shake", 0)) > 0.0:
			found[0] = true
		for key in dict.keys():
			if key == "assets" or key == "events" or key == "missing_assets":
				continue
			_scan(dict[key], found, emitter_kinds)
	elif node is Array:
		for item in (node as Array):
			_scan(item, found, emitter_kinds)


func _write_text(path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


func _finish() -> void:
	if failures > 0:
		push_error("smoke: vfx_manifest_coverage failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: vfx_manifest_coverage clean")
	quit(0)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)
