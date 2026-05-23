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

## Reference to the World node
@onready var world: Node3D = $World
## Reference to the manual skirmish picker
@onready var skirmish_picker: OptionButton = $UI/MapSelector/SkirmishMenu/SkirmishPicker
## Reference to the launch button
@onready var launch_button: Button = $UI/MapSelector/SkirmishMenu/LaunchButton
#endregion

#region: --- Processing ---
## Called when the node enters the scene tree for the first time
func _ready() -> void:
	skirmish_loader = SkirmishLoader.new()
	add_child(skirmish_loader)
	_populate_skirmish_picker()
	launch_button.grab_focus()
#endregion

#region: --- Signals ---
## Called when the launch button is pressed
func _on_launch_button_pressed() -> void:
	load_selected_skirmish()
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
#endregion
