extends "res://src/world/device.gd"

# An ambush altar, the opt-in fight family (LOOP-REDESIGN section 9): a copper post
# with a brass cap and bone band. Hold E and a pack arrives
# now, round the ring; clear it inside SECONDS and it pays a bonus core. While it runs
# the prompt's gauge is the time left; once it is done, it is spent for the stage.
# Nothing here stops the ball: the post has no collider and the pack comes to you.

const SECONDS := 30.0
const RING := 10.0
const BAND_SIZE := 1.42
const PACK := ["chaser", "chaser", "lobber"]

var running := false
var won := false
var pack: Array = []
var left := 0.0
var _ring: Node3D
var _cap: Node3D

const MODEL := "res://assets/models/world_one/ambush_altar.glb"
const REQUIRED := ["AltarPost", "AltarCap", "AltarBand", "AltarRing"]
static var _shared: Array = []
static var _loaded := false


func _init() -> void:
	family = "fight"


func build() -> void:
	_ring = null
	_cap = dress(self)
	if _cap == null:
		_build_greybox()


# The altar's model on parent: the verdigris post, its bone band and the brass cap, which is returned
# so its owner can turn or hide it. Null, with nothing built, when the model is missing; the park's
# altar sites (activities.gd) wear it too.
static func dress(parent: Node3D) -> MeshInstance3D:
	var parts := _parts()
	if parts.is_empty():
		return null
	_model_part(parts, "AltarPost", parent).material_override = finish(Palette.VERDIGRIS)
	_model_part(parts, "AltarBand", parent).material_override = _bone_material(true)
	var cap := _model_part(parts, "AltarCap", parent)
	cap.material_override = finish(Palette.BRASS)
	return cap


func _build_greybox() -> void:
	cylinder(0.45, 3.2, Vector3.UP * 1.6, Palette.solid(Palette.VERDIGRIS))
	_cap = box(Vector3(1.4, 0.6, 1.4), Vector3.UP * 3.5, Palette.solid(Palette.BRASS))
	box(Vector3(BAND_SIZE, 0.12, BAND_SIZE), Vector3.UP * 3.22, _bone_material(false), false)
	_ring = null


static func finish(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_texture = Palette.look_texture("rusted-salvaged-plate-worn", true)
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE / 4.0
	material.roughness = 0.82
	return material


static func _bone_material(dressed: bool) -> StandardMaterial3D:
	var material := finish(Palette.SAND) if dressed else StandardMaterial3D.new()
	material.resource_name = "altar_bone_band"
	material.albedo_color = Palette.SAND
	material.roughness = 0.82
	return material


func reach_point() -> Vector3:
	return global_position + Vector3.UP * 1.6


func ready_now() -> bool:
	return not spent and not running and ctx.spawner != null and ctx.spawner.has_method("spawn_enemy") and not ctx.calm


func gauge() -> float:
	return left / SECONDS if running else -1.0


func terms() -> String:
	return "core in %d s" % int(SECONDS)


func fire() -> bool:
	pack.clear()
	for i in PACK.size():
		var a := TAU * float(i) / PACK.size() + rotation.y
		var spot := global_position + Vector3(cos(a), 0.0, sin(a)) * RING
		var enemy = ctx.spawner.spawn_enemy(PACK[i], ctx.terrain.drop_point(spot.x, spot.z, 2.4))
		if enemy != null:
			pack.append(enemy)
	running = true
	left = SECONDS
	return true


func alive() -> int:
	var n := 0
	for enemy in pack:
		if is_instance_valid(enemy) and not (enemy.has_method("is_dead") and enemy.is_dead()):
			n += 1
	return n


func tick(delta: float) -> void:
	_cap.rotation.y += delta * (4.0 if running else 0.6)
	if not running:
		return
	left = maxf(0.0, left - delta)
	if alive() == 0:
		_end(true)
	elif left <= 0.0:
		_end(false)


func _end(cleared: bool) -> void:
	running = false
	spent = true
	won = cleared
	if _ring != null:
		_ring.visible = false
	if cleared:
		ctx.run.add_core("ambush", reach_point())
	ctx.events.ambush_ended.emit(id, cleared, reach_point())


static func _slot_material(slot: String) -> StandardMaterial3D:
	if slot not in ["device_concrete", "device_metal", "device_marks"]:
		return null
	var mat := Palette.solid(Color.WHITE)
	mat.resource_name = slot
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95 if slot == "device_concrete" else 0.85
	if slot == "device_metal":
		mat.roughness = 0.68
		mat.metallic = 0.28
	return mat


static func _parts() -> Array:
	if _loaded:
		return _shared
	_loaded = true
	var packed: PackedScene
	if ResourceLoader.exists(MODEL):
		packed = load(MODEL) as PackedScene
	if packed != null:
		var scene := packed.instantiate()
		if scene == null:
			push_warning("ambush_altar: %s cannot instantiate; keeping greybox" % MODEL)
			return _shared
		var valid := scene is Node3D
		var found := {}
		for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			if view.mesh == null or view.mesh.get_surface_count() == 0:
				valid = false
				break
			var mesh := view.mesh.duplicate() as Mesh
			for s in mesh.get_surface_count():
				var source := mesh.surface_get_material(s)
				var mat := _slot_material(String(source.resource_name)) if source != null else null
				var arrays := mesh.surface_get_arrays(s)
				if (mat == null or arrays.size() != Mesh.ARRAY_MAX
					or arrays[Mesh.ARRAY_VERTEX] == null or arrays[Mesh.ARRAY_VERTEX].is_empty()
					or arrays[Mesh.ARRAY_COLOR] == null or arrays[Mesh.ARRAY_COLOR].size() != arrays[Mesh.ARRAY_VERTEX].size()):
					valid = false
					break
				mesh.surface_set_material(s, mat)
			var xf := Transform3D.IDENTITY
			var walk: Node = view
			while walk != scene and walk != null:
				if walk is Node3D:
					xf = (walk as Node3D).transform * xf
				walk = walk.get_parent()
			found[String(view.name)] = true
			_shared.append({"name": String(view.name), "mesh": mesh, "xform": xf})
		valid = valid and found.size() == REQUIRED.size()
		for required in REQUIRED:
			valid = valid and found.has(required)
		scene.free()
		if not valid:
			_shared.clear()
	if _shared.is_empty():
		push_warning("ambush_altar: %s missing or malformed; keeping greybox" % MODEL)
	return _shared


static func _model_part(parts: Array, part_name: String, parent: Node3D) -> MeshInstance3D:
	for part in parts:
		if part.name == part_name:
			var view := MeshInstance3D.new()
			view.name = part.name
			view.mesh = part.mesh
			view.transform = part.xform
			parent.add_child(view)
			return view
	return null
