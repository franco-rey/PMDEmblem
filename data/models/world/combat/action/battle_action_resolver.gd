class_name BattleActionResolver
extends RefCounted

const HAZARD_MOVES: Array[String] = ["spikes", "toxic_spikes", "stealth_rock", "sticky_web"]
const PROTECTION_STATUSES: Array[String] = ["protect", "detect", "kings_shield", "crafty_shield", "wide_guard", "spiky_shield", "mat_block"]
const RAMPAGE_STATUSES: Array[String] = ["outrage", "thrash", "petal_dance"]
const MINIMIZE_DOUBLE_MOVES: Array[String] = ["stomp", "body_slam", "dragon_rush", "steamroller", "heat_crash", "flying_press", "heavy_slam", "phantom_force", "shadow_force"]
const STAGE_ACCURACY_TABLE: Array[float] = [3.0 / 9.0, 3.0 / 8.0, 3.0 / 7.0, 3.0 / 6.0, 3.0 / 5.0, 3.0 / 4.0, 1.0, 4.0 / 3.0, 5.0 / 3.0, 2.0, 7.0 / 3.0, 8.0 / 3.0, 3.0]
const TRAP_STATUSES: Array[String] = ["bind", "wrap", "clamp", "fire_spin", "sand_tomb", "whirlpool", "magma_storm", "infestation"]
const TRAP_EXTEND_ITEM: String = "held_grip_claw"
const TRAP_DAMAGE_ITEM: String = "held_binding_band"

const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves"
const TYPE_CHART_PATH: String = "res://data/models/pokemon/generated/types/type_chart.tres"
const STATUS_COUNTER: String = "counter"
const STATUS_PROTECT: String = "protect"
const STATUS_BURN: String = "burn"
const STATUS_CONFUSE: String = "confuse"
const STATUS_DISABLE: String = "disable"
const STATUS_ENCORE: String = "encore"
const STATUS_HEAL_BLOCK: String = "heal_block"
const STATUS_ITEM_STICKY: String = "item_sticky"
const STATUS_TAUNTED: String = "taunted"
const STATUS_RECHARGE: String = "recharge"
const STATUS_SLEEP: String = "sleep"
const STATUS_LIGHT_SCREEN: String = "light_screen"
const STATUS_REFLECT: String = "reflect"
const STATUS_SAFEGUARD: String = "safeguard"
const STATUS_LUCKY_CHANT: String = "lucky_chant"
const STATUS_MIST: String = "mist"
const SCREEN_STATUSES: Array[String] = [STATUS_LIGHT_SCREEN, STATUS_REFLECT, STATUS_SAFEGUARD, STATUS_LUCKY_CHANT, STATUS_MIST]
const BAD_STATUS_IDS: Array[String] = [
	"blinker",
	"burn",
	"confuse",
	"cursed",
	"disable",
	"embargo",
	"encore",
	"exposed",
	"fire_spin",
	"flinch",
	"freeze",
	"heal_block",
	"immobilized",
	"in_love",
	"infestation",
	"leech_seed",
	"magma_storm",
	"nightmare",
	"paralyze",
	"paused",
	"perish_song",
	"poison",
	"poison_toxic",
	"rage_powder",
	"safeguard",
	"salt_cure",
	"sand_tomb",
	"sleep",
	"taunted",
	"telekinesis",
	"torment",
	"whirlpool",
	"yawning",
]
const MOVE_FEINT: String = "feint"
const MOVE_FALSE_SWIPE: String = "false_swipe"
const TAG_KNOCK_BACK: String = "PMDC.Dungeon.KnockBackEvent, PMDC"
const TAG_THROW_BACK: String = "PMDC.Dungeon.ThrowBackEvent, PMDC"
const TAG_SWITCHER: String = "PMDC.Dungeon.SwitcherEvent, PMDC"
const TAG_HOP: String = "PMDC.Dungeon.HopEvent, PMDC"
const TAG_WARP_ALLIES_IN: String = "PMDC.Dungeon.WarpAlliesInEvent, PMDC"
const TAG_RANDOM_WARP: String = "PMDC.Dungeon.RandomWarpEvent, PMDC"
const TAG_OHKO_DAMAGE: String = "PMDC.Dungeon.OHKODamageEvent, PMDC"
const TAG_CUT_HP_DAMAGE: String = "PMDC.Dungeon.CutHPDamageEvent, PMDC"
const TAG_MAX_HP_DAMAGE: String = "PMDC.Dungeon.MaxHPDamageEvent, PMDC"
const TAG_ENDEAVOR_DAMAGE: String = "PMDC.Dungeon.EndeavorEvent, PMDC"
const TAG_PSYWAVE_DAMAGE: String = "PMDC.Dungeon.PsywaveDamageEvent, PMDC"
const TAG_BASE_POWER_DAMAGE: String = "PMDC.Dungeon.BasePowerDamageEvent, PMDC"
const TAG_PAIN_SPLIT: String = "PMDC.Dungeon.PainSplitEvent, PMDC"
const TAG_STAT_SPLIT: String = "PMDC.Dungeon.StatSplitEvent, PMDC"
const TAG_SWAP_STATS: String = "PMDC.Dungeon.SwapStatsEvent, PMDC"
const TAG_POWER_TRICK: String = "PMDC.Dungeon.PowerTrickEvent, PMDC"
const TAG_REFLECT_STATS: String = "PMDC.Dungeon.ReflectStatsEvent, PMDC"
const TAG_MIRROR_MOVE: String = "PMDC.Dungeon.MirrorMoveEvent, PMDC"
const TAG_RANDOM_MOVE: String = "PMDC.Dungeon.RandomMoveEvent, PMDC"
const TAG_MIMIC_BATTLE: String = "PMDC.Dungeon.MimicBattleEvent, PMDC"
const TAG_SKETCH_BATTLE: String = "PMDC.Dungeon.SketchBattleEvent, PMDC"
const TAG_NATURE_MOVE: String = "PMDC.Dungeon.NatureMoveEvent, PMDC"
const TAG_COPYCAT: String = "PMDC.Dungeon.CopycatEvent, PMDC"
const TAG_SWAP_ABILITY: String = "PMDC.Dungeon.SwapAbilityEvent, PMDC"
const TAG_REFLECT_ABILITY: String = "PMDC.Dungeon.ReflectAbilityEvent, PMDC"
const TAG_CHANGE_TO_ABILITY: String = "PMDC.Dungeon.ChangeToAbilityEvent, PMDC"
const TAG_TRANSFER_STATUS: String = "PMDC.Dungeon.TransferStatusEvent, PMDC"
const TAG_STATUS_STATE: String = "PMDC.Dungeon.StatusStateBattleEvent, PMDC"
const TAG_SET_ITEM_STICKY: String = "PMDC.Dungeon.SetItemStickyEvent, PMDC"
const TAG_REST_EVENT: String = "PMDC.Dungeon.RestEvent, PMDC"
const TAG_BEG_ITEM: String = "PMDC.Dungeon.BegItemEvent, PMDC"
const TAG_BESTOW_ITEM: String = "PMDC.Dungeon.BestowItemEvent, PMDC"
const TAG_LAND_ITEM: String = "PMDC.Dungeon.LandItemEvent, PMDC"
const TAG_ITEM_RESTORE: String = "PMDC.Dungeon.ItemRestoreEvent, PMDC"
const TAG_SWITCH_HELD_ITEM: String = "PMDC.Dungeon.SwitchHeldItemEvent, PMDC"
const NATURE_POWER_DEFAULT_MOVE: String = "tri_attack"
const FORCED_MOVEMENT_TAGS: Array[String] = [
	TAG_KNOCK_BACK,
	TAG_THROW_BACK,
	TAG_SWITCHER,
	TAG_HOP,
	TAG_WARP_ALLIES_IN,
	TAG_RANDOM_WARP,
]
const DAMAGE_VARIANT_TAGS: Array[String] = [
	TAG_OHKO_DAMAGE,
	TAG_CUT_HP_DAMAGE,
	TAG_MAX_HP_DAMAGE,
	TAG_ENDEAVOR_DAMAGE,
	TAG_PSYWAVE_DAMAGE,
	TAG_BASE_POWER_DAMAGE,
]
const DAMAGE_VARIANT_HP_FRACTIONS: Dictionary = {
	"belly_drum": 2,
	"explosion": 2,
	"self_destruct": 2,
	"sonic_boom": 4,
	"super_fang": 2,
}
const STAT_HP_MANIPULATION_TAGS: Array[String] = [
	TAG_PAIN_SPLIT,
	TAG_STAT_SPLIT,
	TAG_SWAP_STATS,
	TAG_POWER_TRICK,
	TAG_REFLECT_STATS,
]
const MOVE_COPYING_TAGS: Array[String] = [
	TAG_MIRROR_MOVE,
	TAG_RANDOM_MOVE,
	TAG_MIMIC_BATTLE,
	TAG_SKETCH_BATTLE,
	TAG_NATURE_MOVE,
	TAG_COPYCAT,
]
const ABILITY_DEPENDENT_TAGS: Array[String] = [
	TAG_SWAP_ABILITY,
	TAG_REFLECT_ABILITY,
	TAG_CHANGE_TO_ABILITY,
]
const STATUS_DEPENDENT_TAGS: Array[String] = [
	TAG_TRANSFER_STATUS,
	TAG_STATUS_STATE,
	TAG_SET_ITEM_STICKY,
	TAG_REST_EVENT,
]
const ITEM_DEPENDENT_TAGS: Array[String] = [
	TAG_BEG_ITEM,
	TAG_BESTOW_ITEM,
	TAG_LAND_ITEM,
	TAG_ITEM_RESTORE,
	TAG_SWITCH_HELD_ITEM,
]
const PSYCHO_SHIFT_STATUSES: Array[String] = [
	"burn",
	"confuse",
	"freeze",
	"heal_block",
	"immobilized",
	"paralyze",
	"poison",
	"poison_toxic",
	"sleep",
	"taunted",
]
const BATON_PASS_STATUSES: Array[String] = [
	"aqua_ring",
	"confuse",
	"encore",
	"heal_block",
	"ingrain",
	"leech_seed",
	"taunted",
]
const STAT_SPLIT_STATS_BY_MOVE: Dictionary = {
	"guard_split": ["defense", "special_defense"],
	"power_split": ["attack", "special_attack"],
}
const STAGE_STATS_BY_MOVE: Dictionary = {
	"guard_swap": ["defense", "special_defense"],
	"power_swap": ["attack", "special_attack"],
	"psych_up": ["speed", "attack", "defense", "special_attack", "special_defense", "accuracy", "evasion"],
}

var damage_resolver := DamageResolver.new()
var animation_resolver := BattleAnimationResolver.new()
var intrinsic_service := BattleIntrinsicService.new()
var presentation_catalog: ActionPresentationCatalog = ActionPresentationCatalog.shared()
var item_actions: BattleItemActions = null
var _presentation_entry: Dictionary = {}
var _bound_level: TacticsLevel = null
var _detached_ops: BattleStateOps = null
var _current_move_index: int = -1
var move_specials: BattleMoveSpecials = BattleMoveSpecials.new()
var _fallback_rng := RandomNumberGenerator.new()


func _init() -> void:
	_fallback_rng.seed = 0
	item_actions = BattleItemActions.new(self)


func execute_intent(intent: BattleActionIntent, battle_level: TacticsLevel = null) -> Dictionary:
	if intent == null:
		return {"ok": false, "reason": "no_intent"}
	match intent.kind:
		BattleActionIntent.KIND_MOVE:
			var ok: bool = execute(intent.actor, intent.target, intent.slot_index, battle_level)
			return {"ok": ok, "kind": intent.kind, "slot_index": intent.slot_index}
		BattleActionIntent.KIND_USE_ITEM, BattleActionIntent.KIND_THROW_ITEM:
			_bind_presentation(battle_level)
			return item_actions.execute(intent, battle_level)
	return {"ok": false, "reason": "unsupported_intent", "kind": intent.kind}


func execute(attacker: TacticsPawn, declared_target: TacticsPawn, move_index: int, battle_level: TacticsLevel = null) -> bool:
	if attacker == null or attacker.stats == null or not attacker.is_alive():
		return false
	var move: PokemonMoveResource = _move_for(attacker, move_index)
	if move == null:
		_append(battle_level.battle_log if battle_level != null else null, {
			"kind": "no_usable_move",
			"attacker": attacker,
			"slot_index": move_index,
		})
		return false
	return _run_move(attacker, declared_target, move, move_index, battle_level)


func execute_move(attacker: TacticsPawn, declared_target: TacticsPawn, move: PokemonMoveResource, battle_level: TacticsLevel = null) -> bool:
	if attacker == null or attacker.stats == null or not attacker.is_alive() or move == null:
		return false
	return _run_move(attacker, declared_target, move, -1, battle_level)


