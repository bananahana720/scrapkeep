extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const BossPlate := preload("res://src/ui/boss_plate.gd")
const BossPosture := preload("res://src/core/boss_posture.gd")

# Brindle's fight reads on the same plate, ring and audio as a Warden's. In the arena,
# entered through the spine's own seam (flow.enter_boss), the HUD mounts the boss plate on
# his hull: his name from the boss_arena_entered row, four pips, the guard bar following the
# posture; a gun presses the bar; rams stagger him (the bar becomes the stagger's time and
# the glyph is "open"); a crack and a shatter take a pip; the ground ring follows the hull;
# the stagger chord plays; and the run log files nothing under a stage's Warden row.
#
# Evidence limit: combat.strike() stands in for the ball's contacts, and the plate is read
# through its accessors, not its pixels.

const DT := 1.0 / 90.0
const RAM_FORCE := 150.0

var _game
var _boss
var _combat
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _hit(target, kind: String, force: float) -> void:
	Harness.put_ball(_game, _boss.arena.global_position + Vector3.UP * 40.0)
	_combat.strike(target, kind, force)
	await physics_frame


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


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_combat = _game.combat
	_game.ctx.spawner = _combat
	_boss = _game.boss
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	await physics_frame
	await physics_frame
	var hull = _boss.ship.hull
	var plate = _game.hud.boss_plate
	if plate == null:
		_report("plate mounts on the hull", false, "no boss plate on the HUD")
		print("boss_brindle_read_test: FAIL (%d)" % _failures)
		quit(1)
		return

	# The plate is on his hull, with his name and four chunks.
	_report("plate mounts on the hull", plate != null and plate.active() and plate.drawn_words() == ["Admiral", "Brindle"]
			and _filled(plate) == 4 and plate.pips().size() == 4 and plate.bar_fraction() == 0.0,
		"plate %s, words %s, %d chunks, bar %.2f" % [plate != null, plate.drawn_words() if plate != null else [], _filled(plate) if plate != null else -1, plate.bar_fraction() if plate != null else -1.0])

	# A gun presses the bar; the plate follows the posture.
	await _hit(hull, "arc", 5.0)
	var pressed: float = _boss.posture()
	_report("a gun fills the bar", pressed > 0.0 and absf(plate.bar_fraction() - pressed / BossPosture.FULL) < 0.001 and plate.glyph_id() == "posture_step",
		"posture %.2f, bar %.3f, glyph %s" % [pressed, plate.bar_fraction(), plate.glyph_id()])

	# His hull's hits take the posture phrase's note, as a Warden's do.
	_report("the hull's hits are heard as the posture fight", _game.presentation.audio._on_posture_fight(hull), "")

	# The ring is on the hull and follows its chunks.
	var ring = hull.get_node_or_null("WardenRing")
	await physics_frame
	_report("the ring follows the hull", ring != null and ring.active() and ring.lit_count() == 4,
		"ring %s, lit %d" % [ring != null, ring.lit_count() if ring != null else -1])

	# Rams stagger him: the bar is the stagger's time, the glyph the open one, a chord plays.
	var chords_before := _chords()
	var rams := 0
	while not _boss.staggered() and rams < 6:
		await _hit(hull, "ram", RAM_FORCE)
		rams += 1
	_report("stagger shows on the plate", _boss.staggered() and plate.glyph_id() == "open" and plate.bar_color() == BossPlate.bar_color_for(true)
			and absf(plate.bar_fraction() - hull.stagger_left() / BossPosture.STAGGER_SECONDS) < 0.001 and ring.open_now(),
		"%d rams, glyph %s, bar %.3f" % [rams, plate.glyph_id(), plate.bar_fraction()])
	_report("the stagger chord plays", _chords() > chords_before, "posture_changed cues %d -> %d" % [chords_before, _chords()])

	# A contact in the opening cracks the chunk; the next opening's contact shatters it.
	await _hit(hull, "ram", RAM_FORCE)
	var cracked: bool = plate.pips()[3]["cracked"]
	for _i in int(ceil((BossPosture.STAGGER_SECONDS + 0.1) / DT)):
		Harness.put_ball(_game, _boss.arena.global_position + Vector3.UP * 40.0)
		_boss.advance(DT)
	rams = 0
	while not _boss.staggered() and rams < 6:
		await _hit(hull, "ram", RAM_FORCE)
		rams += 1
	await _hit(hull, "ram", RAM_FORCE)
	await physics_frame
	_report("chunk loss updates the count", cracked and _boss.chunks_left() == 3 and _filled(plate) == 3 and ring.lit_count() == 3,
		"cracked mark %s, %d chunks, %d pips filled, %d arcs lit" % [cracked, _boss.chunks_left(), _filled(plate), ring.lit_count()])

	# Nothing is filed under a stage's Warden row.
	var posture_rows := 0
	var stages: Dictionary = _game.run_log.get("_stages")
	for key in stages:
		if stages[key].has("posture"):
			posture_rows += 1
	_report("the run log files no Warden row", posture_rows == 0, "%d stage rows carry a posture block" % posture_rows)

	print("boss_brindle_read_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
