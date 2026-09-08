extends SceneTree

const MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const SIM_SCRIPT_PATH: String = "res://data/models/world/combat/sim/battle_sim.gd"
const MOVE_DIR: String = "res://data/models/pokemon/generated/moves"
const OUTPUT_DIR: String = "res://logs/debug/fidelity"
const MAX_FRAMES: int = 24000
const PRESENTATION_PREFIXES: Array[String] = ["vfx_", "presentation_", "sound_", "animation_"]
const PRESENTATION_KINDS: Array[String] = [
	"animation_selected",
	"damage_popup",
	"after_image",
	"after_image_scheduled",
	"movement_timeout",
	"item_landed_visible",
	"item_use_pose",
]
const DROPPED_KEYS: Array[String] = [
	"anim",
	"asset_path",
	"at",
	"chosen_key",
	"frames",
	"layout",
	"lifetime",
	"requested_key",
	"rotate",
	"selection_tier",
	"source_state",
	"text",
]
const LEGALITY_KINDS: Array[String] = ["move_used", "move_rejected", "no_usable_move", "turn_skipped"]
const HP_KINDS: Array[String] = [
	"damage_dealt",
	"damage_prevented",
	"healed",
	"status_tick",
	"unit_fainted",
	"self_faint",
	"recoil",
	"crash_damage",
	"drain",
	"hazard_triggered",
	"hp_split",
	"item_healed",
	"substitute_hit",
]

var _move_cache: Dictionary = {}
var _hp_marks: Array = []
var _c_level: TacticsLevel = null
var _c_sim: Object = null
var _c_state: Variant = null
var _c_shadow: Variant = null
var _c_clone: String = "clone_deep"
var _c_probe: Dictionary = {}
var _c_turn: Dictionary = {}
var _c_pawns: Array[TacticsPawn] = []
var _c_totals: Dictionary = {}
var _c_battle: Dictionary = {}
var _c_worst: Array[Dictionary] = []
var _c_ready: bool = false
var _c_desynced: bool = false
var _c_seed: int = 0


func _init() -> void:
	call_deferred("_run")


func _arg(key: String, fallback: String = "") -> String:
	for argument in OS.get_cmdline_user_args():
		var text: String = String(argument)
		if text.begins_with("--%s=" % key):
			return text.split("=", true, 1)[1]
		if text == "--%s" % key:
			return "1"
	return fallback


func _run() -> void:
	DebugLog.set_debug_enabled(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var mode: String = _arg("mode", "compare")
	var failures: int = 0
	match mode:
		"trace":
			failures = await _mode_trace()
		"determinism":
			failures = await _mode_determinism()
		"census":
			failures = await _mode_census()
		"compare":
			failures = await _mode_compare()
		_:
			print("fidelity: unknown mode %s (trace|determinism|census|compare)" % mode)
			failures = 1
	print("fidelity: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _mode_trace() -> int:
	var seed: int = int(_arg("seed", "1"))
	var team_size: int = int(_arg("team", "3"))
	var run: Dictionary = await _run_real(seed, team_size, int(_arg("plevel", "3")), int(_arg("elevel", "3")))
	if not bool(run.get("ok", false)):
		print("fidelity: trace seed=%d failed reason=%s" % [seed, run.get("reason", "?")])
		return 1
	var path: String = "%s/trace_seed%d.json" % [OUTPUT_DIR, seed]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(run, "\t"))
		file.close()
	var notation_path: String = "%s/trace_seed%d.pmdn" % [OUTPUT_DIR, seed]
	var notation_file := FileAccess.open(notation_path, FileAccess.WRITE)
	if notation_file != null:
		notation_file.store_string(String(run.get("notation", "")))
		notation_file.close()
	print("fidelity: trace seed=%d events=%d result=%s rounds=%d ms=%d" % [
		seed,
		(run.get("trace", []) as Array).size(),
		run.get("result", "?"),
		int(run.get("rounds", 0)),
		int(run.get("ms", 0)),
	])
	print("fidelity: wrote %s and %s" % [path, notation_path])
	return 0


func _mode_determinism() -> int:
	var seeds: Array[int] = _seed_list()
	var repeats: int = maxi(2, int(_arg("repeats", "3")))
	var team_size: int = int(_arg("team", "3"))
	var failures: int = 0
	for seed in seeds:
		var baseline: Dictionary = {}
		for attempt in range(repeats):
			var run: Dictionary = await _run_real(seed, team_size, int(_arg("plevel", "3")), int(_arg("elevel", "3")))
			if not bool(run.get("ok", false)):
				print("fidelity: determinism seed=%d run=%d build failed %s" % [seed, attempt, run.get("reason", "?")])
				failures += 1
				continue
			if baseline.is_empty():
				baseline = run
				continue
			var report: Dictionary = _diff(baseline.get("trace", []), run.get("trace", []), "run0", "run%d" % attempt)
			if bool(report.get("identical", false)):
				print("fidelity: determinism seed=%d run=%d identical (%d events)" % [seed, attempt, int(report.get("matched", 0))])
			else:
				failures += 1
				print("fidelity: determinism seed=%d run=%d DIVERGED" % [seed, attempt])
				_print_divergence(report)
	return failures


func _mode_census() -> int:
	var seeds: Array[int] = _seed_list()
	var team_size: int = int(_arg("team", "3"))
	var battles: int = 0
	var totals: Dictionary = {}
	var battle_hits: Dictionary = {}
	var outcomes: Dictionary = {}
	var rounds_total: int = 0
	var damage_events: int = 0
	for seed in seeds:
		var run: Dictionary = await _run_real(seed, team_size, int(_arg("plevel", "3")), int(_arg("elevel", "3")))
		if not bool(run.get("ok", false)):
			continue
		battles += 1
		rounds_total += int(run.get("rounds", 0))
		var result: String = String(run.get("result", "draw"))
		outcomes[result] = int(outcomes.get(result, 0)) + 1
		var seen: Dictionary = {}
		for tag in _census_tags(run):
			totals[tag] = int(totals.get(tag, 0)) + 1
			seen[tag] = true
		for tag in seen.keys():
			battle_hits[tag] = int(battle_hits.get(tag, 0)) + 1
		for event in run.get("trace", []):
			if String((event as Dictionary).get("kind", "")) == "damage_dealt":
				damage_events += 1
		print("fidelity: census seed=%d result=%s rounds=%d events=%d" % [seed, result, int(run.get("rounds", 0)), (run.get("trace", []) as Array).size()])
	var rows: Array[Dictionary] = []
	for tag in totals.keys():
		rows.append({
			"tag": String(tag),
			"total": int(totals[tag]),
			"battles": int(battle_hits.get(tag, 0)),
			"battle_rate": float(battle_hits.get(tag, 0)) / float(maxi(1, battles)),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["battles"]) != int(b["battles"]):
			return int(a["battles"]) > int(b["battles"])
		if int(a["total"]) != int(b["total"]):
			return int(a["total"]) > int(b["total"])
		return String(a["tag"]) < String(b["tag"]))
	print("fidelity: census battles=%d damage_events=%d mean_rounds=%.2f outcomes=%s" % [battles, damage_events, float(rounds_total) / float(maxi(1, battles)), JSON.stringify(outcomes)])
	for row in rows:
		print("census\t%s\t%d\t%d\t%.4f" % [row["tag"], row["battles"], row["total"], row["battle_rate"]])
	var path: String = "%s/census_%s.json" % [OUTPUT_DIR, _arg("tag", "run")]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"battles": battles, "outcomes": outcomes, "rows": rows}, "\t"))
		file.close()
	print("fidelity: wrote %s" % path)
	return 0 if battles > 0 else 1


