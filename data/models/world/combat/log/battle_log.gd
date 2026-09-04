class_name BattleLog
extends RefCounted

signal event_appended(event: Dictionary)

var events: Array[Dictionary] = []


func append(event: Dictionary) -> void:
	events.append(event)
	event_appended.emit(event)


func clear() -> void:
	events.clear()
