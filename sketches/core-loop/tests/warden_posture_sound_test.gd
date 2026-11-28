extends SceneTree

const Game := preload("res://src/game.gd")
const BossPosture := preload("res://src/core/boss_posture.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Intent := preload("res://src/movement/intent.gd")
const Rows := preload("res://src/presentation/rows.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")
const T := preload("res://tests/support/t.gd")

# A posture Warden is heard (LEGIBILITY section 4), on the slice table and driven through
# combat.strike(); the cue log, not speakers:
#   B3-3  four hits that cross the guard's marks play four rising pitches, the phrase's
#         notes in the live key; the stagger plays the chord once; a shatter plays its sound
#         and the low hit once each; two seconds of drain play nothing; a charge cue playing
#         when the stagger begins is stopped on that tick, and another enemy's charge cue is not. A glance keeps its clank.

const SliceDefs := preload("res://src/core/slice_defs.gd")
const PLATING: float = SliceDefs.DEFS[0]["warden_plating"]
const CURVE: float = SliceDefs.DEFS[0]["posture"]["curve"]
const FIGHT_SOUNDS := ["hit_thwack", "boss_weak_hit", "shatter", "chunk_low", "clank"]

var _t := T.new("warden_posture_sound_test")
# F6 2026-10-04: the plating Warden case is gone; every hit sound here is posture.

var _game
var _audio
var _combat
var _player
var _warden
var _source := Intent.Scripted.new()


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _seconds(seconds: float) -> void:
	await _frames(roundi(seconds * Engine.physics_ticks_per_second))


func _ground(out: float) -> Vector3:
	return _game.ctx.terrain.drop_point(_warden.global_position.x + out, _warden.global_position.z, 1.5)


func _force_for(share: float) -> float:
	var force := 1.0
	while _combat.punch_of("ram", force) < PLATING * pow(share, 1.0 / CURVE):
		force += 0.02
	return force


func _fast_force() -> float:
	var force := _force_for(1.0)
	var cruise: float = _player.tuning.f("cruise")
	while SpeedTier.of(force, cruise) < 2:
		force += 0.5
	return force


# A strike with the cue gaps cleared, so the wall-clock gap never decides what plays.
func _hit(kind: String, force: float) -> void:
	_audio._last_start.clear()
	_combat.strike(_warden, kind, force)
	await physics_frame


func _key() -> float:
	return Harmony.ratio(_audio.live_key())


func _entries(sound: String, status := "now") -> Array:
	return _audio.cue_log.filter(func(entry): return entry[1] == sound and entry[2] == status)


func _pitches(sound: String) -> Array:
	return _entries(sound).map(func(entry): return entry[4])


func _fight_cues() -> Array:
	return _audio.cue_log.filter(func(entry): return entry[2] == "now" and (entry[1] in FIGHT_SOUNDS or String(entry[1]).begins_with("cause_note_")))


func _start() -> bool:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_player = _game.player
	_player.source = _source
	_combat = _game.ctx.spawner
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _seconds(0.4)
	_audio = _game.presentation.audio
	_audio.bake_now()
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0
	_warden = _game.flow.warden
	if not is_instance_valid(_warden):
		return false
	for enemy in get_nodes_in_group("enemy"):
		if enemy != _warden and enemy.get("kind") != "vault":
			enemy.queue_free()
	return true


func _run() -> void:
	if not await _start():
		print("warden_posture_sound_test: FAIL (no Warden on the slice table)")
		quit(1)
		return
	_player.reset_to(_ground(58.0))
	await _seconds(0.3)
	await _climb()
	await _glance()
	await _drain()
	await _stagger()
	await _shatter()
	await _foreign_charge()
	await _foreign_eruption()
	_game.free()
	quit(_t.verdict())


# Hits at guard 0, 30, 55 and 80 cross the marks at 25, 50 and 75.
func _climb() -> void:
	_audio.cue_log.clear()
	var guards: Array = []
	for share in [1.0, 5.0 / 6.0, 5.0 / 6.0]:
		guards.append(_warden.posture())
		await _hit("ram", _force_for(share))
	guards.append(_warden.posture())
	var midis := SfxBank.break_midis(0)
	var want: Array = midis.map(func(midi): return Harmony.ratio(midi - Harmony.HOME) * _key())
	await _hit("runner", 5.0)
	var heard := _pitches("hit_thwack").slice(0, 4)
	_t.eq("four hits were heard", heard.size(), 4)
	_t.check("they crossed the three marks", guards[0] < 25.0 and guards[1] >= 25.0 and guards[1] < 50.0 and guards[2] >= 50.0 and guards[2] < 75.0 and guards[3] >= 75.0,
		"guards %s" % [guards.map(func(g): return snappedf(g, 0.1))])
	var rising := heard.size() == 4
	for i in range(1, heard.size()):
		rising = rising and heard[i] > heard[i - 1]
	_t.check("four different pitches in rising order", rising, "pitches %s" % [heard.map(func(p): return snappedf(p, 0.001))])
	var exact := heard.size() == 4
	for i in heard.size():
		exact = exact and is_equal_approx(heard[i], want[i])
	_t.check("they are the phrase's notes in the live key", exact, "heard %s, want %s" % [heard.map(func(p): return snappedf(p, 0.001)), want.map(func(p): return snappedf(p, 0.001))])
	_t.check("the phrase climbs in the live key through Harmony", midis[0] == Harmony.note_midi("D4") and midis[3] > midis[0])


func _glance() -> void:
	_audio.cue_log.clear()
	_audio._last_start.clear()
	_combat.strike(_warden, "runner", 5.0)
	var clanks := _pitches("clank")
	# The base formula at full integrity (ladder rung 0), not the ladder the code computes.
	_t.check("the Warden is at full integrity", is_equal_approx(float(_game.ctx.spawner.integrity_of(_warden)), 1.0))
	var want: float = Harmony.ratio(lerpf(-7.0, 0.0, 5.0 / PLATING)) * Harmony.ratio(Harmony.pentatonic_step(0)) * _key()
	_t.check("a glance keeps today's clank", clanks.size() == 1 and is_equal_approx(clanks[0], want), "clanks %s, want %.3f" % [clanks, want])


# The guard drains for two seconds and nothing sounds.
func _drain() -> void:
	await _seconds(BossPosture.DRAIN_DELAY + 0.3)
	var before: float = _warden.posture()
	_audio.cue_log.clear()
	await _seconds(2.0)
	_t.check("the guard drained", _warden.posture() < before, "posture %.1f to %.1f" % [before, _warden.posture()])
	_t.eq("two seconds of drain play nothing", _fight_cues().size(), 0)


# A charge cue playing when the stagger begins is stopped on that tick.
func _stagger() -> void:
	_player.reset_to(_ground(58.0))
	await _seconds(0.5)
	_audio.cue_log.clear()
	var guard := 0
	while _warden.posture() < 60.0 and guard < 10:
		await _hit("ram", _force_for(1.0))
		guard += 1
	_audio.cue_log.clear()
	var charge := String(Rows.sound("vent_charging", _audio.cue_context()))
	_game.events.vent_charging.emit(_warden.global_position, 2.0)
	_t.eq("the charge cue plays", _entries(charge).size(), 1)
	var before_stop := _entries(charge, "stop").size()
	_audio._last_start.clear()
	while not _warden.staggered() and guard < 20:
		await _hit("ram", _force_for(1.0))
		guard += 1
	_t.check("it staggered", _warden.staggered())
	_t.eq("the charge cue was stopped as the stagger began", _entries(charge, "stop").size() - before_stop, 1)
	var chord := SfxBank.break_midis(0).map(func(midi): return SfxBank.cause_note_id(midi))
	var once := true
	for id in chord:
		once = once and _entries(id).size() == 1
	_t.check("the stagger plays the chord once", once, "notes %s" % [chord.map(func(id): return _entries(id).size())])
	_t.eq("with the open row's sound once", _entries(String(EventKinds.state_row("open")["sound"])).size(), 1)
	_t.eq("and no shatter yet", _entries("shatter").size() + _entries("chunk_low").size(), 0)
	await _seconds(0.3)
	_t.eq("the chord does not repeat while it stands open", _entries(String(EventKinds.state_row("open")["sound"])).size(), 1)


# A fast ram into the open core shatters the chunk: its row's sound over the low hit, once each.
func _shatter() -> void:
	_audio.cue_log.clear()
	_audio._last_start.clear()
	# The slice row's rams do not shatter; this check is about the shatter's sound, so the rule
	# on this Warden is told they do, as the default rule has it.
	_warden._posture.ram_shatters = true
	_combat.strike(_warden, "ram", _fast_force())
	await _frames(2)
	_t.eq("a chunk was lost", _warden.chunks_left(), 3)
	var row := String(EventKinds.state_row("chunk_shatter")["sound"])
	_t.eq("a shatter plays its row's sound once", _entries(row).size(), 1)
	_t.eq("and the low hit once", _entries("chunk_low").size(), 1)
	_t.check("the low hit is baked in the bank", SfxBank.has_recipe("chunk_low"))
	await _seconds(0.5)
	_t.eq("nothing repeats", _entries(row).size() + _entries("chunk_low").size(), 2)


# Another enemy's charge cue survives a Warden stagger: only a charge the Warden owns is cut.
func _foreign_charge() -> void:
	await _seconds(BossPosture.STAGGER_SECONDS + 0.5)
	_player.reset_to(_ground(58.0))
	await _seconds(0.5)
	_t.check("the Warden closed again", not _warden.staggered())
	_audio.cue_log.clear()
	var charge := String(Rows.sound("vent_charging", _audio.cue_context()))
	_game.events.vent_charging.emit(_warden.global_position + Vector3(40.0, 0.0, 0.0), 2.0)
	_t.eq("the other charge cue plays", _entries(charge).size(), 1)
	var guard := 0
	while not _warden.staggered() and guard < 20:
		await _hit("ram", _force_for(1.0))
		guard += 1
	_t.check("it staggered again", _warden.staggered())
	_t.eq("the other enemy's charge cue was not stopped", _entries(charge, "stop").size(), 0)


# Another enemy's eruption does not end the Warden's own charge: the next stagger still cuts it.
func _foreign_eruption() -> void:
	await _seconds(BossPosture.STAGGER_SECONDS + 0.5)
	_player.reset_to(_ground(58.0))
	await _seconds(0.5)
	_t.check("the Warden closed a second time", not _warden.staggered())
	_audio.cue_log.clear()
	var charge := String(Rows.sound("vent_charging", _audio.cue_context()))
	_game.events.vent_charging.emit(_warden.global_position, 2.0)
	_game.events.vent_erupted.emit(_warden.global_position + Vector3(40.0, 0.0, 0.0))
	var guard := 0
	while not _warden.staggered() and guard < 20:
		await _hit("ram", _force_for(1.0))
		guard += 1
	_t.check("it staggered a third time", _warden.staggered())
	_t.check("the Warden's own charge cue was stopped", _entries(charge, "stop").size() >= 1, "%d stops" % _entries(charge, "stop").size())
