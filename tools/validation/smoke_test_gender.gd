extends SmokeCase

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const LOBBY_SCENE_PATH: String = "res://assets/scene/skirmish_lobby.tscn"
const CODE: String = "match seed=7 mode=pvp p=0025_pikachu@50f|0521_unfezant@50f|0003_venusaur@50f e=0025_pikachu@50m|0029_nidoran_f@50|0081_magnemite@50 map=chessboard"


func _form(slug: String) -> PokemonFormResource:
	var instance: PokemonInstanceResource = load("res://data/models/pokemon/generated/instances/%s.tres" % slug) as PokemonInstanceResource
	return instance.resolved_form() if instance != null else null


func _run() -> void:
	var bulbasaur: PokemonFormResource = _form("0001_bulbasaur")
	var nidoran_f: PokemonFormResource = _form("0029_nidoran_f")
	var nidoran_m: PokemonFormResource = _form("0032_nidoran_m")
	var magnemite: PokemonFormResource = _form("0081_magnemite")
	_assert_true(_same(GenderRules.options(bulbasaur), [GenderRules.MALE, GenderRules.FEMALE]), "bulbasaur offers both genders")
	_assert_true(_same(GenderRules.options(nidoran_f), [GenderRules.FEMALE]) and GenderRules.fixed(nidoran_f) == GenderRules.FEMALE, "nidoran (f) is female only")
	_assert_true(_same(GenderRules.options(nidoran_m), [GenderRules.MALE]), "nidoran (m) is male only")
	_assert_true(_same(GenderRules.options(magnemite), [GenderRules.GENDERLESS]) and GenderRules.ratio_label(magnemite) == "Genderless", "magnemite is genderless")
	_assert_true(GenderRules.ratio_label(bulbasaur) == "7♂ : 1♀", "ratio label reads the species weights (%s)" % GenderRules.ratio_label(bulbasaur))
	var males: int = 0
	for i in range(4000):
		if GenderRules.roll(bulbasaur, i, "player", i % 6) == GenderRules.MALE:
			males += 1
	_assert_true(males > 3300 and males < 3700, "bulbasaur rolls male about seven times in eight (%d of 4000)" % males)
	_assert_true(GenderRules.roll(bulbasaur, 99, "player", 2) == GenderRules.roll(bulbasaur, 99, "player", 2), "gender roll is deterministic")
	_assert_true(GenderRules.roll(nidoran_f, 5, "enemy", 0) == GenderRules.FEMALE and GenderRules.roll(magnemite, 5, "enemy", 0) == GenderRules.GENDERLESS, "fixed species always roll their gender")
	_assert_true(GenderRules.opposite(GenderRules.MALE, GenderRules.FEMALE) and not GenderRules.opposite(GenderRules.MALE, GenderRules.MALE) and not GenderRules.opposite(GenderRules.GENDERLESS, GenderRules.FEMALE), "opposite gender check")
	_assert_true(GenderRules.same(GenderRules.FEMALE, GenderRules.FEMALE) and not GenderRules.same(GenderRules.GENDERLESS, GenderRules.GENDERLESS), "same gender check ignores genderless")
	_assert_true(GenderRules.parse_id("f") == GenderRules.FEMALE and GenderRules.parse_id("Male") == GenderRules.MALE and GenderRules.parse_id("x") == GenderRules.UNKNOWN, "gender ids parse")
	_assert_true(GenderRules.suffix(GenderRules.FEMALE) == " ♀" and GenderRules.suffix(GenderRules.GENDERLESS) == "", "name suffix carries the mark")
	_assert_true(GenderRules.choice_error(nidoran_f, GenderRules.MALE, "Nidoran").begins_with("Nidoran cannot be male"), "choice error names the impossible gender")

	var parsed: Dictionary = SkirmishCode.parse("match seed=3 p=0025_pikachu@50f|0001_bulbasaur@f|0081_magnemite@50 e=0025_pikachu@50m")
	_assert_true(bool(parsed.get("ok", false)), "codes with gender suffixes parse (%s)" % String(parsed.get("error", "")))
	var bad: Dictionary = SkirmishCode.parse("match seed=3 p=0025_pikachu@50x e=0025_pikachu@50m")
	_assert_true(not bool(bad.get("ok", true)), "an unknown level suffix is rejected")
	var wrong: Dictionary = SkirmishCode.build_definitions("match seed=3 mode=pvp p=0029_nidoran_f@50m e=0025_pikachu@50m map=chessboard")
	_assert_true(not bool(wrong.get("ok", true)) and String(wrong.get("error", "")).contains("cannot be male"), "a male nidoran (f) is rejected (%s)" % String(wrong.get("error", "")))
	var built: Dictionary = SkirmishCode.build_definitions(CODE)
	_assert_true(bool(built.get("ok", false)), "explicit gender code builds (%s)" % String(built.get("error", "")))
	if bool(built.get("ok", false)):
		var definition: SkirmishDefinitionResource = (built.get("definitions", []) as Array)[0]
		var genders: Array[int] = []
		for instance in definition.player_team:
			genders.append(instance.gender)
		var enemy_genders: Array[int] = []
		for instance in definition.enemy_team:
			enemy_genders.append(instance.gender)
		_assert_true(_same(genders, [GenderRules.FEMALE, GenderRules.FEMALE, GenderRules.FEMALE]), "player side keeps the explicit female choices (%s)" % str(genders))
		_assert_true(_same(enemy_genders, [GenderRules.MALE, GenderRules.FEMALE, GenderRules.GENDERLESS]), "enemy side resolves male, female-only and genderless (%s)" % str(enemy_genders))
		var encoded: String = SkirmishCode.encode_definition(definition)
		_assert_true(encoded.contains("0025_pikachu@50f") and encoded.contains("0025_pikachu@50m") and not encoded.contains("nidoran_f@50f"), "encoding writes the suffix only where the species has a choice (%s)" % encoded)
		var again: Dictionary = SkirmishCode.build_definitions(encoded)
		_assert_true(bool(again.get("ok", false)) and ((again.get("definitions", []) as Array)[0] as SkirmishDefinitionResource).player_team[0].gender == GenderRules.FEMALE, "encoded code round-trips the gender")
	var random_a: Dictionary = SkirmishCode.build_definitions("match seed=11 mode=pvp team=6 map=chessboard")
	var random_b: Dictionary = SkirmishCode.build_definitions("match seed=11 mode=pvp team=6 map=chessboard")
	if bool(random_a.get("ok", false)) and bool(random_b.get("ok", false)):
		var a: SkirmishDefinitionResource = (random_a.get("definitions", []) as Array)[0]
		var b: SkirmishDefinitionResource = (random_b.get("definitions", []) as Array)[0]
		var same: bool = true
		var unknown: int = 0
		for i in range(a.player_team.size()):
			same = same and a.player_team[i].gender == b.player_team[i].gender
			if a.player_team[i].gender == GenderRules.UNKNOWN:
				unknown += 1
		for i in range(a.enemy_team.size()):
			same = same and a.enemy_team[i].gender == b.enemy_team[i].gender
			if a.enemy_team[i].gender == GenderRules.UNKNOWN:
				unknown += 1
		_assert_true(same and unknown == 0, "random teams roll every gender from the seed (%d unresolved)" % unknown)
	else:
		_assert_true(false, "random 6v6 builds for the gender roll check")

	await _check_lobby()
	await _check_battle()
	_finish("gender")


