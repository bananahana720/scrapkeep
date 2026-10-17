extends "res://src/world/device.gd"

# The relay's stake post (W13 SR10): the copper mast and arc coil that stand outside a park
# relay's ring. Hold E to add one stack, up to the most, then one more hold clears the stake. The
# prompt names what the hold does before it commits; rolling into the ring starts the
# charge and locks the stake (hold_relay.gd), so the post stands spent while it runs.

const Cards := preload("res://src/world/director_cards.gd")

const MAST_HEIGHT := 16.0
const COIL_RADIUS := 2.2

var relay
var _coil_mat: StandardMaterial3D


func _init() -> void:
	family = "fight"


func build() -> void:
	var mast := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 1.2
	cyl.height = MAST_HEIGHT
	mast.mesh = cyl
	mast.material_override = Palette.solid(Palette.COPPER)
	mast.position = Vector3.UP * MAST_HEIGHT * 0.5
	add_child(mast)
	var coil := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = COIL_RADIUS
	sphere.height = COIL_RADIUS * 2.0
	coil.mesh = sphere
	_coil_mat = Palette.solid(Palette.ARC, 0.3)
	coil.material_override = _coil_mat
	coil.position = Vector3.UP * (MAST_HEIGHT + 1.0)
	add_child(coil)


func reach_point() -> Vector3:
	return global_position + Vector3.UP * 2.0


func ready_now() -> bool:
	return relay != null and not relay.charging()


func terms() -> String:
	if relay == null:
		return ""
	var next: int = (relay.stakes + 1) % (Cards.RELAY_STAKE_MAX + 1)
	if next == 0:
		return "clear the stake"
	return "x%d stake, %d parts" % [next, next + 1]


func fire() -> bool:
	if relay != null:
		relay.stake_up()
	return true


# The coil brightens with each stack and while the relay charges.
func tick(_delta: float) -> void:
	if relay == null or _coil_mat == null:
		return
	var glow: float = 0.3 + 0.5 * float(relay.stakes)
	if relay.charging():
		glow += 1.5 * relay.progress()
	_coil_mat.emission_energy_multiplier = glow
