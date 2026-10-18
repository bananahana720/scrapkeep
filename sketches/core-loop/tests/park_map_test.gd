extends SceneTree

# Rule: park_map.gd fills every stage_map field today's systems read (spawn, heading, beacon,
# play_rect, contraptions, kickers, gate_slots, activity_sites, landmark, scatter) from the
# park fixture, in the shapes those readers take, and a park that fails the schema fills
# nothing (design-v3/PARK.md 2.9, K-UNITS KB2).
const ParkMap := preload("res://src/world/park/park_map.gd")
const Contraptions := preload("res://src/world/contraptions.gd")
const Activities := preload("res://src/world/activities.gd")

const EPS := 0.001

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _report(label: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _run() -> void:
	var map = ParkMap.new()
	_report("fixture loads", map.ok and map.errors.is_empty(), str(map.errors))
	_header(map)
	_landmark(map)
	_kickers(map)
	_contraptions(map)
	_activities(map)
	_scatter(map)
	_bad_park()
	print("park_map_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _header(map) -> void:
	_report("title is the map id", map.title == "park_test", map.title)
	_report("spawn", map.spawn.is_equal_approx(Vector2(-100.0, -700.0)), str(map.spawn))
	# heading_deg 30 turns from +z toward +x.
	_report("heading", map.heading.is_equal_approx(Vector3(0.5, 0.0, sqrt(3.0) * 0.5)), str(map.heading))
	_report("play_rect", map.play_rect.is_equal_approx(Rect2(-760.0, -780.0, 1520.0, 1480.0)), str(map.play_rect))
	_report("time of day", map.time_of_day == "dawn", map.time_of_day)


func _landmark(map) -> void:
	_report("beacon", map.beacon.is_equal_approx(Vector2(0.0, 575.0)), str(map.beacon))
	_report("reach", is_equal_approx(map.reach_m, 30.0), str(map.reach_m))
	# terrain.gd landmark_point reads m.landmark when the field exists.
	_report("landmark is sight_top", "landmark" in map and map.landmark.is_equal_approx(Vector3(0.0, 141.0, 640.0)),
		str(map.landmark))
	_report("bay dock", map.bay_dock["at"].is_equal_approx(Vector2(0.0, 467.0))
		and map.bay_dock["facing"].is_equal_approx(Vector3(0.0, 0.0, 1.0)), str(map.bay_dock))
	var slots: Array = map.gate_slots
	# reward_gates.gd _slot_plan reads slot["at"] as Vector2 and slot["facing"] as Vector3.
	var shaped := slots.size() == 3 and slots.all(func(s): return s["at"] is Vector2 and s["facing"] is Vector3)
	_report("three gate slots shaped for reward_gates", shaped, str(slots))
	if shaped:
		_report("gate slot 1", slots[1]["at"].is_equal_approx(Vector2(0.0, 528.0))
			and slots[1]["facing"].is_equal_approx(Vector3(1.0, 0.0, 0.0)), str(slots[1]))


func _kickers(map) -> void:
	var kickers: Array = map.kickers
	_report("one kicker from the kicker row", kickers.size() == 1, str(kickers))
	if kickers.size() != 1:
		return
	var k: Dictionary = kickers[0]
	# The lip row: at [0, -100], 20 m long facing +z, 30 m wide; the lip is its far end.
	_report("kicker lip", k["at"].is_equal_approx(Vector2(0.0, -90.0)) and k["dir"].is_equal_approx(Vector2(0.0, 1.0))
		and is_equal_approx(k["width"], 30.0), str(k))
	_report("near_kicker_lip reads it", map.near_kicker_lip(Vector2(0.0, -92.0)) and not map.near_kicker_lip(Vector2(0.0, -60.0)))


func _contraptions(map) -> void:
	var specs: Array = map.contraptions
	_report("seven contraptions", specs.size() == 7, str(specs.map(func(s): return s["id"])))
	var by_id := {}
	for s in specs:
		by_id[s["id"]] = s
	_report("launcher vectors", by_id["deck_cannon"]["at"] is Vector2
		and by_id["deck_cannon"]["target"].is_equal_approx(Vector3(-20.0, 60.0, -500.0)), str(by_id["deck_cannon"]))
	_report("valve door vectors", by_id["ledge_valve"]["door"]["at"] is Vector2
		and by_id["ledge_valve"]["door"]["size"].is_equal_approx(Vector3(12.0, 6.0, 1.0)), str(by_id["ledge_valve"]))
	_report("barge ends are Vector3", by_id["pool_barge"]["a"] is Vector3 and by_id["pool_barge"]["b"] is Vector3)
	_report("cable ends are Vector3", by_id["bench_zip"]["from"] is Vector3 and by_id["bench_zip"]["to"] is Vector3)
	# contraptions.gd builds every kind from the park's specs, unchanged.
	var stage := Node3D.new()
	root.add_child(stage)
	var c = Contraptions.new()
	stage.add_child(c)
	c.setup(map, func(x: float, z: float, lift: float): return Vector3(x, lift, z), 14.0, 26.0)
	var built: int = c.barges.size() + c.lifts.size() + c.launchers.size() + c.cables.size() + c.valves.size() \
		+ c.walls.size() + c.thermals.size()
	_report("contraptions.gd builds all seven", built == 7, str(built))
	stage.free()


func _activities(map) -> void:
	var sites: Array = map.activity_sites
	_report("three activity sites", sites.size() == 3, str(sites))
	# activities.gd keys its rule by the site's id, the activity kind.
	_report("ids are activity kinds", sites.all(func(s): return Activities.RULES.has(s["id"]) and s["at"] is Vector2),
		str(sites.map(func(s): return s["id"])))
	var camp: Dictionary = sites.filter(func(s): return s["id"] == "enemy_camp")[0]
	_report("camp carries its pack and pay", camp["pack"] == ["chaser", "chaser", "chaser"]
		and camp["pay"] == {"named": "hot_rivets"} and camp["row"] == "wash_camp", str(camp))
	var cache: Dictionary = sites.filter(func(s): return s["id"] == "cracked_cache")[0]
	# Re-pinned 2026-10-11 (KB8b): the fixture's cache now carries its PARK.md 2.12 pay.rarities.
	_report("an empty pack keeps the rule's own and the row's pay passes through",
		not cache.has("pack") and cache.get("pay") == {"rarities": ["rare"]}, str(cache))


func _scatter(map) -> void:
	var keep: Array = map.scatter.get("keep_out", [])
	# 37 park rows, three of them ground and two stamped plain slopes (a bank and a drop), plus the landmark.
	_report("scatter keeps out of 33 footprints", keep.size() == 33, str(keep.size()))
	_report("scatter keeps today's keys", map.scatter.has("kit") and map.scatter.has("clear") and map.scatter.has("spacing"))
	var dam: Array = keep.filter(func(f): return f["id"] == "test_dam")
	_report("landmark footprint", dam.size() == 1 and dam[0]["size"].is_equal_approx(Vector2(120.0, 320.0)), str(dam))


# A park with a planted schema error fills nothing.
func _bad_park() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ParkMap.FIXTURE))
	data["spawn"]["at"] = [300, 300]
	data["weather_rows"][0]["handling"] = "slippery"
	var temp := "user://park_map_bad.json"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var map = ParkMap.new(temp)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
	var named: bool = map.errors.any(func(e): return e["id"] == "test_clear" and e["rule"] == "handling")
	_report("bad park names its row and fills nothing", not map.ok and named and map.spawn == Vector2.ZERO
		and map.contraptions.is_empty() and map.landmark == Vector3.INF, str(map.errors))
