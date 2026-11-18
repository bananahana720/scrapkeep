extends RefCounted

const Tuning := preload("res://src/movement/tuning.gd")
const Palette := preload("res://src/core/palette.gd")
const Run := preload("res://src/core/run_state.gd")

# The reactor relic's driver (design-v3/wardens/reactor.md sections 3 and 4; unit KF2). warden.gd's
# per-kind hook loads this file for every park Warden of the reactor family (spec "harpoon_anchor":
# true and no "mount_driver"), so the authored boss arenas never meet it. The relic never moves on
# either mounting: mount_offset is zero, so anchor_velocity stays zero. Its mounting moves the water.
#
# - dam_face (stage 1, variant ""): every pulse opens the spillway gates and a water sheet
#   SHEET_WIDTH wide runs SHEET_RUN down the face from the relic for SHEET_SECONDS; the next charge
#   ends it at the latest. Once the bar has lost a quarter, each charge opens one half of it
#   (W1-67, _lane_for), drawn faint through the charge. The sheet is a ride (the kind sheet's open question, section 10: a ride
#   assist, as the chutes and the ramp flipper's ride are, through target.add_external_accel). A
#   ball inside the sheet that moves toward the relic is carried up a quarter-pipe profile from the
#   sheet's foot to the core's height, and its planar speed is held at its entry speed, so it
#   arrives at the core as fast as it came. Each ride publishes the ride fact ride_sheet on the
#   bus's world_fact, as the park's ride sensors do. A ball outside the sheet is never touched.
#   The face's downhill direction is the sheet's heading; on level ground it is the heading to the
#   ball at the first pulse, kept for the fight (a mounting row's "sheet_dir" names it outright).
# - flume (stage 2, variant meltdown): warden.gd's own _leave_slag lays the W01 lane. This driver
#   gives it the lane origin (lane_origin, KF2c): the pour channel (POUR_OFFSET from home, or the
#   row's "pour_offset"), so the lane is laid there from the first tick and the windup, strike and
#   recover facts and their geometry all read the one channel. The body never leaves home (KF2b:
#   moving it for the pour let a stagger opened on the landing tick strand it at the pour channel
#   and spike anchor_velocity). slag_hop is untouched. The core window is MELTDOWN_WINDOW times longer (warden.gd's
#   setup already does this). On the park, hung out of ram reach, the line bolts are the fight
#   (FlumePosture below, card FLUME-POSTURE).

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
# The dam ride's upward speed is capped at what carries the ball to the core's height plus this
# margin, under its own gravity: inside the core's contact reach, so the ride lifts the ball onto
# the core and never flings it over the dam (unit BS1). Only the mounted dam sheet is capped.
const RIDE_TOP_MARGIN := 2.0
# A face steeper than this (metres of rise per metre) gives the sheet its heading.
const FACE_SLOPE := 0.15
const POUR_OFFSET := Vector3(0.0, 0.0, -6.0)
const SHEET_COLOR := Palette.SANDSTONE
const SHEET_ALPHA := 0.55
const LANE_TELL_ALPHA := 0.2
const LANE_PAST_CORE := 2.0
# A grown ball breaks the mounted bar in sheet_ram_breaks sheet rams; a lighter one's ram pays
# its heft share of that to the power heft_curve, so a heft-1.0 ball needs 2.2 times the rams
# (7), the posture bands' "small takes at least twice grown" (section 7). The stage's own
# posture curve (2.0) asked 4.84 times (15 rams, about 90 s), past the arena allowance for any
# pilot (unit WT-PARK-BOT). A ball still holding its class through wear hysteresis rams at that
# class's heft, as the HUD reads it.
const MOUNTED_POSTURE := {"sheet_ram_breaks": 3, "heft_curve": 1.0}

