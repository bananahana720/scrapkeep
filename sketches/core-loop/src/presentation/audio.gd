extends Node

const EventKinds := preload("res://src/core/event_kinds.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Synth := preload("res://src/presentation/synth.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")

# The audio director. It hears every GameEvents fact, picks the sound its event_kinds
# row names and decides one thing: now or on the beat.
#   Now: anything the player caused (a jump, a hit, a pickup, a death, the gate you
#   rolled through). Feedback that waits for a beat feels laggy.
#   On the beat: announcements the world or the flow makes (a stage, the gates, the
#   klaxon, a milestone, the stage clear). They go through the band so they land in
#   time, and flow stingers queue in one lane so they never talk over each other.
# It also owns the mixer: Music, SFX and UI buses, a limiter, ducking and volume keys.

const BUSES := {"Music": -3.0, "SFX": 0.0, "UI": -4.0}
const GEN_BUFFER := 0.1
const POLYPHONY := 32
# Simultaneous voices per cue, and the shortest gap between two starts. A burst of
# pickups or a held trigger stays crisp instead of turning into mush.
const VOICE_LIMIT := {"weapon_zap": 4, "scrap_tick": 4, "hit_thwack": 3, "kill_pop": 3, "enemy_arrive": 2, "beacon_hum": 1,
	"hop": 2, "land_thud": 2, "hurt": 2}
const MIN_GAP_MS := {"weapon_zap": 45, "scrap_tick": 30, "enemy_arrive": 200, "hit_thwack": 30, "land_thud": 80, "kill_pop": 35,
	"hurt": 90, "hop": 40}
const PRIORITY_DB := [-6.0, -3.0, 0.0, 0.0]
# Pickups inside this window climb the pentatonic ladder; a gap resets to home.
const COMBO_WINDOW_MS := 700
const KILL_COMBO_WINDOW_MS := 1500
const MENU_STATES := ["title", "class_select", "summary", "dead"]
# Weapon voices per class, so each class sounds like itself (identity, principle 5).
const WEAPON_PITCH := {"arc_caster": -3.0, "rapid_laser": 4.0}
const VOLUME_STEP := 0.1

var ctx
var engine: MusicEngine
var sound_ready := false
# Every cue decided: [kind, sound, "now" | "beat" | "music" | "skip", start_sample, pitch].
var cue_log: Array = []
var volumes := {"Music": 0.8, "SFX": 1.0, "UI": 1.0}
var muted := false
# False on the dummy driver (headless tests, or a machine with no sound device): no
# players start, and the band runs on a real-time clock so every cue decision and beat
# still happens. Quitting right after freeing a playing player leaks its playback.
var live_output := true

var _music_player: AudioStreamPlayer
var _stinger_player: AudioStreamPlayer
var _music_pb: AudioStreamGeneratorPlayback
var _stinger_pb: AudioStreamGeneratorPlayback
var _sfx: AudioStreamPlaybackPolyphonic
var _ui: AudioStreamPlaybackPolyphonic
var _sfx_player: AudioStreamPlayer
var _ui_player: AudioStreamPlayer
var _voices := {}
var _last_start := {}
var _scrap_combo := 0
var _scrap_last := -100000
var _kill_combo := 0
var _kill_last := -100000
var _beacon_rung := -1
var _gates_announced := false
var _flow_queue: Array = []
var _overlay: Label
var _overlay_until := 0
var _virtual_usec := 0

static var _bake_task := -1
static var _baked := false


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Audio"
	# Music keeps playing, softer, while the tree is paused, and the keys still work.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	live_output = AudioServer.get_driver_name() != "Dummy"
	engine = MusicEngine.new()
	_music_player = _generator_player("Music", "MusicStream")
	_stinger_player = _generator_player("SFX", "StingerStream")
	_sfx_player = _poly_player("SFX", "SfxVoices")
	_ui_player = _poly_player("UI", "UiVoices")
	_make_overlay()
	_connect_all(ctx.events)
	_start_bake()


# --- Baking -------------------------------------------------------------------------
# Baking the bank and the band's notes takes about two seconds of CPU, so it runs on
# a worker at startup and the title never waits for it. Nothing touches the caches
# on the main thread until the bake is done; cues before then are skipped.

static func _sound_ids() -> Array:
	var ids := []
	for kind in EventKinds.ROWS:
		var id: String = EventKinds.ROWS[kind]["sound"]
		if not id in ids:
			ids.append(id)
	return ids


static func _bake_everything(ids: Array) -> void:
	SfxBank.bake_all(ids)
	MusicEngine.prepare()


func _start_bake() -> void:
	if _baked or _bake_task >= 0:
		return
	_bake_task = WorkerThreadPool.add_task(_bake_everything.bind(_sound_ids()), false, "presentation audio bake")


static func _poll_bake() -> bool:
	if _baked:
		return true
	if _bake_task >= 0 and WorkerThreadPool.is_task_completed(_bake_task):
		WorkerThreadPool.wait_for_task_completion(_bake_task)
		_bake_task = -1
		_baked = true
	return _baked


# Blocks until the bank is baked; the tests call it, the game never needs to.
func bake_now() -> void:
	if _bake_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_bake_task)
		_bake_task = -1
		_baked = true
	elif not _baked:
		_bake_everything(_sound_ids())
		_baked = true
	_on_ready()


