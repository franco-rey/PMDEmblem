extends SceneTree

const MAIN_SCENE_PATH: String = "res://assets/scene/main.tscn"
const OUTPUT_DIR: String = "res://logs/debug/live_captures"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"

var captured: Array[String] = []
var main: Node = null
var label_prefix: String = ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.content_scale_size = Vector2i(0, 0)
	UiScale.override_factor = UiScale.compute(Vector2(1920, 1080))
	label_prefix = _arg("label")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	GameSettings.remember_window_size = false
	var scene: PackedScene = load(MAIN_SCENE_PATH)
	main = scene.instantiate()
	root.add_child(main)
	await process_frame
	_apply_border_args()
	var lobby: SkirmishLobby = main.get_node("UI/SkirmishLobby")
	var toggle: Button = main.get_node("UI/MapSelector/SkirmishMenu/CustomToggleButton")
	toggle.emit_signal("pressed")
	await process_frame
	lobby.activate_player_team()
	var entries: Array[Dictionary] = lobby.get_roster_entries()
	var idx: Dictionary = {}
	for i in range(entries.size()):
		idx[String(entries[i].get("slug", ""))] = i
	lobby.add_roster_index(int(idx["0006_charizard"]))
	lobby.set_held_item(SkirmishLobby.SIDE_PLAYER, 0, "seed_blast")
	lobby.activate_enemy_team()
	lobby.add_roster_index(int(idx["0001_bulbasaur"]))
	lobby.set_random_enemy_enabled(false)
	var mode_picker: OptionButton = lobby.find_child("ControlModePicker", true, false)
	for i in range(mode_picker.item_count):
		if String(mode_picker.get_item_metadata(i)) == SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER:
			mode_picker.select(i)
	var seed_input: LineEdit = lobby.find_child("SeedInput", true, false)
	seed_input.text = "777"
	var launch: Button = lobby.find_child("LaunchButton", true, false)
	launch.emit_signal("pressed")
	await process_frame
	await process_frame
	var level: TacticsLevel = main.level_instance
	if level == null:
		print("live: level failed to launch")
		quit(1)
		return
	var frames: int = 0
	while not level._scheduler_started and frames < 1800:
		await process_frame
		frames += 1
	var player_pawn: TacticsPawn = level.player.get_child(0)
	var enemy_pawn: TacticsPawn = level.opponent.get_child(0)
	print("live: level started after %d frames; active=%s" % [frames, level.scheduler.get_active_unit().pawn.name if level.scheduler.get_active_unit() != null else "none"])
	_force_moves(player_pawn, ["ember", "flamethrower", "slash", "wing_attack"])
	_force_moves(enemy_pawn, ["razor_leaf", "tackle", "growl", "vine_whip"])
	await _place_near(level, player_pawn, enemy_pawn, 2)
	await process_frame
	await _snap("live_00_start")
	var participant: TacticsParticipantResource = level.participant.res
	var waited: int = 0
	while level.scheduler.get_active_unit() == null and waited < 1800:
		await process_frame
		waited += 1
	if level.scheduler.get_active_unit() == null:
		print("live: no active unit after %d frames" % waited)
		quit(1)
		return
	var first: TacticsPawn = level.scheduler.get_active_unit().pawn
	var second: TacticsPawn = enemy_pawn if first == player_pawn else player_pawn
	print("live: first actor %s (team %d), target %s" % [first.name, level.scheduler.get_active_unit().team, second.name])
	var hp_before: int = second.stats.curr_health
	await _drive_attack(level, first, second, 0)
	var settle: int = 0
	while settle < 240 and level.scheduler.get_active_unit() != null and level.scheduler.get_active_unit().pawn == first:
		await process_frame
		settle += 1
		if settle == 20:
			await _snap("live_01_attack_t20")
		if settle == 45:
			await _snap("live_02_attack_t45")
		if settle == 80:
			await _snap("live_03_attack_t80")
	print("live: first attack done in %d frames; target hp %d -> %d; runner busy=%s; active now %s" % [settle, hp_before, second.stats.curr_health, str(level.presentation_runner.is_busy()), level.scheduler.get_active_unit().pawn.name if level.scheduler.get_active_unit() != null else "none"])
	await _snap("live_04_after_attack")
	if level.scheduler.get_active_unit() != null and level.scheduler.get_active_unit().pawn == first:
		first.end_pawn_turn()
		participant.stage = participant.STAGE_SELECT_PAWN
	var wait_turn: int = 0
	while wait_turn < 120 and (level.scheduler.get_active_unit() == null or level.scheduler.get_active_unit().pawn != second):
		await process_frame
		wait_turn += 1
	print("live: turn passed to %s after %d frames" % [level.scheduler.get_active_unit().pawn.name if level.scheduler.get_active_unit() != null else "none", wait_turn])
	var active: BattleUnit = level.scheduler.get_active_unit()
	if active != null and active.pawn == second:
		participant.stage = participant.STAGE_SELECT_MOVE
		await process_frame
		await process_frame
		participant.display_opponent_stats = true
		participant.stage = participant.STAGE_DISPLAY_TARGETS
		await process_frame
		await process_frame
		var shown_first: bool = first.get_node("Character/CharacterUI").visible
		var shown_second: bool = second.get_node("Character/CharacterUI").visible
		print("live: player-2 targeting shows HUD on opposing %s=%s and own %s=%s" % [first.name, str(shown_first), second.name, str(shown_second)])
		await _snap("live_05_p2_targeting_hud")
		var hp2: int = first.stats.curr_health
		await _drive_attack(level, second, first, 0)
		settle = 0
		while settle < 240 and level.scheduler.get_active_unit() != null and level.scheduler.get_active_unit().pawn == second:
			await process_frame
			settle += 1
			if settle == 30:
				await _snap("live_06_p2_attack_t30")
		print("live: second attack done in %d frames; target hp %d -> %d" % [settle, hp2, first.stats.curr_health])
	var cam: TacticsCamera = main.find_child("TacticsCamera", true, false)
	if cam != null:
		var before_x: float = cam.t_pivot.rotation_degrees.x
		cam.res.toggle_perspective()
		for i in range(90):
			await process_frame
		print("live: perspective %s pitch %.1f -> %.1f" % [cam.res.perspective, before_x, cam.t_pivot.rotation_degrees.x])
		await _snap("live_07_top_down")
		cam.res.toggle_perspective()
		for i in range(90):
			await process_frame
		await _snap("live_08_isometric_again")
	var kinds: Dictionary = {}
	for event in level.battle_log.events:
		var kind: String = String(event.get("kind", ""))
		kinds[kind] = int(kinds.get(kind, 0)) + 1
	print("live: event kinds %s" % str(kinds))
	for event in level.battle_log.events:
		var kind: String = String(event.get("kind", ""))
		if kind in ["move_used", "move_rejected", "damage_dealt", "miss", "presentation_scripted", "presentation_timeout", "presentation_cancelled", "item_action_rejected", "animation_selected", "vfx_projectile_spawned"]:
			print("live-log: %s" % str(event).substr(0, 220))
	for path in captured:
		print("capture: %s" % path)
	quit(0)


