class_name TacticsUIService
extends RefCounted

var controls: TacticsControlsResource


func _init(_controls: TacticsControlsResource) -> void:
	controls = _controls


func ensure_move_picker(ctrl: TacticsControls) -> VBoxContainer:
	if ctrl == null:
		return null
	var existing: VBoxContainer = _move_picker(ctrl)
	if existing != null:
		_ensure_move_buttons(existing, ctrl)
		return existing
	var hbox: HBoxContainer = ctrl.get_node_or_null("HBox") as HBoxContainer
	if hbox == null:
		return null
	var picker: VBoxContainer = VBoxContainer.new()
	picker.name = "MovePicker"
	picker.unique_name_in_owner = true
	picker.visible = false
	picker.mouse_filter = Control.MOUSE_FILTER_STOP
	picker.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_child(picker)
	_ensure_move_buttons(picker, ctrl)
	return picker


func _ensure_move_buttons(picker: VBoxContainer, ctrl: TacticsControls) -> void:
	for i: int in range(PokemonInstanceResource.MAX_MOVE_SLOTS):
		var button: Button = picker.get_node_or_null("MoveSlot%d" % i) as Button
		if button == null:
			button = Button.new()
			button.name = "MoveSlot%d" % i
			picker.add_child(button)
		button.custom_minimum_size = Vector2(240, 58)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if button.text.is_empty():
			button.text = "-"
		_replace_signal_connections(button.pressed, ctrl._player_wants_to_select_move.bind(i))
		_replace_signal_connections(button.button_down, ctrl._player_wants_to_select_move.bind(i))
		_replace_signal_connections(button.gui_input, _on_move_picker_slot_gui_input.bind(ctrl, i))
		if controls != null:
			_replace_signal_connections(button.mouse_entered, _on_move_picker_slot_mouse_entered.bind(ctrl, i))
			_replace_signal_connections(button.mouse_exited, _on_move_picker_slot_mouse_exited.bind(ctrl, i))
	var cancel_button: Button = picker.get_node_or_null("Cancel") as Button
	if cancel_button == null:
		cancel_button = Button.new()
		cancel_button.name = "Cancel"
		picker.add_child(cancel_button)
	cancel_button.custom_minimum_size = Vector2(240, 48)
	cancel_button.mouse_filter = Control.MOUSE_FILTER_STOP
	cancel_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cancel_button.text = "Cancel"
	_replace_signal_connections(cancel_button.pressed, ctrl._player_wants_to_cancel_move_picker)
	_replace_signal_connections(cancel_button.button_down, ctrl._player_wants_to_cancel_move_picker)
	_replace_signal_connections(cancel_button.gui_input, _on_move_picker_cancel_gui_input.bind(ctrl))


func _on_move_picker_slot_gui_input(event: InputEvent, ctrl: TacticsControls, slot_index: int) -> void:
	if ctrl == null:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			ctrl._player_wants_to_select_move(slot_index)
			if ctrl.get_viewport() != null:
				ctrl.get_viewport().set_input_as_handled()


func _on_move_picker_slot_mouse_entered(ctrl: TacticsControls, slot_index: int) -> void:
	if ctrl == null or ctrl.serv == null or controls == null:
		return
	controls.preview_move_slot(slot_index)
	ctrl.serv.refresh_hover_preview()


func _on_move_picker_slot_mouse_exited(ctrl: TacticsControls, slot_index: int) -> void:
	if ctrl == null or ctrl.serv == null or controls == null:
		return
	controls.clear_preview_move_slot(slot_index)
	ctrl.serv.refresh_hover_preview()


func _on_move_picker_cancel_gui_input(event: InputEvent, ctrl: TacticsControls) -> void:
	if ctrl == null:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			ctrl._player_wants_to_cancel_move_picker()
			if ctrl.get_viewport() != null:
				ctrl.get_viewport().set_input_as_handled()


func _replace_signal_connections(signal_ref: Signal, callable: Callable) -> void:
	for connection: Dictionary in signal_ref.get_connections():
		var connected_callable: Callable = connection.get("callable", Callable())
		if connected_callable.is_valid():
			signal_ref.disconnect(connected_callable)
	if not signal_ref.is_connected(callable):
		signal_ref.connect(callable)


func update_controller_hints(ctrl: TacticsControls) -> void:
	if controls.is_joystick:
		ctrl.get_node("%ControllerHints").texture = ctrl.layout_xbox
	else:
		ctrl.get_node("%ControllerHints").texture = ctrl.layout_pc


func set_actions_menu_visibility(v: bool, p: TacticsPawn, ctrl: TacticsControls) -> void:
	var picker: VBoxContainer = ensure_move_picker(ctrl)
	if v and picker != null:
		picker.visible = false
	var actions: VBoxContainer = _actions_container(ctrl)
	if actions == null:
		return
	if not actions.visible:
		var move_button: Button = actions.get_node_or_null("Move") as Button
		if move_button != null and move_button.is_inside_tree():
			move_button.grab_focus()

	if not p:
		actions.visible = false
		return
	actions.visible = v and p.can_act()

	var action_move: Button = actions.get_node_or_null("Move") as Button
	var action_attack: Button = actions.get_node_or_null("Attack") as Button
	if action_move != null:
		if controls != null:
			_replace_signal_connections(action_move.mouse_entered, _on_move_action_mouse_entered.bind(ctrl))
			_replace_signal_connections(action_move.mouse_exited, _on_move_action_mouse_exited.bind(ctrl))
		action_move.disabled = not p.res.can_move
	var has_usable_move: bool = p.stats.move_slots.is_empty() or p.stats.first_usable_move_index(false) >= 0
	if action_attack != null:
		action_attack.disabled = not p.res.can_attack or not has_usable_move


func _on_move_action_mouse_entered(ctrl: TacticsControls) -> void:
	if ctrl == null or ctrl.serv == null or controls == null:
		return
	controls.preview_movement()
	ctrl.serv.refresh_hover_preview()


func _on_move_action_mouse_exited(ctrl: TacticsControls) -> void:
	if ctrl == null or ctrl.serv == null or controls == null:
		return
	controls.clear_preview_movement()
	ctrl.serv.refresh_hover_preview()


func set_move_picker_visibility(v: bool, p: TacticsPawn, ctrl: TacticsControls, all_units: Array[TacticsPawn]) -> void:
	var picker: VBoxContainer = ensure_move_picker(ctrl)
	if picker == null:
		return
	picker.visible = v and p != null and p.is_alive()
	if not picker.visible:
		return
	for i: int in range(PokemonInstanceResource.MAX_MOVE_SLOTS):
		var button: Button = picker.get_node("MoveSlot%d" % i) as Button
		var move: PokemonMoveResource = p.stats.move_slots[i] if i < p.stats.move_slots.size() else null
		if move == null:
			button.text = "-"
			button.disabled = true
			continue
		var pp: int = p.stats.current_pp[i] if i < p.stats.current_pp.size() else 0
		var has_pp: bool = pp > 0
		var has_target: bool = Targeting.has_legal_target(p, move, all_units)
		button.text = "%s\n%s %s  PP %d/%d" % [
			move.display_name(),
			move.type.capitalize(),
			_category_label(move),
			pp,
			move.pp,
		]
		button.disabled = not has_pp or not has_target
		button.tooltip_text = "No PP" if not has_pp else ("No legal target" if not has_target else "")
	var first: Control = _first_enabled_child(picker)
	if first != null and first.is_inside_tree():
		first.grab_focus()


func _first_enabled_child(container: Control) -> Control:
	for child: Node in container.get_children():
		if child is Button and not (child as Button).disabled:
			return child as Control
	return null


func _category_label(move: PokemonMoveResource) -> String:
	match move.category:
		PokemonMoveResource.CATEGORY_PHYSICAL:
			return "Physical"
		PokemonMoveResource.CATEGORY_SPECIAL:
			return "Special"
		_:
			return "Status"


func _move_picker(ctrl: TacticsControls) -> VBoxContainer:
	var node: Node = ctrl.get_node_or_null("HBox/MovePicker")
	if node == null:
		node = ctrl.get_node_or_null("%MovePicker")
	if node == null:
		node = ctrl.find_child("MovePicker", true, false)
	return node as VBoxContainer


func _actions_container(ctrl: TacticsControls) -> VBoxContainer:
	if ctrl == null:
		return null
	var node: Node = ctrl.get_node_or_null("HBox/Actions")
	if node == null:
		node = ctrl.get_node_or_null("%Actions")
	return node as VBoxContainer
