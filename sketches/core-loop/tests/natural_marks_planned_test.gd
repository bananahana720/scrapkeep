# smoke: solo timeout=300s (waits on the marks workers)
extends SceneTree

# MARK-HITCH (measured 2026-10-18 on stage/alpha-w16 8768fb6b, cloud headless, park table): a
# natural row's telegraph and landing marks were projected onto the ground on the main thread when
# the row fired, about 1 s each for the Spillway's west wash flash flood and 0.2 s for the plunge
# pool fill, so play froze mid-stage. A worker now projects every stage's marks from a snapshot of
# its ground as entered, started by the natural setup, so the entry itself does not grow.
#
# Checked on stage 1 and stage 2, whose span collapse sits on its overlay's marker surface: every
# natural row has planned telegraph marks, and a landing mark unless it is an impact;
# each planned surface equals a live projection on the stage's ground vertex for vertex (a
# collapse's landing mark on its overlay's target surface); a telegraph mark built while the
# ground is as planned uses the planned meshes instead of projecting them. With an overlay down on
# the stage's map, the marks near it go back to live projection, and every mark it leaves as
# planned equals a live projection with it down (dense fights, wave 18: once any overlay was down,
# every later mark of the stage was projected live). A collapse landing with its own overlay down
# uses its planned landing mark, which equals a live projection then (the flume's hollow trestle
# projected it live on its landing tick, 437 ms on the cloud).

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
		_t.check("%s %s: planned landing mark unless an impact" % [label, row.id], marks.has("land") != (row.kind == "impact"), str(marks.keys()))
		for phase in marks:
			var live: Dictionary = _live(natural, row, phase == "land")
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
				var live: Dictionary = _live(natural, each, phase == "land")
				for part in live:
					if not planned.has(part) or planned[part].vertices != live[part].vertices:
						differ.append("%s %s %s" % [each.id, phase, part])
		terrain.overlays.erase(id)
		_t.check("%s: overlay %s down sends the marks near it back to live projection" % [label, id], not near.is_empty(), "near %s, clear %s" % [near, clear])
		_t.check("%s: every mark overlay %s leaves as planned equals a live projection with it down" % [label, id], not clear.is_empty() and differ.is_empty(),
			"clear %s, differ %s" % [clear, differ])
	for fall in rows.filter(func(r): return r.kind == "collapse"):
		var landing: Dictionary = natural._prepared[fall.id].marks.get("land", {})
		natural._set_overlay(fall, true)
		var own_down: bool = terrain.overlays.has(natural._prepared[fall.id].swap + "_after")
		var landed_mark: Node3D = natural._mark(fall, natural._prepared[fall.id].geometry, true)
		var landed_style = landed_mark.get_node_or_null("Style")
		var landed_mesh = landed_style.mesh if landed_style != null else null
		var live_landing: Dictionary = _live(natural, fall, true)
		var same_landing: bool = not landing.is_empty() and live_landing.keys() == landing.keys()
		for part in live_landing:
			same_landing = same_landing and landing.has(part) and landing[part].vertices == live_landing[part].vertices
		landed_mark.free()
		natural._set_overlay(fall, false)
		_t.check("%s %s: the landing mark with its own overlay down uses the planned mesh" % [label, fall.id],
			own_down and landed_mesh != null and not landing.is_empty() and landed_mesh == landing.Style.mesh, "down %s, planned %s" % [own_down, landing.keys()])
		_t.check("%s %s: the planned landing mark equals a live projection with its own overlay down" % [label, fall.id], same_landing, str(landing.keys()))
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


# A live projection of row's mark, as natural._mark makes one: a landed collapse's on its target.
func _live(natural, row: Dictionary, landed: bool) -> Dictionary:
	var geometry: Dictionary = natural._prepared[row.id].geometry
	if landed and row.kind == "collapse":
		geometry = geometry.duplicate()
		geometry.marker_surface = natural._overlay_map.swaps[natural._prepared[row.id].swap].target
	return Natural._mark_surfaces(natural.world, row, geometry, landed, natural._overlay_map)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame
