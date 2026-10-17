extends SceneTree

# The four kill-first specials' cues (combat/special_cues.gd, presentation/special_voice.gd,
# presentation/machine_fx.gd). Andrew, 17 Oct 00:45Z: each special has a presence loop, a
# wind-up tell whose sound starts on the frame its picture does, and a death sting. This
# pins, per special: all three cues named for picture and sound, the presence loop on the
# body, the tell's clip, effects and sound starting inside the one SpecialCues.tell() call on
# one process frame, the death sting with its effects on the died frame, and the two-nearest
# presence cap. Cue files that have not landed are stood in for by a silent stream and listed;
# the audio gate (PR #41) counts them as placeholders.
const T := preload("res://tests/support/t.gd")
const SpecialCues := preload("res://src/combat/special_cues.gd")
const MachineFx := preload("res://src/presentation/machine_fx.gd")
const Density := preload("res://src/presentation/density.gd")

var t := T.new("special_cues_test")


# A body as a behaviour builds it, with no special_tell of its own: attach() gives it one.
class Body extends Node3D:
	signal died(at: Vector3, scrap_value: int)
	var kind := "chaser"
	var faction := "fleet"
	var half_height := 1.2
	func cable_ends() -> Array:
		return [global_position, global_position + Vector3(6, 3, 0)]


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


static func _silent() -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = 48000
	s.data = PackedByteArray()
	s.data.resize(48000 * 2)
	return s


func _body(game, special: String, at: Vector3) -> Body:
	var body := Body.new()
	if special == "foreman":
		body.kind = "lobber"
		body.set_meta("elite_affix", "foreman")
	else:
		body.kind = special
	var player := AnimationPlayer.new()
	var lib := AnimationLibrary.new()
	var a := Animation.new()
	a.length = 0.9
	lib.add_animation(SpecialCues.SPECIALS[special]["tell_clip"], a)
	player.add_animation_library("", lib)
	body.add_child(player)
	game.ctx.root.add_child(body)
	body.global_position = at
	SpecialCues.attach(body)
	game.ctx.events.enemy_spawned.emit(body, body.kind)
	return body


func _rows(voice, sound: String) -> Array:
	return voice.heard.filter(func(r: Array): return r[3] == sound)


