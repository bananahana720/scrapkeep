extends "res://src/world/map_reach.gd"

# Unit TP's throwaway probe: today's Cable Reach with a baked DEM heightmap blended under it
# (tools/terrain_bake.py). The bake file holds two 201 x 201 float32 planes at 2 m: the baked
# height, and the weight of today's ground (1 inside a pilot line's corridor plus its 12 m
# feather and wherever the bake owns nothing). sample() reads both through map.sample(), so
# terrain.gd is unchanged. Crater is the Meteor Crater control zone, a separate stage.

const BAKE_PATH := "res://src/world/terrain/reach_probe.bin"
const SIDE := 201
const STEP := 2.0
const HALF := 200.0

# e2's channel lies across the baked east wall, so its roof slab would stand in the ball's way.
const NO_ROOF := ["w1", "e1", "e2"]

var _bake := PackedFloat32Array()
var _weight := PackedFloat32Array()


func _init() -> void:
	super()
	title = "The Cable Reach (DEM probe)"
	var bytes := FileAccess.get_file_as_bytes(BAKE_PATH)
	assert(bytes.size() == SIDE * SIDE * 8, "map_reach_probe: bake file missing or the wrong size")
	var all := bytes.to_float32_array()
	_bake = all.slice(0, SIDE * SIDE)
	_weight = all.slice(SIDE * SIDE, SIDE * SIDE * 2)


func sample(x: float, z: float) -> Array:
	var s := super.sample(x, z)
	var w := _grid(_weight, x, z)
	if w >= 0.9999:
		return [s[0], s[1]]
	var b := _grid(_bake, x, z)
	var h := lerpf(b, float(s[0]), w)
	var tint: Color = _strata(s[1], h, 1.0 - w)
	# Unit LKM: the slickrock region (the bake's dome rectangle, x 90..164, z -99..99, 14 m
	# feather) rides in vertex alpha as 1 - mask; the rock ground shader reads it, nothing else does.
	var dx := minf(x - 90.0, 164.0 - x)
	var dz := minf(z + 99.0, 99.0 - z)
	tint.a = 1.0 - clampf(minf(dx, dz) / 14.0, 0.0, 1.0) * (1.0 - w)
	return [h, tint]


# map_reach's roofs (w2 only on this map) without e2's.
func _tunnel_roofs(parent: Node3D, ground: Callable, mat: Material) -> void:
	for id in TUNNELS:
		if id in NO_ROOF:
			continue
		var ends: Array = TUNNELS[id]
		var a: Vector2 = (ends[0] as Vector2).lerp(ends[1], 0.28)
		var b: Vector2 = (ends[0] as Vector2).lerp(ends[1], 0.62)
		var d := ((ends[1] as Vector2) - (ends[0] as Vector2)).normalized()
		var side := Vector2(-d.y, d.x) * ROOF_SIDE
		var top := func(p: Vector2) -> float:
			return maxf((ground.call(p.x + side.x, p.y + side.y, 0.0) as Vector3).y,
				(ground.call(p.x - side.x, p.y - side.y, 0.0) as Vector3).y) - ROOF_SINK
		var pa := Vector3(a.x, top.call(a), a.y)
		var pb := Vector3(b.x, top.call(b), b.y)
		var along := pb - pa
		var body := box(parent, Vector3(TUNNEL_HALF * 2.0 + 3.0, 1.2, along.length()), (pa + pb) * 0.5 + Vector3.DOWN * 0.6, mat)
		body.name = "TunnelRoof_" + id
		body.basis = Basis.looking_at(along.normalized(), Vector3.UP)


