class_name MultiverseController
extends RefCounted

const PAWN_SCENE_PATH: String = "res://data/modules/tactics/level/pawn/pawn.tscn"
const EXPERTISE_SCENE_PATH: String = "res://data/modules/stats/expertise/expertise.tscn"
const STAT_FIELDS: Array[String] = ["curr_health", "max_health", "hp_max", "attack", "defense", "special_attack", "special_defense", "speed", "level", "movement", "jump", "attack_power", "attack_range", "species_name", "weight_kg", "gender", "transformed", "consumed_berry_id", "choice_locked_item", "last_hit_move_type", "same_move_streak", "intrinsic_override_active", "battle_speed_multiplier", "last_used_move_id", "last_used_move_index", "last_consumed_item_id", "battle_status", "override_name"]
const COPY_FIELDS: Array[String] = ["types", "battle_statuses", "temporary_intrinsic_slugs", "stat_stages", "proxy_stats", "modifiers", "current_pp"]
const RES_FIELDS: Array[String] = ["can_move", "can_attack", "has_acted_this_round", "selected_move_index", "use_legacy_attack_fallback"]
const TRAVEL_MOVES: Dictionary = {
	"roar_of_time": {"axis": "time", "travellers": "both"},
	"spacial_rend": {"axis": "space", "travellers": "both"},
	"hyperspace_hole": {"axis": "space", "travellers": "target"},
	"hyperspace_fury": {"axis": "space", "travellers": "target", "force_new": true},
	"dimensional_hole": {"axis": "time", "travellers": "user", "lag": true},
	"dimensional_glitch": {"axis": "space", "travellers": "user", "random": true},
	"shadow_force": {"axis": "space", "travellers": "user", "strike": true},
}
const IMMUNE_SPECIES: Array[String] = ["0493_arceus"]
const CANCEL_CHOICE: String = "choice"

var level: TacticsLevel = null
var state: MultiverseState = MultiverseState.new()
var enabled: bool = false
var pending_travel: Dictionary = {}
var travel_serial: int = 0
var travels: int = 0
var switches: int = 0
var last_switch_reason: String = ""
var cpu_policy: Callable = Callable()
var strike_hop_declined: Dictionary = {}
var declared_target: TacticsPawn = null
var stage: MultiverseStage = null
var fx: MultiverseFx = null
var minimap: MultiverseMinimap = null
var preview_active: bool = false
var committing: bool = false
var _pawn_scene: PackedScene = null
var _expertise_scene: PackedScene = null


func setup(battle_level: TacticsLevel) -> void:
	level = battle_level
	_pawn_scene = load(PAWN_SCENE_PATH) as PackedScene
	_expertise_scene = load(EXPERTISE_SCENE_PATH) as PackedScene


func focus() -> Vector2i:
	return state.focus


func board_label() -> String:
	var text: String = "%s T%d" % [MultiverseState.label(state.focus.x), level.round_index]
	if not state.timelines.is_empty() and state.owed_boards().size() > 1:
		text += "  (%d boards owed)" % state.owed_boards().size()
	return text


func on_round_building() -> void:
	if not enabled or not state.timelines.is_empty():
		return
	var root: BoardSnapshot = capture(false)
	root.turn = 1
	state.add_root(root)
	present_refresh()


func present_refresh() -> void:
	if stage != null and is_instance_valid(stage):
		stage.refresh()
	if minimap != null and is_instance_valid(minimap):
		minimap.refresh()


func presentation_immediate() -> bool:
	return level == null or level.presentation_runner == null or level.presentation_runner.immediate_mode or not level.is_inside_tree()


func _hold(seconds: float, label: String) -> void:
	if level == null or level.presentation_runner == null:
		return
	level.presentation_runner.enqueue({"kind": BattlePresentationRunner.KIND_WAIT, "seconds": seconds, "label": label})


func show_travel_preview() -> void:
	if pending_travel.is_empty() or stage == null or not is_instance_valid(stage):
		return
	preview_active = true
	stage.show_travel_preview(pending_travel)


func clear_travel_preview() -> void:
	if not preview_active:
		return
	preview_active = false
	if stage != null and is_instance_valid(stage):
		stage.clear_travel_preview()


func highlight_travel_option(index: int) -> void:
	if stage != null and is_instance_valid(stage):
		stage.highlight_travel_option(index)


