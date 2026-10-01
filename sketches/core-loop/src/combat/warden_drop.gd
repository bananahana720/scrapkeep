extends RefCounted

const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Palette := preload("res://src/core/palette.gd")

# Option A's Warden (design-v3/LOOP-REDESIGN.md sections 1 and 2), the fun lab's `drop`
# mode (loop_mode.gd), revised against the Codex review (research/CODEX-REVIEW-1.md,
# findings 1, 2, 3, 6 and 11). The Warden owns one of these only when drop rules apply
# (drop mode, on a map with drop lines); v2 never builds one, so the v2 fight is
# untouched.
#
# The body takes 0, always: no chip, no shred. The weak point opens on the family's own
# cycle (the reactor's pulse), for CORE_WINDOW plus CORE_BONUS a bonus core, and in drop
# mode that cycle runs on its own clock from the stage's start, so the next opening is
# a committed schedule a player can read from the shelf (open_at(), drawn by
# drop_juice.gd) instead of a timer that starts only once you are in reach.
#
# One physical predicate decides every ball contact (verdict()):
#   drop   the ball came off the map (it was beyond LINE_REACH of the mast within
#          DROP_MEMORY), arrives descending at DESCEND_MIN or faster with its centre over
#          the core's top (TOP_SLACK, and REACH_FORGIVE past the drawn core), at
#          DROP_MIN_SPEED or more, into an open window that has not had its drop yet
#   miss   it came off the map but failed any other test: no damage, and the core
#          throws it at the return anyway, so a miss costs one lift ride, not a walk
#   floor  anything from inside the bowl, or within REARM of the last drop or miss:
#          nothing, no throw. Pulse-lift slams, the nearest lip taken from the bowl
#          floor, lift camping and rebound chains all land here, so a bowl shortcut
#          does not count at all (Andrew's answer 2a, "nothing but a drop lands").
# A drop deals a segment (max HP / drops) times heft times arrival speed over
# DROP_REF_SPEED. The gun's role is the lab toggle:
#   hold  the drop is the hammer and closes the window; a weapon hit on the open weak
#         point holds the window HOLD_PER_HIT longer, up to HOLD_CAP a window, and banks
#         GUN_SHARE of its punch, which lands with that window's drop and is lost if the
#         window closes without one. So a gun alone never moves the badge (section 1,
#         "holding fire only extends windows nobody is dropping through"), and holding
#         the door still pays when the drop comes.
#   full  the drop is a burst (FULL_DROP_SHARE of it) that staggers the Warden: the
#         core stands open STAGGER_SECONDS (plus the cores' bonus) and every weapon hit
#         on the Warden deals its full punch. Only a stagger lets the gun land, so a
#         ball that never drops cannot open one (review finding 11).
#
# The five states (section 2), one read for the look, the HUD and the bots:
#   closed     nothing lands
#   telegraph  the pulse charging (2 s, 1.5 s once integrity is at 75% or less)
#   open       the window (or a stagger), shrinking beam and all
#   recover    RECOVER after a window closes, the halves shutting
#   punish     a crater burning where a ball sat through the pulse (CRATER_SECONDS)

const DROP_MIN_SPEED := 20.0
const DROP_REF_SPEED := 25.0
const DESCEND_MIN := 2.0
const LINE_REACH := 50.0
const DROP_MEMORY := 6.0
const REARM := 1.0
const GUN_SHARE := 0.025
const HOLD_PER_HIT := 0.1
const HOLD_CAP := 2.0
const FULL_DROP_SHARE := 0.75
const STAGGER_SECONDS := 6.0
const CORE_BONUS := 1.0
const RECOVER := 0.4
const LATE_SHARE := 0.75
const LATE_CYCLE := 4.5
const LATE_TELEGRAPH := 1.5
const CRATER_SECONDS := 5.0
const CRATER_RADIUS := 5.0
const CRATER_DAMAGE := 6.0
# The throw off the core: at least REBOUND_KEEP of the arrival speed, planar, on an arc
# that comes down on the return lift's mouth (the bowl is a bumper). Under `full` a drop
# throws the ball up the bank beside the lift instead (STAGGER_PERCH m out), so the gun
# has the stagger to work with before the ride.
const REBOUND_KEEP := 0.8
const REBOUND_PLANAR := Vector2(14.0, 30.0)
const REBOUND_LIFT := Vector2(6.0, 20.0)
const REBOUND_CLEAR := 0.35
const STAGGER_PERCH := 36.0
# How far below the core's top a ball's centre may sit (a ball radius: it overlaps the
# rim) and how far out from the mast, for an arrival to count as on the core: the drawn
# core forgives 20%.
const TOP_SLACK := 1.0
const REACH_FORGIVE := 1.2
const CONTACT_KINDS := ["stomp", "ram", "slam"]

