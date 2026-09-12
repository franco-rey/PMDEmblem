extends SmokeCase

const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"


func _run() -> void:
	_check_catalog()
	await _check_blast_seed_use()
	await _check_blast_seed_throw()
	await _check_throw_landing_and_pickup()
	await _check_catch_and_ally_eat()
	_check_random_presets_itemless()
	await _check_lobby_setup_path()
	_finish("held_item_actions")


func _check_catalog() -> void:
	var entries: Array[Dictionary] = BattleItemCatalog.entries()
	_assert_true(entries.size() >= 100 and entries.size() < 160, "held-item catalog lists mainline held items and berries only (%d)" % entries.size())
	var blast: Dictionary = BattleItemCatalog.describe(PokemonItemService.load_item("seed_blast"))
	_assert_true(bool(blast.get("can_use", false)) and bool(blast.get("can_throw", false)) and bool(blast.get("edible", false)), "seed_blast is usable, throwable and edible")
	var life_orb: Dictionary = BattleItemCatalog.entry_for("held_life_orb")
	_assert_true(bool(life_orb.get("passive", false)) and not bool(life_orb.get("can_use", false)), "held_life_orb is passive-only but still throwable")
	var ids: Array[String] = []
	for entry in entries:
		ids.append(String(entry["item_id"]))
	for excluded in ["material_stone", "evo_fire_stone", "ability_capsule", "seed_blast", "medicine_x_sp_def"]:
		_assert_true(not ids.has(excluded), "%s is not offered as a held-slot pick" % excluded)


func _check_blast_seed_use() -> void:
	var ctx: Dictionary = await _build_battle("seed_blast", "")
	var level: TacticsLevel = ctx["level"]
	var user: TacticsPawn = ctx["player"]
	var foe: TacticsPawn = ctx["enemy"]
	await _place_in_front(level, user, foe)
	var resolver := BattleActionResolver.new()
	var before: int = foe.stats.curr_health
	var result: Dictionary = resolver.execute_intent(BattleActionIntent.use_item(user, "seed_blast"), level)
	_assert_true(bool(result.get("ok", false)), "Blast Seed use executes")
	_assert_true(PokemonItemService.held_item_for(user.stats) == null, "Blast Seed is consumed on use")
	var expected_blast: int = mini(user.stats.level * 2, before)
	_assert_true(before - foe.stats.curr_health == expected_blast, "eaten Blast Seed deals 2x user level to the foe in front (%d of expected %d)" % [before - foe.stats.curr_health, expected_blast])
	_assert_true(_log_has(level.battle_log, "effect_excluded_by_owner"), "belly restoration is logged as owner-excluded")
	_assert_true(_log_has(level.battle_log, "item_custom_action"), "nested source action recorded")
	var selection: Dictionary = _first_event(level.battle_log, "animation_selected")
	_assert_true(String(selection.get("requested_key", "")) == "Shoot", "eater performs the source Shoot action")
	await _drain(level)
	_assert_true(_log_has(level.battle_log, "vfx_spawned"), "Blast_Seed explosion emitter spawned")
	ctx["loader"].unload_current()
	await process_frame


