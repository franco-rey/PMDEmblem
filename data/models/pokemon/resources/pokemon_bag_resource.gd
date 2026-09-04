class_name PokemonBagResource
extends Resource

@export var item_counts: Dictionary = {}


func add_item(item: PokemonItemResource, quantity: int = 1) -> int:
	if item == null or item.item_id.is_empty() or quantity <= 0:
		return count(item)
	var next_count: int = int(item_counts.get(item.item_id, 0)) + quantity
	item_counts[item.item_id] = next_count
	return next_count


func remove_item(item: PokemonItemResource, quantity: int = 1) -> bool:
	if item == null or item.item_id.is_empty() or quantity <= 0:
		return false
	var current: int = int(item_counts.get(item.item_id, 0))
	if current < quantity:
		return false
	var next_count: int = current - quantity
	if next_count <= 0:
		item_counts.erase(item.item_id)
	else:
		item_counts[item.item_id] = next_count
	return true


func count(item: PokemonItemResource) -> int:
	if item == null:
		return 0
	return int(item_counts.get(item.item_id, 0))


func has_item(item: PokemonItemResource, quantity: int = 1) -> bool:
	return count(item) >= quantity


func as_entries() -> Array[Dictionary]:
	var keys: Array = item_counts.keys()
	keys.sort()
	var out: Array[Dictionary] = []
	for key in keys:
		out.append({"item_id": String(key), "quantity": int(item_counts[key])})
	return out
