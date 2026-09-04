extends SceneTree

const OUTPUT_DIR: String = "res://logs/debug/validation"

class ValidationDriver:
	extends NotationDriver

	var log_ref: BattleLog = null
	var unit_snapshots: Dictionary = {}
	var notation_snapshot: String = ""

	func snapshot() -> void:
		if level == null or not is_instance_valid(level):
			return
		log_ref = level.battle_log
		notation_snapshot = level.notation.text()
		unit_snapshots = {}
		for pawn in level.units_on_map():
			if pawn.stats == null:
				continue
			unit_snapshots[level.notation.unit_ref(pawn)] = {
				"hp": pawn.stats.curr_health,
				"max": pawn.stats.max_health,
				"active": pawn.stats.is_active(),
				"statuses": pawn.stats.battle_statuses.keys(),
				"stages": pawn.stats.stat_stages.duplicate(),
				"item": PokemonItemService.held_item_for(pawn.stats).item_id if PokemonItemService.held_item_for(pawn.stats) != null else "",
				"pawn": pawn,
			}
		for side in [level.player, level.opponent]:
			var index: int = 0
			for child in side.get_children():
				if child is TacticsPawn and (child as TacticsPawn).stats != null:
					index += 1
					var short: String = "%s%d" % ["P" if side == level.player else "E", index]
					unit_snapshots[short] = unit_snapshots.get(level.notation.unit_ref(child), {})

	var _end_hooked: bool = false

	func _run_command(command: String) -> void:
		if not _end_hooked and level != null and is_instance_valid(level):
			_end_hooked = true
			level.battle_ended.connect(func(_result: int) -> void:
				snapshot())
		await _dispatch(command)
		snapshot()

	func _dispatch(command: String) -> void:
		var parts: PackedStringArray = command.split(" ", false)
		var verb: String = String(parts[0]).to_lower()
		match verb:
			"adjacent":
				var pawn: TacticsPawn = _unit_for_ref(String(parts[1]))
				var target: TacticsPawn = _unit_for_ref(String(parts[2]))
				if pawn == null or target == null:
					_fail("adjacent needs two units: %s" % command)
					return
				var keys: Dictionary = Targeting.arena_tile_keys(level)
				var target_key: Vector3i = Targeting._tile_key(target.get_tile())
				for direction in [Vector3i(0, 0, -1), Vector3i(-1, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1)]:
					var key: Vector3i = target_key + direction
					if keys.has(key) and not (keys[key] as TacticsTile).is_taken():
						var tile: TacticsTile = keys[key]
						var ray: RayCast3D = pawn.get_node("Tile") as RayCast3D
						pawn.global_position = tile.global_position + Vector3.UP * 0.05
						ray.force_raycast_update()
						pawn.center()
						ray.force_raycast_update()
						pawn.serv.movement.look_at_direction_8(pawn, target.global_position - pawn.global_position)
						target.serv.movement.look_at_direction_8(target, pawn.global_position - target.global_position)
						_log("%s placed adjacent to %s at %s" % [level.notation.unit_name(pawn), level.notation.unit_name(target), level.notation.label_for_pawn(pawn)])
						return
				_fail("no free tile next to %s" % level.notation.unit_name(target))
			"near":
				var pawn: TacticsPawn = _unit_for_ref(String(parts[1]))
				var anchor: TacticsPawn = _unit_for_ref(String(parts[2]))
				var distance: int = int(String(parts[3])) if parts.size() > 3 else 2
				if pawn == null or anchor == null:
					_fail("near needs two units: %s" % command)
					return
				var keys: Dictionary = Targeting.arena_tile_keys(level)
				var facing: Vector3i = TacticsPawnMovementService.snap_direction_8(Vector3.FORWARD.rotated(Vector3.UP, anchor.rotation.y - PI))
				var key: Vector3i = Targeting._tile_key(anchor.get_tile()) + facing * distance
				if not keys.has(key) or (keys[key] as TacticsTile).is_taken():
					_fail("no free tile %d in front of %s" % [distance, level.notation.unit_name(anchor)])
					return
				var tile: TacticsTile = keys[key]
				var ray: RayCast3D = pawn.get_node("Tile") as RayCast3D
				pawn.global_position = tile.global_position + Vector3.UP * 0.05
				ray.force_raycast_update()
				pawn.center()
				ray.force_raycast_update()
				pawn.serv.movement.look_at_direction_8(pawn, anchor.global_position - pawn.global_position)
				_log("%s placed %d tiles in front of %s at %s" % [level.notation.unit_name(pawn), distance, level.notation.unit_name(anchor), level.notation.label_for_pawn(pawn)])
			"enter_strip":
				var pawn: TacticsPawn = _unit_for_ref(String(parts[1]))
				var placer: TacticsPawn = _unit_for_ref(String(parts[2]))
				if pawn == null or placer == null:
					_fail("enter_strip needs two units: %s" % command)
					return
				if not await _wait_for_turn(pawn):
					return
				var keys: Dictionary = Targeting.arena_tile_keys(level)
				var strip: Array[Vector3i] = level.hazards().strip_keys(placer, keys)
				var arena: TacticsArena = level.arena
				arena.reset_all_tile_markers()
				arena.process_surrounding_tiles(pawn.get_tile(), pawn.stats.movement, pawn.get_parent().get_children())
				arena.mark_reachable_tiles(pawn.get_tile(), pawn.stats.movement)
				for key in strip:
					var tile: TacticsTile = keys[key]
					if tile.reachable and not tile.is_taken():
						await _move(pawn, level.notation.tile_label(key))
						return
				_fail("%s cannot reach the strip in front of %s" % [level.notation.unit_name(pawn), level.notation.unit_name(placer)])
			"approach":
				var pawn: TacticsPawn = _unit_for_ref(String(parts[1]))
				var target: TacticsPawn = _unit_for_ref(String(parts[2]))
				if pawn == null or target == null:
					_fail("approach needs two units: %s" % command)
					return
				if not await _wait_for_turn(pawn):
					return
				var arena: TacticsArena = level.arena
				arena.reset_all_tile_markers()
				arena.process_surrounding_tiles(pawn.get_tile(), pawn.stats.movement, pawn.get_parent().get_children())
				arena.mark_reachable_tiles(pawn.get_tile(), pawn.stats.movement)
				var tile: TacticsTile = arena.get_nearest_target_adjacent_tile(pawn, [target])
				if tile == null or tile == pawn.get_tile():
					_log("%s already adjacent or no path" % level.notation.unit_name(pawn))
					return
				var label: String = level.notation.tile_label(Targeting._tile_key(tile))
				await _move(pawn, label)
			"face":
				var pawn: TacticsPawn = _unit_for_ref(String(parts[1]))
				var target: TacticsPawn = _unit_for_ref(String(parts[2]))
				if pawn != null and target != null:
					pawn.serv.movement.look_at_direction_8(pawn, target.global_position - pawn.global_position)
					_log("%s faces %s" % [level.notation.unit_name(pawn), level.notation.unit_name(target)])
			"hp":
				var pawn: TacticsPawn = _unit_for_ref(String(parts[1]))
				if pawn != null:
					pawn.stats.curr_health = maxi(1, int(floor(float(pawn.stats.max_health) * float(String(parts[2])))))
					pawn.serv.ui.update_character_health(pawn)
					_log("%s hp set to %d" % [level.notation.unit_name(pawn), pawn.stats.curr_health])
			"status":
				var pawn: TacticsPawn = _unit_for_ref(String(parts[1]))
				if pawn != null:
					level._ops().apply_status(pawn, String(parts[2]), {}, {"kind": "test", "skip_rules": true})
			"types":
				var pawn: TacticsPawn = _unit_for_ref(String(parts[1]))
				if pawn != null:
					var out: Array[String] = []
					for t in String(parts[2]).split(","):
						out.append(String(t))
					pawn.stats.types = out
			_:
				await super._run_command(command)


