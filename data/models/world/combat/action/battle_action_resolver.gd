class_name BattleActionResolver
extends RefCounted

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
const NATURE_POWER_DEFAULT_MOVE: String = "swift"
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
	"psych_up": ["speed", "attack", "defense", "special_attack", "special_defense", "accuracy"],
}

var damage_resolver := DamageResolver.new()
var animation_resolver := BattleAnimationResolver.new()
var intrinsic_service := BattleIntrinsicService.new()
var _fallback_rng := RandomNumberGenerator.new()


func _init() -> void:
	_fallback_rng.seed = 0


func execute(attacker: TacticsPawn, declared_target: TacticsPawn, move_index: int, battle_level: TacticsLevel = null) -> bool:
	if attacker == null or attacker.stats == null or not attacker.is_alive():
		return false
	var move: PokemonMoveResource = _move_for(attacker, move_index)
	var battle_log: BattleLog = battle_level.battle_log if battle_level != null else null
	if move == null:
		_append(battle_log, {
			"kind": "no_usable_move",
			"attacker": attacker,
			"slot_index": move_index,
		})
		return false
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
	if _status_blocks_move(attacker, move, move_index, rng, battle_log):
		return false

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

	var type_chart: TypeChartResource = battle_level.get_type_chart() if battle_level != null else _load_type_chart()
	_append(battle_log, {
		"kind": "move_used",
		"attacker": attacker,
		"move_id": move.move_id,
		"slot_index": move_index,
		"target_count": targets.size(),
	})
	animation_resolver.select_for_move(attacker, move, battle_log)
	_play_move_vfx(attacker, declared_target, move, battle_level, battle_log)

	attacker.stats.consume_pp(move_index)
	attacker.stats.record_move_use(move.move_id, move_index)
	_append(battle_log, {
		"kind": "pp_decremented",
		"attacker": attacker,
		"move_id": move.move_id,
		"slot_index": move_index,
		"remaining": attacker.stats.current_pp[move_index] if move_index < attacker.stats.current_pp.size() else 0,
	})
	var pressure_cost: int = intrinsic_service.pressure_extra_pp_cost(targets)
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

	var hit_count: int = maxi(1, move.strike_count)
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
	if move.effect_records.is_empty() and not move.unsupported_effect_tags.is_empty():
		for unsupported_tag in move.unsupported_effect_tags:
			if _is_runtime_supported_tag(unsupported_tag):
				continue
			_append(battle_log, {
				"kind": "effect_unsupported",
				"attacker": attacker,
				"move_id": move.move_id,
				"source_event": unsupported_tag,
			})
	return true


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
	var hit: bool = AccuracyResolver.roll(move, rng)
	if not hit:
		_append(battle_log, {
			"kind": "miss",
			"attacker": attacker,
			"defender": target,
			"move_id": move.move_id,
			"hit_index": hit_index,
		})
		animation_resolver.select_reaction(target, move, "miss", battle_log)
		return

	if _handle_protection(attacker, target, move, battle_log):
		return

	if intrinsic_service.damage_intercepted(target, move, battle_log):
		animation_resolver.select_reaction(target, move, "miss", battle_log)
		return

	var effectiveness: float = damage_resolver._effectiveness(move, target.stats, type_chart)
	var stab: bool = type_chart.is_stab(move.type, attacker.stats.types) if type_chart != null else false
	var damage: int = 0
	var damage_outcome: Dictionary = {}
	if _should_apply_formula_damage(move):
		var screen_multiplier: float = _screen_damage_multiplier(target, move, battle_level)
		damage_outcome["screen_multiplier"] = screen_multiplier
		var extra_multiplier: float = intrinsic_service.before_damage_multiplier(attacker.stats, move, battle_log, attacker, battle_level) * intrinsic_service.defender_damage_multiplier(target.stats, move, battle_log, target) * PokemonItemService.held_damage_multiplier(attacker.stats, move, battle_log, attacker) * PokemonItemService.held_defense_multiplier(target.stats, move, battle_log, target) * _status_damage_multiplier(attacker.stats, move) * screen_multiplier
		var critical_blocked: bool = _critical_blocked(target, battle_level) or intrinsic_service.blocks_critical(target.stats)
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
			"variance": int(damage_outcome.get("variance", 100)),
		})
		if damage_done > 0:
			intrinsic_service.after_damage(attacker, target, move, damage_done, rng, battle_log)
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
	var chance: int = int(record.get("chance", 100))
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
			if _safeguard_blocks_status(recipient, status_id, battle_level, battle_log, move):
				return
			if intrinsic_service.blocks_status(recipient.stats, status_id, battle_log, recipient, move):
				return
			var payload: Dictionary = {"move_id": move.move_id, "source_event": record.get("source_event", ""), "source_unit": attacker}
			if status_id == STATUS_DISABLE:
				payload["disabled_move_id"] = recipient.stats.last_used_move_id
				payload["disabled_slot_index"] = recipient.stats.last_used_move_index
			elif status_id == STATUS_ENCORE:
				payload["locked_move_id"] = recipient.stats.last_used_move_id
				payload["locked_slot_index"] = recipient.stats.last_used_move_index
			recipient.stats.apply_battle_status(status_id, payload)
			if _is_screen_status(status_id) and battle_level != null:
				battle_level.set_team_battle_condition(status_id, recipient, payload)
				_append(battle_log, {
					"kind": "field_condition_applied",
					"condition_id": status_id,
					"move_id": move.move_id,
					"attacker": attacker,
					"unit": recipient,
					"scope": "team",
					"source_event": record.get("source_event", ""),
				})
			_append(battle_log, {
				"kind": "status_applied",
				"unit": recipient,
				"move_id": move.move_id,
				"status_id": status_id,
			})
			intrinsic_service.maybe_reflect_status(attacker, recipient, status_id, move, battle_log)
		"status_remove":
			var remove_id: String = String(record.get("status_id", ""))
			if remove_id.is_empty():
				return
			var removed: Dictionary = recipient.stats.remove_battle_status(remove_id)
			if not removed.is_empty():
				if _is_screen_status(remove_id) and battle_level != null:
					battle_level.refresh_team_battle_condition(remove_id, recipient)
				_append(battle_log, {
					"kind": "status_removed",
					"unit": recipient,
					"move_id": move.move_id,
					"status_id": remove_id,
				})
		"stat_stage":
			var stat_delta: int = int(record.get("delta", 0))
			if intrinsic_service.blocks_stat_stage(recipient.stats, String(record.get("stat", "")), stat_delta, battle_log, recipient, move):
				return
			if _mist_blocks_stat_stage(recipient, stat_delta, battle_level, battle_log, move, String(record.get("stat", ""))):
				return
			var change: Dictionary = recipient.stats.change_stat_stage(String(record.get("stat", "")), int(record.get("delta", 0)))
			if not change.is_empty():
				_append(battle_log, {
					"kind": "stat_stage_changed",
					"unit": recipient,
					"move_id": move.move_id,
					"stat": change["stat"],
					"before": change["before"],
					"after": change["after"],
					"delta": change["delta"],
				})
		"weather_stat_stage":
			var weather_id: String = String(record.get("weather_id", ""))
			var delta: int = int(record.get("weather_delta", record.get("delta", 0))) if battle_level != null and battle_level.has_battle_condition(weather_id) else int(record.get("delta", 0))
			if intrinsic_service.blocks_stat_stage(recipient.stats, String(record.get("stat", "")), delta, battle_log, recipient, move):
				return
			if _mist_blocks_stat_stage(recipient, delta, battle_level, battle_log, move, String(record.get("stat", ""))):
				return
			var weather_change: Dictionary = recipient.stats.change_stat_stage(String(record.get("stat", "")), delta)
			if not weather_change.is_empty():
				_append(battle_log, {
					"kind": "stat_stage_changed",
					"unit": recipient,
					"move_id": move.move_id,
					"stat": weather_change["stat"],
					"before": weather_change["before"],
					"after": weather_change["after"],
					"delta": weather_change["delta"],
					"condition_id": weather_id if battle_level != null and battle_level.has_battle_condition(weather_id) else "",
				})
		"ability_change":
			var target_ability: String = String(record.get("target_ability", ""))
			if target_ability.is_empty():
				return
			intrinsic_service.replace_intrinsic(recipient, target_ability, move, battle_log, String(record.get("source_event", "")))
		"heal":
			if _healing_blocked(recipient, move, battle_log):
				return
			var amount: int = _heal_amount(record, recipient)
			if amount <= 0:
				return
			var before: int = recipient.stats.curr_health
			recipient.stats.apply_to_curr_health(amount)
			_append(battle_log, {
				"kind": "healed",
				"unit": recipient,
				"move_id": move.move_id,
				"amount": recipient.stats.curr_health - before,
				"before": before,
				"after": recipient.stats.curr_health,
			})
		"drain":
			var drain_amount: int = int(floor(float(damage_done) * float(record.get("fraction", 0.5))))
			if drain_amount > 0:
				if _healing_blocked(attacker, move, battle_log):
					return
				var before_heal: int = attacker.stats.curr_health
				attacker.stats.apply_to_curr_health(drain_amount)
				_append(battle_log, {
					"kind": "healed",
					"unit": attacker,
					"move_id": move.move_id,
					"amount": attacker.stats.curr_health - before_heal,
					"before": before_heal,
					"after": attacker.stats.curr_health,
					"source": "drain",
				})
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
				var attacker_was_active: bool = attacker.stats.is_active()
				attacker.stats.apply_to_curr_health(-recoil)
				_append(battle_log, {
					"kind": "damage_dealt",
					"attacker": attacker,
					"defender": attacker,
					"move_id": move.move_id,
					"amount": recoil,
					"source": "recoil",
				})
				if attacker != target and attacker_was_active and not attacker.stats.is_active():
					_append(battle_log, {
						"kind": "unit_fainted",
						"unit": attacker,
						"move_id": move.move_id,
						"source": "recoil",
					})
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
	if attacker.stats.battle_statuses.has(STATUS_CONFUSE):
		var source_rng: RandomNumberGenerator = rng if rng != null else _fallback_rng
		if source_rng.randi_range(0, 1) == 0:
			_apply_confusion_self_hit(attacker, move, battle_log)
			return true
	return false


