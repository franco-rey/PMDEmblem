extends Node

const SkirmishCode = preload("res://data/modules/skirmish/skirmish_code.gd")
const SkirmishControlMode = preload("res://data/modules/skirmish/skirmish_control_mode.gd")

const MANUAL_SKIRMISHES: Array[Dictionary] = [
	{
		"kind": "static",
		"id": "demo_3v3",
		"label": "Demo 3v3 (fixed)",
		"path": "res://data/models/skirmish/manual/demo_3v3.tres",
	},
	{
		"kind": "static",
		"id": "single_1v1",
		"label": "1v1 fixture (fixed)",
		"path": "res://data/models/skirmish/manual/single_1v1.tres",
	},
	{
		"kind": "static",
		"id": "team_3v3",
		"label": "3v3 fixture (fixed)",
		"path": "res://data/models/skirmish/manual/team_3v3.tres",
	},
	{
		"kind": "static",
		"id": "type_effectiveness_test",
		"label": "Type effectiveness fixture",
		"path": "res://data/models/skirmish/manual/type_effectiveness_test.tres",
	},
	{
		"kind": "random",
		"id": "random_1v1",
		"label": "Random 1v1",
		"team_size": 1,
	},
	{
		"kind": "random",
		"id": "random_2v2",
		"label": "Random 2v2",
		"team_size": 2,
	},
	{
		"kind": "random",
		"id": "random_3v3",
		"label": "Random 3v3",
		"team_size": 3,
	},
	{
		"kind": "random",
		"id": "random_4v4",
		"label": "Random 4v4",
		"team_size": 4,
	},
	{
		"kind": "random",
		"id": "random_5v5",
		"label": "Random 5v5",
		"team_size": 5,
	},
	{
		"kind": "series_code",
		"id": "random_6v6_bots_1",
		"label": "1 Random 6v6 CPU vs CPU",
		"code": "series seed=6100 team=6 matches=1 -bots",
	},
	{
		"kind": "series_code",
		"id": "random_6v6_bots_5",
		"label": "5 Random 6v6 CPU vs CPU",
		"code": "series seed=6200 team=6 matches=5 -bots",
	},
	{
		"kind": "series_code",
		"id": "random_6v6_bots_10",
		"label": "10 Random 6v6 CPU vs CPU",
		"code": "series seed=6300 team=6 matches=10 -bots",
	},
]
const MENU_CONTROL_SIZE: Vector2 = Vector2(520, 72)
const MENU_FONT_SIZE: int = 36

const MIN_WINDOW_SIZE: Vector2i = Vector2i(1280, 720)

var level_instance: TacticsLevel
var skirmish_loader: SkirmishLoader
var pause_menu: PauseMenu = null
var results_screen: BattleResultsScreen = null
var speed_bar: SpectatorSpeedBar = null
var interface_visible: bool = true
var _controls_enabled: bool = true
var menu_graphics_panel: GraphicsSettingsPanel = null
var menu_controls_panel: ControlsPanel = null
var controls_button: Button = null
var options_button: Button = null
var quit_button: Button = null
var _relaunch: Callable = Callable()
var _ended_definition: SkirmishDefinitionResource = null
var _ended_result: int = 0
var skirmish_queue: Array[SkirmishDefinitionResource] = []
var skirmish_queue_index: int = 0
var skirmish_queue_code: String = ""

@onready var world: Node3D = $World
@onready var skirmish_picker: OptionButton = $UI/MapSelector/SkirmishMenu/SkirmishPicker
@onready var launch_button: Button = $UI/MapSelector/SkirmishMenu/LaunchButton
@onready var custom_toggle_button: Button = $UI/MapSelector/SkirmishMenu/CustomToggleButton
@onready var skirmish_lobby: SkirmishLobby = $UI/SkirmishLobby
@onready var tactics_controls: Control = $TacticsControls

