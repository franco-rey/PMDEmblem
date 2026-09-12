extends SmokeCase

const DRIVER := preload("res://tools/debug/notation_driver.gd")

var driver = null
var level: TacticsLevel = null


func _run() -> void:
	for move_id in ["dimensional_hole", "dimensional_glitch", "hyperspace_fury", "judgment"]:
		var move: PokemonMoveResource = CustomMoves.load_move(move_id)
		_assert_true(move != null and move.move_id == move_id, "custom move %s loads through the shared lookup" % move_id)
	_assert_true(CustomMoves.move_ids_for_species("0251_celebi") == ["dimensional_hole"] and CustomMoves.move_ids_for_species("0720_hoopa") == ["hyperspace_fury"] and CustomMoves.move_ids_for_species("0025_pikachu").is_empty(), "custom learnsets name their holders only")
	var celebi_instance: PokemonInstanceResource = load("res://data/models/pokemon/generated/instances/0251_celebi.tres") as PokemonInstanceResource
	if celebi_instance != null:
		var pool_ids: Array[String] = []
		for move in SkirmishMoveLoadout.move_pool_for_instance(celebi_instance):
			pool_ids.append(move.move_id)
		_assert_true(pool_ids.has("dimensional_hole"), "the lobby move pool offers Dimensional Hole to Celebi")
	var table: Dictionary = MultiverseRoster.travellers()
	var legendary_pool: Array[String] = MultiverseRoster.legendary_slugs()
	var common_pool: Array[String] = MultiverseRoster.common_slugs()
	_assert_true(not legendary_pool.is_empty() and not common_pool.is_empty(), "the traveller table splits into legendary and non-legendary pools (%d/%d)" % [legendary_pool.size(), common_pool.size()])
	var every_move_travels: bool = true
	for slug in table.keys():
		if not MultiverseController.TRAVEL_MOVES.has(String(table[slug])):
			every_move_travels = false
	_assert_true(every_move_travels, "every traveller is mapped to a move that opens or crosses a timeline")

	var plain: Array[String] = [
		"res://data/models/pokemon/generated/instances/0025_pikachu.tres",
		"res://data/models/pokemon/generated/instances/0006_charizard.tres",
		"res://data/models/pokemon/generated/instances/0009_blastoise.tres",
	]
	var guaranteed: Array[String] = MultiverseRoster.ensure_traveller_paths(plain, 991)
	_assert_true(guaranteed.size() == plain.size() and MultiverseRoster.paths_satisfy(guaranteed), "a random roster with no travellers gains one legendary and one non-legendary (%s)" % str(guaranteed))
	_assert_true(MultiverseRoster.ensure_traveller_paths(plain, 991) == guaranteed, "the traveller substitution is deterministic for a seed")
	_assert_true(MultiverseRoster.ensure_traveller_paths(guaranteed, 12345) == guaranteed, "a roster that already satisfies the rule is left alone")
	var solo: Array[String] = MultiverseRoster.ensure_traveller_paths([plain[0]], 991)
	var solo_slug: String = PortraitLibrary.slug_for_path(solo[0]) if solo.size() == 1 else ""
	_assert_true(MultiverseRoster.is_traveller(solo_slug) and MultiverseRoster.is_legendary(solo_slug), "a one-slot random team gets the legendary traveller (%s)" % solo_slug)

	var grovyle: PokemonInstanceResource = load("res://data/models/pokemon/generated/instances/0253_grovyle.tres") as PokemonInstanceResource
	if grovyle != null:
		var copy: PokemonInstanceResource = SkirmishMoveLoadout.clone_for_side(grovyle, PokemonInstanceResource.Team.PLAYER, PokemonInstanceResource.ControlType.AI)
		copy.move_slots = [CustomMoves.load_move("leaf_blade"), CustomMoves.load_move("quick_attack")]
		copy.pp_state = [10, 30]
		var team: Array[PokemonInstanceResource] = [copy]
		var changed: int = MultiverseRoster.ensure_traveller_moves(team)
		var granted: Array[String] = []
		for move in copy.move_slots:
			granted.append(move.move_id if move != null else "")
		_assert_true(changed == 1 and granted.has(MultiverseRoster.travel_move_for("0253_grovyle")), "a traveller that rolled no dimension move is granted one (%s)" % str(granted))
		_assert_true(SkirmishMoveLoadout.has_resolving_attack(copy.move_slots), "granting the dimension move keeps a usable attack")
		_assert_true(copy.pp_state.size() == copy.move_slots.size(), "granting the dimension move keeps PP aligned with the slots")
		_assert_true(MultiverseRoster.ensure_traveller_moves(team) == 0, "a traveller that already carries a dimension move is left alone")

	var built: Dictionary = CustomSkirmishBuilder.build_random(4, "res://data/models/maps/definitions/chessboard.tres", "4242", SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_CPU, true)
	if bool(built.get("ok", false)):
		var definition: SkirmishDefinitionResource = built["definition"]
		MultiverseRoster.ensure_traveller_moves(definition.player_team)
		MultiverseRoster.ensure_traveller_moves(definition.enemy_team)
		_assert_true(MultiverseRoster.team_satisfies(definition.player_team), "a generated 5D player team fields a legendary and a non-legendary traveller")
		_assert_true(MultiverseRoster.team_satisfies(definition.enemy_team), "a generated 5D enemy team fields a legendary and a non-legendary traveller")
	else:
		_assert_true(false, "a random 5D skirmish builds (%s)" % String(built.get("error", "")))

	driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=17 mode=pvp multiverse=1 p=0251_celebi@50:dimensional_hole,psychic:natural_cure|0474_porygon_z@50:dimensional_glitch,tri_attack:adaptability|0493_arceus@50:judgment,recover:multitype e=0483_dialga@50:roar_of_time,dragon_claw:pressure|0720_hoopa@50:hyperspace_fury,psychic:magician|0487_giratina@50:shadow_force,dragon_claw:pressure")
	_assert_true(ok, "a roster with every multiverse Pokemon and all four custom moves launches")
	if not ok:
		_finish("multiverse_roster")
		return
	level = driver.level
	var frames: int = 0
	while not level._scheduler_started and frames < 300:
		await physics_frame
		frames += 1
	var mv: MultiverseController = level.multiverse
	await _play_rounds_until(2)
	var celebi: TacticsPawn = await _wait_for_active("P1")
	_assert_true(celebi != null, "Celebi acts in round 2")
	var hole: PokemonMoveResource = CustomMoves.load_move("dimensional_hole")
	BattleMoveSpecials.new().after_move(null, celebi, hole, level, level.battle_log)
	var options: Array = mv.pending_travel.get("options", [])
	_assert_true(options.size() == 1 and String(options[0].get("label", "")) == "L0 T1", "Dimensional Hole offers Celebi's own past moments (%s)" % str(options.map(func(o: Dictionary) -> String: return String(o.get("label", "")))))
	_assert_true(mv.commit_travel(0), "Celebi hops back alone")
	await physics_frame
	await physics_frame
	var branch: BoardSnapshot = mv.state.latest(1)
	_assert_true(branch != null and branch.has_unit("P1'") and branch.has_unit("P1") and not branch.has_unit("E1'") and mv.state.latest(0).has_unit("E1"), "only Celebi travelled: it meets its past self on L+1 and every other unit stays on timeline 0")
	var arrival: TacticsPawn = level.notation.pawn_for_id("P1'")
	_assert_true(arrival != null and arrival.stats.battle_statuses.has("recharge"), "a Dimensional Hole arrival owes a lag turn")
	await _play_rounds_until(2)
	var glitch_user: TacticsPawn = await _wait_for_active("P2")
	_assert_true(glitch_user != null, "Porygon-Z acts on the branch")
	var glitch: PokemonMoveResource = CustomMoves.load_move("dimensional_glitch")
	BattleMoveSpecials.new().after_move(null, glitch_user, glitch, level, level.battle_log)
	var glitch_options: Array = mv.pending_travel.get("options", [])
	_assert_true(glitch_options.size() >= 1 and bool(mv.travel_rule("dimensional_glitch").get("random", false)), "Dimensional Glitch offers dimensions and is flagged random (%d options)" % glitch_options.size())
	var random_pick: int = mv.pick_random_option()
	_assert_true(random_pick >= 0 and random_pick < glitch_options.size() and mv.commit_travel(random_pick), "Porygon-Z lands somewhere the dice chose")
	await physics_frame
	await physics_frame
	var arceus: TacticsPawn = null
	for pawn in level.units_on_map():
		if PortraitLibrary.slug_for_pawn(pawn) == "0493_arceus":
			arceus = pawn
	var dialga: TacticsPawn = null
	for pawn in level.units_on_map():
		if PortraitLibrary.slug_for_pawn(pawn) == "0483_dialga":
			dialga = pawn
	_assert_true(arceus != null and dialga != null and mv.is_immune(arceus) and not mv.is_immune(dialga), "Arceus is the only unit outside time and space")
	var travellers: Array[TacticsPawn] = mv.travellers_for("roar_of_time", dialga, arceus)
	_assert_true(travellers.size() == 1 and travellers[0] == dialga, "Roar of Time against Arceus moves Dialga alone")
	var fury_travellers: Array[TacticsPawn] = mv.travellers_for("hyperspace_fury", dialga, arceus)
	_assert_true(fury_travellers.is_empty() and mv.travel_options("hyperspace_fury", dialga, arceus).is_empty(), "Hyperspace Fury against Arceus banishes nobody")
	var giratina: TacticsPawn = null
	for pawn in level.units_on_map():
		if PortraitLibrary.slug_for_pawn(pawn) == "0487_giratina":
			giratina = pawn
	var fury_options: Array[Dictionary] = mv.travel_options("hyperspace_fury", dialga, giratina)
	_assert_true(fury_options.size() == 1 and String(fury_options[0].get("kind", "")) == "new", "Hyperspace Fury always tears a fresh universe for a non-immune target (%s)" % str(fury_options))
	var strike_rule: Dictionary = mv.travel_rule("shadow_force")
	_assert_true(giratina != null and bool(strike_rule.get("strike", false)) and String(strike_rule.get("travellers", "")) == "user", "Shadow Force is a solo strike hop")
	var judgment: PokemonMoveResource = CustomMoves.load_move("judgment")
	_assert_true(judgment != null and judgment.is_damaging() and mv.travel_rule("judgment").is_empty(), "Judgment is an ordinary attack")
	_finish("multiverse_roster")


