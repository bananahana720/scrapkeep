extends RefCounted

const Tuning := preload("res://src/movement/tuning.gd")
const Palette := preload("res://src/core/palette.gd")

# The reactor relic's driver (design-v3/wardens/reactor.md sections 3 and 4; unit KF2). warden.gd's
# per-kind hook loads this file for every park Warden of the reactor family (spec "harpoon_anchor":
# true and no "mount_driver"), so the authored boss arenas never meet it. The relic never moves on
# either mounting: mount_offset is zero, so anchor_velocity stays zero. Its mounting moves the water.
#
# - dam_face (stage 1, variant ""): every pulse opens the spillway gates and a water sheet
#   SHEET_WIDTH wide runs SHEET_RUN down the face from the relic for SHEET_SECONDS; the next charge
#   ends it at the latest. The sheet is a ride (the kind sheet's open question, section 10: a ride
#   assist, as the chutes and the ramp flipper's ride are, through target.add_external_accel). A
#   ball inside the sheet that moves toward the relic is carried up a quarter-pipe profile from the
#   sheet's foot to the core's height, and its planar speed is held at its entry speed, so it
#   arrives at the core as fast as it came. Each ride publishes the ride fact ride_sheet on the
#   bus's world_fact, as the park's ride sensors do. A ball outside the sheet is never touched.
#   The face's downhill direction is the sheet's heading; on level ground it is the heading to the
#   ball at the first pulse, kept for the fight (a mounting row's "sheet_dir" names it outright).
# - flume (stage 2, variant meltdown): warden.gd's own _leave_slag lays the W01 lane. This driver
#   makes every lane start at the pour channel (POUR_OFFSET from home, or the row's "pour_offset"):
#   on the tick the charge will land, it stands the relic's origin at the pour channel for that
#   one pulse and puts it back in on_pulse, so the lane is laid, published and burned from the one
#   geometry, and the body is home again before anything else reads it. slag_hop is untouched.
#   The core window is MELTDOWN_WINDOW times longer (warden.gd's setup already does this).

const SHEET_SECONDS := 3.0
const SHEET_WIDTH := 24.0
# How far the sheet's foot lies from the relic, flat, and how far above its profile the water's
# volume reaches (a ball skimming the surface still rides).
const SHEET_RUN := 30.0
const SHEET_DEPTH := 3.0
# Where the profile tops out, flat from the relic: the ride lets go at the core's height this far
# out, and the ball's arc drops it onto the body at the speed it rode in with (a lip, not a road
# over the top: carried to the core itself, a ball sails over the collider and rams nothing).
const SHEET_TOP := 14.0
# A ball must be closing on the relic at least this fast to ride; slower, the water lets it be.
const RIDE_MIN_SPEED := 3.0
# How hard the ride pulls the ball onto its profile, per second of height error.
const RIDE_GAIN := 8.0
# A face steeper than this (metres of rise per metre) gives the sheet its heading.
const FACE_SLOPE := 0.15
const POUR_OFFSET := Vector3(0.0, 0.0, -6.0)
const SHEET_COLOR := Palette.SANDSTONE

var gates_opened := 0
var rides := 0
var sheet_left := 0.0
var sheet_dir := Vector3.ZERO
var riding := false

var _entry_speed := 0.0
# The charge's clock, summed as warden.gd sums _charge_time, so both reach its length on one tick.
var _charge_clock := -1.0
var _charge_len := 0.0
var _poured := false
var _sheet_view: MeshInstance3D


func mount_offset(_warden, _clock: float) -> Vector3:
	return Vector3.ZERO


func sheet_live() -> bool:
	return sheet_left > 0.0


# --- The hook ------------------------------------------------------------------------------

func step(warden, delta: float) -> void:
	if _poured:
		_pour_back(warden)
	if sheet_left > 0.0:
		sheet_left = maxf(0.0, sheet_left - delta)
		if sheet_left <= 0.0:
			_close_sheet()
		else:
			_ride(warden, delta)
	if _charge_clock >= 0.0 and warden.variant == "meltdown" and not warden.staggered():
		_charge_clock += delta
		# The charge lands on this tick's pulse step (warden.gd _step_pulse adds the same delta).
		if _charge_clock >= _charge_len:
			_pour(warden)


func on_charge(_warden, seconds: float) -> void:
	_charge_clock = 0.0
	_charge_len = seconds
	if sheet_live():
		sheet_left = 0.0
		_close_sheet()


func on_pulse(warden, _lifted: bool) -> void:
	_charge_clock = -1.0
	if _poured:
		_pour_back(warden)
	if warden.mounting == "dam_face":
		_open_sheet(warden)


func on_stagger(_warden, open: bool) -> void:
	if open:
		_charge_clock = -1.0


# --- dam_face: the spillway sheet ----------------------------------------------------------

func _open_sheet(warden) -> void:
	if sheet_dir == Vector3.ZERO:
		sheet_dir = _face_heading(warden)
	gates_opened += 1
	sheet_left = SHEET_SECONDS
	riding = false
	_show_sheet(warden)


func _close_sheet() -> void:
	riding = false
	if is_instance_valid(_sheet_view):
		_sheet_view.queue_free()
	_sheet_view = null


