# smoke: solo (the gated beat on the real Waking and Mind)
extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const T := preload("res://tests/support/t.gd")

# Challenge dial <boss>.beat_by_phase (src/core/challenge_dials.gd): a short gated beat right after a
# shatter, in which the Warden takes no posture, crack, shatter or health loss from any path. Covers
# validation, defaults off, and a 4 s beat after shatter 1 on the Waking and the Mind: a TARGET smash
# (Harness.hit), a Combat.strike ram, the ultimate's posture call, and a cannon-style judge + apply all
# bounce; the telegraph names the beat's length; the beat ends and damage works again.
#
# Evidence limit: hits are TARGET and Combat calls, not ball contacts; the ultimate path calls
# ultimate.warden_posture directly (what Combat.strike does while the set piece rides); the visual
# shell is checked as a node, not as pixels, and the sound as the boss_attack_telegraphed event.

const TICKS := 90
const BEAT := 4.0

var _t := T.new("boss_beat_test")
var _telegraphs: Array = []


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _run() -> void:
	_rules()
	await _fight("waking", 2, false)
	await _fight("mind", 3, false)
	await _fight("waking", 2, true)
	await _fight("mind", 3, true)
	ChallengeDials.reset()
	quit(_t.verdict())


func _rules() -> void:
	ChallengeDials.reset()
	_t.eq("default beat list", ChallengeDials.value("waking.beat_by_phase"), [0.0, 0.0, 0.0, 0.0])
	_t.eq("default beat is off", ChallengeDials.beat("mind", 1), 0.0)
	_t.eq("describe is empty at defaults", ChallengeDials.describe(), {})
	var parsed := ChallengeDials.parse("waking.beat_by_phase=0/4/4/0,mind.beat_by_phase=3/5/3.5/0")
	_t.eq("parse a sweep", parsed["waking.beat_by_phase"], [0.0, 4.0, 4.0, 0.0])
	_t.eq("parse the Mind's", parsed["mind.beat_by_phase"], [3.0, 5.0, 3.5, 0.0])
	ChallengeDials.quiet = true
	for bad in ["0/2/0/0", "0/6/0/0", "4", "0/4/4", "0/4/4/0/0", "-1/0/0/0"]:
		var before := ChallengeDials.rejected.size()
		_t.eq("--tune refuses '%s'" % bad, ChallengeDials.parse("waking.beat_by_phase=" + bad).size(), 0)
		_t.eq("'%s' is recorded as rejected" % bad, ChallengeDials.rejected.size(), before + 1)
	for bad in [[0.0, 2.0, 0.0, 0.0], [0.0, 6.0, 0.0, 0.0], 4.0, "4", [4.0]]:
		ChallengeDials.set_overrides({"mind.beat_by_phase": bad})
		_t.eq("override %s refused, default kept" % str(bad), ChallengeDials.value("mind.beat_by_phase"), [0.0, 0.0, 0.0, 0.0])
	_t.eq("a dial for another boss does not exist", ChallengeDials.parse("brindle.beat_by_phase=0/4/4/0").size(), 0)
	ChallengeDials.set_overrides({"waking.beat_by_phase": [0.0, 4.0, 4.0, 0.0]})
	_t.eq("a good override is kept", ChallengeDials.beat("waking", 2), 4.0)
	_t.eq("an entry past the list reads 0", ChallengeDials.beat("waking", 5), 0.0)
	ChallengeDials.reset()


