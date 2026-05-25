extends SceneTree
## M6 smoke: skirmish entrants receive four learnset moves and selected slots log.

const CHARMANDER_PATH: String = "res://data/models/pokemon/generated/instances/0004_charmander.tres"
const MAGMORTAR_PATH: String = "res://data/models/pokemon/overrides/instances/0467_magmortar.tres"
const CONTROLS_SCENE_PATH: String = "res://data/modules/tactics/controls/controls.tscn"
const EXAMPLE_INSTANCE_PATHS: Array[String] = [
	"res://data/models/pokemon/generated/instances/0001_bulbasaur.tres",
	"res://data/models/pokemon/generated/instances/0002_ivysaur.tres",
	"res://data/models/pokemon/generated/instances/0003_venusaur.tres",
	"res://data/models/pokemon/generated/instances/0004_charmander.tres",
	"res://data/models/pokemon/generated/instances/0005_charmeleon.tres",
	"res://data/models/pokemon/generated/instances/0006_charizard.tres",
	"res://data/models/pokemon/generated/instances/0007_squirtle.tres",
	"res://data/models/pokemon/generated/instances/0008_wartortle.tres",
	"res://data/models/pokemon/generated/instances/0009_blastoise.tres",
	"res://data/models/pokemon/overrides/instances/0094_gengar.tres",
	"res://data/models/pokemon/overrides/instances/0282_gardevoir.tres",
	"res://data/models/pokemon/overrides/instances/0356_dusclops.tres",
	"res://data/models/pokemon/overrides/instances/0448_lucario.tres",
	"res://data/models/pokemon/overrides/instances/0454_toxicroak.tres",
	"res://data/models/pokemon/overrides/instances/0467_magmortar.tres",
	"res://data/models/pokemon/overrides/instances/0475_gallade.tres",
]

class FakePawn:
	extends TacticsPawn
	var fake_tile: TacticsTile
	func get_tile() -> TacticsTile:
		return fake_tile

var failures: int = 0


