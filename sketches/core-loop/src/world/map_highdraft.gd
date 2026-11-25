extends "res://src/world/stage_map.gd"


const NET_H := 10.0
const ISLANDS := {
	"spawn": {"at": Vector2(0.0, 120.0), "radius": 18.0, "top": NET_H + 18.0},
	"mid": {"at": Vector2(0.0, 40.0), "radius": 16.0, "top": NET_H + 16.0},
	"beacon": {"at": Vector2(0.0, -60.0), "radius": 22.0, "top": NET_H + 14.0},
	"vault": {"at": Vector2(70.0, 40.0), "radius": 14.0, "top": NET_H + 20.0},
	"west": {"at": Vector2(-70.0, -20.0), "radius": 14.0, "top": NET_H + 12.0},
}
const SKIRT := 4.0
const BRIDGES := [["spawn", "mid"], ["mid", "beacon"]]
const BRIDGE_HALF := 4.0
const BRIDGE_SKIRT := 3.0
const RAMPS := [
	{"island": "beacon", "toward": "mid", "side": 8.0},
	{"island": "beacon", "toward": "mid", "side": -8.0},
]
const RAMP_HALF := 4.0
const RAMP_GRADE := 0.32
const RAMP_SKIRT := 3.0
const THERMAL_A := Vector2(-40.0, 60.0)
const THERMAL_B := Vector2(40.0, -20.0)
const THERMAL_C := Vector2(30.0, -75.0)
const BARGE_SIZE := Vector3(14.0, 2.0, 14.0)
const POST_HEIGHT := 16.0
const POSTS := [
	{"at": Vector2(7.0, 105.0), "height": POST_HEIGHT},
	{"at": Vector2(-7.0, 27.0), "height": POST_HEIGHT},
	{"at": Vector2(-20.0, -56.7), "height": POST_HEIGHT},
	{"at": Vector2(-63.4, -30.7), "height": POST_HEIGHT},
	{"at": Vector2(59.0, 46.0), "height": POST_HEIGHT},
]

var contraptions: Array = []
var rescue_sites: Array = []
var hard_points: Array = []
var relic_spot := Vector2(9.0, 122.0)


func _init() -> void:
	title = "Highdraft"
	scatter["per_preset"] = {"small": 4, "medium": 5, "large": 6}
	spawn = _islands()["spawn"]["at"]
	heading = Vector3(0.0, 0.0, -1.0)
	beacon = _islands()["beacon"]["at"]
	beacon_floor = _islands()["beacon"]["top"]
	vault = _islands()["vault"]["at"]
	gate_slots = [
		{"at": Vector2(-10.0, -74.0), "facing": Vector3(0.0, 0.0, -1.0)},
		{"at": Vector2(0.0, -74.0), "facing": Vector3(0.0, 0.0, -1.0)},
		{"at": Vector2(10.0, -74.0), "facing": Vector3(0.0, 0.0, -1.0)},
	]
	var isles := _islands()
	var mid: Dictionary = isles["mid"]
	var vault_isle: Dictionary = isles["vault"]
	var spawn_isle: Dictionary = isles["spawn"]
	var west: Dictionary = isles["west"]
	var beacon_isle: Dictionary = isles["beacon"]
	for post in _posts():
		hard_points.append({"at": post["at"]})
	contraptions = [
		{"kind": "thermal", "id": "thermal_a", "at": THERMAL_A, "radius": 5.0, "height": 40.0},
		{"kind": "thermal", "id": "thermal_b", "at": THERMAL_B, "radius": 5.0, "height": 40.0},
		{"kind": "thermal", "id": "thermal_c", "at": THERMAL_C, "radius": 5.0, "height": 40.0},
		{"kind": "cable", "id": "grapple_line", "from": Vector3(-14.0, float(spawn_isle["top"]) + 2.6, 110.0),
			"to": Vector3(-60.0, float(west["top"]) + 2.4, -12.0), "radius": 4.5, "floor": 18.0},
		{"kind": "barge", "id": "barge_isle", "a": Vector3(24.0, float(mid["top"]) - BARGE_SIZE.y * 0.5, 40.0),
			"b": Vector3(48.0, float(vault_isle["top"]) - BARGE_SIZE.y * 0.5, 40.0),
			"size": BARGE_SIZE, "travel": 8.0, "dwell": 3.0, "offset": 0.0},
		{"kind": "barge", "id": "barge_west", "a": Vector3(-29.0, float(beacon_isle["top"]) - BARGE_SIZE.y * 0.5, -43.5),
			"b": Vector3(-48.0, float(west["top"]) - BARGE_SIZE.y * 0.5, -32.5),
			"size": BARGE_SIZE, "travel": 10.0, "dwell": 3.0, "offset": 0.0},
	]
	activity_sites = [
		{"id": "enemy_camp", "at": Vector2(-70.0, -20.0), "pack": ["chaser", "chaser", "lobber"], "pay": {"named": "rivet_plating"}},
		{"id": "hauler_bounty", "at": Vector2(70.0, 47.0)},
		{"id": "ambush_altar", "at": Vector2(7.5, 30.0)},
	]
	rescue_sites = [{"id": "tally_cage", "quest": "isles", "pilot": "tally", "prompt": "free the bookkeeper",
		"at": Vector2(-7.5, 52.0), "face": (THERMAL_A - Vector2(-7.5, 52.0)).normalized()}]


