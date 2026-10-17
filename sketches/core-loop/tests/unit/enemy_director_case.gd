extends RefCounted

const Director := preload("res://src/world/director.gd")
const Roster := preload("res://src/combat/roster.gd")
const ClassDef := preload("res://src/core/class_def.gd")

# Pack composition respects the clock (DESIGN-V2 sections 10.5 and 15.4-15.5), stepped
# headless like the stage steps it:
# - tick 0 spawns only chasers and lobbers; reinforcement packs begin at tick 1;
# - the reinforcement weight rises with each tick, and again with each tick past the
#   Warden break (the spike);
# - counters unlock as the ticks rise and a later stage starts with more; every pack
#   composed uses only counters unlocked at that moment;
# - every tagged pack pairs a roster controller with a roster punisher;
# - the stage's ancient family arrives as its own pack;
# - weighting tests the build fairly: an air build draws the air packs more often and
#   every other open pack still comes.

const H := 1.0 / 60.0
const DRAWS := 3000

var _t


func run(t) -> void:
	_t = t
	_clock_gate()
	_weights_and_unlocks()
	_pairs()
	_ancients()
	_build_tilt()
	_class_tilt()


func _report(check: String, ok: bool, detail: String) -> void:
	_t.check(check, ok, detail)


func _clock_gate() -> void:
	var d := Director.new(7)
	d.threat = 1.0
	var t := 0.0
	var early := 0
	var total := 0
	var wrong: Array = []
	var seen := 0
	while t < 170.0:
		var before := d.packs.size()
		var due := d.advance(H, 2, Vector2.ZERO, Vector2(0.0, 14.0), Vector2(0.0, 1.0))
		t += H
		for spawn in due:
			total += 1
			var kind: String = Director.KIND_NAMES[spawn["kind"]]
			if t < Director.TIER_SECONDS and not kind in ["chaser", "lobber"]:
				early += 1
		var unlocked := d.unlocked_counters()
		for i in range(before, d.packs.size()):
			seen += 1
			for kind in d.packs[i]["kinds"]:
				if kind in Director.COUNTERS and not kind in unlocked:
					wrong.append([t, kind])
	_report("tick 0 is quiet", early == 0, "%d reinforcement spawns before the first tick" % early)
	_report("packs come with the clock", seen > 0, "%d packs composed across ticks 1 and 2 of %d spawns" % [seen, total])
	_report("only unlocked counters", wrong.is_empty(), "%d pack members drawn before their unlock %s" % [wrong.size(), wrong.slice(0, 4)])


func _weights_and_unlocks() -> void:
	var d := Director.new(1)
	d.threat = 1.0
	var w := []
	var u := []
	for tier_time in [0.0, Director.TIER_SECONDS, Director.TIER_SECONDS * 2.0]:
		d.stage_time = tier_time
		w.append(d.reinforcement_weight())
		u.append(d.unlocked_counters().size())
	d.spike = true
	d._spike_time = 0.0
	var at_break := d.reinforcement_weight()
	d._spike_time = Director.TIER_SECONDS + 1.0
	var past := d.reinforcement_weight()
	_report("weight rises by tick", w[0] == 0.0 and w[1] < w[2] and w[2] < at_break and at_break < past,
		"weight by tick %s; at the break %.2f, one tick past it %.2f" % [w, at_break, past])
	var late := Director.new(1)
	late.threat = 2.1
	_report("unlocks rise by tick and stage", u[0] < u[1] and u[1] < u[2] and late.unlocked_counters().size() > u[0],
		"stage 1 unlocks %s by tick; stage 3 starts with %d" % [u, late.unlocked_counters().size()])


