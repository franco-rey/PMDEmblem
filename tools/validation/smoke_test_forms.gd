extends SmokeCase

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const LOBBY_SCENE_PATH: String = "res://assets/scene/skirmish_lobby.tscn"
const CODE: String = "match seed=5 mode=pvp p=0019_rattata~1@50|0386_deoxys~1@50|0479_rotom~5@50 e=0019_rattata@50|0483_dialga~1@50|0201_unown~3@50 map=chessboard"


func _species(slug: String) -> PokemonSpeciesResource:
	return load("res://data/models/pokemon/generated/species/%s.tres" % slug) as PokemonSpeciesResource


func _run() -> void:
	var rattata: PokemonSpeciesResource = _species("0019_rattata")
	var rotom: PokemonSpeciesResource = _species("0479_rotom")
	var deoxys: PokemonSpeciesResource = _species("0386_deoxys")
	var charizard: PokemonSpeciesResource = _species("0006_charizard")
	var unown: PokemonSpeciesResource = _species("0201_unown")
	var bulbasaur: PokemonSpeciesResource = _species("0001_bulbasaur")
	_assert_true(_same(FormRules.options(rattata), [0, 1]), "rattata offers its Alolan form (%s)" % str(FormRules.options(rattata)))
	_assert_true(_same(FormRules.options(rotom), [0, 5]), "rotom offers only the released Mow form (%s)" % str(FormRules.options(rotom)))
	_assert_true(_same(FormRules.options(deoxys), [0, 1, 2, 3]), "deoxys offers all four formes (%s)" % str(FormRules.options(deoxys)))
	_assert_true(_same(FormRules.options(charizard), [0]) and not FormRules.is_choice(charizard), "charizard's megas are battle-only and never offered")
	_assert_true(FormRules.options(unown).size() == 28, "unown offers all 28 letters (%d)" % FormRules.options(unown).size())
	_assert_true(not FormRules.is_choice(bulbasaur), "bulbasaur has a single form")
	_assert_true(FormRules.label(rattata, 1) == "Alolan Rattata" and FormRules.label(rattata, 0) == "Rattata", "form labels come from the form names (%s / %s)" % [FormRules.label(rattata, 1), FormRules.label(rattata, 0)])
	_assert_true(FormRules.roll(unown, 3, "player", 2) == FormRules.roll(unown, 3, "player", 2), "form roll is deterministic")
	var seen: Dictionary = {}
	for i in range(2800):
		seen[FormRules.roll(unown, i, "player", i % 6)] = int(seen.get(FormRules.roll(unown, i, "player", i % 6), 0)) + 1
	var thin: int = 0
	for key in seen.keys():
		if int(seen[key]) < 50:
			thin += 1
	_assert_true(seen.size() == 28 and thin == 0, "unown rolls spread across every letter (%d letters, %d thin)" % [seen.size(), thin])
	_assert_true(FormRules.roll(bulbasaur, 9, "enemy", 0) == 0, "single-form species always roll their form")
	_assert_true(FormRules.choice_error(charizard, 1, "Charizard").contains("battle-only"), "battle-only forms are refused with a reason")
	_assert_true(FormRules.choice_error(rotom, 2, "Rotom").contains("not released"), "unreleased forms are refused with a reason")
	_assert_true(FormRules.choice_error(rattata, 7, "Rattata").contains("no form 7"), "out-of-range forms are refused")

	var parsed: Dictionary = SkirmishCode.parse("match seed=3 p=0019_rattata~1@50f|0479_rotom~5@50 e=0019_rattata@50m")
	_assert_true(bool(parsed.get("ok", false)), "codes with form marks parse (%s)" % String(parsed.get("error", "")))
	var bad: Dictionary = SkirmishCode.parse("match seed=3 p=0019_rattata~x@50 e=0019_rattata@50")
	_assert_true(not bool(bad.get("ok", true)), "a non-numeric form mark is rejected")
	var mega: Dictionary = SkirmishCode.build_definitions("match seed=3 mode=pvp p=0006_charizard~1@50 e=0019_rattata@50 map=chessboard")
	_assert_true(not bool(mega.get("ok", true)) and String(mega.get("error", "")).contains("battle-only"), "a mega form in a code is rejected (%s)" % String(mega.get("error", "")))
	var built: Dictionary = SkirmishCode.build_definitions(CODE)
	_assert_true(bool(built.get("ok", false)), "explicit form code builds (%s)" % String(built.get("error", "")))
	if bool(built.get("ok", false)):
		var definition: SkirmishDefinitionResource = (built.get("definitions", []) as Array)[0]
		var forms: Array[int] = []
		for instance in definition.player_team:
			forms.append(instance.form_index)
		var enemy_forms: Array[int] = []
		for instance in definition.enemy_team:
			enemy_forms.append(instance.form_index)
		_assert_true(_same(forms, [1, 1, 5]), "player side keeps the explicit forms (%s)" % str(forms))
		_assert_true(_same(enemy_forms, [0, 1, 3]), "enemy side keeps default and explicit forms (%s)" % str(enemy_forms))
		var alolan: PokemonFormResource = definition.player_team[0].resolved_form()
		_assert_true(alolan != null and str(alolan.types()) == str(["dark", "normal"]), "Alolan Rattata resolves its own types (%s)" % str(alolan.types() if alolan != null else []))
		var encoded: String = SkirmishCode.encode_definition(definition)
		_assert_true(encoded.contains("0019_rattata~1@50") and encoded.contains("0479_rotom~5@50") and encoded.contains("e=0019_rattata@50"), "encoding writes the mark only for non-default forms (%s)" % encoded)
		var again: Dictionary = SkirmishCode.build_definitions(encoded)
		_assert_true(bool(again.get("ok", false)) and ((again.get("definitions", []) as Array)[0] as SkirmishDefinitionResource).player_team[0].form_index == 1, "encoded code round-trips the form")
	var random_a: Dictionary = SkirmishCode.build_definitions("match seed=13 mode=pvp team=6 map=chessboard")
	var random_b: Dictionary = SkirmishCode.build_definitions("match seed=13 mode=pvp team=6 map=chessboard")
	if bool(random_a.get("ok", false)) and bool(random_b.get("ok", false)):
		var a: SkirmishDefinitionResource = (random_a.get("definitions", []) as Array)[0]
		var b: SkirmishDefinitionResource = (random_b.get("definitions", []) as Array)[0]
		var same: bool = true
		for i in range(a.player_team.size()):
			same = same and a.player_team[i].form_index == b.player_team[i].form_index
		for i in range(a.enemy_team.size()):
			same = same and a.enemy_team[i].form_index == b.enemy_team[i].form_index
		_assert_true(same, "random teams roll the same forms for the same seed")
	var rolled: int = 0
	for seed in range(1, 41):
		var result: Dictionary = SkirmishCode.build_definitions("match seed=%d mode=pvp team=6 map=chessboard" % seed)
		if not bool(result.get("ok", false)):
			continue
		var definition: SkirmishDefinitionResource = (result.get("definitions", []) as Array)[0]
		for instance in definition.player_team + definition.enemy_team:
			if instance.form_index != FormRules.default_index(instance.species):
				rolled += 1
	_assert_true(rolled > 0, "random teams sometimes land on alternate forms (%d across forty seeds)" % rolled)

	await _check_lobby(rattata)
	await _check_battle()
	_finish("forms")


