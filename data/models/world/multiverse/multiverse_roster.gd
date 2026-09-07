class_name MultiverseRoster
extends RefCounted

const OVERRIDE_INSTANCE_DIR: String = "res://data/models/pokemon/overrides/instances/"
const GENERATED_INSTANCE_DIR: String = "res://data/models/pokemon/generated/instances/"
const SIGNATURE_TRAVELLERS: Dictionary = {
	"0483_dialga": "roar_of_time",
	"0484_palkia": "spacial_rend",
	"0487_giratina": "shadow_force",
	"0720_hoopa": "hyperspace_hole",
}
const LEGENDARY_SLUGS: Array[String] = [
	"0483_dialga",
	"0484_palkia",
	"0487_giratina",
	"0720_hoopa",
	"0251_celebi",
]

static var _travellers: Dictionary = {}
static var _travellers_built: bool = false


static func travellers() -> Dictionary:
	if _travellers_built:
		return _travellers
	_travellers_built = true
	var out: Dictionary = {}
	var signature_slugs: Array[String] = []
	for slug in SIGNATURE_TRAVELLERS.keys():
		signature_slugs.append(String(slug))
	signature_slugs.sort()
	for slug in signature_slugs:
		if _instance_path(slug).is_empty():
			continue
		out[slug] = String(SIGNATURE_TRAVELLERS[slug])
	var move_ids: Array[String] = []
	for move_id in CustomMoves.learnsets().keys():
		move_ids.append(String(move_id))
	move_ids.sort()
	for move_id in move_ids:
		if not MultiverseController.TRAVEL_MOVES.has(move_id):
			continue
		var slugs: Array = CustomMoves.learnsets()[move_id]
		for entry in slugs:
			var slug: String = String(entry)
			if out.has(slug) or _instance_path(slug).is_empty():
				continue
			out[slug] = move_id
	_travellers = out
	return _travellers


static func is_traveller(slug: String) -> bool:
	return travellers().has(slug)


static func is_legendary(slug: String) -> bool:
	return LEGENDARY_SLUGS.has(slug)


static func travel_move_for(slug: String) -> String:
	return String(travellers().get(slug, ""))


static func legendary_slugs() -> Array[String]:
	return _group_slugs(true)


static func common_slugs() -> Array[String]:
	return _group_slugs(false)


static func instance_path(slug: String) -> String:
	return _instance_path(slug)


static func slug_for_instance(instance: PokemonInstanceResource) -> String:
	if instance == null or instance.species == null:
		return ""
	return String(instance.species.species_id)


static func paths_satisfy(paths: Array[String]) -> bool:
	return _group_in_paths(paths, true) and (paths.size() < 2 or _group_in_paths(paths, false))


static func ensure_traveller_paths(paths: Array[String], seed: int) -> Array[String]:
	var out: Array[String] = paths.duplicate()
	if out.is_empty():
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	out = _ensure_group_in_paths(out, true, rng)
	if out.size() >= 2:
		out = _ensure_group_in_paths(out, false, rng)
	return out


static func required_slugs(team_size: int, taken: Array[String], seed: int) -> Array[String]:
	var out: Array[String] = []
	if team_size <= 0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var used: Array[String] = taken.duplicate()
	if not _group_in_slugs(used, true):
		var pick: String = _pick_slug(legendary_slugs(), used, rng)
		if not pick.is_empty():
			out.append(pick)
			used.append(pick)
	if team_size >= 2 and not _group_in_slugs(used, false):
		var pick_common: String = _pick_slug(common_slugs(), used, rng)
		if not pick_common.is_empty():
			out.append(pick_common)
	return out


static func ensure_traveller_moves(team: Array[PokemonInstanceResource]) -> int:
	var changed: int = 0
	for instance in team:
		if instance == null:
			continue
		var slug: String = slug_for_instance(instance)
		if not is_traveller(slug) or _has_travel_move(instance):
			continue
		if _grant_travel_move(instance, travel_move_for(slug)):
			changed += 1
	return changed


