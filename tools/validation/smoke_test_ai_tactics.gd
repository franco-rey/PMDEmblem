extends SceneTree

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"
const CODE: String = "match seed=11 mode=pvp map=chessboard p=0006_charizard@50:flamethrower,dragon_claw,lava_plume,will_o_wisp:blaze|0065_alakazam@50:psychic,recover:synchronize|0025_pikachu@50:thunderbolt,quick_attack:static e=0018_pidgeot@50:brave_bird,air_slash:keen_eye|0009_blastoise@50:hydro_pump,ice_beam:torrent|0095_onix@50:rock_slide,dig:sturdy|0003_venusaur@50:giga_drain,sludge_bomb:overgrow"
const IDS: Array[String] = ["P1", "P2", "P3", "E1", "E2", "E3", "E4"]
const PUZZLE_POOL: int = 100
const KO_HEADROOM: float = 0.75
const SURVIVE_HEADROOM: int = 22
const AREA_BLAST_KEY: Vector3i = Vector3i(-1, 0, 0)
const AREA_LONE_KEY: Vector3i = Vector3i(1, 0, 0)
const AREA_BLAST_IDS: Array[String] = ["E1", "E3", "E2"]
const AREA_FOE_IDS: Array[String] = ["E1", "E3", "E2", "E4"]
const AREA_LONE_ID: String = "E4"
const AREA_BLAST_SIZE: int = 3
const AREA_CHIP_FRACTION: float = 0.60
const AREA_LONE_FRACTION: float = 0.78
const AREA_HEALTH_FRACTION: float = 0.5
const AREA_UNIT_VALUE: float = 250.0
const AREA_SPREAD_SPOTS: Dictionary = {
	"P1": Vector3i(0, 0, 0),
	"E1": Vector3i(-2, 0, 1),
	"E3": Vector3i(-2, 0, -1),
	"E2": Vector3i(-3, 0, 0),
	"E4": Vector3i(2, 0, 0),
	"P2": Vector3i(3, 0, 3),
	"P3": Vector3i(2, 0, 3),
}
const AREA_ALLY_SPOTS: Dictionary = {
	"P1": Vector3i(0, 0, 0),
	"E1": Vector3i(-2, 0, 1),
	"E3": Vector3i(-2, 0, -1),
	"E2": Vector3i(-3, 0, 0),
	"E4": Vector3i(2, 0, 0),
	"P3": Vector3i(-1, 0, 1),
	"P2": Vector3i(3, 0, 3),
}

var failures: int = 0
var level: TacticsLevel = null
var chart: TypeChartResource = null
var tiles: Dictionary = {}
var units: Dictionary = {}
var baseline: Dictionary = {}
var estimator: BattleAI = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch(CODE)
	_assert_true(ok, "the tactics puzzle board launches")
	if not ok:
		_finish()
		return
	level = driver.level
	chart = level.get_type_chart()
	tiles = Targeting.arena_tile_keys(level)
	estimator = BattleAI.new()
	estimator.set_level(4)
	for id in IDS:
		var pawn: TacticsPawn = level.notation.pawn_for_id(id)
		units[id] = pawn
		if pawn == null:
			_assert_true(false, "unit %s is on the board" % id)
			_finish()
			return
		baseline[id] = {
			"max_health": pawn.stats.max_health,
			"attack": pawn.stats.attack,
			"special_attack": pawn.stats.special_attack,
			"movement": pawn.stats.movement,
			"moves": pawn.stats.move_slots.duplicate(),
		}
	_check_turn_order()
	await _puzzle_lethal_blow()
	await _puzzle_type_matchup()
	await _puzzle_threat_range()
	await _puzzle_area_spread()
	await _puzzle_area_over_ally()
	await _puzzle_heal_without_lethal()
	await _puzzle_heal_against_lethal()
	await _puzzle_turn_order_denial()
	await _puzzle_setup_versus_attack()
	await _puzzle_status_infliction()
	await _puzzle_focus_wounded()
	await _puzzle_retreat()
	_finish()


func _check_turn_order() -> void:
	var order: Array[String] = []
	for entry in level.scheduler.peek_upcoming(12):
		order.append(_id_of(entry.pawn))
	_assert_true(order.size() >= 6 and order[0] == "E1" and order[1] == "P1", "the queue puts one foe ahead of the acting unit and the rest behind it (%s)" % ", ".join(order))


