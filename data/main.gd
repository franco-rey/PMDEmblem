extends Node

const SkirmishCode = preload("res://data/modules/skirmish/skirmish_code.gd")
const SkirmishControlMode = preload("res://data/modules/skirmish/skirmish_control_mode.gd")

const TEMPORAL_CODE: String = "match seed=7 mode=pvc map=chessboard multiverse=1 p=0483_dialga@100:roar_of_time,dragon_claw,flash_cannon,earth_power:pressure|0251_celebi@100:dimensional_hole,psychic,giga_drain,recover:natural_cure|0474_porygon_z@100:dimensional_glitch,tri_attack,thunderbolt,ice_beam:adaptability|0493_arceus@100:judgment,recover,extreme_speed,earth_power:multitype|0253_grovyle@100:dimensional_hole,leaf_blade,quick_attack,pursuit:overgrow e=0484_palkia@100:spacial_rend,aqua_tail,dragon_claw,earth_power:pressure|0487_giratina@100:shadow_force,dragon_claw,shadow_sneak,will_o_wisp:pressure|0720_hoopa@100:hyperspace_hole,hyperspace_fury,psychic,shadow_ball:magician|0477_dusknoir@100:dimensional_hole,shadow_punch,ice_punch,will_o_wisp:pressure"
const MANUAL_SKIRMISHES: Array[Dictionary] = [
	{
		"kind": "code",
		"id": "temporal_5v4",
		"label": "Temporal Skirmish 5v4 (5D chess, fixed)",
		"code": TEMPORAL_CODE,
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
		"code": "series team=6 matches=1 -bots",
	},
	{
		"kind": "series_code",
		"id": "random_6v6_bots_5",
		"label": "5 Random 6v6 CPU vs CPU",
		"code": "series team=6 matches=5 -bots",
	},
	{
		"kind": "series_code",
		"id": "random_6v6_bots_10",
		"label": "10 Random 6v6 CPU vs CPU",
		"code": "series team=6 matches=10 -bots",
	},
]
const MENU_CONTROL_SIZE: Vector2 = Vector2(PmdStyle.CONTROL_WIDTH, PmdStyle.CONTROL_HEIGHT)
const MENU_FONT_SIZE: int = PmdStyle.FONT_BODY
const PRESET_PLACEHOLDER: String = "Choose Preset..."
const CREDITS_URL: String = "https://github.com/franco-rey/PMDEmblem/blob/main/CREDITS.txt"

const MIN_WINDOW_SIZE: Vector2i = Vector2i(1280, 720)

var level_instance: TacticsLevel
var skirmish_loader: SkirmishLoader
var pause_menu: PauseMenu = null
var net_session: NetSession = null
var net_suspend_panel: NetSuspendPanel = null
var _net_previous_state: int = NetSession.IDLE
var multiplayer_menu: MultiplayerMenu = null
var net_beacon: LanBeacon = null
var multiplayer_button: Button = null
var roster_carousel: RosterCarousel = null
var showcase_pedestal: ShowcasePedestal = null
var results_screen: BattleResultsScreen = null
var speed_bar: SpectatorSpeedBar = null
var interface_visible: bool = true
var _controls_enabled: bool = true
var menu_graphics_panel: GraphicsSettingsPanel = null
var menu_controls_panel: ControlsPanel = null
var menu_customize_panel: CustomizePanel = null
var _window_size_seen: Vector2i = Vector2i.ZERO
var _window_size_changed_at: float = -1.0
var controls_button: Button = null
var attack_button: Button = null
var random_pokemon_button: Button = null
var _controls_from_options: bool = false
var options_button: Button = null
var quit_button: Button = null
var credits_button: Button = null
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
	add_child(SoundPlayer.new())
	add_child(UiSoundHook.new())
	add_child(MusicPlayer.new())
	BattleNotation.prune_output_dir()
	_style_main_menu()
	_setup_menus()
	_set_tactics_controls_enabled(false)
	net_session = NetSession.new()
	net_session.local_name = GameSettings.player_name
	net_session.start_requested.connect(_on_net_start_requested)
	net_session.battle_over_remote.connect(_on_net_battle_over)
	net_session.notice.connect(_on_net_notice)
	net_session.desynced.connect(_on_net_desync)
	net_session.state_changed.connect(_on_net_state_changed)
	add_child(net_session)
	net_suspend_panel = NetSuspendPanel.new()
	net_suspend_panel.rejoin_requested.connect(_on_net_rejoin_pressed)
	net_suspend_panel.claim_requested.connect(func() -> void: net_session.claim_win())
	net_suspend_panel.main_menu_requested.connect(_on_main_menu_requested)
	add_child(net_suspend_panel)
	net_beacon = LanBeacon.new()
	add_child(net_beacon)
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
	MusicPlayer.play_scene("menu")