func _run_move(attacker: TacticsPawn, declared_target: TacticsPawn, move: PokemonMoveResource, move_index: int, battle_level: TacticsLevel) -> bool:
	var battle_log: BattleLog = battle_level.battle_log if battle_level != null else null
	if declared_target == null or not declared_target.is_alive():
		_append(battle_log, {
			"kind": "move_rejected",
			"attacker": attacker,
			"move_id": move.move_id,
			"slot_index": move_index,
			"reason": "no_target",
		})
		return false

	var rng: RandomNumberGenerator = battle_level.battle_rng if battle_level != null else _fallback_rng
	_ops(battle_level, battle_log)
	if _status_blocks_move(attacker, move, move_index, rng, battle_log):
		return false
	if BattleIntrinsicService.EXPLOSION_MOVES.has(move.move_id) and intrinsic_service.field_blocks_explosions(attacker):
		_append(battle_log, {"kind": "move_rejected", "attacker": attacker, "move_id": move.move_id, "slot_index": move_index, "reason": "damp"})
		return false
	intrinsic_service.before_move_used(attacker, move, battle_log)
	if attacker.stats.battle_statuses.has("powder") and move.type == "fire":
		_ops(battle_level, battle_log).remove_status(attacker, "powder", {"source": "triggered"})
		_ops(battle_level, battle_log).damage(attacker, maxi(1, int(floor(float(attacker.stats.max_health) / 4.0))), {"kind": "status_tick", "status_id": "powder"})
		_append(battle_log, {"kind": "move_rejected", "attacker": attacker, "move_id": move.move_id, "slot_index": move_index, "reason": "powder"})
		return false
	if move.move_id == "belch" and not attacker.stats.last_consumed_item_id.begins_with("berry_"):
		_append(battle_log, {"kind": "move_rejected", "attacker": attacker, "move_id": move.move_id, "slot_index": move_index, "reason": "no_berry_eaten"})
		return false
	_current_move_index = move_index

	var targets: Array[TacticsPawn] = _expanded_targets(attacker, declared_target, move, battle_level)
	if targets.is_empty():
		_append(battle_log, {
			"kind": "move_rejected",
			"attacker": attacker,
			"move_id": move.move_id,
			"slot_index": move_index,
			"reason": "illegal_target",
		})
		return false

	if battle_level != null and BattleWeatherService.blocks_move(battle_level.effective_weather(), move):
		_append(battle_log, {"kind": "move_rejected", "attacker": attacker, "move_id": move.move_id, "slot_index": move_index, "reason": "weather"})
		return false
	if battle_level != null and targets.size() == 1 and targets[0] != attacker and battle_level.are_foes(attacker, targets[0]):
		for other in battle_level.units_on_map():
			if other != targets[0] and other != attacker and other.stats != null and other.stats.is_active() and battle_level.are_foes(attacker, other) and not battle_level.are_foes(targets[0], other) and (other.stats.battle_statuses.has("follow_me") or (other.stats.battle_statuses.has("rage_powder") and not BattleStateOps.POWDER_MOVES.has(move.move_id) and not intrinsic_service.intrinsic_slugs_for(attacker.stats).has("overcoat"))):
				_append(battle_log, {"kind": "move_redirected", "attacker": attacker, "defender": other, "move_id": move.move_id, "status_id": "follow_me" if other.stats.battle_statuses.has("follow_me") else "rage_powder"})
				targets = [other] as Array[TacticsPawn]
				declared_target = other
				break
	if battle_level != null and move.category == PokemonMoveResource.CATEGORY_STATUS and targets.size() == 1 and targets[0] == attacker:
		for other in battle_level.units_on_map():
			if other != attacker and other.stats != null and other.stats.is_active() and other.stats.battle_statuses.has("snatch") and battle_level.are_foes(attacker, other):
				_remove_status_with_log(other, "snatch", move.move_id, "snatched", battle_log)
				_append(battle_log, {"kind": "move_snatched", "attacker": attacker, "defender": other, "move_id": move.move_id})
				targets = [other] as Array[TacticsPawn]
				break
	var type_chart: TypeChartResource = battle_level.get_type_chart() if battle_level != null else _load_type_chart()
	_append(battle_log, {
		"kind": "move_used",
		"attacker": attacker,
		"move_id": move.move_id,
		"slot_index": move_index,
		"target_count": targets.size(),
	})
	_bind_presentation(battle_level)
	var chosen_state: String = animation_resolver.select_for_move(attacker, move, battle_log)
	_presentation_entry = presentation_catalog.skill(move.move_id)
	if animation_resolver.runner != null and not _presentation_entry.is_empty():
		BattleActionPresentation.enqueue_move_start(animation_resolver.runner, attacker, declared_target, targets, move, _presentation_entry, chosen_state, battle_log)
	else:
		_play_move_vfx(attacker, declared_target, move, battle_level, battle_log)

	if move_index >= 0:
		attacker.stats.consume_pp(move_index)
	attacker.stats.record_move_use(move.move_id, move_index)
	PokemonItemService.note_move_used(attacker.stats)
	if move_index >= 0:
		_append(battle_log, {
			"kind": "pp_decremented",
			"attacker": attacker,
			"move_id": move.move_id,
			"slot_index": move_index,
			"remaining": attacker.stats.current_pp[move_index] if move_index < attacker.stats.current_pp.size() else 0,
		})
	var pressure_cost: int = intrinsic_service.pressure_extra_pp_cost(targets) if move_index >= 0 else 0
	if pressure_cost > 0:
		for i in range(pressure_cost):
			attacker.stats.consume_pp(move_index)
		_append(battle_log, {
			"kind": "pp_decremented",
			"attacker": attacker,
			"move_id": move.move_id,
			"slot_index": move_index,
			"remaining": attacker.stats.current_pp[move_index] if move_index < attacker.stats.current_pp.size() else 0,
			"source": "pressure",
			"amount": pressure_cost,
		})

	if move_specials.pre_execute(self, attacker, declared_target, move, targets, battle_level, battle_log, rng):
		_after_move_statuses(attacker, move, battle_level, battle_log)
		move_specials.after_move(self, attacker, move, battle_level, battle_log)
		_finish_presentation()
		return true
	var hit_count: int = move_specials.hit_count(intrinsic_service, attacker, move, rng)
	if hit_count > 1:
		_append(battle_log, {
			"kind": "multi_hit_started",
			"attacker": attacker,
			"move_id": move.move_id,
			"hit_count": hit_count,
		})

	for hit_index in range(hit_count):
		for target in targets:
			if target == null or not target.is_alive():
				continue
			_resolve_one_target(attacker, target, move, hit_index, type_chart, rng, battle_log, battle_level)
	_after_move_statuses(attacker, move, battle_level, battle_log)
	_after_move_field(attacker, move, battle_level, battle_log)
	move_specials.after_move(self, attacker, move, battle_level, battle_log)
	PokemonItemService.after_move_used(attacker, move, battle_log)
	if move.effect_records.is_empty() and not move.unsupported_effect_tags.is_empty() and not HAZARD_MOVES.has(move.move_id):
		for unsupported_tag in move.unsupported_effect_tags:
			if _is_runtime_supported_tag(unsupported_tag):
				continue
			_append(battle_log, {
				"kind": "effect_unsupported",
				"attacker": attacker,
				"move_id": move.move_id,
				"source_event": unsupported_tag,
			})
	_finish_presentation()
	return true


func _ops(battle_level: TacticsLevel = null, battle_log: BattleLog = null) -> BattleStateOps:
	var level: TacticsLevel = battle_level if battle_level != null else _bound_level
	if level != null:
		var shared: BattleStateOps = level._ops()
		intrinsic_service.state_ops = shared
		return shared
	if _detached_ops == null:
		_detached_ops = BattleStateOps.new(null, battle_log, intrinsic_service)
	_detached_ops.battle_log = battle_log
	intrinsic_service.state_ops = _detached_ops
	return _detached_ops


func _terrain_multiplier(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, battle_level: TacticsLevel) -> float:
	if battle_level == null or move == null:
		return 1.0
	var terrain: String = battle_level.current_terrain()
	if terrain.is_empty():
		return 1.0
	var multiplier: float = 1.0
	var attacker_grounded: bool = battle_level.is_grounded(attacker)
	var target_grounded: bool = battle_level.is_grounded(target)
	match terrain:
		"grassy_terrain":
			if move.type == "grass" and attacker_grounded:
				multiplier *= 1.3
			if move.move_id in ["earthquake", "bulldoze", "magnitude"] and target_grounded:
				multiplier *= 0.5
		"electric_terrain":
			if move.type == "electric" and attacker_grounded:
				multiplier *= 1.3
		"psychic_terrain":
			if move.type == "psychic" and attacker_grounded:
				multiplier *= 1.3
		"misty_terrain":
			if move.type == "dragon" and target_grounded:
				multiplier *= 0.5
	return multiplier


func _stage_accuracy_multiplier(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource) -> float:
	if attacker == null or target == null or attacker.stats == null or target.stats == null:
		return 1.0
	var accuracy_stage: int = attacker.stats.get_stat_stage("accuracy")
	var evasion_stage: int = target.stats.get_stat_stage("evasion")
	if target.stats.battle_statuses.has("exposed") or target.stats.battle_statuses.has("miracle_eye"):
		evasion_stage = mini(evasion_stage, 0)
	var combined: int = clampi(accuracy_stage - evasion_stage, -6, 6)
	return STAGE_ACCURACY_TABLE[combined + 6]


func _lock_on_active(attacker: TacticsPawn, target: TacticsPawn) -> bool:
	if attacker == null or attacker.stats == null or not attacker.stats.battle_statuses.has("sure_shot"):
		return false
	var payload: Dictionary = _status_payload(attacker.stats, "sure_shot")
	var locked: Variant = payload.get("target_unit", null)
	return locked == null or locked == target


func _status_adjusted_effectiveness(target: TacticsPawn, move: PokemonMoveResource, effectiveness: float, type_chart: TypeChartResource) -> float:
	if target == null or target.stats == null or move == null:
		return effectiveness
	if move.type == "ground" and (target.stats.battle_statuses.has("magnet_rise") or target.stats.battle_statuses.has("telekinesis")):
		return 0.0
	if _bound_level != null and BattleWeatherService.neutralizes_flying_weakness(_bound_level.effective_weather()) and target.stats.types.has("flying") and type_chart != null and type_chart.get_effectiveness(move.type, "flying") > 1.0:
		var other_type: String = "none"
		for type_id in target.stats.types:
			if String(type_id) != "flying":
				other_type = String(type_id)
		effectiveness = type_chart.get_effectiveness_dual(move.type, other_type, "none")
	if effectiveness <= 0.0 and type_chart != null and PokemonItemService.ignores_type_immunity(target.stats):
		var type_a: String = target.stats.types[0] if target.stats.types.size() > 0 else "none"
		var type_b: String = target.stats.types[1] if target.stats.types.size() > 1 else "none"
		return type_chart.get_effectiveness_dual_ignoring_immunity(move.type, type_a, type_b)
	if effectiveness > 0.0 or type_chart == null:
		return effectiveness
	var ignored: String = ""
	if target.stats.battle_statuses.has("exposed") and (move.type == "normal" or move.type == "fighting") and target.stats.types.has("ghost"):
		ignored = "ghost"
	elif target.stats.battle_statuses.has("miracle_eye") and move.type == "psychic" and target.stats.types.has("dark"):
		ignored = "dark"
	if ignored.is_empty():
		return effectiveness
	var other: String = "none"
	for type_id in target.stats.types:
		if String(type_id) != ignored:
			other = String(type_id)
	return type_chart.get_effectiveness_dual(move.type, other, "none")


func _after_move_field(attacker: TacticsPawn, move: PokemonMoveResource, battle_level: TacticsLevel, battle_log: BattleLog) -> void:
	if attacker == null or move == null or battle_level == null:
		return
	if HAZARD_MOVES.has(move.move_id):
		battle_level.place_hazard(attacker, move.move_id)
	elif move.move_id == "rapid_spin" and attacker.stats != null and attacker.stats.is_active():
		battle_level.clear_hazards(attacker, true, move.move_id)
	elif move.move_id == "defog":
		battle_level.clear_hazards(attacker, false, move.move_id)


func _after_move_statuses(attacker: TacticsPawn, move: PokemonMoveResource, battle_level: TacticsLevel, battle_log: BattleLog) -> void:
	if attacker == null or attacker.stats == null or move == null:
		return
	var ops: BattleStateOps = _ops(battle_level, battle_log)
	if attacker.stats.battle_statuses.has("charge") and move.type == "electric":
		ops.remove_status(attacker, "charge", {"source": "consumed"})
	if attacker.stats.battle_statuses.has("electrified"):
		ops.remove_status(attacker, "electrified", {"source": "consumed"})
	if attacker.stats.battle_statuses.has("sure_shot"):
		ops.remove_status(attacker, "sure_shot", {"source": "consumed"})
	if (move.move_id == "spit_up" or move.move_id == "swallow") and attacker.stats.battle_statuses.has("stockpile"):
		var stacks: int = int(_status_payload(attacker.stats, "stockpile").get("stacks", 1))
		if move.move_id == "swallow":
			var fractions: Array[int] = [4, 2, 1]
			var divisor: int = fractions[clampi(stacks, 1, 3) - 1]
			ops.heal(attacker, maxi(1, int(floor(float(attacker.stats.max_health) / float(divisor)))), {"kind": "move", "move": move})
		ops.remove_status(attacker, "stockpile", {"source": "released", "move": move})
		ops.change_stat_stage(attacker, "defense", -stacks, {"kind": "move", "move": move, "skip_rules": true})
		ops.change_stat_stage(attacker, "special_defense", -stacks, {"kind": "move", "move": move, "skip_rules": true})
	if move.move_id == "conversion" and not attacker.stats.move_slots.is_empty() and attacker.stats.move_slots[0] != null:
		var first_type: String = attacker.stats.move_slots[0].type
		if first_type != "none":
			attacker.stats.types = [first_type] as Array[String]
			_append(battle_log, {"kind": "type_changed", "unit": attacker, "types": [first_type], "source": "move", "move_id": move.move_id})
	if move.move_id == "conversion_2" and not attacker.stats.last_hit_move_type.is_empty():
		var chart: TypeChartResource = battle_level.get_type_chart() if battle_level != null else _load_type_chart()
		for candidate in ["steel", "rock", "ghost", "fairy", "poison", "fire", "water", "grass", "electric", "ice", "fighting", "ground", "flying", "psychic", "bug", "dragon", "dark", "normal"]:
			if chart != null and chart.get_effectiveness_dual(attacker.stats.last_hit_move_type, candidate, "none") < 1.0:
				attacker.stats.types = [candidate] as Array[String]
				_append(battle_log, {"kind": "type_changed", "unit": attacker, "types": [candidate], "source": "move", "move_id": move.move_id})
				break
	if move.move_id == "roost" and attacker.stats.types.has("flying"):
		var roost_payload: Dictionary = _status_payload(attacker.stats, "roosting") if attacker.stats.battle_statuses.has("roosting") else {}
		if not roost_payload.has("original_types"):
			var remaining: Array[String] = []
			for type_id in attacker.stats.types:
				if String(type_id) != "flying":
					remaining.append(String(type_id))
			if remaining.is_empty():
				remaining.append("normal")
			roost_payload["original_types"] = attacker.stats.types.duplicate()
			if attacker.stats.battle_statuses.has("roosting"):
				attacker.stats.battle_statuses["roosting"] = roost_payload
			else:
				ops.apply_status(attacker, "roosting", roost_payload, {"kind": "move", "move": move, "skip_rules": true})
			attacker.stats.types = remaining
	if RAMPAGE_STATUSES.has(move.move_id) and attacker.stats.battle_statuses.has(move.move_id):
		var rampage: Dictionary = _status_payload(attacker.stats, move.move_id)
		if not rampage.has("locked_turns"):
			rampage["locked_turns"] = true
			rampage["counter"] = 2 + (1 if (battle_level.battle_rng if battle_level != null else _fallback_rng).randf() < 0.5 else 0)
			attacker.stats.battle_statuses[move.move_id] = rampage


func _effective_move_for_hit(attacker: TacticsPawn, move: PokemonMoveResource) -> PokemonMoveResource:
	if attacker == null or attacker.stats == null or move == null:
		return move
	var override: String = intrinsic_service.move_type_override(attacker.stats, move)
	if attacker.stats.battle_statuses.has("electrified"):
		override = "electric"
	var stacks: int = int(_status_payload(attacker.stats, "stockpile").get("stacks", 0)) if attacker.stats.battle_statuses.has("stockpile") else 0
	if (override.is_empty() or override == move.type) and not (move.move_id == "spit_up" and stacks > 0):
		return move
	var copy: PokemonMoveResource = move.duplicate()
	if not override.is_empty() and override != move.type:
		copy.type = override
		copy.set_meta("type_overridden", true)
	if move.move_id == "spit_up" and stacks > 0:
		copy.base_power = 100 * stacks
	return copy


func _bind_presentation(battle_level: TacticsLevel) -> void:
	_bound_level = battle_level
	animation_resolver.runner = battle_level.presentation_runner if battle_level != null else null
	animation_resolver.presentation_catalog = presentation_catalog
	_presentation_entry = {}


func _finish_presentation() -> void:
	if animation_resolver.runner != null and not _presentation_entry.is_empty():
		BattleActionPresentation.enqueue_move_end(animation_resolver.runner)
	_presentation_entry = {}


func _resolve_one_target(
		attacker: TacticsPawn,
		target: TacticsPawn,
		move: PokemonMoveResource,
		hit_index: int,
		type_chart: TypeChartResource,
		rng: RandomNumberGenerator,
		battle_log: BattleLog,
		battle_level: TacticsLevel = null
) -> void:
	var was_active: bool = target.stats.is_active()
	move = move_specials.prepare_weight_move(attacker, target, _effective_move_for_hit(attacker, move), intrinsic_service)
	intrinsic_service.begin_hit(attacker.stats, target.stats)
	var weather_accuracy: int = battle_level.weather_accuracy_override(move) if battle_level != null else -1
	var accuracy_multiplier: float = intrinsic_service.accuracy_multiplier(attacker, target, move, battle_level) * _stage_accuracy_multiplier(attacker, target, move) * PokemonItemService.accuracy_multiplier(attacker.stats) * PokemonItemService.target_accuracy_multiplier(target.stats) * PokemonItemService.zoom_lens_multiplier(attacker.stats, target.stats)
	var guaranteed: bool = intrinsic_service.sure_hit(attacker.stats, target.stats) or move.is_sure_hit() or target.stats.battle_statuses.has("telekinesis") or _lock_on_active(attacker, target) or (target.stats.battle_statuses.has("minimized") and MINIMIZE_DOUBLE_MOVES.has(move.move_id))
	var hit: bool = true
	var invulnerable: String = move_specials.target_invulnerable(target, move)
	if not invulnerable.is_empty():
		_append(battle_log, {"kind": "miss", "attacker": attacker, "defender": target, "move_id": move.move_id, "hit_index": hit_index, "reason": invulnerable})
		animation_resolver.select_reaction(target, move, "miss", battle_log)
		move_specials.on_miss(self, attacker, target, move, battle_level, battle_log)
		PokemonItemService.on_miss(attacker, battle_log)
		intrinsic_service.end_hit()
		return
	if guaranteed:
		hit = true
	elif weather_accuracy >= 0:
		hit = weather_accuracy >= 100 or rng.randf() * 100.0 < float(weather_accuracy) * accuracy_multiplier
	elif is_equal_approx(accuracy_multiplier, 1.0):
		hit = AccuracyResolver.roll(move, rng)
	else:
		hit = rng.randf() * 100.0 < float(move.accuracy) * accuracy_multiplier
	if not hit:
		_append(battle_log, {
			"kind": "miss",
			"attacker": attacker,
			"defender": target,
			"move_id": move.move_id,
			"hit_index": hit_index,
		})
		animation_resolver.select_reaction(target, move, "miss", battle_log)
		move_specials.on_miss(self, attacker, target, move, battle_level, battle_log)
		PokemonItemService.on_miss(attacker, battle_log)
		intrinsic_service.end_hit()
		return

	if _handle_protection(attacker, target, move, battle_log):
		intrinsic_service.end_hit()
		return

	if intrinsic_service.damage_intercepted(target, move, battle_log):
		animation_resolver.select_reaction(target, move, "miss", battle_log)
		return

	if animation_resolver.runner != null and not _presentation_entry.is_empty():
		BattleActionPresentation.enqueue_hit_fx(animation_resolver.runner, _presentation_entry, attacker, target, move.move_id)

	var effectiveness: float = _status_adjusted_effectiveness(target, move, intrinsic_service.adjust_effectiveness(attacker.stats, target.stats, move, damage_resolver._effectiveness(move, target.stats, type_chart), type_chart), type_chart)
	if target.stats.battle_statuses.has("magic_coat") and move.category == PokemonMoveResource.CATEGORY_STATUS and attacker != target:
		_remove_status_with_log(target, "magic_coat", move.move_id, "reflected", battle_log)
		_append(battle_log, {"kind": "move_reflected", "attacker": attacker, "defender": target, "move_id": move.move_id, "status_id": "magic_coat"})
		target = attacker
	elif move.category == PokemonMoveResource.CATEGORY_STATUS and attacker != target and intrinsic_service.intrinsic_slugs_for(target.stats).has("magic_bounce") and (battle_level == null or battle_level.are_foes(attacker, target)):
		_append(battle_log, {"kind": "move_reflected", "attacker": attacker, "defender": target, "move_id": move.move_id, "intrinsic_id": "magic_bounce"})
		target = attacker
	if intrinsic_service.wonder_guard_blocks(target.stats, effectiveness, move):
		_append(battle_log, {"kind": "damage_prevented", "unit": target, "defender": target, "attacker": attacker, "move_id": move.move_id, "source": "intrinsic", "intrinsic_id": "wonder_guard", "reason": "wonder_guard"})
		animation_resolver.select_reaction(target, move, "miss", battle_log)
		intrinsic_service.end_hit()
		return
	var stab: bool = type_chart.is_stab(move.type, attacker.stats.types) if type_chart != null else false
	var damage: int = 0
	var damage_outcome: Dictionary = {}
	if _should_apply_formula_damage(move):
		var screen_multiplier: float = _screen_damage_multiplier(target, move, battle_level)
		damage_outcome["screen_multiplier"] = screen_multiplier
		var weather_multiplier: float = battle_level.weather_damage_multiplier(move, target) if battle_level != null else 1.0
		damage_outcome["weather_multiplier"] = weather_multiplier
		var extra_multiplier: float = intrinsic_service.before_damage_multiplier(attacker.stats, move, battle_log, attacker, battle_level, effectiveness, target) * intrinsic_service.defender_damage_multiplier(target.stats, move, battle_log, target, effectiveness) * PokemonItemService.held_damage_multiplier(attacker.stats, move, battle_log, attacker, effectiveness) * PokemonItemService.held_defense_multiplier(target.stats, move, battle_log, target, effectiveness) * _status_damage_multiplier(attacker.stats, move) * screen_multiplier * weather_multiplier * intrinsic_service.field_damage_multiplier(attacker, target, move) * move_specials.sport_multiplier(move, battle_level) * move_specials.power_multiplier(attacker, move) * _terrain_multiplier(attacker, target, move, battle_level) * (0.25 if hit_index == 1 and intrinsic_service.intrinsic_slugs_for(attacker.stats).has("parental_bond") and move.strike_count <= 1 else 1.0)
		var critical_blocked: bool = _critical_blocked(target, battle_level) or intrinsic_service.blocks_critical(target.stats)
		damage_outcome["crit_bonus"] = intrinsic_service.crit_stage_bonus(attacker.stats) + PokemonItemService.crit_stage_bonus(attacker.stats) + (2 if attacker.stats.battle_statuses.has("focus_energy") else 0)
		if target.stats.battle_statuses.has("minimized") and MINIMIZE_DOUBLE_MOVES.has(move.move_id):
			extra_multiplier *= 2.0
		damage_outcome["ignore_defender_stages"] = intrinsic_service.ignores_stages(attacker.stats)
		damage_outcome["ignore_attacker_stages"] = intrinsic_service.ignores_stages(target.stats)
		damage = damage_resolver.calculate_damage(attacker.stats, target.stats, move, effectiveness, stab, extra_multiplier, rng, damage_outcome, critical_blocked)

	var damage_done: int = 0
	if damage > 0:
		damage_done = _apply_damage(attacker, target, move, damage, battle_log, {
			"kind": "damage_dealt",
			"hit_index": hit_index,
			"multiplier": effectiveness,
			"stab": stab,
			"critical": bool(damage_outcome.get("is_critical", false)),
			"critical_blocked": bool(damage_outcome.get("critical_blocked", false)),
			"screen_multiplier": float(damage_outcome.get("screen_multiplier", 1.0)),
			"weather_multiplier": float(damage_outcome.get("weather_multiplier", 1.0)),
			"variance": int(damage_outcome.get("variance", 100)),
		})
		if damage_done > 0:
			intrinsic_service.after_damage(attacker, target, move, damage_done, rng, battle_log, bool(damage_outcome.get("is_critical", false)))
			PokemonItemService.after_damage_dealt(attacker, move, damage_done, battle_log)

	var variant_damage_done: int = _apply_runtime_damage_variant_tags(attacker, target, move, effectiveness, battle_log)
	if variant_damage_done > 0:
		damage_done += variant_damage_done
		intrinsic_service.after_damage(attacker, target, move, variant_damage_done, rng, battle_log)
		PokemonItemService.after_damage_dealt(attacker, move, variant_damage_done, battle_log)

	for record in _records_for_runtime(move):
		_apply_effect_record(record, attacker, target, move, damage_done, rng, battle_log, battle_level)

	_apply_runtime_stat_hp_tags(attacker, target, move, battle_log)
	_apply_runtime_unsupported_tags(attacker, target, move, rng, battle_log, battle_level)
	_apply_move_id_item_effects(attacker, target, move, damage_done, battle_log)
	_apply_counter(attacker, target, move, damage_done, battle_log)

	if was_active and not target.stats.is_active():
		target.res.hurt_remaining = 0.0
		_append(battle_log, {
			"kind": "unit_fainted",
			"unit": target,
			"move_id": move.move_id,
		})
		animation_resolver.select_reaction(target, move, "faint", battle_log)
		intrinsic_service.on_knockout(attacker, target, move, battle_log)
		if attacker != target and target.stats.battle_statuses.has("destiny_bond") and attacker.stats.is_active():
			_append(battle_log, {"kind": "status_triggered", "unit": target, "status_id": "destiny_bond", "defender": attacker})
			var bond: Dictionary = _ops(battle_level, battle_log).damage(attacker, attacker.stats.curr_health, {"kind": "destiny_bond", "attacker": target, "move": move, "event": {"source": "destiny_bond"}})
			if bool(bond.get("fainted", false)):
				animation_resolver.select_reaction(attacker, move, "faint", battle_log)
		if attacker != target and target.stats.battle_statuses.has("grudge") and _current_move_index >= 0 and _current_move_index < attacker.stats.current_pp.size():
			attacker.stats.current_pp[_current_move_index] = 0
			_append(battle_log, {"kind": "status_triggered", "unit": target, "status_id": "grudge", "defender": attacker, "move_id": move.move_id})
	elif damage_done > 0 and target.stats.battle_statuses.has("enraged") and attacker != target:
		_ops(battle_level, battle_log).change_stat_stage(target, "attack", 1, {"kind": "status", "event": {"source": "enraged"}})
	if damage_done > 0:
		PokemonItemService.after_hit_taken(target, attacker, move, damage_done, effectiveness, battle_log)
		var flinch_chance: int = PokemonItemService.flinch_chance(attacker.stats, move)
		if flinch_chance > 0 and target.stats.is_active() and attacker != target and not PokemonItemService.blocks_additional_effects(target.stats) and rng.randi_range(1, 100) <= flinch_chance:
			_ops(battle_level, battle_log).apply_status(target, "flinch", {"source": "held_item"}, {"kind": "status", "attacker": attacker, "move": move, "item_id": "held_kings_rock"})
	move_specials.after_hit(self, attacker, target, move, damage_done, was_active, battle_level, battle_log)
	intrinsic_service.end_hit()


