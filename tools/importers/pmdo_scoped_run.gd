extends SceneTree

const IMPORT_MANIFEST_PATH: String = "res://data/models/pokemon/generated/manifests/pokemon_import_manifest.json"


func _init() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var slugs: Array[String] = _resolve_slugs(args)
	if slugs.is_empty():
		push_error("pmdo_scoped_run: pass --only=<slug,slug> and/or --dex-range=<a-b>")
		quit(2)
		return
	print_rich("[color=cyan]PMDOImporter scoped sprite-set run for %d entries: %s[/color]" % [slugs.size(), ", ".join(slugs)])
	var importer := PMDOImporter.new()
	var result: Dictionary = importer.run_scoped_sprite_sets(slugs)
	var selected: Array = result.get("selected", [])
	var missing: Array = result.get("missing", [])
	var errors: Array = result.get("errors", [])
	var warnings: Array = result.get("warnings", [])
	print("scoped import: manifest_entries=%d selected=%d missing=%d sprite_sets=%d errors=%d warnings=%d" % [
		int(result.get("manifest_entry_count", 0)),
		selected.size(),
		missing.size(),
		(result.get("sprite_sets", {}) as Dictionary).size(),
		errors.size(),
		warnings.size(),
	])
	for warning in warnings:
		print("scoped import warning: %s" % String(warning))
	for error in errors:
		push_error("scoped import error: %s" % String(error))
	for slug in missing:
		push_error("scoped import: manifest has no entry for %s" % String(slug))
	quit(1 if not errors.is_empty() or not missing.is_empty() else 0)


func _parse_args(raw: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for arg in raw:
		var text: String = String(arg)
		if not text.begins_with("--"):
			continue
		var body: String = text.substr(2)
		var eq: int = body.find("=")
		if eq < 0:
			out[body] = "true"
		else:
			out[body.substr(0, eq)] = body.substr(eq + 1)
	return out


func _resolve_slugs(args: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for part in String(args.get("only", "")).split(","):
		var slug: String = part.strip_edges()
		if not slug.is_empty() and not out.has(slug):
			out.append(slug)
	var dex_range: String = String(args.get("dex-range", "")).strip_edges()
	if not dex_range.is_empty():
		var bounds: PackedStringArray = dex_range.split("-")
		var low: int = int(bounds[0])
		var high: int = int(bounds[bounds.size() - 1])
		for slug in _manifest_slugs_in_range(low, high):
			if not out.has(slug):
				out.append(slug)
	return out


func _manifest_slugs_in_range(low: int, high: int) -> Array[String]:
	var out: Array[String] = []
	if not FileAccess.file_exists(IMPORT_MANIFEST_PATH):
		return out
	var file: FileAccess = FileAccess.open(IMPORT_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return out
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return out
	for entry in (parsed as Dictionary).get("species", []):
		if not (entry is Dictionary):
			continue
		var dex: int = int((entry as Dictionary).get("dex_number", 0))
		if dex >= low and dex <= high:
			out.append(String((entry as Dictionary).get("slug", "")))
	return out
