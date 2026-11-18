# smoke: bots timeout=900s (one bot_run child from stage 1 through Brindle into stage 3: 268 s wall alone on a 4-core cloud box on 2026-11-12; a loaded gate box can double it)
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const PrimCensus := preload("res://tools/prim_census.gd")
const T := preload("res://tests/support/t.gd")

# Rule (SG-13, the world 1 visual assets audit, 12 November 2026): nothing a player meets is drawn
# from a Godot primitive mesh unless the pin says so. One skipper bot (seed 40317, the Pylon
# Engineer, the park table) plays the dam, the flume and Brindle with tools/prim_census_run.gd, which
# lists every primitive surface drawn; tools/prim_census.gd judges the list against
# tools/prim_census_pin.tsv:
#   new      a surface no pin row covers fails, named by owner, mesh, path and tick. Give it a model,
#            or pin it as code with the reason it is meant to be a shape (a mark, a ring, an effect)
#   stand-in an object still waiting for its model (the pin's BACKLOG row owes it) passes as a skip;
#            with SCRAPKEEP_RELEASE_GATE=1 each one fails, the switch release_gate_placeholder_test reads
#   stale    a stand-in row (built with its stage) that matched nothing fails: its model landed, so
#            drop the row and the pin falls. W1-21 to W1-23 and W1-46 land that way. A stand-in-live
#            row (an object only play spawns: cogs, an elite's crate, a reward gate) is never stale
# Keys are one per owner, mesh and shape: a second primitive under a key already pinned is not seen.
# The test is bot tier, so sketch:fast sends it to the bot shards and the wave gate runs it.
# Control: the child hangs a BoxMesh on the first park activity (--prim-plant=1); the census must
# call it new, so the test can fail.
#
# Evidence limit: one seed, one pilot, one table. A surface the run never builds (a stage-2 secret
# this bot skips, a drop it never sees) is not judged; the whole tree is scanned every 30 ticks, so
# what a stage builds counts whether or not the ball goes near it.

# Receipt (scripts/gate/stand-ins-receipt.mjs, the world 1 done read's row no-code-stand-ins): the test ends with
#   SUMMARY {"surfaces", "pinned", "stand_ins", "new", "stale", "plant"}
# PRIM_PLANT=dam_box is the receipt's plant: the control box is judged as a real surface, a new code-built box the
# pin does not cover, so the test must fail and name it. MIN_SURFACES is the least the run must count; fewer means
# part of the world was not built.

const SEED := 40317
const PILOT := "pylon_engineer"
const TIMEOUT_S := 840.0
# 129 is the count this run measured on stage/alpha-w44 d313e95f3 (17 Nov 2026): every primitive surface key drawn
# from stage 1 into stage 3, the control box left out. It falls when a stand-in gets its model or a stage stops building
# a mark; a fall that is meant lowers this pin (and PINNED_SURFACES in scripts/gate/stand-ins-receipt.mjs) in the same
# change, with the census line that went. A fall nobody meant is a stage that was not built, and fails here.
const MIN_SURFACES := 129

var _areas := {}
var _area_hits := []
var _t := T.new("prim_census_test")


