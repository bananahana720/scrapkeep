# smoke: timeout=360s (153.9 s in a w21 chunk and 167.6-174.3 s solo on 4-core cloud boxes; killed at the 180 s default cap in a w22 chunk and solo, gate/w22-81c42290)
extends SceneTree

const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const PartDef := preload("res://src/build/part_def.gd")
const Items := preload("res://src/build/items.gd")
const Palette := preload("res://src/core/palette.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")

# SI4 shot bits (W13-INTEGRATION-3.md, SI4; comps/isaac/items-and-synergies.md:89,
# TADR-008 line 24: a closed table, no framework). Each part adds zero to two bits from
# a closed set of five (pierce, bounce, split, pull, heat); a shot carries the OR of its
# parts' bits, capped at three; child bolts copy the set; one table row per bit holds
# its colour, its sound and its rule, so sight and sound read one record.
#
# (a) the closed set: five names, five distinct powers of two.
# (b) the table: every bit has a palette colour (never HAZARD), a baked sound and a rule;
#     colours and sounds are distinct; a bit's tell reads colour and sound off one row;
#     a planted row missing its sound is refused.
# (c) the pair table: every pair of distinct bits has a declared outcome; removing one
#     planted pair makes it unspecified.
# (d) parts: every live part carries 0 to 2 bits; a planted three-bit row is trimmed.
# (e) the OR and the cap: union, idempotent copies, order of held parts, a fourth bit
#     dropped and reported.
# (f) children copy the set (bolts.gd), and a bolt fired with no set carries none.
# (g) 10,000 random 6-part builds drawn through Parts.roll: zero unspecified pairs, at
#     least 30% reach 3 bits, at most 3 bits per shot; the same seed gives the same
#     numbers.
# (h) the worst build's bit work for a full live pool stays inside the frame budget.
# (i) set operations only: no equality on a set in shot_bits.gd or bolts.gd, with a
#     planted control.

const MODULE := "res://src/build/shot_bits.gd"
const BOLTS := "res://src/combat/bolts.gd"
const BUILDS := 10000
const BUILD_SIZE := 6
const OFFER_SIZE := 2
const SEED := 1
const SHARE3_TARGET := 0.30
# The frame budget as work, not wall time (sketch-lint L1): per live bolt a tick the bit
# layer reads one tell per bit and one pair row per pair, so a full pool of the worst
# build reads at most MAX_LIVE * (3 + 3) rows, however many parts are held.
const READS_PER_BOLT_CAP := 6
const LONG_BUILD := 20
# A runtime script error aborts a check function without failing the run, so every
# check must report: fewer than this many verdicts is itself a failure.
const EXPECTED_REPORTS := 11
# An equality or inequality on a set-named value: a line naming bits or mask with == or !=.
const SET_EQUALITY := "(bits|mask)[A-Za-z_\\]\\)\"]*\\s*[!=]=|[!=]=\\s*[A-Za-z_.]*(bits|mask)"

var _failures := 0
var _reports := 0
var S


func _initialize() -> void:
	if not ResourceLoader.exists(MODULE):
		_report("shot bits module", false, "%s is missing" % MODULE)
		_finish()
		return
	S = load(MODULE)
	_check_closed_set()
	_check_table()
	_check_pairs()
	_check_parts()
	_check_or_and_cap()
	_check_children()
	_check_compose()
	_check_frame_budget()
	_check_set_operations()
	_finish()


