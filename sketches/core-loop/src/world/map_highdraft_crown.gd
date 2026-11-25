extends "res://src/world/map_highdraft.gd"


const CROWN_ISLANDS := {
	"spawn": {"at": Vector2(-30.0, 125.0), "radius": 18.0, "top": NET_H + 30.0},
	"mid": {"at": Vector2(30.0, 10.0), "radius": 16.0, "top": NET_H + 28.0},
	"beacon": {"at": Vector2(-20.0, -115.0), "radius": 22.0, "top": NET_H + 26.0},
	"vault": {"at": Vector2(100.0, 60.0), "radius": 14.0, "top": NET_H + 34.0},
	"west": {"at": Vector2(-100.0, -30.0), "radius": 14.0, "top": NET_H + 24.0},
}
const CROWN_BRIDGES := [["spawn", "mid"], ["mid", "beacon"]]
const CROWN_THERMALS := [Vector2(-60.0, 60.0), Vector2(70.0, -50.0), Vector2(40.0, -130.0)]
const CROWN_THERMAL_HEIGHT := 46.0
const CROWN_BARGES := [
	{"id": "barge_isle", "from": "mid", "to": "vault", "travel": 10.0},
	{"id": "barge_west", "from": "beacon", "to": "west", "travel": 14.0},
]
const BARGE_DOCK := 8.0
const CROWN_POSTS := [
	{"at": Vector2(-16.9, 114.9), "height": POST_HEIGHT},
	{"at": Vector2(31.7, -4.7), "height": POST_HEIGHT},
	{"at": Vector2(-38.1, -106.0), "height": POST_HEIGHT},
	{"at": Vector2(-87.4, -33.2), "height": POST_HEIGHT},
	{"at": Vector2(95.1, 47.9), "height": POST_HEIGHT},
]


func _init() -> void:
	super()
	title = "Highdraft: the crown"
	var isles := CROWN_ISLANDS
	spawn = isles["spawn"]["at"]
	beacon = isles["beacon"]["at"]
	beacon_floor = isles["beacon"]["top"]
	vault = isles["vault"]["at"]
	var mid: Vector2 = isles["mid"]["at"]
	var toward_mid: Vector2 = (mid - spawn).normalized()
	heading = Vector3(toward_mid.x, 0.0, toward_mid.y)
	var approach: Vector2 = (beacon - mid).normalized()
	var side := Vector2(-approach.y, approach.x)
	var facing := Vector3(approach.x, 0.0, approach.y)
	gate_slots = []
	for k in [-1.0, 0.0, 1.0]:
		gate_slots.append({"at": beacon + approach * 14.0 + side * 10.0 * k, "facing": facing})
	hard_points = []
	relic_spot = Vector2(-8.0, -115.0)
	for post in CROWN_POSTS:
		hard_points.append({"at": post["at"]})
	contraptions = []
	var ids := ["thermal_a", "thermal_b", "thermal_c"]
	for i in CROWN_THERMALS.size():
		contraptions.append({"kind": "thermal", "id": ids[i], "at": CROWN_THERMALS[i], "radius": 5.0, "height": CROWN_THERMAL_HEIGHT})
	var spawn_isle: Dictionary = isles["spawn"]
	var west: Dictionary = isles["west"]
	var down: Vector2 = ((west["at"] as Vector2) - spawn).normalized()
	var from: Vector2 = spawn + down * 14.0
	var to: Vector2 = (west["at"] as Vector2) - down * 11.0
	contraptions.append({"kind": "cable", "id": "grapple_line", "from": Vector3(from.x, float(spawn_isle["top"]) + 2.6, from.y),
		"to": Vector3(to.x, float(west["top"]) + 2.4, to.y), "radius": 4.5, "floor": 18.0})
	for barge in CROWN_BARGES:
		var a: Dictionary = isles[barge["from"]]
		var b: Dictionary = isles[barge["to"]]
		var dir: Vector2 = ((b["at"] as Vector2) - (a["at"] as Vector2)).normalized()
		var at_a: Vector2 = (a["at"] as Vector2) + dir * (float(a["radius"]) + BARGE_DOCK)
		var at_b: Vector2 = (b["at"] as Vector2) - dir * (float(b["radius"]) + BARGE_DOCK)
		contraptions.append({"kind": "barge", "id": barge["id"],
			"a": Vector3(at_a.x, float(a["top"]) - BARGE_SIZE.y * 0.5, at_a.y),
			"b": Vector3(at_b.x, float(b["top"]) - BARGE_SIZE.y * 0.5, at_b.y),
			"size": BARGE_SIZE, "travel": barge["travel"], "dwell": 3.0, "offset": 0.0})
	activity_sites = [
		{"id": "enemy_camp", "at": Vector2(-100.0, -30.0), "pack": ["chaser", "chaser", "lobber"], "pay": {"named": "rivet_plating"}},
		{"id": "hauler_bounty", "at": Vector2(95.9, 65.7)},
		{"id": "cracked_cache", "at": Vector2(36.6, 6.5)},
	]
	rescue_sites = []


func _islands() -> Dictionary:
	return CROWN_ISLANDS


func _bridges() -> Array:
	return CROWN_BRIDGES


func _posts() -> Array:
	return CROWN_POSTS
