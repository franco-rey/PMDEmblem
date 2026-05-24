class_name SkirmishRosterProvider
extends RefCounted
## Data-driven roster listing for skirmish setup screens.
##
## External sprite repositories are import sources only. Runtime callers only
## receive `res://` paths owned by this project.

const PORTRAIT_ROOT: String = "res://assets/textures/pokemon/portraits/"
const FALLBACK_ICON_PATH: String = "res://assets/textures/ui/icons/icon.png"


static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for path in CustomSkirmishBuilder.roster_paths():
		var instance: PokemonInstanceResource = load(path) as PokemonInstanceResource
		if instance == null:
			continue
		var species: PokemonSpeciesResource = instance.species
		var form: PokemonFormResource = instance.resolved_form()
		var slug: String = species.species_id if species != null and not species.species_id.is_empty() else path.get_file().get_basename()
		var portrait_path: String = _portrait_path_for(form, slug)
		out.append({
			"path": path,
			"slug": slug,
			"label": instance.display_name(),
			"dex_number": species.dex_number if species != null else _dex_from_slug(slug),
			"types": form.types() if form != null else [],
			"portrait_path": portrait_path,
			"has_portrait": not portrait_path.is_empty() and portrait_path != FALLBACK_ICON_PATH,
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