func _seed_list() -> Array[int]:
	var out: Array[int] = []
	var explicit: String = _arg("seeds", "")
	if not explicit.is_empty() and explicit.contains(","):
		for token in explicit.split(",", false):
			out.append(int(token))
		return out
	var count: int = int(explicit) if explicit.is_valid_int() else 4
	var first: int = int(_arg("seed", "1"))
	for i in range(count):
		out.append(first + i)
	return out


func _run_real(seed: int, team_size: int, player_level: int, enemy_level: int) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	var out: Dictionary = {"ok": false, "seed": seed, "team_size": team_size}
	var built: Dictionary = CustomSkirmishBuilder.build_random(team_size, MAP_PATH, str(seed), SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU)
	if not bool(built.get("ok", false)):
		out["reason"] = String(built.get("error", "build_failed"))
		return out
	var definition: SkirmishDefinitionResource = built["definition"]
	definition.skirmish_id = "fidelity_%d_%d_%d" % [seed, player_level, enemy_level]
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var level: TacticsLevel = loader.load_skirmish(definition, root)
	if level == null:
		out["reason"] = "load_failed"
		loader.queue_free()
		return out
	level.ai_team_levels = {
		PokemonInstanceResource.Team.PLAYER: AIProfile.clamp_level(player_level),
		PokemonInstanceResource.Team.ENEMY: AIProfile.clamp_level(enemy_level),
	}
	level.presentation_runner.immediate_mode = true
	level.process_mode = Node.PROCESS_MODE_ALWAYS
	if _arg("quiet", "1") == "1":
		level.battle_log.event_appended.disconnect(level._on_battle_event_appended)
		level.battle_log.event_appended.connect(func(event: Dictionary) -> void:
			level.notation.record(event))
	_hp_marks = []
	level.battle_log.event_appended.connect(func(event: Dictionary) -> void:
		if HP_KINDS.has(String(event.get("kind", ""))):
			_hp_marks.append(_hp_snapshot(level)))
	var ended: Array = [false, -1]
	level.battle_ended.connect(func(value: int) -> void:
		ended[0] = true
		ended[1] = value)
	var roster: Array[Dictionary] = []
	var frames: int = 0
	while frames < MAX_FRAMES and not ended[0]:
		await physics_frame
		frames += 1
		if roster.is_empty() and not level.notation.lines.is_empty():
			roster = _roster(level)
	out["ok"] = true
	out["frames"] = frames
	out["rounds"] = level.round_index
	out["result"] = _result_name(ended[0], int(ended[1]))
	out["roster"] = roster if not roster.is_empty() else _roster(level)
	out["trace"] = _canonicalise(level)
	out["final"] = _hp_snapshot(level)
	out["notation"] = level.notation.text()
	out["ms"] = Time.get_ticks_msec() - started
	level.queue_free()
	loader.queue_free()
	await process_frame
	await process_frame
	return out


func _result_name(ended: bool, code: int) -> String:
	if not ended:
		return "draw"
	if code == TacticsLevel.RESULT_PLAYER_WIN:
		return "player"
	if code == TacticsLevel.RESULT_PLAYER_LOSS:
		return "enemy"
	return "draw"


func _all_pawns(level: TacticsLevel) -> Array[TacticsPawn]:
	var out: Array[TacticsPawn] = []
	for team_node in [level.player, level.opponent]:
		if team_node == null:
			continue
		for child in team_node.get_children():
			if child is TacticsPawn and is_instance_valid(child):
				out.append(child)
	return out


func _hp_snapshot(level: TacticsLevel) -> Dictionary:
	var out: Dictionary = {}
	for pawn in _all_pawns(level):
		if pawn.stats == null:
			continue
		out[level.notation.unit_id(pawn)] = pawn.stats.curr_health
	return out


func _roster(level: TacticsLevel) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pawn in _all_pawns(level):
		var stats: Stats = pawn.stats
		var instance: PokemonInstanceResource = stats.pokemon_instance if stats != null else null
		var moves: Array[String] = []
		if stats != null:
			for move in stats.move_slots:
				if move != null:
					moves.append(String(move.move_id))
		var ability: String = ""
		if instance != null:
			ability = String(instance.ability_override)
		if ability.is_empty() and stats != null:
			var natural: Array[String] = BattleIntrinsicService.natural_slugs_static(stats)
			if not natural.is_empty():
				ability = natural[0]
		out.append({
			"id": level.notation.unit_id(pawn),
			"species": level.notation.species_slug(pawn),
			"level": stats.level if stats != null else 0,
			"max_health": stats.max_health if stats != null else 0,
			"tile": level.notation.label_for_pawn(pawn),
			"ability": ability,
			"item": String(instance.held_item.item_id) if instance != null and instance.held_item != null else "",
			"moves": moves,
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["id"]) < String(b["id"]))
	return out