func _check_lobby() -> void:
	var scene: PackedScene = load(LOBBY_SCENE_PATH) as PackedScene
	var lobby: Control = scene.instantiate() as Control
	root.add_child(lobby)
	lobby.size = Vector2(1280, 900)
	await process_frame
	await process_frame
	var entries: Array[Dictionary] = lobby.get_roster_entries()
	var pikachu_index: int = -1
	var nidoran_index: int = -1
	for i in range(entries.size()):
		if String(entries[i].get("slug", "")) == "0025_pikachu":
			pikachu_index = i
		elif String(entries[i].get("slug", "")) == "0029_nidoran_f":
			nidoran_index = i
	_assert_true(pikachu_index >= 0 and nidoran_index >= 0, "roster lists pikachu and nidoran (f)")
	lobby.activate_player_team()
	lobby.add_roster_index(pikachu_index)
	lobby.add_roster_index(nidoran_index)
	await process_frame
	var slot: Button = lobby.find_child("PlayerSlot1", true, false) as Button
	if slot != null:
		slot.pressed.emit()
	await process_frame
	var random_check: CheckButton = lobby.find_child("RandomGenderCheck", true, false) as CheckButton
	var picker: OptionButton = lobby.find_child("GenderPicker", true, false) as OptionButton
	var value: Label = lobby.find_child("GenderValueLabel", true, false) as Label
	_assert_true(random_check != null and picker != null and value != null, "lobby details carry the gender controls")
	if random_check == null or picker == null or value == null:
		lobby.queue_free()
		return
	_assert_true(not random_check.disabled and random_check.button_pressed and picker.disabled, "pikachu starts on a random gender with the picker idle")
	_assert_true(value.text.contains("4♂ : 4♀"), "random gender explains the species ratio (%s)" % value.text)
	_assert_true(lobby.set_slot_gender("player", 0, "female"), "female can be chosen for pikachu")
	await process_frame
	_assert_true(not random_check.button_pressed and not picker.disabled and picker.selected == 1, "choosing female enables the picker on Female")
	var title: Label = lobby.find_child("SlotTitleLabel", true, false) as Label
	_assert_true(title != null and title.text.ends_with("♀"), "slot title shows the chosen mark (%s)" % (title.text if title != null else "-"))
	var payload: Array = lobby.call("_specs_payload", "player")
	_assert_true(payload.size() == 2 and String((payload[0] as Dictionary).get("gender", "")) == "female" and String((payload[1] as Dictionary).get("gender", "")) == "random", "spec payload carries the choice and the random default")
	var second: Button = lobby.find_child("PlayerSlot2", true, false) as Button
	if second != null:
		second.pressed.emit()
	await process_frame
	_assert_true(random_check.disabled and picker.disabled and value.text == "Female only", "nidoran (f) locks the gender controls (%s)" % value.text)
	_assert_true(not lobby.set_slot_gender("player", 1, "male"), "a male nidoran (f) is refused")
	lobby.activate_enemy_team()
	lobby.add_roster_index(pikachu_index)
	await process_frame
	var result: Dictionary = lobby.build_current_definition()
	_assert_true(bool(result.get("ok", false)), "lobby builds with the gender choices (%s)" % String(result.get("error", "")))
	if bool(result.get("ok", false)):
		var definition: SkirmishDefinitionResource = result["definition"]
		_assert_true(definition.player_team[0].gender == GenderRules.FEMALE and definition.player_team[1].gender == GenderRules.FEMALE, "built player team keeps female pikachu and nidoran")
		_assert_true(definition.enemy_team[0].gender != GenderRules.UNKNOWN, "random enemy pikachu resolves a gender")
	lobby.queue_free()
	await process_frame


