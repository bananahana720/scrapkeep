extends "res://src/combat/counter.gd"

const AreaField := preload("res://src/combat/area_field.gd")
const JoltAudio := preload("res://src/presentation/jolt_layer_audio.gd")

# The jolt layer (design-v3/FIELDS-AND-CASTS.md section 2.3): a Spillway crew under a cable
# spool that unrolls a live mat where the ball is going. The warning is an instant ring laid
# across the ball's line ahead (LAY_AHEAD), the field the mat will cover. Live, the mat pulses every AreaField row
# `pulse` seconds; the ring fills over each pulse's lead so the jolt is read before it lands.
# A pulse that finds the ball rolling slow on the mat jolts it: charging gauges and casts drop
# with nothing spent and the specials and line skill jam for half a second. Speed (FAST tier),
# being in the air or a harpoon line attached lets the pulse pass. It never holds or slows
# the ball, and the weapon, the boost, the smash and Q stay open: a jolt costs a cast, not speed.
# Q can start inside a mat, but a jolt during its wind-up recalls it with a full refund.
# Flow (design-v3/SPILLWAY-ROSTER.md): a mat laid on standing water spreads WET_SPREAD wider,
# because the water carries the current; slipping a pulse at speed is its codex trick.

const FIELD := "static_jam"
const HP := 45.0
const WET_SPREAD := 1.5
# W1-66 (gameplay critique finding 4): the mat is laid across the ball's line where its roll will carry
# it by the time the mat is live (warn_seconds on), at most LAY_AHEAD metres on, so a ball holding its
# line meets it live and the answer is a jump over it (or a turn off the line); speed still slips it.
const LAY_AHEAD := 12.0

var field = null
# Pulses that landed on the ball, and pulses it slipped by its own verb, for tests and the lab.
var jolts := 0
var slipped := 0
var recalls := 0

# The voice (JoltAudio): the presence loop, and the pulse whose tell has started.
var _presence: AudioStreamPlayer3D
var _told := -1
var _spool: MeshInstance3D
var _coil: MeshInstance3D
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
	_presence = JoltAudio.player("presence", self)
	if _presence != null:
		_presence.autoplay = true
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
	if _shared.is_empty():
		_shared = EnemyCasting.parts("res://assets/models/world_one/enemy_jolt_layer.glb", "jolt_layer")
	return _shared


func _commit(_to_ball: Vector3) -> Node3D:
	var at := _ahead(warn_seconds, LAY_AHEAD)
	field = AreaField.new(FIELD, at, self)
	if _on_water(at):
		field.spread = WET_SPREAD
	var ring: Node3D = _commit_ring(Threat.Type.INSTANT, at, field.radius(), 4.0)
	# The mat cannot jolt until its first pulse, 1.2 s after it goes live, so only pulses land
	# (assumption Andrew can overturn, 12 Nov 2026).
	if ring != null:
		ring.lands_on_live = false
	return ring


func _live(delta: float) -> bool:
	var tele := telegraph()
	if tele == null or field == null:
		return false
	var pulsed: bool = field.step(delta)
	tele.set_progress(field.lead_fraction())
	# The tell starts TELL_LEAD before each pulse that will go off inside the live window.
	if field.pulses != _told and field.until_pulse() <= JoltAudio.TELL_LEAD:
		_told = field.pulses
		_cue("tell")
	if not pulsed:
		return true
	# The lead fill restarts on every pulse and never reaches its end, so each pulse lands here.
	tele.land()
	var player = _player()
	if player == null:
		return true
	match String(field.pulse_player(player, _real_ball())):
		"landed":
			jolts += 1
			flash()
			_cue("jam")
			_recall_q()
		"speed", "air", "line":
			slipped += 1
			if fleet != null:
				fleet.discover("mat_slip", _real_ball())
	return true


func _on_water(at: Vector3) -> bool:
	return terrain != null and terrain.has_method("on_water") and terrain.on_water(at)


# Q's wind-up is its cast: a jolt that lands during it recalls Q with a full refund (Andrew's
# "Big ones only", 2026-10-17 19:56:59Z).
func _recall_q() -> void:
	var combat = fleet.combat if fleet != null else null
	var ult = combat.ultimate if combat != null else null
	if ult != null and ult.winding_up():
		ult.recall()
		recalls += 1
		_cue("fizzle")


func _on_end() -> void:
	field = null
	_told = -1


func _die() -> void:
	JoltAudio.one_shot("break", get_parent(), global_position)
	super._die()


func _cue(part: String) -> void:
	if is_inside_tree():
		JoltAudio.one_shot(part, get_parent(), global_position)


func _pose() -> void:
	if _coil != null:
		var lead: float = field.lead_fraction() if field != null else 0.0
		_coil.scale = Vector3.ONE * (1.0 + 0.35 * lead)
	if _spool != null:
		_spool.rotation.x += 0.25 if phase == Phase.LIVE else 0.02