func _puzzle_lethal_blow() -> void:
	_reset_units()
	await _layout({
		"P1": Vector3i(0, 0, 0),
		"E3": Vector3i(2, 0, 0),
		"E1": Vector3i(-1, 0, 0),
		"P2": Vector3i(3, 0, -4),
		"P3": Vector3i(2, 0, -4),
		"E2": Vector3i(-4, 0, 3),
		"E4": Vector3i(-3, 0, 3),
	}, "lethal blow")
	var actor: TacticsPawn = units["P1"]
	var finishable: TacticsPawn = units["E3"]
	var tougher: TacticsPawn = units["E1"]
	_equip(actor, ["flamethrower"])
	_disarm(finishable)
	_disarm(tougher)
	_root(actor)
	var move: PokemonMoveResource = actor.stats.move_slots[0]
	var small: int = int(_estimate(actor, finishable, move))
	var large: int = int(_estimate(actor, tougher, move))
	_assert_true(large > small and small > 0, "the far target takes less raw damage than the near one (%d vs %d)" % [small, large])
	# Both targets share one health pool. Every tier above level 1 ranks targets by health
	# FRACTION, not by absolute health, so leaving the two on their own species maximums
	# made "the finishable one is the weaker one" accidentally false and decided the puzzle
	# on sub-point margins. The pool keeps the two fractions directly comparable.
	_set_health(finishable, maxi(1, int(round(float(small) * KO_HEADROOM))), PUZZLE_POOL)
	_set_health(tougher, mini(PUZZLE_POOL - 1, large + SURVIVE_HEADROOM), PUZZLE_POOL)
	var finish_fraction: float = float(finishable.stats.curr_health) / float(finishable.stats.max_health)
	var tough_fraction: float = float(tougher.stats.curr_health) / float(tougher.stats.max_health)
	_assert_true(small >= finishable.stats.curr_health + 5, "lethal blow: the knockout on the far target is certain rather than a damage-roll coin flip (%d damage into %d health)" % [small, finishable.stats.curr_health])
	_assert_true(large + 5 <= tougher.stats.curr_health, "lethal blow: the near target clearly survives the same move (%d damage into %d health)" % [large, tougher.stats.curr_health])
	_assert_true(tough_fraction - finish_fraction > 0.25, "lethal blow: the finishable target is also the clearly weaker one by health fraction (%.2f against %.2f)" % [finish_fraction, tough_fraction])
	var allies: Array = [actor]
	var foes: Array = [tougher, finishable]
	for tier in [3, 4, 5]:
		var action: AIAction = _decide(actor, allies, foes, tier)
		_assert_true(action.target_unit == finishable, "lethal blow: level %d finishes the target it can knock out" % tier)
	# Level 2 ranks by base power times type effectiveness and owns no knockout detection at
	# all, so it swings at the neutral target rather than the resisted one it could finish.
	# Passing up an available knockout is the boundary this puzzle draws: knockout awareness
	# starts at level 3. Level 2's health-fraction preference is covered by "focus wounded".
	var scrappy: AIAction = _decide(actor, allies, foes, 2)
	_assert_true(scrappy.target_unit == tougher, "lethal blow: level 2 owns no knockout detection and swings at the better type matchup instead")
	var low: AIAction = _decide(actor, allies, foes, 1)
	_assert_true(low.target_unit == tougher, "lethal blow: level 1 hits the nearer survivor instead of taking the knockout")


func _puzzle_type_matchup() -> void:
	_reset_units()
	await _layout({
		"P1": Vector3i(0, 0, 0),
		"E4": Vector3i(2, 0, 0),
		"E2": Vector3i(-1, 0, 0),
		"P2": Vector3i(3, 0, -4),
		"P3": Vector3i(2, 0, -4),
		"E1": Vector3i(-4, 0, 3),
		"E3": Vector3i(-3, 0, 3),
	}, "type matchup")
	var actor: TacticsPawn = units["P1"]
	var weak: TacticsPawn = units["E4"]
	var resistant: TacticsPawn = units["E2"]
	_equip(actor, ["flamethrower"])
	_disarm(weak)
	_disarm(resistant)
	_root(actor)
	_set_health(weak, 100, baseline["E4"]["max_health"])
	_set_health(resistant, 99, baseline["E2"]["max_health"])
	var move: PokemonMoveResource = actor.stats.move_slots[0]
	_assert_true(_estimate(actor, weak, move) > 3.0 * _estimate(actor, resistant, move), "type matchup: the weak target takes far more than the resistant one (%d vs %d)" % [int(_estimate(actor, weak, move)), int(_estimate(actor, resistant, move))])
	var allies: Array = [actor]
	var foes: Array = [resistant, weak]
	for tier in [2, 3, 4, 5]:
		var action: AIAction = _decide(actor, allies, foes, tier)
		_assert_true(action.target_unit == weak, "type matchup: level %d attacks the target its move is strong against" % tier)
	var blind: AIAction = _decide(actor, allies, foes, 1)
	_assert_true(blind.target_unit == resistant, "type matchup: level 1 has no type awareness and walks into the resistant target it stands next to")


