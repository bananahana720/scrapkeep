extends SceneTree

# The four kill-first specials' cues (combat/special_cues.gd, the hook; audio.gd for the
# sound, machine_fx.gd for the effects, special_rig.gd for the clip). Andrew, 17 Oct 00:45Z:
# each special has a presence loop, a wind-up tell whose sound starts on the frame its
# picture does, and a death sting. This pins, per special: all three cues named and backed
# by a sound file, the presence loop on the body, one SpecialCues.tell() starting the tell's
# sound and effects once each on one process frame, the death sting with its effects on the
# died frame, and the two-nearest presence cap. Then the real Foreman's horn and Linker's
# brace each sound their tell exactly once.
const T := preload("res://tests/support/t.gd")
const SpecialCues := preload("res://src/combat/special_cues.gd")
const MachineFx := preload("res://src/presentation/machine_fx.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Density := preload("res://src/presentation/density.gd")

var t := T.new("special_cues_test")


# A body as a behaviour builds it, with no special_tell of its own: attach() gives it one.
class Body extends Node3D:
	signal died(at: Vector3, scrap_value: int)
	var kind := "chaser"
	var faction := "fleet"
	var half_height := 1.2
	var rammed_at_ground := false
	func cable_ends() -> Array:
		return [global_position, global_position + Vector3(6, 3, 0)]


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _body(game, special: String, at: Vector3) -> Body:
	var body := Body.new()
	body.kind = special
	game.ctx.root.add_child(body)
	body.global_position = at
	SpecialCues.attach(body)
	game.ctx.events.enemy_spawned.emit(body, body.kind)
	return body


func _count(audio, sound: String) -> int:
	return audio.cue_log.filter(func(r: Array): return r[1] == sound and r[2] == "now").size()


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
	var fx = game.presentation.machine_fx
	Density.live().force(1.0)

	var ball: Vector3 = game.player.ball_position()
	var slot := 0
	for special in SpecialCues.SPECIALS:
		slot += 1
		var cues: Dictionary = SpecialCues.cues(special)
		var ids: Array = []
		for cue in SpecialCues.CUES:
			ids.append_array(cues[cue])
		t.check("%s names a presence, a tell and a death sound" % special,
			SpecialCues.CUES.all(func(c: String): return not (cues[c] as Array).is_empty()) and ids.all(func(id: String): return id != ""))
		var silent := ids.filter(func(id: String): return SfxBank.stream(id) == null)
		t.check("%s: every cue has its sound file" % special, silent.is_empty(), "missing %s" % str(silent))
		var row: Dictionary = MachineFx.SPECIALS[special]
		t.check("%s has presence, tell and death effects" % special, row.has("presence") and row.has("tell")
			and (row["tell_word"] as String) != "" and (SpecialCues.SPECIALS[special]["breaks"] as Array).all(func(m: String): return row.has(m)))

		var body := _body(game, special, ball + Vector3(-10 - 4 * slot, 0, 6))
		var presence: Node = body.get_node_or_null("SpecialPresence")
		t.check("%s: its presence loop rides the body" % special, audio._specials.has(body.get_instance_id())
			and presence != null and (presence.stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED)

		await _frames(2)
		var tell: String = special + "_tell"
		var fx_before: int = fx.spawned.get(tell, 0)
		var tell_spec: String = (MachineFx.SPECIALS[special]["tell"] as Dictionary).keys()[0]
		var spec_before: int = fx.spawned.get(tell_spec, 0)
		var sound_before := _count(audio, tell)
		var frame := Engine.get_process_frames()
		var said: String = SpecialCues.tell(body)
		t.eq("%s: tell() names its sound" % special, said, tell)
		t.check("%s: the tell's effects fire once" % special, fx.spawned.get(tell, 0) == fx_before + 1
			and fx.spawned.get(tell_spec, 0) > spec_before, "%s %d -> %d" % [tell_spec, spec_before, fx.spawned.get(tell_spec, 0)])
		t.check("%s: the tell's sound starts now, once" % special, _count(audio, tell) == sound_before + 1
			and audio.cue_log.back()[1] == tell, str(audio.cue_log.back()))
		t.check("%s: picture and sound share the start frame" % special, Engine.get_process_frames() == frame)

		await _frames(2)
		if special == "splitter":
			body.rammed_at_ground = true
		var death: String = special + "_" + SpecialCues.break_moment(body)
		var fx_died: int = fx.spawned.get(death, 0)
		var sting_before := _count(audio, death)
		body.died.emit(body.global_position, 6)
		t.check("%s: the death sting plays with its effects on the died frame" % special, _count(audio, death) == sting_before + 1
			and fx.spawned.get(death, 0) == fx_died + 1, death)
		t.check("%s: the presence loop stops on death" % special, not audio._specials.has(body.get_instance_id()))
		body.queue_free()
		await _frames(1)

	var clean := Body.new()
	clean.kind = "splitter"
	t.eq("a Splitter killed from above dies clean", SpecialCues.break_moment(clean), "break_clean")
	clean.set_meta("split", true)
	t.eq("a split meta also reads as rammed", SpecialCues.break_moment(clean), "break_split")
	clean.free()
	var plain := Body.new()
	t.eq("an ordinary enemy is no special", SpecialCues.tell(plain), "")
	plain.free()
	var unheard := Body.new()
	unheard.kind = "linker"
	game.ctx.root.add_child(unheard)
	t.eq("a special nobody attached before it spawned refuses the tell", SpecialCues.tell(unheard), "")
	unheard.free()

	# At most two presence loops at once, nearest first.
	var near := _body(game, "linker", ball + Vector3(6, 0, 0))
	var mid := _body(game, "dispatcher", ball + Vector3(0, 0, 14))
	var far := _body(game, "splitter", ball + Vector3(30, 0, 0))
	audio._tend_specials()
	var heard: Array = audio.specials_heard
	t.check("two nearest presences are heard, the far one waits", heard.size() == 2 and near.get_instance_id() in heard
		and mid.get_instance_id() in heard and not far.get_instance_id() in heard, str(heard))
	for b in [near, mid, far]:
		b.died.emit(b.global_position, 6)
		b.queue_free()
	await _frames(1)

	# The real bodies: one horn, one brace, one tell sound each.
	var spawner = game.ctx.spawner
	var foreman: Node3D = spawner.spawn_enemy("foreman", game.ctx.terrain.drop_point(ball.x - 14, ball.z + 4, 1.8))
	await _frames(2)
	var horns := _count(audio, "foreman_tell")
	var fx_horns: int = fx.spawned.get("foreman_tell", 0)
	foreman._horn()
	t.check("the Foreman's horn sounds its tell once", _count(audio, "foreman_tell") == horns + 1 and fx.spawned.get("foreman_tell", 0) == fx_horns + 1,
		"sound %d, effects %d" % [_count(audio, "foreman_tell") - horns, fx.spawned.get("foreman_tell", 0) - fx_horns])
	spawner.spawn_enemy("plated_brute", game.ctx.terrain.drop_point(ball.x + 10, ball.z, 1.8))
	audio.cue_log.clear()
	var linker: Node3D = spawner.spawn_enemy("linker", game.ctx.terrain.drop_point(ball.x + 16, ball.z + 5, 1.8))
	var spawn_cues: Array = audio.cue_log.filter(func(r: Array): return r[1] == "linker_spawn")
	var spawn_cue: Array = spawn_cues.front() if not spawn_cues.is_empty() else []
	t.check("the real Linker's spawn answer is queued to the beat", spawn_cue.size() > 2 and spawn_cue[2] == "beat", str(spawn_cue))
	var loop := linker.get_node_or_null("SpecialPresence") as AudioStreamPlayer3D
	t.check("the real Linker carries a looping presence player in the world", loop != null and loop.is_inside_tree()
		and (loop.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD and loop.global_position.is_equal_approx(linker.global_position))
	await _frames(10)
	var braces := _count(audio, "linker_tell")
	var fx_braces: int = fx.spawned.get("linker_tell", 0)
	linker._brace()
	t.check("the Linker's brace sounds its tell once", _count(audio, "linker_tell") == braces + 1 and fx.spawned.get("linker_tell", 0) == fx_braces + 1,
		"sound %d, effects %d" % [_count(audio, "linker_tell") - braces, fx.spawned.get("linker_tell", 0) - fx_braces])
	var ends: Array = linker.cable_ends()
	t.check("the Linker's cable_ends are two distinct world points", ends.size() == 2 and ends[0] is Vector3 and ends[1] is Vector3
		and (ends[0] as Vector3).distance_to(ends[1]) > 0.5, str(ends))
	var after_brace := _count(audio, "linker_tell")
	linker.cut_cable("struck")
	t.check("cutting the cable sounds no second tell", _count(audio, "linker_tell") == after_brace)
	var broken := _count(audio, "linker_break")
	var linker_id := linker.get_instance_id()
	linker.take_damage(99999.0)
	await _frames(2)
	t.check("the real Linker's death sounds its break once and stops its loop", _count(audio, "linker_break") == broken + 1
		and not audio._specials.has(linker_id))

	Density.live().force(0.0)
	game.free()
	quit(t.verdict())