func _initialize() -> void:
	if OS.get_environment("PRIM_SCOPE") == "all":
		_scan_areas.call_deferred()
		return
	var enforce := OS.get_environment("SCRAPKEEP_RELEASE_GATE") == "1"
	_judge_rules()
	var pin := PrimCensus.load_pin()
	var bad: Array = pin.filter(func(p): return p.has("error"))
	_t.check("the pin reads", not pin.is_empty() and bad.is_empty(), "; ".join(bad.map(func(p): return "line %d: %s" % [p.line, p.error])))
	var out := OS.get_user_data_dir().path_join("prim-census-%d" % OS.get_process_id())
	var result: Dictionary = ChildRuns.run([{"script": "res://tools/prim_census_run.gd", "args": ["--out=" + out, "--table=park",
		"--policy=skipper", "--pilot=" + PILOT, "--seeds=%d" % SEED, "--until=2", "--prim-plant=1"]}], TIMEOUT_S)[0]
	var log := String(result["log"])
	var errors: Array = ChildRuns.summary(result)["errors"]
	_t.check("child ran clean", result["code"] == 0 and not result["timed_out"] and errors.is_empty(),
		"exit %s, timed out %s, %.0f s; %s" % [result["code"], result["timed_out"], result["seconds"], "; ".join(errors.slice(0, 3))])
	_t.check("the bot played through Brindle into stage 3", log.contains("-> until at stage 3"), _tail(log))
	var census := _rows(log)
	var planted := census.filter(func(r): return String(r.shape).ends_with("/" + "PlantedStandIn"))
	var plant := OS.get_environment("PRIM_PLANT")
	var real: Array[Dictionary] = []
	real.assign(census.filter(func(r): return plant == "dam_box" or not String(r.shape).ends_with("/PlantedStandIn")))
	_t.check("control: the BoxMesh planted on a park activity is new to the pin",
		planted.size() == 1 and PrimCensus.pin_for(planted[0], pin).is_empty(), "%d planted rows" % planted.size())
	var verdict := PrimCensus.judge(real, pin)
	_t.check("the census saw at least the pinned surfaces", real.size() >= MIN_SURFACES and real.size() > 50, "%d, pinned %d" % [real.size(), MIN_SURFACES])
	_t.check("no primitive surface outside the pin", verdict.unlisted.is_empty(),
		"%d new: %s" % [verdict.unlisted.size(), "; ".join(verdict.unlisted.slice(0, 8).map(PrimCensus.describe))])
	_t.check("no stale stand-in row (its model landed: drop the row)", verdict.stale.is_empty(),
		"; ".join(verdict.stale.map(func(p): return "line %d %s|%s|%s (%s)" % [p.line, p.owner, p.mesh, p.shape, p.row])))
	var by_row := {}
	for hit in verdict.stand_ins:
		by_row[hit.row] = by_row.get(hit.row, 0) + 1
		if enforce:
			_t.check("stand-in drawn from a primitive (%s)" % hit.row, false, PrimCensus.describe(hit))
	for row in by_row:
		print("[skip] %d stand-in surface(s) owed by %s" % [by_row[row], row])
	print("prim census: %d surfaces, %d code, %d stand-in" % [real.size(), real.size() - verdict.stand_ins.size() - verdict.unlisted.size(), verdict.stand_ins.size()])
	var brief := func(r): return {"file": r.owner, "mesh": r.mesh, "shape": r.shape, "row": r.get("row", ""), "path": r.get("path", ""), "stage": r.get("stage", 0)}
	print("SUMMARY " + JSON.stringify({"surfaces": real.size(), "pinned": MIN_SURFACES, "stand_ins": verdict.stand_ins.map(brief),
		"new": verdict.unlisted.map(brief), "stale": verdict.stale.map(func(p): return {"line": p.line, "file": p.owner, "mesh": p.mesh, "shape": p.shape, "row": p.row}),
		"plant": plant}))
	_remove_tree(out)
	quit(_t.verdict())