func _puzzle_threat_range() -> void:
	_reset_units()
	await _layout({
		"P1": Vector3i(0, 0, -2),
		"E4": Vector3i(0, 0, 2),
		"E3": Vector3i(-1, 0, 1),
		"E2": Vector3i(1, 0, 1),
		"P2": Vector3i(3, 0, -4),
		"P3": Vector3i(2, 0, -4),
		"E1": Vector3i(-4, 0, 3),
	}, "threat range")
	var actor: TacticsPawn = units["P1"]
	var quarry: TacticsPawn = units["E4"]
	var left: TacticsPawn = units["E3"]
	var right: TacticsPawn = units["E2"]
	_equip(actor, ["flamethrower"])
	_disarm(quarry)
	_equip(left, ["rock_slide"])
	_equip(right, ["rock_slide"])
	left.stats.movement = 1
	right.stats.movement = 1
	var allies: Array = [actor]
	var foes: Array = [quarry, left, right]
	var guards: Array = [left, right]
	var incoming: float = _estimate(left, actor, left.stats.move_slots[0]) + _estimate(right, actor, right.stats.move_slots[0])
	_assert_true(incoming > float(actor.stats.max_health) * 0.9, "threat range: the two guards together threaten most of the acting unit's health (%d of %d)" % [int(incoming), actor.stats.max_health])
	for tier in [3, 4, 5]:
		var action: AIAction = _decide(actor, allies, foes, tier)
		var key: Vector3i = _tile_key(action.move_to_tile)
		_assert_true(key == Vector3i(0, 0, -1) and not _threatened(key, guards, actor), "threat range: level %d stops on the safe square that still reaches the quarry (%s)" % [tier, str(key)])
	for tier in [1, 2]:
		var action: AIAction = _decide(actor, allies, foes, tier)
		var key: Vector3i = _tile_key(action.move_to_tile)
		_assert_true(key == Vector3i(0, 0, 1) and _threatened(key, guards, actor), "threat range: level %d walks into the square both guards cover (%s)" % [tier, str(key)])


func _puzzle_area_spread() -> void:
	_reset_units()
	await _layout(AREA_SPREAD_SPOTS, "area spread")
	_arm_area_spread()
	var actor: TacticsPawn = units["P1"]
	var move: PokemonMoveResource = actor.stats.move_slots[0]
	var allies: Array = [actor]
	var foes: Array = [units["E1"], units["E3"], units["E2"], units["E4"]]
	_assert_true(Targeting.effective_range_kind(move) == PokemonMoveResource.TacticalRangeKind.AREA, "area spread: the acting unit holds an area move")
	_assert_true(_area_hits(actor, move, AREA_BLAST_KEY, foes) == AREA_BLAST_SIZE and _area_hits(actor, move, AREA_LONE_KEY, foes) == 1, "area spread: one square catches the whole cluster and the other catches the lone foe")
	_guard_area_premise(actor, move)
	for tier in [3, 4, 5]:
		var action: AIAction = _decide(actor, allies, foes, tier)
		var key: Vector3i = _tile_key(action.move_to_tile)
		_assert_true(_area_hits(actor, move, key, foes) == AREA_BLAST_SIZE, "area spread: level %d takes the square that catches the whole cluster (%s)" % [tier, str(key)])
	for tier in [1, 2]:
		var action: AIAction = _decide(actor, allies, foes, tier)
		var key: Vector3i = _tile_key(action.move_to_tile)
		_assert_true(_area_hits(actor, move, key, foes) == 1, "area spread: level %d scores the area move as a single hit and takes the lone foe (%s)" % [tier, str(key)])


func _puzzle_area_over_ally() -> void:
	_reset_units()
	await _layout(AREA_ALLY_SPOTS, "area over ally")
	_arm_area_spread()
	var actor: TacticsPawn = units["P1"]
	var friend: TacticsPawn = units["P3"]
	_disarm(friend)
	var move: PokemonMoveResource = actor.stats.move_slots[0]
	var allies: Array = [actor, friend]
	var foes: Array = [units["E1"], units["E3"], units["E2"], units["E4"]]
	_assert_true(Targeting.key_in_range(AREA_BLAST_KEY, _key_of(friend), actor, move), "area over ally: the ally really does stand inside the blast square's area range")
	_guard_area_premise(actor, move)
	for tier in [3, 4, 5]:
		var action: AIAction = _decide(actor, allies, foes, tier)
		var key: Vector3i = _tile_key(action.move_to_tile)
		_assert_true(_area_hits(actor, move, key, foes) == AREA_BLAST_SIZE, "area over ally: level %d still takes the cluster square with an ally standing in the blast (%s)" % [tier, str(key)])
		_assert_true(Targeting.key_in_range(key, _key_of(friend), actor, move), "area over ally: level %d ends inside area range of its own ally" % tier)
		var splashed: Array[TacticsPawn] = _reachable_targets(actor, move, key)
		_assert_true(not splashed.has(friend) and splashed.size() == AREA_BLAST_SIZE, "area over ally: the resolver's own target filter drops the ally from the blast at level %d" % tier)
	var counted: Array[TacticsPawn] = estimator._targets_hit(actor, move, AREA_BLAST_KEY, units["E1"], _pawns(foes), _pawns(allies))
	_assert_true(not counted.has(friend) and counted.size() == AREA_BLAST_SIZE, "area over ally: the damage estimator counts every foe in the blast and never the ally")


