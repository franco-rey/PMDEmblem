extends SceneTree

const MAIN_SCENE_PATH: String = "res://assets/scene/main.tscn"
const OUTPUT_DIR: String = "res://logs/debug/vfx_captures"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"
const SCENARIOS: Array = [
	["calm_mind", true, 3],
	["absorb", false, 1],
	["spikes", true, 3],
	["thunderbolt", false, 3],
	["blizzard", false, 3],
	["psychic", false, 3],
	["extreme_speed", false, 3],
	["brick_break", false, 1],
	["ancient_power", false, 3],
	["earthquake", false, 2],
	["hyper_beam", false, 3],
	["leaf_storm", false, 3],
	["swords_dance", true, 3],
	["thunder", false, 3],
	["fire_blast", false, 3],
]

var captured: Array[String] = []
var main: Node = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.content_scale_size = Vector2i(0, 0)
	UiScale.override_factor = UiScale.compute(Vector2(1920, 1080))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scene: PackedScene = load(MAIN_SCENE_PATH)
	main = scene.instantiate()
	root.add_child(main)
	await process_frame
	var lobby: SkirmishLobby = main.get_node("UI/SkirmishLobby")
	var toggle: Button = main.get_node("UI/MapSelector/SkirmishMenu/CustomToggleButton")
	toggle.emit_signal("pressed")
	await process_frame
	lobby.activate_player_team()
	var entries: Array[Dictionary] = lobby.get_roster_entries()
	var idx: Dictionary = {}
	for i in range(entries.size()):
		idx[String(entries[i].get("slug", ""))] = i
	lobby.add_roster_index(int(idx["0009_blastoise"]))
	lobby.activate_enemy_team()
	lobby.add_roster_index(int(idx["0003_venusaur"]))
	lobby.set_random_enemy_enabled(false)
	var mode_picker: OptionButton = lobby.find_child("ControlModePicker", true, false)
	for i in range(mode_picker.item_count):
		if String(mode_picker.get_item_metadata(i)) == SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER:
			mode_picker.select(i)
	var seed_input: LineEdit = lobby.find_child("SeedInput", true, false)
	seed_input.text = "909"
	var launch: Button = lobby.find_child("LaunchButton", true, false)
	launch.emit_signal("pressed")
	await process_frame
	await process_frame
	var level: TacticsLevel = main.level_instance
	if level == null:
		print("vfx-capture: level failed to launch")
		quit(1)
		return
	var frames: int = 0
	while not level._scheduler_started and frames < 300:
		await process_frame
		frames += 1
	var player_pawn: TacticsPawn = level.player.get_child(0)
	var enemy_pawn: TacticsPawn = level.opponent.get_child(0)
	await _place_near(level, player_pawn, enemy_pawn, 3)
	var cam: TacticsCamera = main.find_child("TacticsCamera", true, false)
	if cam != null:
		cam.res.target_fov = 34.0
	for i in range(30):
		await process_frame
	var participant: TacticsParticipantResource = level.participant.res
	for i in range(SCENARIOS.size()):
		var move_id: String = String(SCENARIOS[i][0])
		var self_target: bool = bool(SCENARIOS[i][1])
		var distance: int = int(SCENARIOS[i][2])
		var active: BattleUnit = level.scheduler.get_active_unit()
		if active == null:
			break
		var attacker: TacticsPawn = active.pawn
		var other: TacticsPawn = enemy_pawn if attacker == player_pawn else player_pawn
		var target: TacticsPawn = attacker if self_target else other
		_heal(attacker)
		_heal(other)
		await _place_near(level, attacker, other, distance)
		_force_moves(attacker, [move_id])
		await _drive_attack(level, attacker, target, 0)
		var settle: int = 0
		var start_events: int = level.battle_log.events.size()
		var first_seen: int = -1
		var taken: int = 0
		while settle < 300 and level.scheduler.get_active_unit() != null and level.scheduler.get_active_unit().pawn == attacker:
			await process_frame
			settle += 1
			var visible_fx: int = _effect_count(level.vfx_player)
			if first_seen < 0 and visible_fx > 0:
				first_seen = settle
			if first_seen >= 0 and taken < 3 and (settle == first_seen + 1 or settle == first_seen + 12 or settle == first_seen + 28):
				taken += 1
				await _snap("vfx_%02d_%s_t%02d" % [i, move_id, settle])
		var kinds: Dictionary = {}
		for e in range(start_events, level.battle_log.events.size()):
			var kind: String = String(level.battle_log.events[e].get("kind", ""))
			if kind.begins_with("vfx_") or kind.begins_with("move_") or kind.begins_with("presentation_"):
				kinds[kind] = int(kinds.get(kind, 0)) + 1
			if kind == "move_rejected" or kind == "presentation_timeout":
				print("vfx-capture: %s" % str(level.battle_log.events[e]).substr(0, 240))
		print("vfx-capture: %s by %s settled in %d frames; %s" % [move_id, attacker.name, settle, str(kinds)])
		if level.scheduler.get_active_unit() != null and level.scheduler.get_active_unit().pawn == attacker:
			attacker.end_pawn_turn()
			participant.stage = participant.STAGE_SELECT_PAWN
		var wait_turn: int = 0
		while wait_turn < 180 and (level.scheduler.get_active_unit() == null or level.scheduler.get_active_unit().pawn == attacker):
			await process_frame
			wait_turn += 1
		for j in range(20):
			await process_frame
	for path in captured:
		print("capture: %s" % path)
	quit(0)


func _effect_count(player: BattleVFXPlayer) -> int:
	var count: int = 0
	for child in player.get_children():
		if child is CanvasLayer:
			count += (child as CanvasLayer).get_child_count()
		elif child is Node3D and (child as Node3D).visible:
			count += 1
	return count


func _heal(pawn: TacticsPawn) -> void:
	pawn.stats.curr_health = pawn.stats.max_health


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
			return
	print("vfx-capture: could not place mover near anchor")


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null:
		return
	var path: String = "%s/%s.png" % [OUTPUT_DIR, label]
	image.save_png(ProjectSettings.globalize_path(path))
	captured.append(path)
