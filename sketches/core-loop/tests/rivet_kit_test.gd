extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Enemy := preload("res://src/combat/enemy.gd")
const Kit := preload("res://src/combat/rivet_kit.gd")
const TerrainFaces := preload("res://src/combat/terrain_faces.gd")
const T := preload("res://tests/support/t.gd")
const Bank := preload("res://src/presentation/sfx_bank.gd")
const AudioRows := preload("res://src/presentation/rows.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# PC-RIVET, 2026-10-11 (design-v3/pilots/rivet.md sections 2.3, 9 and 10). Expected: 54 checks,
# 2026-10-12 (PC-RIVET round 3): arrival preview, early cues, shared guard feedback and cue gain/key.
# 2026-10-12 (PC-RIVET r4): 45 -> 50, inspect actual PCM cue offsets and duration at key 3.
# 2026-10-12 (coordinator, KE9 r1 gate): 50 -> 51, a freed target drops its pulse without an error.
# including the count assertion, so an empty or short run fails. Real game and router, scripted
# calm shelf with no AI attacks; the kit is stepped by hand so every number is read on its tick.
const DT := 1.0 / 60.0
const SHELF := Vector3(-45.0, 122.0, 6.0)
class TimingAudio:
	extends "res://src/presentation/audio.gd"
	var played: Array = []

	func _start(kind: String, sound: String, stream: AudioStream, volume: float, pitch: float, bus: String) -> void:
		played.append({"stream": stream, "pitch": pitch})
		super._start(kind, sound, stream, volume, pitch, bus)


# Read the first nonzero PCM sample after an instrument's silent gap. Convert the
# sample position through the pitch actually passed to playback, into physical seconds.
func _sound_time(played: Dictionary, after_seconds: float) -> float:
	var wav: AudioStreamWAV = played["stream"]
	for i in range(int(after_seconds * wav.mix_rate), wav.data.size() / 2):
		if wav.data.decode_s16(i * 2) != 0:
			return float(i) / (wav.mix_rate * float(played["pitch"]))
	return -1.0


func _cue_timing() -> void:
	var audio := TimingAudio.new()
	audio.ctx = _game.ctx
	audio.engine = _game.presentation.audio.engine
	audio.engine.key = 3
	audio.sound_ready = true
	var pitch := Harmony.ratio(audio.live_key())
	_kit.last_cue = {"on": "body", "delay": 0.6}
	audio._on_rivet_line_drive("line_drive", null, Vector3.ZERO, "body")
	var punch: Dictionary = audio.played.back()
	_t.near("the snare starts at the recorded delay in the live key", _sound_time(punch, 0.5), float(_kit.last_cue["delay"]), 0.002)
	var punch_wav: AudioStreamWAV = punch["stream"]
	_t.near("the punch buffer keeps its physical duration", float(punch_wav.data.size()) / (2.0 * punch_wav.mix_rate * pitch), 0.9, 0.0001)
	_kit.last_cue = {"on": "world", "seconds": 1.0}
	audio._on_rivet_line_drive("line_drive", null, Vector3.ZERO, "world")
	var arrive: Dictionary = audio.played.back()
	_t.near("the hat roll interval survives the live key", _sound_time(arrive, 0.055), float(audio.RIVET_LINE["roll_step"]), 0.002)
	var last_hat_end: float = (float(_kit.last_cue["seconds"]) - float(audio.RIVET_LINE["roll_step"])) * pitch + 0.05
	_t.near("the final clav starts at the recorded arrival in the live key", _sound_time(arrive, last_hat_end), float(_kit.last_cue["seconds"]), 0.002)
	var arrive_wav: AudioStreamWAV = arrive["stream"]
	_t.near("the arrival buffer keeps its physical duration", float(arrive_wav.data.size()) / (2.0 * arrive_wav.mix_rate * pitch), float(_kit.last_cue["seconds"]) + 0.5, 0.0001)
	audio.free()


var _t := T.new("rivet_kit_test")
var _expected_checks := 58
var _game
var _player
var _combat
var _kit
var _source := Intent.Scripted.new()
var _struck: Array = []
var _fired: Array = []
var _pinned: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _boot() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	var def: Resource = ClassDef.by_id("runner_gunner")
	_game.run.class_def = def
	_player.fit_class(def)
	await _sim(0.6)
	_kit = _combat.get_node("RivetKit")
	# Full Cut lands on its peak tick here, as before the worker carve; rivet_full_cut_late_test
	# checks the late landing.
	_kit.cut_ticks = 0
	_player.set_physics_process(false)
	_combat.set_physics_process(false)
	_kit.set_physics_process(false)
	_combat.ultimate.set_physics_process(false)
	_game.events.enemy_struck.connect(func(enemy: Node3D, kind: String, force: float): _struck.append([enemy.get_instance_id(), kind, force]))
	_game.events.line_skill_fired.connect(func(id: String, _target: Node3D, _at: Vector3, on: String): _fired.append([id, on]))
	_game.events.enemy_pinned.connect(func(victim: Node3D, _damage: float): _pinned.append(victim.get_instance_id()))
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400.0, 1.0, 400.0)
	collision.shape = box
	floor_body.add_child(collision)
	_game.add_child(floor_body)
	floor_body.global_position = Vector3(-45.0, 119.5, 6.0)
	await _fresh()