func _puzzle_heal_without_lethal() -> void:
	_reset_units()
	await _layout({
		"P1": Vector3i(0, 0, 0),
		"E1": Vector3i(1, 0, 0),
		"P2": Vector3i(3, 0, -4),
		"P3": Vector3i(2, 0, -4),
		"E2": Vector3i(-4, 0, 3),
		"E3": Vector3i(-3, 0, 3),
		"E4": Vector3i(-2, 0, 3),
	}, "heal without lethal")
	var actor: TacticsPawn = units["P1"]
	var foe: TacticsPawn = units["E1"]
	_equip(actor, ["flamethrower"])
	_disarm(foe)
	_root(actor)
	_set_health(actor, 20, baseline["P1"]["max_health"])
	var berry: PokemonItemResource = PokemonItemService.load_item("berry_oran")
	_assert_true(berry != null and actor.stats.pokemon_instance != null, "heal without lethal: the oran berry and the acting instance both exist")
	actor.stats.pokemon_instance.held_item = berry
	_assert_true(_estimate(actor, foe, actor.stats.move_slots[0]) < float(foe.stats.curr_health), "heal without lethal: no knockout is available this turn")
	var allies: Array = [actor]
	var foes: Array = [foe]
	for tier in [2, 3, 4, 5]:
		var action: AIAction = _decide(actor, allies, foes, tier)
		_assert_true(action.intent != null and action.intent.is_item_action(), "heal without lethal: level %d eats its berry below half health" % tier)
	var low: AIAction = _decide(actor, allies, foes, 1)
	_assert_true(low.intent == null or not low.intent.is_item_action(), "heal without lethal: level 1 never reaches for an item")
	actor.stats.pokemon_instance.held_item = null


func _puzzle_heal_against_lethal() -> void:
	_reset_units()
	await _layout({
		"P1": Vector3i(0, 0, 0),
		"E1": Vector3i(1, 0, 0),
		"P2": Vector3i(3, 0, -4),
		"P3": Vector3i(2, 0, -4),
		"E2": Vector3i(-4, 0, 3),
		"E3": Vector3i(-3, 0, 3),
		"E4": Vector3i(-2, 0, 3),
	}, "heal against lethal")
	var actor: TacticsPawn = units["P1"]
	var foe: TacticsPawn = units["E1"]
	_equip(actor, ["flamethrower"])
	_disarm(foe)
	_root(actor)
	_set_health(actor, 20, baseline["P1"]["max_health"])
	_set_health(foe, 5, baseline["E1"]["max_health"])
	actor.stats.pokemon_instance.held_item = PokemonItemService.load_item("berry_oran")
	_assert_true(_estimate(actor, foe, actor.stats.move_slots[0]) >= float(foe.stats.curr_health), "heal against lethal: a guaranteed knockout is on the board")
	var allies: Array = [actor]
	var foes: Array = [foe]
	for tier in [3, 4, 5]:
		var action: AIAction = _decide(actor, allies, foes, tier)
		_assert_true(action.intent == null or not action.intent.is_item_action(), "heal against lethal: level %d takes the knockout instead of drinking" % tier)
		_assert_true(action.target_unit == foe and action.move_index >= 0, "heal against lethal: level %d aims the finishing move at the foe" % tier)
	var scrappy: AIAction = _decide(actor, allies, foes, 2)
	_assert_true(scrappy.intent == null or not scrappy.intent.is_item_action(), "heal against lethal: level 2 takes the knockout instead of drinking")
	var low: AIAction = _decide(actor, allies, foes, 1)
	_assert_true(low.intent == null or not low.intent.is_item_action(), "heal against lethal: level 1 attacks only because it owns no item behaviour")
	actor.stats.pokemon_instance.held_item = null


