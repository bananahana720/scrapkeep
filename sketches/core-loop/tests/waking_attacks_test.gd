extends SceneTree

const WakingAttacks := preload("res://src/boss/waking_attacks.gd")
const BossAttacks := preload("res://src/boss/boss_attacks.gd")
const T := preload("res://tests/support/t.gd")

# The Waking's attack families as pure rules (waking_attacks.gd): which floor exposes which
# family, each family's shape and timing, the warning gap inside one attack, and the escape
# guarantee over a seeded sweep of balls, headings and phases on the 36 m floor.
#
# Evidence limit: rules only. The fight, the floor rule and the bank are in
# waking_attack_fight_test.gd.

const RADIUS := 36.0
const CRUISE := 14.0
const SWEEP := 400

var _t := T.new("waking_attacks_test")


func _initialize() -> void:
	var center := Vector3(5.0, 12.0, -3.0)
	_t.eq("Spoil exposes burrow", WakingAttacks.exposed(1), ["burrow"])
	_t.eq("Seam adds cave-in", WakingAttacks.exposed(2), ["burrow", "cave_in"])
	_t.eq("Bedrock adds bore", WakingAttacks.exposed(3), ["burrow", "cave_in", "bore"])
	_t.eq("the pit keeps all three", WakingAttacks.exposed(4), ["burrow", "cave_in", "bore"])
	_t.eq("each floor teaches its own", [WakingAttacks.newest(1), WakingAttacks.newest(2), WakingAttacks.newest(3)],
			["burrow", "cave_in", "bore"])

	var ball := center + Vector3(10.0, 0.0, 4.0)
	var one := WakingAttacks.burrow(1, ball, center, 1, RADIUS)
	_t.eq("Spoil burrow is one lane", one.size(), 1)
	_t.check("the lane runs at the ball", BossAttacks.covers(one[0], ball), str(one[0]["dir"]))
	var two := WakingAttacks.burrow(1, ball, center, 2, RADIUS)
	_t.eq("Seam burrow is two lanes", two.size(), 2)
	_t.near("the second lane warns a gap later", float(two[1]["delay"]), WakingAttacks.GAP)

	var cave := WakingAttacks.cave_in(3, ball, Vector3(0.0, 0.0, 12.0), center, 2, RADIUS)
	_t.eq("three cave-in holes", cave.size(), WakingAttacks.CAVE_COUNT)
	for i in cave.size():
		_t.near("hole %d warns %d gaps in" % [i, i], float(cave[i]["delay"]), WakingAttacks.GAP * i)
		var along: float = (cave[i]["at"] - ball).dot(Vector3(0.0, 0.0, 1.0))
		_t.check("hole %d sits down the ball's line" % i, along > 0.0, "along %.1f" % along)
		_t.check("hole %d inside the floor" % i, _flat(cave[i]["at"] - center).length() <= RADIUS - WakingAttacks.CAVE_R + 0.001)

	var bore := WakingAttacks.bore(5, ball, center, 3, RADIUS)
	_t.eq("Bedrock bore is one hole", bore.size(), 1)
	_t.check("the bore opens under the ball", BossAttacks.covers(bore[0], ball))
	var pit := WakingAttacks.bore(5, ball, center, 4, RADIUS)
	_t.eq("pit bore sprays three lanes", pit.size(), 1 + WakingAttacks.PIT_SPRAY)
	for d in pit.slice(1):
		var tip: Vector3 = d["from"] + d["dir"] * (float(d["ahead"]) + float(d["half"]))
		_t.check("spray %s stays on the floor" % d["id"], _flat(tip - center).length() <= RADIUS + 0.01, str(tip))

	# Every delay is a whole number of gaps, so no two of one attack's warnings start closer.
	var off_grid := 0
	var no_escape := 0
	var paths := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in SWEEP:
		var phase := 1 + i % 4
		var r := rng.randf_range(0.0, RADIUS - 2.0)
		var a := rng.randf() * TAU
		var at := center + Vector3(cos(a) * r, 0.0, sin(a) * r)
		var heading := Vector3(cos(a * 3.0), 0.0, sin(a * 3.0)) * rng.randf_range(0.0, 24.0)
		for family in WakingAttacks.exposed(phase):
			var safe := WakingAttacks.commit_safe(family, i * 31 + 7, at, heading, center, phase, CRUISE, RADIUS)
			paths[safe["path"]] = int(paths.get(safe["path"], 0)) + 1
			var descs: Array = safe["descriptors"]
			if not descs.is_empty() and BossAttacks.escape_point(descs, at, CRUISE, center, RADIUS) == null:
				no_escape += 1
			for d in descs:
				var steps := float(d["delay"]) / WakingAttacks.GAP
				if absf(steps - roundf(steps)) > 0.001:
					off_grid += 1
	print("waking_attacks: commit paths %s" % str(paths))
	_t.eq("every laid set leaves a way out", no_escape, 0)
	_t.eq("every delay is whole gaps", off_grid, 0)
	_t.eq("nothing fell back to an empty set", int(paths.get("none", 0)), 0)
	quit(_t.verdict())


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
