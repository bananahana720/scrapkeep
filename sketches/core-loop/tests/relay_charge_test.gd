extends SceneTree

const HoldRelay := preload("res://src/world/hold_relay.gd")
const Parts := preload("res://src/build/parts.gd")
const Items := preload("res://src/build/items.gd")

# SR9 relay charge rule (W13-INTEGRATION-3.md, SR9; comps/ror2/events-and-objectives.md:116).
# The opt-in hold relay charges by a data rule: charge rate is share^s, where share is the
# occupied fraction of the living; an empty ring drains at the discharge rate (0 keeps the
# old pause); the ring follows charge down to a floor; and the convergence part trades a
# tighter ring for a faster charge, capped at three copies.
#
# (a) 100 seeded runs with 1 to 4 occupants of 4 living, s drawn from 0.5 to 1.5: the charge
#     time equals T / share^s within 1%.
# (b) with discharge above 0 an empty ring drains to 0; with discharge 0 the charge pauses.
# (c) the ring never falls under its floor while it follows charge, and stays fixed by default.
# (d) the convergence part at counts 1 to 3: radius base / (2 x count) and charge
#     T / (1 + 0.3 x count), each within 1%.
# (e) count 4 gives exactly the count 3 numbers.
# (f) the convergence row is a capped stack of three in the parts catalogue.
# (g) the convergence row is never offered until its seam relay.convergence is set.

const ROW_ID := "relay_convergence"
const SEAM := "relay.convergence"
const SEEDS := 100
const LIVING := 4
const TOLERANCE := 0.01
const EXPECTED_REPORTS := 8
const DT := 1.0 / 60.0
const INSIDE := Vector3(0.0, 0.0, 0.0)
const OUTSIDE := Vector3(100.0, 0.0, 100.0)

var _failures := 0
var _reports := 0


