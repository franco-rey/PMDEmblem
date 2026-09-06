class_name NetSession
extends Node

signal state_changed(state: int)
signal remote_lobby_changed(state: Dictionary)
signal notice(text: String)
signal start_requested(code: String, battle_id: String)
signal battle_over_remote(result: int, reason: String)
signal desynced(reason: String)

enum {
	IDLE,
	HOSTING,
	CONNECTING,
	LOBBY,
	STARTING,
	IN_BATTLE,
	ENDED,
}

const STALL_FRAMES: int = 3600

var link: NetLink = null
var state: int = IDLE
var host_role: bool = false
var local_side: int = PokemonInstanceResource.Team.PLAYER
var local_name: String = "Player"
var remote_name: String = ""
var remote_lobby: Dictionary = {}
var local_lobby: Dictionary = {}
var remote_ready: bool = false
var battle_id: String = ""
var pending_code: String = ""
var level: TacticsLevel = null
var applier: BattleCommandApplier = null
var auto_play: bool = false
var last_reason: String = ""
var chain: String = ""
var line_count: int = 0
var desync_reason: String = ""

var _send_seq: int = 0
var _expect_seq: int = 0
var _inbox: Array[Dictionary] = []
var _draining: bool = false
var _turn_header: String = ""
var _my_rounds: Dictionary = {}
var _their_rounds: Dictionary = {}
var _ready_local: bool = false
var _ready_remote: bool = false
var _auto_busy: bool = false
var _stall_frames: int = 0
var _stall_header: String = ""
var disconnect_grace_seconds: float = 3.0
var _disconnect_grace: float = -1.0


func _ready() -> void:
	name = "NetSession"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


func active() -> bool:
	return state != IDLE


func in_battle() -> bool:
	return state == IN_BATTLE


func host(port: int = EnetLink.DEFAULT_PORT) -> String:
	var enet := EnetLink.new()
	var error: String = enet.host(port)
	if not error.is_empty():
		return error
	host_role = true
	local_side = PokemonInstanceResource.Team.PLAYER
	_use_link(enet)
	_set_state(HOSTING)
	return ""


func join(address: String, port: int = EnetLink.DEFAULT_PORT) -> String:
	var enet := EnetLink.new()
	var error: String = enet.join(address, port)
	if not error.is_empty():
		return error
	host_role = false
	local_side = PokemonInstanceResource.Team.ENEMY
	_use_link(enet)
	_set_state(CONNECTING)
	return ""


func use_test_link(test_link: NetLink, as_host: bool) -> void:
	host_role = as_host
	local_side = PokemonInstanceResource.Team.PLAYER if as_host else PokemonInstanceResource.Team.ENEMY
	_use_link(test_link)
	_set_state(HOSTING if as_host else CONNECTING)
	if not as_host:
		_send_hello()


func leave(reason: String = "left") -> void:
	if link != null and link.is_open():
		link.send(NetMessages.build(NetMessages.BYE, {"reason": reason}))
		link.close(reason)
	link = null
	_reset_battle_state()
	remote_name = ""
	remote_lobby = {}
	remote_ready = false
	_set_state(IDLE)


func _use_link(new_link: NetLink) -> void:
	if link != null:
		link.close("replaced")
	link = new_link
	link.received.connect(_on_received)
	link.closed.connect(_on_closed)
	link.opened.connect(_on_opened)


func _process(delta: float) -> void:
	if link != null:
		link.poll(delta)
	if _disconnect_grace >= 0.0:
		if level != null and is_instance_valid(level) and level.battle_finished:
			_disconnect_grace = -1.0
			_set_state(ENDED)
		else:
			_disconnect_grace -= delta
			if _disconnect_grace <= 0.0:
				_disconnect_grace = -1.0
				_finish_remote(_local_win_result(), "disconnect")
	_update_remote_lock()
	if not _inbox.is_empty() and not _draining:
		_pump()
	if auto_play and state == IN_BATTLE and not _auto_busy and not _draining:
		_auto_play_step()


func _on_opened() -> void:
	if not host_role:
		_send_hello()


func _on_closed(reason: String) -> void:
	last_reason = reason
	if in_battle() and state != ENDED:
		if _stall_frames > 60:
			_raise_desync("stalled waiting for %s when the connection dropped" % _stall_header, false)
			return
		notice.emit("%s disconnected." % _remote_label())
		_disconnect_grace = disconnect_grace_seconds
		return
	if state != ENDED:
		notice.emit("Disconnected (%s)." % reason)
		_set_state(IDLE)


