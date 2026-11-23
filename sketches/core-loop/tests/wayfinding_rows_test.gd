extends SceneTree

# Wayfinding data keys, visited state and pack read (design-v3/WAYFINDING.md sections 3, 4, 6, 7;
# ruling ek, unit E1-14):
# - ParkSchema optional keys: cable_rows, district_rows, approach (with optional far_card outside play_rect).
# - StageLocks read-only pips_lit() / packs_wanted() matching cable-dead order (pip_index < pips_lit()),
#   including enemy_camp and 75 s clock clamp openings, and clean reset on stage entry / retry.
# - SiteMarkers per-kind visited state: flips once, idempotent, resets on entry / retry / clear,
#   furnace never flips, bone/copper colour law (never mint #8BF0D3), zero static var leaks.

const T := preload("res://tests/support/t.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const LockRows := preload("res://src/world/lock_rows.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const Palette := preload("res://src/core/palette.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const StageLocks := preload("res://src/world/stage_locks.gd")
const SiteMarkers := preload("res://src/presentation/site_markers.gd")

const PARK_DIR := "res://src/world/park/"

var _t := T.new("wayfinding_rows_test")


class FakeMap extends RefCounted:
	var title := ""

	func _init(name_in: String) -> void:
		title = name_in


class FakeTerrain extends RefCounted:
	var current_map: FakeMap

	func map():
		return current_map


class FakeFlow extends RefCounted:
	var gate
	var sealed := true
	var warden = null

	func in_stage() -> bool:
		return true

	func show_start_card() -> void:
		pass


class FakePlayer extends RefCounted:
	func ball_position() -> Vector3:
		return Vector3.ZERO


# The three plume sources SiteMarkers.sites() reads, so the test drives real plume keys, not hand-written ones.
class FakeScrap extends RefCounted:
	var rows := []

	func caches() -> Array:
		return rows


class FakeDirector extends RefCounted:
	var homes := []

	func live_homes() -> Array:
		return homes


class FakeRescue extends RefCounted:
	var cages := []

	func waiting() -> Array:
		return cages


class FakeWorld extends RefCounted:
	var rescue := FakeRescue.new()
	var director := FakeDirector.new()
	var rogue_plan := {}


class FakeCtx extends RefCounted:
	var calm := false
	var stages = ParkDefs
	var terrain: FakeTerrain
	var flow: FakeFlow
	var player: FakePlayer
	var events: GameEvents


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_schema_existing_parks()
	_fixture_park_wayfinding()
	_schema_cable_rows()
	_schema_district_rows()
	_schema_approach()
	_locks_pips_lit()
	_site_markers_visited()
	quit(_t.verdict())


func _load_json(name_id: String) -> Dictionary:
	return ParkSchema.read_file("%s%s.json" % [PARK_DIR, name_id])["data"]


func _plant(base: Dictionary, label: String, id: String, rule: String, mutate: Callable, ctx := {}) -> void:
	var park: Dictionary = base.duplicate(true)
	mutate.call(park)
	var errors := ParkSchema.validate(park, ctx)
	var hit := errors.any(func(e): return e["id"] == id and e["rule"] == rule)
	_t.check("%s fails as %s [%s]" % [label, id, rule], hit, ParkSchema.describe(errors))


func _schema_existing_parks() -> void:
	for map_id in ["park_dam", "park_flume", "park_test"]:
		var read := ParkSchema.load_park("%s%s.json" % [PARK_DIR, map_id])
		_t.check("%s validates cleanly as-is" % map_id, read["errors"].is_empty(), ParkSchema.describe(read["errors"]))


# WAYFINDING.md §6 line 122 (W46 E3-06): park_test.json carries all three wayfinding keys on disk,
# loads cleanly through ParkSchema.load_park() and ParkMap, and exercises SiteMarkers visited state.
func _fixture_park_wayfinding() -> void:
	var path := PARK_DIR + "park_test.json"
	var read := ParkSchema.load_park(path)
	_t.check("park_test.json loads via ParkSchema.load_park with 0 errors", read["errors"].is_empty(), ParkSchema.describe(read["errors"]))
	var park: Dictionary = read["data"]

	# 1. cable_rows: explicitly present and empty (LockRows.row("park_test") asks for 0 gate packs).
	_t.check("park_test.json carries cable_rows", park.has("cable_rows") and park["cable_rows"] is Array)
	_t.eq("park_test.json cable_rows is empty for 0-pack fixture", park.get("cable_rows", null), [])

	# 2. district_rows: 3 non-overlapping, uniquely named abutting districts covering play_rect.
	_t.check("park_test.json carries district_rows", park.has("district_rows") and park["district_rows"] is Array)
	var districts: Array = park.get("district_rows", [])
	_t.eq("park_test.json has 3 district_rows", districts.size(), 3)
	var pr: Array = park["play_rect"]
	var play_box := Rect2(float(pr[0]), float(pr[1]), float(pr[2]), float(pr[3]))
	var seen_ids := {}
	var seen_names := {}
	var boxes: Array = []
	var covered_area := 0.0
	var all_inside := true
	var any_overlap := false
	for row in districts:
		var id := String(row.get("id", "")).strip_edges()
		var dname := String(row.get("name", "")).strip_edges()
		var grade := String(row.get("grade", "")).strip_edges()
		_t.check("fixture district %s has non-empty id, name and grade" % id, id != "" and dname != "" and grade != "")
		_t.check("fixture district %s name is in NAMES.md list" % id, ParkSchema.DISTRICT_NAMES.has(dname), dname)
		_t.check("fixture district %s id and name are unique" % id, not seen_ids.has(id) and not seen_names.has(dname))
		seen_ids[id] = true
		seen_names[dname] = true
		var r: Array = row["rect"]
		var box := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		_t.check("fixture district %s has positive rect area" % id, box.size.x > 0.0 and box.size.y > 0.0, str(r))
		if not play_box.encloses(box):
			all_inside = false
		for prior: Rect2 in boxes:
			if box.intersects(prior, false):
				any_overlap = true
		boxes.append(box)
		covered_area += box.get_area()
	_t.check("fixture districts do not overlap", not any_overlap)
	_t.check("fixture districts stay inside play_rect", all_inside, str(play_box))
	_t.near("fixture districts cover play_rect cleanly", covered_area, play_box.get_area(), 0.01)

	# 3. approach: valid to, smoke, and far_card standing strictly outside play_rect.
	_t.check("park_test.json carries approach", park.has("approach") and park["approach"] is Dictionary)
	var approach: Dictionary = park.get("approach", {})
	_t.check("fixture approach has non-empty to", String(approach.get("to", "")).strip_edges() != "")
	_t.check("fixture approach has [x, z] smoke", approach.get("smoke") is Array and (approach["smoke"] as Array).size() == 2)
	_t.check("fixture approach carries far_card", approach.has("far_card") and approach["far_card"] is Dictionary)
	var card: Dictionary = approach.get("far_card", {})
	_t.check("fixture far_card has non-empty to", String(card.get("to", "")).strip_edges() != "")
	var at: Array = card.get("at", [0.0, 0.0])
	var px := float(at[0])
	var pz := float(at[1])
	var inside_play := px >= play_box.position.x and px <= play_box.end.x and pz >= play_box.position.y and pz <= play_box.end.y
	_t.check("fixture far_card stands strictly outside play_rect", not inside_play, "%s vs %s" % [str(at), str(pr)])

	# 4. ParkMap loads park_test.json cleanly with approach populated.
	var map := ParkMap.new(path)
	_t.check("ParkMap loads park_test.json cleanly", map.ok and map.errors.is_empty(), ParkSchema.describe(map.errors))
	_t.eq("ParkMap carries fixture approach.to", map.approach.get("to", ""), String(approach["to"]))
	_t.eq("ParkMap carries fixture approach.smoke", map.approach.get("smoke", Vector2.ZERO), Vector2(float(approach["smoke"][0]), float(approach["smoke"][1])))

	# 5. SiteMarkers visited state flips and resets cleanly against park_test.json's own home_rows.
	var holder := Node3D.new()
	root.add_child(holder)
	var events := GameEvents.new()
	holder.add_child(events)
	var markers := SiteMarkers.new()
	holder.add_child(markers)
	markers.setup({"events": events})
	var home_id := String(park["home_rows"][0]["id"])
	var home_key := "crew:" + home_id
	var world := FakeWorld.new()
	var scrap := FakeScrap.new()
	world.director.homes = [{"id": home_id, "at": Vector2(0.0, -100.0)}]
	markers.sync(SiteMarkers.sites(world, scrap, null), true)
	_t.check("fixture home standing plume is unvisited", not markers.is_visited(home_key))
	world.director.homes = []
	markers.sync(SiteMarkers.sites(world, scrap, null), true)
	_t.check("fixture home flips to visited when cleared", markers.is_visited(home_key))
	_t.eq("fixture cleared home gets chalk_x mark", markers.visited_state(home_key).get("mark"), "chalk_x")
	events.stage_entered.emit(1, true)
	_t.eq("retry resets fixture visited state", markers.visited_sites(), [])
	markers.sync([], false)
	holder.free()


func _dam_cables(park: Dictionary) -> Array:
	var home_ids: Array = (park["home_rows"] as Array).map(func(r): return String(r["id"]))
	var want := int(LockRows.row("park_dam")["gate"]["packs"])
	var out := []
	for i in want:
		out.append({
			"id": "dam_cable_%d" % (i + 1),
			"pip": i + 1,
			"to": home_ids[i % home_ids.size()],
			"via": [[float(i * 20), 400.0], [float(i * 15), 200.0]],
		})
	return out


func _schema_cable_rows() -> void:
	var dam := _load_json("park_dam")
	var valid_dam := dam.duplicate(true)
	valid_dam["cable_rows"] = _dam_cables(dam)
	var errs := ParkSchema.validate(valid_dam)
	_t.check("dam with 5 valid cable_rows passes", errs.is_empty(), ParkSchema.describe(errs))

	var flume := _load_json("park_flume")
	var valid_flume := flume.duplicate(true)
	valid_flume["cable_rows"] = [{
		"id": "flume_cable_1",
		"pip": 1,
		"to": String(flume["home_rows"][0]["id"]),
		"via": [[100.0, 200.0]],
	}]
	errs = ParkSchema.validate(valid_flume)
	_t.check("flume with 1 valid cable_row passes", errs.is_empty(), ParkSchema.describe(errs))

	var fixture := _load_json("park_test")
	var empty_test := fixture.duplicate(true)
	empty_test["cable_rows"] = []
	errs = ParkSchema.validate(empty_test)
	_t.check("0-pack park with empty cable_rows passes", errs.is_empty(), ParkSchema.describe(errs))

	var ctx_two := ParkSchema.stage_context("park_test").merged({"gate_packs": 2}, true)
	var two_test := fixture.duplicate(true)
	two_test["cable_rows"] = [
		{"id": "c1", "pip": 1, "to": "wash_chasers", "via": []},
		{"id": "c2", "pip": 2, "to": "ledge_lobbers", "via": [[-100.0, 50.0]]},
	]
	errs = ParkSchema.validate(two_test, ctx_two)
	_t.check("park_test with ctx gate_packs=2 and 2 cables passes", errs.is_empty(), ParkSchema.describe(errs))

	# Planted cable_rows errors.
	_plant(valid_dam, "cable_rows not an array", "cable_rows", "type", func(p): p["cable_rows"] = {})
	_plant(valid_dam, "cable to unknown home", "dam_cable_1", "reference", func(p): p["cable_rows"][0]["to"] = "no_home")
	_plant(valid_dam, "cable via bad point", "dam_cable_2", "type", func(p): p["cable_rows"][1]["via"] = [[0, 1, 2]])
	_plant(valid_dam, "cable pip 0", "dam_cable_1", "cable", func(p): p["cable_rows"][0]["pip"] = 0)
	_plant(valid_dam, "cable fractional pip", "dam_cable_1", "cable", func(p): p["cable_rows"][0]["pip"] = 1.5)
	_plant(valid_dam, "duplicate cable pip", "dam_cable_2", "duplicate", func(p): p["cable_rows"][1]["pip"] = 1)
	_plant(valid_dam, "missing cable pip 5", "cable_rows", "cable", func(p): p["cable_rows"].pop_back())
	_plant(valid_dam, "cable pip past gate packs", "dam_cable_6", "cable", func(p):
		p["cable_rows"].append({"id": "dam_cable_6", "pip": 6, "to": p["cable_rows"][0]["to"], "via": []}))
	_plant(fixture, "0-pack park with a cable", "cable_rows", "cable", func(p):
		p["cable_rows"] = [{"id": "c1", "pip": 1, "to": "wash_chasers", "via": []}])


func _schema_district_rows() -> void:
	var dam := _load_json("park_dam")
	var valid_dam := dam.duplicate(true)
	# Adjacent districts sharing an exact border edge (z = -200, z = 200) must not count as overlapping.
	valid_dam["district_rows"] = [
		{"id": "intake", "name": "Intake Catwalks", "rect": [-760, -780, 1520, 580], "grade": "dam_intake"},
		{"id": "apron", "name": "Spillway Apron", "rect": [-760, -200, 1520, 400], "grade": "dam_apron"},
		{"id": "pump_yard", "name": "Sunken Pump Yard", "rect": [-760, 200, 1520, 560], "grade": "dam_pump"},
	]
	var errs := ParkSchema.validate(valid_dam)
	_t.check("dam with 3 abutting non-overlapping districts passes", errs.is_empty(), ParkSchema.describe(errs))

	var flume := _load_json("park_flume")
	var valid_flume := flume.duplicate(true)
	valid_flume["district_rows"] = [
		{"id": "weir", "name": "Weir Bobsled", "rect": [-780, -780, 1300, 500], "grade": "flume_weir"},
		{"id": "trestle", "name": "Trestle Span", "rect": [-780, -280, 1300, 500], "grade": "flume_trestle"},
		{"id": "headhouse", "name": "Headhouse Overlook", "rect": [-780, 220, 1300, 560], "grade": "flume_headhouse"},
	]
	errs = ParkSchema.validate(valid_flume)
	_t.check("flume with 3 valid NAMES.md districts passes", errs.is_empty(), ParkSchema.describe(errs))

	# World 2/3 extensibility (WAYFINDING.md §7): parks outside World 1 accept unique non-empty district names
	# with no code change while still checking non-empty name, uniqueness, non-overlap and non-empty grade.
	var pit := _load_json("park_pit")
	var valid_pit := pit.duplicate(true)
	valid_pit["district_rows"] = [
		{"id": "upper_bench", "name": "Upper Haul Bench", "rect": [-780, -790, 1560, 520], "grade": "pit_upper"},
		{"id": "pit_floor", "name": "Main Pit Floor", "rect": [-780, -270, 1560, 540], "grade": "pit_floor"},
		{"id": "tailings", "name": "Tailings Rim", "rect": [-780, 270, 1560, 520], "grade": "pit_tailings"},
	]
	errs = ParkSchema.validate(valid_pit)
	_t.check("world 2 park_pit accepts valid non-W1 district_rows without code change", errs.is_empty(), ParkSchema.describe(errs))
	_plant(valid_pit, "world 2 blank district name", "upper_bench", "district", func(p): p["district_rows"][0]["name"] = "   ")
	_plant(valid_pit, "world 2 duplicate district name", "pit_floor", "duplicate", func(p): p["district_rows"][1]["name"] = "Upper Haul Bench")
	_plant(valid_pit, "world 2 overlapping districts", "pit_floor", "district", func(p): p["district_rows"][1]["rect"] = [-780, -300, 1560, 570])

	# Planted district_rows errors on World 1.
	_plant(valid_dam, "district_rows not an array", "district_rows", "type", func(p): p["district_rows"] = "intake")
	_plant(valid_dam, "district name not in NAMES.md", "intake", "enum", func(p): p["district_rows"][0]["name"] = "The Sump")
	_plant(valid_dam, "world 1 blank district name", "intake", "district", func(p): p["district_rows"][0]["name"] = "  ")
	_plant(valid_dam, "duplicate district name", "apron", "duplicate", func(p): p["district_rows"][1]["name"] = "Intake Catwalks")
	_plant(valid_dam, "overlapping districts", "apron", "district", func(p): p["district_rows"][1]["rect"] = [-760, -250, 1520, 450])
	_plant(valid_dam, "zero-width district rect", "intake", "district", func(p): p["district_rows"][0]["rect"] = [-760, -780, 0, 580])
	_plant(valid_dam, "empty district grade", "pump_yard", "district", func(p): p["district_rows"][2]["grade"] = "   ")


func _schema_approach() -> void:
	var dam := _load_json("park_dam")
	var valid_dam := dam.duplicate(true)
	# play_rect on park_dam is [-760, -780, 1520, 1540] -> x in [-760, 760], z in [-780, 760].
	valid_dam["approach"] = {
		"to": "slag_bowl",
		"smoke": [460, 2080],
		"far_card": {"at": [0, 1050], "to": "park_flume", "size": [420, 120], "yaw_deg": 0},
	}
	var errs := ParkSchema.validate(valid_dam)
	_t.check("dam approach with smoke and far_card outside play_rect passes", errs.is_empty(), ParkSchema.describe(errs))

	# Planted approach errors.
	_plant(valid_dam, "approach empty to", "approach", "missing", func(p): p["approach"]["to"] = "")
	_plant(valid_dam, "approach missing smoke", "approach", "missing", func(p): p["approach"].erase("smoke"))
	_plant(valid_dam, "far_card inside play_rect", "approach", "approach", func(p): p["approach"]["far_card"]["at"] = [0, 500])
	_plant(valid_dam, "far_card on play_rect edge", "approach", "approach", func(p): p["approach"]["far_card"]["at"] = [0, 760])
	_plant(valid_dam, "far_card empty to", "approach", "missing", func(p): p["approach"]["far_card"]["to"] = "")
	_plant(valid_dam, "far_card non-positive size", "approach", "approach", func(p): p["approach"]["far_card"]["size"] = [0, 120])
	_plant(valid_dam, "far_card bad yaw_deg", "approach", "type", func(p): p["approach"]["far_card"]["yaw_deg"] = "north")


func _dead_cables(locks: StageLocks) -> Array:
	var out := []
	var lit := locks.pips_lit()
	for i in locks.packs_wanted():
		out.append(i < lit)
	return out


func _locks_pips_lit() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var ctx := FakeCtx.new()
	ctx.events = GameEvents.new()
	ctx.terrain = FakeTerrain.new()
	ctx.flow = FakeFlow.new()
	ctx.player = FakePlayer.new()
	var locks := StageLocks.new()
	holder.add_child(locks)
	locks.setup(ctx)

	# Dam: 5 packs -> 5 pips/cables in fixed order.
	ctx.terrain.current_map = FakeMap.new("park_dam")
	ctx.events.stage_entered.emit(1, false)
	_t.eq("dam wants 5 packs", locks.packs_wanted(), 5)
	_t.eq("dam starts with 0 pips lit", locks.pips_lit(), 0)
	_t.eq("all 5 cables alive on entry", _dead_cables(locks), [false, false, false, false, false])

	for k in range(1, 5):
		locks.cleared = k
		_t.eq("after %d pack(s) pips_lit is %d" % [k, k], locks.pips_lit(), k)
		var dead := _dead_cables(locks)
		var expect := []
		for i in 5:
			expect.append(i < k)
		_t.eq("cable-dead order matches pip_index < %d" % k, dead, expect)

	# Enemy camp opens clamp early -> every remaining pip lights and kills every remaining cable.
	locks.cleared = 2
	_t.eq("at 2 cleared before camp, pips_lit is 2", locks.pips_lit(), 2)
	ctx.events.activity_done.emit("enemy_camp", Vector3.ZERO)
	locks._step_gate()
	_t.check("enemy_camp opens the clamp", not locks.locked())
	_t.eq("enemy_camp lights all 5 pips", locks.pips_lit(), 5)
	_t.eq("all 5 cables dead once enemy_camp opens clamp", _dead_cables(locks), [true, true, true, true, true])

	# Retry resets pips_lit back to 0 and revives every cable.
	ctx.events.stage_entered.emit(1, true)
	_t.check("retry re-shuts dam clamp", locks.locked())
	_t.eq("retry resets pips_lit to 0", locks.pips_lit(), 0)
	_t.eq("all 5 cables alive after retry", _dead_cables(locks), [false, false, false, false, false])

	# 75 s engaged clock opens clamp -> every remaining pip lights and kills every remaining cable.
	ctx.events.warden_engaged.emit(1)
	locks._engaged_s = float(LockRows.row("park_dam")["gate"]["max_s"])
	locks._step_gate()
	_t.check("75 s clock opens the clamp", not locks.locked())
	_t.eq("75 s clock lights all 5 pips", locks.pips_lit(), 5)
	_t.eq("all 5 cables dead once clock opens clamp", _dead_cables(locks), [true, true, true, true, true])

	# Stage 2 (park_flume): 1 pack -> 1 pip/cable.
	ctx.terrain.current_map = FakeMap.new("park_flume")
	ctx.events.stage_entered.emit(2, false)
	_t.eq("flume wants 1 pack", locks.packs_wanted(), 1)
	_t.eq("flume starts with 0 pips lit", locks.pips_lit(), 0)
	locks.cleared = 1
	locks._step_gate()
	_t.eq("flume pack lights pip 1", locks.pips_lit(), 1)
	_t.eq("flume cable dead", _dead_cables(locks), [true])

	# Park with no gate row (park_pit): 0 wanted, 0 lit.
	ctx.terrain.current_map = FakeMap.new("park_pit")
	ctx.events.stage_entered.emit(3, false)
	_t.eq("park_pit wants 0 packs", locks.packs_wanted(), 0)
	_t.eq("park_pit pips_lit is 0", locks.pips_lit(), 0)

	holder.free()


func _site_markers_visited() -> void:
	var mint := Palette.live()
	var flipping_kinds := ["cache", "crew", "cage", "rogue", "shortcut", "cable"]
	for kind in flipping_kinds + ["furnace"]:
		var spec := SiteMarkers.visited_spec(kind)
		_t.check("%s has a visited spec" % kind, not spec.is_empty())
		_t.eq("%s visited mark has zero glow (quiet)" % kind, float(spec["glow"]), 0.0)
		_t.check("%s visited mark is still" % kind, bool(spec["still"]))
		_t.check("%s visited spec adds no text label" % kind, not spec.has("label") and not spec.has("text"))
		_t.check("%s visited color is never mint (#8BF0D3)" % kind, spec["color"] != mint and spec["color"] != Palette.ARC)
		_t.check("%s visited tie is never mint (#8BF0D3)" % kind, spec["tie"] != mint and spec["tie"] != Palette.ARC)

	var cache_spec := SiteMarkers.visited_spec("cache")
	_t.eq("cleared cache mark is a flag", cache_spec["mark"], "flag")
	_t.eq("cleared cache flag colour is bone/sand", cache_spec["color"], Palette.SAND)
	_t.eq("cleared cache tie colour is copper", cache_spec["tie"], Palette.COPPER)

	var crew_spec := SiteMarkers.visited_spec("crew")
	_t.eq("cleared crew mark is chalk_x (never PAID)", crew_spec["mark"], "chalk_x")
	_t.eq("cleared crew chalk colour is bone/sand", crew_spec["color"], Palette.SAND)

	var cage_spec := SiteMarkers.visited_spec("cage")
	_t.eq("freed cage mark is scarf_post", cage_spec["mark"], "scarf_post")
	_t.eq("freed cage post colour is bone/sand", cage_spec["color"], Palette.SAND)
	_t.eq("freed cage default scarf colour is copper (Rivet)", cage_spec["tie"], Palette.COPPER)

	var holder := Node3D.new()
	root.add_child(holder)
	var events := GameEvents.new()
	var markers := SiteMarkers.new()
	var other := SiteMarkers.new()
	holder.add_child(markers)
	holder.add_child(other)
	markers.setup({"events": events})

	# Every flipping kind flips once and is idempotent on repeat calls.
	for i in flipping_kinds.size():
		var kind: String = flipping_kinds[i]
		var key := "%s:site_%d" % [kind, i]
		var at := Vector3(float(i * 10), 2.0, -float(i * 5))
		_t.check("%s starts unvisited" % kind, not markers.is_visited(key))
		_t.check("%s flips once -> true" % kind, markers.mark_visited(key, kind, at))
		_t.check("%s is now visited" % kind, markers.is_visited(key))
		_t.check("%s repeat flip is idempotent -> false" % kind, not markers.mark_visited(key, kind, Vector3(999, 9, 999)))
		var state := markers.visited_state(key)
		_t.eq("%s keeps first flip position" % kind, state["at"], at)
		_t.eq("%s state carries kind mark" % kind, state["mark"], SiteMarkers.visited_spec(kind)["mark"])
		# Defensive copy: mutating returned dict does not mutate internal state.
		state["mark"] = "tampered"
		_t.eq("%s internal state is unaffected by caller mutation" % kind, markers.visited_state(key)["mark"], SiteMarkers.visited_spec(kind)["mark"])

	# Zero static var leaks: sibling instance has its own clean visited table.
	_t.eq("sibling SiteMarkers instance shares no static visited state", other.visited_sites(), [])

	# Furnace never flips; unknown kind and empty key never flip.
	_t.check("furnace never flips", not markers.mark_visited("furnace", "furnace", Vector3(900, 0, 480)))
	_t.check("furnace stays unvisited", not markers.is_visited("furnace"))
	_t.check("unknown kind never flips", not markers.mark_visited("x:1", "mystery", Vector3.ZERO))
	_t.check("empty key never flips", not markers.mark_visited("", "cache", Vector3.ZERO))

	# Stage entry, retry and clear all reset visited state completely.
	_t.eq("six flipping kinds recorded", markers.visited_sites().size(), flipping_kinds.size())
	events.stage_entered.emit(1, false)
	_t.eq("stage_entered resets visited state", markers.visited_sites(), [])

	markers.mark_visited("cache:10:20", "cache", Vector3(1, 0, 2))
	events.stage_entered.emit(1, true)
	_t.eq("retry resets visited state", markers.visited_sites(), [])

	markers.mark_visited("crew:culvert_chasers", "crew", Vector3(10, 0, 20))
	events.stage_content_cleared.emit("test")
	_t.eq("stage_content_cleared resets visited state", markers.visited_sites(), [])

	_plume_keyed_flips(markers, events, holder)

	# sync(..., true) flips disappeared sites even when player is within GONE_M (view.visible == false),
	# while furnace leaving sync(..., true) does not flip, and sync(..., false) does not flip.
	markers.reset_visited()
	markers.sync([
		{"key": "cache:50:60", "kind": "cache", "at": Vector3(5.0, 1.0, 6.0)},
		{"key": "furnace", "kind": "furnace", "at": Vector3(900.0, 0.0, 480.0)},
		{"key": "rogue:dam_mb_mid", "kind": "rogue", "at": Vector3(104.0, 5.0, 96.0)},
	], false)
	_t.check("sync without fade leaves sites unvisited", markers.visited_sites().is_empty())
	# Leave view.visible == false (as when eye is inside GONE_M) and drop all three with fade=true.
	# Waking a rogue drops its sleeping smoke plume WITHOUT marking it visited.
	markers.sync([], true)
	_t.check("cache disappearing in live sync flips to visited even while plume hidden", markers.is_visited("cache:50:60"))
	_t.check("furnace disappearing in live sync never flips to visited", not markers.is_visited("furnace"))
	_t.check("waking a rogue removes its plume without marking it visited",
		not markers.views.has("rogue:dam_mb_mid") and not markers.is_visited("rogue:dam_mb_mid"))

	# Non-rogue kills never flip the rogue; defeating a Rogue.ROWS kind flips it once at its death spot.
	events.enemy_killed.emit("chaser", Vector3(110.0, 5.0, 100.0), 4)
	_t.check("plain enemy kill does not mark rogue visited", not markers.is_visited("rogue:dam_mb_mid"))
	var death_at := Vector3(142.0, 4.0, 128.0)
	events.enemy_killed.emit("rogue_crane", death_at, 30)
	_t.check("defeating a rogue flips its site to visited", markers.is_visited("rogue:dam_mb_mid"))
	var rogue_state := markers.visited_state("rogue:dam_mb_mid")
	_t.eq("rogue visited mark is wreck", rogue_state["mark"], "wreck")
	_t.eq("rogue visited position is its death spot, not spawn", rogue_state["at"], death_at)
	events.enemy_killed.emit("rogue_crane", Vector3(999.0, 9.0, 999.0), 30)
	_t.eq("repeat rogue kill keeps first death spot (idempotent)", markers.visited_state("rogue:dam_mb_mid")["at"], death_at)
	events.stage_entered.emit(1, true)
	_t.eq("retry clears rogue visited state and tracked key", markers.visited_sites(), [])

	holder.free()


# Crew and cache flip only by their plume keys (crew:<home id> from director.live_homes(), cache:<foot> from
# scrap_field.caches()) through sync's fade; an activity's activity_done is no plume site and flips nothing.
func _plume_keyed_flips(markers: SiteMarkers, events: GameEvents, holder: Node3D) -> void:
	markers.reset_visited()
	# Regression: the Dam's enemy_camp (domes_camp) and cracked caches (rim_cache, incline_cache) keep no visited row.
	events.activity_done.emit("enemy_camp", Vector3(-51.0, 2.0, -396.0))
	events.activity_done.emit("cracked_cache", Vector3(-210.0, 0.0, 400.0))
	events.activity_done.emit("cracked_cache", Vector3(-44.0, 0.0, 255.0))
	_t.eq("enemy_camp and cracked_cache activity_done add no visited row", markers.visited_sites(), [])

	var dam := _load_json("park_dam")
	var home_id := String(dam["home_rows"][0]["id"])
	var home_at := Vector2(-120.0, 300.0)
	var rib := Node3D.new()
	holder.add_child(rib)
	var foot := Vector3(33.4, 6.0, -71.2)
	var world := FakeWorld.new()
	var scrap := FakeScrap.new()
	world.director.homes = [{"id": home_id, "at": home_at}]
	world.rescue.cages = [{"quest": "rivet", "at": Vector3(8.0, 1.0, 9.0)}]
	scrap.rows = [{"item": rib, "foot": foot}]
	var list := SiteMarkers.sites(world, scrap, null)
	var keys: Array = list.map(func(row): return String(row["key"]))
	var crew_key := "crew:" + home_id
	var cache_key := "cache:334:-712"
	_t.check("the crew plume is keyed by its home id", keys.has(crew_key), str(keys))
	_t.check("the cache plume is keyed by its foot", keys.has(cache_key), str(keys))
	markers.sync(list, true)
	_t.eq("standing plumes flip nothing", markers.visited_sites(), [])
	# Activity events while the plumes stand still flip neither of them.
	events.activity_done.emit("enemy_camp", Vector3(home_at.x, 0.0, home_at.y))
	events.activity_done.emit("cracked_cache", foot)
	_t.eq("activity_done beside standing plumes adds no visited row", markers.visited_sites(), [])

	# A rescue whose cage never stood a plume has no site; one whose plume stands flips at the plume's foot.
	events.rescue_completed.emit("ghost")
	_t.check("a rescue with no cage plume adds no visited row", not markers.is_visited("cage:ghost") and markers.visited_sites().is_empty())
	events.rescue_completed.emit("rivet")
	_t.eq("rescue_completed flips the cage at its plume's foot", markers.visited_state("cage:rivet").get("at"), Vector3(8.0, 1.0, 9.0))

	# The home breaks and the cache is taken: the next live sync drops both plumes and flips them by their plume keys.
	world.director.homes = []
	scrap.rows = []
	markers.sync(SiteMarkers.sites(world, scrap, null), true)
	_t.eq("a broken crew home flips by its plume key", markers.visited_state(crew_key).get("mark"), "chalk_x")
	_t.eq("the crew mark stands at the home", markers.visited_state(crew_key).get("at"), Vector3(home_at.x, 0.0, home_at.y))
	_t.eq("a taken rib cache flips by its plume key", markers.visited_state(cache_key).get("mark"), "flag")
	_t.eq("the cache flag stands at its foot", markers.visited_state(cache_key).get("at"), foot)
	var flipped: Array = markers.visited_sites().map(func(row): return String(row["key"]))
	flipped.sort()
	var want := [cache_key, "cage:rivet", crew_key]
	want.sort()
	_t.eq("only plume keys are visited", flipped, want)
	markers.sync([], false)
	rib.free()
