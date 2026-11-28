extends "res://src/world/device.gd"

const ModelKit := preload("res://src/world/model_kit.gd")

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


func _init() -> void:
	family = "fight"


func build() -> void:
	_ring = null
	_cap = dress(self)
	if _cap == null:
		_build_greybox()


static func dress(parent: Node3D) -> MeshInstance3D:
	var parts := _parts()
	if parts.is_empty():
		return null
	ModelKit.attach_part(parts, "AltarPost", parent).material_override = finish(Palette.VERDIGRIS)
	ModelKit.attach_part(parts, "AltarBand", parent).material_override = _bone_material(true)
	var cap := ModelKit.attach_part(parts, "AltarCap", parent)
	cap.material_override = finish(Palette.BRASS)
	return cap


static func _parts() -> Array:
	return ModelKit.device_parts(MODEL, REQUIRED, "ambush_altar")


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