func _check_battle() -> void:
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch(CODE)
	_assert_true(ok, "gendered 3v3 launches")
	if not ok:
		return
	var level: TacticsLevel = driver.level
	var frames: int = 0
	while not level._scheduler_started and frames < 1800:
		await process_frame
		frames += 1
	var player_pawns: Array = level.player.get_children()
	var enemy_pawns: Array = level.opponent.get_children()
	var pikachu_f: TacticsPawn = null
	var pikachu_m: TacticsPawn = null
	var unfezant_f: TacticsPawn = null
	var magnemite: TacticsPawn = null
	for pawn in player_pawns:
		var slug: String = String(pawn.stats.pokemon_instance.species.species_id)
		if slug == "0025_pikachu":
			pikachu_f = pawn
		elif slug == "0521_unfezant":
			unfezant_f = pawn
	for pawn in enemy_pawns:
		var slug: String = String(pawn.stats.pokemon_instance.species.species_id)
		if slug == "0025_pikachu":
			pikachu_m = pawn
		elif slug == "0081_magnemite":
			magnemite = pawn
	_assert_true(pikachu_f != null and pikachu_m != null and unfezant_f != null and magnemite != null, "all probe units spawned")
	if pikachu_f == null or pikachu_m == null or unfezant_f == null or magnemite == null:
		return
	_assert_true(pikachu_f.stats.gender == GenderRules.FEMALE and pikachu_m.stats.gender == GenderRules.MALE and magnemite.stats.gender == GenderRules.GENDERLESS, "battle stats carry the chosen genders")
	var f_sprite: Sprite3D = _sprite_of(pikachu_f)
	var m_sprite: Sprite3D = _sprite_of(pikachu_m)
	var u_sprite: Sprite3D = _sprite_of(unfezant_f)
	_assert_true(f_sprite != null and f_sprite.texture != null and f_sprite.texture.resource_path.contains("0025_pikachu_female/"), "female pikachu draws the female sprite set (%s)" % (f_sprite.texture.resource_path if f_sprite != null and f_sprite.texture != null else "-"))
	_assert_true(m_sprite != null and m_sprite.texture != null and m_sprite.texture.resource_path.contains("0025_pikachu/"), "male pikachu draws the base sprite set")
	_assert_true(u_sprite != null and u_sprite.texture != null and u_sprite.texture.resource_path.contains("0521_unfezant_female/"), "female unfezant draws the female sprite set")
	_assert_true(PortraitLibrary.slug_for_stats(unfezant_f.stats) == "0521_unfezant_female", "female unfezant portraits come from the female folder (%s)" % PortraitLibrary.slug_for_stats(unfezant_f.stats))
	_assert_true(PortraitLibrary.slug_for_stats(pikachu_f.stats) == "0025_pikachu", "female pikachu keeps the shared portrait when no female portrait exists (%s)" % PortraitLibrary.slug_for_stats(pikachu_f.stats))
	var active_name: Label = level.hud.get_node("HudRoot/ActivePanel").find_child("ActiveName", true, false) as Label
	_assert_true(active_name != null and (active_name.text.contains("♀") or active_name.text.contains("♂") or level.scheduler.get_active_unit().pawn == magnemite), "active panel shows the gender mark (%s)" % (active_name.text if active_name != null else "-"))


func _same(values: Array[int], expected: Array) -> bool:
	if values.size() != expected.size():
		return false
	for i in range(values.size()):
		if values[i] != int(expected[i]):
			return false
	return true


func _sprite_of(pawn: TacticsPawn) -> Sprite3D:
	for child in pawn.get_children():
		if child is Sprite3D:
			return child
	return null
