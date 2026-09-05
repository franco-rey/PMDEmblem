extends SceneTree

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const SPRITES_DIR: String = "res://data/models/pokemon/generated/sprites/"
const REQUIRED: Array[String] = ["idle", "walk", "hurt", "sleep"]

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var broken_required: Array[String] = []
	var scanned: int = 0
	var dir: DirAccess = DirAccess.open(SPRITES_DIR)
	dir.list_dir_begin()
	var file: String = dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var set: PokemonSpriteSetResource = load(SPRITES_DIR + file) as PokemonSpriteSetResource
			if set != null:
				scanned += 1
				for key in REQUIRED:
					var entry: Variant = set.animation_states.get(key, null)
					if entry is Dictionary:
						var cell: Vector2i = (entry as Dictionary).get("cell_size", Vector2i.ZERO)
						if (cell.x <= 0 or cell.y <= 0) and int((entry as Dictionary).get("frame_count", 0)) <= 0:
							broken_required.append("%s:%s" % [file, key])
		file = dir.get_next()
	_assert_true(scanned >= 686 and broken_required.is_empty(), "no required state is zero-sized across %d sprite sets (%s)" % [scanned, str(broken_required.slice(0, 5))])
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=4 mode=pvp p=0383_groudon@50:earthquake,stone_edge,fire_punch,swords_dance:drought|0623_golurk@50:shadow_punch,earthquake,dynamic_punch,hammer_arm:iron_fist e=0065_alakazam@50:psybeam,calm_mind,recover,shadow_ball:synchronize|0435_skuntank@50:night_slash,poison_jab,sucker_punch,toxic:aftermath")
	_assert_true(ok, "Groudon and Golurk vs Alakazam and Skuntank launch")
	if not ok:
		_finish()
		return
	var level: TacticsLevel = driver.level
	for pawn in level.player.get_children() + level.opponent.get_children():
		var sprite: TacticsPawnSprite = pawn.get_node("Character")
		var name: String = level.notation.unit_name(pawn)
		var faint_path: String = String(sprite.state_texture_paths.get("faint", ""))
		var cell_w: int = int(sprite.state_cell_widths.get("faint", 0))
		var frames: int = int(sprite.state_frame_counts.get("faint", 0))
		var aliased: bool = name == "Groudon"
		_assert_true(not faint_path.is_empty() and cell_w > 0 and frames > 0 and (not aliased or not faint_path.ends_with("faint.png")), "%s faint state resolves to a usable sheet (%s, cell %d, frames %d)" % [name, faint_path.get_file(), cell_w, frames])
		if name == "Golurk":
			_assert_true(not sprite.state_cell_widths.has("shoot") and not sprite.state_cell_widths.has("special_attack"), "Golurk drops its zero-sized shoot and special_attack entries")
		if name == "Skuntank":
			_assert_true(not sprite.state_cell_widths.has("debuff"), "Skuntank drops its zero-sized debuff alias")
		for key in sprite.state_cell_widths:
			if int(sprite.state_cell_widths[key]) <= 0:
				_assert_true(false, "%s loaded a zero-width state %s" % [name, key])
		var shadow: Sprite3D = pawn.get_node_or_null("Shadow")
		_assert_true(shadow != null and shadow.axis == Vector3.AXIS_Y and shadow.texture != null and shadow.position.y > 0.0, "%s has a ground shadow lying on the tile" % name)
	_finish()


func _finish() -> void:
	if failures > 0:
		push_error("smoke: sprite_state_fallbacks failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: sprite_state_fallbacks clean")
	quit(0)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)
