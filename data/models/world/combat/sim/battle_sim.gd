class_name BattleSim
extends RefCounted

const STAT_IDS: Array[String] = ["attack", "defense", "special_attack", "special_defense", "speed", "accuracy", "evasion"]
const SLOT_COUNT: int = 4
const STATUS_IDS: Array[String] = [
	"burn", "poison", "poison_toxic", "paralyze", "sleep", "freeze", "confuse", "flinch",
	"leech_seed", "trap", "taunted", "encore", "disable", "recharge", "in_love", "protect",
	"charging", "immobilized", "paused", "nightmare", "ingrain", "aqua_ring", "heal_block",
	"focus_energy", "perish_song", "yawning", "endure", "decoy", "reflect", "light_screen",
	"safeguard", "lucky_chant", "mist", "minimized", "torment", "sleepless", "exposed",
	"sure_shot", "rooted", "enraged", "destiny_bond",
	"airborne", "underground", "underwater", "vanished",
]
const TRAP_IDS: Array[String] = ["bind", "wrap", "clamp", "fire_spin", "sand_tomb", "whirlpool", "magma_storm", "infestation"]
const SCREEN_IDS: Array[String] = ["reflect", "light_screen", "safeguard", "lucky_chant", "mist"]
const TURN_SKIP_ORDER: Array[String] = ["flinch", "sleep", "freeze", "immobilized", "paused", "recharge"]
const EXPIRE_AT_TURN_START: Array[String] = ["protect", "endure", "destiny_bond", "enraged"]
const RAMPAGE_IDS: Array[String] = ["outrage", "thrash", "petal_dance"]
const HAZARD_IDS: Array[String] = ["spikes", "toxic_spikes", "stealth_rock", "sticky_web"]
const SPIKE_FRACTIONS: Array[int] = [8, 6, 4]
const STAGE_ACCURACY_TABLE: Array[float] = [3.0 / 9.0, 3.0 / 8.0, 3.0 / 7.0, 3.0 / 6.0, 3.0 / 5.0, 3.0 / 4.0, 1.0, 4.0 / 3.0, 5.0 / 3.0, 2.0, 7.0 / 3.0, 8.0 / 3.0, 3.0]
const MULTI_HIT_WEIGHTS: Array[int] = [35, 35, 15, 15]
const TYPE_CHART_PATH: String = "res://data/models/pokemon/generated/types/type_chart.tres"

const S_BURN: int = 0
const S_POISON: int = 1
const S_POISON_TOXIC: int = 2
const S_PARALYZE: int = 3
const S_SLEEP: int = 4
const S_FREEZE: int = 5
const S_CONFUSE: int = 6
const S_FLINCH: int = 7
const S_LEECH_SEED: int = 8
const S_TRAP: int = 9
const S_TAUNTED: int = 10
const S_ENCORE: int = 11
const S_DISABLE: int = 12
const S_RECHARGE: int = 13
const S_IN_LOVE: int = 14
const S_PROTECT: int = 15
const S_CHARGING: int = 16
const S_IMMOBILIZED: int = 17
const S_PAUSED: int = 18
const S_NIGHTMARE: int = 19
const S_INGRAIN: int = 20
const S_AQUA_RING: int = 21
const S_HEAL_BLOCK: int = 22
const S_FOCUS_ENERGY: int = 23
const S_PERISH_SONG: int = 24
const S_YAWNING: int = 25
const S_ENDURE: int = 26
const S_DECOY: int = 27
const S_REFLECT: int = 28
const S_LIGHT_SCREEN: int = 29
const S_SAFEGUARD: int = 30
const S_LUCKY_CHANT: int = 31
const S_MIST: int = 32
const S_MINIMIZED: int = 33
const S_TORMENT: int = 34
const S_SLEEPLESS: int = 35
const S_EXPOSED: int = 36
const S_SURE_SHOT: int = 37
const S_ROOTED: int = 38
const S_ENRAGED: int = 39
const S_DESTINY_BOND: int = 40
const S_INVULNERABLE_FIRST: int = 41

const KNOWN_ABILITIES: Array[String] = ["poison_heal", "magic_guard", "levitate", "no_guard", "wonder_guard", "sturdy", "moxie", "shield_dust", "sheer_force", "serene_grace", "liquid_ooze", "rock_head", "early_bird", "synchronize", "parental_bond", "skill_link", "compound_eyes", "hustle", "sand_veil", "snow_cloak", "analytic", "rivalry", "quick_feet", "surge_surfer", "prankster", "gale_wings", "chlorophyll", "swift_swim", "sand_rush", "slush_rush", "cute_charm", "illuminate", "cursed_body", "effect_spore", "flame_body", "poison_point", "static", "justified", "rattled", "weak_armor", "anger_point", "berserk", "gooey", "tangling_hair", "rough_skin", "iron_barbs", "intimidate"]
const AB_POISON_HEAL: int = 0
const AB_MAGIC_GUARD: int = 1
const AB_LEVITATE: int = 2
const AB_NO_GUARD: int = 3
const AB_WONDER_GUARD: int = 4
const AB_STURDY: int = 5
const AB_MOXIE: int = 6
const AB_SHIELD_DUST: int = 7
const AB_SHEER_FORCE: int = 8
const AB_SERENE_GRACE: int = 9
const AB_LIQUID_OOZE: int = 10
const AB_ROCK_HEAD: int = 11
const AB_EARLY_BIRD: int = 12
const AB_SYNCHRONIZE: int = 13
const AB_PARENTAL_BOND: int = 14
const AB_SKILL_LINK: int = 15
const AB_COMPOUND_EYES: int = 16
const AB_HUSTLE: int = 17
const AB_SAND_VEIL: int = 18
const AB_SNOW_CLOAK: int = 19
const AB_ANALYTIC: int = 20
const AB_RIVALRY: int = 21
const AB_QUICK_FEET: int = 22
const AB_SURGE_SURFER: int = 23
const AB_PRANKSTER: int = 24
const AB_GALE_WINGS: int = 25
const AB_CHLOROPHYLL: int = 26
const AB_SWIFT_SWIM: int = 27
const AB_SAND_RUSH: int = 28
const AB_SLUSH_RUSH: int = 29
const AB_CUTE_CHARM: int = 30
const AB_ILLUMINATE: int = 31
const AB_CURSED_BODY: int = 32
const AB_EFFECT_SPORE: int = 33
const AB_FLAME_BODY: int = 34
const AB_POISON_POINT: int = 35
const AB_STATIC: int = 36
const AB_JUSTIFIED: int = 37
const AB_RATTLED: int = 38
const AB_WEAK_ARMOR: int = 39
const AB_ANGER_POINT: int = 40
const AB_BERSERK: int = 41
const AB_GOOEY: int = 42
const AB_TANGLING_HAIR: int = 43
const AB_ROUGH_SKIN: int = 44
const AB_IRON_BARBS: int = 45
const AB_INTIMIDATE: int = 46

const STATUS_COUNT: int = 45
const SCREEN_COUNT: int = 5
const HAZARD_COUNT: int = 4

const U_X: int = 0
const U_Z: int = 1
const U_HP: int = 2
const U_MAXHP: int = 3
const U_ATK: int = 4
const U_DEF: int = 5
const U_SPA: int = 6
const U_SPD: int = 7
const U_SPE: int = 8
const U_LEVEL: int = 9
const U_TEAM: int = 10
const U_MOVEMENT: int = 11
const U_ALIVE: int = 12
const U_INSERT: int = 13
const U_TIE: int = 14
const U_REST: int = 15
const U_TYPE1: int = 16
const U_TYPE2: int = 17
const U_ABILITY: int = 18
const U_ITEM: int = 19
const U_SPEEDMUL: int = 20
const U_ACTED: int = 21
const U_LASTSLOT: int = 22
const U_LASTMOVE: int = 23
const U_STREAK: int = 24
const U_TOXIC: int = 25
const U_LEECHSRC: int = 26
const U_TRAPFRAC: int = 27
const U_DISABLE_SLOT: int = 28
const U_ENCORE_SLOT: int = 29
const U_GENDER: int = 30
const U_SCOUNT: int = 31
const U_CHARGE_SLOT: int = 32
const U_STAGE: int = 33
const U_MOVE: int = 40
const U_PP: int = 44
const U_STATUS: int = 48
const U_STRIDE: int = U_STATUS + STATUS_COUNT

const F_WEATHER: int = 0
const F_WEATHER_ROUNDS: int = 1
const F_TERRAIN: int = 2
const F_TERRAIN_ROUNDS: int = 3
const F_ROUND: int = 4
const F_RESULT: int = 5
const F_RNG_LO: int = 6
const F_RNG_HI: int = 7
const F_QLEN: int = 8
const F_QPOS: int = 9
const F_ACTIVE: int = 10
const F_PLIES: int = 11
const F_SCREEN: int = 12
const F_QUEUE: int = F_SCREEN + 2 * SCREEN_COUNT

const M_KIND: int = 0
const M_RANGE: int = 1
const M_CAT: int = 2
const M_POWER: int = 3
const M_ACC: int = 4
const M_PP: int = 5
const M_TYPE: int = 6
const M_STRIKE: int = 7
const M_ALIGN: int = 8
const M_DAMAGING: int = 9
const M_FORMULA: int = 10
const M_SELFFAINT: int = 11
const M_RECHARGE: int = 12
const M_MULTI5: int = 13
const M_HAZARD: int = 14
const M_SURE: int = 15
const M_CHARGE: int = 16
const M_INVULN: int = 17
const M_SUNSKIP: int = 18
const M_CHARGE_STAT: int = 19
const M_CHARGE_DELTA: int = 20
const M_TIPDASH: int = 21
const M_STRIDE: int = 22

const R_FAMILY: int = 0
const R_TARGET: int = 1
const R_CHANCE: int = 2
const R_STATUS: int = 3
const R_STAT: int = 4
const R_DELTA: int = 5
const R_FRAC_I: int = 6
const R_MAXHP: int = 7
const R_AMOUNT: int = 8
const R_DIVISOR: int = 9
const R_PERCENT: int = 10
const R_REQ_DAMAGE: int = 11
const R_COND: int = 12
const R_ADDITIONAL: int = 13
const R_FRAC_F: int = 14
const R_COUNTER: int = 15

const FAM_SKIP: int = -1
const FAM_DAMAGE: int = 0
const FAM_STATUS: int = 1
const FAM_STAT: int = 2
const FAM_RECOIL: int = 3
const FAM_DRAIN: int = 4
const FAM_HEAL: int = 5
const FAM_STATUS_REMOVE: int = 6
const FAM_CURE: int = 7
const FAM_FIXED: int = 8
const FAM_LEVEL: int = 9
const FAM_PERCENT: int = 10
const FAM_HP_TO_1: int = 11
const FAM_PP: int = 12
const FAM_FIELD: int = 13
const FAM_WEATHER_STAT: int = 14

const RESULT_ONGOING: int = 0
const RESULT_TEAM0: int = 1
const RESULT_TEAM1: int = 2
const RESULT_DRAW: int = 3

var unit_count: int = 0
var tile_count: int = 0
var max_rounds: int = 60
var state_size: int = 0
var field_off: int = 0
var board_off: int = 0
var hazard_off: int = 0

var tile_keys: Array[Vector3i] = []
var tile_index: Dictionary = {}
var neighbors: PackedInt32Array = PackedInt32Array()
var tile_x: PackedInt32Array = PackedInt32Array()
var tile_z: PackedInt32Array = PackedInt32Array()

var move_res: Array[PokemonMoveResource] = []
var move_ids: PackedStringArray = PackedStringArray()
var move_info: PackedInt32Array = PackedInt32Array()
var move_records: Array = []
var move_lookup: Dictionary = {}

var ability_names: PackedStringArray = PackedStringArray()
var ability_lookup: Dictionary = {}
var unit_names: PackedStringArray = PackedStringArray()
var name_order: PackedInt32Array = PackedInt32Array()
var unit_types: Array = []

var type_chart: TypeChartResource = null
var type_names: PackedStringArray = PackedStringArray()
var type_lookup: Dictionary = {}
var eff_table: PackedFloat32Array = PackedFloat32Array()
var type_count: int = 0

