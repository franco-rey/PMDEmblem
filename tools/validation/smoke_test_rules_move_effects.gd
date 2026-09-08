extends SceneTree

const ATTACKER_PATH: String = "res://data/models/pokemon/generated/instances/0004_charmander.tres"
const DEFENDER_PATH: String = "res://data/models/pokemon/overrides/instances/0467_magmortar.tres"
const MOVES_DIR: String = "res://data/models/pokemon/generated/moves"

class FakePawn:
	extends TacticsPawn
	var fake_tile: TacticsTile
	func get_tile() -> TacticsTile:
		return fake_tile

var failures: int = 0
var resolver := BattleActionResolver.new()


func _init() -> void:
	_check_self_faint_cut_hp()
	_check_level_damage()
	_check_pp_damage()
	_check_cure_scopes()
	_check_dry_skin_absorbs_water()
	if failures > 0:
		push_error("smoke: rules_move_effects failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: rules_move_effects clean")
		quit(0)


func _check_self_faint_cut_hp() -> void:
	for move_id in ["explosion", "self_destruct"]:
		var ctx: Dictionary = _setup()
		var attacker: FakePawn = ctx["attacker"]
		var defender: FakePawn = ctx["defender"]
		_give(attacker, _move(move_id))
		var before: int = defender.stats.curr_health
		var expected: int = maxi(1, int(floor(float(before) / 2.0)))
		resolver.execute(attacker, defender, 0, ctx["level"])
		var dealt: int = before - defender.stats.curr_health
		_assert_true(dealt == expected, "%s cuts half the target's HP (%d of %d, expected %d)" % [move_id, dealt, before, expected])
		_assert_true(not attacker.stats.is_active(), "%s faints its user" % move_id)
		(ctx["level"] as TacticsLevel).free()


func _check_level_damage() -> void:
	var ctx: Dictionary = _setup()
	var attacker: FakePawn = ctx["attacker"]
	var defender: FakePawn = ctx["defender"]
	_give(attacker, _move("night_shade"))
	var attacker_before: int = attacker.stats.curr_health
	var defender_before: int = defender.stats.curr_health
	resolver.execute(attacker, defender, 0, ctx["level"])
	_assert_true(defender_before - defender.stats.curr_health == attacker.stats.level, "Night Shade deals the user's level to the target")
	_assert_true(attacker.stats.curr_health == attacker_before, "Night Shade does not damage its user")
	(ctx["level"] as TacticsLevel).free()


func _check_pp_damage() -> void:
	var ctx: Dictionary = _setup()
	var attacker: FakePawn = ctx["attacker"]
	var defender: FakePawn = ctx["defender"]
	var first: PokemonMoveResource = _move("tackle")
	var second: PokemonMoveResource = _move("ember")
	defender.stats.move_slots = [first, second]
	defender.stats.current_pp = [first.pp, second.pp]
	defender.stats.record_move_use(second.move_id, 1)
	_give(attacker, _move("spite"))
	resolver.execute(attacker, defender, 0, ctx["level"])
	_assert_true(defender.stats.current_pp[0] == first.pp, "Spite leaves untouched slots alone")
	_assert_true(defender.stats.current_pp[1] < second.pp, "Spite drains the last used move slot")
	(ctx["level"] as TacticsLevel).free()

	var idle: Dictionary = _setup()
	var idle_attacker: FakePawn = idle["attacker"]
	var idle_defender: FakePawn = idle["defender"]
	idle_defender.stats.move_slots = [first]
	idle_defender.stats.current_pp = [first.pp]
	_give(idle_attacker, _move("spite"))
	resolver.execute(idle_attacker, idle_defender, 0, idle["level"])
	_assert_true(idle_defender.stats.current_pp[0] == first.pp, "Spite has no effect before the target has used a move")
	(idle["level"] as TacticsLevel).free()