func _canonicalise(level: TacticsLevel) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var mark: int = 0
	for index in range(level.battle_log.events.size()):
		var event: Dictionary = level.battle_log.events[index]
		var kind: String = String(event.get("kind", ""))
		if _is_presentation(kind):
			continue
		var canonical: Dictionary = {"kind": kind}
		var keys: Array = event.keys()
		keys.sort()
		for key in keys:
			var name: String = String(key)
			if name == "kind" or DROPPED_KEYS.has(name):
				continue
			canonical[name] = _canon_value(event[key], level)
		if HP_KINDS.has(kind):
			if mark < _hp_marks.size():
				canonical["hp"] = _hp_marks[mark]
			mark += 1
		out.append(canonical)
	return out


func _is_presentation(kind: String) -> bool:
	if PRESENTATION_KINDS.has(kind):
		return true
	for prefix in PRESENTATION_PREFIXES:
		if kind.begins_with(prefix):
			return true
	return false


func _canon_value(value: Variant, level: TacticsLevel) -> Variant:
	if value == null:
		return "-"
	if value is float:
		return snappedf(float(value), 0.0001)
	if value is int or value is bool or value is String or value is StringName:
		return value if not (value is StringName) else String(value)
	if value is Vector3i:
		return level.notation.tile_label(value)
	if value is Vector2i:
		var v: Vector2i = value
		return "L%dT%d" % [v.x, v.y]
	if value is Vector3:
		var w: Vector3 = value
		return "%.2f,%.2f,%.2f" % [w.x, w.y, w.z]
	if value is Array:
		var items: Array = []
		for entry in value:
			items.append(_canon_value(entry, level))
		return items
	if value is Dictionary:
		var nested: Dictionary = {}
		var keys: Array = (value as Dictionary).keys()
		keys.sort()
		for key in keys:
			if DROPPED_KEYS.has(String(key)):
				continue
			nested[String(key)] = _canon_value((value as Dictionary)[key], level)
		return nested
	if value is TacticsPawn or value is Stats:
		return level.notation.unit_id(value)
	if value is PokemonMoveResource:
		return String((value as PokemonMoveResource).move_id)
	if value is PokemonItemResource:
		return String((value as PokemonItemResource).item_id)
	if value is Resource:
		return String((value as Resource).resource_path).get_file()
	if value is Object:
		return (value as Object).get_class()
	return str(value)


func _signature(event: Dictionary) -> String:
	var keys: Array = event.keys()
	keys.sort()
	var tokens: PackedStringArray = []
	for key in keys:
		if String(key) == "hp":
			continue
		tokens.append("%s=%s" % [String(key), JSON.stringify(event[key])])
	return "|".join(tokens)


func _diff(left: Array, right: Array, left_name: String, right_name: String) -> Dictionary:
	var matched: int = 0
	var compared: int = maxi(left.size(), right.size())
	var first: Dictionary = {}
	var first_index: int = -1
	var damage_errors: Array[int] = []
	var legality_mismatch: int = 0
	var legality_total: int = 0
	var kind_mismatch: Dictionary = {}
	var hp_total: int = 0
	var hp_mismatch: int = 0
	var limit: int = mini(left.size(), right.size())
	for i in range(limit):
		var a: Dictionary = left[i]
		var b: Dictionary = right[i]
		if a.has("hp") and b.has("hp"):
			hp_total += 1
			if JSON.stringify(a["hp"]) != JSON.stringify(b["hp"]):
				hp_mismatch += 1
		var same: bool = _signature(a) == _signature(b)
		if same:
			matched += 1
		else:
			var kind_a: String = String(a.get("kind", ""))
			var kind_b: String = String(b.get("kind", ""))
			var pair: String = "%s vs %s" % [kind_a, kind_b]
			kind_mismatch[pair] = int(kind_mismatch.get(pair, 0)) + 1
			if first.is_empty():
				first_index = i
				first = {
					"index": i,
					left_name: a,
					right_name: b,
					"context": _context(left, right, i, left_name, right_name),
				}
		if String(a.get("kind", "")) == "damage_dealt" and String(b.get("kind", "")) == "damage_dealt":
			damage_errors.append(int(b.get("amount", 0)) - int(a.get("amount", 0)))
		if LEGALITY_KINDS.has(String(a.get("kind", ""))) or LEGALITY_KINDS.has(String(b.get("kind", ""))):
			legality_total += 1
			if String(a.get("kind", "")) != String(b.get("kind", "")) or String(a.get("move_id", "")) != String(b.get("move_id", "")) or String(a.get("reason", "")) != String(b.get("reason", "")):
				legality_mismatch += 1
	if left.size() != right.size() and first.is_empty():
		first_index = limit
		first = {
			"index": limit,
			left_name: left[limit] if limit < left.size() else {},
			right_name: right[limit] if limit < right.size() else {},
			"context": _context(left, right, limit, left_name, right_name),
			"reason": "length %s=%d %s=%d" % [left_name, left.size(), right_name, right.size()],
		}
	return {
		"identical": first.is_empty() and left.size() == right.size(),
		"matched": matched,
		"compared": compared,
		"first": first,
		"first_index": first_index,
		"damage_errors": damage_errors,
		"legality_mismatch": legality_mismatch,
		"legality_total": legality_total,
		"hp_mismatch": hp_mismatch,
		"hp_total": hp_total,
		"kind_mismatch": kind_mismatch,
		"left_size": left.size(),
		"right_size": right.size(),
	}


