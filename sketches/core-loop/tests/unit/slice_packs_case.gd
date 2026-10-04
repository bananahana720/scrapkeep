extends RefCounted

const Director := preload("res://src/world/director.gd")
const SliceDefs := preload("res://src/core/slice_defs.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")

# The slice's packs come from one list on the stage table (slice_defs.gd), drawn by a
# director given them and nothing else:
# - every arrival is exactly one authored pack, and only the six slice kinds appear;
# - no pack repeats back to back, nor on either side of the elite; the third arrival is the
#   elite, and it comes once;
# - a pack never arrives when the cap lacks room for all of it, and waits instead;
# - the default table answers "no packs" and a director without them draws as before:
#   the arrival counts and positions below were recorded at the base for two seeds.

const H := 1.0 / 60.0
const SLICE_KINDS := ["chaser", "lobber", "mag_trapper", "deflector", "plated_brute", "winch_drone"]
# Recorded at the base before this unit: seed, arrivals in 240 s with the beacon spike on
# after 100 s, a position checksum (x + 2y summed), and the first kinds drawn.
const BASE := [
	{"seed": 7, "count": 68, "checksum": 5530.557, "first": [0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1]},
	{"seed": 20260922, "count": 68, "checksum": 3945.007, "first": [0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]},
]

var _t


func run(t) -> void:
	_t = t
	_tables()
	_arrivals()
	_waits_for_room()
	_default_unchanged()


func _slice_director(seed_value: int) -> Director:
	var d := Director.new(seed_value)
	d.authored = SliceDefs.packs()
	d.elite = SliceDefs.elite()
	d.elite_arrival = SliceDefs.elite_arrival()
	return d


func _tables() -> void:
	_t.check("table: the slice has three packs, an elite and no vault",
		SliceDefs.packs().size() == 3 and SliceDefs.elite()["id"] == "elite" and SliceDefs.elite_arrival() == 3 and not SliceDefs.has_vault(),
		"%d packs, elite arrival %d" % [SliceDefs.packs().size(), SliceDefs.elite_arrival()])
	_t.check("table: the slice has no timed events", SliceDefs.of(1)["event_mix"].is_empty(), "event_mix %s" % [SliceDefs.of(1)["event_mix"]])
	# 2026-10-04: the default table answers from AlphaDefs, so it carries the alpha packs and elite and no vault.
	_t.check("table: the default table answers as the alpha table (packs, elite, no vault)",
		StageDefs.packs() == AlphaDefs.packs() and StageDefs.elite() == AlphaDefs.elite() and not StageDefs.has_vault(), "default answers follow AlphaDefs")


