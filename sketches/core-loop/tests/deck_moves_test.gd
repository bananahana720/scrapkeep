extends SceneTree

const AceSequencer := preload("res://src/presentation/ace_sequencer.gd")
const Audio := preload("res://src/presentation/audio.gd")
const DeckFx := preload("res://src/presentation/deck_fx.gd")
const DeckMoves := preload("res://src/presentation/deck_moves.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const AceStub := preload("res://tests/support/ace_stub.gd")
const T := preload("res://tests/support/t.gd")

# Festival deck moves (--deck=festival):
#   1. With --deck off, AceSequencer.render() output is sample-identical to base.
#   2. With pump set, bass and other dip to 1 - depth by 220 frames and recover to 1.0 by 0.62 beat; drums untouched.
#   3. Pump is 0 on non-pumped sections, flat packs, and whenever the arbiter disallows the DJ.
#   4. Pump only lowers level (never exceeds unpumped sample).
#   5. Build shots start sample-exact on bar lines, follow BUILD_TIERS, book at most one bar ahead,
#      cancel within GAP_RAMP on leaving telegraph; open books one downlifter; impact starts on drop
#      sample and swell ends on it.
#   6. No shot survives stop(), pack change, death, or invalidate_trims().
#   7. Every deck_fx buffer keeps 2-4 kHz at least 12 dB under its loudest of 200-1800 Hz and 4.4-12 kHz,
#      and peaks <= 0.6.


class FakeFlow extends RefCounted:
	var state := "stage"
	var sealed := false
	var warden: Node3D = null

	func in_play() -> bool:
		return state in ["stage", "beacon", "gates", "launch", "boss"]

	func state_name() -> String:
		return state

	func engaged() -> bool:
		return sealed


class FakeRun extends RefCounted:
	var stage := 1
	var armor_mode := false
	var run_id := "deck_test"
	var mass := 100.0


class FakeCtx extends RefCounted:
	var events: Node
	var flow: FakeFlow
	var run: FakeRun
	var tuning: Tuning
	var player = null
	var spawner = null
	var stages = null
	var boss = null
	var terrain = null
	var build = null
	var root = null
	var dev := false
	var calm := true


var _t := T.new("deck_moves_test")
var _prev_stem_dir := ""


func _initialize() -> void:
	_prev_stem_dir = MusicRows.stem_dir
	AceStub.install()
	_test_switch_default_and_off_identical()
	_test_pump_shape_and_stems()
	_test_pump_zero_sections_and_flat()
	_test_build_breath_drop_shots()
	_test_shot_cleanup_and_arbiter()
	_test_viking_preset()
	_test_deck_fx_spectrum_and_peak()
	MusicRows.stem_dir = _prev_stem_dir
	quit(_t.verdict())


func _manifest() -> String:
	return MusicRows.ROWS["1-1"]["ace_manifest"]


func _advance_to_section(seq: AceSequencer, target: String, max_blocks := 600) -> void:
	for _i in max_blocks:
		if seq.section == target:
			return
		var step := 512
		if not seq.pending.is_empty() and String(seq.pending["section"]) == target:
			step = mini(step, maxi(1, int(seq.pending["at"]) - seq.clock))
		seq.render(step)


func _test_switch_default_and_off_identical() -> void:
	var tuning := Tuning.new()
	_t.eq("deck switch is off by default", tuning.option(Tuning.DECK_KEY), "off")
	var base := AceSequencer.new(_manifest())
	var off := AceSequencer.new(_manifest())
	var deck := DeckMoves.new()
	base.start_level(0, true)
	off.start_level(0, true)
	var diff_count := 0
	var total := 0
	var script := [
		{"bars": 2, "posture": 30.0, "stagger": false, "land": false},
		{"bars": 2, "posture": 85.0, "stagger": false, "land": false},
		{"bars": 1, "posture": 100.0, "stagger": true, "land": false},
		{"bars": 2, "posture": 0.0, "stagger": false, "land": true},
	]
	for step_row in script:
		var a_drop := base.follow_guard(float(step_row["posture"]), bool(step_row["stagger"]), bool(step_row["land"]))
		var b_drop := off.follow_guard(float(step_row["posture"]), bool(step_row["stagger"]), bool(step_row["land"]))
		deck.tend(off, {"on": false, "allow": true, "posture": float(step_row["posture"]), "staggered": bool(step_row["stagger"])})
		if b_drop >= 0:
			deck.on_drop(off, b_drop)
		_t.eq("off drop booking matches base", b_drop, a_drop)
		var frames := int(step_row["bars"]) * base.grid_bar
		var done := 0
		while done < frames:
			var n := mini(2048, frames - done)
			deck.tend(off, {"on": false, "allow": true, "posture": float(step_row["posture"]), "staggered": bool(step_row["stagger"])})
			var ba := base.render(n)
			var bb := off.render(n)
			for i in n:
				total += 1
				if ba[i] != bb[i]:
					diff_count += 1
			done += n
	_t.eq("deck off is sample-identical to base (%d samples)" % total, diff_count, 0)


func _test_pump_shape_and_stems() -> void:
	for sec_name in ["build", "telegraph", "drop"]:
		var depth: float = DeckMoves.PUMP[sec_name]
		for stem in ["drums", "bass", "other"]:
			var ref := AceSequencer.new(_manifest())
			var pumped := AceSequencer.new(_manifest())
			ref.solo = [stem]
			pumped.solo = [stem]
			pumped.set_pump(DeckMoves.PUMP)
			_enter_warden_section(ref, sec_name)
			_enter_warden_section(pumped, sec_name)
			var beat := ref.grid_beat
			# Render 2 full beats starting from the next beat line.
			var to_beat := ref.next_beat() - ref.clock
			if to_beat > 0:
				ref.render(to_beat)
				pumped.render(to_beat)
			var buf_ref := ref.render(beat * 2)
			var buf_p := pumped.render(beat * 2)
			if stem == "drums":
				var same := true
				for i in buf_ref.size():
					if buf_ref[i] != buf_p[i]:
						same = false
						break
				_t.check("%s drums untouched by pump" % sec_name, same)
				continue
			# Acceptance 4: pump never exceeds unpumped sample.
			var exceeded := 0
			for i in buf_ref.size():
				if absf(buf_p[i].x) > absf(buf_ref[i].x) + 1e-5 or absf(buf_p[i].y) > absf(buf_ref[i].y) + 1e-5:
					exceeded += 1
			_t.eq("%s %s pump never raises level" % [sec_name, stem], exceeded, 0)
			# Acceptance 2: check gain at breakpoints (within 1 frame) on beat 1 (steady state).
			var b1 := beat
			var check_points := [
				["attack_end_220", DeckMoves.PUMP_ATTACK_FRAMES, 1.0 - depth],
				["hold_end_007", int(round(0.07 * beat)), 1.0 - depth],
				["bp_020", int(round(0.20 * beat)), 1.0 - depth * 0.86],
				["bp_0345", int(round(0.345 * beat)), 1.0 - depth * 0.50],
				["bp_049", int(round(0.49 * beat)), 1.0 - depth * 0.14],
				["recover_062", int(round(0.62 * beat)), 1.0],
				["tail_080", int(round(0.80 * beat)), 1.0],
			]
			for cp in check_points:
				var label: String = cp[0]
				var k: int = cp[1]
				var want: float = cp[2]
				var got := _measure_gain_near(buf_ref, buf_p, b1 + k)
				_t.check("%s %s %s gain=%.3f want=%.3f" % [sec_name, stem, label, got, want],
					absf(got - want) <= 0.015, "got=%.4f want=%.4f" % [got, want])
	# Verify depth change ramps over one beat.
	var rseq := AceSequencer.new(_manifest())
	_enter_warden_section(rseq, "build")
	rseq.set_pump(DeckMoves.PUMP)
	var bass_v: AceSequencer.Voice = null
	for v: AceSequencer.Voice in rseq.voices:
		if v.stem == "bass":
			bass_v = v
	_t.check("depth change starts ramp from 0 to target", bass_v != null and is_equal_approx(bass_v.pump_depth, 0.0) and is_equal_approx(bass_v.pump_target, DeckMoves.PUMP["build"]))
	rseq.render(rseq.grid_beat / 2)
	_t.check("depth change halfway after half a beat", absf(bass_v.pump_depth - DeckMoves.PUMP["build"] * 0.5) < 0.03, "depth=%.4f" % bass_v.pump_depth)
	rseq.render(rseq.grid_beat)
	_t.check("depth change finishes within one beat", is_equal_approx(bass_v.pump_depth, DeckMoves.PUMP["build"]), "depth=%.4f" % bass_v.pump_depth)


func _measure_gain_near(ref: PackedVector2Array, pumped: PackedVector2Array, idx: int) -> float:
	# Pick a sample within +-1 frame of idx where the sine carrier isn't at a zero crossing.
	var best_i := idx
	var best_mag := 0.0
	for d in [-1, 0, 1, -2, 2]:
		var j := clampi(idx + d, 0, ref.size() - 1)
		var m := absf(ref[j].x)
		if m > best_mag:
			best_mag = m
			best_i = j
	return pumped[best_i].x / ref[best_i].x


func _enter_warden_section(seq: AceSequencer, sec_name: String) -> void:
	seq.start_level(0, true)
	_advance_to_section(seq, "build")
	if sec_name == "build":
		return
	if sec_name == "telegraph":
		seq.follow_guard(80.0, false, false)
		_advance_to_section(seq, "telegraph")
	elif sec_name == "open":
		seq.follow_guard(100.0, true, false)
		_advance_to_section(seq, "open")
	elif sec_name == "drop":
		seq.follow_guard(100.0, true, false)
		_advance_to_section(seq, "open")
		seq.follow_guard(0.0, false, true)
		_advance_to_section(seq, "drop")


func _test_pump_zero_sections_and_flat() -> void:
	var seq := AceSequencer.new(_manifest())
	seq.set_pump(DeckMoves.PUMP)
	_t.check("pump_active true when pump set on sectioned pack", seq.pump_active())
	for sec in ["pivot", "open", "break", "return", "home", "calm", "travel", "cadence"]:
		_t.eq("pump depth is 0 on %s bass" % sec, seq.pump_depth_for("bass", sec), 0.0)
		_t.eq("pump depth is 0 on %s other" % sec, seq.pump_depth_for("other", sec), 0.0)
	seq.flat = true
	_t.check("pump_active false on flat pack", not seq.pump_active())
	for sec in ["build", "telegraph", "drop", "main"]:
		_t.eq("pump depth is 0 on flat pack %s" % sec, seq.pump_depth_for("bass", sec), 0.0)
		_t.eq("pump depth is 0 on flat pack %s other" % sec, seq.pump_depth_for("other", sec), 0.0)


func _test_build_breath_drop_shots() -> void:
	_t.eq("tier below 75 is 0", DeckMoves.tier_for_posture(60.0), 0)
	_t.eq("tier at 75 is 0", DeckMoves.tier_for_posture(75.0), 0)
	_t.eq("tier at 84.9 is 0", DeckMoves.tier_for_posture(84.9), 0)
	_t.eq("tier at 85 is 1", DeckMoves.tier_for_posture(85.0), 1)
	_t.eq("tier at 94.9 is 1", DeckMoves.tier_for_posture(94.9), 1)
	_t.eq("tier at 95 is 2", DeckMoves.tier_for_posture(95.0), 2)
	_t.eq("tier at 100 is 2", DeckMoves.tier_for_posture(100.0), 2)

	var seq := AceSequencer.new(_manifest())
	var deck := DeckMoves.new()
	_enter_warden_section(seq, "telegraph")
	var bar := seq.grid_bar
	var room := {"on": true, "allow": true, "posture": 78.0, "staggered": false}
	# Step to just over half a bar before next_bar: nothing booked yet.
	var to_early := (seq.next_bar() - bar / 2 - 10) - seq.clock
	if to_early > 0:
		seq.render(to_early)
		deck.tend(seq, room)
		_t.eq("no build booked more than half a bar early", seq.shots.size(), 0)
	# Step into booking window (within half a bar of next_bar).
	var to_win := (seq.next_bar() - bar / 2 + 10) - seq.clock
	if to_win > 0:
		seq.render(to_win)
	deck.tend(seq, room)
	_t.eq("exactly one build bar booked ahead", seq.shots.size(), 1)
	var s0: AceSequencer.Shot = seq.shots[0]
	_t.eq("build shot starts sample-exact on next_bar", s0.at, seq.next_bar())
	_t.check("build shot uses tier 0 pcm for posture 78", s0.pcm == DeckFx.build(0, seq.grid_bar, seq.grid_beat))
	# Calling tend repeatedly in the same bar never double-books.
	deck.tend(seq, room)
	deck.tend(seq, {"on": true, "allow": true, "posture": 96.0, "staggered": false})
	_t.eq("at most one bar booked ahead", seq.shots.size(), 1)
	# Advance into that bar (past start), then into booking window for next bar at posture 96 (tier 2).
	seq.render(s0.at - seq.clock + bar / 2 + 10)
	deck.tend(seq, {"on": true, "allow": true, "posture": 96.0, "staggered": false})
	var future_builds := seq.shots.filter(func(s): return s.tag == DeckMoves.TAG_BUILD and s.at >= seq.clock)
	_t.eq("next bar books tier 2 build at posture 96", future_builds.size(), 1)
	_t.check("tier 2 pcm matches", future_builds[0].pcm == DeckFx.build(2, seq.grid_bar, seq.grid_beat))

	# Leaving telegraph cancels live + future build shots within GAP_RAMP frames.
	seq.follow_guard(100.0, true, false)
	_advance_to_section(seq, "open")
	deck.tend(seq, {"on": true, "allow": true, "posture": 100.0, "staggered": true})
	var breath_shots := seq.shots.filter(func(s): return s.tag == DeckMoves.TAG_BREATH)
	_t.eq("entering open books one downlifter", breath_shots.size(), 1)
	deck.tend(seq, {"on": true, "allow": true, "posture": 100.0, "staggered": true})
	_t.eq("staying in open does not double-book downlifter", seq.shots.filter(func(s): return s.tag == DeckMoves.TAG_BREATH).size(), 1)
	seq.render(AceSequencer.GAP_RAMP + 4)
	_t.eq("build shots gone within GAP_RAMP after leaving telegraph",
		seq.shots.filter(func(s): return s.tag == DeckMoves.TAG_BUILD).size(), 0)

	# Drop: impact starts on drop_at, swell ends on drop_at.
	var drop_at := seq.follow_guard(0.0, false, true)
	_t.check("follow_guard returns drop sample", drop_at > seq.clock)
	deck.on_drop(seq, drop_at)
	var drop_shots := seq.shots.filter(func(s): return s.tag == DeckMoves.TAG_DROP)
	_t.eq("on_drop books swell and impact", drop_shots.size(), 2)
	var has_impact := false
	var has_swell := false
	for ds: AceSequencer.Shot in drop_shots:
		if ds.at == drop_at and ds.pcm == DeckFx.impact():
			has_impact = true
		if ds.at + ds.pcm.size() == drop_at and ds.at < drop_at:
			has_swell = true
	_t.check("impact starts sample-exact on drop sample", has_impact)
	_t.check("swell ends sample-exact on drop sample", has_swell)

	# Regression #1: calling tend() between on_drop() and the drop commit must NOT re-book TAG_BREATH.
	_t.eq("still in open before drop commits", seq.section, "open")
	_t.eq("drop is pending", String(seq.pending.get("section", "")), "drop")
	seq.render(AceSequencer.GAP_RAMP + 4)
	deck.tend(seq, {"style": "festival", "allow": true, "posture": 0.0, "staggered": false})
	_t.eq("tend between on_drop and drop commit never re-fires TAG_BREATH",
		seq.shots.filter(func(s): return s.tag == DeckMoves.TAG_BREATH).size(), 0)

	# Regression #3: back-to-back on_drop() cancels prior TAG_DROP shots (no orphans).
	var drop_at_2 := drop_at + 1024
	deck.on_drop(seq, drop_at_2)
	var after_second_drop := seq.shots.filter(func(s): return s.tag == DeckMoves.TAG_DROP and s.env_target > 0.0)
	_t.eq("back-to-back on_drop leaves only the new swell+impact active", after_second_drop.size(), 2)
	seq.render(AceSequencer.GAP_RAMP + 4)
	var live_drop_shots := seq.shots.filter(func(s): return s.tag == DeckMoves.TAG_DROP)
	_t.eq("prior TAG_DROP shots cleared after GAP_RAMP", live_drop_shots.size(), 2)
	_t.check("surviving impact belongs to second on_drop",
		live_drop_shots.any(func(s): return s.at == drop_at_2 and s.pcm == DeckFx.impact()))


func _test_shot_cleanup_and_arbiter() -> void:
	# Regression #2: invalidate_trims() must NOT cancel deck shots (set-director preemption coexists with deck).
	var seq := AceSequencer.new(_manifest())
	_enter_warden_section(seq, "build")
	var pcm := DeckFx.impact()
	seq.shot_at(seq.clock - 10, pcm, DeckMoves.TAG_BUILD, 1.0)
	seq.shot_at(seq.clock + 2000, pcm, DeckMoves.TAG_DROP, 1.0)
	seq.invalidate_trims(AceSequencer.GAP_RAMP)
	_t.eq("invalidate_trims preserves future deck shots", seq.shots.filter(func(s): return s.tag == DeckMoves.TAG_DROP).size(), 1)
	seq.render(AceSequencer.GAP_RAMP + 4)
	_t.eq("invalidate_trims preserves live deck shots", seq.shots.filter(func(s): return s.tag == DeckMoves.TAG_BUILD).size(), 1)

	# stop() clears both future and live shots.
	seq.stop(AceSequencer.STOP_RAMP)
	_t.eq("stop drops unstarted shot immediately", seq.shots.filter(func(s): return s.tag == DeckMoves.TAG_DROP).size(), 0)
	seq.render(AceSequencer.STOP_RAMP + 4)
	_t.eq("stop fades out live shot", seq.shots.size(), 0)

	# Full Audio + MusicArbiter + SetDirector integration: combined preemption, radio pin, pack change, death.
	var events := GameEvents.new()
	var flow := FakeFlow.new()
	var run := FakeRun.new()
	var tuning := Tuning.new()
	tuning.set_option(Tuning.MUSIC_KEY, "ace")
	tuning.set_option(Tuning.WARDEN_FORM_KEY, "form")
	tuning.set_option(Tuning.SET_DIRECTOR_KEY, "on")
	tuning.set_option(Tuning.DECK_KEY, "festival")
	var ctx := FakeCtx.new()
	ctx.events = events
	ctx.flow = flow
	ctx.run = run
	ctx.tuning = tuning
	var audio := Audio.new()
	audio.setup(ctx)
	audio.pack_available = func(_id: String) -> bool: return true
	audio.tune_available = func(_id: String) -> bool: return true
	audio.bake_now()
	events.run_started.emit("sable")
	audio._remixes = {}
	events.stage_entered.emit(1, false)
	audio._flush_flow()
	_pump(audio, audio.engine.bar_len() * 2)
	flow.sealed = true
	events.warden_engaged.emit(1)
	_pump(audio, audio.engine.bar_len() * 2)
	audio._tend_set()
	_t.check("arbiter allows deck pump in warden fight", audio.ace.pump_active())

	# Regression #2 combined: --set-director=on + --deck=festival; spoiling June's answer
	# calls ace.invalidate_trims() without killing active deck shots.
	audio._follow_warden_form(90.0, false, false)
	_pump(audio, audio.engine.bar_len())
	audio.ace.shot_at(audio.ace.clock + 4000, pcm, DeckMoves.TAG_BUILD, 1.0)
	audio._set_answer = "set_answer_test"
	audio._set_answer_at = audio.ace.clock
	audio._focus_until = audio.clock + 2.0
	var epoch_before := audio.ace.trim_epoch
	audio._tend_set()
	_t.check("set-director preemption invalidated trims", audio.ace.trim_epoch > epoch_before and audio._set_answer == "")
	_t.eq("set-director preemption preserved deck shots",
		audio.ace.shots.filter(func(s): return s.tag == DeckMoves.TAG_BUILD).size(), 1)
	audio._focus_until = -1.0

	# Regression #6: radio_play revokes pump immediately (before _tend_set) and clears shots on pack change.
	audio.radio_play("roam-1-1", "roam-1-1", true)
	_t.check("radio_play clears deck pump immediately with no transient window", not audio.ace.pump_active())
	_t.eq("pack change clears shots", audio.ace.shots.size(), 0)
	audio._tend_set()
	_t.check("radio pin keeps deck pump off", not audio.ace.pump_active())
	audio.radio_release()
	_pump(audio, audio.engine.bar_len() * 2)
	audio._tend_set()
	_t.check("unpin restores deck pump in warden fight", audio.ace.pump_active())

	# Death clears both pump and shots immediately.
	audio.ace.shot_at(audio.ace.clock + 4000, pcm, DeckMoves.TAG_BUILD, 1.0)
	audio.ace.shot_at(audio.ace.clock - 10, pcm, DeckMoves.TAG_DROP, 1.0)
	events.player_died.emit()
	audio._flush_flow()
	audio._tend_set()
	_t.check("death clears deck pump", not audio.ace.pump_active())
	_t.eq("death drops unstarted shots", audio.ace.shots.filter(func(s): return s.tag == DeckMoves.TAG_BUILD).size(), 0)
	audio.ace.render(AceSequencer.GAP_RAMP + 4)
	_t.eq("death fades out live shots", audio.ace.shots.size(), 0)

	audio.free()
	events.free()


func _test_viking_preset() -> void:
	# Verify --deck=viking pump depths (0.58 / 0.72 / 0.68), drums untouched, never raises level.
	for sec_name in ["build", "telegraph", "drop"]:
		var depth: float = DeckMoves.PUMP_VIKING[sec_name]
		for stem in ["drums", "bass", "other"]:
			var ref := AceSequencer.new(_manifest())
			var pumped := AceSequencer.new(_manifest())
			ref.solo = [stem]
			pumped.solo = [stem]
			pumped.set_pump(DeckMoves.pump_for("viking"))
			_enter_warden_section(ref, sec_name)
			_enter_warden_section(pumped, sec_name)
			var beat := ref.grid_beat
			var to_beat := ref.next_beat() - ref.clock
			if to_beat > 0:
				ref.render(to_beat)
				pumped.render(to_beat)
			var buf_ref := ref.render(beat * 2)
			var buf_p := pumped.render(beat * 2)
			if stem == "drums":
				_t.check("viking %s drums untouched by pump" % sec_name, buf_ref == buf_p)
				continue
			var exceeded := 0
			for i in buf_ref.size():
				if absf(buf_p[i].x) > absf(buf_ref[i].x) + 1e-5 or absf(buf_p[i].y) > absf(buf_ref[i].y) + 1e-5:
					exceeded += 1
			_t.eq("viking %s %s pump never raises level" % [sec_name, stem], exceeded, 0)
			var got_dip := _measure_gain_near(buf_ref, buf_p, beat + DeckMoves.PUMP_ATTACK_FRAMES)
			_t.check("viking %s %s dip=%.3f want=%.3f" % [sec_name, stem, got_dip, 1.0 - depth],
				absf(got_dip - (1.0 - depth)) <= 0.015, "got=%.4f want=%.4f" % [got_dip, 1.0 - depth])
			var got_rec := _measure_gain_near(buf_ref, buf_p, beat + int(round(0.62 * beat)))
			_t.check("viking %s %s recover=%.3f want=1.0" % [sec_name, stem, got_rec],
				absf(got_rec - 1.0) <= 0.015, "got=%.4f" % got_rec)

	# Verify DeckMoves with style="viking" books viking_build and viking_impact.
	var seq := AceSequencer.new(_manifest())
	var deck := DeckMoves.new()
	_enter_warden_section(seq, "telegraph")
	var to_win := (seq.next_bar() - seq.grid_bar / 2 + 10) - seq.clock
	if to_win > 0:
		seq.render(to_win)
	deck.tend(seq, {"style": "viking", "allow": true, "posture": 90.0, "staggered": false})
	_t.eq("viking telegraph books one build bar", seq.shots.size(), 1)
	_t.check("viking telegraph uses viking_build tier 1",
		seq.shots[0].pcm == DeckFx.viking_build(1, seq.grid_bar, seq.grid_beat))
	seq.follow_guard(100.0, true, false)
	_advance_to_section(seq, "open")
	deck.tend(seq, {"style": "viking", "allow": true, "posture": 100.0, "staggered": true})
	var drop_at := seq.follow_guard(0.0, false, true)
	deck.on_drop(seq, drop_at, "viking")
	var drop_shots := seq.shots.filter(func(s): return s.tag == DeckMoves.TAG_DROP)
	_t.check("viking drop books viking_impact sample-exact on drop",
		drop_shots.any(func(s): return s.at == drop_at and s.pcm == DeckFx.viking_impact()))


func _pump(audio: Audio, frames: int) -> void:
	var until: int = audio.engine.clock + frames
	while audio.engine.clock < until:
		audio._pump(mini(4096, until - audio.engine.clock))


func _test_deck_fx_spectrum_and_peak() -> void:
	DeckFx.clear_cache()
	var bar := 82048
	var beat := 20512
	var cases := [
		["build_tier0", DeckFx.build(0, bar, beat)],
		["build_tier1", DeckFx.build(1, bar, beat)],
		["build_tier2", DeckFx.build(2, bar, beat)],
		["viking_build_tier0", DeckFx.viking_build(0, bar, beat)],
		["viking_build_tier1", DeckFx.viking_build(1, bar, beat)],
		["viking_build_tier2", DeckFx.viking_build(2, bar, beat)],
		["downlifter", DeckFx.downlifter(bar)],
		["swell_beat", DeckFx.swell(beat)],
		["swell_short", DeckFx.swell(beat / 3)],
		["impact", DeckFx.impact()],
		["viking_impact", DeckFx.viking_impact()],
	]
	# Determinism check: calling again after clearing cache yields identical PCM.
	var impact_a := DeckFx.impact()
	var vimpact_a := DeckFx.viking_impact()
	DeckFx.clear_cache()
	var impact_b := DeckFx.impact()
	var vimpact_b := DeckFx.viking_impact()
	_t.check("deck_fx festival impact is deterministic across cache resets", impact_a == impact_b)
	_t.check("deck_fx viking impact is deterministic across cache resets", vimpact_a == vimpact_b)

	# Bounded swell cache check: variable swell lengths reuse one base buffer.
	DeckFx.clear_cache()
	var _s0 := DeckFx.swell(beat)
	var after_one := DeckFx.cache_size()
	for extra_len in [1000, 2345, 5120, 7777, 11111, 15000, 19999, 20500]:
		var _sv := DeckFx.swell(extra_len)
	_t.eq("variable swell lengths do not grow DeckFx cache", DeckFx.cache_size(), after_one)

	for row in cases:
		var label: String = row[0]
		var buf: PackedVector2Array = row[1]
		var peak := 0.0
		for v in buf:
			peak = maxf(peak, maxf(absf(v.x), absf(v.y)))
		_t.check("%s non-empty and peak <= 0.6 (%.3f)" % [label, peak], buf.size() > 0 and peak > 0.001 and peak <= 0.6,
			"size=%d peak=%.4f" % [buf.size(), peak])
		_t.check("%s exact-zero endpoints after filtering" % label,
			buf[0] == Vector2.ZERO and buf[buf.size() - 1] == Vector2.ZERO,
			"first=%s last=%s" % [buf[0], buf[buf.size() - 1]])
		var margin_db := _warning_lane_margin_db(buf)
		_t.check("%s 2-4 kHz lane at least 12 dB under loudest band (%.1f dB)" % [label, margin_db],
			margin_db <= -12.0, "margin=%.2f dB" % margin_db)


# Welch averaged PSD (4096-point Hann windows, 50% overlap) returning 10*log10(lane / max(low, high)).
static func _warning_lane_margin_db(buf: PackedVector2Array) -> float:
	var n := 4096
	var hop := 2048
	var total := buf.size()
	var psd := PackedFloat64Array()
	psd.resize(n / 2 + 1)
	var win := PackedFloat64Array()
	win.resize(n)
	for i in n:
		win[i] = 0.5 * (1.0 - cos(TAU * float(i) / float(n)))
	var windows := 0
	var pos := 0
	while pos < total:
		var re := PackedFloat64Array()
		var im := PackedFloat64Array()
		re.resize(n)
		im.resize(n)
		var avail := mini(n, total - pos)
		for i in avail:
			var v := buf[pos + i]
			re[i] = 0.5 * (v.x + v.y) * win[i]
		_fft_in_place(re, im)
		for k in n / 2 + 1:
			psd[k] += re[k] * re[k] + im[k] * im[k]
		windows += 1
		if pos + n >= total:
			break
		pos += hop
	var df := float(DeckFx.RATE) / float(n)
	var low_sum := 0.0
	var low_cnt := 0
	var lane_sum := 0.0
	var lane_cnt := 0
	var hi_sum := 0.0
	var hi_cnt := 0
	for k in n / 2 + 1:
		var f := float(k) * df
		var p := psd[k] / float(maxi(windows, 1))
		if f >= 200.0 and f < 1800.0:
			low_sum += p
			low_cnt += 1
		elif f >= 2000.0 and f <= 4000.0:
			lane_sum += p
			lane_cnt += 1
		elif f > 4400.0 and f <= 12000.0:
			hi_sum += p
			hi_cnt += 1
	var lane_avg := lane_sum / float(maxi(lane_cnt, 1))
	var rest_avg := maxf(low_sum / float(maxi(low_cnt, 1)), hi_sum / float(maxi(hi_cnt, 1)))
	return 10.0 * log(maxf(lane_avg, 1e-30) / maxf(rest_avg, 1e-30)) / log(10.0)


static func _fft_in_place(re: PackedFloat64Array, im: PackedFloat64Array) -> void:
	var n := re.size()
	var j := 0
	for i in range(1, n):
		var bit := n >> 1
		while (j & bit) != 0:
			j ^= bit
			bit >>= 1
		j ^= bit
		if i < j:
			var tr := re[i]
			re[i] = re[j]
			re[j] = tr
			var ti := im[i]
			im[i] = im[j]
			im[j] = ti
	var length := 2
	while length <= n:
		var ang := -TAU / float(length)
		var wlen_r := cos(ang)
		var wlen_i := sin(ang)
		var i := 0
		while i < n:
			var wr := 1.0
			var wi := 0.0
			var half := length >> 1
			for k in half:
				var u_r := re[i + k]
				var u_i := im[i + k]
				var v_r := re[i + k + half] * wr - im[i + k + half] * wi
				var v_i := re[i + k + half] * wi + im[i + k + half] * wr
				re[i + k] = u_r + v_r
				im[i + k] = u_i + v_i
				re[i + k + half] = u_r - v_r
				im[i + k + half] = u_i - v_i
				var nwr := wr * wlen_r - wi * wlen_i
				wi = wr * wlen_i + wi * wlen_r
				wr = nwr
			i += length
		length <<= 1
