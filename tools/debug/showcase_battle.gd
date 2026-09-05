extends SceneTree

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const CODE_TEMPLATE: String = "match seed=%d mode=pvp p=0006_charizard@60:flamethrower,air_slash,fire_spin,dragon_dance:blaze:held_focus_sash|0009_blastoise@60:hydro_pump,rain_dance,ice_beam,rapid_spin:torrent:berry_sitrus|0003_venusaur@60:solar_beam,leech_seed,sleep_powder,sludge_bomb:chlorophyll:held_life_orb|0025_pikachu@60:thunder,quick_attack,thunder_wave,iron_tail:static:held_light_ball|0094_gengar@60:shadow_ball,confuse_ray,sludge_bomb,dark_pulse:cursed_body:held_focus_sash|0068_machamp@60:cross_chop,bulk_up,rock_slide,dynamic_punch:guts:held_flame_orb|0130_gyarados@60:waterfall,dragon_dance,ice_fang,crunch:intimidate:held_leftovers|0065_alakazam@60:psybeam,calm_mind,recover,shadow_ball:synchronize:berry_sitrus e=0248_tyranitar@60:stone_edge,crunch,earthquake,stealth_rock:sand_stream:held_weakness_policy|0149_dragonite@60:outrage,fire_punch,dragon_dance,extreme_speed:multiscale:berry_lum|0143_snorlax@60:body_slam,rest,yawn,crunch:thick_fat:held_leftovers|0448_lucario@60:aura_sphere,close_combat,bone_rush,swords_dance:inner_focus:held_life_orb|0076_golem@60:rollout,explosion,rock_blast,defense_curl:sturdy:held_air_balloon|0059_arcanine@60:flare_blitz,extreme_speed,crunch,will_o_wisp:intimidate:berry_sitrus|0131_lapras@60:ice_beam,hydro_pump,sing,thunderbolt:water_absorb:held_rocky_helmet|0212_scizor@60:bullet_punch,swords_dance,x_scissor,u_turn:technician:held_focus_sash"
const MAX_TURNS: int = 112
const START_HOLD: int = 120
const END_HOLD: int = 200
const TURN_HOLD: int = 24
const LOW_HP_FRACTION: float = 0.4
const PLAN: Dictionary = {
	"charizard": [["self", "dragon_dance"], ["attack", "flamethrower", "scizor"], ["attack", "air_slash", "lucario"], ["attack", "fire_spin", "snorlax"]],
	"blastoise": [["self", "rain_dance"], ["attack", "hydro_pump", "arcanine"], ["attack", "hydro_pump", "tyranitar"], ["attack", "ice_beam", "dragonite"]],
	"venusaur": [["attack", "leech_seed", "snorlax"], ["attack", "sleep_powder", "dragonite"], ["attack", "solar_beam", "lapras"], ["attack", "sludge_bomb", "lapras"]],
	"pikachu": [["attack", "thunder_wave", "dragonite"], ["attack", "thunder", "lapras"], ["attack", "thunder", "scizor"], ["attack", "iron_tail", "tyranitar"]],
	"gengar": [["attack", "confuse_ray", "snorlax"], ["attack", "shadow_ball", "lucario"], ["attack", "dark_pulse", "lucario"], ["attack", "sludge_bomb", "arcanine"]],
	"machamp": [["self", "bulk_up"], ["attack", "cross_chop", "tyranitar"], ["attack", "dynamic_punch", "snorlax"], ["attack", "rock_slide", "arcanine"]],
	"gyarados": [["self", "dragon_dance"], ["attack", "waterfall", "golem"], ["attack", "ice_fang", "dragonite"], ["attack", "crunch", "lucario"]],
	"alakazam": [["self", "calm_mind"], ["attack", "psybeam", "lucario"], ["self_low", "recover"], ["attack", "shadow_ball", "lapras"]],
	"tyranitar": [["self", "stealth_rock"], ["attack", "stone_edge", "charizard"], ["attack", "crunch", "alakazam"], ["attack", "earthquake", "pikachu"]],
	"dragonite": [["self", "dragon_dance"], ["attack", "outrage", "machamp"], ["attack", "fire_punch", "venusaur"]],
	"snorlax": [["attack", "yawn", "gengar"], ["attack", "body_slam", "pikachu"], ["self_low", "rest"], ["attack", "crunch", "alakazam"]],
	"lucario": [["self", "swords_dance"], ["attack", "bone_rush", "pikachu"], ["attack", "aura_sphere", "blastoise"], ["attack", "close_combat", "gyarados"]],
	"golem": [["self", "defense_curl"], ["any", "rollout"], ["self_low", "explosion"], ["any", "rollout"], ["attack", "rock_blast", "charizard"]],
	"arcanine": [["attack", "will_o_wisp", "machamp"], ["attack", "flare_blitz", "venusaur"], ["attack", "extreme_speed", "pikachu"], ["attack", "crunch", "gengar"]],
	"lapras": [["attack", "sing", "gyarados"], ["attack", "ice_beam", "venusaur"], ["attack", "thunderbolt", "gyarados"], ["attack", "hydro_pump", "charizard"]],
	"scizor": [["self", "swords_dance"], ["attack", "bullet_punch", "alakazam"], ["attack", "x_scissor", "alakazam"], ["attack", "u_turn", "gengar"]],
}

