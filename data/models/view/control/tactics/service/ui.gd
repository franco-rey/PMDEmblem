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


func ensure_item_action_button(ctrl: TacticsControls) -> Button:
	var actions: VBoxContainer = _actions_container(ctrl)
	if actions == null:
		return null
	var existing: Button = actions.get_node_or_null("Item") as Button
	if existing != null:
		return existing
	var button := Button.new()
	button.name = "Item"
	button.text = "Item"
	var attack: Button = actions.get_node_or_null("Attack") as Button
	if attack != null:
		button.custom_minimum_size = attack.custom_minimum_size
		button.size_flags_horizontal = attack.size_flags_horizontal
		button.focus_mode = attack.focus_mode
		button.mouse_default_cursor_shape = attack.mouse_default_cursor_shape
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	actions.add_child(button)
	if attack != null:
		actions.move_child(button, attack.get_index() + 1)
	return button


func ensure_item_picker(ctrl: TacticsControls) -> VBoxContainer:
	if ctrl == null:
		return null
	var existing: VBoxContainer = _item_picker(ctrl)
	if existing != null:
		_ensure_item_buttons(existing, ctrl)
		return existing
	var hbox: HBoxContainer = ctrl.get_node_or_null("HBox") as HBoxContainer
	if hbox == null:
		return null
	var picker: VBoxContainer = VBoxContainer.new()
	picker.name = "ItemPicker"
	picker.unique_name_in_owner = true
	picker.visible = false
	picker.mouse_filter = Control.MOUSE_FILTER_STOP
	picker.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_child(picker)
	_ensure_item_buttons(picker, ctrl)
	return picker


func _ensure_item_buttons(picker: VBoxContainer, ctrl: TacticsControls) -> void:
	var specs: Array = [
		["ItemUse", "Use", Callable(ctrl, "_player_wants_to_select_item_use")],
		["ItemThrow", "Throw", Callable(ctrl, "_player_wants_to_select_item_throw")],
		["Cancel", "Cancel", Callable(ctrl, "_player_wants_to_cancel_item_picker")],
	]
	for spec in specs:
		var button: Button = picker.get_node_or_null(String(spec[0])) as Button
		if button == null:
			button = Button.new()
			button.name = String(spec[0])
			picker.add_child(button)
		button.custom_minimum_size = Vector2(240, 48)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if button.text.is_empty():
			button.text = String(spec[1])
		var callable: Callable = spec[2]
		_replace_signal_connections(button.pressed, callable)
		_replace_signal_connections(button.button_down, callable)
		_replace_signal_connections(button.gui_input, _on_item_picker_gui_input.bind(callable, ctrl))


func _on_item_picker_gui_input(event: InputEvent, callable: Callable, ctrl: TacticsControls) -> void:
	if ctrl == null:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if callable.is_valid():
				callable.call()
			if ctrl.get_viewport() != null:
				ctrl.get_viewport().set_input_as_handled()


func set_item_picker_visibility(v: bool, p: TacticsPawn, ctrl: TacticsControls) -> void:
	if controls != null and controls.remote_turn:
		v = false
	var picker: VBoxContainer = ensure_item_picker(ctrl)
	if picker == null:
		return
	var item: PokemonItemResource = PokemonItemService.held_item_for(p.stats) if p != null and p.stats != null else null
	picker.visible = v and p != null and p.is_alive() and item != null
	if not picker.visible:
		return
	var entry: Dictionary = BattleItemCatalog.entry_for(item.item_id)
	var use_button: Button = picker.get_node("ItemUse") as Button
	var throw_button: Button = picker.get_node("ItemThrow") as Button
	var can_use: bool = bool(entry.get("can_use", false))
	use_button.text = "%s %s" % [String(entry.get("use_verb", "Use")), item.display_name()]
	use_button.disabled = not can_use
	var item_text: String = BattleText.item_description(item.item_id)
	use_button.tooltip_text = item_text if can_use else "This item has no use action; it can be thrown\n%s" % item_text
	var options: Array[Dictionary] = Targeting.throw_options(p, 8, _units_for(p), Targeting.arena_tile_keys(_level_for(p)))
	throw_button.text = "Throw %s" % item.display_name()
	throw_button.disabled = options.is_empty()
	throw_button.tooltip_text = item_text if not options.is_empty() else "No open tile to throw toward\n%s" % item_text
	_focus_picker_if_idle(picker)


func _units_for(p: TacticsPawn) -> Array[TacticsPawn]:
	var out: Array[TacticsPawn] = []
	var level: TacticsLevel = _level_for(p)
	if level == null:
		return out
	for node in [level.player, level.opponent]:
		if node == null:
			continue
		for child in node.get_children():
			if child is TacticsPawn:
				out.append(child)
	return out


