extends Node

const Threat := preload("res://src/combat/threat_grammar.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# The dodge read (playtest entry 8: "I don't know if I was dodging"). It watches every
# committed hostile threat (the "threat" group: combat's telegraphs and the boss's
# hazards) through the threat's own contains(), the same test its damage uses, and
# publishes near_miss when the ball was inside while the threat warned and outside when
# it landed, or left within the grace without being hurt. It reads and publishes; it
# never changes an outcome.
#
# The same watch answers the question before the landing: standing_in() is how far along
# the furthest warning the ball stands in has run, for the HUD's mark over the ball
# (ui/danger_mark.gd). A floor mark cannot say "you are in me" to a camera inside it. And
# escape() is the way out of that same warning, for the ground paint (W1-05).

var events
# The ball's position; combat points it at the real ball, a test at a scripted point.
var ball: Callable
var grace := float(EventKinds.juice("near_miss").get("grace_ms", 250)) / 1000.0
var fired := 0

var _watch := {}
var _clock := 0.0
var _last_hit := -INF
var _hit_pending := false
var _standing := -1.0
var _escape := {}


func setup(events_ref, ball_ref: Callable) -> void:
	name = "NearMiss"
	events = events_ref
	ball = ball_ref
	events.player_hit.connect(func(_amount: float, _source: String): _hit_pending = true)


func _physics_process(delta: float) -> void:
	step(delta)


# How far along the furthest warning the ball stands in has run, 0 to 1, as of the last
# step, or -1 when it stands in none: the ball is inside a threat that has not landed.
func standing_in() -> float:
	return _standing


# The way out of the warning the ball stands in, as of the last step: {dir, metres, run}, the
# flat unit way to its nearest edge, how far that edge is and how far the warning has run; {}
# when it stands in none. The ground paint (presentation/way_out_paint.gd) draws it on the floor.
func escape() -> Dictionary:
	return _escape


# The shortest way out of a warning for a ball at `at`, flat and unit length, from its committed
# shape (the descriptor its damage reads): a ring or wave outward, a band (a ring with a hole)
# inward or outward, a wedge also across its nearer side, a lane sideways or off either end.
# Zero when the shape gives no way (the ball on a ring's very centre still gets one: outward
# along the ring's own first edge).
static func way_out(d: Dictionary, at: Vector3) -> Vector3:
	return way_out_reach(d, at)["dir"]


# The same way out with how far it runs: {dir, metres}, metres the flat distance from `at` to
# that nearest edge (0 when there is no way).
static func way_out_reach(d: Dictionary, at: Vector3) -> Dictionary:
	var centre: Vector3 = d.get("centre", at)
	var flat := Vector3(at.x - centre.x, 0.0, at.z - centre.z)
	var best := INF
	var way := Vector3.ZERO
	match String(d.get("form", "")):
		"radial":
			var r := flat.length()
			var out := flat / r if r > 0.01 else Vector3(cos(float(d.get("a0", 0.0))), 0.0, sin(float(d.get("a0", 0.0))))
			best = float(d.get("r_out", 0.0)) - r
			way = out
			var r_in := float(d.get("r_in", 0.0))
			if r_in > 0.0 and r - r_in < best:
				best = r - r_in
				way = -out
			var a0 := float(d.get("a0", 0.0))
			var a1 := float(d.get("a1", TAU))
			if a1 - a0 < TAU - 0.01 and r > 0.01:
				var angle := atan2(flat.z, flat.x)
				for edge in [a0, a1]:
					var across := r * absf(sin(wrapf(angle - edge, -PI, PI)))
					if across < best:
						best = across
						var side := Vector3(-out.z, 0.0, out.x)
						way = side if wrapf(edge - angle, -PI, PI) > 0.0 else -side
		"lane":
			var dir: Vector3 = d.get("dir", Vector3.FORWARD)
			dir = Vector3(dir.x, 0.0, dir.z).normalized()
			var along := flat.dot(dir)
			var lateral := flat - dir * along
			var side := lateral.normalized() if lateral.length() > 0.01 else Vector3(-dir.z, 0.0, dir.x)
			best = float(d.get("half_width", 0.0)) - lateral.length()
			way = side
			if float(d.get("length", 0.0)) - along < best:
				best = float(d.get("length", 0.0)) - along
				way = dir
			# A lane reaches `back` metres behind its start (hazard.gd: along >= -back).
			if along + float(d.get("back", 0.0)) < best:
				best = along + float(d.get("back", 0.0))
				way = -dir
	if way.length_squared() <= 0.0:
		return {"dir": Vector3.ZERO, "metres": 0.0}
	return {"dir": way.normalized(), "metres": maxf(best, 0.0)}


func step(delta: float) -> void:
	_clock += delta
	_standing = -1.0
	_escape = {}
	# A hit this tick counts from this tick, whichever ran first, the attack or this watch.
	if _hit_pending:
		_hit_pending = false
		_last_hit = _clock
	if not is_inside_tree() or not ball.is_valid():
		return
	var at: Vector3 = ball.call()
	for node in get_tree().get_nodes_in_group(Threat.GROUP):
		var id := node.get_instance_id()
		if not _watch.has(id) and node.has_method("contains") and node.has_method("descriptor"):
			_watch[id] = {"node": node, "entered": false, "resolved": -1.0, "done": false}
			node.tree_exiting.connect(_on_exiting.bind(id), CONNECT_ONE_SHOT)
	for id in _watch.keys():
		var w: Dictionary = _watch[id]
		var node: Node = w["node"]
		if not is_instance_valid(node):
			_watch.erase(id)
			continue
		if w["done"]:
			continue
		var inside: bool = node.contains(at)
		if w["resolved"] < 0.0:
			# One read of the committed numbers serves every test below this tick.
			var d: Dictionary = node.descriptor()
			if _landed(node, at, d):
				_resolve(id, inside, at)
			elif inside or _ahead_of_front(node, at, d):
				if not w["entered"]:
					w["entered_at"] = _clock
				w["entered"] = true
				# An air-only mark (the netcaster's net) catches only a ball off the ground, and
				# its answer is to stay down: a mark that says "get out or jump" would say the
				# wrong thing, so it raises none.
				if not bool(d.get("air", false)):
					var ran := _run_of(node, at, d)
					if ran >= _standing:
						_standing = ran
						_escape = way_out_reach(d, at)
						_escape["run"] = ran
			continue
		if _last_hit >= w["resolved"]:
			w["done"] = true
		elif not inside:
			_fire(id, at)
		elif _clock - w["resolved"] > grace:
			w["done"] = true


static func _landed(node: Node, at: Vector3, d := {}) -> bool:
	if d.is_empty():
		d = node.descriptor()
	if _front_wave(node, d):
		return node.is_spent() or node.front_radius() - Threat.WAVE_EDGE > _flat_from(node, at, d)
	# A lane with a running front (Brindle's charge) lands for the ball once its front has
	# reached the ball, not when it goes live: the mark over the ball stays up until the hull arrives.
	if d.has("front_m") and bool(d.get("live", false)):
		return float(d["front_m"]) >= _lane_along(at, d)
	return bool(d.get("live", false)) or float(d.get("progress", 0.0)) >= 1.0


static func _lane_along(at: Vector3, d: Dictionary) -> float:
	var dir: Vector3 = d.get("dir", Vector3.FORWARD)
	var c: Vector3 = d["centre"]
	return Vector3(at.x - c.x, 0.0, at.z - c.z).dot(Vector3(dir.x, 0.0, dir.z).normalized())


# A WAVE telegraph (telegraph.gd) hurts only on its running front, so contains() is false
# all through the warning (F003). Its watch reads the front instead: the ball is in while
# it stands inside the ring and the front has not run past it, and the wave lands for the
# ball once the front has run past it or the wave is spent.
static func _front_wave(node: Node, d := {}) -> bool:
	if not (node.has_method("front_radius") and node.has_method("is_spent")):
		return false
	return int((d if not d.is_empty() else node.descriptor()).get("type", -1)) == Threat.Type.WAVE


# How far a warning has run for a ball at `at`: its progress, and for a front wave half for
# the arming and half for the front's run from the centre out to the ball.
static func _run_of(node: Node, at: Vector3, d: Dictionary) -> float:
	var progress := clampf(float(d.get("progress", 0.0)), 0.0, 1.0)
	if not _front_wave(node, d):
		return progress
	var front: float = node.front_radius()
	if front < 0.0:
		return 0.5 * progress
	return 0.5 + 0.5 * clampf(front / maxf(_flat_from(node, at, d), 0.01), 0.0, 1.0)


static func _flat_from(node: Node, at: Vector3, d := {}) -> float:
	var centre: Vector3 = (d if not d.is_empty() else node.descriptor())["centre"]
	return Vector2(at.x - centre.x, at.z - centre.z).length()


static func _runs_front(node: Node) -> bool:
	return _front_wave(node) or node.descriptor().has("front_m")


static func _ahead_of_front(node: Node, at: Vector3, d := {}) -> bool:
	if d.is_empty():
		d = node.descriptor()
	if not _front_wave(node, d):
		return false
	var terrain = node.get("terrain")
	var ground: float = node.ground_under(terrain, at) if terrain != null else float(d["centre"].y)
	var above := at.y - ground
	if above > float(d.get("reach", 0.0)) or above < -2.0:
		return false
	var flat := _flat_from(node, at, d)
	return flat <= float(d.get("r_out", 0.0)) and node.front_radius() - Threat.WAVE_EDGE <= flat


func _resolve(id: int, inside: bool, at: Vector3) -> void:
	var w: Dictionary = _watch[id]
	if not w["entered"]:
		w["done"] = true
		return
	# A front wave or a running lane (Brindle's ram) lands after its front reached the ball, so a
	# hit since the ball was in already came from it.
	if _runs_front(w["node"]) and _last_hit >= float(w.get("entered_at", INF)):
		w["done"] = true
		return
	w["resolved"] = _clock
	if not inside:
		_fire(id, at)


# A threat freed in the tick it landed still counts, judged where the ball is now.
func _on_exiting(id: int) -> void:
	if not _watch.has(id):
		return
	var w: Dictionary = _watch[id]
	var node: Node = w["node"]
	if not w["done"] and w["resolved"] < 0.0 and w["entered"] and is_instance_valid(node) and ball.is_valid() \
			and _landed(node, ball.call()):
		var at: Vector3 = ball.call()
		_resolve(id, node.contains(at), at)
	_watch.erase(id)


func _fire(id: int, at: Vector3) -> void:
	var node: Node = _watch[id]["node"]
	var kind: String = node.threat_kind() if is_instance_valid(node) and node.has_method("threat_kind") else "threat_instant"
	_watch[id]["done"] = true
	fired += 1
	events.near_miss.emit(kind, at)
