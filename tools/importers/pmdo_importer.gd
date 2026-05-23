@tool
class_name PMDOImporter
extends RefCounted
## PMDODump -> Godot Pokemon resource importer.
##
## Reads JSON from the sibling PMDODump checkout, emits .tres files into
## `res://data/models/pokemon/generated/`, hand-authors level-50 instance
## overrides under `overrides/instances/`, and writes a flat report at
## `import_reports/pokemon_import_report.txt`.
##
## Scoped to the M1 species slice (7 Pokemon, 7 signature moves, full type chart).
## Adding more species in M7 is a matter of extending `PMDOPaths.TARGET_SPECIES`
## and `PMDOPaths.SIGNATURE_MOVES`.
##
## Two ways to invoke it:
## 1. From the Godot editor: open `pmdo_importer_editor.gd` in the script editor
##    and choose File -> Run.
## 2. Headless: `godot --headless --path <project> --script tools/importers/pmdo_run.gd`.

const _SkillMapper: GDScript = preload("res://tools/importers/pmdo_skill_mapper.gd")
const _Paths: GDScript = preload("res://tools/importers/pmdo_paths.gd")
const _Validation: GDScript = preload("res://tools/validation/pokemon_validation.gd")


func run() -> void:
	print_rich("[color=cyan]PMDOImporter: starting import[/color]")
	_ensure_directories()

	var report: PokemonValidation = _Validation.new()

	var type_chart: TypeChartResource = _import_type_chart(report)
	var sprite_sets: Dictionary = _import_sprite_sets(report)
	var moves: Dictionary = _import_moves(report)
	var species_map: Dictionary = _import_species(sprite_sets, moves, report)
	_author_instances(species_map, moves, report)

	var report_path: String = _Paths.REPORT_PATH
	if report.write(report_path):
		print_rich("[color=cyan]PMDOImporter: report written to %s[/color]" % report_path)
	else:
		push_error("PMDOImporter: failed to write %s" % report_path)

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
		_Paths.GENERATED_SPRITES_DIR,
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

func _import_type_chart(report: PokemonValidation) -> TypeChartResource:
	var raw: Variant = _read_json_absolute(_Paths.PMDO_UNIVERSAL_PATH)
	if raw == null:
		report.add_error("Could not read Universal.json at %s" % _Paths.PMDO_UNIVERSAL_PATH)
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

func _import_sprite_sets(report: PokemonValidation) -> Dictionary:
	var out: Dictionary = {}
	for slug in _Paths.TARGET_SPECIES:
		var sprite_set: PokemonSpriteSetResource = _build_sprite_set(slug, report)
		var save_path: String = _Paths.generated_sprite_path(slug)
		var err: int = ResourceSaver.save(sprite_set, save_path)
		if err != OK:
			report.add_error("Failed to save sprite set for %s (err %d)" % [slug, err])
			continue
		out[slug] = save_path
	return out


func _build_sprite_set(slug: String, report: PokemonValidation) -> PokemonSpriteSetResource:
	var sprite_set: PokemonSpriteSetResource = PokemonSpriteSetResource.new()
	var anim_data_path: String = _Paths.anim_data_path(slug)
	if ResourceLoader.exists(anim_data_path) or FileAccess.file_exists(anim_data_path):
		sprite_set.anim_data_path = anim_data_path
	else:
		report.add_warning("%s missing AnimData.xml at %s" % [slug, anim_data_path])
	var idle_path: String = _Paths.sprite_state_path(slug, "idle")
	var sidecars: Array = [
		["walk", _Paths.sprite_state_path(slug, "walk")],
		["hurt", _Paths.sprite_state_path(slug, "hurt")],
		["sleep", _Paths.sprite_state_path(slug, "sleep")],
		["hop", _Paths.sprite_state_path(slug, "hop")],
	]

	if ResourceLoader.exists(idle_path):
		sprite_set.idle_path = idle_path
	else:
		var msg: String = "%s missing idle sprite at %s" % [slug, idle_path]
		sprite_set.validation_warnings.append(msg)
		report.add_warning(msg)

	for entry in sidecars:
		var label: String = String(entry[0])
		var path: String = String(entry[1])
		if ResourceLoader.exists(path):
			match label:
				"walk": sprite_set.walk_path = path
				"hurt": sprite_set.hurt_path = path
				"sleep": sprite_set.sleep_path = path
				"hop": sprite_set.hop_path = path
		else:
			var warning: String = "%s missing %s sprite at %s" % [slug, label, path]
			sprite_set.validation_warnings.append(warning)
			report.add_warning(warning)

	return sprite_set