func _apply_effect_record(
		record: Dictionary,
		attacker: TacticsPawn,
		target: TacticsPawn,
		move: PokemonMoveResource,
		damage_done: int,
		rng: RandomNumberGenerator,
		battle_log: BattleLog,
		battle_level: TacticsLevel = null
) -> void:
	var family: String = String(record.get("family", ""))
	if family in ["damage", "multi_hit", "boost_critical", "block_critical"]:
		return
	if bool(record.get("require_damage", false)) and damage_done <= 0:
		return
	if family == "field_condition":
		_apply_field_condition(record, attacker, move, battle_level, battle_log)
		return
	var recipient: TacticsPawn = _recipient_for(record, attacker, target)
	if recipient == null or recipient.stats == null:
		return
	if _screen_blocks_additional_effect(recipient, record, move, battle_level, battle_log):
		return
	if intrinsic_service.blocks_additional_effect(attacker.stats, record, move, battle_log, attacker):
		return
	if recipient != attacker and intrinsic_service.shields_additional_effect(recipient.stats, record, move, battle_log, recipient):
		return
	var chance: int = mini(100, int(round(float(record.get("chance", 100)) * intrinsic_service.effect_chance_multiplier(attacker.stats))))
	if chance < 100:
		var roll: float = rng.randf() * 100.0
		if roll >= float(chance):
			_append(battle_log, {
				"kind": "effect_missed",
				"attacker": attacker,
				"defender": target,
				"move_id": move.move_id,
				"effect_family": family,
				"chance": chance,
				"roll": roll,
			})
			return
	match family:
		"status":
			var status_id: String = String(record.get("status_id", ""))
			if status_id.is_empty():
				return
			var payload: Dictionary = {"move_id": move.move_id, "source_event": record.get("source_event", ""), "source_unit": attacker}
			if status_id == "sure_shot" and target != attacker:
				payload["target_unit"] = target
			if TRAP_STATUSES.has(status_id):
				var trap_item: PokemonItemResource = PokemonItemService.held_item_for(attacker)
				payload["counter"] = 7 if trap_item != null and trap_item.item_id == TRAP_EXTEND_ITEM else 4 + (1 if rng.randf() < 0.5 else 0)
				payload["hp_fraction"] = 6 if trap_item != null and trap_item.item_id == TRAP_DAMAGE_ITEM else 8
				payload["source_unit"] = attacker
			if status_id == STATUS_DISABLE:
				payload["disabled_move_id"] = recipient.stats.last_used_move_id
				payload["disabled_slot_index"] = recipient.stats.last_used_move_index
			elif status_id == STATUS_ENCORE:
				payload["locked_move_id"] = recipient.stats.last_used_move_id
				payload["locked_slot_index"] = recipient.stats.last_used_move_index
			_ops(battle_level, battle_log).apply_status(recipient, status_id, payload, {"kind": "move", "attacker": attacker, "move": move, "source_event": String(record.get("source_event", ""))})
		"status_remove":
			var remove_id: String = String(record.get("status_id", ""))
			if remove_id.is_empty():
				return
			_ops(battle_level, battle_log).remove_status(recipient, remove_id, {"move": move})
		"stat_stage":
			_ops(battle_level, battle_log).change_stat_stage(recipient, String(record.get("stat", "")), int(record.get("delta", 0)), {"kind": "move", "attacker": attacker, "move": move})
		"weather_stat_stage":
			var weather_id: String = String(record.get("weather_id", ""))
			var weather_active: bool = battle_level != null and battle_level.has_battle_condition(weather_id)
			var delta: int = int(record.get("weather_delta", record.get("delta", 0))) if weather_active else int(record.get("delta", 0))
			_ops(battle_level, battle_log).change_stat_stage(recipient, String(record.get("stat", "")), delta, {"kind": "move", "attacker": attacker, "move": move, "event": {"condition_id": weather_id if weather_active else ""}})
		"ability_change":
			var target_ability: String = String(record.get("target_ability", ""))
			if target_ability.is_empty():
				return
			intrinsic_service.replace_intrinsic(recipient, target_ability, move, battle_log, String(record.get("source_event", "")))
		"heal":
			var amount: int = _heal_amount(record, recipient, battle_level)
			if amount <= 0:
				return
			_ops(battle_level, battle_log).heal(recipient, amount, {"kind": "move", "move": move})
		"drain":
			var drain_amount: int = int(floor(float(damage_done) * float(record.get("fraction", 0.5)) * PokemonItemService.drain_multiplier(attacker.stats)))
			if drain_amount > 0:
				if intrinsic_service.reverses_drain(target.stats):
					_ops(battle_level, battle_log).damage(attacker, drain_amount, {"kind": "intrinsic", "attacker": target, "move": move, "intrinsic_id": "liquid_ooze", "event": {"source": "liquid_ooze"}})
				else:
					_ops(battle_level, battle_log).heal(attacker, drain_amount, {"kind": "drain", "move": move, "event": {"source": "drain"}})
		"recoil":
			var recoil: int = _recoil_amount(record, attacker)
			if recoil > 0:
				if intrinsic_service.blocks_recoil(attacker.stats):
					_append(battle_log, {
						"kind": "effect_blocked",
						"unit": attacker,
						"move_id": move.move_id,
						"effect_family": "recoil",
						"intrinsic_id": "rock_head",
					})
					return
				var recoil_outcome: Dictionary = _ops(battle_level, battle_log).damage(attacker, recoil, {"kind": "recoil", "attacker": attacker, "move": move, "emit_faint": attacker != target})
				if attacker != target and bool(recoil_outcome.get("fainted", false)):
					animation_resolver.select_reaction(attacker, move, "faint", battle_log)
		"fixed_damage":
			var fixed: int = int(record.get("amount", 0))
			if fixed > 0:
				_apply_damage(attacker, recipient, move, fixed, battle_log, {
					"kind": "damage_dealt",
					"source": "fixed_damage",
				})
		"level_damage":
			var divisor: int = maxi(1, int(record.get("denominator", 1)))
			var level_damage: int = maxi(1, int(floor(float(attacker.stats.level * int(record.get("numerator", 1))) / float(divisor))))
			_apply_damage(attacker, recipient, move, level_damage, battle_log, {
				"kind": "damage_dealt",
				"source": "level_damage",
			})
		"percent_damage":
			var pct_damage: int = int(floor(float(recipient.stats.max_health) * float(record.get("percent", 0.0))))
			if pct_damage > 0:
				_apply_damage(attacker, recipient, move, pct_damage, battle_log, {
					"kind": "damage_dealt",
					"source": "percent_damage",
				})
		"cure_statuses":
			_cure_statuses(recipient, move, battle_log)
		"hp_to_1":
			var hp_delta: int = maxi(0, recipient.stats.curr_health - 1)
			if hp_delta > 0:
				_apply_damage(attacker, recipient, move, hp_delta, battle_log, {
					"kind": "damage_dealt",
					"source": "hp_to_1",
				})
		"pp_damage":
			_apply_pp_damage(recipient, move, int(record.get("amount", 0)), battle_log)
		"tactical_noop":
			_append(battle_log, {
				"kind": "effect_deferred",
				"attacker": attacker,
				"defender": target,
				"move_id": move.move_id,
				"effect_family": family,
				"source_event": record.get("source_event", ""),
			})
		_:
			_append(battle_log, {
				"kind": "effect_unsupported",
				"attacker": attacker,
				"defender": target,
				"move_id": move.move_id,
				"effect_family": family,
				"source_event": record.get("source_event", ""),
			})


func _apply_runtime_unsupported_tags(
		attacker: TacticsPawn,
		target: TacticsPawn,
		move: PokemonMoveResource,
		rng: RandomNumberGenerator,
		battle_log: BattleLog,
		battle_level: TacticsLevel = null
) -> void:
	for tag in move.unsupported_effect_tags:
		match tag:
			TAG_KNOCK_BACK, TAG_THROW_BACK:
				_push_unit(attacker, target, move, tag, battle_level, battle_log)
			TAG_SWITCHER:
				_swap_units(attacker, target, move, tag, battle_level, battle_log)
			TAG_HOP:
				_hop_unit(attacker, move, tag, battle_level, battle_log)
			TAG_RANDOM_WARP:
				_random_warp_unit(attacker, move, tag, rng, battle_level, battle_log)
			TAG_WARP_ALLIES_IN:
				_warp_allies_in(attacker, move, tag, battle_level, battle_log)
			TAG_RANDOM_MOVE:
				_use_random_copied_move(attacker, target, move, tag, rng, battle_log, battle_level)
			TAG_NATURE_MOVE:
				_use_named_copied_move(attacker, target, move, tag, NATURE_POWER_DEFAULT_MOVE, rng, battle_log, battle_level)
			TAG_MIRROR_MOVE, TAG_COPYCAT:
				_use_last_observed_move(attacker, target, move, tag, rng, battle_log, battle_level)
			TAG_MIMIC_BATTLE, TAG_SKETCH_BATTLE:
				_replace_slot_with_observed_move(attacker, target, move, tag, battle_log)
			TAG_SWAP_ABILITY:
				intrinsic_service.swap_intrinsics(attacker, target, move, battle_log, tag)
			TAG_REFLECT_ABILITY:
				_reflect_ability(attacker, target, move, tag, battle_log)
			TAG_TRANSFER_STATUS:
				_transfer_statuses(attacker, target, move, tag, battle_log, battle_level)
			TAG_STATUS_STATE:
				_apply_status_state(attacker, move, tag, battle_log)
			TAG_SET_ITEM_STICKY:
				_apply_item_sticky(target, move, tag, battle_log)
			TAG_REST_EVENT:
				_apply_rest(attacker, move, tag, battle_log)
			TAG_BEG_ITEM:
				_steal_held_item(attacker, target, move, tag, battle_log)
			TAG_BESTOW_ITEM:
				_bestow_held_item(attacker, target, move, tag, battle_log)
			TAG_LAND_ITEM:
				_land_held_item(attacker, target, move, tag, battle_log)
			TAG_ITEM_RESTORE:
				_restore_consumed_item(attacker, move, tag, battle_log)
			TAG_SWITCH_HELD_ITEM:
				PokemonItemService.swap_held_items(attacker.stats, target.stats, battle_log, tag)


func _is_runtime_supported_tag(tag: String) -> bool:
	return FORCED_MOVEMENT_TAGS.has(tag) or DAMAGE_VARIANT_TAGS.has(tag) or STAT_HP_MANIPULATION_TAGS.has(tag) or MOVE_COPYING_TAGS.has(tag) or ABILITY_DEPENDENT_TAGS.has(tag) or STATUS_DEPENDENT_TAGS.has(tag) or ITEM_DEPENDENT_TAGS.has(tag)


func _status_blocks_move(attacker: TacticsPawn, move: PokemonMoveResource, move_index: int, rng: RandomNumberGenerator, battle_log: BattleLog) -> bool:
	if attacker == null or attacker.stats == null or move == null:
		return false
	if attacker.stats.battle_statuses.has(STATUS_TAUNTED) and move.category == PokemonMoveResource.CATEGORY_STATUS:
		_log_status_move_blocked(attacker, move, STATUS_TAUNTED, "status_move_blocked", battle_log)
		return true
	if attacker.stats.battle_statuses.has(STATUS_DISABLE):
		var disable_payload: Dictionary = _status_payload(attacker.stats, STATUS_DISABLE)
		if _payload_move_matches(disable_payload, move, move_index, "disabled_move_id", "disabled_slot_index"):
			_log_status_move_blocked(attacker, move, STATUS_DISABLE, "move_disabled", battle_log)
			return true
	if attacker.stats.battle_statuses.has(STATUS_ENCORE):
		var encore_payload: Dictionary = _status_payload(attacker.stats, STATUS_ENCORE)
		var locked_move: String = String(encore_payload.get("locked_move_id", ""))
		var locked_slot: int = int(encore_payload.get("locked_slot_index", -1))
		if (not locked_move.is_empty() and move.move_id != locked_move) or (locked_move.is_empty() and locked_slot >= 0 and move_index != locked_slot):
			_log_status_move_blocked(attacker, move, STATUS_ENCORE, "encore_locked", battle_log)
			return true
	if attacker.stats.battle_statuses.has("bide") and move.move_id != "bide":
		_log_status_move_blocked(attacker, move, "bide", "biding", battle_log)
		return true
	if attacker.stats.battle_statuses.has("in_love"):
		var love_rng: RandomNumberGenerator = rng if rng != null else _fallback_rng
		if love_rng.randf() < 0.5:
			_log_status_move_blocked(attacker, move, "in_love", "infatuated", battle_log)
			return true
	if attacker.stats.battle_statuses.has("torment") and not attacker.stats.last_used_move_id.is_empty() and move.move_id == attacker.stats.last_used_move_id:
		_log_status_move_blocked(attacker, move, "torment", "torment_blocked", battle_log)
		return true
	if move_specials.charging_lock(attacker, move):
		_log_status_move_blocked(attacker, move, "charging", "charging_locked", battle_log)
		return true
	var item_block: String = PokemonItemService.blocks_move(attacker.stats, move)
	if not item_block.is_empty():
		_log_status_move_blocked(attacker, move, item_block, item_block, battle_log)
		return true
	for rampage_id in RAMPAGE_STATUSES:
		if attacker.stats.battle_statuses.has(rampage_id) and move.move_id != rampage_id:
			_log_status_move_blocked(attacker, move, rampage_id, "rampage_locked", battle_log)
			return true
	if attacker.stats.battle_statuses.has(STATUS_CONFUSE):
		var source_rng: RandomNumberGenerator = rng if rng != null else _fallback_rng
		if source_rng.randi_range(0, 1) == 0:
			_apply_confusion_self_hit(attacker, move, battle_log)
			return true
	return false


