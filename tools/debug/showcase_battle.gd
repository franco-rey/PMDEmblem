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
var ai: BattleAI = BattleAI.new()
var damage_calculator: DamageResolver = DamageResolver.new()
var turns_taken: int = 0
var status_uses: Dictionary = {}
var seed_value: int = 42
var max_turns: int = MAX_TURNS
var cinematic: bool = false
var fast_turns: int = 0
var code_override: String = ""
var plan_path: String = ""
var spin: bool = false
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
var director: bool = false
var human: bool = false
var human_step: int = 0
var speed_setting: float = 0.0
var center_marker: Node3D = null
var director_turn: int = 0
var director_round: int = -1
var director_shot: String = ""


func _init() -> void:
	call_deferred("_run")


var _settings_snapshot: String = ""


func _snapshot_settings() -> void:
	if FileAccess.file_exists(GameSettings.SETTINGS_PATH):
		_settings_snapshot = FileAccess.get_file_as_string(GameSettings.SETTINGS_PATH)


func _restore_settings() -> void:
	if _settings_snapshot.is_empty():
		return
	var file := FileAccess.open(GameSettings.SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(_settings_snapshot)
		file.close()


func _run() -> void:
	_snapshot_settings()
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
		elif String(arg).begins_with("--plan="):
			plan_path = String(arg).substr(7)
		elif String(arg).begins_with("--spin="):
			spin = String(arg).substr(7) == "1"
		elif String(arg).begins_with("--director="):
			director = String(arg).substr(11) == "1"
		elif String(arg).begins_with("--human="):
			human = String(arg).substr(8) == "1"
		elif String(arg).begins_with("--speed="):
			speed_setting = float(String(arg).substr(8))
		elif String(arg).begins_with("--code="):
			code_override = String(arg).substr(7)
	driver = DRIVER.new(self)
	var ok: bool = await driver._launch(code_override if not code_override.is_empty() else CODE_TEMPLATE % seed_value)
	if not ok:
		print("showcase: launch failed")
		quit(1)
		return
	level = driver.level
	level.battle_ended.connect(_on_battle_ended)
	_skip_intro()
	_index_pawns()
	var plan: Dictionary = _load_plan()
	for slug in plan:
		queues[slug] = (plan[slug] as Array).duplicate(true)
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
	if cinematic:
		GameSettings.battle_flair = true
		if human:
			GameSettings.camera_track = true
		if director:
			GameSettings.camera_track = true
			center_marker = Node3D.new()
			center_marker.name = "DirectorMarker"
			level.add_child(center_marker)
			center_marker.global_position = _board_center()
		if speed_setting > 0.0:
			GameSettings.cpu_speed = speed_setting
		GameSettings.window_mode = "windowed"
		GameSettings.resolution = Vector2i(1920, 1080)
		UiScale.override_factor = 0.0
		GameSettings.ui_scale = 1.0
		GameSettings.apply(root)
		await physics_frame
		await physics_frame
		Input.warp_mouse(Vector2(160.0, float(root.size.y) - 60.0))
	start_frame = Engine.get_physics_frames()
	print("showcase: recording starts at frame %d (%.2f s)" % [start_frame, float(start_frame) / 60.0])
	print("showcase: window=%s root=%s scale=%.2f hud=%s override=%.2f" % [str(DisplayServer.window_get_size()), str(root.size), root.content_scale_factor, str(level.hud.layout_size()), UiScale.override_factor])
	if cinematic:
		base_yaw = level.camera.y_rot
		level.camera.target_fov = 40.0
		if director:
			_director_cut("wide", null, null)
		elif human:
			pass
		else:
			_enter_shot(0)
			_cinematic_tick(0.0)
		_camera_loop()
	await _hold(START_HOLD * (1 if spin else (2 if cinematic else 1)))
	while turns_taken < max_turns and _battle_alive() and not _out_of_time():
		var pawn: TacticsPawn = await _next_active()
		if pawn == null:
			break
		turns_taken += 1
		await _take_turn(pawn)
		await _hold(TURN_HOLD * (2 if spin else (3 if cinematic else 1)))
	print("showcase: seed %d, %d turns taken, %s" % [seed_value, turns_taken, result_line if not result_line.is_empty() else "no result"])
	if director:
		_director_cut("finale", null, null)
		await _hold(END_HOLD * 3)
	else:
		await _hold(END_HOLD)
	_restore_settings()
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


func _board_center() -> Vector3:
	var total: Vector3 = Vector3.ZERO
	var count: int = 0
	for pawn in _all_units():
		total += pawn.global_position
		count += 1
	return total / float(maxi(1, count))


func _director_cut(kind: String, focus: TacticsPawn, other: TacticsPawn) -> void:
	var camera: TacticsCameraResource = level.camera
	director_shot = kind
	orbit_dir = -orbit_dir
	var wants_top_down: bool = kind == "top"
	if wants_top_down != top_down:
		camera.toggle_perspective()
		top_down = wants_top_down
	match kind:
		"wide":
			orbit_speed = 5.0
			camera.x_rot = -34
			camera.target_fov = 42.0
			center_marker.global_position = _board_center()
		"medium":
			orbit_speed = 8.0
			camera.x_rot = -33
			camera.target_fov = 34.0
			var a: Vector3 = focus.global_position if focus != null else _board_center()
			var b: Vector3 = other.global_position if other != null else a
			center_marker.global_position = ((a + b) * 0.5).lerp(_board_center(), 0.35)
		"top":
			orbit_speed = 4.0
			camera.target_fov = 40.0
			center_marker.global_position = _board_center()
		"finale":
			orbit_speed = 14.0
			camera.x_rot = -30
			camera.target_fov = 40.0
			center_marker.global_position = _board_center()
	camera.target = center_marker


func _director_turn_start(pawn: TacticsPawn) -> void:
	director_turn += 1
	if level.round_index != director_round:
		director_round = level.round_index
		_director_cut("wide", null, null)
	elif director_turn % 9 == 0:
		_director_cut("top", null, null)
	elif director_shot == "medium":
		center_marker.global_position = pawn.global_position.lerp(_board_center(), 0.35)


func _director_tick(dt: float) -> void:
	orbit_phase += orbit_dir * orbit_speed * dt
	level.camera.y_rot = int(fmod(float(base_yaw) + 180.0 + orbit_phase + 360.0, 360.0))
	if level.camera.target != center_marker:
		level.camera.target = center_marker


func _camera_loop() -> void:
	var previous: int = -1
	while cinematic and (director or _battle_alive()):
		await physics_frame
		if level == null or not is_instance_valid(level) or level.camera == null:
			return
		if director:
			_director_tick(1.0 / 60.0)
			continue
		if human:
			continue
		var elapsed: float = float(Engine.get_physics_frames() - start_frame) / 60.0
		var index: int = _shot_index_at(elapsed)
		if index != previous:
			_enter_shot(index)
			previous = index
		_cinematic_tick(1.0 / 60.0)


func _shots() -> Array:
	if spin:
		return [[0.0, -30.0, 9.0, -34, 42.0, false], [5.0, 60.0, -14.0, -26, 26.0, false], [10.0, -20.0, 7.0, -40, 36.0, false], [14.5, 0.0, 12.0, -80, 44.0, true], [19.0, 40.0, -9.0, -24, 22.0, false], [24.0, -50.0, 16.0, -30, 34.0, false], [28.0, 25.0, -6.0, -20, 20.0, false]]
	return [[0.0, -25.0, 5.0, -36, 44.0, false], [7.0, 20.0, -4.0, -24, 22.0, false], [13.0, 0.0, 8.0, -80, 40.0, true], [20.0, -40.0, 6.0, -30, 30.0, false], [26.0, 35.0, -5.0, -22, 20.0, false]]


func _load_plan() -> Dictionary:
	if plan_path.is_empty():
		return PLAN
	var text: String = FileAccess.get_file_as_string(plan_path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		print("showcase: plan %s with %d units" % [plan_path, (parsed as Dictionary).size()])
		return parsed
	push_error("showcase: could not read plan %s" % plan_path)
	return PLAN


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
	pawns_by_slug.clear()
	for node in [level.player, level.opponent]:
		for pawn in node.get_children():
			if pawn is TacticsPawn and pawn.stats != null and pawn.stats.pokemon_instance != null and pawn.stats.pokemon_instance.species != null:
				var slug: String = _species_slug(pawn)
				if not pawns_by_slug.has(slug) or not level.notation.unit_id(pawn).ends_with("'"):
					pawns_by_slug[slug] = pawn


func _species_slug(pawn: TacticsPawn) -> String:
	return String(pawn.stats.pokemon_instance.species.species_id).substr(5)


func _slug_of(pawn: TacticsPawn) -> String:
	if pawn == null or not is_instance_valid(pawn) or pawn.stats == null or pawn.stats.pokemon_instance == null or pawn.stats.pokemon_instance.species == null:
		return ""
	return _species_slug(pawn)


func _battle_alive() -> bool:
	return is_instance_valid(level) and not level.battle_finished


func _skip_intro() -> void:
	if level != null and is_instance_valid(level) and level.banner != null and level.banner.intro_active:
		level.banner.finish_intro()


func _hold(frames: int) -> void:
	for i in range(frames):
		if not director:
			_skip_intro()
		await physics_frame


func _next_active() -> TacticsPawn:
	var frames: int = 0
	while frames < 1800 and _battle_alive():
		_skip_intro()
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
	_index_pawns()
	var slug: String = _slug_of(pawn)
	var acted: bool = false
	if director:
		_director_turn_start(pawn)
	if human:
		await _human_turn_start()
		await _hold(24)
	var queue: Array = queues.get(slug, [])
	if level.multiverse != null and not level.multiverse.pending_travel.is_empty() and level.participant.res.stage == level.participant.res.STAGE_SELECT_TRAVEL:
		var hop_choice: int = -1
		if not queue.is_empty() and String((queue[0] as Array)[0]) == "hop":
			hop_choice = int((queue[0] as Array)[1]) if (queue[0] as Array).size() > 1 else 0
			queue.remove_at(0)
		await _answer_travel_picker(pawn, hop_choice)
		if not _battle_alive() or not is_instance_valid(pawn):
			return
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
		elif outcome == "moved":
			queue.remove_at(index)
			if not _battle_alive() or not is_instance_valid(pawn):
				break
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
	if kind == "wait":
		return "done"
	if kind == "map":
		await _press(KEY_M)
		await _hold(int(intent[1]) if intent.size() > 1 else 90)
		await _press(KEY_M)
		await _hold(10)
		return "moved"
	if kind == "zoom_out" or kind == "zoom_in":
		var steps: int = int(intent[1]) if intent.size() > 1 else 6
		for i in range(steps):
			await _press(KEY_MINUS if kind == "zoom_out" else KEY_EQUAL)
			await _hold(6)
		await _hold(int(intent[2]) if intent.size() > 2 else 120)
		return "moved"
	if kind == "move":
		var label: String = String(intent[1])
		if not pawn.res.can_move:
			return "drop"
		print("showcase: %s moves to %s" % [_slug_of(pawn), label])
		if human and human_step % 3 != 0:
			await _human_leave_top_down()
			await _hold(12)
		var tile: TacticsTile = driver._tile_for_label(label) if human else null
		if tile != null:
			await _human_move(pawn, tile)
		else:
			await driver._move(pawn, label)
		return "moved"
	if kind == "self" or kind == "self_low":
		var slot: int = _slot_for(pawn, String(intent[1]))
		if slot < 0:
			return "drop"
		print("showcase: %s uses %s" % [_slug_of(pawn), String(intent[1])])
		await _perform_attack(pawn, slot, pawn)
		return "done"
	if kind == "any":
		if intent.size() > 2:
			travel_choice = int(intent[2])
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
		await _perform_attack(pawn, any_slot, options[0])
		return "done"
	if kind == "attack" and intent.size() > 3:
		travel_choice = int(intent[3])
	var target: TacticsPawn = pawns_by_slug.get(String(intent[2] if kind == "attack" and intent.size() > 2 else intent[intent.size() - 1]), null)
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
		await _approach(pawn, target, move)
		if not _battle_alive() or not is_instance_valid(pawn) or not is_instance_valid(target):
			return "retry"
		if not Targeting.legal_targets_for_move(pawn, move, _all_units()).has(target):
			print("showcase: %s cannot reach %s with %s from %s (target at %s, legal: %s)" % [_slug_of(pawn), _slug_of(target), move.move_id, level.notation.tile_label(Targeting._tile_key(pawn.get_tile())), level.notation.tile_label(Targeting._tile_key(target.get_tile())), _labels(Targeting.legal_targets_for_move(pawn, move, _all_units()))])
			return "retry"
	print("showcase: %s uses %s on %s" % [_slug_of(pawn), move.move_id, _slug_of(target)])
	await _perform_attack(pawn, slot, target)
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


func _controls() -> TacticsControls:
	return driver.main.get_node_or_null("TacticsControls") as TacticsControls


func _show_actions(pawn: TacticsPawn) -> void:
	var participant: TacticsParticipantResource = level.participant.res
	participant.curr_pawn = pawn
	participant.stage = participant.STAGE_SHOW_ACTIONS
	var controls: TacticsControls = _controls()
	if controls != null:
		controls.set_actions_menu_visibility(true, pawn)
	await _hold(18)


const HUMAN_KEYS: Array = [[KEY_P, KEY_MINUS], [KEY_P, KEY_EQUAL], [KEY_E], [KEY_MINUS], [KEY_P], [KEY_P, KEY_Q, KEY_EQUAL]]


func _press(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await physics_frame


func _human_top_down() -> bool:
	return level.camera.perspective == TacticsCameraResource.PERSPECTIVE_TOP_DOWN


func _human_turn_start() -> void:
	human_step += 1
	for code in HUMAN_KEYS[human_step % HUMAN_KEYS.size()]:
		await _press(code)
		await _hold(4)


func _human_leave_top_down() -> void:
	if _human_top_down():
		await _press(KEY_P)


func _human_click(pos: Vector2, hover_frames: int) -> void:
	Input.warp_mouse(pos)
	await _hold(hover_frames)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = pos
		event.global_position = pos
		Input.parse_input_event(event)
		await physics_frame
	await physics_frame


func _human_click_control(control: Control, hover_frames: int) -> bool:
	if control == null or not control.is_visible_in_tree():
		return false
	await _human_click(control.get_global_rect().get_center(), hover_frames)
	return true


func _human_world_point(world: Vector3) -> Vector2:
	return level.get_viewport().get_camera_3d().unproject_position(world + Vector3(0.0, 0.35, 0.0))


func _human_click_world(world: Vector3, hover_frames: int) -> void:
	await _wait_camera_settled()
	Input.warp_mouse(_human_world_point(world))
	await _hold(maxi(hover_frames - 8, 4))
	await _wait_camera_settled()
	await _human_click(_human_world_point(world), 2)


func _wait_camera_settled() -> void:
	var camera: TacticsCamera = level.get_tree().root.find_child("TacticsCamera", true, false) as TacticsCamera
	if camera == null:
		return
	var frames: int = 0
	while frames < 150 and (camera.velocity.length() > 0.05 or camera.res.target != null or camera.res.is_rotating):
		await physics_frame
		frames += 1


func _human_move(pawn: TacticsPawn, tile: TacticsTile) -> void:
	var participant: TacticsParticipantResource = level.participant.res
	await _show_actions(pawn)
	await _human_click_control(_controls().get_act("Move"), 16)
	await _hold(18)
	await _human_click_world(tile.global_position, 26)
	var frames: int = 0
	while frames < 40 and participant.stage != participant.STAGE_MOVE_PAWN and not pawn.res.is_moving:
		await physics_frame
		frames += 1
	if participant.stage != participant.STAGE_MOVE_PAWN and not pawn.res.is_moving:
		await driver._move(pawn, level.notation.tile_label(Targeting._tile_key(tile)))
		return
	frames = 0
	while frames < 900 and _battle_alive() and is_instance_valid(pawn) and (participant.stage == participant.STAGE_MOVE_PAWN or pawn.res.is_moving or not pawn.res.pathfinding_tilestack.is_empty()):
		await physics_frame
		frames += 1


func _human_attack(pawn: TacticsPawn, slot: int, target: TacticsPawn) -> void:
	var participant: TacticsParticipantResource = level.participant.res
	await _show_actions(pawn)
	await _human_click_control(_controls().get_act("Attack"), 16)
	await _hold(36)
	await _human_click_control(_controls().get_node_or_null("HBox/MovePicker/MoveSlot%d" % slot) as Button, 20)
	await _hold(14)
	if not is_instance_valid(pawn) or not is_instance_valid(target):
		return
	await _human_click_world(target.global_position, 30)
	var frames: int = 0
	while frames < 30 and participant.stage != participant.STAGE_ATTACK and is_instance_valid(pawn):
		await physics_frame
		frames += 1
	if not is_instance_valid(pawn):
		return
	if participant.stage == participant.STAGE_ATTACK:
		await _wait_attack_end(pawn)
		await _resolve_travel_choice(pawn)
		return
	await driver._attack(pawn, slot, target)
	await _resolve_travel_choice(pawn)


var travel_choice: int = -1


func _answer_travel_picker(pawn: TacticsPawn, choice: int) -> void:
	if choice >= 0:
		travel_choice = choice
		await _resolve_travel_choice(pawn)
		return
	await _hold(20)
	if human:
		var picker: Control = _controls().get_node_or_null("HBox/TravelPicker") as Control
		var stay: Button = picker.get_node_or_null("Cancel") as Button if picker != null else null
		if stay != null and await _human_click_control(stay, 20):
			await _hold(12)
			return
	level.multiverse.cancel_travel()
	await _hold(12)


func _resolve_travel_choice(_pawn: Variant) -> void:
	if travel_choice < 0 or level.multiverse == null or level.multiverse.pending_travel.is_empty():
		travel_choice = -1
		return
	var choice: int = travel_choice
	travel_choice = -1
	await _hold(20)
	if human:
		var picker: Control = _controls().get_node_or_null("HBox/TravelPicker") as Control
		var button: Button = picker.get_node_or_null("Option%d" % choice) as Button if picker != null else null
		if button != null and await _human_click_control(button, 24):
			await _hold(30)
			return
	level.multiverse.commit_travel(choice)
	await _hold(30)


func _perform_attack(pawn: TacticsPawn, slot: int, target: TacticsPawn) -> void:
	if director and director_shot != "top":
		_director_cut("medium", pawn, target)
	if human:
		await _human_leave_top_down()
		await _hold(12)
		await _human_attack(pawn, slot, target)
		await _resolve_travel_choice(pawn)
		return
	var controls: TacticsControls = _controls()
	if not cinematic or controls == null:
		await driver._attack(pawn, slot, target)
		return
	var participant: TacticsParticipantResource = level.participant.res
	await _show_actions(pawn)
	controls.get_act("Attack").pressed.emit()
	await _hold(40)
	var slot_button: Button = controls.get_node_or_null("HBox/MovePicker/MoveSlot%d" % slot) as Button
	if slot_button != null and participant.stage == participant.STAGE_SELECT_MOVE:
		slot_button.pressed.emit()
		await _hold(30)
	if participant.stage == participant.STAGE_ATTACK:
		await _wait_attack_end(pawn)
		return
	await driver._attack(pawn, slot, target)


func _wait_attack_end(pawn: TacticsPawn) -> void:
	var participant: TacticsParticipantResource = level.participant.res
	var frames: int = 0
	while frames < 900 and _battle_alive() and is_instance_valid(pawn) and (participant.stage == participant.STAGE_ATTACK or level.is_presentation_busy() or pawn.res.presentation_locked):
		await physics_frame
		frames += 1
	for i in range(3):
		await physics_frame


func _approach(pawn: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource = null) -> void:
	if not pawn.res.can_move:
		return
	if cinematic and not human and _controls() != null:
		await _show_actions(pawn)
		_controls().get_act("Move").pressed.emit()
	var arena: TacticsArena = level.arena
	var all_units: Array[TacticsPawn] = _all_units()
	arena.reset_all_tile_markers()
	arena.process_surrounding_tiles(pawn.get_tile(), pawn.stats.movement, pawn.get_parent().get_children())
	arena.mark_reachable_tiles(pawn.get_tile(), pawn.stats.movement)
	var tile: TacticsTile = null
	if move != null and move.tactical_range_kind == PokemonMoveResource.TacticalRangeKind.LINE:
		tile = _line_tile(pawn, target, move, all_units)
	if tile == null:
		tile = arena.get_nearest_target_adjacent_tile(pawn, [target])
	if tile == null:
		tile = _closest_reachable_tile(pawn, target, all_units)
	if tile == null or tile == pawn.get_tile():
		return
	if human:
		await _human_move(pawn, tile)
		return
	if cinematic:
		await _hold(30)
	await driver._move(pawn, level.notation.tile_label(Targeting._tile_key(tile)))


func _line_tile(pawn: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, all_units: Array[TacticsPawn]) -> TacticsTile:
	var target_key: Vector3i = Targeting._tile_key(target.get_tile())
	var own_key: Vector3i = Targeting._tile_key(pawn.get_tile())
	var reach: int = maxi(1, move.tactical_range_value + BattleIntrinsicService.range_bonus_for(pawn.stats, move))
	var best: TacticsTile = null
	var best_distance: int = 1 << 20
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	for key in keys:
		var tile: TacticsTile = keys[key]
		if key != own_key and (not tile.reachable or Targeting.unit_at_key(key, all_units) != null):
			continue
		if key.x != target_key.x and key.z != target_key.z:
			continue
		var gap: int = _chebyshev(key, target_key)
		if gap < 1 or gap > reach:
			continue
		var distance: int = _chebyshev(own_key, key)
		if distance < best_distance:
			best_distance = distance
			best = tile
	return best


func _labels(pawns: Array[TacticsPawn]) -> Array[String]:
	var out: Array[String] = []
	for pawn in pawns:
		out.append(_slug_of(pawn))
	return out


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


func _expected_damage(pawn: TacticsPawn, move: PokemonMoveResource, target: TacticsPawn) -> int:
	var chart: TypeChartResource = level.get_type_chart()
	var type_a: String = target.stats.types[0] if target.stats.types.size() > 0 else "none"
	var type_b: String = target.stats.types[1] if target.stats.types.size() > 1 else "none"
	var effectiveness: float = chart.get_effectiveness_dual(move.type, type_a, type_b) if chart != null else 1.0
	if effectiveness <= 0.0:
		return 0
	var stab: bool = pawn.stats.types.has(move.type)
	return damage_calculator.calculate_damage(pawn.stats, target.stats, move, effectiveness, stab, 1.0, null, {}, true)


func _best_damaging(pawn: TacticsPawn) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = 0.0
	for i in range(pawn.stats.move_slots.size()):
		var move: PokemonMoveResource = pawn.stats.move_slots[i]
		if move == null or not move.is_damaging() or not pawn.stats.has_pp(i):
			continue
		for target in _foe_targets(pawn, move):
			if target.stats.curr_health <= 0:
				continue
			var damage: int = _expected_damage(pawn, move, target)
			if damage <= 0:
				continue
			var accuracy: float = float(move.accuracy) / 100.0 if move.accuracy > 0 else 1.0
			var fraction: float = float(mini(damage, target.stats.curr_health)) / float(maxi(1, target.stats.max_health))
			var score: float = fraction * accuracy
			if damage >= target.stats.curr_health:
				score += 1.0 * accuracy
			score += 0.05 * (1.0 - float(target.stats.curr_health) / float(maxi(1, target.stats.max_health)))
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
		await _perform_attack(pawn, int(pick["slot"]), pick["target"])
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
		await _perform_attack(pawn, i, pawn)
		return true
	print("showcase: %s advances" % slug)
	return false


func _end_turn(pawn: TacticsPawn) -> void:
	if not _battle_alive() or not is_instance_valid(pawn) or not pawn.is_alive():
		return
	var active: BattleUnit = level.scheduler.get_active_unit()
	if active != null and active.pawn == pawn and is_instance_valid(pawn):
		if human and pawn.can_act():
			await _show_actions(pawn)
			if await _human_click_control(_controls().get_act("Wait"), 16):
				if is_instance_valid(pawn):
					await driver._wait_turn_change(pawn)
				return
		pawn.end_pawn_turn()
		level.participant.res.stage = level.participant.res.STAGE_SELECT_PAWN
		await driver._wait_turn_change(pawn)
