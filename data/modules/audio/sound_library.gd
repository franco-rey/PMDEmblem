class_name SoundLibrary
extends RefCounted

const MANIFEST_PATH: String = "res://data/models/audio/generated/sound_manifest.json"

static var _manifest: Dictionary = {}
static var _loaded: bool = false
static var _streams: Dictionary = {}


static func manifest() -> Dictionary:
	if _loaded:
		return _manifest
	_loaded = true
	if FileAccess.file_exists(MANIFEST_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if parsed is Dictionary:
			_manifest = parsed
	return _manifest


static func available() -> bool:
	return not (manifest().get("sounds", {}) as Dictionary).is_empty()


static func count() -> int:
	return (manifest().get("sounds", {}) as Dictionary).size()


const CRY_PREFIX: String = "cry:"


static func key_for(name: String) -> String:
	var sounds: Dictionary = manifest().get("sounds", {})
	if sounds.has(name):
		return name
	if name.begins_with(CRY_PREFIX) and has_cry(name.trim_prefix(CRY_PREFIX)):
		return name
	var by_name: Dictionary = manifest().get("by_name", {})
	return String(by_name.get(name, ""))


static func has(name: String) -> bool:
	return not name.is_empty() and not key_for(name).is_empty()


static func path_for(name: String) -> String:
	var key: String = key_for(name)
	if key.is_empty():
		return ""
	if key.begins_with(CRY_PREFIX):
		return String((manifest().get("cries", {}) as Dictionary).get(key.trim_prefix(CRY_PREFIX), ""))
	var entry: Dictionary = (manifest().get("sounds", {}) as Dictionary).get(key, {})
	return String(entry.get("path", ""))


static func has_cry(slug: String) -> bool:
	return not slug.is_empty() and (manifest().get("cries", {}) as Dictionary).has(slug)


static func cry_name(slug: String) -> String:
	return CRY_PREFIX + slug


static func _load_stream(path: String) -> AudioStream:
	var absolute: String = ProjectSettings.globalize_path(path)
	match path.get_extension().to_lower():
		"ogg":
			return AudioStreamOggVorbis.load_from_file(absolute)
		"wav":
			return AudioStreamWAV.load_from_file(absolute)
		"mp3":
			return AudioStreamMP3.load_from_file(absolute)
	return null


static func stream_for(name: String) -> AudioStream:
	var key: String = key_for(name)
	if key.is_empty():
		return null
	if _streams.has(key):
		return _streams[key]
	var path: String = path_for(key)
	var stream: AudioStream = null
	if not path.is_empty() and FileAccess.file_exists(path):
		stream = _load_stream(path)
	_streams[key] = stream
	return stream


static func status_sound(status_id: String) -> String:
	return String((manifest().get("status_sounds", {}) as Dictionary).get(status_id, ""))


static func map_status_sound(condition_id: String) -> String:
	return String((manifest().get("map_status_sounds", {}) as Dictionary).get(condition_id, ""))
