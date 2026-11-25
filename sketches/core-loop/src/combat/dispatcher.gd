extends "res://src/combat/counter.gd"

# The Dispatcher (design-v3/ENEMY-PRIORITY.md section 4, lever 4): a kill-first spawner. The
# cache chassis clamped to a perch 6 to 10 m up, fixed, and it never attacks with its body. Every
# DROP_EVERY seconds it fires one chaser down its pneumatic tube at the ball: the landing ring is
# committed with the tube's suck-up tell, the pod flies the drawn trace and lands on the ring's
# centre on the strike frame, and the landing hurts a ball the ring contains then. The pod opens
# into a chaser that comes out ready to lunge and carries no scrap, so the stream cannot be farmed.
#
# - A drop is an attack like any counter's: it asks the attacker budget (attack_budget.gd) first,
#   so the stream fills the cap rather than breaking it, and its warning keeps the 0.2 s gap to
#   any other threat. Its own chasers each ask again before they lunge.
# - It stops dropping while ADD_CAP of its chasers stand.
# - A hard hit in the suck-up breaks the drop (the counter's stagger window), so reaching it in
#   the wind-up is a play.
# - The perch: spec "perch" is a park high point's top (stage builders, lever 5). Without one it
#   brings its own dispatch mast, PERCH_HEIGHT tall, a world collider the harpoon can bite, so
#   reaching it means going up: grapple, vault or a long gun.
# - special_tell("tell") fires on the committed-telegraph frame (design-v3/MACHINE-VFX.md, the
#   specials contract), through SpecialCues.tell(self) once special_cues.gd is in the tree
#   (CONTRACTS.md "Special cues"); `dispatched` reports each chaser it lands.

const Projectile := preload("res://src/combat/projectile.gd")
# Loaded, not preloaded, until the special cues branch lands; then this becomes a preload.
const SPECIAL_CUES := "res://src/combat/special_cues.gd"

signal special_tell(moment: String)
signal dispatched(enemy: Node3D)

const SpecialRig := preload("res://src/presentation/special_rig.gd")
const MODEL := "res://assets/models/world_one/enemy_dispatcher.glb"
# A chaser's health: reaching it is the test, not grinding it down.
const HP := 60.0
const SCRAP := 8
# The perch band the design asks for, and the mast's height when no park perch is given.
const PERCH_MIN := 6.0
const PERCH_MAX := 10.0
const PERCH_HEIGHT := 8.0
const MAST_WIDTH := 1.6
const DECK_SIZE := Vector3(3.6, 0.3, 3.6)
# The model's floor sits on its clamp pads 1.5 m under its origin (enemy_dispatcher.py).
const FLOOR_DROP := 1.5
const BODY_SIZE := Vector3(2.9, 2.3, 2.9)
# Start values (ENEMY-PRIORITY lever 4): one chaser every 8 s. The ring sits where the ball is
# when the drop is committed, with no lead: rolling off it beats it at any speed, and a ball
# circling under the perch gets hit (a lead missed a curving ball by 9 m on the median in the lab).
const DROP_EVERY := 8.0
const FIRST_DROP := 2.0
const DROP_RANGE := 45.0
# The tell: the tube sucks up for SUCK seconds (dispatcher_tell's sweep), then the pod flies.
const SUCK := 0.45
const FLIGHT := 0.75
const WARN := SUCK + FLIGHT
const DROP_RADIUS := 4.0
const DROP_DAMAGE := 10.0
const DROP_SHOVE := 6.0
const ADD_CAP := 4
# Escalate (Andrew's card, 17 Oct): each drop landed with no hit on the Dispatcher since the
# last one climbs a step, so a Dispatcher left alone snowballs; each hit on it steps back
# down one. A step names the add the next pod opens into, the drop-to-drop interval and the
# landing's damage (a heavier pod).
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
var adds: Array = []
var perch_top := Vector3.ZERO
var mast: StaticBody3D

var _mouth := Vector3(0.0, -0.6, -3.4)
var _radar: Node3D
var _signal_material: StandardMaterial3D
var _pod: MeshInstance3D
var _pod_from := Vector3.ZERO
var _pod_launch := Vector3.ZERO
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


# Pre-warms shared GLB, Jolt shapes, mast geometry, pod mesh and cues once so Sinkhole
# Dispatcher spawns stay under the 8 ms frame budget instead of stalling on first spawn.
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
	weight = 4.0  # past the Tarn claw's largest tow limit (3.5); what a hit's interrupt is read against
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
	# On screen the glb's own scene stands in, so its idle, tell and break clips play (the
	# radar's turn is the clip's then); sockets, collider and signals are as before.
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


# A body that still reads as the Dispatcher if the model is missing: the box and the tube.
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


# A node's transform in the model's root space, read before the scene is in a tree.
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