func _puzzle_turn_order_denial() -> void:
	_reset_units()
	await _layout({
		"P1": Vector3i(0, 0, 0),
		"E1": Vector3i(1, 0, 0),
		"E3": Vector3i(-1, 0, 0),
		"E2": Vector3i(0, 0, 3),
		"P2": Vector3i(3, 0, -4),
		"P3": Vector3i(2, 0, -4),
		"E4": Vector3i(-4, 0, 3),
	}, "turn order denial")
	var actor: TacticsPawn = units["P1"]
	var early: TacticsPawn = units["E1"]
	var late: TacticsPawn = units["E3"]
	var decoy: TacticsPawn = units["E2"]
	_equip(actor, ["dragon_claw"])
	_disarm(early)
	_disarm(late)
	_disarm(decoy)
	_root(actor)
	_set_health(early, 5, 100)
	_set_health(late, 5, 100)
	_set_health(decoy, 1, 100)
	_set_offense(early, 10, 10)
	_set_offense(late, 10, 10)
	_set_offense(decoy, 250, 250)
	var move: PokemonMoveResource = actor.stats.move_slots[0]
	_assert_true(_estimate(actor, early, move) >= 5.0 and _estimate(actor, late, move) >= 5.0, "turn order denial: both foes can be knocked out this turn")
	_assert_true(_acts_before(early, actor) and not _acts_before(late, actor), "turn order denial: one foe is queued ahead of the acting unit and one behind it")
	var allies: Array = [actor]
	var foes: Array = [decoy, late, early]
	for tier in [4, 5]:
		var action: AIAction = _decide(actor, allies, foes, tier)
		_assert_true(action.target_unit == early, "turn order denial: level %d removes the foe that would act before it" % tier)
	for tier in [1, 2, 3]:
		var action: AIAction = _decide(actor, allies, foes, tier)
		_assert_true(action.target_unit == late, "turn order denial: level %d cannot tell the two knockouts apart and keeps the first it scored" % tier)
	var contested_foes: Array = [late, early]
	for tier in [4, 5]:
		var contested: AIAction = _decide(actor, allies, contested_foes, tier)
		_assert_true(contested.target_unit == early, "turn order denial: level %d spends its tempo bonus to deny the foe that acts first, even against the team focus" % tier)


func _puzzle_setup_versus_attack() -> void:
	_reset_units()
	await _layout({
		"P1": Vector3i(0, 0, 0),
		"E1": Vector3i(1, 0, 0),
		"P2": Vector3i(3, 0, -4),
		"P3": Vector3i(2, 0, -4),
		"E2": Vector3i(-4, 0, 3),
		"E3": Vector3i(-3, 0, 3),
		"E4": Vector3i(-2, 0, 3),
	}, "setup versus attack")
	var actor: TacticsPawn = units["P1"]
	var foe: TacticsPawn = units["E1"]
	_equip(actor, ["swords_dance", "dragon_claw"])
	_disarm(foe)
	_root(actor)
	var allies: Array = [actor]
	var foes: Array = [foe]
	for tier in [1, 2, 3, 4, 5]:
		var action: AIAction = _decide(actor, allies, foes, tier)
		_assert_true(action.move_index == 1 and action.target_unit == foe, "setup versus attack: level %d attacks rather than buffing when a target is in reach" % tier)
	await _layout({
		"P1": Vector3i(0, 0, 0),
		"E1": Vector3i(0, 0, 3),
		"P2": Vector3i(3, 0, -4),
		"P3": Vector3i(2, 0, -4),
		"E2": Vector3i(-4, 0, 3),
		"E3": Vector3i(-3, 0, 3),
		"E4": Vector3i(-2, 0, 3),
	}, "setup out of reach")
	for tier in [4, 5]:
		var action: AIAction = _decide(actor, allies, foes, tier)
		_assert_true(action.move_index == 0, "setup versus attack: level %d buffs itself when nothing can be attacked" % tier)
	for tier in [1, 2, 3]:
		var action: AIAction = _decide(actor, allies, foes, tier)
		_assert_true(action.move_index < 0, "setup versus attack: level %d has no use for a setup move and idles" % tier)


func _puzzle_status_infliction() -> void:
	_reset_units()
	await _layout({
		"P1": Vector3i(0, 0, 0),
		"E1": Vector3i(0, 0, 3),
		"P2": Vector3i(3, 0, -4),
		"P3": Vector3i(2, 0, -4),
		"E2": Vector3i(-4, 0, 3),
		"E3": Vector3i(-3, 0, 3),
		"E4": Vector3i(-2, 0, 3),
	}, "status infliction")
	var actor: TacticsPawn = units["P1"]
	var foe: TacticsPawn = units["E1"]
	_equip(actor, ["will_o_wisp", "dragon_claw"])
	_disarm(foe)
	_root(actor)
	var allies: Array = [actor]
	var foes: Array = [foe]
	for tier in [3, 4, 5]:
		var action: AIAction = _decide(actor, allies, foes, tier)
		_assert_true(action.move_index == 0 and action.target_unit == foe, "status infliction: level %d burns a clean target it cannot reach with an attack" % tier)
	for tier in [1, 2]:
		var action: AIAction = _decide(actor, allies, foes, tier)
		_assert_true(action.move_index < 0, "status infliction: level %d ignores status moves entirely" % tier)
	foe.stats.battle_statuses["burn"] = {}
	var afflicted: AIAction = _decide(actor, allies, foes, 5)
	foe.stats.battle_statuses = {}
	_assert_true(afflicted.move_index < 0, "status infliction: level 5 does not spend a turn re-applying a status the target already carries")


