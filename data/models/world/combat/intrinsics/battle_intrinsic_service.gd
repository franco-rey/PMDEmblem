class_name BattleIntrinsicService
extends RefCounted

const PINCH_DAMAGE_BOOSTS: Dictionary = {
	"blaze": "fire",
	"overgrow": "grass",
	"swarm": "bug",
	"torrent": "water",
}
const MAJOR_STATUS_IDS: Array[String] = ["burn", "poison", "poison_toxic", "paralyze", "sleep", "freeze"]
const SLEEP_STATUSES: Array[String] = ["sleep", "asleep", "yawn", "yawning"]
const FLINCH_STATUSES: Array[String] = ["flinch", "cringe"]
const SYNCHRONIZE_STATUSES: Array[String] = ["burn", "poison", "poison_toxic", "paralyze"]
const CRITICAL_BLOCK_INTRINSICS: Array[String] = ["battle_armor", "shell_armor"]
const RECOIL_BLOCK_INTRINSICS: Array[String] = ["rock_head"]
const WEATHER_SPEED_INTRINSICS: Dictionary = {
	"chlorophyll": "sunny",
	"swift_swim": "rain",
	"sand_rush": "sandstorm",
	"slush_rush": "hail",
}
const STATUS_PREVENTION_BY_INTRINSIC: Dictionary = {
	"immunity": ["poison", "poison_toxic"],
	"limber": ["paralyze"],
	"oblivious": ["in_love", "rage_powder"],
	"own_tempo": ["confuse"],
	"run_away": ["immobilized", "wrap", "bind", "fire_spin", "whirlpool", "sand_tomb", "telekinesis", "clamp", "infestation", "magma_storm"],
	"water_veil": ["burn"],
	"magma_armor": ["freeze"],
	"sweet_veil": ["sleep", "yawning"],
}
const BALL_MOVES: Array[String] = ["acid_spray", "aura_sphere", "barrage", "beak_blast", "bullet_seed", "egg_bomb", "electro_ball", "energy_ball", "focus_blast", "gyro_ball", "ice_ball", "magnet_bomb", "mist_ball", "mud_bomb", "octazooka", "pollen_puff", "pyro_ball", "rock_blast", "rock_wrecker", "searing_shot", "seed_bomb", "shadow_ball", "sludge_bomb", "weather_ball", "zap_cannon"]
const EXPLOSION_MOVES: Array[String] = ["self_destruct", "explosion", "mind_blown", "misty_explosion"]
const ABILITY_IGNORING_INTRINSICS: Array[String] = ["mold_breaker", "teravolt", "turboblaze"]
const WEATHER_SUPPRESSING_INTRINSICS: Array[String] = ["cloud_nine", "air_lock"]
const BATTLE_START_WEATHER: Dictionary = {"drought": "sunny", "drizzle": "rain", "sand_stream": "sandstorm", "snow_warning": "hail"}
const EXCLUDED_INTRINSICS: Dictionary = {
	"pickup": "no battle effect outside dungeon item pickup",
	"honey_gather": "no battle effect",
	"illusion": "cosmetic disguise only",
	"quick_draw": "random priority has no counterpart in a speed-ordered round",
}
const MOVE_TYPE_OVERRIDES: Dictionary = {"pixilate": "fairy", "aerilate": "flying", "galvanize": "electric", "refrigerate": "ice"}
const AURA_TYPES: Dictionary = {"dark_aura": "dark", "fairy_aura": "fairy"}
const ALLY_VEIL_STATUSES: Dictionary = {"aroma_veil": ["torment", "taunted", "encore", "disable", "heal_block", "in_love"]}
const STAT_DROP_BLOCKS_BY_INTRINSIC: Dictionary = {
	"big_pecks": ["defense"],
	"clear_body": [],
	"white_smoke": [],
	"hyper_cutter": ["attack"],
	"keen_eye": ["accuracy"],
}
const TYPE_IMMUNITY_BY_INTRINSIC: Dictionary = {
	"levitate": "ground",
}
const ABSORB_HEAL_BY_INTRINSIC: Dictionary = {
	"volt_absorb": "electric",
	"water_absorb": "water",
	"dry_skin": "water",
}
const ABSORB_STAGE_BY_INTRINSIC: Dictionary = {
	"lightning_rod": {"element": "electric", "stat": "special_attack"},
	"sap_sipper": {"element": "grass", "stat": "attack"},
	"storm_drain": {"element": "water", "stat": "special_attack"},
	"motor_drive": {"element": "electric", "stat": "speed"},
}
const CONTACT_STATUS_BY_INTRINSIC: Dictionary = {
	"flame_body": "burn",
	"poison_point": "poison",
	"static": "paralyze",
}
var state_ops: BattleStateOps = null

const FORM_SPECIES: Dictionary = {"castform": {"rain": 2, "sunny": 1, "hail": 3, "primordial_sea": 2, "desolate_land": 1}, "cherrim": {"sunny": 1, "desolate_land": 1}}
const STRONG_WEATHER_BY_INTRINSIC: Dictionary = {"desolate_land": "desolate_land", "primordial_sea": "primordial_sea", "delta_stream": "delta_stream"}
const TERRAIN_BY_SURGE: Dictionary = {"electric_surge": "electric_terrain", "grassy_surge": "grassy_terrain", "misty_surge": "misty_terrain", "psychic_surge": "psychic_terrain"}
const SUPPORTED_INTRINSICS: Array[String] = [
	"adaptability",
	"aerilate",
	"aftermath",
	"air_lock",
	"analytic",
	"anger_point",
	"anticipation",
	"arena_trap",
	"aroma_veil",
	"aura_break",
	"bad_dreams",
	"battle_armor",
	"berserk",
	"big_pecks",
	"blaze",
	"bulletproof",
	"cheek_pouch",
	"chlorophyll",
	"clear_body",
	"cloud_nine",
	"color_change",
	"competitive",
	"compound_eyes",
	"contrary",
	"cud_chew",
	"curious_medicine",
	"cursed_body",
	"cute_charm",
	"damp",
	"dark_aura",
	"defeatist",
	"defiant",
	"delta_stream",
	"desolate_land",
	"download",
	"drizzle",
	"drought",
	"dry_skin",
	"early_bird",
	"effect_spore",
	"electric_surge",
	"fairy_aura",
	"filter",
	"flame_body",
	"flare_boost",
	"flash_fire",
	"flower_gift",
	"flower_veil",
	"forecast",
	"forewarn",
	"friend_guard",
	"frisk",
	"fur_coat",
	"gale_wings",
	"galvanize",
	"gluttony",
	"gooey",
	"gorilla_tactics",
	"grass_pelt",
	"grassy_surge",
	"guts",
	"harvest",
	"healer",
	"heatproof",
	"heavy_metal",
	"huge_power",
	"hustle",
	"hydration",
	"hyper_cutter",
	"ice_body",
	"illuminate",
	"immunity",
	"imposter",
	"infiltrator",
	"inner_focus",
	"insomnia",
	"intimidate",
	"iron_barbs",
	"iron_fist",
	"justified",
	"keen_eye",
	"klutz",
	"leaf_guard",
	"levitate",
	"light_metal",
	"lightning_rod",
	"limber",
	"liquid_ooze",
	"magic_bounce",
	"magic_guard",
	"magician",
	"magma_armor",
	"magnet_pull",
	"marvel_scale",
	"mega_launcher",
	"minus",
	"misty_surge",
	"mold_breaker",
	"moody",
	"motor_drive",
	"moxie",
	"multiscale",
	"multitype",
	"mummy",
	"natural_cure",
	"neutralizing_gas",
	"no_guard",
	"normalize",
	"oblivious",
	"overcoat",
	"overgrow",
	"own_tempo",
	"parental_bond",
	"pastel_veil",
	"pickpocket",
	"pixilate",
	"plus",
	"poison_heal",
	"poison_point",
	"poison_touch",
	"power_construct",
	"power_of_alchemy",
	"prankster",
	"pressure",
	"primordial_sea",
	"protean",
	"psychic_surge",
	"pure_power",
	"quick_feet",
	"rain_dish",
	"rattled",
	"receiver",
	"reckless",
	"refrigerate",
	"regenerator",
	"rivalry",
	"rock_head",
	"rough_skin",
	"run_away",
	"sand_force",
	"sand_rush",
	"sand_stream",
	"sand_veil",
	"sap_sipper",
	"scrappy",
	"screen_cleaner",
	"serene_grace",
	"shadow_tag",
	"sharpness",
	"shed_skin",
	"sheer_force",
	"shell_armor",
	"shield_dust",
	"simple",
	"skill_link",
	"slow_start",
	"slush_rush",
	"sniper",
	"snow_cloak",
	"snow_warning",
	"solar_power",
	"solid_rock",
	"soundproof",
	"speed_boost",
	"stall",
	"stance_change",
	"static",
	"steadfast",
	"stench",
	"sticky_hold",
	"storm_drain",
	"strong_jaw",
	"sturdy",
	"suction_cups",
	"super_luck",
	"surge_surfer",
	"swarm",
	"sweet_veil",
	"swift_swim",
	"symbiosis",
	"synchronize",
	"tangled_feet",
	"tangling_hair",
	"technician",
	"telepathy",
	"teravolt",
	"thick_fat",
	"tinted_lens",
	"torrent",
	"tough_claws",
	"toxic_boost",
	"trace",
	"truant",
	"turboblaze",
	"unaware",
	"unburden",
	"unnerve",
	"victory_star",
	"vital_spirit",
	"volt_absorb",
	"wandering_spirit",
	"water_absorb",
	"water_veil",
	"weak_armor",
	"white_smoke",
	"wonder_guard",
	"wonder_skin",
	"zen_mode",
]

