class_name BattleItemCatalog
extends RefCounted

const GENERATED_ITEMS_DIR: String = "res://data/models/pokemon/generated/items/"
const APPLICABLE_CATEGORIES: Array[String] = ["held", "berry"]
const PMD_ONLY_HELD: Array[String] = ["held_blank_plate", "held_cover_band", "held_defense_scarf", "held_fickle_lens", "held_friend_bow", "held_goggle_specs", "held_golden_mask", "held_heal_ribbon", "held_mobile_scarf", "held_pass_scarf", "held_pierce_band", "held_pink_bow", "held_power_band", "held_reunion_cape", "held_special_band", "held_trap_scarf", "held_twist_band", "held_warp_scarf", "held_weather_rock", "held_x_ray_specs", "held_zinc_band", "held_shed_shell"]
const NO_BATTLE_EFFECT: Array[String] = ["berry_hondew", "berry_kelpsy", "berry_qualot", "berry_tamato"]
const UNRELEASED_IMPLEMENTED: Array[String] = ["berry_cheri", "berry_chesto", "berry_pecha", "berry_rawst", "berry_aspear", "berry_persim", "berry_kee", "berry_maranga", "berry_custap"]
const APPLICABLE_STATES: Array[String] = [
	"PMDC.Dungeon.HeldState, PMDC",
	"PMDC.Dungeon.EquipState, PMDC",
	"PMDC.Dungeon.BerryState, PMDC",
]
const EXCLUDED_STATES: Array[String] = [
	"RogueEssence.Dungeon.MaterialState, RogueEssence",
	"PMDC.Dungeon.EvoState, PMDC",
	"PMDC.Dungeon.RecruitState, PMDC",
]
const USAGE_NONE: int = 0
const USAGE_USE: int = 1
const USAGE_USE_OTHER: int = 2
const USAGE_THROW: int = 3
const USAGE_EAT: int = 4
const USAGE_DRINK: int = 5
const USAGE_LEARN: int = 6
const USAGE_BOX: int = 7
const USAGE_TREASURE: int = 8
const EDIBLE_STATE: String = "PMDC.Dungeon.EdibleState, PMDC"
const AMMO_STATE: String = "PMDC.Dungeon.AmmoState, PMDC"
const RECRUIT_STATE: String = "PMDC.Dungeon.RecruitState, PMDC"
const HELD_STATE: String = "PMDC.Dungeon.HeldState, PMDC"
const EQUIP_STATE: String = "PMDC.Dungeon.EquipState, PMDC"

static var _cached_entries: Array[Dictionary] = []
static var _cached_by_id: Dictionary = {}


static func entries() -> Array[Dictionary]:
	if not _cached_entries.is_empty():
		return _cached_entries
	var presentation: ActionPresentationCatalog = ActionPresentationCatalog.shared()
	var paths: Array[String] = []
	for folder in [GENERATED_ITEMS_DIR, PokemonItemService.CUSTOM_ITEMS_DIR]:
		for filename in ResourceDir.file_names(folder):
			paths.append("%s%s" % [folder, filename])
	paths.sort_custom(func(a: String, b: String) -> bool: return a.get_file() < b.get_file())
	for path in paths:
		var item: PokemonItemResource = load(path) as PokemonItemResource
		if item == null or (not item.released and not UNRELEASED_IMPLEMENTED.has(item.item_id)) or not is_applicable(item, presentation):
			continue
		var entry: Dictionary = describe(item)
		_cached_entries.append(entry)
		_cached_by_id[item.item_id] = entry
	return _cached_entries


static func entry_for(item_id: String) -> Dictionary:
	if item_id.is_empty():
		return {}
	if _cached_by_id.is_empty():
		entries()
	var entry: Variant = _cached_by_id.get(item_id, null)
	if entry is Dictionary:
		return entry
	var item: PokemonItemResource = PokemonItemService.load_item(item_id)
	return describe(item) if item != null else {}


static func is_selectable(item_id: String) -> bool:
	if item_id.is_empty():
		return false
	if _cached_by_id.is_empty():
		entries()
	return _cached_by_id.has(item_id)


static func is_applicable(item: PokemonItemResource, presentation: ActionPresentationCatalog = null) -> bool:
	if item == null:
		return false
	for state in item.item_states:
		if EXCLUDED_STATES.has(String(state)):
			return false
	if not APPLICABLE_CATEGORIES.has(item.category) or PMD_ONLY_HELD.has(item.item_id) or NO_BATTLE_EFFECT.has(item.item_id):
		return false
	if presentation != null and presentation.loaded and presentation.has_item(item.item_id):
		return true
	for state in item.item_states:
		if APPLICABLE_STATES.has(String(state)):
			return true
	return true


static func describe(item: PokemonItemResource) -> Dictionary:
	if item == null:
		return {}
	var edible: bool = item.item_states.has(EDIBLE_STATE)
	var usable: bool = item.usage_type in [USAGE_USE, USAGE_USE_OTHER, USAGE_EAT, USAGE_DRINK] and (not item.effect_records.is_empty() or not item.unsupported_effect_tags.is_empty() or _has_presentation_use(item))
	var passive: bool = item.item_states.has(HELD_STATE) or item.item_states.has(EQUIP_STATE) or not item.passive_effect_records.is_empty()
	return {
		"item_id": item.item_id,
		"label": item.display_name(),
		"category": item.category,
		"usage_type": item.usage_type,
		"can_hold": true,
		"can_use": usable,
		"can_throw": true,
		"passive": passive,
		"edible": edible,
		"ammo": item.item_states.has(AMMO_STATE),
		"catchable": not item.item_states.has(RECRUIT_STATE),
		"use_verb": _use_verb(item),
		"icon_path": item.icon_path,
		"sprite_key": item.sprite_key,
	}


static func _use_verb(item: PokemonItemResource) -> String:
	match item.usage_type:
		USAGE_EAT:
			return "Eat"
		USAGE_DRINK:
			return "Drink"
		_:
			return "Use"


static func _has_presentation_use(item: PokemonItemResource) -> bool:
	var presentation: ActionPresentationCatalog = ActionPresentationCatalog.shared()
	if not presentation.loaded:
		return false
	var entry: Dictionary = presentation.item(item.item_id)
	if entry.is_empty():
		return false
	var events: Variant = entry.get("use_events", {})
	return events is Dictionary and not (events as Dictionary).is_empty()


static func labels_for_picker() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in entries():
		out.append({"item_id": entry["item_id"], "label": "%s (%s)" % [entry["label"], String(entry["category"]).capitalize()]})
	return out
