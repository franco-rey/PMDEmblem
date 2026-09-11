class_name AIProfile
extends RefCounted

enum TargetMode { NEAREST, WEAKEST, MATCHUP, SECURE_KO, EXPECTED_VALUE }
enum MoveMode { SLOT_ORDER, RAW_POWER, EXPECTED_DAMAGE }

const MIN_LEVEL: int = 1
const MAX_LEVEL: int = 5
const DEFAULT_LEVEL: int = 3

const LABELS: Array[String] = ["Wandering", "Scrappy", "Tactical", "Ruthless", "Champion"]
const RISK_WEIGHT: float = 0.40
const APPROACH_WEIGHT: float = 0.7
const COMPETENCE: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]
const FLOOR_DROP: float = 0.65
const FLOOR_NOISE: float = 90.0
const FLOOR_LAPSE: float = 0.15
const CEILING_PLIES: int = 6
const CEILING_NODES: int = 200

var level: int = DEFAULT_LEVEL
var target_mode: int = TargetMode.MATCHUP
var move_mode: int = MoveMode.EXPECTED_DAMAGE
var consider_status_moves: bool = true
var consider_setup_moves: bool = false
var consider_field_moves: bool = false
var consider_ability_items: bool = false
var use_ko_probability: bool = false
var value_weighted: bool = false
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
var risk_weight: float = 0.35
var approach_weight: float = 0.8
var competence: float = 1.0
var shortfall: float = 0.0
var wobble_width: int = 2
var plan_depth: int = 0
var node_budget: int = 0
var feature_drop: float = 0.0
var value_noise: float = 0.0
var lapse_rate: float = 0.0


static func clamp_level(value: int) -> int:
	return clampi(value, MIN_LEVEL, MAX_LEVEL)


static func label_for(value: int) -> String:
	return LABELS[clamp_level(value) - 1]


static func for_level(value: int) -> AIProfile:
	var profile := AIProfile.new()
	var n: int = clamp_level(value)
	profile.level = n
	profile.target_mode = TargetMode.EXPECTED_VALUE
	profile.move_mode = MoveMode.EXPECTED_DAMAGE
	profile.consider_status_moves = true
	profile.consider_setup_moves = true
	profile.consider_field_moves = true
	profile.consider_ability_items = true
	profile.use_ko_probability = true
	profile.value_weighted = true
	profile.avoid_hazards = true
	profile.threat_aware = true
	profile.focus_fire_staging = true
	profile.zone_control = true
	profile.retreat_when_losing = true
	profile.use_heal_items = true
	profile.use_throwables = true
	profile.full_item_use = true
	profile.shared_focus = true
	profile.turn_order_aware = true
	profile.team_assignment = true
	profile.risk_weight = RISK_WEIGHT
	profile.approach_weight = APPROACH_WEIGHT
	var competence: float = COMPETENCE[n - 1]
	var shortfall: float = sqrt(1.0 - competence)
	profile.competence = competence
	profile.shortfall = shortfall
	profile.plan_depth = int(round(float(CEILING_PLIES) * competence))
	profile.node_budget = int(round(float(CEILING_NODES) * pow(competence, 1.5)))
	profile.feature_drop = FLOOR_DROP * shortfall
	profile.value_noise = FLOOR_NOISE * shortfall
	profile.lapse_rate = FLOOR_LAPSE * shortfall
	profile.wobble_width = maxi(2, int(round(2.0 + 10.0 * shortfall)))
	return profile