func _arrivals() -> void:
	var ids: Array = []
	var bad: Array = []
	var foreign: Array = []
	var over := 0
	var near_cap := 0
	var d := _slice_director(11)
	var seen := 0
	var t := 0.0
	while d.packs.size() < 200 and t < 20000.0:
		# Two of every three 7 s spans the live count is low; the third it sits three under the
		# cap, so a pack of four does not fit and ignoring the room rule would overshoot.
		var phase := int(t / 7.0) % 3
		var alive := d.cap() - 3 if phase == 2 else phase
		d.advance(H, alive, Vector2.ZERO, Vector2(0.0, 14.0), Vector2(0.0, 1.0))
		t += H
		if d.packs.size() > seen:
			if alive + d.arrivals.size() > d.cap():
				over += 1
			if alive > 2:
				near_cap += 1
			seen = d.packs.size()
	for p in d.packs:
		ids.append(p["id"])
		for kind in p["kinds"]:
			if not kind in SLICE_KINDS:
				foreign.append(kind)
		var row := _row_of(p["id"])
		if row.is_empty() or row["kinds"] != p["kinds"]:
			bad.append(p["id"])
	var repeats := 0
	for i in range(1, ids.size()):
		if ids[i] == ids[i - 1]:
			repeats += 1
	_t.check("arrivals: 200 arrivals, each exactly one authored pack", ids.size() >= 200 and bad.is_empty(), "%d arrivals, %d off the list" % [ids.size(), bad.size()])
	_t.check("arrivals: only the six slice kinds appear", foreign.is_empty(), "foreign kinds %s" % [foreign])
	_t.check("arrivals: no pack repeats back to back", repeats == 0, "%d repeats" % repeats)
	_t.check("arrivals: the third arrival is the elite, once", ids.size() > 3 and ids[2] == "elite" and ids.count("elite") == 1,
		"first four %s, elites %d" % [ids.slice(0, 4), ids.count("elite")])
	var same_round_elite := []
	for seed_value in range(1, 21):
		var e := _slice_director(seed_value)
		var clock := 0.0
		while e.packs.size() < 4 and clock < 600.0:
			e.advance(H, 0, Vector2.ZERO, Vector2(0.0, 14.0), Vector2(0.0, 1.0))
			clock += H
		if e.packs.size() >= 4 and e.packs[1]["id"] == e.packs[3]["id"]:
			same_round_elite.append(seed_value)
	_t.check("arrivals: the pack after the elite is not the pack before it", same_round_elite.is_empty(),
		"seeds 1 to 20 where the second and fourth arrivals match: %s" % [same_round_elite])
	var ordinary := {}
	for id in ids:
		ordinary[id] = int(ordinary.get(id, 0)) + 1
	_t.check("arrivals: every ordinary pack is drawn", ordinary.has("run_down") and ordinary.has("grounded") and ordinary.has("rebound"), "counts %s" % [ordinary])
	_t.check("arrivals: a pack never lands past the cap, with the live count held near it",
		over == 0 and near_cap > 0, "%d arrivals over the cap, %d of them with the count three under it" % [over, near_cap])


func _row_of(id: String) -> Dictionary:
	if id == SliceDefs.elite()["id"]:
		return SliceDefs.elite()
	for row in SliceDefs.packs():
		if row["id"] == id:
			return row
	return {}


# With the live count at the cap minus two, no pack of three or four fits: nothing
# arrives, and the same pack goes out as soon as room opens.
func _waits_for_room() -> void:
	var d := _slice_director(5)
	var tight := 0
	var t := 0.0
	while t < 120.0:
		d.advance(H, d.cap() - 2, Vector2.ZERO, Vector2(0.0, 14.0), Vector2(0.0, 1.0))
		t += H
		tight += d.arrivals.size()
	_t.check("room: nothing arrives while the cap has room for two", tight == 0 and d.packs.is_empty(), "%d arrivals, %d packs in 120 s" % [tight, d.packs.size()])
	var waiting: Dictionary = d._next_pack
	var size: int = waiting["kinds"].size()
	t = 0.0
	while t < 60.0 and d.packs.is_empty():
		d.advance(H, d.cap() - size, Vector2.ZERO, Vector2(0.0, 14.0), Vector2(0.0, 1.0))
		t += H
	_t.check("room: the waiting pack arrives once there is room for all of it",
		not waiting.is_empty() and not d.packs.is_empty() and d.packs[0]["id"] == waiting["id"],
		"waiting %s, arrived %s" % [waiting.get("id", "none"), d.packs[0]["id"] if not d.packs.is_empty() else "none"])


func _default_unchanged() -> void:
	for row in BASE:
		var d := Director.new(row["seed"])
		d.threat = 1.0
		var kinds := []
		var n := 0
		var checksum := 0.0
		var t := 0.0
		while t < 240.0:
			if t > 100.0:
				d.spike = true
			var due := d.advance(H, 3, Vector2.ZERO, Vector2(0.0, 14.0), Vector2(0.0, 1.0))
			t += H
			for s in due:
				n += 1
				kinds.append(s["kind"])
				checksum += s["at"].x + 2.0 * s["at"].y
		_t.check("default: seed %d draws as at the base" % row["seed"],
			n == row["count"] and absf(checksum - row["checksum"]) < 0.01 and kinds.slice(0, 12) == row["first"],
			"%d arrivals (base %d), checksum %.3f (base %.3f)" % [n, row["count"], checksum, row["checksum"]])
