extends RefCounted

const SpeedTier := preload("res://src/movement/speed_tier.gd")

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
var spread := 1.0
var centre := Vector3.ZERO
var pulses := 0
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


func lead_fraction() -> float:
	var pulse := float(row.get("pulse", 1.0))
	var lead := minf(float(row.get("lead", 0.0)), pulse)
	var into := fmod(_clock, pulse)
	if lead <= 0.0 or into < pulse - lead:
		return 0.0
	return clampf((into - (pulse - lead)) / lead, 0.0, 1.0)


func until_pulse() -> float:
	var pulse := float(row.get("pulse", 1.0))
	return pulse - fmod(_clock, pulse)


func step(delta: float) -> bool:
	var pulse := float(row.get("pulse", 1.0))
	var before := int(floor(_clock / pulse))
	_clock += delta
	var now := int(floor(_clock / pulse))
	if now > before:
		pulses += 1
		return true
	return false


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
