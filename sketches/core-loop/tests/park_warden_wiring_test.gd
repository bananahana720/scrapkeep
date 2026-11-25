extends SceneTree
# smoke: solo timeout=300s

const Game := preload("res://src/game.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const T := preload("res://tests/support/t.gd")

# Measured by entering every alpha and default-table stage on 560d177 before the fix.
# Both tables produced these same six rows. The spec omits the fleet's object references.
# Re-pinned 2026-10-13: stages 3 to 6 carry WT-BANDS's contact-gain posture tuning (907bfef), which the park
# table mirrors; every other field is unchanged. 2026-10-23: stage 3's hive takes HIVE_HEAVY_RATIO
# 0.7 (swarm hive option 1, alpha_defs.gd). 2026-11-24 (W46-S1): stage 1 dam warden_plating moved 90 -> 105
# (alpha_defs.gd and park_defs.gd) to hold posture_bands_reactor_test grown in 25-45 s with ratio >= 2.0.
const UNCHANGED := [
  {
    "harpoon_anchor": false,
    "mounting": "dam_face",
    "radius": 30.0,
    "spec": {
      "family": "reactor",
      "hp": 650.0,
      "plating": 105.0,
      "posture": {
        "curve": 2.0,
        "ram_shatters": false
      },
      "reach": 30.0,
      "stage": 1,
      "variant": ""
    }
  },
  {
    "harpoon_anchor": false,
    "mounting": "flume",
    "radius": 30.0,
    "spec": {
      "family": "reactor",
      "hp": 800.0,
      "plating": 110.0,
      "posture": {
        "curve": 2.0,
        "ram_shatters": false
      },
      "reach": 30.0,
      "stage": 2,
      "variant": "meltdown"
    }
  },
  {
    "harpoon_anchor": false,
    "mounting": "headframe",
    "radius": 30.0,
    "spec": {
      "family": "swarm",
      "hp": 950.0,
      "plating": 130.0,
      "posture": {
        "contact_gain_floor": 0.55,
        "contact_gain_scale": 150.0,
        "curve": 2.1,
        "heavy_ratio": 0.7,
        "ram_shatters": false
      },
      "reach": 30.0,
      "stage": 3,
      "variant": ""
    }
  },
  {
    "harpoon_anchor": false,
    "mounting": "sinkhole",
    "radius": 30.0,
    "spec": {
      "family": "swarm",
      "hp": 1100.0,
      "plating": 150.0,
      "posture": {
        "contact_gain_floor": 0.55,
        "contact_gain_scale": 150.0,
        "curve": 2.1,
        "ram_shatters": false
      },
      "reach": 30.0,
      "stage": 4,
      "variant": "brood"
    }
  },
  {
    "harpoon_anchor": false,
    "mounting": "under_island",
    "radius": 30.0,
    "spec": {
      "family": "mind",
      "hp": 1250.0,
      "plating": 170.0,
      "posture": {
        "contact_gain_floor": 0.35,
        "contact_gain_scale": 10.0,
        "curve": 2.2,
        "drain_rate": 0.5,
        "ram_shatters": false
      },
      "reach": 30.0,
      "stage": 5,
      "variant": ""
    }
  },
  {
    "harpoon_anchor": false,
    "mounting": "spires",
    "radius": 30.0,
    "spec": {
      "family": "mind",
      "hp": 1400.0,
      "plating": 190.0,
      "posture": {
        "contact_gain_floor": 0.35,
        "contact_gain_scale": 10.0,
        "curve": 2.2,
        "drain_rate": 0.5,
        "ram_shatters": false
      },
      "reach": 30.0,
      "stage": 6,
      "variant": "choir"
    }
  }
]

const HARDPOINTS := [Vector3(0.0, 1.6, 0.0), Vector3(2.8, 0.0, 0.0), Vector3(-2.8, 0.0, 0.0)]
const UNCHANGED_PLACEMENTS := [Vector3(-46, 16.6, -12), Vector3(0, -6.4, 118),
	Vector3(20, 1.6, 90), Vector3(40, -10.4, 130), Vector3(0, 25.6, -60), Vector3(-20, 37.6, -115)]
const MOUNTINGS := {"reactor:": "dam_face", "reactor:meltdown": "flume", "swarm:": "headframe",
	"swarm:brood": "sinkhole", "mind:": "under_island", "mind:choir": "spires"}
var t := T.new("park_warden_wiring_test")


class PulseTarget extends RefCounted:
	var kit = null
	var at := Vector3.ZERO
	var lifts := 0

	func ball_position() -> Vector3:
		return at

	func crowd_control(_source: String, _acceleration: Vector3) -> void:
		lifts += 1


func _initialize() -> void:
	_run.call_deferred()


func _game_for(table: String):
	var game = Game.new()
	game.test_mode = true
	game.table = table
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = true
	game.flow.press_start()
	game.flow.choose_class(0)
	return game


func _run() -> void:
	for table in ["alpha", ""]:
		var game = _game_for(table)
		var label: String = "old" if table.is_empty() else table
		t.eq(label + " stage count", game.ctx.stages.COUNT, UNCHANGED.size())
		for stage in range(1, UNCHANGED.size() + 1):
			game.flow.enter_stage(stage, Vector3.ZERO, false)
			_check_unchanged(game, stage, label)
		game.free()
		await process_frame

	var game = _game_for("park")
	var files := DirAccess.get_files_at("res://src/world/park/")
	var present := 0
	var first_path := ""
	for file in files:
		if not file.ends_with(".json"):
			continue
		var path := "res://src/world/park/" + file
		var row: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var stage := 0
		for def in ParkDefs.DEFS:
			if def["map"] == row["map"]:
				stage = int(def["stage"])
		# park_test is the schema fixture, exercised in stage 1's slot on the park table.
		var fixture: bool = row["map"] == "park_test"
		if not t.check(file + " has a park stage or is the park fixture", stage > 0 or fixture):
			continue
		present += 1
		if fixture:
			_exercise_copy(game, path, 1)
		else:
			game.flow.enter_stage(stage, Vector3.ZERO, false)
			_check_park(game, path, stage)
			if first_path.is_empty():
				first_path = path
	t.check("park JSON files present", present > 0, "%d files" % present)
	# Current stage files may all say 30 m. A test-owned JSON copy separates reach from the
	# table radius, so falling back to the stage row cannot silently pass.
	if not first_path.is_empty():
		var copy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(first_path))
		copy["landmark"]["reach_m"] = 47.0
		var probe_path := "user://park_warden_wiring_reach.json"
		var out := FileAccess.open(probe_path, FileAccess.WRITE)
		out.store_string(JSON.stringify(copy))
		out.close()
		_exercise_copy(game, probe_path, 1)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(probe_path))
	var moving: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ParkMap.FIXTURE))
	moving["map"] = "park_crown"
	for home in moving["home_rows"]:
		home["reinforce"]["pack"] = "elite_highdraft"
	moving["landmark"]["warden"].merge({"family": "mind", "mounting": "spires",
		"harpoon_anchor": true, "anchor": [0, 22, 590],
		"path": [[0, 22, 590], [18, 30, 600], [-12, 24, 570]]}, true)
	var moving_path := _write_copy(moving, "moving")
	_exercise_copy(game, moving_path, 1)
	var w = game.flow.warden
	var points: Array = moving["landmark"]["warden"]["path"]
	for leg in range(points.size()):
		var start := _v3(points[leg])
		var finish := _v3(points[(leg + 1) % points.size()])
		w._step_mounting(8.0)
		_near3("moving takeoff %d" % leg, w.global_position, start)
		w._step_mounting(1.5)
		_near3("moving midpoint %d" % leg, w.global_position, start.lerp(finish, 0.5) + Vector3.UP * 9.0)
		w._step_mounting(1.5)
		_near3("moving landing %d" % leg, w.global_position, finish)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(moving_path))
	# Each copy reinforces with its world's elite pack; the Dig's is dig_elite and the Highdraft's
	# elite_highdraft (WORLD-ROSTERS.md; world 3's pack list has no plain elite since 3059e90).
	for fixture in [{"family": "reactor", "map": "park_test", "mounting": "flume", "elite": "elite"},
		{"family": "swarm", "map": "park_pit", "mounting": "sinkhole", "elite": "dig_elite"},
		{"family": "mind", "map": "park_crown", "mounting": "spires", "elite": "elite_highdraft"}]:
		for flag in range(3):
			var copy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ParkMap.FIXTURE))
			copy["map"] = fixture["map"]
			copy["landmark"]["reach_m"] = 47.0
			copy["landmark"]["warden"].merge({"family": fixture["family"],
				"mounting": fixture["mounting"], "hardpoints": flag + 1}, true)
			if flag < 2:
				copy["landmark"]["warden"]["harpoon_anchor"] = flag == 0
			else:
				copy["landmark"]["warden"].erase("harpoon_anchor")
			for home in copy["home_rows"]:
				home["reinforce"]["pack"] = fixture["elite"]
			var path := _write_copy(copy, "%s_flag_%d" % [fixture["family"], flag])
			_exercise_copy(game, path, 1)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.free()
	await process_frame
	print("park_warden_wiring_test checks: %d passed, %d failed" % [t.checks - t.failures, t.failures])
	print("park_warden_wiring_test: %s" % ("PASS" if t.failures == 0 else "FAIL"))
	quit(0 if t.failures == 0 else 1)