func _check_cure_scopes() -> void:
	var haze: Dictionary = _cure_probe("haze")
	_assert_true((haze["stages"] as Dictionary).is_empty(), "Haze clears stat stages")
	_assert_true((haze["statuses"] as Array).has("burn"), "Haze leaves status conditions in place")

	var clear_smog: Dictionary = _cure_probe("clear_smog")
	_assert_true((clear_smog["stages"] as Dictionary).is_empty(), "Clear Smog clears stat stages")

	var refresh: Dictionary = _cure_probe("refresh")
	_assert_true(not (refresh["statuses"] as Array).has("burn"), "Refresh cures a major status")
	_assert_true((refresh["statuses"] as Array).has("focus_energy"), "Refresh keeps a beneficial status")
	_assert_true((refresh["statuses"] as Array).has("leech_seed"), "Refresh only cures major statuses")
	_assert_true(not (refresh["stages"] as Dictionary).is_empty(), "Refresh leaves stat stages alone")

	var heal_bell: Dictionary = _cure_probe("heal_bell")
	_assert_true(not (heal_bell["statuses"] as Array).has("burn"), "Heal Bell cures a bad status")
	_assert_true(not (heal_bell["statuses"] as Array).has("leech_seed"), "Heal Bell cures every bad status")
	_assert_true((heal_bell["statuses"] as Array).has("focus_energy"), "Heal Bell keeps a beneficial status")


func _cure_probe(move_id: String) -> Dictionary:
	var ctx: Dictionary = _setup()
	var attacker: FakePawn = ctx["attacker"]
	var defender: FakePawn = ctx["defender"]
	var move: PokemonMoveResource = _move(move_id)
	var recipient: FakePawn = attacker if (move.can_target_self() and not move.can_target_foes()) else defender
	recipient.stats.apply_battle_status("burn")
	recipient.stats.apply_battle_status("leech_seed")
	recipient.stats.apply_battle_status("focus_energy")
	recipient.stats.set_stat_stage("attack", 3)
	recipient.stats.set_stat_stage("defense", -2)
	_give(attacker, move)
	resolver.execute(attacker, recipient, 0, ctx["level"])
	var out: Dictionary = {
		"statuses": recipient.stats.battle_statuses.keys(),
		"stages": recipient.stats.stat_stages.duplicate(),
	}
	(ctx["level"] as TacticsLevel).free()
	return out


func _check_dry_skin_absorbs_water() -> void:
	var ctx: Dictionary = _setup()
	var attacker: FakePawn = ctx["attacker"]
	var defender: FakePawn = ctx["defender"]
	defender.stats.pokemon_instance.ability_override = "dry_skin"
	defender.stats.curr_health = int(defender.stats.max_health / 2)
	var before: int = defender.stats.curr_health
	_give(attacker, _move("water_gun"))
	resolver.execute(attacker, defender, 0, ctx["level"])
	_assert_true(defender.stats.curr_health > before, "Dry Skin absorbs a Water move instead of taking damage")
	(ctx["level"] as TacticsLevel).free()

	var burn: Dictionary = _setup()
	var burner: FakePawn = burn["attacker"]
	var victim: FakePawn = burn["defender"]
	victim.stats.pokemon_instance.ability_override = "dry_skin"
	var burn_before: int = victim.stats.curr_health
	_give(burner, _move("ember"))
	resolver.execute(burner, victim, 0, burn["level"])
	_assert_true(victim.stats.curr_health < burn_before, "Dry Skin still takes damage from a Fire move")
	(burn["level"] as TacticsLevel).free()


func _give(pawn: FakePawn, move: PokemonMoveResource) -> void:
	pawn.stats.move_slots = [move]
	pawn.stats.current_pp = [maxi(1, move.pp)]


func _move(move_id: String) -> PokemonMoveResource:
	var move: PokemonMoveResource = (load("%s/%s.tres" % [MOVES_DIR, move_id]) as PokemonMoveResource).duplicate()
	move.accuracy = PokemonMoveResource.ACCURACY_NEVER_MISS
	return move


func _setup() -> Dictionary:
	var level := TacticsLevel.new()
	level.player = TacticsPlayer.new()
	level.opponent = TacticsOpponent.new()
	level.battle_rng.seed = 4242
	level.add_child(level.player)
	level.add_child(level.opponent)
	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "Actor", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn(DEFENDER_PATH, "Target", Vector3(1, 0, 0))
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


func _assert_true(value: bool, label: String) -> void:
	if value:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: fail - %s" % label)