func _process(_delta: float) -> void:
	_poll_net_ready()
	_poll_speed_keys()
	_poll_interface_toggle()
	_sync_turn_speed()
	UiScale.apply(get_tree().root)
	_remember_window_size()
	var backdrop: Control = $UI.get_node_or_null("Backdrop") as Control
	if backdrop != null:
		var overlay: Control = $UI.get_node_or_null("OptionsOverlay") as Control
		backdrop.visible = $UI/MapSelector.visible or (skirmish_lobby != null and skirmish_lobby.visible) or (overlay != null and overlay.visible and level_instance == null)


func _remember_window_size() -> void:
	if not GameSettings.remember_window_size or DisplayServer.get_name() == "headless" or GameSettings.window_mode != "windowed":
		return
	var window_id: int = get_tree().root.get_window_id()
	if DisplayServer.window_get_mode(window_id) != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var current: Vector2i = DisplayServer.window_get_size(window_id)
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if current != _window_size_seen:
		_window_size_seen = current
		_window_size_changed_at = now
		return
	if _window_size_changed_at >= 0.0 and now - _window_size_changed_at > 0.75:
		_window_size_changed_at = -1.0
		if current != GameSettings.resolution and current.x > 0 and current.y > 0:
			GameSettings.resolution = current
			GameSettings.save_settings()


func _on_multiplayer_pressed() -> void:
	var overlay: Control = $UI.get_node_or_null("OptionsOverlay") as Control
	if overlay == null:
		return
	$UI/MapSelector.visible = false
	overlay.visible = true
	menu_graphics_panel.visible = false
	menu_controls_panel.visible = false
	multiplayer_menu.visible = true
	multiplayer_menu.focus_first()


func _on_net_host_requested(port: int) -> void:
	net_session.local_name = GameSettings.player_name
	var error: String = net_session.host(port)
	if not error.is_empty():
		multiplayer_menu.set_status(error)
		return
	net_beacon.start_broadcast(port, GameSettings.player_name)
	_open_network_lobby()


func _on_net_join_requested(address: String, port: int) -> void:
	net_session.local_name = GameSettings.player_name
	var error: String = net_session.join(address, port)
	if not error.is_empty():
		multiplayer_menu.set_status(error)
		return
	multiplayer_menu.set_status("Connecting to %s..." % address)


func _on_net_state_changed(state: int) -> void:
	if state == NetSession.SUSPENDED:
		SoundPlayer.cue("ui.error")
	elif state == NetSession.IN_BATTLE and _net_previous_state == NetSession.SUSPENDED:
		SoundPlayer.cue("lobby.join")
	_net_previous_state = state
	if state == NetSession.LOBBY and skirmish_lobby != null and not skirmish_lobby.visible and level_instance == null:
		_open_network_lobby()
	if state == NetSession.IDLE:
		net_beacon.stop_broadcast()
		if skirmish_lobby != null:
			skirmish_lobby.set_session(null)


func _open_network_lobby() -> void:
	var overlay: Control = $UI.get_node_or_null("OptionsOverlay") as Control
	if overlay != null:
		overlay.visible = false
	if multiplayer_menu != null:
		multiplayer_menu.visible = false
	$UI/MapSelector.visible = false
	_set_tactics_controls_enabled(false)
	if skirmish_lobby != null:
		skirmish_lobby.set_session(net_session)
		skirmish_lobby.open()