func _puzzle_focus_wounded() -> void:
	_reset_units()
	await _layout({
		"P1": Vector3i(0, 0, 0),
		"E1": Vector3i(1, 0, 0),
		"E2": Vector3i(-1, 0, 0),
		"P2": Vector3i(3, 0, -4),
		"P3": Vector3i(2, 0, -4),
		"E3": Vector3i(-3, 0, 3),
		"E4": Vector3i(-2, 0, 3),
	}, "focus wounded")
	var actor: TacticsPawn = units["P1"]
	var healthy: TacticsPawn = units["E1"]
	var wounded: TacticsPawn = units["E2"]
	_equip(actor, ["dragon_claw"])
	_disarm(healthy)
	_disarm(wounded)
	_root(actor)
	_set_health(healthy, 100, 100)
	_set_health(wounded, 40, 100)
	var move: PokemonMoveResource = actor.stats.move_slots[0]
	_assert_true(_estimate(actor, wounded, move) < float(wounded.stats.curr_health), "focus wounded: the wounded foe still survives the hit")
	var allies: Array = [actor]
	var foes: Array = [healthy, wounded]
	for tier in [2, 3, 4, 5]:
		var action: AIAction = _decide(actor, allies, foes, tier)
		_assert_true(action.target_unit == wounded, "focus wounded: level %d piles onto the foe an ally already hurt" % tier)
	var low: AIAction = _decide(actor, allies, foes, 1)
	_assert_true(low.target_unit == healthy, "focus wounded: level 1 spreads its damage onto the nearest healthy foe")


func _puzzle_retreat() -> void:
	_reset_units()
	await _layout({
		"P1": Vector3i(0, 0, -3),
		"E1": Vector3i(0, 0, 3),
		"P2": Vector3i(3, 0, 3),
		"P3": Vector3i(2, 0, 3),
		"E2": Vector3i(-4, 0, 3),
		"E3": Vector3i(-3, 0, 3),
		"E4": Vector3i(-2, 0, 3),
	}, "retreat")
	var actor: TacticsPawn = units["P1"]
	var foe: TacticsPawn = units["E1"]
	_equip(actor, ["dragon_claw"])
	_disarm(foe)
	foe.stats.movement = 1
	_set_health(actor, 20, baseline["P1"]["max_health"])
	var allies: Array = [actor]
	var foes: Array = [foe]
	var advanced: int = 1 << 30
	for tier in [3, 4]:
		var action: AIAction = _decide(actor, allies, foes, tier)
		var key: Vector3i = _tile_key(action.move_to_tile)
		var distance: int = _manhattan(key, _key_of(foe))
		advanced = mini(advanced, distance)
		_assert_true(action.move_index < 0 and distance <= 2, "retreat: level %d keeps closing on a foe it cannot reach even at low health (%s)" % [tier, str(key)])
	var top: AIAction = _decide(actor, allies, foes, 5)
	var top_key: Vector3i = _tile_key(top.move_to_tile)
	var top_distance: int = _manhattan(top_key, _key_of(foe))
	_assert_true(top_distance > advanced + 4, "retreat: level 5 backs away when it is hurt and nothing is in reach (%s at %d against %d)" % [str(top_key), top_distance, advanced])


# The first cut of this square pinned every foe to a shared 100-point pool and read the
# chip fraction straight off that pool. Absolute health and health FRACTION then drifted
# apart: the lone foe landed on 24/100 while the cluster sat at 80/100 and 61/100, which
# handed the lone foe both the wounded-target preference every tier above 2 applies and
# the level 4/5 team focus multiplier. Levels 4 and 5 were deciding the puzzle on 0.08 and
# 1.43 points, and level 2 on 0.50. Health fraction, unit value and damage fraction are
# now set independently so that only the number of foes caught can decide it, and
# _guard_area_premise fails loudly the moment the damage numbers drift out of that regime.
func _arm_area_spread() -> void:
	var actor: TacticsPawn = units["P1"]
	_equip(actor, ["lava_plume"])
	actor.stats.movement = 1
	var move: PokemonMoveResource = actor.stats.move_slots[0]
	for id in AREA_FOE_IDS:
		_disarm(units[String(id)])
	for id in AREA_BLAST_IDS:
		_chip(units[String(id)], move, AREA_CHIP_FRACTION)
	_chip(units[AREA_LONE_ID], move, AREA_LONE_FRACTION)
	for id in AREA_FOE_IDS:
		_level_unit_value(units[String(id)], AREA_UNIT_VALUE)


# Health fraction is held at AREA_HEALTH_FRACTION for every foe so the tier's wounded-target
# preference cannot pick a side; the damage fraction rides on curr_health alone.
func _chip(pawn: TacticsPawn, move: PokemonMoveResource, fraction: float) -> void:
	var damage: float = _estimate(units["P1"], pawn, move)
	var current: int = maxi(2, int(round(damage / fraction)))
	var pool: int = maxi(current, int(round(float(current) / AREA_HEALTH_FRACTION)))
	_set_health(pawn, current, pool)