class DamPosture extends "res://src/combat/boss_posture.gd":
	var mounted_warden: WeakRef
	func judge(hit: Dictionary) -> Dictionary:
		var result := super.judge(hit)
		var w = mounted_warden.get_ref()
		if w != null:
			w.mount_driver.judge_sheet_ram(w, self, hit, result)
		return result
	func apply(result: Dictionary, frame: int) -> void:
		if not result.get("sheet_ram", false):
			super.apply(result, frame)
			return
		posture = minf(FULL, posture + float(result["gain"]))
		idle = 0.0
		gain_in_frame = gain_in_frame + float(result["gain"]) if frame == gain_frame else float(result["gain"])
		gain_frame = frame
		var w = mounted_warden.get_ref()
		if w != null:
			w.mount_driver.pay_sheet(float(result["gain"]))
		if result.get("shatter", false):
			chunks = 0
			staggered = false
			stagger_left = 0.0
			shatter_frame = frame

# The mounted flume's line fight (card FLUME-POSTURE, rulings FL1 to FL3; reactor.md:80). Hung 12 m over
# the drum, the relic is out of ram reach, so the bolts a latched ball fires are the fight. A line bolt
# pays the stage's other_base (other_base_charging while the relic charges) times LINE_PAY, times its damage over the
# pilot's base weapon damage per second, times LINE_REFERENCE_WEAPON's over line_reference_damage(). So at the
# reference heft every pilot's base kit fills the bar at the same posture per second (Rivet's under FL1,
# 7.07 at a LINE_PAY of 1), and a part that raises damage or fire rate still raises it. Plating does not enter: the generic rule's
# punch-over-plating paid a 7 to 10 punch bolt about 0.06 against plating 110, and the bar drained
# between pulses (register row 747: never broken in 600 s). The pay is also scaled by the ball's heft
# over LINE_REFERENCE_HEFT to the stage's own posture curve, as a ram's heft-scaled punch is: with no ram
# in reach, heft is what keeps the posture bands' "small takes at least twice grown". The finisher's fixed
# seconds compress that ratio, so the dam's flatter heft_curve 1.0 is not enough here (measured small
# 78.6 s against grown 41.2 s, ratio 1.91; 1.25 gave a band ratio of 1.61). While the ball is engaged and
# latched the bar does not drain. A bolt from off the line keeps the generic rule, so the camper never
# breaks it.
class FlumePosture extends "res://src/combat/boss_posture.gd":
	var mounted_warden: WeakRef
	var line_held := false
	func judge(hit: Dictionary) -> Dictionary:
		var result := super.judge(hit)
		var w = mounted_warden.get_ref()
		if w != null and line_held and not staggered and not result.get("contact", false):
			w.mount_driver.judge_line_bolt(w, self, hit, result)
		return result

const Weapons := preload("res://src/combat/weapons.gd")
const ClassDef := preload("res://src/core/class_def.gd")
static var _line_reference := -1.0
# The second heft class's floor: a park skipper reaches stage 2 at heft 1.1 to 1.4.
const LINE_REFERENCE_HEFT := 1.5
# The pilot whose FL1 posture per second FL3 keeps: Rivet's rapid_laser, 7 x 12 = 84 damage per second.
const LINE_REFERENCE_WEAPON := "rapid_laser"
# The share of the stage's pay a line bolt keeps. 11 Nov 2026, wave 36: the weir deck's rims stopped
# catching the ball, and the same bots broke this Warden about a fifth sooner (grown median 15.8 to
# 12.8 s, under its 15 s floor). The pay came down so the fight is harder, not the deck worse (ruling
# cu). Measured medians, small and grown: 0.8 gave 27.0 and 19.4 s, 0.7 gave 33.1 and 22.4 s; 0.7 is the
# first that puts both at or over the fight before the deck fix (30.9 and 15.8 s).
# posture_bands_flume_test holds the fight's length.
const LINE_PAY := 0.7

var gates_opened := 0
var rides := 0
var sheet_left := 0.0
var sheet_dir := Vector3.ZERO
var riding := false
var entered_sheet_cycle := -1
# One sheet pays one ram: the gain a cycle's sheet has paid, so a second contact in the same
# sheet (the ball's boundary and core contacts on successive frames) only tops it up.
var paid_cycle := -1
var paid_gain := 0.0
# The open half of the sheet (W1-67): 0 the whole width, 1 the right half, -1 the left (right of
# sheet_dir, looking down the face), set at each charge by _lane_for.
var lane := 0

var _entry_speed := 0.0
var _camera_declared := false
var _sheet_view: MeshInstance3D


