class_name AccuracyResolver
extends RefCounted
## Deterministic move accuracy helper. The battle owns the RNG and passes it in.


static func roll(move: PokemonMoveResource, rng: RandomNumberGenerator) -> bool:
	if move == null:
		return false
	if move.is_sure_hit():
		return true
	if rng == null:
		push_error("AccuracyResolver.roll requires a battle-owned RandomNumberGenerator")
		return false
	return rng.randf() * 100.0 < float(move.accuracy)
