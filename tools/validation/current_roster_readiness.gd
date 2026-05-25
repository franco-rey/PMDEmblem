class_name CurrentRosterReadiness
extends RefCounted
## M7 current-roster readiness report used by hardening smoke tests.

const REPORT_JSON_PATH: String = "res://data/models/pokemon/import_reports/current_roster_readiness_report.json"
const REPORT_TEXT_PATH: String = "res://data/models/pokemon/import_reports/current_roster_readiness_report.txt"
const REQUIRED_STATE_GROUPS: Dictionary = {
	"idle": ["idle"],
	"movement": ["walk"],
	"move_use": ["physical_attack", "special_attack", "status_attack"],
	"deal_damage": ["attack", "physical_attack", "special_attack", "shoot"],
	"receive_damage": ["hurt"],
	"faint": ["faint", "sleep"],
}
const EXTERNAL_PATH_MARKERS: Array[String] = [
	"/Users/",
	"PMDODump",
	"RawAsset",
	"SpriteCollab",
	"pokerogue",
]
const CURRENT_ROSTER_PATHS: Array[String] = [
	"res://data/models/pokemon/overrides/instances/0475_gallade.tres",
	"res://data/models/pokemon/overrides/instances/0448_lucario.tres",
	"res://data/models/pokemon/overrides/instances/0282_gardevoir.tres",
	"res://data/models/pokemon/overrides/instances/0454_toxicroak.tres",
	"res://data/models/pokemon/overrides/instances/0467_magmortar.tres",
	"res://data/models/pokemon/overrides/instances/0094_gengar.tres",
	"res://data/models/pokemon/overrides/instances/0356_dusclops.tres",
	"res://data/models/pokemon/generated/instances/0001_bulbasaur.tres",
	"res://data/models/pokemon/generated/instances/0002_ivysaur.tres",
	"res://data/models/pokemon/generated/instances/0003_venusaur.tres",
	"res://data/models/pokemon/generated/instances/0004_charmander.tres",
	"res://data/models/pokemon/generated/instances/0005_charmeleon.tres",
	"res://data/models/pokemon/generated/instances/0006_charizard.tres",
	"res://data/models/pokemon/generated/instances/0007_squirtle.tres",
	"res://data/models/pokemon/generated/instances/0008_wartortle.tres",
	"res://data/models/pokemon/generated/instances/0009_blastoise.tres",
]


func build_payload() -> Dictionary:
	var entries: Array[Dictionary] = []
	for path in CURRENT_ROSTER_PATHS:
		entries.append(_entry_for_path(path))
	return {
		"schema_version": 1,
		"source": "CurrentRosterReadiness",
		"release": "0.11.0",
		"roster_count": entries.size(),
		"summary": _summary(entries),
		"pokemon": entries,
	}


func write_reports(payload: Dictionary) -> bool:
	var ok_json: bool = _write_text(REPORT_JSON_PATH, JSON.stringify(payload, "\t") + "\n")
	var ok_text: bool = _write_text(REPORT_TEXT_PATH, _render_text(payload))
	return ok_json and ok_text


