extends SceneTree

const PAWN_SCENE_PATH: String = "res://data/modules/tactics/level/pawn/pawn.tscn"
const EXPERTISE_SCENE_PATH: String = "res://data/modules/stats/expertise/expertise.tscn"
const BULBASAUR_PATH: String = "res://data/models/pokemon/generated/instances/0001_bulbasaur.tres"
const SQUIRTLE_PATH: String = "res://data/models/pokemon/generated/instances/0007_squirtle.tres"
const GALLADE_PATH: String = "res://data/models/pokemon/generated/instances/0475_gallade.tres"

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load(PAWN_SCENE_PATH) as PackedScene
	var expertise_scene: PackedScene = load(EXPERTISE_SCENE_PATH) as PackedScene
	var pawn: TacticsPawn = _spawn_pawn(scene, expertise_scene, BULBASAUR_PATH)
	await process_frame

	var sprite: TacticsPawnSprite = pawn.get_node("Character") as TacticsPawnSprite
	var resolver := BattleAnimationResolver.new()
	_check_playback(resolver, pawn, sprite, _move("physical", PokemonMoveResource.CATEGORY_PHYSICAL), "move_use", "physical move-use")
	_check_playback(resolver, pawn, sprite, _move("special", PokemonMoveResource.CATEGORY_SPECIAL), "move_use", "special move-use")
	_check_playback(resolver, pawn, sprite, _move("status", PokemonMoveResource.CATEGORY_STATUS), "move_use", "status move-use")
	_check_reaction(resolver, pawn, sprite, "heal")
	_check_reaction(resolver, pawn, sprite, "buff")
	_check_reaction(resolver, pawn, sprite, "debuff")
	_check_reaction(resolver, pawn, sprite, "miss")
	_check_reaction(resolver, pawn, sprite, "receive_damage")
	_check_reaction(resolver, pawn, sprite, "faint")
	pawn.queue_free()

	var squirtle: TacticsPawn = _spawn_pawn(scene, expertise_scene, SQUIRTLE_PATH)
	await process_frame
	var squirtle_sprite: TacticsPawnSprite = squirtle.get_node("Character") as TacticsPawnSprite
	_check_move_map_ignored_for_reactions(resolver, squirtle, squirtle_sprite)
	squirtle.queue_free()

	var gallade: TacticsPawn = _spawn_pawn(scene, expertise_scene, GALLADE_PATH)
	await process_frame
	var gallade_sprite: TacticsPawnSprite = gallade.get_node("Character") as TacticsPawnSprite
	_check_sleep_backed_faint(resolver, gallade, gallade_sprite)
	gallade.queue_free()

	await _check_current_roster_faint_reactions(scene, expertise_scene, resolver)
	_finish("animation_playback")


func _spawn_pawn(scene: PackedScene, expertise_scene: PackedScene, instance_path: String) -> TacticsPawn:
	var pawn: TacticsPawn = scene.instantiate() as TacticsPawn
	var expertise: Expertise = expertise_scene.instantiate() as Expertise
	expertise.name = "Expertise"
	expertise.pokemon_instance = load(instance_path) as PokemonInstanceResource
	pawn.add_child(expertise)
	root.add_child(pawn)
	return pawn


func _check_playback(
		resolver: BattleAnimationResolver,
		pawn: TacticsPawn,
		sprite: TacticsPawnSprite,
		move: PokemonMoveResource,
		purpose: String,
		label: String
) -> void:
	var log := BattleLog.new()
	var chosen: String = resolver.select_for_move(pawn, move, log)
	_assert_true(sprite.can_play_state(chosen), "%s chose playable state %s" % [label, chosen])
	_assert_true(pawn.res.forced_anim_state == chosen, "%s handed state to pawn playback" % label)
	_assert_true(_has_animation_event(log, purpose), "%s emitted animation event" % label)


func _check_reaction(resolver: BattleAnimationResolver, pawn: TacticsPawn, sprite: TacticsPawnSprite, purpose: String) -> void:
	var log := BattleLog.new()
	var chosen: String = resolver.select_reaction(pawn, _move(purpose, PokemonMoveResource.CATEGORY_STATUS), purpose, log)
	_assert_true(sprite.can_play_state(chosen), "%s reaction chose playable state %s" % [purpose, chosen])
	_assert_true(pawn.res.forced_anim_state == chosen, "%s reaction handed state to pawn playback" % purpose)
	_assert_true(_has_animation_event(log, purpose), "%s reaction emitted animation event" % purpose)


