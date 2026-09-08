extends SceneTree

const MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const TUNING = preload("res://tools/debug/run_weight_tuning.gd")


class VUnitValue:
	extends BattleAI

	var w: Dictionary = TUNING.BASE_WEIGHTS

	func _unit_value(pawn: TacticsPawn) -> float:
		if pawn == null or pawn.stats == null:
			return 0.0
		var offence: float = float(maxi(pawn.stats.attack, pawn.stats.special_attack))
		var durability: float = float(pawn.stats.max_health)
		return float(w["VALUE_OFFENCE_WEIGHT"]) * offence + float(w["VALUE_DURABILITY_WEIGHT"]) * durability


class VSupportScore:
	extends BattleAI

	var w: Dictionary = TUNING.BASE_WEIGHTS

	func _support_score(unit: TacticsPawn, move: PokemonMoveResource, target: TacticsPawn) -> float:
		var fam: Dictionary = _families(move)
		var score: float = 0.0
		if fam.has("status:hit_target") and target != unit and profile.consider_status_moves:
			if target.stats != null and target.stats.battle_statuses.is_empty():
				score += float(w["STATUS_SCORE"])
		if fam.has("stat_raise:self") or (fam.has("stat_stage") and target == unit and not fam.has("stat_drop:self")):
			if profile.consider_setup_moves:
				score += float(w["SETUP_SCORE"]) * _setup_headroom(unit)
		elif fam.has("stat_drop:hit_target") and target != unit and profile.consider_status_moves:
			score += float(w["STATUS_SCORE"]) * 0.6 * _setup_headroom(target)
		if (fam.has("field_condition") or fam.has("weather_stat_stage")) and profile.consider_field_moves and not _field_already_set(move):
			score += float(w["FIELD_SCORE"])
		if fam.has("heal") or fam.has("cure_statuses") or fam.has("status_remove"):
			if target != null and target.stats != null and target.stats.max_health > 0:
				var missing: float = 1.0 - float(target.stats.curr_health) / float(target.stats.max_health)
				score += float(w["STATUS_SCORE"]) * missing
		return score


class VTargetPreference:
	extends BattleAI

	var w: Dictionary = TUNING.BASE_WEIGHTS

	func _target_preference(unit: TacticsPawn, target: TacticsPawn, retaliation: Dictionary) -> float:
		if target == null or target.stats == null or target.stats.max_health <= 0:
			return 0.0
		var hp_fraction: float = float(target.stats.curr_health) / float(target.stats.max_health)
		match profile.target_mode:
			AIProfile.TargetMode.NEAREST:
				return -float(_manhattan(_key_of(unit), _key_of(target))) * float(w["NEAREST_WEIGHT"])
			AIProfile.TargetMode.WEAKEST:
				return -100.0 * hp_fraction * float(w["WEAKEST_WEIGHT"])
			AIProfile.TargetMode.MATCHUP:
				return 0.0
			AIProfile.TargetMode.SECURE_KO:
				return -100.0 * hp_fraction * float(w["SECURE_WEIGHT"])
			AIProfile.TargetMode.EXPECTED_VALUE:
				return -100.0 * hp_fraction * float(w["SECURE_WEIGHT"])
		return 0.0


class VDamageValue:
	extends BattleAI

	var w: Dictionary = TUNING.BASE_WEIGHTS

	func _damage_value(
			unit: TacticsPawn,
			move: PokemonMoveResource,
			index: int,
			target: TacticsPawn,
			key: Vector3i,
			damage_table: Dictionary,
			foes: Array[TacticsPawn],
			friends: Array[TacticsPawn],
			focus: TacticsPawn
	) -> float:
		var total: float = 0.0
		for hit in _targets_hit(unit, move, key, target, foes, friends):
			if hit == null or hit.stats == null:
				continue
			var remaining: float = maxf(1.0, float(hit.stats.curr_health))
			var value: float = 0.0
			var shape: Dictionary = (_shapes.get(index, {}) as Dictionary).get(hit, {})
			if profile.use_ko_probability and not shape.is_empty():
				var chance: float = 0.0 if _survives_lethal(hit, move) else _ko_chance(shape, remaining)
				var mean: float = float(shape.get("mean", 0.0))
				if mean <= 0.0:
					continue
				var share: float = _unit_value(hit) / _reference_value if profile.value_weighted else 1.0
				var chip: float = minf(mean / remaining, 1.0)
				value = 100.0 * share * (chance + (1.0 - chance) * float(w["CHIP_WEIGHT"]) * chip)
				if chance > 0.0 and profile.turn_order_aware and _acts_before(unit, hit):
					value += float(w["TEMPO_BONUS"]) * chance
			else:
				var expected: float = _expected_for(unit, move, index, hit, damage_table)
				if expected <= 0.0:
					continue
				value = 100.0 * minf(expected / remaining, 1.0)
				if expected >= remaining and profile.target_mode >= AIProfile.TargetMode.SECURE_KO:
					value += float(w["KO_BONUS"])
					if profile.turn_order_aware and _acts_before(unit, hit):
						value += float(w["TEMPO_BONUS"])
			if profile.shared_focus and focus != null and hit == focus:
				value *= float(w["FOCUS_GAIN"])
			total += value
		return total