func _never() -> bool:
	return false


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _fresh() -> void:
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.queue_free()
	_kit._clear()
	_kit._cards.clear()
	_kit._punches = 0
	_kit._shrugs = 0
	_combat.ultimate._phase = "idle"
	_combat.ultimate._ride = null
	_combat.ultimate.meter.locked = false
	_player.kit.drop_line("reset")
	_player.kit.rewind_left = 0.0
	_player.kit.sprinting = false
	_player.immune_left = 0.0
	_player.chain.reset()
	_player.abilities.refill()
	_player.abilities.snap_back("test")
	_player._fire_latched = false
	_combat._line_load = {}
	_combat._bite_pending = false
	_combat._pinned.clear()
	_struck.clear()
	_fired.clear()
	_pinned.clear()
	_game.run.mass = 0.0
	_game.run.parts.clear()
	_game.run._heft_class = 1
	_player.body().freeze = true
	_player.reset_to(SHELF)
	_player.state.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame


func _enemy(kind: String, dx: float, dz := 0.0) -> Node3D:
	var ball: Vector3 = _player.ball_position()
	var enemy: Node3D = _combat.spawn_enemy(kind, ball + Vector3(dx, 0.0, dz))
	enemy.global_position = ball + Vector3(dx, 0.0, dz)
	if enemy.get("live") != null:
		enemy.live = _never
	if enemy.get("hp") != null:
		enemy.hp = 10000.0
		enemy.max_hp = 10000.0
	enemy.set_physics_process(true)
	return enemy


func _boss(dx: float) -> Node3D:
	var enemy := Enemy.new()
	enemy.kind = "brindle_hull"
	enemy.weight = 1.0
	enemy.hp = 10000.0
	enemy.max_hp = 10000.0
	_game.add_child(enemy)
	enemy.add_to_group("enemy")
	enemy.global_position = _player.ball_position() + Vector3.RIGHT * dx
	return enemy


func _tick(fields := {}, dt := DT) -> void:
	_player.intent.clear()
	for key in fields:
		_player.intent.set(key, fields[key])
	_player._route_slots(dt)
	_combat._step_special(_player.intent, dt)
	_combat._step_line(_player.intent, dt)


func _cast(target: Node3D = null, anchor := Vector3.ZERO) -> void:
	if target != null:
		_player.grapple_to(target.global_position, Vector3.UP, target)
	elif anchor != Vector3.ZERO:
		_player.grapple_to(anchor, Vector3.LEFT, null)
	_tick({"slot_pick": 2, "fire_pressed": true, "fire_held": true})
	_tick({"fire_released": true}, 0.0)