var trace_damage: PackedInt32Array = PackedInt32Array()
var trace_enabled: bool = false
var trace_hits: int = 0
var trace_misses: int = 0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _damage: DamageResolver = DamageResolver.new()
var _intrinsics: BattleIntrinsicService = BattleIntrinsicService.new()
var _sa: Stats = null
var _sb: Stats = null
var _sa_stages: Dictionary = {}
var _sb_stages: Dictionary = {}
var _sa_status: Dictionary = {}
var _sb_status: Dictionary = {}
var _sa_slugs: Array[String] = [""]
var _sb_slugs: Array[String] = [""]
var _bfs_dist: PackedInt32Array = PackedInt32Array()
var _bfs_queue: PackedInt32Array = PackedInt32Array()
var _targets: PackedInt32Array = PackedInt32Array()
var _status_counter: PackedInt32Array = PackedInt32Array()
var _status_lookup: Dictionary = {}
var _weather_ids: PackedStringArray = PackedStringArray()
var _terrain_ids: PackedStringArray = PackedStringArray()
var _bad_status: PackedByteArray = PackedByteArray()
var _major_status: PackedByteArray = PackedByteArray()
var _non_reapply: PackedByteArray = PackedByteArray()
var _synchronize_status: PackedByteArray = PackedByteArray()
var _type_immunity: Array = []
var _flying_index: int = -1
var _ground_index: int = -1
var _dark_index: int = -1
var _bug_index: int = -1
var _ghost_index: int = -1
var _weather_sandstorm: int = -1
var _weather_hail: int = -1
var _terrain_electric: int = -1
var _terrain_grassy: int = -1
var ability_code: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	_sa = Stats.new()
	_sb = Stats.new()
	_sa.pokemon_instance = null
	_sb.pokemon_instance = null
	_sa.stat_stages = _sa_stages
	_sb.stat_stages = _sb_stages
	_sa.battle_statuses = _sa_status
	_sb.battle_statuses = _sb_status
	_sa.intrinsic_override_active = true
	_sb.intrinsic_override_active = true
	_sa.temporary_intrinsic_slugs = _sa_slugs
	_sb.temporary_intrinsic_slugs = _sb_slugs
	for i in range(STATUS_IDS.size()):
		_status_lookup[STATUS_IDS[i]] = i
	for trap_id in TRAP_IDS:
		_status_lookup[trap_id] = _status_lookup["trap"]
	_status_lookup["toxic"] = _status_lookup["poison_toxic"]
	_status_lookup["confusion"] = _status_lookup["confuse"]
	_status_lookup["asleep"] = _status_lookup["sleep"]
	_status_lookup["cringe"] = _status_lookup["flinch"]
	_status_lookup["substitute"] = _status_lookup["decoy"]
	_status_counter.resize(STATUS_COUNT)
	for i in range(STATUS_COUNT):
		var payload: Dictionary = Stats.DEFAULT_STATUS_PAYLOADS.get(STATUS_IDS[i], {})
		_status_counter[i] = int(payload.get("counter", 0))
	_status_counter[_status_lookup["trap"]] = 5
	_bad_status.resize(STATUS_COUNT)
	_major_status.resize(STATUS_COUNT)
	_non_reapply.resize(STATUS_COUNT)
	_synchronize_status.resize(STATUS_COUNT)
	for i in range(STATUS_COUNT):
		_synchronize_status[i] = 1 if BattleIntrinsicService.SYNCHRONIZE_STATUSES.has(STATUS_IDS[i]) else 0
		_bad_status[i] = 1 if BattleActionResolver.BAD_STATUS_IDS.has(STATUS_IDS[i]) else 0
		_major_status[i] = 1 if BattleStateOps.MAJOR_STATUSES.has(STATUS_IDS[i]) else 0
		_non_reapply[i] = 1 if BattleStateOps.NON_REAPPLY_STATUSES.has(STATUS_IDS[i]) else 0
	for trap_id in TRAP_IDS:
		if BattleActionResolver.BAD_STATUS_IDS.has(trap_id):
			_bad_status[_status_lookup["trap"]] = 1
	for weather_id in BattleWeatherService.WEATHER_IDS:
		_weather_ids.append(weather_id)
	for terrain_id in BattleWeatherService.TERRAIN_IDS:
		_terrain_ids.append(terrain_id)
	_weather_sandstorm = int(_weather_ids.find("sandstorm"))
	_weather_hail = int(_weather_ids.find("hail"))
	_terrain_electric = int(_terrain_ids.find("electric_terrain"))
	_terrain_grassy = int(_terrain_ids.find("grassy_terrain"))
	_load_type_chart()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _sa != null and is_instance_valid(_sa):
			_sa.free()
		if _sb != null and is_instance_valid(_sb):
			_sb.free()


func _load_type_chart() -> void:
	type_chart = load(TYPE_CHART_PATH) as TypeChartResource
	if type_chart == null:
		return
	type_count = type_chart.type_list.size()
	for i in range(type_count):
		type_names.append(String(type_chart.type_list[i]))
		type_lookup[String(type_chart.type_list[i])] = i
	_flying_index = int(type_lookup.get("flying", -1))
	_ground_index = int(type_lookup.get("ground", -1))
	_dark_index = int(type_lookup.get("dark", -1))
	_bug_index = int(type_lookup.get("bug", -1))
	_ghost_index = int(type_lookup.get("ghost", -1))
	eff_table.resize(type_count * type_count * type_count)
	for a in range(type_count):
		for b in range(type_count):
			for c in range(type_count):
				eff_table[(a * type_count + b) * type_count + c] = type_chart.get_effectiveness_dual(type_names[a], type_names[b], type_names[c])
	_type_immunity.resize(STATUS_COUNT)
	for i in range(STATUS_COUNT):
		var immune: PackedInt32Array = PackedInt32Array()
		for type_id in BattleStateOps.STATUS_TYPE_IMMUNITY.get(STATUS_IDS[i], []):
			if type_lookup.has(String(type_id)):
				immune.append(int(type_lookup[String(type_id)]))
		_type_immunity[i] = immune


func setup_from_level(level: TacticsLevel) -> PackedInt32Array:
	if level == null:
		return PackedInt32Array()
	_build_board(level)
	var pawns: Array[TacticsPawn] = _ordered_pawns(level)
	unit_count = pawns.size()
	unit_names.resize(unit_count)
	unit_types.resize(unit_count)
	move_res.clear()
	move_ids.clear()
	move_info.clear()
	move_records.clear()
	move_lookup.clear()
	ability_names.clear()
	ability_lookup.clear()
	ability_code.clear()
	_compute_offsets()
	var d: PackedInt32Array = PackedInt32Array()
	d.resize(state_size)
	d.fill(0)
	for i in range(tile_count):
		d[board_off + i] = -1
	for i in range(unit_count):
		_ingest_pawn(d, i, pawns[i], level)
	_build_name_order()
	var scheduler_rng := RandomNumberGenerator.new()
	scheduler_rng.seed = level.battle_seed
	for i in range(unit_count):
		d[i * U_STRIDE + U_TIE] = int(scheduler_rng.randi() & 0x7FFFFFFF)
	d[field_off + F_WEATHER] = -1
	d[field_off + F_TERRAIN] = -1
	d[field_off + F_ACTIVE] = -1
	_set_rng_state(d, level.battle_rng.state)
	_start(d)
	return d


func capture(level: TacticsLevel) -> PackedInt32Array:
	if level == null or unit_count == 0:
		return setup_from_level(level)
	var pawns: Array[TacticsPawn] = _ordered_pawns(level)
	var d: PackedInt32Array = PackedInt32Array()
	d.resize(state_size)
	d.fill(0)
	for i in range(tile_count):
		d[board_off + i] = -1
	for i in range(mini(unit_count, pawns.size())):
		_ingest_pawn(d, i, pawns[i], level)
	d[field_off + F_WEATHER] = int(_weather_ids.find(level.current_weather()))
	d[field_off + F_TERRAIN] = int(_terrain_ids.find(level.current_terrain()))
	d[field_off + F_ACTIVE] = -1
	d[field_off + F_ROUND] = level.round_index
	_set_rng_state(d, level.battle_rng.state)
	for team in range(2):
		for s in range(SCREEN_COUNT):
			d[field_off + F_SCREEN + team * SCREEN_COUNT + s] = 0
	return d


func duplicate_state(d: PackedInt32Array) -> PackedInt32Array:
	return d.duplicate()


func clone_deep(d: PackedInt32Array) -> PackedInt32Array:
	return d.duplicate()


func share_state(d: PackedInt32Array) -> PackedInt32Array:
	return d


func apply_battle_start(d: PackedInt32Array) -> void:
	for i in range(unit_count):
		if d[i * U_STRIDE + U_ALIVE] != 1:
			continue
		var slug: String = _ability_of(d, i)
		if slug == "intimidate":
			for other in range(unit_count):
				if other == i or d[other * U_STRIDE + U_ALIVE] != 1 or d[other * U_STRIDE + U_TEAM] == d[i * U_STRIDE + U_TEAM]:
					continue
				_change_stage(d, other, 0, -1, i)
		elif BattleIntrinsicService.BATTLE_START_WEATHER.has(slug):
			d[field_off + F_WEATHER] = int(_weather_ids.find(String(BattleIntrinsicService.BATTLE_START_WEATHER[slug])))
			d[field_off + F_WEATHER_ROUNDS] = BattleWeatherService.DEFAULT_ROUNDS
		elif BattleIntrinsicService.TERRAIN_BY_SURGE.has(slug):
			d[field_off + F_TERRAIN] = int(_terrain_ids.find(String(BattleIntrinsicService.TERRAIN_BY_SURGE[slug])))
			d[field_off + F_TERRAIN_ROUNDS] = 5


func turn_queue(d: PackedInt32Array) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for i in range(d[field_off + F_QLEN]):
		out.append(d[field_off + F_QUEUE + i])
	return out


func active_unit(d: PackedInt32Array) -> int:
	return d[field_off + F_ACTIVE]


func result(d: PackedInt32Array) -> int:
	return d[field_off + F_RESULT]


func is_over(d: PackedInt32Array) -> bool:
	return d[field_off + F_RESULT] != RESULT_ONGOING


func round_index(d: PackedInt32Array) -> int:
	return d[field_off + F_ROUND]


func unit_hp(d: PackedInt32Array, unit: int) -> int:
	return d[unit * U_STRIDE + U_HP]


func unit_position(d: PackedInt32Array, unit: int) -> Vector3i:
	return Vector3i(d[unit * U_STRIDE + U_X], 0, d[unit * U_STRIDE + U_Z])


func unit_team(d: PackedInt32Array, unit: int) -> int:
	return d[unit * U_STRIDE + U_TEAM]


func unit_alive(d: PackedInt32Array, unit: int) -> bool:
	return d[unit * U_STRIDE + U_ALIVE] == 1


func legal_actions(d: PackedInt32Array, unit: int) -> Array:
	var packed: PackedInt32Array = legal_actions_packed(d, unit)
	var out: Array = []
	out.resize(packed.size())
	for i in range(packed.size()):
		var code: int = packed[i]
		out[i] = Vector3i(code >> 12, ((code >> 6) & 63) - 1, (code & 63) - 1)
	return out


func decode_action(code: int) -> Vector3i:
	return Vector3i(code >> 12, ((code >> 6) & 63) - 1, (code & 63) - 1)


func encode_action(action: Vector3i) -> int:
	return (action.x << 12) | ((action.y + 1) << 6) | (action.z + 1)


func apply_packed(d: PackedInt32Array, code: int) -> PackedInt32Array:
	return apply(d, Vector3i(code >> 12, ((code >> 6) & 63) - 1, (code & 63) - 1))