class VActionScore:
	extends BattleAI

	var w: Dictionary = TUNING.BASE_WEIGHTS

	func _action_score(
			unit: TacticsPawn,
			move: PokemonMoveResource,
			index: int,
			target: TacticsPawn,
			key: Vector3i,
			damage_table: Dictionary,
			retaliation: Dictionary,
			focus: TacticsPawn,
			foes: Array[TacticsPawn],
			friends: Array[TacticsPawn]
	) -> float:
		var hostile: bool = foes.has(target)
		var base: float = 0.0
		var modifiers: float = 0.0
		if move.is_damaging():
			if not hostile:
				return INVALID_SCORE
			match profile.move_mode:
				AIProfile.MoveMode.SLOT_ORDER:
					base = 60.0 - float(index)
				AIProfile.MoveMode.RAW_POWER:
					var chart_gain: float = _damage._effectiveness(move, target.stats, _chart) if target.stats != null else 1.0
					if chart_gain <= 0.0:
						return INVALID_SCORE
					base = float(move.base_power) * _accuracy_of(move) * chart_gain
				AIProfile.MoveMode.EXPECTED_DAMAGE:
					base = _damage_value(unit, move, index, target, key, damage_table, foes, friends, focus)
			if base <= 0.0:
				return INVALID_SCORE
			if profile.target_mode >= AIProfile.TargetMode.EXPECTED_VALUE and not _is_lethal(unit, move, index, target, damage_table):
				var pool: float = maxf(1.0, float(unit.stats.max_health))
				modifiers -= float(w["RETALIATION_WEIGHT"]) * 100.0 * minf(float(retaliation.get(target, 0.0)) / pool, 1.0)
		else:
			base = _support_score(unit, move, target)
			if base <= 0.0:
				return INVALID_SCORE
		if hostile:
			modifiers += _target_preference(unit, target, retaliation)
			if not move.is_damaging() and profile.shared_focus and focus != null and target == focus:
				modifiers += float(w["FOCUS_BONUS"])
		return base + modifiers


class VPositionalScore:
	extends BattleAI

	var w: Dictionary = TUNING.BASE_WEIGHTS

	func _positional_score(
			unit: TacticsPawn,
			key: Vector3i,
			origin: Vector3i,
			foes: Array[TacticsPawn],
			focus: TacticsPawn,
			threat: Array,
			battle_level: TacticsLevel,
			engaging: bool
	) -> float:
		var score: float = 0.0
		if profile.avoid_hazards and battle_level != null and battle_level.hazard_service != null:
			if battle_level.hazard_service.threatens(unit, key):
				score -= float(w["HAZARD_PENALTY"])
		var retreating: bool = false
		if profile.retreat_when_losing and not engaging and unit.stats != null and unit.stats.max_health > 0:
			retreating = float(unit.stats.curr_health) / float(unit.stats.max_health) < float(w["RETREAT_HP_FRACTION"])
		if profile.threat_aware and engaging:
			var pool: float = maxf(1.0, float(unit.stats.curr_health)) if unit.stats != null else 1.0
			var spread: float = _threat_at(key, threat)
			var worst: float = _worst_single(key, threat)
			var chip: float = minf(spread / pool, 1.0)
			var combined: float = maxf(worst, _raw_threat_at(key, threat))
			var band: float = maxf(0.0001, float(w["LETHAL_BAND"]))
			var lethal: float = clampf(combined / pool - float(w["LETHAL_FLOOR"]), 0.0, band) / band
			score -= profile.risk_weight * (float(w["CHIP_RISK"]) * chip + float(w["LETHAL_RISK"]) * lethal)
			if retreating and spread <= 0.0:
				score += float(w["RETREAT_BONUS"])
		var anchor: TacticsPawn = focus if (profile.focus_fire_staging and focus != null and not engaging) else _nearest(unit, foes)
		if anchor != null:
			var distance: int = _manhattan(key, _key_of(anchor))
			if retreating:
				score += profile.approach_weight * float(w["APPROACH_SCALE"]) * float(distance) * 0.5
			else:
				score -= profile.approach_weight * float(w["APPROACH_SCALE"]) * float(distance)
		if profile.zone_control:
			score += _formation_bonus(unit, key)
		if key == origin:
			score += 0.5
		return score


class VFormationBonus:
	extends BattleAI

	var w: Dictionary = TUNING.BASE_WEIGHTS

	func _formation_bonus(unit: TacticsPawn, key: Vector3i) -> float:
		var parent: Node = unit.get_parent()
		if parent == null:
			return 0.0
		var nearby: int = 0
		for child in parent.get_children():
			if not (child is TacticsPawn) or child == unit:
				continue
			var ally: TacticsPawn = child
			if not ally.is_alive():
				continue
			if _manhattan(key, _key_of(ally)) <= 2:
				nearby += 1
		return float(w["ZONE_BONUS"]) * minf(float(nearby), 2.0)