func mount_offset(_warden, _clock: float) -> Vector3:
	return Vector3.ZERO


func sheet_live() -> bool:
	return sheet_left > 0.0


# --- The hook ------------------------------------------------------------------------------

static func _is_dam(warden) -> bool:
	return warden.spec.get("park_landmark", false) and warden.family == "reactor" and warden.mounting == "dam_face"


# The dam fight asks the chase camera to keep the ball and the floor in view near this body, once on each change.
func _declare_fight(warden, engaged: bool) -> void:
	if engaged == _camera_declared or warden.fleet == null or warden.fleet.ctx.camera == null:
		return
	_camera_declared = engaged
	warden.fleet.ctx.camera.set_contact_subject(warden if engaged else null)


static func _is_flume(warden) -> bool:
	return warden.spec.get("park_landmark", false) and warden.family == "reactor" and warden.mounting == "flume"


func step(warden, delta: float) -> void:
	if _is_dam(warden):
		if not warden._posture is DamPosture:
			warden.replace_posture(DamPosture.new(warden.spec.get("posture", {})))
		var engaged: bool = warden.fleet != null and warden.fleet.ctx.flow.engaged() \
				and warden._in_play() and warden.hp > 0.0
		warden._posture.contact_drain_delay = delta if engaged else 0.0
		_declare_fight(warden, engaged)
		for child in warden.get_children():
			if child is CollisionShape3D:
				if not child.shape is SphereShape3D:
					var core := SphereShape3D.new()
					core.radius = warden.FAMILY_POINT_RADIUS
					child.shape = core
				child.global_position = warden.family_point_at()
	if _is_flume(warden):
		if not warden._posture is FlumePosture:
			warden.replace_posture(FlumePosture.new(warden.spec.get("posture", {})))
		var held: bool = warden.fleet != null and warden.fleet.ctx.flow.engaged() \
				and warden._in_play() and warden.hp > 0.0 and _line_on(warden)
		warden._posture.line_held = held
		warden._posture.contact_drain_delay = delta if held else 0.0
	# A charge a stagger cancelled leaves its faint lane behind: it goes with the charge.
	if sheet_left <= 0.0 and not warden._charging and is_instance_valid(_sheet_view):
		_close_sheet()
	if sheet_left > 0.0:
		sheet_left = maxf(0.0, sheet_left - delta)
		if sheet_left <= 0.0:
			_close_sheet()
		else:
			_ride(warden, delta)


# The dam's sheet ram breaks all four chunks at once (DamPosture.apply), so chunk_2 would land on the
# break's frame, behind the break's park quiet. Its fight phases read the bar's quarters instead: chunk_N
# when the bar first crosses N quarters (DECISIONS, mounted Wardens pulse chunk_N at posture quarters).
func phase_chunks_left(warden) -> int:
	if not warden._posture is DamPosture:
		return warden.chunks_left()
	var quarters := floori(warden._posture.posture / warden._posture.FULL * 4.0 + 1e-6)
	# A full bar that has not broken (a generic stagger) reads one chunk left; only the break reads none.
	return mini(warden.chunks_left(), maxi(1, 4 - quarters))


func judge_sheet_ram(warden, posture, hit: Dictionary, result: Dictionary) -> void:
	if not result.get("contact", false) or not sheet_live() \
			or entered_sheet_cycle != gates_opened:
		return
	var target = warden.target
	if target == null or not target.body().get_colliding_bodies().has(warden):
		return
	var heft: float = sheet_heft(warden, target.heft_of.call())
	var plating: float = hit["plating"]
	var grown_punch: float = float(hit["punch"]) / heft * Run.HEFT_CLASS_AT[2]
	var grown_ratio: float = grown_punch / plating if plating > 0.0 else posture.ordinary_ceiling()
	var ratio: float = float(hit["punch"]) / plating if plating > 0.0 else posture.ordinary_ceiling()
	var curve: float = MOUNTED_POSTURE["heft_curve"]
	var relative_gain: float = pow(clampf(ratio, posture.mult_min, posture.ordinary_ceiling()), curve) \
			/ pow(clampf(grown_ratio, posture.mult_min, posture.ordinary_ceiling()), curve)
	var gain: float = posture.FULL / float(MOUNTED_POSTURE["sheet_ram_breaks"]) * relative_gain
	if int(hit["frame"]) == posture.gain_frame:
		gain = maxf(0.0, gain - posture.gain_in_frame)
	elif paid_cycle == gates_opened:
		gain = maxf(0.0, gain - paid_gain)
	result["sheet_ram"] = true
	result["gain"] = gain
	result["shatter"] = posture.posture + gain >= posture.FULL or is_equal_approx(posture.posture + gain, posture.FULL)
	result["crack"] = false
	if result["shatter"]:
		result["dealt"] = float(hit["hp"])
		result["part"] = warden.family_point()


