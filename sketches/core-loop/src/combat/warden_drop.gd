extends RefCounted

const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Palette := preload("res://src/core/palette.gd")

# Option A's Warden (design-v3/LOOP-REDESIGN.md sections 1 and 2), the fun lab's `drop`
# mode (loop_mode.gd). The Warden owns one of these only when drop rules apply (drop
# mode, on a map with drop lines); v2 never builds one, so the v2 fight is untouched.
#
# The rule: the body takes 0, always; no chip, no shred. The weak point opens on the
# family's own cycle (the reactor's pulse), for CORE_WINDOW plus CORE_BONUS a bonus
# core, and runs on its own clock from the stage's start, so a drop can be timed from
# the shelf. A drop is a contact that arrives on the open core from above at
# DROP_MIN_SPEED or more; it deals a segment (max HP / drops) times heft times impact
# speed over DROP_REF_SPEED, closes the window, and throws the ball off the core toward
# the return lift. The gun's role is a lab toggle:
#   hold  a weapon hit on the open weak point deals GUN_SHARE of its punch and holds
#         the window HOLD_PER_HIT longer, up to HOLD_CAP a window
#   full  a weapon hit while the window is open deals its full punch; drops are burst
# Outside a window nothing lands, whatever the role.
#
# The five states (section 2), one read for the look, the HUD and the bots:
#   closed     nothing lands
#   telegraph  the pulse charging (2 s, 1.5 s once integrity is at 75% or less)
#   open       the window, shrinking beam and all
#   recover    RECOVER after a window closes, the halves shutting
#   punish     a crater burning where a ball sat through the pulse (CRATER_SECONDS)

const DROP_MIN_SPEED := 20.0
const DROP_REF_SPEED := 25.0
const GUN_SHARE := 0.025
const HOLD_PER_HIT := 0.1
const HOLD_CAP := 2.0
const CORE_BONUS := 1.0
const RECOVER := 0.4
const LATE_SHARE := 0.75
const LATE_CYCLE := 4.5
const LATE_TELEGRAPH := 1.5
const CRATER_SECONDS := 5.0
const CRATER_RADIUS := 5.0
const CRATER_DAMAGE := 6.0
# The rebound off the core: at least this share of the arrival speed, planar, aimed so
# the arc comes down on the return lift's mouth (the bowl is a bumper).
const REBOUND_KEEP := 0.8
const REBOUND_PLANAR := Vector2(14.0, 30.0)
const REBOUND_LIFT := Vector2(6.0, 20.0)
const REBOUND_CLEAR := 0.35
# How far above the core's top a ball's centre may be, and how far out from the mast,
# for a contact to count as arriving on it (the drawn core forgives 20%).
const TOP_SLACK := 0.6
const REACH_FORGIVE := 1.2
const CONTACT_KINDS := ["stomp", "ram", "slam"]

var warden
var drops := 4
var gun_role := "hold"
var segment_hp := 100.0
var cores_fn := Callable()
var rebound_to := Vector3.INF
var gravity := 26.0
# Bookkeeping the tests and the bots read.
var windows := 0
var drops_landed := 0
var window_total := 0.0
var held := 0.0
var damage := {"drop": 0.0, "gun": 0.0, "outside": 0.0}
var last_drop := {}
# The last ball contact the rule judged: kind, window open, on the core, speed, and the
# ball's centre above the core's top. The bots' miss notes read it.
var last_contact := {}
var state := "closed"

var _recover := 0.0
var _craters: Array = []
var _clear_left := 0.0


func _init(warden_ref, spec: Dictionary) -> void:
	warden = warden_ref
	drops = maxi(1, int(spec.get("drops", 4)))
	gun_role = String(spec.get("gun_role", "hold"))
	cores_fn = spec.get("cores", Callable())
	rebound_to = spec.get("rebound_to", Vector3.INF)
	gravity = float(spec.get("gravity", 26.0))
	segment_hp = warden.max_hp / drops


func segments_left() -> int:
	return clampi(ceili(warden.hp / segment_hp - 0.001), 0, drops)


