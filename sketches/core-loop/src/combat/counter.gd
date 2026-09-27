extends "res://src/combat/enemy.gd"

const Roster := preload("res://src/combat/roster.gd")

# What every Fleet reinforcement shares (DESIGN-V2 section 10): an animal crew with its
# anti-ball tool as the biggest shape, and one loop, roam -> warn -> live -> rest.
#
# - Warn commits the unit's telegraph with W2's grammar and dresses it with the Fleet's
#   voice and the unit's mechanic tag (roster.gd), so the danger draws and sounds on the
#   frame it is declared. Nothing holds the ball before its warning has run.
# - Live is the unit's own mechanic (a subclass's _live). A hold goes through the holds
#   node, which owns the crowd-control door, tenacity and breaking free.
# - A hard hit in the warning (a knock at INTERRUPT) breaks the attack, as a chaser's.
#
# Subclasses set the dials in _configure(), build the tool in _build_tool(), commit the
# telegraph in _commit() and run the mechanic in _live(delta) -> bool (false ends it).

enum Phase { ROAM, WARN, LIVE }

const INTERRUPT := 10.0
const CREW_RADIUS := 0.8
const CREW_HALF := 1.1
const HEAD_RADIUS := 0.38
const TAG_SIZE := Vector3(0.36, 0.24, 0.06)

var holds
var row := {}
var phase := Phase.ROAM
# Telegraphs committed and holds started, for tests and the balance read.
var warned := 0
var caught := 0
# The last warning's committed seconds, for the telegraph-before-hold check.
var last_warn := 0.0

var walk_speed := 3.8
var keep_near := 9.0
var keep_far := 24.0
var attack_range := 22.0
var warn_seconds := 1.0
var live_seconds := 1.0
var rest_seconds := 3.0
var first_rest := 1.5
var interruptible := true

var _t := 0.0
var _rest := 0.0
var _strafe := 1.0
var _crew: MeshInstance3D


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	_setup_common(target_ref, terrain_ref, root_ref, live_ref, spec_ref)
	kind = spec.get("kind", "chaser")
	row = Roster.row(kind)
	faction = Roster.faction_of(kind)
	holds = spec.get("holds")
	_strafe = 1.0 if (get_instance_id() % 2) == 0 else -1.0
	_configure(threat)
	_rest = first_rest
	_build_crew()
	_build_tool()


func state_name() -> String:
	return ["roam", "warn", "live"][phase]


# --- Subclass hooks -------------------------------------------------------------------

func _configure(threat: float) -> void:
	_set_health(40.0 * threat)


func _build_tool() -> void:
	pass


func _wants_attack(to_ball: Vector3) -> bool:
	return to_ball.length() <= attack_range and is_on_floor()


func _commit(_to_ball: Vector3) -> Node3D:
	return null


func _go_live() -> void:
	pass


func _live(_delta: float) -> bool:
	return true


func _on_end() -> void:
	pass


func _pose() -> void:
	pass


func _roam(to_ball: Vector3) -> Vector3:
	var distance := to_ball.length()
	if distance < 0.1:
		return Vector3.ZERO
	var toward := to_ball / distance
	if distance > keep_far:
		return toward * walk_speed
	if distance < keep_near:
		return -toward * walk_speed
	return toward.cross(Vector3.UP) * _strafe * walk_speed * 0.5


# --- The loop -------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_update_flash(delta)
	if not _in_play() or target == null:
		_idle(delta)
		return
	_t += delta
	var to_ball := _flat_to_ball()
	match phase:
		Phase.ROAM:
			_rest -= delta
			_move(delta, _roam(to_ball))
			if _rest <= 0.0 and _knocked_speed() < 1.0 and _wants_attack(to_ball):
				_warn(to_ball)
		Phase.WARN:
			_move(delta, Vector3.ZERO)
			var tele := telegraph()
			if tele != null:
				tele.set_progress(_t / warn_seconds)
			if tele == null or (interruptible and _knocked_speed() >= INTERRUPT):
				_end()
			elif _t >= warn_seconds:
				last_warn = _t
				phase = Phase.LIVE
				_t = 0.0
				_go_live()
		Phase.LIVE:
			_move(delta, _live_motion(to_ball))
			if not _live(delta) or _t >= live_seconds:
				_end()
	_pose()


