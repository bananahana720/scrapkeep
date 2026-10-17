extends Node

const SpecialCues := preload("res://src/combat/special_cues.gd")

# What the four kill-first specials sound like (INTEGRATION.md section 7 item 5): you hear
# which special is near before you see it.
#   presence  a looping 3D voice on the body while it lives, its own player so it never
#             steals a combat voice; at most MAX_PRESENCE heard at once, nearest first.
#   tell      heard now, from the body's special_tell(moment) emit, the same emit
#             machine_fx draws the tell from (SpecialCues.tell is the one caller).
#   death     heard now, from the body's died emit; the Splitter picks split or clean.
#   spawn     a one-beat answer at the band's next beat, within a frame of it (a file
#             stream cannot ride the engine's sample-exact stinger lane).
# The sounds are the specials.py renders under SpecialCues.SOUND_DIR. A cue whose file is
# not there plays nothing and logs "missing"; the audio gate (PR #41) counts it.

const MAX_PRESENCE := 2
const RANK_GAP := 0.25
const PRESENCE_DB := -6.0
const PRESENCE_REACH := 45.0
const LOG_KEEP := 128

var ctx
var audio
# [process frame, special, moment, sound, state]; state is "now", "beat", "loop",
# "missing" or "skip". For the tests and captures.
var heard: Array = []

var _streams := {}
var _loops := {}
# instance id -> {"enemy": Node3D, "player": AudioStreamPlayer3D, "heard": bool}
var _presences := {}
# [due sample, special, sound]
var _answers: Array = []
var _rank_clock := 0.0


func setup(ctx_ref, audio_ref) -> void:
	ctx = ctx_ref
	audio = audio_ref
	name = "SpecialVoice"
	if ctx.events.has_signal("enemy_spawned"):
		ctx.events.enemy_spawned.connect(_on_spawned)
	ctx.events.stage_entered.connect(func(_stage: int, _retry: bool): clear())
	ctx.events.stage_content_cleared.connect(func(_reason: String): clear())


func clear() -> void:
	for id in _presences.keys():
		_stop_presence(id)
	_answers.clear()


# The stream for a sound id, loaded once; null when the file has not landed.
func stream(id: String) -> AudioStream:
	if not _streams.has(id):
		var path := SpecialCues.sound_path(id)
		_streams[id] = load(path) if path != "" else null
	return _streams[id]


# The sound ids with no file yet.
func missing() -> Array:
	return SpecialCues.all_sounds().filter(func(id: String): return stream(id) == null)


func heard_presences() -> Array:
	return _presences.values().filter(func(p: Dictionary): return p["heard"]).map(func(p: Dictionary): return p["enemy"])


func _note(special: String, moment: String, sound: String, state: String) -> void:
	heard.append([Engine.get_process_frames(), special, moment, sound, state])
	if heard.size() > LOG_KEEP:
		heard.pop_front()


func _on_spawned(enemy: Node3D, _kind: String) -> void:
	var special := SpecialCues.special_of(enemy)
	if special == "":
		return
	var tell := _on_tell.bind(enemy)
	if not enemy.has_signal("special_tell") or enemy.is_connected("special_tell", tell):
		return
	enemy.connect("special_tell", tell)
	if enemy.has_signal("died"):
		enemy.died.connect(_on_died.bind(enemy))
	enemy.tree_exiting.connect(_stop_presence.bind(enemy.get_instance_id()))
	_start_presence(enemy, special)
	_answer(special)


func _on_tell(moment: String, enemy: Node3D) -> void:
	var special := SpecialCues.special_of(enemy)
	_play_now(special, moment, SpecialCues.sound(special, moment), true)


func _on_died(_at: Vector3, _scrap: int, enemy: Node3D) -> void:
	var special := SpecialCues.special_of(enemy)
	_stop_presence(enemy.get_instance_id())
	var moment := SpecialCues.break_moment(enemy)
	_play_now(special, moment, SpecialCues.sound(special, moment), false)


func _play_now(special: String, moment: String, sound: String, danger: bool) -> void:
	if sound == "":
		return
	var s := stream(sound)
	if s == null:
		_note(special, moment, sound, "missing")
		return
	_note(special, moment, sound, "now" if audio.play_file(sound, s, 0.0, danger) else "skip")


func _start_presence(enemy: Node3D, special: String) -> void:
	var sound := SpecialCues.sound(special, SpecialCues.PRESENCE)
	var s := stream(sound)
	if s == null:
		_note(special, SpecialCues.PRESENCE, sound, "missing")
		return
	var player := AudioStreamPlayer3D.new()
	player.name = "PresenceVoice"
	if not _loops.has(sound):
		_loops[sound] = _looped(s)
	player.stream = _loops[sound]
	player.bus = "SFX"
	player.volume_db = PRESENCE_DB
	player.max_distance = PRESENCE_REACH
	enemy.add_child(player)
	player.play()
	_presences[enemy.get_instance_id()] = {"enemy": enemy, "player": player, "heard": true}
	_note(special, SpecialCues.PRESENCE, sound, "loop")
	_rank()


func _stop_presence(id: int) -> void:
	var p: Dictionary = _presences.get(id, {})
	_presences.erase(id)
	if not p.is_empty() and is_instance_valid(p["player"]):
		p["player"].stop()
		p["player"].queue_free()


static func _looped(s: AudioStream) -> AudioStream:
	var out: AudioStream = s.duplicate()
	if out is AudioStreamWAV:
		var wav := out as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(round(wav.get_length() * wav.mix_rate))
	elif "loop" in out:
		out.set("loop", true)
	return out


# Nearest MAX_PRESENCE loops play; the rest pause until they are among the nearest again.
func _rank() -> void:
	if ctx.player == null:
		return
	var ball: Vector3 = ctx.player.ball_position()
	var live := []
	for p in _presences.values():
		p["heard"] = false
		if is_instance_valid(p["enemy"]) and p["enemy"].is_inside_tree():
			live.append(p)
	live.sort_custom(func(a: Dictionary, b: Dictionary):
		return a["enemy"].global_position.distance_squared_to(ball) < b["enemy"].global_position.distance_squared_to(ball))
	for i in live.size():
		live[i]["heard"] = i < MAX_PRESENCE
		live[i]["player"].stream_paused = not live[i]["heard"]


func _answer(special: String) -> void:
	var sound := SpecialCues.sound(special, SpecialCues.SPAWN)
	if stream(sound) == null:
		_note(special, SpecialCues.SPAWN, sound, "missing")
		return
	if not audio.sound_ready or audio.engine == null:
		_note(special, SpecialCues.SPAWN, sound, "skip")
		return
	_answers.append([audio.engine.next_beat(), special, sound])
	_note(special, SpecialCues.SPAWN, sound, "beat")


func _process(delta: float) -> void:
	_rank_clock += delta
	if _rank_clock >= RANK_GAP:
		_rank_clock = 0.0
		_rank()
	if _answers.is_empty() or audio.engine == null:
		return
	var due := _answers.filter(func(a: Array): return audio.engine.clock >= int(a[0]))
	for a in due:
		_answers.erase(a)
		audio.play_file(a[2], stream(a[2]))