func _level_for(p: TacticsPawn) -> TacticsLevel:
	var node: Node = p
	while node != null:
		if node is TacticsLevel:
			return node as TacticsLevel
		node = node.get_parent()
	return null


func _item_picker(ctrl: TacticsControls) -> VBoxContainer:
	var node: Node = ctrl.get_node_or_null("HBox/ItemPicker")
	if node == null:
		node = ctrl.find_child("ItemPicker", true, false)
	return node as VBoxContainer


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


func set_actions_menu_visibility(v: bool, p: TacticsPawn, ctrl: TacticsControls) -> void:
	if controls != null and controls.remote_turn:
		v = false
	var picker: VBoxContainer = ensure_move_picker(ctrl)
	if v and picker != null:
		picker.visible = false
	var item_picker: VBoxContainer = ensure_item_picker(ctrl)
	if v and item_picker != null:
		item_picker.visible = false
	var travel_picker: VBoxContainer = _travel_picker(ctrl)
	if v and travel_picker != null:
		travel_picker.visible = false
	var actions: VBoxContainer = _actions_container(ctrl)
	if actions == null:
		return
	for child in actions.get_children():
		if child is Button and (child as Button).text in ["Wait", "End Turn"]:
			child.add_to_group(UiSoundHook.OPT_OUT_GROUP)
	if not p:
		actions.visible = false
		return
	actions.visible = v and p.can_act()
	_show_only_cancel_while_choosing(ctrl, actions)
	_sync_menu_focus(ctrl, actions)

	var action_move: Button = actions.get_node_or_null("Move") as Button
	var action_attack: Button = actions.get_node_or_null("Attack") as Button
	if action_move != null:
		if controls != null:
			_replace_signal_connections(action_move.mouse_entered, _on_move_action_mouse_entered.bind(ctrl))
			_replace_signal_connections(action_move.mouse_exited, _on_move_action_mouse_exited.bind(ctrl))
		action_move.disabled = not p.res.can_move
	var charging_move: String = _charging_move_id(p)
	var has_usable_move: bool = p.stats.move_slots.is_empty() or p.stats.first_usable_move_index(false) >= 0 or not charging_move.is_empty()
	if action_attack != null:
		action_attack.disabled = not p.res.can_attack or not has_usable_move
	var action_item: Button = ensure_item_action_button(ctrl)
	if action_item != null:
		var held: PokemonItemResource = PokemonItemService.held_item_for(p.stats) if p.stats != null else null
		action_item.disabled = held == null or not p.res.can_attack or not charging_move.is_empty()
		action_item.text = "Item" if held == null else "Item: %s" % held.display_name()


func _charging_move_id(p: TacticsPawn) -> String:
	if p == null or p.stats == null:
		return ""
	var payload: Variant = p.stats.battle_statuses.get("charging", null)
	return String((payload as Dictionary).get("move_id", "")) if payload is Dictionary else ""


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
	if controls != null and controls.remote_turn:
		v = false
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
		var charging_move: String = _charging_move_id(p)
		if not charging_move.is_empty() and move.move_id != charging_move:
			button.text = "%s\n%s %s  PP %d/%d" % [move.display_name(), move.type.capitalize(), _category_label(move), pp, move.pp]
			button.disabled = true
			button.tooltip_text = "Charging %s\n%s" % [BattleMessageCatalog.move_label(charging_move), BattleText.move_summary(move)]
			continue
		button.text = "%s\n%s %s  PP %d/%d" % [
			move.display_name(),
			move.type.capitalize(),
			_category_label(move),
			pp,
			move.pp,
		]
		button.disabled = not has_pp or not has_target
		var reason: String = "No PP" if not has_pp else ("No legal target" if not has_target else "")
		var summary: String = BattleText.move_summary(move)
		button.tooltip_text = summary if reason.is_empty() else "%s\n%s" % [reason, summary]
	_focus_picker_if_idle(picker)


func set_travel_picker_visibility(v: bool, ctrl: TacticsControls, pending: Dictionary) -> void:
	if controls != null and controls.remote_turn:
		v = false
	var picker: VBoxContainer = _travel_picker(ctrl)
	if picker == null:
		return
	picker.visible = v and not pending.is_empty()
	if not picker.visible:
		picker.set_meta("serial", -1)
		return
	var serial: int = int(pending.get("serial", 0))
	if int(picker.get_meta("serial", -1)) == serial:
		return
	picker.set_meta("serial", serial)
	var options: Array = pending.get("options", [])
	var move_id: String = String(pending.get("move_id", ""))
	var title: Label = picker.get_node("Title") as Label
	title.text = "%s: choose a %s" % [BattleMessageCatalog.move_label(move_id), "moment" if String(MultiverseController.TRAVEL_MOVES.get(move_id, {}).get("axis", "")) == "time" else "dimension"]
	for child in picker.get_children():
		if child.name.begins_with("Option"):
			child.queue_free()
	var cancel_button: Button = picker.get_node("Cancel") as Button
	for i in range(options.size()):
		var option: Dictionary = options[i]
		var button := Button.new()
		button.name = "Option%d" % i
		button.custom_minimum_size = Vector2(240, 48)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.text = String(option.get("label", ""))
		var board: Variant = option.get("board", null)
		if board is BoardSnapshot:
			button.tooltip_text = "Player %d standing, enemy %d standing" % [(board as BoardSnapshot).standing(0), (board as BoardSnapshot).standing(1)]
		button.pressed.connect(ctrl._player_wants_to_travel.bind(i))
		button.focus_entered.connect(ctrl._player_previews_travel.bind(i))
		button.mouse_entered.connect(ctrl._player_previews_travel.bind(i))
		picker.add_child(button)
		picker.move_child(button, picker.get_child_count() - 2)
	_replace_signal_connections(cancel_button.pressed, ctrl._player_wants_to_cancel_travel)
	_focus_picker_if_idle(picker)


func _travel_picker(ctrl: TacticsControls) -> VBoxContainer:
	if ctrl == null:
		return null
	var existing: Node = ctrl.get_node_or_null("HBox/TravelPicker")
	if existing is VBoxContainer:
		return existing
	var hbox: HBoxContainer = ctrl.get_node_or_null("HBox") as HBoxContainer
	if hbox == null:
		return null
	var picker := VBoxContainer.new()
	picker.name = "TravelPicker"
	picker.visible = false
	picker.mouse_filter = Control.MOUSE_FILTER_STOP
	picker.alignment = BoxContainer.ALIGNMENT_END
	var title := Label.new()
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	picker.add_child(title)
	var cancel_button := Button.new()
	cancel_button.name = "Cancel"
	cancel_button.text = "Stay"
	cancel_button.custom_minimum_size = Vector2(240, 48)
	picker.add_child(cancel_button)
	hbox.add_child(picker)
	return picker


func _show_only_cancel_while_choosing(ctrl: TacticsControls, actions: VBoxContainer) -> void:
	if ctrl == null or ctrl.serv == null or ctrl.serv.participant == null:
		return
	var stage: int = ctrl.serv.participant.stage
	var choosing: bool = stage in [TacticsParticipantResource.STAGE_SHOW_MOVEMENTS, TacticsParticipantResource.STAGE_SELECT_LOCATION, TacticsParticipantResource.STAGE_DISPLAY_TARGETS, TacticsParticipantResource.STAGE_SELECT_ATTACK_TARGET, TacticsParticipantResource.STAGE_SELECT_THROW_TARGET]
	for child in actions.get_children():
		if child is Button:
			(child as Button).visible = not choosing or child.name == "Cancel"
	var cancel: Button = actions.get_node_or_null("Cancel") as Button
	if cancel != null:
		var pawn: TacticsPawn = ctrl.serv.participant.curr_pawn
		var fresh: bool = stage == TacticsParticipantResource.STAGE_SHOW_ACTIONS and pawn != null and pawn.res != null and pawn.res.can_move and pawn.res.can_attack
		cancel.text = "Menu" if fresh else "Cancel"


func _sync_menu_focus(ctrl: TacticsControls, actions: VBoxContainer) -> void:
	if ctrl == null or not ctrl.is_inside_tree() or ctrl.serv == null or ctrl.serv.participant == null:
		return
	var stage: int = ctrl.serv.participant.stage
	var viewport: Viewport = ctrl.get_viewport()
	if viewport == null:
		return
	var owner: Control = viewport.gui_get_focus_owner()
	var owner_in_menu: bool = owner != null and actions.is_ancestor_of(owner)
	if actions.visible and stage == TacticsParticipantResource.STAGE_SHOW_ACTIONS:
		if not owner_in_menu:
			var first: Control = _first_enabled_child(actions)
			if first != null and first.is_inside_tree():
				first.grab_focus()
	elif owner_in_menu and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		owner.release_focus()


func _focus_picker_if_idle(picker: Control) -> void:
	if picker == null or not picker.is_inside_tree():
		return
	var owner: Control = picker.get_viewport().gui_get_focus_owner()
	if owner != null and picker.is_ancestor_of(owner) and owner.visible and not (owner is Button and (owner as Button).disabled):
		return
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
