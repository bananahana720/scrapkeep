extends SceneTree

# Rule: a route's wash elbow (two wash rows consecutive in a route's `via` once non-wash entries are skipped,
# footprints within GAP_MAX_M) must not be a momentum trap. A sharp kink between the two axes with the bank
# toe on the inside or outside of the turn rising well past the wash profile's designed rise stops a rolled-back
# ball dead ("momentum is sacred": a 40 m/s ball stopped at a 28 deg kink, sinkhole lava_channel_12>13).
# Geometric, not seeded stop counts. Per elbow: kink = acute angle between the axes (0..90 deg); rise = max over
# 1 m samples of the centre line within 30 m of the junction of (max baked ground at lateral 1..12 m both sides
# minus centre ground); designed = the wash profile's own rise (park_stamps.gd wash) at the best offset;
# excess = rise - designed.
# Flag = kink >= KINK_MIN_DEG (18) and excess >= EXCESS_MIN_M (1.25). Set from the two seen traps and the clean
# controls (measured 2026-10-23 on the baked grounds): A lava_channel_12>13 kink 28.2 excess 1.55 and B
# lava_channel_20>21 kink 20.2 excess 1.64 flagged. The bounds sit about 10 percent under B's kink and 20 percent
# under A's excess, so a rebake near an elbow does not unflag a control; bounds set just under A and B
# (20, 1.5) would also have passed lava_channel_19>20 (36.1 deg, 1.49), 13>14 and 14>15 (30+ deg, 1.38) on
# hundredths of a metre. The controls pin each term: the straight mid-run of lava_channel_12 reads about its
# designed rise (excess 0.39) and is not flagged; east_haulage_6>7 (kink 27.9, excess 0.18) and pit
# dump_wash_1>2 (kink 9.8, excess 0.19) are not. A and B's excess is only about 1.6 m, the same as many
# neighbouring lava_channel elbows, so this is a positional screen, not a stop predictor.
# Eased 2026-10-23 (wave 19, ruling #241 item 3): the sinkhole's lava_channel_12, 13 and 21 rows moved (yaw, at, length)
# so A reads kink 18.3 excess 1.08, B kink 19.2 excess 0.95, and 11>12 (32.1 deg, 1.00) and 13>14 (32.2 deg, 1.07) fall
# under the excess bound too. Their positive controls were the then-flagged lava_channel_14>15 (33.3 deg, 1.38) and
# 19>20 (36.1 deg, 1.49), 0.13 m and 0.24 m over EXCESS_MIN_M.
# Eased 2026-10-23 (wave 19, ruling #241 item 3, second pass): lava_channel_14 shortened (58.51 to 56.5 m) and
# lava_channel_20 shortened (59.4 to 55.0 m), at and yaw unchanged, so 14>15 reads kink 33.3 excess 1.00 and 19>20
# kink 36.1 excess 1.12, both under the excess bound, and 13>14 (0.91) and 20>21 (19.2 deg, 0.53) stay unflagged. The
# positive controls move to the two still-flagged elbows with the widest margin over both bounds: main_tube_lower_3>4
# (48.7 deg, 15.40 m) and main_tube_upper_7>8 (39.2 deg, 7.42 m). The remaining lava_channel elbow 6>7 (24.3 deg, 2.13)
# is the next sinkhole wash easing target; its margin is smaller than the chosen controls'.
# FLAGGED pins the flagged set: a later easing PR shrinks it; a new or vanished entry fails with the diff.

const T := preload("res://tests/support/t.gd")
const ParkStamps := preload("res://src/world/park/park_stamps.gd")
const ParkGround := preload("res://tests/support/park_ground.gd")

const MAPS := ["park_crown", "park_dam", "park_flume", "park_islands", "park_pit", "park_sinkhole"]
const GAP_MAX_M := 2.0
const NEAR_M := 30.0
const LATERAL_MAX_M := 12.0
const KINK_MIN_DEG := 18.0
const EXCESS_MIN_M := 1.25
const FLAGGED: Array = [
	"park_sinkhole:lava_channel_6>lava_channel_7",
	"park_sinkhole:main_tube_upper_5>main_tube_upper_6",
	"park_sinkhole:main_tube_upper_7>main_tube_upper_8",
	"park_sinkhole:main_tube_lower_3>main_tube_lower_4",
	"park_sinkhole:main_tube_lower_9>main_tube_lower_10",
	"park_sinkhole:west_gallery_6>west_gallery_7",
	"park_sinkhole:west_gallery_7>west_gallery_8",
	"park_sinkhole:east_drift_8>east_drift_9",
	"park_sinkhole:skylight_chain_3>skylight_chain_4",
	"park_sinkhole:skylight_chain_5>skylight_chain_6",
	"park_sinkhole:cannon_tube_5>cannon_tube_6",
	"park_sinkhole:east_haulage_5>east_haulage_6",
	"park_sinkhole:west_breakthrough_5>west_breakthrough_6",
]

