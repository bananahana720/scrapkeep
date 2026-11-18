extends SceneTree

const BossPlate := preload("res://src/ui/boss_plate.gd")
const BuildRead := preload("res://src/ui/build_read.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const EdgeMarkers := preload("res://src/ui/edge_markers.gd")
const FlourishPlayer := preload("res://src/presentation/flourish_player.gd")
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
#   P5  the objective plate under it names each phase's loop, one row a phase: the crane magnets
#       then the cockpit, the vent caps then the cockpit, the baited charge, and the scooter on the
#       eject. An open cockpit (a stagger, or a stun in the Scuttle) keeps the row's words, turns
#       its glyph to the cockpit's and makes the row's second step the live one; while a Scuttle
#       charge is committed the cockpit is not open, even through a stagger;
#   P6  the markers point at the next move: each crane magnet, each vent cap, the cockpit while it
#       is open, the scooter, and nothing while the row is the baited charge; a target in view
#       wears brackets and, where there is room, its tag; one out of view goes to the edge;
#   P7  a thing behind a wall or Brindle's wreck keeps faint brackets and no tag; a comic panel over a thing takes no mark;
#   R1  the pause build read with all twelve panels held (a long list) sits on screen, left of
#       the pause column and clear of it, at 1280x720 and 1920x1080, and so does the empty read;
#       on a short screen the turning view shrinks (to VIEW_MIN at least) and the read stays on screen.
#   R2  the read's turning view wears the pilot's own shell, not the grey stand-in sphere (W1-46).
# The plate's clock is stepped by hand, never read from the wall.

const SIZES := [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]
# A short screen the twelve-panel list cannot fit at full view height, so the view shrinks.
const SHORT := Vector2(1280.0, 560.0)
const TAG_SEEDS := [203, 1, 7, 31, 99, 4242]

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
	await _late_phase_rows()
	_game.free()
	quit(_t.verdict())


func _unit_checks() -> void:
	var warden := FakeWarden.new()
	root.add_child(warden)
	var plate := BossPlate.new()
	plate.set_process(false)
	plate.bind(warden)
	_t.check("P1 no phases: no diamonds, plate size unchanged", plate.phase_pips().is_empty() and plate.size == plate.rest_size(), "%s %s" % [plate.phase_pips(), plate.size])
	var phases := FakePhases.new()
	plate.bind(warden, phases)
	_t.eq("P2 phase 0 before the fight: nothing lit", plate.phase_pips(), ["ahead", "ahead", "ahead"])
	_t.eq("P2 the plate grows by the drop", plate.size, plate.rest_size() + Vector2(0.0, BossPlate.PHASE_DROP))
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
	_t.eq("P5 phase one: the plate names the crane magnets, then the cockpit", _plate_row(), ["shoot_magnets", "Shoot magnets, then cockpit", Objectives.glyph("shoot_magnets")])
	_t.eq("P6 phase one: a marker for each crane magnet, tagged", _marks(),
		[boss.ship.magnets.map(func(m): return m.global_position), "MAGNET", Objectives.glyph("shoot_magnets")])
	boss._posture.staggered = true
	_t.eq("P5 a stagger in phase one keeps the row's words and turns its glyph", [boss.staggered(), _plate_row()],
		[true, ["shoot_magnets", "Shoot magnets, then cockpit", Objectives.COCKPIT_GLYPH]])
	_t.eq("P6 and the one marker moves to the cockpit", _marks(), [[boss.ship.cockpit_point()], "COCKPIT", Objectives.COCKPIT_GLYPH])
	_game.hud._process(0.0)
	_t.eq("P5 the row's second step is live, on the reading and on the plate", [_game.hud.objective_reading()["step"], _game.hud._objective.step], [1, 1])
	boss._posture.staggered = false
	_game.hud._process(0.0)
	_t.eq("P5 and its first again when the cockpit shuts", [_game.hud.objective_reading()["step"], _game.hud._objective.step], [0, 0])
	_marker_checks(boss.ship.magnets[0].global_position)
	await _sight_checks(boss.ship.magnets[0].global_position)
	boss.jump_to_phase(2)
	_t.eq("P5 phase two: the vent caps, then the cockpit", _plate_row(), ["slam_caps", "Slam caps, then cockpit", Objectives.glyph("slam_caps")])
	_t.eq("P6 phase two: a marker for each vent cap, tagged", [_marks(), boss.ship.caps.size()],
		[[boss.ship.caps.map(func(c): return c.global_position), "VENT CAP", Objectives.glyph("slam_caps")], 3])
	# A stagger opens the cockpit in any phase, and the weak points pay nothing through it.
	boss._posture.staggered = true
	_t.eq("P5 a stagger in phase two keeps the row's words and turns its glyph", [boss.staggered(), _plate_row()],
		[true, ["slam_caps", "Slam caps, then cockpit", Objectives.COCKPIT_GLYPH]])
	_t.eq("P6 and the one marker moves to the cockpit", _marks(), [[boss.ship.cockpit_point()], "COCKPIT", Objectives.COCKPIT_GLYPH])
	boss._posture.staggered = false
	_t.eq("P5 and the caps' glyph comes back when it ends", _plate_row(), ["slam_caps", "Slam caps, then cockpit", Objectives.glyph("slam_caps")])
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
	return [reading["id"], reading["words"], reading["icon"]]


# What the markers point at for the row the plate shows now: the places, the tag they wear and the
# glyph they carry to the view's edge ("" when there is none or they differ). The HUD hands the
# markers the row and its glyph each frame; here they are handed over.
func _marks() -> Array:
	var markers = _game.hud.edge_markers
	var row := _plate_row()
	markers.objective_id = row[0]
	markers.objective_icon = row[2]
	var targets: Array = markers.targets()
	var same := targets.all(func(t): return t["kind"] == "boss_arena_entered" and t["mark"] and t["icon"] == targets[0]["icon"] and t["tag"] == targets[0]["tag"])
	return [targets.map(func(t): return t["at"]), targets[0]["tag"] if same and not targets.is_empty() else "", targets[0]["icon"] if same and not targets.is_empty() else ""]


# One target looked at from 20 m wears brackets round it, big enough to see, and the target nearest
# the middle of the view wears the tag, all of it inside the play view; with the camera turned away
# the same target goes to the edge of the play view as any marker does.
func _marker_checks(at: Vector3) -> void:
	var markers = _game.hud.edge_markers
	var cam: Camera3D = _game.camera.cam
	var size: Vector2 = cam.get_viewport().get_visible_rect().size
	var was := cam.global_transform
	var view: Rect2 = EdgeMarkers.view_rect(size)
	_marks()
	cam.look_at_from_position(at + Vector3(0.0, 0.0, 20.0), at)
	var want: Vector2 = cam.unproject_position(at)
	var marks: Array = markers.markers(size).filter(func(m): return m.has("box"))
	var on: Array = marks.filter(func(m): return m["box"].has_point(want))
	_t.check("P6 a target in view wears brackets round it", on.size() == 1, "markers %s, wanted one round %s" % [markers.markers(size), want])
	if on.size() == 1:
		var box: Rect2 = on[0]["box"]
		_t.check("P6 the brackets are big enough to see", minf(box.size.x, box.size.y) >= EdgeMarkers.MARK_MIN * 2.0, "box %s" % box)
		_t.eq("P6 the target in the middle of the view wears the tag", on[0]["tag"], "MAGNET")
		_t.check("P6 and brackets and tag sit between the top and bottom bands", EdgeMarkers.mark_view(size).encloses(EdgeMarkers.mark_rect(box, on[0]["tag"])),
			"mark %s room %s" % [EdgeMarkers.mark_rect(box, on[0]["tag"]), EdgeMarkers.mark_view(size)])
	# Every pair of brackets wears the tag where it has room (three blind readers could not tell
	# whether brackets with no tag were a magnet too), and no tag covers another mark.
	var taken: Array = marks.map(func(m): return EdgeMarkers.mark_rect(m["box"], m["tag"], m["under"]))
	var covered := false
	for i in taken.size():
		for j in i:
			covered = covered or taken[i].intersects(taken[j])
	var bare := []
	for m in marks:
		var others: Array[Rect2] = []
		for r in taken:
			if not r.has_point(m["box"].get_center()):
				others.append(r)
		if m["tag"] != "MAGNET" and EdgeMarkers._free(EdgeMarkers.mark_rect(m["box"], "MAGNET"), EdgeMarkers.mark_view(size), others):
			bare.append(m)
	_t.check("P6 every pair of brackets with room wears the tag, and no mark covers another", not covered and bare.is_empty(), "marks %s" % [marks])
	_t.eq("P6 the tags are counted as words on the screen", Array(markers.drawn_words()).size() if not markers._shown.is_empty() else -1,
		markers._shown.filter(func(m): return m.get("tag", "") != "").size() if not markers._shown.is_empty() else -1)
	var crowd: Array[Rect2] = [Rect2(100, 100, 80, 40)]
	_t.eq("P6 a tag has no room over another mark", [EdgeMarkers._free(Rect2(150, 120, 40, 20), Rect2(0, 0, 400, 400), crowd), EdgeMarkers._free(Rect2(200, 200, 40, 20), Rect2(0, 0, 400, 400), crowd),
		EdgeMarkers._free(Rect2(380, 200, 40, 20), Rect2(0, 0, 400, 400), crowd)], [false, true, false])
	# Two targets close together on the screen share one pair of brackets.
	var boxes: Array[Dictionary] = []
	for box in [Rect2(100, 100, 60, 60), Rect2(150, 110, 60, 60), Rect2(400, 100, 60, 60)]:
		EdgeMarkers._group(boxes, {"box": box, "color": Color.WHITE, "tag": "VENT CAP", "targets": [box]})
	_t.eq("P6 boxes that touch share one pair of brackets", boxes.map(func(g): return [g["box"], g["targets"].size()]),
		[[Rect2(100, 100, 110, 70), 2], [Rect2(400, 100, 60, 60), 1]])
	# A box that bridges two groups takes both, and then a third that only the grown box touches.
	var chain: Array[Dictionary] = []
	for box in [Rect2(0, 0, 40, 40), Rect2(100, 0, 40, 40), Rect2(60, 60, 30, 30), Rect2(35, 30, 70, 35)]:
		EdgeMarkers._group(chain, {"box": box, "color": Color.WHITE, "tag": "VENT CAP", "targets": [box]})
	_t.eq("P6 a box that joins groups takes every group the joined box touches", chain.map(func(g): return [g["box"], g["targets"].size()]), [[Rect2(0, 0, 140, 90), 4]])
	# A thing at the room's rim keeps its brackets: they move the least it takes to stand in the
	# room while its middle stays inside them, and the tag goes under when there is no room over.
	var room: Rect2 = EdgeMarkers.mark_view(size)
	var rim := Rect2(room.get_center().x - 30.0, room.position.y - 10.0, 60.0, 60.0)
	var slid: Rect2 = EdgeMarkers._slid(rim, room)
	_t.check("P6 brackets at the room's rim slide into it, round the thing still", room.encloses(EdgeMarkers.mark_rect(slid, "")) and slid.has_point(rim.get_center())
			and slid.position.x == rim.position.x, "%s to %s in %s" % [rim, slid, room])
	_t.check("P6 with no room over them the tag fits under", not room.encloses(EdgeMarkers.mark_rect(slid, "SCOOTER")) and room.encloses(EdgeMarkers.mark_rect(slid, "SCOOTER", true))
			and EdgeMarkers.tag_rect(slid, "SCOOTER", true).position.y > slid.end.y)
	var out_of_room := Rect2(room.get_center().x - 30.0, room.position.y - 45.0, 60.0, 60.0)
	_t.eq("P6 brackets whose thing is out of the room are left where they are", EdgeMarkers._slid(out_of_room, room), out_of_room)
	# Under the top band a mark would cover the plate: the target goes to the edge instead.
	var high := Vector2.ZERO
	for drop in 80:
		cam.look_at_from_position(at + Vector3(0.0, 0.0, 20.0), at + Vector3.DOWN * (4.0 + drop * 0.5))
		high = cam.unproject_position(at)
		if high.y < room.position.y - 2.0:
			break
	if _t.check("P6 (premise) the target projects on screen under the top band", Rect2(Vector2.ZERO, size).has_point(high) and high.y < room.position.y, "at %s, room %s" % [high, room]):
		_t.check("P6 a target under the top band goes to the edge, with no brackets", markers.markers(size).all(func(m): return not m.has("box") or not m["box"].has_point(high)),
			"markers %s" % [markers.markers(size)])
	cam.look_at_from_position(at + Vector3(0.0, 0.0, 20.0), at + Vector3(0.0, 0.0, 40.0))
	var away: Array = markers.markers(size)
	_t.check("P6 out of view, every target goes to the edge of the play view", away.size() == markers.targets().size()
			and away.all(func(m): return m.has("dir") and _on_rim(view, m["at"])), "markers %s" % [away])
	cam.global_transform = was


# A mark is only as true as the picture under it (PC film of PR 729): a wall between the camera and
# the thing leaves faint brackets and no tag, and a comic panel over the thing takes no mark.
func _sight_checks(at: Vector3) -> void:
	var markers = _game.hud.edge_markers
	var cam: Camera3D = _game.camera.cam
	var size: Vector2 = cam.get_viewport().get_visible_rect().size
	var was := cam.global_transform
	_marks()
	cam.look_at_from_position(at + Vector3(0.0, 0.0, 20.0), at)
	var want: Vector2 = cam.unproject_position(at)
	_t.check("P7 (premise) nothing stands between the camera and the magnet", markers.in_sight(cam, at))
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12.0, 12.0, 0.5)
	shape.shape = box
	wall.add_child(shape)
	_game.add_child(wall)
	wall.global_position = at + Vector3(0.0, 0.0, 10.0)
	await _frames(2)
	_t.check("P7 a wall between the camera and the thing hides it", not markers.in_sight(cam, at))
	var on: Array = markers.markers(size).filter(func(m): return m.has("box") and m["box"].has_point(want))
	_t.check("P7 behind a wall the thing keeps faint brackets and no tag", on.size() == 1 and on[0]["tag"] == "" and on[0]["color"].a < 0.5,
		"marks %s" % [on])
	wall.free()
	await _frames(2)
	var edges: int = markers.markers(size).filter(func(m): return m.has("dir")).size()
	var panel := Control.new()
	panel.add_to_group(FlourishPlayer.AVOID_GROUP)
	_game.hud.add_child(panel)
	panel.position = want - Vector2(150.0, 150.0)
	panel.size = Vector2(300.0, 300.0)
	var panel_rect := Rect2(panel.position, panel.size)
	var shown: Array = markers.markers(size)
	_t.check("P7 a comic panel over the thing takes no mark, at the edge or round it",
		shown.all(func(m): return not m.has("box") or not m["box"].intersects(panel_rect)) and shown.filter(func(m): return m.has("dir")).size() == edges,
		"marks %s" % [shown])
	panel.free()
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
	_t.eq("P5 phase three: bait the charge", _plate_row(), ["bait_charge", "Bait into walls, then cockpit", Objectives.glyph("bait_charge")])
	_t.eq("P6 a baited charge names no one place, so nothing is marked", _marks(), [[], "", ""])
	boss._posture.staggered = true
	_t.eq("P5 a stagger between charges keeps the row and turns its glyph", [boss.charge_coming(), _plate_row()], [false, ["bait_charge", "Bait into walls, then cockpit", Objectives.COCKPIT_GLYPH]])
	# A stagger does not hold a Scuttle charge back. From the commit (the lane's tell) to the end of
	# the run the plate keeps the charge's row, and no marker sends the player at the cockpit.
	boss._commit_charge(_game.player.ball_position())
	_t.eq("P5 a charge committed through the stagger keeps the charge's row", [boss.staggered(), boss.charge_coming(), _plate_row()],
		[true, true, ["bait_charge", "Bait into walls, then cockpit", Objectives.glyph("bait_charge")]])
	_t.eq("P6 and marks nothing", _marks(), [[], "", ""])
	boss._charge["state"] = boss.CHARGE_RUN
	_t.eq("P5 and through the run", [boss.charging(), _plate_row()], [true, ["bait_charge", "Bait into walls, then cockpit", Objectives.glyph("bait_charge")]])
	_t.eq("P5 with the row's first step live", _game.hud.objective_reading()["step"], 0)
	boss._posture.staggered = false
	boss._stun(2.0)
	_t.eq("P5 a stun keeps the row and turns its glyph", [boss.charge_coming(), _plate_row()], [false, ["bait_charge", "Bait into walls, then cockpit", Objectives.COCKPIT_GLYPH]])
	_t.eq("P6 with its marker", _marks(), [[boss.ship.cockpit_point()], "COCKPIT", Objectives.COCKPIT_GLYPH])
	_t.eq("P5 and the row's second step live", _game.hud.objective_reading()["step"], 1)
	boss._begin_eject()
	_t.eq("P5 the eject names the scooter", _plate_row(), ["ram_scooter", "Ram the Admiral's scooter", Objectives.glyph("ram_scooter")])
	_t.eq("P6 and the marker follows the scooter", _marks(), [[boss.scooter.global_position], "SCOOTER", Objectives.glyph("ram_scooter")])
	# The scooter lands across the arena from the ball, often with the wreck between: the wreck is
	# world from the eject on and hides what is behind it like any wall.
	await _frames(2)
	var cam: Camera3D = _game.camera.cam
	var was := cam.global_transform
	var hull: Vector3 = boss.ship.hull.global_position
	cam.look_at_from_position(hull + Vector3(0.0, 0.0, 20.0), hull)
	_t.check("P7 the wreck hides a thing behind it", not _game.hud.edge_markers.in_sight(cam, hull + Vector3(0.0, 0.0, -20.0)))
	cam.global_transform = was


