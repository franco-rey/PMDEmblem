extends SceneTree
## M6 smoke: deterministic move effect families.

const ATTACKER_PATH: String = "res://data/models/pokemon/generated/instances/0004_charmander.tres"
const DEFENDER_PATH: String = "res://data/models/pokemon/overrides/instances/0467_magmortar.tres"

class FakePawn:
	extends TacticsPawn
	var fake_tile: TacticsTile
	func get_tile() -> TacticsTile:
		return fake_tile

var failures: int = 0
var resolver := BattleActionResolver.new()


func _init() -> void:
	_check_damage_status_stat_heal_recoil_fixed_percent()
	_check_multi_hit()
	_check_recoil_faint()
	_check_area_targets()
	if failures > 0:
		push_error("smoke: move effects failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: move_effects clean")
		quit(0)


func _check_damage_status_stat_heal_recoil_fixed_percent() -> void:
	var level: TacticsLevel = _fake_level()
	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "Attacker", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn(DEFENDER_PATH, "Defender", Vector3(1, 0, 0))
	level.player.add_child(attacker)
	level.opponent.add_child(defender)

	var move := _move("combo", PokemonMoveResource.CATEGORY_PHYSICAL, 50, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [
		{"family": "damage", "target": "hit_target"},
		{"family": "status", "target": "hit_target", "status_id": "poison"},
		{"family": "stat_stage", "target": "hit_target", "stat": "defense", "delta": -1},
		{"family": "recoil", "target": "self", "fraction": 6, "max_hp": true},
		{"family": "fixed_damage", "target": "hit_target", "amount": 7},
		{"family": "percent_damage", "target": "hit_target", "percent": 0.1},
	])
	attacker.stats.move_slots = [move]
	attacker.stats.current_pp = [move.pp]
	var before_attacker_hp: int = attacker.stats.curr_health
	var before_defender_hp: int = defender.stats.curr_health
	resolver.execute(attacker, defender, 0, level)
	_assert_true(defender.stats.curr_health < before_defender_hp, "damage/fixed/percent damage changed defender HP")
	_assert_true(attacker.stats.curr_health < before_attacker_hp, "recoil changed attacker HP")
	_assert_true(defender.stats.battle_statuses.has("poison"), "status applied")
	_assert_true(defender.stats.get_stat_stage("defense") == -1, "stat stage dropped")
	_assert_true(_log_has(level.battle_log, "status_applied"), "status_applied logged")
	_assert_true(_log_has(level.battle_log, "stat_stage_changed"), "stat_stage_changed logged")

	var heal := _move("heal", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.SELF, PokemonMoveResource.TARGET_SELF, [
		{"family": "heal", "target": "self", "hp_divisor": 4},
	])
	attacker.stats.move_slots = [heal]
	attacker.stats.current_pp = [heal.pp]
	var hurt_hp: int = attacker.stats.curr_health
	resolver.execute(attacker, attacker, 0, level)
	_assert_true(attacker.stats.curr_health > hurt_hp, "heal restored HP")
	_assert_true(_log_has(level.battle_log, "healed"), "healed logged")
	level.free()


func _check_multi_hit() -> void:
	var level: TacticsLevel = _fake_level()
	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "MultiAttacker", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn(DEFENDER_PATH, "MultiDefender", Vector3(1, 0, 0))
	level.player.add_child(attacker)
	level.opponent.add_child(defender)
	var move := _move("triple_hit", PokemonMoveResource.CATEGORY_PHYSICAL, 10, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [
		{"family": "multi_hit", "target": "hit_target"},
		{"family": "damage", "target": "hit_target"},
	])
	move.strike_count = 3
	attacker.stats.move_slots = [move]
	attacker.stats.current_pp = [move.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(_count_events(level.battle_log, "damage_dealt") >= 3, "multi-hit deals repeated damage")
	level.free()


func _check_recoil_faint() -> void:
	var level: TacticsLevel = _fake_level()
	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "RecoilAttacker", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn(DEFENDER_PATH, "RecoilDefender", Vector3(1, 0, 0))
	level.player.add_child(attacker)
	level.opponent.add_child(defender)
	attacker.stats.curr_health = 1
	var move := _move("recoil_faint", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [
		{"family": "recoil", "target": "self", "amount": 9},
	])
	attacker.stats.move_slots = [move]
	attacker.stats.current_pp = [move.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(not attacker.stats.is_active(), "recoil can faint attacker")
	_assert_true(_log_has_source(level.battle_log, "unit_fainted", "recoil"), "recoil faint logged")
	level.free()


func _check_area_targets() -> void:
	var level: TacticsLevel = _fake_level()
	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "AreaAttacker", Vector3.ZERO)
	var defender_a: FakePawn = _fake_pawn(DEFENDER_PATH, "AreaA", Vector3(1, 0, 0))
	var defender_b: FakePawn = _fake_pawn(DEFENDER_PATH, "AreaB", Vector3(0, 0, 1))
	level.player.add_child(attacker)
	level.opponent.add_child(defender_a)
	level.opponent.add_child(defender_b)
	var move := _move("area_hit", PokemonMoveResource.CATEGORY_SPECIAL, 20, PokemonMoveResource.TacticalRangeKind.AREA, PokemonMoveResource.TARGET_FOE, [
		{"family": "damage", "target": "hit_target"},
	])
	move.tactical_range_value = 1
	attacker.stats.move_slots = [move]
	attacker.stats.current_pp = [move.pp]
	resolver.execute(attacker, defender_a, 0, level)
	_assert_true(_count_events(level.battle_log, "damage_dealt") == 2, "area move hits both legal targets")
	level.free()


func _fake_level() -> TacticsLevel:
	var level := TacticsLevel.new()
	level.player = TacticsPlayer.new()
	level.opponent = TacticsOpponent.new()
	level.battle_rng.seed = 123
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
	return _count_events(log, kind) > 0


func _log_has_source(log: BattleLog, kind: String, source: String) -> bool:
	for event in log.events:
		if event.get("kind", "") == kind and event.get("source", "") == source:
			return true
	return false


func _count_events(log: BattleLog, kind: String) -> int:
	var count: int = 0
	for event in log.events:
		if event.get("kind", "") == kind:
			count += 1
	return count


func _assert_true(value: bool, label: String) -> void:
	if value:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: fail - %s" % label)