func _ready() -> void:
	GameSettings.load_settings()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_min_size(MIN_WINDOW_SIZE)
	GameSettings.apply(get_tree().root)
	UiScale.watch(get_tree().root)
	BattleNotation.clear_output_dir()
	_style_main_menu()
	_setup_menus()
	_set_tactics_controls_enabled(false)
	skirmish_loader = SkirmishLoader.new()
	add_child(skirmish_loader)
	skirmish_loader.skirmish_ended.connect(_on_skirmish_ended)
	_populate_skirmish_picker()
	if skirmish_lobby != null:
		skirmish_lobby.visible = false
		skirmish_lobby.launch_requested.connect(_on_lobby_launch_requested)
		skirmish_lobby.launch_series_requested.connect(_on_lobby_launch_series_requested)
		skirmish_lobby.close_requested.connect(_on_lobby_close_requested)
	launch_button.grab_focus()

func _process(_delta: float) -> void:
	_poll_speed_keys()
	_poll_interface_toggle()
	_sync_turn_speed()
	UiScale.apply(get_tree().root)
	var backdrop: Control = $UI.get_node_or_null("Backdrop") as Control
	if backdrop != null:
		backdrop.visible = $UI/MapSelector.visible or (skirmish_lobby != null and skirmish_lobby.visible)


func _on_launch_button_pressed() -> void:
	load_selected_skirmish()


func _setup_menus() -> void:
	pause_menu = PauseMenu.new()
	pause_menu.can_open = _can_open_pause_menu
	pause_menu.restart_requested.connect(_on_restart_requested)
	pause_menu.lobby_requested.connect(_on_return_to_lobby_requested)
	pause_menu.main_menu_requested.connect(_on_main_menu_requested)
	pause_menu.quit_requested.connect(_on_quit_requested)
	add_child(pause_menu)
	results_screen = BattleResultsScreen.new()
	results_screen.play_again_requested.connect(_on_results_play_again)
	results_screen.lobby_requested.connect(_on_results_lobby)
	results_screen.main_menu_requested.connect(_on_main_menu_requested)
	results_screen.next_requested.connect(_on_results_next)
	add_child(results_screen)
	speed_bar = SpectatorSpeedBar.new()
	speed_bar.speed_selected.connect(_on_speed_selected)
	add_child(speed_bar)
	var menu := $UI/MapSelector/SkirmishMenu as VBoxContainer
	if menu != null:
		options_button = Button.new()
		options_button.name = "OptionsButton"
		options_button.text = "Options"
		options_button.custom_minimum_size = MENU_CONTROL_SIZE
		options_button.add_theme_font_size_override("font_size", MENU_FONT_SIZE)
		options_button.pressed.connect(_on_options_pressed)
		menu.add_child(options_button)
		controls_button = Button.new()
		controls_button.name = "ControlsButton"
		controls_button.text = "Controls"
		controls_button.custom_minimum_size = MENU_CONTROL_SIZE
		controls_button.add_theme_font_size_override("font_size", MENU_FONT_SIZE)
		controls_button.pressed.connect(_on_controls_pressed)
		menu.add_child(controls_button)
		quit_button = Button.new()
		quit_button.name = "QuitButton"
		quit_button.text = "Quit"
		quit_button.custom_minimum_size = MENU_CONTROL_SIZE
		quit_button.add_theme_font_size_override("font_size", MENU_FONT_SIZE)
		quit_button.pressed.connect(_on_quit_requested)
		menu.add_child(quit_button)
	var overlay := CenterContainer.new()
	overlay.name = "OptionsOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	$UI.add_child(overlay)
	menu_graphics_panel = GraphicsSettingsPanel.new()
	menu_graphics_panel.closed.connect(func() -> void:
		overlay.visible = false
		$UI/MapSelector.visible = true
		if options_button != null:
			options_button.grab_focus())
	overlay.add_child(menu_graphics_panel)
	menu_graphics_panel.controls_requested.connect(_on_controls_pressed)
	menu_controls_panel = ControlsPanel.new()
	menu_controls_panel.visible = false
	menu_controls_panel.closed.connect(func() -> void:
		menu_controls_panel.visible = false
		menu_graphics_panel.visible = true
		menu_graphics_panel.focus_first())
	overlay.add_child(menu_controls_panel)


