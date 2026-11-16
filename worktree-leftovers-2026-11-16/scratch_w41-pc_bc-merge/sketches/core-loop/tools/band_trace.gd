extends "res://tools/band_run.gd"
# SCRATCH ONLY (PC lane, BC replay trace, 14 Nov 2026): never for the repo's tests or a game branch.
# band_run with --trace-ticks=1, plus on every 90th tick the SurveyPosts node's physics_process state and
# the counts of physics bodies and areas under ctx.root, so a difference in the node set shows up.

func _snapshot(delta: float) -> Dictionary:
	var row := super._snapshot(delta)
	if int(row["tick"]) % 90 == 0:
		var posts = _game.world.get("survey_posts")
		row["posts_node"] = posts != null
		row["posts_physics"] = posts.is_physics_processing() if posts != null else null
		row["posts_standing"] = posts.standing.size() if posts != null and "standing" in posts else null
		var bodies := 0
		var areas := 0
		for n in _game.ctx.root.find_children("*", "CollisionObject3D", true, false):
			if n is Area3D:
				areas += 1
			else:
				bodies += 1
		row["bodies"] = bodies
		row["areas"] = areas
		row["nodes"] = _game.ctx.root.get_child_count()
	return row