func pay_sheet(gain: float) -> void:
	paid_gain = paid_gain + gain if paid_cycle == gates_opened else gain
	paid_cycle = gates_opened


# The heft a sheet ram is judged at: the ball's own, or the floor of the class it still holds.
func sheet_heft(warden, heft: float) -> float:
	var fleet = warden.get("fleet")
	var run = fleet.ctx.run if fleet != null and fleet.ctx != null else null
	if run == null:
		return heft
	return maxf(heft, float(Run.HEFT_CLASS_AT[run.heft_class() - 1]))


func on_charge(warden, seconds: float) -> void:
	if _is_dam(warden):
		warden._charge_time = maxf(0.0, warden._pulse_clock - (warden.cycle_now() - seconds))
	if sheet_live():
		sheet_left = 0.0
		_close_sheet()
	if _is_dam(warden):
		lane = _lane_for(warden)
		if lane != 0:
			if sheet_dir == Vector3.ZERO:
				sheet_dir = _face_heading(warden)
			_show_sheet(warden, LANE_TELL_ALPHA)


# W1-67: the dam's sheet runs full width until the bar has lost a quarter; from then on each charge
# opens one of its two halves, drawn faint across the charge so the side is read before the gates
# open. The side is drawn per chunk from the run seed, so the second half of the fight asks the
# player to read which side, and a run cannot learn one fixed answer.
func _lane_for(warden) -> int:
	var lost: int = warden.chunks_lost()
	if lost <= 0:
		return 0
	var fleet = warden.get("fleet")
	var run = fleet.ctx.run if fleet != null and fleet.ctx != null else null
	var run_seed: int = int(run.run_seed) if run != null else 0
	return 1 if posmod(hash([run_seed, warden.stage, lost]), 2) == 0 else -1


# Where across the sheet a point lies: metres to the right of its centre line (sheet_dir x up).
func _across(warden, point: Vector3) -> float:
	var flat := Vector3(point.x - warden.home.x, 0.0, point.z - warden.home.z)
	return flat.dot(sheet_dir.cross(Vector3.UP))


# The open lane's centre, metres right of the sheet's centre line: 0 for the full sheet. A lane is
# its half of the sheet plus LANE_PAST_CORE over the centre line, so a ride that drifts across the
# core's line on the way in keeps its water.
func lane_offset() -> float:
	return float(lane) * (SHEET_WIDTH * 0.5 - LANE_PAST_CORE) * 0.5


func lane_width() -> float:
	return SHEET_WIDTH if lane == 0 else SHEET_WIDTH * 0.5 + LANE_PAST_CORE


# The dam's pulse never ratchets tighter than its sheet runs (warden.gd cycle_now): the next charge
# closes the sheet, so a shorter rest would cut the ride, the fight's one way in.
func rest_floor(warden) -> float:
	return SHEET_SECONDS if _is_dam(warden) else 0.0


func on_pulse(warden, _lifted: bool) -> void:
	if warden.mounting == "dam_face":
		_open_sheet(warden)


# --- dam_face: the spillway sheet ----------------------------------------------------------

func _open_sheet(warden) -> void:
	if sheet_dir == Vector3.ZERO:
		sheet_dir = _face_heading(warden)
	gates_opened += 1
	sheet_left = SHEET_SECONDS
	riding = false
	_show_sheet(warden)


# The killing ram always lands with the sheet open, and a freed Warden no longer steps the
# sheet's timer, so the slab (drawn under the world root, not the Warden) closes here.
func on_exit(_warden) -> void:
	sheet_left = 0.0
	_close_sheet()


