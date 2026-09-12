extends SmokeCase

const MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const SEED: int = 4242
const ROUND_CAP: int = 12
const MAX_FRAMES: int = 6000


func _run() -> void:
	var first: Array[String] = await _play()
	var second: Array[String] = await _play()
	_assert_true(first.size() > 8, "the seeded CPU battle produced a notation (%d lines)" % first.size())
	_assert_true(first == second, "the same seed replays to an identical notation (%d vs %d lines)" % [first.size(), second.size()])
	if first != second:
		for i in range(mini(first.size(), second.size())):
			if first[i] != second[i]:
				push_error("smoke: first divergence at line %d: %s | %s" % [i, first[i], second[i]])
				break
	_finish("bot_determinism")


func _play() -> Array[String]:
	var built: Dictionary = CustomSkirmishBuilder.build_random(2, MAP_PATH, str(SEED), SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU)
	if not bool(built.get("ok", false)):
		push_error("smoke: build failed %s" % String(built.get("error", "")))
		return [] as Array[String]
	var definition: SkirmishDefinitionResource = built["definition"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("determinism:%d" % SEED)
	var pool: Array[Dictionary] = BattleItemCatalog.entries()
	for side in [definition.player_team, definition.enemy_team]:
		for instance in side:
			var abilities: Array[String] = CustomSkirmishBuilder.available_ability_ids(instance)
			if not abilities.is_empty():
				instance.ability_override = abilities[rng.randi_range(0, abilities.size() - 1)]
			if not pool.is_empty():
				instance.held_item = PokemonItemService.load_item(String(pool[rng.randi_range(0, pool.size() - 1)].get("item_id", "")))
	definition.skirmish_id = "determinism_%d" % SEED
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var level: TacticsLevel = loader.load_skirmish(definition, root)
	level.presentation_runner.immediate_mode = true
	level.process_mode = Node.PROCESS_MODE_ALWAYS
	var ended: Array = [false]
	level.battle_ended.connect(func(_result: int) -> void:
		ended[0] = true)
	var frames: int = 0
	while frames < MAX_FRAMES and not ended[0] and level.notation.turn_index < ROUND_CAP * 4:
		await physics_frame
		frames += 1
	var lines: Array[String] = []
	for line in level.notation.lines:
		var text: String = String(line)
		if text.begins_with("#"):
			continue
		lines.append(text)
	loader.unload_current()
	loader.queue_free()
	await process_frame
	await process_frame
	return lines