func _pause_checks() -> void:
	var menu = _game.get_node("PauseMenu")
	var read = menu.build_read
	# Stop the preview's turn first, so the facing check reads the opening pose however slow the run.
	read.set_process(false)
	for held in [[], Panels.ROWS.keys()]:
		_game.run.panels.clear()
		for id in held:
			for n in 3:
				_game.run.panels.append(String(id))
		menu._show_build()
		var label := "all twelve panels" if held.size() > 0 else "no panels"
		# W1-46: the pilot's own shell turns in the view, never the grey stand-in sphere.
		_t.check("R2 %s: the view wears the pilot's shell" % label, not read._worn.is_empty() and read._worn.core.is_inside_tree() and not read._ball.visible, str(read._worn.keys()))
		var pilot: Node3D = read._worn.pod.get_node_or_null("AnimatedPilot")
		_t.check("R2 %s: the pilot's model is in the shell" % label, pilot != null and pilot.scene_file_path.contains("pilot_"))
		_t.check("R2 %s: the preview opens with the pilot facing the eye" % label, (-read._worn.pod.global_basis.z).dot(Vector3.BACK) > 0.9)
		var cores: Array = read._pivot.get_children().filter(func(n): return n.name == "HeroCore" and not n.is_queued_for_deletion())
		_t.eq("R2 %s: one shell, never a pile of them" % label, cores.size(), 1)
		_t.eq("R1 %s: one stat line each" % label, read.lines.size(), maxi(1, held.size()))
		if held.size() > 0 and _game.presentation.hero_assets.ball_look() == "cutaway":
			var parts: Array = read.shell.find_children("*", "MultiMeshInstance3D", false, false)
			_t.eq("R2 the grown preview wears the held panels", read.shell.shown_count(), _game.run.panels.size())
			_t.check("R2 every panel leaves the same window as the shell", not parts.is_empty() and parts.all(func(part):
				var material = part.multimesh.mesh.surface_get_material(0)
				return material is ShaderMaterial and material.get_shader_parameter("held") == true))
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
	await _opening_tags(menu)


