class_name BattleCommandApplier
extends RefCounted

const MAX_WAIT_FRAMES: int = 900

var tree: SceneTree = null
var level: TacticsLevel = null
var current_unit: TacticsPawn = null
var failures: int = 0
var log_lines: Array[String] = []
var auto_end_other_humans: bool = true
var verbose: bool = true


func _init(scene_tree: SceneTree, battle_level: TacticsLevel = null, shared_log: Variant = null) -> void:
	tree = scene_tree
	level = battle_level
	if shared_log is Array:
		log_lines = shared_log


func level_alive() -> bool:
	return level != null and is_instance_valid(level)


func apply(command: String) -> void:
	var parsed: Dictionary = NotationParser.parse(command)
	if String(parsed.get("kind", "")) == NotationParser.KIND_TURN:
		current_unit = unit_for_ref(String(parsed.get("unit", "")))
		if current_unit == null:
			fail("unknown unit in turn header: %s" % command)
		return
	if String(parsed.get("kind", "")) != NotationParser.KIND_ACTION:
		return
	var verb: String = String(parsed.get("verb", ""))
	var args: PackedStringArray = parsed.get("args", PackedStringArray())
	match verb:
		"mv":
			var pawn: TacticsPawn = require_current(command)
			if pawn == null or args.is_empty():
				return
			var hops: PackedStringArray = NotationParser.split_move(args[0])
			if not await wait_for_turn(pawn):
				return
			await apply_move(pawn, hops[hops.size() - 1])
		"atk":
			var pawn: TacticsPawn = require_current(command)
			if pawn == null or args.size() < 3:
				return
			var slot_index: int = int(args[0]) - 1 if args[0].is_valid_int() else slot_for_move(pawn, args[1])
			var target: TacticsPawn = pawn if args[2] == "self" or args[2] == "-" else unit_for_ref(args[2])
			if target == null:
				fail("unknown target in %s" % command)
				return
			if not await wait_for_turn(pawn):
				return
			await apply_attack(pawn, slot_index, target)
		"item":
			var pawn: TacticsPawn = require_current(command)
			if pawn == null or args.size() < 3:
				return
			if args[0] == "use":
				if not await wait_for_turn(pawn):
					return
				await apply_use_item(pawn, args[2])
			elif args[0] == "throw":
				var direction: Vector3i = Vector3i.ZERO
				if args.size() > 3:
					var parts: PackedStringArray = args[3].split(",")
					if parts.size() >= 2:
						direction = Vector3i(int(parts[0]), 0, int(parts[1]))
				if not await wait_for_turn(pawn):
					return
				await apply_throw_item(pawn, args[2], direction)
		"end":
			if args.is_empty() and (current_unit == null or not is_instance_valid(current_unit)):
				return
			var pawn: TacticsPawn = current_unit if args.is_empty() else unit_for_ref(args[0])
			if pawn == null:
				fail("end needs a current unit: %s" % command)
				return
			await apply_end_turn(pawn)
		"stay":
			var pawn: TacticsPawn = current_unit if args.is_empty() else unit_for_ref(args[0])
			apply_stay(pawn)
		"move":
			var pawn: TacticsPawn = unit_for_ref(args[0]) if not args.is_empty() else null
			if pawn == null or args.size() < 2:
				fail("move needs a unit and a tile: %s" % command)
				return
			if not await wait_for_turn(pawn):
				return
			await apply_move(pawn, args[1])
		"attack":
			var pawn: TacticsPawn = unit_for_ref(args[0]) if not args.is_empty() else null
			if pawn == null or args.size() < 3:
				fail("attack needs unit, slot and target: %s" % command)
				return
			var target: TacticsPawn = pawn if args[2].to_lower() == "self" else unit_for_ref(args[2])
			if target == null:
				fail("unknown target in %s" % command)
				return
			var slot_index: int = int(args[1]) - 1
			var move: PokemonMoveResource = pawn.stats.move_slots[slot_index] if pawn.stats != null and slot_index >= 0 and slot_index < pawn.stats.move_slots.size() else null
			if move != null and not move.can_target_foes() and move.can_target_self():
				target = pawn
			if not await wait_for_turn(pawn):
				return
			await apply_attack(pawn, slot_index, target)
		"wait":
			var pawn: TacticsPawn = unit_for_ref(args[0]) if not args.is_empty() else null
			if pawn == null:
				fail("wait needs a unit: %s" % command)
				return
			await apply_end_turn(pawn)
		"travel", "hop":
			await apply_travel(verb, args, command)
		"rounds":
			var count: int = int(args[0]) if not args.is_empty() else 1
			for i in range(count):
				level._on_round_started()
			log_line("advanced %d round(s)" % count)
		_:
			if not ["hit", "miss", "nfx", "st", "tick", "stat", "heal", "wx", "fld", "hz", "push", "ko", "skip", "rej", "held"].has(verb):
				fail("unknown command: %s" % command)


