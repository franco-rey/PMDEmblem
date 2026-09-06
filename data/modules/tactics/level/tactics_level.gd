class_name TacticsLevel
extends Node3D

signal battle_ended(result: int)
signal weather_changed(weather_id: String)

const RESULT_ONGOING: int = 0
const RESULT_PLAYER_WIN: int = 1
const RESULT_PLAYER_LOSS: int = 2
const TYPE_CHART_PATH: String = "res://data/models/pokemon/generated/types/type_chart.tres"
const STATUS_BURN: String = "burn"
const STATUS_POISON: String = "poison"
const STATUS_TOXIC: String = "poison_toxic"
const STATUS_LEECH_SEED: String = "leech_seed"
const STATUS_INGRAIN: String = "ingrain"
const STATUS_SLEEP: String = "sleep"
const STATUS_CONFUSE: String = "confuse"
const RAMPAGE_STATUSES: Array[String] = ["outrage", "thrash", "petal_dance"]
const TRAP_STATUSES: Array[String] = ["bind", "wrap", "clamp", "fire_spin", "sand_tomb", "whirlpool", "magma_storm", "infestation"]
const STATUS_AQUA_RING: String = "aqua_ring"
const STATUS_HEAL_BLOCK: String = "heal_block"
const STATUS_PARALYZE: String = "paralyze"
const SCREEN_CONDITIONS: Array[String] = ["light_screen", "reflect", "safeguard", "lucky_chant", "mist"]

@export var camera: TacticsCameraResource = load("res://data/models/view/camera/tactics/camera.tres")
@export var camera_boundary_radius: float = 10.0
@export var ui_control: TacticsControlsResource = load("res://data/models/view/control/tactics/control.tres")
@export var use_speed_scheduler: bool = true
@export var battle_seed: int = 0
const SKY_TOP_COLOR: Color = Color(0.30, 0.56, 0.95)
const SKY_HORIZON_COLOR: Color = Color(0.80, 0.88, 0.98)
const GROUND_BOTTOM_COLOR: Color = Color(0.22, 0.28, 0.40)
const GROUND_HORIZON_COLOR: Color = Color(0.62, 0.70, 0.84)
const AMBIENT_COLOR: Color = Color(0.72, 0.74, 0.80)
var participant: TacticsParticipant
var player: TacticsPlayer = null
var opponent: TacticsOpponent
var arena: TacticsArena
var turn_stage: int = 0
var battle_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var hazard_service: BattleHazardService = null
var battle_log: BattleLog = BattleLog.new()
var intrinsic_service: BattleIntrinsicService = BattleIntrinsicService.new()
var state_ops: BattleStateOps = null
var battle_conditions: Dictionary = {}
var message_log: BattleMessageLog = null
var hud: BattleHud = null
var notation: BattleNotation = BattleNotation.new()
var notation_context: Dictionary = {}
var battle_label: String = ""
var weather_overlay: WeatherOverlay = null
var floating_text: BattleFloatingText = null
var sound_cues: BattleSoundCues = null
var banner: BattleBanner = null
var terrain_overlay: TerrainOverlay = null
var stats_tracker: BattleStatsTracker = BattleStatsTracker.new()
var intro_pending: bool = false
var interface_visible: bool = true
var round_index: int = 0
var multiverse: MultiverseController = MultiverseController.new()
var multiverse_enabled: bool = false
var timeline_map: TimelineMap = null
var multiverse_stage: MultiverseStage = null
var multiverse_fx: MultiverseFx = null
var multiverse_minimap: MultiverseMinimap = null
var battle_finished: bool = false
var net_session: Node = null
var scheduler: BattleScheduler = null
var battle_units: Array[BattleUnit] = []
var presentation_runner: BattlePresentationRunner = null
var vfx_player: BattleVFXPlayer = null
var force_timed_presentation: bool = false
var landed_items: Dictionary = {}
var _scheduler_started: bool = false
var _type_chart: TypeChartResource = null

func _ready() -> void:
	battle_rng.seed = battle_seed
	battle_log.event_appended.connect(_on_battle_event_appended)
	_ops()
	_setup_presentation()
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
	if not camera.edge_pan_toggled.is_connected(_on_edge_pan_toggled):
		camera.edge_pan_toggled.connect(_on_edge_pan_toggled)

	if use_speed_scheduler:
		scheduler = BattleScheduler.new()
		scheduler.turn_started.connect(_on_turn_started)
		scheduler.turn_completed.connect(_on_turn_completed)
		scheduler.round_building.connect(_on_round_building)
		scheduler.round_started.connect(_on_round_started)
		multiverse.setup(self)
		scheduler.round_gate = multiverse.round_gate

