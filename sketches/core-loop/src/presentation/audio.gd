extends Node

const EventKinds := preload("res://src/core/event_kinds.gd")
const Rows := preload("res://src/presentation/rows.gd")
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
# Danger sounds pull the bass down so the low end never masks a warning.
const DANGER_SOUNDS := ["hurt", "enemy_arrive", "boss_telegraph", "klaxon", "threat_up", "death",
	"threat_tick", "threat_whoosh", "threat_whistle", "threat_hum"]
# A launch whose landing never comes (a fall into the next stage's rail) still drops.
const LANDING_FALLBACK_MS := 2000
# Expected launch-to-landing time, for the pace of the build's sweep.
const LAUNCH_BUILD_SECONDS := 1.6
# Pitched cues that follow the live key (a lifted Warden plays its chimes in Eb).
const KEYED_SOUNDS := ["scrap_tick", "kill_pop", "part_get", "core_socket", "found_chime", "gate_through",
	"grapple_clink", "grapple_release", "pylon_plant", "beacon_hum", "clank", "hit_thwack", "hurt",
	"enemy_arrive", "boss_weak_hit", "ui_tick", "element_resolved", "ice_form", "vault_rise", "synergy_hit"]
# Event progress until the spine publishes event_progress(event_id, fraction): the
# seconds each participatory event usually takes (REQUEST in the hand-back).
const EVENT_SECONDS := {"hold_the_relay": 18.0, "surge_run": 22.0, "scrap_stampede": 16.0}

# v2 W3 characters: the class-ability facts, heard through their event rows.
const CHARACTER_KINDS := ["enemy_rebounded", "enemy_pinned", "vault_kicked", "gauge_charging", "gauge_released",
	"gauge_cancelled", "sprint_started", "cc_ignored", "cloak_started", "cloak_broken", "sticky_detonated",
	"rocket_jumped", "blink_used", "arc_slammed", "skid_smashed", "demo_slammed"]

var ctx
var engine: MusicEngine
# v2 W3 characters: which of CHARACTER_KINDS are already connected.
var _character_wired := {}
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
var _heft_class := 1
var _unseal_ms := -100000
var _boss_phase := 1
var _weak_combo := 0
# The launch build: armed on launched, handed its stage on stage_entered, dropped on
# the first landing after it. [touchdown_sample, drop_sample] per landing drop.
var _launch_armed := false
var _landing_theme := -1
var _entered_ms := -1
var _launch_stage := false
var drop_log: Array = []
var _miniboss: Node3D
var _event_id := ""
var _event_started_ms := -1
var _event_progress_live := false
var _chase_lead0 := -1.0
var _weak_last := -100000
var _flow_queue: Array = []
var _overlay: Label
var _overlay_until := 0
var _virtual_usec := 0

static var _bake_task := -1
static var _baked := false
static var _rest_task := -1


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
	var ids: Array = Rows.sound_ids()
	for kind in EventKinds.THREAT_ROWS:
		ids.append(EventKinds.THREAT_ROWS[kind]["sound"])
	for extra in ["womp", "build_riser", "vault_rise", "vault_drop", "synergy_hit"]:
		if not extra in ids:
			ids.append(extra)
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


