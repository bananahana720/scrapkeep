extends SceneTree

const Music := preload("res://src/presentation/music_engine.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Synth := preload("res://src/presentation/synth.gd")
var _failures := 0
var _checks := 0


func _initialize() -> void:
	_open_and_hold()
	_grid()
	_segments()
	_pins()
	_rules()
	_voice_cap()
	_duck()
	_density()
	_check("all groups completed", _checks >= 30, "script errors cannot silently skip the checks")
	print("presentation_v3_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _band(track := "warden", section := "build", theme := 0) -> Music:
	var engine := Music.new()
	engine._rng.seed = 20260928
	engine.force_track(track, theme, section, track == "warden")
	return engine


func _advance(engine: Music, samples: int) -> void:
	while samples > 0:
		var n := mini(samples, 1024)
		engine.render(n)
		samples -= n


func _events(engine: Music, kind: String) -> Array:
	return engine.events_log.filter(func(e: Array): return e[0] == kind)


func _open_and_hold() -> void:
	var e := _band()
	e.hold_dominant(true)
	e.start_build(2.0)
	var sus := e._chord(3)
	_check("dominant sus", sus.root == 45 and sus.voicing == [55, 57, 62, 64] and not sus.tones.has(61), "A D E G, no third; the root is A")
	_advance(e, int(2.0 * Harmony.RATE) - e.beat_len())
	_check("last beat gains b9", e._chord(0).tones.has(58), "Bb joins the suspension in the final build beat")
	e.warden_section("open")
	var targets := true
	for layer in Music.OPEN_GAINS.size():
		targets = targets and is_equal_approx(e.layer_target(layer), Music.OPEN_GAINS[layer])
	var kick := e.layer_starts[Music.KICK]
	var snare := e.layer_starts[Music.SNARE]
	var hats := e.layer_starts[Music.HATS]
	_advance(e, e.bar_len())
	_check("open layers", targets and not e.building() and e.layer_starts[Music.KICK] == kick and e.layer_starts[Music.SNARE] == snare and e.layer_starts[Music.HATS] - hats == 16 and is_equal_approx(e._pump_depth, 0.65), "kick/snare off; sub, bass and stabs pump; 16 hats at half; roll cancelled")
	_check("open filter", e._cutoff > Music.TONE_OPEN_HZ * 0.95, "open window clears the build filter")
	e.hold_dominant(false)
	e.warden_section("build")
	_check("miss has no drop", e.section == "build" and not e.in_drop() and e._chord(0).name == "Dm9", "closing the missed window restores the dark build")
	e.hold_dominant(true)
	e.start_build(1.6, true)
	_check("launch gem wins", e._chord(0) == Harmony.CADENCE[0] and e._voicing(e._chord(0)) == Harmony.CADENCE[0].voicing, "rice-cooker A7b9 is unchanged even with a held sus")
	e.cancel_build()
	e.warden_open_held_breath = false
	e.warden_section("open")
	_advance(e, e.beat_len() + 1)
	_check("window lab toggle", e.in_drop() and not e._dominant_held, "alternate open policy drops; default holds its breath")


func _grid() -> void:
	for tempo in [Harmony.STEP, Harmony.BOSS_STEP]:
		var e := _band()
		e._set_grid(tempo)
		_advance(e, tempo + 137)
		var asked := e.clock
		var at := e.door_tick()
		_advance(e, at - e.clock)
		var silent := _events(e, "door_tick").is_empty()
		e.render(1)
		var ticks := _events(e, "door_tick")
		_check("door sixteenth %d" % tempo, silent and ticks.size() == 1 and ticks[0][1] == at and posmod(at - e.grid_origin, tempo) == 0 and at - asked < tempo, "no early tick; exact next live sixteenth")
	var e := _band("level")
	_advance(e, 123)
	var pivot := e.begin_boss("warden")
	var duplicate := e.begin_boss("warden")
	_advance(e, pivot + Harmony.BAR - e.clock + 1)
	_check("one pivot", Music.WARDEN_PIVOT_ONCE_PER_STAGE and duplicate == -1 and _events(e, "pulse").size() == 1 and pivot % Harmony.BEAT == 0 and e.step_len == Harmony.BOSS_STEP and e.begin_boss("warden") == -1, "repeated lip commits queue one triplet pivot, on the 172 beat")
	_check("once per stage return", e.end_warden_lap() == -1 and e.track == "warden" and e.step_len == Harmony.BOSS_STEP, "shelf return stays in the club")
	e.warden_pivot_once_per_stage = false
	e.end_warden_lap()
	_advance(e, e.bar_len() * 4)
	_check("per lap lab toggle", e.track == "level" and e.step_len == Harmony.STEP, "alternate shelf return cadences to 172")


func _segments() -> void:
	var e := _band()
	e.segments_cut(1, 4)
	e.segments_cut(9, 0)
	_check("first segment", _events(e, "lift_queued").is_empty() and is_equal_approx(e._segment_fraction, 0.25), "one quarter stays below the existing lift threshold; invalid totals ignored")
	e.segments_cut(2, 4)
	e.segments_cut(1, 4)
	e.segments_cut(2, 4)
	_check("half lifts once", _events(e, "lift_queued").size() == 1 and _events(e, "lift_queued")[0][2] == 0.5 and e._segment_fraction == 0.5, "duplicate and stale counts cannot lower the arc or repeat its lift")
	_advance(e, e.bar_len() * 3)
	_check("lift applied", e.key == 1 and e.section == "lift" and e._lead_octave == 12, "pickup bar lifts the stage to Eb")
	e.hold_dominant(true)
	e.warden_section("open")
	e.duck_bass(0.3, 5.0)
	e.segments_cut(3, 4)
	var at := e.drop_now(1, 1.0)
	e.free_bass()
	_advance(e, at - e.clock + 1)
	_check("landing drop", e.in_drop() and e.bar_origin == at and posmod(at - e.grid_origin, e.beat_len()) == 0 and not e._dominant_held and e.key == 1 and e._bass_duck_target == 1.0, "landing starts a new bar on the beat, releases the sus/bass and preserves Eb")
	e.segments_cut(2, 4)
	_advance(e, e.bar_len() * 4)
	_check("three quarters breaks once", _events(e, "break_queued").size() == 1 and _events(e, "break_queued")[0][2] == 0.75 and e.section == "break" and e.key == 1, "queued break survives a landing drop at the unchanged 0.75 threshold")
	e.segments_cut(4, 4)
	e.unseal_drop()
	_advance(e, e.bar_len() * 13)
	_check("unseal home", e.track == "level" and e.step_len == Harmony.STEP and e.key == 0, "eight-bar final drop then cadence restores D at 172")
	var off := _band()
	off.warden_escalate_from_segments = false
	off.segments_cut(4, 4)
	_check("escalation lab toggle", _events(off, "lift_queued").is_empty(), "alternate clock disables the segment adapter; AU3 supplies its clock")


func _pins() -> void:
	var e := _band("level")
	e.set_class_motif("kest")
	e.pin_rotation("arp", {"arp": 2, "arp_oct": 12})
	e.pin_rotation("echo", {"echo_voice": "bell", "shift": 7})
	e.pin_rotation("counter", {"counter": "tom", "class_counter": true, "counter_oct": -12, "counter_boom": true})
	var survive := true
	var choir := {}
	for i in 8:
		e._revoice()
		var rot := e._rotation_state()
		survive = survive and rot.arp == 2 and rot.arp_oct == 12 and rot.echo_voice == "bell" and rot.shift == 7 and rot.counter == "tom" and rot.class_counter
		choir[rot.choir + rot.vowel] = true
	_check("pins survive rotations", survive and choir.size() > 1, "three evolution slots persist; the choir continues rotating")
	e.applied_pressure = 1.0
	e._retarget()
	var cell: Array = e._class_counter[0]
	e._play_counter(int(cell[0]) / 16, int(cell[0]) % 16)
	var notes: Array = e._voices.filter(func(v): return v.layer == Music.COUNTER)
	_check("counter pin sounds", notes.size() == 2 and notes[0].buf == Synth.note("tom", int(cell[1]) - 12) and notes[1].buf == Synth.note("sub", int(cell[1]) - 24), "class phrase plays in the pinned tom and sub register")
	e.hold_dominant(true)
	_check("sus arp overrides pin", e._rotation_state().arp == 0, "drop-line ascent temporarily masks the evolution shape")
	e.hold_dominant(false)
	_check("evolution restored", e._rotation_state().arp == 2, "releasing the hold restores the evolution")
	e.pin_rotation("arp", {})
	e.pin_rotation("arp", {"arp": 2}, 1)
	e._revoice()
	var tease: bool = e._rotation_state().arp == 2
	e._revoice()
	e._revoice()
	_check("armed tease expires", tease and e._rotation_state().arp == Music.ROTATIONS[e._rotation % 4].arp, "one rotation then the ordinary cycle resumes")


func _rules() -> void:
	for track in ["level", "warden"]:
		var plain := _band(track)
		var rules := _band(track)
		rules.rules = Music.RULE_DOUBLE_CLAP | Music.RULE_DEEP_PUMP | Music.RULE_FLEET_ANSWER
		_advance(plain, plain.bar_len())
		_advance(rules, rules.bar_len())
		_check("rule accents " + track, rules.layer_starts[Music.SNARE] == plain.layer_starts[Music.SNARE] + 1 and rules.layer_starts[Music.FLEET] == plain.layer_starts[Music.FLEET] + 1, "one extra clap and one Fleet brass answer per bar")
		if track == "warden":
			_check("deep pump", is_equal_approx(rules._pump_depth, 0.8), "rule deepens the club pump from 0.65 to 0.8")


func _voice_cap() -> void:
	var e := Music.new()
	var buf := PackedFloat32Array([0.1, 0.0])
	var bass := e._start(buf, 2, Music.SUB, 1.0, 0.0, false)
	var oldest := e._start(buf, 2, Music.KEYS, 1.0, 0.0, false)
	var stinger := e._start(buf, 2, Music.KEYS, 1.0, 0.0, true)
	for i in Music.BAND_VOICE_CAP - 2:
		e._start(buf, 2, Music.KEYS, 1.0, 0.0, false)
	e._start(buf, 2, Music.KEYS, 1.0, 0.0, false)
	var refused := e._start(buf, 2, Music.SUB, 1.0, 0.0, false)
	_check("voice cap", e.voice_count() == Music.BAND_VOICE_CAP + 1 and not e._voices.has(oldest) and e._voices.has(bass) and e._voices.has(stinger) and refused == null, "oldest same-layer band note stolen; bass/stinger protected; no eligible victim means no admission")


func _duck() -> void:
	var targets := []
	for intensity in [0.3, 0.65, 1.0]:
		var e := _band("level")
		e.applied_pressure = intensity
		e._retarget()
		e.duck(0.55, 0.35)
		targets.append(e._duck_target)
		e.duck_bass(0.3, 0.45)
		_check("bass duck unchanged %.2f" % intensity, is_equal_approx(e._bass_duck_target, 0.3), "danger bass duck remains 0.3")
	_check("intensity duck", is_equal_approx(targets[0], 0.7) and targets[1] < targets[0] and targets[1] > targets[2] and is_equal_approx(targets[2], 0.55), "band duck is 0.70 at 0.3, 0.55 at 1.0, monotonic between")


func _density() -> void:
	var peak := 0
	var rejected := 0
	var stolen := 0
	for state in ["snowball", "telegraph", "open", "drop"]:
		for theme in 3:
			var e := _band("level" if state == "snowball" else "warden", "build", theme)
			e.set_pressure(1.0)
			e.set_overcharge(2)
			e.set_fleet_ticks(3)
			e.set_class_motif("kest")
			e.pin_rotation("arp", {"arp": 2, "arp_oct": 12})
			e.pin_rotation("echo", {"echo_voice": "bell", "shift": 7})
			e.pin_rotation("counter", {"counter": "tom", "class_counter": true, "counter_oct": -12, "counter_boom": true})
			e.set_reactor_pedal(true)
			e.rules = Music.RULE_DOUBLE_CLAP | Music.RULE_DEEP_PUMP | Music.RULE_FLEET_ANSWER
			if state == "telegraph":
				e.start_build(2.0)
			elif state == "open":
				e.warden_section("open")
			elif state == "drop":
				e.drop_now(8, 1.0)
			_advance(e, e.bar_len() * 8)
			peak = maxi(peak, e.band_voice_peak)
			rejected += e.band_voice_rejections
			stolen += e.band_voice_steals
	_check("density headroom", peak * 1.25 <= Music.BAND_VOICE_CAP and rejected == 0 and stolen == 0, "four states x three themes x eight bars: peak %d, cap %d, rejected %d, stolen %d" % [peak, Music.BAND_VOICE_CAP, rejected, stolen])


func _check(name: String, ok: bool, detail: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("%s %s: %s" % ["PASS" if ok else "FAIL", name, detail])