func legal_actions_packed(d: PackedInt32Array, unit: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if unit < 0 or unit >= unit_count or d[unit * U_STRIDE + U_ALIVE] != 1:
		return out
	var base: int = unit * U_STRIDE
	var team: int = d[base + U_TEAM]
	var slot_move: PackedInt32Array = PackedInt32Array()
	var slot_index: PackedInt32Array = PackedInt32Array()
	var slot_kind: PackedInt32Array = PackedInt32Array()
	var slot_distance: PackedInt32Array = PackedInt32Array()
	for slot in range(SLOT_COUNT):
		var mi: int = d[base + U_MOVE + slot]
		if mi < 0 or d[base + U_PP + slot] <= 0:
			continue
		if _move_blocked(d, unit, mi, slot):
			continue
		slot_move.append(mi)
		slot_index.append(slot)
		slot_kind.append(move_info[mi * M_STRIDE + M_KIND])
		slot_distance.append(_range_distance(d, unit, mi))
	var candidate: PackedInt32Array = PackedInt32Array()
	var candidate_x: PackedInt32Array = PackedInt32Array()
	var candidate_z: PackedInt32Array = PackedInt32Array()
	var candidate_mask: PackedInt32Array = PackedInt32Array()
	for other in range(unit_count):
		var obase: int = other * U_STRIDE
		if d[obase + U_ALIVE] != 1:
			continue
		var mask: int = 0
		for si in range(slot_move.size()):
			var info: int = slot_move[si] * M_STRIDE
			if _alignment_allows(unit, other, team, d[obase + U_TEAM], move_info[info + M_ALIGN], move_info[info + M_DAMAGING]):
				mask |= 1 << si
		if mask == 0:
			continue
		candidate.append(other)
		candidate_x.append(d[obase + U_X])
		candidate_z.append(d[obase + U_Z])
		candidate_mask.append(mask)
	var destinations: PackedInt32Array = reachable_tiles(d, unit)
	var slot_total: int = slot_move.size()
	var candidate_total: int = candidate.size()
	for di in range(destinations.size()):
		var dest: int = destinations[di]
		var ox: int = tile_x[dest]
		var oz: int = tile_z[dest]
		var found: bool = false
		for ci in range(candidate_total):
			var dx: int = absi(candidate_x[ci] - ox)
			var dz: int = absi(candidate_z[ci] - oz)
			var man: int = dx + dz
			var cheb: int = dx if dx > dz else dz
			var mask: int = candidate_mask[ci]
			for si in range(slot_total):
				if mask & (1 << si) == 0:
					continue
				var kind: int = slot_kind[si]
				var reach: int = slot_distance[si]
				var ok: bool = false
				if kind == 1:
					ok = man == 1
				elif kind == 3:
					ok = man > 0 and cheb <= reach
				elif kind == 2:
					ok = (dx == 0 or dz == 0) and man >= 1 and man <= reach
				elif kind == 5:
					ok = man <= reach
				else:
					ok = man == 0
				if not ok:
					continue
				out.append((dest << 12) | ((slot_index[si] + 1) << 6) | (candidate[ci] + 1))
				found = true
		if not found:
			out.append(dest << 12)
	if out.is_empty():
		out.append(int(tile_index.get(Vector3i(d[base + U_X], 0, d[base + U_Z]), 0)) << 12)
	return out


func legal_actions_active(d: PackedInt32Array) -> Array:
	return legal_actions(d, d[field_off + F_ACTIVE])


func legal_actions_active_packed(d: PackedInt32Array) -> PackedInt32Array:
	return legal_actions_packed(d, d[field_off + F_ACTIVE])


func apply(d: PackedInt32Array, action: Vector3i) -> PackedInt32Array:
	if d[field_off + F_RESULT] != RESULT_ONGOING:
		return d
	_rng.state = _get_rng_state(d)
	var unit: int = d[field_off + F_ACTIVE]
	if unit >= 0:
		_take_turn(d, unit, action)
	_complete_and_advance(d)
	_set_rng_state(d, _rng.state)
	return d


func random_playout(d: PackedInt32Array, playout_rng: RandomNumberGenerator) -> int:
	var guard: int = 0
	while d[field_off + F_RESULT] == RESULT_ONGOING and guard < 4096:
		var unit: int = d[field_off + F_ACTIVE]
		if unit < 0:
			break
		var actions: PackedInt32Array = legal_actions_packed(d, unit)
		if actions.is_empty():
			break
		apply_packed(d, actions[playout_rng.randi_range(0, actions.size() - 1)])
		guard += 1
	return d[field_off + F_RESULT]


func reachable_tiles(d: PackedInt32Array, unit: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var base: int = unit * U_STRIDE
	var origin: int = int(tile_index.get(Vector3i(d[base + U_X], 0, d[base + U_Z]), -1))
	if origin < 0:
		return out
	out.append(origin)
	if _is_trapped(d, unit):
		return out
	var movement: int = d[base + U_MOVEMENT]
	var team: int = d[base + U_TEAM]
	_bfs_dist.fill(-1)
	_bfs_dist[origin] = 0
	var head: int = 0
	var tail: int = 0
	_bfs_queue[tail] = origin
	tail += 1
	while head < tail:
		var current: int = _bfs_queue[head]
		head += 1
		var dist: int = _bfs_dist[current]
		if dist >= movement:
			continue
		for n in range(4):
			var next: int = neighbors[current * 4 + n]
			if next < 0 or _bfs_dist[next] >= 0:
				continue
			var occupant: int = d[board_off + next]
			if occupant >= 0 and d[occupant * U_STRIDE + U_TEAM] != team:
				continue
			_bfs_dist[next] = dist + 1
			_bfs_queue[tail] = next
			tail += 1
			if occupant < 0:
				out.append(next)
	return out


func _build_board(level: TacticsLevel) -> void:
	tile_keys.clear()
	tile_index.clear()
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	var sorted: Array = keys.keys()
	sorted.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return a.x < b.x if a.x != b.x else a.z < b.z)
	for key in sorted:
		tile_index[key] = tile_keys.size()
		tile_keys.append(key)
	tile_count = tile_keys.size()
	tile_x.resize(tile_count)
	tile_z.resize(tile_count)
	for i in range(tile_count):
		tile_x[i] = tile_keys[i].x
		tile_z[i] = tile_keys[i].z
	neighbors.resize(tile_count * 4)
	var offsets: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	for i in range(tile_count):
		for n in range(4):
			neighbors[i * 4 + n] = int(tile_index.get(tile_keys[i] + offsets[n], -1))
	_bfs_dist.resize(tile_count)
	_bfs_queue.resize(tile_count)


func _compute_offsets() -> void:
	field_off = unit_count * U_STRIDE
	board_off = field_off + F_QUEUE + unit_count
	hazard_off = board_off + tile_count
	state_size = hazard_off + tile_count * HAZARD_COUNT
	_targets.resize(unit_count)


func _ordered_pawns(level: TacticsLevel) -> Array[TacticsPawn]:
	var out: Array[TacticsPawn] = []
	for team_node in [level.player, level.opponent]:
		if team_node == null:
			continue
		for child in team_node.get_children():
			if child is TacticsPawn:
				out.append(child as TacticsPawn)
	return out


func _ingest_pawn(d: PackedInt32Array, index: int, pawn: TacticsPawn, level: TacticsLevel) -> void:
	var stats: Stats = pawn.stats
	var base: int = index * U_STRIDE
	var key: Vector3i = Targeting._tile_key(pawn.get_tile())
	d[base + U_X] = key.x
	d[base + U_Z] = key.z
	d[base + U_HP] = stats.curr_health
	d[base + U_MAXHP] = stats.max_health
	d[base + U_ATK] = stats.attack
	d[base + U_DEF] = stats.defense
	d[base + U_SPA] = stats.special_attack
	d[base + U_SPD] = stats.special_defense
	d[base + U_SPE] = stats.speed
	d[base + U_LEVEL] = stats.level
	d[base + U_TEAM] = 0 if level.player != null and level.player.is_ancestor_of(pawn) else 1
	d[base + U_MOVEMENT] = stats.movement
	d[base + U_ALIVE] = 1 if stats.is_active() else 0
	d[base + U_INSERT] = index
	d[base + U_SPEEDMUL] = int(round(stats.battle_speed_multiplier * 1000.0))
	d[base + U_GENDER] = stats.gender
	d[base + U_LASTMOVE] = -1
	d[base + U_LASTSLOT] = -1
	d[base + U_DISABLE_SLOT] = -1
	d[base + U_ENCORE_SLOT] = -1
	d[base + U_CHARGE_SLOT] = -1
	d[base + U_LEECHSRC] = -1
	d[base + U_TRAPFRAC] = 8
	d[base + U_TYPE1] = int(type_lookup.get(String(stats.types[0]).to_lower(), 0)) if stats.types.size() > 0 else 0
	d[base + U_TYPE2] = int(type_lookup.get(String(stats.types[1]).to_lower(), 0)) if stats.types.size() > 1 else 0
	var slugs: Array[String] = BattleIntrinsicService.natural_slugs_static(stats)
	d[base + U_ABILITY] = _ability_id(slugs[0] if slugs.size() > 0 else "")
	d[base + U_ITEM] = -1
	unit_names[index] = String(pawn.name)
	var types: Array[String] = []
	for t in stats.types:
		types.append(String(t))
	unit_types[index] = types
	for slot in range(SLOT_COUNT):
		if slot < stats.move_slots.size() and stats.move_slots[slot] != null:
			d[base + U_MOVE + slot] = _move_id(stats.move_slots[slot])
			d[base + U_PP + slot] = stats.current_pp[slot] if slot < stats.current_pp.size() else stats.move_slots[slot].pp
		else:
			d[base + U_MOVE + slot] = -1
			d[base + U_PP + slot] = 0
	for s in range(STAT_IDS.size()):
		d[base + U_STAGE + s] = stats.get_stat_stage(STAT_IDS[s])
	var count: int = 0
	for status_id in stats.battle_statuses.keys():
		var si: int = int(_status_lookup.get(String(status_id), -1))
		if si < 0 or d[base + U_STATUS + si] != 0:
			continue
		var payload: Variant = stats.battle_statuses[status_id]
		var counter: int = int((payload as Dictionary).get("counter", -1)) if payload is Dictionary else -1
		d[base + U_STATUS + si] = counter if counter > 0 else -1
		count += 1
	d[base + U_SCOUNT] = count
	if d[base + U_ALIVE] == 1:
		var tile: int = int(tile_index.get(key, -1))
		if tile >= 0:
			d[board_off + tile] = index


func _build_name_order() -> void:
	var order: Array = []
	for i in range(unit_count):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return unit_names[a] < unit_names[b])
	name_order.resize(unit_count)
	for i in range(unit_count):
		name_order[i] = order[i]


func _ability_id(slug: String) -> int:
	var key: String = slug.strip_edges().to_lower()
	if key.is_empty() or key == "none":
		return -1
	if ability_lookup.has(key):
		return int(ability_lookup[key])
	var index: int = ability_names.size()
	ability_names.append(key)
	ability_lookup[key] = index
	ability_code.append(int(KNOWN_ABILITIES.find(key)))
	return index