func validate_payload(payload: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var entries: Array = payload.get("pokemon", [])
	if entries.size() != CURRENT_ROSTER_PATHS.size():
		failures.append("expected %d roster entries, found %d" % [CURRENT_ROSTER_PATHS.size(), entries.size()])
	for raw_entry in entries:
		if not (raw_entry is Dictionary):
			failures.append("non-dictionary roster entry")
			continue
		var entry: Dictionary = raw_entry
		var slug: String = String(entry.get("slug", "unknown"))
		if not bool(entry.get("battle_ready", false)):
			failures.append("%s is not battle_ready" % slug)
		if int(entry.get("move_slot_count", 0)) <= 0:
			failures.append("%s has no move slots" % slug)
		if int(entry.get("move_pool_count", 0)) < PokemonInstanceResource.MAX_MOVE_SLOTS:
			failures.append("%s has fewer than four level-appropriate moves" % slug)
		if int(entry.get("missing_move_animation_mappings", 0)) > 0:
			failures.append("%s has unmapped move animations" % slug)
		var readiness: Dictionary = entry.get("readiness", {})
		for missing in readiness.get("missing", []):
			failures.append("%s missing %s" % [slug, String(missing)])
		var sprites: Dictionary = entry.get("sprites", {})
		for leak in sprites.get("external_path_leaks", []):
			failures.append("%s has external runtime path %s" % [slug, String(leak)])
		for intrinsic in entry.get("intrinsics", []):
			if intrinsic is Dictionary and not bool((intrinsic as Dictionary).get("exists", false)):
				failures.append("%s intrinsic missing resource %s" % [slug, String((intrinsic as Dictionary).get("slug", ""))])
	return failures


func _entry_for_path(path: String) -> Dictionary:
	var instance: PokemonInstanceResource = load(path) as PokemonInstanceResource
	if instance == null:
		return {
			"path": path,
			"slug": path.get_file().get_basename(),
			"battle_ready": false,
			"readiness": {"missing": ["instance_resource"], "unsupported": []},
		}
	var species: PokemonSpeciesResource = instance.species
	var form: PokemonFormResource = instance.resolved_form()
	var slug: String = species.species_id if species != null else path.get_file().get_basename()
	var sprite_set: PokemonSpriteSetResource = form.sprite_set if form != null else null
	var readiness_missing: Array[String] = []
	var readiness_unsupported: Array[String] = []
	var move_entries: Array[Dictionary] = _move_entries(instance, sprite_set, readiness_unsupported)
	var sprite_entry: Dictionary = _sprite_entry(sprite_set, readiness_missing)
	var intrinsic_entries: Array[Dictionary] = _intrinsic_entries(form, readiness_unsupported)
	var move_pool: Array[PokemonMoveResource] = SkirmishMoveLoadout.move_pool_for_instance(instance)
	if instance.move_slots.is_empty():
		readiness_missing.append("move_slots")
	if move_pool.size() < PokemonInstanceResource.MAX_MOVE_SLOTS:
		readiness_missing.append("four_move_level_pool")
	if species == null:
		readiness_missing.append("species")
	if form == null:
		readiness_missing.append("form")
	return {
		"path": path,
		"slug": slug,
		"name": instance.display_name(),
		"battle_ready": not instance.move_slots.is_empty() and sprite_set != null and sprite_set.is_complete(),
		"level": instance.level,
		"move_slot_count": instance.move_slots.size(),
		"move_pool_count": move_pool.size(),
		"missing_move_animation_mappings": _missing_move_animation_mapping_count(instance, sprite_set),
		"moves": move_entries,
		"learnsets": _learnset_entry(species),
		"intrinsics": intrinsic_entries,
		"form": _form_entry(species, form),
		"sprites": sprite_entry,
		"readiness": {
			"missing": _unique_sorted(readiness_missing),
			"unsupported": _unique_sorted(readiness_unsupported),
		},
	}


func _move_entries(instance: PokemonInstanceResource, sprite_set: PokemonSpriteSetResource, unsupported: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(instance.move_slots.size()):
		var move: PokemonMoveResource = instance.move_slots[i]
		if move == null:
			continue
		var families: Array[String] = []
		for record in move.effect_records:
			var family: String = String(record.get("family", ""))
			if not family.is_empty() and not families.has(family):
				families.append(family)
		families.sort()
		for tag in move.unsupported_effect_tags:
			var unsupported_key: String = "move:%s:%s" % [move.move_id, String(tag)]
			if not unsupported.has(unsupported_key):
				unsupported.append(unsupported_key)
		var mapped_key: String = ""
		if sprite_set != null and sprite_set.move_animation_map.has(move.move_id):
			mapped_key = String(sprite_set.move_animation_map[move.move_id])
		out.append({
			"slot": i,
			"move_id": move.move_id,
			"name": move.display_name(),
			"category": move.category,
			"type": move.type,
			"pp": move.pp,
			"effect_families": families,
			"unsupported_effect_tags": move.unsupported_effect_tags.duplicate(),
			"animation_key": move.animation_key,
			"mapped_animation_key": mapped_key,
			"mapping_kind": "deterministic_category" if not mapped_key.is_empty() else "fallback_reported",
		})
	return out


func _sprite_entry(sprite_set: PokemonSpriteSetResource, missing: Array[String]) -> Dictionary:
	if sprite_set == null:
		missing.append("sprite_set")
		return {
			"complete": false,
			"minimal_states": {},
			"animation_state_count": 0,
			"animation_states": [],
			"move_animation_map": {},
			"external_path_leaks": [],
			"portrait_paths": [],
		}
	var minimal_states: Dictionary = {}
	for pair in sprite_set.iter_animation_paths():
		var label: String = String(pair[0])
		var path: String = String(pair[1])
		minimal_states[label] = _path_entry(path)
		if path.is_empty() or not FileAccess.file_exists(path):
			missing.append("sprite:%s" % label)
	var state_entries: Array[Dictionary] = []
	var leaks: Array[String] = []
	var keys: Array = sprite_set.animation_states.keys()
	keys.sort()
	for key_v in keys:
		var key: String = String(key_v)
		var raw_state: Variant = sprite_set.animation_states[key_v]
		if not (raw_state is Dictionary):
			continue
		var state: Dictionary = raw_state
		var path: String = String(state.get("path", ""))
		if _has_external_marker(path):
			leaks.append(path)
		if path.is_empty() or not FileAccess.file_exists(path):
			missing.append("animation_state:%s" % key)
		var cell_size: Vector2i = state.get("cell_size", Vector2i.ZERO)
		var timing: Array = state.get("timing", [])
		state_entries.append({
			"key": key,
			"path": path,
			"source_name": String(state.get("source_name", "")),
			"source_filename": String(state.get("source_filename", "")),
			"checksum": String(state.get("checksum", "")),
			"alias_of": String(state.get("alias_of", "")),
			"cell_size": [cell_size.x, cell_size.y],
			"directions": int(state.get("directions", 0)),
			"frame_count": int(state.get("frame_count", 0)),
			"timing_count": timing.size(),
		})
	for group_name in REQUIRED_STATE_GROUPS.keys():
		if not _has_any_state(sprite_set, REQUIRED_STATE_GROUPS[group_name]):
			missing.append("animation_group:%s" % group_name)
	var portraits: Array[String] = []
	for portrait in sprite_set.portrait_paths:
		portraits.append(String(portrait))
		if _has_external_marker(String(portrait)):
			leaks.append(String(portrait))
	return {
		"complete": sprite_set.is_complete(),
		"minimal_states": minimal_states,
		"anim_data": _path_entry(sprite_set.anim_data_path),
		"animation_state_count": state_entries.size(),
		"animation_states": state_entries,
		"move_animation_map": sprite_set.move_animation_map.duplicate(true),
		"external_path_leaks": _unique_sorted(leaks),
		"portrait_paths": portraits,
		"validation_warnings": sprite_set.validation_warnings.duplicate(),
	}


func _intrinsic_entries(form: PokemonFormResource, unsupported: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if form == null:
		return out
	var seen: Dictionary = {}
	for slug in [form.intrinsic1, form.intrinsic2, form.intrinsic3]:
		var key: String = String(slug)
		if key.is_empty() or key == "none" or seen.has(key):
			continue
		seen[key] = true
		var path: String = "res://data/models/pokemon/generated/intrinsics/%s.tres" % key
		var res: PokemonIntrinsicResource = null
		if ResourceLoader.exists(path):
			res = load(path) as PokemonIntrinsicResource
		var unsupported_hooks: Array[String] = res.unsupported_hook_families.duplicate() if res != null else ["resource_missing"]
		for hook in unsupported_hooks:
			var unsupported_key: String = "intrinsic:%s:%s" % [key, String(hook)]
			if not unsupported.has(unsupported_key):
				unsupported.append(unsupported_key)
		out.append({
			"slug": key,
			"resource_path": path,
			"exists": res != null,
			"supported_hooks": res.supported_hook_families.duplicate() if res != null else [],
			"unsupported_hooks": unsupported_hooks,
			"summary": res.report_summary if res != null else "",
		})
	return out


func _learnset_entry(species: PokemonSpeciesResource) -> Dictionary:
	if species == null:
		return {
			"level_up_count": 0,
			"teach_count": 0,
			"shared_count": 0,
			"secret_count": 0,
		}
	return {
		"level_up_count": species.level_skills.size(),
		"teach_count": species.teach_skills.size(),
		"shared_count": species.shared_skills.size(),
		"secret_count": species.secret_skills.size(),
	}


func _form_entry(species: PokemonSpeciesResource, form: PokemonFormResource) -> Dictionary:
	if species == null or form == null:
		return {}
	return {
		"generation": form.generation,
		"types": form.types(),
		"base_stats": {
			"hp": form.base_hp,
			"attack": form.base_atk,
			"defense": form.base_def,
			"special_attack": form.base_spa,
			"special_defense": form.base_spd,
			"speed": form.base_speed,
		},
		"exp_table": form.exp_table,
		"join_rate": form.join_rate,
		"evolution_from": species.evolution_from,
		"skill_groups": [species.skill_group1, species.skill_group2],
		"temporary": form.temporary,
		"progression_placeholders": {
			"stat_growth": "deferred_to_0.12.0",
			"xp_runtime": "deferred_to_0.12.0",
			"evolution_runtime": "deferred_to_0.12.0",
		},
	}


func _summary(entries: Array[Dictionary]) -> Dictionary:
	var summary: Dictionary = {
		"battle_ready": 0,
		"missing_entries": 0,
		"unsupported_entries": 0,
		"animation_states": 0,
		"move_animation_mappings": 0,
	}
	for entry in entries:
		if bool(entry.get("battle_ready", false)):
			summary["battle_ready"] += 1
		var readiness: Dictionary = entry.get("readiness", {})
		summary["missing_entries"] += (readiness.get("missing", []) as Array).size()
		summary["unsupported_entries"] += (readiness.get("unsupported", []) as Array).size()
		var sprites: Dictionary = entry.get("sprites", {})
		summary["animation_states"] += int(sprites.get("animation_state_count", 0))
		var move_map: Dictionary = sprites.get("move_animation_map", {})
		summary["move_animation_mappings"] += move_map.size()
	return summary


func _missing_move_animation_mapping_count(instance: PokemonInstanceResource, sprite_set: PokemonSpriteSetResource) -> int:
	if sprite_set == null:
		return instance.move_slots.size()
	var count: int = 0
	for move in instance.move_slots:
		if move == null:
			continue
		if not sprite_set.move_animation_map.has(move.move_id):
			count += 1
	return count


func _path_entry(path: String) -> Dictionary:
	return {
		"path": path,
		"exists": not path.is_empty() and FileAccess.file_exists(path),
		"project_owned": path.begins_with("res://") and not _has_external_marker(path),
	}


func _has_any_state(sprite_set: PokemonSpriteSetResource, candidates: Array) -> bool:
	for candidate in candidates:
		if sprite_set.has_animation_state(String(candidate)):
			return true
	return false


func _has_external_marker(path: String) -> bool:
	for marker in EXTERNAL_PATH_MARKERS:
		if path.contains(marker):
			return true
	return false


func _unique_sorted(values: Array) -> Array[String]:
	var seen: Dictionary = {}
	for value in values:
		var key: String = String(value)
		if not key.is_empty():
			seen[key] = true
	var out: Array[String] = []
	for key in seen.keys():
		out.append(String(key))
	out.sort()
	return out


func _write_text(path: String, text: String) -> bool:
	var dir_path: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var err: int = DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			push_error("CurrentRosterReadiness: failed to create %s (err %d)" % [dir_path, err])
			return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("CurrentRosterReadiness: failed to open %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true


func _render_text(payload: Dictionary) -> String:
	var out: PackedStringArray = PackedStringArray()
	var summary: Dictionary = payload.get("summary", {})
	out.append("Current Roster Readiness Report")
	out.append("================================")
	out.append("Release: %s" % String(payload.get("release", "")))
	out.append("Roster count: %d" % int(payload.get("roster_count", 0)))
	out.append("Battle-ready: %d" % int(summary.get("battle_ready", 0)))
	out.append("Animation states cataloged: %d" % int(summary.get("animation_states", 0)))
	out.append("Move animation mappings: %d" % int(summary.get("move_animation_mappings", 0)))
	out.append("Missing entries: %d" % int(summary.get("missing_entries", 0)))
	out.append("Unsupported/report-only entries: %d" % int(summary.get("unsupported_entries", 0)))
	out.append("")
	for raw_entry in payload.get("pokemon", []):
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var readiness: Dictionary = entry.get("readiness", {})
		var sprites: Dictionary = entry.get("sprites", {})
		out.append("- %s (%s)" % [String(entry.get("slug", "")), String(entry.get("name", ""))])
		out.append("    moves: slots=%d pool=%d mapped_missing=%d" % [
			int(entry.get("move_slot_count", 0)),
			int(entry.get("move_pool_count", 0)),
			int(entry.get("missing_move_animation_mappings", 0)),
		])
		out.append("    animation states: %d" % int(sprites.get("animation_state_count", 0)))
		for missing in readiness.get("missing", []):
			out.append("    missing: %s" % String(missing))
		for unsupported in readiness.get("unsupported", []):
			out.append("    report-only: %s" % String(unsupported))
	return "\n".join(out) + "\n"