func _send_hello() -> void:
	if link == null:
		return
	link.send(NetMessages.build(NetMessages.HELLO, {
		"protocol": NetMessages.PROTOCOL,
		"version": GameSettings.GAME_VERSION,
		"name": local_name,
		"content": NetMessages.content_fingerprint(),
	}))


func send_lobby(state_dict: Dictionary) -> void:
	local_lobby = state_dict.duplicate(true)
	if link != null and (state == LOBBY or state == ENDED):
		link.send(NetMessages.build(NetMessages.LOBBY, {"state": local_lobby}))


func set_ready(value: bool) -> void:
	local_lobby["ready"] = value
	send_lobby(local_lobby)


func both_ready() -> bool:
	return bool(local_lobby.get("ready", false)) and remote_ready


func start_battle(code: String) -> void:
	if not host_role or link == null:
		return
	var built: Dictionary = SkirmishCode.build_definitions(code)
	if not bool(built.get("ok", false)):
		notice.emit("Cannot start: %s" % String(built.get("error", "")))
		return
	var definitions: Array = built.get("definitions", [])
	var definition: SkirmishDefinitionResource = definitions[0] as SkirmishDefinitionResource if not definitions.is_empty() else null
	battle_id = "%d-%d" % [definition.seed if definition != null else 0, int(Time.get_unix_time_from_system())]
	pending_code = code
	link.send(NetMessages.build(NetMessages.START, {
		"code": code,
		"battle_id": battle_id,
		"units": NetMessages.unit_fingerprints(definition),
	}))
	_set_state(STARTING)


func _on_received(message: Dictionary) -> void:
	var error: String = NetMessages.validate(message)
	if not error.is_empty():
		notice.emit("Protocol error: %s" % error)
		leave("protocol")
		return
	var kind: String = String(message.get("k", ""))
	match kind:
		NetMessages.HELLO:
			_handle_hello(message)
		NetMessages.WELCOME:
			local_side = int(message.get("side", PokemonInstanceResource.Team.ENEMY))
			remote_name = String(message.get("host_name", "Host"))
			remote_lobby = message.get("lobby", {})
			remote_ready = bool(remote_lobby.get("ready", false))
			_set_state(LOBBY)
			remote_lobby_changed.emit(remote_lobby)
			notice.emit("Connected to %s." % remote_name)
			send_lobby(local_lobby)
		NetMessages.REJECT:
			notice.emit("The host refused the connection: %s" % String(message.get("reason", "")))
			leave("rejected")
		NetMessages.LOBBY:
			remote_lobby = message.get("state", {})
			remote_ready = bool(remote_lobby.get("ready", false))
			remote_lobby_changed.emit(remote_lobby)
		NetMessages.START:
			_handle_start(message)
		NetMessages.START_REFUSED:
			notice.emit("The other player refused the start: %s" % String(message.get("reason", "")))
			_set_state(LOBBY)
		NetMessages.START_ACK:
			start_requested.emit(pending_code, battle_id)
		NetMessages.BATTLE_READY:
			_ready_remote = true
		NetMessages.CMD, NetMessages.SYNC:
			_inbox.append(message)
		NetMessages.DESYNC:
			_raise_desync("the other player reported a desync: %s" % String(message.get("reason", "")), false)
		NetMessages.RESIGN:
			_finish_remote(_local_win_result(), "resign")
		NetMessages.BYE:
			notice.emit("%s left (%s)." % [_remote_label(), String(message.get("reason", ""))])
			if in_battle():
				_finish_remote(_local_win_result(), "resign")
			else:
				leave("peer_left")


func _handle_hello(message: Dictionary) -> void:
	remote_name = String(message.get("name", "Player"))
	if not host_role:
		return
	if int(message.get("protocol", -1)) != NetMessages.PROTOCOL:
		link.send(NetMessages.build(NetMessages.REJECT, {"reason": "protocol"}))
		return
	if String(message.get("version", "")) != GameSettings.GAME_VERSION:
		link.send(NetMessages.build(NetMessages.REJECT, {"reason": "version"}))
		return
	if String(message.get("content", "")) != NetMessages.content_fingerprint():
		link.send(NetMessages.build(NetMessages.REJECT, {"reason": "content"}))
		return
	link.send(NetMessages.build(NetMessages.WELCOME, {
		"side": PokemonInstanceResource.Team.ENEMY,
		"host_name": local_name,
		"lobby": local_lobby,
	}))
	_set_state(LOBBY)
	notice.emit("%s connected." % remote_name)


