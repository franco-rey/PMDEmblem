class_name BattleStateOps
extends RefCounted

const STATUS_HEAL_BLOCK: String = "heal_block"
const STATUS_SAFEGUARD: String = "safeguard"
const STATUS_MIST: String = "mist"
const SCREEN_STATUSES: Array[String] = ["light_screen", "reflect", "safeguard", "lucky_chant", "mist"]
const STATUS_TYPE_IMMUNITY: Dictionary = {
	"poison": ["poison", "steel"],
	"poison_toxic": ["poison", "steel"],
	"toxic": ["poison", "steel"],
	"burn": ["fire"],
	"paralyze": ["electric"],
	"freeze": ["ice"],
	"leech_seed": ["grass"],
}
const POWDER_MOVES: Array[String] = ["sleep_powder", "poison_powder", "stun_spore", "spore", "cotton_spore", "rage_powder", "magic_powder"]
const MAJOR_STATUSES: Array[String] = ["poison", "poison_toxic", "toxic", "burn", "paralyze", "freeze", "sleep"]
const NON_REAPPLY_STATUSES: Array[String] = ["poison", "poison_toxic", "toxic", "burn", "paralyze", "freeze", "sleep", "leech_seed", "confusion"]

var battle_level: TacticsLevel = null
var battle_log: BattleLog = null
var intrinsic_service: BattleIntrinsicService = null


func _init(level: TacticsLevel = null, log: BattleLog = null, intrinsics: BattleIntrinsicService = null) -> void:
	battle_level = level
	battle_log = log
	intrinsic_service = intrinsics


static func for_pawn(pawn: TacticsPawn, log: BattleLog = null, intrinsics: BattleIntrinsicService = null) -> BattleStateOps:
	var node: Node = pawn
	while node != null:
		if node is TacticsLevel and (node as TacticsLevel).state_ops != null:
			return (node as TacticsLevel).state_ops
		node = node.get_parent()
	return BattleStateOps.new(null, log, intrinsics)


func damage(unit: TacticsPawn, amount: int, cause: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"applied": 0, "before": 0, "after": 0, "fainted": false}
	if unit == null or unit.stats == null or amount <= 0 or not unit.stats.is_active():
		return out
	var kind: String = String(cause.get("kind", "hit"))
	var move: PokemonMoveResource = cause.get("move", null) as PokemonMoveResource
	if kind != "hit" and intrinsic_service != null and intrinsic_service.blocks_indirect_damage(unit.stats):
		_append({"kind": "damage_prevented", "unit": unit, "defender": unit, "source": "intrinsic", "intrinsic_id": "magic_guard", "reason": "indirect_damage"})
		return out
	if kind == "hit" and unit.stats.battle_statuses.has("endure") and amount >= unit.stats.curr_health and unit.stats.curr_health > 1:
		amount = unit.stats.curr_health - 1
		_append({"kind": "status_triggered", "unit": unit, "status_id": "endure"})
	if kind == "hit" and unit.stats.battle_statuses.has("decoy") and cause.get("attacker", null) != unit:
		var decoy: Dictionary = (unit.stats.battle_statuses["decoy"] as Dictionary).duplicate(true)
		var decoy_hp: int = int(decoy.get("hp", 0))
		var absorbed: int = mini(decoy_hp, amount)
		decoy["hp"] = decoy_hp - absorbed
		unit.stats.battle_statuses["decoy"] = decoy
		_append({"kind": "substitute_hit", "unit": unit, "amount": absorbed, "remaining": int(decoy["hp"])})
		if int(decoy["hp"]) <= 0:
			unit.stats.remove_battle_status("decoy")
			_append({"kind": "status_removed", "unit": unit, "status_id": "decoy", "source": "broken"})
		return {"applied": 0, "before": unit.stats.curr_health, "after": unit.stats.curr_health, "fainted": false, "absorbed": absorbed}
	if kind == "hit" and unit.stats.curr_health > 1:
		amount = PokemonItemService.survive_hit(unit, amount, battle_log)
	var before: int = unit.stats.curr_health
	unit.stats.apply_to_curr_health(-amount)
	var applied: int = before - unit.stats.curr_health
	if kind == "hit" and move != null:
		unit.stats.last_hit_move_type = move.type
	var cause_attacker: Variant = cause.get("attacker", null)
	if kind == "hit" and cause_attacker is TacticsPawn and cause_attacker != unit:
		unit.stats.last_attacker = cause_attacker
	if kind == "hit" and unit.stats.battle_statuses.has("bide") and applied > 0:
		var biding: Dictionary = (unit.stats.battle_statuses["bide"] as Dictionary).duplicate(true)
		biding["stored"] = int(biding.get("stored", 0)) + applied
		unit.stats.battle_statuses["bide"] = biding
	out = {"applied": applied, "before": before, "after": unit.stats.curr_health, "fainted": before > 0 and not unit.stats.is_active()}
	var event: Dictionary = {}
	var extras: Dictionary = cause.get("event", {}) if cause.get("event", null) is Dictionary else {}
	for key in extras.keys():
		event[key] = extras[key]
	if kind == "status_tick":
		event["kind"] = "status_tick"
		event["unit"] = unit
		event["status_id"] = String(cause.get("status_id", ""))
		event["amount"] = applied
		event["before"] = before
		event["after"] = unit.stats.curr_health
	else:
		event["kind"] = "damage_dealt"
		event["defender"] = unit
		event["amount"] = applied
		if not event.has("attacker") and cause.get("attacker", null) is TacticsPawn:
			event["attacker"] = cause["attacker"]
		if kind != "hit" and not event.has("source"):
			event["source"] = kind
		if move != null and not event.has("move_id"):
			event["move_id"] = move.move_id
		for key in ["intrinsic_id", "item_id", "status_id"]:
			if cause.has(key) and not event.has(key):
				event[key] = cause[key]
	_append(event)
	if bool(out["fainted"]) and bool(cause.get("emit_faint", true)):
		var faint: Dictionary = {"kind": "unit_fainted", "unit": unit}
		if kind == "status_tick":
			faint["source"] = String(cause.get("status_id", ""))
		elif kind != "hit":
			faint["source"] = String(event.get("source", kind))
		if move != null:
			faint["move_id"] = move.move_id
		_append(faint)
	if applied > 0 and unit.stats.is_active() and bool(cause.get("threshold", true)):
		PokemonItemService.try_trigger_held_threshold(unit, battle_log)
	return out


