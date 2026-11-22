extends SceneTree

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Juice := preload("res://src/presentation/juice.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const Kit := preload("res://src/presentation/destructible_kit.gd")
const Events := preload("res://src/core/game_events.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const BallState := preload("res://src/movement/ball_state.gd")
const BallRules := preload("res://src/movement/ball_rules.gd")
const Intent := preload("res://src/movement/intent.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Capture := preload("res://tools/press_latency_capture.gd")

# W45 P2 combat weight. Four feel facts, each with a planted control that must not land:
#   A. juice.gd lands the Warden's posture edges and a boss's fall through EventKinds.weigh: a chunk heavy, a
#      stagger and the breaking chunk massive (55 ms, shake 0.4), a boss climax (60 ms, shake 0.5), each inside
#      the one stop budget, MAX_STOP and SHAKE_CAP; a reading with no edge, and a fact with no weight, land nothing.
#   B. world.gd publishes the stage Warden's chunk phases on fight_phase_changed once each, and audio.gd answers
#      a later Warden phase on the band without moving a mini-boss's anthem; a repeated chunk publishes nothing.
#   C. destructibles.gd sends one world_fact("piece_shattered") per break, plays its family's sound at the break's
#      point and lands its tier's weight: tiers 1 and 2 no stop, tier 3 under tier 4, all inside the budget.
#   D. ball_rules.gd holds a boost pressed 0.08 s before its cooldown ends and fires it on the first legal tick,
#      with the same impulse and cooldown; one pressed 0.25 s before is spent.

const STEP := 1.0 / 90.0
const SIZES := {1: Vector3(1.0, 1.0, 1.0), 2: Vector3(1.4, 1.4, 1.4), 3: Vector3(2.0, 1.6, 2.0), 4: Vector3(2.6, 2.0, 2.6), 5: Vector3(3.2, 2.6, 3.2)}


# The posture body the bus's other listeners read (run_log, machine_fx, ultimate): chunks, glances, a kind.
class FakeWarden extends Node3D:
	var chunks := BossPosture.CHUNKS
	var kind := "warden"

	func glances() -> int:
		return 0

	func chunks_left() -> int:
		return chunks

	func phase_chunks_left() -> int:
		return chunks


var t := T.new("w45_combat_feel_test")
var game
var juice
var sent: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_boost_buffer()
	_latency_cases()
	_shatter_module()
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await process_frame
	await _frames(5)
	juice = game.presentation.juice
	juice.plating_of = Callable()
	juice.resolve_of = Callable()
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	await _frames(30)
	juice.hit_stop_sink = func(seconds: float): sent.append(seconds)
	await _posture_and_boss()
	await _shatter_juice()
	await _warden_phases()
	_boost_shift_live()
	game.queue_free()
	await _frames(5)
	quit(t.verdict())


func _frames(n: int) -> void:
	for i in n:
		await process_frame


# Flushes the frame's juice and returns the stops sent since `from`.
func _flush_since(from: int) -> Array:
	juice.flush()
	return sent.slice(from)


func _fresh() -> int:
	juice.reset_stops()
	return sent.size()


# --- A. posture and boss weight ---

func _posture_and_boss() -> void:
	var warden := FakeWarden.new()
	game.add_child(warden)
	warden.global_position = game.player.ball_position() + Vector3(0.0, 0.0, -6.0)
	var events = game.events

	var from := _fresh()
	events.posture_changed.emit(warden, 0.4, false)
	t.eq("A control: a posture reading with no edge sends no stop", _flush_since(from), [])

	from = _fresh()
	warden.chunks = 3
	events.posture_changed.emit(warden, 0.0, false)
	var chunk := _flush_since(from)
	var heavy: float = Juice.stop_ms_for(0.0, false, true)
	t.check("A: a chunk shattered lands the heavy stop", chunk.size() == 1 and is_equal_approx(chunk[0] * 1000.0, heavy), "%s, want [%.1f ms]" % [chunk, heavy])

	from = _fresh()
	var shake_before: float = game.camera.shake_amplitude()
	events.posture_changed.emit(warden, 1.0, true)
	var stagger := _flush_since(from)
	var massive := EventKinds.weigh("posture_changed", {"staggered": true})
	t.check("A: a stagger lands the massive weight through weigh (55 ms)", stagger.size() == 1 and is_equal_approx(stagger[0] * 1000.0, 55.0) and massive.weight == "massive", "%s %s" % [stagger, massive.weight])
	t.check("A: the stagger's stop is within MAX_STOP and logged as posture_changed", juice.hit_stop_log.back()[2] == "posture_changed" and float(juice.hit_stop_log.back()[1]) <= Juice.SPINE_CAP_MS / 1000.0, str(juice.hit_stop_log.back()))
	t.check("A: the stagger kicks and shakes the camera inside SHAKE_CAP", juice.hook_log.has(["kick", "posture_changed"]) and game.camera.shake_amplitude() > shake_before and is_equal_approx(massive.shake, 0.4) and massive.shake <= Juice.SHAKE_CAP,
		"shake %.2f -> %.2f, weighed %.2f" % [shake_before, game.camera.shake_amplitude(), massive.shake])

	from = _fresh()
	events.posture_changed.emit(warden, 1.0, true)
	t.eq("A control: the same staggered reading again lands nothing", _flush_since(from), [])

	# A stagger right after a strike's stop is inside the gap: the budget refuses it rather than stack.
	from = _fresh()
	juice.request_hit_stop(0.03, "test")
	warden.chunks = 2
	events.posture_changed.emit(warden, 0.0, false)
	events.posture_changed.emit(warden, 1.0, true)
	var gated := _flush_since(from)
	t.check("A: a weighed stop inside the stop gap is refused, not stacked", gated.size() == 1 and is_equal_approx(gated[0], 0.03), str(gated))

	# A ram and the stagger it opens in one frame are one stop: the larger, never two.
	from = _fresh()
	events.posture_changed.emit(warden, 0.2, false)
	warden.chunks = 1
	events.enemy_struck.emit(warden, "ram", 30.0)
	events.posture_changed.emit(warden, 1.0, true)
	var merged := _flush_since(from)
	t.check("A: a ram and its stagger in one frame send one stop, at least the stagger's 55 ms and within MAX_STOP", merged.size() == 1 and merged[0] * 1000.0 >= 55.0 - 0.001 and merged[0] * 1000.0 <= Juice.SPINE_CAP_MS + 0.001, str(merged))

	from = _fresh()
	warden.chunks = 0
	events.posture_changed.emit(warden, 0.0, false)
	var broke := _flush_since(from)
	t.check("A: the breaking chunk lands posture_break's massive stop", broke.size() == 1 and is_equal_approx(broke[0] * 1000.0, 55.0) and juice.hit_stop_log.back()[2] == "posture_break", "%s %s" % [broke, juice.hit_stop_log.back()])

	from = _fresh()
	events.boss_defeated.emit()
	var felled := _flush_since(from)
	var climax := EventKinds.weigh("boss_defeated")
	t.check("A: a boss's fall lands the climax stop (60 ms, the spine's cap)", felled.size() == 1 and is_equal_approx(felled[0] * 1000.0, 60.0) and felled[0] * 1000.0 <= Juice.SPINE_CAP_MS, str(felled))
	t.check("A: the climax shake is 0.5, at SHAKE_CAP, with its zoom", is_equal_approx(climax.shake, 0.5) and climax.shake <= Juice.SHAKE_CAP and juice.hook_log.has(["punch_fov", "boss_defeated"]), str(climax.shake))

	from = _fresh()
	juice.weigh("jumped", {}, Vector3.ZERO)
	t.eq("A control: a fact with no weight row sends no stop", _flush_since(from), [])
	var faint := EventKinds.weigh("boss_defeated", {"strength": 0.0})
	t.check("A control: a zero-strength climax shakes and kicks nothing", faint.shake == 0.0 and faint.kick == 0.0, str([faint.shake, faint.kick]))

	# Within one second the budget never passes STOP_BUDGET_MS, however many breaks ask.
	juice.reset_stops()
	var spent_from: int = juice.hit_stop_log.size()
	for i in 6:
		warden.chunks = BossPosture.CHUNKS
		events.posture_changed.emit(warden, 0.0, false)
		warden.chunks = 0
		events.posture_changed.emit(warden, 0.0, false)
		juice.flush()
	var spent := 0.0
	for row in juice.hit_stop_log.slice(spent_from):
		spent += float(row[1]) * 1000.0
	t.check("A: six breaks back to back stay inside the window budget", spent <= EventKinds.STOP_WINDOW_BUDGET_MS + 0.001, "%.1f ms sent" % spent)
	warden.queue_free()
	await _frames(2)


# --- B. Warden phases on the bus, and the band's answer ---

func _warden_phases() -> void:
	var events = game.events
	var audio = game.presentation.audio
	var heard: Array = []
	var record := func(id: String, phase: int, phases: int): heard.append([id, phase, phases])
	events.fight_phase_changed.connect(record)
	var warden := FakeWarden.new()
	game.add_child(warden)
	var held = game.flow.warden
	game.flow.warden = warden
	events.stage_entered.emit(game.run.stage, true)
	heard.clear()
	events.posture_changed.emit(warden, 0.3, false)
	t.eq("B control: a full guard's reading opens no fight phase", heard, [])
	events.warden_engaged.emit(game.run.stage)
	t.eq("B: the engage publishes phase 1 of 4", heard, [["warden", 1, 4]])
	warden.chunks = 3
	events.posture_changed.emit(warden, 0.0, false)
	t.eq("B: the first chunk publishes phase 2", heard.back(), ["warden", 2, 4])
	var count := heard.size()
	events.posture_changed.emit(warden, 0.5, false)
	events.warden_engaged.emit(game.run.stage)
	t.eq("B control: the same chunk again and a second engage publish nothing", heard.size(), count)
	warden.chunks = 1
	events.posture_changed.emit(warden, 0.0, false)
	t.eq("B: two chunks in one hit publish phases 3 and 4 once each", heard.slice(count), [["warden", 3, 4], ["warden", 4, 4]])
	warden.chunks = 0
	count = heard.size()
	events.posture_changed.emit(warden, 0.0, false)
	t.eq("B: the break publishes no fifth phase", heard.size(), count)
	events.stage_entered.emit(game.run.stage, true)
	heard.clear()
	warden.chunks = BossPosture.CHUNKS
	events.warden_engaged.emit(game.run.stage)
	t.eq("B: a new attempt starts again from phase 1", heard, [["warden", 1, 4]])
	game.flow.warden = held

	var rows: Array = audio.cue_log.filter(func(r): return r is Array and r.size() > 2 and r[0] == "fight_phase_changed")
	t.check("B: audio answers each later Warden phase on the band", rows.size() == 3 and rows.all(func(r): return r[1] == "warden" and r[2] == "phase"), str(rows))
	# A planted mini-boss moment: the Warden's phase leaves its anthem, a mini-boss's own turn moves it.
	var tune_check: Callable = audio.tune_available
	audio.tune_available = func(_id: String) -> bool: return true
	audio._moments.append({"id": "miniboss", "kind": "miniboss", "key": "w45_probe", "seq": 0, "until": -1})
	events.fight_phase_changed.emit("warden", 2, 4)
	var kept: bool = audio._moments.back().id == "miniboss"
	events.fight_phase_changed.emit("rogue_crane", 2, 2)
	var moved: bool = audio._moments.back().id == "miniboss-heavy"
	t.check("B: a Warden phase moves no mini-boss anthem; the planted mini-boss turn does", kept and moved, "kept %s, moved %s" % [kept, moved])
	audio._moments.pop_back()
	audio.tune_available = tune_check
	events.fight_phase_changed.disconnect(record)
	warden.queue_free()
	await _frames(2)


# --- C. destructible breaks ---

func _rows(count: int, tier_of: Callable) -> Array:
	var rows: Array = []
	for i in count:
		var tier: int = tier_of.call(i)
		rows.append({"id": "w45_p%02d" % i, "tier": tier, "at": Vector3(float(i) * 6.0, SIZES[tier].y * 0.5, 0.0), "size": SIZES[tier]})
	return rows


func _shatter_module() -> void:
	var bus := Events.new()
	var facts: Array = []
	bus.world_fact.connect(func(kind: String, at: Vector3): facts.append([kind, at]))
	var weights: Array = []
	var sounds: Array = []
	var mod: Node3D = Destructibles.new()
	mod.build(_rows(5, func(i: int) -> int: return i + 1), {"root": root, "cruise": 14.0, "run_seed": 7, "run_id": "w45", "stage": 1,
		"refused": func(_at: Vector3) -> void: pass, "events": bus,
		"sfx": func(id: String, at: Vector3) -> void: sounds.append([id, at]),
		"weight": func(tier: int, at: Vector3) -> void: weights.append([tier, at])})
	mod.finish_build()
	mod.set_process(false)
	mod.on_blast(Vector3(12.0, 1.0, 0.0), 60.0, "test", 1, 5)
	var shattered := facts.filter(func(f): return f[0] == "piece_shattered")
	t.eq("C: one piece_shattered world fact per break", shattered.size(), 5)
	var tiers: Array = weights.map(func(w): return w[0])
	tiers.sort()
	t.eq("C: every break hands its tier to the weight", tiers, [1, 2, 3, 4, 5])
	var placed := true
	for i in weights.size():
		placed = placed and weights[i][1] == sounds[i][1] and weights[i][1] == shattered[i][1]
	t.check("C: the sound, the weight and the fact share the break's point", placed and sounds.size() == 5, str(sounds))
	var families: Array = sounds.map(func(s): return s[0])
	t.check("C: each break still plays its family's sound", families.has(Kit.sfx_id(1)) and families.has(Kit.sfx_id(4)), str(families))
	mod.teardown()
	mod.queue_free()

	var quiet_weights: Array = []
	var quiet: Node3D = Destructibles.new()
	quiet.build(_rows(3, func(i: int) -> int: return i + 3), {"root": root, "cruise": 14.0, "run_seed": 7, "run_id": "w45", "stage": 1, "no_visuals": true,
		"refused": func(_at: Vector3) -> void: pass, "weight": func(tier: int, at: Vector3) -> void: quiet_weights.append([tier, at])})
	quiet.finish_build()
	quiet.set_process(false)
	quiet.on_blast(Vector3(6.0, 1.0, 0.0), 60.0, "test", 1, 5)
	t.check("C control: --bot-no-visuals breaks land no weight", quiet.intact_count() == 0 and quiet_weights.is_empty(), "%d intact, %s" % [quiet.intact_count(), quiet_weights])
	quiet.teardown()
	quiet.queue_free()
	bus.free()

	t.check("C: tiers 1 and 2 land no weight", Juice.shatter_weight(1).is_empty() and Juice.shatter_weight(2).is_empty())
	var t3 := Juice.shatter_weight(3)
	var t4 := Juice.shatter_weight(4)
	var t5 := Juice.shatter_weight(5)
	t.check("C: tier 3 under tier 4 under or at tier 5, all within the spine's cap", t3.stop_ms > 0.0 and t3.stop_ms < t4.stop_ms and t4.stop_ms <= t5.stop_ms and t5.stop_ms <= Juice.SPINE_CAP_MS,
		"%.1f, %.1f, %.1f ms" % [t3.stop_ms, t4.stop_ms, t5.stop_ms])
	t.check("C: tier shakes climb inside SHAKE_CAP", t3.shake > 0.0 and t3.shake < t4.shake and t5.shake <= Juice.SHAKE_CAP, "%.2f, %.2f, %.2f" % [t3.shake, t4.shake, t5.shake])


func _shatter_juice() -> void:
	var at: Vector3 = game.player.ball_position() + Vector3(4.0, 0.0, 0.0)
	var from := _fresh()
	juice.on_piece_shattered(2, at)
	t.eq("C control: a tier 2 break sends no stop", _flush_since(from), [])
	from = _fresh()
	juice.on_piece_shattered(4, at)
	var crunch := _flush_since(from)
	t.check("C: a tier 4 break sends its heavy stop as piece_shattered", crunch.size() == 1 and is_equal_approx(crunch[0] * 1000.0, Juice.shatter_weight(4).stop_ms) and juice.hit_stop_log.back()[2] == "piece_shattered", str(crunch))

	# The game's wiring: a module built with the game's ctx finds the game's juice and audio itself.
	var heard_from: int = game.presentation.audio.cue_log_total
	var mod: Node3D = Destructibles.new()
	var base: Vector3 = game.player.ball_position() + Vector3(30.0, 0.0, 30.0)
	mod.build([{"id": "w45_live", "tier": 4, "at": base, "size": SIZES[4]}], {"ctx": game.ctx, "root": game.ctx.root})
	mod.finish_build()
	mod.set_process(false)
	from = _fresh()
	mod.on_blast(base, 10.0, "test", 1, 5)
	var live := _flush_since(from)
	t.check("C: the live module lands the game's juice", live.size() == 1 and juice.hit_stop_log.back()[2] == "piece_shattered", str(live))
	var rows: Array = game.presentation.audio.cues_since(heard_from)
	var shatter_rows := rows.filter(func(r): return r is Array and r[0] == "destructible_shatter")
	var ticks := rows.filter(func(r): return r is Array and r[0] == "world_fact")
	t.check("C: the live break asks audio for its family once, and its world fact adds no tick", shatter_rows.size() == 1 and ticks.is_empty(), str(rows))
	var audio = game.presentation.audio
	var near_db: float = audio.distance_db(game.player.shown_position() + Vector3(2.0, 0.0, 0.0))
	var mid_db: float = audio.distance_db(game.player.shown_position() + Vector3(27.5, 0.0, 0.0))
	var far_db: float = audio.distance_db(game.player.shown_position() + Vector3(200.0, 0.0, 0.0))
	t.check("C: a break's sound falls off with its distance from the ball", near_db == 0.0 and mid_db < 0.0 and mid_db > far_db and is_equal_approx(far_db, audio.HEARD_FAR_DB), "%.1f, %.1f, %.1f dB" % [near_db, mid_db, far_db])
	mod.teardown()
	mod.queue_free()
	await _frames(2)


# --- D. the boost buffer ---

# Ticks the rules the way the ball does (timers, then the boost) for `seconds`, pressing on the first tick.
# Returns [seconds into the run it fired or -1, the impulse, the cooldown it set].
func _boost_run(cooldown_left: float, seconds: float, press := true) -> Array:
	var state := BallState.new()
	var tuning := Tuning.new()
	var intent := Intent.new()
	state.boost_cooldown = cooldown_left
	var clock := 0.0
	var first := true
	while clock <= seconds:
		intent.clear()
		intent.boost_pressed = press and first
		first = false
		var got := BallRules.boost(state, tuning, intent, Vector3.FORWARD, Vector3.FORWARD)
		if got != Vector3.ZERO:
			return [clock, got, state.boost_cooldown]
		clock += STEP
		state.tick_timers(STEP)
	return [-1.0, Vector3.ZERO, state.boost_cooldown]


func _boost_buffer() -> void:
	var tuning := Tuning.new()
	t.eq("D: the boost buffer matches the jump buffer", Tuning.BOOST_BUFFER, Tuning.JUMP_BUFFER)
	var now := _boost_run(0.0, 0.1)
	t.check("D: a boost pressed off cooldown fires at once with the boost impulse", now[0] == 0.0 and is_equal_approx((now[1] as Vector3).length(), Tuning.BOOST_IMPULSE) and is_equal_approx(now[2], tuning.boost_cooldown()), str(now))
	var early := _boost_run(0.08, 0.5)
	t.check("D: a press 0.08 s early fires on the first tick the cooldown ends", early[0] >= 0.08 - 0.0001 and early[0] < 0.08 + STEP, "fired at %.4f s" % early[0])
	t.check("D: the buffered boost has the same impulse and cooldown", is_equal_approx((early[1] as Vector3).length(), Tuning.BOOST_IMPULSE) and is_equal_approx(early[2], tuning.boost_cooldown()), str(early))
	var late := _boost_run(0.25, 0.6)
	t.eq("D control: a press 0.25 s early is spent and never fires", late[0], -1.0)
	var none := _boost_run(0.08, 0.5, false)
	t.eq("D control: no press, no boost when the cooldown ends", none[0], -1.0)
	var state := BallState.new()
	state.boost_buffer = Tuning.BOOST_BUFFER
	state.reset()
	t.eq("D: a reset forgets a held press", state.boost_buffer, 0.0)


func _boost_shift_live() -> void:
	# Live keyboard Shift path on player_ball._read_shift(): a Shift press inside BOOST_BUFFER
	# forwards to boost_pressed with no cooldown refusal; outside the window refuses cleanly.
	var fails: Array = []
	var on_fail := func(verb: String, reason: String, _at: Vector3) -> void: fails.append([verb, reason])
	game.ctx.events.verb_failed.connect(on_fail)
	var player = game.player
	var saved_cd: float = player.state.boost_cooldown
	var saved_plant: float = player.kit.plant_time
	var saved_mounted: bool = player.kit.mounted
	player.kit.plant_time = 0.0
	player.kit.mounted = false
	player.state.boost_cooldown = 0.08
	player.intent.clear()
	player.intent.shift_pressed = true
	player._read_shift()
	var in_win_pressed: bool = player.intent.boost_pressed
	var in_win_fails := fails.duplicate()
	fails.clear()
	player.state.boost_cooldown = 0.25
	player.intent.clear()
	player.intent.shift_pressed = true
	player._read_shift()
	var out_win_pressed: bool = player.intent.boost_pressed
	var out_win_fails := fails.duplicate()
	player.state.boost_cooldown = saved_cd
	player.kit.plant_time = saved_plant
	player.kit.mounted = saved_mounted
	game.ctx.events.verb_failed.disconnect(on_fail)
	t.check("D: live Shift inside BOOST_BUFFER forwards without cooldown refusal", in_win_pressed and in_win_fails.is_empty(),
		"pressed %s, fails %s" % [in_win_pressed, in_win_fails])
	t.check("D control: live Shift past BOOST_BUFFER refuses with cooldown", not out_win_pressed and out_win_fails == [["boost", "cooldown"]],
		"pressed %s, fails %s" % [out_win_pressed, out_win_fails])


# --- the payoff verbs' latency cases ---

func _latency_cases() -> void:
	var by_name := {}
	for v in Capture.VERBS:
		by_name[v["name"]] = v
	var payoff := ["haul_line", "reel_body", "dunk"]
	t.eq("E: the latency tool knows the payoff verbs", Capture.unknown_cases(payoff), [])
	t.check("E: each payoff verb is Ctrl with its line set and named", payoff.all(func(n): return by_name[n]["code"] == KEY_CTRL and by_name[n].has("line") and String(by_name[n]["context"]) != ""), str(payoff.map(func(n): return by_name[n])))
	t.eq("E control: an unknown verb is still refused", Capture.unknown_cases(["dunk", "dunk_twice"]), ["dunk_twice"])