func _context(left: Array, right: Array, index: int, left_name: String, right_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(maxi(0, index - 4), index):
		out.append({"index": i, left_name: left[i] if i < left.size() else {}, right_name: right[i] if i < right.size() else {}})
	return out


func _print_divergence(report: Dictionary) -> void:
	var first: Dictionary = report.get("first", {})
	if first.is_empty():
		return
	for entry in first.get("context", []):
		print("fidelity:   context[%d] %s" % [int((entry as Dictionary).get("index", 0)), JSON.stringify(entry)])
	print("fidelity:   FIRST DIVERGENCE %s" % JSON.stringify(first))
	print("fidelity:   sizes left=%d right=%d matched=%d hp_mismatch=%d/%d" % [int(report.get("left_size", 0)), int(report.get("right_size", 0)), int(report.get("matched", 0)), int(report.get("hp_mismatch", 0)), int(report.get("hp_total", 0))])
	var kinds: Dictionary = report.get("kind_mismatch", {})
	if not kinds.is_empty():
		print("fidelity:   mismatch kinds %s" % JSON.stringify(kinds))


func _census_tags(run: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for entry in run.get("roster", []):
		var record: Dictionary = entry
		if not String(record.get("ability", "")).is_empty():
			out.append("roster_ability:%s" % record["ability"])
		if not String(record.get("item", "")).is_empty():
			out.append("roster_item:%s" % record["item"])
	for raw in run.get("trace", []):
		var event: Dictionary = raw
		var kind: String = String(event.get("kind", ""))
		out.append("event:%s" % kind)
		match kind:
			"intrinsic_triggered":
				out.append("ability:%s" % _text(event, "intrinsic_id"))
				out.append("ability_hook:%s" % _text(event, "hook"))
			"held_item_triggered", "held_item_consumed", "held_item_knocked_off", "held_item_stolen", "held_item_bestowed":
				out.append("held_item:%s" % _text(event, "item_id"))
			"item_used", "item_thrown", "item_hit_unit", "item_picked_up":
				out.append("item:%s" % _text(event, "item_id"))
			"status_applied", "status_tick", "status_blocked", "status_triggered", "status_removed":
				out.append("status:%s" % _text(event, "status_id"))
			"weather_started", "weather_tick", "weather_ended", "weather_failed":
				out.append("weather:%s" % _text(event, "condition_id"))
			"field_condition_applied", "field_condition_ended", "field_condition_failed":
				out.append("field:%s" % _text(event, "condition_id"))
			"hazard_placed", "hazard_triggered", "hazard_absorbed":
				out.append("hazard:%s" % _text(event, "hazard_id"))
			"stat_stage_changed":
				out.append("stat:%s" % _text(event, "stat"))
			"damage_dealt":
				out.append("damage_multiplier:%s" % _bucket(float(event.get("multiplier", 1.0))))
				if bool(event.get("critical", false)):
					out.append("damage:critical")
				if not is_equal_approx(float(event.get("weather_multiplier", 1.0)), 1.0):
					out.append("damage:weather_scaled")
				if not is_equal_approx(float(event.get("screen_multiplier", 1.0)), 1.0):
					out.append("damage:screen_scaled")
			"move_used":
				var move: PokemonMoveResource = _move(_text(event, "move_id"))
				if move != null:
					out.append("move_category:%s" % _category(move.category))
					out.append("move_range_kind:%d" % move.tactical_range_kind)
					for record in move.effect_records:
						out.append("move_family:%s" % String((record as Dictionary).get("family", "none")))
					if move.strike_count > 1:
						out.append("move_family:multi_hit")
					for flag in move.flags:
						out.append("move_flag:%s" % String(flag))
					if not move.unsupported_effect_tags.is_empty():
						out.append("move_family:unsupported_tag")
				out.append("move:%s" % _text(event, "move_id"))
			"move_rejected", "turn_skipped", "item_action_rejected":
				out.append("reject:%s" % _text(event, "reason"))
	return out


func _text(event: Dictionary, key: String) -> String:
	var value: String = String(event.get(key, "")).strip_edges()
	return value if not value.is_empty() else "none"


func _bucket(value: float) -> String:
	if value <= 0.0:
		return "immune"
	if value < 1.0:
		return "resisted"
	if value > 1.0:
		return "super"
	return "neutral"


func _category(value: int) -> String:
	if value == PokemonMoveResource.CATEGORY_PHYSICAL:
		return "physical"
	if value == PokemonMoveResource.CATEGORY_SPECIAL:
		return "special"
	return "status"


func _move(move_id: String) -> PokemonMoveResource:
	if _move_cache.has(move_id):
		return _move_cache[move_id]
	var path: String = "%s/%s.tres" % [MOVE_DIR, move_id]
	var resource: PokemonMoveResource = load(path) if ResourceLoader.exists(path) else null
	_move_cache[move_id] = resource
	return resource


func _print_contract() -> void:
	print("fidelity: expected simulator contract at %s" % SIM_SCRIPT_PATH)
	print("fidelity:   setup_from_level(level) -> state, capture(level) -> state, clone_deep/duplicate_state(state) -> state")
	print("fidelity:   legal_actions(state, unit) -> Array[Vector3i(tile, slot, target)], apply(state, action) -> state")
	print("fidelity:   set_rng_state(state, value), begin_trace(state), run_move(state, attacker, slot, target)")
	print("fidelity:   unit_hp/unit_position/unit_alive/active_unit/result/round_index accessors")
	print("fidelity:   tile_index dictionary keyed by Vector3i, trace_damage/trace_hits/trace_misses fields")
	print("fidelity:   unit order must equal player children then opponent children")


func _sim_ready(sim: Object) -> bool:
	for name in ["setup_from_level", "capture", "legal_actions", "apply", "set_rng_state", "begin_trace", "run_move", "unit_hp", "unit_position", "unit_alive", "active_unit", "result"]:
		if not sim.has_method(name):
			print("fidelity: simulator is missing method %s" % name)
			return false
	_c_clone = ""
	for name in ["clone_deep", "duplicate_state", "copy_state"]:
		if sim.has_method(name):
			_c_clone = name
			break
	if _c_clone.is_empty():
		print("fidelity: simulator is missing a state clone method (clone_deep/duplicate_state/copy_state)")
		return false
	return true


func _state_empty(state: Variant) -> bool:
	if state == null:
		return true
	if state is Dictionary:
		return (state as Dictionary).is_empty()
	if state is PackedInt32Array:
		return (state as PackedInt32Array).is_empty()
	return false


func _new_totals() -> Dictionary:
	return {
		"battles": 0,
		"state_units": 0,
		"state_hp": 0,
		"state_pos": 0,
		"state_alive": 0,
		"legality_checked": 0,
		"legality_chosen_illegal": 0,
		"legality_pairs_real": 0,
		"legality_missing": 0,
		"legality_extra": 0,
		"moves": 0,
		"moves_exact": 0,
		"damage_pairs": 0,
		"damage_abs_error": 0,
		"damage_max_error": 0,
		"damage_zero_vs_nonzero": 0,
		"hit_checked": 0,
		"hit_mismatch": 0,
		"ko_checked": 0,
		"ko_mismatch": 0,
		"turn_order_checked": 0,
		"turn_order_mismatch": 0,
		"lockstep_turns": 0,
		"lockstep_hp_mismatch": 0,
		"outcome_checked": 0,
		"outcome_agree": 0,
		"outcome_unfinished": 0,
		"err_0": 0,
		"err_1_3": 0,
		"err_4_10": 0,
		"err_11_50": 0,
		"err_51_up": 0,
	}


func _mode_compare() -> int:
	if not ResourceLoader.exists(SIM_SCRIPT_PATH):
		print("fidelity: simulator missing at %s" % SIM_SCRIPT_PATH)
		_print_contract()
		return 1
	var script: Script = load(SIM_SCRIPT_PATH)
	if script == null:
		print("fidelity: simulator failed to load (parse error?)")
		return 1
	var probe: Object = script.new()
	if probe == null or not _sim_ready(probe):
		_print_contract()
		return 1
	var seeds: Array[int] = _seed_list()
	var team_size: int = int(_arg("team", "3"))
	_c_totals = _new_totals()
	_c_worst = []
	var failures: int = 0
	for seed in seeds:
		var ok: bool = await _run_compare(script, seed, team_size, int(_arg("plevel", "3")), int(_arg("elevel", "3")))
		if not ok:
			failures += 1
	_report_compare()
	if int(_c_totals["state_hp"]) + int(_c_totals["state_pos"]) + int(_c_totals["state_alive"]) > 0:
		failures += 1
	if int(_c_totals["legality_chosen_illegal"]) > 0 or int(_c_totals["legality_missing"]) > 0 or int(_c_totals["legality_extra"]) > 0:
		failures += 1
	if int(_c_totals["moves"]) > int(_c_totals["moves_exact"]):
		failures += 1
	if int(_c_totals["hit_mismatch"]) > 0 or int(_c_totals["ko_mismatch"]) > 0:
		failures += 1
	if int(_c_totals["turn_order_mismatch"]) > 0:
		failures += 1
	return failures


func _report_compare() -> void:
	var t: Dictionary = _c_totals
	print("fidelity: compare battles=%d" % int(t["battles"]))
	print("fidelity: capture   units=%d hp_mismatch=%d pos_mismatch=%d alive_mismatch=%d" % [int(t["state_units"]), int(t["state_hp"]), int(t["state_pos"]), int(t["state_alive"])])
	print("fidelity: legality  actions=%d chosen_illegal=%d (%.4f) real_pairs=%d missing_in_sim=%d extra_in_sim=%d" % [
		int(t["legality_checked"]),
		int(t["legality_chosen_illegal"]),
		float(t["legality_chosen_illegal"]) / float(maxi(1, int(t["legality_checked"]))),
		int(t["legality_pairs_real"]),
		int(t["legality_missing"]),
		int(t["legality_extra"]),
	])
	print("fidelity: damage    moves=%d exact=%d (%.4f) pairs=%d mean_abs_error=%.4f max_abs_error=%d hard_misses=%d" % [
		int(t["moves"]),
		int(t["moves_exact"]),
		float(t["moves_exact"]) / float(maxi(1, int(t["moves"]))),
		int(t["damage_pairs"]),
		float(t["damage_abs_error"]) / float(maxi(1, int(t["damage_pairs"]))),
		int(t["damage_max_error"]),
		int(t["damage_zero_vs_nonzero"]),
	])
	print("fidelity: accuracy  checked=%d mismatch=%d (%.4f)" % [int(t["hit_checked"]), int(t["hit_mismatch"]), float(t["hit_mismatch"]) / float(maxi(1, int(t["hit_checked"])))])
	print("fidelity: knockouts checked=%d mismatch=%d (%.4f)" % [int(t["ko_checked"]), int(t["ko_mismatch"]), float(t["ko_mismatch"]) / float(maxi(1, int(t["ko_checked"])))])
	print("fidelity: turnorder checked=%d mismatch=%d (%.4f)" % [int(t["turn_order_checked"]), int(t["turn_order_mismatch"]), float(t["turn_order_mismatch"]) / float(maxi(1, int(t["turn_order_checked"])))])
	print("fidelity: lockstep  turns=%d hp_mismatch=%d (%.4f)" % [int(t["lockstep_turns"]), int(t["lockstep_hp_mismatch"]), float(t["lockstep_hp_mismatch"]) / float(maxi(1, int(t["lockstep_turns"])))])
	print("fidelity: dmg_hist  err0=%d err1-3=%d err4-10=%d err11-50=%d err51+=%d" % [int(t["err_0"]), int(t["err_1_3"]), int(t["err_4_10"]), int(t["err_11_50"]), int(t["err_51_up"])])
	print("fidelity: outcome   checked=%d agree=%d (%.4f) sim_unfinished=%d" % [int(t["outcome_checked"]), int(t["outcome_agree"]), float(t["outcome_agree"]) / float(maxi(1, int(t["outcome_checked"]))), int(t["outcome_unfinished"])])
	var shown: int = 0
	for entry in _c_worst:
		if shown >= int(_arg("worst", "12")):
			break
		shown += 1
		print("fidelity: divergence %s" % JSON.stringify(entry))
	var path: String = "%s/compare_%s.json" % [OUTPUT_DIR, _arg("tag", "run")]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"totals": _c_totals, "divergences": _c_worst}, "\t"))
		file.close()
	print("fidelity: wrote %s" % path)