# Unit LKP: the four sculpted sandstone pieces on the probe ground, behind `--kit=1` (user args).
# Without the flag build_props is today's. Every piece loads from KIT_PIECES, so a new round of
# the glbs at the same paths needs no code change. Rows are [piece, x, z, yaw in degrees, scale];
# the yaw turns the piece's front (-z) to that heading, so yaw 270 faces +x and 180 faces +z.
# A piece's base sits KIT_SINK below the lowest ground under its footprint. Each piece has a
# static trimesh collider built from its own mesh at its scale.
const KIT_PIECES := {
	"cliff_strata": "res://assets/models/world_one/landforms/sculpted/cliff_strata.glb",
	"alcove": "res://assets/models/world_one/landforms/sculpted/alcove.glb",
	"fin_spire": "res://assets/models/world_one/landforms/sculpted/fin_spire.glb",
	"arch": "res://assets/models/world_one/landforms/sculpted/arch.glb",
}
const KIT_SINK := 0.6
# Unit LKP2: the piece shader colours each piece with the ground's beds (target_bed4.gdshaderinc);
# a piece's own maps keep only the normal map and the ambient-occlusion and cavity terms.
const KIT_SHADER := preload("res://assets/shaders/target_piece_rock.gdshader")
const KIT_DIR := "res://assets/models/world_one/landforms/sculpted/"
const KIT := [
	["cliff_strata", -56.0, -91.0, 270.0, 0.62],
	["cliff_strata", -58.0, -78.0, 266.0, 0.7],
	["cliff_strata", -57.0, -66.0, 276.0, 0.6],
	["cliff_strata", -56.5, -57.0, 268.0, 0.55],
	["alcove", -167.0, -72.0, 270.0, 0.8],
	["alcove", -167.0, -42.0, 270.0, 0.75],
	["fin_spire", 108.0, -24.0, 20.0, 0.8],
	["fin_spire", 109.0, -10.0, 130.0, 1.0],
	["fin_spire", 107.0, 2.0, 250.0, 0.65],
	["arch", -52.0, 104.0, 290.0, 1.0],
	["fin_spire", -58.0, 90.0, 70.0, 0.6],
	["fin_spire", -46.0, 122.0, 200.0, 0.75],
]

var _kit_faces := {}
var _kit_mats := {}


static func kit_enabled() -> bool:
	return "--kit=1" in OS.get_cmdline_args() or "--kit=1" in OS.get_cmdline_user_args()


func build_props(parent: Node3D, ground: Callable) -> void:
	super(parent, ground)
	if not kit_enabled():
		return
	var holder := Node3D.new()
	holder.name = "Kit"
	parent.add_child(holder)
	for i in KIT.size():
		var row: Array = KIT[i]
		_place_piece(holder, ground, i, row[0], Vector2(row[1], row[2]), row[3], row[4])


func _place_piece(holder: Node3D, ground: Callable, index: int, piece: String, at: Vector2, yaw_deg: float, size: float) -> void:
	var scene := (load(KIT_PIECES[piece]) as PackedScene).instantiate() as Node3D
	var views := scene.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (views[0] as MeshInstance3D).mesh
	(views[0] as MeshInstance3D).material_override = _kit_material(piece)
	var box := mesh.get_aabb()
	var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var low := INF
	for u in range(-2, 3):
		for v in range(-2, 3):
			var local := Vector3(u * 0.25 * box.size.x, 0.0, v * 0.25 * box.size.z) * size
			var w := at + Vector2((basis * local).x, (basis * local).z)
			low = minf(low, (ground.call(w.x, w.y, 0.0) as Vector3).y)
	var body := StaticBody3D.new()
	body.name = "Kit%02d_%s" % [index, piece]
	body.position = Vector3(at.x, low - KIT_SINK, at.y)
	body.basis = basis
	scene.scale = Vector3.ONE * size
	body.add_child(scene)
	if not _kit_faces.has(piece):
		_kit_faces[piece] = mesh.get_faces()
	var faces := PackedVector3Array(_kit_faces[piece])
	for k in faces.size():
		faces[k] *= size
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	holder.add_child(body)