func _can_open_pause_menu() -> bool:
	if level_instance == null or not is_instance_valid(level_instance) or level_instance.battle_finished or level_instance.intro_pending:
		return false
	if results_screen != null and results_screen.visible:
		return false
	if skirmish_lobby != null and skirmish_lobby.visible:
		return false
	if tactics_controls == null or not tactics_controls.visible:
		return true
	var stage: int = level_instance.participant.res.stage if level_instance.participant != null and level_instance.participant.res != null else 0
	return stage <= TacticsParticipantResource.STAGE_SHOW_ACTIONS


func _on_options_pressed() -> void:
	var overlay: Control = $UI.get_node_or_null("OptionsOverlay") as Control
	if overlay == null:
		return
	$UI/MapSelector.visible = false
	overlay.visible = true
	menu_controls_panel.visible = false
	menu_graphics_panel.visible = true
	menu_graphics_panel.refresh()
	menu_graphics_panel.focus_first()


func _on_controls_pressed() -> void:
	var overlay: Control = $UI.get_node_or_null("OptionsOverlay") as Control
	if overlay == null:
		return
	$UI/MapSelector.visible = false
	overlay.visible = true
	menu_graphics_panel.visible = false
	menu_controls_panel.visible = true
	menu_controls_panel.focus_first()


func _on_restart_requested() -> void:
	if _relaunch.is_valid():
		_relaunch.call()


func _on_return_to_lobby_requested() -> void:
	unload_level()
	_set_tactics_controls_enabled(false)
	$UI/MapSelector.visible = false
	if skirmish_lobby != null:
		skirmish_lobby.open()


func _on_main_menu_requested() -> void:
	unload_level()
	_set_tactics_controls_enabled(false)
	if skirmish_lobby != null:
		skirmish_lobby.visible = false
	$UI/MapSelector.visible = true
	launch_button.grab_focus()


func _on_quit_requested() -> void:
	_set_battle_speed(1.0)
	get_tree().quit()


func _set_battle_speed(value: float) -> void:
	Engine.time_scale = maxf(value, 0.1)


func _poll_speed_keys() -> void:
	if level_instance == null or not is_instance_valid(level_instance):
		return
	for i in range(GameSettings.CPU_SPEEDS.size()):
		if Input.is_action_just_pressed("battle_speed_%d" % (i + 1)):
			_on_speed_selected(GameSettings.CPU_SPEEDS[i])
			if speed_bar != null:
				speed_bar.highlight(GameSettings.CPU_SPEEDS[i])
			return


func _poll_interface_toggle() -> void:
	if level_instance == null or not is_instance_valid(level_instance) or level_instance.battle_finished:
		return
	if Input.is_action_just_pressed("toggle_interface"):
		set_interface_visible(not interface_visible)


func set_interface_visible(value: bool) -> void:
	interface_visible = value
	if tactics_controls != null:
		tactics_controls.visible = _controls_enabled and interface_visible
	if level_instance != null and is_instance_valid(level_instance):
		level_instance.set_interface_visible(interface_visible)
	if speed_bar != null and not interface_visible:
		speed_bar.visible = false


func _sync_turn_speed() -> void:
	if level_instance == null or not is_instance_valid(level_instance) or level_instance.battle_finished or speed_bar == null:
		return
	if _ended_definition != null and results_screen != null and results_screen.visible:
		return
	var participant: TacticsParticipant = level_instance.participant
	if participant == null or participant.res == null:
		return
	var current: TacticsPawn = participant.res.curr_pawn
	var human_match: bool = tactics_controls != null and tactics_controls.visible
	if not human_match:
		return
	var cpu_turn: bool = current != null and is_instance_valid(current) and current.stats != null and current.stats.pokemon_instance != null and current.stats.pokemon_instance.control_type != PokemonInstanceResource.ControlType.PLAYER and level_instance._scheduler_started
	var wanted: float = GameSettings.cpu_speed
	if not is_equal_approx(Engine.time_scale, wanted):
		_set_battle_speed(wanted)
	var show_bar: bool = cpu_turn and interface_visible
	if speed_bar.visible != show_bar:
		speed_bar.visible = show_bar
		speed_bar.highlight(GameSettings.cpu_speed)


