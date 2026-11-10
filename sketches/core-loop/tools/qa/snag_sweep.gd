extends SceneTree

# Snag sweep (wave 36, map standard point 8c): finds where a fast ball loses half its speed against
# a contact facing its line of travel, along or over every large static piece of one map. The probe
# itself (what a piece is, the lanes, what a snag is) is tools/qa/snag_probe.gd; this boots the map,
# deals the pieces out to shards and writes one JSON file. Calm (no enemies); it only reads the game.
#
#   $GODOT_BIN --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/qa/snag_sweep.gd -- \
#     --map=park_flume|park_dam|...|arena --out=<file.json> [--shard=0/1] [--seed=1] [--only=<path substring>]
#
# Each snag row: position (at), contact normal (n), the piece rolled at (piece) and the collider hit
# (hit), the lane kind (ride or graze), speed before and after, and visible (a drawn mesh covers the
# contact). Under --headless MultiMesh instances are not drawn into the index (the dummy renderer
# keeps no transforms), so visible false is then a lower bound; "multimesh_trusted" says which.
# --map=arena finishes stage 2 into the Slag Bowl, as tools/qa/invisible_walls.gd does.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const Probe := preload("res://tools/qa/snag_probe.gd")

var _settings := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			_settings[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	var shard := String(_settings.get("shard", "0/1")).split("/")
	if not _settings.has("out") or not _settings.has("map") or shard.size() != 2 or int(shard[1]) < 1 or int(shard[0]) >= int(shard[1]):
		printerr("snag_sweep: --map=<park map|arena> --out=<file.json> [--shard=i/n] [--seed=1] [--only=<substring>]")
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
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
	if arena:
		game.flow._finish_stage()
		var bowl: Node3D = null
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
	var all: Array = probe.pieces(game)
	var shard := String(_settings.get("shard", "0/1")).split("/")
	var only := String(_settings.get("only", ""))
	var snags := []
	var lanes_run := 0
	var skipped := 0
	var mine := 0
	for n in all.size():
		if n % int(shard[1]) != int(shard[0]) or (only != "" and only not in String(all[n].path)):
			continue
		mine += 1
		for lane in probe.lanes(all[n]):
			var row: Dictionary = await probe.roll(all[n], lane)
			if row.has("skipped"):
				skipped += 1
				continue
			lanes_run += 1
			if row.has("piece"):
				var pc: Vector3 = Probe.center(all[n])
				row["piece_at"] = [snappedf(pc.x, 0.1), snappedf(pc.y, 0.1), snappedf(pc.z, 0.1)]
				row["hit_is_piece"] = String(row["hit"]) == String(all[n].path)
				row["size"] = [snappedf(all[n].aabb.size.x, 0.1), snappedf(all[n].aabb.size.y, 0.1), snappedf(all[n].aabb.size.z, 0.1)]
				snags.append(row)
		print("snag_sweep: piece %d/%d %s, %d snags so far" % [n + 1, all.size(), String(all[n].path).get_file(), snags.size()])
	var report := {"map": map_id, "seed": int(_settings.get("seed", "1")), "shard": String(_settings.get("shard", "0/1")),
		"display": DisplayServer.get_name(), "multimesh_trusted": probe.multimesh_trusted, "pieces_total": all.size(),
		"pieces_in_shard": mine, "lanes_run": lanes_run, "lanes_skipped": skipped, "loss": probe.loss, "window_s": probe.window_s,
		"max_angle_deg": probe.max_angle_deg, "snags": snags}
	var f := FileAccess.open(String(_settings["out"]), FileAccess.WRITE)
	if f == null:
		printerr("snag_sweep: cannot write %s" % _settings["out"])
		quit(2)
		return
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	print("snag_sweep: %s shard %s: %d pieces, %d lanes, %d snags" % [map_id, report.shard, mine, lanes_run, snags.size()])
	quit(0)