func late() -> bool:
	return warden.integrity() <= LATE_SHARE


func cycle_seconds(base: float) -> float:
	return LATE_CYCLE if late() else base


func telegraph_seconds(base: float) -> float:
	return LATE_TELEGRAPH if late() else base


# The window the family cycle asked for, lengthened by the stage's bonus cores.
func opened(seconds: float) -> float:
	var cores: int = int(cores_fn.call()) if cores_fn.is_valid() else 0
	window_total = seconds + CORE_BONUS * cores
	held = 0.0
	windows += 1
	return window_total


func window_left() -> float:
	return warden._open_left


# The one damage rule in drop mode, answered to combat.resolve() in its record shape.
func rule(kind: String, part: String, punch: float, heft: float) -> Dictionary:
	var open: bool = warden.family_open()
	var out := {"punch": punch, "plating": warden.plating, "full": false, "dealt": 0.0, "part": part, "shred": false,
		"drop": false, "speed": 0.0, "hold": false}
	if kind in CONTACT_KINDS:
		var arrival := _arrival()
		out["speed"] = arrival["speed"]
		last_contact = {"kind": kind, "open": open, "on_core": arrival["on_core"], "speed": snappedf(arrival["speed"], 0.1),
			"height": snappedf(arrival["ball"].y - warden.global_position.y - warden.HALF_HEIGHT, 0.01)}
		if open and arrival["on_core"] and arrival["speed"] >= DROP_MIN_SPEED:
			out["drop"] = true
			out["full"] = true
			out["dealt"] = segment_hp * heft * arrival["speed"] / DROP_REF_SPEED
		return out
	if not open:
		return out
	if gun_role == "full":
		out["full"] = true
		out["dealt"] = punch
	elif part == warden.family_point():
		out["full"] = true
		out["dealt"] = punch * GUN_SHARE
		out["hold"] = true
	return out


# Where and how fast the ball is arriving: on the core's top (or its upper edge, with
# the forgiveness), not rising, and its speed. A slam's own dive is a steering tool, not
# a power source, so a slamming ball brings only its planar speed.
func _arrival() -> Dictionary:
	var player = warden.target
	var ball: Vector3 = player.ball_position()
	var top: Vector3 = warden.global_position + Vector3.UP * warden.HALF_HEIGHT
	var to := top - ball
	var v: Vector3 = player.pre_contact_velocity(to.normalized() if to.length() > 0.01 else Vector3.DOWN)
	var slamming: bool = player.kit.slamming if "kit" in player else false
	var speed := Vector2(v.x, v.z).length() if slamming else v.length()
	var flat := Vector2(ball.x - top.x, ball.z - top.z).length()
	var on_core: bool = ball.y >= top.y - TOP_SLACK and flat <= warden.FAMILY_REACH * REACH_FORGIVE and v.y < 1.0
	return {"speed": speed, "on_core": on_core, "velocity": v, "ball": ball}


func on_struck(kind: String, result: Dictionary) -> void:
	var dealt: float = result.get("dealt", 0.0)
	if not warden.family_open() and dealt > 0.0:
		damage["outside"] += dealt
	if result.get("drop", false):
		damage["drop"] += dealt
		_land(result)
	elif not kind in CONTACT_KINDS:
		damage["gun"] += dealt
		if result.get("hold", false) and held < HOLD_CAP:
			var add := minf(HOLD_PER_HIT, HOLD_CAP - held)
			held += add
			warden._open_left += add
			_events().warden_window_held.emit(warden.family_point_at(), warden._open_left)


