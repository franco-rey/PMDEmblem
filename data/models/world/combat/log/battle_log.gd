class_name BattleLog
extends RefCounted
## Lightweight battle event stream used by smoke tests and debug output.

signal event_appended(event: Dictionary)

var events: Array[Dictionary] = []


func append(event: Dictionary) -> void:
	events.append(event)
	event_appended.emit(event)


func clear() -> void:
	events.clear()