func _fight(boss: String, world: int, on: bool) -> void:
	var label := "%s %s" % [boss, "beat" if on else "default"]
	ChallengeDials.reset()
	if on:
		ChallengeDials.set_overrides({"%s.beat_by_phase" % boss: [BEAT, 0.0, 0.0, 0.0]})
	var game = Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.flow.victory_lap = false
	_telegraphs = []
	game.ctx.events.boss_attack_telegraphed.connect(func(id: String, seconds: float):
		_telegraphs.append({"id": id, "seconds": seconds}))
	Harness.boot(game)
	Harness.enter_world(game, world)
	var mod = Harness.module(game, world)
	var warden = Harness.target(mod)
	if not _t.check(label + ": the module and Warden are seated", mod != null and warden != null and mod.has_method("objective_text")):
		game.free()
		return
	_t.check(label + ": no beat before a shatter", not warden.beat_immune())
	var hp0: float = warden.hp
	# Hit until the first shatter: a TARGET smash staggers, the next one shatters.
	var guard := 0
	while warden.chunks_left() == 4 and guard < 20:
		Harness.hit(mod)
		guard += 1
		await physics_frame
	_t.eq(label + ": first shatter landed", warden.chunks_left(), 3)
	var hp1: float = warden.hp
	_t.check(label + ": the shatter cost health", hp1 < hp0, "%.1f -> %.1f" % [hp0, hp1])
	# The Waking holds the announcement for a free warning slot (the floor drop warns first).
	await _frames(40)
	var beats := _telegraphs.filter(func(e): return String(e["id"]).ends_with("_beat"))
	if not on:
		_t.check(label + ": no immunity", not warden.beat_immune())
		_t.eq(label + ": no beat event", beats.size(), 0)
		_t.check(label + ": no shell", warden.get_node_or_null("BeatShell") == null)
		_t.eq(label + ": objective has no bracing line", mod.objective_text().contains("bracing"), false)
		_t.eq(label + ": music is not held", bool(mod.music_state().get("held", true)), false)
		var guard2 := 0
		while warden.chunks_left() == 3 and guard2 < 20:
			Harness.hit(mod)
			guard2 += 1
			await physics_frame
		_t.eq(label + ": the next shatter works at once", warden.chunks_left(), 2)
		game.free()
		return

	_t.check(label + ": immune after shatter 1", warden.beat_immune())
	_t.eq(label + ": one beat event named for the boss", beats.size(), 1)
	if beats.size() == 1:
		_t.eq(label + ": event id", beats[0]["id"], boss + "_beat")
		_t.near(label + ": event carries the beat length", float(beats[0]["seconds"]), BEAT)
	_t.check(label + ": a visible shell stands", is_instance_valid(warden.get_node_or_null("BeatShell")))
	_t.check(label + ": the objective says bracing", mod.objective_text().contains("bracing"), mod.objective_text())
	_t.eq(label + ": music is held", bool(mod.music_state().get("held", false)), true)

	var deflects := [0]
	game.ctx.events.strike_deflected.connect(func(_e, _k, _p, _pl): deflects[0] += 1)
	var combat = game.ctx.spawner
	for round in 3:
		Harness.hit(mod)
		combat.strike(warden, "ram", 9999.0)
		var judged: Dictionary = warden.judge_hit("slam", 9999.0, true, 3)
		warden._apply_posture(judged)
		if combat.ultimate != null:
			combat.ultimate.warden_posture(warden, warden.judge_hit("slam", 9999.0, true, 3))
		await physics_frame
	_t.check(label + ": a ram, a smash, the ultimate and a cannon hit all bounced", deflects[0] >= 1, "deflects %d" % deflects[0])
	_t.check(label + ": the judge reads no gain, crack or shatter", float(warden.judge_hit("slam", 9999.0, true, 3)["gain"]) == 0.0
			and not bool(warden.judge_hit("slam", 9999.0, true, 3)["shatter"]))
	_t.eq(label + ": no chunk fell", warden.chunks_left(), 3)
	_t.eq(label + ": health unchanged", warden.hp, hp1)
	_t.near(label + ": posture unmoved", warden.posture(), 0.0)
	_t.check(label + ": no stagger opened and no stagger clock", not warden.staggered() and warden.stagger_left() == 0.0)
	_t.check(label + ": no crack", not warden.chunk_cracked())

	# The beat runs its length, then ends visibly and damage works again.
	await _frames(int(BEAT * TICKS) - 40 - 6 + 10)
	_t.check(label + ": the beat ended", not warden.beat_immune())
	await _frames(2)
	_t.check(label + ": the shell is gone", warden.get_node_or_null("BeatShell") == null)
	_t.eq(label + ": no second beat event", _telegraphs.filter(func(e): return String(e["id"]).ends_with("_beat")).size(), 1)
	_t.eq(label + ": objective no longer says bracing", mod.objective_text().contains("bracing"), false)
	var guard3 := 0
	while warden.chunks_left() == 3 and guard3 < 20:
		Harness.hit(mod)
		guard3 += 1
		await physics_frame
	_t.eq(label + ": shatter 2 works after the beat", warden.chunks_left(), 2)
	_t.check(label + ": health fell again", warden.hp < hp1)
	_t.check(label + ": no beat after shatter 2 (its entry is 0)", not warden.beat_immune())
	game.free()
