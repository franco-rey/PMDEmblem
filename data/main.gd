extends Node
## A placeholder script that is meant to be replaced by your own level loader system

#region: --- Props ---
const MANUAL_SKIRMISHES: Array[Dictionary] = [
	{
		"id": "demo_3v3",
		"path": "res://data/models/skirmish/manual/demo_3v3.tres",
	},
	{
		"id": "single_1v1",
		"path": "res://data/models/skirmish/manual/single_1v1.tres",
	},
	{
		"id": "team_3v3",
		"path": "res://data/models/skirmish/manual/team_3v3.tres",
	},
	{
		"id": "type_effectiveness_test",
		"path": "res://data/models/skirmish/manual/type_effectiveness_test.tres",
	},
]

## The current instance of the TacticsLevel
var level_instance: TacticsLevel
var skirmish_loader: SkirmishLoader

var _roster_paths: Array[String] = []
var _map_paths: Array[String] = []
var _player_team_paths: Array[String] = []
var _enemy_team_paths: Array[String] = []

## Reference to the World node
@onready var world: Node3D = $World
## Reference to the manual skirmish picker
@onready var skirmish_picker: OptionButton = $UI/MapSelector/SkirmishMenu/SkirmishPicker
## Reference to the launch button
@onready var launch_button: Button = $UI/MapSelector/SkirmishMenu/LaunchButton
@onready var custom_builder: VBoxContainer = $UI/MapSelector/SkirmishMenu/CustomBuilder
@onready var player_picker: OptionButton = $UI/MapSelector/SkirmishMenu/CustomBuilder/PlayerTeamRow/PlayerPicker
@onready var enemy_picker: OptionButton = $UI/MapSelector/SkirmishMenu/CustomBuilder/EnemyTeamRow/EnemyPicker
@onready var player_team_list_label: Label = $UI/MapSelector/SkirmishMenu/CustomBuilder/PlayerTeamList
@onready var enemy_team_list_label: Label = $UI/MapSelector/SkirmishMenu/CustomBuilder/EnemyTeamList
@onready var map_picker: OptionButton = $UI/MapSelector/SkirmishMenu/CustomBuilder/MapPicker
@onready var seed_input: LineEdit = $UI/MapSelector/SkirmishMenu/CustomBuilder/SeedInput
@onready var resolved_seed_label: Label = $UI/MapSelector/SkirmishMenu/CustomBuilder/ResolvedSeedLabel
@onready var status_label: Label = $UI/MapSelector/SkirmishMenu/CustomBuilder/StatusLabel
#endregion

#region: --- Processing ---
## Called when the node enters the scene tree for the first time
func _ready() -> void:
	skirmish_loader = SkirmishLoader.new()
	add_child(skirmish_loader)
	_populate_skirmish_picker()
	_populate_custom_pickers()
	_refresh_team_labels()
	launch_button.grab_focus()
#endregion

#region: --- Signals ---
## Called when the launch button is pressed
func _on_launch_button_pressed() -> void:
	load_selected_skirmish()


func _on_custom_toggle_pressed() -> void:
	custom_builder.visible = not custom_builder.visible


func _on_player_add_pressed() -> void:
	_add_to_team(_player_team_paths, player_picker, "Player")


func _on_player_remove_pressed() -> void:
	_remove_from_team(_player_team_paths, "Player")


func _on_enemy_add_pressed() -> void:
	_add_to_team(_enemy_team_paths, enemy_picker, "Enemy")


func _on_enemy_remove_pressed() -> void:
	_remove_from_team(_enemy_team_paths, "Enemy")


func _on_launch_custom_pressed() -> void:
	_launch_custom_skirmish()
#endregion

#region: --- Methods ---
## Unloads the current level instance
func unload_level() -> void:
	if skirmish_loader != null and level_instance == skirmish_loader.current_level:
		skirmish_loader.unload_current()
	elif is_instance_valid(level_instance):
		level_instance.queue_free()
	level_instance = null # Reset the level instance variable

## Loads the current level instance -- clears existing level in the process
##
## @param level_name: The name of the level to load
func load_level(level_name: String) -> void:
	unload_level() # Unload the current level
	var level_path: String = "res://assets/maps/level/%s_level.tscn" % level_name # Construct the level path
	level_instance = load(level_path).instantiate() # Load and instantiate the new level
	world.add_child(level_instance) # Add the new level to the World node
	$UI/MapSelector.visible = false # Hide the map selector UI


