extends StaticBody3D

const Augments := preload("res://src/movement/augments.gd")
const WeakPoints := preload("res://src/boss/weak_points.gd")
const Palette := preload("res://src/core/palette.gd")

# One physical weak point of a boss fight (challenge lane, #241 step 2a): a hatch on a floor's rim, the pit's
# bore-head override, drawn after the art board (boss_weak_points set brief) in procedural boxes. It exists only when the boss's weak_points dial is
# on, and the boss (stub_boss.gd) owns it: it builds it, mirrors the rule's state onto it every tick, pays for
# its contacts, and frees it.
#
# It is a hookable body and nothing else. The harpoon bites a body in Augments.STAKE_GROUP on the stake layer
# (the same body-line route a Sable stake takes), so Ctrl commits the haul with no stagger needed. It is
# deliberately not in the "enemy" group: the director, the bot's target scan, the ultimate, the run record and
# the arena-clear count all read that group, and a part is none of those. It is hookable only while OPEN; a SHUT
# or BROKEN part sits on no layer, so the line's aim cannot pick it. It has no health, takes no damage, never
# dies and never attacks; a ball contact on it is paid to the Warden's bar by the boss.

# The sphere a ball must reach to touch the part: the part's own radius plus the ball's.
const REACH := 2.8
const GROUP := "weak_part"
const SIZE := Vector3(3.2, 2.4, 0.8)
# The art board (boss_weak_points set brief): petrol enamel cover with a bone rubbed edge, a charcoal border and
# cavity, ancient-green notches at the seat only, oxide wear on the failed couplings. Hazard and brass never appear.
const COVER := Palette.VERDIGRIS
const EDGE := Palette.SAND
const BORDER := Palette.CHARCOAL
const CAVITY := Palette.CHARCOAL
const WEAR := Palette.RUST
const NOTCH := Palette.ANCIENT
const NOTCH_ENERGY := 2.2
const NOTCH_COUNT := 8

var point_id := ""
var state := WeakPoints.SHUT
# enemy.gd's radius: the harpoon line's "passed" check reads it.
var radius := 1.8

var _cover: Node3D
var _cavity: MeshInstance3D
var _cavity_material: StandardMaterial3D
var _notches: Node3D
var _notch_material: StandardMaterial3D
var _wreck: Node3D
var _frame: Array = []


func setup(id: String, _facing: Vector3) -> void:
	point_id = id
	name = "WeakPart_%s" % id
	add_to_group(GROUP)
	add_to_group(Augments.STAKE_GROUP)
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var solid := BoxShape3D.new()
	solid.size = SIZE
	shape.shape = solid
	add_child(shape)
	# The part faces local -Z (look_at); the arena side is -Z, the recess +Z.
	_cavity_material = Palette.solid(CAVITY, 0.0, false)
	_cavity = _box("Cavity", SIZE, Vector3.ZERO, _cavity_material, self)
	for edge in [["Top", Vector3(3.8, 0.3, 0.7), Vector3(0.0, 1.35, -0.1)], ["Bottom", Vector3(3.8, 0.3, 0.7), Vector3(0.0, -1.35, -0.1)],
			["Left", Vector3(0.3, 2.4, 0.7), Vector3(-1.75, 0.0, -0.1)], ["Right", Vector3(0.3, 2.4, 0.7), Vector3(1.75, 0.0, -0.1)]]:
		_frame.append(_box("Frame" + edge[0], edge[1], edge[2], Palette.solid(BORDER, 0.0, false), self))
	_build_cover()
	_build_notches()
	_build_wreck()
	set_state(WeakPoints.SHUT)


