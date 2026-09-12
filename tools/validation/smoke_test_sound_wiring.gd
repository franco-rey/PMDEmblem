extends SmokeCase

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const PRESENTATION_MANIFEST: String = "res://data/models/visuals/generated/action_presentation_manifest.json"


func _run() -> void:
	_assert_true(SoundLibrary.available() and SoundLibrary.count() >= 700, "sound manifest lists the imported files (%d)" % SoundLibrary.count())
	_assert_true(AudioServer.get_bus_index("SFX") >= 0 and AudioServer.get_bus_index("Music") >= 0, "SFX and Music buses exist in the default bus layout")
	var missing_presentation: Array[String] = []
	var names: Dictionary = {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PRESENTATION_MANIFEST))
	if parsed is Dictionary:
		_collect_sounds((parsed as Dictionary).get("entries", {}), names)
	for sound_name in names:
		if sound_name != "-" and not SoundLibrary.has(sound_name):
			missing_presentation.append(sound_name)
	_assert_true(names.size() >= 300 and missing_presentation.is_empty(), "every presentation manifest sound resolves (%d names, missing %s)" % [names.size(), str(missing_presentation.slice(0, 5))])
	var missing_cues: Array[String] = []
	for cue_id in SoundCues.all_ids():
		if not SoundLibrary.has(SoundCues.resolve(cue_id)):
			missing_cues.append(cue_id)
	_assert_true(SoundCues.all_ids().size() >= 30 and missing_cues.is_empty(), "every cue in the cue table resolves (missing %s)" % str(missing_cues))
	var stream: AudioStream = SoundLibrary.stream_for("Menu/Confirm")
	_assert_true(stream != null and stream is AudioStreamOggVorbis and stream.get_length() > 0.0, "an OGG resolves through the imported audio library, so exported builds keep their sound")
	GameSettings.load_settings()
	var saved_master: float = GameSettings.master_volume
	var saved_sfx: float = GameSettings.sfx_volume
	var saved_music: float = GameSettings.music_volume
	GameSettings.sfx_volume = 0.5
	GameSettings.apply_audio()
	var sfx_index: int = AudioServer.get_bus_index("SFX")
	_assert_true(is_equal_approx(AudioServer.get_bus_volume_db(sfx_index), linear_to_db(0.5)) and not AudioServer.is_bus_mute(sfx_index), "effects volume reaches the SFX bus")
	GameSettings.music_volume = 0.0
	GameSettings.apply_audio()
	_assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "a zero volume mutes the bus")
	GameSettings.master_volume = 0.7
	GameSettings.sfx_volume = 0.35
	GameSettings.music_volume = 0.25
	GameSettings.save_settings()
	GameSettings.master_volume = 1.0
	GameSettings.sfx_volume = 1.0
	GameSettings.music_volume = 1.0
	GameSettings.load_settings()
	_assert_true(is_equal_approx(GameSettings.master_volume, 0.7) and is_equal_approx(GameSettings.sfx_volume, 0.35) and is_equal_approx(GameSettings.music_volume, 0.25), "volumes round trip through the settings file")
	GameSettings.master_volume = saved_master
	GameSettings.sfx_volume = saved_sfx
	GameSettings.music_volume = saved_music
	GameSettings.save_settings()
	GameSettings.apply_audio()
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=5 mode=pvp p=0006_charizard@50:flamethrower,swords_dance,earthquake:blaze e=0009_blastoise@50:hydro_pump,protect:torrent|0001_bulbasaur@50:tackle:overgrow")
	_assert_true(ok, "battle launches for the sound checks")
	if not ok:
		_finish("sound_wiring")
		return
	var level: TacticsLevel = driver.level
	var main: Node = driver.main
	_assert_true(SoundPlayer.shared != null and is_instance_valid(SoundPlayer.shared), "main adds the shared sound player")
	_assert_true(level.sound_cues != null and level.sound_cues.level == level, "the level owns a battle sound cue node")
	OS.delay_msec(60)
	var before: int = SoundPlayer.shared.play_count
	_assert_true(SoundPlayer.cue("ui.confirm") and SoundPlayer.shared.play_count == before + 1, "a cue plays through the pool in headless mode")
	var hook: UiSoundHook = get_root().find_child("UiSoundHook", true, false) as UiSoundHook
	_assert_true(hook != null, "main adds the UI sound hook")
	var button := Button.new()
	button.name = "CancelButton"
	get_root().add_child(button)
	await process_frame
	before = SoundPlayer.shared.play_count
	button.pressed.emit()
	_assert_true(SoundPlayer.shared.play_count == before + 1 and SoundPlayer.shared.last_played == SoundCues.resolve("ui.cancel"), "a button named Cancel plays the cancel cue when pressed")
	button.queue_free()
	var slider := HSlider.new()
	get_root().add_child(slider)
	await process_frame
	before = SoundPlayer.shared.play_count
	slider.value = 0.5
	_assert_true(SoundPlayer.shared.play_count == before, "moving a slider is silent")
	slider.queue_free()
	_assert_true(not SoundLibrary.has_cry("0006_charizard") and not SoundPlayer.cry("0006_charizard"), "cries stay silent without imported cry files")
	var lobby: Node = main.get_node_or_null("UI/SkirmishLobby")
	var roster_buttons: Array = lobby.find_children("Roster_*", "Button", true, false) if lobby != null else []
	_assert_true(not roster_buttons.is_empty() and (roster_buttons[0] as Node).is_in_group(UiSoundHook.OPT_OUT_GROUP), "roster portraits opt out of the generic button sounds")
	var frames: int = 0
	while not level._scheduler_started and frames < 300:
		await physics_frame
		frames += 1
	var charizard: TacticsPawn = level.notation.pawn_for_id("P1")
	var blastoise: TacticsPawn = level.notation.pawn_for_id("E1")
	var options_panel := GraphicsSettingsPanel.new()
	get_root().add_child(options_panel)
	await process_frame
	_assert_true(options_panel.master_slider != null and options_panel.sfx_slider != null and options_panel.music_slider != null, "options panel carries the three volume sliders")
	options_panel.queue_free()
	level.arena.reset_all_tile_markers()
	level.arena.process_surrounding_tiles(charizard.get_tile(), charizard.stats.movement, level.player.get_children())
	level.arena.mark_reachable_tiles(charizard.get_tile(), charizard.stats.movement)
	var step_tile: TacticsTile = null
	for tile in Targeting.arena_tile_keys(level).values():
		if tile is TacticsTile and (tile as TacticsTile).reachable and tile != charizard.get_tile():
			step_tile = tile
			break
	before = SoundPlayer.shared.play_count
	if step_tile != null:
		await driver._move(charizard, level.notation.tile_label(Targeting._tile_key(step_tile)))
	_assert_true(step_tile != null and SoundPlayer.shared.play_count > before and SoundPlayer.shared.last_played == SoundCues.resolve("battle.step"), "walking plays a footstep per tile reached")
	var log_before: int = level.battle_log.events.size()
	await driver._attack(charizard, 1, charizard)
	var setup_sounds: int = _count_since(level, log_before, "sound_played")
	_assert_true(setup_sounds >= 1, "a stat move plays its stat and move sounds through the runner (%d)" % setup_sounds)
	var samples: Array[Dictionary] = [
		{"kind": "damage_dealt", "attacker": charizard, "defender": blastoise, "move_id": "flamethrower", "amount": 40, "multiplier": 2.0, "stab": true, "critical": false},
		{"kind": "miss", "attacker": charizard, "defender": blastoise, "move_id": "flamethrower"},
		{"kind": "unit_fainted", "unit": blastoise},
		{"kind": "status_applied", "unit": blastoise, "status_id": "paralyze", "move_id": "thunder_wave"},
		{"kind": "weather_started", "condition_id": "rain", "rounds": 5, "move_id": "rain_dance"},
		{"kind": "stat_stage_changed", "unit": charizard, "move_id": "swords_dance", "source_event": "self", "stat": "attack", "before": 0, "after": 2, "delta": 2},
		{"kind": "healed", "unit": charizard, "amount": 20, "before": 100},
	]
	var expected: Array[String] = ["event:damage_dealt", "event:miss", "event:unit_fainted", "event:status_applied", "event:weather_started", "event:stat_stage_changed", "event:healed"]
	for i in range(samples.size()):
		OS.delay_msec(50)
		log_before = level.battle_log.events.size()
		level.battle_log.append(samples[i])
		_assert_true(_count_since_label(level, log_before, expected[i]) == 1, "%s plays its cue through the runner" % expected[i])
	_assert_true(SoundPlayer.shared.last_played == SoundCues.resolve("battle.heal"), "the heal cue was the last sound played")
	_assert_true(_count_since(level, 0, "sound_skipped") == 0, "no cue was skipped for a missing file")
	_finish("sound_wiring")


func _collect_sounds(node: Variant, names: Dictionary) -> void:
	if node is Dictionary:
		for key in node:
			if String(key) == "sound" and node[key] is String and not String(node[key]).is_empty():
				names[String(node[key])] = true
			else:
				_collect_sounds(node[key], names)
	elif node is Array:
		for item in node:
			_collect_sounds(item, names)


func _count_since(level: TacticsLevel, start: int, kind: String) -> int:
	var count: int = 0
	for i in range(start, level.battle_log.events.size()):
		if String((level.battle_log.events[i] as Dictionary).get("kind", "")) == kind:
			count += 1
	return count


func _count_since_label(level: TacticsLevel, start: int, label: String) -> int:
	var count: int = 0
	for i in range(start, level.battle_log.events.size()):
		var event: Dictionary = level.battle_log.events[i]
		if String(event.get("kind", "")) == "sound_played" and String(event.get("label", "")) == label:
			count += 1
	return count
