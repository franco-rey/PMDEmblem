class_name ShinyRules
extends RefCounted

const ODDS: int = 4096
const SUFFIX: String = "_shiny"
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
	return SpriteVariants.has_sprites(slug, SpriteVariants.SHINY)


static func has_shiny_portrait(slug: String) -> bool:
	return SpriteVariants.has_portrait(slug, SpriteVariants.SHINY)


static func portrait_slug(slug: String, shiny: bool) -> String:
	return SpriteVariants.portrait_slug(slug, shiny, false)


static func shiny_sprite_set(base: PokemonSpriteSetResource, slug: String) -> PokemonSpriteSetResource:
	return SpriteVariants.resolve_sprite_set(base, slug, true, false)


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