func _move_id(move: PokemonMoveResource) -> int:
	if move_lookup.has(move.move_id):
		return int(move_lookup[move.move_id])
	var index: int = move_res.size()
	move_lookup[move.move_id] = index
	move_res.append(move)
	move_ids.append(move.move_id)
	move_info.resize((index + 1) * M_STRIDE)
	var info: int = index * M_STRIDE
	move_info[info + M_KIND] = Targeting.effective_range_kind(move)
	move_info[info + M_RANGE] = move.tactical_range_value
	move_info[info + M_CAT] = move.category
	move_info[info + M_POWER] = move.base_power
	move_info[info + M_ACC] = move.accuracy
	move_info[info + M_PP] = move.pp
	move_info[info + M_TYPE] = int(type_lookup.get(move.type.to_lower(), 0))
	move_info[info + M_STRIKE] = maxi(1, move.strike_count)
	move_info[info + M_ALIGN] = move.target_alignment
	move_info[info + M_DAMAGING] = 1 if move.is_damaging() else 0
	move_info[info + M_SELFFAINT] = 1 if BattleMoveSpecials.SELF_FAINT_MOVES.has(move.move_id) else 0
	move_info[info + M_RECHARGE] = 1 if BattleMoveSpecials.RECHARGE_MOVES.has(move.move_id) else 0
	move_info[info + M_HAZARD] = int(HAZARD_IDS.find(move.move_id))
	move_info[info + M_SURE] = 1 if move.is_sure_hit() else 0
	move_info[info + M_CHARGE] = 1 if BattleMoveSpecials.CHARGING.has(move.move_id) else 0
	move_info[info + M_INVULN] = -1
	move_info[info + M_SUNSKIP] = 0
	move_info[info + M_CHARGE_STAT] = -1
	move_info[info + M_CHARGE_DELTA] = 0
	move_info[info + M_TIPDASH] = 1 if BattleMoveSpecials.TIP_POWER_DASH_MOVES.has(move.move_id) else 0
	if move_info[info + M_CHARGE] == 1:
		var rule: Dictionary = BattleMoveSpecials.CHARGING[move.move_id]
		move_info[info + M_INVULN] = int(BattleMoveSpecials.INVULNERABLE_STATUSES.find(String(rule.get("invulnerable", ""))))
		move_info[info + M_SUNSKIP] = 1 if bool(rule.get("sun_skips", false)) else 0
		if rule.has("charge_stat"):
			move_info[info + M_CHARGE_STAT] = int(STAT_IDS.find(String((rule["charge_stat"] as Array)[0])))
			move_info[info + M_CHARGE_DELTA] = int((rule["charge_stat"] as Array)[1])
	var has_variant: bool = false
	for tag in move.unsupported_effect_tags:
		if BattleActionResolver.DAMAGE_VARIANT_TAGS.has(tag):
			has_variant = true
	var formula: bool = false
	if move.is_damaging():
		if move_info[info + M_SELFFAINT] == 1:
			formula = true
		elif has_variant:
			formula = false
		elif move.effect_records.is_empty():
			formula = true
		else:
			for record in move.effect_records:
				if String(record.get("family", "")) == "damage":
					formula = true
	move_info[info + M_FORMULA] = 1 if formula else 0
	var multi5: bool = false
	for record in move.effect_records:
		if String(record.get("family", "")) == "multi_hit" and int((record.get("params", {}) as Dictionary).get("hit_count", 0)) == 5:
			multi5 = true
	move_info[info + M_MULTI5] = 1 if multi5 else 0
	move_records.append(_compile_records(move))
	return index


func _compile_records(move: PokemonMoveResource) -> Array:
	var out: Array = []
	for record in move.effect_records:
		var family: String = String(record.get("family", ""))
		var code: int = FAM_SKIP
		match family:
			"damage": code = FAM_DAMAGE
			"status": code = FAM_STATUS
			"stat_stage": code = FAM_STAT
			"recoil": code = FAM_RECOIL
			"drain": code = FAM_DRAIN
			"heal": code = FAM_HEAL
			"status_remove": code = FAM_STATUS_REMOVE
			"cure_statuses": code = FAM_CURE
			"fixed_damage": code = FAM_FIXED
			"level_damage": code = FAM_LEVEL
			"percent_damage": code = FAM_PERCENT
			"hp_to_1": code = FAM_HP_TO_1
			"pp_damage": code = FAM_PP
			"field_condition": code = FAM_FIELD
			"weather_stat_stage": code = FAM_WEATHER_STAT
		var entry: Array = []
		entry.resize(16)
		entry[R_FAMILY] = code
		entry[R_TARGET] = 1 if String(record.get("target", "hit_target")) == "self" else 0
		entry[R_CHANCE] = int(record.get("chance", 100))
		entry[R_STATUS] = int(_status_lookup.get(String(record.get("status_id", "")), -1))
		entry[R_STAT] = int(STAT_IDS.find(String(record.get("stat", ""))))
		entry[R_DELTA] = int(record.get("delta", 0))
		entry[R_FRAC_I] = int(record.get("fraction", 0)) if code == FAM_RECOIL else 0
		entry[R_MAXHP] = 1 if bool(record.get("max_hp", true)) else 0
		entry[R_AMOUNT] = int(record.get("amount", 0))
		entry[R_DIVISOR] = int(record.get("hp_divisor", 0))
		entry[R_PERCENT] = int(round(float(record.get("percent", 0.0)) * 10000.0))
		entry[R_REQ_DAMAGE] = 1 if bool(record.get("require_damage", false)) else 0
		entry[R_COND] = _condition_code(String(record.get("condition_id", "")))
		entry[R_ADDITIONAL] = 1 if (record.has("wrapped_source_event") or (move.is_damaging() and record.has("chance") and int(record.get("chance", 100)) < 100)) else 0
		entry[R_FRAC_F] = int(round(float(record.get("fraction", 0.5)) * 10000.0)) if code == FAM_DRAIN else 0
		entry[R_COUNTER] = int(record.get("weather_delta", record.get("counter", 0)))
		if code == FAM_STATUS and entry[R_STATUS] < 0:
			entry[R_FAMILY] = FAM_SKIP
		if code == FAM_STAT and entry[R_STAT] < 0:
			entry[R_FAMILY] = FAM_SKIP
		out.append(entry)
	if out.is_empty() and move.is_damaging() and move_info[(move_res.size() - 1) * M_STRIDE + M_FORMULA] == 1:
		var synthetic: Array = []
		synthetic.resize(16)
		for i in range(16):
			synthetic[i] = 0
		synthetic[R_FAMILY] = FAM_DAMAGE
		synthetic[R_CHANCE] = 100
		synthetic[R_STATUS] = -1
		synthetic[R_STAT] = -1
		synthetic[R_MAXHP] = 1
		synthetic[R_COND] = -1
		out.append(synthetic)
	return out


func _condition_code(condition_id: String) -> int:
	if condition_id.is_empty():
		return -1
	var weather: int = int(_weather_ids.find(BattleWeatherService.normalize(condition_id)))
	if weather >= 0:
		return weather
	var terrain: int = int(_terrain_ids.find(condition_id))
	if terrain >= 0:
		return 100 + terrain
	return -1


func _start(d: PackedInt32Array) -> void:
	_rng.state = _get_rng_state(d)
	_build_queue(d)
	d[field_off + F_ROUND] = d[field_off + F_ROUND] + 1
	_tick_weather(d)
	d[field_off + F_ACTIVE] = -1
	_activate_next(d)
	_set_rng_state(d, _rng.state)


func _build_queue(d: PackedInt32Array) -> void:
	_apply_speed_modifiers(d)
	var living: Array = []
	for i in range(unit_count):
		var base: int = i * U_STRIDE
		if d[base + U_REST] > 0:
			d[base + U_REST] = d[base + U_REST] - 1
			continue
		if d[base + U_ALIVE] == 1:
			living.append(i)
	living.sort_custom(func(a: int, b: int) -> bool: return _queue_less(d, a, b))
	for i in range(living.size()):
		d[field_off + F_QUEUE + i] = living[i]
	d[field_off + F_QLEN] = living.size()
	d[field_off + F_QPOS] = 0
	for i in range(unit_count):
		d[i * U_STRIDE + U_ACTED] = 0


func _queue_less(d: PackedInt32Array, a: int, b: int) -> bool:
	var sa: int = _speed_of(d, a)
	var sb: int = _speed_of(d, b)
	if sa != sb:
		return sa > sb
	var ta: int = d[a * U_STRIDE + U_TEAM]
	var tb: int = d[b * U_STRIDE + U_TEAM]
	if ta != tb:
		return ta < tb
	var ia: int = d[a * U_STRIDE + U_INSERT]
	var ib: int = d[b * U_STRIDE + U_INSERT]
	if ia != ib:
		return ia < ib
	return d[a * U_STRIDE + U_TIE] < d[b * U_STRIDE + U_TIE]


func _speed_of(d: PackedInt32Array, unit: int) -> int:
	var base: int = unit * U_STRIDE
	var value: int = maxi(1, int(floor(float(d[base + U_SPE]) * _stage_multiplier(d[base + U_STAGE + 4]))))
	return maxi(1, int(floor(float(value) * float(d[base + U_SPEEDMUL]) / 1000.0)))


func _stage_multiplier(stage: int) -> float:
	var clamped: int = clampi(stage, -6, 6)
	if clamped >= 0:
		return float(2 + clamped) / 2.0
	return 2.0 / float(2 - clamped)


func _apply_speed_modifiers(d: PackedInt32Array) -> void:
	var weather: int = d[field_off + F_WEATHER]
	var weather_id: String = _weather_ids[weather] if weather >= 0 else ""
	for i in range(unit_count):
		var base: int = i * U_STRIDE
		var multiplier: float = 1.0
		var slug: String = _ability_of(d, i)
		if slug == "quick_feet" and _has_major(d, i):
			multiplier *= 1.5
		elif BattleIntrinsicService.WEATHER_SPEED_INTRINSICS.has(slug) and String(BattleIntrinsicService.WEATHER_SPEED_INTRINSICS[slug]) == weather_id:
			multiplier *= 2.0
		elif slug == "surge_surfer" and d[field_off + F_TERRAIN] == _terrain_electric:
			multiplier *= 2.0
		d[base + U_SPEEDMUL] = int(round(multiplier * 1000.0))


func _activate_next(d: PackedInt32Array) -> void:
	while true:
		var found: int = -1
		while d[field_off + F_QPOS] < d[field_off + F_QLEN]:
			var candidate: int = d[field_off + F_QUEUE + d[field_off + F_QPOS]]
			d[field_off + F_QPOS] = d[field_off + F_QPOS] + 1
			if d[candidate * U_STRIDE + U_ALIVE] == 1:
				found = candidate
				break
		if found < 0:
			if _battle_over(d):
				d[field_off + F_RESULT] = _winner(d)
				d[field_off + F_ACTIVE] = -1
				return
			if d[field_off + F_ROUND] >= max_rounds:
				d[field_off + F_RESULT] = RESULT_DRAW
				d[field_off + F_ACTIVE] = -1
				return
			_build_queue(d)
			d[field_off + F_ROUND] = d[field_off + F_ROUND] + 1
			_tick_weather(d)
			_tick_conditions(d)
			continue
		d[field_off + F_ACTIVE] = found
		if _turn_start(d, found):
			d[found * U_STRIDE + U_ACTED] = 1
			continue
		return


func _battle_over(d: PackedInt32Array) -> bool:
	var teams: int = 0
	var seen0: bool = false
	var seen1: bool = false
	for i in range(unit_count):
		if d[i * U_STRIDE + U_ALIVE] != 1:
			continue
		if d[i * U_STRIDE + U_TEAM] == 0:
			seen0 = true
		else:
			seen1 = true
	teams = (1 if seen0 else 0) + (1 if seen1 else 0)
	return teams <= 1


func _winner(d: PackedInt32Array) -> int:
	var seen0: bool = false
	var seen1: bool = false
	for i in range(unit_count):
		if d[i * U_STRIDE + U_ALIVE] != 1:
			continue
		if d[i * U_STRIDE + U_TEAM] == 0:
			seen0 = true
		else:
			seen1 = true
	if seen0 and not seen1:
		return RESULT_TEAM0
	if seen1 and not seen0:
		return RESULT_TEAM1
	return RESULT_DRAW


func _complete_and_advance(d: PackedInt32Array) -> void:
	var unit: int = d[field_off + F_ACTIVE]
	if unit >= 0:
		d[unit * U_STRIDE + U_ACTED] = 1
	d[field_off + F_PLIES] = d[field_off + F_PLIES] + 1
	if _battle_over(d):
		d[field_off + F_RESULT] = _winner(d)
		d[field_off + F_ACTIVE] = -1
		return
	_activate_next(d)


func _turn_start(d: PackedInt32Array, unit: int) -> bool:
	var base: int = unit * U_STRIDE
	_expire_statuses(d, unit)
	_status_turn_effects(d, unit)
	if d[base + U_ALIVE] != 1:
		return true
	_decrement_counters(d, unit)
	if d[base + U_ALIVE] != 1:
		return true
	return _consume_turn_skip(d, unit)