func _check_blast_seed_throw() -> void:
	var ctx: Dictionary = await _build_battle("seed_blast", "")
	var level: TacticsLevel = ctx["level"]
	var thrower: TacticsPawn = ctx["player"]
	var foe: TacticsPawn = ctx["enemy"]
	await _place_in_front(level, thrower, foe)
	var facing: Vector3i = Targeting._facing_direction(thrower)
	var options: Array[Dictionary] = Targeting.throw_options(thrower, 8, _units(level), Targeting.arena_tile_keys(level))
	var hit_option: Dictionary = {}
	for option in options:
		if option.get("hit_unit", null) == foe:
			hit_option = option
	_assert_true(not hit_option.is_empty() and hit_option.get("direction", Vector3i.ZERO) == facing, "throw options include the foe on the facing ray")
	var resolver := BattleActionResolver.new()
	var thrower_before: int = thrower.stats.curr_health
	var result: Dictionary = resolver.execute_intent(BattleActionIntent.throw_item(thrower, "seed_blast", facing, foe), level)
	_assert_true(bool(result.get("ok", false)) and result.get("hit_unit", null) == foe, "thrown Blast Seed hits the foe")
	_assert_true(PokemonItemService.held_item_for(thrower.stats) == null, "thrown Blast Seed leaves the thrower's slot")
	_assert_true(PokemonItemService.held_item_for(foe.stats) == null, "foe cannot catch a thrown edible")
	_assert_true(_log_has(level.battle_log, "item_hit_unit"), "thrown item hit logged")
	var custom: Dictionary = _first_event(level.battle_log, "item_custom_action")
	_assert_true(custom.get("unit", null) == foe, "the foe eats the seed and fires the nested blast forward")
	var damage_events: Array = _events(level.battle_log, "damage_dealt")
	var expected: int = foe.stats.level * 2
	var thrower_hit: bool = thrower_before - thrower.stats.curr_health == expected
	_assert_true(thrower_hit or damage_events.is_empty(), "blast damage applies only to units in the eater's front tile (thrower hit=%s)" % str(thrower_hit))
	await _drain(level)
	_assert_true(_log_has(level.battle_log, "vfx_projectile_spawned"), "seed projectile visibly leaves the thrower")
	_assert_true(level.vfx_player.active_count() == 0, "throw VFX cleaned up")
	ctx["loader"].unload_current()
	await process_frame


func _check_throw_landing_and_pickup() -> void:
	var ctx: Dictionary = await _build_battle("seed_blast", "")
	var level: TacticsLevel = ctx["level"]
	var thrower: TacticsPawn = ctx["player"]
	var foe: TacticsPawn = ctx["enemy"]
	var units: Array[TacticsPawn] = _units(level)
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	var empty_ray: Dictionary = {}
	for option in Targeting.throw_options(thrower, 8, units, keys):
		if option.get("hit_unit", null) == null and int(option.get("distance", 0)) >= 2:
			empty_ray = option
			break
	_assert_true(not empty_ray.is_empty(), "an empty throw ray exists")
	if empty_ray.is_empty():
		ctx["loader"].unload_current()
		return
	var resolver := BattleActionResolver.new()
	var result: Dictionary = resolver.execute_intent(BattleActionIntent.throw_item(thrower, "seed_blast", empty_ray["direction"]), level)
	var landing: Vector3i = empty_ray["landing"]
	_assert_true(bool(result.get("ok", false)) and result.get("landing", Vector3i.ZERO) == landing, "missed throw lands at the end of the ray")
	_assert_true(level.landed_item_at(landing) == "seed_blast", "landed item recorded on the tile")
	_assert_true(level.get_node_or_null("LandedItems") != null and level.get_node("LandedItems").get_child_count() == 1, "landed item sprite placed")
	await _drain(level)
	var tile: TacticsTile = keys.get(landing, null)
	await _settle_on_tile(thrower, tile)
	thrower.res.can_move = false
	thrower.serv.movement.check_movement_completion(thrower)
	_assert_true(PokemonItemService.held_item_for(thrower.stats) != null and PokemonItemService.held_item_for(thrower.stats).item_id == "seed_blast", "unit picks the landed seed back up when its slot is empty")
	_assert_true(level.landed_item_at(landing).is_empty(), "landed item record cleared after pickup")
	_assert_true(foe.stats.curr_health == foe.stats.max_health, "missed throw damaged nobody")
	ctx["loader"].unload_current()
	await process_frame


