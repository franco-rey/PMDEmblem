class_name BattleStatsTracker
extends RefCounted

var records: Dictionary = {}
var _log: BattleLog = null


func setup(log: BattleLog) -> void:
	_log = log
	if _log != null and not _log.event_appended.is_connected(_on_event):
		_log.event_appended.connect(_on_event)


func summary(pawn: Variant) -> Dictionary:
	var key: Variant = _key(pawn)
	var stored: Variant = records.get(key, null) if key != null else null
	if stored is Dictionary:
		return stored
	return {"dealt": 0, "taken": 0, "healed": 0, "kos": 0}


func _record(pawn: Variant) -> Dictionary:
	var key: Variant = _key(pawn)
	if key == null:
		return {}
	if not records.has(key):
		records[key] = {"dealt": 0, "taken": 0, "healed": 0, "kos": 0}
	return records[key]


func _key(value: Variant) -> Variant:
	if value is TacticsPawn and is_instance_valid(value):
		return value
	if value is Stats and is_instance_valid(value):
		var parent: Node = (value as Stats).get_parent()
		if parent is TacticsPawn:
			return parent
	return null


func _on_event(event: Dictionary) -> void:
	match String(event.get("kind", "")):
		"damage_dealt":
			var amount: int = int(event.get("amount", 0))
			var attacker: Dictionary = _record(event.get("attacker", null))
			if not attacker.is_empty() and event.get("attacker", null) != event.get("defender", null):
				attacker["dealt"] = int(attacker["dealt"]) + amount
			var defender: Dictionary = _record(event.get("defender", null))
			if not defender.is_empty():
				defender["taken"] = int(defender["taken"]) + amount
		"status_tick":
			var unit: Dictionary = _record(event.get("unit", null))
			if not unit.is_empty():
				unit["taken"] = int(unit["taken"]) + int(event.get("amount", 0))
		"healed":
			var unit: Dictionary = _record(event.get("unit", null))
			if not unit.is_empty():
				unit["healed"] = int(unit["healed"]) + int(event.get("amount", 0))
		"unit_fainted":
			var fainted: Variant = _key(event.get("unit", null))
			var credit: Variant = event.get("attacker", null)
			if credit == null and fainted is TacticsPawn and (fainted as TacticsPawn).stats != null:
				credit = (fainted as TacticsPawn).stats.last_attacker
			var scorer: Dictionary = _record(credit)
			if not scorer.is_empty() and _key(credit) != fainted:
				scorer["kos"] = int(scorer["kos"]) + 1
