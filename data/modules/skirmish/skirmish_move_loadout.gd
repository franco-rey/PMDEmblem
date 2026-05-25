class_name SkirmishMoveLoadout
extends RefCounted

const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"
const MAX_MOVE_SLOTS: int = PokemonInstanceResource.MAX_MOVE_SLOTS


static func clone_with_loadout(
		template: PokemonInstanceResource,
		team: int,
		control_type: int,
		seed: int,
		side_key: String,
		slot_index: int
) -> PokemonInstanceResource:
	var instance: PokemonInstanceResource = clone_for_side(template, team, control_type)
	assign_loadout(instance, seed, side_key, slot_index)
	return instance


static func clone_for_side(template: PokemonInstanceResource, team: int, control_type: int) -> PokemonInstanceResource:
	var instance := PokemonInstanceResource.new()
	if template == null:
		return instance
	instance.species = template.species
	instance.form_index = template.form_index
	instance.level = template.level
	instance.experience = template.experience
	instance.current_hp = PokemonInstanceResource.CURRENT_HP_AUTO if template.current_hp == PokemonInstanceResource.CURRENT_HP_AUTO else template.current_hp
	instance.move_slots = template.move_slots.duplicate()
	instance.pp_state = template.pp_state.duplicate()
	instance.known_move_ids = template.known_move_ids.duplicate()
	instance.team = team
	instance.control_type = control_type
	instance.nickname = template.nickname
	instance.movement_override = template.movement_override
	instance.recruited = template.recruited
	instance.nature_id = template.nature_id
	instance.permanent_modifiers = template.permanent_modifiers.duplicate(true)
	instance.held_item = template.held_item
	instance.runtime_modifiers = template.runtime_modifiers.duplicate(true)
	instance.temporary_statuses = template.temporary_statuses.duplicate()
	return instance


static func assign_loadout(instance: PokemonInstanceResource, seed: int, side_key: String, slot_index: int) -> void:
	if instance == null:
		return
	var pool: Array[PokemonMoveResource] = move_pool_for_instance(instance)
	if pool.is_empty():
		pool = _template_pool(instance)
	if pool.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _salt_seed(seed, side_key, slot_index, instance)
	var selected: Array[PokemonMoveResource] = _choose_unique(pool, rng, MAX_MOVE_SLOTS)
	selected = _ensure_resolving_attack(selected, pool, rng)
	if selected.is_empty():
		return
	instance.move_slots = selected
	instance.pp_state = []
	for move in instance.move_slots:
		instance.pp_state.append(move.pp if move != null else 0)


static func has_resolving_attack(moves: Array[PokemonMoveResource]) -> bool:
	return _has_resolving_attack(moves)


static func move_pool_for_instance(instance: PokemonInstanceResource) -> Array[PokemonMoveResource]:
	var out: Array[PokemonMoveResource] = []
	if instance == null or instance.species == null:
		return out
	var seen: Dictionary = {}
	var learned: Array[Dictionary] = []
	for entry in instance.species.level_skills:
		if int(entry.get("level", 0)) <= instance.level:
			learned.append(entry)
	for entry in learned:
		var slug: String = String(entry.get("skill", ""))
		if slug.is_empty() or seen.has(slug):
			continue
		var move: PokemonMoveResource = _load_move(slug)
		if move == null:
			continue
		seen[slug] = true
		out.append(move)
	return out


static func _template_pool(instance: PokemonInstanceResource) -> Array[PokemonMoveResource]:
	var out: Array[PokemonMoveResource] = []
	var seen: Dictionary = {}
	for move in instance.move_slots:
		if move == null or seen.has(move.move_id):
			continue
		seen[move.move_id] = true
		out.append(move)
	return out


static func _ensure_resolving_attack(
		selected: Array[PokemonMoveResource],
		pool: Array[PokemonMoveResource],
		rng: RandomNumberGenerator
) -> Array[PokemonMoveResource]:
	if _has_resolving_attack(selected):
		return selected
	var candidates: Array[PokemonMoveResource] = []
	for move in pool:
		if _is_resolving_attack(move) and not _has_move_id(selected, move.move_id):
			candidates.append(move)
	if candidates.is_empty():
		return selected
	candidates.sort_custom(_is_move_less_than)
	var replacement: PokemonMoveResource = candidates[int(rng.randi_range(0, candidates.size() - 1))]
	if selected.size() < MAX_MOVE_SLOTS:
		selected.append(replacement)
		return selected
	var replaceable_slots: Array[int] = []
	for i in range(selected.size()):
		if not _is_resolving_attack(selected[i]):
			replaceable_slots.append(i)
	if replaceable_slots.is_empty():
		return selected
	var replace_index: int = replaceable_slots[int(rng.randi_range(0, replaceable_slots.size() - 1))]
	selected[replace_index] = replacement
	return selected


static func _has_resolving_attack(moves: Array[PokemonMoveResource]) -> bool:
	for move in moves:
		if _is_resolving_attack(move):
			return true
	return false


static func _is_resolving_attack(move: PokemonMoveResource) -> bool:
	if move == null or move.pp <= 0 or not move.can_target_foes():
		return false
	if move.effect_records.is_empty():
		return move.is_damaging() and move.base_power > 0
	for record in move.effect_records:
		var record_target: String = String(record.get("target", "hit_target"))
		if record_target == "self" or record_target == "field":
			continue
		var family: String = String(record.get("family", ""))
		if family == "damage" and move.is_damaging():
			return true
		if ["fixed_damage", "level_damage", "percent_damage", "hp_to_1"].has(family):
			return true
	return false


static func _has_move_id(moves: Array[PokemonMoveResource], move_id: String) -> bool:
	for move in moves:
		if move != null and move.move_id == move_id:
			return true
	return false


static func _choose_unique(pool: Array[PokemonMoveResource], rng: RandomNumberGenerator, limit: int) -> Array[PokemonMoveResource]:
	var available: Array[PokemonMoveResource] = pool.duplicate()
	available.sort_custom(_is_move_less_than)
	var out: Array[PokemonMoveResource] = []
	while not available.is_empty() and out.size() < limit:
		var pick_index: int = int(rng.randi_range(0, available.size() - 1))
		out.append(available[pick_index])
		available.remove_at(pick_index)
	return out


static func _is_move_less_than(a: PokemonMoveResource, b: PokemonMoveResource) -> bool:
	return a.move_id < b.move_id


static func _load_move(slug: String) -> PokemonMoveResource:
	if slug.is_empty():
		return null
	var path: String = "%s%s.tres" % [GENERATED_MOVES_DIR, slug]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PokemonMoveResource


static func _salt_seed(seed: int, side_key: String, slot_index: int, instance: PokemonInstanceResource) -> int:
	var h: int = int(seed) & 0x7FFFFFFF
	for i in range(side_key.length()):
		h = int(((h * 131) ^ side_key.unicode_at(i)) & 0x7FFFFFFF)
	var species_id: String = instance.species.species_id if instance != null and instance.species != null else ""
	for i in range(species_id.length()):
		h = int(((h * 131) ^ species_id.unicode_at(i)) & 0x7FFFFFFF)
	h = int((h ^ (slot_index + 1) * 0x45D9F3B) & 0x7FFFFFFF)
	return maxi(1, h)
