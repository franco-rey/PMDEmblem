class_name BattlePresentationRunner
extends Node

signal sequence_started(sequence_id: int, label: String)
signal sequence_finished(sequence_id: int, label: String)
signal cue_started(cue: Dictionary)

const KIND_ACTOR_ACTION: String = "actor_action"
const KIND_WAIT: String = "wait"
const KIND_WAIT_UNTIL_HIT: String = "wait_until_hit"
const KIND_WAIT_UNTIL_RUSH: String = "wait_until_rush"
const KIND_WAIT_UNTIL_DONE: String = "wait_until_done"
const KIND_VFX: String = "vfx"
const KIND_PROJECTILE: String = "projectile"
const KIND_REACTION: String = "reaction"
const KIND_LUNGE: String = "lunge"
const KIND_LOG: String = "log"
const KIND_CALLBACK: String = "callback"
const KIND_FACE: String = "face"
const KIND_SOUND: String = "sound"
const MAX_SEQUENCE_SECONDS: float = 12.0
const MAX_CUE_SECONDS: float = 6.0

var battle_log: BattleLog = null
var vfx_player: BattleVFXPlayer = null
var immediate_mode: bool = false

var _queue: Array[Dictionary] = []
var _active: Dictionary = {}
var _active_remaining: float = 0.0
var _sequence_id: int = 0
var _sequence_label: String = ""
var _sequence_open: bool = false
var _sequence_elapsed: float = 0.0
var _last_action: Dictionary = {}
var _last_action_started: float = 0.0
var _clock: float = 0.0
var _lunges: Array[Dictionary] = []
var _timeouts: int = 0
var _completed_sequences: int = 0


func begin_sequence(label: String) -> int:
	_sequence_id += 1
	_sequence_label = label
	_sequence_open = true
	_sequence_elapsed = 0.0
	sequence_started.emit(_sequence_id, label)
	return _sequence_id


func end_sequence() -> void:
	_sequence_open = false
	if immediate_mode or not is_inside_tree():
		drain_immediately()


func enqueue(cue: Dictionary) -> void:
	if cue.is_empty():
		return
	_queue.append(cue.duplicate(true))
	if immediate_mode or not is_inside_tree():
		drain_immediately()


func is_busy() -> bool:
	return not _queue.is_empty() or not _active.is_empty() or _sequence_open or not _lunges.is_empty()


func is_idle() -> bool:
	return not is_busy()


func pending_count() -> int:
	return _queue.size() + (1 if not _active.is_empty() else 0)


func drain_immediately() -> void:
	var guard: int = 0
	while (not _queue.is_empty() or not _active.is_empty()) and guard < 4096:
		guard += 1
		if _active.is_empty():
			_start_next()
		_active = {}
		_active_remaining = 0.0
	_lunges.clear()
	if not _sequence_open:
		_finish_sequence()


func cancel_all(reason: String = "") -> void:
	_queue.clear()
	_active = {}
	_active_remaining = 0.0
	for lunge in _lunges:
		_finish_lunge(lunge)
	_lunges.clear()
	_sequence_open = false
	_append_log({"kind": "presentation_cancelled", "reason": reason, "sequence": _sequence_id})


func stats() -> Dictionary:
	return {
		"completed_sequences": _completed_sequences,
		"timeouts": _timeouts,
		"pending": pending_count(),
		"busy": is_busy(),
		"active_vfx": vfx_player.active_count() if vfx_player != null else 0,
	}


func _process(delta: float) -> void:
	_clock += delta
	_advance_lunges(delta)
	if _active.is_empty():
		if _queue.is_empty():
			if not _sequence_open and _sequence_label != "":
				_finish_sequence()
			return
		_start_next()
	if _active.is_empty():
		return
	_sequence_elapsed += delta
	_active_remaining -= delta
	if _sequence_elapsed > MAX_SEQUENCE_SECONDS:
		_timeouts += 1
		_append_log({"kind": "presentation_timeout", "sequence": _sequence_id, "label": _sequence_label, "pending": pending_count()})
		_queue.clear()
		_active = {}
		_active_remaining = 0.0
		for lunge in _lunges:
			_finish_lunge(lunge)
		_lunges.clear()
		return
	if _active_remaining <= 0.0:
		_active = {}
		_active_remaining = 0.0


func _start_next() -> void:
	var guard: int = 0
	while not _queue.is_empty() and guard < 256:
		guard += 1
		var cue: Dictionary = _queue.pop_front()
		cue_started.emit(cue)
		var block_seconds: float = _run_cue(cue)
		if block_seconds > 0.0 and not immediate_mode and is_inside_tree():
			_active = cue
			_active_remaining = minf(block_seconds, MAX_CUE_SECONDS)
			return