func _status_damage_multiplier(stats: Stats, move: PokemonMoveResource) -> float:
	if stats == null or move == null:
		return 1.0
	if stats.battle_statuses.has(STATUS_BURN) and move.category == PokemonMoveResource.CATEGORY_PHYSICAL:
		return 2.0 / 3.0
	return 1.0


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
			var max_fraction: int = _damage_variant_hp_fraction(move, 2)
			return maxi(1, int(floor(float(target.stats.max_health) / float(max_fraction))))
		TAG_ENDEAVOR_DAMAGE:
			return maxi(0, target.stats.curr_health - attacker.stats.curr_health)
		TAG_PSYWAVE_DAMAGE:
			var distance: int = _grid_distance(attacker, target)
			var diff: int = distance % 4
			var power: int = 1 if diff > 2 else diff
			return maxi(1, int(floor(float(attacker.stats.level * power) / 2.0)))
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
		copied = _last_used_move(target)
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
	var forward: Vector3 = -basis.z
	if absf(forward.x) > absf(forward.z):
		return Vector3i(1 if forward.x > 0.0 else -1, 0, 0)
	return Vector3i(0, 0, 1 if forward.z > 0.0 else -1)


func _unit_key(unit: TacticsPawn) -> Vector3i:
	if unit == null:
		return Vector3i.ZERO
	var tile: TacticsTile = unit.get_tile()
	var pos: Vector3 = tile.global_position if tile != null and tile.is_inside_tree() else (tile.position if tile != null else unit.global_position)
	return Vector3i(roundi(pos.x), 0, roundi(pos.z))


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
	return Vector3i(roundi(pos.x), 0, roundi(pos.z))


