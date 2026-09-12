extends SmokeCase

const MANIFEST_PATH: String = "res://data/models/pokemon/generated/manifests/pokemon_import_manifest.json"
const GENERATED_INTRINSICS_DIR: String = "res://data/models/pokemon/generated/intrinsics"
const GENERATED_FORMS_DIR: String = "res://data/models/pokemon/generated/forms"
const REPORT_PATH: String = "res://data/models/pokemon/import_reports/intrinsic_coverage_report.json"
const EXPECTED_INTRINSICS: int = 208
const EXPECTED_SPECIES: int = 686
const IMPLEMENTED_OUTSIDE_SUPPORTED_LIST: Array[String] = []


func _init() -> void:
	var manifest: Dictionary = _load_json(MANIFEST_PATH)
	_assert_true(not manifest.is_empty(), "import manifest loads")
	var slugs: Array[String] = _intrinsic_slugs()
	_assert_true(slugs.size() == EXPECTED_INTRINSICS, "found %d generated intrinsics (expected %d)" % [slugs.size(), EXPECTED_INTRINSICS])
	var implemented: Dictionary = {}
	for slug in BattleIntrinsicService.SUPPORTED_INTRINSICS:
		implemented[String(slug)] = true
	for slug in IMPLEMENTED_OUTSIDE_SUPPORTED_LIST:
		implemented[slug] = true
	var frequency: Dictionary = {}
	var missing_resources: Array[String] = []
	var species_counted: int = 0
	for raw_entry in manifest.get("species", []):
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var species_slug: String = String(entry.get("slug", ""))
		var form_index: int = int(entry.get("default_form_index", 0))
		var form: PokemonFormResource = load("%s/%s__%d.tres" % [GENERATED_FORMS_DIR, species_slug, form_index]) as PokemonFormResource
		if form == null:
			failures += 1
			push_error("smoke: FAIL - default form missing for %s" % species_slug)
			continue
		species_counted += 1
		var seen: Dictionary = {}
		for slot_slug in [form.intrinsic1, form.intrinsic2, form.intrinsic3]:
			var key: String = String(slot_slug)
			if key.is_empty() or key == "none" or seen.has(key):
				continue
			seen[key] = true
			frequency[key] = int(frequency.get(key, 0)) + 1
			if not slugs.has(key) and not missing_resources.has(key):
				missing_resources.append(key)
	missing_resources.sort()
	_assert_true(species_counted == EXPECTED_SPECIES, "default forms load for %d species (expected %d)" % [species_counted, EXPECTED_SPECIES])
	_assert_true(missing_resources.is_empty(), "every roster intrinsic has a generated resource")
	for slug in missing_resources:
		push_error("smoke: missing intrinsic resource - %s" % slug)
	var entries: Array[Dictionary] = []
	var implemented_count: int = 0
	var implemented_carrier_species: int = 0
	for slug in slugs:
		var is_implemented: bool = implemented.has(slug)
		if is_implemented:
			implemented_count += 1
			implemented_carrier_species += int(frequency.get(slug, 0))
		entries.append({
			"implemented": is_implemented,
			"roster_frequency": int(frequency.get(slug, 0)),
			"slug": slug,
		})
	var ranked: Array[Dictionary] = entries.duplicate()
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["roster_frequency"]) != int(b["roster_frequency"]):
			return int(a["roster_frequency"]) > int(b["roster_frequency"])
		return String(a["slug"]) < String(b["slug"])
	)
	var ranked_slugs: Array[String] = []
	for entry in ranked:
		ranked_slugs.append(String(entry["slug"]))
	var payload: Dictionary = {
		"frequency_ranked_slugs": ranked_slugs,
		"intrinsics": entries,
		"schema_version": 1,
		"source": "smoke_test_intrinsic_coverage",
		"summary": {
			"implemented_count": implemented_count,
			"intrinsic_total": entries.size(),
			"report_only_count": entries.size() - implemented_count,
			"species_total": species_counted,
		},
	}
	_assert_true(_write_text(REPORT_PATH, JSON.stringify(payload, "\t") + "\n"), "intrinsic coverage report written")
	if failures > 0:
		push_error("smoke: intrinsic_coverage failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: intrinsic_coverage clean - intrinsics=%d implemented=%d report_only=%d" % [
		entries.size(),
		implemented_count,
		entries.size() - implemented_count,
	])
	for entry in ranked.slice(0, 15):
		print("smoke: frequency - %s x%d%s" % [
			String(entry["slug"]),
			int(entry["roster_frequency"]),
			" (implemented)" if bool(entry["implemented"]) else "",
		])
	quit(0)


func _intrinsic_slugs() -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(GENERATED_INTRINSICS_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name.is_empty():
			break
		if not dir.current_is_dir() and name.ends_with(".tres"):
			out.append(name.get_basename())
	dir.list_dir_end()
	out.sort()
	return out


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _write_text(path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("smoke: failed to open %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true