var driver = null
var level: TacticsLevel = null
var pawns_by_slug: Dictionary = {}
var queues: Dictionary = {}
var attempts: Dictionary = {}
var ai: MinimumViableAI = MinimumViableAI.new()
var turns_taken: int = 0
var status_uses: Dictionary = {}
var seed_value: int = 42
var max_turns: int = MAX_TURNS
var cinematic: bool = false
var fast_turns: int = 0
var max_seconds: float = 0.0
var start_frame: int = 0
var shot_index: int = 0
var base_yaw: int = -45
var orbit_phase: float = 0.0
var orbit_dir: float = 1.0
var orbit_speed: float = 40.0
var orbit_arc: float = 80.0
var top_down: bool = false
var result_line: String = ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.content_scale_size = Vector2i(0, 0)
	UiScale.override_factor = UiScale.compute(Vector2(1920, 1080))
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--seed="):
			seed_value = int(String(arg).substr(7))
		elif String(arg).begins_with("--turns="):
			max_turns = int(String(arg).substr(8))
		elif String(arg).begins_with("--cinematic="):
			cinematic = String(arg).substr(12) == "1"
		elif String(arg).begins_with("--seconds="):
			max_seconds = float(String(arg).substr(10))
		elif String(arg).begins_with("--fast-turns="):
			fast_turns = int(String(arg).substr(13))
	driver = DRIVER.new(self)
	var ok: bool = await driver._launch(CODE_TEMPLATE % seed_value)
	if not ok:
		print("showcase: launch failed")
		quit(1)
		return
	level = driver.level
	level.battle_ended.connect(_on_battle_ended)
	_index_pawns()
	for slug in PLAN:
		queues[slug] = (PLAN[slug] as Array).duplicate(true)
	if fast_turns > 0:
		level.presentation_runner.immediate_mode = true
		while turns_taken < fast_turns and _battle_alive():
			var fast_pawn: TacticsPawn = await _next_active()
			if fast_pawn == null:
				break
			turns_taken += 1
			await _take_turn(fast_pawn)
		level.presentation_runner.immediate_mode = false
		print("showcase: fast phase ended after %d turns at %.2f s" % [turns_taken, float(Engine.get_physics_frames()) / 60.0])
	start_frame = Engine.get_physics_frames()
	if cinematic:
		base_yaw = level.camera.y_rot
		level.camera.target_fov = 40.0
		_enter_shot(0)
		_cinematic_tick(0.0)
		_camera_loop()
	await _hold(START_HOLD * (2 if cinematic else 1))
	while turns_taken < max_turns and _battle_alive() and not _out_of_time():
		var pawn: TacticsPawn = await _next_active()
		if pawn == null:
			break
		turns_taken += 1
		await _take_turn(pawn)
		await _hold(TURN_HOLD * (3 if cinematic else 1))
	print("showcase: seed %d, %d turns taken, %s" % [seed_value, turns_taken, result_line if not result_line.is_empty() else "no result"])
	await _hold(END_HOLD)
	quit(0)


func _on_battle_ended(result: int) -> void:
	var player_alive: int = 0
	var enemy_alive: int = 0
	var player_hp: int = 0
	var enemy_hp: int = 0
	for pawn in level.player.get_children():
		if pawn is TacticsPawn and pawn.is_alive():
			player_alive += 1
			player_hp += pawn.stats.curr_health
	for pawn in level.opponent.get_children():
		if pawn is TacticsPawn and pawn.is_alive():
			enemy_alive += 1
			enemy_hp += pawn.stats.curr_health
	result_line = "result=%d player_standing=%d (%d hp) enemy_standing=%d (%d hp)" % [result, player_alive, player_hp, enemy_alive, enemy_hp]


