extends SceneTree

# PF-16 (w42 first-timer film): the "!" diamond said the ball was in danger and not where the
# attack came from, so a lobber's shell was blamed on a world event and a chaser's lane on a
# boiler. The dodge watch now records the attack's source (a shell's launch point, a lane's
# start, a ring's middle), the HUD gives the danger mark the screen direction of it, and the
# mark draws a bone triangle outside the diamond that way. The way-out chevrons stay on the floor.

const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const NearMiss := preload("res://src/combat/near_miss.gd")
const DangerMark := preload("res://src/ui/danger_mark.gd")
const Chaser := preload("res://src/combat/chaser.gd")
const Enemy := preload("res://src/combat/enemy.gd")
const Projectile := preload("res://src/combat/projectile.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("danger_mark_source_test")
var _world := Node3D.new()
var _cam := Camera3D.new()
var _ground := FlatGround.new()


class FlatGround:
	func height(_x: float, _z: float) -> float:
		return 0.0


class _Bus:
	signal player_hit(amount: float, source: String)
	signal near_miss(kind: String, at: Vector3)


func _initialize() -> void:
	root.add_child(_world)
	root.add_child(_cam)
	_cam.position = Vector3(0.0, 14.0, 16.0)
	_cam.look_at_from_position(_cam.position, Vector3(0.0, 1.0, 0.0))
	_run.call_deferred()


# The escape the dodge watch publishes for a ball at `at` standing in `mark`.
func _escape_for(mark: Node, at: Vector3) -> Dictionary:
	mark.add_to_group(Threat.GROUP)
	var holder := [at]
	var watch := NearMiss.new()
	watch.setup(_Bus.new(), func() -> Vector3: return holder[0])
	root.add_child(watch)
	watch.step(1.0 / 60.0)
	var escape: Dictionary = watch.escape().duplicate()
	watch.free()
	return escape


func _run() -> void:
	var ball := Vector3(0.0, 1.0, 0.0)
	# A lane committed the way chaser.gd does: from the chaser's body toward the ball, run_body on.
	var from := Vector3(-6.0, 0.0, -8.0)
	var to_ball := (ball - from)
	var lane: Node3D = Telegraph.lane(_world, _ground, Threat.Type.LANE, from, to_ball, Chaser.LUNGE_LENGTH, Chaser.LUNGE_WIDTH)
	lane.run_body(0.0, 2.0)
	lane.set_progress(0.5)
	var e := _escape_for(lane, ball)
	_t.check("1a lane: the watch raised the escape", e.has("dir") and e.has("run"), str(e))
	_t.check("1a lane: the source is the lane's start", e.has("source") and e["source"].is_equal_approx(lane.center), str(e.get("source")))
	lane.free()

	# A shell's ring with its flight, committed as projectile.gd does.
	var launch := Vector3(30.0, 3.0, -30.0)
	var shell: Node3D = Telegraph.ring(_world, _ground, Threat.Type.PROJECTILE, ball + Vector3(1.0, 0.0, 0.0), 3.6)
	shell.set_flight(launch, Threat.lob_bump(Enemy.GRAVITY, 1.9))
	shell.set_progress(0.4)
	var s := _escape_for(shell, ball)
	_t.check("1b shell: the source is the launch point", s.has("source") and s["source"].is_equal_approx(launch), str(s.get("source")))
	shell.free()

	var ring: Node3D = Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3(3.0, 0.0, -2.0), 6.0)
	ring.set_progress(0.4)
	var r := _escape_for(ring, ball)
	_t.check("1c ring: the source is its centre", r.has("source") and r["source"].is_equal_approx(ring.center), str(r.get("source")))
	ring.free()

	_directions(ball)
	_geometry(ball)
	_held()
	quit(_t.verdict())


func _angle(a: Vector2, b: Vector2) -> float:
	return rad_to_deg(absf(a.angle_to(b)))


# A real mark over a real camera: the escape goes in through aim(), the HUD's own call.
func _mark_for(ball: Vector3, source: Vector3) -> Node:
	var mark := DangerMark.new()
	root.add_child(mark)
	mark.show_run(0.5)
	mark.aim(_cam, ball, {"source": source, "dir": Vector3.ZERO})
	mark.follow(_cam.unproject_position(ball + _cam.global_basis.y * 1.0))
	return mark


func _directions(ball: Vector3) -> void:
	var ball_px := _cam.unproject_position(ball)
	var seen := 0
	for k in 8:
		var screen := Vector2(sin(k * TAU / 8.0), -cos(k * TAU / 8.0))
		var source := _cam.project_position(ball_px + screen * 300.0, 30.0)
		var want: Vector2 = (_cam.unproject_position(source) - ball_px).normalized()
		var mark := _mark_for(ball, source)
		var tip: Vector2 = mark.spike_tip() - mark._at
		seen += 1
		_t.check("2a on screen, direction %d: the spike's tip points from the ball's screen point to the source's" % k, tip != Vector2.ZERO and _angle(tip, want) <= 5.0, "tip %s want %s, %.1f deg apart" % [tip, want, _angle(tip, want)])
		var pts: PackedVector2Array = DangerMark.spike_points(mark.pointer, DangerMark.spike_reach(mark.pointer, mark._at, mark.ball_box))
		_t.check("2a direction %d: the drawn outline's tip is that tip" % k, pts.size() == 3 and pts[2].distance_to(tip) < 0.01)
		mark.free()
	_t.check("2a looped", seen == 8)
	# Behind the camera (it looks toward -z from z 16): the way the source lies across the camera's
	# own right and up from the ball, which is the screen edge nearest it.
	var behind := 0
	for source in [Vector3(9.0, 1.0, 30.0), Vector3(-9.0, 1.0, 30.0), Vector3(0.0, 1.0, 40.0)]:
		var off: Vector3 = source - ball
		var want := Vector2(off.dot(_cam.global_basis.x), -off.dot(_cam.global_basis.y)).normalized()
		var mark := _mark_for(ball, source)
		var tip: Vector2 = mark.spike_tip() - mark._at
		behind += 1
		_t.check("2b behind the camera %s: the tip points to its screen edge" % [source], _cam.is_position_behind(source) and tip != Vector2.ZERO and _angle(tip, want) <= 5.0, "tip %s want %s" % [tip, want])
		mark.free()
	_t.check("2b looped", behind == 3)
	_t.check("2c a source on the ball has no direction", DangerMark.screen_dir(_cam, ball, ball) == Vector2.ZERO)


