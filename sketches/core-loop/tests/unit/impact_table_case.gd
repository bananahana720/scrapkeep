extends RefCounted

const EventKinds := preload("res://src/core/event_kinds.gd")
const EventJuice := preload("res://src/presentation/event_juice.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Augments := preload("res://src/movement/augments.gd")
const Juice := preload("res://src/presentation/juice.gd")

# The IMPACT table is the one place a hit's shove, lift, stop, shake and reaction live
# (event_kinds.gd): every row carries exactly the fields with allowed words, every kind
# combat hits with and every contact kind juice knows has a row, the ram and slam rows
# match the numbers augments.gd still holds, and weapons.gd reads its knocks from it.

# The strike kinds combat passes to _hit, and the sources that throw differently under a
# kind another hit shares (the discharge, the overdrive blast, a spill, a blink cut).
const HIT_SOURCES := ["burst", "overdrive", "spill", "proc"]


func run(t) -> void:
	var impact: Dictionary = EventKinds.IMPACT
	var bad_fields: Array = []
	var bad_words: Array = []
	for kind in impact:
		var row: Dictionary = impact[kind]
		var keys: Array = row.keys()
		keys.sort()
		var want: Array = EventKinds.IMPACT_FIELDS.duplicate()
		want.sort()
		if keys != want:
			bad_fields.append(kind)
		if not row.get("stop", "") in EventKinds.IMPACT_STOPS or not row.get("react", "") in EventKinds.IMPACT_REACTS:
			bad_words.append(kind)
	t.check("rows have exactly the fields", bad_fields.is_empty(), "rows off the field list %s: %s" % [EventKinds.IMPACT_FIELDS, bad_fields])
	t.check("stop and react hold allowed words", bad_words.is_empty(), "rows with a stop outside %s or a react outside %s: %s"
		% [EventKinds.IMPACT_STOPS, EventKinds.IMPACT_REACTS, bad_words])

	var kinds: Array = Weapons.STRIKE_KIND.values()
	kinds.append("line")
	for kind in Juice.CONTACT_KINDS:
		kinds.append(kind)
	for kind in HIT_SOURCES:
		kinds.append(kind)
	var missing: Array = []
	for kind in kinds:
		if not impact.has(kind):
			missing.append(kind)
	t.check("every hit kind has a row", missing.is_empty() and impact.size() >= kinds.size(),
		"%d rows for %d kinds, missing %s" % [impact.size(), kinds.size(), missing])

	t.check("guns never stop time", ["runner", "arc", "turret"].all(func(k): return impact[k]["stop"] == "none" and impact[k]["shake"] == 0.0),
		"laser, arc and turret rows stop none and shake 0")
	t.check("contact kinds are heavy", Juice.CONTACT_KINDS.all(func(k): return impact[k]["stop"] == "heavy"), "ram, stomp and slam rows stop heavy")
	t.eq("ram knock matches augments", impact["ram"]["knock"], Augments.RAM_KNOCK)
	t.eq("slam knock matches augments", impact["slam"]["knock"], Augments.SLAM_KNOCK)
	t.eq("weapons read the table", [Weapons.BASE[Weapons.RAPID_LASER]["knock"], Weapons.BASE[Weapons.ARC_CASTER]["knock"],
			Weapons.BASE[Weapons.PYLON_TURRET]["knock"], Weapons.BASE[Weapons.STICKY_CHARGE]["knock"], Weapons.BURST_KNOCK, Weapons.LINE_KNOCK, Weapons.OVERDRIVE_KNOCK],
		[impact["runner"]["knock"], impact["arc"]["knock"], impact["turret"]["knock"], impact["sticky"]["knock"], impact["burst"]["knock"],
			impact["line"]["knock"], impact["overdrive"]["knock"]])
	t.eq("unknown kind lands plain", EventKinds.impact("no_such_kind")["stop"], "hit")

	var outside_band: Array = []
	for kind in impact:
		var row: Dictionary = impact[kind]
		var weight: String = row["stop"]
		var center := float(EventJuice.WEIGHT[weight]["shake"])
		var low := 0.0 if weight == "none" else center * 0.5
		var high := center * 1.5
		if float(row["shake"]) < low or float(row["shake"]) > high:
			outside_band.append(kind)
	t.eq("impact shake inside weight class band", outside_band, [])
