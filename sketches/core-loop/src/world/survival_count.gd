extends RefCounted

# The survival count (BACKLOG W1-101; Andrew, 13 Nov 2026): machines climb in by counts, each count
# harder than the last, with no last count. When a count is cleared a gate opens for `gate_s`:
# leave through it and the pay earned so far is yours, or stay and the next count pays more. A count
# not cleared inside `count_s` gets the next one on top of it, and no gate opens until the floor is
# clear. A ball destroyed inside is paid nothing: the pay is only banked by leaving.
#
# The rule is data, so a world's arena is a row: `counts` are the opening counts by role, `after`
# says how every later count grows, `pay` and `pay_after` are the ladder, ROSTERS turns a role into
# that world's machine and HAZARDS names what the arena itself does each count. The three ways in
# (a yard on the map, an event that comes to the ball, a ring at camp) differ only in FORMS; this
# module holds the count, and the caller spawns what pack() names and reports how many still stand.

const RULE := {
	"counts": [
		["runner", "runner", "runner"],
		["runner", "runner", "runner", "thrower"],
		["runner", "runner", "runner", "thrower", "trapper"],
		["runner", "runner", "runner", "thrower", "trapper", "heavy"],
		["runner", "runner", "runner", "thrower", "trapper", "heavy", "rogue"],
	],
	# Past the opening counts: the last one again, `stronger` times the count before it, with one
	# more rogue on every `rogue_every`th count after the opening.
	"after": {"stronger": 1.35, "rogue_every": 3},
	"count_s": 25.0,
	"gate_s": 5.0,
	# What leaving after count n has earned in all (never a sum of the rows before it).
	"pay": [
		{"scrap": 180, "parts": []},
		{"scrap": 180, "parts": ["common"]},
		{"scrap": 180, "parts": ["rare"]},
		{"scrap": 180, "parts": ["rare"], "cores": 1},
		{"scrap": 180, "parts": ["rare", "rare"], "cores": 1},
	],
	# Past the ladder: one more rare part a count, and a cobalt part in place of a rare on each
	# count in `cobalt_at`.
	"pay_after": {"part": "rare", "cobalt_at": [8, 12]},
}

# A role's machine in each world. World 1 is the Spillway's roster; a later world adds its row.
const ROSTERS := {
	1: {"runner": "chaser", "thrower": "lobber", "trapper": "mag_trapper", "heavy": "plated_brute", "rogue": "reactor_relic"},
}

# What the arena does each count, by world. World 1: water rises `step_m` a count to `max_m`.
const HAZARDS := {
	1: {"kind": "flood", "step_m": 1.0, "max_m": 4.0},
}

# The ways in. `pay` "record" pays nothing and keeps a best count. `move` names a MOVES row: how
# the ground the count is fought on travels once it has landed (Andrew, 13 Nov 2026).
const FORMS := {
	"yard": {"enter": "gate", "leave": "gate", "pay": "ladder", "move": "still"},
	"muster": {"enter": "siren", "leave": "ring_edge", "pay": "ladder", "move": "loop"},
	"ring": {"enter": "camp", "leave": "any", "pay": "record", "move": "still"},
}

# How the fought ground moves. "still" stays where it landed. "loop" rides a circle of `radius_m`
# that passes through the landing point and comes back to it every `lap_s`.
const MOVES := {
	"still": {},
	"loop": {"radius_m": 60.0, "lap_s": 45.0},
}

var rule: Dictionary = RULE
var world := 1
var form := "yard"
# The count now standing (1 is the first); 0 before begin().
var count := 0
# The last count cleared, which is what leaving pays for.
var cleared := 0
var gate_open := false
var done := false
var _count_left := 0.0
var _gate_left := 0.0


func _init(world_id := 1, form_id := "yard", rule_row: Dictionary = RULE) -> void:
	world = world_id
	form = form_id
	rule = rule_row