func _pairs() -> void:
	var bad: Array = []
	for id in Director.PACKS:
		var row: Dictionary = Director.PACKS[id]
		if Roster.row(row["controller"]).get("role", "") != "controller" or Roster.row(row["punisher"]).get("role", "") != "punisher":
			bad.append(id)
	var names_ok := true
	for kind in Roster.COUNTERS + Roster.ANCIENTS:
		names_ok = names_ok and kind in Director.KIND_NAMES
	_report("controller with punisher", bad.is_empty() and names_ok and Director.COUNTERS == Roster.COUNTERS,
		"%d tagged packs, mismatched %s; the director names every reinforcement %s" % [Director.PACKS.size(), bad, names_ok])


func _ancients() -> void:
	var got := []
	for threat in [1.0, 1.25, 2.1]:
		var d := Director.new(3)
		d.threat = threat
		d.stage_time = Director.TIER_SECONDS * 2.0
		var family := ""
		for i in 200:
			var kinds: Array = d.compose()
			if kinds.size() == 1:
				family = kinds[0]
				break
		got.append(family)
	_report("ancient per stage", got == Roster.ANCIENTS, "the ancient pack by stage: %s" % [got])


func _build_tilt() -> void:
	var plain := _draw({})
	var air := _draw({"class": "demolitions_caster", "habits": {"air": 0.5, "jump": 0.3, "ram": 0.2}, "branch_tags": []})
	var air_packs: Array = Director.PACKS.keys().filter(func(id): return Director.PACKS[id]["tests"] == "air")
	var plain_air := 0
	var tilted_air := 0
	for id in air_packs:
		plain_air += int(plain.get(id, 0))
		tilted_air += int(air.get(id, 0))
	var starved: Array = Director.PACKS.keys().filter(func(id): return int(air.get(id, 0)) < DRAWS / 40)
	_report("tests the build", tilted_air > plain_air * 1.4, "air packs drawn %d of %d for an air build, %d with no build read" % [tilted_air, DRAWS, plain_air])
	_report("never a hard counter", starved.is_empty(), "every open pack still drawn for the air build: %s; starved %s" % [air, starved])
	var tree_air := _draw({"class": "", "habits": {}, "branch_tags": ["air", "air"]})
	var tree_count := 0
	for id in air_packs:
		tree_count += int(tree_air.get(id, 0))
	_report("reads W3's branch tags", tree_count > plain_air * 1.4,
		"air packs drawn %d of %d for a tree tagged air twice, %d with no build read" % [tree_count, DRAWS, plain_air])


# CLASS-TILT: the class id fleet.gd build_read() sends is ClassDef.id, so every real pilot id
# must resolve to an axis and, alone (no habits, no tags), tilt that axis's packs up.
func _class_tilt() -> void:
	var plain := _draw({})
	var ids: Array = []
	var bad: Array = []
	for def in ClassDef.all():
		var id := String(def.id)
		ids.append(id)
		var axis: String = Director.CLASS_AXIS.get(id, "")
		var axis_packs: Array = Director.PACKS.keys().filter(func(k): return Director.PACKS[k]["tests"] == axis)
		var drawn := _draw({"class": id, "habits": {}, "branch_tags": []})
		var got := 0
		var base := 0
		for k in axis_packs:
			got += int(drawn.get(k, 0))
			base += int(plain.get(k, 0))
		if axis == "" or axis_packs.is_empty() or got <= base * 1.3:
			bad.append("%s axis [%s] drew %d vs %d plain" % [id, axis, got, base])
	_report("class ids tilt", ids.size() == 6 and bad.is_empty(), "six real pilot ids %s; misses %s" % [ids, bad])


func _draw(build: Dictionary) -> Dictionary:
	var d := Director.new(11)
	d.threat = 2.1
	d.stage_time = Director.TIER_SECONDS * 2.0
	d.spike = true
	d.build = build
	var counts := {}
	var n := 0
	while n < DRAWS:
		var kinds: Array = d.compose()
		if kinds.size() < 2:
			continue
		var id: String = d.packs[-1]["id"]
		counts[id] = int(counts.get(id, 0)) + 1
		n += 1
	return counts