func _status_damage_multiplier(stats: Stats, move: PokemonMoveResource) -> float:
	if stats == null or move == null:
		return 1.0
	var multiplier: float = 1.0
	if stats.battle_statuses.has(STATUS_BURN) and move.category == PokemonMoveResource.CATEGORY_PHYSICAL:
		multiplier *= 2.0 / 3.0
	if stats.battle_statuses.has("charge") and move.type == "electric":
		multiplier *= 2.0
	return multiplier


func _screen_damage_multiplier(defender: TacticsPawn, move: PokemonMoveResource, battle_level: TacticsLevel) -> float:
	if defender == null or move == null:
		return 1.0
	if move.category == PokemonMoveResource.CATEGORY_PHYSICAL and _unit_has_condition(defender, STATUS_REFLECT, battle_level):
		return 0.5
	if move.category == PokemonMoveResource.CATEGORY_SPECIAL and _unit_has_condition(defender, STATUS_LIGHT_SCREEN, battle_level):
		return 0.5
	return 1.0


func _critical_blocked(defender: TacticsPawn, battle_level: TacticsLevel) -> bool:
	return _unit_has_condition(defender, STATUS_LUCKY_CHANT, battle_level)


func _screen_blocks_additional_effect(
		recipient: TacticsPawn,
		record: Dictionary,
		move: PokemonMoveResource,
		battle_level: TacticsLevel,
		battle_log: BattleLog
) -> bool:
	if not _record_is_additional_effect(record, move):
		return false
	if not _unit_has_condition(recipient, STATUS_LUCKY_CHANT, battle_level):
		return false
	_append(battle_log, {
		"kind": "effect_blocked",
		"unit": recipient,
		"move_id": move.move_id if move != null else "",
		"effect_family": String(record.get("family", "")),
		"status_id": STATUS_LUCKY_CHANT,
		"reason": "additional_effect_blocked",
	})
	return true


func _safeguard_blocks_status(
		recipient: TacticsPawn,
		status_id: String,
		battle_level: TacticsLevel,
		battle_log: BattleLog,
		move: PokemonMoveResource
) -> bool:
	if status_id == STATUS_SAFEGUARD or not BAD_STATUS_IDS.has(status_id):
		return false
	if not _unit_has_condition(recipient, STATUS_SAFEGUARD, battle_level):
		return false
	_append(battle_log, {
		"kind": "status_blocked",
		"unit": recipient,
		"move_id": move.move_id if move != null else "",
		"status_id": status_id,
		"blocked_by": STATUS_SAFEGUARD,
	})
	return true


func _mist_blocks_stat_stage(
		recipient: TacticsPawn,
		delta: int,
		battle_level: TacticsLevel,
		battle_log: BattleLog,
		move: PokemonMoveResource,
		stat_id: String
) -> bool:
	if delta >= 0 or not _unit_has_condition(recipient, STATUS_MIST, battle_level):
		return false
	_append(battle_log, {
		"kind": "stat_stage_blocked",
		"unit": recipient,
		"move_id": move.move_id if move != null else "",
		"stat": stat_id,
		"delta": delta,
		"blocked_by": STATUS_MIST,
	})
	return true


func _unit_has_condition(unit: TacticsPawn, status_id: String, battle_level: TacticsLevel) -> bool:
	if unit == null:
		return false
	if unit.stats != null and unit.stats.battle_statuses.has(status_id):
		return true
	return battle_level != null and battle_level.has_team_battle_condition(status_id, unit)


func _record_is_additional_effect(record: Dictionary, move: PokemonMoveResource) -> bool:
	if record.has("wrapped_source_event"):
		return true
	return move != null and move.is_damaging() and record.has("chance") and int(record.get("chance", 100)) < 100


func _is_screen_status(status_id: String) -> bool:
	return SCREEN_STATUSES.has(status_id)


func _healing_blocked(unit: TacticsPawn, move: PokemonMoveResource, battle_log: BattleLog) -> bool:
	if unit == null or unit.stats == null or not unit.stats.battle_statuses.has(STATUS_HEAL_BLOCK):
		return false
	_append(battle_log, {
		"kind": "heal_blocked",
		"unit": unit,
		"move_id": move.move_id if move != null else "",
		"status_id": STATUS_HEAL_BLOCK,
	})
	return true


func _status_payload(stats: Stats, status_id: String) -> Dictionary:
	if stats == null:
		return {}
	var payload: Variant = stats.battle_statuses.get(status_id, {})
	return (payload as Dictionary).duplicate(true) if payload is Dictionary else {}


func _payload_move_matches(payload: Dictionary, move: PokemonMoveResource, move_index: int, move_key: String, slot_key: String) -> bool:
	var blocked_move: String = String(payload.get(move_key, ""))
	if not blocked_move.is_empty() and move != null and move.move_id == blocked_move:
		return true
	var blocked_slot: int = int(payload.get(slot_key, -1))
	return blocked_slot >= 0 and move_index == blocked_slot


func _log_status_move_blocked(attacker: TacticsPawn, move: PokemonMoveResource, status_id: String, reason: String, battle_log: BattleLog) -> void:
	_append(battle_log, {
		"kind": "move_blocked",
		"attacker": attacker,
		"move_id": move.move_id if move != null else "",
		"status_id": status_id,
		"reason": reason,
	})


func _apply_confusion_self_hit(attacker: TacticsPawn, move: PokemonMoveResource, battle_log: BattleLog) -> void:
	if attacker == null or attacker.stats == null:
		return
	var was_active: bool = attacker.stats.is_active()
	var amount: int = maxi(1, int(floor(float(attacker.stats.max_health) / 8.0)))
	_apply_damage(attacker, attacker, move, amount, battle_log, {
		"kind": "damage_dealt",
		"source": STATUS_CONFUSE,
	})
	_log_status_move_blocked(attacker, move, STATUS_CONFUSE, "confused_self_hit", battle_log)
	if was_active and not attacker.stats.is_active():
		_append(battle_log, {
			"kind": "unit_fainted",
			"unit": attacker,
			"move_id": move.move_id,
			"source": STATUS_CONFUSE,
		})


func _apply_runtime_damage_variant_tags(
		attacker: TacticsPawn,
		target: TacticsPawn,
		move: PokemonMoveResource,
		effectiveness: float,
		battle_log: BattleLog
) -> int:
	var total: int = 0
	if BattleMoveSpecials.SELF_FAINT_MOVES.has(move.move_id):
		return 0
	for tag in move.unsupported_effect_tags:
		if not DAMAGE_VARIANT_TAGS.has(tag):
			continue
		if effectiveness <= 0.0:
			_append(battle_log, {
				"kind": "damage_prevented",
				"attacker": attacker,
				"defender": target,
				"move_id": move.move_id,
				"source": "type_immunity",
				"source_event": tag,
			})
			continue
		if tag == TAG_OHKO_DAMAGE and target.stats.level > attacker.stats.level:
			_append(battle_log, {"kind": "move_rejected", "attacker": attacker, "move_id": move.move_id, "reason": "target_level_higher"})
			continue
		if tag == TAG_OHKO_DAMAGE and intrinsic_service.intrinsic_slugs_for(target.stats).has("sturdy"):
			_append(battle_log, {"kind": "damage_prevented", "unit": target, "defender": target, "attacker": attacker, "move_id": move.move_id, "source": "intrinsic", "intrinsic_id": "sturdy", "reason": "sturdy"})
			continue
		if tag == TAG_OHKO_DAMAGE and move.move_id == "sheer_cold" and target.stats.types.has("ice"):
			_append(battle_log, {"kind": "damage_prevented", "unit": target, "defender": target, "attacker": attacker, "move_id": move.move_id, "source": "type"})
			continue
		var amount: int = _damage_variant_amount(attacker, target, move, tag)
		if amount <= 0:
			continue
		total += _apply_damage(attacker, target, move, amount, battle_log, {
			"kind": "damage_dealt",
			"source": _damage_variant_source(tag),
			"source_event": tag,
		})
	return total


func _damage_variant_amount(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, source_event: String) -> int:
	if attacker == null or attacker.stats == null or target == null or target.stats == null:
		return 0
	match source_event:
		TAG_OHKO_DAMAGE:
			return target.stats.curr_health
		TAG_CUT_HP_DAMAGE:
			var cut_fraction: int = _damage_variant_hp_fraction(move, 2)
			return maxi(1, int(floor(float(target.stats.curr_health * (cut_fraction - 1)) / float(cut_fraction))))
		TAG_MAX_HP_DAMAGE:
			if move.move_id == "sonic_boom":
				return 20
			var max_fraction: int = _damage_variant_hp_fraction(move, 2)
			return maxi(1, int(floor(float(target.stats.max_health) / float(max_fraction))))
		TAG_ENDEAVOR_DAMAGE:
			return maxi(0, target.stats.curr_health - attacker.stats.curr_health)
		TAG_PSYWAVE_DAMAGE:
			return maxi(1, int(floor(float(attacker.stats.level) * (0.5 + _fallback_rng.randf()))))
		TAG_BASE_POWER_DAMAGE:
			return maxi(0, move.base_power)
	return 0


func _damage_variant_hp_fraction(move: PokemonMoveResource, fallback: int) -> int:
	var fraction: int = int(DAMAGE_VARIANT_HP_FRACTIONS.get(move.move_id, fallback)) if move != null else fallback
	return maxi(1, fraction)


func _damage_variant_source(source_event: String) -> String:
	match source_event:
		TAG_OHKO_DAMAGE:
			return "ohko"
		TAG_CUT_HP_DAMAGE:
			return "cut_hp"
		TAG_MAX_HP_DAMAGE:
			return "max_hp"
		TAG_ENDEAVOR_DAMAGE:
			return "endeavor"
		TAG_PSYWAVE_DAMAGE:
			return "psywave"
		TAG_BASE_POWER_DAMAGE:
			return "base_power"
	return "damage_variant"


func _apply_runtime_stat_hp_tags(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, battle_log: BattleLog) -> void:
	for tag in move.unsupported_effect_tags:
		match tag:
			TAG_PAIN_SPLIT:
				_apply_pain_split(attacker, target, move, tag, battle_log)
			TAG_STAT_SPLIT:
				_apply_stat_split(attacker, target, move, tag, battle_log)
			TAG_SWAP_STATS:
				_apply_stage_swap(attacker, target, move, tag, battle_log)
			TAG_POWER_TRICK:
				_apply_power_trick(target, move, tag, battle_log)
			TAG_REFLECT_STATS:
				_apply_stage_reflect(attacker, target, move, tag, battle_log)


func _use_random_copied_move(
		attacker: TacticsPawn,
		target: TacticsPawn,
		move: PokemonMoveResource,
		source_event: String,
		rng: RandomNumberGenerator,
		battle_log: BattleLog,
		battle_level: TacticsLevel
) -> void:
	var choices: Array[PokemonMoveResource] = _generated_copyable_moves(move.move_id)
	if choices.is_empty():
		_log_move_copy_failed(attacker, target, move, source_event, battle_log, "no_copyable_moves")
		return
	var source_rng: RandomNumberGenerator = rng if rng != null else _fallback_rng
	var copied: PokemonMoveResource = choices[source_rng.randi_range(0, choices.size() - 1)]
	_resolve_copied_move(attacker, target, move, copied, source_event, rng, battle_log, battle_level)


func _use_named_copied_move(
		attacker: TacticsPawn,
		target: TacticsPawn,
		move: PokemonMoveResource,
		source_event: String,
		copied_move_id: String,
		rng: RandomNumberGenerator,
		battle_log: BattleLog,
		battle_level: TacticsLevel
) -> void:
	_resolve_copied_move(attacker, target, move, _load_generated_move(copied_move_id), source_event, rng, battle_log, battle_level)


func _use_last_observed_move(
		attacker: TacticsPawn,
		target: TacticsPawn,
		move: PokemonMoveResource,
		source_event: String,
		rng: RandomNumberGenerator,
		battle_log: BattleLog,
		battle_level: TacticsLevel
) -> void:
	var copied: PokemonMoveResource = null
	if move.move_id == "assist":
		copied = _last_ally_move(attacker, battle_level)
	else:
		copied = _last_used_move(target) if target != attacker else null
		if copied == null and battle_level != null:
			for unit in battle_level.units_on_map():
				if unit != attacker and unit.stats != null and not unit.stats.last_used_move_id.is_empty():
					copied = _load_generated_move(unit.stats.last_used_move_id)
	_resolve_copied_move(attacker, target, move, copied, source_event, rng, battle_log, battle_level)


func _replace_slot_with_observed_move(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, source_event: String, battle_log: BattleLog) -> void:
	if attacker == null or attacker.stats == null:
		return
	var copied: PokemonMoveResource = _last_used_move(target)
	if not _copyable_move(copied, move.move_id):
		_log_move_copy_failed(attacker, target, move, source_event, battle_log, "no_observed_move")
		return
	var slot_index: int = attacker.stats.last_used_move_index
	if slot_index < 0 or slot_index >= attacker.stats.move_slots.size():
		_log_move_copy_failed(attacker, target, move, source_event, battle_log, "no_move_slot")
		return
	var before_id: String = attacker.stats.move_slots[slot_index].move_id if attacker.stats.move_slots[slot_index] != null else ""
	attacker.stats.move_slots[slot_index] = copied
	if slot_index < attacker.stats.current_pp.size():
		attacker.stats.current_pp[slot_index] = copied.pp
	_append(battle_log, {
		"kind": "move_slot_replaced",
		"attacker": attacker,
		"defender": target,
		"move_id": move.move_id,
		"source_event": source_event,
		"slot_index": slot_index,
		"before_move_id": before_id,
		"copied_move_id": copied.move_id,
	})