var warden
var drops := 4
var gun_role := "hold"
var segment_hp := 100.0
var cores_fn := Callable()
var rebound_to := Vector3.INF
var perch_to := Vector3.INF
var gravity := 26.0
# Bookkeeping the tests and the bots read.
var windows := 0
var staggers := 0
var drops_landed := 0
var misses := 0
var window_total := 0.0
var held := 0.0
var staggered := false
var damage := {"drop": 0.0, "gun": 0.0, "outside": 0.0, "stagger_gun": 0.0, "banked_lost": 0.0}
# The hold role's gun share banked this window, and every ball contact that struck.
var banked := 0.0
var contacts := 0
var last_drop := {}
# The last ball contact that struck, with its verdict; the bots' miss notes read it.
var last_contact := {}
var state := "closed"

var _recover := 0.0
var _craters: Array = []
var _clear_left := 0.0
var _clock := 0.0
var _last_outside := -INF
var _rearm := 0.0
var _dropped := false
var _excepted := false


func _init(warden_ref, spec: Dictionary) -> void:
	warden = warden_ref
	drops = maxi(1, int(spec.get("drops", 4)))
	gun_role = String(spec.get("gun_role", "hold"))
	cores_fn = spec.get("cores", Callable())
	rebound_to = spec.get("rebound_to", Vector3.INF)
	perch_to = spec.get("perch_to", Vector3.INF)
	gravity = float(spec.get("gravity", 26.0))
	segment_hp = warden.max_hp / drops


# The badge's whole chunks, true to the Warden's actual HP: a chunk is lit while any of
# its HP stands. It counts HP, not the drops a player still owes.
func segments_left() -> int:
	return clampi(ceili(warden.hp / segment_hp - 0.001), 0, drops)


func late() -> bool:
	return warden.integrity() <= LATE_SHARE


func cycle_seconds(base: float) -> float:
	return LATE_CYCLE if late() else base


func telegraph_seconds(base: float) -> float:
	return LATE_TELEGRAPH if late() else base


func _cores() -> int:
	return int(cores_fn.call()) if cores_fn.is_valid() else 0


func base_window() -> float:
	return warden.CORE_WINDOW + CORE_BONUS * _cores()


# The family cycle asked for a window. Time already standing is never taken away: a
# stagger or window longer than the fresh one keeps its time, and a window still open at
# the pulse keeps its banked share and held time and is not counted a second time.
func opened(seconds: float) -> float:
	var fresh := seconds + CORE_BONUS * _cores()
	var left: float = warden._open_left
	if staggered and left > fresh:
		return left
	if not staggered and left > 0.0:
		window_total = maxf(left, fresh)
		return window_total
	staggered = false
	window_total = fresh
	held = 0.0
	_forfeit()
	windows += 1
	_dropped = false
	return window_total


func window_left() -> float:
	return warden._open_left


# The committed schedule: seconds until the next pulse opens the core.
func next_pulse_in() -> float:
	if warden._charging:
		return maxf(0.0, warden._charge_len - warden._charge_time)
	return maxf(0.0, cycle_seconds(warden.PULSE_CYCLE) - warden._pulse_clock)


