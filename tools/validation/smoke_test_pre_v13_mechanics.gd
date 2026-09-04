extends SceneTree

const BULBASAUR_PATH: String = "res://data/models/pokemon/generated/instances/0001_bulbasaur.tres"
const CHARMANDER_PATH: String = "res://data/models/pokemon/generated/instances/0004_charmander.tres"

class FakePawn:
	extends TacticsPawn
	var fake_tile: TacticsTile
	func get_tile() -> TacticsTile:
		return fake_tile

var failures: int = 0
var resolver := BattleActionResolver.new()


func _init() -> void:
	_check_imported_move_mappings()
	_check_static_idle_substitution()
	_check_runtime_effect_records()
	if failures > 0:
		push_error("smoke: pre-v13 mechanics failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: pre_v13_mechanics clean")
		quit(0)


func _check_imported_move_mappings() -> void:
	_assert_move_range("poison_jab", PokemonMoveResource.TacticalRangeKind.LINE, "DashAction maps to line")
	_assert_move_range("seed_bomb", PokemonMoveResource.TacticalRangeKind.PROJECTILE, "ThrowAction maps to projectile")
	_assert_move_range("solar_beam", PokemonMoveResource.TacticalRangeKind.LINE, "WaveMotionAction maps to line")
	_assert_record("fire_spin", "status", "status_id", "fire_spin", "OnHitEvent unwraps Fire Spin status")
	_assert_record("worry_seed", "ability_change", "target_ability", "insomnia", "ChangeToAbilityEvent maps to ability_change")
	_assert_record("rain_dance", "field_condition", "condition_id", "rain", "GiveMapStatusEvent maps to field condition")
	_assert_record("growth", "weather_stat_stage", "stat", "attack", "WeatherStackEvent maps to attack stage")
	_assert_record("growth", "weather_stat_stage", "stat", "special_attack", "WeatherStackEvent maps to special attack stage")