var _ignored_stats: Stats = null


func log_battle_start(units: Array[BattleUnit], battle_log: BattleLog, battle_level: TacticsLevel = null) -> void:
	if battle_log == null:
		return
	for unit in units:
		if unit == null or unit.pawn == null or unit.stats == null:
			continue
		for slug in intrinsic_slugs_for(unit.stats):
			_apply_battle_start_effect(slug, unit.pawn, units, battle_level, battle_log)
			if SUPPORTED_INTRINSICS.has(slug):
				battle_log.append({
					"kind": "intrinsic_triggered",
					"hook": "battle_start",
					"unit": unit.pawn,
					"intrinsic_id": slug,
					"supported": true,
				})
				if BATTLE_START_WEATHER.has(slug) and battle_level != null:
					var weather_id: String = String(BATTLE_START_WEATHER[slug])
					battle_level.set_battle_condition(weather_id, {"source_intrinsic": slug, "unit": unit.pawn.name})
					battle_log.append({
						"kind": "field_condition_applied",
						"condition_id": weather_id,
						"source": "intrinsic",
						"intrinsic_id": slug,
						"unit": unit.pawn,
					})
			else:
				battle_log.append({
					"kind": "intrinsic_future_only",
					"hook": "battle_start",
					"unit": unit.pawn,
					"intrinsic_id": slug,
				})


func before_damage_multiplier(attacker: Stats, move: PokemonMoveResource, battle_log: BattleLog = null, pawn: TacticsPawn = null, battle_level: TacticsLevel = null, effectiveness: float = 1.0, target: TacticsPawn = null) -> float:
	if attacker == null or move == null:
		return 1.0
	var multiplier: float = 1.0
	for slug in intrinsic_slugs_for(attacker):
		var applied_multiplier: float = _damage_multiplier_for_slug(slug, attacker, move, battle_level, effectiveness, target)
		if is_equal_approx(applied_multiplier, 1.0):
			continue
		multiplier *= applied_multiplier
		if battle_log != null:
			battle_log.append({
				"kind": "intrinsic_triggered",
				"hook": "before_damage",
				"unit": pawn,
				"intrinsic_id": slug,
				"move_id": move.move_id,
				"multiplier": applied_multiplier,
			})
	return multiplier


func defender_damage_multiplier(defender: Stats, move: PokemonMoveResource, battle_log: BattleLog = null, pawn: TacticsPawn = null, effectiveness: float = 1.0) -> float:
	if defender == null or move == null:
		return 1.0
	var multiplier: float = 1.0
	for slug in intrinsic_slugs_for(defender):
		var applied_multiplier: float = 1.0
		if slug == "grass_pelt" and move.category == PokemonMoveResource.CATEGORY_PHYSICAL and state_ops != null and state_ops.battle_level != null and state_ops.battle_level.current_terrain() == "grassy_terrain":
			applied_multiplier = 2.0 / 3.0
		elif slug == "flower_gift" and move.category == PokemonMoveResource.CATEGORY_SPECIAL and state_ops != null and state_ops.battle_level != null and state_ops.battle_level.effective_weather() in ["sunny", "desolate_land"]:
			applied_multiplier = 0.8
		elif slug == "thick_fat" and (move.type == "fire" or move.type == "ice"):
			applied_multiplier = 0.5
		elif (slug == "filter" or slug == "solid_rock") and effectiveness > 1.0:
			applied_multiplier = 0.75
		elif slug == "multiscale" and defender.curr_health == defender.max_health:
			applied_multiplier = 0.5
		elif slug == "marvel_scale" and move.category == PokemonMoveResource.CATEGORY_PHYSICAL and _has_major_status(defender):
			applied_multiplier = 2.0 / 3.0
		elif slug == "heatproof" and move.type == "fire":
			applied_multiplier = 0.5
		elif slug == "dry_skin" and move.type == "fire":
			applied_multiplier = 1.25
		elif slug == "fur_coat" and move.category == PokemonMoveResource.CATEGORY_PHYSICAL:
			applied_multiplier = 0.5
		if is_equal_approx(applied_multiplier, 1.0):
			continue
		multiplier *= applied_multiplier
		if battle_log != null:
			battle_log.append({
				"kind": "intrinsic_triggered",
				"hook": "before_being_hit",
				"unit": pawn,
				"intrinsic_id": slug,
				"move_id": move.move_id,
				"multiplier": applied_multiplier,
			})
	return multiplier


func on_turn_started(pawn: TacticsPawn, battle_level: TacticsLevel, battle_log: BattleLog) -> void:
	if pawn == null or pawn.stats == null or battle_level == null:
		return
	for slug in intrinsic_slugs_for(pawn.stats):
		match slug:
			"natural_cure":
				if pawn.stats.curr_health >= pawn.stats.max_health and (_has_major_status(pawn.stats) or pawn.stats.battle_statuses.has("confuse")):
					_cure_major_status(pawn, slug, battle_log)
					if pawn.stats.battle_statuses.has("confuse"):
						_ops(pawn, battle_log).remove_status(pawn, "confuse", {"source": "intrinsic", "intrinsic_id": slug})
			"regenerator":
				var near_foe: bool = false
				for foe in _foes_of(pawn):
					if _grid_distance_between(pawn, foe) <= 5:
						near_foe = true
				if not near_foe and pawn.stats.curr_health < pawn.stats.max_health:
					_heal_fraction(pawn, 16, slug, battle_log)
			"multitype":
				var plate: PokemonItemResource = PokemonItemService.held_item_for(pawn.stats)
				var plate_type: String = "normal"
				if plate != null and plate.item_id.ends_with("_plate") and PokemonItemService.TYPE_BOOST_ITEMS.has(plate.item_id):
					plate_type = String(PokemonItemService.TYPE_BOOST_ITEMS[plate.item_id])
				if pawn.stats.types != ([plate_type] as Array[String]):
					_set_types(pawn, [plate_type], slug, battle_log)
			"zen_mode", "power_construct":
				_apply_hp_form(pawn, slug, battle_log)
			"forecast", "flower_gift":
				_apply_weather_form(pawn, slug, battle_level.effective_weather(), battle_log)
			"rain_dish":
				if battle_level.has_battle_condition("rain"):
					_heal_fraction(pawn, 16, slug, battle_log)
			"dry_skin":
				if battle_level.has_battle_condition("rain"):
					_heal_fraction(pawn, 8, slug, battle_log)
				elif battle_level.has_battle_condition("sunny"):
					_damage_fraction(pawn, 8, slug, battle_log)
			"solar_power":
				if battle_level.has_battle_condition("sunny"):
					_damage_fraction(pawn, 8, slug, battle_log)
			"chlorophyll":
				if battle_level.has_battle_condition("sunny") and battle_log != null:
					battle_log.append({
						"kind": "intrinsic_triggered",
						"hook": "turn_start",
						"unit": pawn,
						"intrinsic_id": slug,
						"condition_id": "sunny",
					})
			"speed_boost":
				_apply_stat_boost(pawn, "speed", 1, slug, null, battle_log)
			"moody":
				var stats_pool: Array = ["attack", "defense", "special_attack", "special_defense", "speed"]
				var up: String = String(stats_pool[battle_level.battle_rng.randi_range(0, stats_pool.size() - 1)])
				var down: String = up
				while down == up:
					down = String(stats_pool[battle_level.battle_rng.randi_range(0, stats_pool.size() - 1)])
				_apply_stat_boost(pawn, up, 2, slug, null, battle_log)
				_apply_stat_boost(pawn, down, -1, slug, null, battle_log)
			"harvest":
				var last_item: String = pawn.stats.last_consumed_item_id
				if last_item.begins_with("berry_") and PokemonItemService.held_item_for(pawn) == null and (battle_level.effective_weather() == "sunny" or _chance(battle_level.battle_rng, 50)):
					var berry: PokemonItemResource = PokemonItemService.load_item(last_item)
					if berry != null and PokemonItemService.give_held_item(pawn, berry, battle_log, "harvest"):
						battle_log.append({"kind": "intrinsic_triggered", "hook": "turn_start", "unit": pawn, "intrinsic_id": slug, "item_id": last_item})
			"healer":
				for ally in _allies_of(pawn, true):
					if _chance(battle_level.battle_rng, 30):
						_cure_major_status(ally, slug, battle_log)
			"bad_dreams":
				for foe in _foes_of(pawn):
					if foe.stats.battle_statuses.has("sleep"):
						_damage_fraction(foe, 8, slug, battle_log)
			"ice_body":
				if battle_level.effective_weather() == "hail":
					_heal_fraction(pawn, 16, slug, battle_log)
			"hydration":
				if battle_level.effective_weather() == "rain":
					_cure_major_status(pawn, slug, battle_log)
			"shed_skin":
				if _chance(battle_level.battle_rng, 30):
					_cure_major_status(pawn, slug, battle_log)


