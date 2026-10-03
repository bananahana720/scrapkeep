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
	return [h, _strata(s[1], h, 1.0 - w)]


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