# Whether the core will stand open t seconds from now, by the schedule (a held door or
# a stagger only lengthens what this says).
func open_at(t: float) -> bool:
	if warden._open_left > t:
		return true
	var first := next_pulse_in()
	if t < first:
		return false
	return fmod(t - first, cycle_seconds(warden.PULSE_CYCLE)) < base_window()


# The one damage rule in drop mode, answered to combat.resolve() in its record shape.
func rule(kind: String, part: String, punch: float, heft: float) -> Dictionary:
	var out := {"punch": punch, "plating": warden.plating, "full": false, "dealt": 0.0, "part": part, "shred": false,
		"drop": false, "miss": false, "speed": 0.0, "hold": false}
	if kind in CONTACT_KINDS:
		var arrival := _arrival()
		var verdict := _verdict(arrival)
		out["speed"] = arrival["speed"]
		out["contact"] = {"kind": kind, "verdict": verdict, "open": warden.family_open(), "on_core": arrival["on_core"],
			"descending": arrival["descending"], "from_line": arrival["from_line"], "speed": snappedf(arrival["speed"], 0.1),
			"height": snappedf(arrival["height"], 0.01)}
		if verdict == "drop":
			out["drop"] = true
			out["full"] = true
			out["banked"] = banked
			out["dealt"] = segment_hp * heft * arrival["speed"] / DROP_REF_SPEED * (FULL_DROP_SHARE if gun_role == "full" else 1.0) + banked
		elif verdict == "miss":
			out["miss"] = true
		return out
	if gun_role == "full":
		if staggered and warden.family_open():
			out["full"] = true
			out["dealt"] = punch
	elif warden.family_open() and part == warden.family_point():
		out["full"] = true
		out["banks"] = punch * GUN_SHARE
		out["hold"] = true
	return out


# Where and how the ball is arriving. A slam's own dive is a steering tool, not a power
# source, so a slamming ball brings only its planar speed.
func _arrival() -> Dictionary:
	var player = warden.target
	var ball: Vector3 = player.ball_position()
	var top: Vector3 = warden.global_position + Vector3.UP * warden.HALF_HEIGHT
	var to := top - ball
	var v: Vector3 = player.pre_contact_velocity(to.normalized() if to.length() > 0.01 else Vector3.DOWN)
	var slamming: bool = player.kit.slamming if "kit" in player else false
	var speed: float = Vector2(v.x, v.z).length() if slamming else v.length()
	var flat := Vector2(ball.x - top.x, ball.z - top.z).length()
	var on_core: bool = ball.y >= top.y - TOP_SLACK and flat <= warden.FAMILY_REACH * REACH_FORGIVE
	return {"speed": speed, "on_core": on_core, "descending": v.y <= -DESCEND_MIN, "velocity": v, "ball": ball,
		"height": ball.y - top.y, "from_line": _clock - _last_outside <= DROP_MEMORY}


func _verdict(a: Dictionary) -> String:
	if not a["from_line"] or _rearm > 0.0:
		return "floor"
	if warden.family_open() and not _dropped and a["on_core"] and a["descending"] and a["speed"] >= DROP_MIN_SPEED:
		return "drop"
	return "miss"


func on_struck(kind: String, result: Dictionary) -> void:
	if result.has("contact"):
		contacts += 1
		last_contact = result["contact"]
	var dealt: float = result.get("dealt", 0.0)
	if not warden.family_open() and dealt > 0.0:
		damage["outside"] += dealt
	if result.get("drop", false):
		var share: float = result.get("banked", 0.0)
		damage["drop"] += dealt - share
		damage["gun"] += share
		banked = 0.0
		_land(result)
	elif result.get("miss", false):
		_miss()
	elif not kind in CONTACT_KINDS:
		damage["gun"] += dealt
		if staggered:
			damage["stagger_gun"] += dealt
		banked += float(result.get("banks", 0.0))
		if result.get("hold", false) and held < HOLD_CAP:
			var add := minf(HOLD_PER_HIT, HOLD_CAP - held)
			held += add
			warden._open_left += add
			_events().warden_window_held.emit(warden.family_point_at(), warden._open_left)


