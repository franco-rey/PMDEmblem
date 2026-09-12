extends SmokeCase

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const CODE: String = "match seed=3 mode=pvp p=0003_venusaur@50:calm_mind,razor_leaf,growth,sleep_powder:overgrow e=0025_pikachu@50:thunder_shock,quick_attack,growl,tail_whip:static"


func _run() -> void:
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch(CODE)
	_assert_true(ok, "Venusaur vs Pikachu launches")
	if not ok:
		_finish("pawn_grounding_facing")
		return
	var level: TacticsLevel = driver.level
	var venusaur: TacticsPawn = level.player.get_child(0)
	var pikachu: TacticsPawn = level.opponent.get_child(0)
	for pawn in [venusaur, pikachu]:
		var sprite: TacticsPawnSprite = pawn.serv.sprite if "sprite" in pawn.serv else pawn.find_child("Sprite", true, false)
		if sprite == null:
			sprite = pawn.find_children("*", "TacticsPawnSprite", true, false)[0] if not pawn.find_children("*", "TacticsPawnSprite", true, false).is_empty() else null
		_assert_true(sprite != null, "%s exposes its sprite service" % level.notation.unit_name(pawn))
		if sprite == null:
			continue
		var drop: int = sprite.foot_drop_px("idle")
		var expected: float = float(sprite.ground_shadow_px + maxi(0, drop)) - (TacticsPawnSprite.DEFAULT_CHARACTER_CENTER_Y / sprite.pixel_size)
		_assert_true(sprite.grounding_mode == TacticsPawnSprite.GROUNDING_SOURCE and is_equal_approx(sprite.offset.y, expected), "%s idle offset lifts by its foot drop (drop %d, offset %.1f)" % [level.notation.unit_name(pawn), drop, sprite.offset.y])
		if pawn == venusaur:
			_assert_true(drop >= 4, "Venusaur's art extends below the shadow line and is lifted (%d px)" % drop)
	var before: float = venusaur.rotation.y
	pikachu.serv.movement.look_at_direction(venusaur, Vector3.ZERO)
	_assert_true(is_equal_approx(venusaur.rotation.y, before), "a zero direction keeps the current facing")
	if not await driver._wait_for_turn(venusaur):
		_finish("pawn_grounding_facing")
		return
	venusaur.serv.movement.look_at_direction(venusaur, pikachu.global_position - venusaur.global_position)
	var facing_foe: float = venusaur.rotation.y
	await driver._attack(venusaur, 0, venusaur)
	_assert_true(_same_heading(venusaur.rotation.y, facing_foe), "using Calm Mind on itself keeps Venusaur facing the foe (%.2f vs %.2f)" % [venusaur.rotation.y, facing_foe])
	_finish("pawn_grounding_facing")


func _same_heading(a: float, b: float) -> bool:
	return absf(angle_difference(a, b)) < 0.01