func _run_cue(cue: Dictionary) -> float:
	var kind: String = String(cue.get("kind", ""))
	match kind:
		KIND_ACTOR_ACTION:
			return _run_actor_action(cue)
		KIND_WAIT:
			return maxf(0.0, float(cue.get("seconds", 0.0)))
		KIND_WAIT_UNTIL_HIT:
			return _remaining_until("hit")
		KIND_WAIT_UNTIL_RUSH:
			return _remaining_until("rush")
		KIND_WAIT_UNTIL_DONE:
			return _remaining_until("total")
		KIND_VFX:
			var seconds: float = _run_vfx(cue)
			return seconds if bool(cue.get("block", false)) else 0.0
		KIND_PROJECTILE:
			return _run_projectile(cue)
		KIND_REACTION:
			return _run_reaction(cue)
		KIND_LUNGE:
			_run_lunge(cue)
			return 0.0
		KIND_FACE:
			_run_face(cue)
			return 0.0
		KIND_LOG:
			var event: Variant = cue.get("event", {})
			if event is Dictionary:
				_append_log(event)
			return 0.0
		KIND_SOUND:
			var sound_name: String = String(cue.get("sound", ""))
			var played: bool = SoundPlayer.sound(sound_name, float(cue.get("volume_db", 0.0)))
			_append_log({"kind": "sound_played" if played else "sound_skipped", "sound": sound_name, "label": String(cue.get("label", ""))})
			return 0.0
		KIND_CALLBACK:
			var callable: Variant = cue.get("callable", null)
			if callable is Callable and (callable as Callable).is_valid():
				(callable as Callable).call()
			return 0.0
	return 0.0


func _run_actor_action(cue: Dictionary) -> float:
	var pawn: TacticsPawn = cue.get("pawn", null) as TacticsPawn
	var state: String = String(cue.get("state", ""))
	if pawn == null or not is_instance_valid(pawn) or state.is_empty():
		_last_action = {}
		return 0.0
	var sprite: TacticsPawnSprite = pawn.get_node_or_null("Character") as TacticsPawnSprite
	var phases: Dictionary = {"rush": 0.0, "hit": 0.0, "return": 0.0, "total": 0.0}
	if sprite != null and sprite.can_play_state(state):
		phases = sprite.state_phase_seconds(state)
	var total: float = maxf(float(phases.get("total", 0.0)), float(cue.get("min_seconds", 0.0)))
	if total <= 0.0:
		total = float(cue.get("fallback_seconds", 0.45))
	pawn.res.force_animation(state, total + float(cue.get("hold_seconds", 0.0)), bool(cue.get("one_shot", true)))
	_last_action = {
		"pawn": pawn,
		"state": state,
		"rush": float(phases.get("rush", 0.0)),
		"hit": minf(float(phases.get("hit", total)), total),
		"return": minf(float(phases.get("return", total)), total),
		"total": total,
	}
	_last_action_started = _clock
	if bool(cue.get("lunge", false)) and sprite != null:
		_run_lunge({
			"pawn": pawn,
			"direction": cue.get("direction", Vector3.ZERO),
			"rush": _last_action["rush"],
			"hit": _last_action["hit"],
			"return": _last_action["return"],
			"total": _last_action["total"],
			"distance": float(cue.get("lunge_distance", 0.5)),
		})
	return float(cue.get("block_seconds", 0.0))


func _remaining_until(phase: String) -> float:
	if _last_action.is_empty():
		return 0.0
	var target: float = float(_last_action.get(phase, 0.0))
	var elapsed: float = _clock - _last_action_started
	return maxf(0.0, target - elapsed)


func _run_vfx(cue: Dictionary) -> float:
	if vfx_player == null:
		return 0.0
	return vfx_player.play_cue(cue)


func _run_projectile(cue: Dictionary) -> float:
	if vfx_player == null:
		return 0.0
	var seconds: float = vfx_player.play_projectile_cue(cue)
	return seconds if bool(cue.get("block", true)) else 0.0


func _run_reaction(cue: Dictionary) -> float:
	var pawn: TacticsPawn = cue.get("pawn", null) as TacticsPawn
	var state: String = String(cue.get("state", ""))
	if pawn == null or not is_instance_valid(pawn) or state.is_empty():
		return 0.0
	var duration: float = float(cue.get("duration", 0.35))
	if state == TacticsPawnSprite.ANIM_HURT:
		pawn.res.hurt_remaining = maxf(pawn.res.hurt_remaining, duration)
	else:
		pawn.res.force_animation(state, duration, bool(cue.get("one_shot", true)))
	return duration if bool(cue.get("block", false)) else 0.0


