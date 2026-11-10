extends SceneTree

const BossPlate := preload("res://src/ui/boss_plate.gd")
const BuildRead := preload("res://src/ui/build_read.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const EdgeMarkers := preload("res://src/ui/edge_markers.gd")
const Intent := preload("res://src/movement/intent.gd")
const Objectives := preload("res://src/core/objectives.gd")
const Panels := preload("res://src/build/panels.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const T := preload("res://tests/support/t.gd")

# Unit 20, the phase read and the panel read (world 1 plan, 23 Oct):
#   P1  a plate bound without phases sets no diamonds and keeps its size, so a stage
#       Warden's plate is unchanged;
#   P2  a three-phase fight sets three diamonds in the rim (live, ahead, ahead) and the
#       plate grows by the drop; the first phase lighting at the fight's start is no crack;
#   P3  each turn cracks the spent diamond for CRACK_SECONDS of stepped time, then it rests
#       cracked; the last phase reads spent, spent, live;
#   P4  in the real Slag Bowl the HUD binds Brindle's own FightPhases: the plate follows
#       jump_to_phase with a crack, and at 1280x720 and 1920x1080 it sits top-centre inside
#       the top band, the diamonds clear of the objective plate under it;
#   P5  the objective plate under it names each phase's verb: the crane magnets, the vent
#       caps, the baited charge, the open cockpit on a stagger or a stun, and the scooter on the eject;
#       while a Scuttle charge is committed the plate keeps the charge's row through a stagger;
#   P6  the markers point at what the row names: each crane magnet, each vent cap, the cockpit
#       while the plate names it, the scooter, and nothing while the row is the baited charge;
#       a target in view keeps a small marker over it, one out of view goes to the edge;
#   R1  the pause build read with all twelve panels held (a long list) sits on screen, left of
#       the pause column and clear of it, at 1280x720 and 1920x1080, and so does the empty read;
#       on a short screen the turning view shrinks (to VIEW_MIN at least) and the read stays on screen.
# The plate's clock is stepped by hand, never read from the wall.

const SIZES := [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]
# A short screen the twelve-panel list cannot fit at full view height, so the view shrinks.
const SHORT := Vector2(1280.0, 560.0)

var _t := T.new("hud_phase_read_test")
var _game
var _started := false


class FakeWarden extends Node3D:
	func fight() -> String:
		return "posture"

	func is_dead() -> bool:
		return false

	func chunks_left() -> int:
		return BossPosture.CHUNKS

	func chunk_cracked() -> bool:
		return false

	func staggered() -> bool:
		return false

	func posture() -> float:
		return 40.0

	func stagger_left() -> float:
		return 0.0


class FakePhases extends RefCounted:
	var phase := 0
	var phases := 3


func _initialize() -> void:
	_unit_checks()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null or _started:
		return false
	_started = true
	_run()
	return false


func _run() -> void:
	await _arena_checks()
	await _pause_checks()
	_late_phase_rows()
	_game.free()
	quit(_t.verdict())


func _unit_checks() -> void:
	var warden := FakeWarden.new()
	root.add_child(warden)
	var plate := BossPlate.new()
	plate.set_process(false)
	plate.bind(warden)
	_t.check("P1 no phases: no diamonds, plate size unchanged", plate.phase_pips().is_empty() and plate.size == BossPlate.SIZE, "%s %s" % [plate.phase_pips(), plate.size])
	var phases := FakePhases.new()
	plate.bind(warden, phases)
	_t.eq("P2 phase 0 before the fight: nothing lit", plate.phase_pips(), ["ahead", "ahead", "ahead"])
	_t.eq("P2 the plate grows by the drop", plate.size, BossPlate.SIZE + Vector2(0.0, BossPlate.PHASE_DROP))
	phases.phase = 1
	plate.advance(0.016)
	_t.eq("P2 phase one lit", plate.phase_pips(), ["live", "ahead", "ahead"])
	_t.check("P2 the fight's opening phase is no crack", plate.turn_age() < 0.0, "turn age %s" % plate.turn_age())
	phases.phase = 2
	plate.advance(0.016)
	_t.eq("P3 turn to two: spent, live, ahead", plate.phase_pips(), ["spent", "live", "ahead"])
	_t.check("P3 the crack starts at the turn", plate.turn_age() >= 0.0 and plate.turn_age() < 0.05, "turn age %s" % plate.turn_age())
	plate.advance(0.1)
	_t.check("P3 mid-crack the spent diamond pops and the lit one grows in", plate.diamond_scale(0) > 1.05 and plate.diamond_scale(1) < 1.0 and plate.diamond_scale(2) == 1.0,
		"%s %s %s" % [plate.diamond_scale(0), plate.diamond_scale(1), plate.diamond_scale(2)])
	BossPlate.reduced_motion = true
	_t.check("P3 reduced motion: no pop, no grow", plate.diamond_scale(0) == 1.0 and plate.diamond_scale(1) == 1.0)
	BossPlate.reduced_motion = false
	for i in int(ceil(BossPlate.CRACK_SECONDS / 0.1)) + 1:
		plate.advance(0.1)
	_t.check("P3 the crack ends after CRACK_SECONDS", plate.turn_age() < 0.0, "turn age %s" % plate.turn_age())
	phases.phase = 3
	plate.advance(0.016)
	_t.eq("P3 the last phase: spent, spent, live", plate.phase_pips(), ["spent", "spent", "live"])
	plate.unbind()
	_t.check("P3 unbound: no diamonds, size back", plate.phase_pips().is_empty() and plate.size == BossPlate.SIZE, str(plate.size))
	plate.free()
	warden.free()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _arena_checks() -> void:
	Harness.install(_game)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	Harness.start_run(_game)
	_game.run.set_max_hp(99999.0)
	_game.flow.enter_stage(StageDefs.last_of(1), Vector3(0.0, 0.0, 16.0), false)
	_game.flow._finish_stage()
	await _frames(3)
	var hud = _game.hud
	var plate = hud.boss_plate
	if not _t.check("P4 the Slag Bowl puts the boss plate up", plate != null and plate.active(), str(plate)):
		return
	plate.set_process(false)
	var boss = _game.boss
	_t.check("P4 the plate reads Brindle's own phases", plate._phases == boss._phases and plate.phase_count() == 3, "%s" % plate.phase_count())
	_t.eq("P4 phase one lit, no crack", [plate.phase_pips(), plate.turn_age() < 0.0], [["live", "ahead", "ahead"], true])
	_t.eq("P5 phase one: the plate names the crane magnets", _plate_row(), ["shoot_magnets", "Shoot the crane magnets"])
	_t.eq("P6 phase one: a marker for each crane magnet, in the row's glyph", _marks(),
		[boss.ship.magnets.map(func(m): return m.global_position), Objectives.glyph("shoot_magnets")])
	_marker_checks(boss.ship.magnets[0].global_position)
	boss.jump_to_phase(2)
	_t.eq("P5 phase two: the vent caps", _plate_row(), ["slam_caps", "Slam the vent caps"])
	_t.eq("P6 phase two: a marker for each vent cap", [_marks()[0], boss.ship.caps.size()], [boss.ship.caps.map(func(c): return c.global_position), 3])
	# A stagger opens the cockpit in any phase, and the weak points pay nothing through it.
	boss._posture.staggered = true
	_t.eq("P5 a stagger in phase two names the open cockpit", [boss.staggered(), _plate_row()], [true, ["hit_cockpit", "Hit the open cockpit"]])
	_t.eq("P6 and the one marker moves to the cockpit", _marks(), [[boss.ship.cockpit_point()], Objectives.glyph("hit_cockpit")])
	boss._posture.staggered = false
	_t.eq("P5 and the caps come back when it ends", _plate_row(), ["slam_caps", "Slam the vent caps"])
	plate.advance(0.016)
	_t.eq("P4 jump_to_phase(2) turns the diamonds", plate.phase_pips(), ["spent", "live", "ahead"])
	_t.check("P4 and cracks the spent one", plate.turn_age() >= 0.0)
	for size in SIZES:
		hud.layout(size)
		var tag := "%dx%d" % [int(size.x), int(size.y)]
		var rect := Rect2(plate.position, plate.size)
		var objective: Rect2 = hud.piece_rects()["top"][0]
		_t.check("P4 %s plate top-centre, inside the screen" % tag, absf(rect.get_center().x - size.x * 0.5) < 2.0 and rect.position.y >= 0.0 and rect.end.y < size.y * 0.5, str(rect))
		_t.check("P4 %s diamonds clear of the objective plate" % tag, not rect.intersects(objective), "plate %s objective %s" % [rect, objective])
	hud.layout(hud._screen_size())


func _plate_row() -> Array:
	var reading: Dictionary = _game.hud.objective_reading()
	return [reading["id"], reading["words"]]


# What the markers point at for the row the plate shows now: the places, and the glyph they wear
# ("" when there is none). The HUD hands the markers the row each frame; here it is handed over.
func _marks() -> Array:
	var markers = _game.hud.edge_markers
	markers.objective_id = _plate_row()[0]
	var targets: Array = markers.targets()
	var same := targets.all(func(t): return t["kind"] == "boss_arena_entered" and t["mark"] and t["icon"] == targets[0]["icon"])
	return [targets.map(func(t): return t["at"]), targets[0]["icon"] if same and not targets.is_empty() else ""]


# One target looked at from 20 m keeps a small marker over it, pointing down; with the camera turned
# away the same target goes to the edge of the play view as any marker does.
func _marker_checks(at: Vector3) -> void:
	var markers = _game.hud.edge_markers
	var cam: Camera3D = _game.camera.cam
	var size: Vector2 = cam.get_viewport().get_visible_rect().size
	var was := cam.global_transform
	cam.look_at_from_position(at + Vector3(0.0, 0.0, 20.0), at)
	var over: Array = markers.markers(size).filter(func(m): return m["dir"] == Vector2.DOWN and is_equal_approx(m["size"], EdgeMarkers.MARK_SIZE))
	var want: Vector2 = cam.unproject_position(at) + Vector2.UP * EdgeMarkers.MARK_GAP
	_t.check("P6 a target in view keeps a small marker over it, pointing down", over.any(func(m): return m["at"].distance_to(want) < 0.5),
		"markers %s, wanted one at %s" % [markers.markers(size), want])
	cam.look_at_from_position(at + Vector3(0.0, 0.0, 20.0), at + Vector3(0.0, 0.0, 40.0))
	var away: Array = markers.markers(size)
	var view: Rect2 = EdgeMarkers.view_rect(size)
	_t.check("P6 out of view, every target goes to the edge of the play view", away.size() == markers.targets().size()
			and away.all(func(m): return m["size"] > EdgeMarkers.MARK_SIZE and _on_rim(view, m["at"])), "markers %s" % [away])
	cam.global_transform = was


static func _on_rim(view: Rect2, at: Vector2) -> bool:
	var on_side := absf(at.x - view.position.x) < 1.0 or absf(at.x - view.end.x) < 1.0
	var on_end := absf(at.y - view.position.y) < 1.0 or absf(at.y - view.end.y) < 1.0
	return view.grow(1.0).has_point(at) and (on_side or on_end)


# Last, since the stun and the eject leave the fight where no other check wants it.
func _late_phase_rows() -> void:
	var boss = _game.boss
	if not _t.check("P5 the fight is still live", boss.active(), "state %s" % boss.state):
		return
	boss.jump_to_phase(3)
	_t.eq("P5 phase three: bait the charge", _plate_row(), ["bait_charge", "Bait his charge into walls"])
	_t.eq("P6 a baited charge names no one place, so nothing is marked", _marks(), [[], ""])
	boss._posture.staggered = true
	_t.eq("P5 a stagger between charges names the open cockpit", [boss.charge_coming(), _plate_row()], [false, ["hit_cockpit", "Hit the open cockpit"]])
	# A stagger does not hold a Scuttle charge back. From the commit (the lane's tell) to the end of
	# the run the plate keeps the charge's row, and no marker sends the player at the cockpit.
	boss._commit_charge(_game.player.ball_position())
	_t.eq("P5 a charge committed through the stagger keeps the charge's row", [boss.staggered(), boss.charge_coming(), _plate_row()],
		[true, true, ["bait_charge", "Bait his charge into walls"]])
	_t.eq("P6 and marks nothing", _marks(), [[], ""])
	boss._charge["state"] = boss.CHARGE_RUN
	_t.eq("P5 and through the run", [boss.charging(), _plate_row()], [true, ["bait_charge", "Bait his charge into walls"]])
	boss._posture.staggered = false
	boss._stun(2.0)
	_t.eq("P5 a stun opens the cockpit on the plate", [boss.charge_coming(), _plate_row()], [false, ["hit_cockpit", "Hit the open cockpit"]])
	_t.eq("P6 with its marker", _marks(), [[boss.ship.cockpit_point()], Objectives.glyph("hit_cockpit")])
	boss._begin_eject()
	_t.eq("P5 the eject names the scooter", _plate_row(), ["ram_scooter", "Ram the Admiral's scooter"])
	_t.eq("P6 and the marker follows the scooter", _marks(), [[boss.scooter.global_position], Objectives.glyph("ram_scooter")])


func _pause_checks() -> void:
	var menu = _game.get_node("PauseMenu")
	var read = menu.build_read
	for held in [[], Panels.ROWS.keys()]:
		_game.run.panels.clear()
		for id in held:
			for n in 3:
				_game.run.panels.append(String(id))
		menu._show_build()
		var label := "all twelve panels" if held.size() > 0 else "no panels"
		_t.eq("R1 %s: one stat line each" % label, read.lines.size(), maxi(1, held.size()))
		for size in SIZES:
			menu.lay_build(size)
			var tag := "%dx%d %s" % [int(size.x), int(size.y), label]
			var rect := Rect2(read.position, read.size)
			var column_left: float = (size.x - menu.column_width()) * 0.5
			_t.check("R1 %s inside the screen" % tag, Rect2(Vector2.ZERO, size).encloses(rect), str(rect))
			_t.check("R1 %s left of the pause column, clear of it" % tag, rect.end.x <= column_left - 8.0, "read %s column from x %s" % [rect, column_left])
			_t.check("R1 %s ball view at least VIEW_MIN tall" % tag, read._frame.custom_minimum_size.y >= BuildRead.VIEW.y * BuildRead.VIEW_MIN - 0.5, str(read._frame.custom_minimum_size))
		if held.size() > 0:
			menu.lay_build(SHORT)
			var rect := Rect2(read.position, read.size)
			var view_y: float = read._frame.custom_minimum_size.y
			_t.check("R1 short screen: the view shrinks, not below VIEW_MIN", view_y < BuildRead.VIEW.y and view_y >= BuildRead.VIEW.y * BuildRead.VIEW_MIN - 0.5, str(view_y))
			_t.check("R1 short screen: the read stays on screen", Rect2(Vector2.ZERO, SHORT).encloses(rect), str(rect))
