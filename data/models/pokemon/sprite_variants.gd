class_name SpriteVariants
extends RefCounted

const ACTOR_ROOT: String = "res://assets/textures/actor/pokemon/"
const PORTRAIT_ROOT: String = "res://assets/textures/pokemon/portraits/"
const SHINY: String = "_shiny"
const FEMALE: String = "_female"
const FEMALE_SHINY: String = "_female_shiny"
const FORM: String = "_form"
const FRAME_KEYS: Array[String] = ["cell_size", "frame_count", "timing", "checksum"]


static func form_suffix(form_index: int, default_index: int = 0) -> String:
	return "" if form_index == default_index or form_index < 0 else "%s%d" % [FORM, form_index]


static func chain(shiny: bool, female: bool, form: String = "") -> Array[String]:
	var out: Array[String] = []
	if shiny and female:
		out.append(form + FEMALE_SHINY)
	if shiny:
		out.append(form + SHINY)
	if female:
		out.append(form + FEMALE)
	out.append(form)
	if not form.is_empty():
		out.append("")
	return out


static func has_sprites(slug: String, suffix: String) -> bool:
	if slug.is_empty():
		return false
	if suffix.is_empty():
		return true
	var folder: String = "%s%s%s/" % [ACTOR_ROOT, slug, suffix]
	return FileAccess.file_exists(folder + "AnimData.xml") and FileAccess.file_exists(folder + "anchors.json")


static func has_portrait(slug: String, suffix: String) -> bool:
	if slug.is_empty():
		return false
	if suffix.is_empty():
		return true
	return ResourceLoader.exists("%s%s%s/Normal.png" % [PORTRAIT_ROOT, slug, suffix])


static func sprite_suffix(slug: String, shiny: bool, female: bool, form: String = "") -> String:
	for suffix in chain(shiny, female, form):
		if has_sprites(slug, suffix):
			return suffix
	return ""


static func portrait_suffix(slug: String, shiny: bool, female: bool, form: String = "") -> String:
	for suffix in chain(shiny, female, form):
		if has_portrait(slug, suffix):
			return suffix
	return ""


static func portrait_slug(slug: String, shiny: bool, female: bool, form: String = "") -> String:
	return slug + portrait_suffix(slug, shiny, female, form)


static func resolve_sprite_set(base: PokemonSpriteSetResource, slug: String, shiny: bool, female: bool, form: String = "") -> PokemonSpriteSetResource:
	if base == null or slug.is_empty() or not (shiny or female or not form.is_empty()):
		return base
	var from: String = "/pokemon/%s/" % slug
	for suffix in chain(shiny, female, form):
		if suffix.is_empty():
			break
		if not has_sprites(slug, suffix):
			continue
		var copy: PokemonSpriteSetResource = _rewritten_copy(base, from, "/pokemon/%s%s/" % [slug, suffix], suffix.begins_with(FORM))
		if copy.idle_path.is_empty() or ResourceLoader.exists(copy.idle_path):
			return copy
	return base


static func _rewritten_copy(base: PokemonSpriteSetResource, from: String, to: String, other_frames: bool) -> PokemonSpriteSetResource:
	var copy: PokemonSpriteSetResource = base.duplicate(true) as PokemonSpriteSetResource
	for property in copy.get_property_list():
		var name: String = String(property.get("name", ""))
		if not name.ends_with("_path"):
			continue
		var value: Variant = copy.get(name)
		if value is String and String(value).contains(from):
			copy.set(name, String(value).replace(from, to))
	var states: Dictionary = _rewrite_paths(copy.animation_states, from, to)
	var kept: Dictionary = {}
	for key in states.keys():
		var entry: Variant = states[key]
		if not (entry is Dictionary):
			continue
		var state: Dictionary = (entry as Dictionary).duplicate(true)
		var path: String = String(state.get("path", ""))
		if not path.is_empty() and not ResourceLoader.exists(path):
			continue
		if other_frames:
			for frame_key in FRAME_KEYS:
				state.erase(frame_key)
		kept[key] = state
	copy.animation_states = kept
	if other_frames:
		copy.cell_size = Vector2i.ZERO
		copy.frame_counts = {}
		copy.validation_warnings = []
	copy.move_animation_map = _rewrite_paths(copy.move_animation_map, from, to)
	return copy


static func _rewrite_paths(value: Variant, from: String, to: String) -> Variant:
	if value is String:
		return String(value).replace(from, to) if String(value).contains(from) else value
	if value is Dictionary:
		var out: Dictionary = {}
		for key in (value as Dictionary).keys():
			out[key] = _rewrite_paths((value as Dictionary)[key], from, to)
		return out
	if value is Array:
		var list: Array = []
		for item in (value as Array):
			list.append(_rewrite_paths(item, from, to))
		return list
	return value
