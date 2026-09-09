class_name MultiplayerMenu
extends CenterContainer

signal closed
signal host_requested(port: int)
signal join_requested(address: String, port: int)

const PANEL_WIDTH: float = 620.0
const ROW_HEIGHT: float = 44.0

var name_input: LineEdit = null
var port_input: LineEdit = null
var address_input: LineEdit = null
var join_port_input: LineEdit = null
var status_label: Label = null
var host_list: VBoxContainer = null
var beacon: LanBeacon = null

var _panel: PanelContainer = null


func _ready() -> void:
	name = "MultiplayerMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.add_theme_stylebox_override("panel", PmdStyle.window(PmdStyle.NAVY_DEEP, PmdStyle.FRAME, 3, 10))
	centre.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 18)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Direct Connect"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PmdStyle.apply_title(title, 40)
	column.add_child(title)

	name_input = LineEdit.new()
	name_input.name = "NameInput"
	name_input.custom_minimum_size.y = ROW_HEIGHT
	name_input.text = GameSettings.player_name
	name_input.text_changed.connect(_on_name_changed)
	column.add_child(_row("Your name", name_input))

	port_input = LineEdit.new()
	port_input.name = "PortInput"
	port_input.custom_minimum_size.y = ROW_HEIGHT
	port_input.text = str(GameSettings.net_port)
	column.add_child(_row("Port", port_input))

	var host_button := Button.new()
	host_button.name = "HostButton"
	host_button.text = "Host Game"
	host_button.custom_minimum_size.y = ROW_HEIGHT
	host_button.pressed.connect(_on_host_pressed)
	column.add_child(host_button)

	column.add_child(_separator())

	address_input = LineEdit.new()
	address_input.name = "AddressInput"
	address_input.custom_minimum_size.y = ROW_HEIGHT
	address_input.text = GameSettings.last_address
	column.add_child(_row("Host address", address_input))

	join_port_input = LineEdit.new()
	join_port_input.name = "JoinPortInput"
	join_port_input.custom_minimum_size.y = ROW_HEIGHT
	join_port_input.text = str(GameSettings.net_port)
	column.add_child(_row("Port", join_port_input))

	var join_button := Button.new()
	join_button.name = "JoinButton"
	join_button.text = "Join Game"
	join_button.custom_minimum_size.y = ROW_HEIGHT
	join_button.pressed.connect(_on_join_pressed)
	column.add_child(join_button)

	var found := Label.new()
	found.text = "Games on this network"
	found.add_theme_color_override("font_color", PmdStyle.TEXT_DIM)
	column.add_child(found)
	host_list = VBoxContainer.new()
	host_list.name = "HostList"
	host_list.add_theme_constant_override("separation", 4)
	column.add_child(host_list)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.text = "Both players need the same game version and Pokemon data. Over the internet the host has to forward the port."
	status_label.add_theme_color_override("font_color", PmdStyle.TEXT_DIM)
	column.add_child(status_label)

	var back := Button.new()
	back.name = "BackButton"
	back.text = "Back"
	back.custom_minimum_size.y = ROW_HEIGHT
	back.pressed.connect(_on_back_pressed)
	column.add_child(back)

	beacon = LanBeacon.new()
	add_child(beacon)
	beacon.hosts_changed.connect(_on_hosts_changed)
	visibility_changed.connect(_on_visibility_changed)
	_refresh_host_list([])


func _row(label_text: String, control: Control) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 180
	box.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(control)
	return box


func _separator() -> HSeparator:
	var line := HSeparator.new()
	line.custom_minimum_size.y = 8
	return line


func _on_visibility_changed() -> void:
	if beacon == null:
		return
	if visible:
		beacon.start_listening()
	else:
		beacon.stop_listening()


func _on_name_changed(text: String) -> void:
	GameSettings.player_name = text.strip_edges()
	GameSettings.save_settings()


func _port_value(input: LineEdit) -> int:
	var text: String = input.text.strip_edges()
	return int(text) if text.is_valid_int() and int(text) > 0 and int(text) < 65536 else EnetLink.DEFAULT_PORT


func _on_host_pressed() -> void:
	var port: int = _port_value(port_input)
	GameSettings.net_port = port
	GameSettings.save_settings()
	host_requested.emit(port)


func _on_join_pressed() -> void:
	var port: int = _port_value(join_port_input)
	var address: String = address_input.text.strip_edges()
	if address.is_empty():
		set_status("Enter the host's address first.")
		return
	GameSettings.net_port = port
	GameSettings.last_address = address
	GameSettings.save_settings()
	join_requested.emit(address, port)


func _on_back_pressed() -> void:
	closed.emit()


func set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func focus_first() -> void:
	var button: Button = find_child("HostButton", true, false) as Button
	if button != null:
		button.grab_focus()


func _on_hosts_changed(hosts: Array) -> void:
	_refresh_host_list(hosts)


func _refresh_host_list(hosts: Array) -> void:
	for child in host_list.get_children():
		child.queue_free()
	if hosts.is_empty():
		var none := Label.new()
		none.text = "None found yet"
		none.add_theme_color_override("font_color", PmdStyle.TEXT_DIM)
		host_list.add_child(none)
		return
	for entry in hosts:
		var button := Button.new()
		button.text = "%s at %s" % [String(entry.get("name", "Player")), String(entry.get("address", ""))]
		button.custom_minimum_size.y = ROW_HEIGHT
		var address: String = String(entry.get("address", ""))
		var port: int = int(entry.get("port", EnetLink.DEFAULT_PORT))
		button.pressed.connect(func() -> void:
			address_input.text = address
			join_port_input.text = str(port))
		host_list.add_child(button)
