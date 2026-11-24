extends SceneTree

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Probe := preload("res://tools/qa/snag_probe.gd")

# The planted control for tools/qa/snag_sweep.gd (map standard 8c). A fixture floor high over the
# map carries a 0.3 m lip box. The probe must report a snag at the lip, none on the same lanes once
# the lip is gone, none along a flat wall (a graze slides off), and none for the lip when the loss
# tolerance is set too loose to see it. Without the control a zero from the sweep means nothing.
# The same lip on a moving body is classed moving, on an actor (it takes damage) is no snag, and a
# low piece held 10 m over the floor gets no ride lanes (the Slag Bowl's crossbars, wave 37), one
# held 1.8 m over it, lower than the ball is tall, keeps them.
#
# Evidence limit: one fixture on a flat floor, calm world, not a run.

const FLOOR_Y := 500.0
const FLOOR_AT := Vector3(0.0, FLOOR_Y, 0.0)
const FLOOR_SIZE := Vector3(120.0, 1.0, 120.0)
const LIP_SIZE := Vector3(12.0, 0.3, 1.2)
const WALL_SIZE := Vector3(20.0, 6.0, 1.0)
const WALL_AT := Vector3(0.0, 3.5, 40.0)

var t := T.new("snag_sweep_test")


func _initialize() -> void:
	_run.call_deferred()


func _box(parent: Node, name: String, size: Vector3, at: Vector3, body: PhysicsBody3D = null) -> PhysicsBody3D:
	if body == null:
		body = StaticBody3D.new()
	body.name = name
	body.collision_layer = 1
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	body.add_child(mesh)
	parent.add_child(body)
	return body


func _snags(probe, piece: Dictionary, lanes: Array) -> Array:
	var rows := []
	for lane in lanes:
		var row: Dictionary = await probe.roll(piece, lane)
		rows.append(row)
	return rows


func _count(rows: Array) -> int:
	var n := 0
	for r in rows:
		if r.has("piece"):
			n += 1
	return n


func _skipped(rows: Array) -> int:
	var n := 0
	for r in rows:
		if r.has("skipped"):
			n += 1
	return n


func _row(hit: String, at: Array, cls: String, before := 13.0, after := 3.0, piece := "/r/Stage2/ParkRows/P/Collider") -> Dictionary:
	return {"hit": hit, "at": at, "class": cls, "speed_before": before, "speed_after": after, "visible": false, "piece": piece}


