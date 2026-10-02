extends "res://src/world/stage_map.gd"

# Unit P2: the Highdraft terrain probe (throwaway; its findings are the product, see
# artifacts/local/alpha/r7/P2-FINDINGS.md). Three floating islands about 35 m apart edge
# to edge at different heights, a harpoon post or two on each, one thermal, and a net deck
# under everything.
#
# The ground heightmap is the NET: a funnel whose low points are the feet of three return
# ramps, one behind each island, so a ball that lands on it rolls to a foot and climbs
# back onto its island. The islands are not in the heightmap (it holds one height per
# point); each is a cylinder collider, and they enter terrain.height() as the live overlay
# "islands", so height(), drop_point() and material_at() read an island's top where the
# ball is over one.

const NET_RISE := 0.06
const NET_RISE_MAX := 6.0
const RAMP_LENGTH := 100.0
const RAMP_HALF := 14.0
const RAMP_BLEND := 8.0
const RIM_START := 185.0
const RIM_CURVE := 0.02
const BOUNCE := 0.0

const ISLAND_RADIUS := 12.0
const ISLAND_THICK := 4.0
# centre (x, z), top (y), the outward direction its return ramp climbs along, and the posts:
# each {"at": offset from the island centre, "height": above the island top}.
const ISLANDS := [
	{"id": "i1", "at": Vector2(0.0, -90.0), "top": 0.0, "out": Vector2(-1.0, 0.0),
		"posts": [{"at": Vector2(4.0, 8.0), "height": 30.0}]},
	{"id": "i2", "at": Vector2(16.0, -33.0), "top": 5.0, "out": Vector2(1.0, 0.0),
		"posts": [{"at": Vector2(-4.0, -8.0), "height": 30.0}, {"at": Vector2(-3.0, 8.0), "height": 30.0}]},
	{"id": "i3", "at": Vector2(-6.0, 22.0), "top": 2.0, "out": Vector2(-1.0, 0.0),
		"posts": [{"at": Vector2(3.0, -8.0), "height": 30.0}]},
]
const THERMAL_AT := Vector2(30.0, -64.0)
const THERMAL_RADIUS := 6.0
const THERMAL_HEIGHT := 44.0

# The net depth below the lowest deck (the probe tool can override it from P2_net_foot).
var net_foot := -34.0
var feet: Array[Vector2] = []
var ground_bounce := BOUNCE
var contraptions: Array = []
var start_overlays: Array[String] = ["islands"]
var terrain_sites := {}
var swaps := {}
var marble_path: Array = []
var landmark := Vector3.ZERO


func _init() -> void:
	if OS.get_environment("P2_BOUNCE") != "":
		ground_bounce = float(OS.get_environment("P2_BOUNCE"))
	if OS.get_environment("P2_NET_FOOT") != "":
		net_foot = float(OS.get_environment("P2_NET_FOOT"))
	title = "Highdraft probe"
	spawn = Vector2(0.0, -98.0)
	heading = Vector3(0.0, 0.0, 1.0)
	beacon = Vector2(900.0, 900.0)
	beacon_floor = -28.0
	vault = Vector2(120.0, 120.0)
	play_rect = Rect2(-160.0, -160.0, 320.0, 320.0)
	for isl in ISLANDS:
		feet.append((isl["at"] as Vector2) + (isl["out"] as Vector2).normalized() * (ISLAND_RADIUS + RAMP_LENGTH))
	contraptions = [{"kind": "thermal", "id": "thermal_a", "at": THERMAL_AT, "radius": THERMAL_RADIUS, "height": THERMAL_HEIGHT}]
	landmark = Vector3(0.0, 40.0, -30.0)


func island_top(x: float, z: float) -> float:
	for isl in ISLANDS:
		if Vector2(x, z).distance_to(isl["at"]) <= ISLAND_RADIUS:
			return float(isl["top"])
	return -INF


func overlay_height(_id: String, x: float, z: float, _ground: float) -> float:
	return island_top(x, z)


