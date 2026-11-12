extends Node3D

const Palette := preload("res://src/core/palette.gd")

# How the off line looks and sounds (twin_lines.gd; docs/design/twin-lines.md, "How it reads").
# A prototype view: it draws itself from the twin's state and owns nothing else.
#
#   cable    sand at rest, so it never reads as the harpoon's live cable; it turns live while a
#            release would pay, fuller the more it would pay, and flickers rust as it frays
#   post     a small ring where the off line stands
#   pluck    a short plucked string when a release pays, a step higher for a fuller payment
#
#   halo     a thin live ring round the ball while the harpoon swings on the world with no off
#            line out and its release would pay, so the same read holds for the harpoon (its own
#            line keeps its own view, line_view.gd)

# The colour law (design-v3/LEGIBILITY.md): sand is neutral ink, live is "your verb works on
# this right now", rust is "you lost something".
const TWINE := Palette.SAND
const RUST := Palette.RUST
const RADIUS := 0.07
const RING := 0.6
# A pentatonic climb, in semitones over the root, by how full the payment was.
const STEPS := [0, 2, 4, 7, 9, 12]
const ROOT_HZ := 196.0
const PLUCK_S := 0.35
const RATE := 22050

var twin
var ball: RigidBody3D

var _cable: MeshInstance3D
var _post: MeshInstance3D
var _halo: MeshInstance3D
var _halo_material: StandardMaterial3D
var _material: StandardMaterial3D
var _voice: AudioStreamPlayer
var _plucks := {}


func _ready() -> void:
	top_level = true
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = TWINE
	var rod := CylinderMesh.new()
	rod.top_radius = RADIUS
	rod.bottom_radius = RADIUS
	rod.height = 1.0
	rod.radial_segments = 6
	rod.material = _material
	_cable = MeshInstance3D.new()
	_cable.mesh = rod
	_cable.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cable)
	var ring := TorusMesh.new()
	ring.inner_radius = RING * 0.75
	ring.outer_radius = RING
	ring.material = _material
	_post = MeshInstance3D.new()
	_post.mesh = ring
	add_child(_post)
	_halo_material = StandardMaterial3D.new()
	_halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_material.albedo_color = Palette.live()
	var halo := TorusMesh.new()
	halo.inner_radius = 1.25
	halo.outer_radius = 1.4
	halo.material = _halo_material
	_halo = MeshInstance3D.new()
	_halo.mesh = halo
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)
	_voice = AudioStreamPlayer.new()
	add_child(_voice)


func _process(_delta: float) -> void:
	if twin == null or not is_instance_valid(ball):
		return
	var from: Vector3 = ball.get_global_transform_interpolated().origin \
			if ball.is_inside_tree() and ball.get_tree().physics_interpolation else ball.global_position
	_cable.visible = twin.hooked
	_post.visible = twin.hooked
	_halo.visible = not twin.hooked and twin.pay > 0.0
	if _halo.visible:
		_halo.global_transform = Transform3D(Basis.IDENTITY, from)
		_halo_material.albedo_color = Color(Palette.live(), clampf(twin.pay, 0.0, 1.0))
	if not twin.hooked:
		return
	var to: Vector3 = twin.anchor
	var span := from.distance_to(to)
	if span < 0.01:
		return
	var up := (to - from) / span
	var side := up.cross(Vector3.UP)
	if side.length() < 0.01:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	var basis := Basis(side, up, side.cross(up)).orthonormalized()
	_cable.global_transform = Transform3D(basis.scaled_local(Vector3(1.0, span, 1.0)), (from + to) * 0.5)
	var face := Basis.looking_at(up, Vector3.UP if absf(up.y) < 0.99 else Vector3.RIGHT)
	_post.global_transform = Transform3D(face, to)
	_material.albedo_color = colour(twin.pay, twin.fraying(), Time.get_ticks_msec() / 1000.0)


# The cable's colour: sand, toward live by what a release would pay, and a rust flicker
# over the last stretch before it frays.
static func colour(pay: float, fray: float, now: float) -> Color:
	var c := TWINE.lerp(Palette.live(), clampf(pay, 0.0, 1.0))
	if fray > 0.0:
		var flick := 0.5 + 0.5 * sin(now * TAU * (4.0 + 8.0 * fray))
		c = c.lerp(RUST, fray * flick)
	return c


# A release paid `share` (0 to 1) of its most.
func released(share: float) -> void:
	if _voice == null:
		return
	var step: int = STEPS[clampi(roundi(share * (STEPS.size() - 1)), 0, STEPS.size() - 1)]
	if not _plucks.has(step):
		_plucks[step] = pluck(ROOT_HZ * pow(2.0, step / 12.0))
	_voice.stream = _plucks[step]
	_voice.volume_db = lerpf(-14.0, -6.0, share)
	_voice.play()


# A plucked string, Karplus-Strong: a burst of noise through a short averaging loop.
static func pluck(hz: float) -> AudioStreamWAV:
	var count := int(RATE * PLUCK_S)
	var period := maxi(2, int(RATE / hz))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hz * 1000.0)
	var loop := PackedFloat32Array()
	loop.resize(period)
	for i in period:
		loop[i] = rng.randf_range(-1.0, 1.0)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var at := 0
	for i in count:
		var next := (at + 1) % period
		var sample := loop[at]
		loop[at] = 0.498 * (loop[at] + loop[next])
		at = next
		var fade := 1.0 - float(i) / count
		bytes.encode_s16(i * 2, int(clampf(sample * fade, -1.0, 1.0) * 26000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
