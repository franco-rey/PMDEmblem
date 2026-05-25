@tool
class_name PMDOImporter
extends RefCounted
## PMDODump -> Godot Pokemon resource importer.
##
## Reads the batch manifest written by `pokemon_batch_packager.py`, then emits
## .tres files into `res://data/models/pokemon/generated/` and reports under
## `res://data/models/pokemon/import_reports/`.
##
## Two ways to invoke it:
## 1. From the Godot editor: open `pmdo_importer_editor.gd` in the script editor
##    and choose File -> Run.
## 2. Headless: `godot --headless --path <project> --script tools/importers/pmdo_run.gd`.

const _SkillMapper: GDScript = preload("res://tools/importers/pmdo_skill_mapper.gd")
const _Paths: GDScript = preload("res://tools/importers/pmdo_paths.gd")
const _Validation: GDScript = preload("res://tools/validation/pokemon_validation.gd")

const _LEGACY_DEX_NUMBERS: Dictionary = {
	"toxicroak": 454,
	"gardevoir": 282,
	"lucario": 448,
	"gallade": 475,
	"magmortar": 467,
	"dusclops": 356,
	"gengar": 94,
}
const _LEGACY_TARGET_SPECIES: Array[String] = [
	"toxicroak",
	"gardevoir",
	"lucario",
	"gallade",
	"magmortar",
	"dusclops",
	"gengar",
]
const _LEGACY_SIGNATURE_MOVES: Dictionary = {
	"toxicroak": "poison_jab",
	"gardevoir": "moonblast",
	"lucario": "aura_sphere",
	"gallade": "psycho_cut",
	"magmortar": "flamethrower",
	"dusclops": "shadow_punch",
	"gengar": "shadow_ball",
}
const _LEGACY_MOVEMENT_OVERRIDE: Dictionary = {
	"toxicroak": 4,
	"gardevoir": 4,
	"lucario": 5,
	"gallade": 3,
	"magmortar": 5,
	"dusclops": 3,
	"gengar": 4,
}

var _growth_table_cache: Dictionary = {}


func run() -> void:
	print_rich("[color=cyan]PMDOImporter: starting import[/color]")
	_ensure_directories()

	var report: PokemonValidation = _Validation.new()
	var import_context: Dictionary = _load_import_context()
	var import_entries: Array = import_context.get("species", [])
	var source_roots: Dictionary = import_context.get("source_roots", {})
	var visual_manifest: Dictionary = _load_visual_manifest()

	var type_chart: TypeChartResource = _import_type_chart(report, source_roots)
	var sprite_sets: Dictionary = _import_sprite_sets(import_entries, report)
	var moves: Dictionary = _import_moves(import_entries, source_roots, report)
	_finalize_sprite_sets(import_entries, sprite_sets, moves, report)
	var species_map: Dictionary = _import_species(import_entries, sprite_sets, moves, source_roots, report)
	_import_status_resources(moves, report, visual_manifest)
	_import_intrinsic_resources(species_map, source_roots, report)
	_import_item_resources(source_roots, report, visual_manifest)
	_author_generated_instances(import_entries, species_map, moves, report)

	var report_path: String = _Paths.REPORT_PATH
	if report.write(report_path):
		print_rich("[color=cyan]PMDOImporter: report written to %s[/color]" % report_path)
	else:
		push_error("PMDOImporter: failed to write %s" % report_path)
	if report.write_json(_Paths.REPORT_JSON_PATH):
		print_rich("[color=cyan]PMDOImporter: JSON report written to %s[/color]" % _Paths.REPORT_JSON_PATH)
	else:
		push_error("PMDOImporter: failed to write %s" % _Paths.REPORT_JSON_PATH)

	# Suppress unused warnings for callers that don't care about return values.
	if type_chart == null:
		pass

	print_rich("[color=cyan]PMDOImporter: done[/color]")


# ---------------------------------------------------------------------------
# Filesystem prep
# ---------------------------------------------------------------------------

func _ensure_directories() -> void:
	var dirs: Array[String] = [
		_Paths.GENERATED_TYPES_DIR,
		_Paths.GENERATED_SPECIES_DIR,
		_Paths.GENERATED_FORMS_DIR,
		_Paths.GENERATED_MOVES_DIR,
		_Paths.GENERATED_STATUSES_DIR,
		_Paths.GENERATED_INTRINSICS_DIR,
		_Paths.GENERATED_ITEMS_DIR,
		_Paths.GENERATED_SPRITES_DIR,
		_Paths.GENERATED_INSTANCES_DIR,
		_Paths.GENERATED_MANIFESTS_DIR,
		_Paths.OVERRIDE_INSTANCES_DIR,
		_Paths.IMPORT_REPORTS_DIR,
	]
	for d in dirs:
		if not DirAccess.dir_exists_absolute(d):
			var err: int = DirAccess.make_dir_recursive_absolute(d)
			if err != OK:
				push_error("PMDOImporter: could not create %s (err %d)" % [d, err])


# ---------------------------------------------------------------------------
# Type chart
# ---------------------------------------------------------------------------

func _import_type_chart(report: PokemonValidation, source_roots: Dictionary) -> TypeChartResource:
	var raw: Variant = _read_json_absolute(_universal_path(source_roots))
	if raw == null:
		report.add_error("Could not read Universal.json at %s" % _universal_path(source_roots))
		report.set_type_chart_summary(false, 0, 0, [])
		return null

	var element_state: Dictionary = _find_element_table_state(raw)
	if element_state.is_empty():
		report.add_error("Universal.json: ElementTableState not found")
		report.set_type_chart_summary(false, 0, 0, [])
		return null

	var chart: TypeChartResource = TypeChartResource.new()

	var type_map_dict: Dictionary = element_state.get("TypeMap", {})
	var ordered_types: Array[String] = []
	ordered_types.resize(type_map_dict.size())
	for slug in type_map_dict.keys():
		var idx: int = int(type_map_dict[slug])
		if idx >= 0 and idx < ordered_types.size():
			ordered_types[idx] = String(slug)
	chart.type_list = ordered_types
	var index_dict: Dictionary = {}
	for slug in type_map_dict.keys():
		index_dict[String(slug).to_lower()] = int(type_map_dict[slug])
	chart.type_index = index_dict

	var effectiveness_arr: Array = element_state.get("Effectiveness", [])
	var packed_eff: PackedFloat32Array = PackedFloat32Array()
	for v in effectiveness_arr:
		packed_eff.append(float(v))
	chart.effectiveness_table = packed_eff

	# PMDODump's `none` matchup row is all NEUTRAL, so neutral-on-neutral sums
	# to LEVEL_NEUTRAL * 2 = 8. Keep this in sync with TypeChartResource.
	chart.neutral_index = TypeChartResource.LEVEL_NEUTRAL * 2

	var matrix: Array = element_state.get("TypeMatchup", [])
	var packed_levels: PackedByteArray = PackedByteArray()
	var bucket_counts: Dictionary = {}
	for row in matrix:
		if not (row is Array):
			continue
		for cell in row:
			var lvl: int = int(cell)
			packed_levels.append(lvl)
			bucket_counts[lvl] = int(bucket_counts.get(lvl, 0)) + 1
	chart.matchup_levels = packed_levels

	var save_err: int = ResourceSaver.save(chart, _Paths.TYPE_CHART_PATH)
	if save_err != OK:
		report.add_error("Failed to save type chart .tres (err %d)" % save_err)
		report.set_type_chart_summary(false, ordered_types.size(), packed_levels.size(), [])
		return null

	# Bucket counts as ordered list - one entry per Effectiveness slot, plus an
	# "other" tail for any out-of-range levels we encountered.
	var bucket_array: Array[int] = []
	bucket_array.resize(packed_eff.size())
	for k in bucket_counts.keys():
		var idx: int = int(k)
		if idx >= 0 and idx < bucket_array.size():
			bucket_array[idx] = int(bucket_counts[k])
		else:
			report.add_warning("Type chart had matchup level %d outside expected range" % idx)
	report.set_type_chart_summary(true, ordered_types.size(), packed_levels.size(), bucket_array)
	return chart