func _enter_tree() -> void:
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	if _bake_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_bake_task)
		_bake_task = -1
		_baked = true
	if _rest_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_rest_task)
		_rest_task = -1
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
	# The other themes and the bosses bake behind stage 1. Headless runs render them
	# on demand instead, so a test never waits on the worker at quit.
	if _rest_task < 0 and live_output:
		_rest_task = WorkerThreadPool.add_task(MusicEngine.prepare_rest, false, "presentation band bake")
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
	_follow_warden()
	_follow_escalation()
	if _launch_armed and _landing_theme >= 0 and Time.get_ticks_msec() - _entered_ms > LANDING_FALLBACK_MS:
		_land_drop()
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
func play(kind: String, db := 0.0, pitch := 1.0, bus := "SFX", sound_override := "") -> bool:
	var sound: String = sound_override if sound_override != "" else Rows.sound(kind)
	if not sound_ready or sound == "":
		cue_log.append([kind, sound, "skip", -1, pitch])
		return false
	var now := Time.get_ticks_msec()
	if now - int(_last_start.get(sound, -100000)) < int(MIN_GAP_MS.get(sound, 0)):
		cue_log.append([kind, sound, "skip", -1, pitch])
		return false
	_last_start[sound] = now
	if sound in KEYED_SOUNDS:
		pitch *= Harmony.ratio(engine.key)
	var playback := _ui if bus == "UI" else _sfx
	if playback != null:
		var live: Array = _voices.get(sound, [])
		live = live.filter(func(id: int): return playback.is_stream_playing(id))
		if live.size() >= int(VOICE_LIMIT.get(sound, 3)):
			playback.stop_stream(live.pop_front())
		var volume: float = SfxBank.trim_db(sound) + PRIORITY_DB[Rows.priority(kind)] + db
		var id := playback.play_stream(SfxBank.stream(sound), 0.0, volume, pitch, AudioServer.PLAYBACK_TYPE_DEFAULT, bus)
		if id != AudioStreamPlaybackPolyphonic.INVALID_ID:
			live.append(id)
		_voices[sound] = live
	cue_log.append([kind, sound, "now", engine.clock, pitch])
	if Rows.priority(kind) >= 2:
		engine.duck(0.55, 0.35)
	if sound in DANGER_SOUNDS:
		engine.duck_bass(0.3, 0.45)
	return true


# v2 W2 threat grammar. A committed threat warns on the game frame it is declared, never
# on the beat (SOUND-STORY.md section 7): its type's row sound, then the owner's voice
# and the mechanic tag when the threat carries them. Only hostile threats join the
# "threat" group, so the player's own rings and harmless fields stay silent. The check
# runs at the end of the frame, after the committing code has set the layers.
func _on_node_added(node: Node) -> void:
	if node.has_method("threat_kind"):
		_warn_threat.call_deferred(node)


