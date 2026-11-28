extends "res://src/combat/counter.gd"

const CUES := "res://src/combat/special_cues.gd"
const POD := "splitter_pod"
const SpecialRig := preload("res://src/presentation/special_rig.gd")
const BODY_GLB := "res://assets/models/world_one/enemy_splitter.glb"

signal special_tell(moment: String)

const HP := 140.0
const SCRAP := 6
const WEIGHT := 2.0
const BODY_RADIUS := 1.3
const BODY_HALF := 1.35
const WALK := 6.0
const NEAR := 7.0
const FAR := 13.0
const BUD_FIRST := 1.2
const BUD_EVERY := 4.0
const BUD_STEP := 0.5
const BUD_FASTEST := 1.5
const POD_CAP := 4
const CLEAN_RANGE := 15.0
const CLEAN_KINDS := ["stomp", "slam"]
const POP_DELAY := 0.4
const SPLIT_PODS := 3
const POD_SPREAD := 2.1
const SEAM_IDLE := 0.4
const SEAM_FLARE := 4.0
const SEAM_WHITE := Color("f4efe2")
const SEAM_BRASS := Palette.BRASS
const PENDING := "enemy_pending"

var split := false
var buds := 0
var _bud_clock := BUD_FIRST
var _flare_left := 0.0
var _pods: Array = []
var _last_hit := {}
var _seam_material: StandardMaterial3D


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = SCRAP
	weight = WEIGHT
	walk_speed = WALK
	keep_near = NEAR
	keep_far = FAR


func _roam(to_ball: Vector3) -> Vector3:
	return Vector3.ZERO if _flare_left > 0.0 else super(to_ball)


func _wants_attack(_to_ball: Vector3) -> bool:
	return false


func _physics_process(delta: float) -> void:
	super(delta)
	if _dead or not _in_play() or target == null:
		return
	_pods = _pods.filter(func(pod): return is_instance_valid(pod) and not pod.is_dead())
	if _flare_left > 0.0:
		_flare_left -= delta
		if _flare_left <= 0.0:
			_bud()
	elif not stunned():
		_bud_clock -= delta
		if _bud_clock <= 0.0 and _pods.size() < POD_CAP:
			_flare_left = POP_DELAY
			if ResourceLoader.exists(CUES):
				load(CUES).tell(self)
			else:
				special_tell.emit("tell")


func _bud() -> void:
	_bud_clock = bud_interval(buds + 1)
	if fleet == null or fleet.combat == null:
		return
	var to_ball := _flat_to_ball()
	var out := to_ball.normalized() if to_ball.length() > 0.1 else Vector3.FORWARD
	var pod: Node3D = fleet.combat.spawn_enemy(POD, global_position + out * POD_SPREAD)
	if pod == null:
		return
	buds += 1
	_pods.append(pod)
	_join_pack(pod, int(get_meta("pack_seq", -1)))
	pod.knock(out, 5.0)


static func _join_pack(pod: Node3D, pack: int) -> void:
	if pack >= 0:
		pod.set_meta("pack_seq", pack)


static func bud_interval(count: int) -> float:
	return maxf(BUD_FASTEST, BUD_EVERY - BUD_STEP * (count - 1))


func pods() -> Array:
	return _pods.filter(func(pod): return is_instance_valid(pod) and not pod.is_dead())


func _build_crew() -> void:
	radius = BODY_RADIUS
	half_height = BODY_HALF
	_add_capsule(BODY_RADIUS, BODY_HALF * 2.0, Palette.RUST).free()
	_seam_material = PaletteMaterials.solid(SEAM_BRASS, SEAM_IDLE)
	var parts := body_parts()
	var model := SpecialRig.seat(self, _visual_parent(), BODY_GLB, "splitter")
	for part in parts["meshes"]:
		var mi: MeshInstance3D = model.find_child(part.name, true, false) as MeshInstance3D if model != null else null
		if mi == null:
			mi = MeshInstance3D.new()
			mi.name = part.name
			mi.mesh = part.mesh
			mi.transform = part.xform
			_visual_parent().add_child(mi)
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, _material if part.paint else _seam_material)
		if part.paint:
			_crew = mi
	_base_color = Color.WHITE
	_material.albedo_color = _base_color
	_material.vertex_color_use_as_albedo = true


static var _parts := {}


static func parts(path: String) -> Dictionary:
	if not _parts.has(path):
		_parts[path] = _read(path)
	return _parts[path]