var t := T.new("park_wash_elbow_test")


func _initialize() -> void:
	_run.call_deferred()


static func flag(kink_deg: float, excess_m: float) -> bool:
	return kink_deg >= KINK_MIN_DEG and excess_m >= EXCESS_MIN_M


# The wash profile's rise over the floor at lateral offset d (park_stamps.gd wash, away from the open ends).
static func designed_at(f: Dictionary, d: float) -> float:
	var tt := absf(2.0 * d / float(f["width"]))
	if tt > 1.0:
		return float(f["height"])
	var depth := 1.0
	if tt > 0.4:
		var w := (tt - 0.4) / 0.6
		depth = 1.0 - w * w
	return float(f["height"]) * (1.0 - depth)


static func designed(f: Dictionary) -> float:
	var best := 0.0
	var d := 1.0
	while d <= LATERAL_MAX_M:
		best = maxf(best, designed_at(f, d))
		d += 1.0
	return best


static func _seg_pt(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var s := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return p.distance_to(a + ab * s)


static func _cross(o: Vector2, a: Vector2, b: Vector2) -> float:
	return (a - o).cross(b - o)


static func _seg_cross(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	return _cross(a, b, c) * _cross(a, b, d) < 0.0 and _cross(c, d, a) * _cross(c, d, b) < 0.0


static func corners(f: Dictionary) -> Array:
	var hl: Vector2 = f["along"] * float(f["length"]) * 0.5
	var hw: Vector2 = f["across"] * float(f["width"]) * 0.5
	var c: Vector2 = f["at"]
	return [c - hl - hw, c + hl - hw, c + hl + hw, c - hl + hw]


# Gap between two footprints (oriented rectangles); 0 when they overlap.
static func gap(fa: Dictionary, fb: Dictionary) -> float:
	var ca := corners(fa)
	var cb := corners(fb)
	for p: Vector2 in ca:
		if ParkStamps.inside(fb, p.x, p.y):
			return 0.0
	for p: Vector2 in cb:
		if ParkStamps.inside(fa, p.x, p.y):
			return 0.0
	var best := INF
	for i in 4:
		var a0: Vector2 = ca[i]
		var a1: Vector2 = ca[(i + 1) % 4]
		for j in 4:
			var b0: Vector2 = cb[j]
			var b1: Vector2 = cb[(j + 1) % 4]
			if _seg_cross(a0, a1, b0, b1):
				return 0.0
			best = minf(best, minf(minf(_seg_pt(a0, b0, b1), _seg_pt(a1, b0, b1)), minf(_seg_pt(b0, a0, a1), _seg_pt(b1, a0, a1))))
	return best


static func kink_deg(fa: Dictionary, fb: Dictionary) -> float:
	var c := absf((fa["along"] as Vector2).dot(fb["along"]))
	return rad_to_deg(acos(clampf(c, 0.0, 1.0)))


# The junction ends, in route order: a's exit is the end facing b's centre, b's entry the end facing a's.
# (The closest pair of end points picks the far end when a short row sits over the other's end.)
static func junction_ends(fa: Dictionary, fb: Dictionary) -> Array:
	var ab: Vector2 = (fb["at"] as Vector2) - (fa["at"] as Vector2)
	var i := 1 if (fa["along"] as Vector2).dot(ab) >= 0.0 else 0
	var j := 1 if (fb["along"] as Vector2).dot(-ab) >= 0.0 else 0
	return [i, j]


# One row's bank-toe rise near the junction. other_dir: the other row's direction away from the junction.
# Returns {rise, at: Vector2, inside: bool}.
static func row_rise(f: Dictionary, end_i: int, other_dir: Vector2, ground: Callable) -> Dictionary:
	var sgn := 1.0 if end_i == 1 else -1.0
	var junction: Vector2 = (f["at"] as Vector2) + (f["along"] as Vector2) * float(f["length"]) * 0.5 * sgn
	var away: Vector2 = (f["along"] as Vector2) * -sgn
	var span := minf(NEAR_M, float(f["length"]))
	var best := {"rise": -INF, "at": junction, "inside": false}
	var s := 0.0
	while s <= span + 0.0001:
		var p := junction + away * s
		var centre := float(ground.call(p.x, p.y))
		for side in [-1.0, 1.0]:
			var n: Vector2 = (f["across"] as Vector2) * side
			var d := 1.0
			while d <= LATERAL_MAX_M:
				var q := p + n * d
				var r := float(ground.call(q.x, q.y)) - centre
				if r > best["rise"]:
					best = {"rise": r, "at": q, "inside": n.dot(other_dir) > 0.0}
				d += 1.0
		s += 1.0
	return best


# The straight-run rise of one row between along offsets s0..s1 from its centre (negative control reading).
static func mid_rise(f: Dictionary, s0: float, s1: float, ground: Callable) -> float:
	var best := -INF
	var s := s0
	while s <= s1:
		var p: Vector2 = (f["at"] as Vector2) + (f["along"] as Vector2) * s
		var centre := float(ground.call(p.x, p.y))
		for side in [-1.0, 1.0]:
			var d := 1.0
			while d <= LATERAL_MAX_M:
				var q: Vector2 = p + (f["across"] as Vector2) * side * d
				best = maxf(best, float(ground.call(q.x, q.y)) - centre)
				d += 1.0
		s += 1.0
	return best


static func measure(fa: Dictionary, fb: Dictionary, ground: Callable) -> Dictionary:
	var ends := junction_ends(fa, fb)
	var sa := 1.0 if ends[0] == 1 else -1.0
	var sb := 1.0 if ends[1] == 1 else -1.0
	var da: Vector2 = (fa["along"] as Vector2) * -sa
	var db: Vector2 = (fb["along"] as Vector2) * -sb
	var ra := row_rise(fa, ends[0], db, ground)
	var rb := row_rise(fb, ends[1], da, ground)
	var ea := float(ra["rise"]) - designed(fa)
	var eb := float(rb["rise"]) - designed(fb)
	var rise: Dictionary = ra if ea >= eb else rb
	var des := designed(fa) if ea >= eb else designed(fb)
	var k := kink_deg(fa, fb)
	# The travel turn: in along a towards the junction (-da), out along b (db). Above 90 deg the axis kink folds.
	var turn := rad_to_deg(acos(clampf((-da).dot(db), -1.0, 1.0)))
	return {"kink": k, "turn": turn, "rise": rise["rise"], "at": rise["at"], "inside": rise["inside"], "designed": des, "excess": float(rise["rise"]) - des, "flagged": flag(k, float(rise["rise"]) - des)}


func _run() -> void:
	var table: Array = []
	var frames_by_map := {}
	var grounds := {}
	for id in MAPS:
		var ground: Callable = ParkGround.ground(id)
		if not t.check("%s has a baked ground" % id, ground.is_valid()):
			continue
		grounds[id] = ground
		var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/%s.json" % id))
		var rows := {}
		for row: Dictionary in park["park_rows"]:
			rows[String(row["id"])] = row
		var pairs := {}
		for route: Dictionary in park["routes"]:
			var washes: Array = []
			for rid in route["via"]:
				if rows.has(rid) and String(rows[rid]["stamp"]) == "wash":
					washes.append(String(rid))
			for i in washes.size() - 1:
				var key := "%s>%s" % [washes[i], washes[i + 1]]
				if not pairs.has(key):
					pairs[key] = {"a": washes[i], "b": washes[i + 1], "routes": []}
				(pairs[key]["routes"] as Array).append(String(route["id"]))
		var frames := {}
		for rid in rows:
			frames[rid] = ParkStamps.frame(rows[rid])
		frames_by_map[id] = frames
		for key in pairs:
			var p: Dictionary = pairs[key]
			var fa: Dictionary = frames[p["a"]]
			var fb: Dictionary = frames[p["b"]]
			var g := gap(fa, fb)
			if g > GAP_MAX_M:
				continue
			var m := measure(fa, fb, ground)
			m["name"] = "%s:%s" % [id, key]
			m["routes"] = ",".join(PackedStringArray(p["routes"]))
			m["gap"] = g
			table.append(m)
	print("park:pair | routes | gap | kink | turn | rise | designed | excess | where (x,z,side) | flagged")
	var flagged: Array = []
	var by_name := {}
	for m in table:
		by_name[m["name"]] = m
		var at: Vector2 = m["at"]
		print("%s | %s | %.1f | %.1f | %.1f | %.2f | %.2f | %.2f | (%.1f,%.1f,%s) | %s" % [m["name"], m["routes"], m["gap"], m["kink"], m["turn"], m["rise"], m["designed"], m["excess"], at.x, at.y, "inside" if m["inside"] else "outside", m["flagged"]])
		if m["flagged"]:
			flagged.append(m["name"])
	var ex: Array = table.map(func(m): return float(m["excess"]))
	ex.sort()
	var ks: Array = table.map(func(m): return float(m["kink"]))
	ks.sort()
	if not ex.is_empty():
		print("elbows %d, flagged %d; excess min %.2f median %.2f max %.2f; kink min %.1f median %.1f max %.1f" % [table.size(), flagged.size(), ex[0], ex[ex.size() / 2], ex[-1], ks[0], ks[ks.size() / 2], ks[-1]])
	t.check("the walk found elbows (%d)" % table.size(), table.size() >= 10)
	var hairpins := table.filter(func(m): return float(m["turn"]) > 90.0)
	t.check("no elbow turns past 90 deg, where the axis kink would read acute (%d)" % hairpins.size(), hairpins.is_empty())

	# Positive controls.
	for name in ["park_sinkhole:main_tube_lower_3>main_tube_lower_4", "park_sinkhole:main_tube_upper_7>main_tube_upper_8"]:
		var present: bool = by_name.has(name)
		t.check("positive control %s is an elbow" % name, present)
		if present:
			var m: Dictionary = by_name[name]
			t.check("positive control %s flagged (kink %.1f, rise %.2f, excess %.2f)" % [name, m["kink"], m["rise"], m["excess"]], m["flagged"])
	# Negative controls: a straight mid-run, and the real elbows that must not flag.
	var sink: Callable = grounds.get("park_sinkhole", Callable())
	if sink.is_valid():
		var f12: Dictionary = frames_by_map["park_sinkhole"]["lava_channel_12"]
		var len12 := float(f12["length"])
		var mid := mid_rise(f12, -10.0, 10.0, sink)
		var des := designed(f12)
		t.check("negative control: lava_channel_12 mid-run (length %.0f) rises %.2f, designed %.2f, within 0.6 m" % [len12, mid, des], len12 > 50.0 and absf(mid - des) <= 0.6)
		t.check("negative control: the mid-run does not flag at kink 0", not flag(0.0, mid - des))
	var calm := table.filter(func(m): return not m["flagged"] and m["kink"] <= 10.0)
	t.check("negative control: some real elbow with kink <= 10 deg is unflagged (%d)" % calm.size(), calm.size() >= 1)
	if not calm.is_empty():
		print("calm elbow control: %s kink %.1f excess %.2f" % [calm[0]["name"], calm[0]["kink"], calm[0]["excess"]])
	for name in ["park_sinkhole:east_haulage_6>east_haulage_7", "park_pit:dump_wash_1>dump_wash_2"]:
		var present: bool = by_name.has(name)
		t.check("negative control %s is an elbow" % name, present)
		if present:
			t.check("negative control %s not flagged (kink %.1f, excess %.2f)" % [name, by_name[name]["kink"], by_name[name]["excess"]], not by_name[name]["flagged"])
	# Planted: a flagged elbow's numbers with the kink set to 0 must not flag; its kink with no excess must not flag either.
	var a: Dictionary = by_name.get("park_sinkhole:main_tube_lower_3>main_tube_lower_4", {"kink": 48.7, "excess": 15.4})
	t.check("planted: the lower_3>4 excess at kink 0 does not flag", not flag(0.0, a["excess"]))
	t.check("planted: the lower_3>4 kink at excess 0 does not flag", not flag(a["kink"], 0.0))
	t.check("planted: the lower_3>4 kink and excess flag", flag(a["kink"], a["excess"]))
	# Planted at the bounds: a bank notch just over both flags; one just under either does not.
	t.check("planted: kink 18.5 and excess 1.30 flag", flag(18.5, 1.30))
	t.check("planted: kink 17.5 and excess 1.30 do not flag", not flag(17.5, 1.30))
	t.check("planted: kink 18.5 and excess 1.20 do not flag", not flag(18.5, 1.20))

	# Pin.
	var missing: Array = FLAGGED.filter(func(n): return not flagged.has(n))
	var added: Array = flagged.filter(func(n): return not FLAGGED.has(n))
	if not missing.is_empty() or not added.is_empty():
		print("FLAGGED diff: now flagged and not pinned %s; pinned and no longer flagged %s" % [added, missing])
		print("FLAGGED = %s" % [flagged])
	t.check("the flagged set matches FLAGGED (%d)" % FLAGGED.size(), missing.is_empty() and added.is_empty())
	quit(t.verdict())
