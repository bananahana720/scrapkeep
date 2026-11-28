extends RefCounted

const Tuning := preload("res://src/movement/tuning.gd")
const Palette := preload("res://src/core/palette.gd")
const Run := preload("res://src/core/run_state.gd")
const WeaponDriver := preload("res://src/combat/weapon_driver.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const EnemyBossCraft := preload("res://src/presentation/craft/enemy_boss_craft.gd")
static var _sheet_shader: Shader

const SHEET_SECONDS := 3.0
const SHEET_WIDTH := 24.0
const SHEET_RUN := 30.0
const SHEET_DEPTH := 3.0
const SHEET_TOP := 14.0
const RIDE_MIN_SPEED := 3.0
const RIDE_GAIN := 8.0
const RIDE_TOP_MARGIN := 2.0
const FACE_SLOPE := 0.15
const POUR_OFFSET := Vector3(0.0, 0.0, -6.0)
const SHEET_COLOR := Palette.SANDSTONE
const SHEET_ALPHA := 0.55
const LANE_TELL_ALPHA := 0.2
const LANE_PAST_CORE := 2.0
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
const Comfort := preload("res://src/core/comfort.gd")
static var _line_reference := -1.0
const LINE_REFERENCE_HEFT := 1.5
const LINE_REFERENCE_WEAPON := "rapid_laser"
const LINE_PAY := 0.60

var gates_opened := 0
var rides := 0
var sheet_left := 0.0
var sheet_dir := Vector3.ZERO
var riding := false
var entered_sheet_cycle := -1
var paid_cycle := -1
var paid_gain := 0.0
var lane := 0

var _entry_speed := 0.0
var _camera_declared := false
var _sheet_view: MeshInstance3D


func mount_offset(_warden, _clock: float) -> Vector3:
	return Vector3.ZERO


func sheet_live() -> bool:
	return sheet_left > 0.0


static func _is_dam(warden) -> bool:
	return warden.spec.get("park_landmark", false) and warden.family == "reactor" and warden.mounting == "dam_face"


func _declare_fight(warden, engaged: bool) -> void:
	if engaged == _camera_declared or warden.fleet == null or warden.fleet.ctx.camera == null:
		return
	_camera_declared = engaged
	if engaged:
		warden.fleet.ctx.camera.set_contact_subject(warden)
	else:
		warden.fleet.ctx.camera.clear_contact_subject(warden)


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
	if sheet_left <= 0.0 and not warden._charging and is_instance_valid(_sheet_view):
		_close_sheet()
	if sheet_left > 0.0:
		sheet_left = maxf(0.0, sheet_left - delta)
		if sheet_left <= 0.0:
			_close_sheet()
		else:
			_ride(warden, delta)


func phase_chunks_left(warden) -> int:
	if not warden._posture is DamPosture:
		return warden.chunks_left()
	var quarters := floori(warden._posture.posture / warden._posture.FULL * 4.0 + 1e-6)
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


func _lane_for(warden) -> int:
	var lost: int = warden.chunks_lost()
	if lost <= 0:
		return 0
	var fleet = warden.get("fleet")
	var run = fleet.ctx.run if fleet != null and fleet.ctx != null else null
	var run_seed: int = int(run.run_seed) if run != null else 0
	return 1 if posmod(hash([run_seed, warden.stage, lost]), 2) == 0 else -1


func _across(warden, point: Vector3) -> float:
	var flat := Vector3(point.x - warden.home.x, 0.0, point.z - warden.home.z)
	return flat.dot(sheet_dir.cross(Vector3.UP))


func lane_offset() -> float:
	return float(lane) * (SHEET_WIDTH * 0.5 - LANE_PAST_CORE) * 0.5


func lane_width() -> float:
	return SHEET_WIDTH if lane == 0 else SHEET_WIDTH * 0.5 + LANE_PAST_CORE


func rest_floor(warden) -> float:
	return SHEET_SECONDS if _is_dam(warden) else 0.0


func on_pulse(warden, _lifted: bool) -> void:
	if warden.mounting == "dam_face":
		_open_sheet(warden)


func _open_sheet(warden) -> void:
	if sheet_dir == Vector3.ZERO:
		sheet_dir = _face_heading(warden)
	gates_opened += 1
	sheet_left = SHEET_SECONDS
	riding = false
	_show_sheet(warden)


func on_exit(warden) -> void:
	_declare_fight(warden, false)
	sheet_left = 0.0
	_close_sheet()


func _close_sheet() -> void:
	riding = false
	if is_instance_valid(_sheet_view):
		_sheet_view.visible = false
		_sheet_view.name = "ReactorSheetGone"
		_sheet_view.queue_free()
	_sheet_view = null


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


func in_sheet(warden, point: Vector3) -> bool:
	if not sheet_live() or sheet_dir == Vector3.ZERO:
		return false
	var flat := Vector3(point.x - warden.home.x, 0.0, point.z - warden.home.z)
	var along := flat.dot(sheet_dir)
	var across := absf(_across(warden, point) - lane_offset())
	if along < 0.0 or along > SHEET_RUN or across > lane_width() * 0.5:
		return false
	return point.y <= _profile(warden, point, along) + SHEET_DEPTH


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
	var push := Vector3.ZERO
	var speed := planar.length()
	if speed > 0.01 and speed < _entry_speed:
		push = planar / speed * (_entry_speed - speed) / delta
	if mounted and target.has_method("body") and target.body().has_method("set_velocity_now"):
		var held: Vector3 = planar.normalized() * maxf(speed, _entry_speed)
		target.body().set_velocity_now(Vector3(held.x, maxf(v.y, want_vy), held.z))
	else:
		target.add_external_accel(Vector3(push.x, maxf(up, 0.0), push.z))


func _show_sheet(warden, alpha := SHEET_ALPHA) -> void:
	_close_sheet()
	var root = warden.world_root
	if root == null or not is_instance_valid(root):
		return
	var view := MeshInstance3D.new()
	view.name = "ReactorSheet"
	view.mesh = EnemyBossCraft.reactor_spillway_chute(lane_width(), SHEET_RUN - SHEET_TOP)
	var is_live := alpha >= SHEET_ALPHA * 0.9
	view.material_override = _make_sheet_material(alpha, is_live)
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(view)
	var mid: Vector3 = warden.home + sheet_dir * (SHEET_TOP + (SHEET_RUN - SHEET_TOP) * 0.5) \
			+ sheet_dir.cross(Vector3.UP) * lane_offset()
	var ground: float = warden.terrain.height(mid.x, mid.z) if warden.terrain != null else warden.home.y
	view.global_transform = Transform3D(Basis.looking_at(-sheet_dir, Vector3.UP), Vector3(mid.x, ground + 0.2, mid.z))
	if is_live and not Comfort.reduced_motion and view.is_inside_tree():
		view.scale = Vector3(1.0, 1.0, 0.15)
		var tw := view.create_tween()
		tw.tween_property(view, "scale:z", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var foot: Vector3 = warden.home + sheet_dir * SHEET_RUN + sheet_dir.cross(Vector3.UP) * lane_offset()
		var foot_y: float = warden.terrain.height(foot.x, foot.z) if warden.terrain != null else ground
		var at := Vector3(foot.x, foot_y + 0.4, foot.z)
		FxLibrary.burst(view, "steam_puff", at, 10, Color("e8efe9"), Vector3.ZERO, true)
		FxLibrary.burst(view, "slam_dust", at, 8, Color.TRANSPARENT, Vector3.ZERO, true)
	_sheet_view = view


static func _make_sheet_material(alpha: float, is_live: bool) -> ShaderMaterial:
	if _sheet_shader == null:
		_sheet_shader = Shader.new()
		_sheet_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform vec3 deep_col : source_color = vec3(0.08, 0.28, 0.30);
uniform vec3 mid_col : source_color = vec3(0.16, 0.44, 0.45);
uniform vec3 crest_col : source_color = vec3(0.88, 0.92, 0.88);
uniform vec3 lip_col : source_color = vec3(0.24, 0.28, 0.27);
uniform vec3 tell_col : source_color = vec3(0.76, 0.68, 0.56);
uniform vec3 ink_col : source_color = vec3(0.11, 0.10, 0.10);
uniform float opacity = 0.72;
uniform float live = 1.0;
uniform float motion = 1.0;
varying vec3 loc;
varying vec4 vcol;
void vertex() {
	loc = VERTEX;
	vcol = COLOR;
}
void fragment() {
	float t = TIME * 5.2 * motion;
	float streak = 0.5 + 0.5 * sin(loc.x * 2.1 + sin(loc.z * 0.45 - t * 0.6) * 1.6);
	float wave = 0.5 + 0.5 * sin(loc.z * 1.15 - t + streak * 1.4);
	float ripple = 0.5 + 0.5 * sin(loc.z * 2.6 - t * 1.45 - loc.x * 0.85);
	float foam = step(0.68, pow(streak, 1.7) * 0.46 + wave * 0.42 + ripple * 0.22 + vcol.b * 0.18);
	float mid_band = step(0.45, streak * 0.55 + wave * 0.45);
	float end_lip = smoothstep(5.5, 7.9, loc.z) + smoothstep(5.8, 7.9, -loc.z);
	float training_lip = smoothstep(0.60, 0.86, vcol.r);
	float trough_shade = clamp(vcol.g * 0.42, 0.0, 0.5);
	float edge = step(0.94, abs(UV.x - 0.5) * 2.0);
	vec3 water = mix(deep_col, mid_col, mid_band) * (1.0 - trough_shade * 0.45);
	float lip_foam = clamp(vcol.b * (0.45 + 0.55 * ripple) * training_lip, 0.0, 1.0);
	water = mix(water, crest_col, clamp(foam * 0.82 + end_lip * 0.65 + lip_foam * 0.55, 0.0, 1.0));
	vec3 curb = mix(lip_col, crest_col, clamp(lip_foam * 0.75 + vcol.r * 0.18, 0.0, 1.0));
	water = mix(water, curb, training_lip * 0.58);
	vec3 base = mix(tell_col, water, live);
	ALBEDO = mix(base, ink_col, edge * 0.78);
	ALPHA = clamp(opacity + (foam * 0.20 + edge * 0.22 + training_lip * 0.16) * live, 0.0, 0.96);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = _sheet_shader
	mat.set_shader_parameter("opacity", clampf(alpha + (0.22 if is_live else 0.08), 0.0, 0.92))
	mat.set_shader_parameter("live", 1.0 if is_live else 0.0)
	mat.set_shader_parameter("motion", 0.0 if FlashGuard.on or Comfort.reduced_motion else 1.0)
	return mat


func pour_point(warden) -> Vector3:
	var offset := POUR_OFFSET
	var named = warden.spec.get("pour_offset") if "spec" in warden else null
	if named is Array and named.size() == 3:
		offset = Vector3(float(named[0]), float(named[1]), float(named[2]))
	elif named is Vector3:
		offset = named
	return warden.home + offset


func lane_origin(warden) -> Vector3:
	return pour_point(warden)


static func line_reference_damage() -> float:
	if _line_reference < 0.0:
		var total := 0.0
		var pilots: Array = ClassDef.all()
		for def in pilots:
			total += Weapons.base_damage(def.weapon_id)
		_line_reference = total / pilots.size()
	return _line_reference


static func base_dps(weapon: String) -> float:
	var row: Dictionary = Weapons.BASE[weapon]
	if preload("res://src/core/ability_state.gd").ABILITIES.get(weapon, {}).has("pressure"):
		return float(row["damage"]) / Weapons.PRESSURE_ROLL_S
	return WeaponDriver.base_dps(Weapons.base(weapon))


func plate_reading(warden) -> Dictionary:
	if _is_dam(warden):
		return {"mount": "dam_face"}
	if _is_flume(warden):
		return {"mount": "flume"}
	return {}


func plate_targets(warden) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _is_dam(warden):
		if sheet_dir != Vector3.ZERO:
			out.append({"at": _sheet_foot(warden), "what": "sheet" if sheet_live() else "sheet_soon"})
	elif _is_flume(warden):
		var what := "core" if warden.staggered() else "shoot" if _line_on(warden) else "latch"
		out.append({"at": warden.global_position, "what": what})
	return out


func _sheet_foot(warden) -> Vector3:
	var at: Vector3 = warden.home + sheet_dir * SHEET_RUN + sheet_dir.cross(Vector3.UP) * lane_offset()
	if warden.terrain != null:
		at.y = warden.terrain.height(at.x, at.z)
	return at


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
	var share := pow(minf(heft, Run.HEFT_CLASS_AT[2]) / LINE_REFERENCE_HEFT, posture.curve)
	var reference_dps := base_dps(LINE_REFERENCE_WEAPON)
	var fleet = warden.get("fleet")
	var run = fleet.ctx.run if fleet != null and fleet.ctx != null else null
	var def = run.class_def if run != null else null
	var pilot_dps := base_dps(def.weapon_id) if def != null and Weapons.BASE.has(def.weapon_id) else reference_dps
	result["gain"] = pay * LINE_PAY * float(hit.get("punch", 0.0)) / pilot_dps * reference_dps / line_reference_damage() * share
	result["glance"] = false
	result["full"] = true
