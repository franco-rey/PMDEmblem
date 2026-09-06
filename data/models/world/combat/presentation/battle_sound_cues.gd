class_name BattleSoundCues
extends Node

const STAT_IDS: Array[String] = ["attack", "defense", "special_attack", "special_defense", "speed", "accuracy", "evasion"]

var level: TacticsLevel = null
var cues_sent: int = 0


func setup(battle_level: TacticsLevel) -> void:
	level = battle_level
	if level != null and level.battle_log != null and not level.battle_log.event_appended.is_connected(_on_event):
		level.battle_log.event_appended.connect(_on_event)


func _on_event(event: Dictionary) -> void:
	var kind: String = String(event.get("kind", ""))
	match kind:
		"damage_dealt":
			var multiplier: float = float(event.get("multiplier", 1.0))
			if multiplier <= 0.0:
				_cue("battle.hit_immune", kind)
			elif multiplier > 1.0:
				_cue("battle.hit_super", kind)
			elif multiplier < 1.0:
				_cue("battle.hit_nve", kind)
			elif int(event.get("amount", 0)) > 0:
				_cue("battle.hit_neutral", kind)
		"miss":
			_cue("battle.miss", kind)
		"damage_prevented":
			var source: String = String(event.get("source", ""))
			if source == "type":
				_cue("battle.hit_immune", kind)
			elif source == "status":
				_cue("battle.protect", kind)
		"healed", "status_healed":
			if int(event.get("amount", 0)) > 0:
				_cue("battle.heal", kind)
		"unit_fainted", "self_faint":
			var fainted: TacticsPawn = event.get("unit", null) as TacticsPawn
			var cry: String = _cry_name(fainted)
			if cry.is_empty():
				_cue("battle.faint", kind)
			else:
				_sound(cry, kind)
		"turn_started":
			var active: BattleUnit = level.scheduler.get_active_unit() if level.scheduler != null else null
			var pawn: TacticsPawn = active.pawn if active != null else null
			if pawn != null and _player_controlled(pawn):
				var turn_cry: String = _cry_name(pawn)
				if turn_cry.is_empty():
					_cue("battle.unit_selected", kind)
				else:
					_sound(turn_cry, kind)
		"status_tick":
			if int(event.get("amount", 0)) > 0:
				_sound(SoundCues.resolve("battle.status_tick"), kind, -8.0)
		"move_rejected", "item_action_rejected":
			var actor: TacticsPawn = event.get("attacker", event.get("unit", null)) as TacticsPawn
			if actor != null and _player_controlled(actor):
				SoundPlayer.cue("ui.error")
		"stat_stage_changed":
			var stat: String = String(event.get("stat", ""))
			var delta: int = int(event.get("delta", 0))
			if delta == 0:
				return
			var direction: String = "up" if delta > 0 else "down"
			var specific: String = "battle.stat_%s_%s" % [direction, stat]
			if STAT_IDS.has(stat) and not SoundCues.resolve(specific).is_empty():
				_cue(specific, kind)
			else:
				_cue("battle.stat_%s" % direction, kind)
		"status_applied":
			var status_id: String = String(event.get("status_id", ""))
			var cue_id: String = "status.%s" % status_id
			if not SoundCues.resolve(cue_id).is_empty():
				_cue(cue_id, kind)
			else:
				_sound(SoundLibrary.status_sound(status_id), kind)
		"travel":
			_cue("battle.time_travel", kind)
		"board_switched":
			if String(event.get("reason", "")) != "travel":
				_cue("battle.board_switch", kind)
		"weather_started":
			var condition_id: String = String(event.get("condition_id", ""))
			var weather_cue: String = "weather.%s" % condition_id
			if not SoundCues.resolve(weather_cue).is_empty():
				_cue(weather_cue, kind)
			else:
				_sound(SoundLibrary.map_status_sound(condition_id), kind)


func _cue(cue_id: String, label: String) -> void:
	_sound(SoundCues.resolve(cue_id), label)


func _sound(sound_name: String, label: String, volume_db: float = 0.0) -> void:
	if sound_name.is_empty() or level == null or level.presentation_runner == null:
		return
	cues_sent += 1
	level.presentation_runner.enqueue({"kind": BattlePresentationRunner.KIND_SOUND, "sound": sound_name, "label": "event:" + label, "volume_db": volume_db})


func _cry_name(pawn: TacticsPawn) -> String:
	if pawn == null or not is_instance_valid(pawn):
		return ""
	var slug: String = PortraitLibrary.slug_for_pawn(pawn)
	return SoundLibrary.cry_name(slug) if SoundLibrary.has_cry(slug) else ""


static func _player_controlled(pawn: TacticsPawn) -> bool:
	return pawn.stats != null and pawn.stats.pokemon_instance != null and pawn.stats.pokemon_instance.control_type == PokemonInstanceResource.ControlType.PLAYER
