extends SceneTree

const SurvivalCount := preload("res://src/world/survival_count.gd")
const Director := preload("res://src/world/director.gd")
const ItemGen := preload("res://src/build/item_gen.gd")

# The survival count's rule (BACKLOG W1-101), judged on the pure module with no scene:
# (a) the opening counts add one kind of machine each, every machine is one the director knows,
#     and a count under 1 has no pack;
# (b) a cleared floor opens the gate, which stays open for gate_s and no longer, and leaving
#     through it banks exactly that count's pay;
# (c) leaving with the gate shut banks nothing and the count goes on;
# (d) staying past the gate brings the next count, and no count pays less scrap, fewer cores, fewer
#     part rolls or a lower grade of roll than the one before;
# (e) a count not cleared gets the next on top of it at count_s and not before, with no gate; a
#     clear after that credits the later count and pays it;
# (f) there is no last count: count 30 still has a bigger pack, hits harder than count 29 and pays
#     more part rolls;
# (g) every paid roll is a grade the item generator knows; a relic is paid at counts 8 and 12 and
#     nowhere under 8;
# (h) a forfeit during an open gate pays nothing and keeps the best count;
# (i) the camp ring may be left at any time and keeps a record in place of pay;
# (j) the flood rises a metre a count and stops at its top;
# (k) a still form's ground stays where it landed; a looping form's sets off along the ball's
#     heading, stays one radius from a centre to the right of that heading, is a full circle
#     across at half a lap and back on the landing point after one lap;
# (l) a looping form's ways are its own circle to the right then the left, then each tighter circle the same, then
#     holding, and begin() takes the first whose lap its caller says fits; a way to the left sets off along the
#     heading too with its centre on the left; a tighter circle is ridden at the same pace; the way that holds stays
#     put; a still form only holds;
# (m) a way's course starts on the landing point, stays on that way's circle, has points no further apart than
#     COURSE_STEP_M, and matches where the ground is at that share of a lap; the holding way's course is one point.

const DT := 0.1
const EXPECTED_REPORTS := 13

var _failures := 0
var _reports := 0


func _initialize() -> void:
	_opening()
	_gate_banks()
	_shut_gate_pays_nothing()
	_staying_pays_more()
	_pile()
	_no_last_count()
	_grades()
	_forfeit()
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


# Steps with `standing` machines until an event other than "" comes back or `seconds` pass.
# Returns [event, seconds stepped].
func _until(rule, standing: int, seconds: float) -> Array:
	var t := 0.0
	while t < seconds - 0.0001:
		t += DT
		var event: String = rule.step(DT, standing)
		if event != "":
			return [event, t]
	return ["", t]


# Clears count after count, staying through each gate, until count `n` stands cleared with its
# gate open.
func _clear_to(rule, n: int) -> void:
	rule.begin()
	for k in range(1, n + 1):
		rule.step(DT, 0)
		if k < n:
			_until(rule, 0, 6.0)


func _opening() -> void:
	var rule := SurvivalCount.new()
	var ok := true
	for n in range(1, 6):
		var pack: Array = rule.pack(n)
		ok = ok and _kinds(pack) == n
		for kind in pack:
			ok = ok and kind in Director.KIND_NAMES
	ok = ok and rule.pack(0).is_empty()
	_report("(a) counts 1 to 5 hold 1 to 5 kinds the director knows", ok, str(rule.pack(5)))


func _gate_banks() -> void:
	var rule := SurvivalCount.new()
	_clear_to(rule, 3)
	var open_at_start: bool = rule.gate_open and is_equal_approx(rule.gate_left(), 5.0)
	var held: Array = _until(rule, 0, 4.9)
	var still_open: bool = held[0] == "" and rule.gate_open
	var paid: Dictionary = rule.leave()
	var shut := SurvivalCount.new()
	_clear_to(shut, 3)
	var closed: Array = _until(shut, 0, 5.2)
	_report("(b) the gate stays open 5 s and leaving banks count 3's pay", open_at_start and still_open and paid == rule.pay(3) and paid["rarities"] == ["rare"] and rule.done and closed[0] == "count" and not shut.gate_open, "%s after %.1f s, %s" % [closed[0], closed[1], paid])


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
	var last := {"scrap": 0, "cores": 0, "rarities": []}
	for n in range(1, 14):
		ok = ok and rule.step(DT, 0) == "gate" and rule.cleared == n
		var worth: Dictionary = rule.pay(rule.cleared)
		ok = ok and int(worth["scrap"]) >= int(last["scrap"]) and int(worth["cores"]) >= int(last["cores"])
		ok = ok and (worth["rarities"] as Array).size() >= (last["rarities"] as Array).size()
		# Part by part: the nth part of this count is never a lower grade than the nth part of the count before.
		for i in (last["rarities"] as Array).size():
			ok = ok and ItemGen.RARITIES.find(worth["rarities"][i]) >= ItemGen.RARITIES.find(last["rarities"][i])
		last = worth
		var next: Array = _until(rule, 0, 6.0)
		ok = ok and next[0] == "count" and rule.count == n + 1
	_report("(d) staying brings the next count and no count pays less", ok, "reached count %d" % rule.count)


