extends Node
## 효과음·배경음(자동 로드 'Sound'). 음원은 tools/make_sounds.py 로 직접 합성한 CC0 파일.
## 버스: Master ← Music, SFX. 음량은 0~100% 로 settings.cfg 에 저장(main 이 관리).

const SFX := ["click", "place", "hammer", "build_done", "upgrade", "bow", "hit", "knight_down", "castle_hit", "raid_start", "victory", "defeat"]
const MUSIC := {village = "res://assets/audio/music/village.ogg", battle = "res://assets/audio/music/battle.ogg"}
const POLY := 8
## 같은 소리를 너무 자주 겹쳐 내지 않도록 최소 간격(초)
const MIN_GAP := {bow = 0.06, hit = 0.05, hammer = 0.12, castle_hit = 0.15, click = 0.03}

var music_volume := 0.7
var sfx_volume := 0.8
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_name := ""
var _last_play: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for n in SFX:
		var path := "res://assets/audio/sfx/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	for i in POLY:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	apply_volumes()


func _ensure_bus(bus: String) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus)
	AudioServer.set_bus_send(i, "Master")


func apply_volumes() -> void:
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)


func _set_bus_volume(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_play.get(name, -10.0)) < float(MIN_GAP.get(name, 0.0)):
		return
	_last_play[name] = now
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_music(name: String) -> void:
	if name == _music_name:
		return
	_music_name = name
	if not MUSIC.has(name):
		_music.stop()
		return
	var st = load(MUSIC[name])
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	_music.stream = st
	_music.volume_db = -4.0
	_music.play()


## 앱이 배경으로 가면 소리를 내지 않는다
func set_background(on: bool) -> void:
	AudioServer.set_bus_mute(0, on)