func _step_for(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		_kit.step(1.0 / Engine.physics_ticks_per_second)
		await physics_frame


func _hits(enemy: Node3D) -> Array:
	return _struck.filter(func(row): return row[0] == enemy.get_instance_id())


func _punch_of(row: Array) -> float:
	return float(_combat.punch_of(String(row[1]), float(row[2])))


# Parks share one Shape3D across many colliders: each placement keeps its own build, so the
# terrain warm-up does not rebuild every one of them each time (a 100-175 ms tick in a park).
func _shared_shape_cache() -> void:
	var cache := TerrainFaces.new()
	var box := BoxShape3D.new()
	var here := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.0))
	var there := Transform3D(Basis.IDENTITY, Vector3(100.0, 0.0, 0.0))
	var faces := [[Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(0, 0, 1)]]
	var first := cache.request(box, here, faces)
	cache.request(box, there, faces)
	_t.check("both placements of a shared shape stay cached", not cache.cached(box, here).is_empty() and not cache.cached(box, there).is_empty(), "")
	_t.check("a repeat request reuses its placement's build", cache.request(box, here, faces) == first, "")
	var near := cache.faces_near(cache.cached(box, there), AABB(Vector3(98.0, -1.0, -2.0), Vector3(4.0, 2.0, 4.0)))
	_t.eq("each placement reads its own faces", near.size() == 1 and (near[0][0] as Vector3).is_equal_approx(Vector3(99, 0, -1)), true)
	cache.finish()
	_level_ground_budget()


# Andrew's 18 Oct ruling (option B): a Breach on level park ground hits on the landing tick. The
# kit's landing budget is bigger on level ground, smaller than the shares of a heavy carve, and a
# lowered late_work lowers both; the threshold is the one the ruling names.
func _level_ground_budget() -> void:
	_t.check("level ground: the landing budget is bigger on level ground, a lowered late_work lowers both",
		_kit.landing_work(true) > _kit.landing_work(false) and _kit.landing_work(false) == Kit.LANDING_WORK and _kit.landing_work(true) == Kit.LEVEL_LANDING_WORK
		and _kit.late_work == Kit.LATE_WORK, "")
	_kit.late_work = 3
	var lowered := [_kit.landing_work(true), _kit.landing_work(false)]
	_kit.late_work = Kit.LATE_WORK
	_t.eq("level ground: late_work 3 gives a 7 and a 3 part landing", lowered, [roundi(3.0 * Kit.LEVEL_LANDING_WORK / Kit.LATE_WORK), 3])
	_t.check("level ground: the level budget is the ruled 400 parts, not a multiple of the slope share", Kit.LEVEL_LANDING_WORK == 400 and Kit.LATE_WORK == 182, "late %d" % Kit.LATE_WORK)
	var flat := [[Vector3(-2, 0, -2), Vector3(-2, 0, 2), Vector3(2, 0, -2)], [Vector3(2, 0, -2), Vector3(-2, 0, 2), Vector3(2, 0, 2)]]
	_t.check("level ground: a flat face under the landing is level, and the line is 5 degrees (Andrew's stand is 3.43)", _kit.level_ground(flat, Vector3(0.0, 0.5, 0.0)) and Kit.LEVEL_GROUND_DEG == 5.0 and 3.43 < Kit.LEVEL_GROUND_DEG, "")


func _finish() -> void:
	_t.eq("expected check count", _t.checks + 1, _expected_checks)
	_game.free()
	quit(_t.verdict())