func _islands() -> Dictionary:
	return ISLANDS


func _bridges() -> Array:
	return BRIDGES


func _posts() -> Array:
	return POSTS


func _ramps() -> Array:
	return RAMPS


func ramp_line(ramp: Dictionary) -> Dictionary:
	var isles := _islands()
	var isle: Dictionary = isles[ramp["island"]]
	var centre: Vector2 = isle["at"]
	var axis: Vector2 = ((isles[ramp["toward"]]["at"] as Vector2) - centre).normalized()
	var side: float = ramp["side"]
	var radius: float = isle["radius"]
	var top: float = isle["top"]
	var rim: Vector2 = centre + axis * sqrt(radius * radius - side * side) + Vector2(-axis.y, axis.x) * side
	return {"foot": rim + axis * (top - NET_H) / RAMP_GRADE, "rim": rim, "top": top}


func build_props(parent: Node3D, ground: Callable) -> void:
	for post in _posts():
		var at: Vector2 = post["at"]
		grapple_post(parent, ground.call(at.x, at.y, -0.5), post["height"])


func net_deck_height() -> float:
	return NET_H


func sample(x: float, z: float) -> Array:
	var p := Vector2(x, z)
	var h := NET_H
	var tint := Palette.CHARCOAL
	var isles := _islands()
	for id in isles:
		var isle: Dictionary = isles[id]
		var top: float = isle["top"]
		var d: float = p.distance_to(isle["at"]) - float(isle["radius"])
		var ih := _skirt(top, d, SKIRT)
		if ih > h:
			h = ih
			tint = Palette.SAND
	for pair in _bridges():
		var a: Dictionary = isles[pair[0]]
		var b: Dictionary = isles[pair[1]]
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
	for ramp in _ramps():
		var line := ramp_line(ramp)
		var foot: Vector2 = line["foot"]
		var rim: Vector2 = line["rim"]
		var near := Geometry2D.get_closest_point_to_segment(p, foot, rim)
		var rise := lerpf(NET_H, line["top"], (near - foot).length() / foot.distance_to(rim))
		var rh := _skirt(rise, p.distance_to(near) - RAMP_HALF, RAMP_SKIRT)
		if rh > h:
			h = rh
			tint = Palette.RUST
	return [h, tint]


static func _skirt(top: float, d: float, width: float) -> float:
	if d <= 0.0:
		return top
	if d >= width:
		return NET_H
	return lerpf(top, NET_H, smoothstep(0.0, 1.0, d / width))


func material_at(x: float, z: float) -> String:
	return "net" if sample(x, z)[0] <= NET_H + 0.5 else "stone"
