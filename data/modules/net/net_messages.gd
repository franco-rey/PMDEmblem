class_name NetMessages
extends RefCounted

const PROTOCOL: int = 1

const HELLO: String = "hello"
const WELCOME: String = "welcome"
const REJECT: String = "reject"
const LOBBY: String = "lobby"
const START: String = "start"
const START_REFUSED: String = "start_refused"
const START_ACK: String = "start_ack"
const BATTLE_READY: String = "battle_ready"
const CMD: String = "cmd"
const SYNC: String = "sync"
const DESYNC: String = "desync"
const RESIGN: String = "resign"
const BYE: String = "bye"
const REJOIN: String = "rejoin"
const CATCHUP: String = "catchup"

const REQUIRED: Dictionary = {
	HELLO: ["protocol", "version", "name", "content"],
	WELCOME: ["side", "host_name", "lobby"],
	REJECT: ["reason"],
	LOBBY: ["state"],
	START: ["code", "battle_id", "units"],
	START_REFUSED: ["reason"],
	START_ACK: ["battle_id"],
	BATTLE_READY: ["battle_id"],
	CMD: ["seq", "turn", "line", "chain", "count"],
	SYNC: ["round", "chain", "count"],
	DESYNC: ["reason"],
	RESIGN: ["battle_id"],
	BYE: ["reason"],
	REJOIN: ["battle_id", "name"],
	CATCHUP: ["code", "battle_id", "lines", "chain", "count"],
}

const GENERATED_DIRS: Array[String] = [
	"res://data/models/pokemon/generated/species",
	"res://data/models/pokemon/generated/moves",
	"res://data/models/pokemon/generated/instances",
	"res://data/models/pokemon/moves/custom",
]
const TYPE_CHART_PATH: String = "res://data/models/pokemon/generated/types/type_chart.tres"

static var _content_cache: String = ""


static func build(kind: String, fields: Dictionary = {}) -> Dictionary:
	var message: Dictionary = fields.duplicate(true)
	message["k"] = kind
	return message


static func validate(message: Variant) -> String:
	if not (message is Dictionary):
		return "message is not a dictionary"
	var data: Dictionary = message
	var kind: String = String(data.get("k", ""))
	if kind.is_empty():
		return "message has no kind"
	if not REQUIRED.has(kind):
		return "unknown kind %s" % kind
	for field in REQUIRED[kind]:
		if not data.has(field):
			return "%s is missing %s" % [kind, String(field)]
	return ""


static func chain_start() -> String:
	return "".sha256_text()


static func chain_next(previous: String, line: String) -> String:
	return (previous + line).sha256_text()


static func chain_of(lines: Array) -> String:
	var value: String = chain_start()
	for line in lines:
		value = chain_next(value, String(line))
	return value


static func content_fingerprint() -> String:
	if not _content_cache.is_empty():
		return _content_cache
	var parts: PackedStringArray = ["protocol=%d" % PROTOCOL]
	for path in GENERATED_DIRS:
		parts.append("%s=%d" % [path.get_file(), _count_files(path)])
	var chart: String = ""
	if FileAccess.file_exists(TYPE_CHART_PATH):
		var file: FileAccess = FileAccess.open(TYPE_CHART_PATH, FileAccess.READ)
		if file != null:
			chart = file.get_as_text().sha256_text()
			file.close()
	parts.append("chart=%s" % chart)
	parts.append("custom=%s" % ",".join(_custom_move_ids()))
	_content_cache = " ".join(parts).sha256_text()
	return _content_cache


static func unit_fingerprints(definition: SkirmishDefinitionResource) -> PackedStringArray:
	var out: PackedStringArray = []
	if definition == null:
		return out
	for side in [definition.player_team, definition.enemy_team]:
		for instance in side:
			out.append(unit_fingerprint(instance))
	return out


static func unit_fingerprint(instance: PokemonInstanceResource) -> String:
	if instance == null:
		return "-"
	var moves: PackedStringArray = []
	for i in range(instance.move_slots.size()):
		var move: PokemonMoveResource = instance.move_slots[i]
		if move == null:
			continue
		var pp: int = int(instance.pp_state[i]) if i < instance.pp_state.size() else (move.pp if move != null else 0)
		moves.append("%s:%d" % [move.move_id, pp])
	return "%s/%d/L%d/%s/%s/%s/%d/%s" % [
		instance.species.species_id if instance.species != null else "?",
		instance.form_index,
		instance.level,
		instance.nature_id,
		instance.ability_override,
		instance.held_item.item_id if instance.held_item != null else "-",
		instance.gender,
		",".join(moves),
	]


static func fingerprint_diff(mine: PackedStringArray, theirs: PackedStringArray) -> String:
	if mine.size() != theirs.size():
		return "team sizes differ (%d vs %d)" % [mine.size(), theirs.size()]
	for i in range(mine.size()):
		if mine[i] != theirs[i]:
			return "unit %d differs (%s vs %s)" % [i + 1, mine[i], theirs[i]]
	return ""


static func _count_files(path: String) -> int:
	return ResourceDir.file_names(path, ".tres").size() + ResourceDir.file_names(path, ".json").size()


static func _custom_move_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for file in ResourceDir.file_names("res://data/models/pokemon/moves/custom"):
		out.append(file.trim_suffix(".tres"))
	return out
