class_name DebugLog
extends RefCounted

static var debug_enabled: bool = true

const DEBUG_COLORS: Dictionary = {
	"magenta": "FF00FF",
	"yellow": "FFFF00",
	"green": "00FF00",
	"cyan": "00FFFF",
	"purple": "800080",
	"orange": "FFA500",
	"red": "FF0000"
}

static var debug_dict: Dictionary = {
	"participant_turn": {"tmp": null, "old": null},
	"turn_stage": {"tmp": null, "old": null},
	"pawn": {"tmp": null, "old": null},
	"cam": {"tmp": null, "old": null},
	"player_can_act": {"tmp": null, "old": null},
	"turn_skipped": {"tmp": null, "old": null},
	"nearest_target_found": {"tmp": null, "old": null},
	"nearest_target": {"tmp": null, "old": null},
	"quad_snap": {"tmp": null, "old": null},
	"cam_rotating": {"tmp": null, "old": null},
	"in_free_look": {"tmp": null, "old": null},
	"joystick_free_look": {"tmp": null, "old": null},
}


static func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled


static func debug_nospam(debug_name: String, argument: Variant) -> void:
	if not debug_enabled:
		return

	if debug_name in debug_dict:
		var _d: Dictionary = debug_dict[debug_name]

		match debug_name:
			"participant_turn":
				_d.tmp = "Player" if argument else "Opponent"
				compare_debug_values("[ --- Turn Update --- ] 👾 Switched participant: ", _d, "magenta")
			"turn_stage":
				_d.tmp = argument
				compare_debug_values("🎮 -> Turn stage: ", _d, "yellow")
			"pawn":
				_d.tmp = argument
				compare_debug_values("[ 👾 ] New pawn selected: ", _d, "green")
			"cam":
				if argument != null:
					_d.tmp = argument
					compare_debug_values("[ 📷 ] Camera focuses on: ", _d, "cyan")
			"quad_snap":
				if argument != null:
					_d.tmp =  "Enabled (TRUE)" if argument else "Disabled (FALSE)"
					compare_debug_values("[ 📷 ] Quadrant Snapping (is_snapping_to_quad) : ", _d, "cyan")
			"cam_rotating":
				if argument != null:
					_d.tmp =  "Enabled (TRUE)" if argument else "Disabled (FALSE)"
					compare_debug_values("[ 📷 ] Camera Rotating (is_rotating) : ", _d, "cyan")
			"in_free_look":
				if argument != null:
					_d.tmp =  "Enabled (TRUE)" if argument else "Disabled (FALSE)"
					compare_debug_values("[ 📷 ] Free Look (in_free_look) : ", _d, "cyan")
			"joystick_free_look":
				if argument != null:
					_d.tmp =  "Enabled (TRUE)" if argument else "Disabled (FALSE)"
					compare_debug_values("[ 🕹️ ] Joystick Free Look ", _d, "cyan")
			"player_can_act":
				_d.tmp = "-> YES" if argument else "-x NO"
				compare_debug_values("[ 👾 ] Can player act? ", _d, "purple")
			"nearest_target_found":
				_d.tmp = argument
				compare_debug_values("[ 🏒 ] Destination found: ", _d, "orange")
			"nearest_target":
				_d.tmp = argument
				compare_debug_values("[ 🏒 ] Not moving. No nearest target found for ", _d, "red")


static func compare_debug_values(message: String, dict_entry: Dictionary, warning_color: String) -> void:
	if dict_entry.old != dict_entry.tmp:
		var message_color: String = "[color=#" + DEBUG_COLORS[warning_color] + "]"
		var close_color: String = "[/color]"
		print_rich(message_color, message, "[i][u]", dict_entry.tmp, "[/u][/i]", close_color)
	if dict_entry.old == null or dict_entry.old != dict_entry.tmp:
		dict_entry.old = dict_entry.tmp
