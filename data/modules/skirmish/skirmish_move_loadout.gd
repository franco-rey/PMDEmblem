class_name SkirmishMoveLoadout
extends RefCounted
## Deterministic transient four-move loadouts for skirmish entrants.

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
	if selected.is_empty():
		return
	instance.move_slots = selected
	instance.pp_state = []
	for move in instance.move_slots:
		instance.pp_state.append(move.pp if move != null else 0)


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
