extends SceneTree

const DRIVER := preload("res://tools/debug/notation_driver.gd")

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=9 mode=pvp p=0025_pikachu@50:thunderbolt,quick_attack:static e=0004_charmander@50:ember:blaze|0001_bulbasaur@50:tackle:overgrow|0007_squirtle@50:tackle:torrent")
	_assert_true(ok, "battle launches for the fainted removal checks")
	if not ok:
		_finish()
		return
	var level: TacticsLevel = driver.level
	var frames: int = 0
	while not level._scheduler_started and frames < 300:
		await physics_frame
		frames += 1
	var charmander: TacticsPawn = level.notation.pawn_for_id("E1")
	var bulbasaur: TacticsPawn = level.notation.pawn_for_id("E2")
	var tile: TacticsTile = bulbasaur.get_tile()
	var layer_before: int = bulbasaur.collision_layer
	_assert_true(tile != null and tile.get_tile_occupier() == bulbasaur and tile.is_taken(), "a living unit occupies its square")
	_assert_true(_body_hit_at(level, bulbasaur.global_position) == bulbasaur, "a living unit's body answers the pick ray")
	level.hud.pin(bulbasaur)
	await physics_frame
	_assert_true(level.hud.pinned_pawn == bulbasaur, "the inspector can pin a living unit")
	bulbasaur.stats.apply_to_curr_health(-9999)
	for i in range(3):
		await physics_frame
	_assert_true(not bulbasaur.is_alive(), "bulbasaur is fainted")
	_assert_true(bulbasaur.collision_layer == 0 and bulbasaur.collision_mask == 0, "a fainted unit drops its collision at once")
	_assert_true(tile.get_tile_occupier() == null and not tile.is_taken(), "a fainted unit no longer occupies its square")
	_assert_true(_body_hit_at(level, bulbasaur.global_position) == null, "the pick ray passes through a fainted unit")
	_assert_true(level.hud.pinned_pawn == null and level.hud.hovered_unit() != bulbasaur, "the inspector unpins a unit that faints and never picks it")
	_assert_true(bulbasaur.visible, "the faint animation still plays right after the knockout")
	level.arena.reset_all_tile_markers()
	level.arena.process_surrounding_tiles(charmander.get_tile(), float(charmander.stats.jump))
	_assert_true(tile.pf_root != null, "pathfinding walks across the square where a unit fainted")
	var nearest: TacticsTile = level.arena.get_nearest_target_adjacent_tile(charmander, [bulbasaur])
	_assert_true(nearest == charmander.get_tile(), "the CPU finds no square to approach when its only target has fainted")
	await create_timer(PawnStateVisuals.FAINT_HOLD_SECONDS + PawnStateVisuals.FAINT_FADE_SECONDS + 0.4).timeout
	_assert_true(not bulbasaur.visible, "a fainted unit disappears from the map after its faint fade")
	bulbasaur.stats.apply_to_curr_health(9999)
	for i in range(3):
		await physics_frame
	_assert_true(bulbasaur.is_alive() and bulbasaur.visible and bulbasaur.collision_layer == layer_before and tile.get_tile_occupier() == bulbasaur, "a revived unit returns with its body, visibility and square")
	bulbasaur.stats.apply_to_curr_health(-9999)
	var visuals: PawnStateVisuals = bulbasaur.get_node("StateVisuals") as PawnStateVisuals
	visuals.settle_faint()
	_assert_true(not bulbasaur.visible and bulbasaur.collision_layer == 0 and tile.get_tile_occupier() == null, "a settled faint (restored board) hides the unit immediately")
	_finish()


func _body_hit_at(level: TacticsLevel, position: Vector3) -> Object:
	var from: Vector3 = position + Vector3.UP * 5.0
	var to: Vector3 = position + Vector3.DOWN * 1.0
	var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 2, []))
	return hit.get("collider", null)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)


func _finish() -> void:
	if failures > 0:
		push_error("smoke: fainted_removal failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: fainted_removal clean")
	quit(0)