func _geometry(ball: Vector3) -> void:
	var mark := _mark_for(ball, Vector3(8.0, 0.0, -10.0))
	var diamond: Rect2 = mark._box(mark._at)
	var looped := 0
	for k in 8:
		var dir := Vector2(sin(k * TAU / 8.0), -cos(k * TAU / 8.0))
		mark.pointer = dir
		mark.ball_box = Rect2()
		var reach := DangerMark.spike_reach(dir, mark._at, mark.ball_box)
		var tip: Vector2 = mark.spike_tip()
		looped += 1
		_t.near("3a direction %d: the tip is 22 px beyond the diamond's edge" % k, (tip - mark._at).length() - DangerMark.edge_along(dir), DangerMark.SPIKE_LEN, 0.01)
		_t.check("3a direction %d: the tip is outside the diamond's box" % k, not diamond.has_point(tip))
		_t.check("3b direction %d: rect() contains the tip" % k, mark.rect().grow(0.5).has_point(tip), "rect %s tip %s" % [mark.rect(), tip])
		_t.check("3b direction %d: and the diamond's own box" % k, mark.rect().encloses(diamond))
	_t.check("3 looped", looped == 8)
	_t.eq("3c the spike is the diamond's fill colour", DangerMark.spike_color(), DangerMark.FILL_COLOR)
	_t.check("3c and not the chevrons' bone", DangerMark.spike_color() != UiTokens.TEXT)
	# The ball under the mark: the tip keeps 2 px off its box, and is left out when under 8 px remain.
	var stopped := 0
	for gap in [30.0, 20.0, 14.0, 6.0]:
		for k in 8:
			var dir := Vector2(sin(k * TAU / 8.0), -cos(k * TAU / 8.0))
			mark.pointer = dir
			# A ball box straight under the mark, its top `gap` px under the diamond's box.
			mark.ball_box = Rect2(Vector2(mark._at.x - 22.0, diamond.end.y + gap), Vector2(44.0, 44.0))
			var tip: Vector2 = mark.spike_tip()
			var reach := DangerMark.spike_reach(dir, mark._at, mark.ball_box)
			stopped += 1
			_t.check("4 gap %d direction %d: the tip never enters the ball's box" % [gap, k], not mark.ball_box.has_point(tip), "tip %s box %s" % [tip, mark.ball_box])
			_t.check("4 gap %d direction %d: and no spike under 8 px is drawn" % [gap, k], reach == 0.0 or reach >= DangerMark.SPIKE_MIN)
			if k == 4 and gap == 20.0:
				_t.check("4 straight down with the ball 20 px under: shortened, not full", reach > 0.0 and reach < DangerMark.SPIKE_LEN, "reach %.1f" % reach)
				_t.check("4 and it stops 2 px short of the box", absf(tip.y - (mark.ball_box.position.y - DangerMark.BALL_CLEAR)) <= 1.0, "tip y %.1f box top %.1f" % [tip.y, mark.ball_box.position.y])
			if k == 4 and gap == 6.0:
				_t.eq("4 straight down with the ball 6 px under: no spike", reach, 0.0)
				_t.check("4 and rect() is the diamond's box alone", mark.rect() == diamond)
	_t.eq("4 looped", stopped, 32)
	# The reticle's box (avoid) is kept clear the same way: the HUD's name and tags avoid rect().
	mark.ball_box = Rect2()
	mark.pointer = Vector2.DOWN
	mark.avoid = Rect2(Vector2(mark._at.x - 40.0, diamond.end.y + 10.0), Vector2(80.0, 80.0))
	_t.check("4 a spike aimed at the reticle's box stops short of it", not mark.avoid.has_point(mark.spike_tip()) and not mark.rect().intersects(mark.avoid), "rect %s avoid %s" % [mark.rect(), mark.avoid])
	mark.free()


# The source also rides the held body run (the chaser's lunge after its warning ends).
func _held() -> void:
	var from := Vector3(0.0, 0.0, 0.0)
	var lane: Node3D = Telegraph.lane(_world, _ground, Threat.Type.LANE, from, Vector3(0, 0, -1), 11.0, 2.8)
	lane.run_body(0.0, 2.4)
	lane.set_progress(1.0)
	var e := _escape_for(lane, Vector3(0.0, 0.0, -8.0))
	_t.check("5 held body run: the live lane keeps the escape up", float(e.get("run", -1.0)) == 1.0, str(e))
	_t.check("5 and it carries the lane's start as the source", e.has("source") and e["source"].is_equal_approx(lane.center), str(e.get("source")))
	lane.free()
