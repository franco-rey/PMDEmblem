class_name SkirmishCode
extends RefCounted

const SkirmishControlMode = preload("res://data/modules/skirmish/skirmish_control_mode.gd")

const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"
const DEFAULT_MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const MAX_MATCHES: int = 10


static func parse(code: String) -> Dictionary:
	var trimmed: String = code.strip_edges()
	if trimmed.is_empty():
		return {"ok": false, "error": "Skirmish code is empty"}
	var matches: Array[Dictionary] = []
	var segments: PackedStringArray = trimmed.split(";", false)
	for raw_segment in segments:
		var segment: String = String(raw_segment).strip_edges()
		if segment.is_empty():
			return {"ok": false, "error": "Empty match in skirmish code"}
		var parsed: Dictionary = _parse_segment(segment)
		if not bool(parsed.get("ok", false)):
			return parsed
		for match_data in parsed.get("matches", []):
			matches.append(match_data)
	if matches.is_empty():
		return {"ok": false, "error": "Skirmish code did not contain a match"}
	if matches.size() > MAX_MATCHES:
		return {"ok": false, "error": "Skirmish code supports at most %d matches" % MAX_MATCHES}
	return {"ok": true, "matches": matches}


static func build_definitions(code: String, fallback_state: Dictionary = {}) -> Dictionary:
	var parsed: Dictionary = parse(code)
	if not bool(parsed.get("ok", false)):
		return parsed
	var definitions: Array[SkirmishDefinitionResource] = []
	var first_seed: int = 0
	var match_index: int = 0
	for match_data in parsed.get("matches", []):
		var built: Dictionary = _build_match(match_data, fallback_state, match_index)
		if not bool(built.get("ok", false)):
			return built
		var definition: SkirmishDefinitionResource = built.get("definition") as SkirmishDefinitionResource
		if definition == null:
			return {"ok": false, "error": "Skirmish code built an empty definition"}
		definitions.append(definition)
		if match_index == 0:
			first_seed = int(built.get("seed", 0))
		match_index += 1
	return {
		"ok": true,
		"definitions": definitions,
		"seed": first_seed,
		"code": code.strip_edges(),
	}


static func encode_definition(definition: SkirmishDefinitionResource) -> String:
	if definition == null:
		return ""
	var tokens: Array[String] = ["match", "seed=%d" % definition.seed, "mode=%s" % _mode_token(definition.control_mode)]
	if definition.map != null and not definition.map.map_id.is_empty() and definition.map.resource_path != DEFAULT_MAP_PATH:
		tokens.append("map=%s" % definition.map.map_id)
	if definition.multiverse:
		tokens.append("multiverse=1")
	if definition.ai_level != AIProfile.DEFAULT_LEVEL:
		tokens.append("ai=%d" % AIProfile.clamp_level(definition.ai_level))
	var player: String = _encode_team(definition.player_team)
	var enemy: String = _encode_team(definition.enemy_team)
	if not player.is_empty():
		tokens.append("p=%s" % player)
	if not enemy.is_empty():
		tokens.append("e=%s" % enemy)
	return " ".join(tokens)


static func _encode_team(team: Array[PokemonInstanceResource]) -> String:
	var entries: Array[String] = []
	for instance in team:
		if instance == null or instance.species == null:
			continue
		var moves: Array[String] = []
		for move in instance.move_slots:
			if move != null and not moves.has(move.move_id):
				moves.append(move.move_id)
		var fields: Array[String] = ["%s@%d" % [instance.species.species_id, instance.level], ",".join(moves), instance.ability_override, instance.held_item.item_id if instance.held_item != null else ""]
		while fields.size() > 1 and String(fields[fields.size() - 1]).is_empty():
			fields.remove_at(fields.size() - 1)
		entries.append(":".join(fields))
	return "|".join(entries)


static func _mode_token(mode: String) -> String:
	match SkirmishControlMode.normalize(mode):
		SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER:
			return "pvp"
		SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU:
			return "bots"
		_:
			return "pvc"


static func encode_summary(definitions: Array[SkirmishDefinitionResource]) -> String:
	if definitions.is_empty():
		return "0 matches"
	var pieces: Array[String] = []
	for i in range(definitions.size()):
		var definition: SkirmishDefinitionResource = definitions[i]
		var mode: String = SkirmishControlMode.label(definition.control_mode if definition != null else "")
		var seed: int = definition.seed if definition != null else 0
		var player_count: int = definition.player_team.size() if definition != null else 0
		var enemy_count: int = definition.enemy_team.size() if definition != null else 0
		pieces.append("#%d %dv%d %s seed=%d" % [i + 1, player_count, enemy_count, mode, seed])
	return "; ".join(pieces)


