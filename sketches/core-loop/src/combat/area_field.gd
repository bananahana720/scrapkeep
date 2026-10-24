extends RefCounted

const SpeedTier := preload("res://src/movement/speed_tier.gd")

# One area effect (design-v3/FIELDS-AND-CASTS.md section 2): a circle on the ground that pulses
# an effect on what stands in it. Enemies and, later, items share it, so a field is a ROWS
# row plus the owner that draws it; the owner never re-implements the rule.
#
# - anchor: "laid" stays where it was committed; "emitter" follows its source every tick.
# - target: "player" (a debuff on the ball) or "enemies" (a buff on the source's pack, later).
# - pulse: seconds between pulses. lead: the seconds before each pulse in which lead_fraction()
#   climbs 0 to 1, so the owner can draw the charge-up the player reads before it lands.
# - breaks: what the ball does to let a pulse pass it by. "speed" is FAST tier or above (1.15x
#   cruise), "air" is off the ground, "line" is a harpoon line attached. Each answer is a verb
#   the ball already has, so the counterplay to a field is to keep moving.
# - effect "jam": an interrupting hit through the crowd-control door (gauges and casts drop with
#   nothing spent) and the jam on the ability state for jam_seconds. Nothing touches velocity.

const ROWS := {
	"static_jam": {"target": "player", "effect": "jam", "anchor": "laid", "radius": 6.0, "height": 3.0,
		"pulse": 1.2, "lead": 0.5, "jam_seconds": 0.5, "breaks": ["speed", "air", "line"]},
}
const PLAYER := "player"
const LAID := "laid"
const EMITTER := "emitter"
const BREAK_TIER := SpeedTier.FAST

var id := ""
var row := {}
# A multiplier on the row's radius for this one field (the jolt layer's mat laid on water).
var spread := 1.0
var centre := Vector3.ZERO
var pulses := 0
# Pulses that found the ball inside, and how each ended: "landed", "ignored" (the door shut,
# such as Rivet's sprint) or the break that let it pass.
var outcomes: Array = []

var _source: WeakRef = null
var _clock := 0.0


func _init(row_id: String, at: Vector3, source: Node3D = null) -> void:
	id = row_id
	row = ROWS.get(row_id, {})
	centre = at
	if source != null:
		_source = weakref(source)


func radius() -> float:
	return float(row.get("radius", 0.0)) * spread



# Where the circle is now: an emitter's source while it lives, else the committed centre.
func centre_now() -> Vector3:
	if String(row.get("anchor", LAID)) == EMITTER and _source != null:
		var source = _source.get_ref()
		if source != null and is_instance_valid(source):
			var node := source as Node3D
			centre = node.global_position if node.is_inside_tree() else node.position
	return centre


func contains(point: Vector3) -> bool:
	var c := centre_now()
	var flat := Vector2(point.x - c.x, point.z - c.z)
	return flat.length() <= radius() and absf(point.y - c.y) <= float(row.get("height", 3.0))


# 0 to 1 across the lead before the next pulse, 0 the rest of the cycle.
func lead_fraction() -> float:
	var pulse := float(row.get("pulse", 1.0))
	var lead := minf(float(row.get("lead", 0.0)), pulse)
	var into := fmod(_clock, pulse)
	if lead <= 0.0 or into < pulse - lead:
		return 0.0
	return clampf((into - (pulse - lead)) / lead, 0.0, 1.0)


# Seconds until the next pulse.
func until_pulse() -> float:
	var pulse := float(row.get("pulse", 1.0))
	return pulse - fmod(_clock, pulse)


# Advances the clock; true on each tick a pulse goes off.
func step(delta: float) -> bool:
	var pulse := float(row.get("pulse", 1.0))
	var before := int(floor(_clock / pulse))
	_clock += delta
	var now := int(floor(_clock / pulse))
	if now > before:
		pulses += 1
		return true
	return false


# The break the ball holds right now, in row order, or "" when the pulse would land.
func broken_by(player) -> String:
	for b in row.get("breaks", []):
		match b:
			"speed":
				if player.speed_tier() >= BREAK_TIER:
					return b
			"air":
				if not player.state.grounded:
					return b
			"line":
				if player.kit.hooked:
					return b
	return ""


# One pulse on the ball: "" when it was outside, else the outcome recorded in `outcomes`.
func pulse_player(player, ball: Vector3) -> String:
	if String(row.get("target", "")) != PLAYER or not contains(ball):
		return ""
	var outcome := broken_by(player)
	if outcome == "":
		outcome = "landed" if _apply(player) else "ignored"
	outcomes.append(outcome)
	return outcome


func _apply(player) -> bool:
	match String(row.get("effect", "")):
		"jam":
			if not player.crowd_control(id, Vector3.ZERO, true):
				return false
			player.abilities.jam(float(row.get("jam_seconds", 0.0)))
			return true
	return false
