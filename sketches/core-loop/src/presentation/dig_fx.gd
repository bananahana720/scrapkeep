extends Node3D

const FxLibrary := preload("res://src/presentation/fx_library.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Kit := preload("res://src/presentation/world_fx/world_fx_kit.gd")
const RUPTURE_SECONDS := 0.45
const BURST_SECONDS := 0.85
const GRIT_REACH := 22.0
const GRIT_INTERVAL := 0.2
# Mutable only to exercise the missing-resource fallback without moving an asset.
const LAMP_SHADER_PATH := "res://assets/materials/dig_mechanical/lamp_motion.gdshader"
static var lamp_shader_path := LAMP_SHADER_PATH


static func reset_for_tests() -> void:
	lamp_shader_path = LAMP_SHADER_PATH

var available := false
var lamp_views: Array[MultiMeshInstance3D] = []
var faces: Array[Vector3] = []
var ruptures: Array = []
var bursts: Array = []
var grit: Array[GPUParticles3D] = []
var warning_count := 0
var active := true
var _stage_root: Node3D
var _map: RefCounted
var _shader: Shader
var _lamp_materials := {}
var _player
var _ctx
var _stage := 0
var _clock := 0.0
var _grit_wait := 0.0
var _ambient := true
var _grit_on := true
var _frozen := false
var _played := {}


func prepare(stage_root: Node3D, map: RefCounted) -> void:
	_stage_root = stage_root
	_map = map
	if ResourceLoader.exists(lamp_shader_path):
		_shader = load(lamp_shader_path) as Shader
	if _shader != null:
		var uniforms := _shader.get_shader_uniform_list().map(func(row): return row["name"])
		available = uniforms.has("lens") and uniforms.has("spent") and _shader.code.contains("instance uniform float fx_time") \
			and _shader.code.contains("instance uniform bool motion_enabled")
	if not available:
		_warn_once("effect shader missing or malformed; breach covers keep the instant swap")


func finish_build() -> void:
	if available:
		for i in 2:
			var p := FxLibrary.build("dig_grit")
			p.name = "CutFaceGrit%d" % i
			p.set_instance_shader_parameter("tint", FxLibrary.colour("dig_grit", "breach_opened"))
			p.emitting = false
			add_child(p)
			grit.append(p)
	Kit.follow_quality(self)


func bind_context(ctx, stage: int) -> void:
	if _ctx == null:
		_ctx = ctx
		_stage = stage
		_player = ctx.player
		ctx.events.world_fact.connect(_on_world_fact)
		ctx.events.stage_entered.connect(_on_stage_entered)
		ctx.events.stage_content_cleared.connect(_on_content_cleared)
		ctx.terrain.stage_freed.connect(_on_stage_freed)
	_on_stage_entered(stage, false)


# A freed park stage leaves a few nodes a frame (terrain's Reaper), so the lamp views and grit can
# be gone frames before this node is. It lets go of the run's signals the moment its stage is freed;
# a later entry builds a new DigFx on the rebuilt stage root.
func _on_stage_freed(stage: int) -> void:
	if stage != _stage:
		return
	for row in [[_ctx.events.world_fact, _on_world_fact], [_ctx.events.stage_entered, _on_stage_entered],
			[_ctx.events.stage_content_cleared, _on_content_cleared], [_ctx.terrain.stage_freed, _on_stage_freed]]:
		if row[0].is_connected(row[1]):
			row[0].disconnect(row[1])
	active = false
	set_process(false)


func _on_content_cleared(_reason: String) -> void:
	_deactivate()


func _on_stage_entered(stage: int, _retry: bool) -> void:
	clear()
	active = stage == _stage
	_sync_dressing()


func _deactivate() -> void:
	clear()
	active = false
	_sync_dressing()


func _sync_dressing() -> void:
	var low := Kit.low_preset()
	_ambient = available and active and Kit.dressing_share("dig_lamp_motion", low) > 0.0
	_grit_on = available and active and Kit.dressing_share("dig_cut_grit", low) > 0.0
	lamp_views = lamp_views.filter(is_instance_valid)
	grit = grit.filter(is_instance_valid)
	for view in lamp_views:
		view.set_instance_shader_parameter("motion_enabled", _ambient)
	for p in grit:
		p.emitting = false
		p.visible = _grit_on
	# Existing one-shots also shrink if the player selects low during a rupture.
	for burst in bursts:
		for p: GPUParticles3D in burst["node"].get_children():
			p.amount_ratio = _burst_count(String(p.get_meta("kind"))) / float(p.amount)
	set_process(available and active)


func lamp_material(slot: String, fallback: Material) -> Material:
	if not available or slot not in ["steel", "glass"]:
		return fallback
	if not _lamp_materials.has(slot):
		var material := ShaderMaterial.new()
		material.shader = _shader
		material.set_shader_parameter("lens", slot == "glass")
		_lamp_materials[slot] = material
	return _lamp_materials[slot]


func _on_world_fact(kind: String, at: Vector3) -> void:
	if kind != "breach_opened" or not active or not available or not "breach_plates" in _map:
		return
	for plate in _map.breach_plates:
		var rect: Rect2 = plate["rect"]
		if at.x >= rect.position.x and at.x <= rect.end.x and at.z >= rect.position.y and at.z <= rect.end.y:
			var id: String = plate["id"]
			var cover := _stage_root.get_node_or_null("BreachPlate_" + id) as Node3D
			# The world fact follows apply_swap. Read the committed cover state, never infer a break from a slam.
			if cover != null and not cover.visible and not _played.has(id):
				_rupture(id, cover, at)


func _rupture(id: String, cover: Node3D, at: Vector3) -> void:
	var skin := cover.get_node_or_null("BreachSkin") as Node3D
	if skin == null:
		return # The skin loader already warned and retained the old box.
	var wedges := skin.get_children().filter(func(n): return n is MeshInstance3D and n.get_meta("wedge", false))
	if wedges.size() != 3 or wedges.any(func(n): return n.mesh == null or n.material_override == null):
		_warn_once("breach skin missing or malformed; breach covers keep the instant swap")
		return
	_played[id] = true
	var ghost := skin.duplicate(0) as Node3D
	ghost.name = "DigRupture_" + id
	add_child(ghost)
	ghost.global_transform = _stage_root.global_transform * Transform3D(cover.basis, cover.get_meta("home")) * skin.transform
	var moving := []
	for view: MeshInstance3D in ghost.get_children():
		view.set_instance_shader_parameter("state_tint", Kit.dressing_colour("dig_spent"))
		if not view.get_meta("wedge", false):
			view.material_override = _spent_material()
			view.set_instance_shader_parameter("motion_enabled", false)
		if String(view.name).begins_with("tab_"):
			view.visible = false
		if view.get_meta("wedge", false):
			var outward := Vector3(view.position.x, 0, view.position.z).normalized()
			moving.append({"node": view, "rest": view.transform, "outward": outward})
	ruptures.append({"node": ghost, "wedges": moving, "age": 0.0})
	var burst := Node3D.new()
	burst.name = "DigBurst_" + id
	add_child(burst)
	# The fact's contact can be at any edge of the plate. Emit at that contact on its top surface.
	burst.global_position = Vector3(at.x, ghost.global_position.y, at.z)
	for kind: String in ["debris", "dust"]:
		var fx_id: String = "dig_" + kind
		var p := FxLibrary.build(fx_id)
		p.name = kind.capitalize()
		p.set_meta("kind", kind)
		burst.add_child(p)
		FxLibrary.fire(p, fx_id, "breach_opened", _burst_count(kind), burst.global_position + p.position)
		p.amount_ratio = _burst_count(kind) / float(p.amount)
	bursts.append({"node": burst, "age": 0.0})


func _spent_material() -> ShaderMaterial:
	if not _lamp_materials.has("spent"):
		var material := ShaderMaterial.new()
		material.shader = _shader
		material.set_shader_parameter("spent", true)
		material.set_shader_parameter("spent_tint", Kit.dressing_colour("dig_spent"))
		_lamp_materials["spent"] = material
	return _lamp_materials["spent"]


static func _burst_count(kind: String) -> int:
	return int(FxLibrary.effects("breach_opened", "low" if Kit.low_preset() else "")["dig_" + kind])


func _process(delta: float) -> void:
	if _frozen or not available or not active:
		return
	_clock += delta
	if _ambient:
		for view in lamp_views:
			view.set_instance_shader_parameter("fx_time", _clock)
	if _grit_on:
		_grit_wait -= delta
		if _grit_wait <= 0:
			_grit_wait = GRIT_INTERVAL
			_nearby_grit()
	for rupture in ruptures.duplicate():
		rupture["age"] += delta
		_pose(rupture, rupture["age"])
		if rupture["age"] >= RUPTURE_SECONDS:
			rupture["node"].queue_free()
			ruptures.erase(rupture)
	for burst in bursts.duplicate():
		burst["age"] += delta
		if burst["age"] >= BURST_SECONDS:
			burst["node"].queue_free()
			bursts.erase(burst)


static func _pose(rupture: Dictionary, seconds: float) -> void:
	var t := clampf(seconds / RUPTURE_SECONDS, 0, 1)
	var early := seconds <= 0.18
	var k := clampf(seconds / 0.18 if early else (seconds - 0.18) / 0.27, 0, 1)
	var drop := lerpf(0, 1.8, k) if early else lerpf(1.8, 7, k)
	var pitch := deg_to_rad(lerpf(0, 55, k) if early else lerpf(55, 105, k))
	for wedge in rupture["wedges"]:
		var rest: Transform3D = wedge["rest"]
		var outward: Vector3 = wedge["outward"]
		var axis := Vector3(-outward.z, 0, outward.x)
		wedge["node"].transform = Transform3D(Basis(axis, pitch) * rest.basis,
			rest.origin + outward * 0.8 * t + Vector3.DOWN * drop)


func _nearby_grit() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var ball: Vector3 = _player.shown_position()
	var local_ball := to_local(ball)
	var nearest: Array[Vector3] = []
	for face in faces:
		if face.distance_squared_to(local_ball) <= GRIT_REACH * GRIT_REACH:
			nearest.append(face)
	nearest.sort_custom(func(a, b): return a.distance_squared_to(local_ball) < b.distance_squared_to(local_ball))
	for i in grit.size():
		var p := grit[i]
		var emit := i < nearest.size()
		if emit and (not p.emitting or p.position != nearest[i]):
			p.position = nearest[i]
			p.restart()
		p.emitting = emit


# Coordinator's deterministic mid-rupture pose. Call after 0.18 s of particle simulation
# to freeze the live dust too; it never moves a cover or pauses gameplay.
func freeze_rupture(seconds: float = 0.18) -> void:
	_frozen = true
	for rupture in ruptures:
		rupture["age"] = seconds
		_pose(rupture, seconds)
	for burst in bursts:
		burst["age"] = seconds
		for p: GPUParticles3D in burst["node"].get_children():
			p.speed_scale = 0.0
	for p in grit:
		p.speed_scale = 0.0


func clear() -> void:
	for row in ruptures + bursts:
		if is_instance_valid(row["node"]):
			row["node"].free()
	ruptures.clear()
	bursts.clear()
	_played.clear()
	_frozen = false
	grit = grit.filter(is_instance_valid)
	for p in grit:
		p.emitting = false
		p.speed_scale = 1.0


func _warn_once(message: String) -> void:
	if warning_count == 0:
		warning_count += 1
		push_warning("dig_fx: " + message)