func _resolve_copied_move(
		attacker: TacticsPawn,
		target: TacticsPawn,
		source_move: PokemonMoveResource,
		copied_move: PokemonMoveResource,
		source_event: String,
		rng: RandomNumberGenerator,
		battle_log: BattleLog,
		battle_level: TacticsLevel
) -> void:
	if not _copyable_move(copied_move, source_move.move_id):
		_log_move_copy_failed(attacker, target, source_move, source_event, battle_log, "uncopyable_move")
		return
	_append(battle_log, {
		"kind": "move_copied",
		"attacker": attacker,
		"defender": target,
		"move_id": source_move.move_id,
		"source_event": source_event,
		"copied_move_id": copied_move.move_id,
	})
	var copied_targets: Array[TacticsPawn] = _expanded_targets(attacker, target, copied_move, battle_level)
	if copied_targets.is_empty():
		copied_targets = _fallback_copied_targets(attacker, target, copied_move, battle_level)
	var type_chart: TypeChartResource = battle_level.get_type_chart() if battle_level != null else _load_type_chart()
	for copied_target in copied_targets:
		if copied_target == null or not copied_target.is_alive():
			continue
		_resolve_one_target(attacker, copied_target, copied_move, 0, type_chart, rng, battle_log, battle_level)


func _fallback_copied_targets(attacker: TacticsPawn, target: TacticsPawn, copied_move: PokemonMoveResource, battle_level: TacticsLevel) -> Array[TacticsPawn]:
	if copied_move.can_target_self():
		return [attacker]
	for unit in _all_units_for(attacker, battle_level):
		if unit != null and unit.is_alive() and Targeting.alignment_allows(attacker, unit, copied_move):
			return [unit]
	return [target]


func _last_used_move(unit: TacticsPawn) -> PokemonMoveResource:
	if unit == null or unit.stats == null:
		return null
	var move_id: String = unit.stats.last_used_move_id
	if move_id.is_empty():
		return null
	for move in unit.stats.move_slots:
		if move != null and move.move_id == move_id:
			return move
	return _load_generated_move(move_id)


func _last_ally_move(attacker: TacticsPawn, battle_level: TacticsLevel) -> PokemonMoveResource:
	if attacker == null:
		return null
	for unit in _all_units_for(attacker, battle_level):
		if unit == null or unit == attacker or unit.stats == null:
			continue
		if unit.get_parent() != attacker.get_parent():
			continue
		var move: PokemonMoveResource = _last_used_move(unit)
		if move != null:
			return move
	return null


