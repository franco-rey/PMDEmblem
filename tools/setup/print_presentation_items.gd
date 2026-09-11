extends SceneTree

const PRESENTATION_PREFIXES: Array[String] = ["held_", "berry_", "seed_", "medicine_", "herb_", "boost_", "ammo_"]


func _init() -> void:
	var ids: Array[String] = []
	for folder in [BattleItemCatalog.GENERATED_ITEMS_DIR]:
		for filename in ResourceDir.file_names(folder):
			var item: PokemonItemResource = load("%s%s" % [folder, filename]) as PokemonItemResource
			if item == null:
				continue
			if not item.released and not BattleItemCatalog.UNRELEASED_IMPLEMENTED.has(item.item_id):
				continue
			var wanted: bool = BattleItemCatalog.is_applicable(item, null)
			for prefix in PRESENTATION_PREFIXES:
				if item.item_id.begins_with(prefix):
					wanted = true
			for state in item.item_states:
				if BattleItemCatalog.EXCLUDED_STATES.has(String(state)):
					wanted = false
			if not wanted:
				continue
			if not ids.has(item.item_id):
				ids.append(item.item_id)
	ids.sort()
	print("presentation_items: %s" % ",".join(ids))
	quit(0)