static func team_satisfies(team: Array[PokemonInstanceResource]) -> bool:
	var legendary: bool = false
	var common: bool = false
	for instance in team:
		if instance == null or not _has_travel_move(instance):
			continue
		var slug: String = slug_for_instance(instance)
		if not is_traveller(slug):
			continue
		if is_legendary(slug):
			legendary = true
		else:
			common = true
	return legendary and (team.size() < 2 or common)


static func _group_slugs(legendary: bool) -> Array[String]:
	var out: Array[String] = []
	for slug in travellers().keys():
		if is_legendary(String(slug)) == legendary:
			out.append(String(slug))
	out.sort()
	return out


static func _group_in_paths(paths: Array[String], legendary: bool) -> bool:
	for path in paths:
		var slug: String = PortraitLibrary.slug_for_path(path)
		if is_traveller(slug) and is_legendary(slug) == legendary:
			return true
	return false


static func _group_in_slugs(slugs: Array[String], legendary: bool) -> bool:
	for slug in slugs:
		if is_traveller(slug) and is_legendary(slug) == legendary:
			return true
	return false


static func _ensure_group_in_paths(paths: Array[String], legendary: bool, rng: RandomNumberGenerator) -> Array[String]:
	if _group_in_paths(paths, legendary):
		return paths
	var taken: Array[String] = []
	for path in paths:
		taken.append(PortraitLibrary.slug_for_path(path))
	var slug: String = _pick_slug(_group_slugs(legendary), taken, rng)
	if slug.is_empty():
		return paths
	var replace_at: int = _replaceable_index(paths)
	if replace_at < 0:
		return paths
	var out: Array[String] = paths.duplicate()
	out[replace_at] = _instance_path(slug)
	return out


static func _pick_slug(pool: Array[String], taken: Array[String], rng: RandomNumberGenerator) -> String:
	var free: Array[String] = []
	for slug in pool:
		if not taken.has(slug):
			free.append(slug)
	if free.is_empty():
		return pool[0] if not pool.is_empty() else ""
	return free[rng.randi_range(0, free.size() - 1)]


static func _replaceable_index(paths: Array[String]) -> int:
	for i in range(paths.size() - 1, -1, -1):
		if not is_traveller(PortraitLibrary.slug_for_path(paths[i])):
			return i
	return paths.size() - 1


static func _instance_path(slug: String) -> String:
	var override_path: String = "%s%s.tres" % [OVERRIDE_INSTANCE_DIR, slug]
	if ResourceLoader.exists(override_path):
		return override_path
	var generated: String = "%s%s.tres" % [GENERATED_INSTANCE_DIR, slug]
	return generated if ResourceLoader.exists(generated) else ""


static func _has_travel_move(instance: PokemonInstanceResource) -> bool:
	for move in instance.move_slots:
		if move != null and MultiverseController.TRAVEL_MOVES.has(move.move_id):
			return true
	return false


static func _grant_travel_move(instance: PokemonInstanceResource, move_id: String) -> bool:
	if move_id.is_empty():
		return false
	var move: PokemonMoveResource = CustomMoves.load_move(move_id)
	if move == null:
		return false
	var slots: Array[PokemonMoveResource] = instance.move_slots.duplicate()
	if slots.is_empty():
		slots.append(move)
	else:
		var chosen: int = -1
		for i in range(slots.size() - 1, -1, -1):
			var candidate: Array[PokemonMoveResource] = slots.duplicate()
			candidate[i] = move
			if SkirmishMoveLoadout.has_resolving_attack(candidate):
				chosen = i
				break
		if chosen < 0:
			chosen = slots.size() - 1
		slots[chosen] = move
	instance.move_slots = slots
	var pp: Array[int] = []
	for entry in slots:
		pp.append(entry.pp if entry != null else 0)
	instance.pp_state = pp
	if not instance.known_move_ids.has(move_id):
		instance.known_move_ids.append(move_id)
	return true
