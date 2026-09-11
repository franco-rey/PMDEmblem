class_name BattleFloatingText
extends Node3D

const RISE_HEIGHT: float = 0.7
const LIFETIME: float = 1.1
const FADE_SECONDS: float = 0.4
const START_HEIGHT: float = 1.45
const CALLOUT_HEIGHT: float = 1.85
const PIXEL_SIZE: float = 0.006
const BASE_FONT_SIZE: int = PmdStyle.FONT_HERO
const BIG_FONT_SIZE: int = PmdStyle.FONT_BIG

const CALLOUT_COOLDOWN_MS: int = 1500
const STAT_SHORT: Dictionary = {"attack": "ATK", "defense": "DEF", "special_attack": "SPA", "special_defense": "SPD", "speed": "SPE", "accuracy": "ACC", "evasion": "EVA", "hp": "HP"}
const SILENT_STATUSES: Array[String] = ["charging", "recharge", "rampage", "bide", "rollout", "ice_ball", "petal_dance", "thrash", "outrage", "uproar", "airborne", "underground", "underwater", "vanished", "protect"]

var level: TacticsLevel = null
var spawned_total: int = 0
var _recent: Dictionary = {}


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
		"stat_stage_changed":
			var stat: String = String(STAT_SHORT.get(String(event.get("stat", "")), String(event.get("stat", "")).to_upper()))
			var change: int = int(event.get("after", 0)) - int(event.get("before", 0))
			if change == 0:
				_schedule(event.get("unit"), "%s %s" % [stat, "MAX" if int(event.get("delta", 0)) > 0 else "MIN"], PmdStyle.TEXT_DIM, BASE_FONT_SIZE, true)
			else:
				_schedule(event.get("unit"), "%s %s%d" % [stat, "+" if change > 0 else "", change], PmdStyle.HP_HIGH if change > 0 else PmdStyle.HP_LOW, BASE_FONT_SIZE, true)
		"status_applied":
			var status_id: String = String(event.get("status_id", ""))
			if not SILENT_STATUSES.has(status_id) and not StatusBadgeRow.HIDDEN.has(status_id):
				_schedule(event.get("unit"), BattleMessageCatalog._status_label(status_id).to_upper(), PmdStyle.TEXT_GOLD, BASE_FONT_SIZE, true)
		"intrinsic_triggered":
			var ability: String = String(event.get("intrinsic_id", ""))
			if String(event.get("hook", "")) != "battle_start" and _callout_allowed(event.get("unit"), "ability:" + ability):
				_schedule(event.get("unit"), BattleText.ability_name(ability), PmdStyle.CURSOR, BASE_FONT_SIZE, true, CALLOUT_HEIGHT)
		"held_item_triggered", "held_item_consumed":
			var item_id: String = String(event.get("item_id", ""))
			var holder: Variant = event.get("unit", event.get("target", null))
			if _callout_allowed(holder, "item:" + item_id):
				var item: PokemonItemResource = PokemonItemService.load_item(item_id)
				_schedule(holder, item.display_name() if item != null else item_id.capitalize(), PmdStyle.CURSOR, BASE_FONT_SIZE, true, CALLOUT_HEIGHT)


func _callout_allowed(target: Variant, key: String) -> bool:
	var pawn: TacticsPawn = _pawn_of(target)
	if pawn == null:
		return false
	var full_key: String = "%s|%s" % [pawn.get_instance_id(), key]
	var now: int = Time.get_ticks_msec()
	if _recent.has(full_key) and now - int(_recent[full_key]) < CALLOUT_COOLDOWN_MS:
		return false
	_recent[full_key] = now
	return true


func _schedule(target: Variant, text: String, color: Color, size: int, through_runner: bool, height: float = START_HEIGHT) -> void:
	var pawn: TacticsPawn = _pawn_of(target)
	if pawn == null:
		return
	if through_runner and level != null and level.presentation_runner != null and level.presentation_runner.is_busy() and not level.presentation_runner.immediate_mode:
		level.presentation_runner.enqueue({"kind": BattlePresentationRunner.KIND_CALLBACK, "callable": show_text.bind(pawn, text, color, size, height)})
	else:
		show_text(pawn, text, color, size, height)


func show_text(pawn: TacticsPawn, text: String, color: Color, size: int, height: float = START_HEIGHT) -> FloatingPopup:
	if pawn == null or not is_instance_valid(pawn):
		return null
	var popup := FloatingPopup.new()
	popup.name = "Popup_%d" % spawned_total
	popup.text = text
	popup.font = PmdStyle.font_body()
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
	popup.start = pawn.global_position + Vector3(jitter, height, 0.0)
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
