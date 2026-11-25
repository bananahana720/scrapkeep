extends "res://src/combat/counter.gd"

const Projectile := preload("res://src/combat/projectile.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const SPECIAL_CUES := "res://src/combat/special_cues.gd"

signal special_tell(moment: String)
signal dispatched(enemy: Node3D)
signal cargo_flushed(pod: Node3D)
signal cargo_returned(dispatcher: Node3D)

const SpecialRig := preload("res://src/presentation/special_rig.gd")
const MODEL := "res://assets/models/world_one/enemy_dispatcher.glb"
const HP := 60.0
const SCRAP := 8
const PERCH_MIN := 6.0
const PERCH_MAX := 10.0
const PERCH_HEIGHT := 8.0
const MAST_WIDTH := 1.6
const DECK_SIZE := Vector3(3.6, 0.3, 3.6)
const FLOOR_DROP := 1.5
const BODY_SIZE := Vector3(2.9, 2.3, 2.9)
const DROP_EVERY := 8.0
const FIRST_DROP := 2.0
const DROP_RANGE := 45.0
const SUCK := 0.45
const FLIGHT := 0.75
const WARN := SUCK + FLIGHT
const DROP_RADIUS := 4.0
const DROP_DAMAGE := 10.0
const DROP_SHOVE := 6.0
const ADD_CAP := 4
const FLUSH_IGNORE_S := 14.0
const FLUSH_SIREN := 0.95
const FLUSH_FLIGHT := 0.90
const FLUSH_WARN := FLUSH_SIREN + FLUSH_FLIGHT
const FLUSH_RADIUS := 5.0
const FLUSH_DAMAGE := 18.0
const FLUSH_SHOVE := 10.0
const CARGO_RAM_REACH := 3.2
const CARGO_RAM_HEIGHT := 3.5
const CARGO_RAM_SPEED := 8.0
const CARGO_RETURN_FLIGHT := 0.35
const ESCALATION := [
	{"kind": "chaser", "every": DROP_EVERY, "damage": DROP_DAMAGE},
	{"kind": "hooker", "every": 4.5, "damage": 15.0},
	{"kind": "plated_brute", "every": 3.0, "damage": 20.0},
]
const POD_RADIUS := 0.55
const RADAR_TURN := TAU / 4.0 / (60.0 / 129.0)

var drops := 0
var escalation := 0
var _hit_since_drop := false
var landed_hits := 0
var cargo_flushes := 0
var cargo_returns := 0
var ignored_seconds := 0.0
var adds: Array = []
var perch_top := Vector3.ZERO
var mast: StaticBody3D

var _mouth := Vector3(0.0, -0.6, -3.4)
var _radar: Node3D
var _signal_material: StandardMaterial3D
var _pod: MeshInstance3D
var _pod_from := Vector3.ZERO
var _pod_launch := Vector3.ZERO
var _flush_active := false
var _pod_returned := false
var _siren_fx_t := 0.0
var _return_pod: Node3D
static var _shared: Array = []
static var _sockets: Dictionary = {}
static var _asset_warned := false
static var _packed_model: PackedScene
static var _model_checked := false
static var _body_shape: BoxShape3D
static var _deck_shape: BoxShape3D
static var _column_shapes: Dictionary = {}
static var _mast_meshes: Dictionary = {}
static var _mast_charcoal: StandardMaterial3D
static var _mast_rust: StandardMaterial3D
static var _pod_mesh: CapsuleMesh
static var _pod_mat: StandardMaterial3D
static var _special_cues = null
static var _special_cues_checked := false
static var _warmed := false


static func warm_shared() -> void:
	if _warmed:
		return
	_warmed = true
	_parts()
	_get_body_shape()
	_get_deck_shape()
	_get_column_shape(PERCH_HEIGHT)
	_get_mast_meshes(PERCH_HEIGHT)
	_get_pod_mesh()
	_get_pod_mat()
	_get_special_cues()


static func _get_body_shape() -> BoxShape3D:
	if _body_shape == null:
		_body_shape = BoxShape3D.new()
		_body_shape.size = BODY_SIZE
	return _body_shape


static func _get_deck_shape() -> BoxShape3D:
	if _deck_shape == null:
		_deck_shape = BoxShape3D.new()
		_deck_shape.size = DECK_SIZE
	return _deck_shape


static func _get_column_shape(height: float) -> BoxShape3D:
	var key := roundi(height * 10.0)
	if not _column_shapes.has(key):
		var box := BoxShape3D.new()
		box.size = Vector3(MAST_WIDTH, float(key) * 0.1, MAST_WIDTH)
		_column_shapes[key] = box
	return _column_shapes[key] as BoxShape3D


static func _get_pod_mesh() -> CapsuleMesh:
	if _pod_mesh == null:
		_pod_mesh = CapsuleMesh.new()
		_pod_mesh.radius = POD_RADIUS
		_pod_mesh.height = POD_RADIUS * 3.0
	return _pod_mesh


static func _get_pod_mat() -> StandardMaterial3D:
	if _pod_mat == null:
		_pod_mat = Palette.solid(Palette.BRASS, 0.6)
	return _pod_mat


static func _get_special_cues():
	if not _special_cues_checked:
		_special_cues_checked = true
		if ResourceLoader.exists(SPECIAL_CUES):
			_special_cues = load(SPECIAL_CUES)
	return _special_cues


static func _append_box(st: SurfaceTool, size: Vector3, center: Vector3) -> void:
	var h := size * 0.5
	var corners := [
		center + Vector3(-h.x, -h.y, -h.z),
		center + Vector3(h.x, -h.y, -h.z),
		center + Vector3(h.x, h.y, -h.z),
		center + Vector3(-h.x, h.y, -h.z),
		center + Vector3(-h.x, -h.y, h.z),
		center + Vector3(h.x, -h.y, h.z),
		center + Vector3(h.x, h.y, h.z),
		center + Vector3(-h.x, h.y, h.z),
	]
	var quads := [
		[0, 1, 2, 3, Vector3(0, 0, -1)],
		[5, 4, 7, 6, Vector3(0, 0, 1)],
		[4, 0, 3, 7, Vector3(-1, 0, 0)],
		[1, 5, 6, 2, Vector3(1, 0, 0)],
		[3, 2, 6, 7, Vector3(0, 1, 0)],
		[4, 5, 1, 0, Vector3(0, -1, 0)],
	]
	for q in quads:
		st.set_normal(q[4])
		st.add_vertex(corners[q[0]])
		st.add_vertex(corners[q[1]])
		st.add_vertex(corners[q[2]])
		st.add_vertex(corners[q[0]])
		st.add_vertex(corners[q[2]])
		st.add_vertex(corners[q[3]])


static func _get_mast_meshes(height: float) -> Dictionary:
	var key := roundi(height * 10.0)
	if _mast_meshes.has(key):
		return _mast_meshes[key]
	if _mast_charcoal == null:
		_mast_charcoal = Palette.solid(Palette.CHARCOAL)
	if _mast_rust == null:
		_mast_rust = Palette.solid(Palette.RUST)
	var h := float(key) * 0.1
	var leg_at := MAST_WIDTH * 0.5 - 0.1
	var st_frame := SurfaceTool.new()
	st_frame.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in [-leg_at, leg_at]:
		for z in [-leg_at, leg_at]:
			_append_box(st_frame, Vector3(0.18, h, 0.18), Vector3(x, -h * 0.5, z))
	_append_box(st_frame, DECK_SIZE, Vector3(0.0, -DECK_SIZE.y * 0.5, 0.0))
	var st_rungs := SurfaceTool.new()
	st_rungs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rungs := int(h / 1.6)
	for i in rungs:
		var y := -h + 0.8 + i * 1.6
		_append_box(st_rungs, Vector3(MAST_WIDTH, 0.1, 0.1), Vector3(0.0, y, leg_at))
		_append_box(st_rungs, Vector3(MAST_WIDTH, 0.1, 0.1), Vector3(0.0, y, -leg_at))
		_append_box(st_rungs, Vector3(0.1, 0.1, MAST_WIDTH), Vector3(leg_at, y, 0.0))
		_append_box(st_rungs, Vector3(0.1, 0.1, MAST_WIDTH), Vector3(-leg_at, y, 0.0))
	var entry := {
		"frame": st_frame.commit(),
		"rungs": st_rungs.commit() if rungs > 0 else null,
	}
	_mast_meshes[key] = entry
	return entry


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	plating = 0.0
	scrap_value = SCRAP
	weight = 4.0
	walk_speed = 0.0
	attack_range = DROP_RANGE
	warn_seconds = WARN
	live_seconds = 0.05
	rest_seconds = DROP_EVERY - WARN - live_seconds
	first_rest = FIRST_DROP
	keep_far = DROP_RANGE


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	super(target_ref, terrain_ref, root_ref, live_ref, threat, spec_ref)
	_perch()


func _build_crew() -> void:
	radius = BODY_SIZE.x * 0.5
	half_height = FLOOR_DROP
	var shape := CollisionShape3D.new()
	shape.shape = _get_body_shape()
	add_child(shape)
	_base_color = Color.WHITE
	_material = Palette.solid(_base_color)
	_material.vertex_color_use_as_albedo = true
	_crew = null


func _build_tool() -> void:
	var parts := _parts()
	if parts.is_empty():
		_fallback_body()
		return
	var model := SpecialRig.seat(self, _visual_parent(), MODEL, "dispatcher")
	for part in parts:
		var mi: MeshInstance3D = model.find_child(part.name, true, false) as MeshInstance3D if model != null else null
		if mi == null:
			mi = MeshInstance3D.new()
			mi.name = part.name
			mi.mesh = part.mesh
			mi.transform = part.xform
			_visual_parent().add_child(mi)
		match String(part.name):
			"DispatcherBody":
				mi.material_override = _material
			"DispatcherSignal":
				_signal_material = Palette.solid(Palette.BRASS, 0.0)
				_signal_material.vertex_color_use_as_albedo = true
				mi.material_override = _signal_material
			"DispatcherRadar":
				mi.material_override = _material
				if model == null:
					_radar = mi
	_mouth = _sockets.get("drop_mouth", _mouth)


func _fallback_body() -> void:
	var pivot := _visual_parent()
	_box(BODY_SIZE * 0.95, Palette.VERDIGRIS, Vector3.ZERO, 0.0, pivot)
	_cylinder(0.4, 3.0, Palette.CHARCOAL, Vector3(0.0, -0.2, -2.0), 0.0, pivot).rotation.x = PI * 0.5
	var lamp := _box(Vector3(0.5, 0.5, 0.5), Palette.BRASS, Vector3(0.0, 1.6, 0.0), 0.0, pivot)
	_signal_material = lamp.material_override as StandardMaterial3D


static func _parts() -> Array:
	if not _shared.is_empty():
		return _shared
	if not _model_checked:
		_model_checked = true
		_packed_model = load(MODEL) as PackedScene if ResourceLoader.exists(MODEL) else null
	if _packed_model == null:
		_asset_warning()
		return []
	var scene := _packed_model.instantiate() as Node3D
	var parts: Array = []
	for part in ["DispatcherBody", "DispatcherRadar", "DispatcherSignal"]:
		var mi := scene.find_child(part, true, false) as MeshInstance3D
		if mi == null or mi.mesh == null:
			scene.free()
			_asset_warning()
			return []
		parts.append({"name": part, "mesh": mi.mesh, "xform": _in_scene(mi, scene)})
	for socket in ["drop_mouth", "Beacon", "RadarPivot", "perch_foot"]:
		var node := scene.find_child(socket, true, false) as Node3D
		if node != null:
			_sockets[socket] = _in_scene(node, scene).origin
	scene.free()
	_shared = parts
	return _shared


static func _in_scene(node: Node3D, scene: Node3D) -> Transform3D:
	var xform := node.transform
	var ancestor := node.get_parent()
	while ancestor != scene and ancestor is Node3D:
		xform = (ancestor as Node3D).transform * xform
		ancestor = ancestor.get_parent()
	return xform


static func _asset_warning() -> void:
	if not _asset_warned:
		_asset_warned = true
		push_warning("dispatcher: missing or malformed model; using fallback body")


func _perch() -> void:
	var foot := global_position
	var ground: float = terrain.height(foot.x, foot.z) if terrain != null else foot.y
	if spec.has("perch"):
		perch_top = spec["perch"]
	else:
		perch_top = Vector3(foot.x, ground + PERCH_HEIGHT, foot.z)
		_build_mast(perch_top.y - ground)
	global_position = perch_top + Vector3.UP * FLOOR_DROP


func _build_mast(height: float) -> void:
	mast = StaticBody3D.new()
	mast.name = "DispatchMast"
	mast.collision_layer = 1
	mast.collision_mask = 0
	add_child(mast)
	mast.position = Vector3(0.0, -FLOOR_DROP, 0.0)
	var column := CollisionShape3D.new()
	column.shape = _get_column_shape(height)
	column.position = Vector3(0.0, -height * 0.5, 0.0)
	mast.add_child(column)
	var deck := CollisionShape3D.new()
	deck.shape = _get_deck_shape()
	deck.position = Vector3(0.0, -DECK_SIZE.y * 0.5, 0.0)
	mast.add_child(deck)
	var meshes := _get_mast_meshes(height)
	var frame := MeshInstance3D.new()
	frame.name = "MastFrame"
	frame.mesh = meshes["frame"]
	frame.material_override = _mast_charcoal
	mast.add_child(frame)
	if meshes["rungs"] != null:
		var rungs_view := MeshInstance3D.new()
		rungs_view.name = "MastRungs"
		rungs_view.mesh = meshes["rungs"]
		rungs_view.material_override = _mast_rust
		mast.add_child(rungs_view)


func perch_height() -> float:
	return perch_top.y - terrain.height(perch_top.x, perch_top.z) if terrain != null else 0.0


func knock(direction: Vector3, force: float) -> void:
	if _dead or direction.length_squared() < 0.0001:
		return
	if force > 0.0:
		ignored_seconds = 0.0
	knocks += 1
	var push := Vector3(direction.x, 0.0, direction.z).normalized() * force / weight
	if push.length() > _knocked_speed():
		_knock = push


func _physics_process(delta: float) -> void:
	if not _dead and _in_play() and target != null and not is_instance_valid(_return_pod):
		if _flat_to_ball().length() <= attack_range:
			ignored_seconds += delta
	super(delta)
	if not _dead and _flush_active and phase == Phase.WARN and _t >= FLUSH_SIREN and not _pod_returned and is_instance_valid(_pod):
		_check_cargo_ram()


func _move(delta: float, _desired: Vector3) -> void:
	velocity = Vector3.ZERO
	_knock = _knock.move_toward(Vector3.ZERO, KNOCK_DECAY * delta)


func _roam(_to_ball: Vector3) -> Vector3:
	return Vector3.ZERO


func standing_adds() -> int:
	var kept: Array = []
	for add in adds:
		if is_instance_valid(add) and not add.is_dead():
			kept.append(add)
	adds = kept
	return adds.size()


func _flush_ready() -> bool:
	return ignored_seconds >= FLUSH_IGNORE_S


func _wants_attack(to_ball: Vector3) -> bool:
	if is_instance_valid(_return_pod):
		return false
	return to_ball.length() <= attack_range and (standing_adds() < ADD_CAP or _flush_ready()) and fleet != null and fleet.combat != null


func _commit(to_ball: Vector3) -> Node3D:
	_face(to_ball)
	_flush_active = _flush_ready()
	_pod_returned = false
	_siren_fx_t = 0.0
	warn_seconds = FLUSH_WARN if _flush_active else WARN
	var aim := _ball()
	var landing: Vector3 = terrain.drop_point(aim.x, aim.z, 0.0) if terrain != null else aim
	var ring_radius := FLUSH_RADIUS if _flush_active else DROP_RADIUS
	var flight_s := FLUSH_FLIGHT if _flush_active else FLIGHT
	var ring := _commit_ring(Threat.Type.PROJECTILE, landing, ring_radius, 3.5)
	_pod_from = to_global(_mouth)
	ring.set_flight(_pod_from, Threat.lob_bump(GRAVITY, flight_s))
	if _flush_active and world_root != null and is_inside_tree():
		FxLibrary.burst(world_root, "steam_puff", _pod_from, 10)
	return ring


func _voice(tele: Node3D) -> void:
	super(tele)
	tele.warn_seconds = FLUSH_WARN if _flush_active else WARN
	var cues = _get_special_cues()
	if cues != null:
		cues.tell(self)
	else:
		special_tell.emit("tell")


func _face(to_ball: Vector3) -> void:
	if to_ball.length() > 0.5:
		rotation.y = atan2(-to_ball.x, -to_ball.z)


class ReturningCargoPod extends Node3D:
	var dispatcher_ref: WeakRef
	var pod_node: MeshInstance3D
	var from_pos := Vector3.ZERO
	var to_pos := Vector3.ZERO
	var flight := 0.35
	var _age := 0.0

	func _physics_process(delta: float) -> void:
		var rig = dispatcher_ref.get_ref() if dispatcher_ref != null else null
		if rig == null or not is_instance_valid(rig) or rig.is_dead():
			queue_free()
			return
		_age = minf(_age + delta, flight)
		var u := clampf(_age / maxf(flight, 0.001), 0.0, 1.0)
		var eased := u * u
		var pos := from_pos.lerp(to_pos, eased)
		global_position = pos
		if is_instance_valid(pod_node):
			pod_node.rotate_x(TAU * 3.0 * delta)
		if _age >= flight:
			rig._on_cargo_pod_impact()
			queue_free()


func _check_cargo_ram() -> void:
	var player = _player()
	if player == null:
		return
	var ball := _real_ball()
	var pod_pos := _pod.global_position
	var flat_dist := Vector2(ball.x - pod_pos.x, ball.z - pod_pos.z).length()
	var dy := absf(ball.y - pod_pos.y)
	if flat_dist > CARGO_RAM_REACH or dy > CARGO_RAM_HEIGHT:
		return
	var speed: float = player.planar_velocity().length() if player.has_method("planar_velocity") else 0.0
	var fast_enough: bool = (player.has_method("speed_tier") and int(player.speed_tier()) >= SpeedTier.CRUISE) \
		or speed >= CARGO_RAM_SPEED or bool(player.kit.slamming) or bool(player.kit.hooked)
	if not fast_enough:
		return
	_return_cargo_pod()


func _return_cargo_pod() -> void:
	if _pod_returned or not is_instance_valid(_pod):
		return
	_pod_returned = true
	cargo_returns += 1
	var pod_pos := _pod.global_position
	var ret := ReturningCargoPod.new()
	ret.name = "ReturningCargoPod"
	ret.dispatcher_ref = weakref(self)
	ret.from_pos = pod_pos
	ret.to_pos = to_global(_mouth)
	ret.flight = CARGO_RETURN_FLIGHT
	world_root.add_child(ret)
	ret.global_position = pod_pos
	var moved_pod := _pod
	_pod = null
	if moved_pod.get_parent() != null:
		moved_pod.get_parent().remove_child(moved_pod)
	moved_pod.position = Vector3.ZERO
	moved_pod.material_override = Palette.solid(Palette.AMBER, 1.6)
	ret.add_child(moved_pod)
	ret.pod_node = moved_pod
	_return_pod = ret
	if world_root != null and is_inside_tree():
		FxLibrary.burst(world_root, "brass_spark", pod_pos, 16)
		FxLibrary.burst(world_root, "steam_puff", pod_pos, 8)
	cargo_returned.emit(self)
	_end()


func _on_cargo_pod_impact() -> void:
	_return_pod = null
	if _dead:
		return
	if fleet != null:
		fleet.discover("stream_cut", global_position)
	if world_root != null and is_inside_tree():
		FxLibrary.burst(world_root, "plate_chunks", global_position, 14)
		FxLibrary.burst(world_root, "brass_spark", global_position, 16)
		FxLibrary.burst(world_root, "steam_puff", global_position, 10)
	take_damage(maxf(hp, max_hp) + 100.0)


func _go_live() -> void:
	drops += 1
	_free_pod()
	var ring := telegraph()
	if ring == null:
		return
	var landing: Vector3 = ring.center
	if _flush_active:
		cargo_flushes += 1
		ignored_seconds = 0.0
		if ring.contains(_real_ball()):
			landed_hits += 1
			var out: Vector3 = _real_ball() - landing
			out.y = 0.0
			var dir := out.normalized() if out.length() > 0.1 else -global_basis.z
			hit_player.emit(FLUSH_DAMAGE, dir * FLUSH_SHOVE + Vector3.UP * 4.0)
		if world_root != null and is_inside_tree():
			FxLibrary.burst(world_root, "slam_dust", landing, 14)
			FxLibrary.burst(world_root, "brass_spark", landing + Vector3.UP * 0.4, 12)
		if standing_adds() < ADD_CAP:
			var add: Node3D = fleet.combat.spawn_enemy("chaser", landing + Vector3.UP * 1.2)
			if add != null:
				if "_rest" in add:
					add._rest = 0.0
				add.scrap_value = 0
				add.set_meta("dispatched_by", get_instance_id())
				adds.append(add)
				dispatched.emit(add)
		return
	if ring.contains(_real_ball()):
		landed_hits += 1
		var out: Vector3 = _real_ball() - landing
		out.y = 0.0
		var dir := out.normalized() if out.length() > 0.1 else -global_basis.z
		hit_player.emit(float(ESCALATION[escalation]["damage"]), dir * DROP_SHOVE + Vector3.UP * 3.0)
	var add: Node3D = fleet.combat.spawn_enemy(String(ESCALATION[escalation]["kind"]), landing + Vector3.UP * 1.2)
	if not _hit_since_drop:
		_escalate(mini(escalation + 1, ESCALATION.size() - 1))
	_hit_since_drop = false
	if add == null:
		return
	if "_rest" in add:
		add._rest = 0.0
	add.scrap_value = 0
	add.set_meta("dispatched_by", get_instance_id())
	adds.append(add)
	dispatched.emit(add)


func take_damage(amount: float) -> float:
	if amount > 0.0 and not _dead:
		ignored_seconds = 0.0
		_hit_since_drop = true
		_escalate(maxi(escalation - 1, 0))
	return super(amount)


func _escalate(step: int) -> void:
	var before := rest_seconds
	escalation = step
	rest_seconds = float(ESCALATION[step]["every"]) - WARN - live_seconds
	if phase == Phase.ROAM and rest_seconds > before:
		_rest += rest_seconds - before


func _on_end() -> void:
	_flush_active = false
	_pod_returned = false
	warn_seconds = WARN
	_free_pod()


func _die() -> void:
	if (drops > 0 or cargo_returns > 0) and fleet != null:
		fleet.discover("stream_cut", global_position)
	super()


func _free_pod() -> void:
	if is_instance_valid(_pod):
		_pod.queue_free()
	_pod = null


func _pose() -> void:
	if _radar != null:
		_radar.rotate_y(RADAR_TURN * get_physics_process_delta_time())
	var warn := phase == Phase.WARN
	var suck_s := FLUSH_SIREN if _flush_active else SUCK
	var flight_s := FLUSH_FLIGHT if _flush_active else FLIGHT
	if _signal_material != null:
		if warn and _flush_active:
			_signal_material.emission_enabled = true
			_signal_material.emission = Palette.HAZARD
			var pulse := 0.5 + 0.5 * sin(_t * TAU * 4.0)
			_signal_material.emission_energy_multiplier = FlashGuard.spike(0.8, 3.2 * pulse)
		else:
			_signal_material.emission_enabled = warn or escalation > 0
			_signal_material.emission = Palette.AMBER
			_signal_material.emission_energy_multiplier = FlashGuard.spike(0.6 * escalation, 2.5 * clampf(_t / SUCK, 0.0, 1.0)) if warn else 0.6 * escalation
	if warn and _flush_active and _t < suck_s:
		_siren_fx_t += get_physics_process_delta_time()
		if _siren_fx_t >= 0.35 and world_root != null and is_inside_tree():
			_siren_fx_t = 0.0
			FxLibrary.burst(world_root, "steam_puff", to_global(_mouth), 6)
	if not warn or _t < suck_s or _pod_returned:
		return
	var ring := telegraph()
	if ring == null:
		return
	if _pod == null:
		_pod = MeshInstance3D.new()
		_pod.name = "DispatchPod"
		_pod.mesh = _get_pod_mesh()
		if _flush_active:
			_pod.scale = Vector3.ONE * 1.4
			_pod.material_override = Palette.solid(Palette.HAZARD, 1.0)
		else:
			_pod.material_override = _get_pod_mat()
		world_root.add_child(_pod)
		_pod_launch = Projectile.lob_velocity(_pod_from, ring.center, flight_s)
		if _flush_active:
			cargo_flushed.emit(_pod)
	var s := clampf(_t - suck_s, 0.0, flight_s)
	_pod.global_position = _pod_from + _pod_launch * s + Vector3.DOWN * 0.5 * GRAVITY * s * s


func _exit_tree() -> void:
	_free_pod()
	if is_instance_valid(_return_pod):
		_return_pod.queue_free()
	_return_pod = null
	super._exit_tree()

