extends SceneTree
# Review probe core (not a repo test). Parts override PART.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const StageLocks := preload("res://src/world/stage_locks.gd")

const SNAG_S := 0.2
var PART := ""
var _game
var _rows := []


func _initialize() -> void:
	_run.call_deferred()


func _boot() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	await process_frame
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	for i in 120:
		await physics_frame
	_game.ctx.calm = true
	_game.run.set_max_hp(99999.0)


func _out(s: String) -> void:
	print("PROBE ", PART, " ", s)
	var path := ProjectSettings.globalize_path("res://").path_join("../../artifacts/local/e105_%s.log" % PART)
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	f.seek_end()
	f.store_line(s)
	f.close()


func _run() -> void:
	seed(1)
	StageLocks.active = false
	await _boot()
	print("cruise ", _game.player.tuning.tier_cruise())
	await _part()
	StageLocks.active = true
	quit(0)


func _part() -> void:
	pass


func _h(x: float, z: float) -> float:
	return _game.ctx.terrain.height(x, z)


# Max rise between neighbouring 2 m samples in a box, both axes.
func _steps(x0: int, x1: int, z0: int, z1: int) -> void:
	var worst := 0.0
	var at := Vector2.ZERO
	var x := x0
	while x <= x1:
		var z := z0
		while z <= z1:
			for d in [Vector2(2, 0), Vector2(0, 2)]:
				var dh := absf(_h(x + d.x, z + d.y) - _h(x, z))
				if dh > worst:
					worst = dh
					at = Vector2(x, z)
			z += 2
		x += 2
	_out("steps box x %d..%d z %d..%d: worst rise %.3f m over 2 m at %s" % [x0, x1, z0, z1, worst, str(at)])


func _profile(label: String, a: Vector2, b: Vector2, n: int) -> void:
	var s := ""
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		s += "%.1f " % _h(p.x, p.y)
	_out("profile %s %s->%s: %s" % [label, str(a), str(b), s])


func _roll(name: String, at: Vector2, dir: Vector2, k: float, goal: float, ride_s := 5.0) -> Dictionary:
	dir = dir.normalized()
	var cruise: float = _game.player.tuning.tier_cruise()
	_game.world.ride = null
	for i in 3:
		await physics_frame
	_game.world.ride = null
	_game.player.set_velocity_now(Vector3.ZERO, "probe")
	_game.player.body().global_position = _game.ctx.terrain.drop_point(at.x, at.y, 1.0)
	for i in 2:
		await physics_frame
	_game.player.body().global_position = _game.ctx.terrain.drop_point(at.x, at.y, 1.0)
	_game.player.set_velocity_now(Vector3(dir.x, 0.0, dir.y) * cruise * k, "probe")
	var span := maxi(1, roundi(SNAG_S * Engine.physics_ticks_per_second))
	var hist: Array[float] = []
	var snag := ""
	var low_snag := ""
	var worst_ratio := INF
	var worst := ""
	var reach := -INF
	var minspeed := INF
	var t := 0.0
	var tick := 0
	var stall := ""
	var zipped := ""
	while t < ride_s:
		await physics_frame
		tick += 1
		t += 1.0 / float(Engine.physics_ticks_per_second)
		var ball: Vector3 = _game.player.ball_position()
		var v: Vector3 = _game.player.state.velocity
		var flat := Vector2(v.x, v.z).length()
		hist.append(flat)
		if hist.size() > span + 1:
			hist.pop_front()
		if hist.size() == span + 1:
			var r := flat / maxf(hist[0], 0.001)
			if hist[0] > 0.6 * cruise:
				if r < worst_ratio:
					worst_ratio = r
					worst = "%.2f->%.2f@(%.1f,%.1f,%.1f)" % [hist[0] / cruise, flat / cruise, ball.x, ball.y, ball.z]
				if snag == "" and r <= 0.5:
					snag = "(%.1f, %.1f, %.1f) %.2f -> %.2f x" % [ball.x, ball.y, ball.z, hist[0] / cruise, flat / cruise]
			elif hist[0] > 0.3 * cruise and low_snag == "" and r <= 0.5:
				low_snag = "(%.1f, %.1f, %.1f) %.2f -> %.2f x" % [ball.x, ball.y, ball.z, hist[0] / cruise, flat / cruise]
		if tick > 10:
			minspeed = minf(minspeed, flat / cruise)
		if stall == "" and tick > 10 and flat < 0.08 * cruise:
			stall = "(%.1f, %.1f, %.1f)" % [ball.x, ball.y, ball.z]
		if _game.world.ride != null and zipped == "":
			zipped = "(%.1f, %.1f, %.1f)" % [ball.x, ball.y, ball.z]
		reach = maxf(reach, Vector2(ball.x, ball.z).dot(dir))
		if reach >= goal:
			break
	var end: Vector3 = _game.player.ball_position()
	var row := {"name": name, "k": k, "snag": snag, "low_snag": low_snag, "passed": reach >= goal, "reach": snappedf(reach, 0.1),
		"worst": worst, "min": snappedf(minspeed, 0.01), "stall": stall, "end": end.snapped(Vector3.ONE * 0.1), "t": snappedf(t, 0.01)}
	_out("lane %s k=%.1f %s%s%s pass=%s reach=%.1f worst=%s min=%.2f stall=%s end=%s t=%.2f" % [name, k,
		("SNAG " + snag + " ") if snag != "" else "", ("LOWSNAG " + low_snag + " ") if low_snag != "" else "", ("RIDE@" + zipped + " ") if zipped != "" else "",
		str(reach >= goal), reach, worst, minspeed, stall, str(row["end"]), t])
	return row