static func is_rich_code(text: String) -> bool:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return false
	if trimmed.is_valid_int():
		return false
	if _is_integer_with_bots(trimmed):
		return false
	var lower: String = trimmed.to_lower()
	return (
		lower.contains(";")
		or lower.contains("=")
		or lower.begins_with("series")
		or lower.begins_with("match")
	)


static func is_legacy_seed_or_flag(text: String) -> bool:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return true
	if trimmed.is_valid_int():
		return true
	return _is_integer_with_bots(trimmed)


static func legacy_seed_and_mode(text: String, default_mode: String) -> Dictionary:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return {
			"seed_text": "",
			"control_mode": SkirmishControlMode.normalize(default_mode),
		}
	var tokens: PackedStringArray = trimmed.split(" ", false)
	var seed_text: String = ""
	var mode: String = SkirmishControlMode.normalize(default_mode)
	for raw_token in tokens:
		var token: String = String(raw_token).strip_edges()
		if token.is_empty():
			continue
		if token == "-bots":
			mode = SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU
		elif token.is_valid_int() and seed_text.is_empty():
			seed_text = token
		else:
			return {"ok": false, "error": "Seed must be an integer, empty, or use -bots"}
	return {
		"seed_text": seed_text,
		"control_mode": mode,
	}


static func _parse_segment(segment: String) -> Dictionary:
	var tokens: PackedStringArray = segment.split(" ", false)
	var raw: Dictionary = {
		"kind": "match",
		"seed": null,
		"mode": SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_CPU,
		"team": null,
		"matches": 1,
		"map": "",
		"difficulty": null,
		"player_specs": [],
		"enemy_specs": [],
		"multiverse": false,
		"ai": null,
		"raw": segment,
	}
	var saw_key_value: bool = false
	for raw_token in tokens:
		var token: String = String(raw_token).strip_edges()
		if token.is_empty():
			continue
		if token == "-bots":
			raw["mode"] = SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU
			continue
		if token.contains("="):
			saw_key_value = true
			var key: String = token.get_slice("=", 0).strip_edges().to_lower()
			var value: String = token.substr(key.length() + 1).strip_edges()
			var applied: Dictionary = _apply_key_value(raw, key, value)
			if not bool(applied.get("ok", false)):
				return applied
			continue
		if saw_key_value:
			return {"ok": false, "error": "Unknown token '%s'" % token}
		match token.to_lower():
			"series":
				raw["kind"] = "series"
			"match":
				raw["kind"] = "match"
			_:
				if token.is_valid_int() and raw["seed"] == null:
					raw["seed"] = int(token)
				else:
					return {"ok": false, "error": "Unknown token '%s'" % token}
	var count: int = int(raw["matches"])
	if count < 1 or count > MAX_MATCHES:
		return {"ok": false, "error": "matches must be 1-%d" % MAX_MATCHES}
	var matches: Array[Dictionary] = []
	for i in range(count):
		var match_data: Dictionary = raw.duplicate(true)
		if raw["seed"] != null:
			match_data["seed"] = int(raw["seed"]) + i
		match_data["series_index"] = i
		match_data["series_count"] = count
		matches.append(match_data)
	return {"ok": true, "matches": matches}


