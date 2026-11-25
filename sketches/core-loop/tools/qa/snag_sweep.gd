extends SceneTree

# than 20% of the lanes were skipped. Under --headless MultiMesh instances are not drawn into the

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const Probe := preload("res://tools/qa/snag_probe.gd")

const MAX_SKIP := 0.2

var _settings := {}
var _t0 := 0


func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			_settings[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	if _settings.has("merge") and _settings.has("out"):
		quit(_merge(String(_settings["merge"]).split(","), String(_settings["out"])))
		return
	var shard := String(_settings.get("shard", "0/1")).split("/")
	if not _settings.has("out") or not _settings.has("map") or shard.size() != 2 or int(shard[1]) < 1 or int(shard[0]) >= int(shard[1]):
		printerr("snag_sweep: --map=<park map|arena> --out=<file.json> [--shard=i/n] [--seed=1] [--only=<substring>]  or  --merge=<a.json>,<b.json> --out=<file.json>")
		quit(2)
		return
	_run.call_deferred()


func _load() -> String:
	var out := []
	OS.execute("cat", ["/proc/loadavg"], out)
	return "?" if out.is_empty() else String(out[0]).split(" ")[0]


func _wall() -> String:
	return "wall %.0f s, load %s" % [(Time.get_ticks_msec() - _t0) / 1000.0, _load()]


func _run() -> void:
	print("snag_sweep: start, load %s" % _load())
	var map_id := String(_settings["map"])
	var arena := map_id == "arena"
	var stage := 2
	if not arena:
		stage = 0
		for row in ParkDefs.DEFS:
			if String(row.get("map", "")) == map_id:
				stage = int(row["stage"])
		if stage == 0:
			printerr("snag_sweep: %s is not a park table map" % map_id)
			quit(2)
			return
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	game.ground_behind_menu = false
	root.add_child(game)
	while game.flow == null:
		await process_frame
	game.run.run_seed_override = int(_settings.get("seed", "1"))
	game.ctx.calm = true
	var source := Intent.Scripted.new()
	game.player.source = source
	game.flow.press_start()
	game.flow.choose_class(0)
	if stage != 1:
		game.flow.enter_stage(stage, Vector3.ZERO, false)
	var terrain = game.ctx.terrain
	var waited := 0
	while waited < 3000 and not (terrain.rows_ready(stage) and terrain.is_ready(stage) and game.flow.state_name() == "stage"):
		await process_frame
		waited += 1
	if game.presentation.park_props != null:
		game.presentation.park_props.finish()
	for i in 30:
		await physics_frame
	var bowl: Node3D = null
	if arena:
		game.flow._finish_stage()
		waited = 0
		while waited < 1200 and (bowl == null or not bowl.built()):
			await process_frame
			waited += 1
			var found := game.find_children("SlagBowl", "Node3D", true, false)
			bowl = found[0] if not found.is_empty() else null
		for i in 240:
			await process_frame
		if bowl == null:
			printerr("snag_sweep: no SlagBowl after stage 2 finished")
			quit(1)
			return
	for i in 10:
		await physics_frame
	var probe = Probe.new(self, game, source)
	probe.index_drawn([game])
	var gb := AABB()
	var everything: Array = probe.pieces(bowl if arena else game, arena)
	var all := []
	if arena:
		all = everything
	else:
		gb = probe.ground_bounds(game)
		for p in everything:
			if Probe.inside(p, gb):
				all.append(p)
	var off_map := everything.size() - all.size()
	var shard := String(_settings.get("shard", "0/1")).split("/")
	var si := int(shard[0])
	var sn := int(shard[1])
	var only := String(_settings.get("only", ""))
	var meta := {"map": map_id, "seed": int(_settings.get("seed", "1")), "shard": String(_settings.get("shard", "0/1")),
		"display": DisplayServer.get_name(), "multimesh_trusted": probe.multimesh_trusted, "pieces_total": all.size(),
		"pieces_off_map": off_map, "pieces_in_shard": 0, "lanes_run": 0, "lanes_skipped": 0, "skipped_reasons": {},
		"controls_run": 0, "loss": probe.loss, "window_s": probe.window_s, "max_angle_deg": probe.max_angle_deg, "complete": false}
	var snags := []
	var controls := []
	for n in all.size():
		if n % sn != si or (only != "" and only not in String(all[n].path)):
			continue
		meta["pieces_in_shard"] += 1
		for lane in probe.lanes(all[n]):
			var row: Dictionary = await probe.roll(all[n], lane)
			if row.has("skipped"):
				_skip(meta, row, String(all[n].path))
				continue
			meta["lanes_run"] += 1
			if row.has("piece"):
				var pc: Vector3 = Probe.center(all[n])
				row["piece_at"] = [snappedf(pc.x, 0.1), snappedf(pc.y, 0.1), snappedf(pc.z, 0.1)]
				row["size"] = [snappedf(all[n].aabb.size.x, 0.1), snappedf(all[n].aabb.size.z, 0.1), snappedf(all[n].aabb.size.y, 0.1)]
				snags.append(row)
		_write(String(_settings["out"]), meta, snags, controls)
		print("snag_sweep: piece %d/%d %s, %d snags so far, %s" % [n + 1, all.size(), String(all[n].path).get_file(), snags.size(), _wall()])
	if not arena and gb.size.x > 0.0 and only == "":
		var lanes: Array = probe.control_lanes(all, gb)
		var top := gb.end.y
		for k in lanes.size():
			if k % sn != si:
				continue
			var ctl := {"path": "control", "aabb": AABB(Vector3(lanes[k].from.x, top - 1.0, lanes[k].from.y), Vector3(0, 1, 0)), "yaw": 0.0}
			var row: Dictionary = await probe.roll(ctl, lanes[k])
			if row.has("skipped"):
				_skip(meta, row, "control")
				continue
			meta["controls_run"] += 1
			meta["lanes_run"] += 1
			if row.has("piece"):
				controls.append(row)
		print("snag_sweep: %d control lanes of %d, %d snags, %s" % [meta["controls_run"], lanes.size(), controls.size(), _wall()])
	meta["complete"] = true
	if not _write(String(_settings["out"]), meta, snags, controls):
		quit(2)
		return
	print("snag_sweep: %s shard %s done, %s" % [map_id, meta["shard"], _wall()])
	quit(_verdict(meta, snags, controls))


func _skip(meta: Dictionary, row: Dictionary, path: String) -> void:
	meta["lanes_skipped"] += 1
	var why: Dictionary = meta["skipped_reasons"]
	var key := "%s at %s" % [row["skipped"], path.get_file() if path == "control" else path.trim_prefix("/root/").get_slice("/", 1)]
	why[key] = int(why.get(key, 0)) + 1


static func _report(meta: Dictionary, snags: Array, controls: Array) -> Dictionary:
	var out := meta.duplicate(true)
	snags.sort_custom(func(a, b): return JSON.stringify(a) < JSON.stringify(b))
	controls.sort_custom(func(a, b): return JSON.stringify(a) < JSON.stringify(b))
	out["snags"] = snags
	out["controls"] = controls
	out["classes_raw"] = _by_class(snags)
	var places: Array = Probe.dedupe(snags)
	out["places"] = places
	out["classes_places"] = _by_class(places)
	var ride_snags := snags.filter(func(r): return String(r.get("lane", "")) == "ride")
	out["classes_ride_raw"] = _by_class(ride_snags)
	var ride_places: Array = Probe.dedupe(ride_snags)
	out["ride_places"] = ride_places
	out["classes_ride_places"] = _by_class(ride_places)
	out["seams"] = Probe.dedupe(controls)
	return out


static func _by_class(rows: Array) -> Dictionary:
	var c := {"piece": 0, "ground": 0, "other": 0, Probe.MOVING: 0}
	for r in rows:
		c[r["class"]] += 1
	return c


func _write(path: String, meta: Dictionary, snags: Array, controls: Array) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("snag_sweep: cannot write %s" % path)
		return false
	f.store_string(JSON.stringify(_report(meta, snags.duplicate(), controls.duplicate()), "\t"))
	f.close()
	return true


func _verdict(meta: Dictionary, snags: Array, controls: Array) -> int:
	var rep := _report(meta, snags.duplicate(), controls.duplicate())
	var total := int(meta["lanes_run"]) + int(meta["lanes_skipped"])
	print("snag_sweep: %d pieces (%d off the map left out), %d lanes, %d skipped" % [meta["pieces_in_shard"], meta["pieces_off_map"], total, meta["lanes_skipped"]])
	print("snag_sweep: snags %s -> %d places %s" % [rep["classes_raw"], rep["places"].size(), rep["classes_places"]])
	print("snag_sweep: ride snags %s -> %d places %s" % [rep["classes_ride_raw"], rep["ride_places"].size(), rep["classes_ride_places"]])
	print("snag_sweep: control lanes %d run, %d snags, %d seam places" % [meta["controls_run"], controls.size(), rep["seams"].size()])
	if total > 0 and float(meta["lanes_skipped"]) / float(total) > MAX_SKIP:
		printerr("snag_sweep: FAIL, %d of %d lanes skipped (limit %d%%): %s" % [meta["lanes_skipped"], total, int(MAX_SKIP * 100), meta["skipped_reasons"]])
		return 1
	return 0


func _merge(files: PackedStringArray, out_path: String) -> int:
	var meta := {}
	var snags := []
	var controls := []
	var shards := []
	for fp in files:
		var f := FileAccess.open(fp, FileAccess.READ)
		var d = null if f == null else JSON.parse_string(f.get_as_text())
		if not (d is Dictionary):
			printerr("snag_sweep: cannot read %s" % fp)
			return 2
		if not bool(d.get("complete", false)):
			printerr("snag_sweep: %s is not complete (a killed run)" % fp)
			return 2
		if meta.is_empty():
			meta = d.duplicate(true)
			for k in ["snags", "controls", "classes_raw", "places", "classes_places", "ride_places", "classes_ride_places", "classes_ride_raw", "seams"]:
				meta.erase(k)
			for k in ["pieces_in_shard", "lanes_run", "lanes_skipped", "controls_run"]:
				meta[k] = 0
			meta["skipped_reasons"] = {}
		elif d["map"] != meta["map"] or d["seed"] != meta["seed"]:
			printerr("snag_sweep: %s is a different map or seed" % fp)
			return 2
		for k in ["pieces_in_shard", "lanes_run", "lanes_skipped", "controls_run"]:
			meta[k] += int(d[k])
		for k in d["skipped_reasons"]:
			meta["skipped_reasons"][k] = int(meta["skipped_reasons"].get(k, 0)) + int(d["skipped_reasons"][k])
		snags.append_array(d["snags"])
		controls.append_array(d["controls"])
		shards.append(String(d["shard"]))
	shards.sort()
	meta["shard"] = "merged " + ",".join(shards)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		printerr("snag_sweep: cannot write %s" % out_path)
		return 2
	f.store_string(JSON.stringify(_report(meta, snags.duplicate(), controls.duplicate()), "\t"))
	f.close()
	return _verdict(meta, snags, controls)
