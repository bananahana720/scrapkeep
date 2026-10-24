extends "res://src/combat/counter.gd"

# The drill crew (roster_dig.gd, world 2): a plated rig that bores where the ball will be.
# It aims at the ball plus its velocity times LEAD and commits an instant ring there; the
# floor caves in when the wind-up ends. Its plate takes the first breaking hit whole before
# the body (the plated brute's rule), and a slam on the rig during the wind-up stops the
# bore. It holds nothing. Dying leaves bore_fact, a read-only dict for the breach system.
# The cave-in only takes a ball on the floor (FloorRule, design-v3/WORLD-ROSTERS.md): a ball
# carving the bank or in the air over the ring is past it.

const FloorRule := preload("res://src/combat/floor_rule.gd")

const PLATING := 22.0
const HP := 90.0
const LEAD := 0.8
const BORE_RADIUS := 3.0
const BORE_DAMAGE := 11.0
const BORE_SHOVE := 7.0

var plates := 1
var plates_popped := 0
var bores := 0
var stopped := 0
var last_bore := {}
# Set by _die(): breach.gd reads enemy.bore_fact inside a died handler, where this node is
# still readable (the died signal fires before queue_free). Empty while the rig lives.
var bore_fact := {}
var _absorb := false
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
			var painted := Palette.solid(Color.WHITE)
			painted.vertex_color_use_as_albedo = true
			painted.metallic = 0.45 if slot == "working_tool" else (0.25 if slot == "part_state" else 0.0)
			painted.roughness = 0.5 if slot == "working_tool" else 0.82
			mesh.surface_set_material(i, painted)
		_shared.append({"name": mi.name, "mesh": mesh, "xform": mi.transform, "flash": flash})
	scene.free()
	return _shared


# E20 reads the same WARN clock as the committed floor ring; only the screw moves.
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


# True when on_struck will pop a plate for this hit, so it removes nothing (combat marks the
# result "absorbed" before the hit is announced, and no damage number rises for it).
func absorbs_hit(result: Dictionary) -> bool:
	return bool(result.get("full", false)) and plates > 0


func _on_end() -> void:
	if _bit != null:
		_bit.position = _bit_rest


func _commit(_to_ball: Vector3) -> Node3D:
	var aim: Vector3 = _ball() + target.planar_velocity() * LEAD
	_facing(aim - global_position)
	return _commit_ring(Threat.Type.INSTANT, aim, BORE_RADIUS, 2.0)


func _go_live() -> void:
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
func take_damage(amount: float) -> float:
	if _absorb:
		_absorb = false
		flash()
		return 0.0
	return super.take_damage(amount)


func _die() -> void:
	bore_fact = {"breached": true, "kind": "drill_crew", "id": "drill_%d" % get_instance_id(),
		"at": global_position, "radius": BORE_RADIUS, "last_bore": last_bore}
	super._die()
