extends SceneTree

# The world effects' sounds (FX-09, Specs.SOUNDS, world_fx_sound.gd): every row names a real set or
# hook and a file in the ambience register, a set's one voice goes to its nearest emitting anchor, a
# pulsed set sounds once per puff, the splash sounds once per hook, the wake follows the ball through
# water, resting silences everything, and each start reaches the cue log at its heard level.
const T := preload("res://tests/support/t.gd")
const Specs := preload("res://src/presentation/world_fx/world_fx_specs.gd")
const WorldFx := preload("res://src/presentation/world_fx/world_fx.gd")
const Anchor := preload("res://src/presentation/world_fx/world_fx_anchor.gd")
const WorldSound := preload("res://src/presentation/world_fx/world_fx_sound.gd")
const Grain := preload("res://src/presentation/world_fx/world_fx_grain.gd")
const MixRows := preload("res://src/presentation/mix_rows.gd")

# The ambience register (tools/ace/world_sfx.py): one-shots peak at -6.1 dBFS like the ambient life,
# loops sit at -26 dBFS RMS. A little slack for 16-bit rounding.
const ONE_SHOT_PEAK_DB := -6.0
const LOOP_RMS_DB := -25.5

var t := T.new("world_fx_sound_test")


# Stands in for audio.gd: the bus offsets it glides and the cue log line.
class FakeAudio:
	extends RefCounted
	var mix_db := {"Ambient": -5.0, "SFX": 0.0}
	var rows: Array = []

	# As audio.gd note_cue: the voice's level plus its bus against the effects bus.
	func note_cue(kind: String, sound: String, volume: float, bus := "SFX") -> void:
		rows.append([kind, sound, volume + float(MixRows.BUS_DB.get(bus, 0.0)) + float(mix_db.get(bus, 0.0))
			- float(MixRows.BUS_DB["SFX"]) - float(mix_db["SFX"]), bus])

	func count(sound: String) -> int:
		return rows.filter(func(r): return r[1] == sound).size()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_table()
	_files()
	_falloff()
	t.check("the sound director takes a world cue (audio.gd note_cue)",
		(load("res://src/presentation/audio.gd") as Script).get_script_method_list().any(func(m): return m["name"] == "note_cue"))
	await _runtime()
	quit(t.verdict())


func _table() -> void:
	for key in Specs.SOUNDS:
		var r: Dictionary = Specs.SOUNDS[key]
		t.check("%s is a set or a hook" % key, Specs.SETS.has(key) or Specs.HOOKS.has(key))
		t.check("%s plays as loop, pulse or once" % key, ["loop", "pulse", "once"].has(r["play"]))
		t.check("%s: once is for hooks, loop and pulse for sets" % key, (r["play"] == "once") == Specs.HOOKS.has(key))
		t.check("%s reaches past its full-level distance" % key, float(r["reach_m"]) > float(r["unit_m"]))
		if r["play"] == "pulse":
			var of := String(r.get("pulse_of", ""))
			t.check("%s puffs with a pulsed spec of its own set" % key, Specs.SETS[key].has(of) and Specs.SPECS[of].has("pulse"), of)
	# The critique's named gaps (E10) and the two found beside them.
	for key in ["ball_splash", "spill_falls", "spill_powerhouse", "landmark_penstock_tower", "spill_flood", "landmark_dam", "spill_wake"]:
		t.check("%s has a sound" % key, Specs.SOUNDS.has(key))


