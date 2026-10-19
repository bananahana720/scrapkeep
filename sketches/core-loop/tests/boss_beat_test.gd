# smoke: solo (the gated beat on the real Waking and Mind)
extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const T := preload("res://tests/support/t.gd")

# Challenge dial <boss>.beat_by_phase (src/core/challenge_dials.gd): a short gated beat right after a
# shatter, in which the Warden takes no posture, crack, shatter or health loss from any path. Covers
# validation, defaults off, and a 4 s beat after each of shatters 1 to 3 on the Waking and the Mind: a
# TARGET smash (Harness.hit), Combat.strike rams (each one deflects), the ultimate's posture call, the
# real cannon set-piece hit, the rivet line punch and a wear-trail style take_damage all bounce; the beat
# holds to its last frame and ends within two; boss_beat (never boss_attack_telegraphed) cues it; the
# final shatter arms none; the Mind's brace plate warns at least GAP after the cue.
#
# Evidence limit: hits are TARGET and Combat calls, not ball contacts; the ultimate path calls
# ultimate.warden_posture directly (what Combat.strike does while the set piece rides); the visual
# shell is checked as a node, not as pixels, and the sound as the boss_beat event (audio_event_latency_test
# and the contract tests own the cue row).

const TICKS := 90
const BEAT := 4.0

var _t := T.new("boss_beat_test")
var _telegraphs: Array = []
var _beats: Array = []


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _run() -> void:
	_rules()
	for boss in [["waking", 2], ["mind", 3]]:
		await _fight(boss[0], boss[1], false)
		await _fight(boss[0], boss[1], true)
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


func _boot(boss: String, world: int, on: bool):
	ChallengeDials.reset()
	if on:
		ChallengeDials.set_overrides({"%s.beat_by_phase" % boss: [BEAT, BEAT, BEAT, BEAT]})
	var game = Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.flow.victory_lap = false
	_telegraphs = []
	_beats = []
	game.ctx.events.boss_attack_telegraphed.connect(func(id: String, seconds: float):
		_telegraphs.append({"id": id, "seconds": seconds, "frame": Engine.get_physics_frames()}))
	game.ctx.events.boss_beat.connect(func(id: String, seconds: float):
		_beats.append({"id": id, "seconds": seconds, "frame": Engine.get_physics_frames()}))
	Harness.boot(game)
	Harness.enter_world(game, world)
	return game


# Hits until the chunk count falls to `want`; the first hit staggers, the next shatters.
func _shatter_to(mod, warden, want: int) -> void:
	var guard := 0
	while is_instance_valid(warden) and warden.chunks_left() > want and guard < 30:
		Harness.hit(mod)
		guard += 1
		await physics_frame


