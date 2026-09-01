extends SceneTree

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
	_check_turn_processed_statuses()
	_check_status_action_guards()
	if failures > 0:
		push_error("smoke: statuses failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: statuses clean")
		quit(0)


func _check_turn_processed_statuses() -> void:
	var level: TacticsLevel = _fake_level()
	var source: FakePawn = _fake_pawn(ATTACKER_PATH, "SeedSource", Vector3.ZERO)
	var target: FakePawn = _fake_pawn(DEFENDER_PATH, "StatusTarget", Vector3(1, 0, 0))
	level.player.add_child(source)
	level.opponent.add_child(target)

	target.stats.max_health = 80
	target.stats.curr_health = 80
	target.stats.apply_battle_status("burn")
	level._process_turn_start_statuses(target)
	_assert_true(target.stats.curr_health == 70, "burn deals 1/8 max HP tick")
	_assert_true(_log_has_status(level.battle_log, "status_tick", "burn"), "burn tick logged")
	level.battle_log.events.clear()

	target.stats.battle_statuses = {}
	target.stats.max_health = 160
	target.stats.curr_health = 160
	target.stats.apply_battle_status("poison")
	level._process_turn_start_statuses(target)
	_assert_true(target.stats.curr_health == 150, "poison deals 1/16 max HP tick")
	_assert_true(int((target.stats.battle_statuses["poison"] as Dictionary).get("counter", 0)) == 5, "poison counter decrements")
	level.battle_log.events.clear()

	source.stats.max_health = 100
	source.stats.curr_health = 50
	target.stats.battle_statuses = {}
	target.stats.max_health = 120
	target.stats.curr_health = 120
	target.stats.apply_battle_status("leech_seed", {"source_unit": source})
	level._process_turn_start_statuses(target)
	_assert_true(target.stats.curr_health == 110 and source.stats.curr_health == 60, "Leech Seed drains target and heals source")
	level.battle_log.events.clear()

	target.stats.battle_statuses = {}
	target.stats.max_health = 120
	target.stats.curr_health = 60
	target.stats.apply_battle_status("ingrain")
	level._process_turn_start_statuses(target)
	_assert_true(target.stats.curr_health == 80, "Ingrain heals 1/6 max HP")
	_assert_true(int((target.stats.battle_statuses["ingrain"] as Dictionary).get("counter", 0)) == 9, "Ingrain counter decrements")
	level.battle_log.events.clear()

	target.stats.battle_statuses = {}
	target.stats.curr_health = 60
	target.stats.apply_battle_status("aqua_ring")
	level._process_turn_start_statuses(target)
	_assert_true(target.stats.curr_health == 75, "Aqua Ring heals 1/8 max HP")
	level.battle_log.events.clear()

	target.stats.battle_statuses = {}
	target.stats.curr_health = 60
	target.stats.apply_battle_status("aqua_ring")
	target.stats.apply_battle_status("heal_block")
	level._process_turn_start_statuses(target)
	_assert_true(target.stats.curr_health == 60, "Heal Block blocks turn-start healing")
	_assert_true(_log_has(level.battle_log, "status_heal_blocked"), "blocked status healing logged")
	level.battle_log.events.clear()

	target.stats.battle_statuses = {}
	target.stats.apply_battle_status("sleep")
	level._process_turn_start_statuses(target)
	var sleep_skip: Dictionary = target.stats.consume_turn_skip_status()
	_assert_true(String(sleep_skip.get("status_id", "")) == "sleep", "sleep remains a skip status after first counter tick")
	_assert_true(int((target.stats.battle_statuses["sleep"] as Dictionary).get("counter", 0)) == 4, "sleep counter decrements")
	level.battle_log.events.clear()

	target.stats.battle_statuses = {}
	target.stats.apply_battle_status("flinch")
	var flinch_skip: Dictionary = target.stats.consume_turn_skip_status()
	_assert_true(String(flinch_skip.get("status_id", "")) == "flinch", "flinch reports a skip status")
	_assert_true(not target.stats.battle_statuses.has("flinch"), "flinch is consumed after one skipped turn")
	level.battle_log.events.clear()

	target.stats.battle_statuses = {}
	target.stats.apply_battle_status("paralyze")
	level._process_turn_start_statuses(target)
	_assert_true(target.stats.consume_turn_skip_status().is_empty(), "paralyze does not skip on its first recent=false turn")
	level._process_turn_start_statuses(target)
	var para_skip: Dictionary = target.stats.consume_turn_skip_status()
	_assert_true(String(para_skip.get("status_id", "")) == "paralyze", "paralyze alternates into a skip turn")
	level.free()


func _check_status_action_guards() -> void:
	var level: TacticsLevel = _fake_level()
	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "GuardedAttacker", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn(DEFENDER_PATH, "GuardedDefender", Vector3(1, 0, 0))
	level.player.add_child(attacker)
	level.opponent.add_child(defender)

	var heal := _move("recover", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.SELF, PokemonMoveResource.TARGET_SELF, [
		{"family": "heal", "target": "self", "hp_divisor": 2},
	])
	attacker.stats.max_health = 100
	attacker.stats.curr_health = 40
	attacker.stats.apply_battle_status("heal_block")
	attacker.stats.move_slots = [heal]
	attacker.stats.current_pp = [heal.pp]
	resolver.execute(attacker, attacker, 0, level)
	_assert_true(attacker.stats.curr_health == 40, "Heal Block blocks direct healing moves")
	_assert_true(_log_has(level.battle_log, "heal_blocked"), "direct heal block logged")
	level.battle_log.events.clear()

	attacker.stats.battle_statuses = {}
	attacker.stats.apply_battle_status("taunted")
	attacker.stats.current_pp = [heal.pp]
	resolver.execute(attacker, attacker, 0, level)
	_assert_true(_log_has_status(level.battle_log, "move_blocked", "taunted"), "Taunt blocks status moves")
	level.battle_log.events.clear()

	var tackle := _move("tackle", PokemonMoveResource.CATEGORY_PHYSICAL, 40, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [
		{"family": "damage", "target": "hit_target"},
	])
	attacker.stats.battle_statuses = {}
	attacker.stats.apply_battle_status("disable", {"disabled_move_id": "tackle", "disabled_slot_index": 0})
	attacker.stats.move_slots = [tackle]
	attacker.stats.current_pp = [tackle.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(_log_has_status(level.battle_log, "move_blocked", "disable"), "Disable blocks sealed move")
	level.battle_log.events.clear()

	var growl := _move("growl", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [
		{"family": "stat_stage", "target": "hit_target", "stat": "attack", "delta": -1},
	])
	attacker.stats.battle_statuses = {}
	attacker.stats.apply_battle_status("encore", {"locked_move_id": "tackle", "locked_slot_index": 0})
	attacker.stats.move_slots = [tackle, growl]
	attacker.stats.current_pp = [tackle.pp, growl.pp]
	resolver.execute(attacker, defender, 1, level)
	_assert_true(_log_has_status(level.battle_log, "move_blocked", "encore"), "Encore blocks moves other than the locked one")
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


func _log_has_status(log: BattleLog, kind: String, status_id: String) -> bool:
	for event in log.events:
		if event.get("kind", "") == kind and event.get("status_id", "") == status_id:
			return true
	return false


func _assert_true(value: bool, label: String) -> void:
	if value:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: fail - %s" % label)