func _pile() -> void:
	var rule := SurvivalCount.new()
	rule.begin()
	var early: Array = _until(rule, 3, 24.8)
	var left: float = rule.count_left()
	var piled: Array = _until(rule, 3, 1.0)
	var ok: bool = early[0] == "" and left > 0.0 and left < 0.5 and piled[0] == "pile" and rule.count == 2 and not rule.gate_open and rule.cleared == 0
	var opened: String = rule.step(DT, 0)
	var paid: Dictionary = rule.leave()
	ok = ok and opened == "gate" and rule.cleared == 2 and paid == rule.pay(2)
	_report("(e) an uncleared count piles at 25 s, and a clear after it pays count 2", ok, "%s then %s" % [piled[0], opened])


func _no_last_count() -> void:
	var rule := SurvivalCount.new()
	var ok: bool = rule.pack(30).size() > rule.pack(5).size()
	ok = ok and rule.strength(30) > rule.strength(29) and is_equal_approx(rule.strength(5), 1.0) and is_equal_approx(rule.strength(6), 1.35)
	ok = ok and (rule.pay(30)["rarities"] as Array).size() > (rule.pay(29)["rarities"] as Array).size()
	# The extra rogue machines arrive on every third count past the opening five: none at 6 and 7, one from 8, two from 11.
	var rogues := func(n: int) -> int: return rule.pack(n).count("reactor_relic")
	ok = ok and rogues.call(5) == 1 and rogues.call(7) == 1 and rogues.call(8) == 2 and rogues.call(10) == 2 and rogues.call(11) == 3
	_report("(f) there is no last count", ok, "count 10 is x%.2f" % rule.strength(10))


func _grades() -> void:
	var rule := SurvivalCount.new()
	var ok := true
	for n in range(1, 31):
		for rarity in rule.pay(n)["rarities"]:
			ok = ok and rarity in ItemGen.RARITIES
	for n in range(1, 8):
		ok = ok and not ("relic" in rule.pay(n)["rarities"])
	ok = ok and (rule.pay(8)["rarities"] as Array).count("relic") == 1 and (rule.pay(11)["rarities"] as Array).count("relic") == 1 and (rule.pay(12)["rarities"] as Array).count("relic") == 2
	_report("(g) every roll is a known grade; a relic at counts 8 and 12, none under 8", ok, str(rule.pay(8)))


func _forfeit() -> void:
	var rule := SurvivalCount.new()
	_clear_to(rule, 2)
	var open: bool = rule.gate_open
	var best: int = rule.forfeit()
	_report("(h) a forfeit during an open gate pays nothing and keeps the best count", open and best == 2 and rule.done and rule.leave().is_empty() and rule.step(DT, 0) == "")


func _ring() -> void:
	var rule := SurvivalCount.new(1, "ring")
	_clear_to(rule, 1)
	_until(rule, 0, 6.0)
	rule.step(DT, 4)
	var shut: bool = not rule.gate_open
	var paid: Dictionary = rule.leave()
	_report("(i) the camp ring is left at any time for a record", shut and paid == {"record": 1}, str(paid))


func _flood() -> void:
	var rule := SurvivalCount.new()
	var ok: bool = is_zero_approx(rule.hazard(1)["level"]) and is_equal_approx(rule.hazard(3)["level"], 2.0) and is_equal_approx(rule.hazard(9)["level"], 4.0) and rule.hazard(1)["kind"] == "flood"
	_report("(j) the flood rises a metre a count to four", ok)