func _run_face(cue: Dictionary) -> void:
	var pawn: TacticsPawn = cue.get("pawn", null) as TacticsPawn
	if pawn == null or not is_instance_valid(pawn):
		return
	var direction: Vector3 = cue.get("direction", Vector3.ZERO)
	if direction.length() < 0.0001:
		return
	pawn.serv.movement.look_at_direction_8(pawn, direction)


func _run_lunge(cue: Dictionary) -> void:
	var pawn: TacticsPawn = cue.get("pawn", null) as TacticsPawn
	if pawn == null or not is_instance_valid(pawn):
		return
	var direction: Vector3 = cue.get("direction", Vector3.ZERO)
	direction.y = 0.0
	if direction.length() < 0.0001:
		return
	_lunges.append({
		"pawn": pawn,
		"direction": direction.normalized(),
		"rush": float(cue.get("rush", 0.0)),
		"hit": float(cue.get("hit", 0.2)),
		"return": float(cue.get("return", 0.3)),
		"total": maxf(float(cue.get("total", 0.45)), 0.05),
		"distance": float(cue.get("distance", 0.5)),
		"elapsed": 0.0,
	})


func run_dash(pawn: TacticsPawn, from_world: Vector3, to_world: Vector3, state: String, seconds: float) -> void:
	if pawn == null or not is_instance_valid(pawn):
		return
	var sprite: TacticsPawnSprite = pawn.get_node_or_null("Character") as TacticsPawnSprite
	if sprite == null:
		return
	var offset: Vector3 = from_world - to_world
	offset.y = 0.0
	if immediate_mode or not is_inside_tree() or offset.length() < 0.001:
		return
	if sprite.can_play_state(state):
		sprite.freeze_pose(state)
	_lunges.append({
		"pawn": pawn,
		"dash": true,
		"start_offset": offset,
		"total": maxf(seconds, 0.05),
		"elapsed": 0.0,
		"state": state,
	})


func _advance_lunges(delta: float) -> void:
	if _lunges.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for lunge in _lunges:
		lunge["elapsed"] = float(lunge["elapsed"]) + delta
		var pawn: TacticsPawn = lunge.get("pawn", null) as TacticsPawn
		if pawn == null or not is_instance_valid(pawn):
			continue
		var sprite: TacticsPawnSprite = pawn.get_node_or_null("Character") as TacticsPawnSprite
		if sprite == null:
			continue
		if bool(lunge.get("dash", false)):
			var progress: float = clampf(float(lunge["elapsed"]) / float(lunge["total"]), 0.0, 1.0)
			sprite.set_lunge_offset((lunge["start_offset"] as Vector3) * (1.0 - progress))
			if progress >= 1.0:
				sprite.unfreeze_pose()
				_finish_lunge(lunge)
				continue
			remaining.append(lunge)
			continue
		var t: float = float(lunge["elapsed"])
		var rush: float = float(lunge["rush"])
		var hit: float = float(lunge["hit"])
		var ret: float = float(lunge["return"])
		var total: float = float(lunge["total"])
		var distance: float = float(lunge["distance"])
		var direction: Vector3 = lunge["direction"]
		var amount: float = 0.0
		if t < rush:
			amount = 0.0
		elif t < hit:
			amount = (t - rush) / maxf(hit - rush, 0.001)
		elif t < ret:
			amount = 1.0
		elif t < total:
			amount = 1.0 - (t - ret) / maxf(total - ret, 0.001)
		else:
			_finish_lunge(lunge)
			continue
		sprite.set_lunge_offset(direction * distance * clampf(amount, 0.0, 1.0))
		remaining.append(lunge)
	_lunges = remaining


func _finish_lunge(lunge: Dictionary) -> void:
	var pawn: TacticsPawn = lunge.get("pawn", null) as TacticsPawn
	if pawn == null or not is_instance_valid(pawn):
		return
	if bool(lunge.get("dash", false)):
		var frozen: TacticsPawnSprite = pawn.get_node_or_null("Character") as TacticsPawnSprite
		if frozen != null:
			frozen.unfreeze_pose()
	var sprite: TacticsPawnSprite = pawn.get_node_or_null("Character") as TacticsPawnSprite
	if sprite != null:
		sprite.clear_lunge_offset()


func _finish_sequence() -> void:
	if _sequence_label == "" and _sequence_id == 0:
		return
	_completed_sequences += 1
	var label: String = _sequence_label
	_sequence_label = ""
	_last_action = {}
	sequence_finished.emit(_sequence_id, label)


func _append_log(event: Dictionary) -> void:
	if battle_log != null:
		battle_log.append(event)
