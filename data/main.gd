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

var level_instance: TacticsLevel
var skirmish_loader: SkirmishLoader
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
	UiScale.watch(get_tree().root)
	BattleNotation.clear_output_dir()
	_style_main_menu()
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
	UiScale.apply(get_tree().root)


func _on_launch_button_pressed() -> void:
	load_selected_skirmish()


func _on_custom_toggle_pressed() -> void:
	$UI/MapSelector.visible = false
	_set_tactics_controls_enabled(false)
	if skirmish_lobby != null:
		skirmish_lobby.open()

func unload_level() -> void:
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
	_set_tactics_controls_enabled(_definition_has_human_control(definition))


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
	var ended_level: TacticsLevel = level_instance
	if skirmish_loader != null:
		skirmish_loader.unload_current()
	level_instance = null
	if not skirmish_queue.is_empty() and skirmish_queue_index < skirmish_queue.size():
		await get_tree().create_timer(0.75).timeout
		_launch_next_queued_skirmish()
		return
	if skirmish_lobby != null:
		skirmish_lobby.show_battle_summary(result, definition, ended_level)
	$UI/MapSelector.visible = false
	skirmish_queue.clear()
	skirmish_queue_index = 0
	skirmish_queue_code = ""


func _style_main_menu() -> void:
	var menu := $UI/MapSelector/SkirmishMenu as VBoxContainer
	if menu != null:
		menu.add_theme_constant_override("separation", 8)
	for control in [skirmish_picker, launch_button, custom_toggle_button]:
		control.custom_minimum_size = MENU_CONTROL_SIZE
		control.add_theme_font_size_override("font_size", MENU_FONT_SIZE)


func _set_tactics_controls_enabled(enabled: bool) -> void:
	if tactics_controls == null:
		return
	tactics_controls.visible = enabled
	tactics_controls.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