func _handle_start(message: Dictionary) -> void:
	battle_id = String(message.get("battle_id", ""))
	var code: String = String(message.get("code", ""))
	var built: Dictionary = SkirmishCode.build_definitions(code)
	if not bool(built.get("ok", false)):
		link.send(NetMessages.build(NetMessages.START_REFUSED, {"reason": String(built.get("error", "bad code")), "units": PackedStringArray()}))
		return
	var definitions: Array = built.get("definitions", [])
	var definition: SkirmishDefinitionResource = definitions[0] if not definitions.is_empty() else null
	var mine: PackedStringArray = NetMessages.unit_fingerprints(definition)
	var theirs: PackedStringArray = message.get("units", PackedStringArray())
	var diff: String = NetMessages.fingerprint_diff(mine, theirs)
	if not diff.is_empty():
		link.send(NetMessages.build(NetMessages.START_REFUSED, {"reason": diff, "units": mine}))
		notice.emit("Refused the start: %s" % diff)
		return
	pending_code = code
	link.send(NetMessages.build(NetMessages.START_ACK, {"battle_id": battle_id}))
	_set_state(STARTING)
	start_requested.emit(code, battle_id)


func attach_level(battle_level: TacticsLevel) -> void:
	detach_level()
	level = battle_level
	if level == null:
		return
	applier = BattleCommandApplier.new(get_tree(), level)
	applier.auto_end_other_humans = false
	applier.verbose = false
	chain = NetMessages.chain_of(level.notation.lines)
	line_count = level.notation.lines.size()
	_send_seq = 0
	_expect_seq = 0
	_inbox.clear()
	_stall_frames = 0
	_disconnect_grace = -1.0
	_my_rounds.clear()
	_their_rounds.clear()
	_ready_local = false
	_ready_remote = false
	_turn_header = ""
	desync_reason = ""
	level.notation.line_appended.connect(_on_line_appended)
	level.battle_ended.connect(_on_battle_ended)
	if level.scheduler != null:
		level.scheduler.round_started.connect(_on_round_started)
	_set_state(IN_BATTLE)


func detach_level() -> void:
	if level != null and is_instance_valid(level):
		if level.notation.line_appended.is_connected(_on_line_appended):
			level.notation.line_appended.disconnect(_on_line_appended)
		if level.battle_ended.is_connected(_on_battle_ended):
			level.battle_ended.disconnect(_on_battle_ended)
		if level.scheduler != null and level.scheduler.round_started.is_connected(_on_round_started):
			level.scheduler.round_started.disconnect(_on_round_started)
		if level.ui_control != null:
			level.ui_control.remote_turn = false
	level = null
	applier = null


func mark_ready() -> void:
	if _ready_local or link == null:
		return
	_ready_local = true
	link.send(NetMessages.build(NetMessages.BATTLE_READY, {"battle_id": battle_id}))


func ready_to_play() -> bool:
	return _ready_local and _ready_remote


func active_unit_side() -> int:
	if level == null or not is_instance_valid(level) or level.scheduler == null:
		return -1
	var unit: BattleUnit = level.scheduler.get_active_unit()
	return unit.team if unit != null else -1


func remote_turn_active() -> bool:
	if not in_battle() or level == null or not is_instance_valid(level):
		return false
	var side: int = active_unit_side()
	return side >= 0 and side != local_side


func _update_remote_lock() -> void:
	if level == null or not is_instance_valid(level) or level.ui_control == null:
		return
	level.ui_control.remote_turn = remote_turn_active()