func _find_element_table_state(node: Variant) -> Dictionary:
	if node is Dictionary:
		var d: Dictionary = node
		var t: String = String(d.get("$type", ""))
		if t.begins_with("PMDC.Dungeon.ElementTableState"):
			return d
		for key in d.keys():
			var found: Dictionary = _find_element_table_state(d[key])
			if not found.is_empty():
				return found
	elif node is Array:
		for item in node:
			var found2: Dictionary = _find_element_table_state(item)
			if not found2.is_empty():
				return found2
	return {}


# ---------------------------------------------------------------------------
# Sprite sets
# ---------------------------------------------------------------------------

func _import_sprite_sets(import_entries: Array, report: PokemonValidation) -> Dictionary:
	var out: Dictionary = {}
	for raw_entry in import_entries:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var project_slug: String = String(entry.get("slug", ""))
		if project_slug.is_empty():
			continue
		var sprite_set: PokemonSpriteSetResource = _build_sprite_set(entry, report)
		var save_path: String = _Paths.generated_sprite_path_for_project_slug(project_slug)
		var err: int = ResourceSaver.save(sprite_set, save_path)
		if err != OK:
			report.add_error("Failed to save sprite set for %s (err %d)" % [project_slug, err])
			continue
		out[project_slug] = save_path
	return out


func _build_sprite_set(entry: Dictionary, report: PokemonValidation) -> PokemonSpriteSetResource:
	var sprite_set: PokemonSpriteSetResource = PokemonSpriteSetResource.new()
	var project_slug: String = String(entry.get("slug", ""))
	var assets: Dictionary = entry.get("assets", {})
	var manifest_warnings: Array = entry.get("warnings", [])
	for warning in manifest_warnings:
		sprite_set.validation_warnings.append(String(warning))

	sprite_set.idle_path = String(assets.get("idle", ""))
	sprite_set.walk_path = String(assets.get("walk", ""))
	sprite_set.hurt_path = String(assets.get("hurt", ""))
	sprite_set.sleep_path = String(assets.get("sleep", ""))
	sprite_set.hop_path = String(assets.get("hop", ""))
	sprite_set.anim_data_path = String(assets.get("anim_data", ""))
	sprite_set.animation_states = _animation_states_from_manifest(sprite_set, entry)
	sprite_set.portrait_paths = _portrait_paths_from_manifest(assets)

	for pair in sprite_set.iter_animation_paths():
		var label: String = String(pair[0])
		var path: String = String(pair[1])
		if path.is_empty() or not _res_path_exists(path):
			var msg: String = "%s missing %s sprite at %s" % [project_slug, label, path]
			if not sprite_set.validation_warnings.has(msg):
				sprite_set.validation_warnings.append(msg)
			report.add_warning(msg)
	if sprite_set.anim_data_path.is_empty() or not _res_path_exists(sprite_set.anim_data_path):
		var anim_msg: String = "%s missing AnimData.xml at %s" % [project_slug, sprite_set.anim_data_path]
		if not sprite_set.validation_warnings.has(anim_msg):
			sprite_set.validation_warnings.append(anim_msg)
		report.add_warning(anim_msg)

	return sprite_set


func _animation_states_from_manifest(sprite_set: PokemonSpriteSetResource, entry: Dictionary) -> Dictionary:
	var assets: Dictionary = entry.get("assets", {})
	var states: Dictionary = _default_animation_states(sprite_set)
	var raw_states: Variant = assets.get("animation_states", {})
	if raw_states is Dictionary:
		for state_key_v in (raw_states as Dictionary).keys():
			var state_key: String = String(state_key_v)
			var raw_entry: Variant = (raw_states as Dictionary)[state_key_v]
			if not (raw_entry is Dictionary):
				continue
			var state_entry: Dictionary = raw_entry
			var path: String = String(state_entry.get("path", ""))
			if path.is_empty():
				continue
			var metadata: Dictionary = state_entry.get("metadata", {})
			states[state_key] = {
				"path": path,
				"source_name": String(state_entry.get("source_name", state_key.capitalize())),
				"source_filename": String(state_entry.get("source_filename", "")),
				"checksum": String(state_entry.get("checksum", "")),
				"cell_size": Vector2i(int(metadata.get("frame_width", 0)), int(metadata.get("frame_height", 0))),
				"directions": _directions_for_state(state_key),
				"frame_count": int(metadata.get("frame_count", 0)),
				"timing": _typed_int_array(metadata.get("durations", [])),
				"source_index": int(metadata.get("index", 0)),
				"copy_of": String(metadata.get("copy_of", "")),
				"rush_frame": int(metadata.get("rush_frame", 0)),
				"hit_frame": int(metadata.get("hit_frame", 0)),
				"return_frame": int(metadata.get("return_frame", 0)),
			}
	_apply_sprite_substitutions(states, sprite_set, assets)
	_apply_animation_aliases(states)
	return states


