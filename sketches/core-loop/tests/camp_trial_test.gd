extends SceneTree

# Rule: the camp time trial's clock runs from the start line to the finish line through
# checkpoint_0..3 in order, and a skipped checkpoint is no finish. Lap times earn bronze,
# silver or gold from thresholds derived from a measured bot lap. The best lap's path is
# recorded at 10 Hz, kept compactly in the profile and replayed as a ghost. One check runs the
# scripted bot (Intent.Scripted, steering along the authored line toward the next checkpoint)
# around the committed track on the game's own ball at 90 ticks, so the medal thresholds are
# tied to a lap that is run here and not only written in a comment. Physics evidence only;
# it does not qualify how the lap feels.
const T := preload("res://tests/support/t.gd")
const FakeHub := preload("res://tests/support/camp_fake_hub.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Trial := preload("res://src/world/camp_trial.gd")
const Records := preload("res://src/world/camp_records.gd")
const Profile := preload("res://src/core/profile.gd")

var _t := T.new("camp_trial_test")


# A profile with the camp key: what profile.json holds, written to text and read back on each
# access so nothing survives that JSON would drop.
class DiskProfile:
	extends RefCounted
	var text := "{}"
	var can_save := false
	var last_error := ""

	func camp() -> Dictionary:
		return JSON.parse_string(text)

	func set_camp(doc: Dictionary) -> void:
		text = JSON.stringify(doc)

	func save_if_allowed() -> bool:
		return true


func _initialize() -> void:
	Engine.physics_ticks_per_second = 90
	_order()
	_medals()
	_ghost()
	await _lap()
	quit(_t.verdict())


func _order() -> void:
	var run := Trial.Run.new()
	_t.check("an idle clock ignores a start", not run.start())
	run.arm()
	_t.eq("armed", run.state, Trial.State.ARMED)
	_t.check("the clock does not run before the line", not run.checkpoint(0))
	run.start(0.004)
	run.tick(1.0)
	_t.near("the clock runs", run.time, 1.004, 0.0001)
	_t.check("checkpoint 1 first is refused", not run.checkpoint(1))
	_t.check("checkpoint 0 is taken", run.checkpoint(0))
	_t.check("0 again is refused", not run.checkpoint(0))
	_t.check("finish before the last checkpoint is refused", not run.finish())
	_t.check("checkpoint 2 skipping 1 is refused", not run.checkpoint(2))
	_t.check("checkpoint 1", run.checkpoint(1))
	_t.check("checkpoint 3 skipping 2 is refused", not run.checkpoint(3))
	_t.check("finish with 2 and 3 missing is refused", not run.finish())
	_t.eq("still running after a bad finish", run.state, Trial.State.RUNNING)
	_t.check("checkpoint 2", run.checkpoint(2))
	_t.check("checkpoint 3", run.checkpoint(3))
	run.tick(11.996)
	_t.check("finish after all four", run.finish(0.002))
	_t.eq("finished", run.state, Trial.State.DONE)
	_t.eq("lap time in ms, finish lead taken off", run.ms(), 12998)
	run.tick(5.0)
	_t.eq("a finished clock stops", run.ms(), 12998)
	_t.eq("four splits", run.splits.size(), 4)

	var skipped := Trial.Run.new()
	skipped.arm()
	skipped.start()
	for i in [0, 2, 3]:
		skipped.checkpoint(i)
	_t.check("a lap that skipped checkpoint 1 does not finish", not skipped.finish())

	# The line: behind to ahead only, and only across the track.
	var line := Vector3(-16, 1, 8)
	_t.check("crossing heading -Z", Trial.crossed(Vector3(-16, 1, 8.5), Vector3(-16, 1, 7.5), line) >= 0.0)
	_t.near("the crossing's lead", Trial.crossed(Vector3(-16, 1, 8.5), Vector3(-16, 1, 7.5), line), 0.5)
	_t.check("heading +Z is not a crossing", Trial.crossed(Vector3(-16, 1, 7.5), Vector3(-16, 1, 8.5), line) < 0.0)
	_t.check("beside the track is not a crossing", Trial.crossed(Vector3(0, 1, 8.5), Vector3(0, 1, 7.5), line) < 0.0)


func _medals() -> void:
	_t.eq("gold at the reference", Trial.medal_for(13000), "gold")
	_t.eq("just over gold is silver", Trial.medal_for(13001), "silver")
	_t.eq("silver edge", Trial.medal_for(15000), "silver")
	_t.eq("bronze", Trial.medal_for(15001), "bronze")
	_t.eq("bronze edge", Trial.medal_for(17500), "bronze")
	_t.eq("slower is no medal", Trial.medal_for(17501), "")
	_t.eq("no time is no medal", Trial.medal_for(0), "")
	_t.check("silver is the reference x 1.15 to the half second", absf(Trial.SILVER_MS - Trial.GOLD_MS * 1.15) <= 250.0)
	_t.check("bronze is the reference x 1.35 to the half second", absf(Trial.BRONZE_MS - Trial.GOLD_MS * 1.35) <= 250.0)
	_t.eq("gold lights three lamps", Trial.lamps_for("gold"), ["bronze", "silver", "gold"])
	_t.eq("silver lights two", Trial.lamps_for("silver"), ["bronze", "silver"])
	_t.eq("no medal lights none", Trial.lamps_for(""), [])
	_t.eq("time format", Trial.format_ms(58200), "0:58.20")
	_t.eq("time format over a minute", Trial.format_ms(75040), "1:15.04")


func _ghost() -> void:
	# Sampling: one point per 0.1 s of lap time, then the finish.
	var rec := Trial.Recorder.new()
	rec.begin(Vector3.ZERO)
	var time := 0.0
	for i in 270:
		time += 1.0 / 90.0
		rec.tick(time, Vector3(time * 10.0, 1.0, -time))
	rec.end(Vector3(30, 1, -3))
	_t.check("3 s at 10 Hz is 30 samples after the first, plus the finish", rec.points.size() in [31, 32], str(rec.points.size()))
	_t.near("sample 10 is a second in", rec.points[10].x, 10.0, 0.15)

	# Compact encoding and the round trip through profile text.
	var path := PackedVector3Array()
	for i in 400:
		path.append(Vector3(sin(i * 0.05) * 16.0, 1.0 + 0.5 * cos(i * 0.2), -i * 0.31))
	var enc := Records.encode_ghost(path)
	_t.eq("encodes at 10 Hz", enc["hz"], 10)
	_t.eq("one delta triple per later sample", enc["d"].split(",").size(), 399 * 3)
	var back := Records.decode_ghost(JSON.parse_string(JSON.stringify(enc)))
	_t.eq("round trip keeps every sample", back.size(), path.size())
	var worst := 0.0
	for i in path.size():
		worst = maxf(worst, back[i].distance_to(path[i]))
	_t.check("round trip is within a centimetre", worst <= 0.0087, "worst %.4f m" % worst)
	var biggest := 0
	for v in enc["d"].split(","):
		biggest = maxi(biggest, absi(v.to_int()))
	_t.check("deltas stay small integers", biggest < 200, "largest %d cm" % biggest)
	_t.eq("a path past the cap is not stored", Records.encode_ghost(_long(Records.GHOST_MAX_SAMPLES + 1)), {})
	_t.eq("a path at the cap is", Records.encode_ghost(_long(Records.GHOST_MAX_SAMPLES))["d"].split(",").size(), (Records.GHOST_MAX_SAMPLES - 1) * 3)
	_t.eq("garbage decodes to nothing", Records.decode_ghost({"p0": [0, 0], "d": ""}).size(), 0)
	_t.eq("a ragged delta list decodes to nothing", Records.decode_ghost({"p0": [0, 0, 0], "d": "1,2"}).size(), 0)
	_t.eq("a missing ghost decodes to nothing", Records.decode_ghost({}).size(), 0)

	# Playback.
	var line := PackedVector3Array([Vector3.ZERO, Vector3(10, 0, 0), Vector3(10, 0, 10)])
	_t.check("start of lap", Trial.ghost_at(line, 0.0, 4.0).is_equal_approx(Vector3.ZERO))
	_t.check("halfway through the lap is the middle point", Trial.ghost_at(line, 2.0, 4.0).is_equal_approx(Vector3(10, 0, 0)))
	_t.check("a quarter in is between", Trial.ghost_at(line, 1.0, 4.0).is_equal_approx(Vector3(5, 0, 0)))
	_t.check("past the end holds the finish", Trial.ghost_at(line, 9.0, 4.0).is_equal_approx(Vector3(10, 0, 10)))

	# Records through a profile that has the camp key: best only, ghost kept, survives text.
	var profile := DiskProfile.new()
	var records := Records.new(profile)
	_t.eq("no best yet", records.trial_best_ms(), 0)
	_t.check("a first lap is a best", records.submit_trial(15200, path))
	_t.eq("best stored", records.trial_best_ms(), 15200)
	_t.check("a slower lap is not", not records.submit_trial(15900, line))
	_t.eq("and the ghost is still the first", records.ghost().size(), path.size())
	_t.check("a faster lap replaces it", records.submit_trial(14100, line))
	_t.eq("new ghost", records.ghost().size(), 3)
	var reread := Records.new(profile)
	_t.eq("a second reader sees the best", reread.trial_best_ms(), 14100)
	_t.check("and the ghost", reread.ghost()[1].is_equal_approx(Vector3(10, 0, 0)))
	_t.check("a skee best sits beside it", records.submit_skee(120) and Records.new(profile).skee_best() == 120)
	_t.eq("the trial best is untouched by it", Records.new(profile).trial_best_ms(), 14100)

	# The real profile, once it carries the camp key; before that, records fall back and the
	# check is skipped.
	var real := Profile.new("user://test-camp-trial-%d.json" % OS.get_process_id())
	if real.has_method("camp"):
		var stored := Records.new(real)
		stored.submit_trial(14100, line)
		_t.eq("the real profile holds the best", Records.new(real).trial_best_ms(), 14100)
		_t.eq("and the ghost", Records.new(real).ghost().size(), 3)
	else:
		print("[real profile] profile.gd has no camp key yet; the in-memory fallback is used -> SKIP")
		var fallback := Records.new(real)
		_t.check("without the key the trial best lasts the session", fallback.submit_trial(14100, line) and fallback.trial_best_ms() == 14100)
		_t.check("and the skee best is kept in stats", fallback.submit_skee(90) and real.stat(Records.SKEE_STAT) == 90.0)


func _long(n: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(n)
	return out


# The node end to end with the real ball and a bot.
func _lap() -> void:
	var game = Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.world.set_physics_process(false)
	var source := Intent.Scripted.new()
	game.player.source = source
	game.player.set_frozen(false)

	var hub := FakeHub.new()
	root.add_child(hub)
	await physics_frame
	hub.ball = game.player
	var origin := Vector3(500, 60, 500)
	hub.place("camp_trial_track", origin)
	hub.place("camp_trial_arch", hub.socket("camp_trial_track", "arch").origin)
	var disk := DiskProfile.new()
	var records := Records.new(disk)
	var trial := Trial.new()
	hub.root.add_child(trial)
	trial.setup(hub, records)
	_t.eq("one station at the start socket", hub.stations.size(), 1)
	_t.check("it sits on the start socket", hub.stations[0]["at"].is_equal_approx(hub.socket("camp_trial_track", "start").origin))
	_t.check("before a lap the dotted guide line shows", trial.guide.visible)
	_t.check("and the ghost does not", not trial.ghost_mesh.visible)
	_t.check("no lamp is lit", not trial.lamp_lit("bronze") and not trial.lamp_lit("gold"))
	_t.eq("the guide line is the 32 authored points", trial.guide.multimesh.instance_count, 32)
	_t.check("the timer reads amber", trial.timer_label.modulate.is_equal_approx(Color("e5a044")))

	hub.stations[0]["on_press"].call()
	_t.eq("a press arms the clock", trial.run.state, Trial.State.ARMED)
	var line: Vector3 = hub.socket("camp_trial_track", "start").origin
	var ghosts := []
	for i in 32:
		ghosts.append(hub.socket("camp_trial_track", "ghost_%02d" % i).origin)
	var body: RigidBody3D = game.player.body()
	var near := 0
	var seconds := 0.0
	var ticks := 0
	var started := false
	var skipped_finish := false
	while ticks < 90 * 40 and trial.run.state != Trial.State.DONE:
		await physics_frame
		ticks += 1
		var p := body.global_position
		if trial.run.state == Trial.State.RUNNING:
			started = true
		var best := 1e9
		var pick := near
		for j in range(near, mini(near + 6, 32)):
			var d2 := Vector2(p.x - ghosts[j].x, p.z - ghosts[j].z).length()
			if d2 < best:
				best = d2
				pick = j
		near = pick
		var target: Vector3 = ghosts[near + 2] if near + 2 < 32 and trial.run.next < Trial.CHECKPOINTS else line + Vector3(0, 0, -20)
		var aim := target - p
		aim.y = 0.0
		aim = aim.normalized()
		var flat := body.linear_velocity
		flat.y = 0.0
		var basis: Basis = game.player.drive_basis
		source.hold = {
			"move": Vector2(aim.dot(basis.x), -aim.dot(basis.z)),
			"brake_held": flat.length() > 6.0 and flat.normalized().dot(aim) < 0.9,
		}
	_t.check("the bot started the clock at the line", started)
	_t.eq("the bot lap finished", trial.run.state, Trial.State.DONE)
	var ms: int = trial.last_result.get("ms", 0)
	print("bot lap %d ms, medal %s" % [ms, trial.last_result.get("medal", "")])
	_t.check("the bot lap is within the reference band (12 to 15 s)", ms >= 12000 and ms <= 15000, "%d ms" % ms)
	_t.eq("all four checkpoints were taken in order", trial.run.splits.size(), 4)
	_t.check("the splits rise", trial.run.splits[0] < trial.run.splits[1] and trial.run.splits[2] < trial.run.splits[3])
	_t.check("the bot lap earns a medal", trial.last_result["medal"] in ["gold", "silver"], trial.last_result["medal"])
	_t.check("the lap became the best", trial.last_result["best"])
	_t.eq("the best is saved", records.trial_best_ms(), ms)
	var saved := records.ghost()
	_t.check("the ghost holds about 10 samples a second", absi(saved.size() - (ms / 100 + 2)) <= 2, "%d samples for %d ms" % [saved.size(), ms])
	var line_local: Vector3 = hub.piece("camp_trial_track").global_transform.affine_inverse() * line
	_t.check("and starts at the line", saved[0].distance_to(line_local) < 1.5, "%s vs %s" % [saved[0], line_local])
	_t.check("the timer shows the time", trial.timer_label.text.begins_with(Trial.format_ms(ms)), trial.timer_label.text)
	var lit := 0
	for medal in trial.lamps:
		lit += 1 if trial.lamp_lit(medal) else 0
	_t.eq("the earned lamps are lit", lit, Trial.lamps_for(trial.last_result["medal"]).size())
	_t.check("the disk text stays small", disk.text.length() < 40000, "%d bytes" % disk.text.length())

	# A new session: the ghost is replayed, the guide line is gone and the lamps stay lit.
	trial.run.state = Trial.State.IDLE
	var again := Trial.new()
	hub.root.add_child(again)
	again.setup(hub, Records.new(disk))
	_t.check("the guide line is gone once a lap exists", not again.guide.visible)
	_t.check("the best lap's lamps are lit on load", again.lamp_lit("bronze"))
	again.arm()
	_t.check("arming shows the ghost at the line", again.ghost_mesh.visible)
	_t.check("the ghost is a translucent mesh", again.ghost_mesh.material_override.albedo_color.a < 0.5)
	hub.queue_free()
	game.queue_free()
