class_name SkirmishRosterProvider
extends RefCounted

const PORTRAIT_ROOT: String = "res://assets/textures/pokemon/portraits/"
const FALLBACK_ICON_PATH: String = "res://assets/textures/ui/icons/icon.png"
const IMPORT_MANIFEST_PATH: String = "res://data/models/pokemon/generated/manifests/pokemon_import_manifest.json"


static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var manifest_entries: Dictionary = _manifest_entries_by_slug()
	for path in CustomSkirmishBuilder.roster_paths():
		var instance: PokemonInstanceResource = load(path) as PokemonInstanceResource
		if instance == null:
			continue
		var species: PokemonSpeciesResource = instance.species
		var form: PokemonFormResource = instance.resolved_form()
		var slug: String = species.species_id if species != null and not species.species_id.is_empty() else path.get_file().get_basename()
		var manifest_entry: Dictionary = manifest_entries.get(slug, {})
		var portrait_path: String = _portrait_path_for(form, slug)
		var complete_sprite_set: bool = form != null and form.sprite_set != null and form.sprite_set.is_complete()
		var usable_move: bool = _has_usable_move(instance)
		var battle_ready: bool = complete_sprite_set and usable_move
		var manifest_warnings: Array = manifest_entry.get("warnings", []) if manifest_entry.has("warnings") else []
		var warnings: Array[String] = []
		for warning in manifest_warnings:
			warnings.append(String(warning))
		if form != null and form.sprite_set != null:
			for warning in form.sprite_set.validation_warnings:
				if not warnings.has(warning):
					warnings.append(warning)
		out.append({
			"path": path,
			"slug": slug,
			"label": instance.display_name(),
			"dex_number": species.dex_number if species != null else _dex_from_slug(slug),
			"generation": int(manifest_entry.get("generation", _generation_from_dex(species.dex_number if species != null else _dex_from_slug(slug)))),
			"types": form.types() if form != null else [],
			"portrait_path": portrait_path,
			"has_portrait": not portrait_path.is_empty() and portrait_path != FALLBACK_ICON_PATH,
			"battle_ready": battle_ready and String(manifest_entry.get("status", "battle_ready")) == "battle_ready",
			"status": String(manifest_entry.get("status", "battle_ready" if battle_ready else "metadata_only")),
			"warnings": warnings,
			"disabled_reason": String(manifest_entry.get("disabled_reason", "")),
			"has_complete_sprite_set": complete_sprite_set,
			"has_usable_move": usable_move,
			"instance": instance,
		})
	return out


static func label_for_path(path: String) -> String:
	var instance: PokemonInstanceResource = load(path) as PokemonInstanceResource
	if instance != null:
		return instance.display_name()
	return path.get_file().get_basename().capitalize()


static func texture_for_entry(entry: Dictionary) -> Texture2D:
	return texture_for_path(String(entry.get("portrait_path", "")))


static func texture_for_path(path: String) -> Texture2D:
	if path.is_empty():
		path = FALLBACK_ICON_PATH
	if ResourceLoader.exists(path):
		var texture: Texture2D = load(path) as Texture2D
		if texture != null:
			return texture

	var image := Image.new()
	var err: Error = image.load(path)
	if err != OK:
		if path != FALLBACK_ICON_PATH:
			return texture_for_path(FALLBACK_ICON_PATH)
		return null
	return ImageTexture.create_from_image(image)


static func _portrait_path_for(form: PokemonFormResource, slug: String) -> String:
	if form != null and form.sprite_set != null:
		for path in form.sprite_set.portrait_paths:
			if _res_file_exists(path):
				return path
	var fallback: String = "%s%s/Normal.png" % [PORTRAIT_ROOT, slug]
	if _res_file_exists(fallback):
		return fallback
	if _res_file_exists(FALLBACK_ICON_PATH):
		return FALLBACK_ICON_PATH
	return ""


static func _res_file_exists(path: String) -> bool:
	return not path.is_empty() and FileAccess.file_exists(path)


static func _dex_from_slug(slug: String) -> int:
	var prefix: String = slug.split("_")[0] if slug.contains("_") else ""
	return int(prefix) if prefix.is_valid_int() else 0


static func _has_usable_move(instance: PokemonInstanceResource) -> bool:
	if instance == null:
		return false
	for move in instance.move_slots:
		if move != null:
			return true
	return false


static func _manifest_entries_by_slug() -> Dictionary:
	var out: Dictionary = {}
	if not FileAccess.file_exists(IMPORT_MANIFEST_PATH):
		return out
	var file: FileAccess = FileAccess.open(IMPORT_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return out
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return out
	var species_entries: Variant = (parsed as Dictionary).get("species", [])
	if not (species_entries is Array):
		return out
	for raw_entry in species_entries:
		if raw_entry is Dictionary:
			var entry: Dictionary = raw_entry
			var slug: String = String(entry.get("slug", ""))
			if not slug.is_empty():
				out[slug] = entry
	return out


static func _generation_from_dex(dex_number: int) -> int:
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
