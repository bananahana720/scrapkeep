extends SceneTree

# SR7 (W13-INTEGRATION-3.md, SPIL-9 drivers, leash and chirp). Rules:
# - Each module family is an ordered list of driver rows (Companion.DRIVERS); pick(state)
#   returns the first row the state meets. Reordering two rows changes which fires with no
#   code edit: 100 of 100 sampled ticks on the pure pick, and live in combat.
# - With no leader (the run not alive) the companion stalls within 1 s and waits at the
#   last spot its leader held; it clears on respawn. Far past the leash it is recalled.
# - The body's animation, its chirp and the chirp's motif read one cue row (Companion.CUES):
#   zero mismatches in 100 sampled events, and at most one chirp per cue in its cooldown.
# - One chassis, two sockets, no health economy, no revive.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Companion := preload("res://src/core/companion.gd")
const Body := preload("res://src/presentation/companion_body.gd")
const Audio := preload("res://src/presentation/audio.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const T := preload("res://tests/support/t.gd")

const SAMPLES := 100
const SEED := 7007
const FORCE := 20.0
const STEP := 1.0 / 60.0


class FakePlayer extends RefCounted:
	var at := Vector3.ZERO

	func planar_velocity() -> Vector3:
		return Vector3.ZERO

	func shown_position() -> Vector3:
		return at


class FakeRun extends RefCounted:
	var companion := {}
	var live := true

	func alive() -> bool:
		return live


class FakeCtx extends RefCounted:
	var player
	var run
	var spawner


class FakePresentation extends Node3D:
	var audio


var _t := T.new("companion_drivers_test")
var _game
var _ticks := 0
var _spawned: Array = []
var _consts := {}


func _initialize() -> void:
	_consts = (Companion as Script).get_script_constant_map()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_setup()
		return false
	if _ticks < 12:
		return false
	_check_table()
	_check_reorder_pure()
	_check_reorder_live()
	_check_leash_pure()
	_check_body_stall()
	_check_cue_events()
	_check_chirp_cooldown()
	_check_bounds()
	_clear()
	quit(_t.verdict())
	return true


func _setup() -> void:
	var ctx = _game.ctx
	ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	var spawn: Vector3 = ctx.terrain.spawn_point(1)
	var anchor := Vector3(spawn.x, ctx.terrain.height(spawn.x, spawn.z) + 1.05, spawn.z)
	_game.player.reset_to(anchor)
	_game.player.body().global_position = anchor


func _drivers() -> Dictionary:
	return _consts.get("DRIVERS", {})


func _cues() -> Dictionary:
	return _consts.get("CUES", {})


func _pick(state: Dictionary, table: Dictionary) -> Dictionary:
	if not Companion.new().has_method("pick"):
		return {}
	return Companion.pick(state, table)


func _doc(pair: Array) -> Dictionary:
	var c := Companion.new()
	for id in pair:
		c.acquire(id)
	c.assemble(pair)
	return c.to_dict()


# The real table with the prime row widened to answer contacts too: a data edit that makes
# the two primer rows overlap. Order `reversed` puts the prime row first.
func _overlap(reversed: bool) -> Dictionary:
	var table: Dictionary = _drivers().duplicate(true)
	var rows: Array = table.get(Companion.CONDUCTIVE_PRIMER, [])
	for row in rows:
		if row.get("act") == "prime":
			row["on"] = ["weapon", "contact", "special"]
	if reversed:
		rows.reverse()
	return table


func _check_table() -> void:
	var drivers := _drivers()
	_t.check("DRIVERS table exists", not drivers.is_empty(), "Companion.DRIVERS")
	_t.check("CUES table exists", not _cues().is_empty(), "Companion.CUES")
	_t.check("pick exists", Companion.new().has_method("pick"), "Companion.pick")
	if not Companion.new().has_method("validate_drivers"):
		_t.check("validate_drivers exists", false)
		return
	_t.eq("driver table is sound", Companion.validate_drivers(), [])
	for fam in Companion.FAMILIES:
		_t.check("%s has ordered rows" % fam, (drivers.get(fam, []) as Array).size() >= 2)
	# Structural defect is caught: a row naming a missing cue.
	var broken: Dictionary = drivers.duplicate(true)
	(broken[Companion.RAM_BRACE] as Array)[0]["cue"] = "no_such_cue"
	_t.check("validate_drivers catches a bad cue", not Companion.validate_drivers(broken).is_empty())
	# The real rows: a primed contact consumes, a weapon primes, an escape window acts by style.
	_t.eq("primed contact consumes", _pick({"piece": "primer_coil", "on": "contact", "primed": true}, drivers).get("act"), "consume")
	_t.eq("weapon primes", _pick({"piece": "primer_mesh", "on": "weapon", "primed": true}, drivers).get("act"), "prime")
	_t.eq("unprimed contact does nothing", _pick({"piece": "primer_coil", "on": "contact", "primed": false}, drivers), {})
	_t.eq("vent shoves", _pick({"piece": "escape_vent", "on": "escape_window", "alive": true}, drivers).get("act"), "shove")
	_t.eq("rail lays a lane", _pick({"piece": "escape_rail", "on": "escape_window", "alive": true}, drivers).get("act"), "lane")
	_t.eq("no escape when dead", _pick({"piece": "escape_vent", "on": "escape_window", "alive": false}, drivers), {})
	_t.eq("unseated piece picks nothing", _pick({"piece": "", "on": "ram", "dealt": true}, drivers), {})


func _check_reorder_pure() -> void:
	var a := _overlap(false)
	var b := _overlap(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var changed := 0
	for i in SAMPLES:
		var state := {"piece": ["primer_coil", "primer_mesh"][rng.randi_range(0, 1)],
			"on": ["contact", "special"][rng.randi_range(0, 1)], "primed": true}
		var first := String(_pick(state, a).get("act", ""))
		var second := String(_pick(state, b).get("act", ""))
		if first == "consume" and second == "prime":
			changed += 1
	_t.eq("reordered rows change the pick", "%d of %d" % [changed, SAMPLES], "%d of %d" % [SAMPLES, SAMPLES])


# Live: combat's primer act reads its driver table. A contact on a primed foe consumes the
# prime under the shipped order and re-primes under the reordered overlap table.
func _check_reorder_live() -> void:
	var combat = _game.ctx.spawner
	_t.check("combat holds a driver table", combat.get("drivers") != null, "combat.drivers")
	if combat.get("drivers") == null:
		return
	_game.ctx.run.companion = _doc(["primer_coil", "ram_prow"])
	var e := _spawn("chaser", Vector3(4.0, 0.0, 0.0))
	combat.strike(e, "runner", FORCE, "", "weapon")
	_t.check("weapon hit primes", combat.primed(e))
	combat.strike(e, "ram", FORCE)
	_t.check("shipped order: the ram consumes the prime", not combat.primed(e))
	combat.drivers = _overlap(true)
	combat.strike(e, "runner", FORCE, "", "weapon")
	combat.strike(e, "ram", FORCE)
	_t.check("reordered rows: the ram re-primes instead", combat.primed(e))
	combat.drivers = _drivers()
	combat.strike(e, "ram", FORCE)
	_t.check("restored order consumes again", not combat.primed(e))


func _check_leash_pure() -> void:
	if not Companion.new().has_method("leash_step"):
		_t.check("leash_step exists", false)
		return
	var leash := {}
	var lead := Vector3(3.0, 0.0, 4.0)
	for i in 60:
		leash = Companion.leash_step(leash, STEP, true, lead, lead + Vector3(2.0, 0.0, 0.0))
	_t.eq("follows while led", leash["state"], "follow")
	var stalled_at := -1.0
	var stall_events := 0
	var t := 0.0
	for i in 180:
		t += STEP
		leash = Companion.leash_step(leash, STEP, false, Vector3(50.0, -20.0, 0.0), lead)
		if leash["event"] == "stalled":
			stall_events += 1
			if stalled_at < 0.0:
				stalled_at = t
	_t.check("stalls within 1 s of owner loss", stalled_at > 0.0 and stalled_at <= 1.0, "stalled at %.3f s" % stalled_at)
	_t.eq("one stall event", stall_events, 1)
	_t.eq("waits at the leader's last live spot", leash["safe"], lead)
	leash = Companion.leash_step(leash, STEP, true, lead, lead)
	_t.eq("respawn clears the stall", leash["state"], "follow")
	_t.eq("respawn rejoins", leash["event"], "rejoined")
	_t.check("respawn recalls to the leader", leash["recall"])
	var recalled := false
	for i in int(ceil((Companion.LEASH_SECONDS + 0.1) / STEP)):
		leash = Companion.leash_step(leash, STEP, true, lead, lead + Vector3(Companion.LEASH_RANGE + 5.0, 0.0, 0.0))
		recalled = recalled or leash["recall"]
	_t.check("leash recalls a companion left far behind", recalled)
	_t.check("stall start is under 1 s", Companion.STALL_AFTER > 0.0 and Companion.STALL_AFTER < 1.0, str(Companion.STALL_AFTER))


func _fake_body(pair: Array):
	var pres := FakePresentation.new()
	root.add_child(pres)
	pres.audio = Audio.new()
	var ctx := FakeCtx.new()
	ctx.player = FakePlayer.new()
	ctx.run = FakeRun.new()
	ctx.run.companion = _doc(pair)
	var body = Body.new()
	pres.add_child(body)
	body.setup(ctx)
	body.set_process(false)
	body.combat = null
	body._process(STEP)
	return body


func _free_body(body) -> void:
	var pres = body.get_parent()
	pres.audio.free()
	pres.queue_free()


func _check_body_stall() -> void:
	var body = _fake_body(["primer_coil", "ram_spring"])
	if not body.has_method("state"):
		_t.check("body exposes state()", false)
		_free_body(body)
		return
	var lead := Vector3(1.0, 0.0, 1.0)
	body.ctx.player.at = lead
	for i in 30:
		body._process(STEP)
	body.ctx.run.live = false
	body.ctx.player.at = Vector3(40.0, -30.0, 0.0)
	var t := 0.0
	while body.state() != "stalled" and t < 2.0:
		body._process(STEP)
		t += STEP
	_t.check("body stalls within 1 s", body.state() == "stalled" and t <= 1.0, "%.3f s" % t)
	for i in 60:
		body._process(STEP)
	_t.check("body waits near the safe spot", Vector2(body.global_position.x, body.global_position.z).distance_to(Vector2(lead.x, lead.z)) < Body.SIDE + 1.0, str(body.global_position))
	_t.eq("still stalled", body.state(), "stalled")
	body.ctx.run.live = true
	body._process(STEP)
	_t.check("respawn clears the body's stall", body.state() != "stalled", body.state())
	_free_body(body)


func _check_cue_events() -> void:
	var cues := _cues()
	var covered := {}
	var mismatches := 0
	var events := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for pair in [["primer_coil", "ram_spring"], ["ram_prow", "escape_vent"]]:
		var body = _fake_body(pair)
		if not body.has_method("cue"):
			_t.check("body exposes cue()", false)
			_free_body(body)
			return
		var anims: Array = body.find_children("*", "AnimationPlayer", true, false)
		_t.check("real model for %s" % [pair], not anims.is_empty())
		if anims.is_empty():
			_free_body(body)
			return
		var anim: AnimationPlayer = anims[0]
		var usable: Array = []
		for ev in cues:
			if anim.has_animation(String(cues[ev]["clip"])):
				usable.append(ev)
		var audio = body.get_parent().audio
		for i in SAMPLES / 2:
			# Each usable row once, then random draws, so coverage never rests on the seed.
			var ev: String = usable[i] if i < usable.size() else usable[rng.randi_range(0, usable.size() - 1)]
			covered[ev] = true
			var row: Dictionary = cues[ev]
			var logged: int = audio.chirp_log.size()
			body.cue(ev)
			events += 1
			var bad: bool = body.state() != ev or String(anim.current_animation) != String(row["clip"])
			var want_chirp := String(row["chirp"])
			if want_chirp == "":
				bad = bad or audio.chirp_log.size() != logged
			else:
				if audio.chirp_log.size() != logged + 1:
					bad = true
				else:
					var entry: Array = audio.chirp_log.back()
					bad = bad or entry[0] != ev or entry[1] != want_chirp \
						or entry[2] != String(EventKinds.UI_ROWS[want_chirp]["sound"])
			if bad:
				mismatches += 1
		_t.check("cooldown holds in sampled events %s" % [pair], _cooldown_ok(audio.chirp_log))
		_free_body(body)
	_t.eq("events sampled", events, SAMPLES)
	_t.eq("animation, chirp and motif mismatches", mismatches, 0)
	_t.eq("every cue row sampled", covered.size(), cues.size())


# At most one fired chirp per cue inside the cooldown, read from a chirp log.
func _cooldown_ok(log: Array) -> bool:
	var last := {}
	for entry in log:
		if not entry[4]:
			continue
		if last.has(entry[0]) and float(entry[3]) - float(last[entry[0]]) < Audio.CHIRP_COOLDOWN:
			return false
		last[entry[0]] = float(entry[3])
	return true


func _check_chirp_cooldown() -> void:
	var audio = Audio.new()
	if not audio.has_method("chirp"):
		_t.check("audio exposes chirp()", false)
		audio.free()
		return
	var cd: float = Audio.CHIRP_COOLDOWN
	_t.check("first chirp fires", audio.chirp("primer_set", 10.0))
	_t.check("same cue inside cooldown is held", not audio.chirp("primer_set", 10.0 + cd * 0.5))
	_t.check("another cue is its own trigger", audio.chirp("spring_arm", 10.0 + cd * 0.5))
	_t.check("same cue after cooldown fires", audio.chirp("primer_set", 10.0 + cd + 0.01))
	_t.check("silent cue never chirps", not audio.chirp("primer_expire", 20.0))
	_t.check("cooldown log check", _cooldown_ok(audio.chirp_log))
	_t.check("planted double chirp is caught", not _cooldown_ok([["x", "k", "s", 1.0, true], ["x", "k", "s", 1.0 + cd * 0.5, true]]))
	audio.free()


func _check_bounds() -> void:
	_t.eq("one chassis", Companion.CHASSIS, "spil9")
	_t.eq("two sockets", Companion.SOCKETS, 2)
	var doc: Dictionary = Companion.new().to_dict()
	_t.check("no health economy in the doc", not doc.has("hp") and not doc.has("health"), str(doc.keys()))
	var acts := {}
	for fam in _drivers():
		for row in _drivers()[fam]:
			acts[row["act"]] = true
	_t.check("no revive act", not acts.has("revive"), str(acts.keys()))


func _spawn(kind: String, offset: Vector3) -> Node3D:
	var spot: Vector3 = _game.player.ball_position() + offset
	var e: Node3D = _game.ctx.spawner.spawn_enemy(kind, _game.ctx.terrain.drop_point(spot.x, spot.z, 2.4))
	_spawned.append(e)
	if e != null and e.get("hp") != null:
		e.hp = 99999.0
		e.max_hp = 99999.0
	return e


func _clear() -> void:
	for e in _spawned:
		if is_instance_valid(e):
			e.remove_from_group("enemy")
			e.queue_free()
	_spawned.clear()