# ---------------------------------------------------------------------------
# Moves
# ---------------------------------------------------------------------------

func _import_moves(report: PokemonValidation) -> Dictionary:
	var out: Dictionary = {}
	var slugs_seen: Dictionary = {}
	for species_slug in _Paths.SIGNATURE_MOVES.keys():
		var move_slug: String = String(_Paths.SIGNATURE_MOVES[species_slug])
		if slugs_seen.has(move_slug):
			out[move_slug] = slugs_seen[move_slug]
			continue
		var save_path: String = _import_move(move_slug, report)
		slugs_seen[move_slug] = save_path
		out[move_slug] = save_path
	return out


func _import_move(slug: String, report: PokemonValidation) -> String:
	var entry := PokemonValidation.MoveEntry.new()
	entry.slug = slug

	var json_path: String = _Paths.skill_json_path(slug)
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
# Species + forms
# ---------------------------------------------------------------------------

func _import_species(sprite_sets: Dictionary, moves: Dictionary, report: PokemonValidation) -> Dictionary:
	var out: Dictionary = {}
	for slug in _Paths.TARGET_SPECIES:
		var save_path: String = _import_one_species(slug, sprite_sets, moves, report)
		if not save_path.is_empty():
			out[slug] = save_path
	return out


func _import_one_species(slug: String, sprite_sets: Dictionary, moves: Dictionary, report: PokemonValidation) -> String:
	# `slug` is the bare PMDODump identifier (e.g. "gallade"); `project_slug`
	# carries the in-project numbered prefix (e.g. "0475_gallade") that every
	# generated file and every cross-resource reference uses.
	var project_slug: String = _Paths.project_slug_for(slug)
	var entry := PokemonValidation.SpeciesEntry.new()
	entry.slug = project_slug
	entry.signature_move = String(_Paths.SIGNATURE_MOVES.get(slug, ""))

	var raw: Variant = _read_json_absolute(_Paths.monster_json_path(slug))
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

	var sprite_path: String = String(sprite_sets.get(slug, ""))
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

		var form_save_path: String = _Paths.generated_form_path(slug, i)
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

	var save_path: String = _Paths.generated_species_path(slug)
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
	var sig_move_slug: String = String(_Paths.SIGNATURE_MOVES.get(slug, ""))
	if not sig_move_slug.is_empty() and not moves.has(sig_move_slug):
		entry.notes.append("signature move %s did not import" % sig_move_slug)
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


# ---------------------------------------------------------------------------
# Instance overrides
# ---------------------------------------------------------------------------

func _author_instances(species_map: Dictionary, moves: Dictionary, report: PokemonValidation) -> void:
	for slug in _Paths.TARGET_SPECIES:
		var species_path: String = String(species_map.get(slug, ""))
		if species_path.is_empty():
			report.add_warning("Skipping instance for %s (species missing)" % slug)
			continue

		var instance: PokemonInstanceResource = PokemonInstanceResource.new()
		instance.species = load(species_path) as PokemonSpeciesResource
		instance.form_index = 0
		instance.level = 50
		instance.current_hp = PokemonInstanceResource.CURRENT_HP_AUTO
		instance.movement_override = int(_Paths.LEGACY_MOVEMENT_OVERRIDE.get(slug, 0))

		if slug in _Paths.PLAYER_TEAM_SPECIES:
			instance.team = PokemonInstanceResource.Team.PLAYER
			instance.control_type = PokemonInstanceResource.ControlType.PLAYER
		else:
			instance.team = PokemonInstanceResource.Team.ENEMY
			instance.control_type = PokemonInstanceResource.ControlType.AI

		var move_slug: String = String(_Paths.SIGNATURE_MOVES.get(slug, ""))
		var move_path: String = String(moves.get(move_slug, ""))
		var move: PokemonMoveResource = null
		if not move_path.is_empty():
			move = load(move_path) as PokemonMoveResource
		if move != null:
			instance.move_slots = [move]
			instance.pp_state = [move.pp]
		else:
			report.add_warning("Instance for %s has no move (signature %s missing)" % [slug, move_slug])

		var save_path: String = _Paths.instance_override_path(slug)
		var err: int = ResourceSaver.save(instance, save_path)
		if err != OK:
			report.add_error("Failed to save instance %s (err %d)" % [slug, err])
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