func _moves() -> void:
	var landed := Vector2(40.0, -120.0)
	var heading := Vector2(0.0, 1.0)
	var loop: Dictionary = SurvivalCount.MOVES["loop"]
	var radius := float(loop["radius_m"])
	var lap := float(loop["lap_s"])
	var yard := SurvivalCount.new(1, "yard")
	yard.begin(landed, heading)
	yard.step(20.0, 3)
	var ok: bool = yard.ground() == landed
	var muster := SurvivalCount.new(1, "muster")
	muster.begin(landed, heading, func(_lap: PackedVector2Array) -> bool: return true)
	var unasked := SurvivalCount.new(1, "muster")
	unasked.begin(landed, heading)
	ok = ok and unasked.way == 0.0 and muster.way == radius
	ok = ok and muster.ground().distance_to(landed) < 0.01
	muster.step(1.0, 3)
	var first: Vector2 = muster.ground() - landed
	ok = ok and first.normalized().dot(heading) > 0.95
	var centre := landed - heading.orthogonal() * radius
	ok = ok and is_equal_approx(muster.ground().distance_to(centre), radius)
	muster.step(lap * 0.5 - 1.0, 3)
	ok = ok and absf(muster.ground().distance_to(landed) - radius * 2.0) < 0.01
	muster.step(lap * 0.5, 3)
	ok = ok and muster.ground().distance_to(landed) < 0.01
	_report("(k) a still ground stays put; a looping ground sets off ahead and comes back each lap", ok, "first second moved %s" % first)
	var tight: Array = loop["tighter_m"]
	var ways := SurvivalCount.ways("muster")
	ok = ways == [radius, -radius, float(tight[0]), -float(tight[0]), float(tight[1]), -float(tight[1]), 0.0]
	ok = ok and SurvivalCount.ways("yard") == [0.0] and SurvivalCount.ways("ring") == [0.0]
	# Each way is taken when every lap before it is refused, and the lap handed over is that way's course.
	for i in ways.size():
		var seen := []
		var picky := SurvivalCount.new(1, "muster")
		picky.begin(landed, heading, func(lap: PackedVector2Array) -> bool:
			seen.append(lap)
			return seen.size() > i)
		ok = ok and picky.way == ways[i] and seen.size() == mini(i + 1, ways.size() - 1)
		ok = ok and (seen.is_empty() or seen[-1] == SurvivalCount.course(landed, heading, ways[mini(i, ways.size() - 2)]))
	var left := _riding(landed, heading, 1)
	left.step(1.0, 3)
	var left_first: Vector2 = left.ground() - landed
	ok = ok and left.way == -radius and left_first.normalized().dot(heading) > 0.95
	ok = ok and is_equal_approx(left.ground().distance_to(landed + heading.orthogonal() * radius), radius)
	ok = ok and left_first.dot(heading.orthogonal()) * first.dot(heading.orthogonal()) < 0.0
	var small := _riding(landed, heading, 4)
	small.step(1.0, 3)
	ok = ok and small.way == float(tight[1]) and absf((small.ground() - landed).length() - first.length()) < 0.2
	small.step(lap * float(tight[1]) / radius - 1.0, 3)
	ok = ok and small.ground().distance_to(landed) < 0.01
	var held := _riding(landed, heading, ways.size())
	held.step(lap * 0.3, 3)
	ok = ok and held.way == 0.0 and held.ground() == landed
	var still := SurvivalCount.new(1, "yard")
	still.begin(landed, heading, func(_lap: PackedVector2Array) -> bool: return true)
	ok = ok and still.way == 0.0
	_report("(l) ways: right, left, tighter, hold, each taken when the laps before it do not fit; left sets off ahead too; tighter keeps the pace", ok, "ways %s" % [ways])
	ok = true
	for way in ways:
		var course := SurvivalCount.course(landed, heading, way)
		if is_zero_approx(way):
			ok = ok and course == PackedVector2Array([landed])
			continue
		var centre_w: Vector2 = landed - heading.orthogonal() * way
		var rider := _riding(landed, heading, ways.find(way))
		rider.step(lap * absf(way) / radius / course.size(), 3)
		ok = ok and course[0] == landed and course[1].distance_to(rider.ground()) < 0.01
		for i in course.size():
			ok = ok and is_equal_approx(course[i].distance_to(centre_w), absf(way))
			ok = ok and course[i].distance_to(course[(i + 1) % course.size()]) <= SurvivalCount.COURSE_STEP_M + 0.001
	_report("(m) a course starts on the landing, keeps to its circle in short steps and is where the ground goes", ok)


# A muster begun on its way number `refused`: the laps of the ways before it are refused.
func _riding(landed: Vector2, heading: Vector2, refused: int) -> SurvivalCount:
	var asked := [0]
	var count := SurvivalCount.new(1, "muster")
	count.begin(landed, heading, func(_lap: PackedVector2Array) -> bool:
		asked[0] += 1
		return asked[0] > refused)
	return count
