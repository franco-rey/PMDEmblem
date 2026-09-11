class_name FormRules
extends RefCounted

const RANDOM_CHOICE: String = "random"
const CODE_MARK: String = "~"
const ROLL_SALT: int = 0x7F4A7C15


static func default_index(species: PokemonSpeciesResource) -> int:
	if species == null or species.forms.is_empty():
		return 0
	return clampi(species.default_form_index, 0, species.forms.size() - 1)


static func options(species: PokemonSpeciesResource) -> Array[int]:
	var out: Array[int] = []
	var base: int = default_index(species)
	out.append(base)
	if species == null:
		return out
	for i in range(species.forms.size()):
		if i == base:
			continue
		var form: PokemonFormResource = species.forms[i]
		if form == null or form.temporary or not form.released:
			continue
		if not SpriteVariants.has_sprites(String(species.species_id), SpriteVariants.form_suffix(i, base)):
			continue
		out.append(i)
	return out


static func is_choice(species: PokemonSpeciesResource) -> bool:
	return options(species).size() > 1


static func is_selectable(species: PokemonSpeciesResource, index: int) -> bool:
	return options(species).has(index)


static func form_name(species: PokemonSpeciesResource, index: int) -> String:
	if species == null or index < 0 or index >= species.forms.size() or species.forms[index] == null:
		return ""
	return String(species.forms[index].form_name).strip_edges()


static func label(species: PokemonSpeciesResource, index: int) -> String:
	var name: String = form_name(species, index)
	if name.is_empty():
		name = species.canonical_name if species != null and index == default_index(species) and not species.canonical_name.is_empty() else "Form %d" % index
	var twins: int = 0
	if species != null:
		for other in options(species):
			if other != index and form_name(species, other) == form_name(species, index):
				twins += 1
	return "%s (%d)" % [name, index] if twins > 0 else name


static func roll(species: PokemonSpeciesResource, seed: int, side_key: String, slot_index: int) -> int:
	var list: Array[int] = options(species)
	if list.size() <= 1:
		return list[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("form:%d:%s:%d" % [seed ^ ROLL_SALT, side_key, slot_index])
	return list[rng.randi_range(0, list.size() - 1)]


static func choice_error(species: PokemonSpeciesResource, index: int, name: String) -> String:
	if species == null:
		return "%s has no forms" % name
	if index < 0 or index >= species.forms.size():
		return "%s has no form %d" % [name, index]
	if not is_selectable(species, index):
		var form: PokemonFormResource = species.forms[index]
		var why: String = "is a battle-only form" if form != null and form.temporary else ("is not released" if form != null and not form.released else "has no packaged sprites")
		return "%s form %d %s" % [name, index, why]
	return ""


static func code_suffix(instance: PokemonInstanceResource) -> String:
	if instance == null or instance.species == null or instance.form_index == default_index(instance.species):
		return ""
	return "%s%d" % [CODE_MARK, instance.form_index]


static func display_name(instance: PokemonInstanceResource) -> String:
	if instance == null:
		return ""
	var name: String = form_name(instance.species, instance.form_index) if instance.species != null and instance.form_index != default_index(instance.species) else ""
	return name if not name.is_empty() else instance.display_name()


static func decorate(name: String, stats: Stats) -> String:
	if stats == null or stats.pokemon_instance == null or stats.pokemon_instance.species == null:
		return name
	var instance: PokemonInstanceResource = stats.pokemon_instance
	if instance.form_index == default_index(instance.species) or not instance.nickname.is_empty():
		return name
	var form: String = form_name(instance.species, instance.form_index)
	if form.is_empty():
		return name
	var species_name: String = instance.species.canonical_name
	if not species_name.is_empty() and name.contains(species_name):
		return name.replace(species_name, form)
	return "%s (%s)" % [name, form]
