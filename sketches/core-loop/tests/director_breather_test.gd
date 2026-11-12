extends SceneTree

# Breathers (map audit unit 7, map points 2, 3 and 9; park breather_rows, ParkMap.breathers(), director.gd):
# 1. Data: park_dam has two breathers and park_flume one. Each stands on the riding lines (at least LINE_MIN line nodes
#    inside it) and clear of every fight site (its edge at least CLEAR_M from the nearest one), so no authored fight
#    is moved by it. Planted: a breather on the Warden's beacon fails the clearance line.
# 2. The director places no pack inside a breather: a spot inside one is refused.
# 3. While the ball is inside one, the timer's packs are banked (up to BANK_MAX), not placed and not dropped. All of
#    them fall due on the first tick after it leaves (ruling cu: a breather moves pressure later, never away). Over a
#    30 s stretch (inside the bank), a stage with no breather places as many packs as one with a breather, give or
#    take one tick; past the bank, a parked ball stores no more than BANK_MAX.
#    Credit income keeps accruing inside, so the credit path is paid back the same way.
# 4. Schema: a breather radius outside BREATHER_RADIUS is refused.

const T := preload("res://tests/support/t.gd")
const Director := preload("res://src/world/director.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const FightReach := preload("res://tests/support/fight_reach.gd")
const Breath := preload("res://tests/park_breath_test.gd")

const WANT := {"park_dam": 2, "park_flume": 1}
const LINE_MIN := 10
const CLEAR_M := 25.0

var t := T.new("director_breather_test")


func _initialize() -> void:
	_data()
	_refuses_spots()
	_banks_and_pays_back()
	_credit_keeps_accruing()
	_schema()
	quit(t.verdict())


static func clearance(sites: Array, b: Dictionary) -> float:
	return FightReach.nearest(sites, b["at"]) - float(b["radius_m"])


func _data() -> void:
	for map_id in WANT:
		var map := ParkMap.new("res://src/world/park/%s.json" % map_id)
		var g = ParkGraph.read("res://assets/park/%s/graph.bin" % map_id)
		if not t.check("%s loads" % map_id, map.ok and g != null):
			continue
		var list := map.breathers()
		t.eq("%s breathers" % map_id, list.size(), int(WANT[map_id]))
		var sites := map.fight_sites()
		var points := Breath.line_points(g)
		for b in list:
			var inside := points.filter(func(p: Vector2) -> bool: return p.distance_to(b["at"]) <= float(b["radius_m"])).size()
			var clear := clearance(sites, b)
			print("[breather] %s %s: %d line nodes inside, edge %.0f m from the nearest fight site" % [map_id, b["id"], inside, clear])
			t.check("%s %s stands on the riding lines" % [map_id, b["id"]], inside >= LINE_MIN, "%d" % inside)
			t.check("%s %s keeps clear of every fight site" % [map_id, b["id"]], clear >= CLEAR_M, "%.0f" % clear)
		if map_id == "park_dam":
			var planted := {"id": "planted", "at": map.beacon, "radius_m": 60.0}
			t.check("planted: a breather on the Warden's beacon fails the clearance line", clearance(sites, planted) < CLEAR_M)


static func _director(with_breather: bool) -> Director:
	var d := Director.new(7)
	d.play_rect = Rect2(-2000.0, -2000.0, 4000.0, 4000.0)
	if with_breather:
		d.breathers = [{"id": "test", "at": Vector2.ZERO, "radius_m": 60.0}]
	return d


func _refuses_spots() -> void:
	var d := _director(true)
	t.check("a spot inside a breather is in it", d.in_breather(Vector2(30.0, 0.0)))
	t.check("a spot on its edge is in it", d.in_breather(Vector2(60.0, 0.0)))
	t.check("a spot past it is not", not d.in_breather(Vector2(61.0, 0.0)))
	t.check("no breathers, nothing is in one", not _director(false).in_breather(Vector2.ZERO))


# Advances d for seconds with the ball at ball, in physics ticks; returns how many arrivals it queued (those that fell
# due in the stretch and those still showing their ring).
static func _run(d: Director, seconds: float, ball: Vector2) -> int:
	var before := d.arrivals.size()
	var landed := 0
	var steps := maxi(1, int(round(seconds * 60.0)))
	for i in steps:
		landed += d.advance(1.0 / 60.0, 0, ball, Vector2(0.0, 10.0), Vector2(0.0, 1.0)).size()
	return landed + d.arrivals.size() - before


func _banks_and_pays_back() -> void:
	var d := _director(true)
	var inside := _run(d, 80.0, Vector2.ZERO)
	t.eq("no pack is placed while the ball is inside", inside, 0)
	t.eq("the timer's packs are banked, up to BANK_MAX", d.banked, Director.BANK_MAX)
	var out := Vector2(500.0, 0.0)
	var paid := _run(d, 1.0 / 60.0, out)
	# A tick queues a single or a pack of two, so BANK_MAX ticks queue at least BANK_MAX arrivals.
	t.check("every banked tick falls due on the first tick out", paid >= Director.BANK_MAX, "%d arrivals" % paid)
	t.eq("the bank is empty after", d.banked, 0)
	# The same stretch with no breather: the breather moved packs later, not away (within one tick of the timer).
	var plain := _director(false)
	var plain_made := _run(plain, 30.0, Vector2.ZERO) + _run(plain, 1.0 / 60.0, out)
	var held := _director(true)
	paid = _run(held, 30.0, Vector2.ZERO) + _run(held, 1.0 / 60.0, out)
	print("[breather] 30 s inside then out: %d arrivals with a breather (BANK_MAX %d), %d without" % [paid, Director.BANK_MAX, plain_made])
	t.check("a breather inside the bank keeps every pack of the stretch, within one tick", absi(plain_made - paid) <= 1, "%d vs %d" % [paid, plain_made])
	var short := _director(true)
	var plain_short := _director(false)
	var a := _run(short, 9.0, Vector2.ZERO) + _run(short, 1.0 / 60.0, out)
	var b := _run(plain_short, 9.0, Vector2.ZERO) + _run(plain_short, 1.0 / 60.0, out)
	t.eq("a breather shorter than the bank costs no pack", a, b)
	var planted := _director(true)
	planted.breathers = []
	t.check("planted: with the breather gone, packs are placed inside", _run(planted, 40.0, Vector2.ZERO) > 0)


func _credit_keeps_accruing() -> void:
	var d := _director(true)
	d.mode = "credit"
	_run(d, 20.0, Vector2.ZERO)
	t.eq("credit path: no pack placed inside", d.arrivals.size(), 0)
	t.check("credit path: income keeps accruing inside", d.credits > 0.0 and is_equal_approx(d.credits, d.credits_accrued), "%.2f" % d.credits)


func _schema() -> void:
	var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/park_flume.json"))
	t.eq("park_flume passes the schema with its breather", ParkSchema.validate(park), [])
	park["breather_rows"][0]["radius_m"] = 400.0
	var errors := ParkSchema.validate(park)
	t.check("a breather radius past BREATHER_RADIUS is refused", errors.any(func(e) -> bool: return String(e.get("rule", "")) == "range"), str(errors))