func net_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := INF
	for f in feet:
		d = minf(d, p.distance_to(f))
	var h := net_foot + minf(NET_RISE * d, NET_RISE_MAX)
	for isl in ISLANDS:
		var u: Vector2 = (isl["out"] as Vector2).normalized()
		var rel := p - (isl["at"] as Vector2)
		var along := rel.dot(u)
		var across := absf(rel.dot(Vector2(-u.y, u.x)))
		if along < ISLAND_RADIUS - 2.0 or along > ISLAND_RADIUS + RAMP_LENGTH:
			continue
		var side := 1.0 - smoothstep(RAMP_HALF, RAMP_HALF + RAMP_BLEND, across)
		if side <= 0.0:
			continue
		var t := clampf((ISLAND_RADIUS + RAMP_LENGTH - along) / RAMP_LENGTH, 0.0, 1.0)
		var top := float(isl["top"]) - 0.15
		var ramp := minf(lerpf(net_foot, top, t), top)
		h = lerpf(h, maxf(h, ramp), side)
	# The rim: a curved lip so a fast ball cannot leave the world over the edge.
	var over := maxf(maxf(absf(x), absf(z)) - RIM_START, 0.0)
	h += RIM_CURVE * over * over
	return h


func sample(x: float, z: float) -> Array:
	var h := net_height(x, z)
	# Value, not hazard colour: a pale rope weave, a bone check every 8 m, an amber padded
	# perimeter on the rim.
	var weave := (int(floorf(x / 4.0)) + int(floorf(z / 4.0))) & 1
	var c := Palette.SAND.lerp(Color.WHITE, 0.25).darkened(0.06 * float(weave))
	var rim := smoothstep(RIM_START - 6.0, RIM_START + 6.0, maxf(absf(x), absf(z)))
	c = c.lerp(Palette.AMBER, rim * 0.8)
	return [h, c]


func material_at(_x: float, _z: float) -> String:
	return "sand"


func build_props(parent: Node3D, ground: Callable) -> void:
	var stone := Palette.solid(Palette.SAND.darkened(0.1))
	var under := Palette.solid(Palette.CHARCOAL.lightened(0.15))
	var plate := Palette.solid(Palette.VERDIGRIS.lerp(Palette.SAND, 0.2))
	var bone := Palette.solid(Palette.SAND)
	for isl in ISLANDS:
		var c: Vector2 = isl["at"]
		var top: float = isl["top"]
		# Deck: a pale top plane (value step against the dark underside), 4 m thick.
		var deck := cylinder(parent, ISLAND_RADIUS, ISLAND_THICK, Vector3(c.x, top - ISLAND_THICK * 0.5, c.y), stone)
		deck.name = "Island_" + isl["id"]
		# A shallow dark remnant under it, visual only.
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = ISLAND_RADIUS * 0.9
		cm.bottom_radius = 2.0
		cm.height = 6.0
		cone.mesh = cm
		cone.material_override = under
		cone.position = Vector3(c.x, top - ISLAND_THICK - 3.0, c.y)
		parent.add_child(cone)
		# A bone nosing ring on the rim.
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = ISLAND_RADIUS - 0.5
		tm.outer_radius = ISLAND_RADIUS + 0.2
		ring.mesh = tm
		ring.material_override = bone
		ring.position = Vector3(c.x, top + 0.05, c.y)
		ring.scale = Vector3(1.0, 0.4, 1.0)
		parent.add_child(ring)
		for post in isl["posts"]:
			var at: Vector2 = c + (post["at"] as Vector2)
			_fork_post(parent, Vector3(at.x, top, at.y), float(post["height"]), plate)
	# The perimeter: four padded amber fences standing on the rim lip so a fast ball turns
	# back instead of leaving the world.
	var amber := Palette.solid(Palette.AMBER.darkened(0.15))
	for side in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var at: Vector3 = side * 197.0
		var size := Vector3(396.0, 140.0, 2.0) if absf(side.z) > 0.5 else Vector3(2.0, 140.0, 396.0)
		box(parent, size, at, amber)
	# The thermal's rooted hardware on the net (contraptions.gd draws the column).
	var foot: Vector3 = ground.call(THERMAL_AT.x, THERMAL_AT.y, 0.0)
	cylinder(parent, 2.2, 1.6, foot + Vector3.UP * 0.8, Palette.solid(Palette.AMBER.darkened(0.2)))


# One anchor post: a charcoal mast with a 3 m open ring eye at the top and an amber cap.
# The eye is visual; the rope bites the mast.
static func _fork_post(parent: Node3D, foot: Vector3, height_m: float, mat: Material) -> void:
	cylinder(parent, 0.9, height_m, foot + Vector3.UP * height_m * 0.5, Palette.solid(Palette.CHARCOAL))
	var eye := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.2
	tm.outer_radius = 1.6
	eye.mesh = tm
	eye.material_override = Palette.solid(Palette.SAND, 0.4)
	eye.position = foot + Vector3.UP * (height_m + 1.4)
	eye.rotation.x = PI * 0.5
	parent.add_child(eye)
