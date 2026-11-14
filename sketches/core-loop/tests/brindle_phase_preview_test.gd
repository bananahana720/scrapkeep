extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const Arena := preload("res://src/boss/arena.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Palette := preload("res://src/core/palette.gd")

# FX-03: each Brindle phase turn shows the new rule. Through the transition beat that opens the
# Furnace and the Scuttle, while no attack can commit, the phase's signature mark draws once in
# the harmless bone style (a dashed outline): the first slag ring where it will stand, then a
# charge lane from the hull's nose. The preview is never a threat (no threat group, no hazard
# the boss hit-tests, no telegraph event, no damage) and is gone when the beat ends.
#
# Evidence limit: the marks are read from threat_grammar's mark list, not from pixels; the
# beats and phase stills tools are the visual check.

const DT := 1.0 / 90.0

var _game
var _boss
var _failures := 0
var _telegraphs: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _advance(seconds: float, ball: Vector3) -> void:
	for _i in int(ceil(seconds / DT)):
		Harness.put_ball(_game, ball)
		_boss.advance(DT)


func _outline(preview) -> PackedVector3Array:
	var tris := PackedVector3Array()
	for m in Threat.marks(preview.descriptor(), false):
		if m["role"] == "outline":
			tris.append_array(m["tris"])
	return tris


func _check_beat(next: int, form: String, id: String, ball: Vector3) -> void:
	_telegraphs.clear()
	var hp_before: float = _game.run.hp
	_boss.jump_to_phase(next)
	var preview = _boss.preview()
	var shown: bool = preview != null and preview.attack_id == id and preview.color == Palette.SAND
	var harmless: bool = shown and not preview.is_hostile() and not preview.is_in_group(Threat.GROUP) and not preview in _boss.active_hazards()
	var desc: Dictionary = preview.descriptor() if shown else {}
	var outline := _outline(preview) if shown else PackedVector3Array()
	var all_marks: Array = Threat.marks(desc, false).map(func(m): return m["role"]) if shown else []
	_report("phase %d's beat previews its mark" % next, shown and desc.get("form", "") == form and outline.size() > 0
			and all_marks.all(func(r): return String(r).begins_with("outline")),
		"preview %s, form %s, %d outline tris, marks %s" % [preview.attack_id if shown else "none", desc.get("form", ""), outline.size(), all_marks])
	_report("phase %d's preview is harmless" % next, harmless,
		"hostile %s, threat group %s, hit-tested %s" % [preview.is_hostile() if shown else "?", preview.is_in_group(Threat.GROUP) if shown else "?",
			(preview in _boss.active_hazards()) if shown else "?"])
	var beat: float = preview.warn_seconds if shown else FightPhases.TRANSITION_SECONDS
	_advance(beat - 0.1, ball)
	var mid = _boss.preview()
	var in_beat: Array = _telegraphs.duplicate()
	var hp_beat: float = _game.run.hp
	_advance(0.2, ball)
	_report("phase %d's preview lasts the beat and no longer" % next, mid != null and _boss.preview() == null,
		"shown at the beat's end %s; after it %s" % [mid != null, _boss.preview() != null])
	_report("phase %d's beat commits nothing and hurts nothing" % next, in_beat.is_empty() and hp_beat == hp_before,
		"%d telegraphs in the beat, hp %.0f -> %.0f with the ball on the preview" % [in_beat.size(), hp_before, hp_beat])


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	await physics_frame
	_boss = _game.boss
	_game.events.boss_attack_telegraphed.connect(func(id: String, _s: float): _telegraphs.append(id))
	_report("the opening phase has no preview", _boss.preview() == null, "preview %s" % _boss.preview())
	# The ball stands on the first slag ring through the Furnace's beat.
	var on_ring: Vector3 = Harness.ground_spot(_boss, 0.0, (Arena.RING_A.x + Arena.RING_A.y) * 0.5)
	_check_beat(2, "radial", "preview_slag", on_ring)
	_check_beat(3, "lane", "preview_charge", Harness.ground_spot(_boss, PI * 0.5, 20.0))
	_boss.jump_to_phase(4)
	_report("the chase has no ground preview", _boss.preview() == null, "preview %s" % _boss.preview())
	print("brindle_phase_preview_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