func _expire_statuses(d: PackedInt32Array, unit: int) -> void:
	for status_id in EXPIRE_AT_TURN_START:
		_remove_status(d, unit, int(_status_lookup[status_id]))


func _status_turn_effects(d: PackedInt32Array, unit: int) -> void:
	var base: int = unit * U_STRIDE
	if d[base + U_SCOUNT] > 0:
		if _hs(d, unit, S_BURN):
			_status_damage(d, unit, 8, 1)
		if _hs(d, unit, S_POISON):
			if _abc(d, unit) == AB_POISON_HEAL:
				_heal(d, unit, maxi(1, d[base + U_MAXHP] / 8))
			else:
				_status_damage(d, unit, 16, 1)
		if _hs(d, unit, S_POISON_TOXIC):
			if _abc(d, unit) == AB_POISON_HEAL:
				_heal(d, unit, maxi(1, d[base + U_MAXHP] / 8))
			else:
				var stage: int = maxi(1, d[base + U_TOXIC])
				_status_damage(d, unit, 16, stage)
				d[base + U_TOXIC] = stage + 1
		if _hs(d, unit, S_LEECH_SEED):
			var drained: int = _status_damage(d, unit, 12, 1)
			var source: int = d[base + U_LEECHSRC]
			if drained > 0 and source >= 0 and source != unit and d[source * U_STRIDE + U_ALIVE] == 1:
				_heal(d, source, drained)
		if _hs(d, unit, S_INGRAIN):
			_heal(d, unit, maxi(1, d[base + U_MAXHP] / 6))
		if _hs(d, unit, S_AQUA_RING):
			_heal(d, unit, maxi(1, d[base + U_MAXHP] / 8))
		if _hs(d, unit, S_TRAP) and d[base + U_ALIVE] == 1:
			_status_damage(d, unit, maxi(1, d[base + U_TRAPFRAC]), 1)
		if _hs(d, unit, S_NIGHTMARE):
			if _hs(d, unit, S_SLEEP):
				_status_damage(d, unit, 4, 1)
			else:
				_remove_status(d, unit, S_NIGHTMARE)
		if _hs(d, unit, S_PERISH_SONG) and d[base + U_ALIVE] == 1:
			var left: int = d[base + U_STATUS + S_PERISH_SONG]
			if left <= 1:
				_damage_unit(d, unit, d[base + U_HP], -1)
				_remove_status(d, unit, S_PERISH_SONG)
			else:
				d[base + U_STATUS + S_PERISH_SONG] = left - 1
		if _hs(d, unit, S_YAWNING) and d[base + U_STATUS + S_YAWNING] <= 1:
			_remove_status(d, unit, S_YAWNING)
			_apply_status(d, unit, unit, S_SLEEP, -1, true)
	if d[field_off + F_TERRAIN] == _terrain_grassy and _is_grounded(d, unit) and d[base + U_ALIVE] == 1 and d[base + U_HP] < d[base + U_MAXHP]:
		_heal(d, unit, maxi(1, d[base + U_MAXHP] / 16))
	_weather_chip(d, unit)


func _weather_chip(d: PackedInt32Array, unit: int) -> void:
	var weather: int = d[field_off + F_WEATHER]
	if weather < 0 or d[unit * U_STRIDE + U_ALIVE] != 1:
		return
	var weather_id: String = _weather_ids[weather]
	if weather_id != "sandstorm" and weather_id != "hail":
		return
	var rule: Dictionary = BattleWeatherService.RULES[weather_id]
	for type_id in rule.get("chip_immune_types", []):
		if _has_type(d, unit, String(type_id)):
			return
	for slug in rule.get("chip_immune_intrinsics", []):
		if _ability_of(d, unit) == String(slug):
			return
	_status_damage(d, unit, BattleWeatherService.CHIP_FRACTION, 1)


func _decrement_counters(d: PackedInt32Array, unit: int) -> void:
	var base: int = unit * U_STRIDE
	if d[base + U_SCOUNT] <= 0:
		return
	for si in range(STATUS_COUNT):
		var value: int = d[base + U_STATUS + si]
		if value <= 0:
			continue
		var next: int = value - 1
		if next <= 0:
			_remove_status(d, unit, si)
		else:
			d[base + U_STATUS + si] = next


func _consume_turn_skip(d: PackedInt32Array, unit: int) -> bool:
	var base: int = unit * U_STRIDE
	if d[base + U_SCOUNT] <= 0:
		return false
	for status_id in TURN_SKIP_ORDER:
		var si: int = int(_status_lookup[status_id])
		if d[base + U_STATUS + si] == 0:
			continue
		if status_id == "flinch":
			_remove_status(d, unit, si)
		return true
	return false


func _take_turn(d: PackedInt32Array, unit: int, action: Vector3i) -> void:
	var base: int = unit * U_STRIDE
	var dest: int = action.x
	if dest >= 0 and dest < tile_count:
		var origin: int = int(tile_index.get(Vector3i(d[base + U_X], 0, d[base + U_Z]), -1))
		if dest != origin and d[board_off + dest] < 0:
			if origin >= 0:
				d[board_off + origin] = -1
			d[board_off + dest] = unit
			d[base + U_X] = tile_keys[dest].x
			d[base + U_Z] = tile_keys[dest].z
			_trigger_hazards(d, unit, dest)
	if d[base + U_ALIVE] != 1:
		return
	if action.y >= 0 and action.z >= 0:
		_run_move(d, unit, action.y, action.z)


func _run_move(d: PackedInt32Array, attacker: int, slot: int, declared: int) -> void:
	var base: int = attacker * U_STRIDE
	var mi: int = d[base + U_MOVE + slot]
	if mi < 0 or d[base + U_PP + slot] <= 0:
		return
	if d[declared * U_STRIDE + U_ALIVE] != 1:
		return
	if _move_blocked(d, attacker, mi, slot):
		return
	if _status_blocks_move(d, attacker, mi):
		return
	var count: int = _expand_targets(d, attacker, declared, mi)
	if count <= 0:
		return
	var info: int = mi * M_STRIDE
	var move: PokemonMoveResource = move_res[mi]
	if d[field_off + F_WEATHER] >= 0 and BattleWeatherService.blocks_move(_weather_ids[d[field_off + F_WEATHER]], move):
		return
	d[base + U_PP + slot] = maxi(0, d[base + U_PP + slot] - 1)
	d[base + U_STREAK] = d[base + U_STREAK] + 1 if d[base + U_LASTMOVE] == mi else 1
	d[base + U_LASTMOVE] = mi
	d[base + U_LASTSLOT] = slot
	if move_info[info + M_CHARGE] == 1 and _charge_holds(d, attacker, mi, slot):
		return
	var hits: int = _hit_count(d, attacker, mi)
	for hit in range(hits):
		for t in range(count):
			var target: int = _targets[t]
			if d[target * U_STRIDE + U_ALIVE] != 1:
				continue
			_resolve_one(d, attacker, target, mi, hit)
	if move_info[info + M_SELFFAINT] == 1 and d[base + U_ALIVE] == 1:
		_damage_unit(d, attacker, d[base + U_HP], -1)
	if move_info[info + M_RECHARGE] == 1 and d[base + U_ALIVE] == 1:
		_set_status(d, attacker, S_RECHARGE, 2)
	if move_info[info + M_HAZARD] >= 0:
		_place_hazard(d, attacker, move_info[info + M_HAZARD])


func _charge_holds(d: PackedInt32Array, unit: int, mi: int, slot: int) -> bool:
	var base: int = unit * U_STRIDE
	var info: int = mi * M_STRIDE
	if _hs(d, unit, S_CHARGING):
		_remove_status(d, unit, S_CHARGING)
		d[base + U_CHARGE_SLOT] = -1
		for i in range(BattleMoveSpecials.INVULNERABLE_STATUSES.size()):
			_remove_status(d, unit, S_INVULNERABLE_FIRST + i)
		return false
	if move_info[info + M_SUNSKIP] == 1 and d[field_off + F_WEATHER] >= 0 and _weather_ids[d[field_off + F_WEATHER]] == "sunny":
		return false
	_set_status(d, unit, S_CHARGING, -1)
	d[base + U_CHARGE_SLOT] = slot
	if move_info[info + M_INVULN] >= 0:
		_set_status(d, unit, S_INVULNERABLE_FIRST + move_info[info + M_INVULN], -1)
	if move_info[info + M_CHARGE_STAT] >= 0:
		_change_stage(d, unit, move_info[info + M_CHARGE_STAT], move_info[info + M_CHARGE_DELTA], -1)
	return true


func _invulnerable(d: PackedInt32Array, target: int, mi: int) -> bool:
	var base: int = target * U_STRIDE
	if d[base + U_SCOUNT] <= 0:
		return false
	for i in range(BattleMoveSpecials.INVULNERABLE_STATUSES.size()):
		if d[base + U_STATUS + S_INVULNERABLE_FIRST + i] == 0:
			continue
		if (BattleMoveSpecials.INVULNERABLE_EXCEPTIONS[BattleMoveSpecials.INVULNERABLE_STATUSES[i]] as Array).has(move_ids[mi]):
			continue
		return true
	return false


func _move_blocked(d: PackedInt32Array, unit: int, mi: int, slot: int) -> bool:
	var base: int = unit * U_STRIDE
	if d[base + U_SCOUNT] <= 0:
		return false
	if _hs(d, unit, S_TAUNTED) and move_info[mi * M_STRIDE + M_CAT] == PokemonMoveResource.CATEGORY_STATUS:
		return true
	if _hs(d, unit, S_DISABLE) and d[base + U_DISABLE_SLOT] == slot:
		return true
	if _hs(d, unit, S_ENCORE) and d[base + U_ENCORE_SLOT] >= 0 and d[base + U_ENCORE_SLOT] != slot:
		return true
	if _hs(d, unit, S_TORMENT) and d[base + U_LASTMOVE] == mi:
		return true
	if _hs(d, unit, S_CHARGING) and d[base + U_CHARGE_SLOT] >= 0 and d[base + U_CHARGE_SLOT] != slot:
		return true
	return false


func _status_blocks_move(d: PackedInt32Array, unit: int, mi: int) -> bool:
	var base: int = unit * U_STRIDE
	if d[base + U_SCOUNT] <= 0:
		return false
	if _hs(d, unit, S_IN_LOVE) and _rng.randf() < 0.5:
		return true
	if _hs(d, unit, S_CONFUSE) and _rng.randi_range(0, 1) == 0:
		_damage_unit(d, unit, maxi(1, int(floor(float(d[base + U_MAXHP]) / 8.0))), -1)
		return true
	return false


func _expand_targets(d: PackedInt32Array, attacker: int, declared: int, mi: int) -> int:
	var info: int = mi * M_STRIDE
	var kind: int = move_res[mi].tactical_range_kind
	var base: int = attacker * U_STRIDE
	var origin: Vector3i = Vector3i(d[base + U_X], 0, d[base + U_Z])
	var team: int = d[base + U_TEAM]
	var align: int = move_info[info + M_ALIGN]
	var damaging: int = move_info[info + M_DAMAGING]
	var count: int = 0
	if kind == PokemonMoveResource.TacticalRangeKind.LINE:
		var target_key: Vector3i = Vector3i(d[declared * U_STRIDE + U_X], 0, d[declared * U_STRIDE + U_Z])
		var delta: Vector3i = target_key - origin
		var direction: Vector3i = Vector3i.ZERO
		if delta.x != 0 and delta.z == 0:
			direction = Vector3i(signi(delta.x), 0, 0)
		elif delta.z != 0 and delta.x == 0:
			direction = Vector3i(0, 0, signi(delta.z))
		if direction == Vector3i.ZERO:
			return 0
		var distance: int = _range_distance(d, attacker, mi)
		for oi in range(unit_count):
			var other: int = name_order[oi]
			if d[other * U_STRIDE + U_ALIVE] != 1:
				continue
			var dx: int = d[other * U_STRIDE + U_X] - origin.x
			var dz: int = d[other * U_STRIDE + U_Z] - origin.z
			if dx * direction.z != dz * direction.x:
				continue
			var step: int = dx * direction.x + dz * direction.z
			if step < 1 or step > distance:
				continue
			if _alignment_allows(attacker, other, team, d[other * U_STRIDE + U_TEAM], align, damaging):
				_targets[count] = other
				count += 1
		return count
	if kind == PokemonMoveResource.TacticalRangeKind.AREA:
		var area_distance: int = _range_distance(d, attacker, mi)
		for oi in range(unit_count):
			var other: int = name_order[oi]
			if d[other * U_STRIDE + U_ALIVE] != 1:
				continue
			var okey: Vector3i = Vector3i(d[other * U_STRIDE + U_X], 0, d[other * U_STRIDE + U_Z])
			if absi(okey.x - origin.x) + absi(okey.z - origin.z) > area_distance:
				continue
			if _alignment_allows(attacker, other, team, d[other * U_STRIDE + U_TEAM], align, damaging):
				_targets[count] = other
				count += 1
		return count
	if _alignment_allows(attacker, declared, team, d[declared * U_STRIDE + U_TEAM], align, damaging):
		_targets[0] = declared
		return 1
	return 0


