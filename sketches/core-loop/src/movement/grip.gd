extends RefCounted

const Roster := preload("res://src/combat/roster.gd")

# Poles and flails (design-v3/POLES-FLAILS.md section 3): what holding the harpoon does to a
# bitten enemy, decided by weight (Andrew's card "Weight", 2026-10-17). A ball at most BAND
# lighter than the body orbits it as a pole; at least BAND heavier, the body swings on the
# line as a flail; in between the line reels as it always has. The grip is read once, at the
# bite, and the lock shows the same answer before the press.

const POLE := "pole"
const REEL := "reel"
const FLAIL := "flail"

const BAND := 0.25
const PER_THREAT := 0.4
const ELITE := 0.5

# Heft by chassis class (start values, section 3). A row's own `heft` wins over its chassis.
const CHASSIS_HEFT := {
	"swarm": 0.6, "hover": 1.1, "crawler": 1.4, "burrower": 1.8, "emplacement": 2.6, "heavy": 4.0,
}

# Kinds that are never a flail, whatever the ball weighs: the vault, every Warden, every boss
# body (they are not roster rows, so they never reach CHASSIS_HEFT either).
const NEVER_FLAIL := ["vault", "warden"]


# The enemy's heft. A body with a heft `rating` (mag trapper, hooker) already teaches "am I
# heavier?" against that number, so the grip uses the same one. INF means never a flail.
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


# The grip a ball of `ball_heft` takes on a body of `body_heft`. An infinite heft is a pole
# only where the body can carry an anchor line; otherwise the line reels as today.
static func grip(ball_heft: float, body_heft: float, can_anchor := true) -> String:
	if body_heft == INF:
		return POLE if can_anchor else REEL
	if ball_heft <= body_heft - BAND:
		return POLE
	if ball_heft >= body_heft + BAND:
		return FLAIL
	return REEL


# With the `pole_flail` toggle off (tuning.gd) every body line reels, as before.
static func of(body, ball_heft: float, on := true) -> String:
	if not is_instance_valid(body) or not body.is_in_group("enemy"):
		return ""
	if not on:
		return REEL
	return grip(ball_heft, heft_of(body), body.has_method("anchor_point"))


# Adds the grip a press would take to an aim record that holds a body.
static func mark(aim: Dictionary, ball_heft: float, on := true) -> Dictionary:
	var body = aim.get("body")
	var g := of(body, ball_heft, on)
	if g == "":
		aim.erase("grip")
	else:
		aim["grip"] = g
	return aim