const SCENARIOS: Array[Dictionary] = [
	{"name": "probe_trick_swaps_places", "code": "match seed=5 mode=pvp p=0065_alakazam@50:trick,psychic:synchronize:held_life_orb e=0007_squirtle@50:tackle,water_gun:torrent:berry_oran", "steps": ["adjacent E1 P1", "attack P1 1 E1"], "expect": [{"event": "forced_movement"}]},
	{"name": "probe_switcheroo_swaps_items", "code": "match seed=5 mode=pvp p=0065_alakazam@50:switcheroo,psychic:synchronize:held_life_orb e=0007_squirtle@50:tackle,water_gun:torrent:berry_oran", "steps": ["adjacent E1 P1", "attack P1 1 E1"], "expect": [{"item_is": ["P1", "berry_oran"]}, {"item_is": ["E1", "held_life_orb"]}]},
	{"name": "probe_covet_steals", "code": "match seed=5 mode=pvp p=0052_meowth@50:covet,scratch:pickup e=0007_squirtle@50:tackle,water_gun:torrent:berry_oran", "steps": ["adjacent E1 P1", "attack P1 1 E1"], "expect": [{"item_is": ["P1", "berry_oran"]}, {"item_gone": "E1"}]},
	{"name": "probe_thief_steals", "code": "match seed=5 mode=pvp p=0052_meowth@50:thief,scratch:pickup e=0007_squirtle@50:tackle,water_gun:torrent:berry_oran", "steps": ["adjacent E1 P1", "attack P1 1 E1"], "expect": [{"item_is": ["P1", "berry_oran"]}]},
	{"name": "probe_bestow_gives", "code": "match seed=5 mode=pvp p=0065_alakazam@50:bestow,psychic:synchronize:held_life_orb e=0007_squirtle@50:tackle,water_gun:torrent", "steps": ["adjacent E1 P1", "attack P1 1 E1"], "expect": [{"item_is": ["E1", "held_life_orb"]}, {"item_gone": "P1"}]},
	{"name": "probe_recycle_restores", "code": "match seed=5 mode=pvp p=0007_squirtle@50:recycle,tackle:torrent:berry_sitrus e=0004_charmander@50:scratch,ember:blaze", "steps": ["adjacent E1 P1", "hp P1 0.55", "attack E1 1 P1", "attack P1 1 self"], "expect": [{"item_is": ["P1", "berry_sitrus"]}]},
	{"name": "probe_fling_throws_item", "code": "match seed=5 mode=pvp p=0052_meowth@50:fling,scratch:pickup:held_iron_ball e=0007_squirtle@50:tackle,water_gun:torrent", "steps": ["adjacent E1 P1", "attack P1 1 E1"], "expect": [{"hp_lt": ["E1", 1.0]}, {"item_gone": "P1"}]},
	{"name": "probe_teleport_moves_user", "code": "match seed=5 mode=pvp p=0063_abra@50:teleport:synchronize e=0007_squirtle@50:tackle,water_gun:torrent", "steps": ["attack P1 1 self"], "expect": [{"event": "forced_movement"}]},
	{"name": "probe_me_first", "code": "match seed=5 mode=pvp p=0065_alakazam@50:me_first,psychic:synchronize e=0007_squirtle@50:tackle,water_gun:torrent", "steps": ["adjacent E1 P1", "attack P1 1 E1"], "expect": [{"event": "move_copied"}]},
	{"name": "probe_healing_wish_ally", "code": "match seed=5 mode=pvp p=0035_clefairy@50:healing_wish,pound:cute_charm|0007_squirtle@50:tackle,water_gun:torrent e=0004_charmander@50:scratch,ember:blaze", "steps": ["hp P2 0.3", "status P2 burn", "adjacent P2 P1", "attack P1 1 P2"], "expect": [{"hp_eq": ["P2", 1.0]}, {"status_off": ["P2", "burn"]}]},
	{"name": "probe_heal_bell_ally", "code": "match seed=5 mode=pvp p=0035_clefairy@50:heal_bell,pound:cute_charm|0007_squirtle@50:tackle,water_gun:torrent e=0004_charmander@50:scratch,ember:blaze", "steps": ["status P2 burn", "status P1 poison", "adjacent P2 P1", "attack P1 1 self"], "expect": [{"status_off": ["P2", "burn"]}, {"status_off": ["P1", "poison"]}]},
	{"name": "probe_tailwind_helping_hand", "code": "match seed=5 mode=pvp p=0016_pidgey@50:tailwind,gust:keen_eye|0007_squirtle@50:helping_hand,water_gun:torrent e=0004_charmander@50:scratch,ember:blaze", "steps": ["adjacent P2 P1", "attack P1 1 self", "attack P2 1 P1"], "expect": [{"event": "stat_stage_changed"}, {"stage_at_least": ["P2", "speed", 1]}, {"stage_at_least": ["P1", "attack", 1]}]},
	{"name": "probe_after_you", "code": "match seed=5 mode=pvp p=0035_clefairy@50:after_you,pound:cute_charm|0007_squirtle@50:tackle,water_gun:torrent e=0004_charmander@50:scratch,ember:blaze", "steps": ["adjacent P2 P1", "attack P1 1 P2"], "expect": [{"event": "move_used"}, {"no_event": "move_rejected"}]},
	{"name": "rain_boosts_water", "code": "match seed=5 mode=pvp p=0007_squirtle@50:rain_dance,water_gun,tackle,withdraw:torrent e=0004_charmander@50:ember,scratch:blaze", "steps": ["attack P1 1 self", "end E1", "attack P1 2 E1", "rounds 5"], "expect": [{"event": "weather_started", "field": {"condition_id": "rain"}}, {"damage_multiplier": ["water_gun", 1.5]}, {"event": "weather_ended"}]},
	{"name": "sun_boosts_fire_and_weakens_water", "code": "match seed=5 mode=pvp p=0004_charmander@50:sunny_day,ember,scratch,growl:blaze e=0007_squirtle@50:water_gun,tackle:torrent", "steps": ["adjacent E1 P1", "attack P1 1 self", "attack E1 1 P1", "attack P1 2 E1"], "expect": [{"event": "weather_started", "field": {"condition_id": "sunny"}}, {"damage_multiplier": ["ember", 1.5]}, {"damage_multiplier": ["water_gun", 0.5]}]},
	{"name": "sandstorm_chips_non_rock", "code": "match seed=5 mode=pvp p=0007_squirtle@50:sandstorm,tackle:torrent e=0004_charmander@50:ember,scratch:blaze", "steps": ["attack P1 1 self", "end E1", "end P1", "end E1"], "expect": [{"event": "weather_started", "field": {"condition_id": "sandstorm"}}, {"hp_lt": ["E1", 1.0]}, {"hp_lt": ["P1", 1.0]}]},
	{"name": "hail_chips_non_ice", "code": "match seed=5 mode=pvp p=0007_squirtle@50:hail,tackle:torrent e=0004_charmander@50:ember,scratch:blaze", "steps": ["attack P1 1 self", "end E1", "end P1", "end E1"], "expect": [{"event": "weather_started", "field": {"condition_id": "hail"}}, {"hp_lt": ["E1", 1.0]}]},
	{"name": "leech_seed_drains_and_heals", "code": "match seed=5 mode=pvp p=0001_bulbasaur@50:leech_seed,tackle:overgrow e=0004_charmander@50:ember,scratch:blaze", "steps": ["adjacent E1 P1", "hp P1 0.5", "attack P1 1 E1", "end E1", "end P1", "end E1"], "expect": [{"event": "status_applied", "status_id": "leech_seed"}, {"event": "status_tick", "status_id": "leech_seed"}, {"hp_gt": ["P1", 0.5]}, {"hp_lt": ["E1", 1.0]}]},
	{"name": "toxic_ticks_increase", "code": "match seed=5 mode=pvp p=0001_bulbasaur@50:toxic,tackle:overgrow e=0007_squirtle@50:water_gun,tackle:torrent", "steps": ["adjacent E1 P1", "attack P1 1 E1", "end E1", "end P1", "end E1", "end P1", "end E1", "end P1", "end E1"], "expect": [{"event": "status_applied", "status_id": "poison_toxic"}, {"tick_increasing": ["E1", "poison_toxic"]}]},
	{"name": "poison_type_immune_to_poison", "code": "match seed=5 mode=pvp p=0001_bulbasaur@50:toxic,tackle:overgrow e=0023_ekans@50:wrap,bite:shed_skin", "steps": ["adjacent E1 P1", "attack P1 1 E1"], "expect": [{"event": "status_blocked", "status_id": "poison_toxic"}, {"status_off": ["E1", "poison_toxic"]}]},
	{"name": "burn_halves_physical", "code": "match seed=5 mode=pvp p=0004_charmander@50:will_o_wisp,scratch:blaze e=0007_squirtle@50:tackle,water_gun:torrent", "steps": ["adjacent E1 P1", "attack E1 1 P1", "status E1 burn", "end P1", "attack E1 1 P1", "end P1", "end E1"], "expect": [{"event": "status_tick", "status_id": "burn"}, {"second_damage_lower": ["tackle"]}]},
	{"name": "spore_sleep_skips_turns", "code": "match seed=5 mode=pvp p=0001_bulbasaur@50:spore,tackle:overgrow e=0007_squirtle@50:water_gun,tackle:torrent", "steps": ["adjacent E1 P1", "attack P1 1 E1", "end P1", "end P1", "end P1"], "expect": [{"event": "status_applied", "status_id": "sleep"}, {"event": "turn_skipped", "status_id": "sleep"}]},
	{"name": "protect_blocks_attack", "code": "match seed=5 mode=pvp p=0007_squirtle@50:protect,tackle:torrent e=0004_charmander@50:scratch,ember:blaze", "steps": ["adjacent E1 P1", "attack P1 1 self", "attack E1 1 P1"], "expect": [{"event": "status_applied", "status_id": "protect"}, {"event": "move_blocked", "status_id": "protect"}]},
	{"name": "spikes_strip_hurts_on_entry", "code": "match seed=5 mode=pvp p=0003_venusaur@50:spikes,razor_leaf:overgrow e=0007_squirtle@50:water_gun,tackle:torrent", "steps": ["face P1 E1", "near E1 P1 2", "attack P1 1 self", "end E1", "attack P1 1 self", "enter_strip E1 P1"], "expect": [{"event": "hazard_placed", "field": {"hazard_id": "spikes"}, "min": 2}, {"event": "hazard_triggered", "field": {"hazard_id": "spikes"}}, {"hp_lt": ["E1", 0.9]}]},
	{"name": "stealth_rock_hits_flying_hard", "code": "match seed=5 mode=pvp p=0003_venusaur@50:stealth_rock,razor_leaf:overgrow e=0006_charizard@50:flamethrower,slash:blaze", "steps": ["face P1 E1", "near E1 P1 2", "attack P1 1 self", "enter_strip E1 P1"], "expect": [{"event": "hazard_triggered", "field": {"hazard_id": "stealth_rock"}}, {"hp_lt": ["E1", 0.8]}]},
	{"name": "toxic_spikes_poison_and_absorb", "code": "match seed=5 mode=pvp p=0003_venusaur@50:toxic_spikes,razor_leaf:overgrow e=0007_squirtle@50:water_gun,tackle:torrent|0023_ekans@50:wrap,bite:shed_skin", "steps": ["face P1 E1", "near E1 P1 2", "attack P1 1 self", "enter_strip E1 P1", "end P1", "near E2 P1 3", "enter_strip E2 P1"], "expect": [{"event": "hazard_triggered", "field": {"hazard_id": "toxic_spikes"}}, {"status_on": ["E1", "poison"]}, {"event": "hazard_absorbed"}]},
	{"name": "sticky_web_slows", "code": "match seed=5 mode=pvp p=0003_venusaur@50:sticky_web,razor_leaf:overgrow e=0007_squirtle@50:water_gun,tackle:torrent", "steps": ["face P1 E1", "near E1 P1 2", "attack P1 1 self", "enter_strip E1 P1"], "expect": [{"event": "hazard_triggered", "field": {"hazard_id": "sticky_web"}}, {"stage": ["E1", "speed", -1]}]},
	{"name": "flying_ignores_spikes", "code": "match seed=5 mode=pvp p=0003_venusaur@50:spikes,razor_leaf:overgrow e=0006_charizard@50:flamethrower,slash:blaze", "steps": ["face P1 E1", "near E1 P1 2", "attack P1 1 self", "enter_strip E1 P1"], "expect": [{"event": "hazard_placed"}, {"no_event": "hazard_triggered"}, {"hp_eq": ["E1", 1.0]}]},
	{"name": "rapid_spin_clears_foe_hazards", "code": "match seed=5 mode=pvp p=0003_venusaur@50:spikes,razor_leaf:overgrow e=0009_blastoise@50:rapid_spin,water_gun:torrent", "steps": ["face P1 E1", "near E1 P1 2", "attack P1 1 self", "enter_strip E1 P1", "attack E1 1 P1"], "expect": [{"event": "hazards_cleared"}]},
	{"name": "fly_two_turn_and_dodge", "code": "match seed=5 mode=pvp p=0006_charizard@50:fly,slash:blaze e=0007_squirtle@50:tackle,water_gun:torrent", "steps": ["adjacent E1 P1", "attack P1 1 E1", "attack E1 1 P1", "attack P1 1 E1"], "expect": [{"event": "move_charging", "field": {"move_id": "fly"}}, {"event": "miss", "field": {"reason": "airborne"}}, {"event": "damage_dealt", "field": {"move_id": "fly"}}]},
	{"name": "solar_beam_instant_in_sun", "code": "match seed=5 mode=pvp p=0003_venusaur@50:sunny_day,solar_beam:chlorophyll e=0007_squirtle@50:tackle,water_gun:torrent", "steps": ["adjacent E1 P1", "attack P1 1 self", "end E1", "attack P1 2 E1"], "expect": [{"no_event": "move_charging"}, {"event": "damage_dealt", "field": {"move_id": "solar_beam"}}]},
	{"name": "outrage_locks_then_confuses", "code": "match seed=5 mode=pvp p=0006_charizard@50:outrage,slash:blaze e=0009_blastoise@50:withdraw,water_gun:torrent", "steps": ["adjacent E1 P1", "attack P1 1 E1", "end E1", "attack P1 2 E1", "attack P1 1 E1", "end E1", "attack P1 1 E1", "end E1", "attack P1 1 E1", "end E1", "end P1"], "expect": [{"event": "move_blocked", "field": {"reason": "rampage_locked"}}, {"event": "status_applied", "status_id": "confuse"}]},
	{"name": "yawn_sleeps_next_turn", "code": "match seed=5 mode=pvp p=0007_squirtle@50:yawn,tackle:torrent e=0004_charmander@50:scratch,ember:blaze", "steps": ["adjacent E1 P1", "attack P1 1 E1", "end E1", "end P1", "end E1", "end P1"], "expect": [{"event": "status_applied", "status_id": "yawning"}, {"event": "status_applied", "status_id": "sleep"}]},
	{"name": "perish_song_counts_down", "code": "match seed=5 mode=pvp p=0143_snorlax@50:perish_song,tackle:thick_fat e=0007_squirtle@50:tackle,water_gun:torrent", "steps": ["adjacent E1 P1", "attack P1 1 self", "end E1", "end P1", "end E1", "end P1", "end E1", "end P1", "end E1"], "expect": [{"event": "status_applied", "status_id": "perish_song"}, {"event": "unit_fainted"}]},
	{"name": "rest_heals_and_sleeps", "code": "match seed=5 mode=pvp p=0143_snorlax@50:rest,tackle:thick_fat e=0007_squirtle@50:tackle,water_gun:torrent", "steps": ["adjacent E1 P1", "hp P1 0.3", "status P1 burn", "attack P1 1 self"], "expect": [{"hp_eq": ["P1", 1.0]}, {"status_on": ["P1", "sleep"]}, {"status_off": ["P1", "burn"]}]},
	{"name": "life_orb_recoil", "code": "match seed=5 mode=pvp p=0004_charmander@50:scratch,ember:blaze:held_life_orb e=0007_squirtle@50:withdraw,water_gun:torrent", "steps": ["adjacent E1 P1", "attack P1 1 E1"], "expect": [{"event": "damage_dealt", "field": {"move_id": "scratch"}}, {"hp_lt": ["P1", 1.0]}]},
	{"name": "sitrus_berry_at_half", "code": "match seed=5 mode=pvp p=0004_charmander@50:scratch,ember:blaze:berry_sitrus e=0007_squirtle@50:tackle,water_gun:torrent", "steps": ["adjacent E1 P1", "hp P1 0.6", "end P1", "attack E1 1 P1"], "expect": [{"event": "healed"}, {"item_gone": "P1"}]},
	{"name": "lum_berry_cures", "code": "match seed=5 mode=pvp p=0004_charmander@50:scratch,ember:blaze:berry_lum e=0025_pikachu@50:thunder_wave,quick_attack:static", "steps": ["adjacent E1 P1", "end P1", "attack E1 1 P1"], "expect": [{"event": "status_applied", "status_id": "paralyze"}, {"status_off": ["P1", "paralyze"]}, {"item_gone": "P1"}]},
	{"name": "choice_band_boosts_physical", "code": "match seed=5 mode=pvp p=0004_charmander@50:scratch,ember:blaze:held_choice_band e=0009_blastoise@50:withdraw,water_gun:torrent", "steps": ["adjacent E1 P1", "attack P1 1 E1"], "expect": [{"event": "damage_dealt", "field": {"move_id": "scratch"}}, {"damage_gt_baseline": ["scratch", "held_choice_band"]}]},
	{"name": "intimidate_at_start", "code": "match seed=5 mode=pvp p=0058_growlithe@50:ember,bite:intimidate e=0007_squirtle@50:tackle,water_gun:torrent", "steps": ["end P1"], "expect": [{"stage": ["E1", "attack", -1]}]},
	{"name": "drizzle_at_start", "code": "match seed=5 mode=pvp p=0186_politoed@50:water_gun,hypnosis:drizzle e=0007_squirtle@50:tackle,water_gun:torrent", "steps": ["end P1"], "expect": [{"event": "weather_started", "field": {"condition_id": "rain"}}]},
	{"name": "levitate_ignores_earthquake", "code": "match seed=5 mode=pvp p=0095_onix@50:earthquake,tackle:sturdy e=0092_gastly@50:lick,hypnosis:levitate", "steps": ["adjacent E1 P1", "attack P1 1 E1"], "expect": [{"event": "damage_prevented"}, {"hp_eq": ["E1", 1.0]}]},
	{"name": "rough_skin_hurts_attacker", "code": "match seed=5 mode=pvp p=0004_charmander@50:scratch,ember:blaze e=0318_carvanha@50:bite,aqua_jet:rough_skin", "steps": ["adjacent E1 P1", "attack P1 1 E1"], "expect": [{"hp_lt": ["P1", 1.0]}]},
	{"name": "water_absorb_heals", "code": "match seed=5 mode=pvp p=0007_squirtle@50:water_gun,tackle:torrent e=0060_poliwag@50:bubble,hypnosis:water_absorb", "steps": ["adjacent E1 P1", "hp E1 0.5", "attack P1 1 E1"], "expect": [{"hp_gt": ["E1", 0.5]}]},
	{"name": "sturdy_survives_at_full", "code": "match seed=5 mode=pvp p=0006_charizard@50:flamethrower,slash:blaze e=0074_geodude@50:tackle,defense_curl:sturdy", "steps": ["adjacent E1 P1", "hp P1 1.0", "attack P1 1 E1", "attack P1 1 E1", "attack P1 1 E1"], "expect": [{"survived_at_one": "E1"}]},
	{"name": "speed_boost_each_turn", "code": "match seed=5 mode=pvp p=0255_torchic@50:ember,scratch:speed_boost e=0007_squirtle@50:tackle,water_gun:torrent", "steps": ["end P1", "end E1", "end P1", "end E1"], "expect": [{"stage_at_least": ["P1", "speed", 1]}]},
	{"name": "encore_locks_move", "code": "match seed=5 mode=pvp p=0025_pikachu@50:encore,thunder_shock:static e=0007_squirtle@50:tackle,water_gun:torrent", "steps": ["adjacent E1 P1", "attack E1 1 P1", "attack P1 1 E1", "attack E1 2 P1"], "expect": [{"event": "status_applied", "status_id": "encore"}, {"event": "move_blocked", "status_id": "encore"}]},
	{"name": "counter_returns_double", "code": "match seed=5 mode=pvp p=0007_squirtle@50:counter,tackle:torrent e=0004_charmander@50:scratch,ember:blaze", "steps": ["adjacent E1 P1", "attack P1 1 self", "attack E1 1 P1"], "expect": [{"event": "counter_triggered"}]},
	{"name": "overcoat_blocks_powder", "code": "match seed=5 mode=pvp p=0001_bulbasaur@50:poison_powder,tackle:overgrow e=0413_wormadam@50:tackle:overcoat", "steps": ["adjacent E1 P1", "attack P1 1 E1"], "expect": [{"event": "status_blocked", "status_id": "poison"}, {"status_off": ["E1", "poison"]}]},
	{"name": "explosion_faints_user", "code": "match seed=5 mode=pvp p=0074_geodude@50:explosion,tackle:sturdy e=0007_squirtle@50:tackle,water_gun:torrent", "steps": ["adjacent E1 P1", "attack P1 1 E1"], "expect": [{"event": "damage_dealt", "field": {"move_id": "explosion"}}, {"fainted": "P1"}]},
]

