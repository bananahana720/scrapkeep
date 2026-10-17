extends "res://src/world/map_highdraft.gd"

# Highdraft: the crown, greybox. The second Highdraft zone over the same net deck at NET_H:
# every island stands at least NET_H + 24, and the spawn-to-beacon chain is about 1.47 times
# the first zone's centre spacing. Two long ridge bridges join spawn to beacon through the
# middle island, so the route still needs no thermal. Two barges reach the vault and west
# islands, a cable runs from the spawn island down to the west island, three thermal columns
# rise from open deck past every island top, and a harpoon post stands on each island's rim
# toward the next island. The parent's shape code reads these tables through its seams.

# Each island: centre, flat-top radius, top height. Keys match the parent's so its _init reads.
const CROWN_ISLANDS := {
	"spawn": {"at": Vector2(-30.0, 125.0), "radius": 18.0, "top": NET_H + 30.0},
	"mid": {"at": Vector2(30.0, 10.0), "radius": 16.0, "top": NET_H + 28.0},
	"beacon": {"at": Vector2(-20.0, -115.0), "radius": 22.0, "top": NET_H + 26.0},
	"vault": {"at": Vector2(100.0, 60.0), "radius": 14.0, "top": NET_H + 34.0},
	"west": {"at": Vector2(-100.0, -30.0), "radius": 14.0, "top": NET_H + 24.0},
}
const CROWN_BRIDGES := [["spawn", "mid"], ["mid", "beacon"]]
# Open deck, clear of every island skirt and bridge.
const CROWN_THERMALS := [Vector2(-60.0, 60.0), Vector2(70.0, -50.0), Vector2(40.0, -130.0)]
# Thermal columns reach past the highest top (NET_H + 34) from the deck.
const CROWN_THERMAL_HEIGHT := 46.0
# Each barge runs from 8 m past one island's rim to 8 m short of the other's, on the line
# between their centres; neither lane crosses a bridge.
const CROWN_BARGES := [
	{"id": "barge_isle", "from": "mid", "to": "vault", "travel": 10.0},
	{"id": "barge_west", "from": "beacon", "to": "west", "travel": 14.0},
]
const BARGE_DOCK := 8.0
# One per island, 3 m inside its rim toward the next island and 7 m to one side of the
# bridge or barge dock.
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
	# The gates stand 14 m past the beacon along the bridge's approach, as on the first zone.
	var approach: Vector2 = (beacon - mid).normalized()
	var side := Vector2(-approach.y, approach.x)
	var facing := Vector3(approach.x, 0.0, approach.y)
	gate_slots = []
	for k in [-1.0, 0.0, 1.0]:
		gate_slots.append({"at": beacon + approach * 14.0 + side * 10.0 * k, "facing": facing})
	hard_points = []
	# The beacon island's top, 18 m east of its centre: the relic cache. At (-8, -115) it stood on
	# the line from the bridge landing to the east gate's run-in and walled that gate off (seed 2506).
	relic_spot = beacon + side * 18.0
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
	# The camp holds the west island, the bounty brute guards the vault 7 m to the side of the dock.
	# 2026-10-08 (wave 11, GP1): the cache sits on the middle island's east lip, on the outside of
	# the turn between the two bridges, its pocket clear of the walk across.
	activity_sites = [
		{"id": "enemy_camp", "at": Vector2(-100.0, -30.0), "pack": ["chaser", "chaser", "lobber"], "pay": {"named": "rivet_plating"}},
		{"id": "hauler_bounty", "at": Vector2(95.9, 65.7)},
		{"id": "cracked_cache", "at": Vector2(36.6, 6.5)},
	]
	# The parent's rescue is the first zone's; the crown has none.
	rescue_sites = []


func _islands() -> Dictionary:
	return CROWN_ISLANDS


func _bridges() -> Array:
	return CROWN_BRIDGES


func _posts() -> Array:
	return CROWN_POSTS
