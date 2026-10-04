extends RefCounted

const Palette := preload("res://src/core/palette.gd")

# A Highdraft probe map: a flat net deck at NET_H with two island tops ISLAND_RISE above
# it, and one thermal on the deck. Only the slots ZoneSchema requires, for
# probe_highdraft_lift_test.gd.

const NET_H := 10.0
const ISLAND_RISE := 15.0
const ISLAND_RADIUS := 12.0
const ISLANDS := [Vector2(-40.0, 0.0), Vector2(40.0, 0.0)]
const THERMAL_AT := Vector2(0.0, -60.0)

var title := "Highdraft probe"
var spawn := Vector2(0.0, 40.0)
var heading := Vector3(0.0, 0.0, -1.0)
var beacon := Vector2(0.0, 80.0)
var vault := Vector2(60.0, 60.0)
var bay := [{"at": Vector2(-60.0, 60.0)}]
var play_rect := Rect2(-190.0, -190.0, 380.0, 380.0)
var scrap_lines: Array = []
var contraptions: Array = [
	{"kind": "thermal", "id": "t", "at": THERMAL_AT, "radius": 5.0, "height": 40.0},
]


func sample(x: float, z: float) -> Array:
	for c in ISLANDS:
		if Vector2(x, z).distance_to(c) <= ISLAND_RADIUS:
			return [NET_H + ISLAND_RISE, Palette.SAND]
	return [NET_H, Palette.SAND]


func build_props(_parent: Node3D, _ground: Callable) -> void:
	pass


func material_at(_x: float, _z: float) -> String:
	return "stone"
