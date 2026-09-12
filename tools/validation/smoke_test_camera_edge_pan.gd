extends SmokeCase

const DRIVER := preload("res://tools/debug/notation_driver.gd")


func _run() -> void:
	_assert_true(InputMap.has_action("toggle_edge_pan"), "toggle_edge_pan action exists")
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=2 mode=pvp team=2")
	_assert_true(ok, "2v2 launches")
	if not ok:
		_finish("camera_edge_pan")
		return
	var level: TacticsLevel = driver.level
	_assert_true(not level.camera.edge_pan_enabled, "mouse edge panning is off by default")
	var rigs: Array = root.find_children("*", "TacticsCamera", true, false)
	var camera_node: TacticsCamera = rigs[0] if not rigs.is_empty() else null
	_assert_true(camera_node != null, "camera rig is in the tree")
	var press := InputEventAction.new()
	press.action = "toggle_edge_pan"
	press.pressed = true
	var before: int = level.message_log.history.size()
	level.camera.edge_pan_toggled.emit(true)
	if camera_node != null:
		camera_node.serv.handle_input(press)
	_assert_true(level.message_log.history.size() > before and level.message_log.history[-1].begins_with("Mouse edge panning"), "toggling logs the state to the battle log")
	if camera_node != null:
		_assert_true(level.camera.edge_pan_enabled, "the O action turns edge panning on")
		camera_node.serv.handle_input(press)
		_assert_true(not level.camera.edge_pan_enabled, "pressing again turns it off")
	var pawn: TacticsPawn = level.player.get_child(0)
	var name_label: Label3D = pawn.get_node("Character/CharacterUI/NameLabel")
	var hp_label: Label3D = pawn.get_node("Character/CharacterUI/HealthLabel")
	_assert_true(is_equal_approx(name_label.position.y, hp_label.position.y) and name_label.offset.y > hp_label.offset.y and hp_label.offset.y > 0.0, "name and HP labels share a height and stack above the sprite by screen-space offsets")
	_finish("camera_edge_pan")