func round_gate(board_over: bool) -> bool:
	if not enabled or state.timelines.is_empty():
		return not board_over
	var previous: Vector2i = state.focus
	var finished: BoardSnapshot = capture(false)
	finished.turn = level.round_index + 1
	state.advance(state.focus.x, finished)
	state.focus = finished.coords()
	if stage != null and is_instance_valid(stage):
		stage.recentre_camera(previous, state.focus)
	if board_over and _multiverse_over():
		present_refresh()
		return false
	var owed: Array[Vector2i] = state.owed_boards()
	if owed.is_empty():
		present_refresh()
		return not board_over
	if owed[0] == finished.coords() and not board_over:
		present_refresh()
		return true
	_switch_to(owed[0], "present" if not board_over else "board_over")
	return false


func _multiverse_over() -> bool:
	return state.standing_total(PokemonInstanceResource.Team.PLAYER) == 0 or state.standing_total(PokemonInstanceResource.Team.ENEMY) == 0


func multiverse_result() -> int:
	var player_alive: int = state.standing_total(PokemonInstanceResource.Team.PLAYER)
	var enemy_alive: int = state.standing_total(PokemonInstanceResource.Team.ENEMY)
	if enemy_alive == 0:
		return TacticsLevel.RESULT_PLAYER_WIN
	if player_alive == 0:
		return TacticsLevel.RESULT_PLAYER_LOSS
	if state.owed_boards().is_empty() and level.scheduler.is_battle_over():
		return TacticsLevel.RESULT_PLAYER_WIN if player_alive > enemy_alive else TacticsLevel.RESULT_PLAYER_LOSS
	return TacticsLevel.RESULT_ONGOING


func _switch_to(coords: Vector2i, reason: String) -> void:
	var board: BoardSnapshot = state.board(coords.x, coords.y)
	if board == null:
		return
	switches += 1
	last_switch_reason = reason
	restore(board)
	if fx != null and is_instance_valid(fx):
		fx.play_switch(presentation_immediate())
	_hold(0.7, "board_switch")
	present_refresh()
	if level.banner != null:
		level.banner.show_notice("Now on %s, turn %d" % [MultiverseState.label(coords.x), coords.y])
	level.battle_log.append({"kind": "board_switched", "timeline": coords.x, "turn": coords.y, "reason": reason})
	level.notation.record_board_switch(coords.x, coords.y)
	level.scheduler.resume()


func capture(mid_round: bool) -> BoardSnapshot:
	var board := BoardSnapshot.new()
	board.timeline = state.focus.x
	board.turn = level.round_index
	board.mid_round = mid_round
	var by_unit: Dictionary = {}
	for unit in level.battle_units:
		if unit.pawn != null and is_instance_valid(unit.pawn):
			by_unit[unit.pawn] = unit
	for team_node in [level.player, level.opponent]:
		for child in team_node.get_children():
			if child is TacticsPawn:
				var unit: BattleUnit = by_unit.get(child, null)
				board.units.append(capture_unit(child, unit))
	board.conditions = _encode(level.battle_conditions.duplicate(true))
	board.hazards = _encode(level.hazard_service.tiles.duplicate(true)) if level.hazard_service != null else {}
	for key in level.landed_items:
		var record: Dictionary = level.landed_items[key]
		board.landed.append({"key": key, "item_id": String(record.get("item_id", "")), "source": String(record.get("source", "")), "world_position": record.get("world_position", Vector3.ZERO)})
	board.scheduler = _encode_scheduler(mid_round)
	board.battle_rng_state = level.battle_rng.state
	board.notation_turn = level.notation.turn_index
	return board


