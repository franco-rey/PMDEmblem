extends SmokeCase

const ATTACKER_PATH: String = "res://data/models/pokemon/generated/instances/0004_charmander.tres"
const DEFENDER_PATH: String = "res://data/models/pokemon/overrides/instances/0467_magmortar.tres"

class FakePawn:
	extends TacticsPawn
	var fake_tile: TacticsTile
	func get_tile() -> TacticsTile:
		return fake_tile

var resolver := BattleActionResolver.new()


func _init() -> void:
	_check_damage_status_stat_heal_recoil_fixed_percent()
	_check_false_swipe_protect_counter()
	_check_multi_hit()
	_check_recoil_faint()
	_check_area_targets()
	_check_forced_movement()
	_check_damage_variants()
	_check_stat_hp_manipulation()
	_check_move_copying()
	_check_ability_dependent_moves()
	_check_status_dependent_moves()
	_check_item_dependent_moves()
	_check_screen_field_statuses()
	if failures > 0:
		push_error("smoke: move effects failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: move_effects clean")
		quit(0)


func _check_damage_status_stat_heal_recoil_fixed_percent() -> void:
	var level: TacticsLevel = _fake_level()
	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "Attacker", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn(DEFENDER_PATH, "Defender", Vector3(1, 0, 0))
	level.player.add_child(attacker)
	level.opponent.add_child(defender)

	var move := _move("combo", PokemonMoveResource.CATEGORY_PHYSICAL, 50, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [
		{"family": "damage", "target": "hit_target"},
		{"family": "status", "target": "hit_target", "status_id": "poison"},
		{"family": "stat_stage", "target": "hit_target", "stat": "defense", "delta": -1},
		{"family": "recoil", "target": "self", "fraction": 6, "max_hp": true},
		{"family": "fixed_damage", "target": "hit_target", "amount": 7},
		{"family": "percent_damage", "target": "hit_target", "percent": 0.1},
	])
	attacker.stats.move_slots = [move]
	attacker.stats.current_pp = [move.pp]
	var before_attacker_hp: int = attacker.stats.curr_health
	var before_defender_hp: int = defender.stats.curr_health
	resolver.execute(attacker, defender, 0, level)
	_assert_true(defender.stats.curr_health < before_defender_hp, "damage/fixed/percent damage changed defender HP")
	_assert_true(attacker.stats.curr_health < before_attacker_hp, "recoil changed attacker HP")
	_assert_true(defender.stats.battle_statuses.has("poison"), "status applied")
	_assert_true(defender.stats.get_stat_stage("defense") == -1, "stat stage dropped")
	_assert_true(_log_has(level.battle_log, "status_applied"), "status_applied logged")
	_assert_true(_log_has(level.battle_log, "stat_stage_changed"), "stat_stage_changed logged")

	var heal := _move("heal", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.SELF, PokemonMoveResource.TARGET_SELF, [
		{"family": "heal", "target": "self", "hp_divisor": 4},
	])
	attacker.stats.move_slots = [heal]
	attacker.stats.current_pp = [heal.pp]
	var hurt_hp: int = attacker.stats.curr_health
	resolver.execute(attacker, attacker, 0, level)
	_assert_true(attacker.stats.curr_health > hurt_hp, "heal restored HP")
	_assert_true(_log_has(level.battle_log, "healed"), "healed logged")

	var unsupported := _move("weather_stub", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.SELF, PokemonMoveResource.TARGET_SELF, [])
	unsupported.unsupported_effect_tags = ["PMDC.Dungeon.GiveMapStatusEvent, PMDC"]
	attacker.stats.move_slots = [unsupported]
	attacker.stats.current_pp = [unsupported.pp]
	resolver.execute(attacker, attacker, 0, level)
	_assert_true(_log_has(level.battle_log, "effect_unsupported"), "unsupported effect is logged")
	level.battle_log.events.clear()
	level.free()


