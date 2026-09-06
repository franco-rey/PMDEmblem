class_name BoardSnapshot
extends RefCounted

var timeline: int = 0
var turn: int = 1
var units: Array[Dictionary] = []
var conditions: Dictionary = {}
var hazards: Dictionary = {}
var landed: Array[Dictionary] = []
var scheduler: Dictionary = {}
var battle_rng_state: int = 0
var notation_turn: int = 0
var mid_round: bool = false


func duplicate_board() -> BoardSnapshot:
	var copy := BoardSnapshot.new()
	copy.timeline = timeline
	copy.turn = turn
	for unit in units:
		copy.units.append(unit.duplicate(true))
	copy.conditions = conditions.duplicate(true)
	copy.hazards = hazards.duplicate(true)
	for record in landed:
		copy.landed.append(record.duplicate(true))
	copy.scheduler = scheduler.duplicate(true)
	copy.battle_rng_state = battle_rng_state
	copy.notation_turn = notation_turn
	copy.mid_round = mid_round
	return copy


func coords() -> Vector2i:
	return Vector2i(timeline, turn)


func unit(id: String) -> Dictionary:
	for entry in units:
		if String(entry.get("id", "")) == id:
			return entry
	return {}


func has_unit(id: String) -> bool:
	return not unit(id).is_empty()


func standing(team: int) -> int:
	var count: int = 0
	for entry in units:
		if int(entry.get("team", -1)) == team and bool(entry.get("alive", false)):
			count += 1
	return count


func unit_ids() -> Array[String]:
	var out: Array[String] = []
	for entry in units:
		out.append(String(entry.get("id", "")))
	return out


func remove_unit(id: String) -> void:
	for i in range(units.size()):
		if String(units[i].get("id", "")) == id:
			units.remove_at(i)
			break
	var queue: Array = scheduler.get("queue", [])
	queue.erase(id)
	scheduler["queue"] = queue
	var order: Array = scheduler.get("order", [])
	order.erase(id)
	scheduler["order"] = order


func add_unit(entry: Dictionary) -> void:
	units.append(entry)
	var order: Array = scheduler.get("order", [])
	order.append(String(entry.get("id", "")))
	scheduler["order"] = order