# Class and place joining on rows made by hand, each with a case that must come out the other way.
func _check_classes_and_places() -> void:
	var piece := "/root/a/Stage2/ParkRows/Park_x/Collider"
	t.eq("class: the piece's own collider", Probe.classify(piece, piece), "piece")
	t.eq("class: a part of the piece", Probe.classify("/root/a/Stage2/ParkRows/Park_x", piece), "piece")
	t.eq("class: a sibling collider of one prop", Probe.classify(piece, "/root/a/Stage2/ParkRows/Park_x/Rail"), "piece")
	t.eq("class: terrain tile", Probe.classify(piece, "/root/a/Stage2/Ground/Tiles/Tile6_7"), "ground")
	t.eq("class: the bowl floor", Probe.classify(piece, "/root/a/SlagBowl/Bowl"), "ground")
	t.eq("class: another prop's collider", Probe.classify(piece, "/root/a/Stage2/ParkRows/Park_y/Collider"), "other")
	t.eq("class: a prop under the same holder is not this piece", Probe.classify("/root/a/Stage2/ParkRows/Collider", "/root/a/Stage2/ParkRows/Other"), "other")
	t.eq("class: another shape of the piece's own body", Probe.classify("/root/a/SlagBowl/Bowl#4", "/root/a/SlagBowl/Bowl#9"), "other")
	t.eq("class: the floor trimesh of the piece's own body", Probe.classify("/root/a/SlagBowl/Bowl#4", "/root/a/SlagBowl/Bowl#0", true), "ground")
	t.eq("class: the piece's own shape", Probe.classify("/root/a/SlagBowl/Bowl#4", "/root/a/SlagBowl/Bowl#4"), "piece")
	var rows := [
		_row("/c/A", [0.0, 0.0, 0.0], "piece", 13.0, 5.0),
		_row("/c/A", [1.5, 0.0, 0.0], "piece", 13.0, 2.0),
		_row("/c/A", [3.4, 0.0, 0.0], "piece", 13.0, 6.0),
		_row("/c/A", [30.0, 0.0, 0.0], "piece"),
		_row("/c/B", [0.5, 0.0, 0.0], "ground"),
		_row("/c/A", [0.5, 0.0, 0.0], "other"),
	]
	rows[1]["visible"] = true
	var places := Probe.dedupe(rows)
	t.eq("places: 6 snags join to 4 places", places.size(), 4)
	var chain: Dictionary = {}
	for p in places:
		if p.hit == "/c/A" and p["class"] == "piece" and p.count == 3:
			chain = p
	t.check("places: snags 1.5 m and 1.9 m apart chain into one row with count, worst loss and drawn", not chain.is_empty() and chain.worst_loss == 0.85 and chain.drawn, str(places))
	t.check("places: the worst place is listed first", places[0].worst_loss >= places[places.size() - 1].worst_loss)
	# Rideable slope filter for open-ground control lanes: a 0.3 m seam step over 2 m (8.5 deg) stays in,
	# while a 60 deg canyon cliff is skipped.
	var seam_step := func(x: float, _z: float) -> float: return 0.3 if x >= 20.0 else 0.0
	var steep_cliff := func(x: float, _z: float) -> float: return maxf(0.0, (x - 20.0) * 1.732)
	var seam_deg := Probe.max_ground_slope_deg(seam_step, Vector2.ZERO, Vector2(1, 0), Probe.CONTROL_LEN)
	var cliff_deg := Probe.max_ground_slope_deg(steep_cliff, Vector2.ZERO, Vector2(1, 0), Probe.CONTROL_LEN)
	t.check("control slope filter: a 0.3 m terrain step stays rideable", seam_deg <= Probe.CONTROL_MAX_SLOPE_DEG, "%.1f deg" % seam_deg)
	t.check("control slope filter: a 60 deg cliff is skipped", cliff_deg > Probe.CONTROL_MAX_SLOPE_DEG, "%.1f deg" % cliff_deg)