static func _box(label: String, size: Vector3, at: Vector3, material: Material, parent: Node3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = label
	mi.mesh = mesh
	mi.material_override = material
	mi.position = at
	if parent != null:
		parent.add_child(mi)
	return mi


# SHUT: an intact petrol cover that stands a little proud, thin charcoal seams, a bone rubbed edge.
func _build_cover() -> void:
	_cover = Node3D.new()
	_cover.name = "Cover"
	_cover.position = Vector3(0.0, 0.0, -0.15)
	add_child(_cover)
	_box("Plate", SIZE, Vector3.ZERO, Palette.solid(COVER), _cover)
	var edge := Palette.solid(EDGE)
	_box("EdgeTop", Vector3(3.2, 0.1, 0.1), Vector3(0.0, 1.2, -0.4), edge, _cover)
	_box("EdgeBottom", Vector3(3.2, 0.1, 0.1), Vector3(0.0, -1.2, -0.4), edge, _cover)
	_box("EdgeLeft", Vector3(0.1, 2.4, 0.1), Vector3(-1.6, 0.0, -0.4), edge, _cover)
	_box("EdgeRight", Vector3(0.1, 2.4, 0.1), Vector3(1.6, 0.0, -0.4), edge, _cover)
	var seam := Palette.solid(BORDER, 0.0, false)
	_box("SeamH", Vector3(3.0, 0.06, 0.06), Vector3(0.0, 0.0, -0.4), seam, _cover)
	_box("SeamV", Vector3(0.06, 2.2, 0.06), Vector3(0.0, 0.0, -0.4), seam, _cover)


# OPEN: bright ancient-green notches ringed round the seat only; the cavity around them stays charcoal.
func _build_notches() -> void:
	_notches = Node3D.new()
	_notches.name = "Notches"
	_notches.position = Vector3(0.0, 0.0, -0.42)
	add_child(_notches)
	_notch_material = Palette.solid(NOTCH, NOTCH_ENERGY, false)
	for i in NOTCH_COUNT:
		var angle := TAU * float(i) / float(NOTCH_COUNT)
		var notch := _box("Notch%d" % i, Vector3(0.28, 0.28, 0.1), Vector3(cos(angle) * 0.6, sin(angle) * 0.6, 0.0), _notch_material, _notches)
		notch.rotation.z = angle


# BROKEN: the rim is discontinuous (a bar gone, one hanging) and two failed couplings stub out of a dark hole. No
# material here is lit.
func _build_wreck() -> void:
	_wreck = Node3D.new()
	_wreck.name = "Wreck"
	add_child(_wreck)
	var wear := Palette.solid(WEAR, 0.0, false)
	_box("StubA", Vector3(0.22, 0.22, 0.55), Vector3(-0.5, 0.3, -0.3), wear, _wreck).rotation = Vector3(0.0, 0.3, 0.4)
	_box("StubB", Vector3(0.18, 0.18, 0.4), Vector3(0.45, -0.35, -0.25), wear, _wreck).rotation = Vector3(0.2, -0.3, -0.5)
	_box("Grit", Vector3(0.9, 0.12, 0.5), Vector3(0.2, -1.05, -0.5), Palette.solid(Palette.SANDSTONE, 0.0, false), _wreck)


# Mirrors the rule's state: the cover shows only while SHUT, the notches light while OPEN, and BROKEN goes dark with
# a torn rim; only an OPEN part is on the stake layer the harpoon's ray reads.
func set_state(value: int) -> void:
	state = value
	collision_layer = Augments.STAKE_MASK if value == WeakPoints.OPEN else 0
	if _cover == null:
		return
	_cover.visible = value == WeakPoints.SHUT
	_cavity.visible = value != WeakPoints.SHUT
	_notches.visible = value == WeakPoints.OPEN
	_wreck.visible = value == WeakPoints.BROKEN
	_frame[3].visible = value != WeakPoints.BROKEN
	_frame[0].rotation.z = 0.22 if value == WeakPoints.BROKEN else 0.0
	_frame[0].position = Vector3(-0.3, 1.2, -0.1) if value == WeakPoints.BROKEN else Vector3(0.0, 1.35, -0.1)
	_notch_material.emission_energy_multiplier = NOTCH_ENERGY if value == WeakPoints.OPEN else 0.0


# Every surface of this part that glows, as emission colours (a dark part has none): the tests read the seat's light.
func lit_colors() -> Array:
	var out := []
	for mi in find_children("*", "MeshInstance3D", true, false):
		var material := (mi as MeshInstance3D).material_override as StandardMaterial3D
		if mi.is_visible_in_tree() and material != null and material.emission_enabled and material.emission_energy_multiplier > 0.0:
			out.append(material.emission)
	return out


# The seam plate (waking.gd owns it): a replaceable plate sized to the hatch seat. Inert by construction: a plain
# mesh with no body, no group and no light.
static func make_plate() -> MeshInstance3D:
	var plate := _box("SeamPlate", Vector3(SIZE.x, SIZE.y, 0.2), Vector3.ZERO, Palette.solid(COVER), null)
	_box("PlateEdge", Vector3(SIZE.x + 0.1, 0.1, 0.24), Vector3(0.0, SIZE.y * 0.5, 0.0), Palette.solid(EDGE), plate)
	plate.set_meta("inert", true)
	return plate


func hookable() -> bool:
	return state == WeakPoints.OPEN and collision_layer == Augments.STAKE_MASK


# The harpoon and the ball call these on whatever they touch; a part is not shoved and has nothing to flash.
func knock(_direction: Vector3, _force: float) -> void:
	pass


func flash() -> void:
	pass
