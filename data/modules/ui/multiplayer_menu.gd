class_name MultiplayerMenu
extends MenuPanel

signal closed
signal host_requested(port: int)
signal join_requested(address: String, port: int)

const FIELD_WIDTH: float = 460.0

var name_input: LineEdit = null
var port_input: LineEdit = null
var address_input: LineEdit = null
var join_port_input: LineEdit = null
var status_label: Label = null
var host_list: VBoxContainer = null
var beacon: LanBeacon = null


func _ready() -> void:
	super()
	name = "MultiplayerMenu"
	set_title("Direct Connect")
	name_input = _field("NameInput", GameSettings.player_name)
	name_input.text_changed.connect(_on_name_changed)
	add_row("Your name", name_input, FIELD_WIDTH)
	port_input = _field("PortInput", str(GameSettings.net_port))
	add_row("Port", port_input, FIELD_WIDTH)
	add_body_button("Host Game", "HostButton", _on_host_pressed)
	body.add_child(_separator())
	address_input = _field("AddressInput", GameSettings.last_address)
	add_row("Host address", address_input, FIELD_WIDTH)
	join_port_input = _field("JoinPortInput", str(GameSettings.net_port))
	add_row("Port", join_port_input, FIELD_WIDTH)
	add_body_button("Join Game", "JoinButton", _on_join_pressed)
	add_heading("Games on this network")
	host_list = VBoxContainer.new()
	host_list.name = "HostList"
	host_list.add_theme_constant_override("separation", 4)
	body.add_child(host_list)
	status_label = add_caption("Both players need the same game version and Pokemon data. Over the internet the host has to forward the port.")
	status_label.name = "StatusLabel"
	add_footer_button("Back", "BackButton", _on_back_pressed)
	beacon = LanBeacon.new()
	add_child(beacon)
	beacon.hosts_changed.connect(_on_hosts_changed)
	visibility_changed.connect(_on_visibility_changed)
	_refresh_host_list([])


func _field(node_name: String, text: String) -> LineEdit:
	var input := LineEdit.new()
	input.name = node_name
	input.text = text
	return input


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
	fit_to_viewport()
	if name_input != null and name_input.is_inside_tree():
		name_input.grab_focus()


func _on_hosts_changed(hosts: Array) -> void:
	_refresh_host_list(hosts)


func _refresh_host_list(hosts: Array) -> void:
	if host_list == null:
		return
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
		button.custom_minimum_size.y = PmdStyle.ROW_HEIGHT
		var address: String = String(entry.get("address", ""))
		var port: int = int(entry.get("port", EnetLink.DEFAULT_PORT))
		button.pressed.connect(func() -> void:
			address_input.text = address
			join_port_input.text = str(port))
		host_list.add_child(button)