func _check_move_map_ignored_for_reactions(resolver: BattleAnimationResolver, pawn: TacticsPawn, sprite: TacticsPawnSprite) -> void:
	var damage_log := BattleLog.new()
	var damage_move: PokemonMoveResource = _move("water_pulse", PokemonMoveResource.CATEGORY_SPECIAL)
	var damage_chosen: String = resolver.select_reaction(pawn, damage_move, "receive_damage", damage_log)
	_assert_true(damage_chosen == "hurt", "receive-damage reaction ignores same-species move-use animation map")

	var faint_log := BattleLog.new()
	var faint_chosen: String = resolver.select_reaction(pawn, damage_move, "faint", faint_log)
	if sprite.can_play_state("special_attack"):
		sprite.set_anim_state("special_attack")
		sprite.frame = maxi(0, sprite.hframes * sprite.vframes - 1)
	sprite.set_anim_state(faint_chosen)
	_assert_true(faint_chosen == "faint", "faint reaction ignores same-species move-use animation map")
	_assert_true(sprite.hframes == 4, "explicit faint sheet is sliced into four frames")
	_assert_true(sprite.vframes == 1, "explicit faint sheet uses one facing row")
	_assert_true(sprite.frame == 0, "explicit faint resets displayed frame")
	_assert_true(_has_animation_event(damage_log, "receive_damage"), "receive-damage reaction emitted animation event")
	_assert_true(_has_animation_event(faint_log, "faint"), "faint reaction emitted animation event")


func _check_sleep_backed_faint(resolver: BattleAnimationResolver, pawn: TacticsPawn, sprite: TacticsPawnSprite) -> void:
	var log := BattleLog.new()
	var chosen: String = resolver.select_reaction(pawn, _move("faint_probe", PokemonMoveResource.CATEGORY_STATUS), "faint", log)
	if sprite.can_play_state("physical_attack"):
		sprite.set_anim_state("physical_attack")
		sprite.frame = maxi(0, sprite.hframes * sprite.vframes - 1)
	sprite.set_anim_state(chosen)
	_assert_true(chosen == "faint", "sleep-backed faint keeps faint semantic state")
	_assert_true(sprite.hframes == 2, "sleep-backed faint is sliced into two frames")
	_assert_true(sprite.vframes == 1, "sleep-backed faint uses one facing row")
	_assert_true(sprite.frame == 0, "sleep-backed faint resets displayed frame")
	_assert_true(_has_animation_event(log, "faint"), "sleep-backed faint emitted animation event")


func _check_current_roster_faint_reactions(scene: PackedScene, expertise_scene: PackedScene, resolver: BattleAnimationResolver) -> void:
	for path in CurrentRosterReadiness.CURRENT_ROSTER_PATHS:
		var pawn: TacticsPawn = _spawn_pawn(scene, expertise_scene, path)
		await process_frame
		var sprite: TacticsPawnSprite = pawn.get_node("Character") as TacticsPawnSprite
		var log := BattleLog.new()
		var chosen: String = resolver.select_reaction(pawn, _move("water_pulse", PokemonMoveResource.CATEGORY_SPECIAL), "faint", log)
		sprite.set_anim_state(chosen)
		_assert_true(chosen == "faint" or chosen == "sleep", "%s faint reaction chooses rest/death state" % path.get_file().get_basename())
		_assert_true(sprite.frame == 0, "%s faint reaction resets displayed frame" % path.get_file().get_basename())
		var expected_frames: int = _expected_frame_count(pawn, chosen)
		if expected_frames > 1:
			_assert_true(sprite.hframes == expected_frames, "%s faint reaction uses expected frame slicing" % path.get_file().get_basename())
		pawn.queue_free()


func _expected_frame_count(pawn: TacticsPawn, state: String) -> int:
	if pawn.stats == null or pawn.stats.pokemon_instance == null:
		return 0
	var form: PokemonFormResource = pawn.stats.pokemon_instance.resolved_form()
	if form == null or form.sprite_set == null:
		return 0
	var entry: Variant = form.sprite_set.animation_states.get(state)
	if entry is Dictionary:
		return int((entry as Dictionary).get("frame_count", 0))
	return 0


func _move(move_id: String, category: int) -> PokemonMoveResource:
	var move := PokemonMoveResource.new()
	move.move_id = move_id
	move.category = category
	return move


func _has_animation_event(log: BattleLog, purpose: String) -> bool:
	for event in log.events:
		if String(event.get("purpose", "")) == purpose and String(event.get("kind", "")).begins_with("animation_"):
			return true
	return false


func _assert_true(value: bool, label: String) -> void:
	if value:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: fail - %s" % label)


func _finish(name: String) -> void:
	if failures > 0:
		push_error("smoke: %s failed %d check(s)" % [name, failures])
		quit(1)
	else:
		print("smoke: %s clean" % name)
		quit(0)
