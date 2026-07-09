extends SceneTree

const MANIFEST_PATH: String = "res://data/models/pokemon/generated/manifests/pokemon_import_manifest.json"
const VISUAL_MANIFEST_PATH: String = "res://data/models/visuals/generated/visual_asset_manifest.json"
const REPORT_PATH: String = "res://data/models/pokemon/import_reports/asset_coverage_report.json"
const ACTOR_ROOT: String = "res://assets/textures/actor/pokemon"
const PORTRAIT_ROOT: String = "res://assets/textures/pokemon/portraits"
const RAW_ASSET_COPY_ROOT: String = "res://assets/visuals/raw_asset"
const GENERATED_ITEMS_DIR: String = "res://data/models/pokemon/generated/items"
const GENERATED_STATUSES_DIR: String = "res://data/models/pokemon/generated/statuses"
const SPRITE_COLLAB_ROOT_ENV: String = "PMD_EMBLEM_SPRITE_COLLAB_ROOT"
const SPRITE_COLLAB_ROOT_FALLBACK: String = "res://../SpriteCollab"
const RAW_ASSET_ROOT_ENV: String = "PMD_EMBLEM_RAW_ASSET_ROOT"
const RAW_ASSET_ROOT_FALLBACK: String = "res://../RawAsset"
const VFX_CATEGORIES: Array[String] = ["BG", "Beam", "Icon", "Item", "Particle"]
const ANIM_SUFFIX: String = "-Anim.png"
const SOURCE_STATE_TO_RUNTIME_KEY: Dictionary = {
	"Idle": "idle",
	"Walk": "walk",
	"Hurt": "hurt",
	"Sleep": "sleep",
	"Laying": "sleep",
	"EventSleep": "sleep",
	"Hop": "hop",
	"Faint": "faint",
	"Attack": "attack",
}
const REQUIRED_STATE_SOURCES: Dictionary = {
	"idle": ["Idle-Anim.png"],
	"walk": ["Walk-Anim.png"],
	"hurt": ["Hurt-Anim.png"],
	"sleep": ["Laying-Anim.png", "EventSleep-Anim.png", "Sleep-Anim.png"],
	"hop": ["Hop-Anim.png"],
}

var failures: int = 0


func _init() -> void:
	var manifest: Dictionary = _load_json(MANIFEST_PATH)
	var visual_manifest: Dictionary = _load_json(VISUAL_MANIFEST_PATH)
	var sprite_collab_root: String = _resolve_source_root(SPRITE_COLLAB_ROOT_ENV, SPRITE_COLLAB_ROOT_FALLBACK)
	var raw_asset_root: String = _resolve_source_root(RAW_ASSET_ROOT_ENV, RAW_ASSET_ROOT_FALLBACK)
	_assert_true(not manifest.is_empty(), "import manifest loads")
	_assert_true(not visual_manifest.is_empty(), "visual asset manifest loads")
	_assert_true(DirAccess.dir_exists_absolute(sprite_collab_root), "SpriteCollab source root exists (%s)" % sprite_collab_root)
	_assert_true(DirAccess.dir_exists_absolute(raw_asset_root), "RawAsset source root exists (%s)" % raw_asset_root)
	if failures > 0:
		push_error("smoke: asset_coverage failed %d precondition(s)" % failures)
		quit(1)
		return
	var species_section: Dictionary = _build_species_section(manifest, sprite_collab_root)
	var category_section: Dictionary = _build_category_section(raw_asset_root, visual_manifest)
	var mapping_section: Dictionary = _build_icon_mapping_section()
	var payload: Dictionary = {
		"categories": category_section,
		"icon_mappings": mapping_section,
		"schema_version": 1,
		"scope": "686 released base forms; VFX categories BG/Beam/Icon/Item/Particle; Object/Tile/TileDtef/font out of scope",
		"source": "smoke_test_asset_coverage",
		"species": species_section,
	}
	var written: bool = _write_text(REPORT_PATH, JSON.stringify(payload, "\t") + "\n")
	_assert_true(written, "asset coverage report written")
	var species_summary: Dictionary = species_section.get("summary", {})
	_assert_true(int(species_summary.get("species_total", 0)) == 686, "report covers 686 species")
	if failures > 0:
		push_error("smoke: asset_coverage failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: asset_coverage clean - species=%d state_gap_species=%d portrait_gap_species=%d unmapped_item_icons=%d unmapped_status_icons=%d" % [
		int(species_summary.get("species_total", 0)),
		int(species_summary.get("species_with_state_gaps", 0)),
		int(species_summary.get("species_with_portrait_gaps", 0)),
		(mapping_section.get("unmapped_item_icons", []) as Array).size(),
		(mapping_section.get("unmapped_status_icons", []) as Array).size(),
	])
	quit(0)


