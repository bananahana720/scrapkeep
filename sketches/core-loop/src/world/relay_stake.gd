extends "res://src/world/device.gd"


const Cards := preload("res://src/core/director_cards.gd")

const MAST_HEIGHT := 16.0
const COIL_RADIUS := 2.2
const MODEL := "res://assets/models/world_one/relay_stake_post.glb"
const STAKE_RINGS := ["Stake1", "Stake2", "Stake3", "Stake4"]
const STAKE_SWEEP := 0.5
const RING_LIT := 3.0

var relay
var _coil_mat: StandardMaterial3D
var _ring_mats: Array[StandardMaterial3D] = []
var _needle: Node3D


func _init() -> void:
	family = "fight"


func build() -> void:
	if ResourceLoader.exists(MODEL):
		var model := (load(MODEL) as PackedScene).instantiate() as Node3D
		var rings: Array[MeshInstance3D] = []
		for ring_name in STAKE_RINGS:
			rings.append(model.find_child(ring_name, true, false) as MeshInstance3D)
		var glow := model.find_child("CoilGlow", true, false) as MeshInstance3D
		_needle = model.find_child("StakeNeedle", true, false) as Node3D
		if glow != null and _needle != null and not rings.has(null):
			add_child(model)
			for ring in rings:
				var mat := PaletteMaterials.solid(Palette.ARC, RING_LIT)
				mat.albedo_color = Palette.ARC.darkened(0.6)
				ring.material_override = mat
				_ring_mats.append(mat)
			_coil_mat = PaletteMaterials.solid(Palette.ARC, 0.3)
			glow.material_override = _coil_mat
			_show_stakes(0)
			return
		push_warning("relay_stake: %s lacks a stake ring, the dial needle or the coil; keeping the primitive post" % MODEL)
		model.free()
		_needle = null
	var mast := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 1.2
	cyl.height = MAST_HEIGHT
	mast.mesh = cyl
	mast.material_override = PaletteMaterials.solid(Palette.COPPER)
	mast.position = Vector3.UP * MAST_HEIGHT * 0.5
	add_child(mast)
	var coil := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = COIL_RADIUS
	sphere.height = COIL_RADIUS * 2.0
	coil.mesh = sphere
	_coil_mat = PaletteMaterials.solid(Palette.ARC, 0.3)
	coil.material_override = _coil_mat
	coil.position = Vector3.UP * (MAST_HEIGHT + 1.0)
	add_child(coil)


func reach_point() -> Vector3:
	return global_position + Vector3.UP * 2.0


func ready_now() -> bool:
	return relay != null and not spent and not relay.charging()


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


func _show_stakes(k: int) -> void:
	for i in _ring_mats.size():
		_ring_mats[i].emission_enabled = i < k
		_ring_mats[i].albedo_color = Palette.ARC if i < k else Palette.ARC.darkened(0.6)
	if _needle != null:
		_needle.rotation.z = -STAKE_SWEEP * float(k)


func tick(_delta: float) -> void:
	if relay == null or _coil_mat == null:
		return
	_show_stakes(int(relay.stakes))
	var glow: float = 0.3 + 0.5 * float(relay.stakes)
	if relay.charging():
		glow += 1.5 * relay.progress()
	_coil_mat.emission_energy_multiplier = glow
