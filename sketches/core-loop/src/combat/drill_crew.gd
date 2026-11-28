extends "res://src/combat/counter.gd"

const FloorRule := preload("res://src/combat/floor_rule.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")

const PLATING := 22.0
const HP := 90.0
const LEAD := 0.8
const BORE_RADIUS := 3.0
const BORE_DAMAGE := 11.0
const BORE_SHOVE := 7.0
const PRIMARY_WARN := 1.2
const PRIMARY_LIVE := 0.2

const JET_WARN := 0.90
const JET_LIVE := 0.55
const JET_LENGTH := 18.0
const JET_WIDTH := 2.6
const JET_DAMAGE := 10.0
const JET_SHOVE := 6.0
const JET_BLAST_RADIUS := 3.2
const JET_SAMPLE_STEP := 3.0

var plates := 1
var plates_popped := 0
var bores := 0
var stopped := 0
var core_jets := 0
var shortcuts_opened := 0
var next_attack := ""
var last_bore := {}
var last_jet := {}
var bore_fact := {}
var _core_jet := false
var _jet_origin := Vector3.ZERO
var _jet_dir := Vector3.FORWARD
var _jet_hit := false
var _plate: MeshInstance3D
var _bit: MeshInstance3D
var _bit_rest := Vector3.ZERO
static var _warned_asset := false
static var _shared: Array = []


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	plating = float(spec.get("plating", PLATING))
	scrap_value = 7
	weight = 2.6
	walk_speed = 3.0
	attack_range = 20.0
	warn_seconds = 1.2
	live_seconds = 0.2
	rest_seconds = 3.0
	interruptible = false


func _build_tool() -> void:
	var parts := _parts()
	if not parts.is_empty():
		_crew.free()
		_crew = null
		_base_color = Color.WHITE
		_material.albedo_color = _base_color
		_material.vertex_color_use_as_albedo = true
		for part in parts:
			var mi := MeshInstance3D.new()
			mi.name = part.name
			mi.mesh = part.mesh
			mi.transform = part.xform
			if part.flash >= 0:
				mi.set_surface_override_material(part.flash, _material)
			_visual_parent().add_child(mi)
			if part.name == "DrillPlate":
				_plate = mi
			elif part.name == "DrillBit":
				_bit = mi
				_bit_rest = mi.position
		return
	_box(Vector3(1.6, 0.9, 1.6), Palette.CHARCOAL, Vector3(0.0, 0.5, 1.3))
	_plate = _box(Vector3(2.2, 1.8, 0.25), Palette.BRASS, Vector3(0.0, 0.6, -1.0), 0.4)
	var bit := _cylinder(0.45, 2.4, Palette.HAZARD, Vector3(0.0, 0.5, 2.4), 0.6)
	bit.rotation.x = PI * 0.5


static func _parts() -> Array:
	if not _shared.is_empty():
		return _shared
	var path := "res://assets/models/world_two/enemy_drill_crew.glb"
	if not ResourceLoader.exists(path):
		return _shared
	var packed := load(path) as PackedScene
	if packed == null:
		return _shared
	var scene := packed.instantiate()
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh: Mesh = mi.mesh.duplicate()
		var flash := -1
		for i in mesh.get_surface_count():
			var surface_material := mesh.surface_get_material(i)
			if surface_material == null and not _warned_asset:
				_warned_asset = true
				push_warning("drill_crew: surface has no material; using default finish")
			var slot := surface_material.resource_name if surface_material != null else ""
			if slot == "fleet_paint":
				flash = i
			var painted := PaletteMaterials.solid(Color.WHITE)
			painted.vertex_color_use_as_albedo = true
			painted.metallic = 0.45 if slot == "working_tool" else (0.25 if slot == "part_state" else 0.0)
			painted.roughness = 0.5 if slot == "working_tool" else 0.82
			mesh.surface_set_material(i, painted)
		_shared.append({"name": mi.name, "mesh": mesh, "xform": mi.transform, "flash": flash})
	scene.free()
	return _shared


func _pose() -> void:
	if _bit == null:
		return
	var withdrawal := 0.0
	if not is_dead():
		if phase == Phase.WARN:
			withdrawal = clampf(_warn_progress(), 0.0, 1.0)
		elif phase == Phase.LIVE:
			withdrawal = 1.0 - clampf(_t / live_seconds, 0.0, 1.0)
	_bit.position = _bit_rest - Vector3(0.0, 0.0, 0.25 * withdrawal)


func absorbs_hit(result: Dictionary) -> bool:
	return bool(result.get("full", false)) and plates > 0


func _on_end() -> void:
	_core_jet = false
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	if _bit != null:
		_bit.position = _bit_rest


func _use_core_jet() -> bool:
	if next_attack == "core_jet":
		return true
	if next_attack == "bore":
		return false
	return bores > core_jets