func capture_unit(pawn: TacticsPawn, unit: BattleUnit) -> Dictionary:
	var tile_ray: RayCast3D = pawn.get_node_or_null("Tile") as RayCast3D
	if tile_ray != null:
		tile_ray.force_raycast_update()
	var stats: Stats = pawn.stats
	var instance: PokemonInstanceResource = stats.pokemon_instance
	var entry: Dictionary = {
		"id": level.notation.unit_id(pawn),
		"team": unit.team if unit != null else (PokemonInstanceResource.Team.PLAYER if pawn.get_parent() == level.player else PokemonInstanceResource.Team.ENEMY),
		"control": unit.control_type if unit != null else (instance.control_type if instance != null else 0),
		"insertion": unit.insertion_order if unit != null else 0,
		"rest_rounds": unit.rest_rounds if unit != null else 0,
		"instance": instance,
		"held_item_id": instance.held_item.item_id if instance != null and instance.held_item != null else "",
		"alive": pawn.is_alive(),
		"position": pawn.global_position,
		"rotation": pawn.rotation,
		"tile": Targeting._tile_key(pawn.get_tile()) if pawn.get_tile() != null else Vector3i(floori(pawn.global_position.x + 0.5), 0, floori(pawn.global_position.z + 0.5)),
		"moves": [],
		"stats": {},
		"res": {},
	}
	for move in stats.move_slots:
		entry["moves"].append(move.move_id if move != null else "")
	for field in STAT_FIELDS:
		entry["stats"][field] = stats.get(field)
	for field in COPY_FIELDS:
		entry["stats"][field] = _encode((stats.get(field) as Variant).duplicate(true))
	entry["stats"]["last_attacker"] = _encode(stats.last_attacker)
	for field in RES_FIELDS:
		entry["res"][field] = pawn.res.get(field)
	return entry


func _encode_scheduler(mid_round: bool) -> Dictionary:
	var snapshot: Dictionary = level.scheduler.snapshot_state()
	var order: Array = []
	var ties: Dictionary = {}
	for unit in snapshot.get("units", []):
		var id: String = level.notation.unit_id((unit as BattleUnit).pawn)
		order.append(id)
		ties[id] = int((snapshot.get("tie_values", {}) as Dictionary).get(unit, 0))
	var queue: Array = []
	if mid_round:
		for unit in snapshot.get("queue", []):
			queue.append(level.notation.unit_id((unit as BattleUnit).pawn))
	return {"order": order, "queue": queue, "ties": ties, "rng_state": int(snapshot.get("rng_state", 0))}


func restore(board: BoardSnapshot) -> void:
	clear_travel_preview()
	pending_travel = {}
	if level.presentation_runner != null:
		level.presentation_runner.cancel_all("board_switch")
	if level.hud != null:
		level.hud.unpin()
	var participant: TacticsParticipantResource = level.participant.res
	participant.curr_pawn = null
	participant.attackable_pawn = null
	participant.pending_intent = null
	participant.throw_options = []
	participant.stage = participant.STAGE_SELECT_PAWN
	if level.ui_control != null:
		level.ui_control.set_actions_menu_visibility(false, null)
	for team_node in [level.player, level.opponent]:
		for child in team_node.get_children():
			if child is TacticsPawn:
				team_node.remove_child(child)
				child.queue_free()
	var pawns_by_id: Dictionary = {}
	var ids: Dictionary = {}
	for entry in board.units:
		var pawn: TacticsPawn = _spawn_unit(entry)
		pawns_by_id[String(entry["id"])] = pawn
		ids[pawn] = String(entry["id"])
	level.notation.set_unit_ids(ids)
	for entry in board.units:
		_apply_unit(pawns_by_id[String(entry["id"])], entry, pawns_by_id)
	level.battle_conditions = _decode(board.conditions.duplicate(true), pawns_by_id)
	if level.hazard_service != null:
		level.hazard_service.restore_tiles(_decode(board.hazards.duplicate(true), pawns_by_id))
	for key in level.landed_items.keys():
		level.remove_landed_item(key)
	for record in board.landed:
		level.landed_items[record["key"]] = {"item_id": String(record["item_id"]), "node": null, "source": String(record.get("source", "")), "world_position": record.get("world_position", Vector3.ZERO)}
		level.show_landed_item(record["key"])
	level.battle_rng.state = board.battle_rng_state
	level.round_index = board.turn if board.mid_round else board.turn - 1
	level.notation.turn_index = board.notation_turn
	var previous_focus: Vector2i = state.focus
	state.focus = board.coords()
	if stage != null and is_instance_valid(stage):
		stage.recentre_camera(previous_focus, state.focus)
	var units: Array[BattleUnit] = []
	var by_id: Dictionary = {}
	for entry in board.units:
		var pawn: TacticsPawn = pawns_by_id[String(entry["id"])]
		var unit := BattleUnit.new(pawn, pawn.stats, int(entry["team"]), int(entry["control"]), int(entry["insertion"]))
		unit.rest_rounds = int(entry.get("rest_rounds", 0))
		units.append(unit)
		by_id[String(entry["id"])] = unit
	var ordered: Array[BattleUnit] = []
	for id in board.scheduler.get("order", []):
		if by_id.has(id):
			ordered.append(by_id[id])
	for unit in units:
		if not ordered.has(unit):
			ordered.append(unit)
	var queue: Array[BattleUnit] = []
	for id in board.scheduler.get("queue", []):
		if by_id.has(id):
			queue.append(by_id[id])
	var ties: Dictionary = {}
	for id in board.scheduler.get("ties", {}):
		if by_id.has(id):
			ties[by_id[id]] = int(board.scheduler["ties"][id])
	level.battle_units = ordered
	level.scheduler.restore_state(ordered, queue, ties, int(board.scheduler.get("rng_state", 0)))
	level.arena.reset_all_tile_markers()
	level.weather_changed.emit(level.current_weather())
	if level.terrain_overlay != null:
		var terrain: String = level.current_terrain()
		if terrain.is_empty():
			level.terrain_overlay.hide_terrain()
		else:
			level.terrain_overlay.show_terrain(terrain)
	if level.banner != null:
		level.banner.show_turn(board.turn)
	if level.hud != null:
		level.hud.rebuild_queue()
		level.hud.refresh_danger()
	var first: BattleUnit = queue[0] if not queue.is_empty() else (ordered[0] if not ordered.is_empty() else null)
	if first != null:
		level.camera.target = first.pawn