func _check_catch_and_ally_eat() -> void:
	var ctx: Dictionary = await _build_battle("held_life_orb", "")
	var level: TacticsLevel = ctx["level"]
	var thrower: TacticsPawn = ctx["player"]
	var foe: TacticsPawn = ctx["enemy"]
	await _place_in_front(level, thrower, foe)
	var facing: Vector3i = Targeting._facing_direction(thrower)
	var resolver := BattleActionResolver.new()
	var result: Dictionary = resolver.execute_intent(BattleActionIntent.throw_item(thrower, "held_life_orb", facing, foe), level)
	_assert_true(bool(result.get("ok", false)), "held item throw executes")
	_assert_true(PokemonItemService.held_item_for(foe.stats) != null and PokemonItemService.held_item_for(foe.stats).item_id == "held_life_orb", "a non-edible thrown item is caught by a unit with a free slot")
	_assert_true(foe.stats.curr_health == foe.stats.max_health, "caught item deals no damage")
	await _drain(level)
	var second: Dictionary = await _build_battle("berry_oran", "berry_oran")
	var level2: TacticsLevel = second["level"]
	var thrower2: TacticsPawn = second["player"]
	var foe2: TacticsPawn = second["enemy"]
	await _place_in_front(level2, thrower2, foe2)
	foe2.stats.apply_to_curr_health(-20)
	var facing2: Vector3i = Targeting._facing_direction(thrower2)
	var result2: Dictionary = resolver.execute_intent(BattleActionIntent.throw_item(thrower2, "berry_oran", facing2, foe2), level2)
	_assert_true(bool(result2.get("ok", false)), "Oran Berry throw executes")
	_assert_true(PokemonItemService.held_item_for(foe2.stats) != null and PokemonItemService.held_item_for(foe2.stats).item_id == "berry_oran", "holding foe keeps its own item and does not catch")
	_assert_true(foe2.stats.curr_health == foe2.stats.max_health, "thrown Oran Berry is eaten by the target and heals it")
	await _drain(level2)
	ctx["loader"].unload_current()
	second["loader"].unload_current()
	await process_frame


func _check_random_presets_itemless() -> void:
	var maps: Array[String] = CustomSkirmishBuilder.map_paths()
	var result: Dictionary = CustomSkirmishBuilder.build_random(3, maps[0], "9001")
	_assert_true(bool(result.get("ok", false)), "random preset builds")
	if not bool(result.get("ok", false)):
		return
	var definition: SkirmishDefinitionResource = result["definition"]
	var itemless: bool = true
	for instance in definition.player_team + definition.enemy_team:
		if instance != null and instance.held_item != null:
			itemless = false
	_assert_true(itemless, "random preset generators remain itemless")
	var again: Dictionary = CustomSkirmishBuilder.build_random(3, maps[0], "9001")
	var same: bool = true
	var first_def: SkirmishDefinitionResource = again["definition"]
	for i in range(definition.enemy_team.size()):
		if definition.enemy_team[i].species != first_def.enemy_team[i].species:
			same = false
	_assert_true(same, "random preset generation is unchanged for the same seed")