func _on_resign_requested() -> void:
	if net_session != null and net_session.in_battle():
		net_session.resign()


func _poll_net_ready() -> void:
	if net_session == null:
		return
	if pause_menu != null:
		pause_menu.pauses_tree = not net_session.battle_live()
		pause_menu.resign_visible = net_session.battle_live()
		pause_menu.network_battle = net_session.battle_live()
	if level_instance != null and is_instance_valid(level_instance) and level_instance.hud != null:
		level_instance.hud.set_network_text(_net_chip_text())
	if net_suspend_panel != null:
		net_suspend_panel.show_status(net_session if level_instance != null and is_instance_valid(level_instance) else null)
	if not net_session.in_battle():
		return
	if level_instance == null or not is_instance_valid(level_instance):
		return
	if level_instance != null and is_instance_valid(level_instance) and level_instance._scheduler_started and not level_instance.intro_pending:
		net_session.mark_ready()


func _net_chip_text() -> String:
	if net_session == null:
		return ""
	if net_session.suspended():
		if net_session.rejoining():
			return "Reconnecting"
		return "Opponent did not return" if net_session.suspend_expired() else "Connection lost, %d s" % int(ceil(net_session.suspend_remaining()))
	if not net_session.in_battle():
		return ""
	var text: String = "Waiting for %s" % net_session.remote_name
	if net_session.ready_to_play() and not net_session.remote_turn_active():
		text = "Your turn"
	var ping: int = net_session.latency_ms()
	return "%s  %d ms" % [text, ping] if ping >= 0 else text


func _on_net_start_requested(code: String, _battle_id: String) -> void:
	if results_screen != null and results_screen.visible:
		results_screen.visible = false
		_finish_ended_level()
	var built: Dictionary = SkirmishCode.build_definitions(code)
	if not bool(built.get("ok", false)):
		push_error("Main: network start code failed: %s" % String(built.get("error", "")))
		return
	var definitions: Array = built.get("definitions", [])
	if definitions.is_empty():
		return
	skirmish_queue.clear()
	skirmish_queue_index = 0
	skirmish_queue_code = ""
	_relaunch = Callable()
	await _launch_definition(definitions[0] as SkirmishDefinitionResource, false)
	if level_instance != null and is_instance_valid(level_instance):
		level_instance.net_session = net_session
		net_session.attach_level(level_instance)


func _on_net_battle_over(result: int, reason: String) -> void:
	if level_instance == null or not is_instance_valid(level_instance) or level_instance.banner == null:
		return
	var won: bool = result == TacticsLevel.RESULT_PLAYER_WIN if net_session.local_side == PokemonInstanceResource.Team.PLAYER else result == TacticsLevel.RESULT_PLAYER_LOSS
	var remote: String = net_session.remote_name if not net_session.remote_name.is_empty() else "The other player"
	var text: String = "Battle ended: %s" % reason
	match reason:
		"resign":
			text = "%s resigned." % remote if won else "You resigned."
		"abandon":
			text = "%s did not return. You win." % remote
		"desync":
			text = "The two games fell out of step."
	level_instance.banner.show_notice(text)


func _on_net_rejoin_pressed() -> void:
	if net_session == null:
		return
	var error: String = net_session.rejoin()
	if not error.is_empty():
		_on_net_notice(error)


func _on_net_desync(reason: String) -> void:
	push_error("Main: multiplayer desync: %s" % reason)
	_on_net_notice("The two games fell out of step: %s" % reason)


func _on_net_notice(text: String) -> void:
	if level_instance != null and is_instance_valid(level_instance) and level_instance.banner != null:
		level_instance.banner.show_notice(text)
	else:
		print("net: %s" % text)


func _on_launch_button_pressed() -> void:
	load_selected_skirmish()