func ensure_multiverse_presentation() -> void:
	if multiverse_stage != null and is_instance_valid(multiverse_stage):
		return
	multiverse_stage = MultiverseStage.new()
	add_child(multiverse_stage)
	multiverse_stage.setup(self)
	multiverse.stage = multiverse_stage
	multiverse_fx = MultiverseFx.new()
	add_child(multiverse_fx)
	multiverse.fx = multiverse_fx
	multiverse_minimap = MultiverseMinimap.new()
	multiverse_minimap.setup(self, multiverse_stage)
	if hud != null:
		hud.set_corner_control(multiverse_minimap, MultiverseMinimap.DIAMETER)
	else:
		add_child(multiverse_minimap)
	multiverse.minimap = multiverse_minimap
	camera.boundary_radius = camera_boundary_radius + MultiverseStage.pitch * 4.0
	camera.max_overview = 160.0


func set_interface_visible(value: bool) -> void:
	interface_visible = value
	for layer in [hud, message_log, banner]:
		if layer != null and is_instance_valid(layer):
			layer.visible = value


func _unhandled_input(event: InputEvent) -> void:
	if multiverse_enabled and timeline_map != null and event.is_action_pressed("toggle_timeline_map") and not battle_finished:
		timeline_map.toggle()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if battle_finished:
		return
	if ui_control != null:
		ui_control.move_camera(delta)
		ui_control.camera_rotation_inputs(delta)
	if use_speed_scheduler:
		_run_scheduler_loop(delta)
	else:
		match turn_stage:
			0: _init_turn()
			1: _handle_turn(delta)
	_check_and_handle_battle_end()

func _setup_presentation() -> void:
	vfx_player = BattleVFXPlayer.new()
	vfx_player.name = "BattleVFXPlayer"
	vfx_player.setup(battle_seed, battle_log)
	add_child(vfx_player)
	presentation_runner = BattlePresentationRunner.new()
	presentation_runner.name = "BattlePresentationRunner"
	presentation_runner.battle_log = battle_log
	presentation_runner.vfx_player = vfx_player
	presentation_runner.immediate_mode = DisplayServer.get_name() == "headless" and not force_timed_presentation
	add_child(presentation_runner)
	message_log = BattleMessageLog.new()
	message_log.setup(battle_log)
	add_child(message_log)
	hud = BattleHud.new()
	add_child(hud)
	hud.setup(self)
	weather_overlay = WeatherOverlay.new()
	add_child(weather_overlay)
	weather_changed.connect(weather_overlay.set_weather)
	floating_text = BattleFloatingText.new()
	floating_text.name = "BattleFloatingText"
	add_child(floating_text)
	floating_text.setup(self)
	sound_cues = BattleSoundCues.new()
	sound_cues.name = "BattleSoundCues"
	add_child(sound_cues)
	sound_cues.setup(self)
	timeline_map = TimelineMap.new()
	add_child(timeline_map)
	timeline_map.setup(self)
	banner = BattleBanner.new()
	add_child(banner)
	banner.setup(self)
	terrain_overlay = TerrainOverlay.new()
	add_child(terrain_overlay)
	terrain_overlay.setup(self)
	stats_tracker.setup(battle_log)
	_ensure_sky()


func _ensure_sky() -> void:
	if find_children("*", "WorldEnvironment", true, false).size() > 0:
		return
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = SKY_TOP_COLOR
	sky_material.sky_horizon_color = SKY_HORIZON_COLOR
	sky_material.ground_bottom_color = GROUND_BOTTOM_COLOR
	sky_material.ground_horizon_color = GROUND_HORIZON_COLOR
	sky_material.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = AMBIENT_COLOR
	environment.ambient_light_energy = 1.0
	var world_environment := WorldEnvironment.new()
	world_environment.name = "SkyEnvironment"
	world_environment.environment = environment
	add_child(world_environment)


func is_presentation_busy() -> bool:
	return presentation_runner != null and presentation_runner.is_busy()


func charging_payload(pawn: TacticsPawn) -> Dictionary:
	if pawn == null or pawn.stats == null:
		return {}
	var payload: Variant = pawn.stats.battle_statuses.get("charging", null)
	return payload if payload is Dictionary else {}


func charging_slot(pawn: TacticsPawn) -> int:
	var move_id: String = String(charging_payload(pawn).get("move_id", ""))
	if move_id.is_empty():
		return -1
	for i in range(pawn.stats.move_slots.size()):
		var move: PokemonMoveResource = pawn.stats.move_slots[i]
		if move != null and move.move_id == move_id:
			return i
	return -1