func apply_speed_modifiers(units: Array[BattleUnit], battle_level: TacticsLevel, battle_log: BattleLog = null) -> void:
	for unit in units:
		if unit == null or unit.stats == null:
			continue
		unit.stats.battle_speed_multiplier = 1.0
		for slug in intrinsic_slugs_for(unit.stats):
			if slug == "quick_feet" and _has_major_status(unit.stats):
				unit.stats.battle_speed_multiplier *= 1.5
				continue
			if slug == "slow_start" and unit.stats.battle_statuses.has("slow_start"):
				unit.stats.battle_speed_multiplier *= 0.5
				continue
			if slug == "unburden" and unit.stats.battle_statuses.has("unburden"):
				unit.stats.battle_speed_multiplier *= 2.0
				continue
			if slug == "surge_surfer" and battle_level != null and battle_level.current_terrain() == "electric_terrain":
				unit.stats.battle_speed_multiplier *= 2.0
				continue
			if not WEATHER_SPEED_INTRINSICS.has(slug):
				continue
			var weather_id: String = String(WEATHER_SPEED_INTRINSICS[slug])
			if battle_level == null or not battle_level.has_battle_condition(weather_id):
				continue
			unit.stats.battle_speed_multiplier *= 2.0
			if battle_log != null:
				battle_log.append({
					"kind": "intrinsic_triggered",
					"hook": "speed_modifier",
					"unit": unit.pawn,
					"intrinsic_id": slug,
					"condition_id": weather_id,
					"multiplier": 2.0,
				})


func blocks_status(recipient: Stats, status_id: String, battle_log: BattleLog = null, pawn: TacticsPawn = null, move: PokemonMoveResource = null) -> bool:
	var normalized: String = status_id.strip_edges().to_lower()
	for slug in intrinsic_slugs_for(recipient):
		var blocked: bool = false
		if (slug == "vital_spirit" or slug == "insomnia") and SLEEP_STATUSES.has(normalized):
			blocked = true
		elif (slug == "inner_focus" or slug == "steadfast") and FLINCH_STATUSES.has(normalized):
			blocked = true
		elif STATUS_PREVENTION_BY_INTRINSIC.has(slug) and (STATUS_PREVENTION_BY_INTRINSIC[slug] as Array).has(normalized):
			blocked = true
		elif slug == "leaf_guard" and MAJOR_STATUS_IDS.has(normalized) and state_ops != null and state_ops.battle_level != null and state_ops.battle_level.effective_weather() == "sunny":
			blocked = true
		elif slug == "overcoat" and move != null and BattleStateOps.POWDER_MOVES.has(move.move_id):
			blocked = true
		if not blocked:
			continue
		if battle_log != null:
			battle_log.append({
				"kind": "status_blocked",
				"unit": pawn,
				"move_id": move.move_id if move != null else "",
				"status_id": normalized,
				"intrinsic_id": slug,
		})
		return true
	return false


func blocks_stat_stage(recipient: Stats, stat_id: String, delta: int, battle_log: BattleLog = null, pawn: TacticsPawn = null, move: PokemonMoveResource = null) -> bool:
	if recipient == null or delta >= 0:
		return false
	var normalized_stat: String = stat_id.strip_edges().to_lower()
	for slug in intrinsic_slugs_for(recipient):
		if not STAT_DROP_BLOCKS_BY_INTRINSIC.has(slug):
			continue
		var protected_stats: Array = STAT_DROP_BLOCKS_BY_INTRINSIC[slug]
		if not protected_stats.is_empty() and not protected_stats.has(normalized_stat):
			continue
		if battle_log != null:
			battle_log.append({
				"kind": "stat_stage_blocked",
				"unit": pawn,
				"move_id": move.move_id if move != null else "",
				"stat": normalized_stat,
				"delta": delta,
				"intrinsic_id": slug,
			})
		return true
	return false


func damage_intercepted(defender: TacticsPawn, move: PokemonMoveResource, battle_log: BattleLog = null) -> bool:
	if defender == null or defender.stats == null or move == null:
		return false
	for slug in intrinsic_slugs_for(defender.stats):
		if TYPE_IMMUNITY_BY_INTRINSIC.has(slug) and move.type == String(TYPE_IMMUNITY_BY_INTRINSIC[slug]):
			_log_damage_intercept(defender, move, slug, "type_immunity", battle_log)
			return true
		if slug == "soundproof" and move.has_flag("sound"):
			_log_damage_intercept(defender, move, slug, "sound_immunity", battle_log)
			return true
		if slug == "bulletproof" and BALL_MOVES.has(move.move_id):
			_log_damage_intercept(defender, move, slug, "ball_immunity", battle_log)
			return true
		if ABSORB_HEAL_BY_INTRINSIC.has(slug) and move.type == String(ABSORB_HEAL_BY_INTRINSIC[slug]):
			_heal_fraction(defender, 4, slug, battle_log)
			_log_damage_intercept(defender, move, slug, "absorb_heal", battle_log)
			return true
		if slug == "flash_fire" and move.type == "fire":
			defender.stats.apply_battle_status("type_boosted", {"source": "intrinsic", "intrinsic_id": slug, "element": "fire", "move_id": move.move_id})
			_log_damage_intercept(defender, move, slug, "absorb_boost", battle_log)
			return true
		if ABSORB_STAGE_BY_INTRINSIC.has(slug):
			var config: Dictionary = ABSORB_STAGE_BY_INTRINSIC[slug]
			if move.type != String(config.get("element", "")):
				continue
			_apply_stat_boost(defender, String(config.get("stat", "")), 1, slug, move, battle_log)
			_log_damage_intercept(defender, move, slug, "absorb_stage", battle_log)
			return true
	return false


func blocks_critical(defender: Stats) -> bool:
	for slug in intrinsic_slugs_for(defender):
		if CRITICAL_BLOCK_INTRINSICS.has(slug):
			return true
	return false


func blocks_recoil(attacker: Stats) -> bool:
	for slug in intrinsic_slugs_for(attacker):
		if RECOIL_BLOCK_INTRINSICS.has(slug):
			return true
	return false


func cap_damage_for_endure(defender: TacticsPawn, requested_damage: int, move: PokemonMoveResource, battle_log: BattleLog = null) -> int:
	if defender == null or defender.stats == null or requested_damage <= 0:
		return requested_damage
	if defender.stats.curr_health != defender.stats.max_health or requested_damage < defender.stats.curr_health:
		return requested_damage
	if not intrinsic_slugs_for(defender.stats).has("sturdy"):
		return requested_damage
	if battle_log != null:
		battle_log.append({
			"kind": "intrinsic_triggered",
			"hook": "damage_endure",
			"unit": defender,
			"intrinsic_id": "sturdy",
			"move_id": move.move_id if move != null else "",
		})
	return maxi(0, defender.stats.curr_health - 1)


func blocks_additional_effect(attacker: Stats, record: Dictionary, move: PokemonMoveResource, battle_log: BattleLog = null, pawn: TacticsPawn = null) -> bool:
	if attacker == null or not intrinsic_slugs_for(attacker).has("sheer_force"):
		return false
	if not _record_is_additional_effect(record, move):
		return false
	if battle_log != null:
		battle_log.append({
			"kind": "effect_blocked",
			"unit": pawn,
			"move_id": move.move_id if move != null else "",
			"effect_family": String(record.get("family", "")),
			"intrinsic_id": "sheer_force",
			"reason": "additional_effect_blocked",
		})
	return true


func maybe_reflect_status(attacker: TacticsPawn, recipient: TacticsPawn, status_id: String, move: PokemonMoveResource, battle_log: BattleLog) -> void:
	if attacker == null or attacker.stats == null or recipient == null or recipient.stats == null:
		return
	var normalized: String = status_id.strip_edges().to_lower()
	if not SYNCHRONIZE_STATUSES.has(normalized):
		return
	if not intrinsic_slugs_for(recipient.stats).has("synchronize"):
		return
	if attacker.stats.battle_statuses.has(normalized):
		return
	attacker.stats.apply_battle_status(normalized, {"source": "synchronize", "move_id": move.move_id if move != null else ""})
	if battle_log != null:
		battle_log.append({
			"kind": "status_applied",
			"unit": attacker,
			"move_id": move.move_id if move != null else "",
			"status_id": normalized,
			"source": "synchronize",
		})


