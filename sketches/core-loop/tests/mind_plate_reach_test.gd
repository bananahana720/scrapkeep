extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const BossPosture := preload("res://src/core/boss_posture.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const CodexEntries := preload("res://src/boss/codex_entries.gd")
const T := preload("res://tests/support/t.gd")

# The Mind's plate is reachable in a real fight. Pure rules: phase_cap is one phase per
# posture chunk and one per family, only the last phase exposes the plate, and phase 4
# warns equal phase 3 warns, never under WARN_FLOOR. Live fight on the default table,
# world three: struck to its last chunk, the Mind enters phase 4 and its first telegraph
# there is mind_plate_0 within 2 frames, with no plate before it; the HUD names the plate
# and a contact verb. A stagger inside the plate's weak window and a strike with another
# verb fire the mind_plate codex row. The plate opener fires once: the next commit, held
# for before the kill, waits a full ATTACK_PERIOD.
#
# Evidence limit: hits are TARGET calls, not ball contacts; the struck verb is an
# enemy_struck emit; the ball is the test-mode bot, so which attacks land depends on its
# path.

const IDLE_FRAMES := 90 * 5
const CHUNK_CAP := 90 * 30
const STAGGER_CAP := 90 * 10
const KILL_CAP := 90 * 30
const ENTRY_FRAMES := 2
const TICKS := 90.0
const SEEDS := 50
const CENTER := Vector3(3.0, 0.0, -2.0)
const BALL := Vector3(9.0, 0.0, 4.0)

var _t := T.new("mind_plate_reach_test")
var _game
var _telegraphs: Array = []


func _initialize() -> void:
	# These tests pin mechanics with a smash-per-frame TARGET hit, not the fight's length: the PHASE_MIN_SECONDS
	# hold (waking.gd, mind.gd; tests/boss_phase_hold_test.gd) is multiplied out.
	ChallengeDials.set_overrides({"waking.phase_min_by_phase": [0.0, 0.0, 0.0, 0.0], "mind.phase_min_by_phase": [0.0, 0.0, 0.0, 0.0]})
	_rules()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await _fight()
	_game.free()
	quit(_t.verdict())


func _rules() -> void:
	var cap := MindAttacks.phase_cap()
	_t.check("phase_cap is one phase per family and per posture chunk", cap == MindAttacks.FAMILIES.size() and cap == BossPosture.CHUNKS,
			"cap %d, families %d, chunks %d" % [cap, MindAttacks.FAMILIES.size(), BossPosture.CHUNKS])
	_t.check("only the last phase exposes the plate", MindAttacks.exposed(cap).has("plate") and not MindAttacks.exposed(3).has("plate"),
			"exposed(cap) %s, exposed(3) %s" % [MindAttacks.exposed(cap), MindAttacks.exposed(3)])
	var bad: Array = []
	for family in MindAttacks.FAMILIES:
		for s in SEEDS:
			var four: Array = MindAttacks.commit(family, s, BALL, CENTER, 4)
			var three: Array = MindAttacks.commit(family, s, BALL, CENTER, 3)
			for i in four.size():
				var w := float(four[i]["warn"])
				if w < MindAttacks.WARN_FLOOR or i >= three.size() or not is_equal_approx(w, float(three[i]["warn"])):
					bad.append("%s seed %d: %.2f" % [family, s, w])
	_t.check("every phase 4 warn is at least WARN_FLOOR and equals phase 3's", bad.is_empty(), "%s" % [bad.slice(0, 5)])


func _fight() -> void:
	var game = _game
	var seen = Harness.counter(game)
	Harness.boot(game)
	Harness.enter_world(game, 3)
	var mod = Harness.module(game, 3)
	var path: String = mod.get_script().resource_path if mod != null else "none"
	if not _t.check("world 3 module is mind.gd", path.ends_with("mind.gd"), "module %s" % path):
		return
	var defeated_before: int = seen.defeated
	game.ctx.events.boss_attack_telegraphed.connect(func(id: String, _warn: float):
		_telegraphs.append({"id": id, "frame": Engine.get_physics_frames(), "phase": mod.phase, "count": mod.attack_count}))
	for _i in IDLE_FRAMES:
		await physics_frame

	var frames := 0
	var phase4_frame := -1
	while is_instance_valid(mod.warden) and mod.warden.chunks_left() > 1 and frames < CHUNK_CAP:
		Harness.hit(mod)
		frames += 1
		await physics_frame
		if phase4_frame < 0 and mod.phase == 4:
			phase4_frame = Engine.get_physics_frames()
	for _i in ENTRY_FRAMES + 1:
		if phase4_frame < 0 and mod.phase == 4:
			phase4_frame = Engine.get_physics_frames()
		await physics_frame
	_t.check("mind.phase reached 4", mod.phase == 4, "phase %d, chunks_left %d after %d frame(s)" % [mod.phase,
			mod.warden.chunks_left() if is_instance_valid(mod.warden) else -1, frames])
	var first4 := -1
	for i in _telegraphs.size():
		if int(_telegraphs[i]["phase"]) == 4:
			first4 = i
			break
	var early: Array = _telegraphs.filter(func(t): return int(t["phase"]) < 4 and String(t["id"]).begins_with("mind_plate_"))
	_t.check("no mind_plate telegraph before phase 4", early.is_empty(), "%s" % [early])
	var opener: Dictionary = _telegraphs[first4] if first4 >= 0 else {}
	_t.check("the first telegraph of phase 4 is mind_plate_0 within %d frames of entry" % ENTRY_FRAMES,
			not opener.is_empty() and opener["id"] == "mind_plate_0" and absi(int(opener["frame"]) - phase4_frame) <= ENTRY_FRAMES,
			"first %s, phase 4 seen at frame %d" % [opener, phase4_frame])
	_t.check("the plate braces a contact verb", mod._plate_verb in Rules.CONTACT_KINDS, "verb '%s'" % mod._plate_verb)
	var text: String = mod.objective_text()
	_t.check("the objective names the plate", text.contains("plate"), "'%s'" % text)

	frames = 0
	while is_instance_valid(mod.warden) and not mod.warden.staggered() and frames < STAGGER_CAP:
		Harness.hit(mod)
		frames += 1
		await physics_frame
	var staggered: bool = is_instance_valid(mod.warden) and mod.warden.staggered()
	_t.check("the Warden staggered inside the plate's weak window", staggered and mod.clock <= mod._plate_until,
			"staggered %s, clock %.2f, plate_until %.2f, %d frame(s)" % [staggered, mod.clock, mod._plate_until, frames])
	var verb: String = mod._plate_verb
	var other: String = "ram" if verb != "ram" else "stomp"
	game.ctx.events.enemy_struck.emit(mod.warden, other, 1.0)
	_t.check("a %s under a %s plate fires mind_plate" % [other, verb], CodexEntries.MIND_PLATE in game.ctx.codex.discovered_this_run(),
			"verb %s" % verb)

	# Let the next ATTACK_PERIOD run out before the kill, so the commit after the opener
	# is seen.
	for _i in int(mod.ATTACK_PERIOD * TICKS) + 10:
		await physics_frame
	frames = 0
	while Harness._alive(Harness.target(mod)) and frames < KILL_CAP:
		Harness.hit(mod)
		frames += 1
		await physics_frame
	_t.check("the Mind was defeated", seen.defeated > defeated_before and not Harness._alive(Harness.target(mod)),
			"%d frame(s), defeated %d" % [frames, seen.defeated - defeated_before])
	_opener_once(mod, first4)


# The opener is one plate commit; the next commit, if any, comes a full ATTACK_PERIOD later.
func _opener_once(mod, first4: int) -> void:
	if first4 < 0:
		_t.check("the plate opener was committed", false, "no phase 4 telegraph")
		return
	var opener: Dictionary = _telegraphs[first4]
	var period := int(mod.ATTACK_PERIOD * TICKS) - 2
	var plates := 0
	var next = null
	for t in _telegraphs.slice(first4):
		if int(t["count"]) == int(opener["count"]):
			continue
		if next == null:
			next = t
		if String(t["id"]).begins_with("mind_plate_") and int(t["frame"]) - int(opener["frame"]) < period:
			plates += 1
	_t.check("exactly one plate commit before the next ATTACK_PERIOD", plates == 0, "%d extra plate(s)" % plates)
	_t.check("the next telegraph after the plate waits a full ATTACK_PERIOD",
			next != null and int(next["frame"]) - int(opener["frame"]) >= period,
			"opener frame %d, next %s" % [int(opener["frame"]), next])