func celebi_or_any(battle_level: TacticsLevel, not_pawn: TacticsPawn) -> TacticsPawn:
	for pawn in battle_level.units_on_map():
		if pawn != not_pawn and pawn.get_parent() != not_pawn.get_parent() and not battle_level.multiverse.is_immune(pawn):
			return pawn
	return null


func _wait_for_active(id: String) -> TacticsPawn:
	var guard: int = 0
	while guard < 40:
		var active: BattleUnit = await _next_active()
		if active == null:
			return null
		if level.notation.unit_id(active.pawn) == id:
			return active.pawn
		await _play_turn(active.pawn)
		guard += 1
	return null


func _play_rounds_until(round_target: int) -> void:
	var guard: int = 0
	while level.round_index < round_target and guard < 60:
		var active: BattleUnit = await _next_active()
		if active == null:
			break
		await _play_turn(active.pawn)
		guard += 1


func _next_active() -> BattleUnit:
	var frames: int = 0
	while frames < 600:
		var active: BattleUnit = level.scheduler.get_active_unit()
		if active != null and active.pawn != null and is_instance_valid(active.pawn) and not level.is_presentation_busy():
			return active
		if level.battle_finished:
			return null
		await physics_frame
		frames += 1
	return null


func _play_turn(pawn: TacticsPawn) -> void:
	await driver._end_turn(pawn)
