class_name TacticsLevel
extends Node3D

signal battle_ended(result: int)

const RESULT_ONGOING: int = 0
const RESULT_PLAYER_WIN: int = 1
const RESULT_PLAYER_LOSS: int = 2
const TYPE_CHART_PATH: String = "res://data/models/pokemon/generated/types/type_chart.tres"
const STATUS_BURN: String = "burn"
const STATUS_POISON: String = "poison"
const STATUS_TOXIC: String = "poison_toxic"
const STATUS_LEECH_SEED: String = "leech_seed"
const STATUS_INGRAIN: String = "ingrain"
const STATUS_AQUA_RING: String = "aqua_ring"
const STATUS_HEAL_BLOCK: String = "heal_block"
const STATUS_PARALYZE: String = "paralyze"
const SCREEN_CONDITIONS: Array[String] = ["light_screen", "reflect", "safeguard", "lucky_chant", "mist"]

@export var camera: TacticsCameraResource = load("res://data/models/view/camera/tactics/camera.tres")
@export var camera_boundary_radius: float = 10.0
@export var ui_control: TacticsControlsResource = load("res://data/models/view/control/tactics/control.tres")
@export var use_speed_scheduler: bool = true
@export var battle_seed: int = 0
var participant: TacticsParticipant
var player: TacticsPlayer = null
var opponent: TacticsOpponent
var arena: TacticsArena
var turn_stage: int = 0
var battle_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var battle_log: BattleLog = BattleLog.new()
var intrinsic_service: BattleIntrinsicService = BattleIntrinsicService.new()
var battle_conditions: Dictionary = {}
var battle_finished: bool = false
var scheduler: BattleScheduler = null
var battle_units: Array[BattleUnit] = []
var _scheduler_started: bool = false
var _type_chart: TypeChartResource = null

func _ready() -> void:
	battle_rng.seed = battle_seed
	battle_log.event_appended.connect(_on_battle_event_appended)
	if not ui_control:
		push_error("TacticsControls needs a ControlResource from /data/models/view/control/tactics/")
	if not camera:
		push_error("TacticsCamera needs a CameraResource from /data/models/view/camera/tactics/")

	participant = $TacticsParticipant
	player = $TacticsParticipant/TacticsPlayer
	opponent = $TacticsParticipant/TacticsOpponent
	arena = $TacticsArena

	arena.configure_tiles()
	participant.configure(camera, ui_control)

	if camera.boundary_radius != camera_boundary_radius:
		camera.boundary_radius = camera_boundary_radius

	if use_speed_scheduler:
		scheduler = BattleScheduler.new()
		scheduler.turn_started.connect(_on_turn_started)
		scheduler.turn_completed.connect(_on_turn_completed)
		scheduler.round_started.connect(_on_round_started)

func _physics_process(delta: float) -> void:
	if battle_finished:
		return
	if use_speed_scheduler:
		_run_scheduler_loop(delta)
	else:
		match turn_stage:
			0: _init_turn()
			1: _handle_turn(delta)
	_check_and_handle_battle_end()

func _init_turn() -> void:
	if participant.is_configured(player) and participant.is_configured(opponent):
		turn_stage = 1

func _handle_turn(delta: float) -> void:
	DebugLog.debug_nospam("player_can_act", participant.can_act(player))

	if participant.can_act(player):
		if not participant.is_configured(player):
			participant.configure(camera, ui_control)
		participant.act(delta, true, player)

	elif participant.can_act(opponent):
		if not participant.is_configured(opponent):
			participant.configure(camera, ui_control)
		participant.act(delta, false, opponent)

	else:
		if DebugLog.debug_enabled:
			print_rich("[color=green]0Oo◦° O-----------------------------------O °◦oO0[/color]")
			print_rich("[color=green]0Oo◦°[/color][color=red] >}=----->> [/color][color=yellow][ Turn reset! ][/color][color=red] <<-----={< [/color][color=green]°◦oO0[/color]")
			print_rich("[color=green]0Oo◦° O-----------------------------------O °◦oO0[/color]")
		player.reset_turn(player)
		opponent.reset_turn(opponent)


