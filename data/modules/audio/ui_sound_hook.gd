class_name UiSoundHook
extends Node

const CANCEL_WORDS: Array[String] = ["cancel", "back", "close"]
const OPT_OUT_GROUP: String = "no_ui_sound"

var _keyboard_focus: bool = false


func _ready() -> void:
	name = "UiSoundHook"
	process_mode = Node.PROCESS_MODE_ALWAYS
	for node in get_tree().root.find_children("*", "Control", true, false):
		_attach(node)
	get_tree().node_added.connect(_attach)


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_keyboard_focus = true
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		_keyboard_focus = false


func _attach(node: Node) -> void:
	if not (node is Control) or node.is_in_group(OPT_OUT_GROUP):
		return
	if node is CheckButton or node is CheckBox:
		(node as BaseButton).toggled.connect(func(_pressed: bool) -> void: SoundPlayer.cue("ui.toggle"))
		node.focus_entered.connect(_on_focus.bind(node))
	elif node is OptionButton:
		(node as OptionButton).item_selected.connect(func(_index: int) -> void: SoundPlayer.cue("ui.confirm"))
		node.focus_entered.connect(_on_focus.bind(node))
	elif node is BaseButton:
		(node as BaseButton).pressed.connect(_on_pressed.bind(node))
		node.focus_entered.connect(_on_focus.bind(node))
	elif node is Slider:
		node.focus_entered.connect(_on_focus.bind(node))


func _on_pressed(node: Control) -> void:
	SoundPlayer.cue("ui.cancel" if is_cancel_control(node) else "ui.confirm")


func _on_focus(node: Control) -> void:
	if _keyboard_focus and node.is_visible_in_tree():
		SoundPlayer.cue("ui.cursor")


static func is_cancel_control(node: Control) -> bool:
	var haystack: String = node.name.to_lower()
	if node is Button:
		haystack += " " + (node as Button).text.to_lower()
	for word in CANCEL_WORDS:
		if haystack.contains(word):
			return true
	return false