func _exit_tree() -> void:
	if _bake_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_bake_task)
		_bake_task = -1
		_baked = true
	# Stop every player and drop the playbacks, or the polyphonic ones outlive the tree.
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
	_sfx = null
	_ui = null
	_music_pb = null
	_stinger_pb = null


func _on_ready() -> void:
	if sound_ready:
		return
	sound_ready = true
	_virtual_usec = Time.get_ticks_usec()
	if not live_output:
		return
	_sfx_player.play()
	_ui_player.play()
	_sfx = _sfx_player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	_ui = _ui_player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	_music_player.play()
	_stinger_player.play()
	_music_pb = _music_player.get_stream_playback()
	_stinger_pb = _stinger_player.get_stream_playback()
	_pump()


# --- Buses and players --------------------------------------------------------------

func _make_buses() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) >= 0:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, "Master")
		AudioServer.set_bus_volume_db(index, BUSES[bus])
		if bus == "SFX":
			var limiter := AudioEffectHardLimiter.new()
			limiter.ceiling_db = -1.0
			AudioServer.add_bus_effect(index, limiter)
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -0.5
		AudioServer.add_bus_effect(master, limiter)
	_apply_volumes()


func _generator_player(bus: String, node_name: String) -> AudioStreamPlayer:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = Harmony.RATE
	generator.buffer_length = GEN_BUFFER
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.stream = generator
	player.bus = bus
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


func _poly_player(bus: String, node_name: String) -> AudioStreamPlayer:
	var poly := AudioStreamPolyphonic.new()
	poly.polyphony = POLYPHONY
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.stream = poly
	player.bus = bus
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


func _process(_delta: float) -> void:
	if not sound_ready:
		if _poll_bake():
			_on_ready()
		else:
			return
	engine.pause_gain = 0.45 if get_tree().paused else 1.0
	_flush_flow()
	_pump()
	if _overlay != null and _overlay.visible and Time.get_ticks_msec() > _overlay_until:
		_overlay.visible = false


# Renders exactly as many frames as both streams can take, so the band and the
# stinger lane stay sample-locked.
func _pump() -> void:
	if not live_output:
		# No device: advance the band by the real time that passed, as a speaker would.
		var now := Time.get_ticks_usec()
		var owed := int((now - _virtual_usec) * Harmony.RATE / 1000000.0)
		if owed > 0:
			_virtual_usec += int(owed * 1000000.0 / Harmony.RATE)
			engine.render(mini(owed, 8192))
		return
	if _music_pb == null or _stinger_pb == null:
		return
	var frames := mini(_music_pb.get_frames_available(), _stinger_pb.get_frames_available())
	frames = mini(frames, 8192)
	if frames <= 0:
		return
	engine.render(frames)
	_music_pb.push_buffer(engine.out_music)
	_stinger_pb.push_buffer(engine.out_stinger)


# --- Playing a cue ------------------------------------------------------------------