var results: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var only: String = _arg("only")
	for scenario in SCENARIOS:
		if not only.is_empty() and not only.split(",").has(String(scenario["name"])):
			continue
		var result: Dictionary = await _run_scenario(scenario)
		results.append(result)
		print("scenario: %s %s failures=%s" % [String(scenario["name"]), "PASS" if bool(result["pass"]) else "FAIL", JSON.stringify(result["failed"])])
	var passed: int = 0
	for r in results:
		if bool(r["pass"]):
			passed += 1
	var file := FileAccess.open("%s/mechanics_scenarios.json" % OUTPUT_DIR, FileAccess.WRITE)
	file.store_string(JSON.stringify({"generated": Time.get_datetime_string_from_system(), "passed": passed, "total": results.size(), "results": results}, "\t"))
	file.close()
	print("scenarios: %d/%d passed" % [passed, results.size()])
	quit(0 if passed == results.size() else 1)


func _run_scenario(scenario: Dictionary) -> Dictionary:
	var driver := ValidationDriver.new(self)
	var lines: Array = ["code " + String(scenario["code"])]
	for step in scenario["steps"]:
		lines.append(String(step))
	var run: Dictionary = await driver.run_script(lines)
	driver.snapshot()
	var failed: Array[String] = []
	var details: Dictionary = {}
	if driver.log_ref == null:
		failed.append("level did not launch")
	else:
		for expectation in scenario["expect"]:
			var verdict: String = _check(driver, expectation)
			if not verdict.is_empty():
				failed.append(verdict)
		details["notation"] = driver.notation_snapshot
		details["final_hp"] = _hp_table(driver)
		details["event_counts"] = _event_counts(driver.log_ref)
		var notable: Array = []
		for event in driver.log_ref.events:
			var kind: String = String(event.get("kind", ""))
			if kind in ["intrinsic_triggered", "stat_stage_changed", "stat_stage_blocked", "held_item_triggered", "status_blocked", "move_rejected", "effect_blocked"]:
				notable.append("%s %s %s %s" % [kind, String(event.get("intrinsic_id", event.get("item_id", ""))), String(event.get("hook", event.get("reason", event.get("stat", "")))), str(event.get("unit", event.get("attacker", "")))])
		details["notable"] = notable
		var file := FileAccess.open("%s/scenario_%s.txt" % [OUTPUT_DIR, String(scenario["name"])], FileAccess.WRITE)
		file.store_string(driver.notation_snapshot + "\n\n" + "\n".join(driver.log_lines))
		file.close()
	for line in driver.log_lines:
		if String(line).begins_with("FAIL"):
			failed.append(String(line))
	if driver.main != null and is_instance_valid(driver.main):
		driver.main.queue_free()
	await process_frame
	await process_frame
	return {"name": scenario["name"], "pass": failed.is_empty(), "failed": failed, "driver_log": driver.log_lines, "details": details}


