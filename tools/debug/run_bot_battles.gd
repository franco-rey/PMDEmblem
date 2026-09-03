extends SceneTree

const MAP_PATH: String = "res://data/models/maps/definitions/test_arena.tres"
const OUTPUT_DIR: String = "res://logs/debug/validation"
const MAX_FRAMES: int = 24000
const TRACKED_KINDS: Array[String] = ["move_used", "damage_dealt", "miss", "status_applied", "status_tick", "status_removed", "stat_stage_changed", "healed", "weather_started", "weather_tick", "hazard_placed", "hazard_triggered", "intrinsic_triggered", "item_used", "item_thrown", "held_item_consumed", "unit_fainted", "move_rejected", "move_blocked", "effect_unsupported", "move_charging", "counter_triggered", "knocked_back", "forced_movement", "move_copied", "crash_damage", "turn_skipped"]

var summary: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var seed_range: PackedStringArray = _arg("seeds", "1-10").split("-")
	var first: int = int(seed_range[0])
	var last: int = int(seed_range[seed_range.size() - 1])
	var team_size: int = int(_arg("team", "3"))
	var round_cap: int = int(_arg("rounds", "40"))
	var with_items: bool = _arg("items", "1") == "1"
	var with_abilities: bool = _arg("abilities", "1") == "1"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for seed in range(first, last + 1):
		var result: Dictionary = await _battle(seed, team_size, round_cap, with_items, with_abilities)
		summary.append(result)
		print("bots: seed=%d result=%s rounds=%d frames=%d moves=%d faints=%d invariants=%s errors=%d" % [seed, str(result.get("result", "")), int(result.get("rounds", 0)), int(result.get("frames", 0)), int(result.get("moves_used_total", 0)), int(result.get("faints", 0)), str(result.get("invariant_failures", [])), int(result.get("error_count", 0))])
	var aggregate: Dictionary = _aggregate()
	var file := FileAccess.open("%s/bot_battles_%d_%d.json" % [OUTPUT_DIR, first, last], FileAccess.WRITE)
	file.store_string(JSON.stringify({"generated": Time.get_datetime_string_from_system(), "team_size": team_size, "round_cap": round_cap, "aggregate": aggregate, "battles": summary}, "\t"))
	file.close()
	print("bots: done %d battles -> %s" % [summary.size(), JSON.stringify(aggregate)])
	quit(0)


