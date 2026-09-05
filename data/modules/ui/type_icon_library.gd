class_name TypeIconLibrary
extends RefCounted

const ICON_DIR: String = "res://assets/visuals/raw_asset/Element/"

static var _cache: Dictionary = {}


static func texture_for(type_id: String) -> Texture2D:
	var id: String = type_id.to_lower()
	if id.is_empty():
		return null
	if _cache.has(id):
		return _cache[id]
	var path: String = "%s%s.png" % [ICON_DIR, id]
	var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_cache[id] = texture
	return texture
