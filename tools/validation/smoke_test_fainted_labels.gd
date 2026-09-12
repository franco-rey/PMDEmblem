extends SmokeCase

const DRIVER := preload("res://tools/debug/notation_driver.gd")


func _run() -> void:
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=9 mode=pvp p=0025_pikachu@50:thunderbolt,quick_attack:static e=0004_charmander@50:ember:blaze|0001_bulbasaur@50:tackle:overgrow|0007_squirtle@50:tackle:torrent")
	_assert_true(ok, "battle launches for the fainted label checks")
	if not ok:
		_finish("fainted_labels")
		return
	var level: TacticsLevel = driver.level
	var frames: int = 0
	while not level._scheduler_started and frames < 300:
		await physics_frame
		frames += 1
	var charmander: TacticsPawn = level.notation.pawn_for_id("E1")
	var bulbasaur: TacticsPawn = level.notation.pawn_for_id("E2")
	var res: TacticsParticipantResource = level.participant.res
	res.display_opponent_stats = true
	for i in range(3):
		await physics_frame
	_assert_true(_labels_visible(charmander) and _labels_visible(bulbasaur), "targeting shows labels on both living enemies")
	bulbasaur.stats.apply_to_curr_health(-9999)
	for i in range(3):
		await physics_frame
	_assert_true(not bulbasaur.is_alive(), "bulbasaur is fainted")
	_assert_true(_labels_visible(charmander) and not _labels_visible(bulbasaur), "targeting keeps the living enemy's labels and drops the fainted one's")
	res.display_opponent_stats = false
	for i in range(3):
		await physics_frame
	_assert_true(not _labels_visible(charmander) and not _labels_visible(bulbasaur), "leaving targeting hides every enemy label")
	charmander.show_pawn_stats(true)
	charmander.stats.apply_to_curr_health(-9999)
	for i in range(3):
		await physics_frame
	_assert_true(not _labels_visible(charmander), "a target that faints with its labels shown loses them on the next frame")
	_finish("fainted_labels")


func _labels_visible(pawn: TacticsPawn) -> bool:
	if pawn == null or not is_instance_valid(pawn):
		return false
	var ui: Node3D = pawn.get_node_or_null("Character/CharacterUI") as Node3D
	return ui != null and ui.visible
