class_name ShinyRules
extends RefCounted

const ODDS: int = 4096
const SUFFIX: String = "_shiny"
const ACTOR_ROOT: String = "res://assets/textures/actor/pokemon/"
const PORTRAIT_ROOT: String = "res://assets/textures/pokemon/portraits/"
const SPARKLE_INDEX: String = "Screen_Sparkle_RSE"
const SPARKLE_PATH: String = "res://assets/visuals/raw_asset/Particle/Screen_Sparkle_RSE.None.png"
const SPARKLE_CELL: int = 16
const SPARKLE_FRAMES: int = 4
const SPARKLE_FRAME_TIME: int = 5
const SPARKLE_OFFSETS: Array[Vector3] = [
	Vector3(0.0, 1.1, 0.0), Vector3(-0.45, 0.7, 0.2), Vector3(0.45, 0.85, -0.2), Vector3(-0.3, 1.4, -0.25), Vector3(0.35, 1.35, 0.3), Vector3(0.0, 0.45, 0.4),
]

static var force_all: bool = false


static func roll(seed: int, group: String, index: int, species_id: String) -> bool:
	if force_all:
		return true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("shiny:%d:%s:%d:%s" % [seed, group, index, species_id])
	return rng.randi_range(0, ODDS - 1) == 0


static func has_shiny_sprites(slug: String) -> bool:
	if slug.is_empty():
		return false
	var folder: String = "%s%s%s/" % [ACTOR_ROOT, slug, SUFFIX]
	return FileAccess.file_exists(folder + "AnimData.xml") and FileAccess.file_exists(folder + "anchors.json")


static func has_shiny_portrait(slug: String) -> bool:
	return not slug.is_empty() and ResourceLoader.exists("%s%s%s/Normal.png" % [PORTRAIT_ROOT, slug, SUFFIX])


static func portrait_slug(slug: String, shiny: bool) -> String:
	return slug + SUFFIX if shiny and has_shiny_portrait(slug) else slug


static func shiny_sprite_set(base: PokemonSpriteSetResource, slug: String) -> PokemonSpriteSetResource:
	if base == null or not has_shiny_sprites(slug):
		return base
	var from: String = "/pokemon/%s/" % slug
	var to: String = "/pokemon/%s%s/" % [slug, SUFFIX]
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
	if not copy.idle_path.is_empty() and not ResourceLoader.exists(copy.idle_path):
		return base
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


static func sparkle_asset() -> Dictionary:
	if not ResourceLoader.exists(SPARKLE_PATH):
		return {}
	return {
		"category": "Particle",
		"key": SPARKLE_INDEX,
		"lookup_key": SPARKLE_INDEX,
		"path": SPARKLE_PATH,
		"layout": {"cell": [SPARKLE_CELL, SPARKLE_CELL], "frames": SPARKLE_FRAMES, "kind": "None", "rotate": "None", "rows": 1, "size": [SPARKLE_CELL * SPARKLE_FRAMES, SPARKLE_CELL]},
	}
