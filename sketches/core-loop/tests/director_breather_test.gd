extends SceneTree

# Breathers (map audit unit 7, map points 2, 3 and 9; breather_rows.gd, ParkMap.breathers(), director.gd):
# 1. Data: park_dam has two breathers and park_flume one. Each stands on the riding lines (at least LINE_MIN line nodes
#    inside it) and its edge keeps CLEAR_M from every fight site, and its radius sits inside breather_rows.gd RADIUS.
#    Planted: a breather on the Warden's beacon fails the clearance line, a 400 m one the radius line.
# 2. Live wiring, on a director given park_dam's stage row (use_row): it reads the map's breathers, refuses a pack
#    spot inside one, banks its ticks while the ball is inside one with no crew home in the window, and does not
#    bank where a crew home is in the window.
# 3. Pressure (ruling cu): while the ball is inside, ticks bank, not place and not drop. Once it leaves, the bank pays
#    out one tick every RELEASE_GAP, so a breather crossed in its BREATH_S places as many arrivals over the stretch as
#    no breather. A ball parked in one gets BREATH_S of quiet and then packs come as before. A tick the room cannot
#    take stays banked. Credit income keeps accruing inside.
#    Planted: with the breather gone, packs are placed inside.

const T := preload("res://tests/support/t.gd")
const Director := preload("res://src/world/director.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const BreatherRows := preload("res://src/world/breather_rows.gd")
const FightReach := preload("res://tests/support/fight_reach.gd")
const Breath := preload("res://tests/park_breath_test.gd")

const WANT := {"park_dam": 1, "park_flume": 1}
# Line nodes inside a breather with no crew home in the window: where the director's own packs would land.
const FREE_MIN := 10
const LINE_MIN := 10
const CLEAR_M := 25.0
const ParkDefs := preload("res://src/core/park_defs.gd")

var t := T.new("director_breather_test")


func _initialize() -> void:
	_data()
	_refuses_spots()
	_live_wiring()
	_banks_and_pays_back()
	_parked_ball()
	_full_room_keeps_bank()
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


func _live_wiring() -> void:
	for i in [0, 1]:
		var row: Dictionary = ParkDefs.DEFS[i]
		var d := Director.new(7)
		d.use_row(row)
		t.eq("%s's stage row gives the director its breather" % row.map, d.breathers.size(), int(WANT[row.map]))
		if d.breathers.is_empty():
			continue
		var b: Dictionary = d.breathers[0]
		t.check("%s: the director refuses a pack spot inside it" % row.map, not d._park_safe(b["at"]))
		var points := Breath.line_points(ParkGraph.read("res://assets/park/%s/graph.bin" % row.map))
		var free := func(c: Vector2, r: float) -> int:
			return points.filter(func(p: Vector2) -> bool: return p.distance_to(c) <= r and d._window_homes(p).is_empty()).size()
		var n: int = free.call(b["at"], float(b["radius_m"]))
		print("[breather] %s %s: %d line nodes inside with no crew home in the window" % [row.map, b["id"], n])
		t.check("%s: it covers line nodes where the director's own packs land" % row.map, n >= FREE_MIN, "%d" % n)
		_run(d, 4.0, b["at"])
		t.check("%s: with the ball at its centre, ticks bank" % row.map, d.banked > 0 or d._timer > 0.0 and d.breath_used.get(b["id"], 0.0) > 0.0, "%d banked, %.1f s used" % [d.banked, float(d.breath_used.get(b["id"], 0.0))])
		if i == 0:
			# Planted: the apron below the dam face is quiet but a crew home is always in its window, so it would bank nothing.
			var apron: int = free.call(Vector2(-8.0, 240.0), 60.0)
			t.check("planted: a quiet circle with a crew home always ahead covers no free line node", apron < FREE_MIN, "%d" % apron)
			var d2 := Director.new(7)
			d2.use_row(row)
			d2.breathers = [{"id": "apron", "at": Vector2(-8.0, 240.0), "radius_m": 60.0}]
			_run(d2, 4.0, Vector2(-8.0, 240.0))
			t.eq("and a ball there banks nothing: the crew home keeps its fight", d2.banked, 0)


func _banks_and_pays_back() -> void:
	var out := Vector2(500.0, 0.0)
	# A crossing inside BREATH_S, then the stretch after it: the bank pays out and the stretch places as many as none.
	var held := _director(true)
	var inside := _run(held, 6.0, Vector2.ZERO)
	t.eq("no pack is placed while the ball is inside", inside, 0)
	t.check("the timer's ticks are banked", held.banked > 0, "%d" % held.banked)
	var banked := held.banked
	var first := _run(held, 1.0 / 60.0, out)
	t.check("the first tick out pays a banked tick", first >= 1 and held.banked == banked - 1, "%d arrivals, %d left" % [first, held.banked])
	var paid := inside + first + _run(held, 20.0, out)
	t.eq("the bank is empty after", held.banked, 0)
	var plain := _director(false)
	var plain_made := _run(plain, 6.0, Vector2.ZERO) + _run(plain, 1.0 / 60.0, out) + _run(plain, 20.0, out)
	print("[breather] 6 s inside then 20 s out: %d arrivals with a breather, %d without" % [paid, plain_made])
	t.check("a breather crossed in BREATH_S places as many over the stretch as none, within one tick", absi(plain_made - paid) <= 2, "%d vs %d" % [paid, plain_made])
	var planted := _director(true)
	planted.breathers = []
	t.check("planted: with the breather gone, packs are placed inside", _run(planted, 40.0, Vector2.ZERO) > 0)


func _parked_ball() -> void:
	var d := _director(true)
	_run(d, Director.BREATH_S - 0.1, Vector2.ZERO)
	t.eq("quiet for BREATH_S", d.arrivals.size(), 0)
	var later := _run(d, 30.0, Vector2.ZERO)
	t.check("a ball parked past BREATH_S meets packs again", later > 0, "%d" % later)
	t.near("its breather's quiet is spent", float(d.breath_used["test"]), Director.BREATH_S, 0.05)


func _full_room_keeps_bank() -> void:
	var d := _director(true)
	_run(d, 6.0, Vector2.ZERO)
	var banked := d.banked
	for i in 30:
		d.advance(1.0 / 60.0, d.cap(), Vector2(500.0, 0.0), Vector2(0.0, 10.0), Vector2(0.0, 1.0))
	t.eq("a full room keeps the bank", d.banked, banked)


func _credit_keeps_accruing() -> void:
	var d := _director(true)
	d.mode = "credit"
	_run(d, Director.BREATH_S - 1.0, Vector2.ZERO)
	t.eq("credit path: no pack placed inside", d.arrivals.size(), 0)
	t.check("credit path: income keeps accruing inside", d.credits > 0.0 and is_equal_approx(d.credits, d.credits_accrued), "%.2f" % d.credits)


static func radius_ok(r: float) -> bool:
	return r >= BreatherRows.RADIUS.x and r <= BreatherRows.RADIUS.y


func _schema() -> void:
	for map_id in BreatherRows.ROWS:
		for b in BreatherRows.rows(map_id):
			t.check("%s %s radius inside RADIUS" % [map_id, b["id"]], radius_ok(float(b["radius_m"])), "%.0f" % float(b["radius_m"]))
	t.check("planted: a 400 m breather fails the radius line", not radius_ok(400.0))
	t.eq("a map with no row has no breathers", BreatherRows.rows("park_crown"), [])