# The first count climbs in. Returns its pack.
func begin() -> Array:
	count = 1
	cleared = 0
	gate_open = false
	done = false
	_count_left = float(rule["count_s"])
	return pack(count)


# One step with `standing` machines still up. Returns what happened: "" (nothing), "gate" (the floor
# is clear and the gate opened), "count" (the gate shut and the next count climbs in: spawn
# pack(count)) or "pile" (time ran out with machines standing: spawn pack(count) on top).
func step(delta: float, standing: int) -> String:
	if count == 0 or done:
		return ""
	if gate_open:
		_gate_left -= delta
		if _gate_left > 0.0:
			return ""
		gate_open = false
		return _next()
	if standing <= 0:
		cleared = count
		gate_open = true
		_gate_left = float(rule["gate_s"])
		return "gate"
	_count_left -= delta
	if _count_left <= 0.0:
		_next()
		return "pile"
	return ""


# The ball left. Through an open gate (or any time, where the form lets it) the pay is banked and
# returned; otherwise nothing is, and the count goes on.
func leave() -> Dictionary:
	if count == 0 or done:
		return {}
	if not gate_open and str(FORMS[form]["leave"]) != "any":
		return {}
	done = true
	gate_open = false
	return pay(cleared) if str(FORMS[form]["pay"]) == "ladder" else {"record": cleared}


# The ball was destroyed inside: the count ends and pays nothing. Returns the best count cleared.
func broken() -> int:
	done = true
	gate_open = false
	return cleared


# The machines of count n in this world, strongest last.
func pack(n: int) -> Array:
	var counts: Array = rule["counts"]
	var roles: Array = (counts[mini(n, counts.size()) - 1] as Array).duplicate()
	var past := n - counts.size()
	if past > 0:
		for i in past / int(rule["after"]["rogue_every"]):
			roles.append("rogue")
	var roster: Dictionary = ROSTERS[world]
	return roles.map(func(role): return roster[role])


# How much harder count n's machines hit and hold than the opening counts': 1 through the opening,
# then `stronger` times the count before.
func strength(n: int) -> float:
	return pow(float(rule["after"]["stronger"]), maxi(0, n - (rule["counts"] as Array).size()))


# What leaving after count n has earned: {scrap, parts: [rarity...], cores}. Empty for n under 1.
func pay(n: int) -> Dictionary:
	if n < 1:
		return {}
	var ladder: Array = rule["pay"]
	var row: Dictionary = (ladder[mini(n, ladder.size()) - 1] as Dictionary).duplicate(true)
	row["cores"] = int(row.get("cores", 0))
	var parts: Array = row["parts"]
	for k in range(ladder.size() + 1, n + 1):
		parts.append("cobalt" if k in rule["pay_after"]["cobalt_at"] else str(rule["pay_after"]["part"]))
	return row


# The arena's hazard at count n, as {kind, level}: for the flood, the water's depth in metres.
func hazard(n: int) -> Dictionary:
	var row: Dictionary = HAZARDS[world]
	return {"kind": row["kind"], "level": minf(float(row["max_m"]), float(row["step_m"]) * maxi(0, n - 1))}


# Where the fought ground's centre is `t` seconds after it landed at `landed`, the ball then
# heading along `heading`: the landing point itself for a still form; for a loop, a circle to the
# left of the heading that starts and ends each lap on the landing point.
func ground_at(landed: Vector2, heading: Vector2, t: float) -> Vector2:
	var move: Dictionary = MOVES[str(FORMS[form]["move"])]
	if move.is_empty():
		return landed
	var radius := float(move["radius_m"])
	var forward := heading.normalized() if heading.length() > 0.001 else Vector2.DOWN
	var centre := landed + forward.orthogonal() * radius
	return centre + (landed - centre).rotated(TAU * t / float(move["lap_s"]))


# Seconds left on the open gate, or 0 while it is shut.
func gate_left() -> float:
	return maxf(0.0, _gate_left) if gate_open else 0.0


func _next() -> String:
	count += 1
	_count_left = float(rule["count_s"])
	return "count"
