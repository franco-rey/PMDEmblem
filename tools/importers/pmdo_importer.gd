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


func run() -> void:
	print_rich("[color=cyan]PMDOImporter: starting import[/color]")
	_ensure_directories()

	var report: PokemonValidation = _Validation.new()
	var import_context: Dictionary = _load_import_context()
	var import_entries: Array = import_context.get("species", [])
	var source_roots: Dictionary = import_context.get("source_roots", {})

	var type_chart: TypeChartResource = _import_type_chart(report, source_roots)
	var sprite_sets: Dictionary = _import_sprite_sets(import_entries, report)
	var moves: Dictionary = _import_moves(import_entries, source_roots, report)
	var species_map: Dictionary = _import_species(import_entries, sprite_sets, moves, source_roots, report)
	_import_status_resources(moves, report)
	_import_intrinsic_resources(species_map, report)
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
	sprite_set.animation_states = _default_animation_states(sprite_set)
	if assets.has("portrait_normal"):
		sprite_set.portrait_paths = [String(assets["portrait_normal"])]

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


func _default_animation_states(sprite_set: PokemonSpriteSetResource) -> Dictionary:
	var states: Dictionary = {}
	var path_by_key: Dictionary = {
		"idle": sprite_set.idle_path,
		"walk": sprite_set.walk_path,
		"hurt": sprite_set.hurt_path,
		"sleep": sprite_set.sleep_path,
		"faint": sprite_set.sleep_path,
		"hop": sprite_set.hop_path,
		"attack": sprite_set.hop_path,
		"physical_attack": sprite_set.hop_path,
		"special_attack": sprite_set.hop_path,
		"status_attack": sprite_set.idle_path,
		"miss": sprite_set.idle_path,
	}
	for key in path_by_key.keys():
		var path: String = String(path_by_key[key])
		if path.is_empty():
			continue
		states[key] = {
			"path": path,
			"source_name": key.capitalize(),
			"cell_size": Vector2i.ZERO,
			"directions": 8,
			"frame_count": 0,
			"timing": [],
		}
	return states


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

func _import_status_resources(moves: Dictionary, report: PokemonValidation) -> void:
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
		var status_meta: Dictionary = statuses[status_id]
		status.source_event_tags = _typed_string_array(status_meta["events"] as Array)
		status.supported_hook_families = _typed_string_array(status_meta["families"] as Array)
		var err: int = ResourceSaver.save(status, _Paths.generated_status_path(status.status_id))
		if err != OK:
			report.add_error("Failed to save status %s (err %d)" % [status.status_id, err])


func _import_intrinsic_resources(species_map: Dictionary, report: PokemonValidation) -> void:
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

	var supported_damage_boosts: Array[String] = ["blaze", "overgrow", "torrent"]
	for slug in slugs.keys():
		var intrinsic := PokemonIntrinsicResource.new()
		intrinsic.intrinsic_id = String(slug)
		intrinsic.display_name = intrinsic.intrinsic_id.capitalize()
		if supported_damage_boosts.has(intrinsic.intrinsic_id):
			intrinsic.supported_hook_families = _typed_string_array(["battle_start", "before_damage"])
			intrinsic.report_summary = "Supported low-HP same-type damage boost."
		else:
			intrinsic.supported_hook_families = _typed_string_array(["battle_start"])
			intrinsic.unsupported_hook_families = _typed_string_array(["before_accuracy", "before_damage", "after_damage", "status_application", "target_legality"])
			intrinsic.report_summary = "Recorded for M6; combat-specific hooks are explicit unsupported entries."
		var err: int = ResourceSaver.save(intrinsic, _Paths.generated_intrinsic_path(intrinsic.intrinsic_id))
		if err != OK:
			report.add_error("Failed to save intrinsic %s (err %d)" % [intrinsic.intrinsic_id, err])


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
		"source_roots": {"pmdo_root": _Paths.PMDO_ROOT},
	}


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
	return String(source_roots.get("pmdo_root", _Paths.PMDO_ROOT))


func _universal_path(source_roots: Dictionary) -> String:
	return "%s/DumpAsset/Data/Universal.json" % _pmdo_root(source_roots)


func _skill_json_path(slug: String, source_roots: Dictionary) -> String:
	return "%s/DumpAsset/Data/Skill/%s.json" % [_pmdo_root(source_roots), slug]


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
