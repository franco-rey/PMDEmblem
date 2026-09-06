class_name PokemonLearnsetService
extends RefCounted

const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"


static func legal_move_ids_at_level(species: PokemonSpeciesResource, level: int) -> Array[String]:
	var out: Array[String] = []
	if species == null:
		return out
	for entry in species.level_skills:
		if int(entry.get("level", 0)) > level:
			continue
		var move_id: String = String(entry.get("skill", ""))
		if move_id.is_empty() or out.has(move_id):
			continue
		out.append(move_id)
	return out


static func newly_learned_move_ids(species: PokemonSpeciesResource, old_level: int, new_level: int) -> Array[String]:
	var out: Array[String] = []
	if species == null or new_level <= old_level:
		return out
	for entry in species.level_skills:
		var level: int = int(entry.get("level", 0))
		if level <= old_level or level > new_level:
			continue
		var move_id: String = String(entry.get("skill", ""))
		if move_id.is_empty() or out.has(move_id):
			continue
		out.append(move_id)
	return out


static func ensure_known_moves(instance: PokemonInstanceResource) -> void:
	if instance == null:
		return
	var seen: Dictionary = {}
	var known: Array[String] = []
	for move_id in instance.known_move_ids:
		var key: String = String(move_id)
		if not key.is_empty() and not seen.has(key):
			seen[key] = true
			known.append(key)
	for move in instance.move_slots:
		if move == null or seen.has(move.move_id):
			continue
		seen[move.move_id] = true
		known.append(move.move_id)
	for move_id in legal_move_ids_at_level(instance.species, instance.level):
		if seen.has(move_id):
			continue
		seen[move_id] = true
		known.append(move_id)
	instance.known_move_ids = known


static func apply_level_transition(
		instance: PokemonInstanceResource,
		old_level: int,
		new_level: int,
		replacement_choices: Dictionary = {}
) -> Dictionary:
	var move_ids: Array[String] = newly_learned_move_ids(instance.species if instance != null else null, old_level, new_level)
	return apply_new_moves(instance, move_ids, replacement_choices)


static func apply_new_moves(
		instance: PokemonInstanceResource,
		move_ids: Array[String],
		replacement_choices: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {
		"learned": [],
		"replacement_requests": [],
		"ignored": [],
	}
	if instance == null:
		return result
	ensure_known_moves(instance)
	for move_id in move_ids:
		var key: String = String(move_id)
		if key.is_empty() or instance.known_move_ids.has(key):
			continue
		var move: PokemonMoveResource = load_move(key)
		if move == null:
			(result["ignored"] as Array).append(key)
			continue
		if instance.move_slots.size() < PokemonInstanceResource.MAX_MOVE_SLOTS:
			instance.known_move_ids.append(key)
			instance.move_slots.append(move)
			instance.pp_state.append(move.pp)
			(result["learned"] as Array).append(key)
			continue
		if replacement_choices.has(key):
			var slot_index: int = int(replacement_choices[key])
			if apply_replacement(instance, key, slot_index):
				(result["learned"] as Array).append(key)
				continue
		(result["replacement_requests"] as Array).append({
			"new_move_id": key,
			"current_move_ids": current_move_ids(instance),
		})
	return result


static func apply_replacement(instance: PokemonInstanceResource, move_id: String, slot_index: int) -> bool:
	if instance == null:
		return false
	if slot_index < 0 or slot_index >= PokemonInstanceResource.MAX_MOVE_SLOTS:
		return false
	var move: PokemonMoveResource = load_move(move_id)
	if move == null:
		return false
	while instance.move_slots.size() <= slot_index:
		instance.move_slots.append(null)
	while instance.pp_state.size() <= slot_index:
		instance.pp_state.append(0)
	instance.move_slots[slot_index] = move
	instance.pp_state[slot_index] = move.pp
	if not instance.known_move_ids.has(move_id):
		instance.known_move_ids.append(move_id)
	return true


static func current_move_ids(instance: PokemonInstanceResource) -> Array[String]:
	var out: Array[String] = []
	if instance == null:
		return out
	for move in instance.move_slots:
		out.append(move.move_id if move != null else "")
	return out


static func load_move(move_id: String) -> PokemonMoveResource:
	if move_id.is_empty():
		return null
	return CustomMoves.load_move(move_id)