func _build_species_section(manifest: Dictionary, sprite_collab_root: String) -> Dictionary:
	var entries: Array[Dictionary] = []
	var state_gap_entries: Array[Dictionary] = []
	var portrait_gap_entries: Array[Dictionary] = []
	var substitution_count: int = 0
	var source_state_total: int = 0
	var imported_state_total: int = 0
	var source_portrait_total: int = 0
	var imported_portrait_total: int = 0
	var slugs: Array[String] = []
	var entries_by_slug: Dictionary = {}
	for raw_entry in manifest.get("species", []):
		if raw_entry is Dictionary:
			var slug: String = String((raw_entry as Dictionary).get("slug", ""))
			slugs.append(slug)
			entries_by_slug[slug] = raw_entry
	slugs.sort()
	for slug in slugs:
		var manifest_entry: Dictionary = entries_by_slug[slug]
		var dex: String = slug.substr(0, 4)
		var sprite_source_dir: String = _find_sprite_source_dir("%s/sprite/%s" % [sprite_collab_root, dex])
		var source_keys: Array[String] = _source_state_keys(sprite_source_dir)
		var imported_keys: Array[String] = _imported_state_keys("%s/%s/animations" % [ACTOR_ROOT, slug])
		var missing_states: Array[String] = _difference(source_keys, imported_keys)
		var extra_states: Array[String] = _difference(imported_keys, source_keys)
		var substitutions: Dictionary = (manifest_entry.get("assets", {}) as Dictionary).get("sprite_substitutions", {})
		if not substitutions.is_empty():
			substitution_count += 1
		var portrait_source_dir: String = _find_portrait_source_dir("%s/portrait/%s" % [sprite_collab_root, dex])
		var source_portraits: Array[String] = _png_names(portrait_source_dir)
		var imported_portraits: Array[String] = _png_names(ProjectSettings.globalize_path("%s/%s" % [PORTRAIT_ROOT, slug]))
		var missing_portraits: Array[String] = _difference(source_portraits, imported_portraits)
		source_state_total += source_keys.size()
		imported_state_total += imported_keys.size()
		source_portrait_total += source_portraits.size()
		imported_portrait_total += imported_portraits.size()
		var entry: Dictionary = {
			"imported_portrait_count": imported_portraits.size(),
			"imported_state_count": imported_keys.size(),
			"slug": slug,
			"source_portrait_count": source_portraits.size(),
			"source_state_count": source_keys.size(),
			"substitutions": substitutions,
		}
		entries.append(entry)
		if not missing_states.is_empty() or not extra_states.is_empty():
			state_gap_entries.append({
				"extra_states": extra_states,
				"missing_states": missing_states,
				"slug": slug,
			})
		if not missing_portraits.is_empty():
			portrait_gap_entries.append({
				"missing_portraits": missing_portraits,
				"slug": slug,
			})
	return {
		"portrait_gaps": portrait_gap_entries,
		"state_gaps": state_gap_entries,
		"per_species": entries,
		"summary": {
			"imported_portrait_total": imported_portrait_total,
			"imported_state_total": imported_state_total,
			"source_portrait_total": source_portrait_total,
			"source_state_total": source_state_total,
			"species_total": entries.size(),
			"species_with_portrait_gaps": portrait_gap_entries.size(),
			"species_with_state_gaps": state_gap_entries.size(),
			"species_with_substitutions": substitution_count,
		},
	}


func _build_category_section(raw_asset_root: String, visual_manifest: Dictionary) -> Dictionary:
	var categories: Dictionary = {}
	var manifest_categories: Dictionary = visual_manifest.get("categories", {})
	for category in VFX_CATEGORIES:
		var source_count: int = _count_files_recursive("%s/%s" % [raw_asset_root, category])
		var copied_count: int = _count_files_recursive(ProjectSettings.globalize_path("%s/%s" % [RAW_ASSET_COPY_ROOT, category]))
		var manifest_count: int = int((manifest_categories.get(category, {}) as Dictionary).get("actual_count", 0))
		categories[category] = {
			"copied_file_count": copied_count,
			"manifest_entry_count": manifest_count,
			"source_file_count": source_count,
		}
	return categories