static func _apply_key_value(raw: Dictionary, key: String, value: String) -> Dictionary:
	match key:
		"seed":
			if not value.is_valid_int():
				return {"ok": false, "error": "seed must be an integer"}
			raw["seed"] = int(value)
		"mode":
			if value.is_empty() or not SkirmishControlMode.is_valid(value):
				return {"ok": false, "error": "mode must be pvc, pvp, or bots"}
			raw["mode"] = SkirmishControlMode.normalize(value)
		"team":
			if not value.is_valid_int():
				return {"ok": false, "error": "team must be 1-8"}
			var team_size: int = int(value)
			if team_size < CustomSkirmishBuilder.MIN_TEAM_SIZE or team_size > CustomSkirmishBuilder.ABSOLUTE_MAX_TEAM_SIZE:
				return {"ok": false, "error": "team must be 1-%d" % CustomSkirmishBuilder.ABSOLUTE_MAX_TEAM_SIZE}
			raw["team"] = team_size
		"matches":
			if not value.is_valid_int():
				return {"ok": false, "error": "matches must be 1-%d" % MAX_MATCHES}
			var match_count: int = int(value)
			if match_count < 1 or match_count > MAX_MATCHES:
				return {"ok": false, "error": "matches must be 1-%d" % MAX_MATCHES}
			raw["matches"] = match_count
		"multiverse":
			raw["multiverse"] = value in ["1", "true", "on", "yes"]
		"ai":
			if not value.is_valid_int():
				return {"ok": false, "error": "ai must be %d-%d" % [AIProfile.MIN_LEVEL, AIProfile.MAX_LEVEL]}
			var ai_value: int = int(value)
			if ai_value < AIProfile.MIN_LEVEL or ai_value > AIProfile.MAX_LEVEL:
				return {"ok": false, "error": "ai must be %d-%d" % [AIProfile.MIN_LEVEL, AIProfile.MAX_LEVEL]}
			raw["ai"] = ai_value
		"map":
			if value.is_empty():
				return {"ok": false, "error": "map cannot be empty"}
			raw["map"] = value
		"difficulty":
			if not value.is_valid_int():
				return {"ok": false, "error": "difficulty must be 0-4"}
			var difficulty: int = int(value)
			if difficulty < 0 or difficulty > 4:
				return {"ok": false, "error": "difficulty must be 0-4"}
			raw["difficulty"] = difficulty
		"p":
			var specs: Dictionary = _parse_pokemon_list(value)
			if not bool(specs.get("ok", false)):
				return specs
			raw["player_specs"] = specs["specs"]
		"e":
			var specs: Dictionary = _parse_pokemon_list(value)
			if not bool(specs.get("ok", false)):
				return specs
			raw["enemy_specs"] = specs["specs"]
		_:
			return {"ok": false, "error": "Unknown token '%s=%s'" % [key, value]}
	return {"ok": true}


static func _parse_pokemon_list(value: String) -> Dictionary:
	if value.strip_edges().is_empty():
		return {"ok": false, "error": "Pokemon list cannot be empty"}
	var out: Array[Dictionary] = []
	for raw_entry in value.split("|", false):
		var entry: String = String(raw_entry).strip_edges()
		if entry.is_empty():
			return {"ok": false, "error": "Pokemon list contains an empty entry"}
		var fields: PackedStringArray = entry.split(":", true)
		if fields.size() > 4:
			return {"ok": false, "error": "Pokemon entry has too many fields (slug@level:moves:ability:item)"}
		var base_part: String = String(fields[0])
		var move_part: String = String(fields[1]) if fields.size() > 1 else ""
		var ability_part: String = String(fields[2]).strip_edges().to_lower() if fields.size() > 2 else ""
		var item_part: String = String(fields[3]).strip_edges().to_lower() if fields.size() > 3 else ""
		if item_part == "none":
			item_part = ""
		var slug: String = base_part
		var level: int = 0
		if base_part.contains("@"):
			slug = base_part.get_slice("@", 0)
			var level_text: String = base_part.substr(slug.length() + 1)
			if not level_text.is_valid_int():
				return {"ok": false, "error": "Pokemon level must be 1-100"}
			level = int(level_text)
			if level < 1 or level > 100:
				return {"ok": false, "error": "Pokemon level must be 1-100"}
		slug = slug.strip_edges()
		if slug.is_empty():
			return {"ok": false, "error": "Pokemon slug cannot be empty"}
		var moves: Array[String] = []
		if not move_part.strip_edges().is_empty():
			for raw_move in move_part.split(",", false):
				var move_slug: String = String(raw_move).strip_edges()
				if move_slug.is_empty():
					return {"ok": false, "error": "Move slug cannot be empty"}
				moves.append(move_slug)
			if moves.size() > PokemonInstanceResource.MAX_MOVE_SLOTS:
				return {"ok": false, "error": "Pokemon can list at most %d moves" % PokemonInstanceResource.MAX_MOVE_SLOTS}
		out.append({
			"slug": slug,
			"level": level,
			"moves": moves,
			"ability": ability_part,
			"item": item_part,
		})
	return {"ok": true, "specs": out}