func _check_lobby_setup_path() -> void:
	var scene: PackedScene = load("res://assets/scene/skirmish_lobby.tscn") as PackedScene
	var lobby: SkirmishLobby = scene.instantiate() as SkirmishLobby
	root.add_child(lobby)
	await process_frame
	lobby.activate_player_team()
	var entries: Array[Dictionary] = lobby.get_roster_entries()
	var bulbasaur_index: int = -1
	var charmander_index: int = -1
	for i in range(entries.size()):
		var slug: String = String(entries[i].get("slug", ""))
		if slug == "0001_bulbasaur":
			bulbasaur_index = i
		elif slug == "0004_charmander":
			charmander_index = i
	_assert_true(bulbasaur_index >= 0 and charmander_index >= 0, "lobby roster exposes the pilot species")
	lobby.add_roster_index(bulbasaur_index)
	lobby.add_roster_index(bulbasaur_index)
	_assert_true(lobby.set_held_item(SkirmishLobby.SIDE_PLAYER, 0, "berry_sitrus"), "lobby accepts a berry for player slot 1")
	_assert_true(lobby.set_held_item(SkirmishLobby.SIDE_PLAYER, 1, "berry_oran"), "lobby accepts Oran Berry for player slot 2")
	_assert_true(not lobby.set_held_item(SkirmishLobby.SIDE_PLAYER, 0, "not_an_item"), "lobby rejects unknown item ids")
	_assert_true(not lobby.set_held_item(SkirmishLobby.SIDE_PLAYER, 0, "seed_blast"), "lobby rejects PMD seeds after the mainline prune")
	lobby.activate_enemy_team()
	lobby.add_roster_index(charmander_index)
	_assert_true(lobby.set_held_item(SkirmishLobby.SIDE_ENEMY, 0, "held_life_orb"), "lobby accepts Life Orb for enemy slot 1")
	lobby.activate_player_team()
	lobby._on_team_slot_pressed(SkirmishLobby.SIDE_PLAYER, 0)
	lobby._open_chooser(SkirmishLobby.CHOOSER_ITEM)
	var chooser_grid: GridContainer = lobby.find_child("ChooserGrid", true, false) as GridContainer
	var chooser_panel: Control = lobby.find_child("ChooserPanel", true, false) as Control
	_assert_true(chooser_panel != null and chooser_panel.visible and chooser_grid != null and chooser_grid.get_child_count() > 50, "Choose Item window lists applicable items (%d rows)" % (chooser_grid.get_child_count() if chooser_grid != null else 0))
	var first_row: Button = chooser_grid.get_child(1) as Button
	_assert_true(first_row != null and first_row.find_child("*", true, false) != null, "item rows carry icon and label content")
	lobby._close_chooser()
	_assert_true(not chooser_panel.visible, "Choose Item window closes")
	_assert_true(lobby.set_slot_moves(SkirmishLobby.SIDE_PLAYER, 0, ["razor_leaf", "tackle"]), "explicit moves accepted for player slot 1")
	_assert_true(lobby.set_slot_ability(SkirmishLobby.SIDE_PLAYER, 0, "chlorophyll"), "explicit ability accepted for player slot 1")
	_assert_true(lobby.set_slot_ability(SkirmishLobby.SIDE_PLAYER, 1, CustomSkirmishBuilder.RANDOM_CHOICE), "random ability accepted for player slot 2")
	lobby._open_chooser(SkirmishLobby.CHOOSER_MOVES)
	_assert_true(chooser_grid.get_child_count() >= 10 and chooser_grid.get_child_count() <= 20, "Choose Moves window lists the level-up pool (%d rows)" % chooser_grid.get_child_count())
	lobby._close_chooser()
	lobby._open_chooser(SkirmishLobby.CHOOSER_ABILITY)
	_assert_true(chooser_grid.get_child_count() == 2, "Choose Ability window lists Bulbasaur's abilities (%d rows)" % chooser_grid.get_child_count())
	lobby._close_chooser()
	lobby.activate_enemy_team()
	lobby._on_team_slot_pressed(SkirmishLobby.SIDE_ENEMY, 0)
	_assert_true(lobby.set_held_item(SkirmishLobby.SIDE_ENEMY, 0, CustomSkirmishBuilder.RANDOM_CHOICE), "random item accepted for enemy slot 1")
	_assert_true(lobby.get_enemy_item_ids() == ["random"], "random item recorded as a seeded choice")
	_assert_true(lobby.set_held_item(SkirmishLobby.SIDE_ENEMY, 0, "held_life_orb"), "explicit item replaces the random choice")
	_assert_true(lobby.roster_cell_size().x >= SkirmishLobby.ROSTER_MIN_CELL, "roster cells are at least the minimum portrait size (%.1f)" % lobby.roster_cell_size().x)
	lobby.set_random_enemy_enabled(false)
	var mode_picker: OptionButton = lobby.find_child("ControlModePicker", true, false) as OptionButton
	for i in range(mode_picker.item_count):
		if String(mode_picker.get_item_metadata(i)) == SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER:
			mode_picker.select(i)
	var seed_input: LineEdit = lobby.find_child("SeedInput", true, false) as LineEdit
	seed_input.text = "4242"
	var result: Dictionary = lobby._build_launch_result(true)
	_assert_true(bool(result.get("ok", false)), "lobby builds a definition with held items (%s)" % String(result.get("error", "")))
	if not bool(result.get("ok", false)):
		lobby.queue_free()
		return
	var definition: SkirmishDefinitionResource = result["definition"]
	_assert_true(definition.player_team[0].held_item != null and definition.player_team[0].held_item.item_id == "berry_sitrus", "player slot 1 clone holds its berry")
	_assert_true(definition.player_team[0].loadout_locked and definition.player_team[0].move_slots.size() == 2 and definition.player_team[0].move_slots[0].move_id == "razor_leaf", "explicit moves survive the build")
	_assert_true(definition.player_team[0].ability_override == "chlorophyll", "explicit ability survives the build")
	_assert_true(["overgrow", "chlorophyll"].has(definition.player_team[1].ability_override), "random ability resolves to one of the species abilities (%s)" % definition.player_team[1].ability_override)
	var stats_probe := Stats.new()
	stats_probe.init_from_pokemon(definition.player_team[0])
	_assert_true(BattleIntrinsicService.new().intrinsic_slugs_for(stats_probe) == ["chlorophyll"], "ability override is the only active intrinsic in battle")
	_assert_true(definition.player_team[1].held_item != null and definition.player_team[1].held_item.item_id == "berry_oran", "duplicate species slot 2 holds its own Oran Berry")
	_assert_true(definition.enemy_team[0].held_item != null and definition.enemy_team[0].held_item.item_id == "held_life_orb", "enemy slot 1 clone holds Life Orb")
	var template: PokemonInstanceResource = load("res://data/models/pokemon/generated/instances/0001_bulbasaur.tres") as PokemonInstanceResource
	_assert_true(template.held_item == null, "generated template is not mutated by held-item selection")
	_assert_true((definition.generation_metadata.get("player_items", []) as Array) == ["berry_sitrus", "berry_oran"], "definition metadata records player held items")
	var replay: Dictionary = lobby._build_from_state(lobby._last_launch_state)
	_assert_true(bool(replay.get("ok", false)) and (replay["definition"] as SkirmishDefinitionResource).player_team[0].held_item != null, "play-again state retains held items")
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var level: TacticsLevel = loader.load_skirmish(definition, root)
	await process_frame
	await process_frame
	var spawned: TacticsPawn = level.player.get_child(0) as TacticsPawn
	var spawned_second: TacticsPawn = level.player.get_child(1) as TacticsPawn
	_assert_true(PokemonItemService.held_item_for(spawned.stats) != null and PokemonItemService.held_item_for(spawned.stats).item_id == "berry_sitrus", "spawned pawn keeps its berry through the loader")
	_assert_true(PokemonItemService.held_item_for(spawned_second.stats) != null and PokemonItemService.held_item_for(spawned_second.stats).item_id == "berry_oran", "second spawned pawn keeps Oran Berry")
	_assert_true(spawned.stats.move_slots.size() == 2 and spawned.stats.move_slots[0].move_id == "razor_leaf", "loader keeps the explicit two-move loadout instead of re-rolling")
	lobby.activate_player_team()
	lobby.set_held_item(SkirmishLobby.SIDE_PLAYER, 0, "")
	var cleared: Dictionary = lobby.build_current_definition()
	_assert_true(bool(cleared.get("ok", false)) and (cleared["definition"] as SkirmishDefinitionResource).player_team[0].held_item == null, "clearing a slot removes the held item on the next build")
	loader.unload_current()
	loader.queue_free()
	lobby.queue_free()
	await process_frame


