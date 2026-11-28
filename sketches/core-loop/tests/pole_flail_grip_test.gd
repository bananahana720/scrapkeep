extends SceneTree

const Grip := preload("res://src/movement/grip.gd")
const Roster := preload("res://src/combat/roster.gd")
const Augments := preload("res://src/movement/augments.gd")
const T := preload("res://tests/support/t.gd")

# PF1 (design-v3/POLES-FLAILS.md section 11): weight decides the grip a held harpoon takes on
# a bitten enemy. A table of ball heft against roster kinds gives pole, reel or flail, including
# both band edges; trap ratings stand in for chassis heft; Wardens and bosses never flail; the
# aim record carries the grip the press would take, and a world aim carries none.

var _t := T.new("pole_flail_grip_test")


class FakeEnemy extends Node3D:
	var kind := "chaser"
	var threat_level := 1.0
	var spec := {}


class FakeTrap extends FakeEnemy:
	var rating := 1.6


func _initialize() -> void:
	_run()
	quit(_t.verdict())


func _enemy(kind: String, threat := 1.0, affix := "", script = FakeEnemy) -> Node3D:
	var body: Node3D = script.new()
	body.kind = kind
	body.threat_level = threat
	body.spec = {"affix": affix} if affix != "" else {}
	body.add_to_group("enemy")
	root.add_child(body)
	return body


func _anchor() -> Node3D:
	var body := _enemy("warden")
	body.add_to_group(Augments.ANCHOR_GROUP)
	return body


func _trap(rating: float) -> Node3D:
	var body: Node3D = _enemy("mag_trapper", 1.0, "", FakeTrap)
	body.rating = rating
	return body


func _run() -> void:
	var rows := [
		["fresh ball flails a swarm drone", 1.0, _enemy("swarm_remnant"), Grip.FLAIL],
		["fresh ball reels a winch drone", 1.0, _enemy("winch_drone"), Grip.REEL],
		["fresh ball poles a chaser", 1.0, _enemy("chaser"), Grip.POLE],
		["just under the pole edge", 1.14, _enemy("chaser"), Grip.POLE],
		["just over the pole edge reels", 1.16, _enemy("chaser"), Grip.REEL],
		["just over the flail edge", 1.66, _enemy("chaser"), Grip.FLAIL],
		["grown ball rips out a lobber", 3.2, _enemy("lobber"), Grip.FLAIL],
		["pole edge on a heavy is a pole", 3.75, _enemy("plated_brute"), Grip.POLE],
		["flail edge on a heavy is a flail", 4.25, _enemy("plated_brute"), Grip.FLAIL],
		["elite heavy at class V still reels", 4.6, _enemy("plated_brute", 1.0, "target_stamp"), Grip.REEL],
		["threat raises heft", 1.6, _enemy("chaser", 2.0), Grip.REEL],
		["trap rating stands in for chassis", 3.0, _trap(2.0), Grip.FLAIL],
		["even with the trap rating reels", 2.0, _trap(2.0), Grip.REEL],
		["huge ball never flails an anchor Warden", 9.0, _anchor(), Grip.POLE],
		["a Warden that is no anchor reels", 9.0, _enemy("warden"), Grip.REEL],
		["a boss body never flails", 9.0, _enemy("brindle_hull"), Grip.REEL],
		["the vault never flails", 9.0, _enemy("vault"), Grip.REEL],
	]
	for r in rows:
		_t.eq(r[0], Grip.of(r[2], r[1], Roster.heft_of(r[2])), r[3])
	_t.near("chassis heft", Roster.heft_of(_enemy("chaser")), 1.4)
	_t.near("threat 2 heft", Roster.heft_of(_enemy("chaser", 2.0)), 1.8)
	_t.near("elite heft", Roster.heft_of(_enemy("plated_brute", 1.0, "target_stamp")), 4.5)
	_t.check("boss heft is infinite", Roster.heft_of(_enemy("brindle_hull")) == INF)

	var loose := Node3D.new()
	root.add_child(loose)
	_t.eq("a body outside the enemy group has no grip", Grip.of(loose, 1.0, Roster.heft_of(loose)), "")
	var swarm := _enemy("swarm_remnant")
	var aim := Grip.mark({"state": 2, "point": Vector3.ZERO, "body": swarm}, 1.0, Roster.heft_of(swarm))
	_t.eq("aim on a body carries the grip", aim.get("grip", ""), Grip.FLAIL)
	var world := Grip.mark({"state": 1, "point": Vector3.ZERO, "grip": "pole"}, 1.0, INF)
	_t.check("a world aim carries no grip", not world.has("grip"))