# Puts the body on its perch: a park perch top from the spec, else its own mast where it spawned.
func _perch() -> void:
	var foot := global_position
	var ground: float = terrain.height(foot.x, foot.z) if terrain != null else foot.y
	if spec.has("perch"):
		perch_top = spec["perch"]
	else:
		perch_top = Vector3(foot.x, ground + PERCH_HEIGHT, foot.z)
		_build_mast(perch_top.y - ground)
	global_position = perch_top + Vector3.UP * FLOOR_DROP


# The dispatch mast: four legs, cross braces and a deck, one world collider (layer 1) so the
# ball and the harpoon meet it as terrain, not as the enemy. It stands as long as its Dispatcher.
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


# A hit never moves it, but one hard enough still breaks the drop: the knock is kept as the
# speed it would give a free body of its weight, for the counter's interrupt read only.
func knock(direction: Vector3, force: float) -> void:
	if _dead or direction.length_squared() < 0.0001:
		return
	knocks += 1
	var push := Vector3(direction.x, 0.0, direction.z).normalized() * force / weight
	if push.length() > _knocked_speed():
		_knock = push


# It never leaves its perch.
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


func _wants_attack(to_ball: Vector3) -> bool:
	return to_ball.length() <= attack_range and standing_adds() < ADD_CAP and fleet != null and fleet.combat != null


func _commit(to_ball: Vector3) -> Node3D:
	_face(to_ball)
	var aim := _ball()
	var landing: Vector3 = terrain.drop_point(aim.x, aim.z, 0.0) if terrain != null else aim
	var ring := _commit_ring(Threat.Type.PROJECTILE, landing, DROP_RADIUS, 3.5)
	_pod_from = to_global(_mouth)
	ring.set_flight(_pod_from, Threat.lob_bump(GRAVITY, FLIGHT))
	return ring


func _voice(tele: Node3D) -> void:
	super(tele)
	tele.warn_seconds = WARN
	var cues = _get_special_cues()
	if cues != null:
		cues.tell(self)
	else:
		special_tell.emit("tell")


func _face(to_ball: Vector3) -> void:
	if to_ball.length() > 0.5:
		rotation.y = atan2(-to_ball.x, -to_ball.z)


func _go_live() -> void:
	drops += 1
	_free_pod()
	var ring := telegraph()
	if ring == null:
		return
	var landing: Vector3 = ring.center
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
	# Out of the tube ready to go: its first lunge waits only on the attacker budget. It carries
	# no scrap, so the stream can never be farmed for mass (Isaac's spawner adds drop nothing).
	if "_rest" in add:
		add._rest = 0.0
	add.scrap_value = 0
	add.set_meta("dispatched_by", get_instance_id())
	adds.append(add)
	dispatched.emit(add)


# Each hit answers it one step, and a drop after any hit does not climb.
func take_damage(amount: float) -> float:
	if amount > 0.0 and not _dead:
		_hit_since_drop = true
		_escalate(maxi(escalation - 1, 0))
	return super(amount)


func _escalate(step: int) -> void:
	var before := rest_seconds
	escalation = step
	rest_seconds = float(ESCALATION[step]["every"]) - WARN - live_seconds
	# A step down between drops pushes the running countdown back now, not a cycle late.
	if phase == Phase.ROAM and rest_seconds > before:
		_rest += rest_seconds - before


func _on_end() -> void:
	_free_pod()


# Killed with its stream running: the trick fires and the chute goes quiet.
func _die() -> void:
	if drops > 0 and fleet != null:
		fleet.discover("stream_cut", global_position)
	super()


func _free_pod() -> void:
	if is_instance_valid(_pod):
		_pod.queue_free()
	_pod = null


# The tell on the body: the signal lamps light through the suck-up and the radar turns a quarter
# per beat; the pod leaves the tube at SUCK and flies the committed trace onto the ring's centre.
func _pose() -> void:
	if _radar != null:
		_radar.rotate_y(RADAR_TURN * get_physics_process_delta_time())
	var warn := phase == Phase.WARN
	if _signal_material != null:
		# Between drops the lamp holds a glow per escalation step, so a climbing Dispatcher reads.
		_signal_material.emission_enabled = warn or escalation > 0
		_signal_material.emission = Palette.AMBER
		_signal_material.emission_energy_multiplier = FlashGuard.spike(0.6 * escalation, 2.5 * clampf(_t / SUCK, 0.0, 1.0)) if warn else 0.6 * escalation
	if not warn or _t < SUCK:
		return
	var ring := telegraph()
	if ring == null:
		return
	if _pod == null:
		_pod = MeshInstance3D.new()
		_pod.name = "DispatchPod"
		_pod.mesh = _get_pod_mesh()
		_pod.material_override = _get_pod_mat()
		world_root.add_child(_pod)
		_pod_launch = Projectile.lob_velocity(_pod_from, ring.center, FLIGHT)
	var s := clampf(_t - SUCK, 0.0, FLIGHT)
	_pod.global_position = _pod_from + _pod_launch * s + Vector3.DOWN * 0.5 * GRAVITY * s * s


func _exit_tree() -> void:
	_free_pod()
	super._exit_tree()

