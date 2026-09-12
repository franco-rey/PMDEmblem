extends SmokeCase

const BULBASAUR_PATH: String = "res://data/models/pokemon/generated/instances/0001_bulbasaur.tres"

class FakePawn:
	extends TacticsPawn


func _init() -> void:
	var pawn := FakePawn.new()
	pawn.name = "AnimPawn"
	pawn.stats = Stats.new()
	pawn.stats.init_from_pokemon(load(BULBASAUR_PATH) as PokemonInstanceResource)
	pawn.add_child(pawn.stats)
	var resolver := BattleAnimationResolver.new()
	var log := BattleLog.new()

	resolver.select_for_move(pawn, _move("physical", PokemonMoveResource.CATEGORY_PHYSICAL), log)
	resolver.select_for_move(pawn, _move("special", PokemonMoveResource.CATEGORY_SPECIAL), log)
	resolver.select_for_move(pawn, _move("status", PokemonMoveResource.CATEGORY_STATUS), log)
	var exact_chosen: String = resolver.select_for_move(pawn, _move("seed_bomb", PokemonMoveResource.CATEGORY_PHYSICAL), log)
	resolver.select_reaction(pawn, _move("hurt", PokemonMoveResource.CATEGORY_PHYSICAL), "receive_damage", log)
	resolver.select_reaction(pawn, _move("miss", PokemonMoveResource.CATEGORY_STATUS), "miss", log)
	resolver.select_reaction(pawn, _move("faint", PokemonMoveResource.CATEGORY_STATUS), "faint", log)

	_assert_true(_has_purpose(log, "move_use"), "move-use animation logged")
	_assert_true(exact_chosen == "shoot", "exact move animation prefers Shoot-style state")
	_assert_true(_has_move_tier(log, "seed_bomb", "exact"), "exact move animation tier logged")
	_assert_true(_has_move_tier(log, "physical", "category"), "generic move falls back to category tier")
	_assert_true(_has_purpose(log, "receive_damage"), "receive-damage animation logged")
	_assert_true(_has_purpose(log, "miss"), "miss animation logged")
	_assert_true(_has_purpose(log, "faint"), "faint animation logged")
	_assert_true(_count_animation_events(log) >= 6, "all animation requests produced events")
	log.events.clear()
	pawn.free()

	if failures > 0:
		push_error("smoke: move animations failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: move_animations clean")
		quit(0)


func _move(move_id: String, category: int) -> PokemonMoveResource:
	var move := PokemonMoveResource.new()
	move.move_id = move_id
	move.category = category
	return move


func _has_purpose(log: BattleLog, purpose: String) -> bool:
	for event in log.events:
		if String(event.get("purpose", "")) == purpose:
			return true
	return false


func _has_move_tier(log: BattleLog, move_id: String, tier: String) -> bool:
	for event in log.events:
		if String(event.get("move_id", "")) == move_id and String(event.get("selection_tier", "")) == tier:
			return true
	return false


func _count_animation_events(log: BattleLog) -> int:
	var count: int = 0
	for event in log.events:
		if String(event.get("kind", "")).begins_with("animation_"):
			count += 1
	return count