func _initialize() -> void:
	_check_seeded_charge()
	_check_discharge()
	_check_floor()
	_check_convergence_counts()
	_check_count_four()
	_check_row_cap()
	_check_seam_gate()
	if _reports != EXPECTED_REPORTS:
		_failures += 1
		print("FAIL report count: %d of %d checks reported (a check died mid-way)" % [_reports, EXPECTED_REPORTS])
	print("relay_charge_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _report(label: String, ok: bool, detail: String) -> void:
	_reports += 1
	print("%s %s: %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures += 1


func _relay(over: Dictionary) -> RefCounted:
	var relay: RefCounted = HoldRelay.new({"relay": Vector2.ZERO, "ring": Vector2.ZERO}, 0.0)
	for key in over:
		relay.rule[key] = over[key]
	return relay


func _check_seeded_charge() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var worst := 0.0
	var runs := 0
	var base_t: float = HoldRelay.RULE["T"]
	for run in SEEDS:
		var occupants := rng.randi_range(1, LIVING)
		var s := rng.randf_range(0.5, 1.5)
		var relay := _relay({"s": s})
		relay.set_occupancy(occupants, LIVING)
		relay.begin()
		var share := float(occupants) / float(LIVING)
		var expected := base_t / pow(share, s)
		var elapsed := 0.0
		var guard := 0
		while relay.held < base_t and guard < 20000:
			relay.step(DT, INSIDE, Vector3.ZERO)
			elapsed += DT
			guard += 1
		var err := absf(elapsed - expected) / expected
		worst = maxf(worst, err)
		runs += 1
	_report("seeded charge time", runs == SEEDS and worst <= TOLERANCE,
		"%d runs, 1 to %d occupants of %d, s 0.5 to 1.5; worst error %.3f%% (tolerance %.0f%%)"
			% [runs, LIVING, LIVING, worst * 100.0, TOLERANCE * 100.0])


func _check_discharge() -> void:
	var drained := _relay({"discharge": 2.0})
	drained.set_occupancy(1, 1)
	drained.begin()
	for i in 600:
		drained.step(DT, INSIDE, Vector3.ZERO)
	var charged: float = drained.held
	for i in 600:
		drained.step(DT, OUTSIDE, Vector3.ZERO)
	_report("discharge drains an empty ring", charged > 9.0 and drained.held == 0.0,
		"charged %.2f s, then 10 s empty at 2 per s: held %.3f (must reach 0)" % [charged, drained.held])

	var paused := _relay({})
	paused.set_occupancy(1, 1)
	paused.begin()
	for i in 600:
		paused.step(DT, INSIDE, Vector3.ZERO)
	var held_before: float = paused.held
	for i in 600:
		paused.step(DT, OUTSIDE, Vector3.ZERO)
	_report("default discharge pauses", absf(paused.held - held_before) < 1e-9,
		"discharge 0: held %.3f before 10 s outside, %.3f after (must stay)" % [held_before, paused.held])


func _check_floor() -> void:
	var floor_r: float = HoldRelay.RULE["radius_floor"]
	var base_r: float = HoldRelay.RULE["radius"]
	var follow := _relay({"follower": 1.0})
	follow.set_occupancy(1, 1)
	follow.begin()
	var lowest := INF
	for i in int((HoldRelay.RULE["T"] + 5.0) / DT):
		follow.step(DT, INSIDE, Vector3.ZERO)
		lowest = minf(lowest, follow.ring_radius)
	var fixed := _relay({})
	fixed.set_occupancy(1, 1)
	fixed.begin()
	var drift := 0.0
	for i in 600:
		fixed.step(DT, INSIDE, Vector3.ZERO)
		drift = maxf(drift, absf(fixed.ring_radius - base_r))
	_report("ring floor and follow", lowest >= floor_r - 1e-9 and absf(follow.ring_radius - floor_r) < 1e-6 and drift < 1e-9,
		"follower 1: lowest ring %.3f m (floor %.1f), at full charge %.3f m; default follower: drift %.3f m from %.1f m"
			% [lowest, floor_r, follow.ring_radius, drift, base_r])


func _check_convergence_counts() -> void:
	var worst := 0.0
	var detail := ""
	for c in [1, 2, 3]:
		var t: Dictionary = HoldRelay.tuned(c)
		var want_r: float = HoldRelay.RULE["radius"] / (2.0 * c)
		var want_t: float = HoldRelay.RULE["T"] / (1.0 + 0.3 * c)
		var er := absf(float(t["radius"]) - want_r) / want_r
		var et := absf(float(t["T"]) - want_t) / want_t
		worst = maxf(worst, maxf(er, et))
		detail += "count %d: radius %.3f m, charge %.3f s; " % [c, t["radius"], t["T"]]
	_report("convergence counts 1 to 3", worst <= TOLERANCE, "%sworst error %.3f%%" % [detail, worst * 100.0])


func _check_count_four() -> void:
	var four: Dictionary = HoldRelay.tuned(4)
	var three: Dictionary = HoldRelay.tuned(3)
	_report("count 4 equals count 3", four == three,
		"count 4 %s, count 3 %s" % [four, three])


func _check_row_cap() -> void:
	var d: Resource = Parts.def(ROW_ID)
	var ok: bool = d != null and d.stack_rule == "capped" and is_equal_approx(d.stack_cap, 3.0)
	var detail := "missing row" if d == null else "stack %s, cap %s" % [d.stack_rule, d.stack_cap]
	_report("convergence row is capped at three", ok, detail)


func _check_seam_gate() -> void:
	var saved: Dictionary = Parts.seams.duplicate()
	Parts.set_seams({})
	var hidden: bool = not ROW_ID in Parts.offer_pool(Items.KEST, ["common"])
	Parts.set_seams({SEAM: true})
	var shown: bool = ROW_ID in Parts.offer_pool(Items.KEST, ["common"])
	Parts.set_seams(saved)
	_report("convergence row waits on its seam", hidden and shown,
		"not offered with no seam: %s; offered once %s is set: %s" % [hidden, SEAM, shown])