# A landed drop. Under `hold` the window shuts behind it; under `full` it staggers the
# Warden open. Either way the ball comes off the core faster than REBOUND_KEEP of what
# it brought.
func _land(result: Dictionary) -> void:
	drops_landed += 1
	_dropped = true
	_rearm = REARM
	var speed_in: float = result["speed"]
	var out := _throw(speed_in, perch_to if gun_role == "full" and perch_to != Vector3.INF else rebound_to)
	if gun_role == "full":
		staggered = true
		staggers += 1
		warden._open_left = STAGGER_SECONDS + CORE_BONUS * _cores()
		window_total = warden._open_left
		_events().weak_point_opened.emit(warden.family_point(), warden.family_point_at(), warden._open_left)
	else:
		warden._open_left = 0.0
		_recover = RECOVER
	var left := clampi(ceili((warden.hp - float(result["dealt"])) / segment_hp - 0.001), 0, drops)
	last_drop = {"speed_in": speed_in, "speed_out": out.length(), "dealt": result["dealt"], "segments_left": left}
	_events().warden_drop_landed.emit(warden.family_point_at(), speed_in, left, drops)


# A line arrival that did not land still goes back into the loop: the core throws it at
# the return, so the recovery is one ride.
func _miss() -> void:
	misses += 1
	_rearm = REARM
	_throw(float(_arrival()["speed"]), rebound_to)


func _throw(speed_in: float, to: Vector3) -> Vector3:
	var player = warden.target
	var arrival := _arrival()
	var out := _rebound(arrival["ball"], arrival["velocity"], speed_in, to)
	player.set_velocity_now(out)
	player.refresh_air()
	# The ball is still touching the core; one more contact would let the stomp bounce
	# put the arrival's heading back, so the core lets it pass for REBOUND_CLEAR. The
	# ball's exception list can hold freed enemies (a crush's pass), so it is not read.
	if not _excepted:
		player.body().add_collision_exception_with(warden)
		_excepted = true
	_clear_left = REBOUND_CLEAR
	return out


func _rebound(ball: Vector3, v: Vector3, speed_in: float, to: Vector3) -> Vector3:
	var planar := clampf(speed_in * REBOUND_KEEP, REBOUND_PLANAR.x, REBOUND_PLANAR.y)
	var heading := Vector3(v.x, 0.0, v.z).normalized() if Vector2(v.x, v.z).length() > 0.5 else Vector3.FORWARD
	if to == Vector3.INF:
		return heading * planar + Vector3.UP * REBOUND_LIFT.y
	var flat := Vector3(to.x - ball.x, 0.0, to.z - ball.z)
	var t := maxf(0.4, flat.length() / planar)
	var vy := clampf((to.y - ball.y + 0.5 * gravity * t * t) / t, REBOUND_LIFT.x, REBOUND_LIFT.y)
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
	_clock += delta
	_rearm = maxf(0.0, _rearm - delta)
	_recover = maxf(0.0, _recover - delta)
	if was_open and warden._open_left <= 0.0:
		_recover = RECOVER
		staggered = false
		_forfeit()
	if _clear_left > 0.0:
		_clear_left -= delta
		if _clear_left <= 0.0:
			_restore_contact()
	var ball: Vector3 = warden.target.ball_position() if warden.target != null else Vector3.INF
	if ball != Vector3.INF and Vector2(ball.x - warden.global_position.x, ball.z - warden.global_position.z).length() > LINE_REACH:
		_last_outside = _clock
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


func _forfeit() -> void:
	damage["banked_lost"] += banked
	banked = 0.0


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
	if not _excepted:
		return
	_excepted = false
	var player = warden.target
	if player == null or not is_instance_valid(player):
		return
	var body: PhysicsBody3D = player.body()
	if is_instance_valid(body):
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