func _commit(to_ball: Vector3) -> Node3D:
	var is_jet := _use_core_jet()
	_core_jet = is_jet
	next_attack = ""
	if is_jet:
		warn_seconds = JET_WARN
		live_seconds = JET_LIVE
		var flat := Vector3(to_ball.x, 0.0, to_ball.z)
		_jet_dir = flat.normalized() if flat.length() > 0.1 else Vector3.FORWARD
		_jet_origin = global_position
		_jet_hit = false
		_facing(_jet_dir)
		return _commit_lane(Threat.Type.LANE, global_position, _jet_dir, JET_LENGTH, JET_WIDTH, 3.0)
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	var aim: Vector3 = _ball() + target.planar_velocity() * LEAD
	_facing(aim - global_position)
	return _commit_ring(Threat.Type.INSTANT, aim, BORE_RADIUS, 2.0)


func _open_rubble_shortcuts() -> int:
	var opened := 0
	var destructibles = fleet.ctx.destructibles if fleet != null and fleet.ctx != null and "destructibles" in fleet.ctx else null
	if destructibles != null and is_instance_valid(destructibles) and destructibles.has_method("on_blast"):
		var before: int = destructibles.break_order().size() if destructibles.has_method("break_order") else 0
		var dist := JET_SAMPLE_STEP
		while dist <= JET_LENGTH + 0.01:
			var pt := _jet_origin + _jet_dir * minf(dist, JET_LENGTH)
			destructibles.on_blast(pt, JET_BLAST_RADIUS, "drill_core_jet", 5, 5)
			dist += JET_SAMPLE_STEP
		if destructibles.has_method("break_order"):
			opened += maxi(0, destructibles.break_order().size() - before)
	if is_inside_tree():
		for wall in get_tree().get_nodes_in_group("rubble_wall"):
			if not is_instance_valid(wall) or not (wall is Node3D) or wall.get_meta("shortcut_opened", false):
				continue
			var rel: Vector3 = (wall as Node3D).global_position - _jet_origin
			rel.y = 0.0
			var along := rel.dot(_jet_dir)
			if along < -1.0 or along > JET_LENGTH + 1.5:
				continue
			if (rel - _jet_dir * along).length() <= JET_WIDTH * 0.5 + 1.8:
				wall.set_meta("shortcut_opened", true)
				if wall.has_method("open_shortcut"):
					wall.open_shortcut("drill_core_jet")
				elif wall.has_method("shatter"):
					wall.shatter()
				else:
					wall.visible = false
					if wall is CollisionObject3D:
						(wall as CollisionObject3D).collision_layer = PhysicsLayers.NONE
						(wall as CollisionObject3D).collision_mask = PhysicsLayers.NONE
				opened += 1
	return opened


func _go_live() -> void:
	if _core_jet:
		core_jets += 1
		_jet_hit = false
		var opened := _open_rubble_shortcuts()
		shortcuts_opened += opened
		last_jet = {"from": _jet_origin, "dir": _jet_dir, "length": JET_LENGTH, "width": JET_WIDTH,
			"opened": opened, "frame": Engine.get_physics_frames()}
		if opened > 0 and fleet != null:
			fleet.discover("bore_breach", _jet_origin + _jet_dir * minf(6.0, JET_LENGTH))
		_jet_hit_check()
		return
	bores += 1
	var ring := telegraph()
	if ring == null:
		return
	last_bore = {"at": ring.center, "radius": BORE_RADIUS, "frame": Engine.get_physics_frames()}
	var ball := _real_ball()
	var player = _player()
	if not ring.contains(ball) or player == null or not FloorRule.on_floor(player.state):
		return
	var out: Vector3 = ball - ring.center
	out.y = 0.0
	var dir := out.normalized() if out.length() > 0.1 else Vector3.FORWARD
	hit_player.emit(BORE_DAMAGE, dir * BORE_SHOVE + Vector3.UP * 5.0)


func _live(_delta: float) -> bool:
	if _core_jet:
		_jet_hit_check()
	return true


func _jet_hit_check() -> void:
	if _jet_hit:
		return
	var tele := telegraph()
	if tele == null:
		return
	var player = _player()
	var ball := _real_ball()
	if player == null or not FloorRule.on_floor(player.state) or player.speed_tier() >= SpeedTier.CRUISE:
		return
	if tele.contains(ball):
		_jet_hit = true
		var side := _jet_dir.cross(Vector3.UP).normalized()
		hit_player.emit(JET_DAMAGE, side * JET_SHOVE + Vector3.UP * 4.0)


func on_struck(kind_hit: String, _part: String, result: Dictionary) -> void:
	if result.get("full", false) and plates > 0:
		plates -= 1
		plates_popped += 1
		_absorb = true
		if _plate != null:
			_plate.visible = false
	if kind_hit == "slam" and phase == Phase.WARN:
		stopped += 1
		if fleet != null:
			fleet.discover("bore_breach", _real_ball())
		_end()


# The popped plate took that hit whole: the body is untouched this once.
func _die() -> void:
	bore_fact = {"breached": true, "kind": "drill_crew", "id": "drill_%d" % get_instance_id(),
		"at": global_position, "radius": BORE_RADIUS, "last_bore": last_bore}
	super._die()