# Downhill on the face, else the row's heading, else toward the ball.
func _face_heading(warden) -> Vector3:
	var named = warden.spec.get("sheet_dir") if "spec" in warden else null
	if named is Array and named.size() == 3:
		named = Vector3(float(named[0]), 0.0, float(named[2]))
	if named is Vector3 and Vector2(named.x, named.z).length() > 0.01:
		return Vector3(named.x, 0.0, named.z).normalized()
	var home: Vector3 = warden.home
	var terrain = warden.terrain
	if terrain != null:
		var probe := 6.0
		var gx: float = terrain.height(home.x + probe, home.z) - terrain.height(home.x - probe, home.z)
		var gz: float = terrain.height(home.x, home.z + probe) - terrain.height(home.x, home.z - probe)
		var grad := Vector3(gx, 0.0, gz) / (2.0 * probe)
		if grad.length() >= FACE_SLOPE:
			return -grad.normalized()
	var out: Vector3 = warden.flat_to_ball()
	return out.normalized() if out.length() > 0.1 else Vector3.FORWARD


# The sheet's footprint: along its heading from the relic's edge to its foot, half its width
# either side, and no higher than SHEET_DEPTH over the ride's profile.
func in_sheet(warden, point: Vector3) -> bool:
	if not sheet_live() or sheet_dir == Vector3.ZERO:
		return false
	var flat := Vector3(point.x - warden.home.x, 0.0, point.z - warden.home.z)
	var along := flat.dot(sheet_dir)
	var across := absf(flat.dot(sheet_dir.cross(Vector3.UP)))
	if along < 0.0 or along > SHEET_RUN or across > SHEET_WIDTH * 0.5:
		return false
	return point.y <= _profile(warden, point, along) + SHEET_DEPTH


# The ride's height for a ball `along` metres from the relic: a quarter pipe from the ground at
# the sheet's foot (flat) up to the core's height at SHEET_TOP (steep).
func _profile(warden, point: Vector3, along: float) -> float:
	var ground: float = warden.terrain.height(point.x, point.z) + Tuning.RADIUS if warden.terrain != null else point.y
	var core: float = warden.family_point_at().y
	var t := clampf((along - SHEET_TOP) / (SHEET_RUN - SHEET_TOP), 0.0, 1.0)
	return ground + maxf(0.0, core - ground) * (1.0 - t) * (1.0 - t)


func _ride(warden, delta: float) -> void:
	var target = warden.target
	if target == null or delta <= 0.0 or not target.has_method("add_external_accel"):
		riding = false
		return
	var ball: Vector3 = target.ball_position()
	var v: Vector3 = target.body().linear_velocity if target.has_method("body") else target.state.velocity
	var planar := Vector3(v.x, 0.0, v.z)
	var closing := -planar.dot(sheet_dir)
	var core: float = warden.family_point_at().y
	if not in_sheet(warden, ball) or closing < RIDE_MIN_SPEED or ball.y >= core:
		riding = false
		return
	if not riding:
		riding = true
		rides += 1
		_entry_speed = planar.length()
		var fleet = warden.fleet
		if fleet != null:
			fleet.events().world_fact.emit("ride_sheet", ball)
	var flat := Vector3(ball.x - warden.home.x, 0.0, ball.z - warden.home.z)
	var along := flat.dot(sheet_dir)
	var height := _profile(warden, ball, along)
	# The profile's climb rate at this closing speed, plus a pull onto it; never a push down
	# (gravity does that), so a ball that jumps off the water keeps its own arc.
	var t := clampf((along - SHEET_TOP) / (SHEET_RUN - SHEET_TOP), 0.0, 1.0)
	var rise := 0.0
	if along > SHEET_TOP:
		var base: float = warden.terrain.height(ball.x, ball.z) + Tuning.RADIUS if warden.terrain != null else ball.y
		rise = maxf(0.0, core - base) * 2.0 * (1.0 - t) / (SHEET_RUN - SHEET_TOP) * closing
	var want_vy := rise + RIDE_GAIN * (height - ball.y)
	var gravity: float = target.tuning.f("gravity") if "tuning" in target and target.tuning != null else 9.8
	var up := (want_vy - v.y) / delta + gravity
	# The water keeps the planar speed the ball came in with: it adds back what rolling lost.
	var push := Vector3.ZERO
	var speed := planar.length()
	if speed > 0.01 and speed < _entry_speed:
		push = planar / speed * (_entry_speed - speed) / delta
	target.add_external_accel(Vector3(push.x, maxf(up, 0.0), push.z))


# A plain water slab over the footprint, in the ride colour; collides with nothing.
func _show_sheet(warden) -> void:
	_close_sheet()
	var root = warden.world_root
	if root == null or not is_instance_valid(root):
		return
	var view := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(SHEET_WIDTH, 0.3, SHEET_RUN - SHEET_TOP)
	view.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(SHEET_COLOR, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(view)
	var mid: Vector3 = warden.home + sheet_dir * (SHEET_TOP + (SHEET_RUN - SHEET_TOP) * 0.5)
	var ground: float = warden.terrain.height(mid.x, mid.z) if warden.terrain != null else warden.home.y
	view.global_transform = Transform3D(Basis.looking_at(-sheet_dir, Vector3.UP), Vector3(mid.x, ground + 0.2, mid.z))
	_sheet_view = view


# --- flume: the pour channel -----------------------------------------------------------------

# Where every slag lane starts: the pour channel, on the ground beside the relic.
func pour_point(warden) -> Vector3:
	var offset := POUR_OFFSET
	var named = warden.spec.get("pour_offset") if "spec" in warden else null
	if named is Array and named.size() == 3:
		offset = Vector3(float(named[0]), float(named[1]), float(named[2]))
	elif named is Vector3:
		offset = named
	return warden.home + offset


func _pour(warden) -> void:
	_charge_clock = -1.0
	_poured = true
	warden.global_position = pour_point(warden)


func _pour_back(warden) -> void:
	_poured = false
	warden.global_position = warden.home
