extends "res://src/combat/counter.gd"

# The mag trapper (DESIGN-V2 section 10): a crew cart with a stack of pit discs on its
# back. It throws a disc at where the ball will be, and the disc's instant ring closes
# over the warning. Live, it is a magnetic pit: a ball inside it lighter than the
# disc's heft rating is dragged, its speed bled and its line pulled toward the centre.
# Heft at or above the rating rolls straight through, so growing is the counter. A jump
# or a smash shatters the disc.

const PIT_RADIUS := 4.5
const PIT_REACH := 1.4
const LEAD := 0.7
const DRAG := 2.4
const CENTRE_PULL := 2.5
const RATING_BASE := 1.6
const RATING_PER_THREAT := 0.4
const HP := 50.0

var rating := RATING_BASE
var _stack: Node3D


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.2
	warn_seconds = 1.1
	live_seconds = 3.0
	rest_seconds = 3.5
	attack_range = 26.0
	rating = RATING_BASE + RATING_PER_THREAT * (threat - 1.0)


func _build_tool() -> void:
	_stack = Node3D.new()
	_stack.position = Vector3(0.0, CREW_HALF + 0.2, -CREW_RADIUS - 0.4)
	add_child(_stack)
	for i in 4:
		_cylinder(1.05, 0.16, Palette.CHARCOAL, Vector3(0.0, i * 0.2, 0.0), 0.0, _stack)
		_cylinder(0.5, 0.18, Palette.HAZARD, Vector3(0.0, i * 0.2, 0.0), 0.6, _stack)


func _commit(_to_ball: Vector3) -> Node3D:
	var aim: Vector3 = _ball() + target.planar_velocity() * LEAD
	_facing(aim - global_position)
	return _commit_ring(Threat.Type.INSTANT, aim, PIT_RADIUS, PIT_REACH)


func _live(_delta: float) -> bool:
	var pit := telegraph()
	if pit == null:
		return false
	var player = _player()
	var ball := _real_ball()
	if not pit.contains(ball) or player.heft() >= rating:
		if _holding():
			_release("left")
		return true
	if not _holding() and not _catch():
		return true
	var to_centre: Vector3 = pit.center - ball
	to_centre.y = 0.0
	_pull(-player.planar_velocity() * DRAG + to_centre * CENTRE_PULL)
	return true


func _pose() -> void:
	if _stack != null:
		_stack.visible = phase != Phase.LIVE