func _spawn_unit(entry: Dictionary) -> TacticsPawn:
	var team: int = int(entry["team"])
	var parent: Node3D = level.player if team == PokemonInstanceResource.Team.PLAYER else level.opponent
	var source: PokemonInstanceResource = entry["instance"]
	var instance: PokemonInstanceResource = source.duplicate() if source != null else null
	if instance != null:
		var held: String = String(entry.get("held_item_id", ""))
		instance.held_item = PokemonItemService.load_item(held) if not held.is_empty() else null
		instance.team = team
		instance.control_type = int(entry["control"])
	var pawn: TacticsPawn = _pawn_scene.instantiate() as TacticsPawn
	pawn.name = "Pkmn_%s" % String(entry["id"]).replace("'", "p")
	var expertise: Expertise = _expertise_scene.instantiate() as Expertise
	expertise.name = "Expertise"
	expertise.pokemon_instance = instance
	pawn.add_child(expertise)
	pawn.position = parent.global_transform.affine_inverse() * (entry["position"] as Vector3)
	pawn.rotation = entry["rotation"]
	parent.add_child(pawn)
	pawn.global_position = entry["position"]
	pawn.sync_physics_body()
	return pawn


func _apply_unit(pawn: TacticsPawn, entry: Dictionary, pawns_by_id: Dictionary) -> void:
	var stats: Stats = pawn.stats
	var moves: Array[PokemonMoveResource] = []
	for move_id in entry.get("moves", []):
		var move: PokemonMoveResource = PokemonLearnsetService.load_move(String(move_id))
		if move != null:
			moves.append(move)
	if not moves.is_empty():
		stats.move_slots = moves
	var fields: Dictionary = entry.get("stats", {})
	for field in STAT_FIELDS:
		if fields.has(field):
			stats.set(field, fields[field])
	for field in COPY_FIELDS:
		if not fields.has(field):
			continue
		var decoded: Variant = _decode((fields[field] as Variant).duplicate(true), pawns_by_id)
		var current: Variant = stats.get(field)
		if current is Array and decoded is Array:
			(current as Array).assign(decoded)
		else:
			stats.set(field, decoded)
	stats.last_attacker = _decode(fields.get("last_attacker", null), pawns_by_id)
	for field in RES_FIELDS:
		if (entry.get("res", {}) as Dictionary).has(field):
			pawn.res.set(field, entry["res"][field])
	pawn.serv.ui.update_character_health(pawn)
	pawn.serv.ui.tint_when_unable_to_act(pawn)
	if not stats.is_active():
		var visuals: PawnStateVisuals = pawn.get_node_or_null("StateVisuals") as PawnStateVisuals
		if visuals != null:
			visuals.settle_faint()


