extends SceneTree

const EdgeMarkers := preload("res://src/ui/edge_markers.gd")

# Rule: the off-screen arrow to a reward gate is never hidden by the choice written on an arch (a mark
# outranks a word). A sign that reaches the arrow's footprint pushes it along the screen edge to the
# nearest clear spot; it leaves a spot only when a sign touches it (a chasing sign pushes it on, a step at a time) or to go home once clear, so a pixel of camera
# sway never toggles it. The sign rects come in as `sign_rects`, the way the HUD hands `keep_clear`.
# The stub game also answers the old per-frame pull (build.gates.keep_clear_rects) with the same rects,
# so this test fails on code that hides the arrow however it reads them.

var _t := preload("res://tests/support/t.gd").new("edge_arrow_sweep_test")
var _signs: Array[Rect2] = []
# Read by name so the test still loads, and fails on what it checks, against code without the constant.
var _hold: float = float((EdgeMarkers as Script).get_script_constant_map().get("ARROW_HOLD", 12.0))


class _Flow:
	func in_play() -> bool:
		return true

	func state_name() -> String:
		return "gates"


class _Camera:
	var cam: Camera3D


class _Player:
	func shown_position() -> Vector3:
		return Vector3.ZERO


class _Gates:
	var owner_test

	func keep_clear_rects() -> Array[Rect2]:
		return owner_test._signs


class _Build:
	var gates


class _Game:
	var flow := _Flow.new()
	var camera := _Camera.new()
	var player := _Player.new()
	var build := _Build.new()
	var world = null


func _initialize() -> void:
	_run.call_deferred()


func _arrows(markers, size: Vector2) -> Array:
	markers.set("sign_rects", _signs)
	return markers.markers(size).filter(func(m): return m.has("dir"))


func _run() -> void:
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	var game := _Game.new()
	game.camera.cam = cam
	game.build.gates = _Gates.new()
	game.build.gates.owner_test = self
	var markers = EdgeMarkers.new()
	markers.game = game
	root.add_child(markers)
	var gate := Vector3(60.0, 0.0, -10.0)
	markers.gate_points.append(gate)
	var size: Vector2 = root.get_visible_rect().size
	var bare := _arrows(markers, size)
	if not _t.eq("premise: a gate off to the right is one edge arrow", bare.size(), 1):
		quit(_t.verdict())
		return
	var home: Vector2 = bare[0]["at"]
	var foot := EdgeMarkers.edge_footprint(home, bare[0]["dir"], bare[0]["size"])
	_t.check("premise: the arrow stands on a side edge, so a sign slides it up or down", absf(home.x - EdgeMarkers.view_rect(size).end.x) < 1.0, "%s" % home)
	var from_y := foot.position.y - 90.0
	var to_y := foot.end.y + 90.0
	for pass_index in 2:
		var down := pass_index == 0
		var vanished := 0
		var spontaneous := 0
		var flips := 0
		var last: Vector2 = home
		var last_side := 0
		var steps := int(to_y - from_y)
		for i in steps + 1:
			var y := from_y + i if down else to_y - i
			_signs = [Rect2(foot.position.x - 30.0, y, foot.size.x + 60.0, 40.0)]
			var arrows := _arrows(markers, size)
			if arrows.size() != 1:
				vanished += 1
				continue
			var at: Vector2 = arrows[0]["at"]
			if at != last:
				var old_foot := EdgeMarkers.edge_footprint(last, arrows[0]["dir"], arrows[0]["size"])
				if at != home and not old_foot.intersects(_signs[0].grow(_hold)):
					spontaneous += 1
				var side := signi(roundi(at.y - home.y))
				if side != 0 and last_side != 0 and side != last_side:
					flips += 1
				if side != 0:
					last_side = side
			last = at
		var label := "a sign swept %s across the arrow" % ("down" if down else "up")
		_t.eq("%s never hides it" % label, vanished, 0)
		_t.eq("%s leaves its spot only for a sign touching it (or to go home once clear)" % label, spontaneous, 0)
		_t.check("%s changes its side at most once" % label, flips <= 1, "%d changes" % flips)
	# Sway: a sign parked at the edge of the footprint and wobbling one pixel each frame never toggles it.
	for gap in [-6.0, 0.0, 6.0, 13.0]:
		_signs = [Rect2(foot.position.x - 30.0, foot.end.y + gap, foot.size.x + 60.0, 40.0)]
		var first := _arrows(markers, size)
		var settled: Vector2 = first[0]["at"] if not first.is_empty() else Vector2.INF
		var moves := 0
		for frame in 20:
			_signs = [Rect2(foot.position.x - 30.0, foot.end.y + gap + (1.0 if frame % 2 == 0 else 0.0), foot.size.x + 60.0, 40.0)]
			var arrows := _arrows(markers, size)
			if arrows.size() != 1 or arrows[0]["at"] != settled:
				moves += 1
				if arrows.size() == 1:
					settled = arrows[0]["at"]
		_t.check("a sign %.0f px from the footprint, swaying one pixel, moves the arrow at most once" % gap, moves <= 1, "%d moves" % moves)
	# No clear spot within the slide: the arrow stays and is drawn over the sign.
	_signs = [Rect2(foot.position.x - 30.0, EdgeMarkers.view_rect(size).position.y, foot.size.x + 60.0, EdgeMarkers.view_rect(size).size.y)]
	var blocked := _arrows(markers, size)
	_t.check("a sign down the whole edge leaves the arrow drawn", blocked.size() == 1)
	markers.free()
	cam.free()
	quit(_t.verdict())