func _close_sheet() -> void:
	riding = false
	if is_instance_valid(_sheet_view):
		# Hidden and renamed now, so a sheet shown this frame (the pulse replacing the lane tell) is named ReactorSheet,
		# not @MeshInstance3D@. Removing it from the tree here fails when the warden is leaving the tree.
		_sheet_view.visible = false
		_sheet_view.name = "ReactorSheetGone"
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
	var across := absf(_across(warden, point) - lane_offset())
	if along < 0.0 or along > SHEET_RUN or across > lane_width() * 0.5:
		return false
	return point.y <= _profile(warden, point, along) + SHEET_DEPTH


# The ride's height for a ball `along` metres from the relic: a quarter pipe from the ground at
# the sheet's foot (flat) up to the core's height at SHEET_TOP (steep).
func _profile(warden, point: Vector3, along: float) -> float:
	var ground: float = warden.terrain.height(point.x, point.z) + Tuning.RADIUS if warden.terrain != null else point.y
	var core: float = warden.family_point_at().y
	var top := 0.0 if _is_dam(warden) else SHEET_TOP
	var t := clampf((along - top) / (SHEET_RUN - top), 0.0, 1.0)
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
	var mounted: bool = _is_dam(warden)
	if mounted and in_sheet(warden, ball) and closing >= RIDE_MIN_SPEED and ball.y < core:
		entered_sheet_cycle = gates_opened
	if mounted:
		var point: Vector3 = warden.family_point_at()
		var touching: bool = in_sheet(warden, ball) and closing >= RIDE_MIN_SPEED \
				and ball.distance_to(point) <= warden.FAMILY_POINT_RADIUS + Tuning.RADIUS
		if touching:
			riding = false
			return
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
	# Follow the sheet's climb rate and height. The mounted ride hands its velocity to the
	# next solver step; an inverse-delta force here feeds back a stale body velocity.
	var top := 0.0 if mounted else SHEET_TOP
	var t := clampf((along - top) / (SHEET_RUN - top), 0.0, 1.0)
	var rise := 0.0
	if along > top:
		var base: float = warden.terrain.height(ball.x, ball.z) + Tuning.RADIUS if warden.terrain != null else ball.y
		rise = maxf(0.0, core - base) * 2.0 * (1.0 - t) / (SHEET_RUN - top) * closing
	var gravity: float = target.tuning.f("gravity") if "tuning" in target and target.tuning != null else 9.8
	var lift_cap := sqrt(2.0 * gravity * maxf(0.0, core + RIDE_TOP_MARGIN - ball.y)) if mounted else INF
	var want_vy := minf(rise + RIDE_GAIN * (height - ball.y), lift_cap)
	var up := (want_vy - v.y) / delta + gravity
	# The water keeps the planar speed the ball came in with: it adds back what rolling lost.
	var push := Vector3.ZERO
	var speed := planar.length()
	if speed > 0.01 and speed < _entry_speed:
		push = planar / speed * (_entry_speed - speed) / delta
	if mounted and target.has_method("body") and target.body().has_method("set_velocity_now"):
		var held: Vector3 = planar.normalized() * maxf(speed, _entry_speed)
		target.body().set_velocity_now(Vector3(held.x, maxf(v.y, want_vy), held.z))
	else:
		target.add_external_accel(Vector3(push.x, maxf(up, 0.0), push.z))


