class_name SoundPlayer
extends Node

const BUS_NAME: String = "SFX"
const POOL_SIZE: int = 12
const DEDUPE_MS: int = 45

static var shared: SoundPlayer = null

var play_count: int = 0
var last_played: String = ""
var _pool: Array[AudioStreamPlayer] = []
var _last_times: Dictionary = {}


func _ready() -> void:
	name = "SoundPlayer"
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		if AudioServer.get_bus_index(BUS_NAME) >= 0:
			player.bus = BUS_NAME
		add_child(player)
		_pool.append(player)
	shared = self


func _exit_tree() -> void:
	if shared == self:
		shared = null


static func sound(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> bool:
	if shared == null or not is_instance_valid(shared):
		return false
	return shared.play_name(sound_name, volume_db, pitch)


static func cue(cue_id: String, volume_db: float = 0.0, pitch: float = 1.0) -> bool:
	var sound_name: String = SoundCues.resolve(cue_id)
	if sound_name.is_empty():
		return false
	return sound(sound_name, volume_db, pitch)


static func cry(slug: String, volume_db: float = 0.0) -> bool:
	if not SoundLibrary.has_cry(slug):
		return false
	return sound(SoundLibrary.cry_name(slug), volume_db)


func play_name(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> bool:
	if sound_name.is_empty():
		return false
	var now: int = Time.get_ticks_msec()
	if _last_times.has(sound_name) and now - int(_last_times[sound_name]) < DEDUPE_MS:
		return true
	var stream: AudioStream = SoundLibrary.stream_for(sound_name)
	if stream == null:
		return false
	var player: AudioStreamPlayer = _free_voice()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()
	_last_times[sound_name] = now
	play_count += 1
	last_played = sound_name
	return true


func _free_voice() -> AudioStreamPlayer:
	for player in _pool:
		if not player.playing:
			return player
	var oldest: AudioStreamPlayer = _pool[0]
	for player in _pool:
		if player.get_playback_position() > oldest.get_playback_position():
			oldest = player
	return oldest