func _hit_count(d: PackedInt32Array, attacker: int, mi: int) -> int:
	var info: int = mi * M_STRIDE
	var base_hits: int = move_info[info + M_STRIKE]
	if base_hits == 1 and move_info[info + M_DAMAGING] == 1 and _abc(d, attacker) == AB_PARENTAL_BOND:
		return 2
	if base_hits != 5:
		return base_hits
	if move_info[info + M_MULTI5] != 1:
		return base_hits
	if _abc(d, attacker) == AB_SKILL_LINK:
		return 5
	var roll: int = _rng.randi_range(1, 100)
	var total: int = 0
	for i in range(MULTI_HIT_WEIGHTS.size()):
		total += MULTI_HIT_WEIGHTS[i]
		if roll <= total:
			return 2 + i
	return 5


func _resolve_one(d: PackedInt32Array, attacker: int, target: int, mi: int, hit_index: int) -> void:
	var info: int = mi * M_STRIDE
	var move: PokemonMoveResource = move_res[mi]
	var abase: int = attacker * U_STRIDE
	var tbase: int = target * U_STRIDE
	var accuracy_multiplier: float = _accuracy_multiplier(d, attacker, target, mi)
	var weather_accuracy: int = -1
	if d[field_off + F_WEATHER] >= 0:
		weather_accuracy = BattleWeatherService.accuracy_override(_weather_ids[d[field_off + F_WEATHER]], move)
	var guaranteed: bool = move_info[info + M_SURE] == 1 or _abc(d, attacker) == AB_NO_GUARD or _abc(d, target) == AB_NO_GUARD
	if _invulnerable(d, target, mi):
		if trace_enabled:
			trace_misses += 1
		return
	var hit: bool = true
	if guaranteed:
		hit = true
	elif weather_accuracy >= 0:
		hit = weather_accuracy >= 100 or _rng.randf() * 100.0 < float(weather_accuracy) * accuracy_multiplier
	elif is_equal_approx(accuracy_multiplier, 1.0):
		hit = AccuracyResolver.roll(move, _rng)
	else:
		hit = _rng.randf() * 100.0 < float(move_info[info + M_ACC]) * accuracy_multiplier
	if not hit:
		if trace_enabled:
			trace_misses += 1
		return
	if trace_enabled:
		trace_hits += 1
	if attacker != target and _hs(d, target, S_PROTECT):
		return
	var effectiveness: float = _effectiveness(move_info[info + M_TYPE], d[tbase + U_TYPE1], d[tbase + U_TYPE2])
	if _abc(d, target) == AB_WONDER_GUARD and move_info[info + M_DAMAGING] == 1 and effectiveness <= 1.0 and effectiveness > 0.0:
		return
	if move_info[info + M_DAMAGING] == 1 and effectiveness <= 0.0:
		return
	var stab: bool = move_info[info + M_TYPE] == d[abase + U_TYPE1] or move_info[info + M_TYPE] == d[abase + U_TYPE2]
	var damage: int = 0
	var critical: bool = false
	if move_info[info + M_FORMULA] == 1:
		_hydrate(d, attacker, target, mi)
		var extra: float = _extra_multiplier(d, attacker, target, mi, effectiveness, hit_index, move)
		var outcome: Dictionary = {
			"crit_bonus": _intrinsics.crit_stage_bonus(_sa) + (2 if _hs(d, attacker, S_FOCUS_ENERGY) else 0),
			"ignore_defender_stages": _intrinsics.ignores_stages(_sa),
			"ignore_attacker_stages": _intrinsics.ignores_stages(_sb),
		}
		var critical_blocked: bool = _team_screen(d, d[tbase + U_TEAM], 3) > 0 or _intrinsics.blocks_critical(_sb)
		damage = _damage.calculate_damage(_sa, _sb, move, effectiveness, stab, extra, _rng, outcome, critical_blocked)
		critical = bool(outcome.get("is_critical", false))
	var damage_done: int = 0
	if damage > 0:
		damage_done = _apply_damage(d, attacker, target, mi, damage)
		if damage_done > 0:
			_after_damage(d, attacker, target, mi, damage_done, critical)
	for record in move_records[mi]:
		_apply_record(d, record, attacker, target, mi, damage_done)
	if damage_done > 0 and _hs(d, target, S_ENRAGED) and attacker != target:
		_change_stage(d, target, 0, 1, attacker)


func _after_damage(d: PackedInt32Array, attacker: int, target: int, mi: int, damage_done: int, critical: bool) -> void:
	if attacker == target:
		return
	var slug: int = _abc(d, target)
	if slug < 0:
		return
	var move: PokemonMoveResource = move_res[mi]
	var contact: bool = move.has_flag("contact")
	var tbase: int = target * U_STRIDE
	match slug:
		AB_CUTE_CHARM:
			if contact and _rng.randf() * 100.0 < 35.0 and d[attacker * U_STRIDE + U_GENDER] != 2 and d[tbase + U_GENDER] != 2 and d[attacker * U_STRIDE + U_GENDER] != d[tbase + U_GENDER]:
				_apply_status(d, target, attacker, S_IN_LOVE, mi, false)
		AB_ILLUMINATE:
			if d[tbase + U_ALIVE] == 1:
				var _roll: float = _rng.randf()
		AB_CURSED_BODY:
			if _rng.randf() * 100.0 < 30.0:
				_apply_status(d, target, attacker, S_DISABLE, mi, false)
		AB_EFFECT_SPORE:
			if contact and _rng.randf() * 100.0 < 30.0:
				var pick: int = _rng.randi_range(0, 2)
				_apply_status(d, target, attacker, [S_POISON, S_PARALYZE, S_SLEEP][pick], mi, false)
		AB_JUSTIFIED:
			if move_info[mi * M_STRIDE + M_TYPE] == _dark_index:
				_change_stage(d, target, 0, 1, -1)
		AB_RATTLED:
			if move_info[mi * M_STRIDE + M_TYPE] == _bug_index or move_info[mi * M_STRIDE + M_TYPE] == _ghost_index or move_info[mi * M_STRIDE + M_TYPE] == _dark_index:
				_change_stage(d, target, 4, 1, -1)
		AB_WEAK_ARMOR:
			if move_info[mi * M_STRIDE + M_CAT] == PokemonMoveResource.CATEGORY_PHYSICAL:
				_change_stage(d, target, 1, -1, -1)
				_change_stage(d, target, 4, 2, -1)
		AB_ANGER_POINT:
			if critical:
				_change_stage(d, target, 0, 12, -1)
		AB_BERSERK:
			var half: int = int(floor(float(d[tbase + U_MAXHP]) / 2.0))
			if d[tbase + U_HP] > 0 and d[tbase + U_HP] + damage_done > half and d[tbase + U_HP] <= half:
				_change_stage(d, target, 2, 1, -1)
		AB_GOOEY, AB_TANGLING_HAIR:
			if contact:
				_change_stage(d, attacker, 4, -1, -1)
		AB_ROUGH_SKIN, AB_IRON_BARBS:
			if contact:
				_damage_unit(d, attacker, maxi(1, int(floor(float(d[attacker * U_STRIDE + U_MAXHP]) / 8.0))), -1)
		AB_FLAME_BODY, AB_POISON_POINT, AB_STATIC:
			if move_info[mi * M_STRIDE + M_CAT] == PokemonMoveResource.CATEGORY_PHYSICAL and _rng.randf() * 100.0 < 30.0:
				var contact_status: int = S_BURN if slug == AB_FLAME_BODY else (S_POISON if slug == AB_POISON_POINT else S_PARALYZE)
				_apply_status(d, target, attacker, contact_status, mi, false)


func _apply_damage(d: PackedInt32Array, attacker: int, target: int, mi: int, amount: int) -> int:
	var tbase: int = target * U_STRIDE
	var value: int = amount
	if _abc(d, target) == AB_STURDY and d[tbase + U_HP] == d[tbase + U_MAXHP] and value >= d[tbase + U_HP]:
		value = maxi(0, d[tbase + U_HP] - 1)
	if _hs(d, target, S_ENDURE) and value >= d[tbase + U_HP] and d[tbase + U_HP] > 1:
		value = d[tbase + U_HP] - 1
	if move_ids[mi] == "false_swipe":
		value = mini(value, maxi(0, d[tbase + U_HP] - 1))
	if value <= 0:
		return 0
	return _damage_unit(d, target, value, attacker)


func _damage_unit(d: PackedInt32Array, unit: int, amount: int, source: int) -> int:
	var base: int = unit * U_STRIDE
	if d[base + U_ALIVE] != 1 or amount <= 0:
		return 0
	var before: int = d[base + U_HP]
	var after: int = maxi(0, before - amount)
	d[base + U_HP] = after
	if trace_enabled:
		trace_damage[unit] = trace_damage[unit] + (before - after)
	if after <= 0:
		d[base + U_ALIVE] = 0
		var tile: int = int(tile_index.get(Vector3i(d[base + U_X], 0, d[base + U_Z]), -1))
		if tile >= 0 and d[board_off + tile] == unit:
			d[board_off + tile] = -1
		if source >= 0 and source != unit and _abc(d, source) == AB_MOXIE and d[source * U_STRIDE + U_ALIVE] == 1:
			_change_stage(d, source, 0, 1, -1)
	return before - after


func _heal(d: PackedInt32Array, unit: int, amount: int) -> int:
	var base: int = unit * U_STRIDE
	if d[base + U_ALIVE] != 1 or amount <= 0 or _hs(d, unit, S_HEAL_BLOCK):
		return 0
	var before: int = d[base + U_HP]
	d[base + U_HP] = mini(d[base + U_MAXHP], before + amount)
	return d[base + U_HP] - before


func _status_damage(d: PackedInt32Array, unit: int, fraction: int, multiplier: int) -> int:
	var base: int = unit * U_STRIDE
	if d[base + U_ALIVE] != 1:
		return 0
	if _abc(d, unit) == AB_MAGIC_GUARD:
		return 0
	var amount: int = maxi(1, int(floor(float(d[base + U_MAXHP]) / float(maxi(1, fraction)))) * maxi(1, multiplier))
	return _damage_unit(d, unit, amount, -1)


