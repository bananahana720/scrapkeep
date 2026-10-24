extends SceneTree

const BossPlate := preload("res://src/ui/boss_plate.gd")
const BuildRead := preload("res://src/ui/build_read.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Intent := preload("res://src/movement/intent.gd")
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
	boss.jump_to_phase(2)
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