func _run_scheduler_loop(delta: float) -> void:
	if not _scheduler_started:
		if not (participant.is_configured(player) and participant.is_configured(opponent)):
			return
		_start_scheduler()
		return

	_sweep_fainted_units()

	var unit: BattleUnit = scheduler.get_active_unit()
	if unit == null:
		return

	var pawn: TacticsPawn = unit.pawn
	if pawn == null or not pawn.is_alive():
		scheduler.remove_unit(unit)
		return

	if not pawn.can_act():
		scheduler.complete_active_unit()
		return

	if participant.res.stage == participant.res.STAGE_SELECT_PAWN:
		participant.res.stage = participant.res.STAGE_SHOW_ACTIONS
		participant.res.curr_pawn = pawn

	var actor_parent: Node3D = player if unit.team == PokemonInstanceResource.Team.PLAYER else opponent
	var target_parent: Node3D = opponent if unit.team == PokemonInstanceResource.Team.PLAYER else player
	var is_human: bool = unit.control_type == PokemonInstanceResource.ControlType.PLAYER

	if not participant.is_configured(actor_parent):
		participant.configure(camera, ui_control)

	participant.act(delta, is_human, actor_parent, target_parent)
	_sweep_fainted_units()


func _start_scheduler() -> void:
	battle_conditions = {}
	battle_units = _build_battle_units()
	intrinsic_service.log_battle_start(battle_units, battle_log, self)
	intrinsic_service.apply_speed_modifiers(battle_units, self, battle_log)
	scheduler.start_battle(battle_units, int(battle_rng.seed))
	_scheduler_started = true


func _build_battle_units() -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	var insertion: int = 0
	for team_node in [player, opponent]:
		var team_kind: int = PokemonInstanceResource.Team.PLAYER if team_node == player else PokemonInstanceResource.Team.ENEMY
		for child in team_node.get_children():
			if child is TacticsPawn:
				var p: TacticsPawn = child
				var control_kind: int = PokemonInstanceResource.ControlType.PLAYER if team_node == player else PokemonInstanceResource.ControlType.AI
				if p.stats != null and p.stats.pokemon_instance != null:
					control_kind = p.stats.pokemon_instance.control_type
				out.append(BattleUnit.new(p, p.stats, team_kind, control_kind, insertion))
				insertion += 1
	return out


func _sweep_fainted_units() -> void:
	if scheduler == null:
		return
	for unit in battle_units:
		if unit.pawn == null:
			continue
		if not unit.is_alive():
			scheduler.remove_unit(unit)


func _on_turn_started(unit: BattleUnit) -> void:
	if unit == null or unit.pawn == null:
		return
	var pawn: TacticsPawn = unit.pawn
	if not pawn.is_alive():
		return
	_process_turn_start_statuses(pawn)
	if not pawn.is_alive():
		return
	intrinsic_service.on_turn_started(pawn, self, battle_log)
	pawn.reset_turn()
	pawn.res.has_acted_this_round = false
	pawn.res.use_legacy_attack_fallback = false
	if not pawn.stats.move_slots.is_empty():
		var idx: int = pawn.stats.first_usable_move_index(false)
		pawn.res.selected_move_index = max(0, idx)

	var p_res: TacticsParticipantResource = participant.res
	p_res.curr_pawn = pawn
	p_res.stage = p_res.STAGE_SHOW_ACTIONS
	p_res.attackable_pawn = null
	p_res.display_opponent_stats = false
	p_res.turn_just_started = false
	camera.target = pawn

	battle_log.append({
		"kind": "turn_started",
		"unit": pawn,
		"team": unit.team,
	})
	var skip_status: Dictionary = pawn.stats.consume_turn_skip_status()
	var skip_status_id: String = String(skip_status.get("status_id", ""))
	if not skip_status_id.is_empty():
		if bool(skip_status.get("removed", false)):
			battle_log.append({
				"kind": "status_removed",
				"unit": pawn,
				"status_id": skip_status_id,
				"source": "turn_skip_consumed",
			})
		pawn.end_pawn_turn()
		pawn.res.has_acted_this_round = true
		battle_log.append({
			"kind": "turn_skipped",
			"unit": pawn,
			"team": unit.team,
			"status_id": skip_status_id,
		})
		scheduler.skip_active_unit(skip_status_id)
		return


func _expire_turn_start_statuses(pawn: TacticsPawn) -> void:
	if pawn == null or pawn.stats == null:
		return
	for status_id: String in ["protect", "counter"]:
		var removed: Dictionary = pawn.stats.remove_battle_status(status_id)
		if removed.is_empty():
			continue
		battle_log.append({
			"kind": "status_removed",
			"unit": pawn,
			"status_id": status_id,
			"source": "turn_start",
		})


func _process_turn_start_statuses(pawn: TacticsPawn) -> void:
	if pawn == null or pawn.stats == null:
		return
	_expire_turn_start_statuses(pawn)
	_process_status_turn_effects(pawn)
	_prepare_paralysis_skip(pawn)
	_decrement_status_counters(pawn)


