class_name BattleActionIntent
extends RefCounted

const KIND_MOVE: String = "move"
const KIND_USE_ITEM: String = "use_item"
const KIND_THROW_ITEM: String = "throw_item"
const KIND_WAIT: String = "wait"

const TARGET_UNIT: String = "unit"
const TARGET_SELF: String = "self"
const TARGET_DIRECTION: String = "direction"
const TARGET_TILE: String = "tile"

var actor: TacticsPawn = null
var kind: String = KIND_MOVE
var slot_index: int = -1
var item_id: String = ""
var target_mode: String = TARGET_UNIT
var target: TacticsPawn = null
var direction: Vector3i = Vector3i.ZERO
var tile: Vector3i = Vector3i.ZERO


static func move(actor_pawn: TacticsPawn, slot: int, target_pawn: TacticsPawn) -> BattleActionIntent:
	var intent := BattleActionIntent.new()
	intent.actor = actor_pawn
	intent.kind = KIND_MOVE
	intent.slot_index = slot
	intent.target = target_pawn
	intent.target_mode = TARGET_SELF if target_pawn == actor_pawn else TARGET_UNIT
	return intent


static func use_item(actor_pawn: TacticsPawn, held_item_id: String) -> BattleActionIntent:
	var intent := BattleActionIntent.new()
	intent.actor = actor_pawn
	intent.kind = KIND_USE_ITEM
	intent.item_id = held_item_id
	intent.target = actor_pawn
	intent.target_mode = TARGET_SELF
	return intent


static func throw_item(actor_pawn: TacticsPawn, held_item_id: String, grid_direction: Vector3i, target_pawn: TacticsPawn = null) -> BattleActionIntent:
	var intent := BattleActionIntent.new()
	intent.actor = actor_pawn
	intent.kind = KIND_THROW_ITEM
	intent.item_id = held_item_id
	intent.direction = grid_direction
	intent.target = target_pawn
	intent.target_mode = TARGET_DIRECTION
	return intent


func is_item_action() -> bool:
	return kind == KIND_USE_ITEM or kind == KIND_THROW_ITEM


func describe() -> Dictionary:
	return {
		"kind": kind,
		"slot_index": slot_index,
		"item_id": item_id,
		"target_mode": target_mode,
		"direction": direction,
		"has_target": target != null,
	}
