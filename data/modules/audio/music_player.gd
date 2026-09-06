class_name MusicPlayer
extends Node

const BUS_NAME: String = "Music"
const TABLE_PATH: String = "res://data/models/audio/music_cues.json"
const SILENT_DB: float = -40.0
const DUCK_DB: float = -10.0
const DEFAULT_FADE: float = 1.2

static var shared: MusicPlayer = null
static var _table: Dictionary = {}
static var _table_loaded: bool = false

var current_track: String = ""
var ducked: bool = false
var _active: AudioStreamPlayer = null
var _idle: AudioStreamPlayer = null
var _tweens: Array[Tween] = []


func _ready() -> void:
	name = "MusicPlayer"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_active = _voice("MusicA")
	_idle = _voice("MusicB")
	shared = self


func _exit_tree() -> void:
	if shared == self:
		shared = null


static func table() -> Dictionary:
	if _table_loaded:
		return _table
	_table_loaded = true
	if FileAccess.file_exists(TABLE_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
		if parsed is Dictionary:
			_table = parsed
	return _table


static func track_for(scene: String) -> String:
	return String(table().get(scene, ""))


static func battle_track_for(map_id: String, seed_value: int) -> String:
	var by_map: Dictionary = table().get("battle_by_map", {})
	if by_map.has(map_id):
		return String(by_map[map_id])
	var pool: Array = table().get("battle", [])
	if pool.is_empty():
		return ""
	return String(pool[posmod(seed_value, pool.size())])


static func play_scene(scene: String, fade: float = DEFAULT_FADE) -> bool:
	return play(track_for(scene), fade)


static func play(track: String, fade: float = DEFAULT_FADE) -> bool:
	if shared == null or not is_instance_valid(shared):
		return false
	return shared.play_track(track, fade)


static func stop(fade: float = DEFAULT_FADE) -> void:
	if shared != null and is_instance_valid(shared):
		shared.stop_track(fade)


static func duck(enabled: bool) -> void:
	if shared != null and is_instance_valid(shared):
		shared.set_ducked(enabled)


func play_track(track: String, fade: float = DEFAULT_FADE) -> bool:
	if track.is_empty():
		stop_track(fade)
		return false
	if track == current_track and _active.playing:
		return true
	var stream: AudioStream = SoundLibrary.stream_for(track)
	if stream == null:
		return false
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var outgoing: AudioStreamPlayer = _active
	_active = _idle
	_idle = outgoing
	_active.stream = stream
	_active.volume_db = SILENT_DB
	_active.play()
	current_track = track
	_kill_tweens()
	_fade(_active, _target_db(), fade)
	if outgoing.playing:
		var out_tween: Tween = _fade(outgoing, SILENT_DB, fade)
		out_tween.tween_callback(outgoing.stop)
	return true


func stop_track(fade: float = DEFAULT_FADE) -> void:
	current_track = ""
	_kill_tweens()
	for player in [_active, _idle]:
		if player.playing:
			var tween: Tween = _fade(player, SILENT_DB, fade)
			tween.tween_callback(player.stop)


func set_ducked(enabled: bool) -> void:
	if ducked == enabled:
		return
	ducked = enabled
	if _active.playing:
		_fade(_active, _target_db(), 0.4)


func _target_db() -> float:
	return DUCK_DB if ducked else 0.0


func _fade(player: AudioStreamPlayer, to_db: float, seconds: float) -> Tween:
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", to_db, maxf(seconds, 0.05))
	_tweens.append(tween)
	return tween


func _kill_tweens() -> void:
	for tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()


func _voice(voice_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = voice_name
	if AudioServer.get_bus_index(BUS_NAME) >= 0:
		player.bus = BUS_NAME
	player.volume_db = SILENT_DB
	add_child(player)
	return player
