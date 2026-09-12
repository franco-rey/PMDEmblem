extends SmokeCase

const DRIVER := preload("res://tools/debug/notation_driver.gd")


func _run() -> void:
	var music_count: int = 0
	for key in SoundLibrary.manifest().get("sounds", {}):
		if String(key).begins_with("Music/"):
			music_count += 1
	_assert_true(music_count >= 70, "the sound manifest lists the imported music (%d tracks)" % music_count)
	var missing: Array[String] = []
	for scene in ["menu", "lobby"]:
		if not SoundLibrary.has(MusicPlayer.track_for(scene)):
			missing.append(scene)
	for track in MusicPlayer.table().get("battle", []):
		if not SoundLibrary.has(String(track)):
			missing.append(String(track))
	_assert_true(missing.is_empty() and (MusicPlayer.table().get("battle", []) as Array).size() >= 20, "every music cue resolves to an imported track (missing %s)" % str(missing))
	var pick_a: String = MusicPlayer.battle_track_for("chessboard", 7)
	var pick_b: String = MusicPlayer.battle_track_for("chessboard", 7)
	var pick_c: String = MusicPlayer.battle_track_for("chessboard", 8)
	_assert_true(pick_a == pick_b and pick_a != pick_c and (MusicPlayer.table().get("battle", []) as Array).has(pick_a), "the battle track is picked by seed and stable for the same seed")
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=9 mode=pvp p=0025_pikachu@50:thunderbolt,quick_attack:static e=0004_charmander@50:ember:blaze")
	_assert_true(ok, "battle launches for the music checks")
	if not ok:
		_finish("music")
		return
	_assert_true(MusicPlayer.shared != null and is_instance_valid(MusicPlayer.shared), "main adds the music player")
	var expected: String = MusicPlayer.battle_track_for("", 9)
	_assert_true(MusicPlayer.shared.current_track.begins_with("Music/") and MusicPlayer.shared._active.playing, "launching a battle starts its dungeon theme (%s)" % MusicPlayer.shared.current_track)
	_assert_true(MusicPlayer.shared._active.stream is AudioStreamOggVorbis and (MusicPlayer.shared._active.stream as AudioStreamOggVorbis).loop, "the theme loops")
	var before: String = MusicPlayer.shared.current_track
	MusicPlayer.play_scene("lobby", 0.1)
	await create_timer(0.3).timeout
	_assert_true(MusicPlayer.shared.current_track == MusicPlayer.track_for("lobby") and MusicPlayer.shared.current_track != before and MusicPlayer.shared._active.playing and not MusicPlayer.shared._idle.playing, "switching scenes crossfades to the lobby theme and stops the old voice")
	MusicPlayer.duck(true)
	await create_timer(0.6).timeout
	_assert_true(MusicPlayer.shared.ducked and MusicPlayer.shared._active.volume_db < -8.0, "pausing ducks the music")
	MusicPlayer.duck(false)
	await create_timer(0.6).timeout
	_assert_true(MusicPlayer.shared._active.volume_db > -1.0, "resuming restores the level")
	MusicPlayer.stop(0.1)
	await create_timer(0.3).timeout
	_assert_true(MusicPlayer.shared.current_track.is_empty() and not MusicPlayer.shared._active.playing, "stopping fades out and clears the track")
	_finish("music")