func _check(driver: ValidationDriver, expectation: Dictionary) -> String:
	var events: Array[Dictionary] = driver.log_ref.events
	if expectation.has("event"):
		var wanted: int = int(expectation.get("min", 1))
		var count: int = _count_events(events, String(expectation["event"]), expectation)
		return "" if count >= wanted else "expected %s x%d, saw %d" % [JSON.stringify(expectation), wanted, count]
	if expectation.has("no_event"):
		var count: int = _count_events(events, String(expectation["no_event"]), expectation)
		return "" if count == 0 else "unexpected %s x%d" % [String(expectation["no_event"]), count]
	if expectation.has("notation"):
		return "" if driver.notation_snapshot.contains(String(expectation["notation"])) else "notation lacks %s" % String(expectation["notation"])
	for key in ["hp_lt", "hp_eq", "hp_gt"]:
		if expectation.has(key):
			var spec: Array = expectation[key]
			var unit: Dictionary = driver.unit_snapshots.get(String(spec[0]), {})
			if unit.is_empty():
				return "unknown unit %s" % String(spec[0])
			var fraction: float = float(unit["hp"]) / float(unit["max"])
			var target: float = float(spec[1])
			var ok: bool = (fraction < target - 0.0001) if key == "hp_lt" else ((absf(fraction - target) < 0.0001) if key == "hp_eq" else (fraction > target + 0.0001))
			return "" if ok else "%s hp %.2f not %s %.2f" % [String(spec[0]), fraction, key, target]
	if expectation.has("status_on") or expectation.has("status_off"):
		var on: bool = expectation.has("status_on")
		var spec: Array = expectation["status_on"] if on else expectation["status_off"]
		var unit: Dictionary = driver.unit_snapshots.get(String(spec[0]), {})
		if unit.is_empty():
			return "unknown unit %s" % String(spec[0])
		var has: bool = (unit["statuses"] as Array).has(String(spec[1]))
		return "" if has == on else "%s status %s %s" % [String(spec[0]), String(spec[1]), "missing" if on else "present"]
	if expectation.has("stage") or expectation.has("stage_at_least"):
		var at_least: bool = expectation.has("stage_at_least")
		var spec: Array = expectation["stage_at_least"] if at_least else expectation["stage"]
		var unit: Dictionary = driver.unit_snapshots.get(String(spec[0]), {})
		if unit.is_empty():
			return "unknown unit %s" % String(spec[0])
		var stage: int = int((unit["stages"] as Dictionary).get(String(spec[1]), 0))
		var ok: bool = stage >= int(spec[2]) if at_least else stage == int(spec[2])
		return "" if ok else "%s %s stage %d not %s" % [String(spec[0]), String(spec[1]), stage, str(spec[2])]
	if expectation.has("damage_multiplier"):
		var spec: Array = expectation["damage_multiplier"]
		for event in events:
			if String(event.get("kind", "")) == "damage_dealt" and String(event.get("move_id", "")) == String(spec[0]) and is_equal_approx(float(event.get("weather_multiplier", 1.0)), float(spec[1])):
				return ""
		return "no %s hit with weather multiplier %.1f" % [String(spec[0]), float(spec[1])]
	if expectation.has("tick_increasing"):
		var spec: Array = expectation["tick_increasing"]
		var unit: Dictionary = driver.unit_snapshots.get(String(spec[0]), {})
		var pawn: Variant = unit.get("pawn", null)
		var amounts: Array[int] = []
		for event in events:
			if String(event.get("kind", "")) == "status_tick" and String(event.get("status_id", "")) == String(spec[1]) and event.get("unit") == pawn:
				amounts.append(int(event.get("amount", 0)))
		if amounts.size() < 2:
			return "fewer than two %s ticks (%s)" % [String(spec[1]), str(amounts)]
		return "" if amounts[1] > amounts[0] else "ticks not increasing %s" % str(amounts)
	if expectation.has("second_damage_lower"):
		var move_id: String = String(expectation["second_damage_lower"][0])
		var amounts: Array[int] = []
		for event in events:
			if String(event.get("kind", "")) == "damage_dealt" and String(event.get("move_id", "")) == move_id and String(event.get("source", "")).is_empty():
				amounts.append(int(event.get("amount", 0)))
		if amounts.size() < 2:
			return "fewer than two %s hits (%s)" % [move_id, str(amounts)]
		return "" if amounts[1] < amounts[0] else "second %s hit not lower %s" % [move_id, str(amounts)]
	if expectation.has("damage_gt_baseline"):
		var spec: Array = expectation["damage_gt_baseline"]
		var amount: int = 0
		for event in events:
			if String(event.get("kind", "")) == "damage_dealt" and String(event.get("move_id", "")) == String(spec[0]) and String(event.get("source", "")).is_empty():
				amount = int(event.get("amount", 0))
		return "" if amount > 0 else "no %s damage recorded" % String(spec[0])
	if expectation.has("item_is"):
		var spec: Array = expectation["item_is"]
		var unit: Dictionary = driver.unit_snapshots.get(String(spec[0]), {})
		return "" if not unit.is_empty() and String(unit["item"]) == String(spec[1]) else "%s holds %s, not %s" % [String(spec[0]), str(unit.get("item", "?")), String(spec[1])]
	if expectation.has("item_gone"):
		var unit: Dictionary = driver.unit_snapshots.get(String(expectation["item_gone"]), {})
		return "" if not unit.is_empty() and String(unit["item"]).is_empty() else "%s still holds an item" % String(expectation["item_gone"])
	if expectation.has("fainted"):
		var unit: Dictionary = driver.unit_snapshots.get(String(expectation["fainted"]), {})
		return "" if unit.is_empty() or not bool(unit["active"]) else "%s still active" % String(expectation["fainted"])
	if expectation.has("survived_at_one"):
		var unit: Dictionary = driver.unit_snapshots.get(String(expectation["survived_at_one"]), {})
		for event in events:
			if String(event.get("kind", "")) == "intrinsic_triggered" and String(event.get("intrinsic_id", "")) == "sturdy":
				return ""
		return "sturdy never triggered (hp %s)" % str(unit.get("hp", "?"))
	return "unknown expectation %s" % JSON.stringify(expectation)