# BattleAI._unit_value is offence plus VALUE_DURABILITY_WEIGHT * max_health. Chipping moves
# max_health around, so offence is trimmed back to keep every foe worth the same and the
# level 4/5 value weighting neutral.
func _level_unit_value(pawn: TacticsPawn, target: float) -> void:
	var offence: int = maxi(1, int(round(target - BattleAI.VALUE_DURABILITY_WEIGHT * float(pawn.stats.max_health))))
	_set_offense(pawn, offence, offence)


# Every premise the two area squares rest on. If move data, the damage formula or the
# roster shifts under this puzzle these fail by name instead of letting the tier checks
# pass or fail on a rounding error.
func _guard_area_premise(actor: TacticsPawn, move: PokemonMoveResource) -> void:
	var lone: TacticsPawn = units[AREA_LONE_ID]
	var lone_share: float = _damage_share(actor, lone, move)
	var summed: float = 0.0
	var richest: float = 0.0
	var origin: Vector3i = _key_of(actor)
	var reference: float = float(estimator._unit_value(units[AREA_BLAST_IDS[0]]))
	for id in AREA_BLAST_IDS:
		var pawn: TacticsPawn = units[String(id)]
		var share: float = _damage_share(actor, pawn, move)
		summed += share
		richest = maxf(richest, share)
		_assert_true(absf(share - AREA_CHIP_FRACTION) <= 0.03, "area premise: %s takes the intended share of its own health (%.3f against %.3f)" % [id, share, AREA_CHIP_FRACTION])
		_assert_true(_manhattan(origin, _key_of(pawn)) > _manhattan(origin, _key_of(lone)), "area premise: %s stands further off than the lone foe, so the greedy tiers walk the other way" % id)
	for id in AREA_FOE_IDS:
		var pawn: TacticsPawn = units[String(id)]
		var health_fraction: float = float(pawn.stats.curr_health) / float(pawn.stats.max_health)
		_assert_true(absf(health_fraction - AREA_HEALTH_FRACTION) <= 0.02, "area premise: %s is no more wounded than the rest, so the wounded-target preference cannot decide this puzzle (%.3f)" % [id, health_fraction])
		_assert_true(absf(float(estimator._unit_value(pawn)) - reference) <= 2.0, "area premise: %s is worth the same as the rest, so value weighting cannot decide this puzzle (%.1f against %.1f)" % [id, estimator._unit_value(pawn), reference])
		_assert_true(_damage_share(actor, pawn, move) < BattleAI.VARIANCE_LOW, "area premise: %s survives the blast, so this puzzle stays clear of the knockout band (%.3f)" % [id, _damage_share(actor, pawn, move)])
	_assert_true(absf(lone_share - AREA_LONE_FRACTION) <= 0.03, "area premise: the lone foe takes the intended share of its own health (%.3f against %.3f)" % [lone_share, AREA_LONE_FRACTION])
	# The lone foe is the better SINGLE target and the nearer one, so an engine that scored
	# the area move as one hit would take its square. Counting the blast is the only reason
	# to walk the other way, which is exactly what levels 3 to 5 are being asked to do.
	_assert_true(lone_share > richest + 0.15, "area premise: the lone foe is the richer single target (%.3f against the cluster's best %.3f)" % [lone_share, richest])
	_assert_true(summed - lone_share * BattleAI.FOCUS_GAIN > 0.5, "area premise: the whole cluster outweighs the lone foe even when the lone foe holds the team focus (%.3f against %.3f)" % [summed, lone_share * BattleAI.FOCUS_GAIN])


func _damage_share(actor: TacticsPawn, pawn: TacticsPawn, move: PokemonMoveResource) -> float:
	return _estimate(actor, pawn, move) / float(maxi(1, pawn.stats.curr_health))


func _decide(actor: TacticsPawn, allies: Array, foes: Array, tier: int) -> AIAction:
	var ai := BattleAI.new()
	ai.set_level(tier)
	ai.forget(actor)
	level.arena.reset_all_tile_markers()
	return ai.choose_action(actor, allies, foes, chart, level)


func _reset_units() -> void:
	for id in IDS:
		var pawn: TacticsPawn = units[id]
		var base: Dictionary = baseline[id]
		pawn.stats.max_health = int(base["max_health"])
		pawn.stats.curr_health = int(base["max_health"])
		pawn.stats.attack = int(base["attack"])
		pawn.stats.special_attack = int(base["special_attack"])
		pawn.stats.movement = int(base["movement"])
		pawn.stats.stat_stages = {}
		pawn.stats.battle_statuses = {}
		var restored: Array[PokemonMoveResource] = []
		for move in base["moves"]:
			restored.append(move)
		pawn.stats.move_slots = restored
		pawn.stats.refill_all_pp()
		if pawn.stats.pokemon_instance != null:
			pawn.stats.pokemon_instance.held_item = null
		if pawn.res != null:
			pawn.res.can_move = true