func _on_speed_selected(value: float) -> void:
	GameSettings.cpu_speed = value
	GameSettings.save_settings()
	if level_instance != null and is_instance_valid(level_instance) and speed_bar != null and speed_bar.visible:
		_set_battle_speed(value)
		speed_bar.highlight(value)
	if level_instance != null and is_instance_valid(level_instance) and level_instance.hud != null and level_instance.banner != null:
		level_instance.banner.show_notice("Battle speed %s" % GameSettings.cpu_speed_label(value))


func _on_results_play_again() -> void:
	_finish_ended_level()
	if _relaunch.is_valid():
		_relaunch.call()


func _on_results_next() -> void:
	_finish_ended_level()
	if not skirmish_queue.is_empty() and skirmish_queue_index < skirmish_queue.size():
		_launch_next_queued_skirmish()
	else:
		_on_main_menu_requested()


func _on_results_lobby() -> void:
	var ended_level: TacticsLevel = level_instance
	var definition: SkirmishDefinitionResource = _ended_definition
	var result: int = _ended_result
	if skirmish_lobby != null and ended_level != null:
		skirmish_lobby.show_battle_summary(result, definition, ended_level)
	_finish_ended_level()
	$UI/MapSelector.visible = false


func _finish_ended_level() -> void:
	_set_battle_speed(1.0)
	if skirmish_loader != null and level_instance == skirmish_loader.current_level:
		skirmish_loader.unload_current()
	elif is_instance_valid(level_instance):
		level_instance.queue_free()
	level_instance = null
	_ended_definition = null


func _on_custom_toggle_pressed() -> void:
	$UI/MapSelector.visible = false
	_set_tactics_controls_enabled(false)
	if skirmish_lobby != null:
		skirmish_lobby.open()

func unload_level() -> void:
	_set_battle_speed(1.0)
	if speed_bar != null:
		speed_bar.visible = false
	if skirmish_loader != null and level_instance == skirmish_loader.current_level:
		skirmish_loader.unload_current()
	elif is_instance_valid(level_instance):
		level_instance.queue_free()
	level_instance = null

func load_level(level_name: String) -> void:
	unload_level()
	var level_path: String = "res://assets/maps/level/%s_level.tscn" % level_name
	level_instance = load(level_path).instantiate()
	world.add_child(level_instance)
	$UI/MapSelector.visible = false
	_set_tactics_controls_enabled(true)


func load_selected_skirmish() -> void:
	var idx: int = skirmish_picker.selected
	if idx < 0 or idx >= MANUAL_SKIRMISHES.size():
		push_error("Main: no manual skirmish selected")
		return
	var entry: Dictionary = MANUAL_SKIRMISHES[idx]
	if String(entry.get("kind", "static")) == "series_code":
		var built: Dictionary = SkirmishCode.build_definitions(String(entry.get("code", "")))
		if not bool(built.get("ok", false)):
			push_error("Main: series code build failed: %s" % String(built.get("error", "?")))
			return
		_launch_series(_definitions_from_result(built), String(entry.get("code", "")))
		return
	skirmish_queue.clear()
	skirmish_queue_index = 0
	skirmish_queue_code = ""
	var definition: SkirmishDefinitionResource = _resolve_skirmish_definition(entry)
	if definition == null:
		return
	_relaunch = load_selected_skirmish
	_launch_definition(definition, false)


func _resolve_skirmish_definition(entry: Dictionary) -> SkirmishDefinitionResource:
	var kind: String = String(entry.get("kind", "static"))
	if kind == "random":
		return _build_random_skirmish(entry)
	var path: String = String(entry.get("path", ""))
	var definition: SkirmishDefinitionResource = load(path) as SkirmishDefinitionResource
	if definition == null:
		push_error("Main: could not load skirmish %s" % path)
	return definition


