extends SceneTree

const GENERATED_ITEMS_DIR: String = "res://data/models/pokemon/generated/items"
const REPORT_PATH: String = "res://data/models/pokemon/import_reports/item_coverage_report.json"
const EXPECTED_ITEMS: int = 2452
const BELLY_EVENT: String = "RestoreBellyEvent"
const FUNCTIONAL_EVENTS: Array[String] = [
	"AddContextStateEvent",
	"AdNihiloEvent",
	"ChangeToElementEvent",
	"LevelChangeEvent",
	"MoveLearnEvent",
	"PPTo1Event",
	"RemoveStateStatusBattleEvent",
	"RemoveStatusBattleEvent",
	"RemoveStatusStackBattleEvent",
	"RestoreHPEvent",
	"RestorePPEvent",
	"ReverseStateStatusBattleEvent",
	"StatusBattleEvent",
	"StatusStackBattleEvent",
	"StatusStateBattleEvent",
	"TMEvent",
	"VitaGummiEvent",
	"VitaminEvent",
]
const FUNCTIONAL_CATEGORIES: Array[String] = ["evolution", "held", "tm"]
const RUN_LOOP_CATEGORIES: Array[String] = [
	"category_0",
	"category_8",
	"category_12",
	"category_13",
	"category_16",
	"category_18",
]
const FUTURE_CATEGORIES: Array[String] = ["category_2", "category_3", "orb"]
const CONSUMABLE_CATEGORIES: Array[String] = ["berry", "food", "gummi", "medicine", "seed"]

var failures: int = 0


func _init() -> void:
	var slugs: Array[String] = _tres_slugs(GENERATED_ITEMS_DIR)
	_assert_true(slugs.size() == EXPECTED_ITEMS, "found %d generated items (expected %d)" % [slugs.size(), EXPECTED_ITEMS])
	var families: Dictionary = {}
	var item_total: int = 0
	for slug in slugs:
		var item: PokemonItemResource = load("%s/%s.tres" % [GENERATED_ITEMS_DIR, slug]) as PokemonItemResource
		if item == null:
			failures += 1
			push_error("smoke: FAIL - item %s failed to load" % slug)
			continue
		item_total += 1
		var events: Array[String] = _event_names(item.source_effect_tags)
		var family_key: String = "%s|%s" % [item.category, "+".join(events)]
		if not families.has(family_key):
			families[family_key] = {
				"category": item.category,
				"classification": _classify(item.category, events),
				"count": 0,
				"events": events,
				"example_items": [],
			}
		var family: Dictionary = families[family_key]
		family["count"] = int(family["count"]) + 1
		if (family["example_items"] as Array).size() < 3:
			(family["example_items"] as Array).append(item.item_id)
	var family_keys: Array = families.keys()
	family_keys.sort()
	var family_entries: Array[Dictionary] = []
	var classification_item_counts: Dictionary = {}
	var classification_family_counts: Dictionary = {}
	var unclassified_families: Array[String] = []
	for key in family_keys:
		var family: Dictionary = families[key]
		var classification: String = String(family["classification"])
		classification_item_counts[classification] = int(classification_item_counts.get(classification, 0)) + int(family["count"])
		classification_family_counts[classification] = int(classification_family_counts.get(classification, 0)) + 1
		if classification == "unclassified":
			unclassified_families.append(String(key))
		family_entries.append({
			"category": family["category"],
			"classification": classification,
			"count": family["count"],
			"events": family["events"],
			"example_items": family["example_items"],
			"family": key,
		})
	var sorted_item_counts: Dictionary = _sorted_dictionary(classification_item_counts)
	var sorted_family_counts: Dictionary = _sorted_dictionary(classification_family_counts)
	var payload: Dictionary = {
		"families": family_entries,
		"schema_version": 1,
		"source": "smoke_test_item_coverage",
		"summary": {
			"classification_family_counts": sorted_family_counts,
			"classification_item_counts": sorted_item_counts,
			"family_total": family_entries.size(),
			"item_total": item_total,
		},
		"unclassified_worklist": unclassified_families,
	}
	_assert_true(item_total == EXPECTED_ITEMS, "classified %d items (expected %d)" % [item_total, EXPECTED_ITEMS])
	_assert_true(_write_text(REPORT_PATH, JSON.stringify(payload, "\t") + "\n"), "item coverage report written")
	if failures > 0:
		push_error("smoke: item_coverage failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: item_coverage clean - items=%d families=%d item_counts=%s unclassified_families=%d" % [
		item_total,
		family_entries.size(),
		JSON.stringify(sorted_item_counts),
		unclassified_families.size(),
	])
	for key in unclassified_families:
		print("smoke: unclassified family - %s" % key)
	quit(0)


func _classify(category: String, events: Array[String]) -> String:
	if FUNCTIONAL_CATEGORIES.has(category):
		return "functional"
	if RUN_LOOP_CATEGORIES.has(category):
		return "run_loop_deferred"
	if category == "category_15":
		return "run_loop_deferred" if events.is_empty() else "future"
	if FUTURE_CATEGORIES.has(category):
		return "future"
	if category == "material":
		return "run_loop_deferred" if events.is_empty() else "future"
	if CONSUMABLE_CATEGORIES.has(category):
		var non_belly: Array[String] = []
		for event in events:
			if event != BELLY_EVENT:
				non_belly.append(event)
		if non_belly.is_empty():
			if category == "medicine" or category == "gummi":
				return "functional"
			return "run_loop_deferred"
		var all_functional: bool = true
		for event in non_belly:
			if not FUNCTIONAL_EVENTS.has(event):
				all_functional = false
				break
		return "functional" if all_functional else "future"
	return "unclassified"


func _event_names(tags: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for tag in tags:
		var text: String = String(tag)
		var comma: int = text.find(",")
		if comma >= 0:
			text = text.substr(0, comma)
		var short_name: String = text.get_slice(".", text.get_slice_count(".") - 1)
		if short_name.ends_with("Event") and not out.has(short_name):
			out.append(short_name)
	out.sort()
	return out


func _sorted_dictionary(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var keys: Array = source.keys()
	keys.sort()
	for key in keys:
		out[key] = source[key]
	return out


func _tres_slugs(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
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
