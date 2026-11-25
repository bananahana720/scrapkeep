extends "res://src/combat/enemy.gd"

const TelegraphRecord := preload("res://src/combat/telegraph_record.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const PackPressure := preload("res://src/combat/pack_pressure.gd")

# The chaser runs you down and lunges. The lunge is committed: at wind-up it lays a
# lane on the ground from where it stands toward where you are, and only that lane
# can hurt you, only while it is lunging down it. Roll off the lane, jump it, or hit
# the chaser hard enough during the wind-up to break it (a knock at INTERRUPT or more
# cancels the lunge and its lane together). Touching a chaser that is not lunging
# costs nothing but the bump. A chaser ready to lunge asks the attacker budget
# (attack_budget.gd) for a slot first, as every counter does, and keeps chasing until it
# gets one.

const SPEED := 4.8
# No dial runs a chaser this fast or faster: under the ball's 14 m/s cruise (movement/tuning.gd), so a ball
# that keeps rolling is never caught by running (ruling cu; chaser_speed_test holds the two numbers apart).
const SPEED_CEILING := 12.0
# A chaser runs at SPEED for its first ENTRY_GRACE_S alive, then at its stage's pace. A pocket's crew spawns as the
# ball enters, and an idle entry stays safe for its first two seconds (pocket_entry_test) however fast the stage runs.
const ENTRY_GRACE_S := 2.0
const LUNGE_RANGE := 10.0
const WINDUP := 0.6
const LUNGE_TIME := 0.34
const LUNGE_LENGTH := 11.0
const LUNGE_WIDTH := 2.8
const RECOVER := TelegraphRecord.RECOVERY
const REST := 0.8
const DAMAGE := 9.0
const SHOVE := 6.0
const INTERRUPT := 10.0
# 60, so a heft-1 ram at 20 m/s (punch 40) bounces off and from heft 1.5 it crushes:
# the spec's Katamari threshold, where fodder that used to bounce you gets rolled up.
const HP := 60.0
const SCRAP := 3
const ACCENT := Color("ffb070")

# The wind-up rears the wedge up on its planted claws: nose raised, body lifted and drawn back.
# Head-on a small pitch hides in the silhouette, so the rear-up is large enough to show from 10 m.
const REAR_SHIFT := Vector3(0.0, 0.3, 0.7)
const REAR_PITCH := 42.0

enum State { CHASE, WINDUP, LUNGE, RECOVER, CALL }

# Pack pressure (pack_pressure.gd, world 1 experiments; {} without --pack-pressure): "lead" 0 to 1 of the
# ball's predicted roll this chaser steers at and lays its lane toward, "rest" scales REST, "flanker" runs
# ahead of the ball's line, calls, and lunges across it.
var pressure := {}
# A flanker's call: it sounds PRESSURE_CUE_S before the wind-up, then the lane is committed as ever.
signal pressure_cue(cue: String, at: Vector3, seconds_until: float)
const LUNGE_SPEED := LUNGE_LENGTH / LUNGE_TIME
# A flanker heads for the ball's line this far ahead (seconds) and this far to its own side (m), and calls
# once the ball's next FLANK_CALL_S of roll comes within LUNGE_RANGE.
const FLANK_AHEAD_S := 1.6
const FLANK_SIDE := 5.0
const FLANK_CALL_S := 1.1

var state := State.CHASE
var lunges := 0
# This chaser's run speed (m/s): SPEED unless its spawn handed it the stage's (spec "run_speed", stage_speed()).
var run_speed := SPEED
var _age := 0.0

var _clock := 0.0
var _rest := 0.0
var _landed := false
var _mesh: Node3D
# Test seam: only the attack pose is disabled; facing and physics keep running.
var windup_pose_enabled := true
var _pose_parts: Dictionary = {}
var _parts_off_rest := false
# The body cues (LEGIBILITY section 6): while the lunge can still be broken the back wears the
# will_break state row, and a broken wind-up plays the interrupted row. Colour, motion and
# glyph shape come from STATE_ROWS; only the body paint's emission and a reaction move. Test
# seam: a cue disabled here leaves the pose, timings and AI untouched.
const INTERRUPT_SHOWN := 0.9
var body_cue_enabled := true
var _interrupted_left := 0.0
var _cue_clock := 0.0
var _cue_painted := false


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	_setup_common(target_ref, terrain_ref, root_ref, live_ref, spec_ref)
	kind = "chaser"
	_set_health(HP * threat)
	scrap_value = SCRAP
	weight = 1.0
	radius = 1.0
	half_height = 1.5
	pressure = spec_ref.get("pressure", {})
	run_speed = clampf(float(spec_ref.get("run_speed", SPEED)), SPEED, SPEED_CEILING)
	# _add_capsule still lays the collider and the flashing material; its capsule mesh is
	# replaced by the C10 wedge (enemy_chaser.glb): plough wedge, shoulder shield, raked fin
	# and braced haunches, with the lit visor as the glb's brass surface.
	_add_capsule(radius, half_height * 2.0, Palette.RUST).free()
	_mesh = Node3D.new()
	_mesh.name = "ChaserBody"
	_visual_parent().add_child(_mesh)
	# The glb is read once; every chaser shares its mesh and carries only its own flashing
	# body material as a surface override, so a spawn costs a few nodes, not a scene load.
	for part in _parts():
		var mi := MeshInstance3D.new()
		mi.name = part.name
		mi.mesh = part.mesh
		mi.transform = part.xform
		_mesh.add_child(mi)
		_pose_parts[part.name] = {"node": mi, "rest": part.xform}
		if part.body >= 0:
			mi.set_surface_override_material(part.body, _material)


static var _warned_asset := false
static var _shared: Array = []


static func _parts() -> Array:
	if not _shared.is_empty():
		return _shared
	var scene := (load(ModelVariants.path("res://assets/models/world_one/enemy_chaser.glb")) as PackedScene).instantiate()
	var charcoal := Palette.solid(Palette.CHARCOAL)
	var visor := Palette.solid(ACCENT, 3.0)
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh: Mesh = mi.mesh.duplicate()
		var body := -1
		for i in mesh.get_surface_count():
			var surface_material := mesh.surface_get_material(i)
			if surface_material == null and not _warned_asset:
				_warned_asset = true
				push_warning("chaser: surface has no material; using default finish")
			var slot := surface_material.resource_name if surface_material != null else ""
			if slot == "fleet_paint":
				body = i
			mesh.surface_set_material(i, visor if slot == "requisition_tag" else charcoal)
		_shared.append({"name": String(mi.name), "mesh": mesh, "xform": mi.transform, "body": body})
	scene.free()
	return _shared


# What a chaser spawned on `stage` runs at (ChallengeDials mobs.chaser_speed_by_stage, m/s; 0 keeps SPEED):
# never slower than SPEED, never as fast as SPEED_CEILING. Combat hands it to the spawn as spec "run_speed".
static func stage_speed(stage: int) -> float:
	var dial := ChallengeDials.by_stage_or("mobs.chaser_speed_by_stage", stage, 0.0)
	return clampf(dial, SPEED, SPEED_CEILING) if dial > 0.0 else SPEED


# This tick's run speed: SPEED through the entry grace, run_speed after it.
func _pace() -> float:
	return SPEED if _age < ENTRY_GRACE_S else run_speed


func state_name() -> String:
	return ["chase", "windup", "lunge", "recover", "call"][state]


func _physics_process(delta: float) -> void:
	_update_flash(delta)
	if not _in_play() or target == null:
		_cue_step(delta)
		_move(delta, Vector3.ZERO)
		return
	_cue_advance(delta)
	_clock += delta
	_age += delta
	_rest = maxf(0.0, _rest - delta)
	var to_ball := _flat_to_ball()
	match state:
		State.CHASE:
			var lead := PackPressure.lead_now(pressure, target)
			if pressure.get("flanker", false):
				_flank(delta, to_ball)
			elif lead > 0.0:
				_lead_chase(delta, to_ball, lead)
			else:
				var desired := Vector3.ZERO
				var reach := radius + 1.4
				var ball_sq := to_ball.length_squared()
				if ball_sq > reach * reach:
					desired = to_ball.normalized() * _pace()
				_move(delta, desired)
				if _rest <= 0.0 and ball_sq < LUNGE_RANGE * LUNGE_RANGE and is_on_floor() and _knocked_speed() < 1.0:
					if AttackBudget.ask(self):
						_begin_windup(to_ball)
				else:
					AttackBudget.withdraw(self)
		State.CALL:
			_move(delta, _toward(_flat(_flank_point() - global_position)))
			if _knocked_speed() >= INTERRUPT:
				_end_attack(State.RECOVER)
			elif _clock >= PackPressure.PRESSURE_CUE_S:
				# Called but not ready (in the air, still sliding off a knock): the call is spent, no lane.
				if is_on_floor() and _knocked_speed() < 1.0:
					_begin_windup(_led_aim(1.0))
				else:
					_end_attack(State.RECOVER)
		State.WINDUP:
			_move(delta, Vector3.ZERO)
			var lane := telegraph()
			if lane != null:
				lane.set_progress(_clock / WINDUP)
			if _knocked_speed() >= INTERRUPT or lane == null:
				if _knocked_speed() >= INTERRUPT and lane != null:
					_show_interrupted()
				_end_attack(State.RECOVER)
			elif _clock >= WINDUP:
				state = State.LUNGE
				_clock = 0.0
		State.LUNGE:
			var lane := telegraph()
			if lane == null:
				_end_attack(State.RECOVER)
				_paint_cue()
				return
			_move(delta, lane.dir * LUNGE_LENGTH / LUNGE_TIME)
			var along: float = (global_position - lane.center).dot(lane.dir)
			lane.run_body(along, hit_reach())
			_check_hit(lane)
			if _clock >= LUNGE_TIME or along >= lane.length:
				_end_attack(State.RECOVER)
		State.RECOVER:
			_move(delta, Vector3.ZERO)
			if _clock >= RECOVER:
				state = State.CHASE
				_clock = 0.0
	_pose()
	_paint_cue()


# Lead: steer at the earliest point of the ball's predicted roll this chaser can reach lunge range of,
# and wind up when the lane's led end is in range. The lane is still committed at wind-up and only it hurts.
func _lead_chase(delta: float, to_ball: Vector3, lead: float) -> void:
	_move(delta, _toward(_intercept(lead)))
	var aim := _led_aim(lead)
	if _rest <= 0.0 and aim.length() < LUNGE_RANGE and is_on_floor() and _knocked_speed() < 1.0:
		if AttackBudget.ask(self):
			_begin_windup(aim)
	else:
		AttackBudget.withdraw(self)


# Flank: run for a point beside the ball's line ahead of it, then call and lunge across the line.
func _flank(delta: float, to_ball: Vector3) -> void:
	_move(delta, _toward(_flat(_flank_point() - global_position)))
	var ahead := _flat(PackPressure.predict(target, FLANK_CALL_S) - global_position)
	var coming: bool = target.planar_velocity().dot(-to_ball) > 0.0
	if _rest <= 0.0 and ahead.length() < LUNGE_RANGE and coming and is_on_floor() and _knocked_speed() < 1.0:
		if AttackBudget.ask(self):
			state = State.CALL
			_clock = 0.0
			pressure_cue.emit("flank_call", global_position, PackPressure.PRESSURE_CUE_S + WINDUP)
	else:
		AttackBudget.withdraw(self)


func _flank_point() -> Vector3:
	var ahead := PackPressure.predict(target, FLANK_AHEAD_S)
	var v: Vector3 = target.planar_velocity()
	if v.length() < 1.0:
		return ahead
	var side := Vector3(-v.z, 0.0, v.x).normalized()
	if side.dot(global_position - ahead) < 0.0:
		side = -side
	return ahead + side * FLANK_SIDE


# Flat offset from this chaser to the ball's predicted roll at the time a lane laid now would land:
# the wind-up plus the lunge's travel, iterated twice. lead blends the ball's present spot (0) and that point (1).
func _led_aim(lead: float) -> Vector3:
	var now := _ball()
	var t := WINDUP + _flat(now - global_position).length() / LUNGE_SPEED
	var at := PackPressure.predict(target, t)
	t = WINDUP + _flat(at - global_position).length() / LUNGE_SPEED
	at = PackPressure.predict(target, t)
	return _flat(now.lerp(at, lead) - global_position)


# The earliest point of the ball's predicted roll (within MAX_LEAD_S) this chaser can get within lunge
# range of at its run speed; the farthest look when none.
func _intercept(lead: float) -> Vector3:
	var steps := 10
	var best := PackPressure.predict(target, PackPressure.MAX_LEAD_S * lead)
	for i in range(steps + 1):
		var t := PackPressure.MAX_LEAD_S * lead * float(i) / steps
		var at := PackPressure.predict(target, t)
		if _flat(at - global_position).length() - _pace() * t <= LUNGE_RANGE * 0.8:
			best = at
			break
	return _flat(best - global_position)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _toward(offset: Vector3) -> Vector3:
	return offset.normalized() * _pace() if offset.length() > radius + 1.4 else Vector3.ZERO


func _begin_windup(to_ball: Vector3) -> void:
	state = State.WINDUP
	_clock = 0.0
	_landed = false
	_commit_lane(Threat.Type.LANE, global_position, to_ball, LUNGE_LENGTH, LUNGE_WIDTH).run_body(0.0, hit_reach())


# How close the body must come to the ball to hit it; the lane's running-body mark reads the same.
func hit_reach() -> float:
	return radius + 1.4


# The ball is hit when it is inside the committed lane and the chaser's body has
# reached it. Both halves read the same lane the player was shown.
func _check_hit(lane: Node3D) -> void:
	if _landed:
		return
	var ball := _ball()
	var flat := Vector3(ball.x - global_position.x, 0.0, ball.z - global_position.z)
	if flat.length() > hit_reach() or not lane.contains(ball):
		return
	_landed = true
	hit_player.emit(DAMAGE, lane.dir * SHOVE + Vector3.UP * 2.0)


func _end_attack(next: int) -> void:
	if state == State.LUNGE:
		lunges += 1
	state = next
	_clock = 0.0
	_rest = REST * float(pressure.get("rest", 1.0))
	_clear_telegraph()
	AttackBudget.release(self)


# e01_brace_back: the wedge loads back over planted claws and flares its hinged fin.
# The state transition resets _clock before _pose(), so LUNGE at clock zero is the
# release sample (full brace). The same clock then drives the 0.08 s forward snap.
# Absolute rest-relative transforms prevent a cancelled wind-up retaining any pose.
func _pose() -> void:
	if _mesh == null:
		return
	var dt := get_physics_process_delta_time()
	var lane := telegraph() if state == State.WINDUP or state == State.LUNGE else null
	var face: Vector3 = lane.dir if lane != null else _flat_to_ball()
	if face.length_squared() > 0.0001:
		_mesh.rotation.y = lerp_angle(_mesh.rotation.y, atan2(-face.x, -face.z), 1.0 - exp(-14.0 * dt))
	var shift := Vector3.ZERO
	var pitch := 0.0
	var flare := 0.0
	if windup_pose_enabled and lane != null and not _dead and not is_queued_for_deletion():
		if state == State.WINDUP:
			var t := smoothstep(0.0, 1.0, clampf(_clock / WINDUP, 0.0, 1.0))
			shift = REAR_SHIFT * t
			pitch = deg_to_rad(REAR_PITCH) * t
			flare = deg_to_rad(32.0) * t
		elif state == State.LUNGE:
			var snap := smoothstep(0.0, 1.0, clampf(_clock / 0.08, 0.0, 1.0))
			shift = REAR_SHIFT.lerp(Vector3(0.0, -0.08, -0.25), snap)
			pitch = lerpf(deg_to_rad(REAR_PITCH), deg_to_rad(-12.0), snap)
			flare = deg_to_rad(32.0) * (1.0 - snap)
	if pitch == 0.0 and shift == Vector3.ZERO and flare == 0.0:
		if _parts_off_rest:
			_parts_off_rest = false
			for part in _pose_parts.values():
				part.node.transform = part.rest
		return
	_parts_off_rest = true
	var body_pose := Transform3D(Basis(Vector3.RIGHT, pitch), shift)
	for part_name in _pose_parts:
		var part: Dictionary = _pose_parts[part_name]
		var node: Node3D = part.node
		var rest: Transform3D = part.rest
		match part_name:
			"ChaserBody":
				node.transform = body_pose * rest
			"ChaserFin":
				node.transform = body_pose * rest * Transform3D(Basis(Vector3.RIGHT, flare), Vector3.ZERO)
			_:
				node.transform = rest


# The state row the back shows now: "will_break" while winding up, "interrupted" for
# INTERRUPT_SHOWN seconds after a hit broke the wind-up, "" at rest.
func cue_state() -> String:
	if not body_cue_enabled or _dead:
		return ""
	if state == State.WINDUP:
		return "will_break"
	if _interrupted_left > 0.0:
		return "interrupted"
	return ""


func _show_interrupted() -> void:
	if not body_cue_enabled:
		return
	_interrupted_left = INTERRUPT_SHOWN
	# The broken lunge flips the wedge over: the launch reaction along the knock.
	react("launch", _knock)


func _cue_step(delta: float) -> void:
	_cue_advance(delta)
	_paint_cue()


func _cue_advance(delta: float) -> void:
	_interrupted_left = maxf(0.0, _interrupted_left - delta)
	_cue_clock += delta


# The cue is the body paint's emission. A flash and the rest look share that emission, so
# _apply_rest_look hands it back here and an active cue wins over the flash's glow.
func _paint_cue() -> void:
	var row := cue_state()
	if row == "":
		if _cue_painted:
			_cue_painted = false
			if _flash <= 0.0:
				_apply_rest_look()
		return
	_cue_painted = true
	_material.emission_enabled = true
	_material.emission = EventKinds.state_color(row)
	var swing := 1.0
	if String(EventKinds.state_row(row).get("motion", "none")) == "pulse":
		swing += PULSE_DEPTH * sin(TAU * PULSE_HZ * _cue_clock)
	_material.emission_energy_multiplier = PLATE_GLOW_LIVE * swing


func _apply_rest_look() -> void:
	super()
	_paint_cue()
