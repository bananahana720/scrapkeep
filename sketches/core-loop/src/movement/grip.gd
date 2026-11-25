extends RefCounted

const Roster := preload("res://src/combat/roster.gd")
const Augments := preload("res://src/movement/augments.gd")


const POLE := "pole"
const REEL := "reel"
const FLAIL := "flail"

const BAND := 0.25
const PER_THREAT := 0.4
const ELITE := 0.5

const CHASSIS_HEFT := {
	"swarm": 0.6, "hover": 1.1, "crawler": 1.4, "burrower": 1.8, "emplacement": 2.6, "heavy": 4.0,
}

const NEVER_FLAIL := ["vault", "warden"]


static func heft_of(body) -> float:
	if not is_instance_valid(body):
		return INF
	var rating = body.get("rating")
	if rating != null:
		return float(rating)
	var kind := String(body.get("kind")) if body.get("kind") != null else ""
	if kind in NEVER_FLAIL or not Roster.ROWS.has(kind):
		return INF
	var row: Dictionary = Roster.ROWS[kind]
	var base: float = row.get("heft", CHASSIS_HEFT.get(String(row.get("chassis", "")), INF))
	if base == INF:
		return INF
	var threat = body.get("threat_level")
	var spec = body.get("spec")
	var elite: bool = spec is Dictionary and String(spec.get("affix", "")) != ""
	return base + PER_THREAT * maxf(0.0, (float(threat) if threat != null else 1.0) - 1.0) + (ELITE if elite else 0.0)


static func grip(ball_heft: float, body_heft: float, can_anchor := true) -> String:
	if body_heft == INF:
		return POLE if can_anchor else REEL
	if ball_heft <= body_heft - BAND:
		return POLE
	if ball_heft >= body_heft + BAND:
		return FLAIL
	return REEL


static func of(body, ball_heft: float, on := true) -> String:
	if not is_instance_valid(body) or not body.is_in_group("enemy"):
		return ""
	if not on:
		return REEL
	return grip(ball_heft, heft_of(body), Augments.anchor_line(body))


static func mark(aim: Dictionary, ball_heft: float, on := true) -> Dictionary:
	var body = aim.get("body")
	var g := of(body, ball_heft, on)
	if g == "":
		aim.erase("grip")
	else:
		aim["grip"] = g
	return aim