func _files() -> void:
	for key in Specs.SOUNDS:
		var r: Dictionary = Specs.SOUNDS[key]
		var s := WorldSound.stream(key)
		if not t.check("%s loads %s" % [key, WorldSound.path(key)], s != null):
			continue
		t.check("%s loops exactly when its row loops" % key, (s.loop_mode == AudioStreamWAV.LOOP_FORWARD) == (r["play"] == "loop"))
		var pcm := WorldSound.pcm(String(r["file"]))
		t.check("%s is mono 16-bit at 44.1 kHz" % key, pcm != null and not pcm.stereo and pcm.mix_rate == 44100)
		var peak := 0.0
		var sum := 0.0
		var frames := pcm.data.size() / 2
		for i in frames:
			var v := pcm.data.decode_s16(i * 2) / 32768.0
			peak = maxf(peak, absf(v))
			sum += v * v
		var peak_db := linear_to_db(peak)
		var rms_db := linear_to_db(sqrt(sum / frames))
		if r["play"] == "loop":
			t.check("%s loop sits at the ambience level" % key, rms_db <= LOOP_RMS_DB and peak_db <= -9.0, "rms %.1f peak %.1f" % [rms_db, peak_db])
		else:
			t.check("%s one-shot peaks under the ambience ceiling" % key, peak_db <= ONE_SHOT_PEAK_DB, "peak %.1f" % peak_db)
		if r["play"] == "pulse":
			# A puff must end before the next can start, so voices never stack on one roof.
			var beat: Array = Specs.SPECS[r["pulse_of"]]["pulse"]
			var fastest := float(beat[0]) * float(Specs.GRAIN.get(r["pulse_of"], {}).get("pulse", [1.0, 1.0])[0])
			t.check("%s puff is shorter than its fastest pulse" % key, s.get_length() < fastest, "%.2f s vs %.2f s" % [s.get_length(), fastest])


func _falloff() -> void:
	t.near("inside unit_m a voice is at its row level", WorldSound.falloff_db(5.0, 10.0, 100.0), 0.0)
	t.near("twice unit_m is 6 dB down", WorldSound.falloff_db(20.0, 10.0, 100.0), -6.02, 0.01)
	t.check("past reach_m it is silent", WorldSound.falloff_db(120.0, 10.0, 100.0) <= -80.0)