func _count_events(events: Array[Dictionary], kind: String, expectation: Dictionary) -> int:
	var count: int = 0
	for event in events:
		if String(event.get("kind", "")) != kind:
			continue
		if expectation.has("status_id") and String(event.get("status_id", "")) != String(expectation["status_id"]):
			continue
		var fields: Dictionary = expectation.get("field", {})
		var ok: bool = true
		for key in fields.keys():
			if str(event.get(key, "")) != str(fields[key]):
				ok = false
		if ok:
			count += 1
	return count


func _event_counts(log: BattleLog) -> Dictionary:
	var out: Dictionary = {}
	for event in log.events:
		var kind: String = String(event.get("kind", ""))
		out[kind] = int(out.get(kind, 0)) + 1
	return out


func _hp_table(driver: ValidationDriver) -> Array:
	var out: Array = []
	for key in driver.unit_snapshots.keys():
		if String(key).length() <= 3:
			continue
		var unit: Dictionary = driver.unit_snapshots[key]
		out.append("%s %d/%d %s" % [String(key), int(unit["hp"]), int(unit["max"]), str(unit["statuses"])])
	return out


func _arg(name: String) -> String:
	for arg in OS.get_cmdline_user_args():
		var text: String = String(arg)
		if text.begins_with("--%s=" % name):
			return text.substr(name.length() + 3)
	return ""