func _run() -> void:
	var game = preload("res://src/game.gd").new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.flow.press_start()
	game.flow.choose_class(0)
	var waited := 0
	while not game.flow.in_stage() and waited < 120:
		waited += 1
		await physics_frame
	game.ctx.calm = true
	var audio = game.presentation.audio
	audio.bake_now()
	var voice = game.presentation.special_voice
	var fx = game.presentation.machine_fx
	t.check("presentation builds the special voice", voice != null and voice.audio == audio)
	Density.live().force(1.0)

	var missing: Array = voice.missing()
	print("special cue files not landed yet (%d): %s" % [missing.size(), ", ".join(missing)])
	for id in missing:
		voice._streams[id] = _silent()

	var ball: Vector3 = game.player.ball_position()
	var slot := 0
	for special in SpecialCues.SPECIALS:
		slot += 1
		var cues: Dictionary = SpecialCues.cues(special)
		t.check("%s names a presence, a tell and a death sound" % special,
			SpecialCues.CUES.all(func(c: String): return not (cues[c] as Array).is_empty() and (cues[c] as Array).all(func(id: String): return id != "")))
		var row: Dictionary = MachineFx.SPECIALS[special]
		t.check("%s has presence, tell and death effects" % special, row.has("presence") and row.has("tell")
			and (row["tell_word"] as String) != "" and (SpecialCues.SPECIALS[special]["breaks"] as Array).all(func(m: String): return row.has(m)))

		var body := _body(game, special, ball + Vector3(-10 - 4 * slot, 0, 6))
		t.check("%s: presence loop starts on the body" % special, voice._presences.has(body.get_instance_id())
			and body.get_node("PresenceVoice").playing and _rows(voice, special + "_presence").size() == 1)
		var answer := _rows(voice, special + "_spawn")
		t.check("%s: its spawn answer waits for the beat" % special, not answer.is_empty() and answer.back()[4] == "beat")

		await _frames(2)
		var fx_before: int = fx.spawned.get(special + "_tell", 0)
		var tell_spec: String = (MachineFx.SPECIALS[special]["tell"] as Dictionary).keys()[0]
		var spec_before: int = fx.spawned.get(tell_spec, 0)
		var frame := Engine.get_process_frames()
		var said: String = SpecialCues.tell(body)
		var clip := String(SpecialCues.SPECIALS[special]["tell_clip"])
		var anim: AnimationPlayer = body.get_child(0)
		var sound_row: Array = _rows(voice, special + "_tell").back() if not _rows(voice, special + "_tell").is_empty() else []
		t.eq("%s: tell() names its sound" % special, said, special + "_tell")
		t.check("%s: the tell clip starts from its first frame" % special, anim.current_animation == clip and anim.current_animation_position == 0.0,
			"%s at %.3f" % [anim.current_animation, anim.current_animation_position])
		t.check("%s: the tell's effects fire" % special, fx.spawned.get(special + "_tell", 0) == fx_before + 1
			and fx.spawned.get(tell_spec, 0) > spec_before, "%s %d -> %d" % [tell_spec, spec_before, fx.spawned.get(tell_spec, 0)])
		t.check("%s: the tell's sound starts now" % special, not sound_row.is_empty() and sound_row[4] == "now"
			and audio.cue_log.back()[1] == special + "_tell" and audio.cue_log.back()[2] == "now", str(sound_row))
		t.check("%s: picture and sound share the start frame" % special, not sound_row.is_empty() and sound_row[0] == frame
			and Engine.get_process_frames() == frame, "sound %s, call %d" % [str(sound_row[0]) if not sound_row.is_empty() else "-", frame])

		await _frames(2)
		var death: String = SpecialCues.break_moment(body)
		if special == "splitter":
			body.set_meta("split", true)
			death = SpecialCues.break_moment(body)
		var fx_died: int = fx.spawned.get(special + "_" + death, 0)
		frame = Engine.get_process_frames()
		body.died.emit(body.global_position, 6)
		var sting: Array = _rows(voice, special + "_" + death).back() if not _rows(voice, special + "_" + death).is_empty() else []
		t.check("%s: the death sting plays with its effects on the died frame" % special, not sting.is_empty() and sting[4] == "now"
			and sting[0] == frame and fx.spawned.get(special + "_" + death, 0) == fx_died + 1, str(sting))
		t.check("%s: the presence loop stops on death" % special, not voice._presences.has(body.get_instance_id()))
		body.queue_free()
		await _frames(1)

	t.eq("a rammed Splitter splits", SpecialCues.break_moment(_meta_body("splitter", true)), "break_split")
	t.eq("a Splitter killed from above dies clean", SpecialCues.break_moment(_meta_body("splitter", false)), "break_clean")
	t.eq("an ordinary enemy is no special", SpecialCues.tell(_meta_body("chaser", false)), "")
	var unheard := Body.new()
	unheard.kind = "linker"
	game.ctx.root.add_child(unheard)
	t.eq("a special nobody attached before it spawned refuses the tell", SpecialCues.tell(unheard), "")
	unheard.free()
	var late := Body.new()
	late.kind = "dispatcher"
	game.ctx.root.add_child(late)
	game.ctx.events.enemy_spawned.emit(late, late.kind)
	var late_fx: int = fx.spawned.get("dispatcher_tell", 0)
	SpecialCues.tell(late)
	t.check("a body that skipped attach() still gets picture and sound", fx.spawned.get("dispatcher_tell", 0) == late_fx + 1
		and _rows(voice, "dispatcher_tell").back()[0] == Engine.get_process_frames())
	late.died.emit(late.global_position, 6)
	late.free()

	# At most two presence loops at once, nearest first.
	var near := _body(game, "linker", ball + Vector3(6, 0, 0))
	var mid := _body(game, "dispatcher", ball + Vector3(0, 0, 14))
	var far := _body(game, "splitter", ball + Vector3(30, 0, 0))
	voice._rank()
	var heard: Array = voice.heard_presences()
	t.check("two nearest presences are heard, the far one waits", heard.size() == 2 and near in heard and mid in heard and not far in heard,
		"heard %s of near %s mid %s far %s" % [heard.map(func(e): return e.kind), near.kind, mid.kind, far.kind])
	near.died.emit(near.global_position, 6)
	near.queue_free()
	await _frames(1)
	voice._rank()
	heard = voice.heard_presences()
	t.check("when one dies the next nearest is heard", heard.size() == 2 and far in heard)
	game.ctx.events.stage_content_cleared.emit("test")
	t.check("clearing the stage stops every presence", voice._presences.is_empty())

	Density.live().force(0.0)
	game.free()
	quit(t.verdict())


func _meta_body(kind: String, split: bool) -> Body:
	var b := Body.new()
	b.kind = kind
	b.set_meta("split", split)
	b.free.call_deferred()
	return b
