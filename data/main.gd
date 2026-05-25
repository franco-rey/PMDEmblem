extends Node

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
]
const MENU_CONTROL_SIZE: Vector2 = Vector2(400, 48)
const MENU_FONT_SIZE: int = 20

var level_instance: TacticsLevel
var skirmish_loader: SkirmishLoader

@onready var world: Node3D = $World
@onready var skirmish_picker: OptionButton = $UI/MapSelector/SkirmishMenu/SkirmishPicker
@onready var launch_button: Button = $UI/MapSelector/SkirmishMenu/LaunchButton
@onready var custom_toggle_button: Button = $UI/MapSelector/SkirmishMenu/CustomToggleButton
@onready var skirmish_lobby: SkirmishLobby = $UI/SkirmishLobby
@onready var tactics_controls: Control = $TacticsControls

func _ready() -> void:
	_style_main_menu()
	_set_tactics_controls_enabled(false)
	skirmish_loader = SkirmishLoader.new()
	add_child(skirmish_loader)
	skirmish_loader.skirmish_ended.connect(_on_skirmish_ended)
	_populate_skirmish_picker()
	if skirmish_lobby != null:
		skirmish_lobby.visible = false
		skirmish_lobby.launch_requested.connect(_on_lobby_launch_requested)
		skirmish_lobby.close_requested.connect(_on_lobby_close_requested)
	launch_button.grab_focus()

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
	_set_tactics_controls_enabled(true)


func _on_lobby_launch_requested(definition: SkirmishDefinitionResource, seed: int) -> void:
	print("Main: launching lobby skirmish %s seed=%d" % [definition.skirmish_id, seed])
	_launch_definition(definition, true)


func _on_lobby_close_requested() -> void:
	$UI/MapSelector.visible = true
	_set_tactics_controls_enabled(false)
	launch_button.grab_focus()


func _on_skirmish_ended(result: int, definition: SkirmishDefinitionResource) -> void:
	_set_tactics_controls_enabled(false)
	if skirmish_lobby != null:
		skirmish_lobby.show_battle_summary(result, definition, level_instance)
	$UI/MapSelector.visible = false
	if skirmish_loader != null:
		skirmish_loader.unload_current()
	level_instance = null


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