func _exercise_copy(game, path: String, stage: int) -> void:
	var previous = game.ctx.terrain.maps[stage - 1]
	game.ctx.terrain.maps[stage - 1] = ParkMap.new(path)
	game.flow.enter_stage(stage, Vector3.ZERO, false)
	_check_park(game, path, stage)
	game.ctx.terrain.maps[stage - 1] = previous


func _write_copy(row: Dictionary, name: String) -> String:
	var path := "user://park_warden_wiring_%s.json" % name
	var out := FileAccess.open(path, FileAccess.WRITE)
	out.store_string(JSON.stringify(row))
	out.close()
	return path


func _v3(numbers: Array) -> Vector3:
	return Vector3(float(numbers[0]), float(numbers[1]), float(numbers[2]))


func _near3(label: String, got: Vector3, want: Vector3) -> void:
	t.check(label, got.distance_to(want) < 0.0001, "got %s, want %s" % [got, want])


func _check_park(game, path: String, stage: int) -> void:
	var row: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var mark: Dictionary = row["landmark"]
	var expected: Dictionary = mark["warden"]
	var w = game.flow.warden
	var label := "%s stage %d" % [row["map"], stage]
	if not t.check(label + " spawned Warden", is_instance_valid(w)):
		return
	t.check(label + " uses loaded park map", game.ctx.terrain.map() is ParkMap and game.ctx.terrain.map().ok)
	for field in expected:
		t.eq(label + " spec " + field, w.spec.get(field), expected[field])
	if expected.has("anchor"):
		var anchor := _v3(expected["anchor"])
		_near3(label + " home", w.home, anchor)
		_near3(label + " initial world position", w.global_position, anchor)
	var family: String = expected.get("family", UNCHANGED[stage - 1]["spec"]["family"])
	var variant: String = expected.get("variant", UNCHANGED[stage - 1]["spec"]["variant"])
	var mounting: String = expected.get("mounting", MOUNTINGS.get(family + ":" + variant, ""))
	t.eq(label + " family", w.family, family)
	t.eq(label + " mounting", w.mounting, mounting)
	# A park that names "hardpoint_offsets" (P4: the dam, the flume and the sinkhole) mounts those; the rest take the first n.
	var want_points: Array = HARDPOINTS.slice(0, int(expected["hardpoints"]))
	if expected.has("hardpoint_offsets"):
		want_points = []
		for offset in expected["hardpoint_offsets"]:
			want_points.append(_v3(offset))
	t.eq(label + " hardpoint count", w.hardpoints.size(), want_points.size())
	t.eq(label + " hardpoints", w.hardpoints, want_points)
	var anchored: bool = expected.get("harpoon_anchor", false)
	t.eq(label + " harpoon anchor", w.harpoon_anchor, anchored)
	if anchored:
		t.check(label + " mount driver", w.mount_driver != null)
		if w.mount_driver != null:
			t.eq(label + " driver script", w.mount_driver.get_script().resource_path, "res://src/combat/warden_%s.gd" % family)
	else:
		t.check(label + " no mount driver", w.mount_driver == null)
	t.near(label + " beacon radius", game.flow.beacon.radius, float(mark["reach_m"]))
	t.near(label + " spec reach", float(w.spec.get("reach", -1.0)), float(mark["reach_m"]))
	t.near(label + " Warden reach", w.reach, float(mark["reach_m"]))
	_check_pulse(w, label, 30.0, float(mark["reach_m"]))