func _setup_menus() -> void:
	pause_menu = PauseMenu.new()
	pause_menu.can_open = _can_open_pause_menu
	pause_menu.restart_requested.connect(_on_restart_requested)
	pause_menu.lobby_requested.connect(_on_return_to_lobby_requested)
	pause_menu.main_menu_requested.connect(_on_main_menu_requested)
	pause_menu.quit_requested.connect(_on_quit_requested)
	pause_menu.resign_requested.connect(_on_resign_requested)
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
		attack_button = _menu_button("Attack", "AttackButton", _on_attack_pressed)
		menu.add_child(attack_button)
		menu.move_child(attack_button, 0)
		random_pokemon_button = _menu_button("Random Pokemon", "RandomPokemonButton", _on_random_pokemon_pressed)
		menu.add_child(random_pokemon_button)
		menu.move_child(random_pokemon_button, 1)
		multiplayer_button = Button.new()
		multiplayer_button.name = "MultiplayerButton"
		multiplayer_button.text = "Multiplayer"
		multiplayer_button.custom_minimum_size = MENU_CONTROL_SIZE
		multiplayer_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		multiplayer_button.add_theme_font_size_override("font_size", MENU_FONT_SIZE)
		multiplayer_button.pressed.connect(_on_multiplayer_pressed)
		menu.add_child(multiplayer_button)
		options_button = Button.new()
		options_button.name = "OptionsButton"
		options_button.text = "Options"
		options_button.custom_minimum_size = MENU_CONTROL_SIZE
		options_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		options_button.add_theme_font_size_override("font_size", MENU_FONT_SIZE)
		options_button.pressed.connect(_on_options_pressed)
		menu.add_child(options_button)
		controls_button = Button.new()
		controls_button.name = "ControlsButton"
		controls_button.text = "Controls"
		controls_button.custom_minimum_size = MENU_CONTROL_SIZE
		controls_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		controls_button.add_theme_font_size_override("font_size", MENU_FONT_SIZE)
		controls_button.pressed.connect(_on_controls_pressed)
		menu.add_child(controls_button)
		credits_button = _menu_button("Credits", "CreditsButton", _on_credits_pressed)
		menu.add_child(credits_button)
		quit_button = Button.new()
		quit_button.name = "QuitButton"
		quit_button.text = "Quit"
		quit_button.custom_minimum_size = MENU_CONTROL_SIZE
		quit_button.size_flags_horizontal = Control.SIZE_SHRINK_END
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
	menu_graphics_panel.controls_requested.connect(_on_controls_from_options)
	menu_customize_panel = CustomizePanel.new()
	menu_customize_panel.visible = false
	menu_customize_panel.closed.connect(_on_customize_closed)
	overlay.add_child(menu_customize_panel)
	menu_graphics_panel.customize_requested.connect(_on_customize_from_options)
	menu_controls_panel = ControlsPanel.new()
	menu_controls_panel.visible = false
	menu_controls_panel.closed.connect(_on_controls_closed)
	overlay.add_child(menu_controls_panel)
	multiplayer_menu = MultiplayerMenu.new()
	multiplayer_menu.visible = false
	multiplayer_menu.closed.connect(func() -> void:
		overlay.visible = false
		multiplayer_menu.visible = false
		$UI/MapSelector.visible = true
		if multiplayer_button != null:
			multiplayer_button.grab_focus())
	multiplayer_menu.host_requested.connect(_on_net_host_requested)
	multiplayer_menu.join_requested.connect(_on_net_join_requested)
	overlay.add_child(multiplayer_menu)


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
	menu_customize_panel.visible = false
	menu_graphics_panel.visible = true
	menu_graphics_panel.refresh()
	menu_graphics_panel.focus_first()


