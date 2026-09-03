class_name BattleMessageCatalog
extends RefCounted

const STAT_LABELS: Dictionary = {
	"attack": "Attack", "defense": "Defense", "special_attack": "Sp. Atk", "special_defense": "Sp. Def",
	"speed": "Speed", "accuracy": "accuracy", "evasion": "evasiveness", "hp": "HP",
}
const STATUS_APPLIED: Dictionary = {
	"leech_seed": "%s was seeded!", "burn": "%s was burned!", "poison": "%s was poisoned!", "poison_toxic": "%s was badly poisoned!", "toxic": "%s was badly poisoned!",
	"paralyze": "%s is paralyzed! It may be unable to move!", "sleep": "%s fell asleep!", "freeze": "%s was frozen solid!", "confusion": "%s became confused!",
	"protect": "%s protected itself!", "fire_spin": "%s became trapped in the fiery vortex!", "wrap": "%s was wrapped!", "bind": "%s was squeezed!", "clamp": "%s was clamped!", "sand_tomb": "%s became trapped by Sand Tomb!", "whirlpool": "%s became trapped in the vortex!", "magma_storm": "%s became trapped by swirling magma!", "infestation": "%s has been afflicted with an infestation!",
	"flinch": "%s flinched!", "reflect": "Reflect raised %s's team's Defense!", "light_screen": "Light Screen raised %s's team's Sp. Def!",
	"safeguard": "%s's team is protected by Safeguard!", "mist": "%s's team became shrouded in mist!", "ingrain": "%s planted its roots!", "aqua_ring": "%s surrounded itself with a veil of water!",
	"petal_dance": "", "thrash": "", "outrage": "", "rollout": "", "ice_ball": "", "uproar": "", "bide": "", "charging": "", "recharge": "", "rampage": "", "encore": "%s received an encore!", "taunted": "%s fell for the taunt!",
}
const STATUS_TICK: Dictionary = {
	"leech_seed": "%s's health is sapped by Leech Seed!", "burn": "%s is hurt by its burn!", "poison": "%s is hurt by poison!", "poison_toxic": "%s is hurt by poison!", "toxic": "%s is hurt by poison!",
	"fire_spin": "%s is hurt by Fire Spin!", "wrap": "%s is hurt by Wrap!", "bind": "%s is hurt by Bind!", "clamp": "%s is hurt by Clamp!", "sand_tomb": "%s is hurt by Sand Tomb!", "whirlpool": "%s is hurt by Whirlpool!", "magma_storm": "%s is hurt by Magma Storm!", "infestation": "%s is hurt by Infestation!", "ingrain": "%s absorbed nutrients with its roots!", "aqua_ring": "Aqua Ring restored %s's HP!",
	"spikes": "%s is hurt by the spikes!", "stealth_rock": "Pointed stones dug into %s!", "nightmare": "%s is locked in a nightmare!", "powder": "The powder exploded on %s!", "perish_song": "%s's perish count fell!", "wish": "%s's wish came true!", "future_sight": "%s took the Future Sight attack!",
}
const STATUS_REMOVED: Dictionary = {
	"leech_seed": "%s is no longer seeded!", "burn": "%s's burn was healed!", "poison": "%s was cured of its poisoning!", "poison_toxic": "%s was cured of its poisoning!", "toxic": "%s was cured of its poisoning!",
	"paralyze": "%s was cured of paralysis!", "sleep": "%s woke up!", "freeze": "%s thawed out!", "confusion": "%s snapped out of its confusion!",
	"protect": "", "fire_spin": "%s was freed from Fire Spin!", "flinch": "", "wrap": "%s was freed from Wrap!", "bind": "%s was freed from Bind!", "clamp": "%s was freed from Clamp!", "sand_tomb": "%s was freed from Sand Tomb!", "whirlpool": "%s was freed from Whirlpool!", "magma_storm": "%s was freed from Magma Storm!", "infestation": "%s was freed from Infestation!",
}
const SKIP_REASONS: Dictionary = {
	"paralyze": "%s is paralyzed! It can't move!", "sleep": "%s is fast asleep.", "freeze": "%s is frozen solid!", "flinch": "%s flinched and couldn't move!", "recharge": "%s must recharge!",
}