func heal(unit: TacticsPawn, amount: int, cause: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"applied": 0, "before": 0, "after": 0, "blocked": false}
	if unit == null or unit.stats == null or amount <= 0 or not unit.stats.is_active():
		return out
	var kind: String = String(cause.get("kind", "move"))
	var move: PokemonMoveResource = cause.get("move", null) as PokemonMoveResource
	if unit.stats.battle_statuses.has(STATUS_HEAL_BLOCK):
		out["blocked"] = true
		if kind == "status":
			_append({"kind": "status_heal_blocked", "unit": unit, "status_id": String(cause.get("status_id", "")), "blocked_by": STATUS_HEAL_BLOCK})
		else:
			_append({"kind": "heal_blocked", "unit": unit, "move_id": move.move_id if move != null else "", "status_id": STATUS_HEAL_BLOCK})
		return out
	var before: int = unit.stats.curr_health
	unit.stats.apply_to_curr_health(amount)
	var applied: int = unit.stats.curr_health - before
	out = {"applied": applied, "before": before, "after": unit.stats.curr_health, "blocked": false}
	if applied <= 0:
		return out
	var event: Dictionary = {}
	var extras: Dictionary = cause.get("event", {}) if cause.get("event", null) is Dictionary else {}
	for key in extras.keys():
		event[key] = extras[key]
	event["kind"] = "status_healed" if kind == "status" else "healed"
	event["unit"] = unit
	event["amount"] = applied
	event["before"] = before
	event["after"] = unit.stats.curr_health
	if kind == "status":
		event["status_id"] = String(cause.get("status_id", ""))
	else:
		if move != null and not event.has("move_id"):
			event["move_id"] = move.move_id
		if kind != "move" and not event.has("source"):
			event["source"] = kind
		for key in ["intrinsic_id", "item_id"]:
			if cause.has(key) and not event.has(key):
				event[key] = cause[key]
	_append(event)
	return out