func _check_lobby(rattata: PokemonSpeciesResource) -> void:
	var scene: PackedScene = load(LOBBY_SCENE_PATH) as PackedScene
	var lobby: Control = scene.instantiate() as Control
	root.add_child(lobby)
	lobby.size = Vector2(1280, 900)
	await process_frame
	await process_frame
	var entries: Array[Dictionary] = lobby.get_roster_entries()
	var rattata_index: int = -1
	var bulbasaur_index: int = -1
	for i in range(entries.size()):
		if String(entries[i].get("slug", "")) == "0019_rattata":
			rattata_index = i
		elif String(entries[i].get("slug", "")) == "0001_bulbasaur":
			bulbasaur_index = i
	_assert_true(rattata_index >= 0 and bulbasaur_index >= 0, "roster lists rattata and bulbasaur")
	lobby.activate_player_team()
	lobby.add_roster_index(rattata_index)
	lobby.add_roster_index(bulbasaur_index)
	await process_frame
	var slot: Button = lobby.find_child("PlayerSlot1", true, false) as Button
	if slot != null:
		slot.pressed.emit()
	await process_frame
	var random_check: CheckButton = lobby.find_child("RandomFormCheck", true, false) as CheckButton
	var picker: OptionButton = lobby.find_child("FormPicker", true, false) as OptionButton
	var value: Label = lobby.find_child("FormValueLabel", true, false) as Label
	_assert_true(random_check != null and picker != null and value != null, "lobby details carry the form controls")
	if random_check == null or picker == null or value == null:
		lobby.queue_free()
		return
	_assert_true(not random_check.disabled and random_check.button_pressed and picker.disabled and picker.item_count == 2, "rattata starts on a random form with two forms listed")
	_assert_true(value.text == "Rolled from 2 forms", "random form explains the pool (%s)" % value.text)
	_assert_true(lobby.set_slot_form("player", 0, "1"), "the Alolan form can be chosen")
	await process_frame
	_assert_true(not random_check.button_pressed and not picker.disabled and picker.get_item_id(picker.selected) == 1, "choosing the form enables the picker on it")
	var title: Label = lobby.find_child("SlotTitleLabel", true, false) as Label
	_assert_true(title != null and title.text.contains("Alolan Rattata"), "slot title names the chosen form (%s)" % (title.text if title != null else "-"))
	var payload: Array = lobby.call("_specs_payload", "player")
	_assert_true(payload.size() == 2 and String((payload[0] as Dictionary).get("form", "")) == "1" and String((payload[1] as Dictionary).get("form", "")) == "random", "spec payload carries the form choice and the random default")
	var second: Button = lobby.find_child("PlayerSlot2", true, false) as Button
	if second != null:
		second.pressed.emit()
	await process_frame
	_assert_true(random_check.disabled and picker.disabled and value.text == "Single form", "bulbasaur locks the form controls (%s)" % value.text)
	_assert_true(not lobby.set_slot_form("player", 1, "1"), "a form bulbasaur lacks is refused")
	lobby.activate_enemy_team()
	lobby.add_roster_index(rattata_index)
	await process_frame
	var result: Dictionary = lobby.build_current_definition()
	_assert_true(bool(result.get("ok", false)), "lobby builds with the form choice (%s)" % String(result.get("error", "")))
	if bool(result.get("ok", false)):
		var definition: SkirmishDefinitionResource = result["definition"]
		_assert_true(definition.player_team[0].form_index == 1, "built player team keeps Alolan Rattata")
	_assert_true(rattata != null and FormRules.label(rattata, 1) == "Alolan Rattata", "form label available for the picker")
	lobby.queue_free()
	await process_frame


