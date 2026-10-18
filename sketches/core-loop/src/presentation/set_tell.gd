extends Node3D

const Palette := preload("res://src/core/palette.gd")
const PartSets := preload("res://src/build/part_sets.gd")

# SI6's tell on the mech: a complete set shows as a band of three studs around the ball, in
# the set's colour, one band per set at its own tilt, so a set reads as "three parts that
# belong together" and stays apart from a synergy's single halo ring (accretion.gd). It is
# drawn from build.gd's sheet on every redraw, so a respec that breaks a set hides its band.

const RADIUS := 1.18
const STUD := Vector3(0.22, 0.22, 0.22)
const BAND_WIDTH := 0.05
const TILT_STEP := 0.55

var _bands := {}


func show_sets(complete: Array) -> void:
	for key in PartSets.SETS:
		var band: Node3D = _bands.get(key)
		if band == null and key in complete:
			band = _build_band(key)
			_bands[key] = band
		if band != null:
			band.visible = key in complete


func shown() -> Array:
	return _bands.keys().filter(func(key): return _bands[key].visible)


func _build_band(set_id: String) -> Node3D:
	var index: int = PartSets.SETS.keys().find(set_id)
	var color: Color = PartSets.SETS[set_id]["color"]
	var mat := Palette.solid(color, 1.5)
	var band := Node3D.new()
	band.name = "Set_" + set_id
	band.rotation = Vector3(TILT_STEP * index, 0.9 * index, 0.0)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RADIUS - BAND_WIDTH
	torus.outer_radius = RADIUS
	ring.mesh = torus
	ring.material_override = mat
	band.add_child(ring)
	for i in PartSets.SIZE:
		var stud := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = STUD
		stud.mesh = box
		stud.material_override = mat
		var angle := TAU * float(i) / float(PartSets.SIZE)
		stud.position = Vector3(cos(angle), 0.0, sin(angle)) * RADIUS
		stud.rotation.y = -angle
		band.add_child(stud)
	add_child(band)
	return band
