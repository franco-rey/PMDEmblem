class_name NetSuspendPanel
extends CanvasLayer

signal rejoin_requested
signal claim_requested
signal main_menu_requested

const LAYER_INDEX: int = 25
const PANEL_WIDTH: float = 620.0
const TOP_OFFSET: float = 300.0

var _panel: PanelContainer = null
var _title: Label = null
var _status: Label = null
var _rejoin: Button = null
var _claim: Button = null
var _menu: Button = null


func _ready() -> void:
	name = "NetSuspendPanel"
	layer = LAYER_INDEX
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_top = TOP_OFFSET
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.add_theme_stylebox_override("panel", PmdStyle.window(PmdStyle.NAVY_DEEP, PmdStyle.FRAME, 3, 10))
	root.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, PmdStyle.PANEL_MARGIN)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", PmdStyle.PANEL_GAP)
	margin.add_child(column)
	_title = Label.new()
	_title.name = "Title"
	_title.text = "Connection lost"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PmdStyle.apply_title(_title, PmdStyle.FONT_TITLE)
	column.add_child(_title)
	_status = Label.new()
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	var row := HBoxContainer.new()
	row.name = "Buttons"
	row.add_theme_constant_override("separation", PmdStyle.PANEL_GAP)
	column.add_child(row)
	_rejoin = _button(row, "Rejoin", "RejoinButton", rejoin_requested)
	_claim = _button(row, "Claim Win", "ClaimButton", claim_requested)
	_menu = _button(row, "Main Menu", "MainMenuButton", main_menu_requested)
	visible = false


func _button(row: HBoxContainer, text: String, node_name: String, target: Signal) -> Button:
	var button := PmdStyle.control_button(text, node_name, func() -> void: target.emit())
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(button)
	return button


func show_status(session: NetSession) -> void:
	if session == null or not session.suspended():
		visible = false
		return
	var remote: String = session.remote_name if not session.remote_name.is_empty() else "The other player"
	var remaining: int = int(ceil(session.suspend_remaining()))
	var expired: bool = session.suspend_expired()
	if session.rejoining():
		_title.text = "Reconnecting"
		_status.text = "Catching up with %s..." % remote if session._catching_up else "Reaching %s..." % remote
	elif expired:
		_title.text = "Opponent did not return"
		_status.text = "%s did not come back in time. Claim the win or return to the main menu." % remote
	elif session.host_role:
		_title.text = "Connection lost"
		_status.text = "Waiting for %s to rejoin: %d s. You can keep playing your turns." % [remote, remaining]
	else:
		_title.text = "Connection lost"
		_status.text = "The link to %s dropped. Retrying every few seconds, %d s left." % [remote, remaining] if session.auto_rejoin else "The link to %s dropped. Rejoin within %d s to continue." % [remote, remaining]
	_rejoin.visible = not session.host_role and not expired
	_rejoin.disabled = not session.can_rejoin()
	_claim.visible = expired
	_menu.visible = true
	visible = true