func _encode(value: Variant) -> Variant:
	if value is TacticsPawn:
		return {"__unit": level.notation.unit_id(value)} if is_instance_valid(value) else null
	if value is Dictionary:
		var out: Dictionary = {}
		for key in value:
			out[key] = _encode(value[key])
		return out
	if value is Array:
		var list: Array = []
		for item in value:
			list.append(_encode(item))
		return list
	return value


func _decode(value: Variant, pawns_by_id: Dictionary) -> Variant:
	if value is Dictionary:
		if (value as Dictionary).has("__unit") and (value as Dictionary).size() == 1:
			return pawns_by_id.get(String(value["__unit"]), null)
		var out: Dictionary = {}
		for key in value:
			out[key] = _decode(value[key], pawns_by_id)
		return out
	if value is Array:
		var list: Array = []
		for item in value:
			list.append(_decode(item, pawns_by_id))
		return list
	return value


func travel_rule(move_id: String) -> Dictionary:
	return TRAVEL_MOVES.get(move_id, {})


func is_immune(pawn: TacticsPawn) -> bool:
	return pawn != null and IMMUNE_SPECIES.has(PortraitLibrary.slug_for_pawn(pawn))


func travellers_for(move_id: String, user: TacticsPawn, target: TacticsPawn) -> Array[TacticsPawn]:
	var rule: Dictionary = travel_rule(move_id)
	var out: Array[TacticsPawn] = []
	match String(rule.get("travellers", "")):
		"both":
			out.append(user)
			if target != null and target != user and not is_immune(target):
				out.append(target)
		"target":
			if target != null and target != user and not is_immune(target):
				out.append(target)
		"user":
			out.append(user)
	return out


func travel_options(move_id: String, user: TacticsPawn, target: TacticsPawn) -> Array[Dictionary]:
	var rule: Dictionary = travel_rule(move_id)
	var out: Array[Dictionary] = []
	if rule.is_empty() or not enabled:
		return out
	var travellers: Array[TacticsPawn] = travellers_for(move_id, user, target)
	if travellers.is_empty():
		return out
	var ids: Array[String] = []
	for pawn in travellers:
		ids.append(level.notation.unit_id(pawn))
	var l: int = state.focus.x
	if String(rule.get("axis", "")) == "time":
		for past in state.past_boards(l, level.round_index):
			var eligible: bool = true
			for id in ids:
				var entry: Dictionary = past.unit(_base_id(id))
				if entry.is_empty() or not bool(entry.get("alive", false)):
					eligible = false
			if eligible:
				out.append({"kind": "branch", "from": past.coords(), "label": "%s T%d" % [MultiverseState.label(l), past.turn], "board": past})
		return out
	if bool(rule.get("force_new", false)):
		out.append({"kind": "new", "from": Vector2i(l, level.round_index), "label": "Tear a new universe"})
		return out
	for other in state.dimensions_at(level.round_index, l):
		out.append({"kind": "hop", "to": other, "label": "%s T%d" % [MultiverseState.label(other), level.round_index], "board": state.latest(other)})
	if out.is_empty():
		out.append({"kind": "new", "from": Vector2i(l, level.round_index), "label": "Tear a new universe"})
	return out


func request_travel(move_id: String, user: TacticsPawn, target: TacticsPawn) -> int:
	clear_travel_preview()
	pending_travel = {}
	var options: Array[Dictionary] = travel_options(move_id, user, target)
	if options.is_empty():
		return 0
	travel_serial += 1
	pending_travel = {"move_id": move_id, "user": user, "target": target, "options": options, "side": MultiverseState.SIDE_PLAYER if user.get_parent() == level.player else MultiverseState.SIDE_ENEMY, "serial": travel_serial}
	level.battle_log.append({"kind": "travel_pending", "unit": user, "move_id": move_id, "options": options.size()})
	return options.size()


func cpu_choice() -> int:
	if pending_travel.is_empty():
		return -1
	if cpu_policy.is_valid():
		return int(cpu_policy.call(pending_travel.get("options", []), pending_travel))
	return -1


func cancel_travel(reason: String = "") -> void:
	clear_travel_preview()
	if pending_travel.is_empty():
		return
	var user: Variant = pending_travel.get("user")
	level.battle_log.append({"kind": "travel_cancelled", "unit": user, "move_id": String(pending_travel.get("move_id", "")), "reason": reason})
	pending_travel = {}
	if reason == CANCEL_CHOICE and level.notation != null and user is TacticsPawn and is_instance_valid(user):
		level.notation.record_stay(user)