static func _read(path: String) -> Dictionary:
	var out := {"meshes": [], "sockets": {}}
	var scene := (load(path) as PackedScene).instantiate()
	var painted := PaletteMaterials.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	for node in scene.find_children("*", "", true, false):
		if node is MeshInstance3D:
			var mesh: Mesh = (node as MeshInstance3D).mesh.duplicate()
			var surface := mesh.surface_get_material(0)
			var paint := surface != null and surface.resource_name == "fleet_paint"
			for i in mesh.get_surface_count():
				mesh.surface_set_material(i, painted)
			out["meshes"].append({"name": String(node.name), "mesh": mesh, "xform": node.transform, "paint": paint})
		elif node is Node3D:
			out["sockets"][String(node.name)] = (node as Node3D).transform
	scene.free()
	return out


static func body_parts() -> Dictionary:
	return parts(BODY_GLB)


func pod_offsets() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var sockets: Dictionary = body_parts()["sockets"]
	for i in SPLIT_PODS:
		var name := "pod_" + "abc"[i]
		var angle := TAU * i / SPLIT_PODS
		var flat := Vector3(cos(angle), 0.0, sin(angle))
		if sockets.has(name):
			var at: Vector3 = global_basis * (sockets[name] as Transform3D).origin
			at.y = 0.0
			if at.length() > 0.01:
				flat = at.normalized()
		out.append(flat * POD_SPREAD)
	return out


func _pose() -> void:
	if _seam_material == null:
		return
	var flare := 1.0 - clampf(_flare_left / POP_DELAY, 0.0, 1.0) if _flare_left > 0.0 else 0.0
	_seam_material.albedo_color = SEAM_BRASS.lerp(SEAM_WHITE, FlashGuard.whiten(flare))
	_seam_material.emission = _seam_material.albedo_color
	_seam_material.emission_energy_multiplier = FlashGuard.spike(SEAM_IDLE, lerpf(SEAM_IDLE, SEAM_FLARE, flare))


func on_struck(kind: String, _part: String, _result: Dictionary) -> void:
	var ball := _real_ball()
	_last_hit = {"kind": kind, "range": Vector2(ball.x - global_position.x, ball.z - global_position.z).length(),
		"frame": Engine.get_physics_frames()}


static func clean_kill(hit_kind: String, hit_range: float) -> bool:
	return hit_kind in CLEAN_KINDS or hit_range >= CLEAN_RANGE


func _die() -> void:
	var fresh: bool = not _last_hit.is_empty() and Engine.get_physics_frames() == int(_last_hit["frame"])
	split = fresh and not clean_kill(String(_last_hit["kind"]), float(_last_hit["range"]))
	set_meta("split", split)
	var at := global_position
	if not split and fresh and fleet != null:
		fleet.discover("split_pop", at)
	var offsets := pod_offsets()
	super()
	if split and fleet != null and fleet.combat != null and world_root != null:
		var pop := Pop.new()
		pop.combat = fleet.combat
		pop.offsets = offsets
		pop.pack = int(get_meta("pack_seq", -1))
		world_root.add_child(pop)
		pop.global_position = at


class Pop extends Node3D:
	var combat
	var pack := -1
	var offsets: Array[Vector3] = []
	var _left := POP_DELAY
	var _shell: MeshInstance3D

	func _ready() -> void:
		add_to_group(PENDING)
		if is_instance_valid(combat) and combat.ctx != null:
			combat.ctx.events.stage_content_cleared.connect(_on_cleared)
		var sphere := SphereMesh.new()
		sphere.radius = BODY_RADIUS * 1.1
		sphere.height = BODY_RADIUS * 2.2
		_shell = MeshInstance3D.new()
		_shell.mesh = sphere
		_shell.material_override = PaletteMaterials.solid(SEAM_WHITE, SEAM_FLARE * 2.0)
		add_child(_shell)

	func _on_cleared(_reason: String) -> void:
		set_physics_process(false)
		queue_free()

	func _physics_process(delta: float) -> void:
		_left -= delta
		_shell.scale = Vector3.ONE * lerpf(1.0, 1.3, 1.0 - _left / POP_DELAY)
		if _left > 0.0:
			return
		set_physics_process(false)
		var flow = combat.ctx.flow if is_instance_valid(combat) else null
		if flow != null and flow.in_stage():
			for offset in offsets:
				var pod: Node3D = combat.spawn_enemy(POD, global_position + offset)
				if pod == null:
					continue
				if pack >= 0:
					pod.set_meta("pack_seq", pack)
				pod.knock(offset, 6.0)
		queue_free()
