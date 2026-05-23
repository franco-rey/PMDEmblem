class_name BattleUnit
extends RefCounted
## Scheduler adapter wrapping a [TacticsPawn] / [Stats] / team / control type.
##
## The [BattleScheduler] never depends on [TacticsPawn] directly. This adapter
## keeps the scheduler usable by future battle models (replays, AI testbeds,
## headless harnesses) that may not spawn full scene-tree pawns. M3 builds one
## adapter per pawn at battle start and hands the flat array to the scheduler.

var pawn: TacticsPawn = null
var stats: Stats = null
## Team enum value (mirrors `PokemonInstanceResource.Team`).
var team: int = 0
## Control type enum value (mirrors `PokemonInstanceResource.ControlType`).
var control_type: int = 0
## Stable insertion index, used as the deterministic mid-tier tie-break.
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
	return stats.speed if stats != null else 0