func _warn_threat(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree() or not node.is_in_group("threat"):
		return
	var kind: String = node.threat_kind()
	var row: Dictionary = EventKinds.THREAT_ROWS.get(kind, {})
	if row.is_empty():
		return
	var db: float = PRIORITY_DB[int(row["priority"])] - PRIORITY_DB[Rows.priority(kind)] - _threat_distance_db(node)
	play(kind, db, 1.0, "SFX", row["sound"])
	for layer in [node.get("owner_voice"), node.get("mechanic_tag")]:
		if layer is String and layer != "":
			play(kind, db, 1.0, "SFX", layer)
	if int(row["priority"]) >= 2:
		engine.duck(0.55, 0.35)


# Cues here are not positional, so a far threat is only quieter: full within 20 m,
# 9 dB down from 60 m.
func _threat_distance_db(node: Node) -> float:
	if ctx == null or ctx.player == null or not node.has_method("threat_at"):
		return 0.0
	var gap: float = (node.threat_at() as Vector3).distance_to(ctx.player.ball_position())
	return 9.0 * clampf((gap - 20.0) / 40.0, 0.0, 1.0)


# Plays a cue on the next beat through the band. lane queues it behind flow stingers.
func on_beat(kind: String, db := 0.0, lane := false, repeats := 1, sound_override := "") -> int:
	var sound: String = sound_override if sound_override != "" else Rows.sound(kind)
	if not sound_ready or sound == "":
		cue_log.append([kind, sound, "skip", -1, 1.0])
		return -1
	var start := engine.schedule_stinger(sound, db, lane, repeats)
	var beats: int = SfxBank.STINGER_BEATS.get(sound, 1)
	engine.duck(0.6, float(start - engine.clock + beats * Harmony.BEAT) / Harmony.RATE)
	if sound in DANGER_SOUNDS:
		engine.duck_bass(0.3, float(start - engine.clock + beats * Harmony.BEAT) / Harmony.RATE)
	cue_log.append([kind, sound, "beat", start, 1.0])
	return start


# --- Facts --------------------------------------------------------------------------

func _connect_all(events) -> void:
	events.run_started.connect(func(_class_id: String):
		_heft_class = 1
		_flow_queue.append(["run"]))
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
	events.landed.connect(_on_landed)
	events.slammed.connect(_on_slammed)
	events.grapple_fired.connect(func(_anchor: Vector3): play("grapple_fired"))
	events.grapple_released.connect(func(): play("grapple_released"))
	events.mounted.connect(func(_at: Vector3, banked: float): play("mounted", 0.0, Harmony.ratio(minf(banked / 4.0, 7.0))))
	events.dismounted.connect(_on_dismounted)
	events.enemy_spawned.connect(_on_enemy_spawned)
	events.enemy_struck.connect(_on_struck)
	events.shot_fired.connect(_on_shot)
	events.special_used.connect(func(_special: String, _at: Vector3): play("special_used"))
	events.reward_offered.connect(_on_offered)
	events.reward_chosen.connect(func(_part: String): play("reward_chosen"))
	events.event_announced.connect(func(_event_id: String, _seconds: float): on_beat("event_announced"))
	events.event_started.connect(_on_event_started)
	events.event_ended.connect(_on_event_ended)
	events.launched.connect(_on_launched)
	events.pressure_changed.connect(_on_pressure)
	wire_optional()


# The demo-spec signals the spine is adding. Each one is connected only if the bus
# has it, and this can be called again once it does (tests add them locally).
func wire_optional() -> void:
	var events = ctx.events
	_listen(events, "beacon_unsealed", func(_stage: int): _flow_queue.append(["unseal"]))
	_listen(events, "heft_class_changed", _on_heft_class)
	_listen(events, "heft_class_dropped", _on_heft_dropped)
	_listen(events, "scrap_lost", func(amount: int, _at: Vector3, _total: int, _cause: String): play("scrap_lost", clampf(amount / 20.0, 0.0, 1.0) * 4.0 - 3.0))
	_listen(events, "strike_deflected", _on_deflected)
	_listen(events, "threat_rose", func(tier: int): on_beat("threat_rose", minf(tier, 3) * 1.0))
	_listen(events, "core_gained", _on_core)
	_listen(events, "synergy_discovered", _on_synergy)
	_listen(events, "interaction_found", func(): play("interaction_found"), true)
	_listen(events, "element_resolved", func(_element: String, _material: String, behaviour: String, _at: Vector3):
		play("element_resolved", 0.0, 1.0, "SFX", Rows.element_sound(behaviour)))
	_listen(events, "warden_engaged", func(_stage: int): _begin_boss("warden_engaged", "warden"))
	_listen(events, "boss_arena_entered", func():
		_boss_phase = 1
		_disarm_launch()
		_begin_boss("boss_arena_entered", "brindle"), true)
	var phase_args := _argc(events, "boss_phase_changed")
	if phase_args >= 1:
		_listen(events, "boss_phase_changed", _on_boss_phase_with.unbind(phase_args - 1) if phase_args > 1 else _on_boss_phase_with)
	else:
		_listen(events, "boss_phase_changed", _on_boss_phase, true)
	_listen(events, "boss_defeated", func(): _on_boss_defeated(), true)
	_listen(events, "boss_attack_telegraphed", _on_boss_telegraph)
	_listen(events, "boss_weak_point_hit", _on_weak_point)
	_listen(events, "event_progress", _on_event_progress)
	# The stage's content leaves before the arena: a soft fade, and any launch build
	# resolves into the arena music instead of a landing.
	_listen(events, "stage_content_cleared", func(reason: String):
		_disarm_launch()
		_event_id = ""
		_chase_lead0 = -1.0
		if reason == "arena_retry" and sound_ready:
			# R in the arena: Brindle's music from phase 1, out of DEAD mode, with a pickup.
			engine.cancel_pending()
			engine.fill_into(engine.restart_boss("brindle"))
		# The stage's bonus cores stay with the stage; a restore may have moved heft.
		engine.set_overcharge(0)
		if ctx.run.has_method("heft_class"):
			_heft_class = int(ctx.run.heft_class())
			engine.set_heft_lift(_heft_class - 1)
		if reason != "arena_retry" and sound_ready and engine.mode != MusicEngine.PLAY and engine.track == "brindle":
			engine.cancel_pending()
			engine.restart_boss("brindle")
		play("stage_content_cleared"))
	# v2 W3 characters: each class-ability fact plays its event row's stand-in sound
	# until W5 bakes the id named in the row's sound_next.
	for kind in CHARACTER_KINDS:
		if events.has_signal(kind) and not _character_wired.has(kind):
			_character_wired[kind] = true
			events.connect(kind, play.bind(kind).unbind(_argc(events, kind)))


# Connects once. loose drops whatever arguments the signal carries.
static func _listen(events: Object, signal_name: String, callable: Callable, loose := false) -> bool:
	if not events.has_signal(signal_name):
		return false
	var target := callable
	if loose:
		var argc := 0
		for info in events.get_signal_list():
			if info["name"] == signal_name:
				argc = (info["args"] as Array).size()
		if argc > 0:
			target = callable.unbind(argc)
	for connection in events.get_signal_connection_list(signal_name):
		if connection["callable"].get_object() == callable.get_object() and connection["callable"].get_method() == callable.get_method():
			return true
	events.connect(signal_name, target)
	return true


func _on_event_started(event_id: String) -> void:
	on_beat("event_started")
	if event_id in EVENT_SECONDS:
		_event_id = event_id
		_event_started_ms = Time.get_ticks_msec()


# A win drops back into the level with the milestone stinger on the drop beat; a pass
# or a loss settles home gracefully, with no punishing sting.
func _on_event_ended(event_id: String, outcome: String) -> void:
	var participatory := event_id == _event_id
	_event_id = ""
	if not participatory or not sound_ready:
		on_beat("event_ended", -6.0 if outcome != "won" else 0.0)
		return
	if outcome == "won":
		var at := engine.resolve_event(true)
		if at >= 0:
			engine.schedule_stinger_at(Rows.sound("milestone_won"), at)
			cue_log.append(["event_ended", Rows.sound("milestone_won"), "beat", at, 1.0])
	else:
		engine.resolve_event(false)
		cue_log.append(["event_ended", "settle", "bar", engine.next_bar(), 1.0])


# The spine's event_progress(event_id, fraction), once it lands, replaces the timer.
func _on_event_progress(event_id: String, fraction: float) -> void:
	if event_id != _event_id or not sound_ready:
		return
	_event_progress_live = true
	engine.escalate(clampf(fraction, 0.0, 1.0), false)


func _on_flow_changed(state: String) -> void:
	if state in MENU_STATES:
		play("flow_changed", 0.0, 1.0, "UI")
	if state == "title" or state == "class_select":
		_flow_queue.append(["idle"])
	# Back in the arena (entry or retry) the band plays, whatever a death left it in.
	if state == "boss" and sound_ready and engine.mode != MusicEngine.PLAY:
		engine.schedule_mode(engine.next_beat(), MusicEngine.PLAY)


func _on_stage_entered(stage: int, retry: bool) -> void:
	engine.set_overcharge(0)
	if retry:
		_disarm_launch()
	elif _launch_armed:
		# The stage the launch was flying to: its theme arrives with the landing drop.
		_landing_theme = clampi(stage - 1, 0, 2)
		_entered_ms = Time.get_ticks_msec()
		_launch_stage = true
	if ctx.run.has_method("heft_class"):
		_heft_class = int(ctx.run.heft_class())
		engine.set_heft_lift(_heft_class - 1)
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


func _on_enemy_spawned(_enemy: Node3D, kind: String) -> void:
	var boss := kind == "miniboss"
	play("enemy_spawned", 3.0 if boss else 0.0, Harmony.ratio(-5.0) if boss else 1.0)
	if boss:
		_miniboss = _enemy
	if boss and sound_ready:
		engine.begin_miniboss()


# The boss music begins on the next bar, after the metric modulation when it pivots,
# and the row's cue marks the moment it begins.
func _begin_boss(kind: String, music: String) -> void:
	if not sound_ready:
		return
	if engine.track == music or engine.mode != MusicEngine.PLAY:
		# A retry into the fight: the band left DEAD (or never left the boss track), so
		# it restarts the boss music in play mode on the next beat, not the keys alone.
		engine.cancel_pending()
		var again := engine.restart_boss(music)
		cue_log.append([kind, "restart", "beat", again, 1.0])
		return
	var at := engine.begin_boss(music)
	if at < 0:
		return
	var sound := Rows.sound(kind)
	if sound != "":
		engine.schedule_stinger_at(sound, at)
	cue_log.append([kind, sound, "bar", at, 1.0])


# boss_phase_changed(phase, name) in wave 4; with no phase argument, count up.
func _on_boss_phase() -> void:
	_boss_phase += 1
	on_beat("boss_phase_changed")
	engine.set_brindle_phase(_boss_phase)


func _on_boss_phase_with(phase) -> void:
	_boss_phase = int(phase)
	on_beat("boss_phase_changed")
	engine.set_brindle_phase(_boss_phase)


static func _argc(events: Object, signal_name: String) -> int:
	for info in events.get_signal_list():
		if info["name"] == signal_name:
			return (info["args"] as Array).size()
	return -1


func _on_boss_defeated() -> void:
	on_beat("boss_defeated", 0.0, true)
	engine.victory()


func _on_kill(_kind: String, _at: Vector3, _value: int) -> void:
	if _kind == "miniboss" and engine.track == "miniboss":
		# The payoff on the kill: the drop home on the next beat, then the cadence.
		engine.miniboss_drop()
		_miniboss = null
	if _kind == "vault":
		# A small drop, on the moment the vault breaks.
		play("enemy_killed", 2.0, 1.0, "SFX", "vault_drop")
	var now := Time.get_ticks_msec()
	_kill_combo = mini(_kill_combo + 1, 7) if now - _kill_last < KILL_COMBO_WINDOW_MS else 0
	_kill_last = now
	play("enemy_killed", 0.0, Harmony.ratio(Harmony.pentatonic_step(_kill_combo)))


func _on_died() -> void:
	play("player_died")
	_flow_queue.append(["dead"])


func _on_slammed(_at: Vector3, strength: float, flatness: float) -> void:
	if strength < 0.05:
		return
	play("slammed", lerpf(-8.0, 0.0, clampf(strength, 0.0, 1.0)), lerpf(1.1, 0.9, clampf(strength - 0.5, 0.0, 1.0)))
	# The womp is the player's own action, so it sounds this frame, never on a beat.
	# The flat full plant is the biggest: loudest and a fourth lower.
	var weight := clampf(strength, 0.0, 1.0) * lerpf(0.5, 1.0, clampf(flatness, 0.0, 1.0))
	play("slammed", lerpf(-12.0, 0.0, weight), Harmony.ratio(lerpf(0.0, -5.0, weight)), "SFX", "womp")


func _on_launched(_velocity: Vector3) -> void:
	play("launched")
	# From the level, a miniboss or the Warden's drop (players take the gate inside
	# the unseal drop); never out of Brindle's arena.
	if not sound_ready or engine.mode != MusicEngine.PLAY or engine.track == "brindle":
		return
	# The launch is the build: the riser, the snare roll and the sweep carry the flight.
	engine.start_build(LAUNCH_BUILD_SECONDS, true)
	_launch_armed = true
	_landing_theme = -1
	_launch_stage = false


func _on_landed(impact: float) -> void:
	play("landed", lerpf(-12.0, 2.0, clampf(impact / 30.0, 0.0, 1.0)), lerpf(1.1, 0.85, clampf(impact / 30.0, 0.0, 1.0)))
	if _launch_armed and _landing_theme >= 0:
		_land_drop()


# The landing is the drop: on the next beat, never more than one beat after touchdown,
# in the new stage's theme.
func _land_drop() -> void:
	var touchdown := engine.clock
	var at := engine.drop_now(4, 0.85, {}, _landing_theme)
	drop_log.append([touchdown, at])
	cue_log.append(["landed", "drop", "beat", at, 1.0])
	_launch_armed = false
	_landing_theme = -1


func _disarm_launch() -> void:
	if _launch_armed:
		engine.cancel_build()
	_launch_armed = false
	_landing_theme = -1
	_launch_stage = false


# The Warden's last quarter is the build; the spine's integrity query is read-only.
func _follow_warden() -> void:
	if engine.track != "warden" or engine.section == "drop":
		return
	if ctx.flow == null or not ctx.flow.has_method("warden_integrity"):
		return
	engine.warden_charge(1.0 - float(ctx.flow.warden_integrity()))


# The B-arc for the miniboss, the live event, Brindle's phases and the chase, each on
# its own real state (guarded reads; nothing here decides an outcome).
func _follow_escalation() -> void:
	if not sound_ready or engine.mode != MusicEngine.PLAY:
		return
	match engine.track:
		"miniboss":
			if is_instance_valid(_miniboss) and ctx.spawner != null and ctx.spawner.has_method("integrity_of"):
				engine.escalate(1.0 - float(ctx.spawner.integrity_of(_miniboss)))
		"brindle":
			_follow_brindle()
		"level":
			if _event_id != "" and not _event_progress_live:
				var seconds: float = EVENT_SECONDS.get(_event_id, 20.0)
				engine.escalate(clampf((Time.get_ticks_msec() - _event_started_ms) / 1000.0 / seconds, 0.0, 1.0), false)


func _follow_brindle() -> void:
	var boss = ctx.get("boss")
	if boss == null or not is_instance_valid(boss):
		return
	var rules := _boss_rules(boss)
	var phase := int(_num(boss, "phase", 0.0))
	if engine.section == "chase":
		var scooter = boss.get("scooter")
		if scooter is Node3D and is_instance_valid(scooter) and boss.has_method("scooter_landed") and boss.scooter_landed():
			var lead: float = (scooter as Node3D).global_position.distance_to(ctx.player.ball_position())
			if _chase_lead0 < 0.0:
				_chase_lead0 = maxf(lead, 1.0)
			engine.chase(clampf(1.0 - lead / _chase_lead0, 0.0, 1.0))
		return
	if rules.is_empty() or phase < 1 or phase > 3:
		return
	var floors: Array = rules["PHASE_FLOORS"]
	var mins: Array = rules["PHASE_MIN_SECONDS"]
	var hp := _num(boss, "hp", 1.0) / maxf(_num(boss, "max_hp", 1.0), 1.0)
	var top := 1.0 if phase == 1 else float(floors[phase - 2])
	var floor_hp := float(floors[phase - 1])
	var in_phase := clampf((top - hp) / maxf(top - floor_hp, 0.01), 0.0, 1.0)
	var held := hp <= floor_hp + 0.001
	engine.brindle_hp(in_phase, held, _num(boss, "phase_clock", 0.0) / maxf(float(mins[phase - 1]), 1.0))


# A number the boss module exposes, or the default when it (or a test double) has none.
static func _num(object: Object, property: String, fallback: float) -> float:
	var value = object.get(property)
	return float(value) if value is int or value is float else fallback


static func _boss_rules(boss: Object) -> Dictionary:
	var script = boss.get_script()
	if script == null:
		return {}
	var rules = (script as Script).get_script_constant_map().get("Rules")
	if not rules is Script:
		return {}
	var map: Dictionary = (rules as Script).get_script_constant_map()
	if not map.has("PHASE_FLOORS") or not map.has("PHASE_MIN_SECONDS"):
		return {}
	return map


func _on_dismounted(velocity: Vector3) -> void:
	# E drops off quietly; the slingshot sings higher the faster it throws you.
	if velocity.length() < 1.0:
		play("dismounted", -8.0, 0.75)
		return
	play("dismounted", 0.0, Harmony.ratio(clampf(velocity.length() / 5.0, 0.0, 7.0)))


func _on_struck(enemy: Node3D, kind: String, force: float) -> void:
	if kind == "synergy":
		# A synergy's shockwave: its own light chime, never the slam family.
		play("enemy_struck", -8.0, Harmony.ratio(Harmony.pentatonic_step(randi() % 5)), "SFX", "synergy_hit")
		return
	if is_instance_valid(enemy) and enemy.get("kind") == "vault":
		# The vault's riser climbs as its integrity falls.
		play("enemy_struck", -2.0, Harmony.ratio(lerpf(0.0, 9.0, 1.0 - _integrity(enemy))), "SFX", "vault_rise")
		return
	var contact := kind in ["stomp", "ram", "slam"]
	var db := lerpf(-6.0, 1.0, clampf(force / 30.0, 0.0, 1.0)) if contact else -5.0
	play("enemy_struck", db, (1.0 if contact else 1.15) * _warden_ladder(enemy))


# Hits on the Warden climb the pentatonic as its integrity falls; the unseal resolves
# them home. 1.0 for anything else.
func _warden_ladder(enemy: Node3D) -> float:
	if ctx.flow == null or not is_instance_valid(enemy) or ctx.flow.get("warden") != enemy:
		return 1.0
	return Harmony.ratio(Harmony.pentatonic_step(int((1.0 - _integrity(enemy)) * 6.0)))


func _integrity(enemy: Node3D) -> float:
	if ctx.spawner != null and ctx.spawner.has_method("integrity_of"):
		return float(ctx.spawner.integrity_of(enemy))
	return 1.0


func _on_shot(weapon_id: String, _from: Vector3, _to: Vector3) -> void:
	var cents := randf_range(-25.0, 25.0) / 100.0
	play("shot_fired", 0.0, Harmony.ratio(WEAPON_PITCH.get(weapon_id, 0.0) + cents))


func _on_offered(_offers: Array) -> void:
	# The gates re-announce when they move; the fanfare plays once per opening.
	if _gates_announced:
		return
	_gates_announced = true
	_flow_queue.append(["gates"])


# Up a class climbs on the next beat; down a class (a crane theft) falls back softly.
# Direction comes from the last class heard until the spine publishes its own.
func _on_heft_class(heft_class: int, _heft: float) -> void:
	engine.set_heft_lift(heft_class - 1)
	if heft_class > _heft_class:
		on_beat("heft_class_changed")
	elif heft_class < _heft_class:
		on_beat("heft_class_changed", 0.0, false, 1, "class_down")
	_heft_class = heft_class


# A class lost has its own signal now: the climb falls back on the next beat.
func _on_heft_dropped(heft_class: int, _heft: float) -> void:
	on_beat("heft_class_dropped")
	engine.set_heft_lift(heft_class - 1)
	_heft_class = heft_class


# Danger is never quantized: the telegraph sounds the frame the boss winds up, and
# the shorter the warning the higher it sits, so a quick swing reads as urgent.
func _on_boss_telegraph(_attack_id: String, seconds_until: float) -> void:
	play("boss_attack_telegraphed", 0.0, Harmony.ratio(lerpf(3.0, 0.0, clampf(seconds_until / 1.5, 0.0, 1.0))))


# Weak-point hits climb the pentatonic like a combo, so a string of them sings.
func _on_weak_point(_point_id: String) -> void:
	var now := Time.get_ticks_msec()
	_weak_combo = mini(_weak_combo + 1, 7) if now - _weak_last < KILL_COMBO_WINDOW_MS else 0
	_weak_last = now
	play("boss_weak_point_hit", 0.0, Harmony.ratio(Harmony.pentatonic_step(_weak_combo)))


# A bounced hit clanks lower the further you are from breaking through.
func _on_deflected(_enemy: Node3D, _kind: String, punch: float, plating: float) -> void:
	var closeness := clampf(punch / maxf(plating, 1.0), 0.0, 1.0)
	play("strike_deflected", 0.0, Harmony.ratio(lerpf(-7.0, 0.0, closeness)) * _warden_ladder(_enemy))


func _on_core(_source: String, _at: Vector3, count: int) -> void:
	play("core_gained", 0.0, Harmony.ratio(Harmony.pentatonic_step(maxi(count - 1, 0))))
	engine.set_overcharge(count)


func _on_synergy(_id: String, _category: String, first_time: bool) -> void:
	on_beat("synergy_discovered", 0.0 if first_time else -6.0)


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
				_disarm_launch()
				engine.cancel_pending()
				var start := on_beat("run_started", 0.0, true)
				if start >= 0:
					engine.schedule_restart(start, MusicEngine.PLAY, 0)
			"stage":
				var stage: int = item[1]
				var retry: bool = item[2]
				if not retry and "run" in kinds:
					continue
				if not retry and _launch_stage:
					# The landing drop announces this stage.
					_launch_stage = false
					continue
				if retry:
					# A pickup fill back into the groove, then the stage hit on its beat.
					engine.cancel_pending()
					var back := engine.retry_restart(MusicEngine.PLAY, clampi(stage - 1, 0, 2))
					engine.schedule_stinger_at(Rows.sound("stage_entered"), back)
					cue_log.append(["stage_entered", Rows.sound("stage_entered"), "beat", back, 1.0])
					continue
				var start := on_beat("stage_entered", 0.0, true, clampi(stage, 1, 4))
				if start >= 0:
					engine.schedule_restart(start, MusicEngine.PLAY, clampi(stage - 1, 0, 2))
			"clear":
				if "end" in kinds:
					_disarm_launch()
					continue
				var start := on_beat("stage_cleared", 0.0, true)
				# Mid-launch the build carries the music; the jingle rings over it.
				if start >= 0 and not _launch_armed:
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
				_disarm_launch()
				engine.cancel_pending()
				engine.death_break()
			"idle":
				engine.schedule_mode(engine.next_beat(), MusicEngine.IDLE)
			"unseal":
				_unseal_ms = Time.get_ticks_msec()
				if engine.track == "warden" and sound_ready:
					# The heaviest drop of the stage, on the next beat, with the unseal
					# stinger on the same downbeat.
					var at := engine.unseal_drop()
					engine.schedule_stinger_at(Rows.sound("beacon_unsealed"), at)
					cue_log.append(["beacon_unsealed", Rows.sound("beacon_unsealed"), "beat", at, 1.0])
				else:
					on_beat("beacon_unsealed", 0.0, true)
			"gates":
				# The unseal stinger already says the gates are open.
				if "unseal" in kinds or Time.get_ticks_msec() - _unseal_ms < 2500:
					continue
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
		KEY_F6:
			engine.boss_pivot = not engine.boss_pivot
			_show_text("Boss tempo: %s (F6)" % ("129 by metric modulation" if engine.boss_pivot else "four on the floor held at 172"))
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


func _show_text(text: String) -> void:
	if _overlay == null:
		return
	_overlay.text = text
	_overlay.visible = true
	_overlay_until = Time.get_ticks_msec() + 2200


func _show_mixer() -> void:
	if _overlay == null:
		return
	if muted:
		_overlay.text = "Sound muted (M)"
	else:
		_overlay.text = "Music %d%%  (- =)    Effects %d%%  ([ ])    M mutes" % [roundi(volumes["Music"] * 100.0), roundi(volumes["SFX"] * 100.0)]
	_overlay.visible = true
	_overlay_until = Time.get_ticks_msec() + 1600