func _run_compare(script: Script, seed: int, team_size: int, player_level: int, enemy_level: int) -> bool:
	var built: Dictionary = CustomSkirmishBuilder.build_random(team_size, MAP_PATH, str(seed), SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU)
	if not bool(built.get("ok", false)):
		print("fidelity: compare seed=%d build failed %s" % [seed, built.get("error", "?")])
		return false
	var definition: SkirmishDefinitionResource = built["definition"]
	definition.skirmish_id = "fidelity_cmp_%d" % seed
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var level: TacticsLevel = loader.load_skirmish(definition, root)
	if level == null:
		loader.queue_free()
		print("fidelity: compare seed=%d load failed" % seed)
		return false
	level.ai_team_levels = {
		PokemonInstanceResource.Team.PLAYER: AIProfile.clamp_level(player_level),
		PokemonInstanceResource.Team.ENEMY: AIProfile.clamp_level(enemy_level),
	}
	level.presentation_runner.immediate_mode = true
	level.process_mode = Node.PROCESS_MODE_ALWAYS
	level.battle_log.event_appended.disconnect(level._on_battle_event_appended)
	level.battle_log.event_appended.connect(func(event: Dictionary) -> void:
		level.notation.record(event))
	_c_level = level
	_c_seed = seed
	_c_sim = script.new()
	_c_state = null
	_c_shadow = null
	_c_ready = false
	_c_probe = {}
	_c_turn = {}
	_c_pawns = []
	_c_desynced = false
	_c_battle = _new_totals()
	level.battle_log.event_appended.connect(_on_compare_event)
	var ended: Array = [false, -1]
	level.battle_ended.connect(func(value: int) -> void:
		ended[0] = true
		ended[1] = value)
	var frames: int = 0
	while frames < MAX_FRAMES and not ended[0]:
		await physics_frame
		frames += 1
	_close_probe()
	_close_turn()
	var real_result: String = _result_name(ended[0], int(ended[1]))
	if _c_ready and not _state_empty(_c_shadow):
		var sim_result: String = _sim_result_name(int(_c_sim.result(_c_shadow)))
		if sim_result == "ongoing":
			_c_battle["outcome_unfinished"] = 1
		else:
			_c_battle["outcome_checked"] = 1
			if sim_result == real_result:
				_c_battle["outcome_agree"] = 1
			else:
				_note({"seed": seed, "what": "outcome", "real": real_result, "sim": sim_result})
	for key in _c_battle.keys():
		if key == "battles":
			continue
		_c_totals[key] = int(_c_totals[key]) + int(_c_battle[key])
	_c_totals["battles"] = int(_c_totals["battles"]) + 1
	print("fidelity: compare seed=%d result=%s moves=%d exact=%d turnorder_bad=%d lockstep_bad=%d capture_bad=%d" % [
		seed,
		real_result,
		int(_c_battle["moves"]),
		int(_c_battle["moves_exact"]),
		int(_c_battle["turn_order_mismatch"]),
		int(_c_battle["lockstep_hp_mismatch"]),
		int(_c_battle["state_hp"]) + int(_c_battle["state_pos"]) + int(_c_battle["state_alive"]),
	])
	_c_level = null
	_c_sim = null
	level.queue_free()
	loader.queue_free()
	await process_frame
	await process_frame
	return true


