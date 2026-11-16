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
const Projectile := preload("res://src/combat/projectile.gd")
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
	shell.set_flight(launch, Threat.lob_bump(Projectile.GRAVITY, 1.9))
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
	quit(_t.verdict())


func _angle(a: Vector2, b: Vector2) -> float:
	return rad_to_deg(absf(a.angle_to(b)))


func _directions(ball: Vector3) -> void:
	var ball_px := _cam.unproject_position(ball)
	var seen := 0
	for source in [Vector3(8.0, 0.0, -10.0), Vector3(-12.0, 0.0, -4.0), Vector3(5.0, 0.0, 9.0), Vector3(-3.0, 6.0, -25.0)]:
		var want: Vector2 = (_cam.unproject_position(source) - ball_px).normalized()
		var got := DangerMark.screen_dir(_cam, ball, source)
		seen += 1
		_t.check("2a on screen %s: points from the ball's screen point to the source's" % [source], got != Vector2.ZERO and _angle(got, want) <= 5.0, "got %s want %s, %.1f deg apart" % [got, want, _angle(got, want)])
	_t.check("2a looped", seen == 4)
	# Behind the camera (it looks toward -z from z 16): the way the source lies across the camera's
	# own right and up from the ball, which is the screen edge nearest it.
	var behind := 0
	for source in [Vector3(9.0, 1.0, 30.0), Vector3(-9.0, 1.0, 30.0), Vector3(0.0, 1.0, 40.0)]:
		var off: Vector3 = source - ball
		var want := Vector2(off.dot(_cam.global_basis.x), -off.dot(_cam.global_basis.y)).normalized()
		var got := DangerMark.screen_dir(_cam, ball, source)
		behind += 1
		_t.check("2b behind the camera %s: points to its screen edge" % [source], _cam.is_position_behind(source) and _angle(got, want) <= 5.0, "got %s want %s" % [got, want])
	_t.check("2b looped", behind == 3)
	_t.check("2c a source on the ball has no direction", DangerMark.screen_dir(_cam, ball, ball) == Vector2.ZERO)


func _geometry(ball: Vector3) -> void:
	var mark := DangerMark.new()
	root.add_child(mark)
	mark.show_run(0.5)
	var top := ball + _cam.global_basis.y * 1.0
	mark.follow(_cam.unproject_position(top))
	var diamond: Rect2 = mark.rect()
	var clear := 0
	var overlapped_unpushed := 0
	for k in 8:
		var dir := Vector2(sin(k * TAU / 8.0), -cos(k * TAU / 8.0))
		var fill := DangerMark.pointer_fill(dir)
		var line := DangerMark.pointer_keyline(dir)
		var lo := INF
		var hi := -INF
		for p in fill:
			lo = minf(lo, p.dot(dir))
			hi = maxf(hi, p.dot(dir))
		var placed := PackedVector2Array()
		for p in line:
			placed.append(mark._at + p)
		var corners := PackedVector2Array([diamond.position, Vector2(diamond.end.x, diamond.position.y), diamond.end, Vector2(diamond.position.x, diamond.end.y)])
		var shared := Geometry2D.intersect_polygons(placed, corners)
		_t.check("3a direction %d: the pointer stands outside the diamond's box" % k, shared.is_empty(), "%d overlapping pieces" % shared.size())
		_t.check("3a direction %d: it is at least the diamond's half size long" % k, hi - lo >= DangerMark.HALF, "%.1f px" % (hi - lo))
		for w in 8:
			var a := w * TAU / 8.0
			var way := Vector3(cos(a), 0.0, sin(a))
			var keep := DangerMark.way_rect(_cam, ball, way)
			mark.pointer = dir
			mark.keep_clear = keep
			if DangerMark._poly_box(line, mark._at).intersects(keep):
				overlapped_unpushed += 1
			var pushed := DangerMark._poly_box(DangerMark.pointer_keyline(dir, mark._push()), mark._at)
			if keep.size != Vector2.ZERO and not pushed.intersects(keep):
				clear += 1
			else:
				_t.check("3b pointer %d vs way-out %d clear" % [k, w], false, "pointer %s way %s" % [pushed, keep])
	print("pointer/way-out combinations clear: %d of 64, %d would overlap without the step-out" % [clear, overlapped_unpushed])
	_t.eq("3b every combination is clear", clear, 64)
	_t.check("3b the step-out is needed somewhere (the check can fail)", overlapped_unpushed > 0)
	mark.free()