func _menu_button(text: String, node_name: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = MENU_CONTROL_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.add_theme_font_size_override("font_size", MENU_FONT_SIZE)
	button.pressed.connect(callback)
	return button


func _on_credits_pressed() -> void:
	OS.shell_open(CREDITS_URL)


func _on_attack_pressed() -> void:
	if showcase_pedestal != null:
		showcase_pedestal.play_attack()


func _on_random_pokemon_pressed() -> void:
	if roster_carousel != null:
		roster_carousel.spin_to_random()


func _on_controls_pressed() -> void:
	_controls_from_options = false
	_show_controls_panel()


func _on_controls_from_options() -> void:
	_controls_from_options = true
	_show_controls_panel()


func _on_customize_from_options() -> void:
	menu_graphics_panel.visible = false
	menu_controls_panel.visible = false
	menu_customize_panel.visible = true
	menu_customize_panel.refresh()
	menu_customize_panel.focus_first()


func _on_customize_closed() -> void:
	menu_customize_panel.visible = false
	menu_graphics_panel.visible = true
	menu_graphics_panel.refresh()
	menu_graphics_panel.focus_first()


func _show_controls_panel() -> void:
	var overlay: Control = $UI.get_node_or_null("OptionsOverlay") as Control
	if overlay == null:
		return
	$UI/MapSelector.visible = false
	overlay.visible = true
	menu_graphics_panel.visible = false
	menu_controls_panel.visible = true
	menu_controls_panel.focus_first()


func _on_controls_closed() -> void:
	menu_controls_panel.visible = false
	if _controls_from_options:
		menu_graphics_panel.visible = true
		menu_graphics_panel.focus_first()
		return
	var overlay: Control = $UI.get_node_or_null("OptionsOverlay") as Control
	if overlay != null:
		overlay.visible = false
	$UI/MapSelector.visible = true
	if controls_button != null:
		controls_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	if level_instance != null and is_instance_valid(level_instance):
		return
	if _close_menu_overlay():
		SoundPlayer.cue("ui.cancel")
		get_viewport().set_input_as_handled()


func _close_menu_overlay() -> bool:
	if menu_controls_panel != null and menu_controls_panel.visible:
		menu_controls_panel.closed.emit()
		return true
	if menu_graphics_panel != null and menu_graphics_panel.visible:
		menu_graphics_panel.closed.emit()
		return true
	if multiplayer_menu != null and multiplayer_menu.visible:
		multiplayer_menu.closed.emit()
		return true
	if skirmish_lobby != null and skirmish_lobby.visible:
		skirmish_lobby.request_close()
		return true
	return false


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
	if net_session != null and net_session.active():
		net_session.leave("left")
	unload_level()
	_set_tactics_controls_enabled(false)
	if skirmish_lobby != null:
		skirmish_lobby.visible = false
	$UI/MapSelector.visible = true
	launch_button.grab_focus()
	MusicPlayer.play_scene("menu")


func _on_quit_requested() -> void:
	if net_session != null and net_session.active():
		net_session.leave("quit")
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
	_sync_turn_speed()


func _sync_turn_speed() -> void:
	if level_instance == null or not is_instance_valid(level_instance) or level_instance.battle_finished or speed_bar == null:
		return
	if _ended_definition != null and results_screen != null and results_screen.visible:
		return
	var participant: TacticsParticipant = level_instance.participant
	if participant == null or participant.res == null:
		return
	var current: TacticsPawn = participant.res.curr_pawn
	var cpu_turn: bool = current != null and is_instance_valid(current) and current.stats != null and current.stats.pokemon_instance != null and current.stats.pokemon_instance.control_type != PokemonInstanceResource.ControlType.PLAYER and level_instance._scheduler_started
	var wanted: float = GameSettings.cpu_speed
	if _controls_enabled and not is_equal_approx(Engine.time_scale, wanted):
		_set_battle_speed(wanted)
	var show_bar: bool = interface_visible and (cpu_turn or not _controls_enabled)
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
	if net_session != null and net_session.active():
		if not net_session.host_role:
			return
		var code: String = net_session.pending_code
		_finish_ended_level()
		net_session.start_battle(code)
		return
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
		if level_instance.get_parent() != null:
			level_instance.get_parent().remove_child(level_instance)
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
	var idx: int = skirmish_picker.selected - 1
	if idx < 0 or idx >= MANUAL_SKIRMISHES.size():
		push_error("Main: no manual skirmish selected")
		return
	var entry: Dictionary = MANUAL_SKIRMISHES[idx]
	if String(entry.get("kind", "static")) == "series_code":
		var code: String = _randomise_series_code(String(entry.get("code", "")))
		var built: Dictionary = SkirmishCode.build_definitions(code)
		if not bool(built.get("ok", false)):
			push_error("Main: series code build failed: %s" % String(built.get("error", "?")))
			return
		_launch_series(_definitions_from_result(built), code)
		return
	skirmish_queue.clear()
	skirmish_queue_index = 0
	skirmish_queue_code = ""
	var definition: SkirmishDefinitionResource = _resolve_skirmish_definition(entry)
	if definition == null:
		return
	_relaunch = load_selected_skirmish
	_launch_definition(definition, false)


func _randomise_series_code(code: String) -> String:
	var maps: Array[String] = CustomSkirmishBuilder.map_paths()
	var out: String = code
	if not maps.is_empty() and not out.contains("map="):
		out += " map=%s" % maps[randi() % maps.size()].get_file().get_basename()
	if not out.contains("ai="):
		out += " ai=%d" % randi_range(AIProfile.MIN_LEVEL, AIProfile.MAX_LEVEL)
	return out


func _resolve_skirmish_definition(entry: Dictionary) -> SkirmishDefinitionResource:
	var kind: String = String(entry.get("kind", "static"))
	if kind == "random":
		return _build_random_skirmish(entry)
	if kind == "code":
		var built: Dictionary = SkirmishCode.build_definitions(String(entry.get("code", "")))
		if not bool(built.get("ok", false)):
			push_error("Main: preset code failed: %s" % String(built.get("error", "")))
			return null
		var definitions: Array = built.get("definitions", [])
		return definitions[0] if not definitions.is_empty() else null
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
	var map_path: String = maps[randi() % maps.size()]
	var result: Dictionary = CustomSkirmishBuilder.build_random(team_size, map_path, "")
	if not result.get("ok", false):
		push_error("Main: random skirmish build failed: %s" % result.get("error", "?"))
		return null
	var definition: SkirmishDefinitionResource = result["definition"]
	definition.ai_level = randi_range(AIProfile.MIN_LEVEL, AIProfile.MAX_LEVEL)
	print("Main: launching %s seed=%d map=%s ai=%d" % [entry.get("id", "random"), int(result["seed"]), map_path.get_file().get_basename(), definition.ai_level])
	return definition


func _populate_skirmish_picker() -> void:
	skirmish_picker.clear()
	skirmish_picker.add_item(PRESET_PLACEHOLDER)
	for entry in MANUAL_SKIRMISHES:
		skirmish_picker.add_item(_label_for_picker_entry(entry))
	skirmish_picker.select(0)
	if not skirmish_picker.item_selected.is_connected(_on_preset_selected):
		skirmish_picker.item_selected.connect(_on_preset_selected)
	_on_preset_selected(0)


func _on_preset_selected(index: int) -> void:
	if launch_button != null:
		launch_button.disabled = index <= 0


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
	var had_level: bool = level_instance != null and is_instance_valid(level_instance)
	unload_level()
	if had_level:
		await get_tree().physics_frame
		await get_tree().physics_frame
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
	MusicPlayer.play(MusicPlayer.battle_track_for(definition.map.map_id if definition != null and definition.map != null else "", definition.seed if definition != null else 0))
	var camera_node: TacticsCamera = find_child("TacticsCamera", true, false) as TacticsCamera
	if camera_node != null and camera_node.res != null:
		camera_node.res.spectator = not human
	_set_battle_speed(GameSettings.cpu_speed)
	if speed_bar != null:
		speed_bar.visible = not human
		speed_bar.highlight(GameSettings.cpu_speed)
	if level_instance.banner != null and GameSettings.battle_flair and DisplayServer.get_name() != "headless" and (net_session == null or not net_session.active()):
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
	MusicPlayer.play_scene("menu")
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
			MusicPlayer.stop(1.5)
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
		MusicPlayer.stop(1.5)
		var networked: bool = net_session != null and net_session.active()
		results_screen.show_result(result, definition, ended_level, "", net_session.local_side if networked else PokemonInstanceResource.Team.PLAYER)
		if networked:
			results_screen.set_play_again_label("Rematch" if net_session.host_role else "Waiting for %s" % (net_session.remote_name if not net_session.remote_name.is_empty() else "the host"), net_session.host_role)
		return
	if skirmish_loader != null:
		skirmish_loader.unload_current()
	level_instance = null
	if skirmish_lobby != null:
		skirmish_lobby.show_battle_summary(result, definition, ended_level)


func _style_main_menu() -> void:
	get_tree().root.theme = PmdStyle.build_theme(load("res://assets/ui/pmd_theme.tres") as Theme)
	TacticsConfig.apply_highlight_set(GameSettings.highlight_set)
	PmdCursor.ensure(get_tree().root)
	var ui: Control = $UI as Control
	var backdrop := PmdBackdrop.new()
	backdrop.name = "Backdrop"
	ui.add_child(backdrop)
	ui.move_child(backdrop, 0)
	var menu := $UI/MapSelector/SkirmishMenu as VBoxContainer
	if menu != null:
		menu.add_theme_constant_override("separation", PmdStyle.PANEL_GAP)
	_build_roster_showcase()
	for control in [skirmish_picker, launch_button, custom_toggle_button]:
		control.custom_minimum_size = MENU_CONTROL_SIZE
		control.size_flags_horizontal = Control.SIZE_SHRINK_END
		control.add_theme_font_size_override("font_size", MENU_FONT_SIZE)
	skirmish_picker.fit_to_longest_item = false
	skirmish_picker.clip_text = true
	_scale_main_menu()
	get_viewport().size_changed.connect(_scale_main_menu)


func menu_zoom() -> float:
	var height: float = RosterCarousel.DESIGN_HEIGHT
	if is_inside_tree() and get_viewport() != null:
		height = get_viewport().get_visible_rect().size.y
	return clampf(height / RosterCarousel.DESIGN_HEIGHT, 1.0, RosterCarousel.MAX_ZOOM)


func _scale_main_menu() -> void:
	var menu: VBoxContainer = get_node_or_null("UI/MapSelector/SkirmishMenu") as VBoxContainer
	if menu == null:
		return
	var zoom: float = menu_zoom()
	menu.add_theme_constant_override("separation", int(round(PmdStyle.PANEL_GAP * zoom)))
	for child in menu.get_children():
		var control: Control = child as Control
		if control == null or not (control is Button or control is OptionButton):
			continue
		control.custom_minimum_size = MENU_CONTROL_SIZE * zoom
		control.add_theme_font_size_override("font_size", int(round(MENU_FONT_SIZE * zoom)))


func _build_roster_showcase() -> void:
	var selector := $UI/MapSelector as Control
	if selector == null or selector.get_node_or_null("RosterShowcase") != null:
		return
	showcase_pedestal = ShowcasePedestal.new()
	showcase_pedestal.name = "ShowcasePedestal"
	showcase_pedestal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selector.add_child(showcase_pedestal)
	selector.move_child(showcase_pedestal, 0)
	var holder := HBoxContainer.new()
	holder.name = "RosterShowcase"
	holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	holder.grow_vertical = Control.GROW_DIRECTION_BOTH
	holder.offset_left = 24.0
	selector.add_child(holder)
	roster_carousel = RosterCarousel.new()
	roster_carousel.name = "RosterCarousel"
	holder.add_child(roster_carousel)
	roster_carousel.picked.connect(_on_roster_picked)
	roster_carousel.selection_changed.connect(_on_roster_picked)
	var entries: Array[Dictionary] = SkirmishRosterProvider.entries()
	var playable: Array[Dictionary] = []
	for entry in entries:
		if bool(entry.get("battle_ready", false)):
			playable.append(entry)
	var listed: Array[Dictionary] = playable if not playable.is_empty() else entries
	listed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("dex_number", 0)) < int(b.get("dex_number", 0)))
	roster_carousel.set_entries(listed)
	if not listed.is_empty():
		roster_carousel.select_index(randi_range(0, listed.size() - 1), false)
	_on_roster_picked(roster_carousel.selected_entry())


func _on_roster_picked(entry: Dictionary) -> void:
	if showcase_pedestal != null and not entry.is_empty():
		showcase_pedestal.show_entry(entry)


func _set_tactics_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	if tactics_controls == null:
		return
	tactics_controls.visible = enabled and interface_visible
	tactics_controls.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