func _build_battle(player_item: String, enemy_item: String) -> Dictionary:
	var map: MapDefinitionResource = load(TEST_ARENA_MAP_PATH) as MapDefinitionResource
	var bulbasaur: PokemonInstanceResource = _instance("0001_bulbasaur", ["tackle", "razor_leaf"], PokemonInstanceResource.Team.PLAYER, player_item)
	var charmander: PokemonInstanceResource = _instance("0004_charmander", ["scratch", "ember"], PokemonInstanceResource.Team.ENEMY, enemy_item)
	var definition := SkirmishDefinitionResource.new()
	definition.skirmish_id = "held_item_smoke"
	definition.map = map
	definition.seed = 7
	definition.player_team = [bulbasaur]
	definition.enemy_team = [charmander]
	definition.control_mode = SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER
	definition.generation_metadata = {"player_spawn_order": [0], "enemy_spawn_order": [0]}
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var level: TacticsLevel = loader.load_skirmish(definition, root)
	await process_frame
	await process_frame
	return {"level": level, "loader": loader, "player": level.player.get_child(0), "enemy": level.opponent.get_child(0)}


func _instance(slug: String, move_ids: Array, team: int, item_id: String) -> PokemonInstanceResource:
	var template: PokemonInstanceResource = load("res://data/models/pokemon/generated/instances/%s.tres" % slug) as PokemonInstanceResource
	var instance: PokemonInstanceResource = SkirmishMoveLoadout.clone_for_side(template, team, PokemonInstanceResource.ControlType.PLAYER)
	var slots: Array[PokemonMoveResource] = []
	var pp: Array[int] = []
	for move_id in move_ids:
		var move: PokemonMoveResource = load("%s%s.tres" % [GENERATED_MOVES_DIR, String(move_id)]) as PokemonMoveResource
		if move != null:
			slots.append(move)
			pp.append(move.pp)
	instance.move_slots = slots
	instance.pp_state = pp
	instance.held_item = PokemonItemService.load_item(item_id) if not item_id.is_empty() else null
	return instance