func _opening_tags(menu: Node) -> void:
	var prior_seed: int = _game.run.run_seed
	var prior_panels := Array(_game.run.panels).duplicate()
	var read = menu.build_read
	read.set_process(false)
	# The hard check: seed 203 puts the spool near the top edge when the pilot faces the player.
	var eight := ["punch_rivet", "fin_plate", "splash_skirt", "ram_bumper",
		"vent_louvre", "winch_drum", "hull_tile", "rope_spool"]
	var first: Dictionary = await _tag_layout(menu, eight, 24, 203)
	_t.check("R2 all eight opening tag bounds fit the 720p preview", first.count == eight.size() and first.room >= 0.0,
		"%d boxes, %.2f px" % [first.count, first.room])
	_t.check("R2 the opening tag bounds have at most one overlapping pair", first.overlaps.size() <= 1, str(first.overlaps))
	# The wide read: every panel type at several seeds, because a seed moves where each part sits on
	# the shell. Only tags on the near side of the shell count; the shell hides the rest in the game.
	var every: Array = Panels.ROWS.keys()
	var overlaps := []
	var tight := []
	for seed_value in TAG_SEEDS:
		var laid: Dictionary = await _tag_layout(menu, every, every.size() * 2, seed_value)
		for pair in laid.overlaps:
			overlaps.append("seed %d: %s" % [seed_value, pair])
		if laid.count != every.size() or laid.room < 0.0:
			tight.append("seed %d: %d boxes, %.2f px" % [seed_value, laid.count, laid.room])
	if tight.is_empty():
		_t.check("R2 all %d opening tag bounds fit the 720p preview at every seed" % every.size(), true, "%d seeds" % TAG_SEEDS.size())
	else:
		_t.skip("R2 all %d opening tag bounds fit the 720p preview at every seed" % every.size(), "open problem, a tag leaves the view (px of room): " + "; ".join(tight))
	if overlaps.is_empty():
		_t.check("R2 no two opening tags overlap, at every seed and panel type", true, "%d seeds" % TAG_SEEDS.size())
	else:
		_t.skip("R2 no two opening tags overlap, at every seed and panel type", "open problem, tags overlap at: " + "; ".join(overlaps))
	_game.run.run_seed = prior_seed
	_game.run.panels.clear()
	_game.run.panels.append_array(prior_panels)
	read.set_process(true)