func apply_status(unit: TacticsPawn, status_id: String, payload: Dictionary = {}, cause: Dictionary = {}) -> Dictionary:
	var normalized: String = status_id.strip_edges().to_lower()
	if unit == null or unit.stats == null or normalized.is_empty():
		return {"applied": false, "reason": "invalid"}
	var attacker: TacticsPawn = cause.get("attacker", null) as TacticsPawn
	var move: PokemonMoveResource = cause.get("move", null) as PokemonMoveResource
	var kind: String = String(cause.get("kind", "move"))
	var loud: bool = kind == "move"
	if not bool(cause.get("skip_rules", false)):
		var reason: String = _status_block_reason(attacker, unit, normalized, move)
		if not reason.is_empty():
			if loud:
				var blocked: Dictionary = {"kind": "status_blocked", "unit": unit, "move_id": move.move_id if move != null else "", "status_id": normalized, "reason": reason}
				if reason == "safeguard":
					blocked["blocked_by"] = STATUS_SAFEGUARD
				if attacker != null:
					blocked["attacker"] = attacker
				_append(blocked)
			return {"applied": false, "reason": reason}
		if intrinsic_service != null and intrinsic_service.blocks_status(unit.stats, normalized, battle_log if loud else null, unit, move):
			return {"applied": false, "reason": "intrinsic"}
	if normalized == "stockpile" and unit.stats.battle_statuses.has("stockpile"):
		var stacked: Dictionary = (unit.stats.battle_statuses["stockpile"] as Dictionary).duplicate(true)
		if int(stacked.get("stacks", 1)) >= 3:
			return {"applied": false, "reason": "max_stacks"}
		stacked["stacks"] = int(stacked.get("stacks", 1)) + 1
		unit.stats.battle_statuses["stockpile"] = stacked
		_append({"kind": "status_applied", "unit": unit, "status_id": normalized, "move_id": move.move_id if move != null else "", "stacks": int(stacked["stacks"])})
		return {"applied": true, "reason": ""}
	if SCREEN_STATUSES.has(normalized) and attacker != null and PokemonItemService.screen_rounds_for(attacker.stats) > 0:
		payload["counter"] = PokemonItemService.screen_rounds_for(attacker.stats)
	unit.stats.apply_battle_status(normalized, payload)
	if intrinsic_service != null:
		intrinsic_service.after_status_applied(unit, normalized)
	if unit is TacticsPawn:
		PokemonItemService.try_cure_on_status(unit, normalized, battle_log)
		if normalized == "in_love" and attacker is TacticsPawn:
			PokemonItemService.on_infatuated(unit, attacker, battle_log)
	if SCREEN_STATUSES.has(normalized) and battle_level != null:
		battle_level.set_team_battle_condition(normalized, unit, payload)
		var field: Dictionary = {"kind": "field_condition_applied", "condition_id": normalized, "move_id": move.move_id if move != null else "", "unit": unit, "scope": "team", "source_event": String(cause.get("source_event", ""))}
		if attacker != null:
			field["attacker"] = attacker
		_append(field)
	var event: Dictionary = {"kind": "status_applied", "unit": unit, "status_id": normalized, "move_id": move.move_id if move != null else ""}
	if kind != "move":
		event["source"] = String(cause.get("source", kind))
	for key in ["intrinsic_id", "item_id"]:
		if cause.has(key):
			event[key] = cause[key]
	_append(event)
	if kind == "move" and attacker != null and move != null and intrinsic_service != null:
		intrinsic_service.maybe_reflect_status(attacker, unit, normalized, move, battle_log)
	return {"applied": true, "reason": ""}


func remove_status(unit: TacticsPawn, status_id: String, cause: Dictionary = {}) -> Dictionary:
	if unit == null or unit.stats == null:
		return {}
	var removed: Dictionary = unit.stats.remove_battle_status(status_id)
	if removed.is_empty():
		return {}
	var normalized: String = String(removed.get("status_id", status_id))
	if SCREEN_STATUSES.has(normalized) and battle_level != null:
		battle_level.refresh_team_battle_condition(normalized, unit)
	var move: PokemonMoveResource = cause.get("move", null) as PokemonMoveResource
	var event: Dictionary = {"kind": "status_removed", "unit": unit, "status_id": normalized}
	if move != null:
		event["move_id"] = move.move_id
	if cause.has("source"):
		event["source"] = String(cause["source"])
	for key in ["intrinsic_id", "item_id"]:
		if cause.has(key):
			event[key] = cause[key]
	_append(event)
	return removed