func _out_of_time() -> bool:
	if max_seconds <= 0.0:
		return false
	return float(Engine.get_physics_frames() - start_frame) / 60.0 >= max_seconds - float(END_HOLD) / 60.0


func _next_shot() -> void:
	pass


func _camera_loop() -> void:
	var previous: int = -1
	while cinematic and _battle_alive():
		await physics_frame
		var elapsed: float = float(Engine.get_physics_frames() - start_frame) / 60.0
		var index: int = _shot_index_at(elapsed)
		if index != previous:
			_enter_shot(index)
			previous = index
		_cinematic_tick(1.0 / 60.0)


func _shots() -> Array:
	return [[0.0, -20.0, 6.0, -34, 40.0, false], [9.0, 30.0, -4.0, -26, 26.0, false], [17.0, 0.0, 9.0, -80, 38.0, true], [24.0, -45.0, 5.0, -30, 30.0, false]]


func _shot_index_at(elapsed: float) -> int:
	var shots: Array = _shots()
	var index: int = 0
	for i in range(shots.size()):
		if elapsed >= float(shots[i][0]):
			index = i
	return index


func _enter_shot(index: int) -> void:
	var shot: Array = _shots()[index]
	var camera: TacticsCameraResource = level.camera
	orbit_phase = float(shot[1])
	orbit_speed = absf(float(shot[2]))
	orbit_dir = signf(float(shot[2]))
	var wants_top_down: bool = bool(shot[5])
	if wants_top_down != top_down:
		camera.toggle_perspective()
		top_down = wants_top_down
	if not top_down:
		camera.x_rot = int(shot[3])
	camera.target_fov = float(shot[4])
	shot_index = index


func _cinematic_tick(dt: float) -> void:
	orbit_phase += orbit_dir * orbit_speed * dt
	level.camera.y_rot = int(fmod(float(base_yaw) + 180.0 + orbit_phase + 360.0, 360.0))


func _punch_in() -> void:
	if cinematic:
		level.camera.target_fov = maxf(level.camera.min_zoom, level.camera.target_fov - 3.0)


func _index_pawns() -> void:
	for node in [level.player, level.opponent]:
		for pawn in node.get_children():
			if pawn is TacticsPawn and pawn.stats != null and pawn.stats.pokemon_instance != null and pawn.stats.pokemon_instance.species != null:
				var species_id: String = String(pawn.stats.pokemon_instance.species.species_id)
				pawns_by_slug[species_id.substr(5)] = pawn


func _slug_of(pawn: TacticsPawn) -> String:
	for slug in pawns_by_slug:
		if pawns_by_slug[slug] == pawn:
			return slug
	return ""


func _battle_alive() -> bool:
	return is_instance_valid(level) and not level.battle_finished


func _hold(frames: int) -> void:
	for i in range(frames):
		await physics_frame


func _next_active() -> TacticsPawn:
	var frames: int = 0
	while frames < 1800 and _battle_alive():
		var active: BattleUnit = level.scheduler.get_active_unit()
		if active != null and active.pawn != null and is_instance_valid(active.pawn) and not level.is_presentation_busy():
			return active.pawn
		await physics_frame
		frames += 1
	return null


func _all_units() -> Array[TacticsPawn]:
	var out: Array[TacticsPawn] = []
	for node in [level.player, level.opponent]:
		for pawn in node.get_children():
			if pawn is TacticsPawn:
				out.append(pawn)
	return out


func _foes_of(pawn: TacticsPawn) -> Array:
	return level.opponent.get_children() if pawn.get_parent() == level.player else level.player.get_children()


func _slot_for(pawn: TacticsPawn, move_id: String) -> int:
	for i in range(pawn.stats.move_slots.size()):
		var move: PokemonMoveResource = pawn.stats.move_slots[i]
		if move != null and move.move_id == move_id and pawn.stats.has_pp(i):
			return i
	return -1


func _take_turn(pawn: TacticsPawn) -> void:
	var slug: String = _slug_of(pawn)
	var acted: bool = false
	var queue: Array = queues.get(slug, [])
	var index: int = 0
	while index < queue.size() and not acted:
		var intent: Array = queue[index]
		var kind: String = String(intent[0])
		if kind == "self_low" and float(pawn.stats.curr_health) > float(pawn.stats.max_health) * LOW_HP_FRACTION:
			index += 1
			continue
		var outcome: String = await _execute_intent(pawn, intent)
		if outcome == "done":
			queue.remove_at(index)
			acted = true
		elif outcome == "drop":
			queue.remove_at(index)
		else:
			var key: String = "%s:%d" % [slug, index]
			attempts[key] = int(attempts.get(key, 0)) + 1
			if int(attempts[key]) >= 3:
				queue.remove_at(index)
			break
	if not acted and _battle_alive() and is_instance_valid(pawn):
		acted = await _fallback(pawn)
	if _battle_alive() and is_instance_valid(pawn):
		await _end_turn(pawn)