func _check_pulse(w, label: String, radius: float, engage: float) -> void:
	var target = w.target
	var driver = w.mount_driver
	var fleet = w.fleet
	var probe := PulseTarget.new()
	w.target = probe
	w.mount_driver = null
	w.fleet = null
	var outside := (radius + engage) * 0.5 if engage > radius else radius + 1.0
	probe.at = w.home + Vector3.RIGHT * outside
	probe.at.y = w.terrain.height(probe.at.x, probe.at.z) + 1.0
	if engage > radius:
		t.check(label + " pulse probe inside engage", outside < engage)
	w._step_pulse(4.0, true)
	var ring = w.telegraph()
	if t.check(label + " pulse committed", ring != null):
		t.near(label + " pulse radius", ring.radius, radius)
		t.near(label + " pulse drawn radius", float(ring.descriptor()["r_out"]), radius)
		t.near(label + " core pulse radius", w._core_ring.radius, 6.0)
	w._step_pulse(2.0, true)
	t.eq(label + " outside pulse no lift", probe.lifts, 0)
	t.eq(label + " outside pulse lifted flag", w.last_pulse_lifted, false)
	probe.at = w.home + Vector3.RIGHT * (radius - 1.0)
	probe.at.y = w.terrain.height(probe.at.x, probe.at.z) + 1.0
	w._step_pulse(4.0, true)
	w._step_pulse(2.0, true)
	t.eq(label + " inside pulse lift control", probe.lifts, 1)
	t.eq(label + " inside pulse lifted flag", w.last_pulse_lifted, true)
	w.target = target
	w.mount_driver = driver
	w.fleet = fleet