func _portrait_paths_from_manifest(assets: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var expressions: Variant = assets.get("portrait_expressions", {})
	if expressions is Dictionary:
		var keys: Array = (expressions as Dictionary).keys()
		keys.sort()
		if (expressions as Dictionary).has("Normal"):
			out.append(String((expressions as Dictionary)["Normal"]))
		for key_v in keys:
			var key: String = String(key_v)
			if key == "Normal":
				continue
			out.append(String((expressions as Dictionary)[key_v]))
	elif assets.has("portrait_normal"):
		out.append(String(assets["portrait_normal"]))
	return out


func _apply_sprite_substitutions(states: Dictionary, sprite_set: PokemonSpriteSetResource, assets: Dictionary) -> void:
	var substitutions: Variant = assets.get("sprite_substitutions", {})
	if not (substitutions is Dictionary):
		return
	if String((substitutions as Dictionary).get("idle", "")) != "idle_static_from_walk":
		return
	if sprite_set.idle_path.is_empty() or not states.has("walk"):
		return
	var walk_entry_v: Variant = states["walk"]
	if not (walk_entry_v is Dictionary):
		return
	var idle_entry: Dictionary = (walk_entry_v as Dictionary).duplicate(true)
	idle_entry["path"] = sprite_set.idle_path
	idle_entry["source_name"] = "Walk"
	idle_entry["source_filename"] = "Walk-Anim.png"
	idle_entry["substitution"] = "idle_static_from_walk"
	idle_entry["frame_count"] = 1
	idle_entry["timing"] = []
	states["idle"] = idle_entry


func _default_animation_states(sprite_set: PokemonSpriteSetResource) -> Dictionary:
	var states: Dictionary = {}
	var path_by_key: Dictionary = {
		"idle": sprite_set.idle_path,
		"walk": sprite_set.walk_path,
		"hurt": sprite_set.hurt_path,
		"sleep": sprite_set.sleep_path,
		"hop": sprite_set.hop_path,
	}
	for key in path_by_key.keys():
		var path: String = String(path_by_key[key])
		if path.is_empty():
			continue
		states[key] = {
			"path": path,
			"source_name": key.capitalize(),
			"cell_size": Vector2i.ZERO,
			"directions": _directions_for_state(key),
			"frame_count": 0,
			"timing": [],
		}
	return states


func _apply_animation_aliases(states: Dictionary) -> void:
	_alias_animation_state(states, "attack", ["attack", "hop", "idle"])
	_alias_animation_state(states, "physical_attack", ["physical_attack", "attack", "strike", "swing", "double", "hop"])
	_alias_animation_state(states, "special_attack", ["special_attack", "shoot", "cast", "charge", "attack", "hop"])
	_alias_animation_state(states, "status_attack", ["status_attack", "cast", "buff", "charge", "shake", "nod", "idle"])
	_alias_animation_state(states, "heal", ["heal", "buff", "charge", "shake", "status_attack", "idle"])
	_alias_animation_state(states, "buff", ["buff", "charge", "shake", "nod", "status_attack", "idle"])
	_alias_animation_state(states, "debuff", ["debuff", "cringe", "shake", "status_attack", "idle"])
	_alias_animation_state(states, "miss", ["miss", "idle"])
	_alias_animation_state(states, "faint", ["faint", "sleep", "hurt", "idle"])


func _alias_animation_state(states: Dictionary, alias_key: String, candidates: Array[String]) -> void:
	if states.has(alias_key):
		return
	for candidate in candidates:
		if not states.has(candidate):
			continue
		var entry: Variant = states[candidate]
		if not (entry is Dictionary):
			continue
		var alias_entry: Dictionary = (entry as Dictionary).duplicate(true)
		alias_entry["alias_of"] = candidate
		states[alias_key] = alias_entry
		return


func _directions_for_state(state_key: String) -> int:
	return 1 if state_key in ["sleep", "faint"] else 8


func _typed_int_array(values: Variant) -> Array[int]:
	var out: Array[int] = []
	if values is Array:
		for value in values:
			out.append(int(value))
	return out


func _finalize_sprite_sets(import_entries: Array, sprite_sets: Dictionary, moves: Dictionary, report: PokemonValidation) -> void:
	for raw_entry in import_entries:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var project_slug: String = String(entry.get("slug", ""))
		var sprite_path: String = String(sprite_sets.get(project_slug, ""))
		if sprite_path.is_empty() or not ResourceLoader.exists(sprite_path):
			continue
		var sprite_set: PokemonSpriteSetResource = load(sprite_path) as PokemonSpriteSetResource
		if sprite_set == null:
			continue
		sprite_set.move_animation_map = _move_animation_map_for_entry(entry, moves, sprite_set)
		var err: int = ResourceSaver.save(sprite_set, sprite_path)
		if err != OK:
			report.add_error("Failed to finalize sprite set for %s (err %d)" % [project_slug, err])


func _move_animation_map_for_entry(entry: Dictionary, moves: Dictionary, sprite_set: PokemonSpriteSetResource) -> Dictionary:
	var out: Dictionary = {}
	var seen: Dictionary = {}
	for key in ["import_moves", "default_moves"]:
		for move_slug_var in _entry_move_array(entry, key):
			var move_slug: String = String(move_slug_var)
			if move_slug.is_empty() or seen.has(move_slug):
				continue
			seen[move_slug] = true
			var move_path: String = String(moves.get(move_slug, ""))
			if move_path.is_empty() or not ResourceLoader.exists(move_path):
				continue
			var move: PokemonMoveResource = load(move_path) as PokemonMoveResource
			if move == null:
				continue
			out[move.move_id] = _animation_key_for_move(move, sprite_set)
	return out


func _animation_key_for_move(move: PokemonMoveResource, sprite_set: PokemonSpriteSetResource) -> String:
	var requested: String = move.animation_key
	if not requested.is_empty() and sprite_set.has_animation_state(requested):
		return requested
	match move.category:
		PokemonMoveResource.CATEGORY_PHYSICAL:
			return _first_animation_key(sprite_set, ["physical_attack", "attack", "strike", "swing", "hop", "idle"])
		PokemonMoveResource.CATEGORY_SPECIAL:
			if move.tactical_range_kind == PokemonMoveResource.TacticalRangeKind.PROJECTILE:
				return _first_animation_key(sprite_set, ["shoot", "special_attack", "attack", "hop", "idle"])
			return _first_animation_key(sprite_set, ["special_attack", "shoot", "cast", "attack", "hop", "idle"])
		_:
			return _first_animation_key(sprite_set, ["status_attack", "buff", "charge", "shake", "idle"])


func _first_animation_key(sprite_set: PokemonSpriteSetResource, candidates: Array[String]) -> String:
	for key in candidates:
		if sprite_set.has_animation_state(key):
			return key
	return "idle"


# ---------------------------------------------------------------------------
# Moves
# ---------------------------------------------------------------------------

func _import_moves(import_entries: Array, source_roots: Dictionary, report: PokemonValidation) -> Dictionary:
	var out: Dictionary = {}
	var slugs_seen: Dictionary = {}
	for move_slug in _move_slugs_for_import(import_entries):
		if slugs_seen.has(move_slug):
			out[move_slug] = slugs_seen[move_slug]
			continue
		var save_path: String = _import_move(move_slug, source_roots, report)
		slugs_seen[move_slug] = save_path
		out[move_slug] = save_path
	return out


func _import_move(slug: String, source_roots: Dictionary, report: PokemonValidation) -> String:
	var entry := PokemonValidation.MoveEntry.new()
	entry.slug = slug

	var json_path: String = _skill_json_path(slug, source_roots)
	var raw: Variant = _read_json_absolute(json_path)
	if raw == null:
		report.add_error("Skill JSON missing or invalid: %s" % json_path)
		report.add_move(entry)
		return ""

	var obj: Dictionary = _dict_field(raw, "Object")
	if obj.is_empty():
		report.add_error("Skill JSON has no Object: %s" % json_path)
		report.add_move(entry)
		return ""

	var move: PokemonMoveResource = PokemonMoveResource.new()
	move.move_id = slug
	move.index_number = int(obj.get("IndexNum", 0))
	move.name = _localized(obj.get("Name", {}))
	move.description = _localized(obj.get("Desc", {}))
	move.pp = int(obj.get("BaseCharges", 0))

	var data: Dictionary = _dict_field(obj, "Data")
	move.type = String(data.get("Element", "none")).to_lower()
	move.category = int(data.get("Category", PokemonMoveResource.CATEGORY_STATUS))
	move.accuracy = int(data.get("HitRate", PokemonMoveResource.ACCURACY_NEVER_MISS))
	move.base_power = _SkillMapper.extract_base_power(data)
	move.strike_count = maxi(1, int(obj.get("Strikes", 1)))
	move.animation_key = _SkillMapper.animation_key_for(move.category)

	var hitbox: Dictionary = _dict_field(obj, "HitboxAction")
	if hitbox.is_empty():
		report.add_warning("%s: missing HitboxAction" % slug)
	move.target_alignment = int(hitbox.get("TargetAlignments", PokemonMoveResource.TARGET_FOE))
	var range_info: Dictionary = _SkillMapper.map_hitbox(hitbox)
	move.tactical_range_kind = int(range_info[_SkillMapper.RESULT_KIND])
	move.tactical_range_value = int(range_info[_SkillMapper.RESULT_VALUE])
	if move.tactical_range_kind == PokemonMoveResource.TacticalRangeKind.UNSUPPORTED:
		var raw_type: String = String(range_info[_SkillMapper.RESULT_RAW])
		if not raw_type.is_empty():
			move.unsupported_effect_tags.append("HitboxAction:%s" % raw_type)

	var tags: Dictionary = _SkillMapper.extract_effect_tags(data)
	move.effect_tags = tags["all"]
	move.unsupported_effect_tags.append_array(tags["unsupported"])
	move.effect_records = _SkillMapper.extract_effect_records(data, slug, move.strike_count)

	var save_path: String = _Paths.generated_move_path(slug)
	var err: int = ResourceSaver.save(move, save_path)
	if err != OK:
		report.add_error("Failed to save move %s (err %d)" % [slug, err])
		report.add_move(entry)
		return ""

	entry.index_number = move.index_number
	entry.name = move.name
	entry.type = move.type
	entry.category = move.category
	entry.base_power = move.base_power
	entry.accuracy = move.accuracy
	entry.pp = move.pp
	entry.range_kind = _SkillMapper.kind_label(move.tactical_range_kind)
	entry.range_value = move.tactical_range_value
	entry.target_alignment = move.target_alignment
	entry.effect_tags = move.effect_tags.duplicate()
	entry.unsupported_effect_tags = move.unsupported_effect_tags.duplicate()
	entry.imported = true
	report.add_move(entry)
	return save_path


# ---------------------------------------------------------------------------
# Statuses + intrinsics
# ---------------------------------------------------------------------------

func _import_status_resources(moves: Dictionary, report: PokemonValidation, visual_manifest: Dictionary) -> void:
	var statuses: Dictionary = {}
	for move_slug in moves.keys():
		var move_path: String = String(moves[move_slug])
		if move_path.is_empty() or not ResourceLoader.exists(move_path):
			continue
		var move: PokemonMoveResource = load(move_path) as PokemonMoveResource
		if move == null:
			continue
		for record in move.effect_records:
			var status_id: String = String(record.get("status_id", ""))
			if status_id.is_empty():
				continue
			if not statuses.has(status_id):
				statuses[status_id] = {
					"events": [],
					"families": [],
				}
			var meta: Dictionary = statuses[status_id]
			var events: Array = meta["events"]
			var families: Array = meta["families"]
			var source_event: String = String(record.get("source_event", ""))
			if not source_event.is_empty() and not events.has(source_event):
				events.append(source_event)
			var family: String = String(record.get("family", ""))
			if not family.is_empty() and not families.has(family):
				families.append(family)

	for status_id in statuses.keys():
		var status := PokemonStatusResource.new()
		status.status_id = String(status_id)
		status.display_name = String(status_id).capitalize()
		status.visual_key = String(status_id)
		status.icon_path = _status_icon_path(status.status_id, visual_manifest)
		var status_meta: Dictionary = statuses[status_id]
		status.source_event_tags = _typed_string_array(status_meta["events"] as Array)
		status.supported_hook_families = _typed_string_array(status_meta["families"] as Array)
		var err: int = ResourceSaver.save(status, _Paths.generated_status_path(status.status_id))
		if err != OK:
			report.add_error("Failed to save status %s (err %d)" % [status.status_id, err])


func _import_intrinsic_resources(species_map: Dictionary, source_roots: Dictionary, report: PokemonValidation) -> void:
	var slugs: Dictionary = {}
	for project_slug in species_map.keys():
		var species_path: String = String(species_map[project_slug])
		if species_path.is_empty() or not ResourceLoader.exists(species_path):
			continue
		var species: PokemonSpeciesResource = load(species_path) as PokemonSpeciesResource
		if species == null:
			continue
		for form in species.forms:
			if form == null:
				continue
			for slug in [form.intrinsic1, form.intrinsic2, form.intrinsic3]:
				var key: String = String(slug)
				if key.is_empty() or key == "none":
					continue
				slugs[key] = true
	var dir: DirAccess = DirAccess.open(_Paths.GENERATED_SPECIES_DIR)
	if dir != null:
		dir.list_dir_begin()
		var name: String = dir.get_next()
		while name != "":
			if not dir.current_is_dir() and name.ends_with(".tres"):
				var species_path: String = "%s/%s" % [_Paths.GENERATED_SPECIES_DIR, name]
				var species: PokemonSpeciesResource = load(species_path) as PokemonSpeciesResource
				if species != null:
					for form in species.forms:
						if form == null:
							continue
						for slug in [form.intrinsic1, form.intrinsic2, form.intrinsic3]:
							var key: String = String(slug)
							if key.is_empty() or key == "none":
								continue
							slugs[key] = true
			name = dir.get_next()
		dir.list_dir_end()

	for slug in slugs.keys():
		var key_slug: String = String(slug)
		var meta: Dictionary = _intrinsic_source_metadata(key_slug, source_roots)
		var intrinsic := PokemonIntrinsicResource.new()
		intrinsic.intrinsic_id = key_slug
		intrinsic.display_name = String(meta.get("display_name", ""))
		if intrinsic.display_name.is_empty():
			intrinsic.display_name = intrinsic.intrinsic_id.capitalize()
		intrinsic.source_event_tags = _typed_string_array(meta.get("source_event_tags", []) as Array)
		var supported_hooks: Array[String] = _supported_intrinsic_hooks(intrinsic.intrinsic_id)
		if not supported_hooks.is_empty():
			intrinsic.supported_hook_families = _typed_string_array(supported_hooks)
			intrinsic.report_summary = "Supported skirmish hooks imported from intrinsic metadata."
		else:
			intrinsic.supported_hook_families = _typed_string_array(["battle_start"])
			intrinsic.unsupported_hook_families = _typed_string_array(["future_only"])
			intrinsic.report_summary = "Metadata imported; gameplay hook is outside the implemented skirmish gate."
		var err: int = ResourceSaver.save(intrinsic, _Paths.generated_intrinsic_path(intrinsic.intrinsic_id))
		if err != OK:
			report.add_error("Failed to save intrinsic %s (err %d)" % [intrinsic.intrinsic_id, err])


func _intrinsic_source_metadata(slug: String, source_roots: Dictionary) -> Dictionary:
	var raw: Variant = _read_json_absolute(_intrinsic_json_path(slug, source_roots))
	if raw == null:
		return {"display_name": slug.capitalize(), "source_event_tags": []}
	var obj: Dictionary = _dict_field(raw, "Object")
	var nodes: Array[Dictionary] = []
	_collect_typed_nodes(obj, nodes)
	var tags: Array[String] = []
	for node in nodes:
		var tag: String = String(node.get("$type", ""))
		if tag.is_empty() or tags.has(tag):
			continue
		tags.append(tag)
	tags.sort()
	return {
		"display_name": _localized(obj.get("Name", {})),
		"source_event_tags": tags,
	}


func _supported_intrinsic_hooks(slug: String) -> Array[String]:
	match slug:
		"blaze", "overgrow", "torrent":
			return ["battle_start", "before_damage"]
		"sharpness", "tough_claws", "mega_launcher", "adaptability", "pixilate":
			return ["battle_start", "before_damage"]
		"rain_dish", "dry_skin", "solar_power", "chlorophyll", "drought":
			return ["battle_start", "field_condition", "turn_start"]
		"inner_focus", "vital_spirit", "steadfast", "synchronize":
			return ["battle_start", "status_application"]
		"justified", "flame_body", "poison_touch", "cursed_body", "pressure", "thick_fat":
			return ["battle_start", "after_damage"]
		"anticipation", "frisk", "shadow_tag", "telepathy", "trace":
			return ["battle_start"]
	return []


# ---------------------------------------------------------------------------
# Items
# ---------------------------------------------------------------------------

func _import_item_resources(source_roots: Dictionary, report: PokemonValidation, visual_manifest: Dictionary) -> void:
	var item_dir: String = _item_dir_path(source_roots)
	var dir: DirAccess = DirAccess.open(item_dir)
	if dir == null:
		report.add_error("Item directory missing: %s" % item_dir)
		return
	var filenames: Array[String] = []
	dir.list_dir_begin()
	var filename: String = dir.get_next()
	while filename != "":
		if not dir.current_is_dir() and filename.ends_with(".json"):
			filenames.append(filename)
		filename = dir.get_next()
	dir.list_dir_end()
	filenames.sort()
	for item_file in filenames:
		_import_item(item_file.get_basename(), "%s/%s" % [item_dir, item_file], report, visual_manifest)


func _import_item(slug: String, json_path: String, report: PokemonValidation, visual_manifest: Dictionary) -> void:
	var entry := PokemonValidation.ItemEntry.new()
	entry.slug = slug
	var raw: Variant = _read_json_absolute(json_path)
	if raw == null:
		report.add_error("Item JSON missing or invalid: %s" % json_path)
		report.add_item(entry)
		return
	var obj: Dictionary = _dict_field(raw, "Object")
	if obj.is_empty():
		report.add_error("Item JSON has no Object: %s" % json_path)
		report.add_item(entry)
		return

	var item := PokemonItemResource.new()
	item.item_id = slug
	item.name = _localized(obj.get("Name", {}))
	item.description = _localized(obj.get("Desc", {}))
	item.released = bool(obj.get("Released", true))
	item.price = int(obj.get("Price", 0))
	item.rarity = int(obj.get("Rarity", 0))
	item.max_stack = int(obj.get("MaxStack", 0))
	item.cannot_drop = bool(obj.get("CannotDrop", false))
	item.bag_effect = bool(obj.get("BagEffect", false))
	item.usage_type = int(obj.get("UsageType", 0))
	item.sort_category = int(obj.get("SortCategory", 0))
	item.sprite_key = String(obj.get("Sprite", ""))
	item.icon_path = _visual_lookup_path(visual_manifest, "Item", item.sprite_key)
	if not visual_manifest.is_empty() and not item.sprite_key.is_empty() and item.icon_path.is_empty():
		report.add_warning("Item %s has unmapped RawAsset icon key %s" % [slug, item.sprite_key])
	item.icon_index = int(obj.get("Icon", 0))
	item.item_states = _item_state_tags(obj)
	item.category = _item_category(slug, item.item_states, item.sort_category)
	item.use_kind = _item_use_kind(slug, item.item_states, item.bag_effect, obj)
	item.source_json_path = "DumpAsset/Data/Item/%s.json" % slug
	item.source_effect_tags = _item_source_tags(obj)
	item.effect_records = _item_effect_records(obj, slug)
	item.passive_effect_records = _item_passive_effect_records(slug, item.item_states)
	item.unsupported_effect_tags = _unsupported_item_effect_tags(item.source_effect_tags, item.effect_records)

	var err: int = ResourceSaver.save(item, _Paths.generated_item_path(slug))
	if err != OK:
		report.add_error("Failed to save item %s (err %d)" % [slug, err])
		report.add_item(entry)
		return
	entry.name = item.name
	entry.category = item.category
	entry.sprite_key = item.sprite_key
	entry.icon_path = item.icon_path
	entry.use_kind = item.use_kind
	entry.effect_count = item.effect_records.size()
	entry.passive_effect_count = item.passive_effect_records.size()
	entry.unsupported_effect_count = item.unsupported_effect_tags.size()
	entry.imported = true
	report.add_item(entry)


func _item_state_tags(obj: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var states: Variant = obj.get("ItemStates", [])
	if states is Array:
		for state in states:
			if state is Dictionary:
				var tag: String = String((state as Dictionary).get("$type", ""))
				if not tag.is_empty() and not out.has(tag):
					out.append(tag)
	return out


func _item_source_tags(obj: Dictionary) -> Array[String]:
	var nodes: Array[Dictionary] = []
	_collect_typed_nodes(obj.get("ItemStates", []), nodes)
	_collect_typed_nodes(obj.get("GroundUseActions", []), nodes)
	_collect_typed_nodes(obj.get("UseEvent", {}), nodes)
	_collect_typed_nodes(obj.get("ProximityEvent", {}), nodes)
	var out: Array[String] = []
	for node in nodes:
		var tag: String = String(node.get("$type", ""))
		if _is_item_report_tag(tag) and not out.has(tag):
			out.append(tag)
	out.sort()
	return out


func _item_effect_records(obj: Dictionary, slug: String) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var nodes: Array[Dictionary] = []
	_collect_typed_nodes(obj.get("GroundUseActions", []), nodes)
	_collect_typed_nodes(obj.get("UseEvent", {}), nodes)
	var teach_move_id: String = _item_teach_move_id(obj)
	for node in nodes:
		var tag: String = String(node.get("$type", ""))
		match tag:
			"PMDC.Dungeon.RestoreHPEvent, PMDC":
				records.append({
					"family": "heal",
					"source_event": tag,
					"numerator": int(node.get("Numerator", 1)),
					"denominator": int(node.get("Denominator", 1)),
				})
			"PMDC.Dungeon.RestorePPEvent, PMDC":
				records.append({
					"family": "restore_pp",
					"source_event": tag,
					"amount": int(node.get("PP", -1)),
				})
			"PMDC.Dungeon.VitaminEvent, PMDC":
				var stat: String = _stat_from_pmdo_index(int(node.get("BoostedStat", -1)))
				if not stat.is_empty():
					records.append({
						"family": "permanent_stat",
						"source_event": tag,
						"stat": stat,
						"amount": int(node.get("Change", 1)),
					})
			"PMDC.Dungeon.VitaGummiEvent, PMDC":
				var gummi_stat: String = _stat_from_pmdo_index(int(node.get("BoostedStat", -1)))
				if not gummi_stat.is_empty():
					records.append({
						"family": "permanent_stat",
						"source_event": tag,
						"stat": gummi_stat,
						"amount": 1,
					})
			"PMDC.Dungeon.LevelChangeEvent, PMDC":
				records.append({
					"family": "level_change",
					"source_event": tag,
					"levels": int(node.get("Level", 1)),
				})
			"PMDC.Dungeon.MoveLearnEvent, PMDC", "RogueEssence.Ground.LearnItemEvent, RogueEssence":
				var move_id: String = String(node.get("Skill", teach_move_id))
				if move_id.is_empty():
					move_id = teach_move_id
				if not move_id.is_empty():
					records.append({
						"family": "teach_move",
						"source_event": tag,
						"move_id": move_id,
					})
	return records


func _item_passive_effect_records(slug: String, item_states: Array[String]) -> Array[Dictionary]:
	if not item_states.has("PMDC.Dungeon.HeldState, PMDC") and not item_states.has("PMDC.Dungeon.EquipState, PMDC"):
		return []
	var held_mods: Dictionary = {
		"held_power_band": ["attack", 10],
		"held_special_band": ["special_attack", 10],
		"held_defense_scarf": ["defense", 10],
		"held_zinc_band": ["special_defense", 10],
		"held_choice_scarf": ["speed", 10],
		"held_munch_belt": ["attack", 5],
	}
	if not held_mods.has(slug):
		return []
	var pair: Array = held_mods[slug]
	return [{
		"family": "held_stat_modifier",
		"source_event": "M8HeldItemBootstrap",
		"stat": String(pair[0]),
		"amount": int(pair[1]),
	}]


func _unsupported_item_effect_tags(source_tags: Array[String], records: Array[Dictionary]) -> Array[String]:
	var supported: Dictionary = {}
	for record in records:
		var source_event: String = String(record.get("source_event", ""))
		if not source_event.is_empty():
			supported[source_event] = true
	var out: Array[String] = []
	for tag in source_tags:
		if not String(tag).contains("Event"):
			continue
		if supported.has(tag):
			continue
		out.append(tag)
	return out


func _item_teach_move_id(obj: Dictionary) -> String:
	var nodes: Array[Dictionary] = []
	_collect_typed_nodes(obj.get("ItemStates", []), nodes)
	_collect_typed_nodes(obj.get("GroundUseActions", []), nodes)
	for node in nodes:
		if String(node.get("$type", "")) == "RogueEssence.Dungeon.ItemIDState, RogueEssence":
			return String(node.get("ID", ""))
		if String(node.get("$type", "")) == "RogueEssence.Ground.LearnItemEvent, RogueEssence":
			return String(node.get("Skill", ""))
	return ""


func _collect_typed_nodes(node: Variant, out: Array[Dictionary]) -> void:
	if node is Dictionary:
		var dict: Dictionary = node
		if dict.has("$type"):
			out.append(dict)
		for key in dict.keys():
			_collect_typed_nodes(dict[key], out)
	elif node is Array:
		for item in node:
			_collect_typed_nodes(item, out)


func _is_item_report_tag(tag: String) -> bool:
	return (
		tag.begins_with("PMDC.Dungeon.")
		or tag.begins_with("RogueEssence.Ground.")
		or tag == "RogueEssence.Dungeon.ItemIDState, RogueEssence"
	)


func _item_category(slug: String, item_states: Array[String], sort_category: int) -> String:
	if item_states.has("PMDC.Dungeon.BerryState, PMDC"):
		return "berry"
	if item_states.has("PMDC.Dungeon.GummiState, PMDC"):
		return "gummi"
	if item_states.has("PMDC.Dungeon.SeedState, PMDC"):
		return "seed"
	if item_states.has("PMDC.Dungeon.FoodState, PMDC"):
		return "food"
	if item_states.has("PMDC.Dungeon.OrbState, PMDC"):
		return "orb"
	if item_states.has("PMDC.Dungeon.EvoState, PMDC"):
		return "evolution"
	if item_states.has("PMDC.Dungeon.HeldState, PMDC") or item_states.has("PMDC.Dungeon.EquipState, PMDC"):
		return "held"
	if slug.begins_with("tm_"):
		return "tm"
	if slug.begins_with("medicine_") or slug.begins_with("boost_"):
		return "medicine"
	if item_states.has("RogueEssence.Dungeon.MaterialState, RogueEssence"):
		return "material"
	return "category_%d" % sort_category


func _item_use_kind(slug: String, item_states: Array[String], bag_effect: bool, obj: Dictionary) -> int:
	if item_states.has("PMDC.Dungeon.HeldState, PMDC") or item_states.has("PMDC.Dungeon.EquipState, PMDC"):
		return PokemonItemResource.UseKind.HELD
	if slug.begins_with("tm_"):
		return PokemonItemResource.UseKind.TM
	if item_states.has("PMDC.Dungeon.EvoState, PMDC"):
		return PokemonItemResource.UseKind.EVOLUTION
	if bag_effect:
		return PokemonItemResource.UseKind.BAG_PASSIVE
	if item_states.has("PMDC.Dungeon.EdibleState, PMDC") or _has_item_use_event(obj):
		return PokemonItemResource.UseKind.CONSUMABLE
	if item_states.has("RogueEssence.Dungeon.MaterialState, RogueEssence"):
		return PokemonItemResource.UseKind.MATERIAL
	return PokemonItemResource.UseKind.NONE


func _has_item_use_event(obj: Dictionary) -> bool:
	var use_event: Dictionary = _dict_field(obj, "UseEvent")
	for key in ["BeforeTryActions", "BeforeActions", "OnActions", "BeforeHits", "OnHits", "AfterActions"]:
		var arr: Variant = use_event.get(key, [])
		if arr is Array and not (arr as Array).is_empty():
			return true
	return false


func _stat_from_pmdo_index(index: int) -> String:
	match index:
		0:
			return "hp"
		1:
			return "attack"
		2:
			return "defense"
		3:
			return "special_attack"
		4:
			return "special_defense"
		5:
			return "speed"
	return ""


# ---------------------------------------------------------------------------
# Species + forms
# ---------------------------------------------------------------------------

func _import_species(import_entries: Array, sprite_sets: Dictionary, moves: Dictionary, source_roots: Dictionary, report: PokemonValidation) -> Dictionary:
	var out: Dictionary = {}
	for raw_entry in import_entries:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var save_path: String = _import_one_species(entry, sprite_sets, moves, source_roots, report)
		if not save_path.is_empty():
			out[String(entry.get("slug", ""))] = save_path
	return out


func _import_one_species(entry_data: Dictionary, sprite_sets: Dictionary, moves: Dictionary, source_roots: Dictionary, report: PokemonValidation) -> String:
	# `slug` is the bare PMDODump identifier (e.g. "gallade"); `project_slug`
	# carries the in-project numbered prefix (e.g. "0475_gallade") that every
	# generated file and every cross-resource reference uses.
	var slug: String = String(entry_data.get("pmdo_slug", ""))
	var project_slug: String = String(entry_data.get("slug", _Paths.project_slug_for(slug, int(entry_data.get("dex_number", 0)))))
	var entry := PokemonValidation.SpeciesEntry.new()
	entry.slug = project_slug
	entry.status = String(entry_data.get("status", "battle_ready"))
	entry.disabled_reason = String(entry_data.get("disabled_reason", ""))
	entry.generation = int(entry_data.get("generation", 0))
	var default_moves: Array = _entry_move_array(entry_data, "default_moves")
	if not default_moves.is_empty():
		entry.signature_move = String(default_moves[0])

	var raw: Variant = _read_json_absolute(_monster_json_path(entry_data, source_roots))
	if raw == null:
		report.add_error("Monster JSON missing or invalid for %s" % slug)
		report.add_species(entry)
		return ""
	var obj: Dictionary = _dict_field(raw, "Object")
	if obj.is_empty():
		report.add_error("Monster JSON has no Object for %s" % slug)
		report.add_species(entry)
		return ""

	var species: PokemonSpeciesResource = PokemonSpeciesResource.new()
	species.species_id = project_slug
	species.dex_number = int(obj.get("IndexNum", 0))
	species.canonical_name = _localized(obj.get("Name", {}))
	species.released = bool(obj.get("Released", true))
	species.evolution_from = String(obj.get("PromoteFrom", ""))
	species.evolutions = _evolutions_from_promotions(obj.get("Promotions", []))
	species.skill_group1 = String(obj.get("SkillGroup1", ""))
	species.skill_group2 = String(obj.get("SkillGroup2", ""))

	var sprite_path: String = String(sprite_sets.get(project_slug, ""))
	var sprite_set: PokemonSpriteSetResource = null
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		sprite_set = load(sprite_path) as PokemonSpriteSetResource
	if sprite_set == null:
		report.add_warning("Species %s could not link sprite set" % slug)

	var forms_v: Variant = obj.get("Forms", [])
	var form_array: Array = forms_v if forms_v is Array else []
	species.forms = []
	species.default_form_index = -1
	var form_summary: PokemonFormResource = null
	for i in range(form_array.size()):
		var form_entry: Variant = form_array[i]
		if not (form_entry is Dictionary):
			continue
		var form_dict: Dictionary = form_entry
		var form: PokemonFormResource = PokemonFormResource.new()
		form.species_id = project_slug
		form.form_index = i
		form.generation = int(form_dict.get("Generation", 0))
		form.type1 = String(form_dict.get("Element1", "none")).to_lower()
		form.type2 = String(form_dict.get("Element2", "none")).to_lower()
		form.base_hp = int(form_dict.get("BaseHP", 0))
		form.base_atk = int(form_dict.get("BaseAtk", 0))
		form.base_def = int(form_dict.get("BaseDef", 0))
		form.base_spa = int(form_dict.get("BaseMAtk", 0))
		form.base_spd = int(form_dict.get("BaseMDef", 0))
		form.base_speed = int(form_dict.get("BaseSpeed", 0))
		form.height = float(form_dict.get("Height", 0.0))
		form.weight = float(form_dict.get("Weight", 0.0))
		form.gender_weights = Vector3i(
			int(form_dict.get("GenderlessWeight", 0)),
			int(form_dict.get("MaleWeight", 0)),
			int(form_dict.get("FemaleWeight", 0)),
		)
		form.exp_table = String(obj.get("EXPTable", ""))
		form.exp_table_values = _growth_table_values(form.exp_table, source_roots, report)
		form.exp_yield = int(form_dict.get("ExpYield", 0))
		form.join_rate = int(obj.get("JoinRate", 0))
		form.temporary = bool(form_dict.get("Temporary", false))
		form.intrinsic1 = String(form_dict.get("Intrinsic1", ""))
		form.intrinsic2 = String(form_dict.get("Intrinsic2", ""))
		form.intrinsic3 = String(form_dict.get("Intrinsic3", ""))
		form.sprite_set = sprite_set if i == 0 else null

		var form_save_path: String = _Paths.generated_form_path_for_project_slug(project_slug, i)
		var err: int = ResourceSaver.save(form, form_save_path)
		if err != OK:
			report.add_error("Failed to save %s form %d (err %d)" % [slug, i, err])
			continue
		var loaded_form: PokemonFormResource = load(form_save_path) as PokemonFormResource
		if loaded_form != null:
			species.forms.append(loaded_form)
			if species.default_form_index < 0 and not loaded_form.temporary:
				species.default_form_index = species.forms.size() - 1
			if i == 0:
				form_summary = loaded_form

	if species.default_form_index < 0:
		species.default_form_index = 0

	var first_form_dict: Dictionary = {}
	if form_array.size() > 0 and form_array[0] is Dictionary:
		first_form_dict = form_array[0]
	var level_skills: Array[Dictionary] = []
	var level_arr: Variant = first_form_dict.get("LevelSkills", [])
	if level_arr is Array:
		for ls in level_arr:
			if ls is Dictionary:
				var ls_dict: Dictionary = ls
				level_skills.append({
					"level": int(ls_dict.get("Level", 1)),
					"skill": String(ls_dict.get("Skill", "")),
				})
	species.level_skills = level_skills
	species.teach_skills = _string_skill_list(first_form_dict, "TeachSkills")
	species.shared_skills = _string_skill_list(first_form_dict, "SharedSkills")
	species.secret_skills = _string_skill_list(first_form_dict, "SecretSkills")

	var save_path: String = _Paths.generated_species_path_for_project_slug(project_slug)
	var save_err: int = ResourceSaver.save(species, save_path)
	if save_err != OK:
		report.add_error("Failed to save species %s (err %d)" % [slug, save_err])
		report.add_species(entry)
		return ""

	entry.dex = species.dex_number
	entry.canonical_name = species.canonical_name
	if form_summary != null:
		entry.type1 = form_summary.type1
		entry.type2 = form_summary.type2
		entry.base_stats = PackedInt32Array([
			form_summary.base_hp, form_summary.base_atk, form_summary.base_def,
			form_summary.base_spa, form_summary.base_spd, form_summary.base_speed,
		])
	if sprite_set != null:
		for warning in sprite_set.validation_warnings:
			entry.sprite_warnings.append(warning)
	for move_slug in default_moves:
		if not moves.has(String(move_slug)):
			entry.notes.append("default move %s did not import" % String(move_slug))
	entry.imported = true
	report.add_species(entry)
	return save_path


func _string_skill_list(form_dict: Dictionary, key: String) -> Array[String]:
	var out: Array[String] = []
	var arr: Variant = form_dict.get(key, [])
	if not (arr is Array):
		return out
	for entry in arr:
		if entry is Dictionary:
			var entry_dict: Dictionary = entry
			if entry_dict.has("Skill"):
				out.append(String(entry_dict["Skill"]))
		elif entry is String:
			out.append(String(entry))
	return out


func _evolutions_from_promotions(promotions: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (promotions is Array):
		return out
	for raw_promotion in promotions:
		if not (raw_promotion is Dictionary):
			continue
		var promotion: Dictionary = raw_promotion
		var result_slug: String = String(promotion.get("Result", ""))
		if result_slug.is_empty():
			continue
		out.append({
			"result": result_slug,
			"requirements": _evolution_requirements(promotion.get("Details", [])),
		})
	return out


func _evolution_requirements(details: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (details is Array):
		return out
	for raw_detail in details:
		if not (raw_detail is Dictionary):
			continue
		var detail: Dictionary = raw_detail
		var tag: String = String(detail.get("$type", ""))
		if tag == "PMDC.Data.EvoLevel, PMDC":
			out.append({
				"kind": "level",
				"level": int(detail.get("Level", 1)),
				"source_event": tag,
			})
		else:
			out.append({
				"kind": "unsupported",
				"source_event": tag,
			})
	return out


func _growth_table_values(exp_table: String, source_roots: Dictionary, report: PokemonValidation) -> PackedInt32Array:
	var key: String = exp_table.to_lower()
	if key.is_empty():
		return PackedInt32Array()
	if _growth_table_cache.has(key):
		return _growth_table_cache[key]
	var raw: Variant = _read_json_absolute(_growth_json_path(key, source_roots))
	if raw == null:
		report.add_warning("Growth table missing or invalid: %s" % key)
		_growth_table_cache[key] = PackedInt32Array()
		return _growth_table_cache[key]
	var obj: Dictionary = _dict_field(raw, "Object")
	var values: PackedInt32Array = PackedInt32Array()
	var arr: Variant = obj.get("EXPTable", [])
	if arr is Array:
		for value in arr:
			values.append(int(value))
	_growth_table_cache[key] = values
	return values


func _typed_string_array(values: Array) -> Array[String]:
	var out: Array[String] = []
	for value in values:
		out.append(String(value))
	return out


# ---------------------------------------------------------------------------
# Generated default instances
# ---------------------------------------------------------------------------

func _author_generated_instances(import_entries: Array, species_map: Dictionary, moves: Dictionary, report: PokemonValidation) -> void:
	for raw_entry in import_entries:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		if String(entry.get("status", "")) != "battle_ready":
			continue
		var slug: String = String(entry.get("pmdo_slug", ""))
		var project_slug: String = String(entry.get("slug", _Paths.project_slug_for(slug, int(entry.get("dex_number", 0)))))
		var species_path: String = String(species_map.get(project_slug, ""))
		if species_path.is_empty():
			report.add_warning("Skipping generated instance for %s (species missing)" % project_slug)
			continue

		var instance: PokemonInstanceResource = PokemonInstanceResource.new()
		instance.species = load(species_path) as PokemonSpeciesResource
		instance.form_index = int(entry.get("default_form_index", 0))
		instance.level = 50
		instance.current_hp = PokemonInstanceResource.CURRENT_HP_AUTO
		instance.movement_override = int(_LEGACY_MOVEMENT_OVERRIDE.get(slug, 0))
		instance.team = PokemonInstanceResource.Team.NEUTRAL
		instance.control_type = PokemonInstanceResource.ControlType.AI

		var move_slugs: Array = _entry_move_array(entry, "default_moves")
		var move_slots: Array[PokemonMoveResource] = []
		var pp_state: Array[int] = []
		for move_slug_var in move_slugs:
			var move_slug: String = String(move_slug_var)
			var move_path: String = String(moves.get(move_slug, ""))
			var move: PokemonMoveResource = null
			if not move_path.is_empty():
				move = load(move_path) as PokemonMoveResource
			if move == null:
				continue
			move_slots.append(move)
			pp_state.append(move.pp)
			if move_slots.size() >= PokemonInstanceResource.MAX_MOVE_SLOTS:
				break
		if move_slots.is_empty():
			report.add_warning("Generated instance for %s has no usable moves" % project_slug)
			continue
		instance.move_slots = move_slots
		instance.pp_state = pp_state

		var save_path: String = _Paths.generated_instance_path_for_project_slug(project_slug)
		var err: int = ResourceSaver.save(instance, save_path)
		if err != OK:
			report.add_error("Failed to save generated instance %s (err %d)" % [project_slug, err])
			continue
		report.record_instance(save_path)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _read_json_absolute(absolute_path: String) -> Variant:
	if not FileAccess.file_exists(absolute_path):
		return null
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return null
	var text: String = file.get_as_text()
	file.close()
	if text.is_empty():
		return null
	var parsed: Variant = JSON.parse_string(text)
	return parsed


## PMD localized strings come as `{ DefaultText: "...", LocalTexts: { ... } }`.
## We just take the default for M1.
func _localized(node: Variant) -> String:
	if node is Dictionary:
		var d: Dictionary = node
		if d.has("DefaultText"):
			return String(d["DefaultText"])
	if node is String:
		return String(node)
	return ""


## Reads a dictionary-typed field from `parent` (which itself may be a Variant
## holding a Dictionary). Returns an empty Dictionary on any type mismatch so
## callers can keep their type annotations clean without unsafe casts.
func _dict_field(parent: Variant, key: String) -> Dictionary:
	if not (parent is Dictionary):
		return {}
	var inner: Variant = (parent as Dictionary).get(key, {})
	if inner is Dictionary:
		return inner
	return {}


func _load_import_context() -> Dictionary:
	if FileAccess.file_exists(_Paths.IMPORT_MANIFEST_PATH):
		var file: FileAccess = FileAccess.open(_Paths.IMPORT_MANIFEST_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				var manifest: Dictionary = parsed
				var species: Array = manifest.get("species", [])
				if not species.is_empty():
					print_rich("[color=cyan]PMDOImporter: using manifest %s (%d entries)[/color]" % [_Paths.IMPORT_MANIFEST_PATH, species.size()])
					return {
						"species": species,
						"source_roots": manifest.get("source_roots", {}),
					}
	print_rich("[color=yellow]PMDOImporter: no manifest found; using legacy M1 target list[/color]")
	return {
		"species": _legacy_import_entries(),
		"source_roots": {"pmdo_root": _Paths.pmdo_root()},
	}


func _load_visual_manifest() -> Dictionary:
	if not FileAccess.file_exists(_Paths.VISUAL_ASSET_MANIFEST_PATH):
		return {}
	var file: FileAccess = FileAccess.open(_Paths.VISUAL_ASSET_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _visual_lookup_path(visual_manifest: Dictionary, category: String, key: String) -> String:
	if key.is_empty():
		return ""
	var lookup: Variant = visual_manifest.get("lookup", {})
	if not (lookup is Dictionary):
		return ""
	var category_lookup: Variant = (lookup as Dictionary).get(category, {})
	if not (category_lookup is Dictionary):
		return ""
	if (category_lookup as Dictionary).has(key):
		return String((category_lookup as Dictionary)[key])
	return ""


func _status_icon_path(status_id: String, visual_manifest: Dictionary) -> String:
	var key: String = _status_icon_key(status_id)
	if key.is_empty():
		return ""
	return _visual_lookup_path(visual_manifest, "Icon", key)


func _status_icon_key(status_id: String) -> String:
	match status_id.to_lower():
		"burn", "burned":
			return "Burn"
		"confuse", "confused":
			return "Confuse"
		"freeze", "frozen":
			return "Freeze"
		"sleep", "asleep":
			return "Sleep"
		"yawn":
			return "Yawn"
	return ""


func _legacy_import_entries() -> Array:
	var out: Array = []
	for slug in _LEGACY_TARGET_SPECIES:
		var dex_number: int = int(_LEGACY_DEX_NUMBERS.get(slug, 0))
		var project_slug: String = _Paths.project_slug_for(slug, dex_number)
		var signature_move: String = String(_LEGACY_SIGNATURE_MOVES.get(slug, ""))
		out.append({
			"pmdo_slug": slug,
			"slug": project_slug,
			"dex_number": dex_number,
			"display_name": slug.capitalize(),
			"generation": _generation_from_dex(dex_number),
			"released": true,
			"default_form_index": 0,
			"status": "battle_ready",
			"disabled_reason": "",
			"warnings": [],
			"assets": {
				"idle": _Paths.sprite_state_path_for_project_slug(project_slug, "idle"),
				"walk": _Paths.sprite_state_path_for_project_slug(project_slug, "walk"),
				"hurt": _Paths.sprite_state_path_for_project_slug(project_slug, "hurt"),
				"sleep": _Paths.sprite_state_path_for_project_slug(project_slug, "sleep"),
				"hop": _Paths.sprite_state_path_for_project_slug(project_slug, "hop"),
				"anim_data": _Paths.anim_data_path_for_project_slug(project_slug),
				"portrait_normal": "res://assets/textures/pokemon/portraits/%s/Normal.png" % project_slug,
			},
			"moves": {
				"import_moves": [signature_move],
				"default_moves": [signature_move],
			},
		})
	return out


func _move_slugs_for_import(import_entries: Array) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	for raw_entry in import_entries:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var moves_info: Variant = entry.get("moves", {})
		if not (moves_info is Dictionary):
			continue
		for key in ["import_moves", "default_moves"]:
			var arr: Variant = (moves_info as Dictionary).get(key, [])
			if not (arr is Array):
				continue
			for move_slug_var in arr:
				var move_slug: String = String(move_slug_var)
				if move_slug.is_empty() or seen.has(move_slug):
					continue
				seen[move_slug] = true
				out.append(move_slug)
	return out


func _entry_move_array(entry: Dictionary, key: String) -> Array:
	var moves_info: Variant = entry.get("moves", {})
	if moves_info is Dictionary:
		var arr: Variant = (moves_info as Dictionary).get(key, [])
		if arr is Array:
			return arr
	return []


func _pmdo_root(source_roots: Dictionary) -> String:
	return String(source_roots.get("pmdo_root", _Paths.pmdo_root()))


func _universal_path(source_roots: Dictionary) -> String:
	return "%s/DumpAsset/Data/Universal.json" % _pmdo_root(source_roots)


func _skill_json_path(slug: String, source_roots: Dictionary) -> String:
	return "%s/DumpAsset/Data/Skill/%s.json" % [_pmdo_root(source_roots), slug]


func _item_dir_path(source_roots: Dictionary) -> String:
	return "%s/DumpAsset/Data/Item" % _pmdo_root(source_roots)


func _intrinsic_json_path(slug: String, source_roots: Dictionary) -> String:
	return "%s/DumpAsset/Data/Intrinsic/%s.json" % [_pmdo_root(source_roots), slug]


func _growth_json_path(slug: String, source_roots: Dictionary) -> String:
	return "%s/DumpAsset/Data/GrowthGroup/%s.json" % [_pmdo_root(source_roots), slug]


func _monster_json_path(entry: Dictionary, source_roots: Dictionary) -> String:
	var source: Variant = entry.get("source", {})
	if source is Dictionary:
		var rel_path: String = String((source as Dictionary).get("monster_json", ""))
		if not rel_path.is_empty():
			return "%s/%s" % [_pmdo_root(source_roots), rel_path]
	return "%s/DumpAsset/Data/Monster/%s.json" % [_pmdo_root(source_roots), String(entry.get("pmdo_slug", ""))]


func _res_path_exists(path: String) -> bool:
	if path.is_empty():
		return false
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


func _generation_from_dex(dex_number: int) -> int:
	if dex_number <= 151:
		return 1
	if dex_number <= 251:
		return 2
	if dex_number <= 386:
		return 3
	if dex_number <= 493:
		return 4
	if dex_number <= 649:
		return 5
	if dex_number <= 721:
		return 6
	if dex_number <= 809:
		return 7
	if dex_number <= 905:
		return 8
	return 9
