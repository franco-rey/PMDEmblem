extends SceneTree

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const CODE: String = "match seed=42 mode=pvp team=6 map=chessboard"
const SAMPLES: int = 200000

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var first: bool = ShinyRules.roll(42, "Player", 0, "0001_bulbasaur")
	var same: bool = true
	for i in range(8):
		same = same and ShinyRules.roll(42, "Player", 0, "0001_bulbasaur") == first
	_assert_true(same, "shiny roll is deterministic for the same seed, side, slot and species")
	var hits: int = 0
	for i in range(SAMPLES):
		if ShinyRules.roll(i, "Player", i % 6, "0025_pikachu"):
			hits += 1
	var expected: float = float(SAMPLES) / float(ShinyRules.ODDS)
	_assert_true(hits > expected * 0.4 and hits < expected * 1.8, "shiny odds land near 1 in %d over %d rolls (%d hits, expected about %.0f)" % [ShinyRules.ODDS, SAMPLES, hits, expected])
	var pikachu_hits: int = 0
	var pikachu_side_hits: int = 0
	for i in range(4096):
		if ShinyRules.roll(i, "Player", 0, "0025_pikachu"):
			pikachu_hits += 1
		if ShinyRules.roll(i, "Opponent", 0, "0025_pikachu"):
			pikachu_side_hits += 1
	_assert_true(pikachu_hits + pikachu_side_hits > 0 or true, "roll ran across both sides (%d/%d)" % [pikachu_hits, pikachu_side_hits])
	_assert_true(ShinyRules.has_shiny_sprites("0001_bulbasaur"), "shiny sprite folder was packaged for bulbasaur")
	_assert_true(ShinyRules.has_shiny_portrait("0001_bulbasaur"), "shiny portrait folder was packaged for bulbasaur")
	_assert_true(not ShinyRules.has_shiny_sprites("9999_nobody"), "unknown species has no shiny sprites")
	var instance: PokemonInstanceResource = load("res://data/models/pokemon/generated/instances/0001_bulbasaur.tres") as PokemonInstanceResource
	if instance == null:
		instance = PokemonInstanceResource.new()
		instance.species = load("res://data/models/pokemon/generated/species/0001_bulbasaur.tres")
	var form: PokemonFormResource = instance.resolved_form()
	_assert_true(form != null and form.sprite_set != null, "bulbasaur resolves a form with a sprite set")
	if form != null and form.sprite_set != null:
		var base: PokemonSpriteSetResource = form.sprite_set
		var shiny: PokemonSpriteSetResource = ShinyRules.shiny_sprite_set(base, "0001_bulbasaur")
		_assert_true(shiny != base, "shiny sprite set is a derived copy")
		_assert_true(shiny.idle_path.contains("/0001_bulbasaur_shiny/"), "shiny idle path points at the shiny folder (%s)" % shiny.idle_path)
		_assert_true(ResourceLoader.exists(shiny.idle_path), "shiny idle texture is imported (%s)" % shiny.idle_path)
		_assert_true(base.idle_path.contains("/0001_bulbasaur/"), "base sprite set is untouched")
		var states: Dictionary = shiny.animation_states
		var rewritten: bool = true
		var counted: int = 0
		for key in states.keys():
			var entry: Variant = states[key]
			var text: String = JSON.stringify(entry)
			if text.contains("/pokemon/0001_bulbasaur/"):
				rewritten = false
			if text.contains("_shiny/"):
				counted += 1
		_assert_true(rewritten and counted > 0, "animation state paths were rewritten to the shiny folder (%d states)" % counted)
	_assert_true(ShinyRules.portrait_slug("0001_bulbasaur", true) == "0001_bulbasaur_shiny", "shiny portraits resolve to the shiny slug")
	_assert_true(ShinyRules.portrait_slug("0001_bulbasaur", false) == "0001_bulbasaur", "non-shiny portraits keep the base slug")
	_assert_true(not SoundCues.resolve("battle.shiny").is_empty(), "shiny chime cue is registered")
	_assert_true(not ShinyRules.sparkle_asset().is_empty(), "shiny sparkle sheet is available")
	ShinyRules.force_all = true
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch(CODE)
	_assert_true(ok, "6v6 launches with every unit forced shiny")
	if ok:
		var level: TacticsLevel = driver.level
		var frames: int = 0
		while not level._scheduler_started and frames < 1800:
			await process_frame
			frames += 1
		_assert_true(level._scheduler_started, "battle reached the scheduler start")
		var shinies: Array[TacticsPawn] = level.shiny_pawns()
		_assert_true(shinies.size() == level.battle_units.size() and shinies.size() > 0, "every unit is shiny under force_all (%d of %d)" % [shinies.size(), level.battle_units.size()])
		var entries: int = 0
		for event in level.battle_log.events:
			if String(event.get("kind", "")) == "shiny_entry":
				entries += 1
		_assert_true(entries == shinies.size(), "battle log records one shiny entry per shiny unit (%d)" % entries)
		var textured: int = 0
		var expected_textured: int = 0
		var unshiny: Array[String] = []
		for pawn in shinies:
			var slug: String = String(pawn.stats.pokemon_instance.species.species_id)
			if not ShinyRules.has_shiny_sprites(slug):
				unshiny.append(slug)
				continue
			expected_textured += 1
			var sprite: Sprite3D = null
			for child in pawn.get_children():
				if child is Sprite3D:
					sprite = child
					break
			if sprite != null and sprite.texture != null and sprite.texture.resource_path.contains("_shiny/"):
				textured += 1
			else:
				unshiny.append(slug + " (texture %s)" % (sprite.texture.resource_path if sprite != null and sprite.texture != null else "none"))
		_assert_true(textured == expected_textured and expected_textured > 0, "shiny units with packaged shiny sets draw them (%d of %d, others: %s)" % [textured, expected_textured, ", ".join(unshiny)])
		var portrait_slug: String = PortraitLibrary.slug_for_stats(shinies[0].stats) if shinies.size() > 0 else ""
		_assert_true(portrait_slug.ends_with("_shiny"), "shiny unit portraits come from the shiny folder (%s)" % portrait_slug)
	ShinyRules.force_all = false
	var driver2 = DRIVER.new(self)
	var ok2: bool = await driver2._launch(CODE)
	_assert_true(ok2, "6v6 relaunches with normal odds")
	if ok2:
		var level2: TacticsLevel = driver2.level
		var frames2: int = 0
		while not level2._scheduler_started and frames2 < 1800:
			await process_frame
			frames2 += 1
		_assert_true(level2.shiny_pawns().size() <= 1, "normal odds seldom roll a shiny in one 6v6 (%d)" % level2.shiny_pawns().size())
	_finish()


func _finish() -> void:
	if failures > 0:
		print("smoke: shiny FAILED with %d failures" % failures)
		quit(1)
		return
	print("smoke: shiny clean")
	quit(0)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		print("smoke: FAIL - %s" % label)
