extends SceneTree

const AimReticle := preload("res://src/ui/aim_reticle.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Augments := preload("res://src/movement/augments.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Intent := preload("res://src/movement/intent.gd")
const Palette := preload("res://src/core/palette.gd")
const WeaponDriver := preload("res://src/combat/weapon_driver.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const T := preload("res://tests/support/t.gd")

# E1-11 (ruling ek): Rivet's and Sable's timing instruments on the aim reticle
# (PILOT-CADENCE section 5.3, LEGIBILITY section 14.1). Read from real WeaponDriver snapshots:
#   - Rivet: a chamber per round, hollow when spent, bone when loaded, copper (and larger) when hot;
#     while reloading a sweep and a notch that is bracketed while it waits, mint while open, slate
#     once spent;
#   - Sable: an empty arc at rest, a fill in her colour (never mint) with the charge, one mint tick
#     at full while held, empty once the bolt leaves;
#   - hold_auto and every other trigger draws nothing;
#   - no mark reaches within DOT_CLEAR px of the aim point, nothing is brass, mint marks only the
#     press-now moment, every mark thins over the pilot, and the instrument adds no words;
#   - the reticle redraws on an instrument change and goes still at rest.

const DT := 1.0 / 60.0

var _t := T.new("reticle_cadence_test")


func _initialize() -> void:
	_rivet()
	_sable()
	_other_triggers()
	_keys()
	_run.call_deferred()


func _run() -> void:
	await _redraws()
	quit(_t.verdict())


func _press() -> Intent:
	var intent := Intent.new()
	intent.fire_pressed = true
	intent.fire_held = true
	return intent


func _hold() -> Intent:
	var intent := Intent.new()
	intent.fire_held = true
	return intent


func _release() -> Intent:
	var intent := Intent.new()
	intent.fire_released = true
	return intent


func _step(drv, pat: Resource, weapon: String, intent: Intent, ticks := 1) -> void:
	for i in ticks:
		drv.step(DT, intent, weapon, pat, pat.rate)


static func _roles(marks: Array, role: String) -> Array:
	return marks.filter(func(m): return m["role"] == role)


static func _role_names(marks: Array) -> Array:
	var out := []
	for m in marks:
		if not out.has(m["role"]):
			out.append(m["role"])
	return out


# Every rule a frame of the instrument keeps whatever its state.
func _frame_rules(label: String, marks: Array, mint_roles: Array) -> void:
	var nearest := INF
	var brass := false
	var mint_off := []
	var layers_ok := true
	for m in marks:
		nearest = minf(nearest, AimReticle.mark_reach(m))
		var c := Color(m["color"], 1.0)
		brass = brass or c.is_equal_approx(Palette.BRASS)
		if c.is_equal_approx(EventKinds.role_color("live")) and not mint_roles.has(m["role"]):
			mint_off.append(m["role"])
		layers_ok = layers_ok and (m["layer"] == "back" or m["layer"] == "line")
	_t.check("%s: no mark covers the centre dot" % label, nearest > AimReticle.DOT_CLEAR, "nearest %.2f px" % nearest)
	_t.check("%s: nothing is brass" % label, not brass)
	_t.check("%s: mint marks only the press-now moment" % label, mint_off.is_empty(), str(mint_off))
	_t.check("%s: every mark is a backing or a reading, so it thins over the pilot" % label, layers_ok)


func _rivet() -> void:
	var pat: Resource = Weapons.base(Weapons.RAPID_LASER)
	var drv := WeaponDriver.new()
	drv.reset(pat)
	var tint: Color = ClassDef.RIVET_COLOR
	var marks := AimReticle.cadence_marks(drv.state_snapshot(), tint)
	_t.eq("Rivet at rest: six loaded chambers", _roles(marks, "chamber_loaded").size(), 6)
	_t.eq("Rivet at rest: no spent or hot chamber", _roles(marks, "chamber_spent").size() + _roles(marks, "chamber_hot").size(), 0)
	_t.check("Rivet at rest: a loaded chamber is bone", (_roles(marks, "chamber_loaded")[0]["color"] as Color).is_equal_approx(EventKinds.role_color("neutral")))
	var first: Vector2 = _roles(marks, "chamber_loaded")[0]["at"]
	_t.check("Rivet: the first chamber sits at twelve", absf(first.x) < 0.001 and first.y < 0.0, str(first))
	_frame_rules("Rivet at rest", marks, [])

	_step(drv, pat, Weapons.RAPID_LASER, _press())
	_step(drv, pat, Weapons.RAPID_LASER, Intent.new(), 14)
	_step(drv, pat, Weapons.RAPID_LASER, _press())
	_step(drv, pat, Weapons.RAPID_LASER, Intent.new(), 14)
	marks = AimReticle.cadence_marks(drv.state_snapshot(), tint)
	var spent := _roles(marks, "chamber_spent")
	_t.eq("Rivet after two rounds: two hollow chambers", spent.size(), 2)
	_t.eq("Rivet after two rounds: four loaded", _roles(marks, "chamber_loaded").size(), 4)
	_t.check("Rivet: the spent chambers are the first fired, clockwise from twelve",
		(spent[0]["at"] as Vector2).y < 0.0 and (spent[1]["at"] as Vector2).x > 0.0, "%s %s" % [spent[0]["at"], spent[1]["at"]])
	_t.check("Rivet: a spent chamber is dimmer than a loaded one, so greyscale still splits them",
		(spent[0]["color"] as Color).a < (_roles(marks, "chamber_loaded")[0]["color"] as Color).a)
	_frame_rules("Rivet part spent", marks, [])

	for i in 4:
		_step(drv, pat, Weapons.RAPID_LASER, _press())
		_step(drv, pat, Weapons.RAPID_LASER, Intent.new(), 14 if i < 3 else 0)
	var snap: Dictionary = drv.state_snapshot()
	_t.check("Rivet: the sixth round starts the reload with the notch waiting", bool(snap["reloading"]) and snap["window"] == "waiting", str(snap))
	_step(drv, pat, Weapons.RAPID_LASER, Intent.new(), 6)
	snap = drv.state_snapshot()
	marks = AimReticle.cadence_marks(snap, tint)
	_t.eq("Rivet reloading: the chambers give way to the sweep", _roles(marks, "chamber_spent").size() + _roles(marks, "chamber_loaded").size(), 0)
	var sweep: Array = _roles(marks, "sweep")
	_t.eq("Rivet reloading: one sweep", sweep.size(), 1)
	_t.near("Rivet reloading: the sweep runs from twelve to the reload's share of the ring",
		float(sweep[0]["to"]) - float(sweep[0]["from"]), TAU * float(snap["reload"]), 0.001)
	var waiting: Array = _roles(marks, "notch_waiting")
	_t.eq("Rivet waiting: a dim notch", waiting.size(), 1)
	_t.eq("Rivet waiting: bracketed by two edges", _roles(marks, "notch_edge").size(), 2)
	var window: Vector2 = snap["window_range"]
	var reload_s := float(snap["reload_s"])
	_t.near("Rivet: the notch opens where the window opens", float(waiting[0]["from"]), -PI * 0.5 + TAU * window.x / reload_s, 0.001)
	_t.near("Rivet: the notch closes where the window closes", float(waiting[0]["to"]), -PI * 0.5 + TAU * window.y / reload_s, 0.001)
	_t.check("Rivet waiting: the notch is dim neutral, not mint or slate",
		(waiting[0]["color"] as Color).a < 1.0 and Color(waiting[0]["color"], 1.0).is_equal_approx(EventKinds.role_color("neutral")))
	_frame_rules("Rivet waiting", marks, [])

	_step(drv, pat, Weapons.RAPID_LASER, Intent.new(), 20)
	snap = drv.state_snapshot()
	_t.eq("Rivet: 26 ticks into the reload the window is open", snap["window"], "open")
	marks = AimReticle.cadence_marks(snap, tint)
	var open: Array = _roles(marks, "notch_open")
	_t.check("Rivet open: the notch is solid mint", open.size() == 1 and (open[0]["color"] as Color).is_equal_approx(EventKinds.role_color("live")))
	_t.eq("Rivet open: no edge brackets", _roles(marks, "notch_edge").size(), 0)
	_t.check("Rivet open: the notch is wider than the waiting notch", float(open[0]["width"]) > float(waiting[0]["width"]))
	_frame_rules("Rivet open", marks, ["notch_open"])

	_step(drv, pat, Weapons.RAPID_LASER, _press())
	snap = drv.state_snapshot()
	marks = AimReticle.cadence_marks(snap, tint)
	var hot: Array = _roles(marks, "chamber_hot")
	_t.eq("Rivet notch hit: five hot rounds left after the first leaves", hot.size(), 5)
	_t.check("Rivet hot rounds are copper, his colour", hot.all(func(m): return (m["color"] as Color).is_equal_approx(Palette.COPPER)))
	_t.check("Rivet's class colour is copper, so his hot rounds are", ClassDef.RIVET_COLOR.is_equal_approx(Palette.COPPER))
	_t.check("Rivet hot rounds are larger than plain ones, so the size carries it too", float(hot[0]["r"]) > AimReticle.CHAMBER_R)
	_t.eq("Rivet notch hit: the first chamber is spent", _roles(marks, "chamber_spent").size(), 1)
	_frame_rules("Rivet hot", marks, [])

	# A top-up after three hot rounds: the hot rounds fire first, the plain ones after.
	_step(drv, pat, Weapons.RAPID_LASER, Intent.new(), 14)
	_step(drv, pat, Weapons.RAPID_LASER, _press())
	_step(drv, pat, Weapons.RAPID_LASER, Intent.new(), 14)
	_step(drv, pat, Weapons.RAPID_LASER, _press())
	drv.top_up_cylinder()
	snap = drv.state_snapshot()
	marks = AimReticle.cadence_marks(snap, tint)
	_t.check("Rivet topped up: three hot then three plain", _roles(marks, "chamber_hot").size() == 3 and _roles(marks, "chamber_loaded").size() == 3, str(snap))
	var hot_at: Vector2 = _roles(marks, "chamber_hot")[0]["at"]
	_t.check("Rivet topped up: the hot rounds are next in line, from twelve", hot_at.y < 0.0 and absf(hot_at.x) < 0.001, str(hot_at))

	# Spend the notch with an early press.
	drv.reset(pat)
	for i in 6:
		_step(drv, pat, Weapons.RAPID_LASER, _press())
		_step(drv, pat, Weapons.RAPID_LASER, Intent.new(), 14 if i < 5 else 0)
	_step(drv, pat, Weapons.RAPID_LASER, Intent.new(), 8)
	_step(drv, pat, Weapons.RAPID_LASER, _press())
	_step(drv, pat, Weapons.RAPID_LASER, Intent.new(), 20)
	snap = drv.state_snapshot()
	marks = AimReticle.cadence_marks(snap, tint)
	var slate: Array = _roles(marks, "notch_spent")
	_t.check("Rivet spent: the notch is slate", slate.size() == 1 and (slate[0]["color"] as Color).is_equal_approx(EventKinds.role_color("slate")), str(snap))
	_t.eq("Rivet spent: no mint, even in the window's time", _roles(marks, "notch_open").size(), 0)
	_t.check("Rivet spent: the sweep runs on", float(_roles(marks, "sweep")[0]["to"]) > float(slate[0]["from"]))
	_frame_rules("Rivet spent", marks, [])


func _sable() -> void:
	var pat: Resource = Weapons.base(Weapons.ARC_CASTER)
	var drv := WeaponDriver.new()
	drv.reset(pat)
	var tint: Color = Palette.ARC
	var marks := AimReticle.cadence_marks(drv.state_snapshot(), tint)
	_t.eq("Sable at rest: the empty arc on its track", _role_names(marks), ["track", "empty"])
	_frame_rules("Sable at rest", marks, [])

	_step(drv, pat, Weapons.ARC_CASTER, _press())
	_step(drv, pat, Weapons.ARC_CASTER, _hold(), 28)
	var snap: Dictionary = drv.state_snapshot()
	marks = AimReticle.cadence_marks(snap, tint)
	var fill: Array = _roles(marks, "fill")
	_t.check("Sable half charge: the charge is part full", float(snap["charge"]) > 0.2 and float(snap["charge"]) < 0.8, str(snap["charge"]))
	_t.eq("Sable half charge: one fill", fill.size(), 1)
	_t.near("Sable: the fill runs clockwise from twelve with the charge", float(fill[0]["to"]) - float(fill[0]["from"]), TAU * float(snap["charge"]), 0.001)
	_t.near("Sable: the fill starts at twelve", float(fill[0]["from"]), -PI * 0.5, 0.0001)
	_t.check("Sable: the fill is her colour through meter_fill_color, never mint",
		(fill[0]["color"] as Color).is_equal_approx(AimReticle.meter_fill_color(tint)) and not (fill[0]["color"] as Color).is_equal_approx(EventKinds.role_color("live")))
	_t.eq("Sable half charge: no tick yet", _roles(marks, "full_tick").size(), 0)
	_frame_rules("Sable half", marks, [])

	_step(drv, pat, Weapons.ARC_CASTER, _hold(), 40)
	snap = drv.state_snapshot()
	marks = AimReticle.cadence_marks(snap, tint)
	_t.check("Sable held long: full charge", float(snap["charge"]) >= 1.0 and bool(snap["charging"]), str(snap))
	var tick: Array = _roles(marks, "full_tick")
	_t.check("Sable full: one mint tick", tick.size() == 1 and (tick[0]["color"] as Color).is_equal_approx(EventKinds.role_color("live")))
	_t.check("Sable full: the tick crosses the arc at twelve", (tick[0]["from"] as Vector2).x == 0.0 and (tick[0]["to"] as Vector2).y < -AimReticle.INSTRUMENT_R)
	_t.eq("Sable full: the tick cuts a dark gap through the fill, so it reads without colour", _roles(marks, "full_tick_back").size(), 1)
	_frame_rules("Sable full", marks, ["full_tick"])

	_step(drv, pat, Weapons.ARC_CASTER, _release())
	marks = AimReticle.cadence_marks(drv.state_snapshot(), tint)
	_t.eq("Sable: the arc empties when the bolt leaves", _role_names(marks), ["track", "empty"])

	var other := AimReticle.cadence_marks({"trigger": "tap_charge", "charge": 0.5, "charging": true}, Palette.COPPER)
	_t.check("a non-mint class colour fills in that colour", (_roles(other, "fill")[0]["color"] as Color).is_equal_approx(Palette.COPPER))
	var full_let_go := AimReticle.cadence_marks({"trigger": "tap_charge", "charge": 1.0, "charging": false}, tint)
	_t.eq("planted: a full charge not held shows no tick", _roles(full_let_go, "full_tick").size(), 0)


func _other_triggers() -> void:
	var drv := WeaponDriver.new()
	var pat: Resource = Weapons.base(Weapons.CLAW_SWEEP)
	drv.reset(pat)
	_step(drv, pat, Weapons.CLAW_SWEEP, Intent.new())
	_t.eq("a weapon with another trigger draws no instrument", AimReticle.cadence_marks(drv.state_snapshot(), Palette.SAND), [])
	for trig in ["hold_auto", "lob_snap", "beats", "stamp", "lock", ""]:
		_t.eq("%s draws no instrument" % (trig if trig != "" else "no snapshot"), AimReticle.cadence_marks({"trigger": trig, "mag": 6, "chamber": 3}, Palette.SAND), [])
	_t.eq("a press weapon with no cylinder draws no instrument", AimReticle.cadence_marks({"trigger": "press", "mag": 0}, Palette.SAND), [])
	_t.eq("an empty snapshot draws nothing", AimReticle.cadence_marks({}, Palette.SAND), [])


func _keys() -> void:
	var rest := {"trigger": "press", "mag": 6, "chamber": 6, "hot": 0, "reloading": false, "reload": 0.0, "window": "idle",
		"window_range": Vector2(0.38, 0.54), "reload_s": 0.95, "cooldown": 0.0, "hold": 0.0}
	var held := rest.duplicate()
	held["hold"] = 0.4
	held["cooldown"] = 0.1
	_t.eq("the redraw key ignores timers the instrument does not show", AimReticle.cadence_key(rest), AimReticle.cadence_key(held))
	var fired := rest.duplicate()
	fired["chamber"] = 5
	_t.check("the redraw key changes when a round leaves", AimReticle.cadence_key(rest) != AimReticle.cadence_key(fired))
	var sable := {"trigger": "tap_charge", "charge": 0.3, "charging": true, "hold": 0.2}
	var sable_later := sable.duplicate()
	sable_later["hold"] = 0.5
	_t.eq("Sable's key ignores the hold timer", AimReticle.cadence_key(sable), AimReticle.cadence_key(sable_later))
	sable_later["charge"] = 0.4
	_t.check("Sable's key changes with the charge", AimReticle.cadence_key(sable) != AimReticle.cadence_key(sable_later))
	_t.eq("hold_auto has no key", AimReticle.cadence_key({"trigger": "hold_auto", "cooldown": 0.1}), [])


class _Counter:
	var n := 0

	func hit() -> void:
		n += 1


class _Kit:
	var aim := {"state": Augments.AIM_NONE}
	var hooked := false
	var rewind_left := 0.0

	func on(_key: String) -> bool:
		return false


class _Player:
	var kit := _Kit.new()


# Over the pilot: every line and backing the instrument draws goes through _thin or _back.
class _Probe extends AimReticle:
	var thinned := 0
	var backed := 0

	func cover(_centre: Vector2) -> float:
		return 1.0

	func _thin(c: Color) -> Color:
		thinned += 1
		return super(c)

	func _back(c: Color) -> Color:
		backed += 1
		return super(c)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _redraws() -> void:
	var reticle := _Probe.new()
	root.add_child(reticle)
	reticle.setup(_Player.new(), null)
	var draws := _Counter.new()
	reticle.draw.connect(draws.hit)
	reticle.cadence_color = Palette.COPPER
	await _frames(3)
	var before := draws.n
	await _frames(3)
	_t.eq("a reticle with no instrument goes still", draws.n - before, 0)

	var pat: Resource = Weapons.base(Weapons.RAPID_LASER)
	var drv := WeaponDriver.new()
	drv.reset(pat)
	reticle.cadence = drv.state_snapshot()
	before = draws.n
	var thin0 := reticle.thinned
	var back0 := reticle.backed
	await _frames(1)
	_t.check("Rivet's instrument arriving redraws", draws.n > before)
	var marks := AimReticle.cadence_marks(reticle.cadence, reticle.cadence_color)
	var lines := marks.filter(func(m): return m["layer"] == "line").size()
	var backs := marks.filter(func(m): return m["layer"] == "back").size()
	_t.check("over the pilot every reading thins", reticle.thinned - thin0 >= lines, "%d thinned, %d readings" % [reticle.thinned - thin0, lines])
	_t.check("over the pilot every backing fades", reticle.backed - back0 >= backs, "%d backed, %d backings" % [reticle.backed - back0, backs])
	_t.eq("the instrument adds no words", reticle.drawn_words(), PackedStringArray())

	for i in 4:
		drv.step(DT, null, Weapons.RAPID_LASER, pat, pat.rate)
		reticle.cadence = drv.state_snapshot()
		await process_frame
	before = draws.n
	for i in 4:
		drv.step(DT, null, Weapons.RAPID_LASER, pat, pat.rate)
		reticle.cadence = drv.state_snapshot()
		await process_frame
	_t.eq("a fresh snapshot of an unchanged cylinder does not redraw", draws.n - before, 0)

	drv.step(DT, _press(), Weapons.RAPID_LASER, pat, pat.rate)
	reticle.cadence = drv.state_snapshot()
	before = draws.n
	await _frames(1)
	_t.check("a round leaving redraws", draws.n > before)
	before = draws.n
	await _frames(3)
	_t.eq("then it goes still", draws.n - before, 0)

	reticle.cadence_color = Palette.ARC
	before = draws.n
	await _frames(1)
	_t.check("a class colour change redraws", draws.n > before)

	reticle.cadence = {"trigger": "hold_auto", "cooldown": 0.05}
	await _frames(2)
	before = draws.n
	for i in 3:
		reticle.cadence = {"trigger": "hold_auto", "cooldown": 0.05 * i}
		await process_frame
	_t.eq("hold_auto's timers never redraw the reticle", draws.n - before, 0)
	reticle.queue_free()
