extends "res://src/world/stage_map.gd"

# Highdraft, greybox: rounded stone islands over a flat net deck at NET_H. Two ridge
# bridges join the spawn island to the beacon island through a middle island, so the
# route needs no thermal. A barge is the moving island (contraptions.gd on_barge carry
# rule), a cable runs from the spawn island down to the west island, and two thermal
# columns stand on the deck as data only: lifting a gliding ball in them needs the glide
# rule change wave 9 owns (augments.gd glides only while falling). Not in Terrain.MAPS.

const NET_H := 10.0
# Each island: centre, flat-top radius, top height. A rounded skirt drops to the deck.
const ISLANDS := {
	"spawn": {"at": Vector2(0.0, 120.0), "radius": 18.0, "top": NET_H + 18.0},
	"mid": {"at": Vector2(0.0, 40.0), "radius": 16.0, "top": NET_H + 16.0},
	"beacon": {"at": Vector2(0.0, -60.0), "radius": 22.0, "top": NET_H + 14.0},
	"vault": {"at": Vector2(70.0, 40.0), "radius": 14.0, "top": NET_H + 20.0},
	"west": {"at": Vector2(-70.0, -20.0), "radius": 14.0, "top": NET_H + 12.0},
}
const SKIRT := 4.0
# Ridge bridges between island rims, at island height, a flat walk BRIDGE_HALF each side.
const BRIDGES := [["spawn", "mid"], ["mid", "beacon"]]
const BRIDGE_HALF := 4.0
const BRIDGE_SKIRT := 3.0
const THERMAL_A := Vector2(-40.0, 60.0)
const THERMAL_B := Vector2(40.0, -20.0)
const BARGE_SIZE := Vector3(14.0, 2.0, 14.0)

var contraptions: Array = []
var rescue_sites: Array = []


func _init() -> void:
	title = "Highdraft"
	spawn = ISLANDS["spawn"]["at"]
	heading = Vector3(0.0, 0.0, -1.0)
	beacon = ISLANDS["beacon"]["at"]
	beacon_floor = ISLANDS["beacon"]["top"]
	vault = ISLANDS["vault"]["at"]
	gate_slots = [
		{"at": Vector2(-10.0, -74.0), "facing": Vector3(0.0, 0.0, -1.0)},
		{"at": Vector2(0.0, -74.0), "facing": Vector3(0.0, 0.0, -1.0)},
		{"at": Vector2(10.0, -74.0), "facing": Vector3(0.0, 0.0, -1.0)},
	]
	var mid: Dictionary = ISLANDS["mid"]
	var vault_isle: Dictionary = ISLANDS["vault"]
	var spawn_isle: Dictionary = ISLANDS["spawn"]
	var west: Dictionary = ISLANDS["west"]
	contraptions = [
		{"kind": "thermal", "id": "thermal_a", "at": THERMAL_A, "radius": 5.0, "height": 40.0},
		{"kind": "thermal", "id": "thermal_b", "at": THERMAL_B, "radius": 5.0, "height": 40.0},
		{"kind": "cable", "id": "grapple_line", "from": Vector3(-14.0, float(spawn_isle["top"]) + 2.6, 110.0),
			"to": Vector3(-60.0, float(west["top"]) + 2.4, -12.0), "radius": 4.5, "floor": 18.0},
		{"kind": "barge", "id": "barge_isle", "a": Vector3(24.0, float(mid["top"]) - BARGE_SIZE.y * 0.5, 40.0),
			"b": Vector3(48.0, float(vault_isle["top"]) - BARGE_SIZE.y * 0.5, 40.0),
			"size": BARGE_SIZE, "travel": 8.0, "dwell": 3.0, "offset": 0.0},
	]


func net_deck_height() -> float:
	return NET_H


func sample(x: float, z: float) -> Array:
	var p := Vector2(x, z)
	var h := NET_H
	var tint := Palette.CHARCOAL
	for id in ISLANDS:
		var isle: Dictionary = ISLANDS[id]
		var top: float = isle["top"]
		var d: float = p.distance_to(isle["at"]) - float(isle["radius"])
		var ih := _skirt(top, d, SKIRT)
		if ih > h:
			h = ih
			tint = Palette.SAND
	for pair in BRIDGES:
		var a: Dictionary = ISLANDS[pair[0]]
		var b: Dictionary = ISLANDS[pair[1]]
		var dir: Vector2 = ((b["at"] as Vector2) - (a["at"] as Vector2)).normalized()
		var from: Vector2 = (a["at"] as Vector2) + dir * float(a["radius"])
		var to: Vector2 = (b["at"] as Vector2) - dir * float(b["radius"])
		var near := Geometry2D.get_closest_point_to_segment(p, from, to)
		var t := clampf((near - from).length() / from.distance_to(to), 0.0, 1.0)
		var top := lerpf(a["top"], b["top"], t)
		var bh := _skirt(top, p.distance_to(near) - BRIDGE_HALF, BRIDGE_SKIRT)
		if bh > h:
			h = bh
			tint = Palette.RUST
	return [h, tint]


# Height over the deck d metres past a flat top's edge: flat inside, a rounded fall over
# width metres, the deck beyond.
static func _skirt(top: float, d: float, width: float) -> float:
	if d <= 0.0:
		return top
	if d >= width:
		return NET_H
	return lerpf(top, NET_H, smoothstep(0.0, 1.0, d / width))


func material_at(x: float, z: float) -> String:
	return "net" if sample(x, z)[0] <= NET_H + 0.5 else "stone"