func _apply_record(d: PackedInt32Array, record: Array, attacker: int, target: int, mi: int, damage_done: int) -> void:
	var family: int = record[R_FAMILY]
	if family == FAM_SKIP or family == FAM_DAMAGE:
		return
	if record[R_REQ_DAMAGE] == 1 and damage_done <= 0:
		return
	if family == FAM_FIELD:
		_apply_field(d, record)
		return
	var recipient: int = attacker if record[R_TARGET] == 1 else target
	var rbase: int = recipient * U_STRIDE
	if d[rbase + U_ALIVE] != 1 and family != FAM_RECOIL:
		return
	if record[R_ADDITIONAL] == 1:
		if _team_screen(d, d[rbase + U_TEAM], 3) > 0:
			return
		if recipient != attacker and _abc(d, recipient) == AB_SHIELD_DUST:
			return
		if _abc(d, attacker) == AB_SHEER_FORCE:
			return
	var chance: int = record[R_CHANCE]
	if _abc(d, attacker) == AB_SERENE_GRACE:
		chance = mini(100, chance * 2)
	if chance < 100 and _rng.randf() * 100.0 >= float(chance):
		return
	match family:
		FAM_STATUS:
			_apply_status(d, attacker, recipient, record[R_STATUS], mi, false)
		FAM_STATUS_REMOVE:
			_remove_status(d, recipient, record[R_STATUS])
		FAM_STAT:
			_change_stage(d, recipient, record[R_STAT], record[R_DELTA], attacker if recipient != attacker else -1)
		FAM_WEATHER_STAT:
			var active: bool = record[R_COND] >= 0 and d[field_off + F_WEATHER] == record[R_COND]
			_change_stage(d, recipient, record[R_STAT], record[R_COUNTER] if active else record[R_DELTA], attacker if recipient != attacker else -1)
		FAM_HEAL:
			var heal_amount: int = _record_heal_amount(d, record, recipient)
			if heal_amount > 0:
				_heal(d, recipient, heal_amount)
		FAM_DRAIN:
			var drained: int = int(floor(float(damage_done) * float(record[R_FRAC_F]) / 10000.0))
			if drained > 0:
				if _abc(d, target) == AB_LIQUID_OOZE:
					_damage_unit(d, attacker, drained, -1)
				else:
					_heal(d, attacker, drained)
		FAM_RECOIL:
			var recoil: int = _record_recoil_amount(d, record, attacker)
			var recoil_ability: int = _abc(d, attacker)
			if recoil > 0 and recoil_ability != AB_ROCK_HEAD and recoil_ability != AB_MAGIC_GUARD:
				_damage_unit(d, attacker, recoil, -1)
		FAM_CURE:
			_cure_statuses(d, recipient)
		FAM_FIXED:
			if record[R_AMOUNT] > 0:
				_apply_damage(d, attacker, recipient, mi, record[R_AMOUNT])
		FAM_LEVEL:
			var level_damage: int = maxi(1, d[attacker * U_STRIDE + U_LEVEL])
			_apply_damage(d, attacker, recipient, mi, level_damage)
		FAM_PERCENT:
			var pct: int = int(floor(float(d[rbase + U_MAXHP]) * float(record[R_PERCENT]) / 10000.0))
			if pct > 0:
				_apply_damage(d, attacker, recipient, mi, pct)
		FAM_HP_TO_1:
			var delta: int = maxi(0, d[rbase + U_HP] - 1)
			if delta > 0:
				_apply_damage(d, attacker, recipient, mi, delta)
		FAM_PP:
			for slot in range(SLOT_COUNT):
				if d[rbase + U_PP + slot] > 0:
					d[rbase + U_PP + slot] = maxi(0, d[rbase + U_PP + slot] - record[R_AMOUNT])
					break


func _record_heal_amount(d: PackedInt32Array, record: Array, recipient: int) -> int:
	var rbase: int = recipient * U_STRIDE
	if record[R_AMOUNT] > 0:
		return record[R_AMOUNT]
	if record[R_DIVISOR] > 0:
		return maxi(1, int(floor(float(d[rbase + U_MAXHP]) / float(record[R_DIVISOR]))))
	if record[R_PERCENT] > 0:
		return maxi(1, int(floor(float(d[rbase + U_MAXHP]) * float(record[R_PERCENT]) / 10000.0)))
	return 0


func _record_recoil_amount(d: PackedInt32Array, record: Array, attacker: int) -> int:
	var abase: int = attacker * U_STRIDE
	if record[R_FRAC_I] > 0:
		var source_hp: int = d[abase + U_MAXHP] if record[R_MAXHP] == 1 else d[abase + U_HP]
		return maxi(1, int(floor(float(source_hp) / float(record[R_FRAC_I]))))
	return record[R_AMOUNT]


func _apply_field(d: PackedInt32Array, record: Array) -> void:
	var code: int = record[R_COND]
	if code < 0:
		return
	if code >= 100:
		d[field_off + F_TERRAIN] = code - 100
		d[field_off + F_TERRAIN_ROUNDS] = 5
		return
	d[field_off + F_WEATHER] = code
	d[field_off + F_WEATHER_ROUNDS] = BattleWeatherService.DEFAULT_ROUNDS


func _apply_status(d: PackedInt32Array, attacker: int, unit: int, si: int, mi: int, skip_rules: bool) -> bool:
	if si < 0 or unit < 0:
		return false
	var base: int = unit * U_STRIDE
	if d[base + U_ALIVE] != 1:
		return false
	if not skip_rules and _status_blocked(d, attacker, unit, si, mi):
		return false
	var screen: int = int(SCREEN_IDS.find(STATUS_IDS[si]))
	if screen >= 0:
		d[field_off + F_SCREEN + d[base + U_TEAM] * SCREEN_COUNT + screen] = maxi(1, _status_counter[si])
	_set_status(d, unit, si, _status_counter[si])
	if STATUS_IDS[si] == "trap":
		d[base + U_TRAPFRAC] = 8
	elif STATUS_IDS[si] == "poison_toxic":
		d[base + U_TOXIC] = 1
	elif STATUS_IDS[si] == "leech_seed":
		d[base + U_LEECHSRC] = attacker
	elif STATUS_IDS[si] == "disable":
		d[base + U_DISABLE_SLOT] = d[base + U_LASTSLOT]
	elif STATUS_IDS[si] == "encore":
		d[base + U_ENCORE_SLOT] = d[base + U_LASTSLOT]
	elif STATUS_IDS[si] == "sleep" and _abc(d, unit) == AB_EARLY_BIRD:
		d[base + U_STATUS + si] = maxi(1, int(ceil(float(_status_counter[si]) / 2.0)))
	if attacker >= 0 and attacker != unit and _synchronize_status[si] == 1 and _abc(d, unit) == AB_SYNCHRONIZE:
		_apply_status(d, unit, attacker, si, mi, false)
	return true


func _status_blocked(d: PackedInt32Array, attacker: int, unit: int, si: int, mi: int) -> bool:
	var base: int = unit * U_STRIDE
	var status_id: String = STATUS_IDS[si]
	if _bad_status[si] == 1 and attacker >= 0 and attacker != unit and _team_screen(d, d[base + U_TEAM], 2) > 0 and status_id != "safeguard":
		return true
	var immune: PackedInt32Array = _type_immunity[si]
	for i in range(immune.size()):
		if d[base + U_TYPE1] == immune[i] or d[base + U_TYPE2] == immune[i]:
			return true
	if mi >= 0 and BattleStateOps.POWDER_MOVES.has(move_ids[mi]) and _has_type(d, unit, "grass"):
		return true
	if d[field_off + F_WEATHER] >= 0 and BattleWeatherService.blocks_status(_weather_ids[d[field_off + F_WEATHER]], status_id):
		return true
	if _non_reapply[si] == 1 and d[base + U_STATUS + si] != 0:
		return true
	if status_id == "sleep" and _hs(d, unit, S_SLEEPLESS):
		return true
	if _is_grounded(d, unit) and d[field_off + F_TERRAIN] >= 0:
		var terrain_id: String = _terrain_ids[d[field_off + F_TERRAIN]]
		if terrain_id == "electric_terrain" and (status_id == "sleep" or status_id == "yawning"):
			return true
		if terrain_id == "misty_terrain" and (_major_status[si] == 1 or status_id == "confuse"):
			return true
	if _major_status[si] == 1:
		for other in range(STATUS_COUNT):
			if other != si and _major_status[other] == 1 and d[base + U_STATUS + other] != 0:
				return true
	_hydrate_one(_sb, _sb_stages, _sb_status, _sb_slugs, d, unit)
	return _intrinsics.blocks_status(_sb, status_id, null, null, move_res[mi] if mi >= 0 else null)


func _cure_statuses(d: PackedInt32Array, unit: int) -> void:
	var base: int = unit * U_STRIDE
	if d[base + U_SCOUNT] <= 0:
		return
	for si in range(STATUS_COUNT):
		if d[base + U_STATUS + si] != 0:
			_remove_status(d, unit, si)


func _change_stage(d: PackedInt32Array, unit: int, stat: int, delta: int, attacker: int) -> void:
	if stat < 0 or delta == 0:
		return
	var base: int = unit * U_STRIDE
	if d[base + U_ALIVE] != 1:
		return
	_hydrate_one(_sb, _sb_stages, _sb_status, _sb_slugs, d, unit)
	if _intrinsics.blocks_stat_stage(_sb, STAT_IDS[stat], delta, null, null, null):
		return
	if delta < 0 and attacker >= 0 and attacker != unit and _team_screen(d, d[base + U_TEAM], 4) > 0:
		return
	var effective: int = _intrinsics.transform_stat_delta(_sb, delta)
	d[base + U_STAGE + stat] = clampi(d[base + U_STAGE + stat] + effective, -6, 6)


func _extra_multiplier(d: PackedInt32Array, attacker: int, target: int, mi: int, effectiveness: float, hit_index: int, move: PokemonMoveResource) -> float:
	var info: int = mi * M_STRIDE
	var tbase: int = target * U_STRIDE
	var abase: int = attacker * U_STRIDE
	var multiplier: float = _intrinsics.before_damage_multiplier(_sa, move, null, null, null, effectiveness, null)
	multiplier *= _intrinsics.defender_damage_multiplier(_sb, move, null, null, effectiveness)
	if _hs(d, attacker, S_BURN) and move_info[info + M_CAT] == PokemonMoveResource.CATEGORY_PHYSICAL:
		multiplier *= 2.0 / 3.0
	if move_info[info + M_CAT] == PokemonMoveResource.CATEGORY_PHYSICAL and _team_screen(d, d[tbase + U_TEAM], 0) > 0:
		multiplier *= 0.5
	elif move_info[info + M_CAT] == PokemonMoveResource.CATEGORY_SPECIAL and _team_screen(d, d[tbase + U_TEAM], 1) > 0:
		multiplier *= 0.5
	if d[field_off + F_WEATHER] >= 0:
		multiplier *= BattleWeatherService.damage_multiplier(_weather_ids[d[field_off + F_WEATHER]], move, unit_types[target])
	if d[field_off + F_TERRAIN] >= 0:
		multiplier *= _terrain_multiplier(d, attacker, target, mi)
	if hit_index == 1 and move_info[info + M_STRIKE] <= 1 and _abc(d, attacker) == AB_PARENTAL_BOND:
		multiplier *= 0.25
	if _abc(d, attacker) == AB_ANALYTIC and d[tbase + U_ACTED] == 1:
		multiplier *= 1.3
	if _abc(d, attacker) == AB_RIVALRY and move_info[info + M_DAMAGING] == 1 and d[abase + U_GENDER] != 2 and d[tbase + U_GENDER] != 2:
		multiplier *= 1.25 if d[abase + U_GENDER] == d[tbase + U_GENDER] else 0.75
	return multiplier


func _terrain_multiplier(d: PackedInt32Array, attacker: int, target: int, mi: int) -> float:
	var terrain_id: String = _terrain_ids[d[field_off + F_TERRAIN]]
	var move_type: int = move_info[mi * M_STRIDE + M_TYPE]
	var multiplier: float = 1.0
	match terrain_id:
		"grassy_terrain":
			if move_type == int(type_lookup.get("grass", -1)) and _is_grounded(d, attacker):
				multiplier *= 1.3
			if move_ids[mi] in ["earthquake", "bulldoze", "magnitude"] and _is_grounded(d, target):
				multiplier *= 0.5
		"electric_terrain":
			if move_type == int(type_lookup.get("electric", -1)) and _is_grounded(d, attacker):
				multiplier *= 1.3
		"psychic_terrain":
			if move_type == int(type_lookup.get("psychic", -1)) and _is_grounded(d, attacker):
				multiplier *= 1.3
		"misty_terrain":
			if move_type == int(type_lookup.get("dragon", -1)) and _is_grounded(d, target):
				multiplier *= 0.5
	return multiplier


