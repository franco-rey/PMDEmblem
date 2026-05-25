class_name TacticsParticipantResource
extends Resource

signal called_skip_turn

const STAGE_SELECT_PAWN: int = 0
const STAGE_SHOW_ACTIONS: int = 1
const STAGE_SHOW_MOVEMENTS: int = 2
const STAGE_SELECT_LOCATION: int = 3
const STAGE_MOVE_PAWN: int = 4
const STAGE_DISPLAY_TARGETS: int = 5
const STAGE_SELECT_ATTACK_TARGET: int = 6
const STAGE_ATTACK: int = 7
const STAGE_SELECT_MOVE: int = 8
var stage: int = 0

var curr_pawn: TacticsPawn = null:
	set(val):
		curr_pawn = val
		DebugLog.debug_nospam("pawn", val)
var attackable_pawn: TacticsPawn = null
var targets: Node = null

var display_opponent_stats: bool = false
var turn_just_started: bool = true


func skip_turn() -> void:
	called_skip_turn.emit()
