class_name AIProfile
extends RefCounted

enum TargetMode { NEAREST, WEAKEST, MATCHUP, SECURE_KO, EXPECTED_VALUE }
enum MoveMode { SLOT_ORDER, RAW_POWER, EXPECTED_DAMAGE }

const MIN_LEVEL: int = 1
const MAX_LEVEL: int = 5
const DEFAULT_LEVEL: int = 3

const LABELS: Array[String] = ["Wandering", "Scrappy", "Tactical", "Ruthless", "Champion"]
const RISK_WEIGHTS: Array[float] = [0.0, 0.0, 0.30, 0.40, 0.50]
const APPROACH_WEIGHTS: Array[float] = [1.0, 1.0, 0.8, 0.7, 0.6]

var level: int = DEFAULT_LEVEL
var target_mode: int = TargetMode.MATCHUP
var move_mode: int = MoveMode.EXPECTED_DAMAGE
var consider_status_moves: bool = true
var consider_setup_moves: bool = false
var consider_field_moves: bool = false
var consider_ability_items: bool = false
var avoid_hazards: bool = true
var threat_aware: bool = true
var focus_fire_staging: bool = false
var zone_control: bool = false
var retreat_when_losing: bool = false
var use_heal_items: bool = true
var use_throwables: bool = false
var full_item_use: bool = false
var shared_focus: bool = true
var turn_order_aware: bool = true
var team_assignment: bool = false
var consider_travel: bool = false
var risk_weight: float = 0.35
var approach_weight: float = 0.8


static func clamp_level(value: int) -> int:
	return clampi(value, MIN_LEVEL, MAX_LEVEL)


static func label_for(value: int) -> String:
	return LABELS[clamp_level(value) - 1]


static func for_level(value: int) -> AIProfile:
	var profile := AIProfile.new()
	var n: int = clamp_level(value)
	profile.level = n
	profile.target_mode = [
		TargetMode.NEAREST,
		TargetMode.WEAKEST,
		TargetMode.MATCHUP,
		TargetMode.SECURE_KO,
		TargetMode.EXPECTED_VALUE,
	][n - 1]
	profile.move_mode = MoveMode.SLOT_ORDER if n <= 1 else (MoveMode.RAW_POWER if n == 2 else MoveMode.EXPECTED_DAMAGE)
	profile.consider_status_moves = n >= 3
	profile.consider_setup_moves = n >= 4
	profile.consider_field_moves = n >= 4
	profile.consider_ability_items = n >= 5
	profile.avoid_hazards = n >= 2
	profile.threat_aware = n >= 3
	profile.focus_fire_staging = n >= 4
	profile.zone_control = n >= 5
	profile.retreat_when_losing = n >= 5
	profile.use_heal_items = n >= 2
	profile.use_throwables = n >= 4
	profile.full_item_use = n >= 5
	profile.shared_focus = n >= 2
	profile.turn_order_aware = n >= 3
	profile.team_assignment = n >= 4
	profile.consider_travel = n >= 5
	profile.risk_weight = RISK_WEIGHTS[n - 1]
	profile.approach_weight = APPROACH_WEIGHTS[n - 1]
	return profile