func after_damage(attacker: TacticsPawn, defender: TacticsPawn, move: PokemonMoveResource, damage_done: int, rng: RandomNumberGenerator, battle_log: BattleLog, critical: bool = false) -> void:
	if attacker == null or defender == null or attacker.stats == null or defender.stats == null or move == null:
		return
	if damage_done <= 0:
		return
	var contact: bool = move.has_flag("contact") and not PokemonItemService.contact_shielded(attacker.stats, move)
	for slug in intrinsic_slugs_for(defender.stats):
		match slug:
			"arena_trap":
				if attacker != defender and state_ops != null and state_ops.battle_level != null and state_ops.battle_level.is_grounded(attacker):
					_apply_contact_status(attacker, "rooted", slug, move, battle_log)
			"shadow_tag":
				if attacker != defender:
					_apply_contact_status(attacker, "rooted", slug, move, battle_log)
			"cute_charm":
				if contact and attacker != defender and _chance(rng, 35) and _genders_attract(attacker.stats, defender.stats):
					_apply_contact_status(attacker, "in_love", slug, move, battle_log)
			"pickpocket":
				if contact and attacker != defender and PokemonItemService.held_item_for(defender.stats) == null and PokemonItemService.held_item_for(attacker.stats) != null and defender.stats.is_active():
					var stolen: PokemonItemResource = PokemonItemService.take_held_item(attacker, battle_log, "pickpocket")
					if stolen != null and PokemonItemService.give_held_item(defender, stolen, battle_log, "pickpocket") and battle_log != null:
						battle_log.append({"kind": "intrinsic_triggered", "hook": "steal", "unit": defender, "intrinsic_id": slug, "item_id": stolen.item_id})
			"illuminate":
				if attacker != defender and defender.stats.is_active() and _chance(rng, 25):
					_warp_farthest_ally_in(defender, slug, battle_log)
			"wandering_spirit":
				if contact and attacker != defender and attacker.stats.is_active():
					swap_intrinsics(defender, attacker, move, battle_log, slug)
			"justified":
				if move.type == "dark":
					_apply_stat_boost(defender, "attack", 1, slug, move, battle_log)
			"cursed_body":
				if _chance(rng, 30):
					_apply_contact_status(attacker, "disable", slug, move, battle_log)
			"rattled":
				if move.type in ["bug", "ghost", "dark"]:
					_apply_stat_boost(defender, "speed", 1, slug, move, battle_log)
			"weak_armor":
				if move.category == PokemonMoveResource.CATEGORY_PHYSICAL:
					_apply_stat_boost(defender, "defense", -1, slug, move, battle_log)
					_apply_stat_boost(defender, "speed", 2, slug, move, battle_log)
			"anger_point":
				if critical:
					_apply_stat_boost(defender, "attack", 12, slug, move, battle_log)
			"rough_skin", "iron_barbs":
				if contact and attacker != defender:
					_damage_fraction(attacker, 8, slug, battle_log)
			"gooey", "tangling_hair":
				if contact and attacker != defender:
					_apply_stat_boost(attacker, "speed", -1, slug, move, battle_log)
			"berserk":
				if defender.stats.curr_health > 0 and defender.stats.curr_health + damage_done > int(floor(float(defender.stats.max_health) / 2.0)) and defender.stats.curr_health <= int(floor(float(defender.stats.max_health) / 2.0)):
					_apply_stat_boost(defender, "special_attack", 1, slug, move, battle_log)
			"color_change":
				if move.is_damaging() and move.type != "none" and not defender.stats.types.has(move.type):
					_set_types(defender, [move.type], slug, battle_log)
			"mummy":
				if contact and attacker != defender and not intrinsic_slugs_for(attacker.stats).has("mummy"):
					replace_intrinsic(attacker, "mummy", move, battle_log, "mummy")
			"effect_spore":
				if contact and attacker != defender and _chance(rng, 30):
					var spore_status: String = ["poison", "paralyze", "sleep"][rng.randi_range(0, 2) if rng != null else 0]
					_apply_contact_status(attacker, spore_status, slug, move, battle_log)
		if CONTACT_STATUS_BY_INTRINSIC.has(slug) and contact and attacker != defender and _chance(rng, 30):
			_apply_contact_status(attacker, String(CONTACT_STATUS_BY_INTRINSIC[slug]), slug, move, battle_log)
	for slug in intrinsic_slugs_for(attacker.stats):
		if slug == "magnet_pull" and attacker != defender and defender.stats.types.has("steel") and defender.stats.is_active():
			_pull_adjacent(attacker, defender, slug, battle_log)
		if slug == "magician" and attacker != defender and PokemonItemService.held_item_for(attacker.stats) == null and PokemonItemService.held_item_for(defender.stats) != null:
			var taken: PokemonItemResource = PokemonItemService.take_held_item(defender, battle_log, "magician")
			if taken != null and PokemonItemService.give_held_item(attacker, taken, battle_log, "magician") and battle_log != null:
				battle_log.append({"kind": "intrinsic_triggered", "hook": "steal", "unit": attacker, "intrinsic_id": slug, "item_id": taken.item_id})
		if slug == "poison_touch" and contact and attacker != defender and _chance(rng, 30):
			_apply_contact_status(defender, "poison", slug, move, battle_log)
		if slug == "stench" and attacker != defender and _chance(rng, 10):
			_apply_contact_status(defender, "flinch", slug, move, battle_log)


func field_damage_multiplier(attacker: TacticsPawn, defender: TacticsPawn, move: PokemonMoveResource) -> float:
	var multiplier: float = 1.0
	if move == null:
		return multiplier
	var units: Array = state_ops.battle_level.units_on_map() if state_ops != null and state_ops.battle_level != null else [attacker, defender]
	var aura_break: bool = false
	var aura: bool = false
	for unit in units:
		var pawn: TacticsPawn = unit as TacticsPawn
		if pawn == null or pawn.stats == null or not pawn.stats.is_active():
			continue
		for slug in intrinsic_slugs_for(pawn.stats):
			if AURA_TYPES.has(slug) and move.type == String(AURA_TYPES[slug]):
				aura = true
			elif slug == "aura_break":
				aura_break = true
	if aura:
		multiplier *= (0.75 if aura_break else 4.0 / 3.0)
	if defender != null and defender.stats != null and attacker != defender and _ally_has_any(defender.stats, ["friend_guard"], true):
		multiplier *= 0.75
	return multiplier


func on_knockout(attacker: TacticsPawn, defender: TacticsPawn, move: PokemonMoveResource, battle_log: BattleLog) -> void:
	if attacker == null or defender == null or attacker.stats == null or defender.stats == null or attacker == defender:
		return
	for slug in intrinsic_slugs_for(attacker.stats):
		if slug == "moxie":
			_apply_stat_boost(attacker, "attack", 1, slug, move, battle_log)
	for slug in intrinsic_slugs_for(defender.stats):
		if slug == "aftermath" and move != null and move.has_flag("contact") and not _field_has_intrinsic("damp", attacker):
			_damage_fraction(attacker, 4, slug, battle_log)
	var fallen_slugs: Array[String] = intrinsic_slugs_for(defender.stats).duplicate()
	for ally in _allies_of(defender, false):
		if ally == defender or ally.stats == null or not ally.stats.is_active():
			continue
		var ally_slugs: Array[String] = intrinsic_slugs_for(ally.stats)
		if (ally_slugs.has("power_of_alchemy") or ally_slugs.has("receiver")) and not fallen_slugs.is_empty():
			replace_intrinsics(ally, fallen_slugs, move, battle_log, "power_of_alchemy")
	if state_ops != null and state_ops.battle_level != null:
		state_ops.battle_level.end_strong_weather_from(defender)


func accuracy_multiplier(attacker: TacticsPawn, defender: TacticsPawn, move: PokemonMoveResource, battle_level: TacticsLevel) -> float:
	var multiplier: float = 1.0
	if attacker != null and attacker.stats != null:
		if intrinsic_slugs_for(attacker.stats).has("victory_star") or _ally_has_any(attacker.stats, ["victory_star"], true):
			multiplier *= 1.1
		for slug in intrinsic_slugs_for(attacker.stats):
			if slug == "compound_eyes":
				multiplier *= 1.3
			elif slug == "hustle" and move != null and move.category == PokemonMoveResource.CATEGORY_PHYSICAL:
				multiplier *= 0.8
	if defender != null and defender.stats != null and defender != attacker:
		var weather: String = battle_level.effective_weather() if battle_level != null else ""
		for slug in intrinsic_slugs_for(defender.stats):
			if slug == "sand_veil" and weather == "sandstorm":
				multiplier *= 0.8
			elif slug == "snow_cloak" and weather == "hail":
				multiplier *= 0.8
			elif slug == "tangled_feet" and defender.stats.battle_statuses.has("confuse"):
				multiplier *= 0.5
			elif slug == "wonder_skin" and move != null and move.category == PokemonMoveResource.CATEGORY_STATUS and move.accuracy > 50:
				multiplier *= 50.0 / float(move.accuracy)
	return multiplier