func charging_release_target(pawn: TacticsPawn) -> TacticsPawn:
	var slot: int = charging_slot(pawn)
	if slot < 0:
		return null
	var move: PokemonMoveResource = pawn.stats.move_slots[slot]
	var legal: Array[TacticsPawn] = Targeting.legal_targets_for_move(pawn, move, units_on_map())
	var declared: Variant = charging_payload(pawn).get("target_unit", null)
	if declared is TacticsPawn and is_instance_valid(declared) and legal.has(declared):
		return declared
	var best: TacticsPawn = null
	var best_distance: float = INF
	for candidate in legal:
		var distance: float = candidate.global_position.distance_squared_to(pawn.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func release_charge(pawn: TacticsPawn) -> bool:
	var slot: int = charging_slot(pawn)
	if slot < 0:
		return false
	var target: TacticsPawn = charging_release_target(pawn)
	if target == null:
		cancel_charge(pawn, "no_target")
		return false
	var p_res: TacticsParticipantResource = participant.res
	var charged_move: String = String(charging_payload(pawn).get("move_id", ""))
	if multiverse.enabled and bool(multiverse.travel_rule(charged_move).get("strike", false)) and not multiverse.strike_hop_declined.has(pawn) and multiverse.request_travel(charged_move, pawn, null) > 0:
		multiverse.strike_hop_declined[pawn] = true
		p_res.curr_pawn = pawn
		if pawn.stats.pokemon_instance != null and pawn.stats.pokemon_instance.control_type == PokemonInstanceResource.ControlType.PLAYER:
			p_res.stage = p_res.STAGE_SELECT_TRAVEL
			return true
		var choice: int = multiverse.cpu_choice()
		if choice >= 0 and multiverse.commit_travel(choice):
			return true
		multiverse.cancel_travel()
	pawn.res.can_attack = true
	pawn.res.can_move = false
	pawn.res.selected_move_index = slot
	p_res.curr_pawn = pawn
	p_res.attackable_pawn = target
	p_res.pending_intent = null
	p_res.throw_options = []
	p_res.display_opponent_stats = true
	p_res.stage = p_res.STAGE_ATTACK
	battle_log.append({"kind": "charge_released", "attacker": pawn, "move_id": pawn.stats.move_slots[slot].move_id, "target": target})
	return true


func cancel_charge(pawn: TacticsPawn, reason: String) -> void:
	var move_id: String = String(charging_payload(pawn).get("move_id", ""))
	if move_id.is_empty():
		return
	var ops: BattleStateOps = _ops()
	ops.remove_status(pawn, "charging", {"source": reason})
	for status_id in BattleMoveSpecials.INVULNERABLE_STATUSES:
		if pawn.stats.battle_statuses.has(status_id):
			ops.remove_status(pawn, status_id, {"source": reason})
	battle_log.append({"kind": "move_rejected", "attacker": pawn, "move_id": move_id, "reason": "charge_%s" % reason})


func land_item(item_id: String, key: Vector3i, world_position: Vector3, source: String = "", defer_visual: bool = false) -> void:
	if item_id.is_empty():
		return
	remove_landed_item(key)
	landed_items[key] = {"item_id": item_id, "node": null, "source": source, "world_position": world_position}
	battle_log.append({"kind": "item_landed", "item_id": item_id, "tile": key, "source": source})
	if not defer_visual:
		show_landed_item(key)


func show_landed_item(key: Vector3i) -> void:
	var record: Variant = landed_items.get(key, null)
	if not (record is Dictionary):
		return
	var existing: Variant = (record as Dictionary).get("node", null)
	if existing is Node and is_instance_valid(existing):
		return
	var item_id: String = String((record as Dictionary).get("item_id", ""))
	var world_position: Vector3 = (record as Dictionary).get("world_position", Vector3.ZERO)
	var sprite := Sprite3D.new()
	sprite.name = "LandedItem_%s_%d_%d" % [item_id, key.x, key.z]
	var item: PokemonItemResource = PokemonItemService.load_item(item_id)
	if item != null and not item.icon_path.is_empty() and ResourceLoader.exists(item.icon_path):
		sprite.texture = load(item.icon_path) as Texture2D
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.04
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_landed_items_root().add_child(sprite)
	sprite.global_position = world_position + Vector3.UP * 0.3
	(record as Dictionary)["node"] = sprite
	landed_items[key] = record
	battle_log.append({"kind": "item_landed_visible", "item_id": item_id, "tile": key})


func landed_item_at(key: Vector3i) -> String:
	var record: Variant = landed_items.get(key, null)
	return String((record as Dictionary).get("item_id", "")) if record is Dictionary else ""


func remove_landed_item(key: Vector3i) -> String:
	var record: Variant = landed_items.get(key, null)
	if not (record is Dictionary):
		return ""
	var node: Variant = (record as Dictionary).get("node", null)
	if node is Node and is_instance_valid(node):
		(node as Node).queue_free()
	landed_items.erase(key)
	return String((record as Dictionary).get("item_id", ""))


func try_pickup_landed_item(pawn: TacticsPawn) -> bool:
	if pawn == null or pawn.stats == null or pawn.stats.pokemon_instance == null or landed_items.is_empty():
		return false
	var key: Vector3i = Targeting._tile_key(pawn.get_tile())
	var item_id: String = landed_item_at(key)
	if item_id.is_empty():
		return false
	if pawn.stats.pokemon_instance.held_item != null:
		battle_log.append({"kind": "item_pickup_blocked", "unit": pawn, "item_id": item_id, "reason": "held_slot_full"})
		return false
	var item: PokemonItemResource = PokemonItemService.load_item(item_id)
	if item == null:
		return false
	remove_landed_item(key)
	pawn.stats.pokemon_instance.held_item = item
	battle_log.append({"kind": "item_picked_up", "unit": pawn, "item_id": item_id, "tile": key})
	return true


func _landed_items_root() -> Node3D:
	var existing: Node = get_node_or_null("LandedItems")
	if existing is Node3D:
		return existing as Node3D
	var node := Node3D.new()
	node.name = "LandedItems"
	add_child(node)
	return node


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
		if intro_pending or not (participant.is_configured(player) and participant.is_configured(opponent)):
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
		if pawn.res.presentation_locked or is_presentation_busy():
			_advance_presentation_wait(unit, delta)
			return
		if multiverse_enabled and _travel_choice_open():
			var travel_actor: Node3D = player if unit.team == PokemonInstanceResource.Team.PLAYER else opponent
			var travel_target: Node3D = opponent if unit.team == PokemonInstanceResource.Team.PLAYER else player
			if not participant.is_configured(travel_actor):
				participant.configure(camera, ui_control)
			participant.act(delta, unit.control_type == PokemonInstanceResource.ControlType.PLAYER, travel_actor, travel_target)
			return
		if multiverse_enabled and not multiverse.pending_travel.is_empty():
			multiverse.cancel_travel()
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


func _travel_choice_open() -> bool:
	var stage: int = participant.res.stage
	if stage == participant.res.STAGE_SELECT_TRAVEL:
		return true
	return stage == participant.res.STAGE_ATTACK and not multiverse.pending_travel.is_empty()


func _advance_presentation_wait(unit: BattleUnit, delta: float) -> void:
	var pawn: TacticsPawn = unit.pawn
	if pawn == null:
		return
	if pawn.res.presentation_locked:
		pawn.res.presentation_wait += delta
		if not is_presentation_busy() or pawn.res.presentation_wait > TacticsPawnResource.PRESENTATION_TIMEOUT:
			if pawn.res.presentation_wait > TacticsPawnResource.PRESENTATION_TIMEOUT and presentation_runner != null:
				presentation_runner.cancel_all("turn_wait_timeout")
			pawn.res.presentation_locked = false
			pawn.res.presentation_wait = 0.0
			pawn.res.wait_delay = 0.0
			pawn.res.intent_executed = false
			participant.res.pending_intent = null
			participant.res.attackable_pawn = null
			participant.res.throw_options = []
			if ui_control != null:
				ui_control.set_actions_menu_visibility(false, null)


func _start_scheduler() -> void:
	battle_conditions = {}
	battle_units = _build_battle_units()
	notation.setup(self, battle_label if not battle_label.is_empty() else name, battle_seed)
	intrinsic_service.log_battle_start(battle_units, battle_log, self)
	scheduler.start_battle(battle_units, int(battle_rng.seed))
	_scheduler_started = true
	if hud != null:
		hud.rebuild_queue()


func _on_edge_pan_toggled(enabled: bool) -> void:
	if message_log != null:
		message_log.add_message("Mouse edge panning %s (O to toggle)." % ("on" if enabled else "off"))


func current_terrain() -> String:
	for terrain_id in BattleWeatherService.TERRAIN_IDS:
		if battle_conditions.has(terrain_id):
			return terrain_id
	return ""


func set_terrain(terrain_id: String, rounds: int, source_move_id: String = "") -> void:
	var previous: String = current_terrain()
	if previous == terrain_id:
		battle_log.append({"kind": "field_condition_failed", "condition_id": terrain_id, "reason": "already_active"})
		return
	if not previous.is_empty():
		battle_conditions.erase(previous)
		battle_log.append({"kind": "field_condition_ended", "condition_id": previous, "reason": "replaced"})
	battle_conditions[terrain_id] = {"condition_id": terrain_id, "counter": rounds + (1 if not _scheduler_started else 0), "move_id": source_move_id}
	battle_log.append({"kind": "field_condition_applied", "condition_id": terrain_id, "move_id": source_move_id, "scope": "field", "rounds": rounds})


func is_grounded(pawn: TacticsPawn) -> bool:
	return hazards()._is_grounded(pawn)


func end_strong_weather_from(pawn: TacticsPawn) -> void:
	var weather: String = current_weather()
	if weather.is_empty() or not BattleWeatherService.is_permanent(weather):
		return
	var stored: Dictionary = battle_condition(weather)
	if String(stored.get("unit", "")) == pawn.name:
		for other in units_on_map():
			if other != pawn and other.stats != null and other.stats.is_active() and intrinsic_service.intrinsic_slugs_for(other.stats).has(String(stored.get("source_intrinsic", ""))):
				return
		clear_weather("source_fainted")


func hazards() -> BattleHazardService:
	if hazard_service == null:
		hazard_service = BattleHazardService.new(self)
	return hazard_service


func place_hazard(source: TacticsPawn, hazard_id: String) -> Array[Vector3i]:
	return hazards().place(source, hazard_id, battle_log)


func clear_hazards(source: TacticsPawn, foes_only: bool, move_id: String) -> int:
	return hazards().clear(source, foes_only, battle_log, move_id)


func record_move_intent(pawn: TacticsPawn, tile: TacticsTile) -> void:
	if pawn == null or not is_instance_valid(pawn) or tile == null:
		return
	battle_log.append({"kind": "unit_move_started", "unit": pawn, "tile": Targeting._tile_key(tile)})


func on_pawn_reached_tile(pawn: TacticsPawn, position: Vector3) -> void:
	if hazard_service != null:
		hazard_service.on_pawn_reached(pawn, position)


func release_bide(pawn: TacticsPawn) -> void:
	var payload: Dictionary = _status_payload(pawn, "bide")
	_ops().remove_status(pawn, "bide", {"source": "released"})
	var stored: int = int(payload.get("stored", 0))
	var target: Variant = pawn.stats.last_attacker
	if stored <= 0 or not (target is TacticsPawn) or not is_instance_valid(target) or (target as TacticsPawn).stats == null or not (target as TacticsPawn).stats.is_active():
		battle_log.append({"kind": "move_rejected", "attacker": pawn, "move_id": "bide", "reason": "no_effect"})
		return
	_ops().damage(target, stored * 2, {"kind": "hit", "attacker": pawn, "move": load("res://data/models/pokemon/generated/moves/bide.tres"), "event": {"source": "bide", "multiplier": 1.0}})
	battle_log.append({"kind": "status_triggered", "unit": pawn, "status_id": "bide", "defender": target, "amount": stored * 2})


func _resolve_future_sight(pawn: TacticsPawn) -> void:
	var payload: Dictionary = _status_payload(pawn, "future_sight")
	_ops().remove_status(pawn, "future_sight", {"source": "expired"})
	var source: Variant = payload.get("source_unit", null)
	var move: PokemonMoveResource = load("res://data/models/pokemon/generated/moves/future_sight.tres") as PokemonMoveResource
	if move == null or not pawn.stats.is_active():
		return
	var attacker_stats: Stats = (source as TacticsPawn).stats if source is TacticsPawn and is_instance_valid(source) and (source as TacticsPawn).stats != null else pawn.stats
	var chart: TypeChartResource = get_type_chart()
	var resolver := DamageResolver.new()
	var effectiveness: float = resolver._effectiveness(move, pawn.stats, chart)
	var stab: bool = chart.is_stab(move.type, attacker_stats.types) if chart != null else false
	var damage: int = resolver.calculate_damage(attacker_stats, pawn.stats, move, effectiveness, stab, 1.0, battle_rng, {}, false)
	if damage > 0:
		_ops().damage(pawn, damage, {"kind": "future_sight", "attacker": source if source is TacticsPawn else null, "move": move, "event": {"source": "future_sight", "multiplier": effectiveness}})


func is_trapped(pawn: TacticsPawn) -> bool:
	if pawn == null or pawn.stats == null:
		return false
	if pawn.stats.battle_statuses.has("rooted"):
		return true
	for trap_id in TRAP_STATUSES:
		if pawn.stats.battle_statuses.has(trap_id):
			return true
	return false


func _ops() -> BattleStateOps:
	if state_ops == null:
		state_ops = BattleStateOps.new(self, battle_log, intrinsic_service)
		intrinsic_service.state_ops = state_ops
	return state_ops


func pawn_team(pawn: TacticsPawn) -> int:
	if player != null and pawn != null and player.is_ancestor_of(pawn):
		return PokemonInstanceResource.Team.PLAYER
	return PokemonInstanceResource.Team.ENEMY


func is_remote_pawn(pawn: TacticsPawn) -> bool:
	if net_session == null or not is_instance_valid(net_session) or pawn == null:
		return false
	if not bool(net_session.call("in_battle")):
		return false
	return pawn_team(pawn) != int(net_session.get("local_side"))


func units_on_map() -> Array[TacticsPawn]:
	var out: Array[TacticsPawn] = []
	for team_node in [player, opponent]:
		if team_node == null:
			continue
		for child in team_node.get_children():
			if child is TacticsPawn and (child as TacticsPawn).is_alive():
				out.append(child as TacticsPawn)
	return out


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
	notation.mark_turn_start(pawn)
	intrinsic_service.on_turn_started(pawn, self, battle_log)
	_process_turn_start_statuses(pawn)
	if not pawn.is_alive():
		return
	pawn.reset_turn()
	if is_trapped(pawn):
		pawn.res.can_move = false
	pawn.res.has_acted_this_round = false
	pawn.res.use_legacy_attack_fallback = false
	if not pawn.stats.move_slots.is_empty():
		var idx: int = pawn.stats.first_usable_move_index(false)
		pawn.res.selected_move_index = max(0, idx)

	var p_res: TacticsParticipantResource = participant.res
	p_res.curr_pawn = pawn
	p_res.stage = p_res.STAGE_SHOW_ACTIONS
	p_res.attackable_pawn = null
	p_res.pending_intent = null
	p_res.throw_options = []
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
	for status_id: String in ["protect", "detect", "kings_shield", "crafty_shield", "wide_guard", "quick_guard", "spiky_shield", "mat_block", "snatch", "follow_me", "rage_powder", "endure", "destiny_bond", "grudge", "powder", "counter", "mirror_coat", "metal_burst", "enraged", "roosting"]:
		if status_id == "roosting" and pawn.stats.battle_statuses.has("roosting"):
			var roost_payload: Dictionary = _status_payload(pawn, "roosting")
			if roost_payload.has("original_types"):
				var restored: Array[String] = []
				for type_id in roost_payload["original_types"]:
					restored.append(String(type_id))
				pawn.stats.types = restored
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
		if intrinsic_service.heals_from_poison(pawn.stats):
			_apply_status_heal(pawn, STATUS_POISON, 8)
		else:
			_apply_status_damage(pawn, STATUS_POISON, _status_hp_fraction(pawn, STATUS_POISON, 16))
	if pawn.stats.battle_statuses.has(STATUS_TOXIC) and intrinsic_service.heals_from_poison(pawn.stats):
		_apply_status_heal(pawn, STATUS_TOXIC, 8)
	elif pawn.stats.battle_statuses.has(STATUS_TOXIC):
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
	for trap_id in TRAP_STATUSES:
		if pawn.stats.battle_statuses.has(trap_id) and pawn.stats.is_active():
			_apply_status_damage(pawn, trap_id, _status_hp_fraction(pawn, trap_id, 8))
	if pawn.stats.battle_statuses.has("nightmare"):
		if pawn.stats.battle_statuses.has(STATUS_SLEEP):
			_apply_status_damage(pawn, "nightmare", 4)
		else:
			_ops().remove_status(pawn, "nightmare", {"source": "woke_up"})
	if pawn.stats.battle_statuses.has("perish_song") and pawn.stats.is_active():
		var perish: Dictionary = _status_payload(pawn, "perish_song")
		var left: int = int(perish.get("perish_left", 3)) - 1
		if left <= 0:
			_ops().damage(pawn, pawn.stats.curr_health, {"kind": "status_tick", "status_id": "perish_song"})
			_ops().remove_status(pawn, "perish_song", {"source": "expired"})
		else:
			perish["perish_left"] = left
			pawn.stats.battle_statuses["perish_song"] = perish
			battle_log.append({"kind": "status_tick", "unit": pawn, "status_id": "perish_song", "amount": 0, "before": pawn.stats.curr_health, "after": pawn.stats.curr_health, "perish_left": left})
	if pawn.stats.battle_statuses.has("yawning") and int(_status_payload(pawn, "yawning").get("counter", 2)) <= 1:
		_ops().remove_status(pawn, "yawning", {"source": "expired"})
		_ops().apply_status(pawn, STATUS_SLEEP, {"source": "yawn"}, {"kind": "status", "source": "yawn"})
	if pawn.stats.battle_statuses.has("wish") and int(_status_payload(pawn, "wish").get("counter", 2)) <= 1:
		_apply_status_heal(pawn, "wish", 2)
	if pawn.stats.battle_statuses.has("future_sight") and int(_status_payload(pawn, "future_sight").get("counter", 3)) <= 1:
		_resolve_future_sight(pawn)
	if pawn.stats.battle_statuses.has("bide") and int(_status_payload(pawn, "bide").get("counter", 2)) <= 1:
		release_bide(pawn)
	if pawn.stats.battle_statuses.has("cud_chew") and int(_status_payload(pawn, "cud_chew").get("counter", 1)) <= 1:
		PokemonItemService.cud_chew(pawn, String(_status_payload(pawn, "cud_chew").get("item_id", "")), battle_log)
		_ops().remove_status(pawn, "cud_chew", {"source": "expired"})
	if current_terrain() == "grassy_terrain" and is_grounded(pawn) and pawn.stats.is_active() and pawn.stats.curr_health < pawn.stats.max_health:
		_apply_status_heal(pawn, "grassy_terrain", 16)
	_apply_weather_chip(pawn)
	PokemonItemService.on_turn_started(pawn, battle_log)


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
			_ops().remove_status(pawn, status_id, {"source": "counter_expired"})
			if RAMPAGE_STATUSES.has(status_id) and pawn.stats.is_active():
				_ops().apply_status(pawn, STATUS_CONFUSE, {"source": "rampage"}, {"kind": "status", "source": "rampage"})
			continue
		data["counter"] = next_counter
		pawn.stats.battle_statuses[status_id] = data


func _apply_status_damage(pawn: TacticsPawn, status_id: String, hp_fraction: int, multiplier: int = 1) -> int:
	if pawn == null or pawn.stats == null or not pawn.stats.is_active():
		return 0
	var amount: int = maxi(1, int(floor(float(pawn.stats.max_health) / float(maxi(1, hp_fraction)))) * maxi(1, multiplier))
	return int(_ops().damage(pawn, amount, {"kind": "status_tick", "status_id": status_id}).get("applied", 0))


func _apply_status_heal(pawn: TacticsPawn, status_id: String, hp_fraction: int) -> int:
	if pawn == null or pawn.stats == null or not pawn.stats.is_active():
		return 0
	var amount: int = maxi(1, int(floor(float(pawn.stats.max_health) / float(maxi(1, hp_fraction)))))
	return int(_ops().heal(pawn, amount, {"kind": "status", "status_id": status_id}).get("applied", 0))


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
	return int(_ops().heal(pawn, amount, {"kind": "status", "status_id": status_id}).get("applied", 0))


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
	intrinsic_service.on_turn_completed(unit.pawn, battle_log)
	notation.mark_turn_end(unit.pawn)
	if multiverse_enabled:
		multiverse.on_turn_completed()


func _on_round_building() -> void:
	multiverse.enabled = multiverse_enabled
	if multiverse_enabled:
		ensure_multiverse_presentation()
	multiverse.on_round_building()
	intrinsic_service.apply_speed_modifiers(battle_units, self, battle_log)
	PokemonItemService.apply_speed_multipliers(battle_units, battle_log)


func _on_round_started() -> void:
	round_index += 1
	if banner != null:
		banner.show_turn(round_index)
	for unit in battle_units:
		if unit.pawn != null:
			unit.pawn.res.has_acted_this_round = false
	_tick_weather()
	_tick_battle_conditions()


func get_type_chart() -> TypeChartResource:
	if _type_chart == null:
		_type_chart = load(TYPE_CHART_PATH) as TypeChartResource
	return _type_chart


func set_battle_condition(condition_id: String, payload: Dictionary = {}) -> void:
	var key: String = condition_id.strip_edges().to_lower()
	if key.is_empty():
		return
	if BattleWeatherService.is_weather(key):
		_set_weather(BattleWeatherService.normalize(key), payload)
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
	for key in BattleWeatherService.WEATHER_IDS:
		if battle_conditions.has(key):
			return key
	return ""


func effective_weather() -> String:
	var weather: String = current_weather()
	if weather.is_empty():
		return ""
	return "" if intrinsic_service.suppresses_weather(units_on_map()) else weather


func are_foes(a: TacticsPawn, b: TacticsPawn) -> bool:
	return _team_condition_key(a) != _team_condition_key(b)


func weather_rounds_left() -> int:
	var weather: String = current_weather()
	if weather.is_empty():
		return 0
	return int(battle_condition(weather).get("rounds_left", 0))


func _set_weather(weather_id: String, payload: Dictionary) -> void:
	var previous: String = current_weather()
	if previous == weather_id:
		battle_log.append({"kind": "weather_failed", "condition_id": weather_id, "reason": "already_active"})
		return
	if not previous.is_empty() and BattleWeatherService.is_permanent(previous) and not BattleWeatherService.is_permanent(weather_id):
		battle_log.append({"kind": "weather_failed", "condition_id": weather_id, "reason": "strong_weather_active"})
		return
	if not previous.is_empty():
		battle_conditions.erase(previous)
		battle_log.append({"kind": "weather_ended", "condition_id": previous, "reason": "replaced"})
	var stored: Dictionary = payload.duplicate(true)
	stored["condition_id"] = weather_id
	var rounds: int = int(payload.get("rounds", 0))
	stored["rounds_left"] = rounds if rounds > 0 else BattleWeatherService.DEFAULT_ROUNDS
	if BattleWeatherService.is_permanent(weather_id):
		stored["rounds_left"] = -1
	elif not _scheduler_started:
		stored["rounds_left"] = int(stored["rounds_left"]) + 1
	battle_conditions[weather_id] = stored
	battle_log.append({"kind": "weather_started", "condition_id": weather_id, "rounds": int(stored["rounds_left"]), "move_id": String(payload.get("move_id", ""))})
	weather_changed.emit(weather_id)


func clear_weather(reason: String = "cleared") -> void:
	var weather: String = current_weather()
	if weather.is_empty():
		return
	battle_conditions.erase(weather)
	battle_log.append({"kind": "weather_ended", "condition_id": weather, "reason": reason})
	weather_changed.emit("")


func _tick_battle_conditions() -> void:
	for key in battle_conditions.keys():
		var stored: Dictionary = battle_conditions[key]
		if not stored.has("counter") or int(stored.get("counter", 0)) <= 0:
			continue
		var left: int = int(stored["counter"]) - 1
		if left <= 0:
			battle_conditions.erase(key)
			battle_log.append({"kind": "field_condition_ended", "condition_id": key})
		else:
			stored["counter"] = left
			battle_conditions[key] = stored


func _tick_weather() -> void:
	var weather: String = current_weather()
	if weather.is_empty():
		return
	var stored: Dictionary = battle_condition(weather)
	if int(stored.get("rounds_left", 0)) < 0:
		return
	var rounds_left: int = int(stored.get("rounds_left", 0)) - 1
	if rounds_left <= 0:
		clear_weather("expired")
		return
	stored["rounds_left"] = rounds_left
	battle_conditions[weather] = stored
	battle_log.append({"kind": "weather_tick", "condition_id": weather, "rounds": rounds_left})


func weather_damage_multiplier(move: PokemonMoveResource, target: TacticsPawn) -> float:
	var target_types: Array = target.stats.types if target != null and target.stats != null else []
	return BattleWeatherService.damage_multiplier(effective_weather(), move, target_types)


func weather_accuracy_override(move: PokemonMoveResource) -> int:
	return BattleWeatherService.accuracy_override(effective_weather(), move)


func weather_blocks_status(status_id: String) -> bool:
	return BattleWeatherService.blocks_status(effective_weather(), status_id)


func _apply_weather_chip(pawn: TacticsPawn) -> void:
	var weather: String = effective_weather()
	if weather.is_empty() or pawn == null or pawn.stats == null or not pawn.stats.is_active():
		return
	if PokemonItemService.ignores_weather(pawn.stats):
		return
	var fraction: int = BattleWeatherService.chip_fraction(weather, pawn.stats.types, intrinsic_service.intrinsic_slugs_for(pawn.stats))
	if fraction <= 0:
		return
	_apply_status_damage(pawn, weather, fraction)


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
	if multiverse.enabled and not multiverse.state.timelines.is_empty():
		result = multiverse.multiverse_result()
		if result == RESULT_ONGOING:
			return
	if result == RESULT_ONGOING:
		if not use_speed_scheduler:
			return
		result = RESULT_PLAYER_LOSS

	finish_battle(result)


func finish_battle(result: int, reason: String = "") -> void:
	if battle_finished:
		return
	battle_finished = true
	turn_stage = 2
	_refill_pp_for_units(player.get_children())
	_refill_pp_for_units(opponent.get_children())
	battle_log.append({
		"kind": "battle_ended",
		"winner": "player" if result == RESULT_PLAYER_WIN else "opponent",
	})
	notation.finish(result, reason)
	var notation_path: String = notation.save()
	if not notation_path.is_empty():
		print("battle: notation saved to %s" % notation_path)
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
	notation.record(event)


func _format_battle_event(event: Dictionary) -> String:
	var readable: Dictionary = event.duplicate()
	for key in ["attacker", "defender", "unit"]:
		if readable.has(key) and readable[key] is Node:
			readable[key] = (readable[key] as Node).name
	return str(readable)