func _kit_material(piece: String) -> ShaderMaterial:
	if _kit_mats.has(piece):
		return _kit_mats[piece]
	var mat := ShaderMaterial.new()
	mat.shader = KIT_SHADER
	mat.resource_name = "kit_" + piece
	mat.set_shader_parameter("varnish_color", Palette.RUST.lerp(Palette.CHARCOAL, 0.6))
	mat.set_shader_parameter("tex_tone", load("res://assets/textures/ground/lkg_tone_c.png"))
	mat.set_shader_parameter("tex_grain", load("res://assets/textures/ground/lkg_grain_d.png"))
	mat.set_shader_parameter("tex_normal", load("%s%s_%s_game_normal.png" % [KIT_DIR, piece, piece]))
	mat.set_shader_parameter("tex_ao", load("%s%s_ao_1024.png" % [KIT_DIR, piece]))
	mat.set_shader_parameter("tex_cavity", load("%s%s_cavity_1024.png" % [KIT_DIR, piece]))
	if piece == "alcove":
		mat.set_shader_parameter("hollow", Vector4(8.0, -4.1, 1.0, 9.0))
	_kit_mats[piece] = mat
	return mat


# A quick strata tint so the stills read as banded rock rather than flat clay: bands by height.
func _strata(base: Color, h: float, owned: float) -> Color:
	var band := 0.5 + 0.5 * sin(h * 1.9)
	var warm := Palette.SANDSTONE.lerp(Palette.RUST, 0.45)
	var pale := Palette.SAND.lerp(Palette.SANDSTONE, 0.35)
	return base.lerp(warm.lerp(pale, band), owned * 0.85)


static func _grid(plane: PackedFloat32Array, x: float, z: float) -> float:
	var gx := clampf((x + HALF) / STEP, 0.0, float(SIDE - 1) - 0.001)
	var gz := clampf((z + HALF) / STEP, 0.0, float(SIDE - 1) - 0.001)
	var i := int(gx)
	var j := int(gz)
	var fx := gx - i
	var fz := gz - j
	var a := plane[j * SIDE + i]
	var b := plane[j * SIDE + i + 1]
	var c := plane[(j + 1) * SIDE + i]
	var d := plane[(j + 1) * SIDE + i + 1]
	if fx + fz <= 1.0:
		return a + (b - a) * fx + (c - a) * fz
	return d + (c - d) * (1.0 - fx) + (b - d) * (1.0 - fz)


# The Meteor Crater control: one stage, the crater at the centre, a spawn on the north rim and
# the beacon just past the south rim. No contraptions, events or activities.
class Crater:
	extends "res://src/world/stage_map.gd"

	const PATH := "res://src/world/terrain/crater_probe.bin"
	var _h := PackedFloat32Array()

	func _init() -> void:
		title = "Meteor Crater (control)"
		spawn = Vector2(0.0, -78.0)
		heading = Vector3(0.0, 0.0, 1.0)
		beacon = Vector2(0.0, 88.0)
		beacon_floor = 0.0
		play_rect = Rect2(-150.0, -150.0, 300.0, 300.0)
		var bytes := FileAccess.get_file_as_bytes(PATH)
		assert(bytes.size() == 201 * 201 * 4, "map_reach_probe: crater bake missing")
		_h = bytes.to_float32_array()
		beacon_floor = _at(beacon.x, beacon.y)
		gate_slots = [{"at": Vector2(0.0, 112.0), "facing": Vector3(0.0, 0.0, 1.0)}]

	func _at(x: float, z: float) -> float:
		var gx := clampf((x + 200.0) / 2.0, 0.0, 199.999)
		var gz := clampf((z + 200.0) / 2.0, 0.0, 199.999)
		var i := int(gx)
		var j := int(gz)
		var fx := gx - i
		var fz := gz - j
		var a := _h[j * 201 + i]
		var b := _h[j * 201 + i + 1]
		var c := _h[(j + 1) * 201 + i]
		var d := _h[(j + 1) * 201 + i + 1]
		if fx + fz <= 1.0:
			return a + (b - a) * fx + (c - a) * fz
		return d + (c - d) * (1.0 - fx) + (b - d) * (1.0 - fz)

	func sample(x: float, z: float) -> Array:
		var h := _at(x, z)
		var band := 0.5 + 0.5 * sin(h * 1.9)
		var tint: Color = Palette.SAND.lerp(Palette.SANDSTONE, 0.35 + 0.3 * band)
		return [h, tint]