func pick_random_option() -> int:
	var options: Array = pending_travel.get("options", [])
	if options.is_empty():
		return -1
	var side: int = int(pending_travel.get("side", MultiverseState.SIDE_PLAYER))
	var mine: int = state.created_by_player if side == MultiverseState.SIDE_PLAYER else state.created_by_enemy
	var theirs: int = state.created_by_enemy if side == MultiverseState.SIDE_PLAYER else state.created_by_player
	var safe: Array[int] = []
	for i in range(options.size()):
		if not MultiversePolicy.lands_frozen(String((options[i] as Dictionary).get("kind", "")), mine, theirs):
			safe.append(i)
	if safe.is_empty():
		return level.battle_rng.randi_range(0, options.size() - 1)
	return safe[level.battle_rng.randi_range(0, safe.size() - 1)]


func commit_travel(choice: int) -> bool:
	if pending_travel.is_empty():
		return false
	var options: Array = pending_travel["options"]
	if choice < 0 or choice >= options.size():
		return false
	var option: Dictionary = options[choice]
	if not is_instance_valid(pending_travel["user"]) or (pending_travel["target"] != null and not is_instance_valid(pending_travel["target"])):
		level.battle_log.append({"kind": "travel_cancelled", "unit": null, "move_id": String(pending_travel.get("move_id", "")), "reason": "traveller_gone"})
		pending_travel = {}
		clear_travel_preview()
		return false
	var move_id: String = String(pending_travel["move_id"])
	var rule: Dictionary = travel_rule(move_id)
	var user: TacticsPawn = pending_travel["user"]
	var target: TacticsPawn = pending_travel["target"]
	var side: int = int(pending_travel["side"])
	committing = true
	var travellers: Array[TacticsPawn] = travellers_for(move_id, user, target)
	var origin: Vector2i = state.focus
	var entries: Array[Dictionary] = []
	var by_unit: Dictionary = {}
	for unit in level.battle_units:
		if unit.pawn != null:
			by_unit[unit.pawn] = unit
	var traveller_ids: Array[String] = []
	var user_id: String = level.notation.unit_id(user)
	for pawn in travellers:
		var entry: Dictionary = capture_unit(pawn, by_unit.get(pawn, null))
		entries.append(entry)
		traveller_ids.append(String(entry["id"]))
	var kind: String = String(option.get("kind", ""))
	var base: BoardSnapshot = null
	var planned_l: int = int(option["to"]) if kind == "hop" else state.next_timeline_index(side)
	var planned_coords: Vector2i = Vector2i(planned_l, state.latest(planned_l).turn) if kind == "hop" else Vector2i(planned_l, (option["from"] as Vector2i).y)
	level.notation.record_travel(move_id, traveller_ids, origin, planned_coords, kind, planned_l, option.get("from", origin), user_id)
	var from_locals: Dictionary = {}
	for pawn in travellers:
		from_locals[level.notation.unit_id(pawn)] = pawn.global_position
	clear_travel_preview()
	if kind != "hop":
		var branch_from: Vector2i = option["from"]
		base = state.board(branch_from.x, branch_from.y).duplicate_board()
	level.scheduler.detach_active()
	for pawn in travellers:
		var unit: BattleUnit = by_unit.get(pawn, null)
		if unit != null:
			level.scheduler.remove_unit(unit)
			level.battle_units.erase(unit)
		pawn.get_parent().remove_child(pawn)
		pawn.queue_free()
	var origin_board: BoardSnapshot = capture(true)
	state.replace_latest(origin.x, origin_board)
	var destination: BoardSnapshot = null
	var dest_coords: Vector2i = Vector2i.ZERO
	var new_l: int = 0
	if kind == "hop":
		var to_l: int = int(option["to"])
		destination = state.latest(to_l)
		dest_coords = destination.coords()
	else:
		destination = base
		destination.mid_round = false
		destination.scheduler["queue"] = []
		new_l = state.branch(option["from"], destination, side)
		dest_coords = destination.coords()
	var arrival_ids: Dictionary = {}
	for entry in entries:
		var arrival: Dictionary = entry.duplicate(true)
		arrival["id"] = _unique_id(String(entry["id"]), destination)
		arrival_ids[String(entry["id"])] = String(arrival["id"])
		arrival["rest_rounds"] = 0 if destination.mid_round else 1
		arrival["tile"] = _free_tile(destination, entry["tile"])
		arrival["position"] = Vector3(float((arrival["tile"] as Vector3i).x), float((entry["position"] as Vector3).y), float((arrival["tile"] as Vector3i).z))
		arrival["res"]["can_move"] = false
		arrival["res"]["can_attack"] = false
		arrival["res"]["has_acted_this_round"] = true
		if bool(rule.get("lag", false)) or move_id == "roar_of_time" and String(entry["id"]) == traveller_ids[0]:
			var statuses: Dictionary = arrival["stats"]["battle_statuses"]
			statuses["recharge"] = {"counter": 2}
			arrival["stats"]["battle_statuses"] = statuses
		destination.add_unit(arrival)
	travels += 1
	level.battle_log.append({"kind": "travel", "unit": user, "move_id": move_id, "travellers": traveller_ids, "from_timeline": origin.x, "from_turn": origin.y, "to_timeline": dest_coords.x, "to_turn": dest_coords.y, "kind_of": kind})
	pending_travel = {}
	var arrived_ids: Array[String] = []
	for entry in destination.units:
		arrived_ids.append(String(entry["id"]))
	restore(destination)
	_present_travel(origin, dest_coords, from_locals, arrival_ids, side)
	if level.banner != null:
		level.banner.show_notice("%s: %s" % [BattleMessageCatalog.move_label(move_id), "a new timeline opens at %s" % MultiverseState.label(dest_coords.x) if kind != "hop" else "arrival on %s" % MultiverseState.label(dest_coords.x)])
	if kind != "hop":
		level.notation.record_branch(destination, arrived_ids)
	level.notation.record_board_switch(dest_coords.x, dest_coords.y)
	level.battle_log.append({"kind": "board_switched", "timeline": dest_coords.x, "turn": dest_coords.y, "reason": "travel"})
	present_refresh()
	committing = false
	level.scheduler.resume()
	return true


