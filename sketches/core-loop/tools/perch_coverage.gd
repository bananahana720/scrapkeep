extends SceneTree

# Prints, per park, the Dispatcher's candidate perch tops by source (anchor posts, landform tops) with their
# rise, and how many of 200 seeded pack points have a perch within 40 m. Read-only:
#   godot --headless --path sketches/core-loop --script res://tools/perch_coverage.gd
# Optional user args after `--`: park ids (default: all six shipped parks).

const PerchPoints := preload("res://src/world/perch_points.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkGround := preload("res://tests/support/park_ground.gd")

const PACKS := 200


func _initialize() -> void:
	var ids: Array = OS.get_cmdline_user_args()
	if ids.is_empty():
		ids = ["dam", "flume", "sinkhole", "islands", "pit", "crown"]
	for id: String in ids:
		var park_map := ParkMap.new("res://src/world/park/park_%s.json" % id)
		var ground := ParkGround.ground("park_%s" % id)
		if not park_map.ok or not ground.is_valid():
			print("park_%s: unreadable" % id)
			continue
		var started := Time.get_ticks_usec()
		var posts := PerchPoints.derive(park_map.park, ground)
		var mid := Time.get_ticks_usec()
		var ledges := PerchPoints.ledges(park_map.park, ground)
		var done := Time.get_ticks_usec()
		var blocked := PerchPoints.blockers(park_map.park)
		var packs := ParkGround.pack_points(park_map.park, PACKS)
		var before := 0
		var after := 0
		for i in packs.size():
			if PerchPoints.pick(posts, packs[i], ground, blocked, i).is_finite():
				before += 1
			if PerchPoints.pick(posts, packs[i], ground, blocked, i, ledges).is_finite():
				after += 1
		# A lower bound on the data change: tops added greedily at pack points until 60 percent are covered.
		var covered := []
		for i in packs.size():
			covered.append(PerchPoints.pick(posts, packs[i], ground, blocked, i, ledges).is_finite())
		var added := 0
		while covered.count(true) < packs.size() * 6 / 10 and added < 100:
			var best := -1
			var best_gain := 0
			for c in packs.size():
				var gain := 0
				for i in packs.size():
					if not covered[i] and Vector2(packs[c].x, packs[c].z).distance_to(Vector2(packs[i].x, packs[i].z)) <= PerchPoints.RANGE_M:
						gain += 1
				if gain > best_gain:
					best_gain = gain
					best = c
			if best < 0:
				break
			for i in packs.size():
				if Vector2(packs[best].x, packs[best].z).distance_to(Vector2(packs[i].x, packs[i].z)) <= PerchPoints.RANGE_M:
					covered[i] = true
			added += 1
		print("   tops to add for 60 percent (greedy, at pack points): %d" % added)
		var rises := []
		for ledge: Vector4 in ledges:
			rises.append(snappedf(ledge.y - ledge.w, 0.1))
		print("park_%s: posts %d, landform tops %d (derive %d ms, ledges %d ms), packs %d, perch within 40 m before %d after %d" % [
			id, posts.size(), ledges.size(), (mid - started) / 1000, (done - mid) / 1000, packs.size(), before, after])
		print("   rises %s" % str(rises.slice(0, 24)))
	quit(0)