func change_stat_stage(unit: TacticsPawn, stat_id: String, delta: int, cause: Dictionary = {}) -> Dictionary:
	if unit == null or unit.stats == null or stat_id.is_empty() or delta == 0:
		return {}
	var attacker: TacticsPawn = cause.get("attacker", null) as TacticsPawn
	var move: PokemonMoveResource = cause.get("move", null) as PokemonMoveResource
	var kind: String = String(cause.get("kind", "move"))
	if not bool(cause.get("skip_rules", false)):
		if intrinsic_service != null and intrinsic_service.blocks_stat_stage(unit.stats, stat_id, delta, battle_log, unit, move):
			return {}
		if delta < 0 and attacker != null and attacker != unit and _unit_has_condition(unit, STATUS_MIST):
			_append({"kind": "stat_stage_blocked", "unit": unit, "move_id": move.move_id if move != null else "", "stat": stat_id, "delta": delta, "blocked_by": STATUS_MIST})
			return {}
		if delta < 0 and intrinsic_service != null and intrinsic_service.ally_veil_blocks_stat_drop(unit, attacker):
			_append({"kind": "stat_stage_blocked", "unit": unit, "move_id": move.move_id if move != null else "", "stat": stat_id, "delta": delta, "intrinsic_id": "flower_veil"})
			return {}
		if delta < 0 and attacker != null and attacker != unit and PokemonItemService.blocks_foe_stat_drops(unit.stats):
			_append({"kind": "stat_stage_blocked", "unit": unit, "move_id": move.move_id if move != null else "", "stat": stat_id, "delta": delta, "item_id": "held_clear_amulet"})
			return {}
		if delta < 0 and attacker != null and attacker != unit and unit.stats.battle_statuses.has("decoy"):
			_append({"kind": "stat_stage_blocked", "unit": unit, "move_id": move.move_id if move != null else "", "stat": stat_id, "delta": delta, "blocked_by": "substitute"})
			return {}
	var effective_delta: int = intrinsic_service.transform_stat_delta(unit.stats, delta) if intrinsic_service != null else delta
	var change: Dictionary = unit.stats.change_stat_stage(stat_id, effective_delta)
	if change.is_empty():
		return {}
	var event: Dictionary = {}
	var extras: Dictionary = cause.get("event", {}) if cause.get("event", null) is Dictionary else {}
	for key in extras.keys():
		event[key] = extras[key]
	event["kind"] = "stat_stage_changed"
	event["unit"] = unit
	event["move_id"] = move.move_id if move != null else ""
	event["stat"] = change["stat"]
	event["before"] = change["before"]
	event["after"] = change["after"]
	event["delta"] = change["delta"]
	if kind != "move" and not event.has("source"):
		event["source"] = kind
	for key in ["intrinsic_id", "item_id"]:
		if cause.has(key) and not event.has(key):
			event[key] = cause[key]
	_append(event)
	if int(change["delta"]) < 0 and attacker != null and attacker != unit and intrinsic_service != null:
		intrinsic_service.on_stat_lowered_by_foe(unit, attacker, String(change["stat"]), int(change["delta"]), move, battle_log)
	if int(change["delta"]) < 0 and String(cause.get("intrinsic_id", "")) == "intimidate":
		PokemonItemService.on_intimidated(unit, battle_log)
	if int(change["delta"]) > 0 and battle_level != null and String(cause.get("item_id", "")) != "held_mirror_herb":
		for other in battle_level.units_on_map():
			if other != unit and other.stats != null and other.stats.is_active() and battle_level.are_foes(unit, other):
				PokemonItemService.mirror_herb(other, String(change["stat"]), int(change["delta"]), battle_log)
	return change


func _status_block_reason(attacker: TacticsPawn, unit: TacticsPawn, status_id: String, move: PokemonMoveResource) -> String:
	if status_id != STATUS_SAFEGUARD and attacker != null and attacker != unit and BattleActionResolver.BAD_STATUS_IDS.has(status_id) and _unit_has_condition(unit, STATUS_SAFEGUARD):
		return "safeguard"
	var unit_types: Array = unit.stats.types
	for type_id in STATUS_TYPE_IMMUNITY.get(status_id, []):
		if unit_types.has(String(type_id)):
			return "type_immunity"
	if move != null and POWDER_MOVES.has(move.move_id) and unit_types.has("grass"):
		return "powder_immunity"
	if battle_level != null and battle_level.weather_blocks_status(status_id):
		return "weather"
	if NON_REAPPLY_STATUSES.has(status_id) and unit.stats.battle_statuses.has(status_id):
		return "already_applied"
	if status_id == "sleep" and unit.stats.battle_statuses.has("sleepless"):
		return "sleepless"
	if move != null and POWDER_MOVES.has(move.move_id) and PokemonItemService.blocks_powder(unit.stats):
		return "safety_goggles"
	if unit.stats.battle_statuses.has("decoy") and attacker != null and attacker != unit and move != null and status_id != "decoy":
		return "substitute"
	if battle_level != null and unit is TacticsPawn and battle_level.is_grounded(unit):
		var terrain: String = battle_level.current_terrain()
		if terrain == "electric_terrain" and (status_id == "sleep" or status_id == "yawning"):
			return "electric_terrain"
		if terrain == "misty_terrain" and (MAJOR_STATUSES.has(status_id) or status_id == "confuse"):
			return "misty_terrain"
	if MAJOR_STATUSES.has(status_id):
		for other in MAJOR_STATUSES:
			if other != status_id and unit.stats.battle_statuses.has(other):
				return "major_status_present"
	if intrinsic_service != null and not intrinsic_service.ally_veil_blocks_status(unit, status_id, attacker).is_empty():
		return "ally_veil"
	return ""


func _unit_has_condition(unit: TacticsPawn, status_id: String) -> bool:
	if unit == null:
		return false
	if unit.stats != null and unit.stats.battle_statuses.has(status_id):
		return true
	return battle_level != null and battle_level.has_team_battle_condition(status_id, unit)


func _append(event: Dictionary) -> void:
	if battle_log != null:
		battle_log.append(event)