static func _build_match(match_data: Dictionary, fallback_state: Dictionary, match_index: int) -> Dictionary:
	var seed: int = _resolve_match_seed(match_data)
	var mode: String = SkirmishControlMode.normalize(String(match_data.get("mode", "")))
	var map_path: String = _resolve_map_path(String(match_data.get("map", "")), String(fallback_state.get("map_path", "")))
	if map_path.is_empty():
		return {"ok": false, "error": "No map available"}
	var difficulty_value: Variant = match_data.get("difficulty", null)
	if difficulty_value == null:
		difficulty_value = fallback_state.get("difficulty_tier", CustomSkirmishBuilder.DEFAULT_RANDOM_DIFFICULTY_TIER)
	var difficulty: int = int(difficulty_value)
	var player_specs: Array = match_data.get("player_specs", [])
	var enemy_specs: Array = match_data.get("enemy_specs", [])
	var result: Dictionary = {}
	if player_specs.is_empty() and enemy_specs.is_empty():
		var team_size: int = _team_size(match_data, fallback_state)
		result = CustomSkirmishBuilder.build_random(team_size, map_path, str(seed), mode)
	elif not player_specs.is_empty() and enemy_specs.is_empty():
		var player_paths: Array[String] = _paths_for_specs(player_specs)
		if player_paths.is_empty():
			return {"ok": false, "error": _first_missing_spec_error(player_specs)}
		var enemy_size: int = int(match_data.get("team", fallback_state.get("enemy_team_size", player_paths.size())))
		result = CustomSkirmishBuilder.build_with_random_enemy(player_paths, map_path, str(seed), enemy_size, difficulty, "", "", mode)
	else:
		if player_specs.is_empty():
			return {"ok": false, "error": "Explicit enemy team requires p= player team"}
		var explicit_player_paths: Array[String] = _paths_for_specs(player_specs)
		var explicit_enemy_paths: Array[String] = _paths_for_specs(enemy_specs)
		if explicit_player_paths.is_empty():
			return {"ok": false, "error": _first_missing_spec_error(player_specs)}
		if explicit_enemy_paths.is_empty():
			return {"ok": false, "error": _first_missing_spec_error(enemy_specs)}
		result = CustomSkirmishBuilder.build(explicit_player_paths, explicit_enemy_paths, map_path, str(seed), mode)
	if not bool(result.get("ok", false)):
		return result
	var definition: SkirmishDefinitionResource = result.get("definition") as SkirmishDefinitionResource
	if definition == null:
		return {"ok": false, "error": "Builder returned no definition"}
	var explicit_result: Dictionary = _apply_explicit_specs(definition, player_specs, enemy_specs, seed)
	if not bool(explicit_result.get("ok", false)):
		return explicit_result
	SkirmishControlMode.apply_to_definition(definition, mode)
	definition.multiverse = bool(match_data.get("multiverse", false))
	var ai_setting: Variant = match_data.get("ai", null)
	definition.ai_level = AIProfile.clamp_level(int(ai_setting)) if ai_setting != null else AIProfile.DEFAULT_LEVEL
	var meta: Dictionary = definition.generation_metadata.duplicate(true)
	meta["skirmish_code"] = String(match_data.get("raw", ""))
	meta["series_index"] = match_index
	meta["series_count"] = int(match_data.get("series_count", 1))
	definition.generation_metadata = meta
	return {"ok": true, "definition": definition, "seed": seed}


static func _resolve_match_seed(match_data: Dictionary) -> int:
	if match_data.get("seed", null) != null:
		return int(match_data["seed"])
	return CustomSkirmishBuilder.resolve_seed("")


static func _team_size(match_data: Dictionary, fallback_state: Dictionary) -> int:
	if match_data.get("team", null) != null:
		return int(match_data["team"])
	if fallback_state.has("team_size"):
		return clampi(int(fallback_state["team_size"]), CustomSkirmishBuilder.MIN_TEAM_SIZE, CustomSkirmishBuilder.ABSOLUTE_MAX_TEAM_SIZE)
	if fallback_state.has("enemy_team_size"):
		return clampi(int(fallback_state["enemy_team_size"]), CustomSkirmishBuilder.MIN_TEAM_SIZE, CustomSkirmishBuilder.ABSOLUTE_MAX_TEAM_SIZE)
	return 3


static func _resolve_map_path(map_value: String, fallback_map_path: String) -> String:
	if not map_value.strip_edges().is_empty():
		if map_value.begins_with("res://"):
			return map_value if ResourceLoader.exists(map_value) else ""
		for path in CustomSkirmishBuilder.map_paths():
			if path.get_file().get_basename() == map_value:
				return path
			var map: MapDefinitionResource = load(path) as MapDefinitionResource
			if map != null and map.map_id == map_value:
				return path
		return ""
	if not fallback_map_path.is_empty() and ResourceLoader.exists(fallback_map_path):
		return fallback_map_path
	if ResourceLoader.exists(DEFAULT_MAP_PATH):
		return DEFAULT_MAP_PATH
	var maps: Array[String] = CustomSkirmishBuilder.map_paths()
	return maps[0] if not maps.is_empty() else ""