const HAZARD_PLACED: Dictionary = {
	"spikes": "Spikes were scattered in front of %s!",
	"toxic_spikes": "Poison spikes were scattered in front of %s!",
	"stealth_rock": "Pointed stones float in front of %s!",
	"sticky_web": "A sticky web was spread in front of %s!",
}
const HAZARD_TRIGGERED: Dictionary = {
	"spikes": "%s is hurt by the spikes!",
	"toxic_spikes": "%s stepped on the poison spikes!",
	"stealth_rock": "Pointed stones dug into %s!",
	"sticky_web": "%s was caught in a sticky web!",
}


static func messages_for(event: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var kind: String = String(event.get("kind", ""))
	match kind:
		"move_used":
			out.append("%s used %s!" % [_unit_name(event.get("attacker")), _move_label(String(event.get("move_id", "")))])
		"damage_dealt":
			if bool(event.get("critical", false)):
				out.append("A critical hit!")
			var multiplier: float = float(event.get("multiplier", 1.0))
			if multiplier > 1.0:
				out.append("It's super effective!")
			elif multiplier > 0.0 and multiplier < 1.0:
				out.append("It's not very effective...")
		"damage_prevented":
			out.append("It doesn't affect %s..." % _unit_name(event.get("defender")))
		"miss":
			out.append("%s avoided the attack!" % _unit_name(event.get("defender")))
		"status_applied":
			var status_id: String = String(event.get("status_id", ""))
			var template: String = String(STATUS_APPLIED.get(status_id, "%s is affected by " + _status_label(status_id) + "!"))
			if not template.is_empty():
				out.append(template % _unit_name(event.get("unit")))
		"status_tick":
			var status_id: String = String(event.get("status_id", ""))
			var chip: String = BattleWeatherService.chip_message(status_id, _unit_name(event.get("unit")))
			if not chip.is_empty():
				out.append(chip)
			else:
				out.append(String(STATUS_TICK.get(status_id, "%s is hurt by " + _status_label(status_id) + "!")) % _unit_name(event.get("unit")))
		"status_removed":
			var status_id: String = String(event.get("status_id", ""))
			var template: String = String(STATUS_REMOVED.get(status_id, "%s's " + _status_label(status_id) + " wore off!"))
			if not template.is_empty():
				out.append(template % _unit_name(event.get("unit")))
		"status_blocked":
			var reason: String = String(event.get("reason", ""))
			var unit_name: String = _unit_name(event.get("unit"))
			var status_id: String = String(event.get("status_id", ""))
			if reason == "already_applied":
				out.append("%s is already affected by %s!" % [unit_name, _status_label(status_id)])
			elif reason == "major_status_present":
				out.append("It doesn't affect %s..." % unit_name)
			elif reason == "weather":
				out.append("%s cannot be frozen in this weather!" % unit_name if status_id == "freeze" else "It doesn't affect %s..." % unit_name)
			else:
				out.append("It doesn't affect %s..." % unit_name)
		"effect_blocked":
			out.append("It doesn't affect %s..." % _unit_name(event.get("unit", event.get("defender"))))
		"stat_stage_changed":
			out.append(_stat_change_message(event))
		"stat_stage_blocked":
			out.append("%s's %s cannot be changed!" % [_unit_name(event.get("unit")), _stat_label(String(event.get("stat", "")))])
		"healed":
			out.append("%s regained health!" % _unit_name(event.get("unit")))
		"weather_started":
			out.append(BattleWeatherService.start_message(String(event.get("condition_id", ""))))
		"weather_ended":
			out.append(BattleWeatherService.end_message(String(event.get("condition_id", ""))))
		"weather_failed":
			out.append("But it failed!")
		"unit_fainted":
			out.append("%s fainted!" % _unit_name(event.get("unit")))
		"turn_skipped":
			var reason: String = String(event.get("status_id", event.get("reason", "")))
			out.append(String(SKIP_REASONS.get(reason, "%s can't move!")) % _unit_name(event.get("unit", event.get("attacker"))))
		"intrinsic_triggered":
			var slug: String = String(event.get("intrinsic_id", event.get("intrinsic", "")))
			if not slug.is_empty() and event.has("unit") and String(event.get("hook", "")) in ["damage_endure", "knockout", "battle_start_weather"]:
				out.append("%s's %s!" % [_unit_name(event.get("unit")), slug.capitalize()])
			elif slug == "forewarn" and event.has("unit"):
				out.append("%s's Forewarn alerted it to %s!" % [_unit_name(event.get("unit")), _move_label(String(event.get("move_id", "")))])
		"type_changed":
			var names: Array = event.get("types", [])
			var labels: Array[String] = []
			for t in names:
				labels.append(String(t).capitalize())
			out.append("%s transformed into the %s type!" % [_unit_name(event.get("unit")), "/".join(labels)])
		"item_used":
			out.append("%s used the %s!" % [_unit_name(event.get("unit", event.get("attacker"))), String(event.get("item_label", event.get("item_id", "item"))).capitalize()])
		"hazard_placed":
			if int(event.get("count", 0)) > 0:
				out.append(String(HAZARD_PLACED.get(String(event.get("hazard_id", "")), "%s laid a trap!")) % _unit_name(event.get("unit")))
			else:
				out.append("But it failed!")
		"hazard_triggered":
			var hazard_id: String = String(event.get("hazard_id", ""))
			if hazard_id == "toxic_spikes" or hazard_id == "sticky_web":
				out.append(String(HAZARD_TRIGGERED.get(hazard_id, "%s stepped on a trap!")) % _unit_name(event.get("unit")))
		"hazard_absorbed":
			out.append("%s absorbed the toxic spikes!" % _unit_name(event.get("unit")))
		"hazards_cleared":
			out.append("%s blew away the traps!" % _unit_name(event.get("unit")))
	var intrinsic_id: String = String(event.get("intrinsic_id", ""))
	if not intrinsic_id.is_empty() and kind in ["status_applied", "stat_stage_changed", "healed", "damage_prevented", "status_blocked", "stat_stage_blocked", "effect_blocked", "status_removed"] and event.has("unit"):
		out.insert(0, "%s's %s!" % [_unit_name(event.get("unit")), intrinsic_id.capitalize()])
	if kind == "move_rejected" and String(event.get("reason", "")) == "damp":
		out.append("Damp prevents %s!" % _move_label(String(event.get("move_id", ""))))
	var cleaned: Array[String] = []
	for text in out:
		if not text.is_empty():
			cleaned.append(text)
	return cleaned


static func _stat_change_message(event: Dictionary) -> String:
	var unit_name: String = _unit_name(event.get("unit"))
	var stat: String = _stat_label(String(event.get("stat", "")))
	var before: int = int(event.get("before", 0))
	var after: int = int(event.get("after", 0))
	var delta: int = after - before
	if delta == 0:
		return "%s's %s won't go any %s!" % [unit_name, stat, "higher" if int(event.get("delta", 0)) > 0 else "lower"]
	var magnitude: int = absi(delta)
	if delta > 0:
		return "%s's %s %s!" % [unit_name, stat, "rose" if magnitude == 1 else ("rose sharply" if magnitude == 2 else "rose drastically")]
	return "%s's %s %s!" % [unit_name, stat, "fell" if magnitude == 1 else ("harshly fell" if magnitude == 2 else "severely fell")]


static func unit_name(value: Variant) -> String:
	return _unit_name(value)


static func move_label(move_id: String) -> String:
	return _move_label(move_id)


static func _unit_name(value: Variant) -> String:
	if value is TacticsPawn:
		var pawn: TacticsPawn = value
		if pawn.stats != null:
			if not pawn.stats.override_name.is_empty():
				return pawn.stats.override_name
			if not pawn.stats.species_name.is_empty():
				return pawn.stats.species_name
		return String(pawn.name)
	if value is Node:
		return String((value as Node).name)
	return "Pokemon"


static func _move_label(move_id: String) -> String:
	var path: String = "res://data/models/pokemon/generated/moves/%s.tres" % move_id
	if ResourceLoader.exists(path):
		var move: PokemonMoveResource = load(path) as PokemonMoveResource
		if move != null:
			return move.display_name()
	return move_id.capitalize()


static func _status_label(status_id: String) -> String:
	return status_id.replace("_", " ").capitalize()


static func _stat_label(stat: String) -> String:
	return String(STAT_LABELS.get(stat, stat.capitalize()))