func _run() -> void:
	await _boot()
	_shared_shape_cache()
	var audio = _game.presentation.audio
	audio.bake_now()
	audio.engine.key = 3
	var def: Resource = ClassDef.by_id("runner_gunner")
	_t.check("class row names line_drive and foundry_cutter", def.line_id == "line_drive" and def.ultimate_id == "foundry_cutter", "%s %s" % [def.line_id, def.ultimate_id])
	_t.eq("slot 3 is Line Drive", _player.abilities.id_of("line"), "line_drive")
	_t.eq("Line Drive is a tap", _player.abilities.gauge("line"), null)
	_t.eq("Q is Foundry Cutter", _player.abilities.ultimate_id, "foundry_cutter")

	# The punch at cruise: a ram at 0.6 x 14 = 8.4, the pulse arrives after distance / 150 s.
	var a := _enemy("chaser", 15.0)
	_player.state.velocity = Vector3(14.0, 0.0, 0.0)
	var want: float = _combat.punch_of("ram", 8.4)
	_cast(a)
	_t.eq("a cast on a body fires line_skill_fired once", _fired, [["line_drive", "body"]])
	_t.eq("the punch waits for the pulse", _hits(a), [])
	_t.near("the pulse runs at 150 m/s", float(_kit.pulses[0]["left"]) if not _kit.pulses.is_empty() else -1.0, 15.0 / 150.0, 0.02)
	_kit.step(0.11)
	var rows := _hits(a)
	_t.check("one ram contact", rows.size() == 1 and rows[0][1] == "ram", str(rows))
	_t.near("punch is punch_of(ram, 0.6 x speed)", _punch_of(rows[0]) if rows.size() == 1 else -1.0, want, 0.01)
	var knock := Vector3(a._knock.x, 0.0, a._knock.z)
	_t.check("knock runs along the cable, away from the ball", knock.length() > 1.0 and rad_to_deg(knock.angle_to(Vector3.RIGHT)) <= 1.0, str(a._knock))
	_t.check("the line stays latched on the machine", _player.kit.hooked and _player.kit.on_body and _player.kit.anchor_body == a)
	_t.eq("Line Drive refuses a pick while cooling", _player.abilities.ready("line"), false)

	# A target freed while its pulse runs drops the pulse without a script error (KE9 r1 gate).
	await _fresh()
	var gone := _enemy("chaser", 15.0)
	_cast(gone)
	var pending: int = _kit.pulses.size()
	gone.free()
	_kit.step(0.2)
	_t.check("a freed target's pulse is dropped", pending == 1 and _kit.pulses.is_empty(), "%d then %d" % [pending, _kit.pulses.size()])

	# The floor: a slow ball still punches at 8. Chain and sprint multiply.
	await _fresh()
	a = _enemy("chaser", 15.0)
	_cast(a)
	_kit.step(0.2)
	_t.near("a stopped ball punches at the floor of 8", _punch_of(_hits(a)[0]) if _hits(a).size() == 1 else -1.0, _combat.punch_of("ram", 8.0), 0.01)
	await _fresh()
	a = _enemy("chaser", 15.0)
	_player.grapple_to(a.global_position, Vector3.UP, a)
	for i in 3:
		_player.chain.link(true, false)
	var mult: float = _player.chain.multiplier()
	_player.abilities.refill()
	_tick({"slot_pick": 2, "fire_pressed": true, "fire_held": true})
	_tick({"fire_released": true}, 0.0)
	_kit.step(0.2)
	_t.check("chain fixture multiplies", mult > 1.0, str(mult))
	_t.near("the punch pays the chain multiplier", _punch_of(_hits(a)[0]) if _hits(a).size() == 1 else -1.0, _combat.punch_of("ram", 8.0) * mult, 0.01)
	await _fresh()
	a = _enemy("chaser", 15.0)
	_player.kit.sprinting = true
	_cast(a)
	_kit.step(0.2)
	var sprint_punch := _punch_of(_hits(a)[0]) if _hits(a).size() == 1 else -1.0
	_player.kit.sprinting = false
	_t.near("sprinting punches x1.25", sprint_punch / _combat.punch_of("ram", 8.0), 1.25, 0.001)

	# The drawn arrow is the committed throw; a punched machine pins the one behind it.
	await _fresh()
	a = _enemy("chaser", 12.0)
	var b := _enemy("chaser", 12.0 + 2.0 * _combat.hull_radius(a) + 1.0)
	_player.grapple_to(a.global_position, Vector3.UP, a)
	_tick({"slot_pick": 2})
	_kit.step(0.0)
	var arrow: Dictionary = _player.indicator.shapes.get("rivet_line", {})
	var drawn := Vector3.ZERO
	if not arrow.is_empty():
		drawn = (arrow["to"] as Vector3) - (arrow["from"] as Vector3)
		drawn.y = 0.0
	_t.near("the arrow is 6 m long", drawn.length(), Kit.ARROW_LENGTH, 0.01)
	_tick({"fire_pressed": true, "fire_held": true})
	_tick({"fire_released": true}, 0.0)
	_kit.step(0.2)
	knock = Vector3(a._knock.x, 0.0, a._knock.z)
	_t.check("drawn arrow equals the committed knock to 1 degree", drawn.length() > 0.0 and knock.length() > 0.0 and rad_to_deg(drawn.angle_to(knock)) <= 1.0,
		"%.2f degrees" % rad_to_deg(drawn.angle_to(knock)) if knock.length() > 0.0 and drawn.length() > 0.0 else "missing")
	for i in 60:
		_combat._pin_step(_game.get_tree().get_nodes_in_group("enemy"))
		_kit.step(DT)
		await physics_frame
		if not _pinned.is_empty():
			break
	_t.check("the punched machine pins the one 1 m behind", _pinned.has(b.get_instance_id()), str(_pinned))
	_t.check("the first pinning punch queues the Line Drive card", _kit._cards.has("rivet_line_drive"), str(_kit._cards.keys()))

	# The haul: a world bite drags the ball straight in, crowd control slides off, it lets go short.
	await _fresh()
	_player.body().freeze = false
	var anchor: Vector3 = _player.ball_position() + Vector3(30.0, 0.0, 0.0)
	_player.grapple_to(anchor, Vector3.LEFT, null)
	_tick({"slot_pick": 2})
	_kit.step(0.0)
	var arrival: Dictionary = _player.indicator.shapes.get("rivet_arrival", {})
	_t.check("world preview draws the arrival ring at the committed haul stop", arrival.get("kind") == "ring" and arrival.get("centre") == _kit.haul_stop(anchor) and float(arrival.get("radius", 0.0)) > 0.0)
	audio.cue_log.clear()
	audio.engine.key = 3
	_tick({"fire_pressed": true, "fire_held": true})
	_tick({"fire_released": true}, 0.0)
	var haul_cues: Array = audio.cue_log.filter(func(row): return row[1] == "rivet_line_arrive" and row[2] == "now")
	_t.check("haul cue uses trim plus priority in the live key", haul_cues.size() == 1 and is_equal_approx(float(haul_cues[0][5]), Bank.trim_db("rivet_line_arrive") + audio.PRIORITY_DB[AudioRows.priority("line_skill_fired")]) and is_equal_approx(float(haul_cues[0][4]), Harmony.ratio(audio.live_key())), str(haul_cues))
	_t.eq("a world cast fires once, as a haul", _fired, [["line_drive", "world"]])
	_t.check("the haul is running", not _kit.haul.is_empty())
	var v: Vector3 = _player.state.velocity
	_t.check("the haul moves at 24 m/s or more toward the anchor", v.dot((anchor - _player.ball_position()).normalized()) >= 24.0 - 0.01, str(v))
	_t.eq("crowd control is refused during the haul", _player.crowd_control("test_knock", Vector3.ZERO), false)
	var arrived := false
	for i in 270:
		_kit.step(1.0 / Engine.physics_ticks_per_second)
		await physics_frame
		if _kit.haul.is_empty():
			arrived = true
			break
	_t.check("the haul ends", arrived)
	_t.check("the line lets go", not _player.kit.hooked)
	_t.near("it lets go 2.5 m short", _player.ball_position().distance_to(anchor), 2.5, 0.75)
	_t.check("the speed is kept", _player.state.velocity.length() >= 24.0 - 0.01, str(_player.state.velocity.length()))
	_player.body().freeze = true

	# The load: no line loads, the bite carries it; a late bite carries nothing.
	await _fresh()
	a = _enemy("chaser", 15.0)
	_cast()
	_t.check("a cast with no line loads", not _combat.line_load().is_empty() and _fired.is_empty(), str(_fired))
	_tick({}, 3.99)
	_player.grapple_to(a.global_position, Vector3.UP, a)
	_tick({}, 0.0)
	_kit.step(0.2)
	_t.eq("the body bite at 3.99 s fires once", _fired, [["line_drive", "body"]])
	_t.eq("and punches", _hits(a).size(), 1)
	await _fresh()
	_cast()
	_tick({}, 3.99)
	_player.body().freeze = false
	_player.grapple_to(_player.ball_position() + Vector3(25.0, 0.0, 0.0), Vector3.LEFT, null)
	_tick({}, 0.0)
	_t.check("a world bite on the load hauls", not _kit.haul.is_empty() and _fired == [["line_drive", "world"]], str(_fired))
	_player.body().freeze = true
	await _fresh()
	_cast()
	_tick({}, 4.01)
	_t.eq("the load expires at 4.01 s", _combat.line_load(), {})
	_kit.last_cue = {"on": "world", "seconds": 4.0}
	_kit.on_body(null, 1.0, 1.0)
	_t.eq("a dead target refreshes the body cue", _kit.last_cue, {"on": "body", "delay": 0.0})
	_kit.last_cue = {"on": "body", "delay": 4.0}
	_kit.on_world(_player.ball_position(), 1.0, 1.0)
	_t.eq("an already-arrived haul refreshes the world cue", _kit.last_cue, {"on": "world", "seconds": 0.0})

	await _fresh()
	a = _enemy("chaser", 15.0)
	for i in 5:
		_player.chain.link(true, false)
	audio.cue_log.clear()
	audio._last_start.clear()
	audio.engine.key = 3
	_cast(a)
	var body_cues: Array = audio.cue_log.filter(func(row): return row[1] == "rivet_line_punch" and row[2] == "now")
	_t.check("a chained punch cue uses trim plus priority in the live key", body_cues.size() == 1 and is_equal_approx(float(body_cues[0][5]), Bank.trim_db("rivet_line_punch") + audio.PRIORITY_DB[AudioRows.priority("line_skill_fired")]) and is_equal_approx(float(body_cues[0][4]), Harmony.ratio(audio.live_key())), str(body_cues))

	# A Warden's closed guard takes posture only, capped, and never moves; a boss takes half.
	await _fresh()
	var warden := _enemy("warden", 15.0)
	warden.set_physics_process(false)
	var before: Vector3 = warden.global_position
	var posture: float = warden.posture()
	var vfx = _game.presentation.vfx
	var glances: int = int(vfx.spawned.get("strike_deflected", 0))
	var contacts := []
	var on_contact := func(enemy: Node3D, kind: String, punch: float, plating: float): contacts.append([enemy, kind, punch, plating])
	_game.events.strike_deflected.connect(on_contact)
	audio.cue_log.clear()
	audio._last_start.clear()
	_player.state.velocity = Vector3(40.0, 0.0, 0.0)
	_cast(warden)
	_kit.step(0.2)
	_game.events.strike_deflected.disconnect(on_contact)
	var clanks: Array = audio.cue_log.filter(func(row): return row[0] == "strike_deflected" and row[1] == EventKinds.state_row("glancing")["sound"] and row[2] == "now")
	var sparks: Array = vfx._glyphs.filter(func(row): return float(row["t"]) == 0.0 and row["color"] == EventKinds.state_color("glancing") and row["node"].mesh == vfx._meshes["burst"] and row["node"].global_position.is_equal_approx(warden.global_position + Vector3.UP * 0.6))
	_t.check("one closed-guard contact logs the shared clank and slate sparks", contacts.size() == 1 and contacts[0][0] == warden and contacts[0][1] == "ram" and clanks.size() == 1 and int(vfx.spawned.get("strike_deflected", 0)) == glances + 1 and sparks.size() == 1 and is_equal_approx(float(clanks[0][5]), Bank.trim_db("clank") + audio.PRIORITY_DB[AudioRows.priority("strike_deflected")]), "%s cues=%s sparks=%d" % [contacts, clanks, sparks.size()])
	_t.check("a closed guard takes 12 posture at most", warden.posture() - posture > 0.0 and warden.posture() - posture <= Weapons.LINE_WARDEN_POSTURE + 0.001,
		str(warden.posture() - posture))
	_t.eq("the Warden never moves", warden.global_position, before)
	await _fresh()
	var boss := _boss(15.0)
	_cast(boss)
	_kit.step(0.2)
	_t.near("a boss takes x0.5", _punch_of(_hits(boss)[0]) / _combat.punch_of("ram", 8.0) if _hits(boss).size() == 1 else -1.0, 0.5, 0.001)
	_t.eq("a boss is not knocked", boss._knock, Vector3.ZERO)

	# Slot 2 through the bar: pick 2, click, release draws and commits the same 12 m ring.
	await _fresh()
	_tick({"slot_pick": 1, "fire_pressed": true, "fire_held": true}, 0.0)
	_tick({"fire_released": true}, 0.0)
	var ring: Dictionary = _player.indicator.last_shape.get("special", {})
	var committed: Dictionary = _combat.last_committed.get("geometry", {})
	_t.check("slot 2 draws and commits the same 12 m ring", not ring.is_empty() and ring == committed and is_equal_approx(float(ring["radius"]), Weapons.OVERDRIVE_RADIUS),
		"%s" % ring.get("radius", -1.0))
	_cue_timing()
	_finish()