func _fight(boss: String, world: int, on: bool) -> void:
	var label := "%s %s" % [boss, "beat" if on else "default"]
	var game = await _boot(boss, world, on)
	var mod = Harness.module(game, world)
	var warden = Harness.target(mod)
	if not _t.check(label + ": the module and Warden are seated", mod != null and warden != null and mod.has_method("objective_text")):
		game.free()
		return
	_t.check(label + ": no beat before a shatter", not warden.beat_immune())
	if not on:
		await _shatter_to(mod, warden, 3)
		await _frames(40)
		_t.check(label + ": no immunity", not warden.beat_immune())
		_t.eq(label + ": no boss_beat", _beats.size(), 0)
		_t.eq(label + ": no beat in the telegraph event", _telegraphs.filter(func(e): return String(e["id"]).ends_with("_beat")).size(), 0)
		_t.check(label + ": no shell", warden.get_node_or_null("BeatShell") == null)
		_t.eq(label + ": objective has no bracing line", mod.objective_text().contains("bracing"), false)
		_t.eq(label + ": music is not held", bool(mod.music_state().get("held", true)), false)
		await _shatter_to(mod, warden, 2)
		_t.eq(label + ": the next shatter works at once", warden.chunks_left(), 2)
		game.free()
		return

	# Past the intro, so the boss is committing attacks while the beats run.
	while mod.clock < 4.0:
		await physics_frame
	var combat = game.ctx.spawner
	var deflects := [0]
	game.ctx.events.strike_deflected.connect(func(_e, _k, _p, _pl): deflects[0] += 1)
	for shatter in [1, 2, 3]:
		var tag := "%s: shatter %d" % [label, shatter]
		var hp_before: float = warden.hp
		await _shatter_to(mod, warden, 4 - shatter)
		if not _t.eq(tag + " landed", warden.chunks_left(), 4 - shatter):
			break
		var started := Engine.get_physics_frames()
		var hp: float = warden.hp
		_t.check(tag + " cost health", hp < hp_before)
		_t.check(tag + " opens a beat", warden.beat_immune())
		_t.check(tag + " a visible shell stands", is_instance_valid(warden.get_node_or_null("BeatShell")))
		# The cue: boss_beat for this boss, with the time left, never the attack-telegraph event.
		await _frames(40)
		_t.eq(tag + " boss_beat count", _beats.size(), shatter)
		if _beats.size() == shatter:
			var cue: Dictionary = _beats[-1]
			_t.eq(tag + " cue names the boss", cue["id"], boss)
			_t.check(tag + " cue carries the time left", float(cue["seconds"]) > BEAT - 0.5 and float(cue["seconds"]) <= BEAT,
					"%.2f" % float(cue["seconds"]))
		# No attack warning starts within GAP after the cue (a one-frame tolerance).
		if _beats.size() == shatter:
			var cue_frame: int = _beats[-1]["frame"]
			var after := _telegraphs.filter(func(e): return int(e["frame"]) >= cue_frame)
			var gap_ok := true
			for e in after:
				gap_ok = gap_ok and int(e["frame"]) - cue_frame >= roundi(ChallengeDials.WARN_GAP * TICKS) - 1
			_t.check(tag + " no attack warning within GAP of the cue", gap_ok, str(after.map(func(e): return int(e["frame"]) - cue_frame)))
		_t.eq(tag + " nothing beat-named on the telegraph event", _telegraphs.filter(func(e): return String(e["id"]).ends_with("_beat")).size(), 0)
		_t.check(tag + " objective says bracing", mod.objective_text().contains("bracing"), mod.objective_text())
		_t.eq(tag + " music is held", bool(mod.music_state().get("held", false)), true)

		# Every path bounces; every Combat.strike deflects.
		var kit = combat.get_node_or_null("RivetKit")
		for round in 3:
			var d0: int = deflects[0]
			Harness.hit(mod)
			combat.strike(warden, "ram", 9999.0)
			combat.strike(warden, "slam", 9999.0)
			_t.eq(tag + " round %d: both strikes deflected" % round, deflects[0] - d0, 2)
			warden._apply_posture(warden.judge_hit("slam", 9999.0, true, 3))
			combat._cannon_set_piece_hit(warden, 500.0, warden.global_position, true, false, {})
			combat._cannon_set_piece_hit(warden, 500.0, warden.global_position, false, false, {})
			if combat.ultimate != null:
				combat.ultimate.warden_posture(warden, warden.judge_hit("slam", 9999.0, true, 3))
			if kit != null:
				kit._punch(warden, 40.0, 1.0, Vector3.FORWARD)
			await physics_frame
		_t.check(tag + " the rivet kit was reachable", kit != null)
		_t.eq(tag + " take_damage (wear trail, rubble) removes nothing", warden.take_damage(500.0), 0.0)
		_t.eq(tag + " no chunk fell", warden.chunks_left(), 4 - shatter)
		_t.eq(tag + " health unchanged", warden.hp, hp)
		_t.near(tag + " posture unmoved", warden.posture(), 0.0)
		_t.check(tag + " no stagger and no stagger clock", not warden.staggered() and warden.stagger_left() == 0.0)
		_t.check(tag + " no crack", not warden.chunk_cracked())

		# Immune to the last frames, then free within two frames of the end.
		var held := true
		var frames := 0
		while warden.beat_immune() and frames < (BEAT + 1.0) * TICKS:
			if warden.beat_left > 0.2:
				held = held and warden.judge_hit("slam", 9999.0, true, 3)["gain"] == 0.0
			await physics_frame
			frames += 1
		var total := Engine.get_physics_frames() - started
		_t.check(tag + " immune to its last stretch", held)
		_t.check(tag + " lasted %d frames of %d" % [total, int(BEAT * TICKS)], absi(total - int(BEAT * TICKS)) <= 3)
		_t.check(tag + " the shell is gone", warden.get_node_or_null("BeatShell") == null)
		_t.eq(tag + " objective no longer says bracing", mod.objective_text().contains("bracing"), false)
		_t.check(tag + " gain works the frame it ends", warden.judge_hit("slam", 9999.0, true, 3)["gain"] > 0.0)

	# The Mind's brace plate commits right after shatter 3 (held for the gap, then warned).
	if boss == "mind":
		_t.check(label + ": the brace plate warned after the beats", _telegraphs.any(func(e): return String(e["id"]).begins_with("mind_plate")),
				str(_telegraphs.map(func(e): return e["id"])))
	await _shatter_to(mod, warden, 0)
	await _frames(5)
	_t.eq(label + ": the final shatter arms no beat", _beats.size(), 3)
	_t.check(label + ": and no immunity", not is_instance_valid(warden) or not warden.beat_immune())
	game.free()