func _sim_result_name(code: int) -> String:
	if code == 1:
		return "player"
	if code == 2:
		return "enemy"
	if code == 3:
		return "draw"
	return "ongoing"


func _note(entry: Dictionary) -> void:
	if _c_worst.size() < 400:
		_c_worst.append(entry)


func _pawn_index(pawn: Variant) -> int:
	if not (pawn is TacticsPawn):
		return -1
	return _c_pawns.find(pawn)


func _on_compare_event(event: Dictionary) -> void:
	if _c_level == null or _c_sim == null:
		return
	var kind: String = String(event.get("kind", ""))
	match kind:
		"turn_started":
			_close_probe()
			_close_turn()
			_begin_turn(event)
		"move_attempted":
			_close_probe()
			_open_probe(event)
		"unit_move_started":
			if not _c_turn.is_empty() and _pawn_index(event.get("unit", null)) == int(_c_turn.get("unit", -1)):
				var tile: Variant = event.get("tile", null)
				if tile is Vector3i:
					_c_turn["dest"] = tile
		"damage_dealt":
			if not _c_probe.is_empty() and String(event.get("move_id", "")) == String(_c_probe.get("move_id", "")):
				var index: int = _pawn_index(event.get("defender", null))
				if index >= 0:
					var real: PackedInt32Array = _c_probe["real_damage"]
					real[index] = real[index] + int(event.get("amount", 0))
					_c_probe["real_damage"] = real
		"miss":
			if not _c_probe.is_empty() and String(event.get("move_id", "")) == String(_c_probe.get("move_id", "")):
				_c_probe["real_miss"] = int(_c_probe.get("real_miss", 0)) + 1
		"unit_fainted":
			if not _c_probe.is_empty():
				var index: int = _pawn_index(event.get("unit", null))
				if index >= 0:
					var ko: Dictionary = _c_probe["real_ko"]
					ko[index] = true
					_c_probe["real_ko"] = ko


func _ensure_sim() -> bool:
	if _c_level == null or _c_sim == null:
		return false
	if not _c_ready:
		_c_state = _c_sim.setup_from_level(_c_level)
		if _state_empty(_c_state):
			return false
		_c_pawns = _all_pawns(_c_level)
		_c_shadow = _c_sim.call(_c_clone, _c_state)
		_c_ready = true
		return true
	_c_state = _c_sim.capture(_c_level)
	return not _state_empty(_c_state)


func _begin_turn(event: Dictionary) -> void:
	if not _ensure_sim():
		return
	var unit: int = _pawn_index(event.get("unit", null))
	if unit < 0:
		return
	if not _state_empty(_c_shadow) and not _c_desynced:
		var active: int = int(_c_sim.active_unit(_c_shadow))
		_c_battle["turn_order_checked"] = int(_c_battle["turn_order_checked"]) + 1
		if active != unit:
			_c_battle["turn_order_mismatch"] = int(_c_battle["turn_order_mismatch"]) + 1
			_note({"seed": _c_seed, "what": "turn_order", "turn": int(_c_battle["lockstep_turns"]) + 1, "real_unit": _unit_label(unit), "sim_unit": _unit_label(active)})
			_c_desynced = true
	_c_turn = {"unit": unit, "dest": Targeting._tile_key(_c_pawns[unit].get_tile()), "slot": -1, "target": -1, "rng": _c_level.battle_rng.state}


