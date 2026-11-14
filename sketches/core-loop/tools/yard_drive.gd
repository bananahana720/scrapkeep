extends SceneTree
# SCRATCH ONLY (PC lane job AU, 14 Nov 2026): never for the repo's tests or a game branch.
# Drives the ball into the Stocktake yard ring on stage 1 (needs stocktake on) and times every frame
# through the counts. The ball is dropped at the ring's centre and held there with no input and a huge
# hull, so it never clears a count: each count not cleared in count_s (25 s) gets the next on top, which
# makes counts 1 to 5 arrive (the ball is put back at the centre whenever it drifts past 20 m, so the
# machines cannot knock it out of the 40 m ring and forfeit the yard) on the clock with the most machines up, the worst case for frame time.
# Writes <out>/frames.ndjson (ms, count, machines up) and prints YARD lines.
#   gamescope ... -- <godot> --audio-driver Dummy --path sketches/core-loop --resolution 1920x1080 \
#     --script res://tools/yard_drive.gd -- --out=<abs dir> [--hold=150]
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

var out := ""
var hold_s := 150.0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--hold="):
			hold_s = float(arg.trim_prefix("--hold="))
	if out.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1920, 1080)
	_run.call_deferred()

func _run() -> void:
	seed(1)
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await process_frame
	await process_frame
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	for i in 900:
		await process_frame
		if game.ctx.terrain.is_ready(1) and game.flow.in_play() and i > 240:
			break
	var site = null
	for s in game.world.activities.sites:
		if String(s.id) == "stocktake_yard":
			site = s
	if site == null:
		print("YARD none: stocktake=", game.tuning.option("stocktake"))
		quit(1)
		return
	var at: Vector3 = site.global_position
	print("YARD site at ", at, " stocktake=", game.tuning.option("stocktake"))
	game.player.reset_to(game.ctx.terrain.drop_point(at.x, at.z, 1.0))
	var hits := {}
	game.ctx.events.player_hit.connect(func(amount: float, source: String) -> void:
		hits[source] = float(hits.get(source, 0.0)) + amount)
	game.ctx.events.player_died.connect(func() -> void: print("YARD player_died hp=", game.run.hp, " hits=", hits))
	var file := FileAccess.open(out.path_join("frames.ndjson"), FileAccess.WRITE)
	var last := Time.get_ticks_usec()
	var t := 0.0
	var deepest := 0
	var seen_done := false
	while t < hold_s:
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		t += ms / 1000.0
		var yard = site.yard
		var count: int = yard.count if yard != null else -1
		deepest = maxi(deepest, count)
		# Keep the hull full so the count, not a death, decides how deep the yard goes.
		game.run.hp = game.run.max_hp
		var bp: Vector3 = game.player.ball_position()
		var dist := Vector2(bp.x - at.x, bp.z - at.z).length()
		if dist > 20.0:
			game.player.reset_to(game.ctx.terrain.drop_point(at.x, at.z, 1.0))
		var up := 0
		for m in site.pack:
			if is_instance_valid(m):
				up += 1
		file.store_line(JSON.stringify({"t": snappedf(t, 0.001), "ms": snappedf(ms, 0.01), "count": count, "up": up, "dist": snappedf(dist, 0.1), "owed": site.yard_owed.size(),
			"started": site.started, "done": site.done or (yard != null and yard.done)}))
		if (site.done or (yard != null and yard.done)) and not seen_done:
			seen_done = true
			print("YARD resolved at t=", snappedf(t, 0.1), " count=", count)
		if count >= 6:
			print("YARD reached count 6 at t=", snappedf(t, 0.1))
			break
	file.close()
	print("YARD hits ", hits)
	print("YARD end deepest=", deepest, " resolved=", seen_done, " started=", site.started, " t=", snappedf(t, 0.1))
	quit(0)