func _build_random_skirmish(entry: Dictionary) -> SkirmishDefinitionResource:
	var team_size: int = int(entry.get("team_size", 1))
	var maps: Array[String] = CustomSkirmishBuilder.map_paths()
	if maps.is_empty():
		push_error("Main: no maps available for random skirmish")
		return null
	var result: Dictionary = CustomSkirmishBuilder.build_random(team_size, maps[0], "")
	if not result.get("ok", false):
		push_error("Main: random skirmish build failed: %s" % result.get("error", "?"))
		return null
	print("Main: launching %s seed=%d" % [entry.get("id", "random"), int(result["seed"])])
	return result["definition"]


func _populate_skirmish_picker() -> void:
	skirmish_picker.clear()
	for entry in MANUAL_SKIRMISHES:
		skirmish_picker.add_item(_label_for_picker_entry(entry))


func _label_for_picker_entry(entry: Dictionary) -> String:
	var explicit: String = String(entry.get("label", ""))
	if not explicit.is_empty():
		return explicit
	var path: String = String(entry.get("path", ""))
	if not path.is_empty():
		var definition: SkirmishDefinitionResource = load(path) as SkirmishDefinitionResource
		if definition != null and not definition.display_name.is_empty():
			return definition.display_name
	return String(entry.get("id", "unnamed"))


func _launch_definition(definition: SkirmishDefinitionResource, return_to_lobby_on_failure: bool) -> void:
	unload_level()
	level_instance = skirmish_loader.load_skirmish(definition, world)
	if level_instance == null:
		push_error("Main: loader rejected skirmish %s" % (definition.skirmish_id if definition != null else "?"))
		_set_tactics_controls_enabled(false)
		if return_to_lobby_on_failure and skirmish_lobby != null:
			skirmish_lobby.open()
		else:
			$UI/MapSelector.visible = true
		return
	$UI/MapSelector.visible = false
	if skirmish_lobby != null:
		skirmish_lobby.visible = false
	var human: bool = _definition_has_human_control(definition)
	interface_visible = true
	_set_tactics_controls_enabled(human)
	var camera_node: TacticsCamera = find_child("TacticsCamera", true, false) as TacticsCamera
	if camera_node != null and camera_node.res != null:
		camera_node.res.spectator = not human
	_set_battle_speed(GameSettings.cpu_speed)
	if speed_bar != null:
		speed_bar.visible = not human
		speed_bar.highlight(GameSettings.cpu_speed)
	if level_instance.banner != null and GameSettings.battle_flair and DisplayServer.get_name() != "headless":
		level_instance.banner.show_intro(level_instance, definition)


func _launch_series(definitions: Array[SkirmishDefinitionResource], code: String) -> void:
	if definitions.is_empty():
		push_error("Main: cannot launch empty skirmish series")
		return
	skirmish_queue = definitions.duplicate()
	skirmish_queue_index = 0
	skirmish_queue_code = code
	_launch_next_queued_skirmish()


func _launch_next_queued_skirmish() -> void:
	if skirmish_queue_index < 0 or skirmish_queue_index >= skirmish_queue.size():
		return
	var definition: SkirmishDefinitionResource = skirmish_queue[skirmish_queue_index]
	skirmish_queue_index += 1
	print("Main: launching queued skirmish %d/%d seed=%d mode=%s" % [
		skirmish_queue_index,
		skirmish_queue.size(),
		definition.seed if definition != null else 0,
		definition.control_mode if definition != null else "",
	])
	_launch_definition(definition, false)


func _definitions_from_result(result: Dictionary) -> Array[SkirmishDefinitionResource]:
	var out: Array[SkirmishDefinitionResource] = []
	if result.has("definitions") and result["definitions"] is Array:
		for entry in result["definitions"]:
			if entry is SkirmishDefinitionResource:
				out.append(entry as SkirmishDefinitionResource)
	elif result.get("definition", null) is SkirmishDefinitionResource:
		out.append(result["definition"] as SkirmishDefinitionResource)
	return out