# Plays a cue now. Returns false if it was gated by the voice limit or the gap.
func play(kind: String, db := 0.0, pitch := 1.0, bus := "SFX") -> bool:
	var sound: String = EventKinds.row(kind).get("sound", "")
	if not sound_ready or sound == "":
		cue_log.append([kind, sound, "skip", -1, pitch])
		return false
	var now := Time.get_ticks_msec()
	if now - int(_last_start.get(sound, -100000)) < int(MIN_GAP_MS.get(sound, 0)):
		cue_log.append([kind, sound, "skip", -1, pitch])
		return false
	_last_start[sound] = now
	var playback := _ui if bus == "UI" else _sfx
	if playback != null:
		var live: Array = _voices.get(sound, [])
		live = live.filter(func(id: int): return playback.is_stream_playing(id))
		if live.size() >= int(VOICE_LIMIT.get(sound, 3)):
			playback.stop_stream(live.pop_front())
		var volume: float = SfxBank.trim_db(sound) + PRIORITY_DB[EventKinds.priority(kind)] + db
		var id := playback.play_stream(SfxBank.stream(sound), 0.0, volume, pitch, AudioServer.PLAYBACK_TYPE_DEFAULT, bus)
		if id != AudioStreamPlaybackPolyphonic.INVALID_ID:
			live.append(id)
		_voices[sound] = live
	cue_log.append([kind, sound, "now", engine.clock, pitch])
	if EventKinds.priority(kind) >= 2:
		engine.duck(0.55, 0.35)
	return true


# Plays a cue on the next beat through the band. lane queues it behind flow stingers.
func on_beat(kind: String, db := 0.0, lane := false, repeats := 1) -> int:
	var sound: String = EventKinds.row(kind).get("sound", "")
	if not sound_ready or sound == "":
		cue_log.append([kind, sound, "skip", -1, 1.0])
		return -1
	var start := engine.schedule_stinger(sound, db, lane, repeats)
	var beats: int = SfxBank.STINGER_BEATS.get(sound, 1)
	engine.duck(0.6, float(start - engine.clock + beats * Harmony.BEAT) / Harmony.RATE)
	cue_log.append([kind, sound, "beat", start, 1.0])
	return start


# --- Facts --------------------------------------------------------------------------

func _connect_all(events) -> void:
	events.run_started.connect(func(_class_id: String): _flow_queue.append(["run"]))
	events.flow_changed.connect(_on_flow_changed)
	events.stage_entered.connect(_on_stage_entered)
	events.stage_cleared.connect(func(stage: int): _flow_queue.append(["clear", stage]))
	events.run_ended.connect(func(won: bool): _flow_queue.append(["end", won]))
	events.beacon_charge_changed.connect(_on_beacon)
	events.scrap_collected.connect(_on_scrap)
	events.part_gained.connect(func(_part: String, _source: String): play("part_gained"))
	events.player_hit.connect(func(amount: float, _source: String): play("player_hit", clampf(amount / 10.0, 0.0, 1.0) * 4.0 - 4.0))
	events.player_died.connect(_on_died)
	events.enemy_killed.connect(_on_kill)
	events.milestone_won.connect(func(_event_id: String): _flow_queue.append(["milestone"]))
	events.jumped.connect(func(air: bool): play("jumped", 0.0, Harmony.ratio(7.0) if air else 1.0))
	events.boosted.connect(func(_direction: Vector3): play("boosted"))
	events.dashed.connect(func(_direction: Vector3): play("dashed"))
	events.landed.connect(func(impact: float): play("landed", lerpf(-12.0, 2.0, clampf(impact / 30.0, 0.0, 1.0)), lerpf(1.1, 0.85, clampf(impact / 30.0, 0.0, 1.0))))
	events.slammed.connect(_on_slammed)
	events.grapple_fired.connect(func(_anchor: Vector3): play("grapple_fired"))
	events.grapple_released.connect(func(): play("grapple_released"))
	events.mounted.connect(func(_at: Vector3, banked: float): play("mounted", 0.0, Harmony.ratio(minf(banked / 4.0, 7.0))))
	events.dismounted.connect(_on_dismounted)
	events.enemy_spawned.connect(func(_enemy: Node3D, kind: String): play("enemy_spawned", 3.0 if kind == "miniboss" else 0.0, Harmony.ratio(-5.0) if kind == "miniboss" else 1.0))
	events.enemy_struck.connect(_on_struck)
	events.shot_fired.connect(_on_shot)
	events.special_used.connect(func(_special: String, _at: Vector3): play("special_used"))
	events.reward_offered.connect(_on_offered)
	events.reward_chosen.connect(func(_part: String): play("reward_chosen"))
	events.event_announced.connect(func(_event_id: String, _seconds: float): on_beat("event_announced"))
	events.event_started.connect(func(_event_id: String): on_beat("event_started"))
	events.event_ended.connect(func(_event_id: String, outcome: String): on_beat("event_ended", -4.0 if outcome == "lost" else 0.0))
	events.launched.connect(func(_velocity: Vector3): play("launched"))
	events.pressure_changed.connect(_on_pressure)