static func _paths_for_specs(specs: Array) -> Array[String]:
	var out: Array[String] = []
	for spec in specs:
		var path: String = _path_for_slug(String((spec as Dictionary).get("slug", "")))
		if path.is_empty():
			return []
		out.append(path)
	return out


static func _first_missing_spec_error(specs: Array) -> String:
	for spec in specs:
		var slug: String = String((spec as Dictionary).get("slug", ""))
		if _path_for_slug(slug).is_empty():
			return "Unknown Pokemon slug '%s'" % slug
	return "Unknown Pokemon slug"


static func _path_for_slug(slug: String) -> String:
	for path in CustomSkirmishBuilder.battle_ready_roster_paths():
		if path.get_file().get_basename() == slug:
			return path
	return ""


static func _apply_explicit_specs(
	definition: SkirmishDefinitionResource,
	player_specs: Array,
	enemy_specs: Array,
	seed: int
) -> Dictionary:
	if not player_specs.is_empty():
		var applied_player: Dictionary = _apply_side_specs(definition.player_team, player_specs, seed, "player")
		if not bool(applied_player.get("ok", false)):
			return applied_player
	if not enemy_specs.is_empty():
		var applied_enemy: Dictionary = _apply_side_specs(definition.enemy_team, enemy_specs, seed, "enemy")
		if not bool(applied_enemy.get("ok", false)):
			return applied_enemy
	return {"ok": true}


static func _apply_side_specs(team: Array[PokemonInstanceResource], specs: Array, seed: int, side_key: String) -> Dictionary:
	if specs.size() > team.size():
		return {"ok": false, "error": "%s explicit team has too many Pokemon" % side_key.capitalize()}
	for i in range(specs.size()):
		var spec: Dictionary = specs[i] as Dictionary
		var instance: PokemonInstanceResource = team[i]
		if instance == null:
			return {"ok": false, "error": "%s team slot %d is empty" % [side_key.capitalize(), i + 1]}
		if int(spec.get("level", 0)) > 0:
			instance.level = int(spec["level"])
			instance.experience = PokemonExperienceService.xp_for_level(instance.resolved_form(), instance.level)
		var move_slugs: Array = spec.get("moves", [])
		if move_slugs.is_empty():
			if int(spec.get("level", 0)) > 0:
				SkirmishMoveLoadout.assign_loadout(instance, seed, side_key, i)
			continue
		var moves: Array[PokemonMoveResource] = []
		for move_slug in move_slugs:
			var move: PokemonMoveResource = _load_move(String(move_slug))
			if move == null:
				return {"ok": false, "error": "Unknown move slug '%s'" % String(move_slug)}
			moves.append(move)
		instance.move_slots = moves
		instance.pp_state = []
		for move in moves:
			instance.pp_state.append(move.pp if move != null else 0)
		instance.loadout_locked = true
	var slot_specs: Array = []
	var item_ids: Array[String] = []
	var any_item: bool = false
	for i in range(team.size()):
		var spec: Dictionary = specs[i] as Dictionary if i < specs.size() else {}
		slot_specs.append({"ability": String(spec.get("ability", ""))})
		var item_id: String = String(spec.get("item", ""))
		item_ids.append(item_id)
		if not item_id.is_empty():
			any_item = true
	var ability_error: String = CustomSkirmishBuilder.apply_slot_specs(team, slot_specs, seed, side_key)
	if not ability_error.is_empty():
		return {"ok": false, "error": ability_error}
	if any_item:
		var item_error: String = CustomSkirmishBuilder.apply_held_items(team, item_ids, seed, side_key)
		if not item_error.is_empty():
			return {"ok": false, "error": item_error}
	return {"ok": true}


static func _load_move(slug: String) -> PokemonMoveResource:
	if slug.is_empty():
		return null
	return CustomMoves.load_move(slug)


static func _is_integer_with_bots(text: String) -> bool:
	var tokens: PackedStringArray = text.strip_edges().split(" ", false)
	var saw_seed: bool = false
	var saw_bots: bool = false
	for raw_token in tokens:
		var token: String = String(raw_token)
		if token == "-bots":
			saw_bots = true
			continue
		if token.is_valid_int() and not saw_seed:
			saw_seed = true
			continue
		return false
	return saw_seed or saw_bots