# A plain water slab over the footprint (its open lane), in the ride colour; collides with nothing.
# The charge draws the lane faint (LANE_TELL_ALPHA) and the pulse replaces it with the water.
func _show_sheet(warden, alpha := SHEET_ALPHA) -> void:
	_close_sheet()
	var root = warden.world_root
	if root == null or not is_instance_valid(root):
		return
	var view := MeshInstance3D.new()
	view.name = "ReactorSheet"
	var box := BoxMesh.new()
	box.size = Vector3(lane_width(), 0.3, SHEET_RUN - SHEET_TOP)
	view.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(SHEET_COLOR, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(view)
	var mid: Vector3 = warden.home + sheet_dir * (SHEET_TOP + (SHEET_RUN - SHEET_TOP) * 0.5) \
			+ sheet_dir.cross(Vector3.UP) * lane_offset()
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


# warden.gd's _leave_slag asks for this: every slag lane is laid from the pour channel.
func lane_origin(warden) -> Vector3:
	return pour_point(warden)


# --- flume: the line fight -------------------------------------------------------------------

# The damage a line bolt is paid against: the mean of the six pilots' base weapon damage.
static func line_reference_damage() -> float:
	if _line_reference < 0.0:
		var total := 0.0
		var pilots: Array = ClassDef.all()
		for def in pilots:
			total += float(Weapons.BASE[def.weapon_id]["damage"])
		_line_reference = total / pilots.size()
	return _line_reference


# A weapon's base damage per second, from its Weapons.BASE row. A pressure weapon (Tally's reader)
# fires at its refill rate, one charge per Weapons.PRESSURE_ROLL_S, not its row rate: time never
# refills pressure, so latched she measured 0.5 shots a second against the row's 2.5 (ruling BL1).
static func base_dps(weapon: String) -> float:
	var row: Dictionary = Weapons.BASE[weapon]
	if preload("res://src/core/ability_state.gd").ABILITIES.get(weapon, {}).has("pressure"):
		return float(row["damage"]) / Weapons.PRESSURE_ROLL_S
	return float(row["damage"]) * float(row["rate"])


# The objective plate's reading of this mounting (ui/hud.gd, core/objectives.gd): which road
# leads to the core.
func plate_reading(warden) -> Dictionary:
	if _is_dam(warden):
		return {"mount": "dam_face"}
	if _is_flume(warden):
		return {"mount": "flume"}
	return {}


# Where the fight sends the player now, for the HUD to mark (ui/edge_markers.gd), each {at, what}
# with what naming the next move there (objectives.gd TAGS). On the dam, the foot of the water
# sheet once the first pulse has set its heading: ride it while it runs, and between pulses the
# water is coming there. On the flume, the relic itself, by the step of the line fight that comes
# next: latch on, shoot from the line, the open core.
func plate_targets(warden) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _is_dam(warden):
		if sheet_dir != Vector3.ZERO:
			out.append({"at": _sheet_foot(warden), "what": "sheet" if sheet_live() else "sheet_soon"})
	elif _is_flume(warden):
		var what := "core" if warden.staggered() else "shoot" if _line_on(warden) else "latch"
		out.append({"at": warden.global_position, "what": what})
	return out


# The sheet's foot on the ground: SHEET_RUN down its heading from the relic, in the open lane.
func _sheet_foot(warden) -> Vector3:
	var at: Vector3 = warden.home + sheet_dir * SHEET_RUN + sheet_dir.cross(Vector3.UP) * lane_offset()
	if warden.terrain != null:
		at.y = warden.terrain.height(at.x, at.z)
	return at


# Whether the ball's line is bitten into this Warden.
func _line_on(warden) -> bool:
	var target = warden.target
	var kit = target.get("kit") if target != null else null
	return kit != null and kit.hooked and kit.on_body and kit.anchor_body == warden


func judge_line_bolt(warden, posture, hit: Dictionary, result: Dictionary) -> void:
	var pay: float = posture.other_base_charging if bool(hit.get("charging", false)) else posture.other_base
	var heft := LINE_REFERENCE_HEFT
	var target = warden.target
	if target != null and target.has_method("heft"):
		heft = sheet_heft(warden, target.heft())
	var share := pow(heft / LINE_REFERENCE_HEFT, posture.curve)
	var reference_dps := base_dps(LINE_REFERENCE_WEAPON)
	var fleet = warden.get("fleet")
	var run = fleet.ctx.run if fleet != null and fleet.ctx != null else null
	var def = run.class_def if run != null else null
	# Without a pilot the bolt is paid as the reference pilot's.
	var pilot_dps := base_dps(def.weapon_id) if def != null and Weapons.BASE.has(def.weapon_id) else reference_dps
	result["gain"] = pay * LINE_PAY * float(hit.get("punch", 0.0)) / pilot_dps * reference_dps / line_reference_damage() * share
	result["glance"] = false
	result["full"] = true