func _on_line_appended(line: String, index: int) -> void:
	var before: String = chain
	chain = NetMessages.chain_next(chain, line)
	line_count = index + 1
	var parsed: Dictionary = NotationParser.parse(line)
	if String(parsed.get("kind", "")) == NotationParser.KIND_TURN:
		_turn_header = line.strip_edges()
		return
	if not NotationParser.is_command(parsed):
		return
	if _turn_header.is_empty():
		_turn_header = current_turn_header()
	if not _owns_header(_turn_header):
		return
	if link == null or not link.is_open():
		return
	_send_seq += 1
	link.send(NetMessages.build(NetMessages.CMD, {
		"seq": _send_seq,
		"turn": _turn_header,
		"line": line.strip_edges(),
		"chain": before,
		"count": index,
	}))


func current_turn_header() -> String:
	if level == null or not is_instance_valid(level):
		return ""
	for i in range(level.notation.lines.size() - 1, -1, -1):
		var line: String = String(level.notation.lines[i])
		if String(NotationParser.parse(line).get("kind", "")) == NotationParser.KIND_TURN:
			return line.strip_edges()
	return ""


func _owns_header(header: String) -> bool:
	var id: String = _header_unit(header)
	if id.is_empty():
		return false
	var side: int = PokemonInstanceResource.Team.PLAYER if id.begins_with("P") else PokemonInstanceResource.Team.ENEMY
	return side == local_side


func _header_unit(header: String) -> String:
	var tokens: PackedStringArray = NotationParser.tokenize(header)
	return tokens[1] if tokens.size() > 1 else ""


func _on_round_started() -> void:
	if level == null or link == null or not link.is_open():
		return
	var round_index: int = level.round_index
	_my_rounds[round_index] = chain
	link.send(NetMessages.build(NetMessages.SYNC, {"round": round_index, "chain": chain, "count": line_count}))
	_compare_round(round_index)


func _compare_round(round_index: int) -> void:
	if not _my_rounds.has(round_index) or not _their_rounds.has(round_index):
		return
	if String(_my_rounds[round_index]) != String(_their_rounds[round_index]):
		_raise_desync("round %d state differs" % round_index, true)


func _pump() -> void:
	while not _inbox.is_empty() and String(_inbox[0].get("k", "")) == NetMessages.SYNC:
		var sync: Dictionary = _inbox.pop_front()
		_their_rounds[int(sync.get("round", 0))] = String(sync.get("chain", ""))
		_compare_round(int(sync.get("round", 0)))
	if _inbox.is_empty() or not desync_reason.is_empty():
		return
	if not in_battle() or level == null or not is_instance_valid(level) or level.battle_finished or not ready_to_play():
		return
	var message: Dictionary = _inbox[0]
	var header: String = String(message.get("turn", ""))
	var pawn: TacticsPawn = applier.unit_for_ref(_header_unit(header))
	if pawn == null or not is_instance_valid(pawn):
		_stall_frames += 1
		_check_stall(header)
		return
	var active: BattleUnit = level.scheduler.get_active_unit()
	if active == null or active.pawn != pawn or level.is_presentation_busy():
		if _is_settled_turn(header) and _is_closing_line(String(message.get("line", ""))):
			_inbox.pop_front()
			_expect_seq = int(message.get("seq", _expect_seq + 1))
			_stall_frames = 0
			return
		_stall_frames += 1
		_check_stall(header)
		return
	_stall_frames = 0
	_inbox.pop_front()
	_draining = true
	await _apply_command(message, pawn)
	_draining = false


func _is_settled_turn(header: String) -> bool:
	var tokens: PackedStringArray = NotationParser.tokenize(header)
	if tokens.is_empty() or not tokens[0].begins_with("T"):
		return false
	var number: String = tokens[0].substr(1)
	if not number.is_valid_int():
		return false
	return int(number) <= level.notation.turn_index


func _is_closing_line(line: String) -> bool:
	var verb: String = String(NotationParser.parse(line).get("verb", ""))
	return verb == "end" or verb == "stay"


func _check_stall(header: String) -> void:
	_stall_header = header
	if _stall_frames > STALL_FRAMES:
		_raise_desync("never reached the turn for %s" % header, true)


func _apply_command(message: Dictionary, pawn: TacticsPawn) -> void:
	var seq: int = int(message.get("seq", 0))
	if seq != _expect_seq + 1:
		_raise_desync("out of order decision (%d after %d)" % [seq, _expect_seq], true)
		return
	_expect_seq = seq
	var header: String = String(message.get("turn", ""))
	var line: String = String(message.get("line", ""))
	if _owns_header(header):
		_raise_desync("received a decision for our own unit (%s)" % header, true)
		return
	var theirs: String = String(message.get("chain", ""))
	if theirs != chain:
		_raise_desync("battle state differs before line %d (%s)" % [int(message.get("count", -1)), line], true)
		return
	applier.current_unit = pawn
	await applier.apply(line)