func _process_status_turn_effects(pawn: TacticsPawn) -> void:
	if pawn == null or pawn.stats == null or not pawn.stats.is_active():
		return
	if pawn.stats.battle_statuses.has(STATUS_BURN):
		_apply_status_damage(pawn, STATUS_BURN, 8)
	if pawn.stats.battle_statuses.has(STATUS_POISON):
		_apply_status_damage(pawn, STATUS_POISON, _status_hp_fraction(pawn, STATUS_POISON, 16))
	if pawn.stats.battle_statuses.has(STATUS_TOXIC):
		var toxic_payload: Dictionary = _status_payload(pawn, STATUS_TOXIC)
		var stage: int = maxi(1, int(toxic_payload.get("toxic_stage", 1)))
		_apply_status_damage(pawn, STATUS_TOXIC, _status_hp_fraction(pawn, STATUS_TOXIC, 16), stage)
		toxic_payload["toxic_stage"] = stage + 1
		pawn.stats.battle_statuses[STATUS_TOXIC] = toxic_payload
	if pawn.stats.battle_statuses.has(STATUS_LEECH_SEED):
		_apply_leech_seed(pawn)
	if pawn.stats.battle_statuses.has(STATUS_INGRAIN):
		_apply_status_heal(pawn, STATUS_INGRAIN, _status_hp_fraction(pawn, STATUS_INGRAIN, 6))
	if pawn.stats.battle_statuses.has(STATUS_AQUA_RING):
		_apply_status_heal(pawn, STATUS_AQUA_RING, _status_hp_fraction(pawn, STATUS_AQUA_RING, 8))


func _prepare_paralysis_skip(pawn: TacticsPawn) -> void:
	if pawn == null or pawn.stats == null or not pawn.stats.battle_statuses.has(STATUS_PARALYZE):
		return
	var payload: Dictionary = _status_payload(pawn, STATUS_PARALYZE)
	var recent: bool = bool(payload.get("recent", false))
	payload["skip_turn"] = recent
	payload["recent"] = not recent
	pawn.stats.battle_statuses[STATUS_PARALYZE] = payload


func _decrement_status_counters(pawn: TacticsPawn) -> void:
	if pawn == null or pawn.stats == null:
		return
	var status_ids: Array[String] = []
	for status_id in pawn.stats.battle_statuses.keys():
		status_ids.append(String(status_id))
	for status_id in status_ids:
		if not pawn.stats.battle_statuses.has(status_id):
			continue
		var payload: Variant = pawn.stats.battle_statuses[status_id]
		if not (payload is Dictionary):
			continue
		var data: Dictionary = (payload as Dictionary).duplicate(true)
		if not data.has("counter"):
			continue
		var next_counter: int = int(data.get("counter", 0)) - 1
		if next_counter <= 0:
			var removed: Dictionary = pawn.stats.remove_battle_status(status_id)
			if not removed.is_empty():
				battle_log.append({
					"kind": "status_removed",
					"unit": pawn,
					"status_id": status_id,
					"source": "counter_expired",
				})
				if SCREEN_CONDITIONS.has(status_id):
					refresh_team_battle_condition(status_id, pawn)
			continue
		data["counter"] = next_counter
		pawn.stats.battle_statuses[status_id] = data


func _apply_status_damage(pawn: TacticsPawn, status_id: String, hp_fraction: int, multiplier: int = 1) -> int:
	if pawn == null or pawn.stats == null or not pawn.stats.is_active():
		return 0
	var amount: int = maxi(1, int(floor(float(pawn.stats.max_health) / float(maxi(1, hp_fraction)))) * maxi(1, multiplier))
	var before: int = pawn.stats.curr_health
	pawn.stats.apply_to_curr_health(-amount)
	var applied: int = before - pawn.stats.curr_health
	battle_log.append({
		"kind": "status_tick",
		"unit": pawn,
		"status_id": status_id,
		"amount": applied,
		"before": before,
		"after": pawn.stats.curr_health,
	})
	if before > 0 and not pawn.stats.is_active():
		battle_log.append({
			"kind": "unit_fainted",
			"unit": pawn,
			"source": status_id,
		})
	return applied


