extends Node

const Threat := preload("res://src/combat/threat_grammar.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# The dodge read (playtest entry 8: "I don't know if I was dodging"). It watches every
# committed hostile threat (the "threat" group: combat's telegraphs and the boss's
# hazards) through the threat's own contains(), the same test its damage uses, and
# publishes near_miss when the ball was inside while the threat warned and outside when
# it landed, or left within the grace without being hurt. It reads and publishes; it
# never changes an outcome.

var events
# The ball's position; combat points it at the real ball, a test at a scripted point.
var ball: Callable
var grace := float(EventKinds.juice("near_miss").get("grace_ms", 250)) / 1000.0
var fired := 0

var _watch := {}
var _clock := 0.0
var _last_hit := -INF
var _hit_pending := false


func setup(events_ref, ball_ref: Callable) -> void:
	name = "NearMiss"
	events = events_ref
	ball = ball_ref
	events.player_hit.connect(func(_amount: float, _source: String): _hit_pending = true)


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	_clock += delta
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
	return bool(d.get("live", false)) or float(d.get("progress", 0.0)) >= 1.0


# A WAVE telegraph (telegraph.gd) hurts only on its running front, so contains() is false
# all through the warning (F003). Its watch reads the front instead: the ball is in while
# it stands inside the ring and the front has not run past it, and the wave lands for the
# ball once the front has run past it or the wave is spent.
static func _front_wave(node: Node, d := {}) -> bool:
	if not (node.has_method("front_radius") and node.has_method("is_spent")):
		return false
	return int((d if not d.is_empty() else node.descriptor()).get("type", -1)) == Threat.Type.WAVE


static func _flat_from(node: Node, at: Vector3, d := {}) -> float:
	var centre: Vector3 = (d if not d.is_empty() else node.descriptor())["centre"]
	return Vector2(at.x - centre.x, at.z - centre.z).length()


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
	# A front wave lands after its front crossed the ball, so a hit since the ball was in
	# already came from it.
	if _front_wave(w["node"]) and _last_hit >= float(w.get("entered_at", INF)):
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
