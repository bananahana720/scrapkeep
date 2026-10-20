extends SceneTree

const Director := preload("res://src/world/director.gd")
const T := preload("res://tests/support/t.gd")

# w17 Warden contact (ruling 15 c'): while warden_core is finite, spawn_spot draws from the ring
# WARDEN_RING around the core, so a pack reaches the 6 m core ring where the Warden's damage lands.
# The honesty rules stay: 25 m from the ball, off the pilot corridor, inside the play rect.
#
# Planted control: set WARDEN_RING.x to 0 (the inner radius) and "inside the ring radii" fails on
# the first spawn within 14 m of the core; drop the MIN_GAP test in _warden_ring_spot and "25 m from the
# ball" fails for the ball lapping at 10 to 20 m. Either mutation turns this test red.

const PARKS := ["park_flume", "park_islands", "park_dam"]
const SPOTS := 120
const SLACK := 0.001
# The ring as the ruling states it, kept apart from Director.WARDEN_RING so a mutated constant is caught.
const RING_INNER := 14.0
const RING_OUTER := 32.0

var _t := T.new("director_warden_ring_test")


# A pit on the +x half of the core's plane: 20 m below the core, so the drop guard must refuse it.
class PitTerrain:
	var edge := 0.0

	func height(x: float, _z: float) -> float:
		return -20.0 if x > edge else 0.0


func _initialize() -> void:
	for id in PARKS:
		_ring_in_park(id)
	_default_is_unchanged()
	_drop_guard()
	_fallback()
	_pack_arrivals()
	quit(_t.verdict())


func _park_director(id: String, seed_value: int):
	var d = Director.new(seed_value)
	d.use_row({"map": id})
	d.play_rect = d._park_map.play_rect
	var spec: Dictionary = d._park_map.warden_spec()
	d.warden_core = Vector2(float(spec["anchor"][0]), float(spec["anchor"][2]))
	return d


func _ring_in_park(id: String) -> void:
	var d = _park_director(id, 11)
	_t.check("%s is a park map" % id, d._park_map != null)
	var core: Vector2 = d.warden_core
	var inside := true
	var gap := true
	var safe := true
	var rect := true
	var made := 0
	for i in SPOTS:
		# The ball laps the core at 10 to 20 m, the ram lap the bots run; every third spot it is far off,
		# where the 25 m gap alone no longer keeps spawns out of the inner radius.
		var ball := core + Vector2.RIGHT.rotated(TAU * i / 12.0) * (70.0 if i % 3 == 2 else 10.0 + 10.0 * float(i % 2))
		var at: Vector2 = d.spawn_spot(ball, Vector2.ZERO, Vector2(0.0, 1.0))
		if at == Vector2.INF:
			continue
		made += 1
		var r := at.distance_to(core)
		inside = inside and r >= RING_INNER - SLACK and r <= RING_OUTER + SLACK
		gap = gap and at.distance_to(ball) >= Director.MIN_GAP
		safe = safe and d._park_safe(at)
		rect = rect and d.play_rect.has_point(at)
	_t.check("%s: ring spots found (%d of %d)" % [id, made, SPOTS], made >= SPOTS * 0.8)
	_t.check("%s: every spot inside the ring radii" % id, inside)
	_t.check("%s: every spot 25 m from the ball" % id, gap)
	_t.check("%s: every spot off the pilot corridor" % id, safe)
	_t.check("%s: every spot in the play rect" % id, rect)
	_t.check("%s: home spots cleared for the pack spread" % id, d._forward_homes.is_empty())


func _default_is_unchanged() -> void:
	var a := Director.new(77)
	var b := Director.new(77)
	b.warden_core = Vector2.INF
	_t.check("warden_core defaults to INF", a.warden_core == Vector2.INF)
	var same := true
	for i in 40:
		var ball := Vector2(float(i), -float(i))
		same = same and a.spawn_spot(ball, Vector2(10.0, 0.0), Vector2(0.0, 1.0)) == b.spawn_spot(ball, Vector2(10.0, 0.0), Vector2(0.0, 1.0))
	_t.check("INF core: spawn sequence matches a fresh director", same)
	# The old path's RNG: the first call draws the ahead roll, then TRIES of angle and distance.
	var ref := RandomNumberGenerator.new()
	ref.seed = 77
	var c := Director.new(77)
	var at: Vector2 = c.spawn_spot(Vector2.ZERO, Vector2.ZERO, Vector2(0.0, 1.0))
	var ahead := ref.randf() < Director.AHEAD_SHARE
	var angle := ref.randf_range(-Director.AHEAD_CONE, Director.AHEAD_CONE) if ahead else ref.randf_range(Director.AHEAD_CONE, PI)
	_t.check("INF core: first draw is the 60/40 ahead roll", at != Vector2.INF and (not ahead or absf(Vector2(0.0, 1.0).angle_to(at)) <= Director.AHEAD_CONE + 0.01), "ahead=%s angle=%s" % [ahead, angle])


func _drop_guard() -> void:
	var d := Director.new(5)
	d.warden_core = Vector2(0.0, 0.0)
	d.terrain = PitTerrain.new()
	var ball := Vector2(0.0, -20.0)
	var clear := true
	var made := 0
	for i in SPOTS:
		var at: Vector2 = d.spawn_spot(ball, Vector2.ZERO, Vector2(0.0, 1.0))
		if at == Vector2.INF:
			continue
		made += 1
		clear = clear and at.x <= 0.0 and at.distance_to(d.warden_core) <= Director.WARDEN_RING.y + SLACK
	_t.check("drop guard: ring spots found (%d)" % made, made > 0)
	_t.check("drop guard: no spot lands in the pit", clear)


func _fallback() -> void:
	var d := Director.new(9)
	d.warden_core = Vector2(5000.0, 5000.0)
	var made := 0
	var gap := true
	for i in 30:
		var ball := Vector2(float(i), 0.0)
		var at: Vector2 = d.spawn_spot(ball, Vector2(12.0, 0.0), Vector2(1.0, 0.0))
		if at != Vector2.INF:
			made += 1
			gap = gap and at.distance_to(ball) >= Director.MIN_GAP and d.play_rect.has_point(at)
	_t.check("core off the play rect: falls back to the old placement (%d of 30)" % made, made >= 20)
	_t.check("fallback spots keep the 25 m gap and the rect", gap)


# Through advance(): arrivals queue on the ring (pack spread of 4.5 m either side), 25 m clear of the ball.
func _pack_arrivals() -> void:
	var d = _park_director("park_flume", 21)
	d.threat = 1.5
	d.stage_time = 120.0
	var core: Vector2 = d.warden_core
	var queued := 0
	var near := true
	var gap := true
	for step in 600:
		var ball := core + Vector2.RIGHT.rotated(float(step) * 0.05) * 15.0
		d.advance(0.5, 0, ball, Vector2.ZERO, Vector2(0.0, 1.0))
		for a in d.arrivals:
			var at: Vector2 = a["at"]
			near = near and at.distance_to(core) <= Director.WARDEN_RING.y + 2.0 * Director.PACK_SPREAD \
				and at.distance_to(core) >= Director.WARDEN_RING.x - 2.0 * Director.PACK_SPREAD
			gap = gap and at.distance_to(ball) >= Director.MIN_GAP
		queued += d.arrivals.size()
		d.arrivals.clear()
	_t.check("advance queues arrivals on the ring (%d seen)" % queued, queued > 0)
	_t.check("arrivals sit within a pack spread of the ring", near)
	_t.check("arrivals keep the 25 m gap", gap)