func _execute_intent(pawn: TacticsPawn, intent: Array) -> String:
	var kind: String = String(intent[0])
	if kind == "self" or kind == "self_low":
		var slot: int = _slot_for(pawn, String(intent[1]))
		if slot < 0:
			return "drop"
		print("showcase: %s uses %s" % [_slug_of(pawn), String(intent[1])])
		await driver._attack(pawn, slot, pawn)
		return "done"
	if kind == "any":
		var any_slot: int = _slot_for(pawn, String(intent[1]))
		if any_slot < 0:
			return "drop"
		var any_move: PokemonMoveResource = pawn.stats.move_slots[any_slot]
		var options: Array[TacticsPawn] = _foe_targets(pawn, any_move)
		if options.is_empty():
			var nearest: TacticsPawn = _nearest_foe(pawn)
			if nearest == null:
				return "drop"
			await _approach(pawn, nearest)
			if not _battle_alive() or not is_instance_valid(pawn):
				return "retry"
			options = _foe_targets(pawn, any_move)
		if options.is_empty():
			return "retry"
		print("showcase: %s uses %s on %s" % [_slug_of(pawn), any_move.move_id, _slug_of(options[0])])
		await driver._attack(pawn, any_slot, options[0])
		return "done"
	var target: TacticsPawn = pawns_by_slug.get(String(intent[intent.size() - 1]), null)
	if target == null or not is_instance_valid(target) or not target.is_alive():
		return "drop"
	if kind == "throw":
		if await _throw_at(pawn, target):
			return "done"
		await _approach(pawn, target)
		if await _throw_at(pawn, target):
			return "done"
		return "retry"
	var slot: int = _slot_for(pawn, String(intent[1]))
	if slot < 0:
		return "drop"
	var move: PokemonMoveResource = pawn.stats.move_slots[slot]
	if not Targeting.legal_targets_for_move(pawn, move, _all_units()).has(target):
		await _approach(pawn, target)
		if not _battle_alive() or not is_instance_valid(pawn) or not is_instance_valid(target):
			return "retry"
		if not Targeting.legal_targets_for_move(pawn, move, _all_units()).has(target):
			return "retry"
	print("showcase: %s uses %s on %s" % [_slug_of(pawn), move.move_id, _slug_of(target)])
	await driver._attack(pawn, slot, target)
	return "done"


func _throw_at(pawn: TacticsPawn, target: TacticsPawn) -> bool:
	var held: PokemonItemResource = PokemonItemService.held_item_for(pawn.stats)
	if held == null:
		return false
	var throw_range: int = ai._throw_range(held)
	for option in Targeting.throw_options(pawn, throw_range, _all_units(), Targeting.arena_tile_keys(level)):
		var hit: TacticsPawn = option.get("hit_unit", null) as TacticsPawn
		if hit == target:
			print("showcase: %s throws %s at %s" % [_slug_of(pawn), held.item_id, _slug_of(target)])
			await _run_item_intent(pawn, BattleActionIntent.throw_item(pawn, held.item_id, option.get("direction", Vector3i.ZERO), target), target)
			return true
	return false


func _run_item_intent(pawn: TacticsPawn, intent: BattleActionIntent, target: TacticsPawn) -> void:
	var participant: TacticsParticipantResource = level.participant.res
	participant.curr_pawn = pawn
	participant.pending_intent = intent
	participant.attackable_pawn = target
	participant.display_opponent_stats = true
	participant.stage = participant.STAGE_ATTACK
	await physics_frame
	var frames: int = 0
	while frames < 900 and _battle_alive() and is_instance_valid(pawn) and (participant.stage == participant.STAGE_ATTACK or level.is_presentation_busy()):
		await physics_frame
		frames += 1
	for i in range(3):
		await physics_frame


func _approach(pawn: TacticsPawn, target: TacticsPawn) -> void:
	if not pawn.res.can_move:
		return
	var arena: TacticsArena = level.arena
	var all_units: Array[TacticsPawn] = _all_units()
	arena.reset_all_tile_markers()
	arena.process_surrounding_tiles(pawn.get_tile(), pawn.stats.movement, pawn.get_parent().get_children())
	arena.mark_reachable_tiles(pawn.get_tile(), pawn.stats.movement)
	var tile: TacticsTile = arena.get_nearest_target_adjacent_tile(pawn, [target])
	if tile == null:
		tile = _closest_reachable_tile(pawn, target, all_units)
	if tile == null or tile == pawn.get_tile():
		return
	await driver._move(pawn, level.notation.tile_label(Targeting._tile_key(tile)))