func sure_hit(attacker: Stats, defender: Stats) -> bool:
	return intrinsic_slugs_for(attacker).has("no_guard") or intrinsic_slugs_for(defender).has("no_guard")


func effect_chance_multiplier(attacker: Stats) -> float:
	return 2.0 if attacker != null and intrinsic_slugs_for(attacker).has("serene_grace") else 1.0


func shields_additional_effect(defender: Stats, record: Dictionary, move: PokemonMoveResource, battle_log: BattleLog = null, pawn: TacticsPawn = null) -> bool:
	if defender == null or not intrinsic_slugs_for(defender).has("shield_dust"):
		return false
	if not _record_is_additional_effect(record, move):
		return false
	if battle_log != null:
		battle_log.append({"kind": "effect_blocked", "unit": pawn, "move_id": move.move_id if move != null else "", "effect_family": String(record.get("family", "")), "intrinsic_id": "shield_dust", "reason": "additional_effect_blocked"})
	return true


func crit_stage_bonus(attacker: Stats) -> int:
	return 1 if attacker != null and intrinsic_slugs_for(attacker).has("super_luck") else 0


func ignores_stages(stats: Stats) -> bool:
	return stats != null and intrinsic_slugs_for(stats).has("unaware")


func transform_stat_delta(stats: Stats, delta: int) -> int:
	var out: int = delta
	for slug in intrinsic_slugs_for(stats):
		if slug == "contrary":
			out = -out
		elif slug == "simple":
			out *= 2
	return out


func after_status_applied(unit: TacticsPawn, status_id: String) -> void:
	if unit == null or unit.stats == null:
		return
	if SLEEP_STATUSES.has(status_id) and intrinsic_slugs_for(unit.stats).has("early_bird"):
		var payload: Variant = unit.stats.battle_statuses.get(status_id, {})
		if payload is Dictionary and (payload as Dictionary).has("counter"):
			var data: Dictionary = (payload as Dictionary).duplicate(true)
			data["counter"] = maxi(1, int(ceil(float(int(data["counter"])) / 2.0)))
			unit.stats.battle_statuses[status_id] = data


func adjust_effectiveness(attacker: Stats, defender: Stats, move: PokemonMoveResource, effectiveness: float, type_chart: TypeChartResource) -> float:
	if effectiveness > 0.0 or attacker == null or defender == null or move == null or type_chart == null:
		return effectiveness
	if not intrinsic_slugs_for(attacker).has("scrappy") or not (move.type == "normal" or move.type == "fighting") or not defender.types.has("ghost"):
		return effectiveness
	var other: String = "none"
	for type_id in defender.types:
		if String(type_id) != "ghost":
			other = String(type_id)
	return type_chart.get_effectiveness_dual(move.type, other, "none")


func begin_hit(attacker: Stats, defender: Stats) -> void:
	_ignored_stats = null
	if attacker == null or defender == null or attacker == defender:
		return
	for slug in intrinsic_slugs_for(attacker):
		if ABILITY_IGNORING_INTRINSICS.has(slug):
			_ignored_stats = defender
			return


func end_hit() -> void:
	_ignored_stats = null


func blocks_indirect_damage(stats: Stats) -> bool:
	return stats != null and intrinsic_slugs_for(stats).has("magic_guard")


func heals_from_poison(stats: Stats) -> bool:
	return stats != null and intrinsic_slugs_for(stats).has("poison_heal")


func suppresses_weather(units: Array) -> bool:
	for unit in units:
		var pawn: TacticsPawn = unit as TacticsPawn
		if pawn == null or pawn.stats == null or not pawn.stats.is_active():
			continue
		for slug in intrinsic_slugs_for(pawn.stats):
			if WEATHER_SUPPRESSING_INTRINSICS.has(slug):
				return true
	return false


func berry_threshold_fraction(stats: Stats) -> float:
	return 0.5 if stats != null and intrinsic_slugs_for(stats).has("gluttony") else 0.25


func berries_blocked_for(unit: TacticsPawn) -> bool:
	if unit == null or state_ops == null or state_ops.battle_level == null:
		return false
	for other in state_ops.battle_level.units_on_map():
		if other == unit or other.stats == null or not other.stats.is_active():
			continue
		if state_ops.battle_level.are_foes(unit, other) and intrinsic_slugs_for(other.stats).has("unnerve"):
			return true
	return false


func field_blocks_explosions(unit: TacticsPawn) -> bool:
	return _field_has_intrinsic("damp", unit)


func _field_has_intrinsic(slug: String, reference: TacticsPawn) -> bool:
	if state_ops == null or state_ops.battle_level == null:
		return reference != null and reference.stats != null and intrinsic_slugs_for(reference.stats).has(slug)
	for other in state_ops.battle_level.units_on_map():
		if other.stats != null and other.stats.is_active() and intrinsic_slugs_for(other.stats).has(slug):
			return true
	return false


func _move_has_recoil(move: PokemonMoveResource) -> bool:
	for record in move.effect_records:
		if String(record.get("family", "")) == "recoil":
			return true
	return false


func pressure_extra_pp_cost(targets: Array[TacticsPawn]) -> int:
	for target in targets:
		if target != null and target.stats != null and intrinsic_slugs_for(target.stats).has("pressure"):
			return 1
	return 0


func current_intrinsics(stats: Stats) -> Array[String]:
	return intrinsic_slugs_for(stats)


func replace_intrinsic(unit: TacticsPawn, intrinsic_id: String, move: PokemonMoveResource = null, battle_log: BattleLog = null, source_event: String = "") -> Dictionary:
	return replace_intrinsics(unit, [intrinsic_id], move, battle_log, source_event)


func replace_intrinsics(unit: TacticsPawn, intrinsic_ids: Array, move: PokemonMoveResource = null, battle_log: BattleLog = null, source_event: String = "") -> Dictionary:
	if unit == null or unit.stats == null:
		return {}
	var before: Array[String] = intrinsic_slugs_for(unit.stats)
	unit.stats.set_temporary_intrinsics(intrinsic_ids)
	var after: Array[String] = intrinsic_slugs_for(unit.stats)
	var payload: Dictionary = {
		"unit": unit,
		"move_id": move.move_id if move != null else "",
		"source_event": source_event,
		"before": before,
		"after": after,
	}
	_log_intrinsic_changed(payload, battle_log)
	return payload


func restore_natural_intrinsics(unit: TacticsPawn, move: PokemonMoveResource = null, battle_log: BattleLog = null, source_event: String = "") -> Dictionary:
	if unit == null or unit.stats == null:
		return {}
	var before: Array[String] = intrinsic_slugs_for(unit.stats)
	unit.stats.clear_temporary_intrinsics()
	var after: Array[String] = intrinsic_slugs_for(unit.stats)
	var payload: Dictionary = {
		"unit": unit,
		"move_id": move.move_id if move != null else "",
		"source_event": source_event,
		"before": before,
		"after": after,
		"restored": true,
	}
	_log_intrinsic_changed(payload, battle_log)
	return payload


func copy_intrinsics(source: TacticsPawn, recipient: TacticsPawn, move: PokemonMoveResource = null, battle_log: BattleLog = null, source_event: String = "") -> Dictionary:
	if source == null or source.stats == null or recipient == null or recipient.stats == null:
		return {}
	return replace_intrinsics(recipient, intrinsic_slugs_for(source.stats), move, battle_log, source_event)


func swap_intrinsics(first: TacticsPawn, second: TacticsPawn, move: PokemonMoveResource = null, battle_log: BattleLog = null, source_event: String = "") -> Array[Dictionary]:
	if first == null or first.stats == null or second == null or second.stats == null:
		return []
	var first_before: Array[String] = intrinsic_slugs_for(first.stats)
	var second_before: Array[String] = intrinsic_slugs_for(second.stats)
	first.stats.set_temporary_intrinsics(second_before)
	second.stats.set_temporary_intrinsics(first_before)
	var first_payload: Dictionary = {
		"unit": first,
		"move_id": move.move_id if move != null else "",
		"source_event": source_event,
		"before": first_before,
		"after": intrinsic_slugs_for(first.stats),
		"swap_partner": second,
	}
	var second_payload: Dictionary = {
		"unit": second,
		"move_id": move.move_id if move != null else "",
		"source_event": source_event,
		"before": second_before,
		"after": intrinsic_slugs_for(second.stats),
		"swap_partner": first,
	}
	_log_intrinsic_changed(first_payload, battle_log)
	_log_intrinsic_changed(second_payload, battle_log)
	return [first_payload, second_payload]