# A landed drop: the window shuts behind it, the badge loses what the hit took, and the
# ball comes off the core toward the return lift, faster than REBOUND_KEEP of what it
# brought.
func _land(result: Dictionary) -> void:
	drops_landed += 1
	var player = warden.target
	var arrival := _arrival()
	var speed_in: float = result["speed"]
	var out := _rebound(arrival["ball"], arrival["velocity"], speed_in)
	player.set_velocity_now(out)
	player.refresh_air()
	# The ball is still touching the core; one more contact would let the stomp bounce
	# put the arrival's heading back, so the core lets it pass for REBOUND_CLEAR.
	var body: PhysicsBody3D = player.body()
	if not body.get_collision_exceptions().has(warden):
		body.add_collision_exception_with(warden)
	_clear_left = REBOUND_CLEAR
	warden._open_left = 0.0
	_recover = RECOVER
	var left := clampi(ceili((warden.hp - float(result["dealt"])) / segment_hp - 0.001), 0, drops)
	last_drop = {"speed_in": speed_in, "speed_out": out.length(), "dealt": result["dealt"], "segments_left": left}
	_events().warden_drop_landed.emit(warden.family_point_at(), speed_in, left, drops)


func _rebound(ball: Vector3, v: Vector3, speed_in: float) -> Vector3:
	var planar := clampf(speed_in * REBOUND_KEEP, REBOUND_PLANAR.x, REBOUND_PLANAR.y)
	var heading := Vector3(v.x, 0.0, v.z).normalized() if Vector2(v.x, v.z).length() > 0.5 else Vector3.FORWARD
	if rebound_to == Vector3.INF:
		return heading * planar + Vector3.UP * REBOUND_LIFT.y
	var flat := Vector3(rebound_to.x - ball.x, 0.0, rebound_to.z - ball.z)
	var t := maxf(0.4, flat.length() / planar)
	var vy := clampf((rebound_to.y - ball.y + 0.5 * gravity * t * t) / t, REBOUND_LIFT.x, REBOUND_LIFT.y)
	return flat.normalized() * planar + Vector3.UP * vy


# A pulse that caught the ball in its reach leaves a crater under it: a burning ring on
# the floor for CRATER_SECONDS, the reactor's punish (WARDEN-DESIGN 9.1).
func on_pulse(caught: bool, ball: Vector3) -> void:
	if not caught:
		return
	var at := Vector3(ball.x, 0.0, ball.z)
	var ring: Node3D = Telegraph.ring(warden.world_root, warden.terrain, Threat.Type.INSTANT, at, CRATER_RADIUS, 2.5, Palette.HAZARD)
	ring.set_progress(1.0)
	_craters.append({"node": ring, "left": CRATER_SECONDS, "hit": false})


# One tick, after the Warden's own: was_open is whether the window stood before it.
func step(delta: float, was_open: bool) -> void:
	_recover = maxf(0.0, _recover - delta)
	if was_open and warden._open_left <= 0.0:
		_recover = RECOVER
	if _clear_left > 0.0:
		_clear_left -= delta
		if _clear_left <= 0.0:
			_restore_contact()
	var ball: Vector3 = warden.target.ball_position() if warden.target != null else Vector3.INF
	for c in _craters.duplicate():
		c["left"] -= delta
		var node: Node3D = c["node"]
		if c["left"] <= 0.0 or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			_craters.erase(c)
			continue
		if not c["hit"] and ball != Vector3.INF and node.contains(ball):
			c["hit"] = true
			warden.hit_player.emit(CRATER_DAMAGE, Vector3.ZERO)
	_publish()


func current_state() -> String:
	if warden._open_left > 0.0:
		return "open"
	if warden._charging:
		return "telegraph"
	if _recover > 0.0:
		return "recover"
	if not _craters.is_empty():
		return "punish"
	return "closed"


func _publish() -> void:
	var now := current_state()
	if now == state:
		return
	state = now
	_events().warden_state_changed.emit(now, warden.family_point_at())


func _restore_contact() -> void:
	var player = warden.target
	if player == null or not is_instance_valid(player):
		return
	var body: PhysicsBody3D = player.body()
	if is_instance_valid(body) and body.get_collision_exceptions().has(warden):
		body.remove_collision_exception_with(warden)


func clear() -> void:
	if _clear_left > 0.0:
		_clear_left = 0.0
		_restore_contact()
	for c in _craters:
		if is_instance_valid(c["node"]):
			c["node"].queue_free()
	_craters.clear()


func _events():
	return warden.fleet.events()
