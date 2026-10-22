# smoke: solo timeout=300s (waits on the marks workers)
extends SceneTree

# MARK-HITCH (measured 2026-10-18 on stage/alpha-w16 8768fb6b, cloud headless, park table): a
# natural row's telegraph and landing marks were projected onto the ground on the main thread when
# the row fired, about 1 s each for the Spillway's west wash flash flood and 0.2 s for the plunge
# pool fill, so play froze mid-stage. A worker now projects every stage's marks from a snapshot of
# its ground as entered, started by the natural setup, so the entry itself does not grow.
#
# Checked on stage 1 and stage 2, whose span collapse sits on its overlay's marker surface: every
# natural row has planned telegraph marks, and a landing mark unless it is a collapse or impact;
# each planned surface equals a live projection on the stage's ground vertex for vertex; a
# telegraph mark built while the ground is as planned uses the planned meshes instead of
# projecting them. With an overlay down on the stage's map, the marks near it go back to live
# projection, and every mark it leaves as planned equals a live projection with it down (dense
# fights, wave 18: once any overlay was down, every later mark of the stage was projected live).

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const Natural := preload("res://src/world/events/natural.gd")

const SETTLE_TICKS := 30
const WAIT_TICKS_MAX := 3600

var _game
var _t := T.new("natural_marks_planned_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SimClock.ticks = true
	seed(11)
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	await physics_frame
	await physics_frame
	_game.run.run_seed_override = 11
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _ticks(SETTLE_TICKS)
	_t.check("the run is on park stage 1", _game.flow.stage() == 1 and _natural() != null, "stage %d" % _game.flow.stage())
	await _until_marks()
	_check_stage("stage 1")

	var terrain = _game.ctx.terrain
	terrain.prepare(2)
	var waited := 0
	while not terrain.is_ready(2) and waited < WAIT_TICKS_MAX:
		await physics_frame
		waited += 1
	# The natural plan for stage 2 starts on a later poll once its ground is ready.
	await _ticks(SETTLE_TICKS)
	Natural.settle_plans()
	_game.player.reset_to(terrain.spawn_point(1) + Vector3.UP * 2.0, Vector3(0.0, 0.0, 6.0))
	await _ticks(2)
	_game.flow._finish_stage()
	await _ticks(2)
	_t.check("the exit entered park stage 2", _game.flow.stage() == 2 and _natural() != null, "stage %d" % _game.flow.stage())
	await _until_marks()
	_check_stage("stage 2")
	_game.queue_free()
	await physics_frame
	quit(_t.verdict())


func _natural():
	return _game.world.event_families.get("natural")


func _until_marks() -> void:
	var waited := 0
	while not Natural._marks_job.is_empty() and waited < WAIT_TICKS_MAX:
		await physics_frame
		waited += 1


func _check_stage(label: String) -> void:
	var natural = _natural()
	if natural == null:
		return
	var rows: Array = natural._original_map.park.event_rows.filter(func(row): return row.family == "natural" and Natural.KINDS.has(row.kind))
	_t.check("%s has natural rows" % label, not rows.is_empty(), str(rows.size()))
	for row in rows:
		var marks: Dictionary = natural._prepared[row.id].marks
		_t.check("%s %s: planned telegraph mark" % [label, row.id], marks.has("telegraph"), str(marks.keys()))
		_t.check("%s %s: planned landing mark unless a collapse or impact" % [label, row.id], marks.has("land") != (row.kind in ["collapse", "impact"]), str(marks.keys()))
		for phase in marks:
			var live: Dictionary = Natural._mark_surfaces(natural.world, row, natural._prepared[row.id].geometry, phase == "land", natural._overlay_map)
			var planned: Dictionary = marks[phase]
			var same: bool = live.keys() == planned.keys()
			for part in live:
				same = same and planned.has(part) and planned[part].vertices == live[part].vertices and planned[part].mesh != null
			_t.check("%s %s %s: planned mark equals a live projection" % [label, row.id, phase], same, str(planned.keys()))
	var row: Dictionary = rows[0]
	var mark: Node3D = natural._mark(row, natural._prepared[row.id].geometry)
	var style: MeshInstance3D = mark.get_node_or_null("Style") if mark.has_node("Style") else mark.get_node_or_null("DustCurtain")
	_t.check("%s %s: the telegraph mark uses the planned mesh" % [label, row.id], style != null and style.mesh == natural._prepared[row.id].marks.telegraph.Style.mesh)
	mark.free()
	var terrain = natural.world.terrain
	var live_map = terrain.map()
	if live_map is Natural.OverlayMap and not live_map.profiles.is_empty():
		var id = live_map.profiles.keys()[0]
		terrain.overlays.append(id)
		var near := []
		var clear := []
		var differ := []
		for each in rows:
			for phase in natural._prepared[each.id].marks:
				var planned: Dictionary = natural._prepared[each.id].marks[phase]
				if not natural._ground_as_planned(planned):
					near.append("%s %s" % [each.id, phase])
					continue
				clear.append("%s %s" % [each.id, phase])
				var live: Dictionary = Natural._mark_surfaces(natural.world, each, natural._prepared[each.id].geometry, phase == "land", natural._overlay_map)
				for part in live:
					if not planned.has(part) or planned[part].vertices != live[part].vertices:
						differ.append("%s %s %s" % [each.id, phase, part])
		terrain.overlays.erase(id)
		_t.check("%s: overlay %s down sends the marks near it back to live projection" % [label, id], not near.is_empty(), "near %s, clear %s" % [near, clear])
		_t.check("%s: every mark overlay %s leaves as planned equals a live projection with it down" % [label, id], not clear.is_empty() and differ.is_empty(),
			"clear %s, differ %s" % [clear, differ])
	# Overlay colliders come from their surfaces' own vertices (EventGround.trimesh), not from a mesh read
	# back from the renderer: each equals the collider the surface's mesh gives.
	if live_map is Natural.OverlayMap and not live_map.swaps.is_empty():
		var compared := []
		var unequal := []
		for swap in live_map.swaps:
			var entry: Dictionary = live_map.swaps[swap]
			for key in ["baseline", "target", "collider"]:
				var surface = entry.get("baseline" if key == "collider" else key)
				if surface == null or surface.mesh == null or (key == "collider" and entry.get("cave", false)):
					continue
				var want = surface.mesh.create_trimesh_shape()
				var got = entry.body.get_child(1).shape if key == "collider" else Natural.EventGround.trimesh(surface)
				compared.append("%s %s" % [swap, key])
				if (want == null) != (got == null) or (want != null and want.get_faces() != got.get_faces()):
					unequal.append("%s %s" % [swap, key])
		_t.check("%s: each overlay collider equals the one its surface's mesh gives" % label, not compared.is_empty() and unequal.is_empty(),
			"compared %s, unequal %s" % [compared, unequal])


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame
