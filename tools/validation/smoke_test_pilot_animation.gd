extends SceneTree

const PAWN_SCENE_PATH: String = "res://data/modules/tactics/level/pawn/pawn.tscn"
const EXPERTISE_SCENE_PATH: String = "res://data/modules/stats/expertise/expertise.tscn"
const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/test_arena.tres"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"
const PILOT: Array[Dictionary] = [
	{"slug": "0001_bulbasaur", "aliases": {"Strike": "strike", "Dance": "dance"}, "moves": {"tackle": "Attack", "razor_leaf": "Shoot", "vine_whip": "Swing", "growl": "Sound"}},
	{"slug": "0002_ivysaur", "aliases": {"Strike": "strike", "Dance": "dance"}, "moves": {"tackle": "Attack", "razor_leaf": "Shoot"}},
	{"slug": "0003_venusaur", "aliases": {"Strike": "strike", "Dance": "dance"}, "moves": {"tackle": "Attack", "petal_dance": "Ricochet"}},
	{"slug": "0004_charmander", "aliases": {"Shoot": "shoot"}, "moves": {"scratch": "Scratch", "ember": "Shoot", "flamethrower": "Shoot", "growl": "Sound"}},
	{"slug": "0005_charmeleon", "aliases": {"SpAttack": "sp_attack"}, "moves": {"scratch": "Scratch", "ember": "Shoot"}},
	{"slug": "0006_charizard", "aliases": {"SpAttack": "sp_attack"}, "moves": {"slash": "Slice", "flamethrower": "Shoot", "wing_attack": "Attack"}},
	{"slug": "0007_squirtle", "aliases": {"Strike": "strike"}, "moves": {"tackle": "Attack", "water_gun": "Shoot", "withdraw": "Withdraw", "bite": "Bite"}},
	{"slug": "0008_wartortle", "aliases": {}, "moves": {"tackle": "Attack", "water_gun": "Shoot", "bite": "Bite"}},
	{"slug": "0009_blastoise", "aliases": {}, "moves": {"tackle": "Attack", "hydro_pump": "Shoot", "withdraw": "Withdraw"}},
]

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load(PAWN_SCENE_PATH) as PackedScene
	var expertise_scene: PackedScene = load(EXPERTISE_SCENE_PATH) as PackedScene
	_check_catalogs()
	for entry in PILOT:
		await _check_species(scene, expertise_scene, entry)
	await _check_live_presentation()
	_finish("pilot_animation")


func _check_catalogs() -> void:
	var actions: ActorActionCatalog = ActorActionCatalog.shared()
	_assert_true(actions.actions_by_name.size() >= 100, "gfx action table loaded (%d actions)" % actions.actions_by_name.size())
	_assert_true(actions.name_for(5) == "Attack" and actions.name_for(7) == "Shoot" and actions.name_for(42) == "Rotate", "global action ids resolve to Attack/Shoot/Rotate")
	_assert_true(actions.fallback_chain("Scratch") == ["Scratch", "Slice", "Strike", "MultiStrike", "Attack"], "Scratch fallback chain follows GFXParams")
	var presentation: ActionPresentationCatalog = ActionPresentationCatalog.shared()
	_assert_true(presentation.loaded and presentation.skill_ids().size() >= 40, "presentation catalog covers pilot skills (%d)" % presentation.skill_ids().size())
	_assert_true(presentation.has_item("seed_blast") and presentation.has_skill("water_gun"), "presentation catalog has seed_blast and water_gun")
	var water_gun: Dictionary = presentation.skill("water_gun")
	_assert_true(String(water_gun.get("hitbox", {}).get("type", "")) == "ProjectileAction", "water_gun hitbox is ProjectileAction")
	_assert_true(String(water_gun.get("hitbox", {}).get("char_anim", {}).get("name", "")) == "Shoot", "water_gun char anim resolves to Shoot")