func _grid_distance(a: TacticsPawn, b: TacticsPawn) -> int:
	var a_key: Vector3i = _unit_key(a)
	var b_key: Vector3i = _unit_key(b)
	return maxi(absi(a_key.x - b_key.x), absi(a_key.z - b_key.z))


func _apply_field_condition(record: Dictionary, attacker: TacticsPawn, move: PokemonMoveResource, battle_level: TacticsLevel, battle_log: BattleLog) -> void:
	var condition_id: String = String(record.get("condition_id", "")).strip_edges().to_lower()
	if condition_id.is_empty() or battle_level == null:
		return
	battle_level.set_battle_condition(condition_id, {
		"move_id": move.move_id,
		"attacker": attacker.name if attacker != null else "",
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
		var removed: Dictionary = unit.stats.remove_battle_status(status_id)
		if removed.is_empty():
			continue
		_append(battle_log, {
			"kind": "status_removed",
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
	if not target.stats.battle_statuses.has(STATUS_PROTECT):
		return false
	if move.move_id == MOVE_FEINT:
		_remove_status_with_log(target, STATUS_PROTECT, move.move_id, "protection_broken", battle_log)
		_append(battle_log, {
			"kind": "protection_broken",
			"attacker": attacker,
			"defender": target,
			"move_id": move.move_id,
		})
		return false
	_remove_status_with_log(target, STATUS_PROTECT, move.move_id, "blocked", battle_log)
	_append(battle_log, {
		"kind": "move_blocked",
		"attacker": attacker,
		"defender": target,
		"move_id": move.move_id,
		"status_id": STATUS_PROTECT,
	})
	animation_resolver.select_reaction(target, move, "miss", battle_log)
	return true


func _apply_counter(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, damage_done: int, battle_log: BattleLog) -> void:
	if attacker == null or target == null or attacker == target or target.stats == null or attacker.stats == null:
		return
	if damage_done <= 0 or move.category != PokemonMoveResource.CATEGORY_PHYSICAL:
		return
	if not target.stats.is_active() or not target.stats.battle_statuses.has(STATUS_COUNTER):
		return
	_remove_status_with_log(target, STATUS_COUNTER, move.move_id, "counter_triggered", battle_log)
	var reflected_damage: int = damage_done * 2
	var attacker_was_active: bool = attacker.stats.is_active()
	var applied: int = _apply_damage(target, attacker, move, reflected_damage, battle_log, {
		"kind": "damage_dealt",
		"source": STATUS_COUNTER,
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
	defender.stats.apply_to_curr_health(-amount)
	defender.res.hurt_remaining = TacticsPawnResource.HURT_DURATION
	var payload: Dictionary = event.duplicate(true)
	payload["attacker"] = attacker
	payload["defender"] = defender
	payload["move_id"] = move.move_id
	payload["amount"] = amount
	_append(battle_log, payload)
	animation_resolver.select_reaction(defender, move, "receive_damage", battle_log)
	PokemonItemService.try_trigger_held_threshold(defender, battle_log)
	return amount


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


func _heal_amount(record: Dictionary, recipient: TacticsPawn) -> int:
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
