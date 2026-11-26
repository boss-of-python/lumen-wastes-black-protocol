# AudioDirector.gd
# 4-stem adaptive crossfade music + procedural/pooled SFX.
# 100% offline: all stems and SFX are local res:// resources, mixed at runtime.
extends Node

const STEM_COVERT := "stem_covert_ambient"
const STEM_COMBAT := "stem_tactical_combat"
const STEM_BOSS := "stem_mythic_boss"
const STEM_ESCAPE := "stem_escape_crescendo"

const STEM_PATH_FMT: String = "res://assets/audio/%s.wav"

const SFX_POOL_SIZE: int = 24

var _music_bus: int = -1
var _sfx_bus: int = -1
var _stems: Dictionary = {}
var _sfx_pool: Array = []
var _current_stem: String = STEM_COVERT
var _fade_active: bool = false

signal stem_changed(stem_name: String)

func _ready() -> void:
	_music_bus = AudioServer.get_bus_index("Music")
	_sfx_bus = AudioServer.get_bus_index("SFX")
	if _music_bus >= 0:
		AudioServer.set_bus_volume_db(_music_bus, -14.0)
	if _sfx_bus >= 0:
		AudioServer.set_bus_volume_db(_sfx_bus, -6.0)
	_build_stems()
	_build_sfx_pool()

func _build_stems() -> void:
	for stem_name in [STEM_COVERT, STEM_COMBAT, STEM_BOSS, STEM_ESCAPE]:
		var path := STEM_PATH_FMT % stem_name
		var stream := AudioStreamWAV.new()
		if ResourceLoader.exists(path):
			var res := load(path) as AudioStreamWAV
			if res != null:
				stream = res
		_stems[stem_name] = stream

func _build_sfx_pool() -> void:
	_sfx_pool.clear()
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)

func _get_free_sfx() -> AudioStreamPlayer:
	for player in _sfx_pool:
		if not player.is_playing():
			return player
	return _sfx_pool[0]

func switch_stem(stem_name: String, fade_time: float = 1.2) -> void:
	if not _stems.has(stem_name):
		return
	if stem_name == _current_stem and not _fade_active:
		return
	var old_stream := _stems.get(_current_stem, null)
	var new_stream := _stems[stem_name] as AudioStreamWAV
	if new_stream == null:
		return
	_fade_active = true
	if old_stream != null:
		_fade_stream(old_stream, fade_time, -80.0, true)
	_fade_stream(new_stream, fade_time, -14.0, false)
	_current_stem = stem_name
	stem_changed.emit(stem_name)

func _fade_stream(stream: AudioStreamWAV, fade_time: float, target_db: float, is_old: bool) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "Music"
	player.volume_db = 0.0 if not is_old else -14.0
	add_child(player)
	player.play()
	var tween := create_tween()
	var start_db: float = -14.0 if is_old else 0.0
	tween.tween_property(player, "volume_db", target_db, fade_time)
	tween.tween_callback(player.queue_free)

func get_current_stem() -> String:
	return _current_stem

func stop_all_music(fade_time: float = 0.4) -> void:
	for stem_name in _stems:
		var stream := _stems[stem_name] as AudioStreamWAV
		if stream != null:
			_fade_stream(stream, fade_time, -80.0, false)

func play_sfx(sfx_type: String, pitch_variation: float = 0.0) -> void:
	var player := _get_free_sfx()
	if player == null:
		return
	var stream := _synthesize_sfx(sfx_type)
	if stream == null:
		return
	player.stream = stream
	if pitch_variation > 0.0:
		player.pitch_scale = 1.0 + randf() * pitch_variation * 2.0 - pitch_variation
	player.play()

func _synthesize_sfx(sfx_type: String) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	var sr: int = 44100
	var duration: float = 0.12
	var buf := PackedByteArray()
	var len := int(duration * float(sr))
	buf.resize(len * 2)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var freq := 220.0
	var decay := 6.0
	switch sfx_type:
		case "shot":
			freq = 180.0; decay = 14.0
		case "melee":
			freq = 140.0; decay = 10.0
		case "explosion":
			freq = 70.0; decay = 8.0
		case "jump":
			freq = 440.0; decay = 12.0
		case "dash":
			freq = 620.0; decay = 16.0
		case "pickup":
			freq = 880.0; decay = 10.0
		case "radio":
			freq = 320.0; decay = 6.0
		case _:
			freq = 220.0; decay = 6.0
	var phase := 0.0
	for i in len:
		var t := float(i) / float(sr)
		var amp := exp(-decay * t)
		var val: float = 0.0
		if sfx_type == "explosion":
			val = (rng.randf() * 2.0 - 1.0) * amp
		else:
			phase += 2.0 * PI * freq / float(sr)
			val = sin(phase) * amp
		var sample := clampi(int(val * 24000.0), -32768, 32767)
		buf[i * 2] = sample & 0xFF
		buf[i * 2 + 1] = (sample >> 8) & 0xFF
	stream.data = buf
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sr
	stream.loop = false
	return stream

func play_radio_chatter() -> void:
	play_sfx("radio")

func play_hit_stop_sfx() -> void:
	play_sfx("melee", 0.1)