func _close_turn() -> void:
	if _c_turn.is_empty() or _state_empty(_c_shadow) or _c_sim == null:
		return
	var turn: Dictionary = _c_turn
	_c_turn = {}
	var dest: int = int(_c_sim.tile_index.get(turn.get("dest", Vector3i.ZERO), -1))
	if dest < 0:
		return
	if _c_sim.has_method("is_over") and bool(_c_sim.is_over(_c_shadow)):
		return
	_c_sim.set_rng_state(_c_shadow, int(turn.get("rng", 0)))
	var advanced: Variant = _c_sim.apply(_c_shadow, Vector3i(dest, int(turn.get("slot", -1)), int(turn.get("target", -1))))
	if not _state_empty(advanced):
		_c_shadow = advanced
	_c_battle["lockstep_turns"] = int(_c_battle["lockstep_turns"]) + 1
	if _c_desynced:
		return
	for i in range(_c_pawns.size()):
		var pawn: TacticsPawn = _c_pawns[i]
		if pawn.stats == null:
			continue
		if int(_c_sim.unit_hp(_c_shadow, i)) != pawn.stats.curr_health:
			_c_battle["lockstep_hp_mismatch"] = int(_c_battle["lockstep_hp_mismatch"]) + 1
			_note({
				"seed": _c_seed,
				"what": "lockstep_hp",
				"turn": int(_c_battle["lockstep_turns"]),
				"unit": _unit_label(i),
				"real_hp": pawn.stats.curr_health,
				"sim_hp": int(_c_sim.unit_hp(_c_shadow, i)),
			})
			_c_desynced = true
			return


func _unit_label(index: int) -> String:
	if index < 0 or index >= _c_pawns.size() or _c_level == null:
		return "?"
	return _c_level.notation.unit_id(_c_pawns[index])


func _open_probe(event: Dictionary) -> void:
	if not _ensure_sim():
		return
	var attacker: int = _pawn_index(event.get("attacker", null))
	var target: int = _pawn_index(event.get("target", null))
	var slot: int = int(event.get("slot_index", -1))
	if attacker < 0 or target < 0 or slot < 0:
		return
	if not _c_turn.is_empty() and int(_c_turn.get("unit", -1)) == attacker:
		_c_turn["dest"] = Targeting._tile_key(_c_pawns[attacker].get_tile())
		_c_turn["slot"] = slot
		_c_turn["target"] = target
	_check_state()
	_check_legality(attacker, slot, target)
	var clone: Variant = _c_sim.call(_c_clone, _c_state)
	_c_sim.set_rng_state(clone, _c_level.battle_rng.state)
	_c_sim.begin_trace(clone)
	_c_sim.run_move(clone, attacker, slot, target)
	var predicted: PackedInt32Array = PackedInt32Array()
	predicted.resize(_c_pawns.size())
	var sim_ko: Dictionary = {}
	for i in range(_c_pawns.size()):
		predicted[i] = int((_c_sim.trace_damage as PackedInt32Array)[i]) if i < (_c_sim.trace_damage as PackedInt32Array).size() else 0
		if not bool(_c_sim.unit_alive(clone, i)) and bool(_c_sim.unit_alive(_c_state, i)):
			sim_ko[i] = true
	var real_damage: PackedInt32Array = PackedInt32Array()
	real_damage.resize(_c_pawns.size())
	_c_probe = {
		"move_id": String(event.get("move_id", "")),
		"attacker": attacker,
		"target": target,
		"slot": slot,
		"predicted": predicted,
		"sim_hits": int(_c_sim.trace_hits),
		"sim_misses": int(_c_sim.trace_misses),
		"sim_ko": sim_ko,
		"real_damage": real_damage,
		"real_ko": {},
		"real_miss": 0,
	}


func _close_probe() -> void:
	if _c_probe.is_empty():
		return
	var probe: Dictionary = _c_probe
	_c_probe = {}
	var predicted: PackedInt32Array = probe["predicted"]
	var real: PackedInt32Array = probe["real_damage"]
	var exact: bool = true
	var detail: Array[String] = []
	for i in range(real.size()):
		if predicted[i] == 0 and real[i] == 0:
			continue
		_c_battle["damage_pairs"] = int(_c_battle["damage_pairs"]) + 1
		var error: int = absi(predicted[i] - real[i])
		_c_battle["damage_abs_error"] = int(_c_battle["damage_abs_error"]) + error
		_c_battle["damage_max_error"] = maxi(int(_c_battle["damage_max_error"]), error)
		if error == 0:
			_c_battle["err_0"] = int(_c_battle["err_0"]) + 1
		elif error <= 3:
			_c_battle["err_1_3"] = int(_c_battle["err_1_3"]) + 1
		elif error <= 10:
			_c_battle["err_4_10"] = int(_c_battle["err_4_10"]) + 1
		elif error <= 50:
			_c_battle["err_11_50"] = int(_c_battle["err_11_50"]) + 1
		else:
			_c_battle["err_51_up"] = int(_c_battle["err_51_up"]) + 1
		if (predicted[i] == 0) != (real[i] == 0):
			_c_battle["damage_zero_vs_nonzero"] = int(_c_battle["damage_zero_vs_nonzero"]) + 1
		if error != 0:
			exact = false
			detail.append("%s real=%d sim=%d" % [_unit_label(i), real[i], predicted[i]])
	_c_battle["moves"] = int(_c_battle["moves"]) + 1
	if exact:
		_c_battle["moves_exact"] = int(_c_battle["moves_exact"]) + 1
	else:
		_note({
			"seed": _c_seed,
			"what": "damage",
			"move_id": String(probe["move_id"]),
			"attacker": _unit_label(int(probe["attacker"])),
			"declared": _unit_label(int(probe["target"])),
			"slot": int(probe["slot"]),
			"detail": detail,
		})
	_c_battle["hit_checked"] = int(_c_battle["hit_checked"]) + 1
	if (int(probe["real_miss"]) > 0) != (int(probe["sim_misses"]) > 0):
		_c_battle["hit_mismatch"] = int(_c_battle["hit_mismatch"]) + 1
		_note({
			"seed": _c_seed,
			"what": "accuracy",
			"move_id": String(probe["move_id"]),
			"attacker": _unit_label(int(probe["attacker"])),
			"real_misses": int(probe["real_miss"]),
			"sim_misses": int(probe["sim_misses"]),
		})
	var real_ko: Dictionary = probe["real_ko"]
	var sim_ko: Dictionary = probe["sim_ko"]
	_c_battle["ko_checked"] = int(_c_battle["ko_checked"]) + 1
	var real_keys: Array = real_ko.keys()
	var sim_keys: Array = sim_ko.keys()
	real_keys.sort()
	sim_keys.sort()
	if JSON.stringify(real_keys) != JSON.stringify(sim_keys):
		_c_battle["ko_mismatch"] = int(_c_battle["ko_mismatch"]) + 1
		_note({
			"seed": _c_seed,
			"what": "knockout",
			"move_id": String(probe["move_id"]),
			"attacker": _unit_label(int(probe["attacker"])),
			"real_ko": real_keys,
			"sim_ko": sim_keys,
		})