static func natural_slugs_static(stats: Stats) -> Array[String]:
	var out: Array[String] = []
	if stats == null:
		return out
	if stats.intrinsic_override_active or not stats.temporary_intrinsic_slugs.is_empty():
		for slug in stats.temporary_intrinsic_slugs:
			if not String(slug).is_empty() and not out.has(String(slug)):
				out.append(String(slug))
		if stats.intrinsic_override_active:
			return out
	if stats.pokemon_instance == null:
		return out
	var override_slug: String = String(stats.pokemon_instance.ability_override).strip_edges().to_lower()
	if not override_slug.is_empty() and override_slug != "none":
		if not out.has(override_slug):
			out.append(override_slug)
		return out
	var form: PokemonFormResource = stats.pokemon_instance.resolved_form()
	if form == null:
		return out
	for slug in [form.intrinsic1, form.intrinsic2, form.intrinsic3]:
		var key: String = String(slug)
		if key.is_empty() or key == "none":
			continue
		if not out.has(key):
			out.append(key)
		break
	return out


static func range_bonus_for(stats: Stats, move: PokemonMoveResource) -> int:
	if stats == null or move == null or move.tactical_range_kind == PokemonMoveResource.TacticalRangeKind.SELF:
		return 0
	var bonus: int = 0
	var slugs: Array[String] = natural_slugs_static(stats)
	if slugs.has("prankster") and move.category == PokemonMoveResource.CATEGORY_STATUS:
		bonus += 2
	if slugs.has("gale_wings") and move.type == "flying" and stats.curr_health >= stats.max_health:
		bonus += 1
	return bonus


func intrinsic_slugs_for(stats: Stats) -> Array[String]:
	if stats != null and stats == _ignored_stats:
		return []
	if stats != null and _neutralizing_gas_active(stats):
		return []
	return _natural_slugs(stats)


func _natural_slugs(stats: Stats) -> Array[String]:
	var out: Array[String] = []
	if stats == null:
		return out
	if stats.intrinsic_override_active:
		for slug in stats.temporary_intrinsic_slugs:
			var temporary_key: String = String(slug)
			if temporary_key.is_empty() or out.has(temporary_key):
				continue
			out.append(temporary_key)
		return out
	for slug in stats.temporary_intrinsic_slugs:
		var override_key: String = String(slug)
		if override_key.is_empty() or out.has(override_key):
			continue
		out.append(override_key)
	if stats.pokemon_instance == null:
		return out
	var override_slug: String = String(stats.pokemon_instance.ability_override).strip_edges().to_lower()
	if not override_slug.is_empty() and override_slug != "none":
		if not out.has(override_slug):
			out.append(override_slug)
		return out
	var form: PokemonFormResource = stats.pokemon_instance.resolved_form()
	if form == null:
		return out
	for slug in [form.intrinsic1, form.intrinsic2, form.intrinsic3]:
		var key: String = String(slug)
		if key.is_empty() or key == "none" or out.has(key):
			continue
		out.append(key)
		break
	return out


func _log_intrinsic_changed(payload: Dictionary, battle_log: BattleLog) -> void:
	if battle_log == null:
		return
	var event: Dictionary = payload.duplicate(true)
	event["kind"] = "intrinsic_changed"
	battle_log.append(event)


func _damage_multiplier_for_slug(slug: String, attacker: Stats, move: PokemonMoveResource, battle_level: TacticsLevel = null, effectiveness: float = 1.0, target: TacticsPawn = null) -> float:
	if slug == "rivalry" and target != null and target.stats != null and move.is_damaging():
		if GenderRules.same(attacker.gender, target.stats.gender):
			return 1.25
		if GenderRules.opposite(attacker.gender, target.stats.gender):
			return 0.75
		return 1.0
	if slug == "stall" and target != null and target.stats != null and move.is_damaging() and target.stats.last_attacker is TacticsPawn and (target.stats.last_attacker as TacticsPawn).stats == attacker:
		return 1.25
	if slug == "flower_gift" and move.category == PokemonMoveResource.CATEGORY_PHYSICAL and battle_level != null and battle_level.effective_weather() in ["sunny", "desolate_land"]:
		return 1.25
	if slug == "tinted_lens" and effectiveness > 0.0 and effectiveness < 1.0:
		return 2.0
	if slug == "reckless" and _move_has_recoil(move):
		return 1.2
	if slug == "analytic" and target != null and target.res != null and target.res.has_acted_this_round:
		return 1.3
	if (slug == "huge_power" or slug == "pure_power") and move.category == PokemonMoveResource.CATEGORY_PHYSICAL:
		return 2.0
	if slug == "flare_boost" and move.category == PokemonMoveResource.CATEGORY_SPECIAL and attacker.battle_statuses.has("burn"):
		return 1.5
	if slug == "toxic_boost" and move.category == PokemonMoveResource.CATEGORY_PHYSICAL and (attacker.battle_statuses.has("poison") or attacker.battle_statuses.has("poison_toxic")):
		return 1.5
	if slug == "defeatist" and attacker.curr_health <= int(floor(float(attacker.max_health) / 2.0)):
		return 0.5
	if slug == "strong_jaw" and move.has_flag("jaw"):
		return 1.5
	if MOVE_TYPE_OVERRIDES.has(slug) and bool(move.get_meta("type_overridden", false)):
		return 1.2
	if slug == "normalize" and bool(move.get_meta("type_overridden", false)):
		return 1.2
	if slug == "gorilla_tactics" and move.category == PokemonMoveResource.CATEGORY_PHYSICAL:
		return 1.5
	if slug == "slow_start" and attacker.battle_statuses.has("slow_start") and move.category == PokemonMoveResource.CATEGORY_PHYSICAL:
		return 0.5
	if (slug == "plus" or slug == "minus") and move.category == PokemonMoveResource.CATEGORY_SPECIAL and _ally_has_any(attacker, ["plus", "minus"]):
		return 1.5
	if PINCH_DAMAGE_BOOSTS.has(slug):
		if String(PINCH_DAMAGE_BOOSTS[slug]) == move.type and attacker.curr_health <= int(floor(float(attacker.max_health) / 4.0)):
			return 2.0
	if slug == "sharpness" and _is_slicing_move(move):
		return 1.5
	if slug == "tough_claws" and move.category == PokemonMoveResource.CATEGORY_PHYSICAL:
		return 1.3
	if slug == "mega_launcher" and _is_pulse_move(move):
		return 1.5
	if slug == "guts" and move.category == PokemonMoveResource.CATEGORY_PHYSICAL and _has_major_status(attacker):
		return 1.5
	if slug == "hustle" and move.category == PokemonMoveResource.CATEGORY_PHYSICAL:
		return 4.0 / 3.0
	if slug == "sheer_force" and _move_has_additional_effect(move):
		return 4.0 / 3.0
	if slug == "technician" and move.base_power > 0 and move.base_power <= 40:
		return 1.5
	if slug == "iron_fist" and _is_punch_move(move):
		return 1.25
	if slug == "sand_force" and battle_level != null and (battle_level.has_battle_condition("sandstorm") or battle_level.has_battle_condition("sand")) and ["rock", "ground", "steel"].has(move.type):
		return 4.0 / 3.0
	if attacker.battle_statuses.has("type_boosted"):
		var payload: Variant = attacker.battle_statuses.get("type_boosted", {})
		if payload is Dictionary and String((payload as Dictionary).get("element", "")) == move.type:
			return 1.5
	return 1.0


func _has_major_status(stats: Stats) -> bool:
	for status_id in MAJOR_STATUS_IDS:
		if stats.battle_statuses.has(status_id):
			return true
	return false


func _move_has_additional_effect(move: PokemonMoveResource) -> bool:
	if move == null:
		return false
	for record in move.effect_records:
		if _record_is_additional_effect(record, move):
			return true
	return false


func _record_is_additional_effect(record: Dictionary, move: PokemonMoveResource) -> bool:
	if record.has("wrapped_source_event"):
		return true
	return move != null and move.is_damaging() and record.has("chance") and int(record.get("chance", 100)) < 100


func _is_slicing_move(move: PokemonMoveResource) -> bool:
	var id: String = move.move_id
	return id.contains("cut") or id.contains("slash") or id.contains("blade") or id.contains("cutter") or id == "razor_leaf"


func _is_punch_move(move: PokemonMoveResource) -> bool:
	var id: String = move.move_id
	return id.contains("punch") or id == "comet_punch" or id == "dizzy_punch"


func _is_pulse_move(move: PokemonMoveResource) -> bool:
	var id: String = move.move_id
	return id.contains("pulse") or id == "aura_sphere"


func _ops(pawn: TacticsPawn, battle_log: BattleLog) -> BattleStateOps:
	if state_ops != null:
		return state_ops
	return BattleStateOps.for_pawn(pawn, battle_log, self)


func _heal_fraction(pawn: TacticsPawn, divisor: int, intrinsic_id: String, battle_log: BattleLog) -> void:
	if pawn == null or pawn.stats == null or divisor <= 0:
		return
	var amount: int = maxi(1, int(floor(float(pawn.stats.max_health) / float(divisor))))
	_ops(pawn, battle_log).heal(pawn, amount, {"kind": "intrinsic", "intrinsic_id": intrinsic_id})


