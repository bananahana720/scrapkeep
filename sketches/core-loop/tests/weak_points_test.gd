extends SceneTree

const WeakPoints := preload("res://src/boss/weak_points.gd")
const T := preload("res://tests/support/t.gd")

# The weak-point rule as pure logic: the off identity, the chip on everything but a reel impact on
# an open point, the seal wearing and breaking, the re-seal clock, the crew's fit, and the numbers
# override. Evidence limit: rule only, no boss scene is wired to it yet.

var _t := T.new("weak_points_test")


func _initialize() -> void:
	_run()
	quit(_t.verdict())


func _parts() -> Array:
	return [{"id": "vent", "seal_hp": 10.0, "removes": "slag"}, {"id": "eye", "seal_hp": 4.0, "removes": "beam"}]


func _hit(point: String, reel: bool, punch := 3.0) -> Dictionary:
	return {"point": point, "reel": reel, "punch": punch, "gain": 20.0}


func _land(rule, hit: Dictionary, now: float) -> Dictionary:
	var answer: Dictionary = rule.judge(hit)
	rule.apply(answer, now)
	return answer


func _run() -> void:
	# Identity: off, and enabled with no parts.
	for rule in [WeakPoints.off(), WeakPoints.new([]), WeakPoints.new(_parts(), {}, false)]:
		var scales := []
		for hit in [_hit("", false), _hit("", true), _hit("vent", true), _hit("vent", false)]:
			scales.append(_land(rule, hit, 1.0)["gain_scale"])
		rule.open("vent", 1.0)
		for i in 50:
			_land(rule, _hit("vent", true, 99.0), 1.0 + i)
			rule.begin_fit("vent", 1.0 + i)
			rule.step(2.0 + i)
		_t.eq("identity: every hit counts in full", scales, [1.0, 1.0, 1.0, 1.0])
		_t.check("identity: no state moves", rule.open_points().is_empty() and rule.removed_families().is_empty()
				and rule.state("vent") == WeakPoints.SHUT and rule.fitters("vent") == 0, "state %d" % rule.state("vent"))

	# Chip: body, non-reel on an open point, any hit on a shut point.
	var rule := WeakPoints.new(_parts())
	_t.near("chip: a body hit", _land(rule, _hit("", true), 0.0)["gain_scale"], WeakPoints.CHIP)
	_t.near("chip: a reel impact on a shut point", _land(rule, _hit("vent", true), 0.0)["gain_scale"], WeakPoints.CHIP)
	_t.check("chip: a shut point is untouched", rule.state("vent") == WeakPoints.SHUT and rule.seal_hp("vent") == 10.0, "hp %.1f" % rule.seal_hp("vent"))
	rule.open("vent", 0.0)
	var plain := _land(rule, _hit("vent", false), 0.0)
	_t.check("chip: a non-reel hit on an open point", is_equal_approx(plain["gain_scale"], WeakPoints.CHIP) and rule.seal_hp("vent") == 10.0
			and plain["damage"] == 0.0, "scale %.2f, hp %.1f" % [plain["gain_scale"], rule.seal_hp("vent")])
	_t.check("judge changes nothing", not rule.judge(_hit("vent", true, 99.0))["removes"].is_empty() and rule.state("vent") == WeakPoints.OPEN
			and rule.seal_hp("vent") == 10.0, "state %d, hp %.1f" % [rule.state("vent"), rule.seal_hp("vent")])

	# A reel impact on an open point: full gain, wears the seal, breaks, removes the family.
	var wear := _land(rule, _hit("vent", true, 3.0), 1.0)
	_t.check("reel on open: full gain and the punch off the seal", wear["gain_scale"] == 1.0 and wear["damage"] == 3.0 and not wear["broke"]
			and is_equal_approx(rule.seal_hp("vent"), 7.0) and rule.removed_families().is_empty(), "hp %.1f" % rule.seal_hp("vent"))
	var broke := _land(rule, _hit("vent", true, 8.0), 2.0)
	_t.check("reel on open: a big enough punch breaks it", broke["broke"] and broke["removes"] == "slag" and broke["damage"] == 7.0
			and rule.state("vent") == WeakPoints.BROKEN and rule.removed_families() == ["slag"], "families %s" % [rule.removed_families()])
	_t.near("after a break a hit there pays full: the body stands bare until the next open", _land(rule, _hit("vent", true, 5.0), 3.0)["gain_scale"], 1.0)
	rule.step(100.0)
	_t.eq("a broken point stays broken", rule.state("vent"), WeakPoints.BROKEN)

	# Bare only with no point open: a break while another point stands open keeps the body chipped.
	rule = WeakPoints.new(_parts())
	rule.open("vent", 0.0)
	rule.open("eye", 0.0)
	_land(rule, _hit("vent", true, 99.0), 1.0)
	var bare_open := rule.bare()
	_t.near("a break with another point open: the body is still chipped", _land(rule, _hit("", true), 1.5)["gain_scale"], WeakPoints.CHIP)
	rule.step(7.0)
	_t.check("that point re-seals: the body stands bare and pays full", bare_open and rule.open_points().is_empty()
			and is_equal_approx(_land(rule, _hit("", true), 7.5)["gain_scale"], 1.0), "open %s" % [rule.open_points()])

	# Re-seal clock.
	rule = WeakPoints.new(_parts())
	rule.open("vent", 0.0)
	rule.open("eye", 0.0)
	rule.step(5.9)
	var still_open: bool = rule.state("vent") == WeakPoints.OPEN
	rule.step(6.0)
	_t.check("re-seal: no hit, shut at open_seconds", still_open and rule.state("vent") == WeakPoints.SHUT and rule.open_points().is_empty(), "state %d" % rule.state("vent"))
	rule.open("vent", 10.0)
	rule.open("eye", 10.0)
	rule.step(15.0)
	_land(rule, _hit("vent", true, 1.0), 15.0)
	rule.step(16.5)
	_t.check("re-seal: a reel hit at t=5 keeps it past t=6", rule.state("vent") == WeakPoints.OPEN and rule.state("eye") == WeakPoints.SHUT, "open %s" % [rule.open_points()])
	rule.step(21.0)
	_t.eq("re-seal: and it then runs out", rule.state("vent"), WeakPoints.SHUT)

	# Fit.
	rule = WeakPoints.new(_parts())
	rule.open("vent", 0.0)
	rule.begin_fit("vent", 0.0)
	rule.begin_fit("vent", 0.0)
	_t.eq("fit: two fitters counted", rule.fitters("vent"), 2)
	rule.step(WeakPoints.FIT_SECONDS - 0.1)
	var held: bool = rule.state("vent") == WeakPoints.OPEN
	rule.step(WeakPoints.FIT_SECONDS)
	_t.check("fit: two fitters held for fit_seconds seal it", held and rule.state("vent") == WeakPoints.SHUT, "state %d" % rule.state("vent"))
	rule = WeakPoints.new(_parts())
	rule.open("vent", 0.0)
	rule.begin_fit("vent", 0.0)
	rule.begin_fit("vent", 0.0)
	rule.step(WeakPoints.FIT_SECONDS - 0.1)
	rule.knock_fit("vent")
	rule.step(WeakPoints.FIT_SECONDS + 0.5)
	_t.check("fit: a knock at fit_seconds - 0.1 keeps it open", rule.fitters("vent") == 1 and rule.state("vent") == WeakPoints.OPEN, "state %d" % rule.state("vent"))
	rule = WeakPoints.new(_parts(), {"open_seconds": 100.0})
	rule.open("vent", 0.0)
	rule.begin_fit("vent", 0.0)
	rule.step(50.0)
	_t.eq("fit: one fitter never seals", rule.state("vent"), WeakPoints.OPEN)
	rule.begin_fit("vent", 50.0)
	rule.step(53.4)
	var late_held: bool = rule.state("vent") == WeakPoints.OPEN
	rule.step(53.5)
	_t.check("fit: the clock starts when the second fitter arrives", late_held and rule.state("vent") == WeakPoints.SHUT, "state %d" % rule.state("vent"))

	# Numbers override.
	rule = WeakPoints.new(_parts(), {"chip": 0.5})
	_t.near("numbers: a chip override", _land(rule, _hit("", true), 0.0)["gain_scale"], 0.5)

	# Planted control: the wrong expectation (a body hit at full gain) must read as a failure.
	rule = WeakPoints.new(_parts())
	var wrong: bool = _land(rule, _hit("", true), 0.0)["gain_scale"] == 1.0
	_t.check("planted control: an enabled body hit at 1.0 is caught wrong", not wrong, "body hit scaled %.2f" % rule.judge(_hit("", true))["gain_scale"])