# The judge on made-up rows: a covered code row, a stand-in, an unlisted row, a stale stand-in row,
# and a malformed pin line.
func _judge_rules() -> void:
	var pin: Array[Dictionary] = [
		{"owner": "beacon.gd", "mesh": "*", "shape": "*/Beacon/*", "kind": "code", "row": "-", "why": "x", "line": 1},
		{"owner": "activities.gd", "mesh": "BoxMesh", "shape": "Activity_ambush_altar/*", "kind": "stand-in", "row": "W1-22", "why": "x", "line": 2},
		{"owner": "radio_cache.gd", "mesh": "*", "shape": "*", "kind": "stand-in", "row": "W1-23", "why": "x", "line": 3},
		{"owner": "scrap_field.gd", "mesh": "*", "shape": "*", "kind": "stand-in-live", "row": "W1-21", "why": "x", "line": 4},
	]
	var rows: Array[Dictionary] = [
		{"key": "a", "owner": "beacon.gd", "mesh": "TorusMesh", "shape": "Node3D/Beacon/MeshInstance3D"},
		{"key": "b", "owner": "activities.gd", "mesh": "BoxMesh", "shape": "Activity_ambush_altar/MeshInstance3D"},
		{"key": "c", "owner": "activities.gd", "mesh": "BoxMesh", "shape": "Activities/Activity_cracked_cache/PlantedStandIn"},
	]
	var verdict := PrimCensus.judge(rows, pin)
	_t.check("judge: a pinned code row passes, a stand-in is listed, an unpinned row is new",
		verdict.unlisted.map(func(r): return r.key) == ["c"] and verdict.stand_ins.map(func(r): return r.key) == ["b"])
	_t.check("judge: a stand-in row that matched nothing is stale, a stand-in-live row is not", verdict.stale.map(func(p): return p.line) == [3])
	_t.check("shape: engine names keep their class, given names lose their digits",
		PrimCensus.shape_of("@Node3D@2/Activities/Find_dam_shift_radio/@StaticBody3D@1954/@MeshInstance3D@1953")
			== "Find_dam_shift_radio/StaticBody3D/MeshInstance3D" and PrimCensus.shape_of("Chunk0_0/Pip12") == "Chunk_/Pip")
	var file := FileAccess.open("user://prim_census_bad_pin.tsv", FileAccess.WRITE)
	file.store_string("# comment\nbeacon.gd\tSphereMesh\t*\tcode\t-\tthe beacon\nradio_cache.gd\t*\t*\tstand-in\t-\tno row\n")
	file.close()
	var read := PrimCensus.load_pin("user://prim_census_bad_pin.tsv")
	_t.check("pin: a stand-in with no BACKLOG row is an error", read.size() == 2 and not read[0].has("error") and read[1].has("error"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://prim_census_bad_pin.tsv"))


func _rows(log: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line in log.split("\n"):
		if not line.begins_with("PRIM\t"):
			continue
		var c := line.split("\t")
		if c.size() < 8:
			continue
		out.append({"tick": int(c[1]), "stage": int(c[2]), "owner": c[4], "mesh": c[5], "shape": c[6], "path": c[7],
			"key": "%s|%s|%s" % [c[4], c[5], c[6]]})
	return out


func _tail(log: String) -> String:
	var lines := log.strip_edges().split("\n")
	return " | ".join(lines.slice(maxi(0, lines.size() - 3)))


func _remove_tree(dir: String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_remove_tree(dir.path_join(sub))
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)

# These stations use the live game for the area census. Each station has its own
# surface set, so a mesh seen at the title still counts if the shop also draws it.

func _station(area: String, where: Node, ready: bool) -> void:
	if not _t.check("station reached: " + area, ready and is_instance_valid(where)):
		return
	var census := PrimCensus.new()
	var rows := census.scan(where, Engine.get_physics_frames(), 0, true)
	var pin := PrimCensus.load_pin()
	var findings := 0
	for row in rows:
		var rule := PrimCensus.pin_for(row, pin)
		if rule.get("kind", "") == "code":
			continue
		var hit := {"area": area, "file": row.owner, "mesh": row.mesh, "shape": row.shape,
			"path": row.path, "row": rule.get("row", "W1-143b"), "why": rule.get("why", "")}
		findings += 1
		_area_hits.append(hit)
	_areas[area] = {"surfaces": rows.size(), "findings": findings}


func _scan_areas() -> void:
	var game = preload("res://src/game.gd").new()
	game.test_mode = true
	game.table = "park"
	preload("res://src/core/sim_clock.gd").ticks = true
	root.add_child(game)
	await process_frame
	await process_frame
	game.run.run_seed_override = SEED
	var screens = game.screens
	screens.prologue_enabled = false
	_station("menu/title", game, game.flow.state_name() == "title")
	for page in ["help", "settings", "achievements"]:
		screens.call("toggle_" + page)
		await process_frame
		_station("menu/" + page, game, screens.call(page + "_open"))
		screens.call("toggle_" + page)
	screens.toggle_camp()
	await process_frame
	var hub = game.camp_hub
	var plant := OS.get_environment("PRIM_PLANT")
	if plant == "camp_box" and hub.built:
		var box := MeshInstance3D.new()
		box.name = "PlantedCampBox"
		box.mesh = BoxMesh.new()
		hub.root.add_child(box)
	_station("camp", hub.root, hub.built and hub.walking)
	for page in ["radio", "jukebox"]:
		screens.call("toggle_" + page)
		await process_frame
		_station("menu/" + page, game, screens.call(page + "_open"))
		screens.call("toggle_" + page)
	screens.toggle_camp()
	game.flow.press_start()
	await process_frame
	var roster := preload("res://src/core/class_def.gd").all()
	_station("menu/pilot-select", game, screens.class_cards().size() == roster.size())
	game.flow.choose_class(0)
	await physics_frame
	var hero = game.presentation.hero_assets
	_t.eq("six pilot definitions", roster.size(), 6)
	for pilot in roster:
		game.player.fit_class(pilot)
		await process_frame
		hero._process(0.0)
		var rec: Dictionary = hero.shell_of(game.player)
		_station("pilot/" + pilot.id, game.player, rec.get("class") == pilot.id
			and is_instance_valid(rec.get("pod")) and is_instance_valid(rec.get("core"))
			and not game.player.find_children("*", "MeshInstance3D", true, false).is_empty())
	var pause_menu = game.get_node("PauseMenu")
	pause_menu.open()
	await process_frame
	_station("menu/pause", pause_menu, pause_menu.is_open())
	pause_menu.close()
	var workshop = game.get_node("Workshop")
	workshop.armed = true
	game.build.shop.enter()
	workshop.open_counter()
	await process_frame
	_station("shop", game, workshop.counter.is_open())
	workshop.close_counter()
	game.build.shop.leave()
	for stage in [1, 2]:
		game.flow.enter_stage(stage, Vector3.ZERO, false)
		await physics_frame
		var park: Dictionary = game.ctx.terrain.map().park
		var events: Array = park.event_rows
		_t.check("world 1 event rows on stage %d" % stage, not events.is_empty())
		for row in events:
			var family = game.world.event_families.get(row.family)
			if not _t.check("handler for " + row.id, is_instance_valid(family)):
				continue
			var site: Dictionary = park.park_rows.filter(func(r): return r.id == row.site)[0]
			var at := Vector3(float(site.at[0]), 0, float(site.at[1]))
			at.y = game.ctx.terrain.height(at.x, at.z)
			var ctx := {"at": at, "clock_s": 1.0, "ball": game.player.ball_position(), "velocity": Vector3.ZERO}
			for phase in ["telegraph", "land"]:
				family.handle(phase, row, ctx)
				await process_frame
				_station("event/%s/%s" % [row.id, phase], game, game.run.stage == stage)
			family.handle("end", row, ctx)
			await process_frame
	game.run.damage(99999.0, "census")
	await process_frame
	_station("menu/death", game, game.flow.state_name() == "dead")
	var boxes := _area_hits.filter(func(r): return r.area == "camp" and r.path.ends_with("/PlantedCampBox"))
	_t.check("camp has no planted box", boxes.is_empty(), str(boxes))
	print("AREAS " + JSON.stringify({"areas": _areas, "findings": _area_hits, "plant": plant}))
	game.free()
	quit(_t.verdict())
