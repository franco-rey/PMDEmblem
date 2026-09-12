extends SmokeCase

const ATTACKER_PATH: String = "res://data/models/pokemon/generated/instances/0004_charmander.tres"
const DEFENDER_PATH: String = "res://data/models/pokemon/overrides/instances/0467_magmortar.tres"
const MOVES_DIR: String = "res://data/models/pokemon/generated/moves"
const TRIALS: int = 200

class FakePawn:
	extends TacticsPawn
	var fake_tile: TacticsTile
	func get_tile() -> TacticsTile:
		return fake_tile

var resolver := BattleActionResolver.new()


func _init() -> void:
	_check_move_flags()
	_check_defender_contact_abilities()
	_check_attacker_contact_ability()
	_finish("rules_contact_abilities")


func _check_move_flags() -> void:
	_assert_true(_move("tackle").has_flag("contact"), "Tackle is a contact move")
	_assert_true(not _move("earthquake").has_flag("contact"), "Earthquake is not a contact move")
	_assert_true(_move("draining_kiss").has_flag("contact"), "Draining Kiss is a contact move")
	_assert_true(_move("draining_kiss").category == PokemonMoveResource.CATEGORY_SPECIAL, "Draining Kiss is special")


func _check_defender_contact_abilities() -> void:
	for entry in [["static", "paralyze"], ["flame_body", "burn"], ["poison_point", "poison"]]:
		var slug: String = String(entry[0])
		var status_id: String = String(entry[1])
		_assert_true(_defender_procs(slug, status_id, "tackle") > 0, "%s procs on a contact move" % slug)
		_assert_true(_defender_procs(slug, status_id, "earthquake") == 0, "%s never procs on a non-contact move" % slug)
		_assert_true(_defender_procs(slug, status_id, "draining_kiss") > 0, "%s procs on a special contact move" % slug)


func _check_attacker_contact_ability() -> void:
	_assert_true(_attacker_procs("poison_touch", "poison", "tackle") > 0, "Poison Touch procs on a contact move")
	_assert_true(_attacker_procs("poison_touch", "poison", "earthquake") == 0, "Poison Touch never procs on a non-contact move")


func _defender_procs(defender_ability: String, status_id: String, move_id: String) -> int:
	var procs: int = 0
	for i in range(TRIALS):
		var ctx: Dictionary = _setup(i)
		var attacker: FakePawn = ctx["attacker"]
		var defender: FakePawn = ctx["defender"]
		defender.stats.pokemon_instance.ability_override = defender_ability
		attacker.stats.types = ["normal"] as Array[String]
		defender.stats.types = ["normal"] as Array[String]
		_give(attacker, _move(move_id))
		resolver.execute(attacker, defender, 0, ctx["level"])
		if attacker.stats.battle_statuses.has(status_id):
			procs += 1
		(ctx["level"] as TacticsLevel).free()
	return procs


func _attacker_procs(attacker_ability: String, status_id: String, move_id: String) -> int:
	var procs: int = 0
	for i in range(TRIALS):
		var ctx: Dictionary = _setup(i)
		var attacker: FakePawn = ctx["attacker"]
		var defender: FakePawn = ctx["defender"]
		attacker.stats.pokemon_instance.ability_override = attacker_ability
		attacker.stats.types = ["normal"] as Array[String]
		defender.stats.types = ["normal"] as Array[String]
		_give(attacker, _move(move_id))
		resolver.execute(attacker, defender, 0, ctx["level"])
		if defender.stats.battle_statuses.has(status_id):
			procs += 1
		(ctx["level"] as TacticsLevel).free()
	return procs


func _give(pawn: FakePawn, move: PokemonMoveResource) -> void:
	pawn.stats.move_slots = [move]
	pawn.stats.current_pp = [maxi(1, move.pp)]


func _move(move_id: String) -> PokemonMoveResource:
	var move: PokemonMoveResource = (load("%s/%s.tres" % [MOVES_DIR, move_id]) as PokemonMoveResource).duplicate()
	move.accuracy = PokemonMoveResource.ACCURACY_NEVER_MISS
	return move


func _setup(seed_value: int) -> Dictionary:
	var level := TacticsLevel.new()
	level.player = TacticsPlayer.new()
	level.opponent = TacticsOpponent.new()
	level.battle_rng.seed = seed_value
	level.add_child(level.player)
	level.add_child(level.opponent)
	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "Striker", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn(DEFENDER_PATH, "Struck", Vector3(1, 0, 0))
	level.player.add_child(attacker)
	level.opponent.add_child(defender)
	return {"level": level, "attacker": attacker, "defender": defender}


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