func _build_icon_mapping_section() -> Dictionary:
	var item_icon_refs: Dictionary = {}
	for file_name in _list_files(ProjectSettings.globalize_path(GENERATED_ITEMS_DIR)):
		if not file_name.ends_with(".tres"):
			continue
		var text: String = _read_text("%s/%s" % [GENERATED_ITEMS_DIR, file_name])
		var marker: String = "icon_path = \""
		var start: int = text.find(marker)
		if start < 0:
			continue
		start += marker.length()
		var stop: int = text.find("\"", start)
		if stop < 0:
			continue
		var icon_path: String = text.substr(start, stop - start)
		if not icon_path.is_empty():
			item_icon_refs[icon_path.get_file()] = true
	var status_icon_refs: Dictionary = {}
	for file_name in _list_files(ProjectSettings.globalize_path(GENERATED_STATUSES_DIR)):
		if not file_name.ends_with(".tres"):
			continue
		var status: PokemonStatusResource = load("%s/%s" % [GENERATED_STATUSES_DIR, file_name]) as PokemonStatusResource
		if status != null and not status.icon_path.is_empty():
			status_icon_refs[status.icon_path.get_file()] = true
	var unmapped_item_icons: Array[String] = []
	for file_name in _list_files(ProjectSettings.globalize_path("%s/Item" % RAW_ASSET_COPY_ROOT)):
		if file_name.ends_with(".png") and not item_icon_refs.has(file_name):
			unmapped_item_icons.append(file_name)
	unmapped_item_icons.sort()
	var unmapped_status_icons: Array[String] = []
	for file_name in _list_files(ProjectSettings.globalize_path("%s/Icon" % RAW_ASSET_COPY_ROOT)):
		if file_name.ends_with(".png") and not status_icon_refs.has(file_name):
			unmapped_status_icons.append(file_name)
	unmapped_status_icons.sort()
	return {
		"item_icons_referenced": item_icon_refs.size(),
		"status_icons_referenced": status_icon_refs.size(),
		"unmapped_item_icons": unmapped_item_icons,
		"unmapped_status_icons": unmapped_status_icons,
	}


func _find_sprite_source_dir(dex_root: String) -> String:
	for candidate in [dex_root, "%s/0000" % dex_root, "%s/0000/0001" % dex_root]:
		if not DirAccess.dir_exists_absolute(candidate):
			continue
		if not FileAccess.file_exists("%s/AnimData.xml" % candidate):
			continue
		if _has_required_state_sources(candidate):
			return candidate
	return ""


func _has_required_state_sources(candidate: String) -> bool:
	for state in REQUIRED_STATE_SOURCES.keys():
		var found: bool = false
		for name in REQUIRED_STATE_SOURCES[state]:
			if FileAccess.file_exists("%s/%s" % [candidate, String(name)]):
				found = true
				break
		if not found and String(state) == "idle":
			found = FileAccess.file_exists("%s/Walk-Anim.png" % candidate)
		if not found:
			return false
	return true


func _find_portrait_source_dir(dex_root: String) -> String:
	for candidate in [dex_root, "%s/0000" % dex_root, "%s/0000/0001" % dex_root]:
		if FileAccess.file_exists("%s/Normal.png" % candidate):
			return candidate
	return ""


func _source_state_keys(source_dir: String) -> Array[String]:
	var keys: Dictionary = {}
	if source_dir.is_empty():
		return []
	for file_name in _list_files(source_dir):
		if not file_name.ends_with(ANIM_SUFFIX):
			continue
		var source_name: String = file_name.substr(0, file_name.length() - ANIM_SUFFIX.length())
		keys[_runtime_state_key(source_name)] = true
	var out: Array[String] = []
	for key in keys.keys():
		out.append(String(key))
	out.sort()
	return out


func _imported_state_keys(res_dir: String) -> Array[String]:
	var out: Array[String] = []
	for file_name in _list_files(ProjectSettings.globalize_path(res_dir)):
		if file_name.ends_with(".png"):
			out.append(file_name.get_basename())
	out.sort()
	return out


func _runtime_state_key(source_name: String) -> String:
	if SOURCE_STATE_TO_RUNTIME_KEY.has(source_name):
		return String(SOURCE_STATE_TO_RUNTIME_KEY[source_name])
	var regex: RegEx = RegEx.new()
	regex.compile("([a-z0-9])([A-Z])")
	var with_separators: String = regex.sub(source_name, "$1_$2", true)
	var cleaner: RegEx = RegEx.new()
	cleaner.compile("[^A-Za-z0-9]+")
	var normalized: String = cleaner.sub(with_separators, "_", true).lstrip("_").rstrip("_").to_lower()
	return normalized if not normalized.is_empty() else source_name.to_lower()


func _png_names(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	if dir_path.is_empty():
		return out
	for file_name in _list_files(dir_path):
		if file_name.ends_with(".png"):
			out.append(file_name)
	out.sort()
	return out


func _count_files_recursive(dir_path: String) -> int:
	var count: int = 0
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return 0
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue
		if dir.current_is_dir():
			count += _count_files_recursive("%s/%s" % [dir_path, name])
		elif not name.ends_with(".import") and not name.ends_with(".gdignore"):
			count += 1
	dir.list_dir_end()
	return count


func _list_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name.is_empty():
			break
		if name.begins_with(".") or dir.current_is_dir():
			continue
		out.append(name)
	dir.list_dir_end()
	out.sort()
	return out


func _difference(left: Array[String], right: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for value in left:
		if not right.has(value):
			out.append(value)
	out.sort()
	return out


func _resolve_source_root(env_key: String, fallback: String) -> String:
	var configured: String = OS.get_environment(env_key)
	if not configured.is_empty():
		return configured
	return ProjectSettings.globalize_path(fallback)


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(_read_text(path))
	return parsed if parsed is Dictionary else {}


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _write_text(path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("smoke: failed to open %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("smoke: ok - %s" % message)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % message)