func _check_battle() -> void:
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch(CODE)
	_assert_true(ok, "form 3v3 launches")
	if not ok:
		return
	var level: TacticsLevel = driver.level
	var frames: int = 0
	while not level._scheduler_started and frames < 1800:
		await process_frame
		frames += 1
	var alolan: TacticsPawn = null
	var plain: TacticsPawn = null
	var unown: TacticsPawn = null
	for pawn in level.player.get_children():
		if String(pawn.stats.pokemon_instance.species.species_id) == "0019_rattata":
			alolan = pawn
	for pawn in level.opponent.get_children():
		var slug: String = String(pawn.stats.pokemon_instance.species.species_id)
		if slug == "0019_rattata":
			plain = pawn
		elif slug == "0201_unown":
			unown = pawn
	_assert_true(alolan != null and plain != null and unown != null, "probe units spawned")
	if alolan == null or plain == null or unown == null:
		return
	_assert_true(str(alolan.stats.types) == str(["dark", "normal"]) and str(plain.stats.types) == str(["normal"]), "battle stats follow the chosen form (%s vs %s)" % [str(alolan.stats.types), str(plain.stats.types)])
	var a_sprite: Sprite3D = _sprite_of(alolan)
	var p_sprite: Sprite3D = _sprite_of(plain)
	var u_sprite: Sprite3D = _sprite_of(unown)
	_assert_true(a_sprite != null and a_sprite.texture != null and a_sprite.texture.resource_path.contains("0019_rattata_form1/"), "Alolan Rattata draws the form sprite set (%s)" % (a_sprite.texture.resource_path if a_sprite != null and a_sprite.texture != null else "-"))
	_assert_true(p_sprite != null and p_sprite.texture != null and p_sprite.texture.resource_path.contains("0019_rattata/"), "plain Rattata draws the base sprite set")
	_assert_true(u_sprite != null and u_sprite.texture != null and u_sprite.texture.resource_path.contains("0201_unown_form3/"), "Unown D draws its letter (%s)" % (u_sprite.texture.resource_path if u_sprite != null and u_sprite.texture != null else "-"))
	_assert_true(PortraitLibrary.slug_for_stats(alolan.stats) == "0019_rattata_form1", "Alolan Rattata portraits come from the form folder (%s)" % PortraitLibrary.slug_for_stats(alolan.stats))
	_assert_true(FormRules.decorate(level.notation.unit_name(alolan), alolan.stats).contains("Alolan Rattata"), "HUD name decoration reads the form name (%s)" % FormRules.decorate(level.notation.unit_name(alolan), alolan.stats))
	var sprite_service = a_sprite
	_assert_true(sprite_service.get("state_frame_counts") != null and int((sprite_service.get("state_frame_counts") as Dictionary).get("idle", 0)) > 0, "form sprite frames come from the form's own animation data (%s)" % str(sprite_service.get("state_frame_counts")))


func _sprite_of(pawn: TacticsPawn) -> Sprite3D:
	for child in pawn.get_children():
		if child is Sprite3D:
			return child
	return null


func _same(values: Array[int], expected: Array) -> bool:
	if values.size() != expected.size():
		return false
	for i in range(values.size()):
		if values[i] != int(expected[i]):
			return false
	return true