func _check_species(scene: PackedScene, expertise_scene: PackedScene, entry: Dictionary) -> void:
	var slug: String = String(entry.get("slug", ""))
	var path: String = "res://data/models/pokemon/generated/instances/%s.tres" % slug
	var pawn: TacticsPawn = _spawn_pawn(scene, expertise_scene, path)
	await process_frame
	var sprite: TacticsPawnSprite = pawn.get_node("Character") as TacticsPawnSprite
	var sprite_set: PokemonSpriteSetResource = pawn.stats.pokemon_instance.resolved_form().sprite_set
	_assert_true(sprite_set.animation_schema_version >= 2, "%s sprite set uses schema 2" % slug)
	_assert_true(not sprite_set.anchors_path.is_empty() and FileAccess.file_exists(sprite_set.anchors_path), "%s anchors file present" % slug)
	_assert_true(sprite.grounding_mode == TacticsPawnSprite.GROUNDING_SOURCE, "%s uses source shadow grounding" % slug)
	_assert_true(sprite.ground_shadow_px > 0 and sprite.ground_shadow_px <= 8, "%s idle shadow anchor is %d px below cell center" % [slug, sprite.ground_shadow_px])
	_assert_true(sprite.shadow_size > 0, "%s shadow size recorded" % slug)
	for state in ["idle", "walk", "hurt", "faint", "attack", "hop"]:
		_assert_true(sprite.can_play_state(state), "%s can play %s" % [slug, state])
	var aliases: Dictionary = entry.get("aliases", {})
	for source_name in aliases.keys():
		var expected_key: String = String(aliases[source_name])
		var resolved: Dictionary = sprite.resolve_source_state(String(source_name))
		_assert_true(String(resolved.get("state_key", "")) == expected_key and String(resolved.get("tier", "")) == "exact", "%s alias %s -> %s (%s)" % [slug, source_name, resolved.get("state_key", ""), resolved.get("tier", "")])
		var alias_entry: Dictionary = sprite_set.state_entry(expected_key)
		_assert_true(bool(alias_entry.get("alias_only", false)) and not String(alias_entry.get("alias_target", "")).is_empty(), "%s alias %s recorded as alias_only of %s" % [slug, source_name, alias_entry.get("alias_target", "")])
	var attack_timing: Array[int] = sprite.state_timing("attack")
	var anim_root: Dictionary = SpriteAnimData.parse_root(sprite_set.anim_data_path)
	var attack_xml: SpriteAnimData.AnimEntry = anim_root["anims"].get("Attack", null)
	_assert_true(attack_xml != null and attack_timing == attack_xml.durations, "%s attack timing matches AnimData durations" % slug)
	var phases: Dictionary = sprite.state_phase_seconds("attack")
	_assert_true(float(phases.get("total", 0.0)) > 0.3 and float(phases.get("hit", 0.0)) > 0.0 and float(phases.get("hit", 0.0)) <= float(phases.get("total", 0.0)), "%s attack phases: hit %.2fs of %.2fs" % [slug, phases.get("hit", 0.0), phases.get("total", 0.0)])
	if attack_xml != null and attack_xml.hit_frame >= 0:
		_assert_true(int(phases.get("hit_frame", -1)) == attack_xml.hit_frame, "%s attack hit frame %d preserved" % [slug, attack_xml.hit_frame])
	var total: float = sprite.play_action("attack")
	_assert_true(sprite.one_shot and sprite.curr_frame == 0 and total > 0.0, "%s attack plays one-shot from frame 0" % slug)
	var steps: int = int(ceil((total + 0.1) / (1.0 / 60.0)))
	for i in range(steps):
		sprite._process(1.0 / 60.0)
	_assert_true(sprite.is_one_shot_finished() and sprite.curr_frame == int(sprite.state_frame_counts["attack"]) - 1, "%s attack holds last frame after %.2fs" % [slug, total])
	sprite.set_anim_state("idle")
	for i in range(30):
		sprite._process(1.0 / 60.0)
	_assert_true(sprite.current_state == "idle" and not sprite.one_shot, "%s returns to looping idle" % slug)
	var resolver := BattleAnimationResolver.new()
	var moves: Dictionary = entry.get("moves", {})
	for move_id in moves.keys():
		var move: PokemonMoveResource = load("%s%s.tres" % [GENERATED_MOVES_DIR, String(move_id)]) as PokemonMoveResource
		if move == null:
			_fail("%s move %s loads" % [slug, move_id])
			continue
		var log := BattleLog.new()
		var chosen: String = resolver.select_for_move(pawn, move, log)
		var selection: Dictionary = resolver.last_selection
		var expected_action: String = String(moves[move_id])
		var actual_source: String = String(selection.get("source_name", ""))
		var chain: Array[String] = ActorActionCatalog.shared().fallback_chain(expected_action)
		_assert_true(sprite.can_play_state(chosen) and chain.has(actual_source), "%s %s -> %s via source action %s (%s)" % [slug, move_id, chosen, actual_source, selection.get("tier", "")])
	pawn.queue_free()
	await process_frame


func _check_live_presentation() -> void:
	var map: MapDefinitionResource = load(TEST_ARENA_MAP_PATH) as MapDefinitionResource
	var bulbasaur: PokemonInstanceResource = _instance_with_moves("0001_bulbasaur", ["razor_leaf", "tackle", "growl", "vine_whip"], PokemonInstanceResource.Team.PLAYER)
	var charmander: PokemonInstanceResource = _instance_with_moves("0004_charmander", ["scratch", "ember", "growl", "smokescreen"], PokemonInstanceResource.Team.ENEMY)
	var definition := SkirmishDefinitionResource.new()
	definition.skirmish_id = "pilot_presentation"
	definition.map = map
	definition.seed = 101
	definition.player_team = [bulbasaur]
	definition.enemy_team = [charmander]
	definition.control_mode = SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER
	definition.generation_metadata = {"player_spawn_order": [0], "enemy_spawn_order": [0]}
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var level: TacticsLevel = loader.load_skirmish(definition, root)
	_assert_true(level != null, "pilot presentation level loads")
	if level == null:
		return
	level.presentation_runner.immediate_mode = false
	await process_frame
	await process_frame
	var attacker: TacticsPawn = level.player.get_child(0) as TacticsPawn
	var target: TacticsPawn = level.opponent.get_child(0) as TacticsPawn
	_assert_true(attacker != null and target != null, "pilot presentation spawned both pawns")
	var resolver := BattleActionResolver.new()
	var before_hp: int = target.stats.curr_health
	var ok: bool = resolver.execute(attacker, target, 0, level)
	_assert_true(ok, "razor_leaf executes through the resolver")
	_assert_true(level.presentation_runner.is_busy(), "presentation sequence is queued after execution")
	_assert_true(target.stats.curr_health < before_hp or _log_has(level.battle_log, "miss"), "razor_leaf resolved damage or a miss before playback")
	var frames: int = 0
	var saw_projectile: bool = false
	var max_vfx: int = 0
	while level.presentation_runner.is_busy() and frames < 900:
		await process_frame
		frames += 1
		max_vfx = maxi(max_vfx, level.vfx_player.active_count())
		if _log_has(level.battle_log, "vfx_projectile_spawned"):
			saw_projectile = true
	_assert_true(not level.presentation_runner.is_busy(), "presentation sequence finishes within %d frames" % frames)
	_assert_true(frames > 20, "presentation took real time (%d frames)" % frames)
	_assert_true(saw_projectile, "razor_leaf spawned a projectile")
	_assert_true(_log_has(level.battle_log, "presentation_scripted"), "presentation script logged")
	_assert_true(max_vfx > 0, "vfx nodes were active during playback (%d)" % max_vfx)
	var cleanup_frames: int = 0
	while level.vfx_player.active_count() > 0 and cleanup_frames < 400:
		await process_frame
		cleanup_frames += 1
	_assert_true(level.vfx_player.active_count() == 0, "all vfx nodes freed automatically (%d frames)" % cleanup_frames)
	_assert_true(int(level.presentation_runner.stats().get("timeouts", 0)) == 0, "no presentation timeouts")
	var selected: Dictionary = _first_event(level.battle_log, "animation_selected")
	_assert_true(String(selected.get("source_state", "")) == "Shoot", "razor_leaf actor animation used source Shoot state")
	var attacker_sprite: TacticsPawnSprite = attacker.get_node("Character") as TacticsPawnSprite
	_assert_true(attacker_sprite.current_state == "idle", "attacker returned to idle after sequence")
	var facing: Vector3i = Targeting._facing_direction(attacker)
	var attacker_key: Vector3i = Targeting._tile_key(attacker.get_tile())
	var adjacent: TacticsTile = _tile_for_key(level, attacker_key + facing)
	_assert_true(adjacent != null, "arena has a tile in front of the attacker")
	if adjacent != null:
		await _settle_on_tile(target, adjacent)
	_assert_true(Targeting._tile_key(target.get_tile()) == attacker_key + facing, "target moved to the facing tile")
	var melee_ok: bool = resolver.execute(attacker, target, 1, level)
	_assert_true(melee_ok, "tackle executes through the resolver")
	frames = 0
	while level.presentation_runner.is_busy() and frames < 900:
		await process_frame
		frames += 1
	_assert_true(not level.presentation_runner.is_busy() and frames > 10, "tackle dash sequence finishes (%d frames)" % frames)
	_assert_true(attacker_sprite.lunge_offset == Vector3.ZERO, "lunge offset cleared after dash")
	loader.unload_current()
	loader.queue_free()
	await process_frame