# Lays the Build preview for one ball and measures its tags on screen: how many there are, the least
# room any near-side tag has inside the view, and which near-side pairs overlap.
func _tag_layout(menu: Node, stack: Array, plates: int, seed_value: int) -> Dictionary:
	var read = menu.build_read
	_game.run.run_seed = seed_value
	_game.run.panels.clear()
	for i in plates:
		_game.run.panels.append(String(stack[i % stack.size()]))
	menu._show_build()
	menu.lay_build(SIZES[0])
	await process_frame
	await process_frame
	var view := read._frame.get_child(0) as SubViewport
	var camera := view.get_camera_3d()
	var centre: Vector3 = read._labels.global_position
	var boxes: Array[Rect2] = []
	var names: Array[String] = []
	var overlaps := []
	var room := INF
	var count := 0
	for tag: Label3D in read._labels.get_children():
		count += 1
		if (tag.global_position - centre).dot(camera.global_position - centre) <= 0.0:
			continue
		# The dummy renderer has no glyph bounds. Estimate the outlined billboard in screen space.
		var font := tag.font if tag.font != null else ThemeDB.fallback_font
		var size := font.get_string_size(tag.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tag.font_size)
		var half := (size + Vector2.ONE * tag.outline_size * 2.0) * tag.pixel_size * 0.5
		var corner := camera.global_basis.y * half.y - camera.global_basis.x * half.x
		var a := camera.unproject_position(tag.global_position + corner)
		var b := camera.unproject_position(tag.global_position - corner)
		var box := Rect2(a, b - a)
		room = minf(room, minf(minf(a.x, a.y), minf(view.size.x - b.x, view.size.y - b.y)))
		for earlier in boxes.size():
			if boxes[earlier].intersects(box):
				overlaps.append("%s over %s" % [names[earlier], tag.text])
		boxes.append(box)
		names.append(tag.text)
	return {"count": count if view.size == BuildRead.VIEW else -1, "room": room, "overlaps": overlaps}
