extends Node3D

const Specs := preload("res://src/presentation/world_fx/world_fx_specs.gd")
const Kit := preload("res://src/presentation/world_fx/world_fx_kit.gd")
const Anchor := preload("res://src/presentation/world_fx/world_fx_anchor.gd")
const Word := preload("res://src/presentation/world_fx/world_fx_word.gd")

# World and event effects (WORLD-FX.md): the runtime. One per stage, installed with the world.
#   var fx := WorldFx.install(stage_root, world_index)   # ambient air for that world
#   fx.bind(camera, ball)                                 # the air follows them
#   WorldFx.fire("relay_full", at)                        # any system fires a hook, no reference needed
#   fx.set_overlay("storm_build")                         # a weather sky or modifier kind adds air
# Ambient emitters follow the camera (or the ball) with an identity basis, so the wind keeps its
# direction while the view turns. Anchors (WorldFxAnchor) register themselves; every RANK_SECONDS
# the nearest ANCHOR_SLOTS inside their lod_m emit and the rest rest or show an impostor.
const RANK_SECONDS := 0.25
const BURST_POOL := 2

static var current: Node3D

var world := -1
var low := false
var reduced_motion := false
var ambient: Array[GPUParticles3D] = []
var overlay: Array[GPUParticles3D] = []
var overlay_kind := ""
var _camera: Camera3D
var _ball: Node3D
var _bursts := {}
var _next := {}
var _rank_wait := 0.0


static func install(parent: Node, world_index: int, is_low := false, is_reduced := false) -> Node3D:
	var fx: Node3D = load("res://src/presentation/world_fx/world_fx.gd").new()
	fx.name = "WorldFx"
	fx.world = world_index
	fx.low = is_low
	fx.reduced_motion = is_reduced
	parent.add_child(fx)
	return fx


# Fire a hook through the installed WorldFx; a no-op when none is installed (menus, tests).
static func fire(hook: String, at: Vector3, tint := Color.TRANSPARENT) -> void:
	if is_instance_valid(current):
		current.play(hook, at, tint)


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	var set_id: String = Specs.WORLD_SETS.get(world, "")
	for id in Specs.SETS.get(set_id, []):
		ambient.append(_add(id))
	_sync()


func bind(camera: Camera3D, ball: Node3D) -> void:
	_camera = camera
	_ball = ball
	_follow()


func set_quality(is_low: bool, is_reduced: bool) -> void:
	low = is_low
	reduced_motion = is_reduced
	_sync()


# A weather sky id or a stage modifier kind (Specs.OVERLAYS); "" clears it.
func set_overlay(kind: String) -> void:
	for p in overlay:
		p.queue_free()
	overlay.clear()
	overlay_kind = kind
	for id in Specs.OVERLAYS.get(kind, []):
		overlay.append(_add(id))
	_sync()
	_follow()


func play(hook: String, at: Vector3, tint := Color.TRANSPARENT) -> void:
	var row: Dictionary = Specs.HOOKS.get(hook, {})
	if row.is_empty():
		push_warning("WorldFx: no hook %s" % hook)
		return
	for id in row["effects"]:
		var p := _burst(id)
		var share := Kit.share(Specs.SPECS[id], low, reduced_motion)
		if share <= 0.0:
			continue
		p.amount_ratio = share
		p.global_transform = Transform3D(Basis.IDENTITY, at)
		p.set_instance_shader_parameter("tint", tint if tint.a > 0.0 else Color.WHITE)
		p.restart()
		p.emitting = true
	if row["word"] != "" and not reduced_motion:
		Word.stamp(self, row["word"], at)


# Live particles this WorldFx can hold at once: ambient plus overlay plus the slotted anchors.
func live_ceiling() -> int:
	var total := 0
	for p in ambient + overlay:
		total += Kit.cost(p.get_meta("world_fx"), low, reduced_motion)
	return total


func _add(id: String) -> GPUParticles3D:
	var p := Kit.build(id)
	add_child(p)
	return p


func _burst(id: String) -> GPUParticles3D:
	if not _bursts.has(id):
		var pool: Array[GPUParticles3D] = []
		for i in BURST_POOL:
			pool.append(_add(id))
		_bursts[id] = pool
		_next[id] = 0
	var i: int = _next[id]
	_next[id] = (i + 1) % BURST_POOL
	return _bursts[id][i]


func _sync() -> void:
	for p in ambient + overlay:
		p.amount_ratio = Kit.share(Specs.SPECS[p.get_meta("world_fx")], low, reduced_motion)
		p.emitting = p.amount_ratio > 0.0
	for ref in Anchor.live:
		var a = ref.get_ref()
		if a != null:
			a.set_quality(low, reduced_motion)


func _process(delta: float) -> void:
	_follow()
	_rank_wait -= delta
	if _rank_wait <= 0.0:
		_rank_wait = RANK_SECONDS
		_rank()


func _follow() -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	var eye := _camera.global_position
	var yaw := Basis(Vector3.UP, _camera.global_rotation.y)
	var feet := _ball.global_position if is_instance_valid(_ball) else eye
	Kit.set_clear(feet)
	for p in ambient + overlay:
		var s: Dictionary = Specs.SPECS[p.get_meta("world_fx")]
		var offset: Vector3 = s.get("offset", Vector3.ZERO)
		if s["attach"] == "ball":
			p.global_position = feet + offset
		else:
			p.global_position = eye + yaw * offset


func _rank() -> void:
	Anchor.live = Anchor.live.filter(func(r): return r.get_ref() != null)
	if _camera == null or not is_instance_valid(_camera):
		return
	var eye := _camera.global_position
	var rows: Array = []
	for ref in Anchor.live:
		var a: Node3D = ref.get_ref()
		if a.is_inside_tree():
			rows.append([a.global_position.distance_to(eye), a])
	rows.sort_custom(func(x, y): return x[0] < y[0])
	var slots := Specs.ANCHOR_SLOTS
	for row in rows:
		var a = row[1]
		var within: bool = row[0] <= a.lod_m()
		a.set_range(row[0], within and slots > 0)
		if within:
			slots -= 1