func _generated_copyable_moves(source_move_id: String) -> Array[PokemonMoveResource]:
	var out: Array[PokemonMoveResource] = []
	var dir: DirAccess = DirAccess.open(GENERATED_MOVES_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir() or not file_name.ends_with(".tres"):
			continue
		var loaded: PokemonMoveResource = load("%s/%s" % [GENERATED_MOVES_DIR, file_name]) as PokemonMoveResource
		if _copyable_move(loaded, source_move_id):
			out.append(loaded)
	dir.list_dir_end()
	out.sort_custom(func(a: PokemonMoveResource, b: PokemonMoveResource) -> bool: return a.move_id < b.move_id)
	return out


func _load_generated_move(move_id: String) -> PokemonMoveResource:
	var key: String = move_id.strip_edges().to_lower()
	if key.is_empty():
		return null
	return load("%s/%s.tres" % [GENERATED_MOVES_DIR, key]) as PokemonMoveResource


func _copyable_move(candidate: PokemonMoveResource, source_move_id: String) -> bool:
	if candidate == null or candidate.move_id.is_empty() or candidate.move_id == source_move_id:
		return false
	if candidate.unsupported_effect_tags.is_empty():
		return candidate.is_damaging() or not candidate.effect_records.is_empty()
	for tag in candidate.unsupported_effect_tags:
		if MOVE_COPYING_TAGS.has(tag):
			return false
	return false


func _log_move_copy_failed(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, source_event: String, battle_log: BattleLog, reason: String) -> void:
	_append(battle_log, {
		"kind": "move_copy_failed",
		"attacker": attacker,
		"defender": target,
		"move_id": move.move_id if move != null else "",
		"source_event": source_event,
		"reason": reason,
	})


func _reflect_ability(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, source_event: String, battle_log: BattleLog) -> void:
	if move.move_id == "role_play":
		intrinsic_service.copy_intrinsics(target, attacker, move, battle_log, source_event)
	else:
		intrinsic_service.copy_intrinsics(attacker, target, move, battle_log, source_event)


func _transfer_statuses(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, source_event: String, battle_log: BattleLog, battle_level: TacticsLevel) -> void:
	if attacker == null or attacker.stats == null or target == null or target.stats == null:
		return
	if move.move_id == "baton_pass":
		_transfer_stat_stages(attacker, target, move, source_event, battle_log)
		_copy_status_subset(attacker, target, move, source_event, battle_log, battle_level, BATON_PASS_STATUSES, false)
	else:
		_copy_status_subset(attacker, target, move, source_event, battle_log, battle_level, PSYCHO_SHIFT_STATUSES, true)


func _transfer_stat_stages(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, source_event: String, battle_log: BattleLog) -> void:
	for stat_id in attacker.stats.stat_stages.keys():
		var stage: int = int(attacker.stats.stat_stages[stat_id])
		var change: Dictionary = target.stats.set_stat_stage(String(stat_id), stage)
		if change.is_empty():
			continue
		_append(battle_log, {
			"kind": "stat_stage_transferred",
			"attacker": attacker,
			"unit": target,
			"move_id": move.move_id,
			"source_event": source_event,
			"stat": change["stat"],
			"after": change["after"],
		})


func _copy_status_subset(
		attacker: TacticsPawn,
		target: TacticsPawn,
		move: PokemonMoveResource,
		source_event: String,
		battle_log: BattleLog,
		battle_level: TacticsLevel,
		allowed_statuses: Array[String],
		remove_from_source: bool
) -> void:
	var status_ids: Array[String] = []
	for status_id in attacker.stats.battle_statuses.keys():
		var key: String = String(status_id)
		if allowed_statuses.has(key):
			status_ids.append(key)
	for status_id in status_ids:
		if _safeguard_blocks_status(target, status_id, battle_level, battle_log, move):
			continue
		if intrinsic_service.blocks_status(target.stats, status_id, battle_log, target, move):
			continue
		var payload: Variant = attacker.stats.battle_statuses.get(status_id, {})
		var copied_payload: Dictionary = (payload as Dictionary).duplicate(true) if payload is Dictionary else {}
		copied_payload["source_event"] = source_event
		copied_payload["source_unit"] = attacker
		target.stats.apply_battle_status(status_id, copied_payload)
		if remove_from_source:
			attacker.stats.remove_battle_status(status_id)
		_append(battle_log, {
			"kind": "status_transferred",
			"attacker": attacker,
			"unit": target,
			"move_id": move.move_id,
			"source_event": source_event,
			"status_id": status_id,
			"removed_from_source": remove_from_source,
		})


func _apply_status_state(attacker: TacticsPawn, move: PokemonMoveResource, source_event: String, battle_log: BattleLog) -> void:
	if attacker == null or attacker.stats == null:
		return
	attacker.stats.apply_battle_status(STATUS_RECHARGE, {"move_id": move.move_id, "source_event": source_event})
	_append(battle_log, {
		"kind": "status_applied",
		"unit": attacker,
		"move_id": move.move_id,
		"status_id": STATUS_RECHARGE,
		"source_event": source_event,
	})


func _apply_item_sticky(target: TacticsPawn, move: PokemonMoveResource, source_event: String, battle_log: BattleLog) -> void:
	if target == null or target.stats == null:
		return
	target.stats.apply_battle_status(STATUS_ITEM_STICKY, {"move_id": move.move_id, "source_event": source_event})
	_append(battle_log, {
		"kind": "status_applied",
		"unit": target,
		"move_id": move.move_id,
		"status_id": STATUS_ITEM_STICKY,
		"source_event": source_event,
	})


func _apply_rest(attacker: TacticsPawn, move: PokemonMoveResource, source_event: String, battle_log: BattleLog) -> void:
	if attacker == null or attacker.stats == null:
		return
	var before: int = attacker.stats.curr_health
	_set_health(attacker.stats, attacker.stats.max_health)
	_append(battle_log, {
		"kind": "healed",
		"unit": attacker,
		"move_id": move.move_id,
		"amount": attacker.stats.curr_health - before,
		"before": before,
		"after": attacker.stats.curr_health,
		"source_event": source_event,
	})
	_cure_statuses(attacker, move, battle_log)
	attacker.stats.apply_battle_status(STATUS_SLEEP, {
		"move_id": move.move_id,
		"source_event": source_event,
		"source_unit": attacker,
	})
	_append(battle_log, {
		"kind": "status_applied",
		"unit": attacker,
		"move_id": move.move_id,
		"status_id": STATUS_SLEEP,
		"source_event": source_event,
	})


func _steal_held_item(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, source_event: String, battle_log: BattleLog) -> void:
	if attacker == null or attacker.stats == null or target == null or target.stats == null:
		return
	if PokemonItemService.held_item_for(attacker.stats) != null:
		_log_item_move_failed(attacker, target, move, source_event, battle_log, "attacker_already_holding")
		return
	var stolen: PokemonItemResource = PokemonItemService.take_held_item(target.stats, battle_log, source_event)
	if stolen == null:
		_log_item_move_failed(attacker, target, move, source_event, battle_log, "target_has_no_item")
		return
	PokemonItemService.give_held_item(attacker.stats, stolen, battle_log, source_event)
	_append(battle_log, {
		"kind": "held_item_stolen",
		"attacker": attacker,
		"defender": target,
		"move_id": move.move_id,
		"item_id": stolen.item_id,
		"source_event": source_event,
	})


func _bestow_held_item(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, source_event: String, battle_log: BattleLog) -> void:
	if attacker == null or attacker.stats == null or target == null or target.stats == null:
		return
	var item: PokemonItemResource = PokemonItemService.take_held_item(attacker.stats, battle_log, source_event)
	if item == null:
		_log_item_move_failed(attacker, target, move, source_event, battle_log, "attacker_has_no_item")
		return
	PokemonItemService.give_held_item(target.stats, item, battle_log, source_event)
	_append(battle_log, {
		"kind": "held_item_bestowed",
		"attacker": attacker,
		"defender": target,
		"move_id": move.move_id,
		"item_id": item.item_id,
		"source_event": source_event,
	})


func _land_held_item(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, source_event: String, battle_log: BattleLog) -> void:
	if move.move_id == "bestow" and PokemonItemService.held_item_for(attacker.stats if attacker != null else null) == null:
		_append(battle_log, {
			"kind": "held_item_landed",
			"attacker": attacker,
			"defender": target,
			"move_id": move.move_id,
			"source_event": source_event,
		})
		return
	_log_item_move_failed(attacker, target, move, source_event, battle_log, "no_landed_item")


func _restore_consumed_item(attacker: TacticsPawn, move: PokemonMoveResource, source_event: String, battle_log: BattleLog) -> void:
	if attacker == null or attacker.stats == null:
		return
	if PokemonItemService.held_item_for(attacker.stats) != null:
		_log_item_move_failed(attacker, attacker, move, source_event, battle_log, "already_holding")
		return
	var item_id: String = attacker.stats.last_consumed_item_id
	var item: PokemonItemResource = PokemonItemService.load_item(item_id)
	if item == null:
		_log_item_move_failed(attacker, attacker, move, source_event, battle_log, "no_consumed_item")
		return
	if not PokemonItemService.give_held_item(attacker.stats, item, battle_log, source_event):
		_log_item_move_failed(attacker, attacker, move, source_event, battle_log, "restore_failed")
		return
	attacker.stats.last_consumed_item_id = ""
	_append(battle_log, {
		"kind": "held_item_restored",
		"attacker": attacker,
		"move_id": move.move_id,
		"item_id": item.item_id,
		"source_event": source_event,
	})


func _apply_move_id_item_effects(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, damage_done: int, battle_log: BattleLog) -> void:
	if move == null or damage_done <= 0:
		return
	match move.move_id:
		"knock_off":
			PokemonItemService.knock_off_held_item(target.stats, battle_log, "move:%s" % move.move_id)
		"thief":
			_steal_held_item(attacker, target, move, "move:%s" % move.move_id, battle_log)


func _log_item_move_failed(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, source_event: String, battle_log: BattleLog, reason: String) -> void:
	_append(battle_log, {
		"kind": "item_move_failed",
		"attacker": attacker,
		"defender": target,
		"move_id": move.move_id if move != null else "",
		"source_event": source_event,
		"reason": reason,
	})


func _apply_pain_split(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, source_event: String, battle_log: BattleLog) -> void:
	if attacker == null or attacker.stats == null or target == null or target.stats == null:
		return
	var attacker_before: int = attacker.stats.curr_health
	var target_before: int = target.stats.curr_health
	var split_hp: int = int((attacker_before + target_before) / 2)
	_set_health(attacker.stats, mini(split_hp, attacker.stats.max_health))
	_set_health(target.stats, mini(split_hp, target.stats.max_health))
	_append(battle_log, {
		"kind": "hp_split",
		"attacker": attacker,
		"defender": target,
		"move_id": move.move_id,
		"source_event": source_event,
		"attacker_before": attacker_before,
		"attacker_after": attacker.stats.curr_health,
		"defender_before": target_before,
		"defender_after": target.stats.curr_health,
	})


func _apply_stat_split(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, source_event: String, battle_log: BattleLog) -> void:
	if attacker == null or attacker.stats == null or target == null or target.stats == null:
		return
	for stat_id in _stat_list_for(move, STAT_SPLIT_STATS_BY_MOVE):
		var split_value: int = int((attacker.stats.raw_battle_stat(stat_id) + target.stats.raw_battle_stat(stat_id)) / 2)
		_log_proxy_stat_change(attacker, move, source_event, attacker.stats.set_proxy_stat(stat_id, split_value), battle_log)
		_log_proxy_stat_change(target, move, source_event, target.stats.set_proxy_stat(stat_id, split_value), battle_log)


func _apply_power_trick(target: TacticsPawn, move: PokemonMoveResource, source_event: String, battle_log: BattleLog) -> void:
	if target == null or target.stats == null:
		return
	var attack_value: int = target.stats.raw_battle_stat("attack")
	var defense_value: int = target.stats.raw_battle_stat("defense")
	_log_proxy_stat_change(target, move, source_event, target.stats.set_proxy_stat("attack", defense_value), battle_log)
	_log_proxy_stat_change(target, move, source_event, target.stats.set_proxy_stat("defense", attack_value), battle_log)


func _apply_stage_swap(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, source_event: String, battle_log: BattleLog) -> void:
	if attacker == null or attacker.stats == null or target == null or target.stats == null:
		return
	for stat_id in _stat_list_for(move, STAGE_STATS_BY_MOVE):
		var attacker_stage: int = attacker.stats.get_stat_stage(stat_id)
		var target_stage: int = target.stats.get_stat_stage(stat_id)
		_log_stat_stage_set(attacker, move, source_event, attacker.stats.set_stat_stage(stat_id, target_stage), battle_log)
		_log_stat_stage_set(target, move, source_event, target.stats.set_stat_stage(stat_id, attacker_stage), battle_log)


func _apply_stage_reflect(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, source_event: String, battle_log: BattleLog) -> void:
	if attacker == null or attacker.stats == null or target == null or target.stats == null:
		return
	for stat_id in _stat_list_for(move, STAGE_STATS_BY_MOVE):
		_log_stat_stage_set(attacker, move, source_event, attacker.stats.set_stat_stage(stat_id, target.stats.get_stat_stage(stat_id)), battle_log)


func _stat_list_for(move: PokemonMoveResource, table: Dictionary) -> Array:
	if move != null and table.has(move.move_id):
		return table[move.move_id]
	return []


func _set_health(stats: Stats, value: int) -> void:
	stats.apply_to_curr_health(clampi(value, 0, stats.max_health) - stats.curr_health)


func _log_proxy_stat_change(unit: TacticsPawn, move: PokemonMoveResource, source_event: String, change: Dictionary, battle_log: BattleLog) -> void:
	if change.is_empty():
		return
	_append(battle_log, {
		"kind": "proxy_stat_changed",
		"unit": unit,
		"move_id": move.move_id,
		"source_event": source_event,
		"stat": change["stat"],
		"before": change["before"],
		"after": change["after"],
		"delta": change["delta"],
	})


func _log_stat_stage_set(unit: TacticsPawn, move: PokemonMoveResource, source_event: String, change: Dictionary, battle_log: BattleLog) -> void:
	if change.is_empty():
		return
	_append(battle_log, {
		"kind": "stat_stage_changed",
		"unit": unit,
		"move_id": move.move_id,
		"source_event": source_event,
		"stat": change["stat"],
		"before": change["before"],
		"after": change["after"],
		"delta": change["delta"],
	})


func _push_unit(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, source_event: String, battle_level: TacticsLevel, battle_log: BattleLog) -> void:
	if attacker == null or target == null or attacker == target or target.stats == null or not target.stats.is_active():
		return
	var direction: Vector3i = _direction_between(attacker, target)
	_move_unit_steps(target, direction, 1, move, source_event, battle_level, battle_log)


func _hop_unit(attacker: TacticsPawn, move: PokemonMoveResource, source_event: String, battle_level: TacticsLevel, battle_log: BattleLog) -> void:
	if attacker == null or attacker.stats == null or not attacker.stats.is_active():
		return
	_move_unit_steps(attacker, _facing_direction(attacker), 1, move, source_event, battle_level, battle_log)


func _swap_units(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, source_event: String, battle_level: TacticsLevel, battle_log: BattleLog) -> void:
	if attacker == null or target == null or attacker == target:
		return
	var attacker_key: Vector3i = _unit_key(attacker)
	var target_key: Vector3i = _unit_key(target)
	_set_unit_key(attacker, target_key, battle_level)
	_set_unit_key(target, attacker_key, battle_level)
	_append(battle_log, {
		"kind": "forced_movement",
		"move_id": move.move_id,
		"source_event": source_event,
		"mode": "swap",
		"unit": attacker,
		"target": target,
		"from": attacker_key,
		"to": target_key,
	})


func _random_warp_unit(attacker: TacticsPawn, move: PokemonMoveResource, source_event: String, rng: RandomNumberGenerator, battle_level: TacticsLevel, battle_log: BattleLog) -> void:
	var destination: Vector3i = _random_free_key(attacker, rng, battle_level)
	if destination == Vector3i.ZERO and _unit_key(attacker) != Vector3i.ZERO:
		_log_forced_movement_blocked(attacker, move, source_event, battle_log, "no_free_tile")
		return
	_move_unit_to_key(attacker, destination, move, source_event, battle_level, battle_log, "warp")


func _warp_allies_in(attacker: TacticsPawn, move: PokemonMoveResource, source_event: String, battle_level: TacticsLevel, battle_log: BattleLog) -> void:
	for ally in _all_units_for(attacker, battle_level):
		if ally == attacker or ally == null or ally.stats == null or not ally.stats.is_active():
			continue
		if not Targeting.alignment_allows(attacker, ally, move):
			continue
		var destination: Vector3i = _adjacent_free_key(attacker, ally, battle_level)
		if destination == Vector3i.ZERO and _unit_key(attacker) != Vector3i.ZERO:
			_log_forced_movement_blocked(ally, move, source_event, battle_log, "no_adjacent_tile")
			continue
		_move_unit_to_key(ally, destination, move, source_event, battle_level, battle_log, "warp_near")


func _move_unit_steps(unit: TacticsPawn, direction: Vector3i, distance: int, move: PokemonMoveResource, source_event: String, battle_level: TacticsLevel, battle_log: BattleLog) -> void:
	if unit == null or direction == Vector3i.ZERO:
		return
	if unit.stats != null and intrinsic_service.intrinsic_slugs_for(unit.stats).has("suction_cups") and move != null and not move.can_target_self():
		_append(battle_log, {"kind": "forced_movement_blocked", "unit": unit, "move_id": move.move_id, "reason": "suction_cups", "intrinsic_id": "suction_cups"})
		return
	var from_key: Vector3i = _unit_key(unit)
	var current: Vector3i = from_key
	var truncated: bool = false
	for _i in range(maxi(1, distance)):
		var candidate: Vector3i = current + direction
		if not _is_free_key(candidate, unit, battle_level):
			truncated = true
			break
		current = candidate
	if current == from_key:
		_log_forced_movement_blocked(unit, move, source_event, battle_log, "blocked")
		return
	_set_unit_key(unit, current, battle_level)
	_append(battle_log, {
		"kind": "forced_movement",
		"move_id": move.move_id,
		"source_event": source_event,
		"mode": "step",
		"unit": unit,
		"from": from_key,
		"to": current,
		"truncated": truncated,
	})


func _move_unit_to_key(unit: TacticsPawn, destination: Vector3i, move: PokemonMoveResource, source_event: String, battle_level: TacticsLevel, battle_log: BattleLog, mode: String) -> void:
	var from_key: Vector3i = _unit_key(unit)
	if destination == from_key:
		_log_forced_movement_blocked(unit, move, source_event, battle_log, "same_tile")
		return
	_set_unit_key(unit, destination, battle_level)
	_append(battle_log, {
		"kind": "forced_movement",
		"move_id": move.move_id,
		"source_event": source_event,
		"mode": mode,
		"unit": unit,
		"from": from_key,
		"to": destination,
	})


func _log_forced_movement_blocked(unit: TacticsPawn, move: PokemonMoveResource, source_event: String, battle_log: BattleLog, reason: String) -> void:
	_append(battle_log, {
		"kind": "forced_movement_blocked",
		"move_id": move.move_id,
		"source_event": source_event,
		"unit": unit,
		"reason": reason,
	})


func _direction_between(attacker: TacticsPawn, target: TacticsPawn) -> Vector3i:
	var from_key: Vector3i = _unit_key(attacker)
	var to_key: Vector3i = _unit_key(target)
	var dx: int = to_key.x - from_key.x
	var dz: int = to_key.z - from_key.z
	if dx == 0 and dz == 0:
		return _facing_direction(attacker) * -1
	if absi(dx) >= absi(dz):
		return Vector3i(1 if dx > 0 else -1, 0, 0)
	return Vector3i(0, 0, 1 if dz > 0 else -1)


func _facing_direction(unit: TacticsPawn) -> Vector3i:
	if unit == null:
		return Vector3i(1, 0, 0)
	var basis: Basis = unit.global_basis if unit.is_inside_tree() else unit.basis
	var forward: Vector3 = basis.z
	if absf(forward.x) > absf(forward.z):
		return Vector3i(1 if forward.x > 0.0 else -1, 0, 0)
	return Vector3i(0, 0, 1 if forward.z > 0.0 else -1)


func _unit_key(unit: TacticsPawn) -> Vector3i:
	if unit == null:
		return Vector3i.ZERO
	var tile: TacticsTile = unit.get_tile()
	var pos: Vector3 = tile.global_position if tile != null and tile.is_inside_tree() else (tile.position if tile != null else unit.global_position)
	return Vector3i(floori(pos.x + 0.5), 0, floori(pos.z + 0.5))


func _set_unit_key(unit: TacticsPawn, key: Vector3i, battle_level: TacticsLevel) -> void:
	if unit == null:
		return
	var tile: TacticsTile = _tile_for_key(key, battle_level)
	var unit_pos: Vector3 = unit.global_position if unit.is_inside_tree() else unit.position
	var destination: Vector3 = tile.global_position if tile != null and tile.is_inside_tree() else Vector3(key.x, unit_pos.y, key.z)
	if unit.is_inside_tree():
		unit.global_position = destination
	else:
		unit.position = destination
	var ray: Node = unit.get_node_or_null("Tile")
	if ray is RayCast3D and unit.is_inside_tree():
		(ray as RayCast3D).force_raycast_update()
		if unit.has_method("center"):
			unit.center()
		(ray as RayCast3D).force_raycast_update()
	var current_tile: TacticsTile = unit.get_tile()
	if current_tile != null and current_tile.get_parent() == unit:
		current_tile.position = Vector3(key.x, current_tile.position.y, key.z)
	if unit.res != null:
		unit.res.pathfinding_tilestack.clear()
		unit.res.is_moving = false


func _is_free_key(key: Vector3i, moving_unit: TacticsPawn, battle_level: TacticsLevel) -> bool:
	if _has_arena_tiles(battle_level) and _tile_for_key(key, battle_level) == null:
		return false
	for unit in _all_units_for(moving_unit, battle_level):
		if unit == moving_unit or unit == null or unit.stats == null or not unit.stats.is_active():
			continue
		if _unit_key(unit) == key:
			return false
	return true


func _random_free_key(unit: TacticsPawn, rng: RandomNumberGenerator, battle_level: TacticsLevel) -> Vector3i:
	var keys: Array[Vector3i] = _free_keys(unit, battle_level)
	if keys.is_empty():
		return Vector3i.ZERO
	var source_rng: RandomNumberGenerator = rng if rng != null else _fallback_rng
	return keys[source_rng.randi_range(0, keys.size() - 1)]


func _adjacent_free_key(anchor: TacticsPawn, moving_unit: TacticsPawn, battle_level: TacticsLevel) -> Vector3i:
	var anchor_key: Vector3i = _unit_key(anchor)
	for direction in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		var candidate: Vector3i = anchor_key + direction
		if _is_free_key(candidate, moving_unit, battle_level):
			return candidate
	return Vector3i.ZERO


func _free_keys(unit: TacticsPawn, battle_level: TacticsLevel) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if _has_arena_tiles(battle_level):
		for tile in battle_level.arena.get_node("Tiles").get_children():
			if tile is TacticsTile:
				var key: Vector3i = _tile_key(tile)
				if _is_free_key(key, unit, battle_level):
					out.append(key)
		return out
	var origin: Vector3i = _unit_key(unit)
	for x in range(origin.x - 3, origin.x + 4):
		for z in range(origin.z - 3, origin.z + 4):
			var key := Vector3i(x, 0, z)
			if _is_free_key(key, unit, battle_level):
				out.append(key)
	return out


func _has_arena_tiles(battle_level: TacticsLevel) -> bool:
	return battle_level != null and battle_level.arena != null and battle_level.arena.get_node_or_null("Tiles") != null


func _tile_for_key(key: Vector3i, battle_level: TacticsLevel) -> TacticsTile:
	if not _has_arena_tiles(battle_level):
		return null
	for tile in battle_level.arena.get_node("Tiles").get_children():
		if tile is TacticsTile and _tile_key(tile) == key:
			return tile
	return null


func _tile_key(tile: TacticsTile) -> Vector3i:
	if tile == null:
		return Vector3i.ZERO
	var pos: Vector3 = tile.global_position if tile.is_inside_tree() else tile.position
	return Vector3i(floori(pos.x + 0.5), 0, floori(pos.z + 0.5))


func _grid_distance(a: TacticsPawn, b: TacticsPawn) -> int:
	var a_key: Vector3i = _unit_key(a)
	var b_key: Vector3i = _unit_key(b)
	return maxi(absi(a_key.x - b_key.x), absi(a_key.z - b_key.z))


func _apply_field_condition(record: Dictionary, attacker: TacticsPawn, move: PokemonMoveResource, battle_level: TacticsLevel, battle_log: BattleLog) -> void:
	var condition_id: String = String(record.get("condition_id", "")).strip_edges().to_lower()
	if condition_id.is_empty() or battle_level == null:
		return
	if BattleWeatherService.is_terrain(condition_id):
		var extender: PokemonItemResource = PokemonItemService.held_item_for(attacker.stats) if attacker != null else null
		battle_level.set_terrain(condition_id, 8 if extender != null and extender.item_id == "held_terrain_extender" else 5, move.move_id)
		return
	var rock_rounds: int = PokemonItemService.weather_rounds_for(attacker.stats, BattleWeatherService.normalize(condition_id)) if attacker != null and attacker.stats != null and BattleWeatherService.is_weather(condition_id) else 0
	battle_level.set_battle_condition(condition_id, {
		"move_id": move.move_id,
		"attacker": attacker.name if attacker != null else "",
		"rounds": rock_rounds,
		"counter": int(record.get("counter", 0)),
		"source_event": record.get("source_event", ""),
	})
	_append(battle_log, {
		"kind": "field_condition_applied",
		"condition_id": condition_id,
		"move_id": move.move_id,
		"attacker": attacker,
		"source_event": record.get("source_event", ""),
	})


func _cure_statuses(unit: TacticsPawn, move: PokemonMoveResource, battle_log: BattleLog) -> void:
	if unit == null or unit.stats == null:
		return
	var statuses: Array[String] = []
	for status_id in unit.stats.battle_statuses.keys():
		statuses.append(String(status_id))
	for status_id in statuses:
		var removed: Dictionary = _ops(null, battle_log).remove_status(unit, status_id, {"move": move, "source": "cure_statuses"})
		if removed.is_empty():
			continue
		_append(battle_log, {
			"kind": "status_cured",
			"unit": unit,
			"move_id": move.move_id,
			"status_id": status_id,
			"source": "cure_statuses",
		})


func _apply_pp_damage(unit: TacticsPawn, move: PokemonMoveResource, amount: int, battle_log: BattleLog) -> void:
	if unit == null or unit.stats == null or amount <= 0:
		return
	for i in range(unit.stats.current_pp.size()):
		if unit.stats.current_pp[i] <= 0:
			continue
		var before: int = unit.stats.current_pp[i]
		unit.stats.current_pp[i] = maxi(0, before - amount)
		_append(battle_log, {
			"kind": "pp_reduced",
			"unit": unit,
			"move_id": move.move_id,
			"slot_index": i,
			"before": before,
			"after": unit.stats.current_pp[i],
			"amount": before - unit.stats.current_pp[i],
		})
		return


func _records_for_runtime(move: PokemonMoveResource) -> Array[Dictionary]:
	if move.effect_records.is_empty() and move.is_damaging() and not _has_damage_variant_tag(move):
		return [{
			"family": "damage",
			"target": "hit_target",
			"source_event": "PMDC.Dungeon.DamageFormulaEvent, PMDC",
		}]
	return move.effect_records


func _handle_protection(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, battle_log: BattleLog) -> bool:
	if attacker == null or target == null or attacker == target or target.stats == null:
		return false
	var shield_id: String = ""
	for candidate in PROTECTION_STATUSES:
		if target.stats.battle_statuses.has(candidate):
			shield_id = candidate
			break
	if shield_id.is_empty():
		return false
	if shield_id == "kings_shield" and not move.is_damaging():
		return false
	if shield_id == "crafty_shield" and move.is_damaging():
		return false
	if shield_id == "wide_guard" and not (move.tactical_range_kind in [PokemonMoveResource.TacticalRangeKind.AREA, PokemonMoveResource.TacticalRangeKind.LINE, PokemonMoveResource.TacticalRangeKind.ROOM]):
		return false
	if shield_id == "mat_block" and not move.is_damaging():
		return false
	if shield_id == "kings_shield" and move.has_flag("contact"):
		_ops(null, battle_log).change_stat_stage(attacker, "attack", -1, {"kind": "status", "attacker": target, "move": move, "event": {"source": "kings_shield"}})
	if shield_id == "spiky_shield" and move.has_flag("contact") and attacker.stats != null and attacker.stats.is_active():
		_ops(null, battle_log).damage(attacker, maxi(1, int(floor(float(attacker.stats.max_health) / 8.0))), {"kind": "status_tick", "status_id": "spiky_shield", "attacker": target})
	if move.move_id == MOVE_FEINT:
		_remove_status_with_log(target, shield_id, move.move_id, "protection_broken", battle_log)
		_append(battle_log, {
			"kind": "protection_broken",
			"attacker": attacker,
			"defender": target,
			"move_id": move.move_id,
		})
		return false
	if shield_id != "wide_guard" and shield_id != "crafty_shield" and shield_id != "mat_block":
		_remove_status_with_log(target, shield_id, move.move_id, "blocked", battle_log)
	_append(battle_log, {
		"kind": "move_blocked",
		"attacker": attacker,
		"defender": target,
		"move_id": move.move_id,
		"status_id": shield_id,
	})
	animation_resolver.select_reaction(target, move, "miss", battle_log)
	return true


func _apply_counter(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, damage_done: int, battle_log: BattleLog) -> void:
	if attacker == null or target == null or attacker == target or target.stats == null or attacker.stats == null:
		return
	if damage_done <= 0 or not target.stats.is_active():
		return
	var counter_id: String = ""
	var reflected_damage: int = 0
	if target.stats.battle_statuses.has(STATUS_COUNTER) and move.category == PokemonMoveResource.CATEGORY_PHYSICAL:
		counter_id = STATUS_COUNTER
		reflected_damage = damage_done * 2
	elif target.stats.battle_statuses.has("mirror_coat") and move.category == PokemonMoveResource.CATEGORY_SPECIAL:
		counter_id = "mirror_coat"
		reflected_damage = damage_done * 2
	elif target.stats.battle_statuses.has("metal_burst") and move.is_damaging():
		counter_id = "metal_burst"
		reflected_damage = int(floor(float(damage_done) * 1.5))
	if counter_id.is_empty():
		return
	_remove_status_with_log(target, counter_id, move.move_id, "counter_triggered", battle_log)
	var attacker_was_active: bool = attacker.stats.is_active()
	var applied: int = _apply_damage(target, attacker, move, reflected_damage, battle_log, {
		"kind": "damage_dealt",
		"source": counter_id,
		"source_move_id": move.move_id,
	})
	if applied <= 0:
		return
	_append(battle_log, {
		"kind": "counter_triggered",
		"attacker": target,
		"defender": attacker,
		"move_id": move.move_id,
		"amount": applied,
		"status_id": counter_id,
	})
	if attacker_was_active and not attacker.stats.is_active():
		_append(battle_log, {
			"kind": "unit_fainted",
			"unit": attacker,
			"move_id": move.move_id,
			"source": STATUS_COUNTER,
		})
		animation_resolver.select_reaction(attacker, move, "faint", battle_log)


func _apply_damage(attacker: TacticsPawn, defender: TacticsPawn, move: PokemonMoveResource, requested_damage: int, battle_log: BattleLog, event: Dictionary) -> int:
	if defender == null or defender.stats == null or requested_damage <= 0:
		return 0
	var amount: int = intrinsic_service.cap_damage_for_endure(defender, requested_damage, move, battle_log)
	amount = _capped_damage(move, defender, amount)
	if amount <= 0:
		return 0
	var outcome: Dictionary = _ops(null, battle_log).damage(defender, amount, {"kind": "hit", "attacker": attacker, "move": move, "event": event, "emit_faint": false})
	if animation_resolver.runner == null:
		defender.res.hurt_remaining = TacticsPawnResource.HURT_DURATION
	animation_resolver.select_reaction(defender, move, "receive_damage", battle_log)
	return int(outcome.get("applied", 0))


func _capped_damage(move: PokemonMoveResource, defender: TacticsPawn, requested_damage: int) -> int:
	if move != null and move.move_id == MOVE_FALSE_SWIPE and defender != null and defender.stats != null:
		return mini(requested_damage, maxi(0, defender.stats.curr_health - 1))
	return requested_damage


func _remove_status_with_log(unit: TacticsPawn, status_id: String, move_id: String, source: String, battle_log: BattleLog) -> void:
	var removed: Dictionary = unit.stats.remove_battle_status(status_id) if unit != null and unit.stats != null else {}
	if removed.is_empty():
		return
	_append(battle_log, {
		"kind": "status_removed",
		"unit": unit,
		"move_id": move_id,
		"status_id": status_id,
		"source": source,
	})


func _should_apply_formula_damage(move: PokemonMoveResource) -> bool:
	if move == null or not move.is_damaging():
		return false
	if BattleMoveSpecials.SELF_FAINT_MOVES.has(move.move_id):
		return true
	if _has_damage_variant_tag(move):
		return false
	if move.effect_records.is_empty():
		return true
	for record in move.effect_records:
		if String(record.get("family", "")) == "damage":
			return true
	return false


func _has_damage_variant_tag(move: PokemonMoveResource) -> bool:
	if move == null:
		return false
	for tag in move.unsupported_effect_tags:
		if DAMAGE_VARIANT_TAGS.has(tag):
			return true
	return false


func _recipient_for(record: Dictionary, attacker: TacticsPawn, target: TacticsPawn) -> TacticsPawn:
	match String(record.get("target", "hit_target")):
		"self":
			return attacker
		_:
			return target


func _heal_amount(record: Dictionary, recipient: TacticsPawn, battle_level: TacticsLevel = null) -> int:
	if String(record.get("source_event", "")).contains("WeatherHPEvent"):
		var fraction: Vector2i = BattleWeatherService.weather_heal_fraction(battle_level.current_weather() if battle_level != null else "")
		return maxi(1, int(floor(float(recipient.stats.max_health) * float(fraction.x) / float(fraction.y))))
	var amount: int = int(record.get("amount", 0))
	if amount > 0:
		return amount
	var divisor: int = int(record.get("hp_divisor", 0))
	if divisor > 0:
		return maxi(1, int(floor(float(recipient.stats.max_health) / float(divisor))))
	var percent: float = float(record.get("percent", 0.0))
	if percent > 0.0:
		return maxi(1, int(floor(float(recipient.stats.max_health) * percent)))
	return 0


func _recoil_amount(record: Dictionary, attacker: TacticsPawn) -> int:
	var fraction: int = int(record.get("fraction", 0))
	if fraction > 0:
		var source_hp: int = attacker.stats.max_health if bool(record.get("max_hp", true)) else attacker.stats.curr_health
		return maxi(1, int(floor(float(source_hp) / float(fraction))))
	return int(record.get("amount", 0))


func _expanded_targets(attacker: TacticsPawn, declared_target: TacticsPawn, move: PokemonMoveResource, battle_level: TacticsLevel) -> Array[TacticsPawn]:
	if move.tactical_range_kind in [PokemonMoveResource.TacticalRangeKind.AREA, PokemonMoveResource.TacticalRangeKind.LINE]:
		return Targeting.legal_targets_for_move(attacker, move, _all_units_for(attacker, battle_level))
	if Targeting.alignment_allows(attacker, declared_target, move):
		return [declared_target]
	return []


func _all_units_for(attacker: TacticsPawn, battle_level: TacticsLevel) -> Array[TacticsPawn]:
	var out: Array[TacticsPawn] = []
	if battle_level != null and battle_level.player != null and battle_level.opponent != null:
		for node in [battle_level.player, battle_level.opponent]:
			for child in node.get_children():
				if child is TacticsPawn:
					out.append(child)
	else:
		var root: Node = attacker.get_tree().current_scene if attacker != null and attacker.get_tree() != null else null
		if root != null:
			for child in root.find_children("*", "TacticsPawn", true, false):
				if child is TacticsPawn:
					out.append(child)
	out.sort_custom(func(a: TacticsPawn, b: TacticsPawn) -> bool: return a.name < b.name)
	return out


func _move_for(attacker: TacticsPawn, move_index: int) -> PokemonMoveResource:
	if attacker == null or attacker.stats == null:
		return null
	if move_index < 0 or move_index >= attacker.stats.move_slots.size():
		return null
	if not attacker.stats.has_pp(move_index):
		return null
	return attacker.stats.move_slots[move_index]


func _play_move_vfx(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, battle_level: TacticsLevel, battle_log: BattleLog) -> void:
	if battle_level == null or move == null:
		return
	var player: MoveVFXPlayer = battle_level.get_node_or_null("MoveVFXPlayer") as MoveVFXPlayer
	if player == null:
		player = MoveVFXPlayer.new()
		player.name = "MoveVFXPlayer"
		battle_level.add_child(player)
	player.play_for_move(move, attacker, target, battle_log)


func _load_type_chart() -> TypeChartResource:
	return load(TYPE_CHART_PATH) as TypeChartResource


func _append(battle_log: BattleLog, event: Dictionary) -> void:
	if battle_log != null:
		battle_log.append(event)