class VFocusTarget:
	extends BattleAI

	var w: Dictionary = TUNING.BASE_WEIGHTS

	func _focus_target(
			unit: TacticsPawn,
			friends: Array[TacticsPawn],
			foes: Array[TacticsPawn],
			damage_table: Dictionary,
			type_chart: TypeChartResource
	) -> TacticsPawn:
		if not profile.shared_focus or foes.is_empty():
			return null
		var team: int = _team_of(unit)
		var round_key: int = _level_ref.round_index if _level_ref != null else -1
		var held: Dictionary = _focus_cache.get(team, {})
		if int(held.get("round", -9999)) == round_key:
			var kept: Variant = held.get("target", null)
			if kept != null and is_instance_valid(kept) and (kept as TacticsPawn).is_alive() and foes.has(kept):
				return kept
		var best: TacticsPawn = null
		var best_score: float = -INF
		for foe in foes:
			var score: float = 0.0
			if profile.team_assignment:
				var incoming: float = 0.0
				var hands: int = 0
				for friend in friends:
					if friend == null or not friend.is_alive():
						continue
					if not _within_window(friend, foe):
						continue
					hands += 1
					incoming += _best_output(friend, foe, type_chart)
				var remaining: float = maxf(1.0, float(foe.stats.curr_health))
				score = 100.0 * minf(incoming / remaining, 1.5)
				score += float(w["WINDOW_BONUS"]) * float(hands)
				score += 100.0 * (_unit_value(foe) / _reference_value) * 0.15
			else:
				score = -float(foe.stats.curr_health)
			if score > best_score:
				best_score = score
				best = foe
		_focus_cache[team] = {"round": round_key, "target": best}
		return best


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DebugLog.set_debug_enabled(false)
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var chart: TypeChartResource = load("res://data/models/pokemon/generated/types/type_chart.tres")
	var names: Array[String] = ["unit_value", "support_score", "target_preference", "damage_value", "action_score", "positional_score", "formation_bonus", "focus_target", "full"]
	var totals: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0]
	var count: int = 0
	for seed in range(1, 6):
		var built: Dictionary = CustomSkirmishBuilder.build_random(4, MAP_PATH, str(seed), SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU)
		if not bool(built.get("ok", false)):
			continue
		var definition: SkirmishDefinitionResource = built["definition"]
		definition.skirmish_id = "zz_var_%d" % seed
		var level: TacticsLevel = loader.load_skirmish(definition, root)
		if level == null:
			continue
		level.ai_team_levels = {PokemonInstanceResource.Team.PLAYER: 5, PokemonInstanceResource.Team.ENEMY: 5}
		level.presentation_runner.immediate_mode = true
		level.process_mode = Node.PROCESS_MODE_ALWAYS
		var frames: int = 0
		while frames < 400 and not level._scheduler_started:
			await physics_frame
			frames += 1
		level.process_mode = Node.PROCESS_MODE_DISABLED
		var brains: Array = [VUnitValue.new(), VSupportScore.new(), VTargetPreference.new(), VDamageValue.new(), VActionScore.new(), VPositionalScore.new(), VFormationBonus.new(), VFocusTarget.new(), TUNING.TunedAI.new()]
		(brains[8] as Object).set("team_weights", {PokemonInstanceResource.Team.PLAYER: TUNING.BASE_WEIGHTS, PokemonInstanceResource.Team.ENEMY: TUNING.BASE_WEIGHTS})
		var stock := BattleAI.new()
		stock.set_team_levels(level.ai_team_levels)
		for brain in brains:
			brain.set_team_levels(level.ai_team_levels)
		var pawns: Array[TacticsPawn] = []
		for node in [level.player, level.opponent]:
			for child in node.get_children():
				if child is TacticsPawn:
					pawns.append(child)
		for index in range(pawns.size()):
			var pawn: TacticsPawn = pawns[index]
			var allies: Array = []
			var enemies: Array = []
			for other in pawns:
				if level.pawn_team(other) == level.pawn_team(pawn):
					allies.append(other)
				else:
					enemies.append(other)
			var mark: Callable = func() -> void:
				level.arena.reset_all_tile_markers()
				level.arena.process_surrounding_tiles(pawn.get_tile(), pawn.stats.movement, allies)
				level.arena.mark_reachable_tiles(pawn.get_tile(), pawn.stats.movement)
			mark.call()
			stock.forget(pawn)
			var a: AIAction = stock.choose_action(pawn, allies, enemies, chart, level)
			count += 1
			for i in range(brains.size()):
				mark.call()
				brains[i].forget(pawn)
				var b: AIAction = brains[i].choose_action(pawn, allies, enemies, chart, level)
				if a.move_index == b.move_index and a.target_unit == b.target_unit and a.move_to_tile == b.move_to_tile:
					totals[i] += 1
		level.queue_free()
		await process_frame
	for i in range(names.size()):
		print("zz: %-18s agree=%d/%d" % [names[i], totals[i], count])
	quit(0)
