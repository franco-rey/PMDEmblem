class_name SpriteVariants
extends RefCounted

const ACTOR_ROOT: String = "res://assets/textures/actor/pokemon/"
const PORTRAIT_ROOT: String = "res://assets/textures/pokemon/portraits/"
const SHINY: String = "_shiny"
const FEMALE: String = "_female"
const FEMALE_SHINY: String = "_female_shiny"


static func chain(shiny: bool, female: bool) -> Array[String]:
	var out: Array[String] = []
	if shiny and female:
		out.append(FEMALE_SHINY)
	if shiny:
		out.append(SHINY)
	if female:
		out.append(FEMALE)
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


static func sprite_suffix(slug: String, shiny: bool, female: bool) -> String:
	for suffix in chain(shiny, female):
		if has_sprites(slug, suffix):
			return suffix
	return ""


static func portrait_suffix(slug: String, shiny: bool, female: bool) -> String:
	for suffix in chain(shiny, female):
		if has_portrait(slug, suffix):
			return suffix
	return ""


static func portrait_slug(slug: String, shiny: bool, female: bool) -> String:
	return slug + portrait_suffix(slug, shiny, female)


static func resolve_sprite_set(base: PokemonSpriteSetResource, slug: String, shiny: bool, female: bool) -> PokemonSpriteSetResource:
	if base == null or slug.is_empty() or not (shiny or female):
		return base
	var from: String = "/pokemon/%s/" % slug
	for suffix in chain(shiny, female):
		if suffix.is_empty():
			break
		if not has_sprites(slug, suffix):
			continue
		var copy: PokemonSpriteSetResource = _rewritten_copy(base, from, "/pokemon/%s%s/" % [slug, suffix])
		if copy.idle_path.is_empty() or ResourceLoader.exists(copy.idle_path):
			return copy
	return base


static func _rewritten_copy(base: PokemonSpriteSetResource, from: String, to: String) -> PokemonSpriteSetResource:
	var copy: PokemonSpriteSetResource = base.duplicate(true) as PokemonSpriteSetResource
	for property in copy.get_property_list():
		var name: String = String(property.get("name", ""))
		if not name.ends_with("_path"):
			continue
		var value: Variant = copy.get(name)
		if value is String and String(value).contains(from):
			copy.set(name, String(value).replace(from, to))
	copy.animation_states = _rewrite_paths(copy.animation_states, from, to)
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