func _check_runtime_effect_records() -> void:
	var level: TacticsLevel = _fake_level()
	var attacker: FakePawn = _fake_pawn(BULBASAUR_PATH, "ReadinessAttacker", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn(CHARMANDER_PATH, "ReadinessDefender", Vector3(1, 0, 0))
	level.player.add_child(attacker)
	level.opponent.add_child(defender)

	var fire_spin := _move("fire_spin_probe", PokemonMoveResource.CATEGORY_SPECIAL, 20, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [
		{"family": "damage", "target": "hit_target"},
		{"family": "status", "target": "hit_target", "status_id": "fire_spin", "require_damage": true},
	])
	_use(attacker, defender, fire_spin, level)
	_assert_true(defender.stats.battle_statuses.has("fire_spin"), "Fire Spin-style OnHit status applies after damage")
	level.battle_log.events.clear()

	var worry_seed := _move("worry_seed_probe", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [
		{"family": "ability_change", "target": "hit_target", "target_ability": "insomnia"},
	])
	_use(attacker, defender, worry_seed, level)
	_assert_true(defender.stats.temporary_intrinsic_slugs.has("insomnia"), "Worry Seed-style ability change stores temporary intrinsic")
	_assert_true(BattleIntrinsicService.new().intrinsic_slugs_for(defender.stats).has("insomnia"), "temporary intrinsic participates in lookup")
	level.battle_log.events.clear()

	var sleep_probe := _move("sleep_probe", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [
		{"family": "status", "target": "hit_target", "status_id": "sleep"},
	])
	_use(attacker, defender, sleep_probe, level)
	_assert_true(not defender.stats.battle_statuses.has("sleep"), "insomnia blocks sleep status")
	_assert_true(_log_has(level.battle_log, "status_blocked"), "blocked status is logged")
	level.battle_log.events.clear()

	var rain_dance := _move("rain_dance_probe", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.SELF, PokemonMoveResource.TARGET_SELF, [
		{"family": "field_condition", "target": "field", "condition_id": "rain"},
	])
	_use(attacker, attacker, rain_dance, level)
	_assert_true(level.has_battle_condition("rain"), "Rain Dance-style field condition is stored")
	_assert_true(_log_has(level.battle_log, "field_condition_applied"), "field condition application is logged")
	level.battle_log.events.clear()

	var growth := _move("growth_probe", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.SELF, PokemonMoveResource.TARGET_SELF, [
		{"family": "weather_stat_stage", "target": "self", "weather_id": "sunny", "stat": "attack", "delta": 1, "weather_delta": 2},
	])
	attacker.stats.stat_stages = {}
	_use(attacker, attacker, growth, level)
	_assert_true(attacker.stats.get_stat_stage("attack") == 1, "Growth gives normal stage outside sun")
	level.set_battle_condition("sunny", {"source": "smoke"})
	attacker.stats.stat_stages = {}
	_use(attacker, attacker, growth, level)
	_assert_true(attacker.stats.get_stat_stage("attack") == 2, "Growth gives weather stage in sun")
	level.battle_log.events.clear()

	defender.stats.set_temporary_intrinsic("pressure")
	var pressure_move := _move("pressure_probe", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [
		{"family": "tactical_noop", "target": "self", "source_event": "smoke.noop"},
	])
	pressure_move.pp = 3
	_use(attacker, defender, pressure_move, level)
	_assert_true(attacker.stats.current_pp[0] == 1, "Pressure consumes one extra PP")
	_assert_true(_log_has_source(level.battle_log, "pp_decremented", "pressure"), "Pressure PP log emitted")
	level.battle_log.events.clear()
	level.free()


func _check_static_idle_substitution() -> void:
	var importer := PMDOImporter.new()
	var sprite_set := PokemonSpriteSetResource.new()
	sprite_set.idle_path = "res://assets/textures/actor/pokemon/0015_beedrill/idle.png"
	sprite_set.walk_path = "res://assets/textures/actor/pokemon/0015_beedrill/walk.png"
	var states: Dictionary = {
		"walk": {
			"path": sprite_set.walk_path,
			"source_name": "Walk",
			"source_filename": "Walk-Anim.png",
			"frame_count": 8,
			"timing": [1, 1, 1, 1, 1, 1, 1, 1],
		},
	}
	importer._apply_sprite_substitutions(states, sprite_set, {"sprite_substitutions": {"idle": "idle_static_from_walk"}})
	_assert_true(states.has("idle"), "idle substitution creates idle animation state")
	var idle: Dictionary = states.get("idle", {})
	_assert_true(int(idle.get("frame_count", 0)) == 1, "idle substitution uses a single Walk frame")
	_assert_true((idle.get("timing", []) as Array).is_empty(), "idle substitution clears Walk timing")
	_assert_true(String(idle.get("path", "")) == sprite_set.idle_path, "idle substitution points at idle sheet path")


func _assert_move_range(move_id: String, expected_kind: int, label: String) -> void:
	var move: PokemonMoveResource = _load_move(move_id)
	_assert_true(move != null, "%s resource exists" % move_id)
	if move == null:
		return
	_assert_true(move.tactical_range_kind == expected_kind, label)
	_assert_true(move.unsupported_effect_tags.is_empty(), "%s has no unsupported effect tags" % move_id)


func _assert_record(move_id: String, family: String, key: String, expected: String, label: String) -> void:
	var move: PokemonMoveResource = _load_move(move_id)
	_assert_true(move != null, "%s resource exists" % move_id)
	if move == null:
		return
	for record in move.effect_records:
		if String(record.get("family", "")) == family and String(record.get(key, "")) == expected:
			_assert_true(true, label)
			return
	_assert_true(false, label)


func _load_move(move_id: String) -> PokemonMoveResource:
	var path: String = "res://data/models/pokemon/generated/moves/%s.tres" % move_id
	return load(path) as PokemonMoveResource if ResourceLoader.exists(path) else null


func _use(attacker: FakePawn, defender: FakePawn, move: PokemonMoveResource, level: TacticsLevel) -> void:
	attacker.stats.move_slots = [move]
	attacker.stats.current_pp = [move.pp]
	resolver.execute(attacker, defender, 0, level)


func _fake_level() -> TacticsLevel:
	var level := TacticsLevel.new()
	level.player = TacticsPlayer.new()
	level.opponent = TacticsOpponent.new()
	level.battle_rng.seed = 321
	level.add_child(level.player)
	level.add_child(level.opponent)
	return level


func _fake_pawn(path: String, pawn_name: String, pos: Vector3) -> FakePawn:
	var instance: PokemonInstanceResource = load(path) as PokemonInstanceResource
	var pawn := FakePawn.new()
	pawn.name = pawn_name
	pawn.res = TacticsPawnResource.new()
	pawn.fake_tile = TacticsTile.new()
	pawn.fake_tile.position = pos
	pawn.add_child(pawn.fake_tile)
	pawn.stats = Stats.new()
	pawn.stats.init_from_pokemon(instance)
	pawn.add_child(pawn.stats)
	return pawn


func _move(move_id: String, category: int, power: int, range_kind: int, alignment: int, effects: Array[Dictionary]) -> PokemonMoveResource:
	var move := PokemonMoveResource.new()
	move.move_id = move_id
	move.name = move_id.capitalize()
	move.type = "normal"
	move.category = category
	move.base_power = power
	move.accuracy = PokemonMoveResource.ACCURACY_NEVER_MISS
	move.pp = 9
	move.tactical_range_kind = range_kind
	move.tactical_range_value = 1
	move.target_alignment = alignment
	move.effect_records = effects
	return move


func _log_has(log: BattleLog, kind: String) -> bool:
	for event in log.events:
		if event.get("kind", "") == kind:
			return true
	return false


func _log_has_source(log: BattleLog, kind: String, source: String) -> bool:
	for event in log.events:
		if event.get("kind", "") == kind and event.get("source", "") == source:
			return true
	return false


func _assert_true(value: bool, label: String) -> void:
	if value:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: fail - %s" % label)