func _apply_status_heal(pawn: TacticsPawn, status_id: String, hp_fraction: int) -> int:
	if pawn == null or pawn.stats == null or not pawn.stats.is_active():
		return 0
	if pawn.stats.battle_statuses.has(STATUS_HEAL_BLOCK):
		battle_log.append({
			"kind": "status_heal_blocked",
			"unit": pawn,
			"status_id": status_id,
			"blocked_by": STATUS_HEAL_BLOCK,
		})
		return 0
	var amount: int = maxi(1, int(floor(float(pawn.stats.max_health) / float(maxi(1, hp_fraction)))))
	var before: int = pawn.stats.curr_health
	pawn.stats.apply_to_curr_health(amount)
	var applied: int = pawn.stats.curr_health - before
	if applied <= 0:
		return 0
	battle_log.append({
		"kind": "status_healed",
		"unit": pawn,
		"status_id": status_id,
		"amount": applied,
		"before": before,
		"after": pawn.stats.curr_health,
	})
	return applied


func _apply_leech_seed(pawn: TacticsPawn) -> void:
	var payload: Dictionary = _status_payload(pawn, STATUS_LEECH_SEED)
	var damage: int = _apply_status_damage(pawn, STATUS_LEECH_SEED, _status_hp_fraction(pawn, STATUS_LEECH_SEED, 12))
	if damage <= 0:
		return
	var source: Variant = payload.get("source_unit", null)
	if source is TacticsPawn:
		var source_pawn: TacticsPawn = source
		if source_pawn != pawn and source_pawn.stats != null and source_pawn.stats.is_active():
			_apply_status_heal_flat(source_pawn, STATUS_LEECH_SEED, damage)


func _apply_status_heal_flat(pawn: TacticsPawn, status_id: String, amount: int) -> int:
	if pawn == null or pawn.stats == null or not pawn.stats.is_active() or amount <= 0:
		return 0
	if pawn.stats.battle_statuses.has(STATUS_HEAL_BLOCK):
		return 0
	var before: int = pawn.stats.curr_health
	pawn.stats.apply_to_curr_health(amount)
	var applied: int = pawn.stats.curr_health - before
	if applied > 0:
		battle_log.append({
			"kind": "status_healed",
			"unit": pawn,
			"status_id": status_id,
			"amount": applied,
			"before": before,
			"after": pawn.stats.curr_health,
		})
	return applied


func _status_payload(pawn: TacticsPawn, status_id: String) -> Dictionary:
	if pawn == null or pawn.stats == null:
		return {}
	var payload: Variant = pawn.stats.battle_statuses.get(status_id, {})
	return (payload as Dictionary).duplicate(true) if payload is Dictionary else {}


func _status_hp_fraction(pawn: TacticsPawn, status_id: String, fallback: int) -> int:
	var payload: Dictionary = _status_payload(pawn, status_id)
	return maxi(1, int(payload.get("hp_fraction", fallback)))


func _on_turn_completed(unit: BattleUnit) -> void:
	if unit == null or unit.pawn == null:
		return
	unit.pawn.res.has_acted_this_round = true


func _on_round_started() -> void:
	for unit in battle_units:
		if unit.pawn != null:
			unit.pawn.res.has_acted_this_round = false


func get_type_chart() -> TypeChartResource:
	if _type_chart == null:
		_type_chart = load(TYPE_CHART_PATH) as TypeChartResource
	return _type_chart


func set_battle_condition(condition_id: String, payload: Dictionary = {}) -> void:
	var key: String = condition_id.strip_edges().to_lower()
	if key.is_empty():
		return
	var stored: Dictionary = payload.duplicate(true)
	stored["condition_id"] = key
	battle_conditions[key] = stored


func has_battle_condition(condition_id: String) -> bool:
	var key: String = condition_id.strip_edges().to_lower()
	return not key.is_empty() and battle_conditions.has(key)


func set_team_battle_condition(condition_id: String, unit: TacticsPawn, payload: Dictionary = {}) -> void:
	var key: String = condition_id.strip_edges().to_lower()
	var team_key: String = _team_condition_key(unit)
	if key.is_empty() or team_key.is_empty():
		return
	var stored: Dictionary = battle_condition(key)
	var raw_teams: Variant = stored.get("teams", {})
	var teams: Dictionary = (raw_teams as Dictionary).duplicate(true) if raw_teams is Dictionary else {}
	var team_payload: Dictionary = payload.duplicate(true)
	team_payload["condition_id"] = key
	team_payload["team"] = team_key
	teams[team_key] = team_payload
	stored["condition_id"] = key
	stored["teams"] = teams
	battle_conditions[key] = stored


