# smoke: solo timeout=300s (waits on the marks workers)
extends SceneTree

# MARK-HITCH (measured 2026-10-18 on stage/alpha-w16 8768fb6b, cloud headless, park table): a
# natural row's telegraph and landing marks were projected onto the ground on the main thread when
# the row fired, about 1 s each for the Spillway's west wash flash flood and 0.2 s for the plunge
# pool fill, so play froze mid-stage. A worker now projects every stage's marks from a snapshot of
# its ground as entered, started by the natural setup, so the entry itself does not grow.
#
# Checked on stage 1 and stage 2, whose span collapse sits on its overlay's marker surface: every
# natural row has planned telegraph marks, and a landing mark unless it is a collapse; each planned
# surface equals a live projection on the stage's ground vertex for vertex; a telegraph mark built
# while the ground is as planned uses the planned meshes instead of projecting them.

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
		_t.check("%s %s: planned landing mark unless a collapse" % [label, row.id], marks.has("land") != (row.kind == "collapse"), str(marks.keys()))
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


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame
