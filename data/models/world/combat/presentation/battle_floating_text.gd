class_name BattleFloatingText
extends Node3D

const RISE_HEIGHT: float = 0.7
const LIFETIME: float = 1.1
const FADE_SECONDS: float = 0.4
const START_HEIGHT: float = 1.45
const PIXEL_SIZE: float = 0.006
const BASE_FONT_SIZE: int = 60
const BIG_FONT_SIZE: int = 76

var level: TacticsLevel = null
var spawned_total: int = 0


class FloatingPopup extends Label3D:
	var elapsed: float = 0.0
	var lifetime: float = LIFETIME
	var rise: float = RISE_HEIGHT
	var start: Vector3 = Vector3.ZERO
	var base_alpha: float = 1.0

	func _process(delta: float) -> void:
		elapsed += delta
		var t: float = clampf(elapsed / lifetime, 0.0, 1.0)
		global_position = start + Vector3.UP * (rise * (1.0 - pow(1.0 - t, 2.0)))
		var fade_start: float = lifetime - FADE_SECONDS
		var alpha: float = base_alpha if elapsed < fade_start else base_alpha * clampf((lifetime - elapsed) / FADE_SECONDS, 0.0, 1.0)
		modulate.a = alpha
		outline_modulate.a = alpha
		if elapsed >= lifetime:
			queue_free()


func setup(battle_level: TacticsLevel) -> void:
	level = battle_level
	if level != null and level.battle_log != null and not level.battle_log.event_appended.is_connected(_on_event):
		level.battle_log.event_appended.connect(_on_event)


func _on_event(event: Dictionary) -> void:
	var kind: String = String(event.get("kind", ""))
	match kind:
		"damage_dealt":
			var multiplier: float = float(event.get("multiplier", 1.0))
			var text: String = "-%d" % int(event.get("amount", 0))
			var color: Color = PmdStyle.TEXT
			var size: int = BASE_FONT_SIZE
			if multiplier > 1.0:
				text += "!"
				color = PmdStyle.HP_MID
				size = BIG_FONT_SIZE
			elif multiplier > 0.0 and multiplier < 1.0:
				color = PmdStyle.TEXT_DIM
			if bool(event.get("critical", false)):
				text = "CRIT " + text
				size = BIG_FONT_SIZE
			_schedule(event.get("defender"), text, color, size, event.has("attacker"))
		"healed":
			_schedule(event.get("unit"), "+%d" % int(event.get("amount", 0)), PmdStyle.HP_HIGH, BASE_FONT_SIZE, false)
		"miss":
			_schedule(event.get("defender"), "MISS", PmdStyle.TEXT_DIM, BASE_FONT_SIZE, true)
		"damage_prevented":
			_schedule(event.get("defender"), "NO EFFECT", PmdStyle.TEXT_DIM, BASE_FONT_SIZE, true)
		"status_tick":
			_schedule(event.get("unit"), "-%d" % int(event.get("amount", 0)), PmdStyle.HP_LOW, BASE_FONT_SIZE, false)


func _schedule(target: Variant, text: String, color: Color, size: int, through_runner: bool) -> void:
	var pawn: TacticsPawn = _pawn_of(target)
	if pawn == null:
		return
	if through_runner and level != null and level.presentation_runner != null and level.presentation_runner.is_busy() and not level.presentation_runner.immediate_mode:
		level.presentation_runner.enqueue({"kind": BattlePresentationRunner.KIND_CALLBACK, "callable": show_text.bind(pawn, text, color, size)})
	else:
		show_text(pawn, text, color, size)


func show_text(pawn: TacticsPawn, text: String, color: Color, size: int) -> FloatingPopup:
	if pawn == null or not is_instance_valid(pawn):
		return null
	var popup := FloatingPopup.new()
	popup.name = "Popup_%d" % spawned_total
	popup.text = text
	popup.font = PmdStyle.TEXT_FONT
	popup.font_size = size
	popup.pixel_size = PIXEL_SIZE
	popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup.no_depth_test = true
	popup.shaded = false
	popup.outline_size = 12
	popup.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	popup.modulate = color
	popup.layers = 2
	popup.render_priority = 2
	add_child(popup)
	var jitter: float = float((spawned_total % 3) - 1) * 0.12
	popup.start = pawn.global_position + Vector3(jitter, START_HEIGHT, 0.0)
	popup.global_position = popup.start
	spawned_total += 1
	if level != null and level.battle_log != null:
		level.battle_log.append({"kind": "damage_popup", "unit": pawn, "text": text})
	return popup


func _pawn_of(value: Variant) -> TacticsPawn:
	if value is TacticsPawn and is_instance_valid(value):
		return value
	if value is Stats and is_instance_valid(value):
		var parent: Node = (value as Stats).get_parent()
		if parent is TacticsPawn:
			return parent
		if level != null:
			for pawn in level.units_on_map():
				if pawn.stats == value:
					return pawn
	return null