func _check_false_swipe_protect_counter() -> void:
	var level: TacticsLevel = _fake_level()
	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "GuardAttacker", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn(DEFENDER_PATH, "GuardDefender", Vector3(1, 0, 0))
	level.player.add_child(attacker)
	level.opponent.add_child(defender)

	var false_swipe := _move("false_swipe", PokemonMoveResource.CATEGORY_PHYSICAL, 500, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [
		{"family": "damage", "target": "hit_target"},
	])
	defender.stats.curr_health = 30
	attacker.stats.move_slots = [false_swipe]
	attacker.stats.current_pp = [false_swipe.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(defender.stats.curr_health == 1, "False Swipe leaves target at 1 HP")
	_assert_true(defender.stats.is_active(), "False Swipe does not faint target")
	_assert_true(_damage_amount(level.battle_log, "false_swipe") == 29, "False Swipe logs capped applied damage")
	level.battle_log.events.clear()

	defender.stats.curr_health = defender.stats.max_health
	defender.stats.apply_battle_status("protect", {"move_id": "protect"})
	var tackle := _move("tackle", PokemonMoveResource.CATEGORY_PHYSICAL, 80, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [
		{"family": "damage", "target": "hit_target"},
	])
	attacker.stats.move_slots = [tackle]
	attacker.stats.current_pp = [tackle.pp]
	var protected_hp: int = defender.stats.curr_health
	resolver.execute(attacker, defender, 0, level)
	_assert_true(defender.stats.curr_health == protected_hp, "Protect blocks incoming move damage")
	_assert_true(not defender.stats.battle_statuses.has("protect"), "Protect clears after blocking")
	_assert_true(_log_has(level.battle_log, "move_blocked"), "Protect logs blocked move")
	level.battle_log.events.clear()

	defender.stats.apply_battle_status("protect", {"move_id": "protect"})
	var feint := _move("feint", PokemonMoveResource.CATEGORY_PHYSICAL, 40, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [
		{"family": "damage", "target": "hit_target"},
	])
	attacker.stats.move_slots = [feint]
	attacker.stats.current_pp = [feint.pp]
	protected_hp = defender.stats.curr_health
	resolver.execute(attacker, defender, 0, level)
	_assert_true(defender.stats.curr_health < protected_hp, "Feint bypasses Protect")
	_assert_true(not defender.stats.battle_statuses.has("protect"), "Feint removes Protect")
	_assert_true(_log_has(level.battle_log, "protection_broken"), "Feint logs protection break")
	level.battle_log.events.clear()

	defender.stats.curr_health = defender.stats.max_health
	defender.stats.apply_battle_status("counter", {"move_id": "counter"})
	attacker.stats.move_slots = [tackle]
	attacker.stats.current_pp = [tackle.pp]
	var attacker_hp: int = attacker.stats.curr_health
	resolver.execute(attacker, defender, 0, level)
	_assert_true(attacker.stats.curr_health < attacker_hp, "Counter reflects physical damage")
	_assert_true(not defender.stats.battle_statuses.has("counter"), "Counter clears after reflecting")
	_assert_true(_log_has(level.battle_log, "counter_triggered"), "Counter logs reflection")
	level.battle_log.events.clear()
	level.free()


func _check_multi_hit() -> void:
	var level: TacticsLevel = _fake_level()
	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "MultiAttacker", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn(DEFENDER_PATH, "MultiDefender", Vector3(1, 0, 0))
	level.player.add_child(attacker)
	level.opponent.add_child(defender)
	var move := _move("triple_hit", PokemonMoveResource.CATEGORY_PHYSICAL, 10, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [
		{"family": "multi_hit", "target": "hit_target"},
		{"family": "damage", "target": "hit_target"},
	])
	move.strike_count = 3
	attacker.stats.move_slots = [move]
	attacker.stats.current_pp = [move.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(_count_events(level.battle_log, "damage_dealt") >= 3, "multi-hit deals repeated damage")
	level.battle_log.events.clear()
	level.free()


func _check_recoil_faint() -> void:
	var level: TacticsLevel = _fake_level()
	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "RecoilAttacker", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn(DEFENDER_PATH, "RecoilDefender", Vector3(1, 0, 0))
	level.player.add_child(attacker)
	level.opponent.add_child(defender)
	attacker.stats.curr_health = 1
	var move := _move("recoil_faint", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [
		{"family": "recoil", "target": "self", "amount": 9},
	])
	attacker.stats.move_slots = [move]
	attacker.stats.current_pp = [move.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(not attacker.stats.is_active(), "recoil can faint attacker")
	_assert_true(_log_has_source(level.battle_log, "unit_fainted", "recoil"), "recoil faint logged")
	level.battle_log.events.clear()
	level.free()


func _check_area_targets() -> void:
	var level: TacticsLevel = _fake_level()
	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "AreaAttacker", Vector3.ZERO)
	var defender_a: FakePawn = _fake_pawn(DEFENDER_PATH, "AreaA", Vector3(1, 0, 0))
	var defender_b: FakePawn = _fake_pawn(DEFENDER_PATH, "AreaB", Vector3(0, 0, 1))
	level.player.add_child(attacker)
	level.opponent.add_child(defender_a)
	level.opponent.add_child(defender_b)
	var move := _move("area_hit", PokemonMoveResource.CATEGORY_SPECIAL, 20, PokemonMoveResource.TacticalRangeKind.AREA, PokemonMoveResource.TARGET_FOE, [
		{"family": "damage", "target": "hit_target"},
	])
	move.tactical_range_value = 1
	attacker.stats.move_slots = [move]
	attacker.stats.current_pp = [move.pp]
	resolver.execute(attacker, defender_a, 0, level)
	_assert_true(_count_events(level.battle_log, "damage_dealt") == 2, "area move hits both legal targets")
	level.battle_log.events.clear()
	level.free()


func _check_forced_movement() -> void:
	var level: TacticsLevel = _fake_level()
	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "PushAttacker", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn(DEFENDER_PATH, "PushDefender", Vector3(1, 0, 0))
	level.player.add_child(attacker)
	level.opponent.add_child(defender)
	var whirlwind := _move("whirlwind", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [])
	whirlwind.unsupported_effect_tags = ["PMDC.Dungeon.KnockBackEvent, PMDC"]
	attacker.stats.move_slots = [whirlwind]
	attacker.stats.current_pp = [whirlwind.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(defender.get_tile().position.x == 2.0, "Whirlwind pushes target one grid step away")
	_assert_true(_log_has(level.battle_log, "forced_movement"), "Whirlwind logs forced movement")
	_assert_true(not _log_has(level.battle_log, "effect_unsupported"), "implemented forced movement does not log unsupported")
	level.battle_log.events.clear()

	defender.fake_tile.position = Vector3(1, 0, 0)
	defender.stats.curr_health = defender.stats.max_health
	var circle_throw := _move("circle_throw", PokemonMoveResource.CATEGORY_PHYSICAL, 40, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [])
	circle_throw.unsupported_effect_tags = ["PMDC.Dungeon.ThrowBackEvent, PMDC"]
	attacker.stats.move_slots = [circle_throw]
	attacker.stats.current_pp = [circle_throw.pp]
	var before_hp: int = defender.stats.curr_health
	resolver.execute(attacker, defender, 0, level)
	_assert_true(defender.stats.curr_health < before_hp, "Circle Throw deals damage before forced movement")
	_assert_true(defender.get_tile().position.x == 2.0, "Circle Throw throws target away")
	level.battle_log.events.clear()

	var ally: FakePawn = _fake_pawn(ATTACKER_PATH, "SwitchAlly", Vector3(1, 0, 0))
	level.player.add_child(ally)
	attacker.fake_tile.position = Vector3.ZERO
	var ally_switch := _move("ally_switch", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FRIEND, [])
	ally_switch.unsupported_effect_tags = ["PMDC.Dungeon.SwitcherEvent, PMDC"]
	attacker.stats.move_slots = [ally_switch]
	attacker.stats.current_pp = [ally_switch.pp]
	resolver.execute(attacker, ally, 0, level)
	_assert_true(attacker.get_tile().position.x == 1.0 and ally.get_tile().position.x == 0.0, "Ally Switch swaps user and ally tiles")
	level.battle_log.events.clear()
	level.free()


func _check_damage_variants() -> void:
	var level: TacticsLevel = _fake_level()
	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "VariantAttacker", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn(DEFENDER_PATH, "VariantDefender", Vector3(1, 0, 0))
	level.player.add_child(attacker)
	level.opponent.add_child(defender)

	var super_fang := _move("super_fang", PokemonMoveResource.CATEGORY_PHYSICAL, 90, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [])
	super_fang.unsupported_effect_tags = ["PMDC.Dungeon.CutHPDamageEvent, PMDC"]
	defender.stats.max_health = 120
	defender.stats.curr_health = 81
	attacker.stats.move_slots = [super_fang]
	attacker.stats.current_pp = [super_fang.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(defender.stats.curr_health == 41, "Super Fang cuts current HP by PMD fraction")
	_assert_true(_damage_amount_by_source(level.battle_log, "super_fang", "cut_hp") == 40, "CutHPDamageEvent logs fixed cut damage")
	level.battle_log.events.clear()

	var sonic_boom := _move("sonic_boom", PokemonMoveResource.CATEGORY_SPECIAL, 90, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [])
	sonic_boom.unsupported_effect_tags = ["PMDC.Dungeon.MaxHPDamageEvent, PMDC"]
	defender.stats.max_health = 135
	defender.stats.curr_health = 135
	attacker.stats.move_slots = [sonic_boom]
	attacker.stats.current_pp = [sonic_boom.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(defender.stats.curr_health == 115, "Sonic Boom deals a flat 20")
	_assert_true(_damage_amount_by_source(level.battle_log, "sonic_boom", "max_hp") == 20, "MaxHPDamageEvent logs the flat damage")
	level.battle_log.events.clear()

	var endeavor := _move("endeavor", PokemonMoveResource.CATEGORY_PHYSICAL, 90, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [])
	endeavor.unsupported_effect_tags = ["PMDC.Dungeon.EndeavorEvent, PMDC"]
	attacker.stats.curr_health = 25
	defender.stats.curr_health = 90
	attacker.stats.move_slots = [endeavor]
	attacker.stats.current_pp = [endeavor.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(defender.stats.curr_health == 25, "Endeavor reduces target HP to user HP")
	_assert_true(_damage_amount_by_source(level.battle_log, "endeavor", "endeavor") == 65, "Endeavor logs HP delta damage")
	level.battle_log.events.clear()

	var psywave := _move("psywave", PokemonMoveResource.CATEGORY_SPECIAL, 90, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [])
	psywave.type = "psychic"
	psywave.unsupported_effect_tags = ["PMDC.Dungeon.PsywaveDamageEvent, PMDC"]
	attacker.stats.level = 50
	defender.stats.curr_health = 100
	attacker.stats.move_slots = [psywave]
	attacker.stats.current_pp = [psywave.pp]
	resolver.execute(attacker, defender, 0, level)
	var psywave_amount: int = _damage_amount_by_source(level.battle_log, "psywave", "psywave")
	_assert_true(psywave_amount >= 25 and psywave_amount <= 75 and defender.stats.curr_health == 100 - psywave_amount, "Psywave deals between half and 1.5x the user's level (%d)" % psywave_amount)
	level.battle_log.events.clear()

	var fissure := _move("fissure", PokemonMoveResource.CATEGORY_PHYSICAL, 90, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [])
	fissure.unsupported_effect_tags = ["PMDC.Dungeon.OHKODamageEvent, PMDC"]
	defender.stats.curr_health = 77
	defender.stats.battle_status = Stats.BattleStatus.ACTIVE
	defender.stats.level = attacker.stats.level
	attacker.stats.move_slots = [fissure]
	attacker.stats.current_pp = [fissure.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(defender.stats.curr_health == 0 and not defender.stats.is_active(), "OHKO damage faints target")
	_assert_true(_damage_amount_by_source(level.battle_log, "fissure", "ohko") == 77, "OHKODamageEvent logs current HP damage")
	level.battle_log.events.clear()

	var bide_release := _move("bide_release", PokemonMoveResource.CATEGORY_PHYSICAL, 30, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [])
	bide_release.unsupported_effect_tags = ["PMDC.Dungeon.BasePowerDamageEvent, PMDC"]
	defender.stats.curr_health = 90
	defender.stats.battle_status = Stats.BattleStatus.ACTIVE
	attacker.stats.move_slots = [bide_release]
	attacker.stats.current_pp = [bide_release.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(defender.stats.curr_health == 60, "BasePowerDamageEvent deals BasePowerState damage")
	_assert_true(_damage_amount_by_source(level.battle_log, "bide_release", "base_power") == 30, "BasePowerDamageEvent logs base-power damage")
	level.battle_log.events.clear()

	var belly_drum := _move("belly_drum", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.SELF, PokemonMoveResource.TARGET_SELF, [
		{"family": "stat_stage", "target": "hit_target", "stat": "attack", "delta": 12},
	])
	belly_drum.unsupported_effect_tags = ["PMDC.Dungeon.MaxHPDamageEvent, PMDC"]
	attacker.stats.max_health = 100
	attacker.stats.curr_health = 100
	attacker.stats.battle_status = Stats.BattleStatus.ACTIVE
	attacker.stats.move_slots = [belly_drum]
	attacker.stats.current_pp = [belly_drum.pp]
	resolver.execute(attacker, attacker, 0, level)
	_assert_true(attacker.stats.curr_health == 50, "Belly Drum pays half max HP")
	_assert_true(attacker.stats.get_stat_stage("attack") == 6, "Belly Drum maximizes attack stage")
	level.battle_log.events.clear()
	level.free()


func _check_stat_hp_manipulation() -> void:
	var level: TacticsLevel = _fake_level()
	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "ManipAttacker", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn(DEFENDER_PATH, "ManipDefender", Vector3(1, 0, 0))
	level.player.add_child(attacker)
	level.opponent.add_child(defender)

	var pain_split := _move("pain_split", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [])
	pain_split.unsupported_effect_tags = ["PMDC.Dungeon.PainSplitEvent, PMDC"]
	attacker.stats.max_health = 100
	attacker.stats.curr_health = 40
	defender.stats.max_health = 120
	defender.stats.curr_health = 100
	attacker.stats.move_slots = [pain_split]
	attacker.stats.current_pp = [pain_split.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(attacker.stats.curr_health == 70 and defender.stats.curr_health == 70, "Pain Split averages user and target HP")
	_assert_true(_log_has(level.battle_log, "hp_split"), "Pain Split logs hp_split")
	level.battle_log.events.clear()

	var guard_split := _move("guard_split", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [])
	guard_split.type = "psychic"
	guard_split.unsupported_effect_tags = ["PMDC.Dungeon.StatSplitEvent, PMDC"]
	attacker.stats.defense = 20
	attacker.stats.special_defense = 30
	defender.stats.defense = 100
	defender.stats.special_defense = 70
	attacker.stats.move_slots = [guard_split]
	attacker.stats.current_pp = [guard_split.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(attacker.stats.battle_stat("defense") == 60 and defender.stats.battle_stat("defense") == 60, "Guard Split averages defense")
	_assert_true(attacker.stats.battle_stat("special_defense") == 50 and defender.stats.battle_stat("special_defense") == 50, "Guard Split averages special defense")
	level.battle_log.events.clear()

	var power_split := _move("power_split", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [])
	power_split.type = "psychic"
	power_split.unsupported_effect_tags = ["PMDC.Dungeon.StatSplitEvent, PMDC"]
	attacker.stats.proxy_stats = {}
	defender.stats.proxy_stats = {}
	attacker.stats.attack = 30
	attacker.stats.special_attack = 40
	defender.stats.attack = 90
	defender.stats.special_attack = 80
	attacker.stats.move_slots = [power_split]
	attacker.stats.current_pp = [power_split.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(attacker.stats.battle_stat("attack") == 60 and defender.stats.battle_stat("attack") == 60, "Power Split averages attack")
	_assert_true(attacker.stats.battle_stat("special_attack") == 60 and defender.stats.battle_stat("special_attack") == 60, "Power Split averages special attack")
	level.battle_log.events.clear()

	var power_trick := _move("power_trick", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.SELF, PokemonMoveResource.TARGET_SELF, [])
	power_trick.type = "psychic"
	power_trick.unsupported_effect_tags = ["PMDC.Dungeon.PowerTrickEvent, PMDC"]
	attacker.stats.proxy_stats = {}
	attacker.stats.attack = 25
	attacker.stats.defense = 80
	attacker.stats.move_slots = [power_trick]
	attacker.stats.current_pp = [power_trick.pp]
	resolver.execute(attacker, attacker, 0, level)
	_assert_true(attacker.stats.battle_stat("attack") == 80 and attacker.stats.battle_stat("defense") == 25, "Power Trick swaps attack and defense proxies")
	level.battle_log.events.clear()

	var guard_swap := _move("guard_swap", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [])
	guard_swap.type = "psychic"
	guard_swap.unsupported_effect_tags = ["PMDC.Dungeon.SwapStatsEvent, PMDC"]
	attacker.stats.set_stat_stage("defense", 2)
	attacker.stats.set_stat_stage("special_defense", -1)
	defender.stats.set_stat_stage("defense", -3)
	defender.stats.set_stat_stage("special_defense", 4)
	attacker.stats.move_slots = [guard_swap]
	attacker.stats.current_pp = [guard_swap.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(attacker.stats.get_stat_stage("defense") == -3 and defender.stats.get_stat_stage("defense") == 2, "Guard Swap swaps defense stages")
	_assert_true(attacker.stats.get_stat_stage("special_defense") == 4 and defender.stats.get_stat_stage("special_defense") == -1, "Guard Swap swaps special defense stages")
	level.battle_log.events.clear()

	var power_swap := _move("power_swap", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [])
	power_swap.type = "psychic"
	power_swap.unsupported_effect_tags = ["PMDC.Dungeon.SwapStatsEvent, PMDC"]
	attacker.stats.set_stat_stage("attack", 3)
	attacker.stats.set_stat_stage("special_attack", -2)
	defender.stats.set_stat_stage("attack", -4)
	defender.stats.set_stat_stage("special_attack", 1)
	attacker.stats.move_slots = [power_swap]
	attacker.stats.current_pp = [power_swap.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(attacker.stats.get_stat_stage("attack") == -4 and defender.stats.get_stat_stage("attack") == 3, "Power Swap swaps attack stages")
	_assert_true(attacker.stats.get_stat_stage("special_attack") == 1 and defender.stats.get_stat_stage("special_attack") == -2, "Power Swap swaps special attack stages")
	level.battle_log.events.clear()

	var psych_up := _move("psych_up", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [])
	psych_up.unsupported_effect_tags = ["PMDC.Dungeon.ReflectStatsEvent, PMDC"]
	attacker.stats.stat_stages = {}
	defender.stats.set_stat_stage("attack", 5)
	defender.stats.set_stat_stage("defense", -2)
	defender.stats.set_stat_stage("special_attack", 1)
	defender.stats.set_stat_stage("special_defense", -3)
	defender.stats.set_stat_stage("speed", 4)
	defender.stats.set_stat_stage("accuracy", -1)
	defender.stats.set_stat_stage("evasion", 6)
	attacker.stats.move_slots = [psych_up]
	attacker.stats.current_pp = [psych_up.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(attacker.stats.get_stat_stage("attack") == 5 and attacker.stats.get_stat_stage("defense") == -2, "Psych Up copies attack and defense stages")
	_assert_true(attacker.stats.get_stat_stage("speed") == 4 and attacker.stats.get_stat_stage("accuracy") == -1, "Psych Up copies speed and accuracy stages")
	_assert_true(attacker.stats.get_stat_stage("evasion") == 6, "Psych Up copies evasion too")
	level.battle_log.events.clear()
	level.free()


func _check_screen_field_statuses() -> void:
	var baseline_special: int = _screen_probe_damage(PokemonMoveResource.CATEGORY_SPECIAL, "")
	var light_screen_damage: int = _screen_probe_damage(PokemonMoveResource.CATEGORY_SPECIAL, "light_screen")
	_assert_true(light_screen_damage > 0 and light_screen_damage <= int(ceil(float(baseline_special) / 2.0)), "Light Screen halves special damage")

	var baseline_physical: int = _screen_probe_damage(PokemonMoveResource.CATEGORY_PHYSICAL, "")
	var reflect_damage: int = _screen_probe_damage(PokemonMoveResource.CATEGORY_PHYSICAL, "reflect")
	_assert_true(reflect_damage > 0 and reflect_damage <= int(ceil(float(baseline_physical) / 2.0)), "Reflect halves physical damage")

	var level: TacticsLevel = _fake_level()
	var screen_user: FakePawn = _fake_pawn(ATTACKER_PATH, "ScreenUser", Vector3.ZERO)
	var ally: FakePawn = _fake_pawn(DEFENDER_PATH, "ScreenAlly", Vector3(1, 0, 0))
	var foe: FakePawn = _fake_pawn(ATTACKER_PATH, "ScreenFoe", Vector3(2, 0, 0))
	level.player.add_child(screen_user)
	level.player.add_child(ally)
	level.opponent.add_child(foe)

	var light_screen := _move("light_screen", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.SELF, PokemonMoveResource.TARGET_SELF, [
		{"family": "status", "target": "hit_target", "status_id": "light_screen"},
	])
	screen_user.stats.move_slots = [light_screen]
	screen_user.stats.current_pp = [light_screen.pp]
	resolver.execute(screen_user, screen_user, 0, level)
	_assert_true(level.has_team_battle_condition("light_screen", ally), "Light Screen applies a team battle condition")
	level.battle_log.events.clear()

	level.set_team_battle_condition("safeguard", ally, {"counter": 15})
	var burn_move := _move("burn_touch", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [
		{"family": "status", "target": "hit_target", "status_id": "burn"},
	])
	foe.stats.move_slots = [burn_move]
	foe.stats.current_pp = [burn_move.pp]
	resolver.execute(foe, ally, 0, level)
	_assert_true(not ally.stats.battle_statuses.has("burn"), "Safeguard blocks bad status application")
	_assert_true(_log_has_blocked_by(level.battle_log, "status_blocked", "safeguard"), "Safeguard logs blocked status")
	level.battle_log.events.clear()

	level.set_team_battle_condition("mist", ally, {"counter": 15})
	var leer := _move("leer", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [
		{"family": "stat_stage", "target": "hit_target", "stat": "defense", "delta": -1},
	])
	foe.stats.move_slots = [leer]
	foe.stats.current_pp = [leer.pp]
	resolver.execute(foe, ally, 0, level)
	_assert_true(ally.stats.get_stat_stage("defense") == 0, "Mist blocks stat drops")
	_assert_true(_log_has_blocked_by(level.battle_log, "stat_stage_blocked", "mist"), "Mist logs blocked stat drop")
	level.battle_log.events.clear()

	level.set_team_battle_condition("lucky_chant", ally, {"counter": 25})
	var slash := _move("slash", PokemonMoveResource.CATEGORY_PHYSICAL, 80, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [
		{"family": "damage", "target": "hit_target"},
		{"family": "boost_critical", "crit_level": 4},
		{"family": "status", "target": "hit_target", "status_id": "burn", "chance": 100, "wrapped_source_event": "PMDC.Dungeon.OnHitEvent, PMDC"},
	])
	foe.stats.move_slots = [slash]
	foe.stats.current_pp = [slash.pp]
	resolver.execute(foe, ally, 0, level)
	var slash_event: Dictionary = _damage_event(level.battle_log, "slash")
	_assert_true(not bool(slash_event.get("critical", true)) and bool(slash_event.get("critical_blocked", false)), "Lucky Chant blocks critical hits")
	_assert_true(not ally.stats.battle_statuses.has("burn"), "Lucky Chant blocks additional effects")
	_assert_true(_log_has_blocked_by(level.battle_log, "effect_blocked", "lucky_chant"), "Lucky Chant logs blocked additional effect")
	level.free()


func _check_move_copying() -> void:
	var level: TacticsLevel = _fake_level()
	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "CopyAttacker", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn(DEFENDER_PATH, "CopyDefender", Vector3(1, 0, 0))
	var ally: FakePawn = _fake_pawn(ATTACKER_PATH, "CopyAlly", Vector3(0, 0, 1))
	level.player.add_child(attacker)
	level.player.add_child(ally)
	level.opponent.add_child(defender)

	var tackle := _move("tackle", PokemonMoveResource.CATEGORY_PHYSICAL, 60, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [
		{"family": "damage", "target": "hit_target"},
	])
	defender.stats.move_slots = [tackle]
	defender.stats.current_pp = [tackle.pp]
	defender.stats.record_move_use("tackle", 0)

	var copycat := _move("copycat", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [])
	copycat.unsupported_effect_tags = ["PMDC.Dungeon.MirrorMoveEvent, PMDC"]
	attacker.stats.move_slots = [copycat]
	attacker.stats.current_pp = [copycat.pp]
	var before_hp: int = defender.stats.curr_health
	resolver.execute(attacker, defender, 0, level)
	_assert_true(defender.stats.curr_health < before_hp, "Copycat-style move replays target's last move")
	_assert_true(_log_copied_id(level.battle_log, "copycat") == "tackle", "Copycat logs copied move id")
	_assert_true(not _log_has(level.battle_log, "effect_unsupported"), "implemented copy move does not log unsupported")
	level.battle_log.events.clear()

	var ember := _move("ember", PokemonMoveResource.CATEGORY_SPECIAL, 40, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [
		{"family": "damage", "target": "hit_target"},
	])
	defender.stats.move_slots = [ember]
	defender.stats.current_pp = [ember.pp]
	defender.stats.record_move_use("ember", 0)
	var sketch := _move("sketch", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [])
	sketch.unsupported_effect_tags = ["PMDC.Dungeon.SketchBattleEvent, PMDC"]
	attacker.stats.move_slots = [sketch]
	attacker.stats.current_pp = [sketch.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(attacker.stats.move_slots[0].move_id == "ember", "Sketch replaces the current slot with the observed move")
	_assert_true(_log_has(level.battle_log, "move_slot_replaced"), "Sketch logs slot replacement")
	level.battle_log.events.clear()

	defender.stats.curr_health = defender.stats.max_health
	defender.stats.battle_status = Stats.BattleStatus.ACTIVE
	ally.stats.move_slots = [tackle]
	ally.stats.current_pp = [tackle.pp]
	ally.stats.record_move_use("tackle", 0)
	var assist := _move("assist", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.SELF, PokemonMoveResource.TARGET_SELF, [])
	assist.unsupported_effect_tags = ["PMDC.Dungeon.MirrorMoveEvent, PMDC"]
	attacker.stats.move_slots = [assist]
	attacker.stats.current_pp = [assist.pp]
	before_hp = defender.stats.curr_health
	resolver.execute(attacker, attacker, 0, level)
	_assert_true(defender.stats.curr_health < before_hp, "Assist replays an ally's last move against a legal foe")
	_assert_true(_log_copied_id(level.battle_log, "assist") == "tackle", "Assist logs copied ally move")
	level.battle_log.events.clear()

	defender.stats.curr_health = defender.stats.max_health
	defender.stats.battle_status = Stats.BattleStatus.ACTIVE
	var nature_power := _move("nature_power", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.SELF, PokemonMoveResource.TARGET_SELF, [])
	nature_power.unsupported_effect_tags = ["PMDC.Dungeon.NatureMoveEvent, PMDC"]
	attacker.stats.move_slots = [nature_power]
	attacker.stats.current_pp = [nature_power.pp]
	before_hp = defender.stats.curr_health
	resolver.execute(attacker, attacker, 0, level)
	_assert_true(defender.stats.curr_health < before_hp, "Nature Power maps to a skirmish default damaging move")
	_assert_true(_log_copied_id(level.battle_log, "nature_power") == "tri_attack", "Nature Power logs Tri Attack as the mainline default")
	level.battle_log.events.clear()

	var metronome := _move("metronome", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.SELF, PokemonMoveResource.TARGET_SELF, [])
	metronome.unsupported_effect_tags = ["PMDC.Dungeon.RandomMoveEvent, PMDC"]
	attacker.stats.move_slots = [metronome]
	attacker.stats.current_pp = [metronome.pp]
	resolver.execute(attacker, attacker, 0, level)
	_assert_true(not _log_copied_id(level.battle_log, "metronome").is_empty(), "Metronome chooses and logs a deterministic random move")
	level.free()


func _check_ability_dependent_moves() -> void:
	var level: TacticsLevel = _fake_level()
	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "AbilityMoveUser", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn(DEFENDER_PATH, "AbilityMoveTarget", Vector3(1, 0, 0))
	var service := BattleIntrinsicService.new()
	level.player.add_child(attacker)
	level.opponent.add_child(defender)

	attacker.stats.set_temporary_intrinsics(["levitate"])
	defender.stats.set_temporary_intrinsics(["pressure"])
	var role_play := _move("role_play", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [])
	role_play.unsupported_effect_tags = ["PMDC.Dungeon.ReflectAbilityEvent, PMDC"]
	attacker.stats.move_slots = [role_play]
	attacker.stats.current_pp = [role_play.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(service.current_intrinsics(attacker.stats) == ["pressure"], "Role Play copies the target intrinsic to the user")
	_assert_true(_log_has(level.battle_log, "intrinsic_changed"), "Role Play logs intrinsic change")
	_assert_true(not _log_has(level.battle_log, "effect_unsupported"), "implemented ability move does not log unsupported")
	level.battle_log.events.clear()

	attacker.stats.set_temporary_intrinsics(["levitate"])
	defender.stats.set_temporary_intrinsics(["pressure"])
	var entrainment := _move("entrainment", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [])
	entrainment.unsupported_effect_tags = ["PMDC.Dungeon.ReflectAbilityEvent, PMDC"]
	attacker.stats.move_slots = [entrainment]
	attacker.stats.current_pp = [entrainment.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(service.current_intrinsics(defender.stats) == ["levitate"], "Entrainment copies the user intrinsic to the target")
	level.battle_log.events.clear()

	attacker.stats.set_temporary_intrinsics(["levitate"])
	defender.stats.set_temporary_intrinsics(["pressure"])
	var skill_swap := _move("skill_swap", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [])
	skill_swap.unsupported_effect_tags = ["PMDC.Dungeon.SwapAbilityEvent, PMDC"]
	attacker.stats.move_slots = [skill_swap]
	attacker.stats.current_pp = [skill_swap.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(service.current_intrinsics(attacker.stats) == ["pressure"], "Skill Swap gives the user the target intrinsic")
	_assert_true(service.current_intrinsics(defender.stats) == ["levitate"], "Skill Swap gives the target the user intrinsic")
	level.free()


func _check_status_dependent_moves() -> void:
	var level: TacticsLevel = _fake_level()
	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "StatusMoveUser", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn(DEFENDER_PATH, "StatusMoveTarget", Vector3(1, 0, 0))
	level.player.add_child(attacker)
	level.opponent.add_child(defender)

	attacker.stats.apply_battle_status("burn")
	var psycho_shift := _move("psycho_shift", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [])
	psycho_shift.unsupported_effect_tags = ["PMDC.Dungeon.TransferStatusEvent, PMDC"]
	attacker.stats.move_slots = [psycho_shift]
	attacker.stats.current_pp = [psycho_shift.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(not attacker.stats.battle_statuses.has("burn") and defender.stats.battle_statuses.has("burn"), "Psycho Shift transfers bad status to target")
	_assert_true(_log_has(level.battle_log, "status_transferred"), "Psycho Shift logs status transfer")
	level.battle_log.events.clear()

	attacker.stats.stat_stages = {}
	attacker.stats.battle_statuses = {}
	defender.stats.stat_stages = {}
	defender.stats.battle_statuses = {}
	attacker.stats.set_stat_stage("attack", 2)
	attacker.stats.apply_battle_status("aqua_ring")
	var baton_pass := _move("baton_pass", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [])
	baton_pass.unsupported_effect_tags = ["PMDC.Dungeon.TransferStatusEvent, PMDC"]
	attacker.stats.move_slots = [baton_pass]
	attacker.stats.current_pp = [baton_pass.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(defender.stats.get_stat_stage("attack") == 2, "Baton Pass transfers stat stages")
	_assert_true(defender.stats.battle_statuses.has("aqua_ring"), "Baton Pass copies portable statuses")
	level.battle_log.events.clear()

	var hyper_beam := _move("hyper_beam", PokemonMoveResource.CATEGORY_SPECIAL, 100, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [
		{"family": "damage", "target": "hit_target"},
	])
	hyper_beam.unsupported_effect_tags = ["PMDC.Dungeon.StatusStateBattleEvent, PMDC"]
	attacker.stats.move_slots = [hyper_beam]
	attacker.stats.current_pp = [hyper_beam.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(attacker.stats.battle_statuses.has("recharge"), "Hyper Beam applies recharge status")
	_assert_true(attacker.stats.consume_turn_skip_status().get("status_id", "") == "recharge", "Recharge status participates in turn-skip handling")
	_assert_true(int(attacker.stats.battle_statuses["recharge"].get("counter", 0)) == 2, "recharge outlasts the turn-start decrement so the skip check still sees it")
	attacker.stats.battle_statuses.erase("recharge")
	level.battle_log.events.clear()

	var previous_types: Array[String] = defender.stats.types.duplicate()
	defender.stats.types.clear()
	defender.stats.types.append("ghost")
	var normal_hit := _move("normal_hit", PokemonMoveResource.CATEGORY_PHYSICAL, 85, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [
		{"family": "damage", "target": "hit_target"},
	])
	attacker.stats.move_slots = [normal_hit]
	attacker.stats.current_pp = [normal_hit.pp]
	var immune_hp: int = defender.stats.curr_health
	resolver.execute(attacker, defender, 0, level)
	_assert_true(defender.stats.curr_health == immune_hp, "a normal move leaves a ghost untouched")
	_assert_true(_log_has_source(level.battle_log, "damage_prevented", "type_immunity"), "type immunity is reported instead of resolving silently")
	defender.stats.types.clear()
	for type_id in previous_types:
		defender.stats.types.append(String(type_id))
	level.battle_log.events.clear()

	var sticky_web := _move("sticky_web", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [])
	sticky_web.unsupported_effect_tags = ["PMDC.Dungeon.SetItemStickyEvent, PMDC"]
	attacker.stats.move_slots = [sticky_web]
	attacker.stats.current_pp = [sticky_web.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(defender.stats.battle_statuses.has("item_sticky"), "Sticky Web applies item-sticky battle flag")
	level.battle_log.events.clear()

	attacker.stats.battle_statuses = {}
	attacker.stats.curr_health = maxi(1, int(floor(float(attacker.stats.max_health) / 2.0)))
	attacker.stats.apply_battle_status("burn")
	var rest := _move("rest", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.SELF, PokemonMoveResource.TARGET_SELF, [])
	rest.unsupported_effect_tags = ["PMDC.Dungeon.RestEvent, PMDC"]
	attacker.stats.move_slots = [rest]
	attacker.stats.current_pp = [rest.pp]
	resolver.execute(attacker, attacker, 0, level)
	_assert_true(attacker.stats.curr_health == attacker.stats.max_health, "Rest restores HP to full")
	_assert_true(not attacker.stats.battle_statuses.has("burn") and attacker.stats.battle_statuses.has("sleep"), "Rest cures existing statuses and applies sleep")
	_assert_true(_log_has(level.battle_log, "healed") and _log_has(level.battle_log, "status_removed") and _log_has(level.battle_log, "status_applied"), "Rest logs heal, cure, and sleep")
	level.free()


func _check_item_dependent_moves() -> void:
	var level: TacticsLevel = _fake_level()
	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "ItemMoveUser", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn(DEFENDER_PATH, "ItemMoveTarget", Vector3(1, 0, 0))
	var charcoal: PokemonItemResource = PokemonItemService.load_item("held_charcoal")
	var magnet: PokemonItemResource = PokemonItemService.load_item("held_magnet")
	var oran: PokemonItemResource = PokemonItemService.load_item("berry_oran")
	level.player.add_child(attacker)
	level.opponent.add_child(defender)

	PokemonItemService.take_held_item(attacker.stats)
	PokemonItemService.give_held_item(defender.stats, charcoal)
	var covet := _move("covet", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [])
	covet.unsupported_effect_tags = ["PMDC.Dungeon.BegItemEvent, PMDC"]
	attacker.stats.move_slots = [covet]
	attacker.stats.current_pp = [covet.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(PokemonItemService.held_item_for(attacker.stats) == charcoal and PokemonItemService.held_item_for(defender.stats) == null, "Covet steals target held item")
	_assert_true(_log_has(level.battle_log, "held_item_stolen"), "Covet logs item steal")
	level.battle_log.events.clear()

	PokemonItemService.give_held_item(attacker.stats, magnet)
	PokemonItemService.give_held_item(defender.stats, charcoal)
	var bestow := _move("bestow", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [])
	bestow.unsupported_effect_tags = ["PMDC.Dungeon.BestowItemEvent, PMDC", "PMDC.Dungeon.LandItemEvent, PMDC"]
	attacker.stats.move_slots = [bestow]
	attacker.stats.current_pp = [bestow.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(PokemonItemService.held_item_for(attacker.stats) == null and PokemonItemService.held_item_for(defender.stats) == magnet, "Bestow passes user's held item to target")
	level.battle_log.events.clear()

	PokemonItemService.give_held_item(attacker.stats, charcoal)
	PokemonItemService.give_held_item(defender.stats, magnet)
	var switcheroo := _move("switcheroo", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.PROJECTILE, PokemonMoveResource.TARGET_FOE, [])
	switcheroo.unsupported_effect_tags = ["PMDC.Dungeon.SwitchHeldItemEvent, PMDC"]
	attacker.stats.move_slots = [switcheroo]
	attacker.stats.current_pp = [switcheroo.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(PokemonItemService.held_item_for(attacker.stats) == magnet and PokemonItemService.held_item_for(defender.stats) == charcoal, "Switcheroo swaps held items")
	level.battle_log.events.clear()

	PokemonItemService.give_held_item(attacker.stats, oran)
	PokemonItemService.consume_held_item(attacker.stats)
	var recycle := _move("recycle", PokemonMoveResource.CATEGORY_STATUS, 0, PokemonMoveResource.TacticalRangeKind.SELF, PokemonMoveResource.TARGET_SELF, [])
	recycle.unsupported_effect_tags = ["PMDC.Dungeon.ItemRestoreEvent, PMDC"]
	attacker.stats.move_slots = [recycle]
	attacker.stats.current_pp = [recycle.pp]
	resolver.execute(attacker, attacker, 0, level)
	_assert_true(PokemonItemService.held_item_for(attacker.stats) == oran and attacker.stats.last_consumed_item_id.is_empty(), "Recycle restores last consumed held item")
	level.battle_log.events.clear()

	PokemonItemService.give_held_item(defender.stats, charcoal)
	defender.stats.curr_health = defender.stats.max_health
	defender.stats.battle_status = Stats.BattleStatus.ACTIVE
	var knock_off := _move("knock_off", PokemonMoveResource.CATEGORY_PHYSICAL, 50, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [
		{"family": "damage", "target": "hit_target"},
	])
	attacker.stats.move_slots = [knock_off]
	attacker.stats.current_pp = [knock_off.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(PokemonItemService.held_item_for(defender.stats) == null, "Knock Off removes target held item after damage")
	_assert_true(_log_has(level.battle_log, "held_item_knocked_off"), "Knock Off logs held item removal")
	level.battle_log.events.clear()

	PokemonItemService.take_held_item(attacker.stats)
	PokemonItemService.give_held_item(defender.stats, magnet)
	defender.stats.curr_health = defender.stats.max_health
	defender.stats.battle_status = Stats.BattleStatus.ACTIVE
	var thief := _move("thief", PokemonMoveResource.CATEGORY_PHYSICAL, 40, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [
		{"family": "damage", "target": "hit_target"},
	])
	attacker.stats.move_slots = [thief]
	attacker.stats.current_pp = [thief.pp]
	resolver.execute(attacker, defender, 0, level)
	_assert_true(PokemonItemService.held_item_for(attacker.stats) == magnet and PokemonItemService.held_item_for(defender.stats) == null, "Thief steals target held item after damage")
	level.free()


func _screen_probe_damage(category: int, condition_id: String) -> int:
	var level: TacticsLevel = _fake_level()
	var attacker: FakePawn = _fake_pawn(ATTACKER_PATH, "ScreenProbeAttacker", Vector3.ZERO)
	var defender: FakePawn = _fake_pawn(DEFENDER_PATH, "ScreenProbeDefender", Vector3(1, 0, 0))
	level.player.add_child(attacker)
	level.opponent.add_child(defender)
	attacker.stats.level = 50
	attacker.stats.attack = 100
	attacker.stats.special_attack = 100
	defender.stats.defense = 50
	defender.stats.special_defense = 50
	if not condition_id.is_empty():
		level.set_team_battle_condition(condition_id, defender, {"counter": 10})
	var move := _move("screen_probe", category, 80, PokemonMoveResource.TacticalRangeKind.MELEE, PokemonMoveResource.TARGET_FOE, [
		{"family": "damage", "target": "hit_target"},
	])
	attacker.stats.move_slots = [move]
	attacker.stats.current_pp = [move.pp]
	resolver.execute(attacker, defender, 0, level)
	var amount: int = _damage_amount(level.battle_log, "screen_probe")
	level.free()
	return amount


func _fake_level() -> TacticsLevel:
	var level := TacticsLevel.new()
	level.player = TacticsPlayer.new()
	level.opponent = TacticsOpponent.new()
	level.battle_rng.seed = 123
	level.add_child(level.player)
	level.add_child(level.opponent)
	return level


func _fake_pawn(path: String, pawn_name: String, pos: Vector3) -> FakePawn:
	var instance: PokemonInstanceResource = load(path) as PokemonInstanceResource
	var pawn := FakePawn.new()
	pawn.name = pawn_name
	pawn.res = TacticsPawnResource.new()
	pawn.fake_tile = TacticsTile.new()
	pawn.fake_tile.position = pos
	pawn.add_child(pawn.fake_tile)
	pawn.stats = Stats.new()
	pawn.stats.init_from_pokemon(instance)
	pawn.add_child(pawn.stats)
	return pawn


func _move(move_id: String, category: int, power: int, range_kind: int, alignment: int, effects: Array[Dictionary]) -> PokemonMoveResource:
	var move := PokemonMoveResource.new()
	move.move_id = move_id
	move.name = move_id.capitalize()
	move.type = "normal"
	move.category = category
	move.base_power = power
	move.accuracy = PokemonMoveResource.ACCURACY_NEVER_MISS
	move.pp = 9
	move.tactical_range_kind = range_kind
	move.tactical_range_value = 1
	move.target_alignment = alignment
	move.effect_records = effects
	return move


func _log_has(log: BattleLog, kind: String) -> bool:
	return _count_events(log, kind) > 0


func _log_has_source(log: BattleLog, kind: String, source: String) -> bool:
	for event in log.events:
		if event.get("kind", "") == kind and event.get("source", "") == source:
			return true
	return false


func _damage_amount(log: BattleLog, move_id: String) -> int:
	for event in log.events:
		if event.get("kind", "") == "damage_dealt" and event.get("move_id", "") == move_id:
			return int(event.get("amount", 0))
	return 0


func _damage_amount_by_source(log: BattleLog, move_id: String, source: String) -> int:
	for event in log.events:
		if event.get("kind", "") == "damage_dealt" and event.get("move_id", "") == move_id and event.get("source", "") == source:
			return int(event.get("amount", 0))
	return 0


func _damage_event(log: BattleLog, move_id: String) -> Dictionary:
	for event in log.events:
		if event.get("kind", "") == "damage_dealt" and event.get("move_id", "") == move_id:
			return event
	return {}


func _log_has_blocked_by(log: BattleLog, kind: String, blocked_by: String) -> bool:
	for event in log.events:
		if event.get("kind", "") == kind and event.get("blocked_by", event.get("status_id", "")) == blocked_by:
			return true
	return false


func _log_copied_id(log: BattleLog, move_id: String) -> String:
	for event in log.events:
		if event.get("kind", "") == "move_copied" and event.get("move_id", "") == move_id:
			return String(event.get("copied_move_id", ""))
	return ""


func _count_events(log: BattleLog, kind: String) -> int:
	var count: int = 0
	for event in log.events:
		if event.get("kind", "") == kind:
			count += 1
	return count