func _battle(seed: int, team_size: int, round_cap: int, with_items: bool, with_abilities: bool) -> Dictionary:
	var out: Dictionary = {"seed": seed, "invariant_failures": [], "error_count": 0}
	var built: Dictionary = CustomSkirmishBuilder.build_random(team_size, MAP_PATH, str(seed), SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU)
	if not bool(built.get("ok", false)):
		out["result"] = "build_failed"
		out["error"] = String(built.get("error", ""))
		return out
	var definition: SkirmishDefinitionResource = built["definition"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("validation:%d" % seed)
	var pool: Array[Dictionary] = BattleItemCatalog.entries()
	var loadout: Array[Dictionary] = []
	for side in [definition.player_team, definition.enemy_team]:
		for instance in side:
			if instance == null:
				continue
			if with_abilities:
				var abilities: Array[String] = CustomSkirmishBuilder.available_ability_ids(instance)
				if not abilities.is_empty():
					instance.ability_override = abilities[rng.randi_range(0, abilities.size() - 1)]
			if with_items and not pool.is_empty() and rng.randf() < 0.85:
				instance.held_item = PokemonItemService.load_item(String(pool[rng.randi_range(0, pool.size() - 1)].get("item_id", "")))
			var moves: Array[String] = []
			for move in instance.move_slots:
				moves.append(move.move_id if move != null else "")
			loadout.append({"species": instance.species.species_id if instance.species != null else "", "team": instance.team, "ability": instance.ability_override, "item": instance.held_item.item_id if instance.held_item != null else "", "moves": moves})
	out["loadout"] = loadout
	definition.skirmish_id = "validation_bots_%d" % seed
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var level: TacticsLevel = loader.load_skirmish(definition, root)
	if level == null:
		out["result"] = "load_failed"
		loader.queue_free()
		return out
	level.presentation_runner.immediate_mode = true
	level.process_mode = Node.PROCESS_MODE_ALWAYS
	var frames: int = 0
	var rounds: int = 0
	var last_round_marker: int = 0
	var ended: Array = [false, -1]
	level.battle_ended.connect(func(result: int) -> void:
		ended[0] = true
		ended[1] = result)
	while frames < MAX_FRAMES and not ended[0]:
		await physics_frame
		frames += 1
		var marker: int = _round_count(level)
		if marker != last_round_marker:
			last_round_marker = marker
			rounds = marker
			_check_invariants(level, out)
			if rounds >= round_cap:
				break
	out["frames"] = frames
	out["rounds"] = rounds
	if frames >= MAX_FRAMES and not ended[0]:
		var active: BattleUnit = level.scheduler.get_active_unit()
		var participant: TacticsParticipantResource = level.participant.res
		var stall: Dictionary = {
			"active": level.notation.unit_ref(active.pawn) if active != null and active.pawn != null else "none",
			"control": active.control_type if active != null else -1,
			"stage": participant.stage,
			"curr_pawn": str(participant.curr_pawn),
			"presentation_busy": level.is_presentation_busy(),
			"statuses": active.pawn.stats.battle_statuses.keys() if active != null and active.pawn != null and active.pawn.stats != null else [],
			"can_move": active.pawn.res.can_move if active != null and active.pawn != null else false,
			"can_attack": active.pawn.res.can_attack if active != null and active.pawn != null else false,
			"has_acted": active.pawn.res.has_acted_this_round if active != null and active.pawn != null else false,
			"is_moving": active.pawn.res.is_moving if active != null and active.pawn != null else false,
			"path": active.pawn.res.pathfinding_tilestack.size() if active != null and active.pawn != null else -1,
			"tail": level.notation.lines.slice(maxi(0, level.notation.lines.size() - 12)),
		}
		out["stall"] = stall
		print("bots: STALL seed=%d %s" % [seed, JSON.stringify(stall)])
		level.notation.save()
	out["result"] = ("player" if ended[1] == 1 else ("enemy" if ended[1] == 2 else "result_%d" % ended[1])) if ended[0] else "round_cap"
	_check_invariants(level, out)
	var kinds: Dictionary = {}
	var moves_used: Dictionary = {}
	var statuses: Dictionary = {}
	var intrinsics: Dictionary = {}
	var items: Dictionary = {}
	var rejected: Dictionary = {}
	var unsupported: Dictionary = {}
	var faints: int = 0
	for event in level.battle_log.events:
		var kind: String = String(event.get("kind", ""))
		if TRACKED_KINDS.has(kind):
			kinds[kind] = int(kinds.get(kind, 0)) + 1
		match kind:
			"move_used":
				moves_used[String(event.get("move_id", ""))] = int(moves_used.get(String(event.get("move_id", "")), 0)) + 1
			"status_applied":
				statuses[String(event.get("status_id", ""))] = int(statuses.get(String(event.get("status_id", "")), 0)) + 1
			"intrinsic_triggered":
				var slug: String = String(event.get("intrinsic_id", event.get("intrinsic", "")))
				intrinsics[slug] = int(intrinsics.get(slug, 0)) + 1
			"item_used", "item_thrown", "held_item_consumed", "held_item_stolen", "held_item_landed":
				items[String(event.get("item_id", ""))] = int(items.get(String(event.get("item_id", "")), 0)) + 1
			"move_rejected":
				var key: String = "%s:%s" % [String(event.get("move_id", "")), String(event.get("reason", ""))]
				rejected[key] = int(rejected.get(key, 0)) + 1
			"effect_unsupported":
				unsupported[String(event.get("move_id", ""))] = int(unsupported.get(String(event.get("move_id", "")), 0)) + 1
			"unit_fainted":
				faints += 1
			"damage_dealt":
				if int(event.get("amount", 0)) < 0:
					(out["invariant_failures"] as Array).append("negative damage %s" % String(event.get("move_id", "")))
		if event.has("item_id") and kind != "item_used" and kind != "item_thrown" and kind != "held_item_consumed" and kind != "held_item_stolen" and kind != "held_item_landed":
			var item_key: String = "%s:%s" % [String(event.get("item_id", "")), kind]
			items[item_key] = int(items.get(item_key, 0)) + 1
		if event.has("intrinsic_id") and kind != "intrinsic_triggered":
			var slug2: String = String(event.get("intrinsic_id", ""))
			if not slug2.is_empty():
				intrinsics[slug2] = int(intrinsics.get(slug2, 0)) + 1
	out["event_counts"] = kinds
	out["moves_used"] = moves_used
	out["moves_used_count"] = moves_used.size()
	out["moves_used_total"] = int(kinds.get("move_used", 0))
	out["moves_used"] = moves_used
	out["statuses"] = statuses
	out["intrinsics"] = intrinsics
	out["items"] = items
	out["rejected"] = rejected
	out["unsupported"] = unsupported
	out["faints"] = faints
	out["moves_used"] = moves_used
	out["notation"] = level.notation.output_path()
	out["final_hp"] = _final_hp(level)
	loader.unload_current()
	loader.queue_free()
	await process_frame
	return out


func _round_count(level: TacticsLevel) -> int:
	var count: int = 0
	for line in level.notation.lines:
		if String(line).begins_with("round "):
			count += 1
	return count if count > 0 else level.notation.turn_index


func _check_invariants(level: TacticsLevel, out: Dictionary) -> void:
	var failures: Array = out["invariant_failures"]
	for pawn in level.units_on_map():
		if pawn.stats == null:
			continue
		if pawn.stats.curr_health < 0 or pawn.stats.curr_health > pawn.stats.max_health:
			failures.append("hp out of range %s %d/%d" % [pawn.name, pawn.stats.curr_health, pawn.stats.max_health])
		for pp in pawn.stats.current_pp:
			if int(pp) < 0:
				failures.append("negative pp %s" % pawn.name)
		for stat in pawn.stats.stat_stages.keys():
			var stage: int = int(pawn.stats.stat_stages[stat])
			if stage < -6 or stage > 6:
				failures.append("stage out of range %s %s %d" % [pawn.name, String(stat), stage])
		if pawn.stats.curr_health == 0 and pawn.stats.is_active():
			failures.append("zero hp but active %s" % pawn.name)
		for status_id in pawn.stats.battle_statuses.keys():
			var payload: Variant = pawn.stats.battle_statuses[status_id]
			if payload is Dictionary and (payload as Dictionary).has("counter") and int((payload as Dictionary)["counter"]) < 0:
				failures.append("negative status counter %s %s" % [pawn.name, String(status_id)])


func _final_hp(level: TacticsLevel) -> Array:
	var out: Array = []
	for pawn in level.units_on_map():
		if pawn.stats != null:
			out.append({"unit": level.notation.unit_ref(pawn), "hp": pawn.stats.curr_health, "max": pawn.stats.max_health, "statuses": pawn.stats.battle_statuses.keys()})
	return out


func _aggregate() -> Dictionary:
	var results: Dictionary = {}
	var kinds: Dictionary = {}
	var moves: Dictionary = {}
	var statuses: Dictionary = {}
	var intrinsics: Dictionary = {}
	var items: Dictionary = {}
	var rejected: Dictionary = {}
	var unsupported: Dictionary = {}
	var invariant_failures: int = 0
	for battle in summary:
		results[String(battle.get("result", ""))] = int(results.get(String(battle.get("result", "")), 0)) + 1
		invariant_failures += (battle.get("invariant_failures", []) as Array).size()
		for table_name in ["event_counts", "moves_used", "statuses", "intrinsics", "items", "rejected", "unsupported"]:
			var source: Dictionary = battle.get(table_name, {})
			var target: Dictionary = {"event_counts": kinds, "moves_used": moves, "statuses": statuses, "intrinsics": intrinsics, "items": items, "rejected": rejected, "unsupported": unsupported}[table_name]
			for key in source.keys():
				target[key] = int(target.get(key, 0)) + int(source[key])
	return {"results": results, "invariant_failures": invariant_failures, "distinct_moves": moves.size(), "distinct_statuses": statuses.size(), "distinct_intrinsics": intrinsics.size(), "distinct_items": items.size(), "event_counts": kinds, "rejected": rejected, "unsupported": unsupported, "statuses": statuses, "intrinsics": intrinsics, "items": items, "moves": moves}


func _arg(name: String, fallback: String = "") -> String:
	for arg in OS.get_cmdline_user_args():
		var text: String = String(arg)
		if text.begins_with("--%s=" % name):
			return text.substr(name.length() + 3)
	return fallback
