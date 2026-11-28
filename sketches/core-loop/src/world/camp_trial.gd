extends Node3D


const Palette := preload("res://src/core/palette.gd")
const PhysicsLayers := preload("res://src/core/physics_layers.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const Records := preload("res://src/world/camp_records.gd")
const CampCraftMeshes := preload("res://src/presentation/craft/camp_craft_meshes.gd")

const TRACK := "camp_trial_track"
const ARCH := "camp_trial_arch"

const CHECKPOINTS := 4
const CHECK_RADIUS := 6.5
const LINE_HALF := 5.5
const STAGE_BEHIND := 4.0
const LAP_CAP := 119.0
const WANDER := 80.0
const GHOST_STEP := 1.0 / float(Records.GHOST_HZ)

const GOLD_MS := 13000
const SILVER_MS := 15000
const BRONZE_MS := 17500
const MEDALS := ["bronze", "silver", "gold"]

enum State { IDLE, ARMED, RUNNING, DONE }

var hub
var records
var run := Run.new()
var recorder := Recorder.new()
var timer_label: Label3D
var ghost_mesh: MeshInstance3D
var guide: MultiMeshInstance3D
var lamps := {}

var _inv := Transform3D.IDENTITY
var _sensors: Array[Area3D] = []
var _line := Vector3.ZERO
var _prev := Vector3.ZERO
var _staging := Vector3.ZERO
var _staged := false
var _ghost: PackedVector3Array = PackedVector3Array()
var _ghost_total := 0.0
var _after := 0.0
var last_result := {}


class Run:
	var state := State.IDLE
	var time := 0.0
	var next := 0
	var splits: Array = []

	func arm() -> void:
		state = State.ARMED
		time = 0.0
		next = 0
		splits = []

	func start(lead := 0.0) -> bool:
		if state != State.ARMED:
			return false
		state = State.RUNNING
		time = lead
		next = 0
		splits = []
		return true

	func tick(delta: float) -> void:
		if state == State.RUNNING:
			time += delta

	func checkpoint(index: int) -> bool:
		if state != State.RUNNING or index != next:
			return false
		splits.append(time)
		next += 1
		return true

	func finish(lead := 0.0) -> bool:
		if state != State.RUNNING or next < CHECKPOINTS:
			return false
		time = maxf(time - lead, 0.0)
		state = State.DONE
		return true

	func abort() -> void:
		state = State.IDLE
		next = 0

	func ms() -> int:
		return roundi(time * 1000.0)


class Recorder:
	var points := PackedVector3Array()
	var _taken := 0

	func begin(at: Vector3) -> void:
		points = PackedVector3Array([at])
		_taken = 1

	func tick(time: float, at: Vector3) -> void:
		while float(_taken) * GHOST_STEP <= time and points.size() < Records.GHOST_MAX_SAMPLES:
			points.append(at)
			_taken += 1

	func end(at: Vector3) -> void:
		if points.size() < Records.GHOST_MAX_SAMPLES:
			points.append(at)


const CLASS_TAG := "camp_trial"


static func attach(hub_ref) -> void:
	for stem in [TRACK, ARCH]:
		if hub_ref.piece(stem) == null:
			push_warning("%s: camp piece %s is missing; left out" % [CLASS_TAG, stem])
			return
	var trial := new()
	trial.name = "CampTrial"
	hub_ref.root.add_child(trial)
	trial.setup(hub_ref)


static func medal_for(ms: int) -> String:
	if ms <= 0:
		return ""
	if ms <= GOLD_MS:
		return "gold"
	if ms <= SILVER_MS:
		return "silver"
	if ms <= BRONZE_MS:
		return "bronze"
	return ""


static func lamps_for(medal: String) -> Array:
	var at := MEDALS.find(medal)
	return MEDALS.slice(0, at + 1) if at >= 0 else []


static func format_ms(ms: int) -> String:
	return "%d:%05.2f" % [ms / 60000, float(ms % 60000) / 1000.0]


static func ghost_at(points: PackedVector3Array, seconds: float, total: float) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	if points.size() == 1 or total <= 0.0 or seconds >= total:
		return points[points.size() - 1]
	var f := clampf(seconds / total, 0.0, 1.0) * float(points.size() - 1)
	var i := int(f)
	return points[i].lerp(points[mini(i + 1, points.size() - 1)], f - float(i))


static func crossed(prev: Vector3, cur: Vector3, line: Vector3) -> float:
	if not (prev.z > line.z and cur.z <= line.z):
		return -1.0
	var f := (prev.z - line.z) / (prev.z - cur.z)
	var at_x := lerpf(prev.x, cur.x, f)
	if absf(at_x - line.x) > LINE_HALF:
		return -1.0
	return 1.0 - f


func setup(hub_ref, records_ref = null) -> void:
	hub = hub_ref
	records = records_ref if records_ref != null else Records.new(_profile())
	var track: Node3D = hub.piece(TRACK)
	_inv = track.global_transform.affine_inverse()
	_line = _inv * hub.socket(TRACK, "start").origin
	for i in CHECKPOINTS:
		_sensors.append(_sensor("checkpoint_%d" % i))
	timer_label = _timer_label()
	_build_lamps()
	_build_ghost()
	_build_guide()
	_refresh_idle()
	hub.add_station("camp_trial", hub.socket(TRACK, "start").origin, "Time trial: arm the clock", "interact", 5.0, Callable(self, "arm"))
	if hub.has_signal("walk_left"):
		hub.walk_left.connect(_on_walk_left)


func _profile():
	return hub.get("camp_store") if hub != null else null


func _sensor(socket: String) -> Area3D:
	var area := Area3D.new()
	area.name = "Sensor_" + socket
	area.collision_layer = PhysicsLayers.NONE
	area.collision_mask = PhysicsLayers.NONE
	area.set_collision_mask_value(PhysicsLayers.BALL_LAYER, true)
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = CHECK_RADIUS
	shape.shape = sphere
	area.add_child(shape)
	hub.root.add_child(area)
	area.global_position = hub.socket(TRACK, socket).origin
	return area


func _timer_label() -> Label3D:
	var label := Label3D.new()
	label.name = "TrialTimer"
	label.font = UiFonts.mono()
	label.font_size = 64
	label.pixel_size = 0.018
	label.modulate = Palette.AMBER
	label.outline_modulate = Palette.CHARCOAL
	label.outline_size = 14
	label.shaded = false
	label.double_sided = false
	hub.root.add_child(label)
	var arch: Node3D = hub.piece(ARCH)
	label.global_transform = Transform3D(arch.global_transform.basis, hub.socket(ARCH, "timer").origin + arch.global_transform.basis.z * 0.12)
	return label


func _build_lamps() -> void:
	var colours := {"bronze": Palette.COPPER, "silver": Palette.LEDGER, "gold": Palette.AMBER}
	for medal in MEDALS:
		var at: Vector3 = hub.socket(ARCH, "light_" + medal).origin
		var bulb := MeshInstance3D.new()
		bulb.mesh = CampCraftMeshes.signal_lantern_mesh(0.4)
		var mat := CampCraftMeshes.lantern_bulb_material(colours[medal], 0.0)
		bulb.set_surface_override_material(0, CampCraftMeshes.iron_material())
		bulb.set_surface_override_material(1, mat)
		bulb.name = "Bulb_" + medal
		hub.root.add_child(bulb)
		bulb.global_position = at
		lamps[medal] = {"bulb": bulb, "mat": mat}


func lamp_lit(medal: String) -> bool:
	return lamps[medal]["mat"].emission_energy_multiplier > 0.0


func _light(earned: Array) -> void:
	for medal in lamps:
		var on := earned.has(medal)
		lamps[medal]["mat"].emission_energy_multiplier = 3.0 if on else 0.0


func _build_ghost() -> void:
	ghost_mesh = MeshInstance3D.new()
	ghost_mesh.name = "BestLapGhost"
	ghost_mesh.mesh = CampCraftMeshes.ghost_sphere_mesh(1.0)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(Palette.ARC, 0.3)
	mat.emission_enabled = true
	mat.emission = Palette.ARC
	mat.emission_energy_multiplier = 0.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ghost_mesh.material_override = mat
	ghost_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost_mesh.visible = false
	hub.root.add_child(ghost_mesh)


func _build_guide() -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = CampCraftMeshes.guide_pip_mesh(0.16)
	multi.instance_count = 32
	for i in 32:
		var at: Vector3 = hub.socket(TRACK, "ghost_%02d" % i).origin
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
	guide = MultiMeshInstance3D.new()
	guide.name = "GuideLine"
	guide.multimesh = multi
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(Palette.ARC, 0.35)
	guide.material_override = mat
	guide.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hub.root.add_child(guide)
	guide.visible = false


func _refresh_idle() -> void:
	var best: int = records.trial_best_ms()
	timer_label.text = "BEST %s" % format_ms(best) if best > 0 else "TIME TRIAL"
	_light(lamps_for(medal_for(best)))
	_ghost = records.ghost()
	_ghost_total = float(best) / 1000.0
	guide.visible = _ghost.is_empty()
	ghost_mesh.visible = false


func _ball_body() -> Node3D:
	return hub.ball.body() if hub != null and hub.ball != null else null


func arm() -> void:
	if run.state == State.ARMED or run.state == State.RUNNING:
		return
	run.arm()
	_refresh_idle()
	var track: Node3D = hub.piece(TRACK)
	var behind: Vector3 = track.global_transform * (_line + Vector3(0, 0, STAGE_BEHIND))
	hub.ball.reset_to(behind, Vector3.ZERO)
	_staging = _line + Vector3(0, 0, STAGE_BEHIND)
	_staged = false
	timer_label.text = "0:00.00"
	if not _ghost.is_empty():
		ghost_mesh.visible = true
		ghost_mesh.global_position = track.global_transform * _ghost[0]


func _physics_process(delta: float) -> void:
	_step(delta)
	_sync_clock()


func _sync_clock() -> void:
	if hub == null or not hub.has_method("set_clock"):
		return
	if run.state == State.RUNNING:
		hub.set_clock("Lap  " + format_ms(run.ms()))
	elif run.state == State.DONE and _after > 0.0:
		hub.set_clock("Lap  " + timer_label.text.strip_edges())
	else:
		hub.set_clock("")


func _step(delta: float) -> void:
	var body := _ball_body()
	if body == null:
		return
	if run.state == State.DONE:
		_after -= delta
		if _after <= 0.0:
			run.state = State.IDLE
			_refresh_idle()
		return
	if run.state == State.IDLE:
		return
	var local := _inv * body.global_position
	var lead := -1.0
	if run.state == State.ARMED:
		if not _staged:
			if local.distance_to(_staging) > 2.5:
				return
			_staged = true
			_prev = local
			return
		lead = crossed(_prev, local, _line)
		if lead >= 0.0:
			run.start(lead * delta)
			recorder.begin(local)
		elif _wandered(local):
			abort()
	elif run.state == State.RUNNING:
		run.tick(delta)
		recorder.tick(run.time, local)
		_check_sensors(body)
		if run.next >= CHECKPOINTS:
			lead = crossed(_prev, local, _line)
			if lead >= 0.0 and run.finish(lead * delta):
				recorder.end(local)
				_finish()
		if run.state == State.RUNNING:
			if run.time > LAP_CAP or _wandered(local):
				abort()
			else:
				timer_label.text = format_ms(run.ms())
				_move_ghost()
	_prev = local


func _check_sensors(body: Node3D) -> void:
	if run.next < CHECKPOINTS and _sensors[run.next].overlaps_body(body):
		run.checkpoint(run.next)


func _wandered(local: Vector3) -> bool:
	return Vector2(local.x, local.z).length() > WANDER or local.y < -8.0


func _move_ghost() -> void:
	if _ghost.is_empty():
		return
	ghost_mesh.visible = true
	ghost_mesh.global_position = hub.piece(TRACK).global_transform * ghost_at(_ghost, run.time, _ghost_total)


func _finish() -> void:
	var ms := run.ms()
	var medal := medal_for(ms)
	var fresh: bool = records.submit_trial(ms, recorder.points)
	last_result = {"ms": ms, "medal": medal, "best": fresh}
	var best: int = records.trial_best_ms()
	_light(lamps_for(medal_for(best)))
	timer_label.text = "%s%s" % [format_ms(ms), "   " + medal.to_upper() if medal != "" else ""]
	ghost_mesh.visible = false
	_after = 6.0


func abort() -> void:
	if run.state == State.IDLE:
		return
	run.abort()
	_refresh_idle()


func _on_walk_left() -> void:
	abort()
