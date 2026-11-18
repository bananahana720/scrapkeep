# smoke: solo timeout=300s (enters every park stage)
extends SceneTree

# Every park stage wears its world's scenery and effects (intent check w16, gap 6): the Spillway's
# cottonwoods and spill mist on the dam and the flume, the Dig's cut kit, carts and lamp lines with
# their effects on the pit and the sinkhole, and the Highdraft's thermal vents, wind effects and
# ball-centred sky on the islands and the crown. Each is built on the entry, stands clear of every
# built row, collides with nothing, and comes back after its stage is freed and entered again.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ParkSites := preload("res://src/presentation/park_sites.gd")
const Spillway := preload("res://src/presentation/spillway_scenery.gd")

const NODES := {1: "SpillwayScenery", 2: "DigScenery", 3: "HighdraftScenery"}

# A tree this close outside a clear view shows the strip is cut from a planted bank, not an empty one.
const NEAR_STRIP_M := 25.0

var _t := T.new("park_world_scenery_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	await process_frame
	await process_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	await physics_frame
	var terrain = game.ctx.terrain
	for stage in range(1, 7):
		game.flow.enter_stage(stage, Vector3.ZERO, false)
		await physics_frame
		var map = terrain.map_for(stage)
		var world: int = game.ctx.stages.world_of(stage)
		var stage_root: Node3D = terrain.geometry_root(stage)
		var id := String(map.park["map"])
		for other in NODES:
			_t.eq("stage %d (%s) carries %s only in world %d" % [stage, id, NODES[other], other],
				stage_root.get_node_or_null(NODES[other]) != null, other == world)
		var scenery: Node3D = stage_root.get_node_or_null(NODES[world])
		if scenery == null:
			continue
		_t.check("stage %d scenery collides with nothing" % stage, _bodies(scenery) == 0 and _bodies(stage_root.get_node_or_null("Cottonwoods")) == 0)
		var sites := ParkSites.new(map, terrain.ground_callable(stage), stage)
		var blocked := []
		var count := 0
		for holder in [scenery, stage_root.get_node_or_null("Cottonwoods")]:
			if holder == null:
				continue
			for view: MultiMeshInstance3D in holder.find_children("*", "MultiMeshInstance3D", true, false):
				if not view.has_meta("origins") or String(view.name).contains("lamp"):
					continue
				for at: Vector3 in view.get_meta("origins"):
					count += 1
					if not sites.clear(Vector2(at.x, at.z), 0.0):
						blocked.append([String(view.name), at])
		_t.check("stage %d: every seated piece stands clear of the built rows and keepouts" % stage, blocked.is_empty(),
			"%d of %d blocked, first %s" % [blocked.size(), count, str(blocked.slice(0, 3))])
		match world:
			1:
				var trees := stage_root.get_node_or_null("Cottonwoods")
				if stage == 2 and trees != null:
					_clear_view_checks(trees, terrain.map().park["park_rows"])
				var planted: int = 0 if trees == null else trees.get_child(0).multimesh.instance_count
				_t.check("stage %d plants cottonwoods by its water" % stage, planted >= 8 and planted <= Spillway.PARK_TREES_MAX, "%d trees" % planted)
				_t.check("stage %d mists its drops" % stage, scenery.get_node_or_null("WaterMist") != null)
			2:
				var fx = scenery.get_node("DigFx")
				_t.check("stage %d hangs lamp lines the lamp pool lights" % stage, fx.lamp_views.size() > 0, "%d lamp views" % fx.lamp_views.size())
				_t.check("stage %d cut faces raise grit" % stage, fx.faces.size() >= 6 and fx.grit.size() == 2, "%d faces" % fx.faces.size())
				_t.check("stage %d's dig effects are live on entry" % stage, fx.active and fx.available)
			3:
				var presence = scenery.get_node("Presence")
				_t.check("stage %d skins its thermals with vents and rising air" % stage, presence.thermals.size() > 0 and presence.thermals.size() == game.world.contraptions[stage].thermals.size(),
					"%d vents" % presence.thermals.size())
				var fx = scenery.get_node_or_null("WindEffects")
				_t.check("stage %d runs the wind effects" % stage, fx != null and fx.thermals.size() == presence.thermals.size())
				game.player.reset_to(terrain.spawn_point(stage))
				await process_frame
				await process_frame
				var ball: Vector3 = game.player.ball_position()
				var sky: Node3D = scenery.get_node("Sky")
				_t.check("stage %d's sky rides with the ball" % stage, Vector2(sky.global_position.x - ball.x, sky.global_position.z - ball.z).length() < 1.0,
					"sky %s, ball %s, visible %s, processing %s" % [sky.global_position, ball, presence.is_visible_in_tree(), presence.can_process()])
	# Stage 1 left memory when the run reached the Highdraft; entering it again builds its scenery again.
	game.flow.enter_stage(1, Vector3.ZERO, false)
	await physics_frame
	_t.check("a freed park stage gets its scenery back", terrain.geometry_root(1).get_node_or_null("SpillwayScenery") != null)
	game.queue_free()
	await physics_frame
	quit(_t.verdict())


func _bodies(node: Node) -> int:
	if node == null:
		return 0
	return node.find_children("*", "CollisionObject3D", true, false).size() + node.find_children("*", "CollisionShape3D", true, false).size()


# Every row with a clear_view keeps trees out of its strip, and trees still stand just outside it, so the check cannot
# pass on an empty bank. The strip is worked out here from the row's own frame: along its run from the rear edge back
# depth_m, across its centre line half_width_m.
func _clear_view_checks(trees: Node3D, rows: Array) -> void:
	var feet: Array[Vector2] = []
	for shell: Node3D in trees.find_children("Cottonwood*", "Node3D", false, false):
		feet.append(Vector2(shell.global_position.x, shell.global_position.z))
	var strips := 0
	for row: Dictionary in rows:
		if not row.has("clear_view"):
			continue
		strips += 1
		var run := Vector2.from_angle(PI * 0.5 - deg_to_rad(float(row["yaw_deg"])))
		var across := Vector2(-run.y, run.x)
		var back: float = -float(row["size"][0]) * 0.5
		var depth: float = row["clear_view"]["depth_m"]
		var half: float = row["clear_view"]["half_width_m"]
		var inside := 0
		var near := 0
		for foot in feet:
			var offset := foot - Vector2(float(row["at"][0]), float(row["at"][1]))
			var gap := Vector2(maxf(maxf(back - depth - offset.dot(run), offset.dot(run) - back), 0.0),
				maxf(absf(offset.dot(across)) - half, 0.0)).length()
			inside += 1 if gap == 0.0 else 0
			near += 1 if gap > 0.0 and gap <= NEAR_STRIP_M else 0
		_t.check("%s: no tree stands in its clear view" % row["id"], inside == 0, "%d of %d trees" % [inside, feet.size()])
		_t.check("%s: trees stand within %.0f m of its clear view" % [row["id"], NEAR_STRIP_M], near > 0, "%d trees" % near)
	_t.check("the siphon's park carries a clear view", strips > 0)