func has_team_battle_condition(condition_id: String, unit: TacticsPawn) -> bool:
	var key: String = condition_id.strip_edges().to_lower()
	var team_key: String = _team_condition_key(unit)
	if key.is_empty() or team_key.is_empty() or not battle_conditions.has(key):
		return false
	var stored: Dictionary = battle_condition(key)
	var teams: Variant = stored.get("teams", {})
	return teams is Dictionary and (teams as Dictionary).has(team_key)


func refresh_team_battle_condition(condition_id: String, unit: TacticsPawn) -> void:
	var key: String = condition_id.strip_edges().to_lower()
	var team_key: String = _team_condition_key(unit)
	if key.is_empty() or team_key.is_empty() or not battle_conditions.has(key):
		return
	if _team_has_status(team_key, key):
		return
	var stored: Dictionary = battle_condition(key)
	var teams: Variant = stored.get("teams", {})
	if not (teams is Dictionary):
		return
	var team_map: Dictionary = (teams as Dictionary).duplicate(true)
	team_map.erase(team_key)
	if team_map.is_empty():
		battle_conditions.erase(key)
		return
	stored["teams"] = team_map
	battle_conditions[key] = stored


func battle_condition(condition_id: String) -> Dictionary:
	var key: String = condition_id.strip_edges().to_lower()
	var raw: Variant = battle_conditions.get(key, {})
	return raw.duplicate(true) if raw is Dictionary else {}


func current_weather() -> String:
	for key in ["rain", "sunny", "sandstorm", "hail", "snow"]:
		if battle_conditions.has(key):
			return key
	return ""


func _team_condition_key(unit: TacticsPawn) -> String:
	if unit == null:
		return ""
	if player != null and _node_contains(player, unit):
		return "player"
	if opponent != null and _node_contains(opponent, unit):
		return "enemy"
	if unit.stats != null and unit.stats.pokemon_instance != null:
		return str(unit.stats.pokemon_instance.team)
	var parent: Node = unit.get_parent()
	return str(parent.get_instance_id()) if parent != null else ""


func _team_has_status(team_key: String, status_id: String) -> bool:
	for unit in _team_pawns_for_key(team_key):
		if unit != null and unit.stats != null and unit.stats.battle_statuses.has(status_id):
			return true
	return false


func _team_pawns_for_key(team_key: String) -> Array[TacticsPawn]:
	var out: Array[TacticsPawn] = []
	for node in [player, opponent]:
		if node == null:
			continue
		var key: String = "player" if node == player else "enemy"
		if key != team_key:
			continue
		for child in node.get_children():
			if child is TacticsPawn:
				out.append(child)
	return out


func _node_contains(parent: Node, child: Node) -> bool:
	var current: Node = child
	while current != null:
		if current == parent:
			return true
		current = current.get_parent()
	return false


func check_battle_end(player_units: Array, enemy_units: Array) -> int:
	if _all_fainted(enemy_units):
		return RESULT_PLAYER_WIN
	if _all_fainted(player_units):
		return RESULT_PLAYER_LOSS
	return RESULT_ONGOING


func _check_and_handle_battle_end() -> void:
	if player == null or opponent == null:
		return
	if use_speed_scheduler:
		if not _scheduler_started:
			return
		if not scheduler.is_battle_over():
			return
	var result: int = check_battle_end(player.get_children(), opponent.get_children())
	if result == RESULT_ONGOING:
		if not use_speed_scheduler:
			return
		result = RESULT_PLAYER_LOSS

	battle_finished = true
	turn_stage = 2
	_refill_pp_for_units(player.get_children())
	_refill_pp_for_units(opponent.get_children())
	battle_log.append({
		"kind": "battle_ended",
		"winner": "player" if result == RESULT_PLAYER_WIN else "opponent",
	})
	battle_ended.emit(result)
	if ui_control != null:
		ui_control.set_actions_menu_visibility(false, null)


func _all_fainted(units: Array) -> bool:
	var saw_unit: bool = false
	for unit in units:
		if not unit is TacticsPawn:
			continue
		saw_unit = true
		if unit.is_alive():
			return false
	return saw_unit


func _refill_pp_for_units(units: Array) -> void:
	for unit in units:
		if unit is TacticsPawn:
			unit.stats.refill_all_pp()


func _on_battle_event_appended(event: Dictionary) -> void:
	print_rich("[color=gray]battle:[/color] %s" % _format_battle_event(event))


func _format_battle_event(event: Dictionary) -> String:
	var readable: Dictionary = event.duplicate()
	for key in ["attacker", "defender", "unit"]:
		if readable.has(key) and readable[key] is Node:
			readable[key] = (readable[key] as Node).name
	return str(readable)
