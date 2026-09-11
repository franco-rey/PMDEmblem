class_name PortraitLibrary
extends RefCounted

const ROOT: String = "res://assets/textures/pokemon/portraits/"
const NORMAL: String = "Normal"
const EXPRESSIONS: Array[String] = ["Normal", "Happy", "Pain", "Angry", "Worried", "Sad", "Crying", "Shouting", "Teary-Eyed", "Determined", "Joyous", "Inspired", "Surprised", "Dizzy", "Sigh", "Stunned", "Special0"]

static var _cache: Dictionary = {}


static func texture_for(slug: String, expression: String = NORMAL) -> Texture2D:
	if slug.is_empty():
		return null
	var key: String = "%s/%s" % [slug, expression]
	if _cache.has(key):
		return _cache[key]
	var path: String = "%s%s/%s.png" % [ROOT, slug, expression]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	elif expression != NORMAL:
		texture = texture_for(slug, NORMAL)
	_cache[key] = texture
	return texture


static func has_expression(slug: String, expression: String) -> bool:
	return ResourceLoader.exists("%s%s/%s.png" % [ROOT, slug, expression])


static func slug_for_stats(stats: Stats) -> String:
	if stats == null or stats.pokemon_instance == null or stats.pokemon_instance.species == null:
		return ""
	return SpriteVariants.portrait_slug(String(stats.pokemon_instance.species.species_id), stats.pokemon_instance.shiny, stats.gender == GenderRules.FEMALE)


static func slug_for_pawn(pawn: TacticsPawn) -> String:
	return slug_for_stats(pawn.stats) if pawn != null else ""


static func slug_for_path(path: String) -> String:
	return path.get_file().get_basename()