func _definition_has_human_control(definition: SkirmishDefinitionResource) -> bool:
	if definition == null:
		return true
	for instance in definition.player_team:
		if instance != null and instance.control_type == PokemonInstanceResource.ControlType.PLAYER:
			return true
	for instance in definition.enemy_team:
		if instance != null and instance.control_type == PokemonInstanceResource.ControlType.PLAYER:
			return true
	return false


func _on_lobby_launch_requested(definition: SkirmishDefinitionResource, seed: int) -> void:
	print("Main: launching lobby skirmish %s seed=%d" % [definition.skirmish_id, seed])
	skirmish_queue.clear()
	skirmish_queue_index = 0
	skirmish_queue_code = ""
	_relaunch = skirmish_lobby._on_play_again_pressed
	_launch_definition(definition, true)


func _on_lobby_launch_series_requested(definitions: Array[SkirmishDefinitionResource], code: String) -> void:
	print("Main: launching lobby skirmish series count=%d code=%s" % [definitions.size(), code])
	_launch_series(definitions, code)


func _on_lobby_close_requested() -> void:
	$UI/MapSelector.visible = true
	_set_tactics_controls_enabled(false)
	launch_button.grab_focus()


func _on_skirmish_ended(result: int, definition: SkirmishDefinitionResource) -> void:
	_set_tactics_controls_enabled(false)
	_set_battle_speed(1.0)
	if speed_bar != null:
		speed_bar.visible = false
	if pause_menu != null and pause_menu.is_open:
		pause_menu.close()
	var ended_level: TacticsLevel = level_instance
	var show_report: bool = _definition_has_human_control(definition) or GameSettings.cpu_battle_report
	if not skirmish_queue.is_empty() and skirmish_queue_index < skirmish_queue.size():
		if show_report and results_screen != null and ended_level != null and is_instance_valid(ended_level) and DisplayServer.get_name() != "headless":
			_ended_definition = definition
			_ended_result = result
			results_screen.show_result(result, definition, ended_level, "Next Battle (%d/%d)" % [skirmish_queue_index + 1, skirmish_queue.size()])
			return
		if skirmish_loader != null:
			skirmish_loader.unload_current()
		level_instance = null
		await get_tree().create_timer(0.75).timeout
		_launch_next_queued_skirmish()
		return
	skirmish_queue.clear()
	skirmish_queue_index = 0
	skirmish_queue_code = ""
	$UI/MapSelector.visible = false
	if show_report and results_screen != null and ended_level != null and is_instance_valid(ended_level) and DisplayServer.get_name() != "headless":
		_ended_definition = definition
		_ended_result = result
		results_screen.show_result(result, definition, ended_level)
		return
	if skirmish_loader != null:
		skirmish_loader.unload_current()
	level_instance = null
	if skirmish_lobby != null:
		skirmish_lobby.show_battle_summary(result, definition, ended_level)


func _style_main_menu() -> void:
	get_tree().root.theme = PmdStyle.build_theme(load("res://assets/ui/pmd_theme.tres") as Theme)
	var ui: Control = $UI as Control
	var backdrop := PmdBackdrop.new()
	backdrop.name = "Backdrop"
	ui.add_child(backdrop)
	ui.move_child(backdrop, 0)
	var menu := $UI/MapSelector/SkirmishMenu as VBoxContainer
	if menu != null:
		menu.add_theme_constant_override("separation", 10)
		var title := Label.new()
		title.name = "Title"
		title.text = "PMD Emblem"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PmdStyle.apply_title(title, 72)
		menu.add_child(title)
		menu.move_child(title, 0)
		var subtitle := Label.new()
		subtitle.name = "Subtitle"
		subtitle.text = "Tactical skirmishes"
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.add_theme_color_override("font_color", PmdStyle.TEXT_DIM)
		menu.add_child(subtitle)
		menu.move_child(subtitle, 1)
	for control in [skirmish_picker, launch_button, custom_toggle_button]:
		control.custom_minimum_size = MENU_CONTROL_SIZE
		control.add_theme_font_size_override("font_size", MENU_FONT_SIZE)


func _set_tactics_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	if tactics_controls == null:
		return
	tactics_controls.visible = enabled and interface_visible
	tactics_controls.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