func load_selected_skirmish() -> void:
	var idx: int = skirmish_picker.selected
	if idx < 0 or idx >= MANUAL_SKIRMISHES.size():
		push_error("Main: no manual skirmish selected")
		return
	var path: String = MANUAL_SKIRMISHES[idx].get("path", "")
	var definition: SkirmishDefinitionResource = load(path) as SkirmishDefinitionResource
	if definition == null:
		push_error("Main: could not load skirmish %s" % path)
		return
	unload_level()
	level_instance = skirmish_loader.load_skirmish(definition, world)
	$UI/MapSelector.visible = false


func _populate_skirmish_picker() -> void:
	skirmish_picker.clear()
	for entry in MANUAL_SKIRMISHES:
		var definition: SkirmishDefinitionResource = load(entry.get("path", "")) as SkirmishDefinitionResource
		var label: String = definition.display_name if definition != null else entry.get("id", "")
		skirmish_picker.add_item(label)


func _populate_custom_pickers() -> void:
	_roster_paths = CustomSkirmishBuilder.roster_paths()
	_map_paths = CustomSkirmishBuilder.map_paths()

	player_picker.clear()
	enemy_picker.clear()
	for path in _roster_paths:
		var label: String = _roster_label_from_path(path)
		player_picker.add_item(label)
		enemy_picker.add_item(label)

	map_picker.clear()
	for path in _map_paths:
		var map_res: MapDefinitionResource = load(path) as MapDefinitionResource
		var label: String = map_res.display_name if map_res != null and not map_res.display_name.is_empty() else path.get_file()
		map_picker.add_item(label)


func _roster_label_from_path(path: String) -> String:
	var instance: PokemonInstanceResource = load(path) as PokemonInstanceResource
	if instance != null:
		return instance.display_name()
	return path.get_file().get_basename().capitalize()


func _add_to_team(team: Array[String], picker: OptionButton, side_label: String) -> void:
	if team.size() >= CustomSkirmishBuilder.MAX_TEAM_SIZE:
		_set_status("%s team is at the %d-Pokemon cap" % [side_label, CustomSkirmishBuilder.MAX_TEAM_SIZE])
		return
	var idx: int = picker.selected
	if idx < 0 or idx >= _roster_paths.size():
		_set_status("Pick a roster Pokemon first")
		return
	team.append(_roster_paths[idx])
	_set_status("")
	_refresh_team_labels()


func _remove_from_team(team: Array[String], side_label: String) -> void:
	if team.is_empty():
		_set_status("%s team is already empty" % side_label)
		return
	team.pop_back()
	_set_status("")
	_refresh_team_labels()


func _refresh_team_labels() -> void:
	player_team_list_label.text = "Player team: %s" % _format_team(_player_team_paths)
	enemy_team_list_label.text = "Enemy team: %s" % _format_team(_enemy_team_paths)


func _format_team(team: Array[String]) -> String:
	if team.is_empty():
		return "(empty)"
	var parts: Array[String] = []
	for path in team:
		parts.append(_roster_label_from_path(path))
	return ", ".join(parts)


func _launch_custom_skirmish() -> void:
	if _map_paths.is_empty():
		_set_status("No maps available")
		return
	var map_idx: int = clampi(map_picker.selected, 0, _map_paths.size() - 1)
	var seed_text: String = seed_input.text
	var result: Dictionary = CustomSkirmishBuilder.build(_player_team_paths, _enemy_team_paths, _map_paths[map_idx], seed_text)
	if not result.get("ok", false):
		_set_status(result.get("error", "Unknown error"))
		return
	var definition: SkirmishDefinitionResource = result["definition"]
	var resolved_seed: int = int(result["seed"])
	resolved_seed_label.text = "Last seed: %d" % resolved_seed
	print("Main: launching custom skirmish %s seed=%d" % [definition.skirmish_id, resolved_seed])
	unload_level()
	level_instance = skirmish_loader.load_skirmish(definition, world)
	if level_instance == null:
		_set_status("Loader rejected the custom skirmish; see error log")
		return
	$UI/MapSelector.visible = false


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text
#endregion