func _place_in_front(level: TacticsLevel, user: TacticsPawn, other: TacticsPawn) -> void:
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	var user_key: Vector3i = Targeting._tile_key(user.get_tile())
	var facing: Vector3i = Vector3i.ZERO
	for direction in Targeting.DIRECTIONS_8:
		if keys.has(user_key + direction) and keys.has(user_key + direction * 2):
			facing = direction
			break
	user.serv.movement.look_at_direction_8(user, Vector3(float(facing.x), 0.0, float(facing.z)))
	var tile: TacticsTile = keys.get(user_key + facing, null)
	await _settle_on_tile(other, tile)
	other.serv.movement.look_at_direction_8(other, Vector3(float(-facing.x), 0.0, float(-facing.z)))
	_assert_true(Targeting._tile_key(other.get_tile()) == user_key + facing, "unit placed on the facing tile")


func _drain(level: TacticsLevel) -> void:
	var frames: int = 0
	while level.presentation_runner.is_busy() and frames < 900:
		await process_frame
		frames += 1
	var cleanup: int = 0
	while level.vfx_player.active_count() > 0 and cleanup < 400:
		await process_frame
		cleanup += 1


func _units(level: TacticsLevel) -> Array[TacticsPawn]:
	var out: Array[TacticsPawn] = []
	for node in [level.player, level.opponent]:
		for child in node.get_children():
			if child is TacticsPawn:
				out.append(child)
	return out


func _settle_on_tile(pawn: TacticsPawn, tile: TacticsTile) -> void:
	var ray: RayCast3D = pawn.get_node("Tile") as RayCast3D
	pawn.global_position = tile.global_position + Vector3.UP * 0.05
	ray.force_raycast_update()
	pawn.center()
	ray.force_raycast_update()
	await physics_frame
	await physics_frame


func _log_has(log: BattleLog, kind: String) -> bool:
	for event in log.events:
		if String(event.get("kind", "")) == kind:
			return true
	return false


func _events(log: BattleLog, kind: String) -> Array:
	var out: Array = []
	for event in log.events:
		if String(event.get("kind", "")) == kind:
			out.append(event)
	return out


func _first_event(log: BattleLog, kind: String) -> Dictionary:
	for event in log.events:
		if String(event.get("kind", "")) == kind:
			return event
	return {}