func _check_state() -> void:
	for i in range(_c_pawns.size()):
		var pawn: TacticsPawn = _c_pawns[i]
		if pawn.stats == null:
			continue
		_c_battle["state_units"] = int(_c_battle["state_units"]) + 1
		if int(_c_sim.unit_hp(_c_state, i)) != pawn.stats.curr_health:
			_c_battle["state_hp"] = int(_c_battle["state_hp"]) + 1
			_note({"seed": _c_seed, "what": "capture_hp", "unit": _unit_label(i), "real": pawn.stats.curr_health, "sim": int(_c_sim.unit_hp(_c_state, i))})
		if bool(_c_sim.unit_alive(_c_state, i)) != pawn.stats.is_active():
			_c_battle["state_alive"] = int(_c_battle["state_alive"]) + 1
			_note({"seed": _c_seed, "what": "capture_alive", "unit": _unit_label(i), "real": pawn.stats.is_active(), "sim": bool(_c_sim.unit_alive(_c_state, i))})
		if pawn.get_tile() == null:
			continue
		var key: Vector3i = Targeting._tile_key(pawn.get_tile())
		var sim_key: Vector3i = _c_sim.unit_position(_c_state, i)
		if pawn.stats.is_active() and (sim_key.x != key.x or sim_key.z != key.z):
			_c_battle["state_pos"] = int(_c_battle["state_pos"]) + 1
			_note({"seed": _c_seed, "what": "capture_pos", "unit": _unit_label(i), "real": _c_level.notation.tile_label(key), "sim": _c_level.notation.tile_label(sim_key)})


func _check_legality(attacker: int, slot: int, target: int) -> void:
	var pawn: TacticsPawn = _c_pawns[attacker]
	if pawn.get_tile() == null or pawn.stats == null:
		return
	var here: int = int(_c_sim.tile_index.get(Targeting._tile_key(pawn.get_tile()), -1))
	if here < 0:
		return
	var sim_pairs: Dictionary = {}
	for action in _c_sim.legal_actions(_c_state, attacker):
		var value: Vector3i = action
		if value.x == here and value.y >= 0 and value.z >= 0:
			sim_pairs["%d:%d" % [value.y, value.z]] = true
	var real_pairs: Dictionary = {}
	var units: Array[TacticsPawn] = _c_level.units_on_map()
	for index in range(pawn.stats.move_slots.size()):
		var move: PokemonMoveResource = pawn.stats.move_slots[index]
		if move == null or not pawn.stats.has_pp(index):
			continue
		for candidate in Targeting.legal_targets_for_move(pawn, move, units):
			var other: int = _pawn_index(candidate)
			if other >= 0:
				real_pairs["%d:%d" % [index, other]] = true
	_c_battle["legality_checked"] = int(_c_battle["legality_checked"]) + 1
	_c_battle["legality_pairs_real"] = int(_c_battle["legality_pairs_real"]) + real_pairs.size()
	var chosen: String = "%d:%d" % [slot, target]
	if not sim_pairs.has(chosen):
		_c_battle["legality_chosen_illegal"] = int(_c_battle["legality_chosen_illegal"]) + 1
		_note({"seed": _c_seed, "what": "legality_chosen", "unit": _unit_label(attacker), "slot": slot, "target": _unit_label(target), "move_id": String(pawn.stats.move_slots[slot].move_id) if slot < pawn.stats.move_slots.size() and pawn.stats.move_slots[slot] != null else "?"})
	var missing: Array[String] = []
	for key in real_pairs.keys():
		if not sim_pairs.has(key):
			missing.append(_pair_label(pawn, String(key)))
	var extra: Array[String] = []
	for key in sim_pairs.keys():
		if not real_pairs.has(key):
			extra.append(_pair_label(pawn, String(key)))
	_c_battle["legality_missing"] = int(_c_battle["legality_missing"]) + missing.size()
	_c_battle["legality_extra"] = int(_c_battle["legality_extra"]) + extra.size()
	if not missing.is_empty() or not extra.is_empty():
		_note({"seed": _c_seed, "what": "legality_set", "unit": _unit_label(attacker), "missing_in_sim": missing, "extra_in_sim": extra})


func _pair_label(pawn: TacticsPawn, key: String) -> String:
	var parts: PackedStringArray = key.split(":")
	var slot: int = int(parts[0])
	var target: int = int(parts[1])
	var move_id: String = "?"
	if pawn.stats != null and slot < pawn.stats.move_slots.size() and pawn.stats.move_slots[slot] != null:
		move_id = String(pawn.stats.move_slots[slot].move_id)
	return "%s->%s" % [move_id, _unit_label(target)]