func apply_travel(verb: String, args: PackedStringArray, command: String) -> void:
	var mv: MultiverseController = level.multiverse
	if mv.pending_travel.is_empty():
		fail("no travel pending for: %s" % command)
		return
	var dest: String = args[4] if args.size() > 4 else ""
	var parts: PackedStringArray = dest.trim_prefix("L").split("T")
	if parts.size() != 2:
		fail("bad destination in: %s" % command)
		return
	var dest_l: int = int(parts[0])
	var dest_t: int = int(parts[1])
	var options: Array = mv.pending_travel.get("options", [])
	var choice: int = -1
	for i in range(options.size()):
		var option: Dictionary = options[i]
		var kind: String = String(option.get("kind", ""))
		if verb == "hop" and kind == "hop" and int(option.get("to", 0)) == dest_l:
			choice = i
		elif verb == "travel" and kind != "hop" and (option.get("from", Vector2i(-99, -99)) as Vector2i).y == dest_t:
			choice = i
	if choice < 0:
		fail("no option reaches %s in: %s" % [dest, command])
		return
	if not mv.commit_travel(choice):
		fail("travel commit failed: %s" % command)
		return
	current_unit = null
	await tree.physics_frame
	await tree.physics_frame
	log_line("%s replayed to %s" % [verb, dest])


func apply_stay(pawn: TacticsPawn) -> void:
	if not level_alive():
		return
	var mv: MultiverseController = level.multiverse
	var move_id: String = String(mv.pending_travel.get("move_id", ""))
	mv.cancel_travel(MultiverseController.CANCEL_CHOICE)
	if bool(mv.travel_rule(move_id).get("strike", false)) and pawn != null and is_instance_valid(pawn) and level.release_charge(pawn):
		return
	var participant: TacticsParticipantResource = level.participant.res
	participant.stage = participant.STAGE_SHOW_ACTIONS if pawn != null and is_instance_valid(pawn) and pawn.can_act() else participant.STAGE_SELECT_PAWN
	log_line("stay applied for %s" % (level.notation.unit_id(pawn) if pawn != null else "?"))


func require_current(command: String) -> TacticsPawn:
	if current_unit == null or not is_instance_valid(current_unit):
		fail("no turn header before: %s" % command)
		return null
	return current_unit


func slot_for_move(pawn: TacticsPawn, move_id: String) -> int:
	if pawn.stats == null:
		return -1
	for i in range(pawn.stats.move_slots.size()):
		var move: PokemonMoveResource = pawn.stats.move_slots[i]
		if move != null and move.move_id == move_id:
			return i
	return -1


func apply_end_turn(pawn: TacticsPawn) -> void:
	var settle: int = 0
	while settle < 30 and level_alive() and level.is_presentation_busy():
		await tree.physics_frame
		settle += 1
	var active: BattleUnit = level.scheduler.get_active_unit() if level_alive() else null
	if active == null or active.pawn != pawn:
		log_line("%s turn already over" % level.notation.unit_ref(pawn))
		return
	if not await wait_for_turn(pawn):
		return
	pawn.end_pawn_turn()
	level.participant.res.stage = level.participant.res.STAGE_SELECT_PAWN
	log_line("%s ends turn" % level.notation.unit_ref(pawn))
	await wait_turn_change(pawn)


