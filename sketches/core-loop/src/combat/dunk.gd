extends RefCounted

# The dunk charge (DECISIONS section 6 and 10): an air slam stores its slam damage, and the
# next reel impact within WINDOW seconds spends it on the body it lands on. One shared rule
# for every pilot: any pilot's slam feeds it (the pilot's flavour rides along as a label,
# never as a different number) and every reel spends it. The player owns the one instance,
# stores from its slam and ticks the clock; combat spends it in the damage door. Presentation
# and audio read the one record through the signals below, so the glow and the cue cannot
# drift apart.
#
# Pure state: no scene, so the rule is testable without one.

# Seconds a charge waits for its reel. A jump-slam, a line fired from the plant and the haul
# to the target take about one to two and a half seconds, so three covers a deliberate setup
# and no more; it matches the ram-brace spring (combat SPRING_WINDOW), the other "the next
# hit pays" window. A start value; the lab tunes it.
const WINDOW := 3.0
# A stored slam under this damage is not worth a charge (a slam into a launch is flat 0).
const MIN_DAMAGE := 0.5

# {damage, flavour, pilot, color, t, until}, or empty. damage is the slam's full-centre
# damage; color is the pilot's class colour (Andrew's ruling: it reads in the pilot's own
# colour on every pilot).
var charge := {}
var clock := 0.0
var stored_count := 0
var spent_count := 0
var expired_count := 0

signal stored(record: Dictionary)
signal spent(record: Dictionary, enemy: Node3D)
signal expired(record: Dictionary, cause: String)


# The slam's damage at its centre: the same row combat strikes a slam with, at full force.
static func slam_damage(force: float, row: Array, heft: float) -> float:
	return (float(row[0]) + force * float(row[1])) * heft


func held() -> bool:
	return not charge.is_empty()


# Seconds left on the held charge; 0 when none.
func left() -> float:
	return maxf(0.0, float(charge["until"]) - clock) if held() else 0.0


# A fresh slam replaces whatever was held (the newest dunk is the setup being played).
func store(damage: float, flavour: String, pilot: String, color: Color) -> bool:
	if damage < MIN_DAMAGE:
		return false
	if held():
		expired.emit(charge, "replaced")
		expired_count += 1
	charge = {"damage": damage, "flavour": flavour, "pilot": pilot, "color": color, "t": clock,
		"until": clock + WINDOW}
	stored_count += 1
	stored.emit(charge)
	return true


# The reel test, shared with combat.punch_of's winch branch: a stomp, ram or slam contact
# while the line is hooked and winching, or a smash landing on the body the line bit (the
# landing lets the line go before its strikes resolve, so smash stands in for hooked).
static func is_reel_impact(kind: String, smash: bool, hooked: bool, winching: bool) -> bool:
	return kind in ["stomp", "ram", "slam"] and (smash or (hooked and winching))


# Returns the stored damage once and clears it; 0 when nothing is held or it has run out.
func spend(enemy: Node3D) -> float:
	_expire_if_due()
	if not held():
		return 0.0
	var record := charge
	charge = {}
	spent_count += 1
	spent.emit(record, enemy)
	return float(record["damage"])


func tick(delta: float) -> void:
	clock += delta
	_expire_if_due()


func clear(cause := "reset") -> void:
	if held():
		var record := charge
		charge = {}
		expired_count += 1
		expired.emit(record, cause)


func _expire_if_due() -> void:
	if held() and clock >= float(charge["until"]):
		clear("timeout")