func _finish() -> void:
	if _reports != EXPECTED_REPORTS:
		_failures += 1
		print("FAIL report count: %d of %d checks reported (a check died mid-way)" % [_reports, EXPECTED_REPORTS])
	print("shot_bits_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _report(label: String, ok: bool, detail: String) -> void:
	_reports += 1
	print("%s %s: %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures += 1


func _check_closed_set() -> void:
	var values: Array = []
	var all := 0
	for name in S.NAMES:
		var b: int = S.bit(name)
		values.append(b)
		all = all | b
	var powers: bool = values.all(func(v): return v > 0 and (v & (v - 1)) < 1)
	var distinct := {}
	for v in values:
		distinct[v] = true
	_report("closed set of five bits", S.NAMES == ["pierce", "bounce", "split", "pull", "heat"]
		and powers and distinct.size() == 5 and all == S.ALL and S.bit("not_a_bit") < 1,
		"names %s, values %s, all %d, unknown -> %d" % [S.NAMES, values, all, S.bit("not_a_bit")])


func _check_table() -> void:
	var palette: Dictionary = (Palette as GDScript).get_script_constant_map()
	var palette_colors: Array = palette.values().filter(func(v): return v is Color)
	var bad: Array = []
	var colors := {}
	var sounds := {}
	for name in S.NAMES:
		var row: Dictionary = S.TABLE.get(name, {})
		var color = row.get("color")
		var sound := String(row.get("sound", ""))
		if not color is Color or not color in palette_colors:
			bad.append("%s colour %s is not a palette colour" % [name, color])
		elif color == Palette.HAZARD:
			bad.append("%s draws in HAZARD" % name)
		if not SfxBank.has_recipe(sound):
			bad.append("%s sound '%s' has no recipe" % [name, sound])
		if String(row.get("rule", "")).strip_edges() == "":
			bad.append("%s has no rule" % name)
		colors[color] = true
		sounds[sound] = true
	_report("one table: colour, sound and rule per bit", bad.is_empty() and S.TABLE.size() == 5
		and colors.size() == 5 and sounds.size() == 5 and S.table_problems(S.TABLE).is_empty(),
		"%d rows, %d distinct colours, %d distinct sounds, problems %s" % [S.TABLE.size(), colors.size(), sounds.size(), bad])
	# Sight and sound paired: each tell is read off the one row for its bit.
	var unpaired: Array = []
	var tells: Array = S.tells(S.ALL)
	for tell in tells:
		var row: Dictionary = S.TABLE[tell["bit"]]
		if tell["color"] != row["color"] or tell["sound"] != row["sound"] or tell["rule"] != row["rule"]:
			unpaired.append(tell["bit"])
	var planted: Dictionary = S.TABLE.duplicate(true)
	planted["heat"] = {"color": Palette.AMBER, "rule": "planted row with no sound"}
	var caught: Array = S.table_problems(planted)
	_report("tells read colour and sound off one row", tells.size() == 5 and unpaired.is_empty()
		and S.tells(0).is_empty() and caught.size() == 1,
		"%d tells for the full set, unpaired %s, empty set -> %d tells; planted soundless row -> %s"
			% [tells.size(), unpaired, S.tells(0).size(), caught])


func _check_pairs() -> void:
	var missing: Array = []
	var checked := 0
	for i in S.NAMES.size():
		for j in range(i + 1, S.NAMES.size()):
			checked += 1
			var a: String = S.NAMES[i]
			var b: String = S.NAMES[j]
			var out: String = S.pair_outcome(a, b)
			if out.strip_edges() == "" or out != S.pair_outcome(b, a):
				missing.append([a, b])
	var reduced: Dictionary = S.PAIRS.duplicate()
	var removed: bool = reduced.erase(S.pair_key("pierce", "heat"))
	var planted: int = S.unspecified_pairs(S.bit("pierce") | S.bit("heat"), reduced)
	var clean: int = S.unspecified_pairs(S.ALL)
	_report("every bit pair declared", checked == 10 and missing.is_empty() and S.PAIRS.size() == 10
		and removed and planted == 1 and clean == 0,
		"%d pairs checked, missing %s; full set -> %d unspecified; pierce+heat removed -> %d unspecified"
			% [checked, missing, clean, planted])


func _check_parts() -> void:
	var over: Array = []
	var stray: Array = []
	var with_bits := 0
	var ids: Array = Parts.ids()
	for part_id in ids:
		var d: Resource = Parts.def(part_id)
		if d == null:
			continue
		var n: int = S.count(d.bits)
		if n > S.MAX_PART_BITS:
			over.append(part_id)
		if S.without(d.bits, S.ALL) > 0:
			stray.append(part_id)
		if n > 0:
			with_bits += 1
	var planted: Resource = PartDef.from_row("planted_three", {"bits": ["pierce", "bounce", "heat"]})
	var from_tags: Resource = PartDef.from_row("planted_tags", {"tags": ["kinetic", "chain"]})
	var none: Resource = PartDef.from_row("planted_none", {"tags": ["speed"]})
	_report("parts carry zero to two bits", ids.size() > 0 and over.is_empty() and stray.is_empty() and with_bits > 0
		and S.count(planted.bits) == S.MAX_PART_BITS and S.count(from_tags.bits) == 2 and S.count(none.bits) == 0,
		"%d parts, %d carry bits, over two %s, outside the set %s; planted three-bit row -> %s; kinetic+chain -> %s; speed -> %s"
			% [ids.size(), with_bits, over, stray, S.names(planted.bits), S.names(from_tags.bits), S.names(none.bits)])


func _check_or_and_cap() -> void:
	var p: int = S.bit("pierce")
	var b: int = S.bit("bounce")
	var s: int = S.bit("split")
	var h: int = S.bit("heat")
	var two: Dictionary = S.shot([p, b])
	var copies: Dictionary = S.shot([p, p, p])
	var swapped: Dictionary = S.shot([b, p])
	var four: Dictionary = S.shot([p | b, s, h])
	var ok: bool = S.has(two["bits"], p) and S.has(two["bits"], b) and S.count(two["bits"]) == 2 \
		and S.count(copies["bits"]) == 1 and S.without(swapped["bits"], two["bits"]) < 1 \
		and S.without(two["bits"], swapped["bits"]) < 1 and S.count(four["bits"]) == S.MAX_SHOT_BITS \
		and S.has(four["dropped"], h) and S.count(four["dropped"]) == 1 and S.count(S.shot([])["bits"]) == 0
	_report("a shot is the OR of its parts, capped at three", ok and S.MAX_SHOT_BITS == 3,
		"pierce|bounce -> %s; three pierce copies -> %s; held order swapped -> %s; four bits -> %s, dropped %s"
			% [S.names(two["bits"]), S.names(copies["bits"]), S.names(swapped["bits"]), S.names(four["bits"]), S.names(four["dropped"])])


func _check_children() -> void:
	var Bolts: Script = load(BOLTS)
	var set_bits: int = S.bit("split") | S.bit("pull")
	var parent := {"origin": Vector3.ZERO, "dir": Vector3.FORWARD, "speed": 40.0, "bits": set_bits, "travelled": 3.0}
	var child: Dictionary = Bolts.child(parent, {"dir": Vector3.RIGHT, "bits": 0})
	var grandchild: Dictionary = Bolts.child(child, {"damage": 1.0})
	var pool: Node = Bolts.new()
	var bare := {"origin": Vector3.ZERO, "dir": Vector3.FORWARD, "speed": 40.0}
	pool.fire(bare)
	var fresh: bool = not child.has("travelled") and child["dir"] == Vector3.RIGHT
	_report("children copy the set", S.without(child["bits"], set_bits) < 1 and S.without(set_bits, child["bits"]) < 1
		and S.without(grandchild["bits"], set_bits) < 1 and S.without(set_bits, grandchild["bits"]) < 1
		and fresh and bare.has("bits") and S.count(bare["bits"]) == 0,
		"parent %s -> child %s (an override of 0 ignored) -> grandchild %s; child flight restarts %s; a bolt fired with no set carries %s"
			% [S.names(set_bits), S.names(child["bits"]), S.names(grandchild["bits"]), fresh, S.names(bare.get("bits", 0))])
	pool.free()


func _compose(run_seed: int, builds: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	var classes := [Items.SABLE, Items.RIVET, Items.KEST]
	var counts := {0: 0, 1: 0, 2: 0, 3: 0}
	var unspecified := 0
	var max_bits := 0
	var reach3 := 0
	var dropped := 0
	var masks := {}
	var worst := 0
	var picks_hash := 0
	for n in builds:
		var class_id: String = classes[n % classes.size()]
		var held: Array = []
		var offered := {}
		for pick in BUILD_SIZE:
			var offer: Array = Parts.roll(rng, PartOffers.gate_rarities(rng.randi_range(0, 2)), class_id, held, OFFER_SIZE, [], offered)
			if offer.is_empty():
				continue
			for key in offer:
				offered[key] = offered.get(key, 0) + 1
			held.append(offer[rng.randi_range(0, offer.size() - 1)])
		picks_hash = hash([picks_hash, held])
		var part_masks: Array = []
		for part_id in held:
			var d: Resource = Parts.def(part_id)
			part_masks.append(d.bits if d != null else 0)
		var shot: Dictionary = S.shot(part_masks)
		var c: int = S.count(shot["bits"])
		counts[c] = counts.get(c, 0) + 1
		max_bits = maxi(max_bits, c)
		if c >= 3:
			reach3 += 1
		if S.count(shot["dropped"]) > 0:
			dropped += 1
		unspecified += S.unspecified_pairs(shot["bits"])
		masks[shot["bits"]] = true
		if c > S.count(worst):
			worst = shot["bits"]
	return {"builds": builds, "counts": counts, "share3": float(reach3) / maxf(builds, 1), "max_bits": max_bits,
		"unspecified": unspecified, "dropped": dropped, "distinct": masks.size(), "worst": worst, "picks_hash": picks_hash}


func _check_compose() -> void:
	var stats := _compose(SEED, BUILDS)
	print("shot_bits compose | seed %d | builds %d | bits per shot %s | 3 bits %.1f%% (target %d%%) | max %d | distinct sets %d | builds with a dropped bit %d | unspecified pairs %d | worst %s"
		% [SEED, stats["builds"], stats["counts"], 100.0 * stats["share3"], int(SHARE3_TARGET * 100), stats["max_bits"],
			stats["distinct"], stats["dropped"], stats["unspecified"], S.names(stats["worst"])])
	_report("10,000 6-part builds", stats["builds"] == BUILDS and stats["unspecified"] == 0
		and stats["share3"] >= SHARE3_TARGET and stats["max_bits"] <= S.MAX_SHOT_BITS,
		"%.1f%% reach 3 bits, max %d bits per shot, %d unspecified pairs, %d distinct sets"
			% [100.0 * stats["share3"], stats["max_bits"], stats["unspecified"], stats["distinct"]])
	var again := _compose(7, 300)
	var twice := _compose(7, 300)
	var other := _compose(8, 300)
	_report("compose reproducible from the seed", again["picks_hash"] == twice["picks_hash"]
		and again["share3"] == twice["share3"] and again["picks_hash"] != other["picks_hash"],
		"seed 7 twice %s / %s, seed 8 %s" % [again["picks_hash"], twice["picks_hash"], other["picks_hash"]])
	set_meta("worst", stats["worst"])


func _check_frame_budget() -> void:
	# The bit layer's per-tick work for the worst build at a full pool: every live bolt
	# spawns a child that copies the set, and every child's tells and pairs are read.
	# A 20-part build of every bit must cost no more than the worst 6-part build.
	var Bolts: Script = load(BOLTS)
	var worst: int = get_meta("worst", S.ALL)
	var long_masks: Array = []
	for i in LONG_BUILD:
		long_masks.append(S.bit(S.NAMES[i % S.NAMES.size()]))
	var long_bits: int = S.shot(long_masks)["bits"]
	var reads := {}
	# The positive control: the raw OR of the long build, uncapped, must overrun the cap.
	for build in [["worst", worst], ["long", long_bits], ["uncapped", S.ALL]]:
		var parent := {"origin": Vector3.ZERO, "dir": Vector3.FORWARD, "speed": 40.0, "bits": build[1]}
		var n := 0
		for i in Bolts.MAX_LIVE:
			var child: Dictionary = Bolts.child(parent, {"damage": 1.0})
			n += S.tells(child["bits"]).size()
			var held: int = S.count(child["bits"])
			n += held * (held - 1) / 2
		reads[build[0]] = n
	var cap: int = Bolts.MAX_LIVE * READS_PER_BOLT_CAP
	_report("worst build inside the frame budget", reads["worst"] <= cap and reads["long"] <= cap
		and reads["long"] <= reads["worst"] and reads["uncapped"] > cap,
		"worst build %s, %d bolts a tick, %d table reads; a %d-part build of every bit %s, %d reads; cap %d; uncapped control %d reads"
			% [S.names(worst), Bolts.MAX_LIVE, reads["worst"], LONG_BUILD, S.names(long_bits), reads["long"], cap, reads["uncapped"]])


func _check_set_operations() -> void:
	var re := RegEx.new()
	re.compile(SET_EQUALITY)
	var hits: Array = []
	for path in [MODULE, BOLTS]:
		var text := FileAccess.get_file_as_string(path)
		var n := 0
		for line in text.split("\n"):
			n += 1
			var code := line.get_slice("#", 0)
			if re.search(code) != null:
				hits.append("%s:%d" % [path.get_file(), n])
	var planted := [re.search("\tif a_bits == b_bits:") != null, re.search("\treturn mask != 0") != null,
		re.search("\treturn (mask & bit) > 0") == null]
	_report("set operations only", hits.is_empty() and planted == [true, true, true],
		"equality on a set at %s; planted equality caught %s" % [hits, planted])
