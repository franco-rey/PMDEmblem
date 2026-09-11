class_name NetLink
extends RefCounted

signal received(message: Dictionary)
signal closed(reason: String)
signal opened

var open: bool = false


func poll(_delta: float = 0.0) -> void:
	pass


func send(_message: Dictionary) -> bool:
	return false


func close(_reason: String = "closed") -> void:
	open = false


func is_open() -> bool:
	return open


func round_trip_ms() -> int:
	return -1


func describe() -> String:
	return "link"