func _run() -> void:
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	await process_frame
	await process_frame
	game.ctx.calm = true
	var source := Intent.Scripted.new()
	game.player.source = source
	game.flow.press_start()
	game.flow.choose_class(0)
	var terrain = game.ctx.terrain
	var waited := 0
	while waited < 1200 and not (terrain.rows_ready(1) and terrain.is_ready(1) and game.flow.state_name() == "stage"):
		await process_frame
		waited += 1
	await physics_frame
	for i in 30:
		await physics_frame
	var fixture := Node3D.new()
	fixture.name = "SnagFixture"
	game.add_child(fixture)
	_box(fixture, "Floor", FLOOR_SIZE, FLOOR_AT + Vector3(0, -0.5, 0))
	var lip := _box(fixture, "Lip", LIP_SIZE, FLOOR_AT + Vector3(0, LIP_SIZE.y * 0.5, 0))
	_box(fixture, "Wall", WALL_SIZE, FLOOR_AT + WALL_AT)
	await physics_frame
	await physics_frame
	var probe = Probe.new(self, game, source)
	probe.index_drawn([fixture])
	var found := {}
	for p in probe.pieces(fixture):
		found[String(p.path).get_file()] = p
	t.check("the lip and the wall are large pieces, the floor is one too", found.has("Lip") and found.has("Wall") and found.has("Floor"), str(found.keys()))
	var lip_lanes: Array = probe.lanes(found["Lip"])
	var wall_lanes: Array = probe.lanes(found["Wall"])
	t.check("a low piece is ridden, a tall one grazed", lip_lanes[0].kind == "ride" and wall_lanes[0].kind == "graze")

	var with_lip: Array = await _snags(probe, found["Lip"], lip_lanes)
	t.check("planted lip: at least one snag", _count(with_lip) >= 1, "%d of %d lanes, %d skipped" % [_count(with_lip), with_lip.size(), _skipped(with_lip)])
	for r in with_lip:
		if r.has("piece"):
			print("snag at ", r.at, " hit ", r.hit, " n ", r.n, " speed ", r.speed_before, " -> ", r.speed_after, " drawn ", r.visible)
			t.check("the snag is at the lip, on the lip's collider, and is drawn", absf(r.at[2] - FLOOR_AT.z) < 3.0 and String(r.hit).ends_with("Lip") and r.visible, str(r))
			break

	# The loose-tolerance case is only a control if the probe saw the lip: a blind probe also finds
	# nothing at loss 0.99, so the lip's contacts are counted and must be there.
	probe.loss = 0.99
	probe.contacts_seen = 0
	var loose: Array = await _snags(probe, found["Lip"], lip_lanes)
	t.eq("loss tolerance set too loose: the lip is missed", _count(loose), 0)
	t.check("loss tolerance set too loose: the probe still saw the lip's contacts", probe.contacts_seen > 0, "%d contacts" % probe.contacts_seen)
	probe.loss = 0.5

	var lipped := {}
	for r in with_lip:
		if r.has("piece"):
			lipped = r
			break
	t.eq("the lip's snag is classed by what it hit: the piece itself", lipped.get("class", ""), "piece")
	t.check("a loss is read from the snag's speeds", Probe.loss_of(lipped) >= 0.5 and Probe.loss_of(lipped) < 1.0, str(Probe.loss_of(lipped)))
	_check_classes_and_places()

	var wall: Array = await _snags(probe, found["Wall"], wall_lanes)
	t.check("flat wall grazed: no snag", _count(wall) == 0 and _skipped(wall) < wall.size(), "%d snags, %d of %d lanes skipped" % [_count(wall), _skipped(wall), wall.size()])

	var again: Array = await _snags(probe, found["Lip"], lip_lanes)
	t.check("two runs of the same lanes give identical rows", JSON.stringify(again) == JSON.stringify(with_lip) and _count(again) >= 1)

	lip.queue_free()
	await physics_frame
	await physics_frame
	var without: Array = await _snags(probe, found["Lip"], lip_lanes)
	t.check("same lanes, lip removed: no snag", _count(without) == 0 and _skipped(without) == 0, "%d snags, %d skipped" % [_count(without), _skipped(without)])

	# The same lip on a moving body (a lift's plate) is listed as moving, not as a catch: its phase test judges it.
	var moving := _box(fixture, "MovingLip", LIP_SIZE, FLOOR_AT + Vector3(0, LIP_SIZE.y * 0.5, 0), AnimatableBody3D.new())
	await physics_frame
	await physics_frame
	var on_moving: Array = await _snags(probe, found["Lip"], lip_lanes)
	var classes := {}
	for r in on_moving:
		if r.has("piece"):
			classes[r["class"]] = true
	t.check("a lip on a moving body: a snag, classed moving and nothing else", _count(on_moving) >= 1 and classes.keys() == [Probe.MOVING], "%d snags, classes %s" % [_count(on_moving), classes.keys()])
	moving.queue_free()

	# The same lip on an actor (anything that takes damage: an enemy, a boss piece) is not the map.
	var script := GDScript.new()
	script.source_code = "extends StaticBody3D\nfunc take_damage(_amount, _source = null):\n\tpass\n"
	script.reload()
	var actor_body := StaticBody3D.new()
	actor_body.set_script(script)
	var actor := _box(fixture, "ActorLip", LIP_SIZE, FLOOR_AT + Vector3(0, LIP_SIZE.y * 0.5, 0), actor_body)
	await physics_frame
	await physics_frame
	probe.actors_seen = 0
	var on_actor: Array = await _snags(probe, found["Lip"], lip_lanes)
	t.eq("a lip that takes damage is an actor: no snag", _count(on_actor), 0)
	t.check("the actor lip's facing contacts were met and left out", probe.actors_seen > 0, "%d contacts" % probe.actors_seen)
	actor.queue_free()

	# A low piece held up over the floor (a crossbar on a mast) gets no ride lanes: they would roll under it.
	var crossbar := _box(fixture, "Crossbar", LIP_SIZE, FLOOR_AT + Vector3(0, 10.0, -30.0))
	await physics_frame
	var bar := {}
	for p in probe.pieces(fixture):
		if String(p.path).get_file() == "Crossbar":
			bar = p
	t.check("a low piece 10 m over the floor is a piece with no lanes", not bar.is_empty() and probe.lanes(bar).is_empty(), str(bar))
	# One hung lower than the ball is tall still gets its lanes: the ball can wedge under it.
	var lowbar := _box(fixture, "LowBar", LIP_SIZE, FLOOR_AT + Vector3(0, 1.8 + LIP_SIZE.y * 0.5, 30.0))
	await physics_frame
	var low := {}
	for p in probe.pieces(fixture):
		if String(p.path).get_file() == "LowBar":
			low = p
	t.check("a low piece 1.8 m over the floor (under the ball's height) keeps its ride lanes", not low.is_empty() and probe.lanes(low).size() == 4 * Probe.LANES, str(low))
	crossbar.free()
	lowbar.free()
	fixture.get_node("Wall").free()

	# Ride-lane run-out: catches an exit-edge lip and a 2 m exit blocker, but does not blame a slab
	# for a tall building standing 9 m clear across open ground.
	var slab_body := _box(fixture, "RideSlab", Vector3(20.0, 0.06, 20.0), FLOOR_AT + Vector3(0, 0.03, 0))
	await physics_frame
	await physics_frame
	var slab := {}
	for p in probe.pieces(fixture):
		if String(p.path).get_file() == "RideSlab":
			slab = p
	var exit_lane := {}
	for l in probe.lanes(slab):
		if l.dir.y > 0.99 and absf(l.from.x) < 0.1:
			exit_lane = l
			break
	t.check("ride slab has a centre +z ride lane", not exit_lane.is_empty(), str(slab))
	var slab_clean: Dictionary = await probe.roll(slab, exit_lane)
	t.check("clean ride slab: no snag", not slab_clean.has("piece") and not slab_clean.has("skipped"), str(slab_clean))
	var exit_lip := _box(fixture, "ExitLip", LIP_SIZE, FLOOR_AT + Vector3(0, 0.06 + LIP_SIZE.y * 0.5, 10.0))
	await physics_frame
	await physics_frame
	var slab_exit_lip: Dictionary = await probe.roll(slab, exit_lane)
	t.check("ride run-out catches a planted 0.3 m exit-edge lip", slab_exit_lip.has("piece") and slab_exit_lip.lane == "ride", str(slab_exit_lip))
	exit_lip.free()
	var close_wall := _box(fixture, "CloseWall", Vector3(12.0, 10.0, 12.0), FLOOR_AT + Vector3(0, 5.0, 18.0))
	await physics_frame
	await physics_frame
	var slab_close_wall: Dictionary = await probe.roll(slab, exit_lane)
	t.check("ride run-out catches a wall 2 m past the exit edge", slab_close_wall.has("piece") and slab_close_wall.lane == "ride", str(slab_close_wall))
	close_wall.free()
	var clear_wall := _box(fixture, "ClearWall", Vector3(12.0, 10.0, 12.0), FLOOR_AT + Vector3(0, 5.0, 25.0))
	await physics_frame
	await physics_frame
	var slab_clear_wall: Dictionary = await probe.roll(slab, exit_lane)
	t.check("ride run-out does not blame a slab for a building 9 m clear past exit", not slab_clear_wall.has("piece") and not slab_clear_wall.has("skipped"), str(slab_clear_wall))
	clear_wall.free()
	slab_body.free()
	fixture.free()
	await physics_frame
	await physics_frame

	# Real park_dam open-ground control lanes: gentle tile-seam lanes are kept (and catch a planted
	# 0.3 m seam lip), while canyon fins and spires are not misclassified as flat tile seams.
	var gb: AABB = probe.ground_bounds(game)
	var dam_all := []
	for p in probe.pieces(game):
		if Probe.inside(p, gb):
			dam_all.append(p)
	var ctl_lanes: Array = probe.control_lanes(dam_all, gb)
	var has_cliff_fin := false
	var has_spire := false
	var seam_lane := {}
	var seam_best_slope := INF
	for l in ctl_lanes:
		var a: Vector2 = l.from
		var d: Vector2 = l.dir
		var b: Vector2 = a + d * float(l.length_m)
		if a.distance_to(Vector2(50.0, 450.0)) < 1.0 and d.x > 0.5:
			has_cliff_fin = true
		if a.distance_to(Vector2(-50.0, -550.0)) < 1.0 and d.y > 0.5:
			has_spire = true
		if floori((a.x + 800.0) / 160.0) != floori((b.x + 800.0) / 160.0) or floori((a.y + 800.0) / 160.0) != floori((b.y + 800.0) / 160.0):
			var slope := Probe.max_ground_slope_deg(Callable(terrain, "height"), a, d, float(l.length_m))
			if slope < seam_best_slope:
				seam_best_slope = slope
				seam_lane = l
	t.check("park_dam control lanes keep rideable tile-seam lanes and exclude cliffs/spires",
		not ctl_lanes.is_empty() and not seam_lane.is_empty() and not has_cliff_fin and not has_spire,
		"kept=%d seam=%s cliff_fin=%s spire=%s" % [ctl_lanes.size(), str(seam_lane), has_cliff_fin, has_spire])
	if not seam_lane.is_empty():
		var ctl_piece := {"path": "control", "aabb": AABB(Vector3(seam_lane.from.x, gb.end.y - 1.0, seam_lane.from.y), Vector3(0, 1, 0)), "yaw": 0.0}
		var ctl_clean: Dictionary = await probe.roll(ctl_piece, seam_lane)
		t.check("gentle open-ground control lane across tile seam: no snag",
			not ctl_clean.has("piece") and not ctl_clean.has("skipped"), str(ctl_clean))
		var mid: Vector2 = seam_lane.from + seam_lane.dir * 25.0
		var entry: Vector2 = mid - seam_lane.dir * 0.6
		var base_y: float = maxf(float(terrain.height(mid.x, mid.y)), float(terrain.height(entry.x, entry.y)))
		var seam_size := Vector3(1.2, 0.5, 12.0) if seam_lane.dir.x > 0.5 else Vector3(12.0, 0.5, 1.2)
		# Embed 0.2 m below ground so the exposed step at the entry face is a full 0.3 m lip.
		var planted_seam := _box(game, "PlantedControlSeam", seam_size, Vector3(mid.x, base_y + 0.05, mid.y))
		await physics_frame
		await physics_frame
		var ctl_planted: Dictionary = await probe.roll(ctl_piece, seam_lane)
		t.check("control lane with planted seam lip: snag caught",
			ctl_planted.has("piece") and ctl_planted.lane == "control", str(ctl_planted))
		planted_seam.free()
		await physics_frame
		await physics_frame
		var ctl_after: Dictionary = await probe.roll(ctl_piece, seam_lane)
		t.check("control lane with planted seam lip removed: no snag",
			not ctl_after.has("piece") and not ctl_after.has("skipped"), str(ctl_after))

	game.queue_free()
	await process_frame
	quit(t.verdict())
