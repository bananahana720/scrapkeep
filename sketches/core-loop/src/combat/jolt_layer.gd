extends "res://src/combat/counter.gd"

const AreaField := preload("res://src/combat/area_field.gd")

# The jolt layer (design-v3/FIELDS-AND-CASTS.md section 2.3): a Spillway crew under a cable
# spool that unrolls a live mat where the ball is going. The warning is an instant ring laid
# over the ball, the field the mat will cover. Live, the mat pulses every AreaField row
# `pulse` seconds; the ring fills over each pulse's lead so the jolt is read before it lands.
# A pulse that finds the ball rolling slow on the mat jolts it: charging gauges and casts drop
# with nothing spent and the specials and line skill jam for half a second. Speed (FAST tier),
# being in the air or a harpoon line attached lets the pulse pass. It never holds or slows
# the ball, and the weapon, the boost, the smash and Q stay open: a jolt costs a cast, not speed.
# Q can start inside a mat, but a jolt during its wind-up recalls it with a full refund.

const FIELD := "static_jam"
const HP := 45.0

var field = null
# Pulses that landed on the ball, and pulses it slipped by its own verb, for tests and the lab.
var jolts := 0
var slipped := 0
var recalls := 0

var _spool: MeshInstance3D
var _coil: MeshInstance3D
static var _warned_asset := false
static var _shared: Array = []


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.0
	warn_seconds = 1.0
	live_seconds = 3.7
	rest_seconds = 4.0
	attack_range = 22.0


func _build_tool() -> void:
	var parts := _parts()
	if not parts.is_empty():
		_crew.free()
		_crew = null
		for part in parts:
			var mi := MeshInstance3D.new()
			mi.name = part.name
			mi.mesh = part.mesh
			mi.transform = part.xform
			if part.flash >= 0:
				mi.set_surface_override_material(part.flash, _material)
			_visual_parent().add_child(mi)
			if part.name == "JoltCoil":
				_coil = mi
		return
	_spool = _cylinder(0.55, 0.5, Palette.CHARCOAL, Vector3(0.0, CREW_HALF + 0.9, -0.25))
	_spool.rotation.z = PI * 0.5
	_coil = _cylinder(0.12, 1.6, Palette.ARC, Vector3(0.0, CREW_HALF + 1.6, -0.25), 1.4)


# The model (tools/blender/world_one/enemy_jolt_layer.py), read once and shared: the body
# flashes on its fleet_paint surface, the coil is its own mesh so it can swell.
static func _parts() -> Array:
	if not _shared.is_empty():
		return _shared
	var path := "res://assets/models/world_one/enemy_jolt_layer.glb"
	if not ResourceLoader.exists(path):
		return _shared
	var packed := load(path) as PackedScene
	if packed == null:
		return _shared
	var scene := packed.instantiate()
	var painted := Palette.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh: Mesh = mi.mesh.duplicate()
		var flash := -1
		for i in mesh.get_surface_count():
			var surface_material := mesh.surface_get_material(i)
			if surface_material == null and not _warned_asset:
				_warned_asset = true
				push_warning("jolt_layer: surface has no material; using default finish")
			if surface_material != null and surface_material.resource_name == "fleet_paint":
				flash = i
			mesh.surface_set_material(i, painted)
		_shared.append({"name": mi.name, "mesh": mesh, "xform": mi.transform, "flash": flash})
	scene.free()
	return _shared


func _commit(_to_ball: Vector3) -> Node3D:
	var at := _ball()
	field = AreaField.new(FIELD, at, self)
	return _commit_ring(Threat.Type.INSTANT, at, field.radius(), 4.0)


func _live(delta: float) -> bool:
	var tele := telegraph()
	if tele == null or field == null:
		return false
	var pulsed: bool = field.step(delta)
	tele.set_progress(field.lead_fraction())
	if not pulsed:
		return true
	var player = _player()
	if player == null:
		return true
	match String(field.pulse_player(player, _real_ball())):
		"landed":
			jolts += 1
			flash()
			_recall_q()
		"speed", "air", "line":
			slipped += 1
	return true


# Q's wind-up is its cast: a jolt that lands during it recalls Q with a full refund (Andrew's
# "Big ones only", 2026-10-17 19:56:59Z).
func _recall_q() -> void:
	var combat = fleet.combat if fleet != null else null
	var ult = combat.ultimate if combat != null else null
	if ult != null and ult.winding_up():
		ult.recall()
		recalls += 1


func _on_end() -> void:
	field = null


func _pose() -> void:
	if _coil != null:
		var lead: float = field.lead_fraction() if field != null else 0.0
		_coil.scale = Vector3.ONE * (1.0 + 0.35 * lead)
	if _spool != null:
		_spool.rotation.x += 0.25 if phase == Phase.LIVE else 0.02
