extends StaticBody3D

const Augments := preload("res://src/movement/augments.gd")
const WeakPoints := preload("res://src/boss/weak_points.gd")

# One physical weak point of a boss fight (challenge lane, #241 step 2a): a hatch on a floor's rim, the pit's
# bore-head override. Greybox only; the art board is card 2c. It exists only when the boss's weak_points dial is
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
const COVER := Color(0.42, 0.37, 0.30)
const GAP := Color(1.0, 0.62, 0.18)
const CAVITY := Color(0.07, 0.06, 0.05)

var point_id := ""
var state := WeakPoints.SHUT
# enemy.gd's radius: the harpoon line's "passed" check reads it.
var radius := 1.8

var _cover: MeshInstance3D
var _cavity: MeshInstance3D
var _cavity_material: StandardMaterial3D


func setup(id: String, facing: Vector3) -> void:
	point_id = id
	name = "WeakPart_%s" % id
	add_to_group(GROUP)
	add_to_group(Augments.STAKE_GROUP)
	collision_mask = 0
	var box := BoxMesh.new()
	box.size = Vector3(3.2, 2.4, 0.8)
	var shape := CollisionShape3D.new()
	var solid := BoxShape3D.new()
	solid.size = box.size
	shape.shape = solid
	add_child(shape)
	_cavity_material = StandardMaterial3D.new()
	_cavity_material.albedo_color = CAVITY
	_cavity_material.emission_enabled = true
	_cavity = MeshInstance3D.new()
	_cavity.name = "Cavity"
	_cavity.mesh = box
	_cavity.material_override = _cavity_material
	add_child(_cavity)
	var plate := StandardMaterial3D.new()
	plate.albedo_color = COVER
	_cover = MeshInstance3D.new()
	_cover.name = "Cover"
	_cover.mesh = box
	_cover.material_override = plate
	# The cover stands a little proud of the cavity, so an open hatch shows a gap from the bank side.
	_cover.position = facing * 0.15
	add_child(_cover)
	set_state(WeakPoints.SHUT)


# Mirrors the rule's state: the cover shows only while SHUT, the cavity glows while OPEN and goes dark when
# BROKEN, and only an OPEN part is on the stake layer the harpoon's ray reads.
func set_state(value: int) -> void:
	state = value
	collision_layer = Augments.STAKE_MASK if value == WeakPoints.OPEN else 0
	if _cover == null:
		return
	_cover.visible = value == WeakPoints.SHUT
	_cavity.visible = value != WeakPoints.SHUT
	_cavity_material.emission = GAP if value == WeakPoints.OPEN else CAVITY
	_cavity_material.emission_energy_multiplier = 2.5 if value == WeakPoints.OPEN else 0.0


func hookable() -> bool:
	return state == WeakPoints.OPEN and collision_layer == Augments.STAKE_MASK


# The harpoon and the ball call these on whatever they touch; a part is not shoved and has nothing to flash.
func knock(_direction: Vector3, _force: float) -> void:
	pass


func flash() -> void:
	pass