func _init() -> void:
	_check_controls_resource_bridge()
	_check_controls_scene_move_picker()
	_check_example_loadout_coverage()

	var template: PokemonInstanceResource = load(CHARMANDER_PATH) as PokemonInstanceResource
	var entrant: PokemonInstanceResource = SkirmishMoveLoadout.clone_with_loadout(
		template,
		PokemonInstanceResource.Team.PLAYER,
		PokemonInstanceResource.ControlType.PLAYER,
		101,
		"player",
		0
	)
	_assert_true(entrant.move_slots.size() == 4, "Charmander entrant receives four moves")
	_assert_true(_unique_move_count(entrant) == entrant.move_slots.size(), "loadout moves are unique")

	var level := TacticsLevel.new()
	var player := TacticsPlayer.new()
	var opponent := TacticsOpponent.new()
	level.player = player
	level.opponent = opponent
	level.add_child(player)
	level.add_child(opponent)

	var attacker: FakePawn = _fake_pawn_from_instance(entrant, "Attacker", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn_from_path(MAGMORTAR_PATH, "Defender", Vector3(1, 0, 0))
	player.add_child(attacker)
	opponent.add_child(defender)

	var participant := TacticsParticipantResource.new()
	participant.curr_pawn = attacker
	participant.targets = opponent
	var selection := TacticsControlsSelectionService.new(participant, null, null, null, null)
	for i in range(entrant.move_slots.size()):
		selection.player_wants_to_select_move(i)
		_assert_true(attacker.res.selected_move_index == i, "slot %d can be selected" % i)
	_assert_true(_count_events(level.battle_log, "move_selected") == entrant.move_slots.size(), "move_selected logged for each slot")
	level.free()

	if failures > 0:
		push_error("smoke: move selection failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: move_selection clean")
		quit(0)


func _check_controls_resource_bridge() -> void:
	var controls := TacticsControlsResource.new()
	var emitted: Array[bool] = [false]
	controls.called_select_move.connect(func() -> void: emitted[0] = true)
	_assert_true(controls.has_method("select_move"), "controls resource exposes select_move")
	controls.select_move()
	_assert_true(emitted[0], "controls resource select_move emits bridge signal")
	var input_service := TacticsControlsInputService.new(controls, null)
	var bare_controls := TacticsControls.new()
	_assert_true(not input_service.is_mouse_hovering_ui_elem(bare_controls), "input service tolerates missing optional UI nodes")
	bare_controls.free()


func _check_controls_scene_move_picker() -> void:
	var scene: PackedScene = load(CONTROLS_SCENE_PATH) as PackedScene
	_assert_true(scene != null, "controls scene loads")
	if scene == null:
		return
	var ctrl: TacticsControls = scene.instantiate() as TacticsControls
	_assert_true(ctrl != null, "controls scene instantiates")
	if ctrl == null:
		return
	var picker: VBoxContainer = ctrl.get_node_or_null("HBox/MovePicker") as VBoxContainer
	_assert_true(picker != null, "controls scene includes MovePicker")
	if picker != null:
		for i in range(PokemonInstanceResource.MAX_MOVE_SLOTS):
			_assert_true(picker.get_node_or_null("MoveSlot%d" % i) is Button, "MovePicker slot %d exists" % i)
		_assert_true(picker.get_node_or_null("Cancel") is Button, "MovePicker cancel button exists")
	ctrl.free()

	var participant := TacticsParticipantResource.new()
	participant.stage = participant.STAGE_SELECT_MOVE
	var service := TacticsControlsService.new(TacticsControlsResource.new(), null, participant, null, null)
	var cancel_event := InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	service.handle_input(cancel_event)
	_assert_true(participant.stage == participant.STAGE_SHOW_ACTIONS, "Escape returns move picker to actions")

	var button_participant := TacticsParticipantResource.new()
	button_participant.stage = button_participant.STAGE_SELECT_MOVE
	var button_ctrl: TacticsControls = scene.instantiate() as TacticsControls
	button_ctrl.controls = TacticsControlsResource.new()
	button_ctrl.participant = button_participant
	button_ctrl.serv = TacticsControlsService.new(
		button_ctrl.controls,
		TacticsCameraResource.new(),
		button_participant,
		TacticsArenaResource.new(),
		null,
	)
	button_ctrl.serv.setup(button_ctrl)
	var button_picker: VBoxContainer = button_ctrl.get_node("HBox/MovePicker") as VBoxContainer
	button_picker.visible = true
	var cancel_button: Button = button_ctrl.get_node("HBox/MovePicker/Cancel") as Button
	cancel_button.emit_signal("button_down")
	cancel_button.emit_signal("pressed")
	_assert_true(button_participant.stage == button_participant.STAGE_SHOW_ACTIONS, "MovePicker Cancel button press/release cancels once")
	button_participant.stage = button_participant.STAGE_SELECT_MOVE
	button_picker.visible = true
	cancel_button.emit_signal("pressed")
	_assert_true(button_participant.stage == button_participant.STAGE_SHOW_ACTIONS, "MovePicker Cancel button returns to actions")
	button_participant.stage = button_participant.STAGE_SELECT_MOVE
	button_picker.visible = true
	var mouse_cancel := InputEventMouseButton.new()
	mouse_cancel.button_index = MOUSE_BUTTON_LEFT
	mouse_cancel.pressed = true
	cancel_button.emit_signal("gui_input", mouse_cancel)
	_assert_true(button_participant.stage == button_participant.STAGE_SHOW_ACTIONS, "MovePicker Cancel gui_input mouse press returns to actions")
	button_ctrl.free()


func _check_example_loadout_coverage() -> void:
	for i in range(EXAMPLE_INSTANCE_PATHS.size()):
		var path: String = EXAMPLE_INSTANCE_PATHS[i]
		var template: PokemonInstanceResource = load(path) as PokemonInstanceResource
		if template == null:
			_assert_true(false, "example instance loads: %s" % path)
			continue
		var pool: Array[PokemonMoveResource] = SkirmishMoveLoadout.move_pool_for_instance(template)
		_assert_true(pool.size() >= PokemonInstanceResource.MAX_MOVE_SLOTS, "%s has at least four level-appropriate moves" % template.display_name())
		var entrant: PokemonInstanceResource = SkirmishMoveLoadout.clone_with_loadout(
			template,
			PokemonInstanceResource.Team.PLAYER,
			PokemonInstanceResource.ControlType.PLAYER,
			2026,
			"coverage",
			i
		)
		_assert_true(entrant.move_slots.size() == PokemonInstanceResource.MAX_MOVE_SLOTS, "%s entrant receives four moves" % template.display_name())


func _fake_pawn_from_path(path: String, pawn_name: String, pos: Vector3) -> FakePawn:
	return _fake_pawn_from_instance(load(path) as PokemonInstanceResource, pawn_name, pos)


func _fake_pawn_from_instance(instance: PokemonInstanceResource, pawn_name: String, pos: Vector3) -> FakePawn:
	var pawn := FakePawn.new()
	pawn.name = pawn_name
	pawn.res = TacticsPawnResource.new()
	pawn.fake_tile = TacticsTile.new()
	pawn.fake_tile.position = pos
	pawn.add_child(pawn.fake_tile)
	pawn.stats = Stats.new()
	pawn.stats.init_from_pokemon(instance)
	return pawn


func _unique_move_count(instance: PokemonInstanceResource) -> int:
	var seen: Dictionary = {}
	for move in instance.move_slots:
		if move != null:
			seen[move.move_id] = true
	return seen.size()


func _count_events(log: BattleLog, kind: String) -> int:
	var count: int = 0
	for event in log.events:
		if event.get("kind", "") == kind:
			count += 1
	return count


func _assert_true(value: bool, label: String) -> void:
	if value:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: fail - %s" % label)