func _check_unchanged(game, stage: int, table: String) -> void:
	var expected: Dictionary = UNCHANGED[stage - 1]
	var w = game.flow.warden
	var label := "%s stage %d" % [table, stage]
	if not t.check(label + " spawned Warden", is_instance_valid(w)):
		return
	var spec: Dictionary = w.spec.duplicate()
	for field in ["fleet", "holds", "kind"]:
		spec.erase(field)
	t.eq(label + " spec unchanged", spec, expected["spec"])
	t.near(label + " beacon unchanged", game.flow.beacon.radius, float(expected["radius"]))
	t.eq(label + " family unchanged", w.family, expected["spec"]["family"])
	t.eq(label + " mounting unchanged", w.mounting, expected["mounting"])
	t.eq(label + " hardpoints unchanged", w.hardpoints, HARDPOINTS)
	t.eq(label + " harpoon unchanged", w.harpoon_anchor, expected["harpoon_anchor"])
	t.check(label + " driver unchanged", w.mount_driver == null)
	_near3(label + " home unchanged", w.home, UNCHANGED_PLACEMENTS[stage - 1])
	_near3(label + " position unchanged", w.global_position, UNCHANGED_PLACEMENTS[stage - 1])
	_check_pulse(w, label, float(expected["radius"]), float(expected["spec"]["reach"]))