func _on_flow_changed(state: String) -> void:
	if state in MENU_STATES:
		play("flow_changed", 0.0, 1.0, "UI")
	if state == "title" or state == "class_select":
		_flow_queue.append(["idle"])


func _on_stage_entered(stage: int, retry: bool) -> void:
	_beacon_rung = -1
	_gates_announced = false
	_scrap_combo = 0
	_flow_queue.append(["stage", stage, retry])


# The beacon climbs the reward ladder as it charges and lands on home, two octaves up.
func _on_beacon(fraction: float) -> void:
	var rung := 10 if fraction >= 1.0 else int(fraction * 8.0)
	if rung <= _beacon_rung:
		return
	_beacon_rung = rung
	play("beacon_charge_changed", 2.0 if rung == 10 else 0.0, Harmony.ratio(Harmony.pentatonic_step(rung)))


func _on_scrap(amount: int, _at: Vector3, _total: int) -> void:
	var now := Time.get_ticks_msec()
	_scrap_combo = mini(_scrap_combo + 1, 9) if now - _scrap_last < COMBO_WINDOW_MS else 0
	_scrap_last = now
	play("scrap_collected", minf(amount, 5.0) * 0.6, Harmony.ratio(Harmony.pentatonic_step(_scrap_combo)))


func _on_kill(_kind: String, _at: Vector3, _value: int) -> void:
	var now := Time.get_ticks_msec()
	_kill_combo = mini(_kill_combo + 1, 7) if now - _kill_last < KILL_COMBO_WINDOW_MS else 0
	_kill_last = now
	play("enemy_killed", 0.0, Harmony.ratio(Harmony.pentatonic_step(_kill_combo)))


func _on_died() -> void:
	play("player_died")
	_flow_queue.append(["dead"])


func _on_slammed(_at: Vector3, strength: float, _flatness: float) -> void:
	if strength < 0.05:
		return
	play("slammed", lerpf(-8.0, 0.0, clampf(strength, 0.0, 1.0)), lerpf(1.1, 0.9, clampf(strength - 0.5, 0.0, 1.0)))


func _on_dismounted(velocity: Vector3) -> void:
	# E drops off quietly; the slingshot sings higher the faster it throws you.
	if velocity.length() < 1.0:
		play("dismounted", -8.0, 0.75)
		return
	play("dismounted", 0.0, Harmony.ratio(clampf(velocity.length() / 5.0, 0.0, 7.0)))


func _on_struck(_enemy: Node3D, kind: String, force: float) -> void:
	var contact := kind in ["stomp", "ram", "slam"]
	var db := lerpf(-6.0, 1.0, clampf(force / 30.0, 0.0, 1.0)) if contact else -5.0
	play("enemy_struck", db, 1.0 if contact else 1.15)


func _on_shot(weapon_id: String, _from: Vector3, _to: Vector3) -> void:
	var cents := randf_range(-25.0, 25.0) / 100.0
	play("shot_fired", 0.0, Harmony.ratio(WEAPON_PITCH.get(weapon_id, 0.0) + cents))


func _on_offered(_offers: Array) -> void:
	# The gates re-announce when they move; the fanfare plays once per opening.
	if _gates_announced:
		return
	_gates_announced = true
	_flow_queue.append(["gates"])