func _damage_fraction(pawn: TacticsPawn, divisor: int, intrinsic_id: String, battle_log: BattleLog) -> void:
	if pawn == null or pawn.stats == null or divisor <= 0:
		return
	var amount: int = maxi(1, int(floor(float(pawn.stats.max_health) / float(divisor))))
	_ops(pawn, battle_log).damage(pawn, amount, {"kind": "intrinsic", "intrinsic_id": intrinsic_id})


func _log_damage_intercept(pawn: TacticsPawn, move: PokemonMoveResource, intrinsic_id: String, reason: String, battle_log: BattleLog) -> void:
	if battle_log == null:
		return
	battle_log.append({
		"kind": "damage_prevented",
		"unit": pawn,
		"defender": pawn,
		"move_id": move.move_id if move != null else "",
		"source": "intrinsic",
		"intrinsic_id": intrinsic_id,
		"reason": reason,
	})


func _apply_stat_boost(pawn: TacticsPawn, stat_id: String, delta: int, intrinsic_id: String, move: PokemonMoveResource, battle_log: BattleLog) -> void:
	_ops(pawn, battle_log).change_stat_stage(pawn, stat_id, delta, {"kind": "intrinsic", "intrinsic_id": intrinsic_id, "move": move, "attacker": pawn})


func _apply_contact_status(pawn: TacticsPawn, status_id: String, intrinsic_id: String, move: PokemonMoveResource, battle_log: BattleLog) -> void:
	if pawn == null or pawn.stats == null or status_id.is_empty():
		return
	_ops(pawn, battle_log).apply_status(pawn, status_id, {"source": "intrinsic", "intrinsic_id": intrinsic_id, "move_id": move.move_id if move != null else ""}, {"kind": "intrinsic", "intrinsic_id": intrinsic_id, "move": move})


func on_turn_completed(pawn: TacticsPawn, battle_log: BattleLog) -> void:
	if pawn == null or pawn.stats == null or not pawn.stats.is_active():
		return
	if intrinsic_slugs_for(pawn.stats).has("truant") and not pawn.stats.battle_statuses.has("paused"):
		_ops(pawn, battle_log).apply_status(pawn, "paused", {"counter": 2, "source": "intrinsic", "intrinsic_id": "truant"}, {"kind": "intrinsic", "intrinsic_id": "truant", "skip_rules": true})


func _apply_battle_start_effect(slug: String, pawn: TacticsPawn, units: Array[BattleUnit], battle_level: TacticsLevel, battle_log: BattleLog) -> void:
	match slug:
		"download":
			var foe: TacticsPawn = null
			for unit in units:
				if unit.pawn != null and unit.pawn != pawn and unit.team != _team_of(pawn, units):
					foe = unit.pawn
					break
			if foe != null and foe.stats != null:
				var stat_id: String = "attack" if foe.stats.battle_stat("defense") < foe.stats.battle_stat("special_defense") else "special_attack"
				_apply_stat_boost(pawn, stat_id, 1, slug, null, battle_log)
		"intimidate":
			for unit in units:
				if unit.pawn == null or unit.pawn == pawn or unit.stats == null or unit.team == _team_of(pawn, units) or not unit.stats.is_active():
					continue
				_ops(pawn, battle_log).change_stat_stage(unit.pawn, "attack", -1, {"kind": "intrinsic", "attacker": pawn, "intrinsic_id": slug, "event": {"source": "intimidate"}})
		"electric_surge", "grassy_surge", "misty_surge", "psychic_surge":
			if battle_level != null:
				battle_level.set_terrain(String(TERRAIN_BY_SURGE[slug]), 5, slug)
		"desolate_land", "primordial_sea", "delta_stream":
			if battle_level != null:
				battle_level.set_battle_condition(String(STRONG_WEATHER_BY_INTRINSIC[slug]), {"source_intrinsic": slug, "unit": pawn.name})
		"imposter":
			var nearest: TacticsPawn = null
			var best: int = 999
			for unit in units:
				if unit.pawn != null and unit.pawn != pawn and unit.stats != null and unit.team != _team_of(pawn, units) and unit.stats.is_active():
					var d: int = _grid_distance_between(pawn, unit.pawn)
					if d < best:
						best = d
						nearest = unit.pawn
			if nearest != null and pawn.stats.transform_into(nearest.stats, intrinsic_slugs_for(nearest.stats)) and battle_log != null:
				battle_log.append({"kind": "transformed", "unit": pawn, "defender": nearest, "intrinsic_id": slug})
		"forecast", "flower_gift":
			if battle_level != null:
				_apply_weather_form(pawn, slug, battle_level.effective_weather(), battle_log)
		"slow_start":
			_ops(pawn, battle_log).apply_status(pawn, "slow_start", {"counter": 5, "source": "intrinsic", "intrinsic_id": slug}, {"kind": "intrinsic", "intrinsic_id": slug, "skip_rules": true})
		"forewarn":
			var strongest: String = ""
			var best_power: int = -1
			for unit in units:
				if unit.pawn == null or unit.pawn == pawn or unit.team == _team_of(pawn, units) or unit.stats == null:
					continue
				for move in unit.stats.move_slots:
					if move != null and move.base_power > best_power:
						best_power = move.base_power
						strongest = move.move_id
			if not strongest.is_empty() and battle_log != null:
				battle_log.append({"kind": "intrinsic_triggered", "hook": "forewarn", "unit": pawn, "intrinsic_id": slug, "move_id": strongest})
		"screen_cleaner":
			if battle_level != null:
				for condition in BattleStateOps.SCREEN_STATUSES:
					for unit in units:
						if unit.pawn != null and unit.stats != null and unit.stats.battle_statuses.has(condition):
							_ops(unit.pawn, battle_log).remove_status(unit.pawn, condition, {"source": "intrinsic", "intrinsic_id": slug})
		"curious_medicine":
			for ally in _allies_of(pawn, false):
				for stat_id in ["attack", "defense", "special_attack", "special_defense", "speed", "accuracy", "evasion"]:
					if ally.stats.get_stat_stage(stat_id) != 0:
						ally.stats.set_stat_stage(stat_id, 0)


func _neutralizing_gas_active(stats: Stats) -> bool:
	if state_ops == null or state_ops.battle_level == null:
		return false
	for other in state_ops.battle_level.units_on_map():
		if other.stats == null or other.stats == stats or not other.stats.is_active():
			continue
		var override: String = other.stats.pokemon_instance.ability_override if other.stats.pokemon_instance != null else ""
		if override == "neutralizing_gas" or (override.is_empty() and _natural_slugs(other.stats).has("neutralizing_gas")):
			return true
	return false


func _team_of(pawn: TacticsPawn, units: Array[BattleUnit]) -> int:
	for unit in units:
		if unit.pawn == pawn:
			return unit.team
	return -1


func _allies_of(pawn: TacticsPawn, adjacent_only: bool) -> Array[TacticsPawn]:
	var out: Array[TacticsPawn] = []
	if pawn == null or state_ops == null or state_ops.battle_level == null:
		return out
	for other in state_ops.battle_level.units_on_map():
		if other == pawn or other.stats == null or not other.stats.is_active() or state_ops.battle_level.are_foes(pawn, other):
			continue
		if adjacent_only and pawn.get_tile() != null and other.get_tile() != null:
			var a: Vector3i = Targeting._tile_key(pawn.get_tile())
			var b: Vector3i = Targeting._tile_key(other.get_tile())
			if maxi(absi(a.x - b.x), absi(a.z - b.z)) > 1:
				continue
		out.append(other)
	return out


func _foes_of(pawn: TacticsPawn) -> Array[TacticsPawn]:
	var out: Array[TacticsPawn] = []
	if pawn == null or state_ops == null or state_ops.battle_level == null:
		return out
	for other in state_ops.battle_level.units_on_map():
		if other != pawn and other.stats != null and other.stats.is_active() and state_ops.battle_level.are_foes(pawn, other):
			out.append(other)
	return out


func _ally_has_any(stats: Stats, slugs: Array, others_only: bool = false) -> bool:
	if state_ops == null or state_ops.battle_level == null:
		return false
	var owner: TacticsPawn = null
	for unit in state_ops.battle_level.units_on_map():
		if unit.stats == stats:
			owner = unit
	if owner == null:
		return false
	for ally in _allies_of(owner, false):
		for slug in slugs:
			if intrinsic_slugs_for(ally.stats).has(String(slug)):
				return true
	return false


func _set_types(pawn: TacticsPawn, types: Array, intrinsic_id: String, battle_log: BattleLog) -> void:
	var typed: Array[String] = []
	for type_id in types:
		typed.append(String(type_id))
	pawn.stats.types = typed
	if battle_log != null:
		battle_log.append({"kind": "type_changed", "unit": pawn, "types": typed.duplicate(), "source": "intrinsic", "intrinsic_id": intrinsic_id})


func move_type_override(attacker: Stats, move: PokemonMoveResource) -> String:
	if attacker == null or move == null:
		return ""
	for slug in intrinsic_slugs_for(attacker):
		if MOVE_TYPE_OVERRIDES.has(slug) and move.type == "normal":
			return String(MOVE_TYPE_OVERRIDES[slug])
		if slug == "normalize" and move.type != "normal" and move.is_damaging():
			return "normal"
	return ""


