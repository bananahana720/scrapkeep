extends RefCounted


const RULE := {
	"counts": [
		["runner", "runner", "runner"],
		["runner", "runner", "runner", "thrower"],
		["runner", "runner", "runner", "thrower", "trapper"],
		["runner", "runner", "runner", "thrower", "trapper", "heavy"],
		["runner", "runner", "runner", "thrower", "trapper", "heavy", "rogue"],
	],
	"after": {"stronger": 1.35, "rogue_every": 3},
	"count_s": 25.0,
	"gate_s": 5.0,
	"pay": [
		{"scrap": 180, "rarities": []},
		{"scrap": 180, "rarities": ["common"]},
		{"scrap": 180, "rarities": ["rare"]},
		{"scrap": 180, "rarities": ["rare"], "cores": 1},
		{"scrap": 180, "rarities": ["rare", "rare"], "cores": 1},
	],
	"pay_after": {"rarity": "rare", "relic": "relic", "relic_at": [8, 12]},
}

const ROSTERS := {
	1: {"runner": "chaser", "thrower": "lobber", "trapper": "mag_trapper", "heavy": "plated_brute", "rogue": "reactor_relic"},
}

const HAZARDS := {
	1: {"kind": "flood", "step": 1.0, "max": 4.0},
}

const FORMS := {
	"yard": {"enter": "gate", "leave": "gate", "pay": "ladder", "move": "still"},
	"muster": {"enter": "siren", "leave": "ring_edge", "pay": "ladder", "move": "loop"},
	"ring": {"enter": "camp", "leave": "any", "pay": "record", "move": "still"},
}

const MOVES := {
	"still": {},
	"loop": {"radius_m": 60.0, "lap_s": 45.0, "tighter_m": [40.0, 25.0]},
}
const COURSE_STEP_M := 8.0

var rule: Dictionary = RULE
var way := 0.0
var world := 1
var form := "yard"
var count := 0
var cleared := 0
var gate_open := false
var done := false
var _count_left := 0.0
var _gate_left := 0.0
var _landed := Vector2.ZERO
var _forward := Vector2.DOWN
var _clock := 0.0


func _init(world_id := 1, form_id := "yard", rule_row: Dictionary = RULE) -> void:
	world = world_id
	form = form_id
	rule = rule_row


func begin(landed := Vector2.ZERO, heading := Vector2.DOWN, fits := Callable()) -> Array:
	_landed = landed
	_forward = heading.normalized() if heading.length() > 0.001 else Vector2.DOWN
	way = 0.0
	for offered in ways(form):
		if is_zero_approx(offered) or (fits.is_valid() and fits.call(course(landed, heading, offered))):
			way = offered
			break
	_clock = 0.0
	count = 1
	cleared = 0
	gate_open = false
	done = false
	_count_left = float(rule["count_s"])
	return pack(count)


func step(delta: float, standing: int) -> String:
	if count == 0 or done:
		return ""
	_clock += delta
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


func leave() -> Dictionary:
	if count == 0 or done:
		return {}
	if not gate_open and str(FORMS[form]["leave"]) != "any":
		return {}
	done = true
	gate_open = false
	return pay(cleared) if str(FORMS[form]["pay"]) == "ladder" else {"record": cleared}


func forfeit() -> int:
	done = true
	gate_open = false
	return cleared


func pack(n: int) -> Array:
	if n < 1:
		return []
	var counts: Array = rule["counts"]
	var roles: Array = (counts[mini(n, counts.size()) - 1] as Array).duplicate()
	var past := n - counts.size()
	if past > 0:
		for i in past / int(rule["after"]["rogue_every"]):
			roles.append("rogue")
	var roster: Dictionary = ROSTERS[world]
	return roles.map(func(role): return roster[role])


func strength(n: int) -> float:
	return pow(float(rule["after"]["stronger"]), maxi(0, n - (rule["counts"] as Array).size()))


func pay(n: int) -> Dictionary:
	if n < 1:
		return {}
	var ladder: Array = rule["pay"]
	var row: Dictionary = (ladder[mini(n, ladder.size()) - 1] as Dictionary).duplicate(true)
	row["cores"] = int(row.get("cores", 0))
	var rolls: Array = row["rarities"]
	var after: Dictionary = rule["pay_after"]
	for k in range(ladder.size() + 1, n + 1):
		rolls.append(str(after["relic"]) if k in after["relic_at"] else str(after["rarity"]))
	return row


func hazard(n: int) -> Dictionary:
	var row: Dictionary = HAZARDS[world]
	return {"kind": row["kind"], "level": minf(float(row["max"]), float(row["step"]) * maxi(0, n - 1))}


func ground() -> Vector2:
	if is_zero_approx(way):
		return _landed
	var move: Dictionary = MOVES[str(FORMS[form]["move"])]
	return _on_course(_landed, _forward, way, _clock / (float(move["lap_s"]) * absf(way) / float(move["radius_m"])))


static func ways(form_id: String) -> Array:
	var move: Dictionary = MOVES[str(FORMS[form_id]["move"])]
	var out := []
	if not move.is_empty():
		for radius in [move["radius_m"]] + move["tighter_m"]:
			out.append(float(radius))
			out.append(-float(radius))
	out.append(0.0)
	return out


static func course(landed: Vector2, heading: Vector2, way: float) -> PackedVector2Array:
	var out := PackedVector2Array([landed])
	var forward := heading.normalized() if heading.length() > 0.001 else Vector2.DOWN
	var steps := ceili(TAU * absf(way) / COURSE_STEP_M)
	for i in range(1, steps):
		out.append(_on_course(landed, forward, way, float(i) / steps))
	return out


static func _on_course(landed: Vector2, forward: Vector2, way: float, laps: float) -> Vector2:
	var centre := landed - forward.orthogonal() * way
	return centre + (landed - centre).rotated(TAU * laps * signf(way))


func count_left() -> float:
	return 0.0 if gate_open else maxf(0.0, _count_left)


func gate_left() -> float:
	return maxf(0.0, _gate_left) if gate_open else 0.0


func _next() -> String:
	count += 1
	_count_left = float(rule["count_s"])
	return "count"