func _on_pressure(pressure: float) -> void:
	cue_log.append(["pressure_changed", "music_pressure", "music", engine.clock, 1.0])
	engine.set_pressure(pressure)


# Flow facts arrive in bursts inside one frame (a clear and the next stage; a run and
# stage 1; the last clear and the run end). They are read together once per frame so
# each burst becomes one musical phrase instead of a pile of stingers.
func _flush_flow() -> void:
	if _flow_queue.is_empty():
		return
	var burst := _flow_queue
	_flow_queue = []
	var kinds := burst.map(func(item: Array): return item[0])
	for item in burst:
		match item[0]:
			"run":
				engine.cancel_pending()
				var start := on_beat("run_started", 0.0, true)
				if start >= 0:
					engine.schedule_restart(start, MusicEngine.PLAY)
			"stage":
				var stage: int = item[1]
				var retry: bool = item[2]
				if not retry and "run" in kinds:
					continue
				if retry:
					engine.cancel_pending()
				var start := on_beat("stage_entered", 0.0, true, clampi(stage, 1, 4))
				if start >= 0:
					engine.schedule_restart(start, MusicEngine.PLAY)
			"clear":
				if "end" in kinds:
					continue
				var start := on_beat("stage_cleared", 0.0, true)
				if start >= 0:
					engine.schedule_cadence(start)
			"end":
				if item[1]:
					var start := on_beat("run_ended", 0.0, true)
					if start >= 0:
						engine.schedule_cadence(start + Harmony.BAR)
						engine.schedule_mode(start + Harmony.BAR * 3, MusicEngine.IDLE)
				else:
					engine.schedule_mode(engine.next_beat(), MusicEngine.IDLE)
			"dead":
				engine.cancel_pending()
				engine.schedule_mode(engine.next_beat(), MusicEngine.DEAD)
			"idle":
				engine.schedule_mode(engine.next_beat(), MusicEngine.IDLE)
			"gates":
				on_beat("reward_offered", 0.0, true)
			"milestone":
				on_beat("milestone_won", 0.0, true)


# --- Mixer keys ---------------------------------------------------------------------
# - and = move the music, [ and ] move the effects, M mutes everything.

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_MINUS:
			nudge("Music", -VOLUME_STEP)
		KEY_EQUAL:
			nudge("Music", VOLUME_STEP)
		KEY_BRACKETLEFT:
			nudge("SFX", -VOLUME_STEP)
		KEY_BRACKETRIGHT:
			nudge("SFX", VOLUME_STEP)
		KEY_M:
			muted = not muted
			_apply_volumes()
			_show_mixer()
		_:
			return
	get_viewport().set_input_as_handled()


func nudge(bus: String, amount: float) -> void:
	volumes[bus] = clampf(snappedf(volumes[bus] + amount, 0.01), 0.0, 1.0)
	if bus == "SFX":
		volumes["UI"] = volumes["SFX"]
	_apply_volumes()
	_show_mixer()
	play("flow_changed", 0.0, Harmony.ratio(Harmony.pentatonic_step(int(volumes[bus] * 8.0))), "UI")


func _apply_volumes() -> void:
	for bus in volumes:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		AudioServer.set_bus_volume_linear(index, volumes[bus] * db_to_linear(BUSES[bus]))
		AudioServer.set_bus_mute(index, muted)


func _make_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_overlay = Label.new()
	_overlay.add_theme_font_size_override("font_size", 18)
	_overlay.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_overlay.add_theme_constant_override("outline_size", 8)
	_overlay.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_overlay.position = Vector2(-360.0, -60.0)
	_overlay.visible = false
	layer.add_child(_overlay)


func _show_mixer() -> void:
	if _overlay == null:
		return
	if muted:
		_overlay.text = "Sound muted (M)"
	else:
		_overlay.text = "Music %d%%  (- =)    Effects %d%%  ([ ])    M mutes" % [roundi(volumes["Music"] * 100.0), roundi(volumes["SFX"] * 100.0)]
	_overlay.visible = true
	_overlay_until = Time.get_ticks_msec() + 1600