func _idle(delta: float) -> void:
	_move(delta, Vector3.ZERO)


func _live_motion(_to_ball: Vector3) -> Vector3:
	return Vector3.ZERO


func _warn(to_ball: Vector3) -> void:
	var tele := _commit(to_ball)
	if tele == null:
		_rest = 0.5
		return
	_voice(tele)
	warned += 1
	phase = Phase.WARN
	_t = 0.0


# The Fleet's voice and this unit's mechanic tag over the type's warn sound (SOUND-STORY
# section 3): the type says what kind of danger, the voice who, the tag which unit.
func _voice(tele: Node3D) -> void:
	tele.owner_voice = String(Roster.faction(faction)["voice"])
	tele.mechanic_tag = String(row.get("tag", ""))


func _end() -> void:
	if holds != null and holds.held(self):
		holds.release(self, "expired")
	_on_end()
	_clear_telegraph()
	phase = Phase.ROAM
	_t = 0.0
	_rest = rest_seconds


# --- Holds ----------------------------------------------------------------------------

func _catch(max_seconds := 0.0, shove := Vector3.ZERO, anchor = null) -> bool:
	if holds == null:
		return false
	var fresh: bool = not holds.held(self)
	var ok: bool = holds.catch(self, String(row["mechanic"]), row["breaks"], max_seconds, shove, anchor)
	if ok and fresh:
		caught += 1
	return ok


func _pull(accel: Vector3) -> bool:
	return holds != null and holds.pull(self, accel)


func _holding() -> bool:
	return holds != null and holds.held(self)


func _release(reason := "left") -> void:
	if holds != null:
		holds.release(self, reason)


# The real ball, not what the sight sees: a hold is tested against where the ball is.
func _real_ball() -> Vector3:
	return holds.player.ball_position() if holds != null else _ball()


func _player():
	return holds.player if holds != null else null


func _exit_tree() -> void:
	if holds != null and is_instance_valid(holds) and holds.held(self):
		holds.release(self, "source_gone")
	super._exit_tree()


# --- The crew -------------------------------------------------------------------------

# An animal crew in Fleet paint with one brass requisition tag (VISUAL-LANGUAGE section
# 11; every crew figure is an animal, primer ruling 13): a rust body, a head with two
# ears, and the tag on the chest. The tool a subclass builds is always bigger.
func _build_crew() -> void:
	radius = CREW_RADIUS
	half_height = CREW_HALF
	_crew = _add_capsule(CREW_RADIUS, CREW_HALF * 2.0, Palette.RUST)
	var head := SphereMesh.new()
	head.radius = HEAD_RADIUS
	head.height = HEAD_RADIUS * 2.0
	_accent(head, Palette.RUST.darkened(0.15), 0.0, Vector3(0.0, CREW_HALF + 0.2, 0.0), _crew)
	for side in [-1.0, 1.0]:
		var ear := CylinderMesh.new()
		ear.top_radius = 0.0
		ear.bottom_radius = 0.13
		ear.height = 0.34
		_accent(ear, Palette.CHARCOAL, 0.0, Vector3(side * 0.2, CREW_HALF + 0.55, 0.0), _crew)
	var tag := BoxMesh.new()
	tag.size = TAG_SIZE
	_accent(tag, Palette.BRASS, 0.8, Vector3(0.0, 0.3, CREW_RADIUS + 0.02), _crew)


func _tool_material(color := Palette.CHARCOAL, energy := 0.0) -> StandardMaterial3D:
	return Palette.solid(color, energy)


func _box(size: Vector3, color: Color, at: Vector3, energy := 0.0, parent: Node3D = self) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _accent(box, color, energy, at, parent)


func _cylinder(r: float, h: float, color: Color, at: Vector3, energy := 0.0, parent: Node3D = self) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = h
	return _accent(cyl, color, energy, at, parent)


func _facing(to_ball: Vector3) -> void:
	if to_ball.length() > 0.5:
		rotation.y = atan2(to_ball.x, to_ball.z)