func _runtime() -> void:
	var fake := FakeAudio.new()
	WorldSound.audio = fake
	var stage := Node3D.new()
	root.add_child(stage)
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.current = true
	# The game installs WorldFx before audio.gd makes its buses: the wake still names Ambient.
	var fx := WorldFx.install(stage, 1)
	fx.bind(cam, cam)
	for bus in ["SFX", "Ambient"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	# Godot reads a missing bus back as Master; the name it was given stands once the bus exists.
	t.eq("the wake made before the buses rides Ambient once they exist", fx.wake_sound.bus, &"Ambient")
	await process_frame

	# One flood in two foam pieces, and the weir's falls: two sets, two voices.
	var near_foam := Anchor.make("spill_flood")
	var far_foam := Anchor.make("spill_flood")
	var falls := Anchor.make("spill_falls")
	for a in [near_foam, far_foam, falls]:
		stage.add_child(a)
	near_foam.position = Vector3(0, 0, -10)
	far_foam.position = Vector3(0, 0, -30)
	falls.position = Vector3(20, 0, -20)
	await process_frame
	fx._rank()
	await process_frame
	t.check("the nearer foam piece takes the flood's voice", near_foam.voiced and near_foam.sound.playing)
	t.check("the farther foam piece stays silent", not far_foam.voiced and not far_foam.sound.playing)
	t.check("the falls sound beside the flood", falls.voiced and falls.sound.playing)
	t.check("no voice plays over its row's trim", near_foam.sound.volume_db <= float(Specs.SOUNDS["spill_flood"]["db"]) + 0.001
		and falls.sound.volume_db <= float(Specs.SOUNDS["spill_falls"]["db"]) + 0.001)
	t.check("the loops reach the cue log", fake.count("flood_foam") >= 1 and fake.count("spill_falls") >= 1)
	var logged: Array = fake.rows.filter(func(r): return r[1] == "spill_falls")[0]
	var want := float(Specs.SOUNDS["spill_falls"]["db"]) + WorldSound.falloff_db(cam.global_position.distance_to(falls.global_position), 12.0, 110.0) \
		+ float(MixRows.BUS_DB["Ambient"]) - 5.0 - float(MixRows.BUS_DB["SFX"])
	t.near("a world cue logs its heard level against the effects bus", float(logged[2]), want, 0.05)

	# Calm water is quieter than a climbing flood.
	near_foam.set_level(1.0)
	await process_frame
	var loud: float = near_foam.sound.volume_db
	near_foam.set_level(0.0)
	await process_frame
	t.check("a calming flood's foam drops toward its quiet trim", near_foam.sound.volume_db < loud - 5.0, "%.1f -> %.1f" % [loud, near_foam.sound.volume_db])

	# The voice stays put while the other piece is only a little nearer, and moves once it is clearly nearer.
	far_foam.position = Vector3(0, 0, -9)
	fx._rank()
	t.check("a piece a little nearer does not take the voice", near_foam.voiced and not far_foam.voiced)
	far_foam.position = Vector3(0, 0, -3)
	fx._rank()
	await process_frame
	t.check("a piece clearly nearer takes the voice", far_foam.voiced and far_foam.sound.playing and not near_foam.sound.playing)
	far_foam.position = Vector3(0, 0, -30)
	fx._rank()
	t.check("the voice comes back when it is clearly nearer again", near_foam.voiced and not far_foam.voiced)

	# Drained water hides its foam: the voice moves to the next piece.
	near_foam.visible = false
	fx._rank()
	await process_frame
	t.check("a hidden foam piece falls silent", not near_foam.voiced and not near_foam.sound.playing)
	t.check("the next piece takes the flood's voice", far_foam.voiced and far_foam.sound.playing)
	near_foam.visible = true

	# Resting (title, summary, death) silences the world.
	fx.set_resting(true)
	await process_frame
	t.check("resting silences every anchor", not near_foam.sound.playing and not far_foam.sound.playing and not falls.sound.playing)
	fx.set_resting(false)
	await process_frame
	t.check("back on a stage the world sounds again", falls.sound.playing)
	for a in [near_foam, far_foam, falls]:
		a.queue_free()
	await process_frame

	# The powerhouse breathes once per puff of its steam.
	Grain.run_seed = 0
	var house := Anchor.make("spill_powerhouse")
	stage.add_child(house)
	house.position = Vector3(0, 0, -12)
	await process_frame
	fx._rank()
	var steam: GPUParticles3D = house.emitters.filter(func(p): return p.get_meta("world_fx") == "spill_powerhouse_steam")[0]
	var beat := Grain.pulse(steam)
	var before := fake.count("steam_breath")
	# Two and a half pulse periods, stepped like frames: two puffs start in them.
	var step := 1.0 / 30.0
	var steps := int(2.5 * float(beat[0]) / step)
	house._clock = 0.0
	house._puffing = true
	for i in steps:
		house._process(step)
	t.eq("the roof breathes once per puff over two periods", fake.count("steam_breath") - before, 2)
	house.set_voiced(false)
	var muted := fake.count("steam_breath")
	for i in steps:
		house._process(step)
	t.eq("a roof without the set's voice stays silent", fake.count("steam_breath"), muted)
	house.queue_free()

	# The splash sounds once per hook, louder for a harder entry; resting skips it.
	var splashes := fake.count("spill_splash")
	fx.play("ball_splash", Vector3(0, 0, -6), Color.TRANSPARENT, 1.3)
	var voice := fx.get_node_or_null("WorldSound_ball_splash")
	t.check("a splash plays a voice where the ball went in", voice != null and voice.get_child(0).playing)
	t.eq("a splash logs one start", fake.count("spill_splash") - splashes, 1)
	fx.set_resting(true)
	fx.play("ball_splash", Vector3(0, 0, -6))
	t.eq("a resting world plays no splash", fake.count("spill_splash") - splashes, 1)
	fx.set_resting(false)

	# The wake churns while the ball rolls through water and stops on dry ground.
	fx.steer_wake(Vector3(0, 0.5, -5), 0.0, Vector3(12, 0, 0))
	t.check("rolling through water churns", fx.wake_sound.playing and fake.count("spill_wake") >= 1)
	var fast: float = fx.wake_sound.volume_db
	fx.steer_wake(Vector3(0, 0.5, -5), 0.0, Vector3(4, 0, 0))
	t.check("a slower roll churns quieter", fx.wake_sound.volume_db < fast)
	fx.steer_wake(Vector3(0, 0.5, -5), NAN, Vector3(12, 0, 0))
	t.check("dry ground stops the churn", not fx.wake_sound.playing)

	WorldSound.audio = null
	stage.queue_free()
	await process_frame