func _closest_reachable_tile(pawn: TacticsPawn, target: TacticsPawn, all_units: Array[TacticsPawn]) -> TacticsTile:
	var target_key: Vector3i = Targeting._tile_key(target.get_tile())
	var own_key: Vector3i = Targeting._tile_key(pawn.get_tile())
	var best: TacticsTile = null
	var best_distance: int = _chebyshev(own_key, target_key)
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	for key in keys:
		var tile: TacticsTile = keys[key]
		if not tile.reachable or Targeting.unit_at_key(key, all_units) != null:
			continue
		var distance: int = _chebyshev(key, target_key)
		if distance < best_distance:
			best_distance = distance
			best = tile
	return best


func _chebyshev(a: Vector3i, b: Vector3i) -> int:
	return maxi(absi(a.x - b.x), absi(a.z - b.z))


func _foe_targets(pawn: TacticsPawn, move: PokemonMoveResource) -> Array[TacticsPawn]:
	var out: Array[TacticsPawn] = []
	var foes: Array = _foes_of(pawn)
	for candidate in Targeting.legal_targets_for_move(pawn, move, _all_units()):
		if foes.has(candidate) and candidate.is_alive():
			out.append(candidate)
	return out


func _nearest_foe(pawn: TacticsPawn) -> TacticsPawn:
	var best: TacticsPawn = null
	var best_distance: int = 1 << 20
	var own_key: Vector3i = Targeting._tile_key(pawn.get_tile())
	for foe in _foes_of(pawn):
		if not (foe is TacticsPawn) or not foe.is_alive():
			continue
		var distance: int = _chebyshev(own_key, Targeting._tile_key(foe.get_tile()))
		if distance < best_distance:
			best_distance = distance
			best = foe
	return best


func _best_damaging(pawn: TacticsPawn) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = 0.0
	var chart: TypeChartResource = level.get_type_chart()
	for i in range(pawn.stats.move_slots.size()):
		var move: PokemonMoveResource = pawn.stats.move_slots[i]
		if move == null or not move.is_damaging() or not pawn.stats.has_pp(i):
			continue
		for target in _foe_targets(pawn, move):
			var score: float = ai._score_move(pawn, move, target, chart, _foes_of(pawn))
			if target.stats.curr_health <= 0:
				continue
			if score > best_score:
				best_score = score
				best = {"slot": i, "target": target, "move": move}
	return best


func _fallback(pawn: TacticsPawn) -> bool:
	var pick: Dictionary = _best_damaging(pawn)
	if pick.is_empty():
		var nearest: TacticsPawn = _nearest_foe(pawn)
		if nearest == null:
			return false
		await _approach(pawn, nearest)
		if not _battle_alive() or not is_instance_valid(pawn):
			return false
		pick = _best_damaging(pawn)
	if not pick.is_empty():
		print("showcase: %s uses %s on %s" % [_slug_of(pawn), (pick["move"] as PokemonMoveResource).move_id, _slug_of(pick["target"])])
		_punch_in()
		await driver._attack(pawn, int(pick["slot"]), pick["target"])
		if cinematic:
			await _hold(TURN_HOLD * 2)
		return true
	var slug: String = _slug_of(pawn)
	for i in range(pawn.stats.move_slots.size()):
		var move: PokemonMoveResource = pawn.stats.move_slots[i]
		if move == null or move.is_damaging() or not pawn.stats.has_pp(i) or not move.can_target_self():
			continue
		var key: String = "%s:%s" % [slug, move.move_id]
		if int(status_uses.get(key, 0)) >= 2:
			continue
		status_uses[key] = int(status_uses.get(key, 0)) + 1
		print("showcase: %s sets up with %s" % [slug, move.move_id])
		await driver._attack(pawn, i, pawn)
		return true
	print("showcase: %s advances" % slug)
	return false


func _end_turn(pawn: TacticsPawn) -> void:
	if not _battle_alive() or not is_instance_valid(pawn) or not pawn.is_alive():
		return
	var active: BattleUnit = level.scheduler.get_active_unit()
	if active != null and active.pawn == pawn:
		pawn.end_pawn_turn()
		level.participant.res.stage = level.participant.res.STAGE_SELECT_PAWN
		await driver._wait_turn_change(pawn)