func _layout(spots: Dictionary, label: String) -> void:
	for id in spots.keys():
		var pawn: TacticsPawn = units[id]
		var tile: TacticsTile = tiles.get(spots[id], null)
		if tile == null:
			_assert_true(false, "%s: tile %s is on the board" % [label, str(spots[id])])
			continue
		pawn.global_position = tile.global_position + Vector3.UP * 0.05
		(pawn.get_node("Tile") as RayCast3D).force_raycast_update()
	await physics_frame
	for id in spots.keys():
		var pawn: TacticsPawn = units[id]
		pawn.center()
		pawn.sync_physics_body()
		(pawn.get_node("Tile") as RayCast3D).force_raycast_update()
	await physics_frame
	await physics_frame
	var placed: bool = spots.size() == IDS.size()
	for id in spots.keys():
		if _key_of(units[id]) != spots[id]:
			placed = false
	_assert_true(placed, "%s: every unit stands on the square the puzzle assigned it" % label)


func _root(pawn: TacticsPawn) -> void:
	if pawn.res != null:
		pawn.res.can_move = false


func _equip(pawn: TacticsPawn, move_ids: Array) -> void:
	var slots: Array[PokemonMoveResource] = []
	for move_id in move_ids:
		var move: PokemonMoveResource = load("%s%s.tres" % [MOVES_DIR, String(move_id)]) as PokemonMoveResource
		if move != null:
			slots.append(move)
	pawn.stats.move_slots = slots
	pawn.stats.refill_all_pp()


func _disarm(pawn: TacticsPawn) -> void:
	_equip(pawn, ["swords_dance"])


func _set_health(pawn: TacticsPawn, current: int, maximum: int) -> void:
	pawn.stats.max_health = maxi(1, maximum)
	pawn.stats.curr_health = clampi(current, 1, pawn.stats.max_health)


func _set_offense(pawn: TacticsPawn, physical: int, special: int) -> void:
	pawn.stats.attack = physical
	pawn.stats.special_attack = special


func _estimate(attacker: TacticsPawn, defender: TacticsPawn, move: PokemonMoveResource) -> float:
	return estimator._expected_damage(attacker, defender, move, chart)


func _area_hits(actor: TacticsPawn, move: PokemonMoveResource, key: Vector3i, foes: Array) -> int:
	var total: int = 0
	for foe in foes:
		if Targeting.key_in_range(key, _key_of(foe as TacticsPawn), actor, move):
			total += 1
	return total


func _reachable_targets(actor: TacticsPawn, move: PokemonMoveResource, key: Vector3i) -> Array[TacticsPawn]:
	var everyone: Array[TacticsPawn] = []
	for id in IDS:
		everyone.append(units[id])
	return Targeting.filter_by_alignment(Targeting.range_from(key, actor, move), actor, move, everyone)


func _threatened(key: Vector3i, guards: Array, victim: TacticsPawn) -> bool:
	for entry in guards:
		var guard: TacticsPawn = entry as TacticsPawn
		var reach: int = guard.stats.movement
		var longest: int = 1
		for i in range(guard.stats.move_slots.size()):
			var move: PokemonMoveResource = guard.stats.move_slots[i]
			if move == null or not guard.stats.has_pp(i):
				continue
			longest = maxi(longest, Targeting.range_distance(guard, move))
		if _estimate(guard, victim, guard.stats.move_slots[0]) <= 0.0:
			continue
		if _manhattan(key, _key_of(guard)) <= reach + longest:
			return true
	return false


func _acts_before(target: TacticsPawn, actor: TacticsPawn) -> bool:
	for entry in level.scheduler.peek_upcoming(12):
		if entry == null or entry.pawn == null:
			continue
		if entry.pawn == target:
			return true
		if entry.pawn == actor:
			return false
	return false


func _pawns(source: Array) -> Array[TacticsPawn]:
	var out: Array[TacticsPawn] = []
	for entry in source:
		if entry is TacticsPawn:
			out.append(entry)
	return out


func _id_of(pawn: TacticsPawn) -> String:
	for id in IDS:
		if units.get(id, null) == pawn:
			return id
	return "?"


func _key_of(pawn: TacticsPawn) -> Vector3i:
	return Targeting._tile_key(pawn.get_tile())


func _tile_key(tile: TacticsTile) -> Vector3i:
	return Targeting._tile_key(tile)


func _manhattan(a: Vector3i, b: Vector3i) -> int:
	return absi(a.x - b.x) + absi(a.z - b.z)


func _finish() -> void:
	if failures > 0:
		push_error("smoke: ai_tactics failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: ai_tactics clean")
	quit(0)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)