func _tile_for_key(level: TacticsLevel, key: Vector3i) -> TacticsTile:
	var tiles: Node = level.arena.get_node_or_null("Tiles")
	if tiles == null:
		return null
	for child in tiles.get_children():
		if child is TacticsTile and Targeting._tile_key(child as TacticsTile) == key:
			return child as TacticsTile
	return null


func _instance_with_moves(slug: String, move_ids: Array, team: int) -> PokemonInstanceResource:
	var template: PokemonInstanceResource = load("res://data/models/pokemon/generated/instances/%s.tres" % slug) as PokemonInstanceResource
	var instance: PokemonInstanceResource = SkirmishMoveLoadout.clone_for_side(template, team, PokemonInstanceResource.ControlType.PLAYER)
	var slots: Array[PokemonMoveResource] = []
	var pp: Array[int] = []
	for move_id in move_ids:
		var move: PokemonMoveResource = load("%s%s.tres" % [GENERATED_MOVES_DIR, String(move_id)]) as PokemonMoveResource
		if move != null:
			slots.append(move)
			pp.append(move.pp)
	instance.move_slots = slots
	instance.pp_state = pp
	return instance


func _spawn_pawn(scene: PackedScene, expertise_scene: PackedScene, instance_path: String) -> TacticsPawn:
	var pawn: TacticsPawn = scene.instantiate() as TacticsPawn
	var expertise: Expertise = expertise_scene.instantiate() as Expertise
	expertise.name = "Expertise"
	expertise.pokemon_instance = load(instance_path) as PokemonInstanceResource
	pawn.add_child(expertise)
	root.add_child(pawn)
	return pawn


func _settle_on_tile(pawn: TacticsPawn, tile: TacticsTile) -> void:
	var ray: RayCast3D = pawn.get_node("Tile") as RayCast3D
	pawn.global_position = tile.global_position + Vector3.UP * 0.05
	ray.force_raycast_update()
	pawn.center()
	ray.force_raycast_update()
	await physics_frame
	await physics_frame


func _log_has(log: BattleLog, kind: String) -> bool:
	for event in log.events:
		if String(event.get("kind", "")) == kind:
			return true
	return false


func _first_event(log: BattleLog, kind: String) -> Dictionary:
	for event in log.events:
		if String(event.get("kind", "")) == kind:
			return event
	return {}


func _assert_true(value: bool, label: String) -> void:
	if value:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: fail - %s" % label)


func _fail(label: String) -> void:
	_assert_true(false, label)


func _finish(name: String) -> void:
	if failures > 0:
		push_error("smoke: %s failed %d check(s)" % [name, failures])
		quit(1)
	else:
		print("smoke: %s clean" % name)
		quit(0)
