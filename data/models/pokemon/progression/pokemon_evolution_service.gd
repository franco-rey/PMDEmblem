class_name PokemonEvolutionService
extends RefCounted
## Evolution lookup, eligibility, and application service.

const GENERATED_SPECIES_DIR: String = "res://data/models/pokemon/generated/species"


static func eligible_evolutions(instance: PokemonInstanceResource) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if instance == null or instance.species == null:
		return out
	for evo in instance.species.evolutions:
		if not (evo is Dictionary):
			continue
		var entry: Dictionary = evo
		if _requirements_met(instance, entry.get("requirements", [])):
			out.append(entry.duplicate(true))
	return out


static func eligible_evolution_ids(instance: PokemonInstanceResource) -> Array[String]:
	var out: Array[String] = []
	for entry in eligible_evolutions(instance):
		var result: String = String(entry.get("result", ""))
		if not result.is_empty():
			out.append(result)
	return out


static func apply_evolution(instance: PokemonInstanceResource, result_slug: String = "") -> Dictionary:
	var before_species: String = instance.species.species_id if instance != null and instance.species != null else ""
	var chosen: Dictionary = {}
	if instance == null:
		return {"evolved": false, "reason": "missing_instance"}
	for entry in eligible_evolutions(instance):
		if result_slug.is_empty() or String(entry.get("result", "")) == result_slug:
			chosen = entry
			break
	if chosen.is_empty():
		return {"evolved": false, "reason": "not_eligible", "before_species": before_species}
	var target_species: PokemonSpeciesResource = _load_species_for_bare_slug(String(chosen.get("result", "")))
	if target_species == null:
		return {"evolved": false, "reason": "target_missing", "before_species": before_species}
	var old_max_hp: int = PokemonStatCalculator.max_hp(instance)
	var hp_ratio: float = 1.0
	if instance.current_hp != PokemonInstanceResource.CURRENT_HP_AUTO:
		hp_ratio = clampf(float(instance.current_hp) / float(maxi(1, old_max_hp)), 0.0, 1.0)
	instance.species = target_species
	instance.form_index = target_species.default_form_index
	if instance.current_hp != PokemonInstanceResource.CURRENT_HP_AUTO:
		instance.current_hp = clampi(int(round(float(PokemonStatCalculator.max_hp(instance)) * hp_ratio)), 0, PokemonStatCalculator.max_hp(instance))
	return {
		"evolved": true,
		"before_species": before_species,
		"after_species": target_species.species_id,
		"result": String(chosen.get("result", "")),
	}


static func build_reverse_lookup() -> Dictionary:
	var out: Dictionary = {}
	for species in _all_generated_species():
		if species == null or species.evolution_from.is_empty():
			continue
		if not out.has(species.evolution_from):
			out[species.evolution_from] = []
		(out[species.evolution_from] as Array).append(species.species_id)
	return out


static func _requirements_met(instance: PokemonInstanceResource, requirements: Variant) -> bool:
	if not (requirements is Array):
		return true
	var saw_supported: bool = false
	for raw_req in requirements:
		if not (raw_req is Dictionary):
			continue
		var req: Dictionary = raw_req
		var kind: String = String(req.get("kind", ""))
		match kind:
			"level":
				saw_supported = true
				if instance.level < int(req.get("level", 0)):
					return false
			_:
				return false
	return saw_supported or (requirements as Array).is_empty()


static func _load_species_for_bare_slug(bare_slug: String) -> PokemonSpeciesResource:
	if bare_slug.is_empty():
		return null
	for species in _all_generated_species():
		if species == null:
			continue
		if species.species_id == bare_slug or species.species_id.ends_with("_" + bare_slug):
			return species
	return null


static func _all_generated_species() -> Array[PokemonSpeciesResource]:
	var out: Array[PokemonSpeciesResource] = []
	var dir: DirAccess = DirAccess.open(GENERATED_SPECIES_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var filename: String = dir.get_next()
	while filename != "":
		if not dir.current_is_dir() and filename.ends_with(".tres"):
			var species: PokemonSpeciesResource = load("%s/%s" % [GENERATED_SPECIES_DIR, filename]) as PokemonSpeciesResource
			if species != null:
				out.append(species)
		filename = dir.get_next()
	dir.list_dir_end()
	out.sort_custom(func(a: PokemonSpeciesResource, b: PokemonSpeciesResource) -> bool: return a.species_id < b.species_id)
	return out