func on_turn_completed() -> void:
	if committing or pending_travel.is_empty():
		return
	level.battle_log.append({"kind": "travel_cancelled", "unit": pending_travel.get("user"), "move_id": String(pending_travel.get("move_id", "")), "reason": "turn_ended"})
	pending_travel = {}
	clear_travel_preview()


func _present_travel(origin: Vector2i, dest_coords: Vector2i, from_locals: Dictionary, arrival_ids: Dictionary, side: int) -> void:
	var immediate: bool = presentation_immediate()
	if stage != null and is_instance_valid(stage):
		for base_id in from_locals:
			var arrival: TacticsPawn = level.notation.pawn_for_id(String(arrival_ids.get(base_id, base_id)))
			var to_local: Vector3 = arrival.position if arrival != null else Vector3.ZERO
			stage.add_travel_arc(origin, from_locals[base_id], dest_coords, to_local, side, not immediate)
			if arrival != null and not immediate and arrival.character != null:
				arrival.character.modulate.a = 0.0
				var tween: Tween = arrival.create_tween()
				tween.tween_interval(0.45)
				tween.tween_property(arrival.character, "modulate:a", 1.0, 0.6)
	if fx != null and is_instance_valid(fx):
		fx.play_travel(immediate)
	_hold(1.6, "travel")


func _unique_id(id: String, board: BoardSnapshot) -> String:
	var candidate: String = id
	while board.has_unit(candidate):
		candidate += "'"
	return candidate


func _base_id(id: String) -> String:
	return id.rstrip("'")


func _free_tile(board: BoardSnapshot, wanted: Vector3i) -> Vector3i:
	var taken: Dictionary = {}
	for entry in board.units:
		if bool(entry.get("alive", false)):
			taken[entry["tile"]] = true
	if not taken.has(wanted):
		return wanted
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	var best: Vector3i = wanted
	var best_distance: int = 1 << 30
	for key in keys:
		if taken.has(key):
			continue
		var distance: int = absi(key.x - wanted.x) + absi(key.z - wanted.z)
		if distance < best_distance:
			best_distance = distance
			best = key
	return best