func _accuracy_multiplier(d: PackedInt32Array, attacker: int, target: int, mi: int) -> float:
	var abase: int = attacker * U_STRIDE
	var tbase: int = target * U_STRIDE
	var combined: int = clampi(d[abase + U_STAGE + 5] - d[tbase + U_STAGE + 6], -6, 6)
	var multiplier: float = STAGE_ACCURACY_TABLE[combined + 6]
	var attacker_ability: int = _abc(d, attacker)
	if attacker_ability == AB_COMPOUND_EYES:
		multiplier *= 1.3
	elif attacker_ability == AB_HUSTLE and move_info[mi * M_STRIDE + M_CAT] == PokemonMoveResource.CATEGORY_PHYSICAL:
		multiplier *= 0.8
	if attacker != target:
		var weather: int = d[field_off + F_WEATHER]
		var target_ability: int = _abc(d, target)
		if target_ability == AB_SAND_VEIL and weather == _weather_sandstorm:
			multiplier *= 0.8
		elif target_ability == AB_SNOW_CLOAK and weather == _weather_hail:
			multiplier *= 0.8
	return multiplier


func _hydrate(d: PackedInt32Array, attacker: int, target: int, mi: int) -> void:
	_hydrate_one(_sa, _sa_stages, _sa_status, _sa_slugs, d, attacker)
	_hydrate_one(_sb, _sb_stages, _sb_status, _sb_slugs, d, target)


func _hydrate_one(stats: Stats, stages: Dictionary, statuses: Dictionary, slugs: Array[String], d: PackedInt32Array, unit: int) -> void:
	var base: int = unit * U_STRIDE
	stats.level = d[base + U_LEVEL]
	stats.attack = d[base + U_ATK]
	stats.defense = d[base + U_DEF]
	stats.special_attack = d[base + U_SPA]
	stats.special_defense = d[base + U_SPD]
	stats.speed = d[base + U_SPE]
	stats.curr_health = d[base + U_HP]
	stats.max_health = d[base + U_MAXHP]
	stats.hp_max = d[base + U_MAXHP]
	stats.gender = d[base + U_GENDER]
	stats.types = unit_types[unit]
	stats.battle_status = Stats.BattleStatus.ACTIVE if d[base + U_ALIVE] == 1 else Stats.BattleStatus.FAINTED
	slugs[0] = _ability_of(d, unit)
	stages.clear()
	for s in range(STAT_IDS.size()):
		if d[base + U_STAGE + s] != 0:
			stages[STAT_IDS[s]] = d[base + U_STAGE + s]
	statuses.clear()
	if d[base + U_SCOUNT] > 0:
		for si in range(STATUS_COUNT):
			if d[base + U_STATUS + si] != 0:
				statuses[STATUS_IDS[si]] = {}


func _effectiveness(move_type: int, type1: int, type2: int) -> float:
	return eff_table[(move_type * type_count + type1) * type_count + type2]


func _alignment_allows(unit: int, other: int, unit_team: int, other_team: int, align: int, damaging: int) -> bool:
	if unit == other:
		return (align & PokemonMoveResource.TARGET_SELF) != 0
	if unit_team == other_team:
		if damaging == 1:
			return false
		return (align & PokemonMoveResource.TARGET_FRIEND) != 0
	return (align & PokemonMoveResource.TARGET_FOE) != 0


func key_in_range(origin: Vector3i, key: Vector3i, kind: int, distance: int) -> bool:
	var dx: int = absi(key.x - origin.x)
	var dz: int = absi(key.z - origin.z)
	match kind:
		PokemonMoveResource.TacticalRangeKind.MELEE:
			return dx + dz == 1
		PokemonMoveResource.TacticalRangeKind.LINE:
			if dx != 0 and dz != 0:
				return false
			return dx + dz >= 1 and dx + dz <= distance
		PokemonMoveResource.TacticalRangeKind.PROJECTILE:
			return (dx != 0 or dz != 0) and maxi(dx, dz) <= distance
		PokemonMoveResource.TacticalRangeKind.AREA:
			return dx + dz <= distance
		PokemonMoveResource.TacticalRangeKind.SELF:
			return dx == 0 and dz == 0
	return false


func _range_distance(d: PackedInt32Array, unit: int, mi: int) -> int:
	var info: int = mi * M_STRIDE
	if move_info[info + M_KIND] == PokemonMoveResource.TacticalRangeKind.SELF:
		return maxi(1, move_info[info + M_RANGE])
	var bonus: int = 0
	var slug: int = _abc(d, unit)
	if slug == AB_PRANKSTER and move_info[info + M_CAT] == PokemonMoveResource.CATEGORY_STATUS:
		bonus += 2
	elif slug == AB_GALE_WINGS and move_info[info + M_TYPE] == _flying_index and d[unit * U_STRIDE + U_HP] >= d[unit * U_STRIDE + U_MAXHP]:
		bonus += 1
	return maxi(1, move_info[info + M_RANGE] + bonus)


func _ability_of(d: PackedInt32Array, unit: int) -> String:
	var index: int = d[unit * U_STRIDE + U_ABILITY]
	return ability_names[index] if index >= 0 else ""


func _abc(d: PackedInt32Array, unit: int) -> int:
	var index: int = d[unit * U_STRIDE + U_ABILITY]
	return ability_code[index] if index >= 0 else -1


func _hs(d: PackedInt32Array, unit: int, si: int) -> bool:
	return d[unit * U_STRIDE + U_STATUS + si] != 0


func _has_type(d: PackedInt32Array, unit: int, type_id: String) -> bool:
	var index: int = int(type_lookup.get(type_id, -1))
	if index < 0:
		return false
	var base: int = unit * U_STRIDE
	return d[base + U_TYPE1] == index or d[base + U_TYPE2] == index


func _is_grounded(d: PackedInt32Array, unit: int) -> bool:
	if _flying_index >= 0 and (d[unit * U_STRIDE + U_TYPE1] == _flying_index or d[unit * U_STRIDE + U_TYPE2] == _flying_index):
		return false
	return _abc(d, unit) != AB_LEVITATE


func _has_major(d: PackedInt32Array, unit: int) -> bool:
	var base: int = unit * U_STRIDE
	if d[base + U_SCOUNT] <= 0:
		return false
	for si in range(STATUS_COUNT):
		if _major_status[si] == 1 and d[base + U_STATUS + si] != 0:
			return true
	return false


func _set_status(d: PackedInt32Array, unit: int, si: int, counter: int) -> void:
	var base: int = unit * U_STRIDE
	if d[base + U_STATUS + si] == 0:
		d[base + U_SCOUNT] = d[base + U_SCOUNT] + 1
	d[base + U_STATUS + si] = counter if counter > 0 else -1


func _remove_status(d: PackedInt32Array, unit: int, si: int) -> void:
	if si < 0:
		return
	var base: int = unit * U_STRIDE
	if d[base + U_STATUS + si] == 0:
		return
	d[base + U_STATUS + si] = 0
	d[base + U_SCOUNT] = maxi(0, d[base + U_SCOUNT] - 1)
	var screen: int = int(SCREEN_IDS.find(STATUS_IDS[si]))
	if screen >= 0:
		d[field_off + F_SCREEN + d[base + U_TEAM] * SCREEN_COUNT + screen] = 0
	if STATUS_IDS[si] in RAMPAGE_IDS:
		_apply_status(d, unit, unit, S_CONFUSE, -1, true)


func _team_screen(d: PackedInt32Array, team: int, screen: int) -> int:
	return d[field_off + F_SCREEN + team * SCREEN_COUNT + screen]


func _is_trapped(d: PackedInt32Array, unit: int) -> bool:
	var base: int = unit * U_STRIDE
	if d[base + U_SCOUNT] <= 0:
		return false
	return d[base + U_STATUS + S_TRAP] != 0 or d[base + U_STATUS + S_ROOTED] != 0


func _tick_weather(d: PackedInt32Array) -> void:
	if d[field_off + F_WEATHER] < 0:
		return
	if BattleWeatherService.is_permanent(_weather_ids[d[field_off + F_WEATHER]]):
		return
	var left: int = d[field_off + F_WEATHER_ROUNDS] - 1
	if left <= 0:
		d[field_off + F_WEATHER] = -1
		d[field_off + F_WEATHER_ROUNDS] = 0
		return
	d[field_off + F_WEATHER_ROUNDS] = left


func _tick_conditions(d: PackedInt32Array) -> void:
	if d[field_off + F_TERRAIN] >= 0:
		var left: int = d[field_off + F_TERRAIN_ROUNDS] - 1
		if left <= 0:
			d[field_off + F_TERRAIN] = -1
			d[field_off + F_TERRAIN_ROUNDS] = 0
		else:
			d[field_off + F_TERRAIN_ROUNDS] = left
	for team in range(2):
		for s in range(SCREEN_COUNT):
			var index: int = field_off + F_SCREEN + team * SCREEN_COUNT + s
			if d[index] > 0:
				d[index] = d[index] - 1


func _place_hazard(d: PackedInt32Array, unit: int, hazard: int) -> void:
	var base: int = unit * U_STRIDE
	var origin: int = int(tile_index.get(Vector3i(d[base + U_X], 0, d[base + U_Z]), -1))
	if origin < 0:
		return
	var team: int = d[base + U_TEAM]
	var max_layers: int = int((BattleHazardService.RULES[HAZARD_IDS[hazard]] as Dictionary)["max_layers"])
	for n in range(4):
		var tile: int = neighbors[origin * 4 + n]
		if tile < 0:
			continue
		var index: int = hazard_off + tile * HAZARD_COUNT + hazard
		var layers: int = d[index] & 0xF
		if layers >= max_layers:
			continue
		d[index] = (layers + 1) | ((team + 1) << 4)


func _trigger_hazards(d: PackedInt32Array, unit: int, tile: int) -> void:
	var base: int = unit * U_STRIDE
	var team: int = d[base + U_TEAM]
	for hazard in range(HAZARD_COUNT):
		var index: int = hazard_off + tile * HAZARD_COUNT + hazard
		var packed: int = d[index]
		if packed == 0:
			continue
		var layers: int = packed & 0xF
		var owner: int = (packed >> 4) - 1
		if owner == team:
			continue
		var hazard_id: String = HAZARD_IDS[hazard]
		if bool((BattleHazardService.RULES[hazard_id] as Dictionary)["grounded"]) and not _is_grounded(d, unit):
			continue
		match hazard_id:
			"spikes":
				_status_damage(d, unit, SPIKE_FRACTIONS[clampi(layers, 1, 3) - 1], 1)
			"toxic_spikes":
				if _has_type(d, unit, "poison"):
					d[index] = 0
					continue
				_apply_status(d, unit, unit, int(_status_lookup["poison_toxic" if layers >= 2 else "poison"]), -1, false)
			"stealth_rock":
				var rock: int = int(type_lookup.get("rock", 0))
				var effectiveness: float = _effectiveness(rock, d[base + U_TYPE1], d[base + U_TYPE2])
				_damage_unit(d, unit, maxi(1, int(floor(float(d[base + U_MAXHP]) * effectiveness / 8.0))), -1)
			"sticky_web":
				_change_stage(d, unit, 4, -1, -1)
		if d[base + U_ALIVE] != 1:
			return


func _get_rng_state(d: PackedInt32Array) -> int:
	return (int(d[field_off + F_RNG_LO]) & 0xFFFFFFFF) | (int(d[field_off + F_RNG_HI]) << 32)


func _set_rng_state(d: PackedInt32Array, value: int) -> void:
	d[field_off + F_RNG_LO] = int(value & 0xFFFFFFFF)
	d[field_off + F_RNG_HI] = int((value >> 32) & 0xFFFFFFFF)


func set_rng_state(d: PackedInt32Array, value: int) -> void:
	_set_rng_state(d, value)


func begin_trace(_d: Variant = null) -> void:
	trace_enabled = true
	trace_hits = 0
	trace_misses = 0
	trace_damage.resize(unit_count)
	trace_damage.fill(0)


func run_move(d: PackedInt32Array, attacker: int, slot: int, target: int) -> void:
	_rng.state = _get_rng_state(d)
	_run_move(d, attacker, slot, target)
	_set_rng_state(d, _rng.state)
