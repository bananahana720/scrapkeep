extends SceneTree

# Rule: a park cable's landing (`to`) end hangs at least 2.35 m over the baked ground, so the cable ride's
# target (the end less the hang, CABLE_HANG 1.3, still CABLE_LAND_CLEAR 1.05 up) never cuts the hang short and
# the cable never runs through the ball. Walks every park map's cable rows against ParkGround. The control
# is a synthetic row 1.0 m over the ground, which fails the same predicate.

const T := preload("res://tests/support/t.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkGround := preload("res://tests/support/park_ground.gd")

const MIN_OVER_M := 2.35
# Vector3 is float32: an end set at exactly the minimum can read a hair under it.
const EPS_M := 0.001
const MAPS := ["park_crown", "park_dam", "park_flume", "park_islands", "park_pit", "park_sinkhole"]
# park_test is the bake fixture: its bench_zip is a flat-world stand-in over a 40 m bench, not a played cable.

var t := T.new("park_cable_ends_test")


func _initialize() -> void:
	_run.call_deferred()


static func end_clear(end: Vector3, ground: Callable) -> bool:
	return end.y - float(ground.call(end.x, end.z)) >= MIN_OVER_M - EPS_M


func _run() -> void:
	var rows := 0
	for id in MAPS:
		var ground: Callable = ParkGround.ground(id)
		if not t.check("%s has a baked ground" % id, ground.is_valid()):
			continue
		var pm = ParkMap.new("res://src/world/park/%s.json" % id)
		for spec in pm.contraptions.filter(func(s): return s["kind"] == "cable"):
			var end: Vector3 = spec["to"]
			rows += 1
			t.check("%s %s to end is %.2f m over its ground, want %.2f" % [id, spec["id"], end.y - float(ground.call(end.x, end.z)), MIN_OVER_M], end_clear(end, ground))
	t.check("the walk found cable rows (%d)" % rows, rows >= 30)
	# Control: a row at ground + 1.0 fails; the minimum itself passes.
	var flat := func(_x: float, _z: float) -> float: return -40.0
	t.check("control: an end 1.0 m over the ground fails", not end_clear(Vector3(150.0, -39.0, -178.0), flat))
	t.check("control: an end exactly 2.35 m over the ground passes", end_clear(Vector3(150.0, -37.65, -178.0), flat))
	quit(t.verdict())