func _raise_desync(reason: String, tell_peer: bool) -> void:
	if not desync_reason.is_empty():
		return
	desync_reason = reason
	if tell_peer and link != null and link.is_open():
		link.send(NetMessages.build(NetMessages.DESYNC, {"reason": reason, "count": line_count, "mine": chain}))
	if level != null and is_instance_valid(level):
		level.battle_label = "%s_desync" % level.battle_label
		level.notation.save()
	notice.emit("Desync: %s" % reason)
	desynced.emit(reason)
	_finish_remote(TacticsLevel.RESULT_ONGOING, "desync")


func resign() -> void:
	if link != null and link.is_open():
		link.send(NetMessages.build(NetMessages.RESIGN, {"battle_id": battle_id}))
	_finish_remote(_local_loss_result(), "resign")


func _on_battle_ended(result: int) -> void:
	_set_state(ENDED)


func _finish_remote(result: int, reason: String) -> void:
	if level != null and is_instance_valid(level) and not level.battle_finished:
		level.finish_battle(result, reason)
	_set_state(ENDED)
	battle_over_remote.emit(result, reason)


func _local_win_result() -> int:
	return TacticsLevel.RESULT_PLAYER_WIN if local_side == PokemonInstanceResource.Team.PLAYER else TacticsLevel.RESULT_PLAYER_LOSS


func _local_loss_result() -> int:
	return TacticsLevel.RESULT_PLAYER_LOSS if local_side == PokemonInstanceResource.Team.PLAYER else TacticsLevel.RESULT_PLAYER_WIN


func _remote_label() -> String:
	return remote_name if not remote_name.is_empty() else "the other player"


func _set_state(next: int) -> void:
	if state == next:
		return
	state = next
	state_changed.emit(state)


func _reset_battle_state() -> void:
	detach_level()
	_inbox.clear()
	_ready_local = false
	_ready_remote = false
	battle_id = ""
	pending_code = ""


func _auto_play_step() -> void:
	if level == null or not is_instance_valid(level) or level.battle_finished or not ready_to_play():
		return
	if _draining:
		return
	var unit: BattleUnit = level.scheduler.get_active_unit()
	if unit == null or unit.team != local_side or unit.pawn == null or not unit.pawn.is_alive():
		return
	if level.is_presentation_busy() or level.participant.res.stage > level.participant.res.STAGE_SHOW_ACTIONS:
		return
	_auto_busy = true
	_auto_turn(unit.pawn)


func _auto_turn(pawn: TacticsPawn) -> void:
	var allies: Array = pawn.get_parent().get_children()
	var enemies: Array = (level.opponent if pawn.get_parent() == level.player else level.player).get_children()
	var brain := MinimumViableAI.new()
	level.arena.reset_all_tile_markers()
	level.arena.process_surrounding_tiles(pawn.get_tile(), pawn.stats.movement, allies)
	level.arena.mark_reachable_tiles(pawn.get_tile(), pawn.stats.movement)
	var action: AIAction = brain.choose_action(pawn, allies, enemies, level.get_type_chart(), level)
	if action.move_index < 0 or action.target_unit == null:
		var destination: TacticsTile = level.arena.get_nearest_target_adjacent_tile(pawn, enemies)
		if destination != null and destination != pawn.get_tile() and destination.reachable:
			await applier.apply_move(pawn, level.notation.tile_label(Targeting._tile_key(destination)))
		level.arena.reset_all_tile_markers()
		action = brain.choose_action(pawn, allies, enemies, level.get_type_chart(), level)
	if is_instance_valid(pawn) and pawn.is_alive() and action.move_index >= 0 and action.target_unit != null and is_instance_valid(action.target_unit):
		await applier.apply_attack(pawn, action.move_index, action.target_unit)
	if is_instance_valid(pawn) and level != null and is_instance_valid(level) and not level.battle_finished:
		if not level.multiverse.pending_travel.is_empty():
			applier.apply_stay(pawn)
		await applier.apply_end_turn(pawn)
	_auto_busy = false
