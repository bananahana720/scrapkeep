extends SceneTree

const SpineWorlds := preload("res://tests/spine_worlds_test.gd")
const BossPlate := preload("res://src/ui/boss_plate.gd")
const BossPosture := preload("res://src/core/boss_posture.gd")
const T := preload("res://tests/support/t.gd")

# World two's boss, the Waking (waking.gd), runs the stub's fight (a posture Warden on a flat
# pad) until its own lands. It reads like a fight: the
# HUD seats the boss plate on ctx.boss's Warden (named for the world's row, four pips), the
# Warden's posture reaches the bus so the ring draws its arcs and the stagger chord plays,
# a stagger shows open, and a lost chunk updates the pips and the arcs. The run is the
# three-world table spine_worlds_test uses, driven to world two's arena through flow.
#
# Evidence limit: strikes are judge_hit/on_struck on the Warden, standing in for contacts,
# and the plate is read through its accessors, not its pixels.

const TICK_LIMIT := 60 * 30

var _t := T.new("stub_boss_read_test")
var _game
var _ticks := 0


func _initialize() -> void:
	# Weak points off whatever the Waking ships on: these strikes stand in for body contacts, which the rule
	# chips, so no stagger would come. No test yet reads the plate's stagger glyph, pips or arcs on dial 1.
	ChallengeDials.set_overrides({"waking.weak_points": 0.0})
	_game = SpineWorlds.ThreeWorldGame.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _filled(plate) -> int:
	var count := 0
	for pip in plate.pips():
		if pip["filled"]:
			count += 1
	return count


func _chords() -> int:
	var count := 0
	for row in _game.presentation.audio.cue_log:
		if row[0] == "posture_changed" and row[2] != "stop":
			count += 1
	return count


func _strike(warden) -> void:
	var result: Dictionary = warden.judge_hit("slam", 9999.0, true, 3)
	warden.on_struck("slam", String(result.get("part", "")), result)
	if bool(result.get("shatter", false)):
		warden.take_damage(float(result.get("dealt", 0.0)))


func _finish(failed := false) -> void:
	_game.free()
	ChallengeDials.reset()
	quit(1 if failed else _t.verdict())


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	var flow = _game.flow
	_game.ctx.calm = true
	var posture_events: Array = []
	var weak_points: Array = []
	var brindle_plate_names: Array = []
	_game.events.posture_changed.connect(func(enemy: Node3D, _p: float, staggered: bool):
		posture_events.append([enemy, staggered]))
	_game.events.weak_point_opened.connect(func(point: String, _at: Vector3, _s: float): weak_points.append(point))
	_game.events.boss_arena_entered.connect(func():
		var plate = _game.hud.boss_plate
		if plate != null and plate.active() and _game.ctx.boss == _game.boss:
			brindle_plate_names.append(plate.drawn_words()))
	flow.press_start()
	flow.choose_class(0)
	# Through stage 1 and Brindle to world two's stub arena.
	var last_stage := -1
	while _ticks < TICK_LIMIT:
		_ticks += 1
		var module = flow._boss_module() if flow.state_name() == "boss" else null
		if module != null and module != _game.boss:
			break
		if module == _game.boss:
			module._defeat("ram", _game.ctx.player.ball_position())
		elif flow.state_name() in ["stage", "beacon", "gates", "launch"] and _game.run.stage != last_stage:
			last_stage = _game.run.stage
			flow._finish_stage()
		await physics_frame
	var stub = flow._boss_module()
	_t.check("reached world two's stub arena", _game.run.stage == 2 and stub != null and stub != _game.boss and stub.active(),
		"stage %d, state %s" % [_game.run.stage, flow.state_name()])
	if stub == null or not stub.active():
		_finish(true)
		return
	_t.eq("Brindle's arena in world one seated his own plate", brindle_plate_names, [["Admiral", "Brindle"]])
	posture_events.clear()
	await physics_frame
	await physics_frame
	var warden = stub.warden
	var plate = _game.hud.boss_plate
	_t.check("the plate is seated on the stub's Warden with a name and four pips",
		plate != null and plate.active() and plate.drawn_words().size() > 0 and plate.plate_name() == "The Waking"
		and plate.pips().size() == 4 and _filled(plate) == 4 and plate.bar_fraction() == 0.0,
		"plate %s, name %s, %d pips" % [plate != null, plate.plate_name() if plate != null else "", plate.pips().size() if plate != null else -1])
	if plate == null:
		_finish(true)
		return
	var ring = warden.get_node_or_null("WardenRing")
	_t.check("the ring draws its four arcs", ring != null and ring.active() and ring.lit_count() == 4,
		"ring %s, lit %d" % [ring != null, ring.lit_count() if ring != null else -1])

	# A smash fills the bar to a stagger.
	var chords_before := _chords()
	var strikes := 0
	while not warden.staggered() and strikes < 8:
		_strike(warden)
		strikes += 1
		await physics_frame
	await physics_frame
	_t.check("posture_changed fired for the stub's Warden",
		posture_events.size() > 0 and posture_events.all(func(row): return row[0] == warden), "%d events" % posture_events.size())
	_t.check("a stagger shows open on the plate and the ring",
		warden.staggered() and plate.glyph_id() == "open" and plate.bar_color() == BossPlate.bar_color_for(true) and ring.open_now(),
		"glyph %s" % plate.glyph_id())
	_t.check("the stagger opened the core weak point", weak_points.has("core"), "weak points %s" % [weak_points])
	_t.check("the stagger chord plays", _chords() > chords_before, "cues %d -> %d" % [chords_before, _chords()])

	# The next smash on the open core takes a chunk.
	_strike(warden)
	await physics_frame
	await physics_frame
	_t.check("chunk loss updates the pips and the arcs",
		warden.chunks_left() == 3 and _filled(plate) == 3 and ring.lit_count() == 3,
		"%d chunks, %d pips, %d arcs" % [warden.chunks_left(), _filled(plate), ring.lit_count()])

	# Nothing is filed under a stage's Warden row.
	var posture_rows := 0
	var stages: Dictionary = _game.run_log.get("_stages")
	for key in stages:
		if stages[key].has("posture"):
			posture_rows += 1
	_t.eq("the run log files no stage Warden row for the stub", posture_rows, 0)
	_finish()