func settle(pawn: TacticsPawn) -> void:
	var frames: int = 0
	while frames < 10 and (pawn.get_tile() == null):
		var ray: RayCast3D = pawn.get_node_or_null("Tile") as RayCast3D
		if ray != null:
			ray.force_raycast_update()
		await tree.physics_frame
		frames += 1


func apply_move(pawn: TacticsPawn, tile_label: String) -> void:
	var participant: TacticsParticipantResource = level.participant.res
	await settle(pawn)
	participant.curr_pawn = pawn
	participant.stage = participant.STAGE_SHOW_MOVEMENTS
	await tree.physics_frame
	await tree.physics_frame
	var tile: TacticsTile = tile_for_label(tile_label)
	if tile == null:
		fail("no tile %s" % tile_label)
		return
	if not tile.reachable:
		level.arena.reset_all_tile_markers()
		level.arena.process_surrounding_tiles(pawn.get_tile(), pawn.stats.movement, pawn.get_parent().get_children())
		level.arena.mark_reachable_tiles(pawn.get_tile(), pawn.stats.movement)
	if not tile.reachable:
		var reachable_count: int = 0
		for key in Targeting.arena_tile_keys(level):
			if (Targeting.arena_tile_keys(level)[key] as TacticsTile).reachable:
				reachable_count += 1
		fail("%s cannot reach %s (movement=%d, tile=%s, reachable=%d, stage=%d)" % [level.notation.unit_ref(pawn), tile_label, pawn.stats.movement, str(pawn.get_tile()), reachable_count, participant.stage])
		participant.stage = participant.STAGE_SHOW_ACTIONS
		return
	level.record_move_intent(pawn, tile)
	pawn.res.pathfinding_tilestack = level.arena.get_pathfinding_tilestack(tile)
	participant.stage = participant.STAGE_MOVE_PAWN
	var frames: int = 0
	while frames < MAX_WAIT_FRAMES and (participant.stage == participant.STAGE_MOVE_PAWN or pawn.res.is_moving or not pawn.res.pathfinding_tilestack.is_empty()):
		await tree.physics_frame
		frames += 1
	if level_alive() and is_instance_valid(pawn):
		log_line("%s moved to %s in %d frames" % [level.notation.unit_name(pawn), level.notation.label_for_pawn(pawn), frames])


func apply_attack(pawn: TacticsPawn, slot: int, target: TacticsPawn) -> void:
	var participant: TacticsParticipantResource = level.participant.res
	var hp_before: int = target.stats.curr_health
	pawn.res.selected_move_index = slot
	participant.curr_pawn = pawn
	participant.attackable_pawn = target
	participant.display_opponent_stats = true
	participant.stage = participant.STAGE_ATTACK
	await tree.physics_frame
	var frames: int = 0
	while frames < MAX_WAIT_FRAMES and level_alive() and is_instance_valid(pawn) and (participant.stage == participant.STAGE_ATTACK or level.is_presentation_busy() or pawn.res.presentation_locked):
		await tree.physics_frame
		frames += 1
	for i in range(3):
		await tree.physics_frame
	if level_alive() and is_instance_valid(target) and target.stats != null:
		log_line("%s used slot %d on %s: HP %d -> %d (%d frames)" % [level.notation.unit_name(pawn), slot + 1, level.notation.unit_name(target), hp_before, target.stats.curr_health, frames])
	else:
		log_line("slot %d used; the battle ended (%d frames)" % [slot + 1, frames])


func apply_use_item(pawn: TacticsPawn, item_id: String) -> void:
	await apply_intent(pawn, BattleActionIntent.use_item(pawn, item_id), "use %s" % item_id)


func apply_throw_item(pawn: TacticsPawn, item_id: String, direction: Vector3i) -> void:
	await apply_intent(pawn, BattleActionIntent.throw_item(pawn, item_id, direction), "throw %s %s" % [item_id, str(direction)])


func apply_intent(pawn: TacticsPawn, intent: BattleActionIntent, label: String) -> void:
	var participant: TacticsParticipantResource = level.participant.res
	participant.curr_pawn = pawn
	participant.pending_intent = intent
	participant.stage = participant.STAGE_ITEM_ACTION
	await tree.physics_frame
	var frames: int = 0
	while frames < MAX_WAIT_FRAMES and level_alive() and is_instance_valid(pawn) and (participant.stage == participant.STAGE_ITEM_ACTION or level.is_presentation_busy() or pawn.res.presentation_locked):
		await tree.physics_frame
		frames += 1
	for i in range(3):
		await tree.physics_frame
	log_line("%s item %s (%d frames)" % [level.notation.unit_name(pawn), label, frames])


func wait_for_turn(pawn: TacticsPawn) -> bool:
	var frames: int = 0
	var auto_ended: Dictionary = {}
	while frames < MAX_WAIT_FRAMES:
		if not level_alive():
			fail("battle ended before %s could act" % str(pawn))
			return false
		var active: BattleUnit = level.scheduler.get_active_unit()
		if active != null and active.pawn == pawn and not level.is_presentation_busy():
			return true
		if level.battle_finished:
			fail("battle ended before %s could act" % level.notation.unit_name(pawn))
			return false
		if auto_end_other_humans and active != null and active.pawn != pawn and not level.is_presentation_busy() and active.control_type == PokemonInstanceResource.ControlType.PLAYER and not auto_ended.has(active.pawn) and frames > 5:
			auto_ended[active.pawn] = true
			log_line("auto-end %s (waiting for %s)" % [level.notation.unit_ref(active.pawn), level.notation.unit_name(pawn)])
			active.pawn.end_pawn_turn()
			level.participant.res.stage = level.participant.res.STAGE_SELECT_PAWN
			await wait_turn_change(active.pawn)
			auto_ended.clear()
		await tree.physics_frame
		frames += 1
	if level_alive():
		fail("timed out waiting for %s's turn (active: %s)" % [level.notation.unit_name(pawn), level.notation.unit_name(level.scheduler.get_active_unit().pawn) if level.scheduler.get_active_unit() != null else "none"])
	else:
		fail("timed out waiting for a turn after the battle ended")
	return false


func wait_turn_change(pawn: TacticsPawn) -> void:
	var frames: int = 0
	while frames < 240 and level_alive() and level.scheduler.get_active_unit() != null and level.scheduler.get_active_unit().pawn == pawn:
		await tree.physics_frame
		frames += 1


func unit_for_ref(ref: String) -> TacticsPawn:
	var key: String = ref.strip_edges()
	if NotationParser.is_unit_id(key):
		var by_id: TacticsPawn = level.notation.pawn_for_id(key)
		if by_id != null:
			return by_id
		var team: Node = level.player if key.begins_with("P") else level.opponent
		var index: int = int(key.substr(1)) - 1
		var pawns: Array[TacticsPawn] = []
		for child in team.get_children():
			if child is TacticsPawn:
				pawns.append(child)
		return pawns[index] if index >= 0 and index < pawns.size() else null
	for pawn in level.units_on_map():
		if level.notation.unit_name(pawn).to_lower() == key.to_lower():
			return pawn
	return null


func tile_for_label(label: String) -> TacticsTile:
	var key: Vector3i = level.notation.grid.key_for_label(label)
	if key.x < 0 and key.y < 0 and key.z < 0:
		return null
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	return keys.get(key, null)


func log_line(text: String) -> void:
	log_lines.append(text)
	if verbose:
		print("driver: %s" % text)


func fail(text: String) -> void:
	failures += 1
	log_lines.append("FAIL " + text)
	push_error("driver: %s" % text)
