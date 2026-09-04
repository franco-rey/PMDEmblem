class_name BattleUnit
extends RefCounted

var pawn: TacticsPawn = null
var stats: Stats = null
var team: int = 0
var control_type: int = 0
var insertion_order: int = 0


func _init(_pawn: TacticsPawn = null, _stats: Stats = null, _team: int = 0, _control_type: int = 0, _insertion_order: int = 0) -> void:
	pawn = _pawn
	stats = _stats
	team = _team
	control_type = _control_type
	insertion_order = _insertion_order


func is_alive() -> bool:
	return stats != null and stats.battle_status == Stats.BattleStatus.ACTIVE


func speed() -> int:
	return stats.battle_stat("speed") if stats != null else 0
