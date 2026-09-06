class_name CustomMoves
extends RefCounted

const CUSTOM_DIR: String = "res://data/models/pokemon/moves/custom/"
const GENERATED_DIR: String = "res://data/models/pokemon/generated/moves/"
const LEARNSETS_PATH: String = "res://data/models/pokemon/moves/custom/custom_learnsets.json"

static var _learnsets: Dictionary = {}
static var _learnsets_loaded: bool = false


static func path_for(move_id: String) -> String:
	var key: String = move_id.strip_edges().to_lower()
	if key.is_empty():
		return ""
	var generated: String = "%s%s.tres" % [GENERATED_DIR, key]
	if ResourceLoader.exists(generated):
		return generated
	var custom: String = "%s%s.tres" % [CUSTOM_DIR, key]
	return custom if ResourceLoader.exists(custom) else ""


static func load_move(move_id: String) -> PokemonMoveResource:
	var path: String = path_for(move_id)
	return load(path) as PokemonMoveResource if not path.is_empty() else null


static func learnsets() -> Dictionary:
	if _learnsets_loaded:
		return _learnsets
	_learnsets_loaded = true
	if FileAccess.file_exists(LEARNSETS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEARNSETS_PATH))
		if parsed is Dictionary:
			_learnsets = parsed
	return _learnsets


static func move_ids_for_species(species_id: String) -> Array[String]:
	var out: Array[String] = []
	for move_id in learnsets():
		if (learnsets()[move_id] as Array).has(species_id):
			out.append(String(move_id))
	return out


static func custom_move_ids() -> Array[String]:
	var out: Array[String] = []
	for move_id in learnsets():
		out.append(String(move_id))
	return out
