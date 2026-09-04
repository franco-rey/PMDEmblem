class_name PokemonPersistenceService
extends RefCounted


static func prepare_for_spawn(instance: PokemonInstanceResource, refill_hp: bool = true, refill_pp: bool = true) -> void:
	if instance == null:
		return
	var form: PokemonFormResource = instance.resolved_form()
	if instance.experience <= 0:
		instance.experience = PokemonExperienceService.xp_for_level(form, instance.level)
	PokemonLearnsetService.ensure_known_moves(instance)
	if refill_hp:
		instance.current_hp = PokemonInstanceResource.CURRENT_HP_AUTO
	if refill_pp:
		instance.pp_state = []
		for move in instance.move_slots:
			instance.pp_state.append(move.pp if move != null else 0)


static func write_runtime_state(stats: Stats, instance: PokemonInstanceResource = null) -> Dictionary:
	if stats == null:
		return {}
	var target: PokemonInstanceResource = instance if instance != null else stats.pokemon_instance
	if target == null:
		return {}
	target.level = stats.level
	target.current_hp = stats.curr_health
	target.pp_state = stats.current_pp.duplicate()
	target.move_slots = stats.move_slots.duplicate()
	if target.experience <= 0:
		target.experience = PokemonExperienceService.xp_for_level(target.resolved_form(), target.level)
	PokemonLearnsetService.ensure_known_moves(target)
	return snapshot(target)


static func snapshot(instance: PokemonInstanceResource) -> Dictionary:
	if instance == null:
		return {}
	return {
		"species_id": instance.species.species_id if instance.species != null else "",
		"form_index": instance.form_index,
		"level": instance.level,
		"experience": instance.experience,
		"current_hp": instance.current_hp,
		"move_ids": PokemonLearnsetService.current_move_ids(instance),
		"pp_state": instance.pp_state.duplicate(),
		"known_move_ids": instance.known_move_ids.duplicate(),
		"nature_id": instance.nature_id,
		"permanent_modifiers": instance.permanent_modifiers.duplicate(true),
		"held_item": instance.held_item.item_id if instance.held_item != null else "",
		"recruited": instance.recruited,
	}


static func clone_for_run(template: PokemonInstanceResource) -> PokemonInstanceResource:
	if template == null:
		return PokemonInstanceResource.new()
	var instance := PokemonInstanceResource.new()
	instance.species = template.species
	instance.form_index = template.form_index
	instance.level = template.level
	instance.experience = template.experience
	instance.current_hp = template.current_hp
	instance.move_slots = template.move_slots.duplicate()
	instance.pp_state = template.pp_state.duplicate()
	instance.known_move_ids = template.known_move_ids.duplicate()
	instance.team = template.team
	instance.control_type = template.control_type
	instance.nickname = template.nickname
	instance.movement_override = template.movement_override
	instance.recruited = template.recruited
	instance.nature_id = template.nature_id
	instance.permanent_modifiers = template.permanent_modifiers.duplicate(true)
	instance.held_item = template.held_item
	instance.runtime_modifiers = template.runtime_modifiers.duplicate(true)
	instance.temporary_statuses = template.temporary_statuses.duplicate()
	instance.ability_override = template.ability_override
	instance.loadout_locked = template.loadout_locked
	prepare_for_spawn(instance, false, false)
	return instance
