extends SceneTree

const SurvivalCount := preload("res://src/world/survival_count.gd")
const Director := preload("res://src/world/director.gd")

# The survival count's rule (BACKLOG W1-101), judged on the pure module with no scene:
# (a) the opening counts add one kind of machine each, and every machine is one the director knows;
# (b) a cleared floor opens the gate for gate_s, and leaving through it banks that count's pay;
# (c) leaving with the gate shut banks nothing and the count goes on;
# (d) staying past the gate brings the next count, and its pay is never less than the last;
# (e) a count not cleared in count_s gets the next one on top of it, with no gate;
# (f) there is no last count: count 30 still has a pack, hits harder than count 29 and pays more parts;
# (g) cobalt is paid at counts 8 and 12 and nowhere under 8;
# (h) a broken ball is paid nothing;
# (i) the camp ring may be left at any time and keeps a record in place of pay;
# (j) the flood rises a metre a count and stops at its top;
# (k) a still form's ground stays where it landed, and a looping form's leaves, stays one radius
#     from its circle's centre and is back on the landing point after one lap.

const DT := 0.1
const EXPECTED_REPORTS := 11

var _failures := 0
var _reports := 0


func _initialize() -> void:
	_opening()
	_gate_banks()
	_shut_gate_pays_nothing()
	_staying_pays_more()
	_pile()
	_no_last_count()
	_cobalt()
	_broken()
	_ring()
	_flood()
	_moves()
	if _reports != EXPECTED_REPORTS:
		_failures += 1
		print("FAIL report count: %d of %d checks reported (a check died mid-way)" % [_reports, EXPECTED_REPORTS])
	print("survival_count_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _report(name: String, ok: bool, detail := "") -> void:
	_reports += 1
	if not ok:
		_failures += 1
	print("%s %s%s" % ["PASS" if ok else "FAIL", name, "" if detail == "" else ": " + detail])


func _kinds(pack: Array) -> int:
	var seen := {}
	for kind in pack:
		seen[kind] = true
	return seen.size()


# Steps until an event other than "" comes back, for at most `seconds`.
func _until(rule, standing: int, seconds: float) -> String:
	var t := 0.0
	while t < seconds:
		var event: String = rule.step(DT, standing)
		if event != "":
			return event
		t += DT
	return ""


func _opening() -> void:
	var rule := SurvivalCount.new()
	var ok := true
	for n in range(1, 6):
		var pack: Array = rule.pack(n)
		ok = ok and _kinds(pack) == n
		for kind in pack:
			ok = ok and kind in Director.KIND_NAMES
	_report("(a) counts 1 to 5 hold 1 to 5 kinds the director knows", ok, str(rule.pack(5)))


func _gate_banks() -> void:
	var rule := SurvivalCount.new()
	rule.begin()
	var opened: String = rule.step(DT, 0)
	var left: float = rule.gate_left()
	var paid: Dictionary = rule.leave()
	_report("(b) a cleared floor opens the gate and leaving banks count 1", opened == "gate" and is_equal_approx(left, 5.0) and int(paid.get("scrap", 0)) == 180 and rule.done, "%s %s %s" % [opened, left, paid])


func _shut_gate_pays_nothing() -> void:
	var rule := SurvivalCount.new()
	rule.begin()
	rule.step(DT, 3)
	var paid: Dictionary = rule.leave()
	_report("(c) leaving with the gate shut banks nothing and the count goes on", paid.is_empty() and not rule.done and rule.count == 1)


func _staying_pays_more() -> void:
	var rule := SurvivalCount.new()
	rule.begin()
	var ok := true
	var last := 0
	for n in range(1, 13):
		ok = ok and rule.step(DT, 0) == "gate"
		var worth: Dictionary = rule.pay(rule.cleared)
		var size: int = (worth["parts"] as Array).size() * 10 + int(worth["cores"])
		ok = ok and size >= last and rule.cleared == n
		last = size
		ok = ok and _until(rule, 0, 6.0) == "count" and rule.count == n + 1
	_report("(d) staying past the gate brings the next count and never pays less", ok, "reached count %d" % rule.count)


func _pile() -> void:
	var rule := SurvivalCount.new()
	rule.begin()
	var event := _until(rule, 3, 30.0)
	_report("(e) an uncleared count gets the next on top, with no gate", event == "pile" and rule.count == 2 and not rule.gate_open and rule.cleared == 0, event)


func _no_last_count() -> void:
	var rule := SurvivalCount.new()
	var ok: bool = rule.pack(30).size() > rule.pack(5).size()
	ok = ok and rule.strength(30) > rule.strength(29) and is_equal_approx(rule.strength(5), 1.0) and is_equal_approx(rule.strength(6), 1.35)
	ok = ok and (rule.pay(30)["parts"] as Array).size() > (rule.pay(29)["parts"] as Array).size()
	_report("(f) there is no last count", ok, "count 10 is x%.2f" % rule.strength(10))


func _cobalt() -> void:
	var rule := SurvivalCount.new()
	var ok := true
	for n in range(1, 8):
		ok = ok and not ("cobalt" in rule.pay(n)["parts"])
	ok = ok and (rule.pay(8)["parts"] as Array).count("cobalt") == 1 and (rule.pay(11)["parts"] as Array).count("cobalt") == 1 and (rule.pay(12)["parts"] as Array).count("cobalt") == 2
	_report("(g) cobalt at counts 8 and 12, none under 8", ok, str(rule.pay(8)))


func _broken() -> void:
	var rule := SurvivalCount.new()
	rule.begin()
	rule.step(DT, 0)
	_until(rule, 0, 6.0)
	var best: int = rule.broken()
	_report("(h) a broken ball is paid nothing and keeps its best count", best == 1 and rule.done and rule.leave().is_empty())


func _ring() -> void:
	var rule := SurvivalCount.new(1, "ring")
	rule.begin()
	rule.step(DT, 0)
	_until(rule, 0, 6.0)
	rule.step(DT, 4)
	var paid: Dictionary = rule.leave()
	_report("(i) the camp ring is left at any time for a record", paid == {"record": 1}, str(paid))


func _flood() -> void:
	var rule := SurvivalCount.new()
	var ok: bool = is_zero_approx(rule.hazard(1)["level"]) and is_equal_approx(rule.hazard(3)["level"], 2.0) and is_equal_approx(rule.hazard(9)["level"], 4.0) and rule.hazard(1)["kind"] == "flood"
	_report("(j) the flood rises a metre a count to four", ok)


func _moves() -> void:
	var landed := Vector2(40.0, -120.0)
	var heading := Vector2(0.0, 1.0)
	var yard := SurvivalCount.new(1, "yard")
	var muster := SurvivalCount.new(1, "muster")
	var loop: Dictionary = SurvivalCount.MOVES["loop"]
	var radius := float(loop["radius_m"])
	var lap := float(loop["lap_s"])
	var ok: bool = yard.ground_at(landed, heading, 20.0) == landed
	ok = ok and muster.ground_at(landed, heading, 0.0).distance_to(landed) < 0.01
	ok = ok and muster.ground_at(landed, heading, lap).distance_to(landed) < 0.01
	ok = ok and is_equal_approx(muster.ground_at(landed, heading, lap * 0.5).distance_to(landed), radius * 2.0)
	var centre := landed + heading.orthogonal() * radius
	for i in 9:
		ok = ok and is_equal_approx(muster.ground_at(landed, heading, lap * i / 9.0).distance_to(centre), radius)
	ok = ok and muster.ground_at(landed, Vector2.ZERO, 0.0).distance_to(landed) < 0.01
	_report("(k) a still ground stays put and a looping ground comes back each lap", ok)