func before_move_used(attacker: TacticsPawn, move: PokemonMoveResource, battle_log: BattleLog) -> void:
	if attacker == null or attacker.stats == null or move == null:
		return
	if intrinsic_slugs_for(attacker.stats).has("protean") and move.type != "none" and not (attacker.stats.types.size() == 1 and attacker.stats.types[0] == move.type):
		_set_types(attacker, [move.type], "protean", battle_log)
	if intrinsic_slugs_for(attacker.stats).has("stance_change") and attacker.stats.pokemon_instance != null and attacker.stats.pokemon_instance.species != null and attacker.stats.pokemon_instance.species.species_id.ends_with("aegislash"):
		var wanted: int = 1 if move.is_damaging() else (0 if move.move_id == "kings_shield" else attacker.stats.pokemon_instance.form_index)
		if wanted != attacker.stats.pokemon_instance.form_index and attacker.stats.change_form(wanted):
			_log_form_change(attacker, "stance_change", wanted, battle_log)


func on_berry_consumed(pawn: TacticsPawn, item_id: String, battle_log: BattleLog) -> void:
	if pawn == null or pawn.stats == null:
		return
	for slug in intrinsic_slugs_for(pawn.stats):
		if slug == "cheek_pouch":
			_heal_fraction(pawn, 3, slug, battle_log)
		elif slug == "unburden":
			pawn.stats.apply_battle_status("unburden", {"source": "intrinsic", "intrinsic_id": slug, "item_id": item_id})


func wonder_guard_blocks(defender: Stats, effectiveness: float, move: PokemonMoveResource) -> bool:
	return defender != null and move != null and move.is_damaging() and intrinsic_slugs_for(defender).has("wonder_guard") and effectiveness <= 1.0


func reverses_drain(defender: Stats) -> bool:
	return defender != null and intrinsic_slugs_for(defender).has("liquid_ooze")


func ally_veil_blocks_status(unit: TacticsPawn, status_id: String, attacker: TacticsPawn) -> String:
	if unit == null or unit.stats == null:
		return ""
	var group: Array[TacticsPawn] = _allies_of(unit, false)
	group.append(unit)
	for member in group:
		for slug in intrinsic_slugs_for(member.stats):
			if slug == "pastel_veil" and (status_id == "poison" or status_id == "poison_toxic"):
				return slug
			if slug == "flower_veil" and unit.stats.types.has("grass") and attacker != null and attacker != unit and MAJOR_STATUS_IDS.has(status_id):
				return slug
			if ALLY_VEIL_STATUSES.has(slug) and (ALLY_VEIL_STATUSES[slug] as Array).has(status_id):
				return slug
	return ""


func ally_veil_blocks_stat_drop(unit: TacticsPawn, attacker: TacticsPawn) -> bool:
	if unit == null or unit.stats == null or attacker == null or attacker == unit or not unit.stats.types.has("grass"):
		return false
	var group: Array[TacticsPawn] = _allies_of(unit, false)
	group.append(unit)
	for member in group:
		if intrinsic_slugs_for(member.stats).has("flower_veil"):
			return true
	return false


func _cure_major_status(pawn: TacticsPawn, intrinsic_id: String, battle_log: BattleLog) -> void:
	for status_id in MAJOR_STATUS_IDS:
		if pawn.stats.battle_statuses.has(status_id):
			_ops(pawn, battle_log).remove_status(pawn, status_id, {"source": "intrinsic", "intrinsic_id": intrinsic_id})


func on_stat_lowered_by_foe(unit: TacticsPawn, attacker: TacticsPawn, stat_id: String, delta: int, move: PokemonMoveResource, battle_log: BattleLog) -> void:
	if unit == null or unit.stats == null:
		return
	for slug in intrinsic_slugs_for(unit.stats):
		match slug:
			"defiant":
				_apply_stat_boost(unit, "attack", 2, slug, move, battle_log)
			"competitive":
				_apply_stat_boost(unit, "special_attack", 2, slug, move, battle_log)


func _chance(rng: RandomNumberGenerator, percent: int) -> bool:
	if percent >= 100:
		return true
	if percent <= 0:
		return false
	var source_rng: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	return source_rng.randf() * 100.0 < float(percent)


func _genders_attract(a: Stats, b: Stats) -> bool:
	if a == null or b == null:
		return false
	return GenderRules.opposite(a.gender, b.gender)


func _grid_distance_between(a: TacticsPawn, b: TacticsPawn) -> int:
	if a == null or b == null or a.get_tile() == null or b.get_tile() == null:
		return 999
	var ka: Vector3i = Targeting._tile_key(a.get_tile())
	var kb: Vector3i = Targeting._tile_key(b.get_tile())
	return maxi(absi(ka.x - kb.x), absi(ka.z - kb.z))


func _apply_hp_form(pawn: TacticsPawn, slug: String, battle_log: BattleLog) -> void:
	var instance: PokemonInstanceResource = pawn.stats.pokemon_instance
	if instance == null or instance.species == null or instance.species.forms.size() < 2:
		return
	var low: bool = pawn.stats.curr_health * 2 < pawn.stats.max_health
	var wanted: int = (instance.species.forms.size() - 1 if slug == "power_construct" else 1) if low else 0
	if wanted != instance.form_index and pawn.stats.change_form(wanted):
		_log_form_change(pawn, slug, wanted, battle_log)


func _apply_weather_form(pawn: TacticsPawn, slug: String, weather: String, battle_log: BattleLog) -> void:
	var instance: PokemonInstanceResource = pawn.stats.pokemon_instance
	if instance == null or instance.species == null:
		return
	var species_key: String = ""
	for key in FORM_SPECIES.keys():
		if instance.species.species_id.ends_with(String(key)):
			species_key = String(key)
	if species_key.is_empty():
		return
	var wanted: int = int((FORM_SPECIES[species_key] as Dictionary).get(weather, 0))
	if wanted >= instance.species.forms.size():
		return
	if wanted != instance.form_index and pawn.stats.change_form(wanted):
		_log_form_change(pawn, slug, wanted, battle_log)


func _log_form_change(pawn: TacticsPawn, slug: String, form_index: int, battle_log: BattleLog) -> void:
	if battle_log != null:
		battle_log.append({"kind": "form_changed", "unit": pawn, "intrinsic_id": slug, "form_index": form_index, "types": pawn.stats.types.duplicate()})


func _free_adjacent_tile(anchor: TacticsPawn) -> TacticsTile:
	if state_ops == null or state_ops.battle_level == null or anchor.get_tile() == null:
		return null
	var level: TacticsLevel = state_ops.battle_level
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	var origin: Vector3i = Targeting._tile_key(anchor.get_tile())
	var occupied: Dictionary = {}
	for unit in level.units_on_map():
		if unit.stats != null and unit.stats.is_active() and unit.get_tile() != null:
			occupied[Targeting._tile_key(unit.get_tile())] = true
	for direction in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		var key: Vector3i = origin + direction
		if keys.has(key) and not occupied.has(key):
			return keys[key]
	return null


func _pull_adjacent(attacker: TacticsPawn, target: TacticsPawn, slug: String, battle_log: BattleLog) -> void:
	if _grid_distance_between(attacker, target) <= 1:
		return
	var tile: TacticsTile = _free_adjacent_tile(attacker)
	if tile == null:
		return
	_relocate(target, tile)
	if battle_log != null:
		battle_log.append({"kind": "forced_movement", "unit": target, "mode": "pull", "to": Targeting._tile_key(tile), "intrinsic_id": slug, "move_id": ""})
	state_ops.battle_level.on_pawn_reached_tile(target, target.global_position)


func _warp_farthest_ally_in(pawn: TacticsPawn, slug: String, battle_log: BattleLog) -> void:
	var farthest: TacticsPawn = null
	var best: int = 1
	for ally in _allies_of(pawn, false):
		if ally == pawn or ally.stats == null or not ally.stats.is_active():
			continue
		var d: int = _grid_distance_between(pawn, ally)
		if d > best:
			best = d
			farthest = ally
	if farthest == null:
		return
	var tile: TacticsTile = _free_adjacent_tile(pawn)
	if tile == null:
		return
	_relocate(farthest, tile)
	if battle_log != null:
		battle_log.append({"kind": "forced_movement", "unit": farthest, "mode": "warp_near", "to": Targeting._tile_key(tile), "intrinsic_id": slug, "move_id": ""})


func _relocate(pawn: TacticsPawn, tile: TacticsTile) -> void:
	var ray: RayCast3D = pawn.get_node_or_null("Tile") as RayCast3D
	pawn.global_position = tile.global_position + Vector3.UP * 0.05
	if ray != null:
		ray.force_raycast_update()
	if pawn.has_method("center"):
		pawn.center()
	if ray != null:
		ray.force_raycast_update()
	if pawn.res != null:
		pawn.res.pathfinding_tilestack.clear()
		pawn.res.is_moving = false
