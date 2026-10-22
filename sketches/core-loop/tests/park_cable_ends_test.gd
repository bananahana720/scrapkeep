extends SceneTree

# Rule: a park cable's landing (`to`) end hangs at least 2.35 m over the baked ground, so the cable ride's
# target (the end less the hang, CABLE_HANG 1.3, still CABLE_LAND_CLEAR 1.05 up) never cuts the hang short and
# the cable never runs through the ball. Walks every park map's cable rows against ParkGround. The control
# is a synthetic row 1.0 m over the ground, which fails the same predicate. Also guards three park_sinkhole
# runouts against sheer posts: the lava-channel bend past tube_rope_1 (BEND_AT) and two post strikes (POST_STRIKES).

const T := preload("res://tests/support/t.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkGround := preload("res://tests/support/park_ground.gd")

const MIN_OVER_M := 2.35
# Vector3 is float32: an end set at exactly the minimum can read a hair under it.
const EPS_M := 0.001
const MAPS := ["park_crown", "park_dam", "park_flume", "park_islands", "park_pit", "park_sinkhole"]
# park_test is the bake fixture: its bench_zip is a flat-world stand-in over a 40 m bench, not a played cable.

# A landing's runout: the ride's ball leaves a cable and rolls on over the channel bend. A post stamped on the
# bank (sheer +20 m) at that bend ends the run in a dead stop (park_sinkhole tube_rope_1 landing, lava_channel_post_21i
# at (-164.9, -448.2) was struck at (-172.8, -446.2), and Rivet dead-stopped 1.5 s later at (-171.2, -438.9)). The bend's baked ground must not rise more than
# BEND_RISE_MAX_M across a BEND_RADIUS_M disc round that spot. Checked on this bend only: measured over every cable end
# (measured 2026-10-22 on the baked grounds), tube_rope_3 and _4, east_haulage_rope_2 and domes_zip already rise 2.8 to 22.6 m within
# 30 m of their ends along the heading, so a general runout rule would fail maps outside this unit.
const BEND_AT := Vector2(-172.8, -446.2)
const BEND_RADIUS_M := 8.0
const BEND_RISE_MAX_M := 8.0
# Two more sheer anchor posts that stopped the Sable pilot (traversal_line --table=park --stage=4 --pilot=sable, seeds
# 1..8, 90 fps, 2026-10-22). Same rule and limit as the bend, a table of (name, strike point):
#   main_tube_upper_post_11i at (-35.3, -120.2): a corner stood 0.4 m inside main_tube_upper_8's wash footprint; Sable
#     dead-stopped at (-40.8, -114.4) on 5 of 8 seeds on stage 42ed00ee (#241 6352524432) and on 2 of 8 (seeds 3
#     and 6) on this change's base 0446a2f2; ground rise over the 8 m disc 26.0 m before, 6.0 m after.
#   lava_channel_post_13i at (-313.1, -585.2), 2.0 m off lava_channel_10: seed 8 struck it airborne (vx 43.4 to -4.6 in the
#     42ed00ee trace, #241 6352524432) and stopped at (-318.7, -588.4); rise 22.3 m before, 4.7 m after.
# Both posts move outward (11i to (-27.3, -120.2), 13i to (-307.1, -582.2)). The limit stays the bend's 8.0 m: the fix passes with 2.0 m and 3.3 m margin, the base fails by 18.0 m and 14.3 m.
const POST_STRIKES := [
	["main_tube_upper_post_11i", Vector2(-40.8, -114.4)],
	["lava_channel_post_13i", Vector2(-318.7, -588.4)],
]

var t := T.new("park_cable_ends_test")


func _initialize() -> void:
	_run.call_deferred()


static func end_clear(end: Vector3, ground: Callable) -> bool:
	return end.y - float(ground.call(end.x, end.z)) >= MIN_OVER_M - EPS_M


# The ground's rise (highest minus lowest) over a disc of radius r round c, sampled every 1 m.
static func disc_rise(ground: Callable, c: Vector2, r: float) -> float:
	var lo := INF
	var hi := -INF
	var dx := -r
	while dx <= r:
		var dz := -r
		while dz <= r:
			if dx * dx + dz * dz <= r * r:
				var y := float(ground.call(c.x + dx, c.y + dz))
				lo = minf(lo, y)
				hi = maxf(hi, y)
			dz += 1.0
		dx += 1.0
	return hi - lo


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
	var sink: Callable = ParkGround.ground("park_sinkhole")
	var rise := disc_rise(sink, BEND_AT, BEND_RADIUS_M)
	t.check("park_sinkhole bend runout: ground rises %.1f m over a %.0f m disc at %s, want at most %.1f" % [rise, BEND_RADIUS_M, BEND_AT, BEND_RISE_MAX_M], rise <= BEND_RISE_MAX_M)
	for ps in POST_STRIKES:
		var pr := disc_rise(sink, ps[1], BEND_RADIUS_M)
		t.check("park_sinkhole %s strike: ground rises %.1f m over a %.0f m disc at %s, want at most %.1f" % [ps[0], pr, BEND_RADIUS_M, ps[1], BEND_RISE_MAX_M], pr <= BEND_RISE_MAX_M)
	# Control: a row at ground + 1.0 fails; the minimum itself passes.
	var flat := func(_x: float, _z: float) -> float: return -40.0
	t.check("control: an end 1.0 m over the ground fails", not end_clear(Vector3(150.0, -39.0, -178.0), flat))
	t.check("control: an end exactly 2.35 m over the ground passes", end_clear(Vector3(150.0, -37.65, -178.0), flat))
	var wall := func(x: float, _z: float) -> float: return -80.0 if x < -170.0 else -60.0
	t.check("control: a 20 m wall in the bend disc fails", disc_rise(wall, Vector2(-172.8, -446.2), BEND_RADIUS_M) > BEND_RISE_MAX_M)
	t.check("control: flat ground in the bend disc passes", disc_rise(flat, Vector2(-172.8, -446.2), BEND_RADIUS_M) <= BEND_RISE_MAX_M)
	for ps in POST_STRIKES:
		var cx: float = ps[1].x
		var post_wall := func(x: float, _z: float) -> float: return -80.0 if x < cx else -60.0
		t.check("control: a 20 m wall through the %s disc fails" % ps[0], disc_rise(post_wall, ps[1], BEND_RADIUS_M) > BEND_RISE_MAX_M)
		t.check("control: flat ground in the %s disc passes" % ps[0], disc_rise(flat, ps[1], BEND_RADIUS_M) <= BEND_RISE_MAX_M)
	quit(t.verdict())