func _drive_attack(level: TacticsLevel, attacker: TacticsPawn, target: TacticsPawn, slot: int) -> void:
	var participant: TacticsParticipantResource = level.participant.res
	attacker.res.selected_move_index = slot
	participant.curr_pawn = attacker
	participant.attackable_pawn = target
	participant.display_opponent_stats = true
	participant.stage = participant.STAGE_ATTACK
	await process_frame


func _force_moves(pawn: TacticsPawn, move_ids: Array) -> void:
	var slots: Array[PokemonMoveResource] = []
	var pp: Array[int] = []
	for move_id in move_ids:
		var move: PokemonMoveResource = load("%s%s.tres" % [GENERATED_MOVES_DIR, String(move_id)])
		if move != null:
			slots.append(move)
			pp.append(move.pp)
	pawn.stats.move_slots = slots
	pawn.stats.current_pp = pp
	pawn.stats.pokemon_instance.move_slots = slots
	pawn.stats.pokemon_instance.pp_state = pp


func _place_near(level: TacticsLevel, anchor: TacticsPawn, mover: TacticsPawn, distance: int) -> void:
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	var anchor_key: Vector3i = Targeting._tile_key(anchor.get_tile())
	for direction in [Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(0, 0, -1), Vector3i(-1, 0, 0)]:
		var ok: bool = true
		for step in range(1, distance + 1):
			if not keys.has(anchor_key + direction * step):
				ok = false
		if ok:
			var tile: TacticsTile = keys[anchor_key + direction * distance]
			var ray: RayCast3D = mover.get_node("Tile")
			mover.global_position = tile.global_position + Vector3.UP * 0.05
			ray.force_raycast_update()
			mover.center()
			ray.force_raycast_update()
			anchor.serv.movement.look_at_direction_8(anchor, Vector3(float(direction.x), 0.0, float(direction.z)))
			mover.serv.movement.look_at_direction_8(mover, Vector3(float(-direction.x), 0.0, float(-direction.z)))
			await physics_frame
			await physics_frame
			print("live: placed %s at %s (anchor %s, dir %s)" % [mover.name, str(Targeting._tile_key(mover.get_tile())), str(anchor_key), str(direction)])
			return
	print("live: could not place mover near anchor")


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null:
		return
	var path: String = "%s/%s%s.png" % [OUTPUT_DIR, label_prefix, label]
	image.save_png(ProjectSettings.globalize_path(path))
	captured.append(path)


func _apply_border_args() -> void:
	var border_arg: String = _arg("border")
	if border_arg.is_valid_int():
		PmdStyle.set_border_style(int(border_arg))
	var color_arg: String = _arg("color")
	if color_arg.is_valid_int():
		PmdStyle.set_border_color(int(color_arg))
	var portrait_arg: String = _arg("portrait")
	if portrait_arg.is_valid_int():
		PmdStyle.set_portrait_border(int(portrait_arg))


func _arg(name: String) -> String:
	for arg in OS.get_cmdline_user_args():
		var text: String = String(arg)
		if text.begins_with("--%s=" % name):
			return text.substr(name.length() + 3)
	return ""
