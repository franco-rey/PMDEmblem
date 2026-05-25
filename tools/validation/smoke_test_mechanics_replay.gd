extends SceneTree
## M7 smoke: same seed + scripted move choices produce identical event logs.

const ATTACKER_PATH: String = "res://data/models/pokemon/generated/instances/0004_charmander.tres"
const DEFENDER_PATH: String = "res://data/models/pokemon/generated/instances/0007_squirtle.tres"

class FakePawn:
	extends TacticsPawn
	var fake_tile: TacticsTile
	func get_tile() -> TacticsTile:
		return fake_tile

var failures: int = 0


func _init() -> void:
	var first: String = _scripted_log_json(20260524)
	var second: String = _scripted_log_json(20260524)
	var third: String = _scripted_log_json(20260525)
	_assert_true(first == second, "same seed produces identical event log")
	_assert_true(first != third, "different seed changes RNG-bearing event log")
	if failures > 0:
		push_error("smoke: mechanics replay failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: mechanics_replay clean")
		quit(0)


func _scripted_log_json(seed: int) -> String:
	var level := TacticsLevel.new()
	level.player = TacticsPlayer.new()
	level.opponent = TacticsOpponent.new()
	level.battle_rng.seed = seed
	level.add_child(level.player)
	level.add_child(level.opponent)

	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "ReplayAttacker", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn(DEFENDER_PATH, "ReplayDefender", Vector3(1, 0, 0))
	level.player.add_child(attacker)
	level.opponent.add_child(defender)

	var move := PokemonMoveResource.new()
	move.move_id = "replay_probe"
	move.name = "Replay Probe"
	move.type = "normal"
	move.category = PokemonMoveResource.CATEGORY_PHYSICAL
	move.base_power = 20
	move.accuracy = PokemonMoveResource.ACCURACY_NEVER_MISS
	move.pp = 8
	move.tactical_range_kind = PokemonMoveResource.TacticalRangeKind.MELEE
	move.tactical_range_value = 1
	move.target_alignment = PokemonMoveResource.TARGET_FOE
	move.effect_records = [
		{"family": "damage", "target": "hit_target", "source_event": "smoke.damage"},
		{"family": "status", "target": "hit_target", "status_id": "poison", "chance": 0, "source_event": "smoke.status_chance"},
		{"family": "stat_stage", "target": "hit_target", "stat": "defense", "delta": -1, "source_event": "smoke.stage"},
	]
	attacker.stats.move_slots = [move]
	attacker.stats.current_pp = [move.pp]

	var resolver := BattleActionResolver.new()
	resolver.execute(attacker, defender, 0, level)
	var sanitized: Array[Dictionary] = _sanitize_events(level.battle_log.events)
	level.battle_log.events.clear()
	level.free()
	return JSON.stringify(sanitized)


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


func _sanitize_events(events: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event in events:
		var clean: Dictionary = {}
		var keys: Array = event.keys()
		keys.sort()
		for key in keys:
			clean[String(key)] = _sanitize_value(event[key])
		out.append(clean)
	return out


func _sanitize_value(value: Variant) -> Variant:
	if value is TacticsPawn:
		return (value as TacticsPawn).name
	if value is Node:
		return (value as Node).name
	if value is Object:
		return str((value as Object).get_instance_id())
	if value is Array:
		var arr: Array = []
		for item in value:
			arr.append(_sanitize_value(item))
		return arr
	if value is Dictionary:
		var dict: Dictionary = {}
		var keys: Array = (value as Dictionary).keys()
		keys.sort()
		for key in keys:
			dict[String(key)] = _sanitize_value((value as Dictionary)[key])
		return dict
	return value


func _assert_true(value: bool, label: String) -> void:
	if value:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: fail - %s" % label)
