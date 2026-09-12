extends SmokeCase

const ATTACKER_PATH: String = "res://data/models/pokemon/generated/instances/0004_charmander.tres"
const DEFENDER_PATH: String = "res://data/models/pokemon/overrides/instances/0467_magmortar.tres"
const MOVES_DIR: String = "res://data/models/pokemon/generated/moves"
const TURN_LIMIT: int = 30

class FakePawn:
	extends TacticsPawn
	var fake_tile: TacticsTile
	func get_tile() -> TacticsTile:
		return fake_tile

var resolver := BattleActionResolver.new()


func _init() -> void:
	_check_turn_skip_statuses_expire()
	_check_immobilized_from_move()
	_check_confusion_is_not_reapplied()
	_check_tangled_feet()
	_finish("rules_statuses")


func _check_turn_skip_statuses_expire() -> void:
	for status_id in Stats.TURN_SKIP_STATUSES:
		var payload: Variant = Stats.DEFAULT_STATUS_PAYLOADS.get(status_id, null)
		_assert_true(payload is Dictionary and (payload as Dictionary).has("counter"), "%s carries a default counter" % status_id)
		var level: TacticsLevel = _fake_level()
		var pawn: FakePawn = _fake_pawn(DEFENDER_PATH, "Skipper", Vector3.ZERO)
		level.opponent.add_child(pawn)
		pawn.stats.apply_battle_status(status_id)
		var skipped: int = 0
		var expired: bool = false
		for turn in range(TURN_LIMIT):
			level._process_turn_start_statuses(pawn)
			if not pawn.stats.battle_statuses.has(status_id):
				expired = true
				break
			if String(pawn.stats.consume_turn_skip_status().get("status_id", "")) == status_id:
				skipped += 1
		_assert_true(expired, "%s expires within %d turns" % [status_id, TURN_LIMIT])
		_assert_true(skipped < TURN_LIMIT, "%s skips a bounded number of turns (%d)" % [status_id, skipped])
		level.free()


func _check_immobilized_from_move() -> void:
	var level: TacticsLevel = _fake_level()
	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "Looker", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn(DEFENDER_PATH, "Looked", Vector3(1, 0, 0))
	level.player.add_child(attacker)
	level.opponent.add_child(defender)
	_give(attacker, _move("mean_look"))
	resolver.execute(attacker, defender, 0, level)
	_assert_true(defender.stats.battle_statuses.has("immobilized"), "Mean Look immobilizes the target")
	var payload: Dictionary = defender.stats.battle_statuses.get("immobilized", {})
	_assert_true(int(payload.get("counter", 0)) > 0, "Mean Look immobilize carries a counter")
	var skipped: int = 0
	for turn in range(TURN_LIMIT):
		level._process_turn_start_statuses(defender)
		if not defender.stats.battle_statuses.has("immobilized"):
			break
		if String(defender.stats.consume_turn_skip_status().get("status_id", "")) == "immobilized":
			skipped += 1
	_assert_true(not defender.stats.battle_statuses.has("immobilized"), "Mean Look immobilize wears off")
	_assert_true(skipped > 0 and skipped < TURN_LIMIT, "Mean Look costs %d turns, not the whole battle" % skipped)
	level.free()


func _check_confusion_is_not_reapplied() -> void:
	var level: TacticsLevel = _fake_level()
	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "Confuser", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn(DEFENDER_PATH, "Confused", Vector3(1, 0, 0))
	level.player.add_child(attacker)
	level.opponent.add_child(defender)
	var ops: BattleStateOps = level._ops()
	ops.apply_status(defender, "confuse", {}, {"kind": "move"})
	var first: int = int((defender.stats.battle_statuses["confuse"] as Dictionary).get("counter", 0))
	_assert_true(first > 0, "confuse applies with a counter")
	for turn in range(3):
		level._process_turn_start_statuses(defender)
	var ticked: int = int((defender.stats.battle_statuses["confuse"] as Dictionary).get("counter", 0))
	_assert_true(ticked == first - 3, "confuse counter ticks down each turn")
	var again: Dictionary = ops.apply_status(defender, "confuse", {}, {"kind": "move"})
	_assert_true(not bool(again.get("applied", true)), "confuse cannot be applied to an already confused unit")
	_assert_true(String(again.get("reason", "")) == "already_applied", "re-applied confuse reports already_applied")
	_assert_true(int((defender.stats.battle_statuses["confuse"] as Dictionary).get("counter", 0)) == ticked, "re-applied confuse does not refresh the counter")
	level.free()


func _check_tangled_feet() -> void:
	var level: TacticsLevel = _fake_level()
	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "Hitter", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn(DEFENDER_PATH, "Dodger", Vector3(1, 0, 0))
	level.player.add_child(attacker)
	level.opponent.add_child(defender)
	defender.stats.pokemon_instance.ability_override = "tangled_feet"
	var move: PokemonMoveResource = _move("tackle")
	var service := BattleIntrinsicService.new()
	var clear_multiplier: float = service.accuracy_multiplier(attacker, defender, move, level)
	defender.stats.apply_battle_status("confuse")
	var confused_multiplier: float = service.accuracy_multiplier(attacker, defender, move, level)
	_assert_true(is_equal_approx(clear_multiplier, 1.0), "Tangled Feet is inert while the holder is not confused")
	_assert_true(confused_multiplier < clear_multiplier, "Tangled Feet lowers incoming accuracy while confused (%.2f)" % confused_multiplier)
	level.free()


func _give(pawn: FakePawn, move: PokemonMoveResource) -> void:
	pawn.stats.move_slots = [move]
	pawn.stats.current_pp = [maxi(1, move.pp)]


func _move(move_id: String) -> PokemonMoveResource:
	return load("%s/%s.tres" % [MOVES_DIR, move_id]) as PokemonMoveResource


func _fake_level() -> TacticsLevel:
	var level := TacticsLevel.new()
	level.player = TacticsPlayer.new()
	level.opponent = TacticsOpponent.new()
	level.battle_rng.seed = 4242
	level.add_child(level.player)
	level.add_child(level.opponent)
	return level


func _fake_pawn(path: String, pawn_name: String, pos: Vector3) -> FakePawn:
	var instance: PokemonInstanceResource = (load(path) as PokemonInstanceResource).duplicate(true)
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
