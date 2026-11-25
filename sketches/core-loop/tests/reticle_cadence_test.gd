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

# E1-11 and E2-07 (ruling ek): the six pilots' timing instruments on the aim reticle
# (PILOT-CADENCE section 5.3, LEGIBILITY section 14.1). Read from real WeaponDriver snapshots:
#   - Rivet: a chamber per round, hollow when spent, bone when loaded, copper (and larger) when hot;
#     while reloading a sweep and a notch that is bracketed while it waits, mint while open, slate
#     once spent;
#   - Sable: an empty arc at rest, a fill in her colour (never mint) with the charge, one mint tick
#     at full while held, empty once the bolt leaves;
#   - Kest: nothing at rest or waiting, a mint chevron while the snap window is open, a solid bone
#     chevron edged amber for the hit's flash, a thin slate chevron once spent;
#   - Tarn: three hollow bars on a cross, filled beat by beat, bar three mint in its window, larger
#     in his colour on the hit then all clear, slate with the count cleared when spent;
#   - Tally: a hollow square, a heavier mint square in the PAID window, ledger cream for the PAID
#     flash, slate once spent;
#   - the Cannon: open dim brackets at rest, closing while the lane is painted, flush and mint in
#     the lock, flush bone edged uranium green after the Rail, slate and opening for the Barrage;
#   - hold_auto draws nothing;
#   - no mark reaches within DOT_CLEAR px of the aim point, nothing is brass, mint marks only the
#     press-now moment, every mark thins over the pilot, and the instrument adds no words;
#   - the six instruments differ by silhouette, and each pilot's states differ without hue;
#   - the reticle redraws on an instrument change, once more when a hit's flash ends, and goes
#     still at rest.

const DT := 1.0 / 60.0

var _t := T.new("reticle_cadence_test")


func _initialize() -> void:
	_rivet()
	_sable()
	_kest()
	_tarn()
	_tally()
	_cannon()
	_silhouettes()
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


func _tap() -> Intent:
	var intent := Intent.new()
	intent.fire_pressed = true
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


# Sorts and rounds a frame's readings to their silhouette, with every colour dropped: shape (and a
# polygon's corners, open or closed), place (to the nearest 45 degrees round the aim point and the
# nearest px out from it), size and stroke.
static func _silhouette(marks: Array) -> Array:
	var out := []
	for m in marks:
		if m["layer"] != "line":
			continue
		var at := Vector2.ZERO
		var form := String(m["shape"])
		var size := float(m.get("r", 0.0))
		match String(m["shape"]):
			"disc", "ring":
				at = m["at"]
			"arc":
				at = Vector2.from_angle((float(m["from"]) + float(m["to"])) * 0.5) * float(m["r"]) if float(m["to"]) - float(m["from"]) < TAU - 0.01 else Vector2.ZERO
			"line":
				at = ((m["from"] as Vector2) + (m["to"] as Vector2)) * 0.5
			"poly", "fill":
				var pts: PackedVector2Array = m["points"]
				at = _mid(pts)
				size = sqrt(_extent(pts))
				form += "%d%s" % [pts.size(), "c" if bool(m.get("closed", false)) else ""]
		var sector := "c" if at.length() < 0.5 else str(posmod(roundi(rad_to_deg(at.angle()) / 45.0), 8))
		out.append("%s@%s:%d/%d/%.1f" % [form, sector, roundi(at.length()), roundi(size), snappedf(float(m.get("width", 0.0)), 0.5)])
	out.sort()
	return out


static func _luma(c: Color) -> float:
	return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * c.a


# The brightest reading in a frame, in greyscale.
static func _peak_luma(marks: Array) -> float:
	var top := 0.0
	for m in marks:
		if m["layer"] == "line":
			top = maxf(top, _luma(m["color"]))
	return top


func _kest() -> void:
	var pat: Resource = Weapons.base(Weapons.STICKY_CHARGE)
	var drv := WeaponDriver.new()
	drv.reset(pat)
	var tint: Color = ClassDef.KEST_COLOR
	_t.eq("Kest at rest: nothing", AimReticle.cadence_marks(drv.state_snapshot(), tint), [])
	_step(drv, pat, Weapons.STICKY_CHARGE, _tap())
	var snap: Dictionary = drv.state_snapshot()
	_t.eq("Kest thrown: the snap window waits", snap["window"], "waiting")
	_t.eq("Kest waiting: still nothing", AimReticle.cadence_marks(snap, tint), [])
	_step(drv, pat, Weapons.STICKY_CHARGE, Intent.new(), 22)
	snap = drv.state_snapshot()
	_t.eq("Kest: 22 ticks after the throw the window is open", snap["window"], "open")
	var open := AimReticle.cadence_marks(snap, tint)
	var tick: Array = _roles(open, "snap_open")
	_t.check("Kest open: one mint chevron", tick.size() == 1 and (tick[0]["color"] as Color).is_equal_approx(EventKinds.role_color("live")))
	var v: PackedVector2Array = tick[0]["points"]
	_t.check("Kest open: the chevron sits at twelve and points in", v.size() == 3 and v[1].y > v[0].y and v[1].y > v[2].y and absf(v[1].x) < 0.001 and v[1].y < 0.0, str(v))
	_t.eq("Kest open: on a dark backing", _roles(open, "snap_back").size(), 1)
	_frame_rules("Kest open", open, ["snap_open"])

	_step(drv, pat, Weapons.STICKY_CHARGE, _tap())
	snap = drv.state_snapshot()
	_t.eq("Kest snap: the window reads hit", snap["window"], "hit")
	var hit := AimReticle.cadence_marks(snap, tint, 0.0)
	var fill: Array = _roles(hit, "snap_hit")
	_t.check("Kest hit: a solid bone chevron", fill.size() == 1 and fill[0]["shape"] == "fill" and (fill[0]["color"] as Color).is_equal_approx(EventKinds.role_color("neutral")))
	var edge: Array = _roles(hit, "snap_edge")
	_t.check("Kest hit: edged in her amber", edge.size() == 1 and (edge[0]["color"] as Color).is_equal_approx(Palette.AMBER))
	_frame_rules("Kest hit", hit, [])
	_t.eq("Kest hit: the flash ends after HIT_FLASH", AimReticle.cadence_marks(snap, tint, AimReticle.HIT_FLASH), [])
	_t.check("Kest: the hit is named for the reticle's flash", AimReticle.cadence_hit(snap) == ["lob_snap", int(snap["snap_token"])], str(AimReticle.cadence_hit(snap)))

	drv.reset(pat)
	_step(drv, pat, Weapons.STICKY_CHARGE, _tap())
	_step(drv, pat, Weapons.STICKY_CHARGE, Intent.new(), 40)
	snap = drv.state_snapshot()
	_t.eq("Kest late: the window is spent", snap["window"], "spent")
	var spent := AimReticle.cadence_marks(snap, tint)
	var slate: Array = _roles(spent, "snap_spent")
	_t.check("Kest spent: a slate chevron", slate.size() == 1 and (slate[0]["color"] as Color).is_equal_approx(EventKinds.role_color("slate")))
	_t.check("Kest spent: thinner than the open chevron", float(slate[0]["width"]) < float(tick[0]["width"]))
	_frame_rules("Kest spent", spent, [])
	_t.check("Kest: open, hit and spent part in greyscale",
		_silhouette(hit) != _silhouette(open) and _peak_luma(open) - _peak_luma(spent) > 0.2,
		"open %.2f spent %.2f" % [_peak_luma(open), _peak_luma(spent)])
	drv.notify_lob_charge_gone(int(snap["snap_token"]))
	_t.eq("Kest: the charge gone, the aim clears", AimReticle.cadence_marks(drv.state_snapshot(), tint), [])


func _tarn() -> void:
	var pat: Resource = Weapons.base(Weapons.CLAW_SWEEP)
	var drv := WeaponDriver.new()
	drv.reset(pat)
	var tint: Color = ClassDef.TARN_COLOR
	var rest := AimReticle.cadence_marks(drv.state_snapshot(), tint)
	_t.eq("Tarn at rest: three hollow bars", _roles(rest, "pip_hollow").size(), 3)
	var arms := _roles(rest, "pip_hollow").map(func(m): return str(posmod(roundi(rad_to_deg(_mid(m["points"]).angle()) / 90.0), 4)))
	_t.eq("Tarn: the bars sit on a cross's arms, nine, three, twelve", arms, ["2", "0", "3"])
	_frame_rules("Tarn at rest", rest, [])

	_step(drv, pat, Weapons.CLAW_SWEEP, _tap())
	var marks := AimReticle.cadence_marks(drv.state_snapshot(), tint)
	_t.check("Tarn beat one: bar one fills bone", _roles(marks, "pip_filled").size() == 1 and _mid(_roles(marks, "pip_filled")[0]["points"]).x < 0.0)
	_frame_rules("Tarn beat one", marks, [])
	_step(drv, pat, Weapons.CLAW_SWEEP, Intent.new(), 28)
	_step(drv, pat, Weapons.CLAW_SWEEP, _tap())
	var snap: Dictionary = drv.state_snapshot()
	_t.check("Tarn beat two: the beat-three window waits", int(snap["beat"]) == 2 and snap["window"] == "waiting", str(snap))
	marks = AimReticle.cadence_marks(snap, tint)
	_t.check("Tarn beat two: two bars full, the third hollow", _roles(marks, "pip_filled").size() == 2 and _roles(marks, "pip_hollow").size() == 1)
	_frame_rules("Tarn beat two", marks, [])
	_step(drv, pat, Weapons.CLAW_SWEEP, Intent.new(), 22)
	snap = drv.state_snapshot()
	_t.eq("Tarn: 22 ticks on the beat-three window is open", snap["window"], "open")
	var open := AimReticle.cadence_marks(snap, tint)
	var third: Array = _roles(open, "pip_open")
	_t.check("Tarn open: bar three is mint, at twelve", third.size() == 1 and (third[0]["color"] as Color).is_equal_approx(EventKinds.role_color("live")) and _mid(third[0]["points"]).y < 0.0)
	_t.eq("Tarn open: bars one and two stay full", _roles(open, "pip_filled").size(), 2)
	_frame_rules("Tarn open", open, ["pip_open"])

	_step(drv, pat, Weapons.CLAW_SWEEP, _tap())
	snap = drv.state_snapshot()
	var hit := AimReticle.cadence_marks(snap, tint)
	var big: Array = _roles(hit, "pip_hit")
	_t.check("Tarn hit: bar three fills in his colour", big.size() == 1 and (big[0]["color"] as Color).is_equal_approx(AimReticle.meter_fill_color(tint)), str(snap["window"]))
	_t.check("Tarn hit: the hit bar is larger, so size carries it too",
		_extent(big[0]["points"]) > _extent(third[0]["points"]))
	_t.eq("Tarn hit: the first two still full", _roles(hit, "pip_filled").size(), 2)
	var rim: Array = _roles(hit, "pip_edge")
	_t.check("Tarn hit: edged bone, so a dark colour still reads", rim.size() == 1 and (rim[0]["color"] as Color).is_equal_approx(EventKinds.role_color("neutral")))
	_frame_rules("Tarn hit", hit, [])
	_step(drv, pat, Weapons.CLAW_SWEEP, Intent.new(), 32)
	_t.eq("Tarn recovered: all three clear", _roles(AimReticle.cadence_marks(drv.state_snapshot(), tint), "pip_hollow").size(), 3)

	drv.reset(pat)
	_step(drv, pat, Weapons.CLAW_SWEEP, _tap())
	_step(drv, pat, Weapons.CLAW_SWEEP, Intent.new(), 28)
	_step(drv, pat, Weapons.CLAW_SWEEP, _tap())
	_step(drv, pat, Weapons.CLAW_SWEEP, Intent.new(), 4)
	_step(drv, pat, Weapons.CLAW_SWEEP, _tap())
	snap = drv.state_snapshot()
	_t.eq("Tarn early: the window is spent", snap["window"], "spent")
	var spent := AimReticle.cadence_marks(snap, tint)
	var slate: Array = _roles(spent, "pip_spent")
	_t.check("Tarn spent: bar three slate", slate.size() == 1 and (slate[0]["color"] as Color).is_equal_approx(EventKinds.role_color("slate")))
	_t.eq("Tarn spent: the count clears", _roles(spent, "pip_hollow").size(), 2)
	_frame_rules("Tarn spent", spent, [])
	_t.check("Tarn: open, hit and spent part in greyscale",
		_silhouette(hit) != _silhouette(open) and _silhouette(spent) != _silhouette(open) and _silhouette(spent) != _silhouette(hit))


static func _mid(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in points:
		sum += p
	return sum / float(points.size())


static func _extent(points: PackedVector2Array) -> float:
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points:
		box = box.expand(p)
	return box.size.x * box.size.y


func _tally() -> void:
	var pat: Resource = Weapons.base(Weapons.LEDGER_READER)
	var drv := WeaponDriver.new()
	drv.reset(pat)
	var tint: Color = ClassDef.TALLY_COLOR
	var rest := AimReticle.cadence_marks(drv.state_snapshot(), tint)
	var square: Array = _roles(rest, "square_rest")
	_t.check("Tally at rest: one hollow square", square.size() == 1 and square[0]["shape"] == "poly" and bool(square[0]["closed"]))
	_t.check("Tally: the square sits at twelve", _mid(square[0]["points"]).y < 0.0 and absf(_mid(square[0]["points"]).x) < 0.001)
	_frame_rules("Tally at rest", rest, [])
	_step(drv, pat, Weapons.LEDGER_READER, _tap())
	var snap: Dictionary = drv.state_snapshot()
	_t.check("Tally stamped: the PAID window waits, no streak", snap["window"] == "waiting" and int(snap["stamp_streak"]) == 0, str(snap))
	_t.eq("Tally waiting: the rest square", _role_names(AimReticle.cadence_marks(snap, tint, INF)), ["square_back", "square_rest"])
	_step(drv, pat, Weapons.LEDGER_READER, Intent.new(), 27)
	snap = drv.state_snapshot()
	_t.eq("Tally: 27 ticks on the PAID window is open", snap["window"], "open")
	var open := AimReticle.cadence_marks(snap, tint, INF)
	var mint: Array = _roles(open, "square_open")
	_t.check("Tally open: a mint square, heavier than at rest", mint.size() == 1 and (mint[0]["color"] as Color).is_equal_approx(EventKinds.role_color("live")) and float(mint[0]["width"]) > float(square[0]["width"]))
	_frame_rules("Tally open", open, ["square_open"])

	_step(drv, pat, Weapons.LEDGER_READER, _tap())
	snap = drv.state_snapshot()
	_t.eq("Tally PAID: the streak rises", int(snap["stamp_streak"]), 1)
	_t.check("Tally: the PAID is named for the reticle's flash", AimReticle.cadence_hit(snap) == ["stamp", 1])
	var hit := AimReticle.cadence_marks(snap, tint, 0.0)
	var cream: Array = _roles(hit, "square_paid")
	_t.check("Tally PAID: the square fills in her colour", cream.size() == 1 and cream[0]["shape"] == "fill" and (cream[0]["color"] as Color).is_equal_approx(AimReticle.meter_fill_color(tint)))
	_t.check("Tally's colour is the ledger cream", tint.is_equal_approx(Palette.LEDGER))
	_frame_rules("Tally PAID", hit, [])
	_t.eq("Tally PAID: the flash ends after HIT_FLASH", _role_names(AimReticle.cadence_marks(snap, tint, AimReticle.HIT_FLASH)), ["square_back", "square_rest"])

	_step(drv, pat, Weapons.LEDGER_READER, Intent.new(), 40)
	snap = drv.state_snapshot()
	_t.check("Tally late: the window is spent and the streak gone", snap["window"] == "spent" and int(snap["stamp_streak"]) == 0, str(snap))
	var spent := AimReticle.cadence_marks(snap, tint, INF)
	var slate: Array = _roles(spent, "square_spent")
	_t.check("Tally spent: a slate square", slate.size() == 1 and (slate[0]["color"] as Color).is_equal_approx(EventKinds.role_color("slate")))
	_frame_rules("Tally spent", spent, [])
	_t.check("Tally: rest, open, PAID and spent part in greyscale",
		_silhouette(hit) != _silhouette(open) and _silhouette(rest) != _silhouette(spent)
		and _peak_luma(hit) - _peak_luma(spent) > 0.2 and _peak_luma(open) - _peak_luma(rest) > 0.2,
		"rest %.2f open %.2f paid %.2f spent %.2f" % [_peak_luma(rest), _peak_luma(open), _peak_luma(hit), _peak_luma(spent)])


# The inner face of the left bracket, in px from the aim point.
static func _bracket_gap(marks: Array, role: String) -> float:
	var left: Array = _roles(marks, role).filter(func(m): return (m["points"] as PackedVector2Array)[1].x < 0.0)
	return -(left[0]["points"] as PackedVector2Array)[1].x if not left.is_empty() else -1.0


func _cannon() -> void:
	var pat: Resource = Weapons.base(Weapons.CANNON_LANE)
	var drv := WeaponDriver.new()
	drv.reset(pat)
	var tint: Color = ClassDef.CANNON_COLOR
	var rest := AimReticle.cadence_marks(drv.state_snapshot(), tint)
	_t.eq("Cannon at rest: two open brackets", _roles(rest, "bracket_rest").size(), 2)
	_t.near("Cannon at rest: the brackets stand open", _bracket_gap(rest, "bracket_rest"), AimReticle.BRACKET_OPEN, 0.001)
	_t.check("Cannon: one bracket each side of the aim point",
		_roles(rest, "bracket_rest").map(func(m): return signf(_mid(m["points"]).x)) == [-1.0, 1.0])
	_frame_rules("Cannon at rest", rest, [])

	_step(drv, pat, Weapons.CANNON_LANE, _press())
	_step(drv, pat, Weapons.CANNON_LANE, _hold(), 9)
	var snap: Dictionary = drv.state_snapshot()
	var closing := AimReticle.cadence_marks(snap, tint)
	var gap := _bracket_gap(closing, "bracket_closing")
	_t.check("Cannon painting: the brackets close in bone", _roles(closing, "bracket_closing").size() == 2
		and Color(_roles(closing, "bracket_closing")[0]["color"], 1.0).is_equal_approx(EventKinds.role_color("neutral")), str(snap["lock_stage"]))
	_t.check("Cannon painting: between open and flush, mirroring the lane's bracket", gap > AimReticle.BRACKET_FLUSH and gap < AimReticle.BRACKET_OPEN, "%.2f" % gap)
	_t.near("Cannon painting: the gap is the lane's", gap, lerpf(AimReticle.BRACKET_FLUSH, AimReticle.BRACKET_OPEN, float(snap["lock_bracket"])), 0.001)
	_frame_rules("Cannon closing", closing, [])

	_step(drv, pat, Weapons.CANNON_LANE, _hold(), 12)
	snap = drv.state_snapshot()
	_t.eq("Cannon: 0.35 s held the lock is the Rail", snap["lock_stage"], "rail")
	var flush := AimReticle.cadence_marks(snap, tint)
	var mint: Array = _roles(flush, "bracket_flush")
	_t.check("Cannon lock: flush and mint", mint.size() == 2 and (mint[0]["color"] as Color).is_equal_approx(EventKinds.role_color("live")))
	_t.near("Cannon lock: the brackets sit flush", _bracket_gap(flush, "bracket_flush"), AimReticle.BRACKET_FLUSH, 0.001)
	_frame_rules("Cannon lock", flush, ["bracket_flush"])

	_step(drv, pat, Weapons.CANNON_LANE, _release())
	snap = drv.state_snapshot()
	_t.eq("Cannon Rail: the window reads hit", snap["window"], "hit")
	var hit := AimReticle.cadence_marks(snap, tint)
	var bone: Array = _roles(hit, "bracket_hit")
	var edge: Array = _roles(hit, "bracket_edge")
	_t.check("Cannon Rail: flush bone brackets", bone.size() == 2 and Color(bone[0]["color"], 1.0).is_equal_approx(EventKinds.role_color("neutral")))
	_t.check("Cannon Rail: a thin uranium-green edge", edge.size() == 2 and (edge[0]["color"] as Color).is_equal_approx(Palette.ANCIENT)
		and float(edge[0]["width"]) - float(bone[0]["width"]) <= 2.0)
	_t.check("Cannon Rail: taller than the lock, so size carries the hit",
		_extent(bone[0]["points"]) > _extent(_roles(flush, "bracket_flush")[0]["points"]))
	_t.check("Cannon: lock and Rail part in greyscale", _silhouette(hit) != _silhouette(flush))
	_frame_rules("Cannon Rail", hit, [])
	_step(drv, pat, Weapons.CANNON_LANE, Intent.new(), 44)
	_t.eq("Cannon recovered: open brackets again", _roles(AimReticle.cadence_marks(drv.state_snapshot(), tint), "bracket_rest").size(), 2)

	_step(drv, pat, Weapons.CANNON_LANE, _press())
	_step(drv, pat, Weapons.CANNON_LANE, _hold(), 36)
	snap = drv.state_snapshot()
	_t.eq("Cannon held past the lock: the Barrage", snap["lock_stage"], "barrage")
	var spent := AimReticle.cadence_marks(snap, tint)
	var slate: Array = _roles(spent, "bracket_spent")
	_t.check("Cannon spent: slate brackets", slate.size() == 2 and (slate[0]["color"] as Color).is_equal_approx(EventKinds.role_color("slate")))
	_t.check("Cannon spent: opening again", _bracket_gap(spent, "bracket_spent") > AimReticle.BRACKET_FLUSH)
	_frame_rules("Cannon spent", spent, [])
	_t.check("Cannon: lock, Rail and Barrage part in greyscale",
		_silhouette(spent) != _silhouette(flush) and _peak_luma(flush) - _peak_luma(spent) > 0.2,
		"flush %.2f spent %.2f" % [_peak_luma(flush), _peak_luma(spent)])
	_step(drv, pat, Weapons.CANNON_LANE, _release())
	_t.eq("Cannon after the Barrage: open brackets", _roles(AimReticle.cadence_marks(drv.state_snapshot(), tint), "bracket_rest").size(), 2)


# The six instruments, each in its window-open frame and at rest, part by silhouette alone.
func _silhouettes() -> void:
	var frames := {
		"Rivet": [{"trigger": "press", "mag": 6, "chamber": 6}, {"trigger": "press", "mag": 6, "chamber": 0, "reloading": true,
			"reload": 0.45, "window": "open", "window_range": Vector2(0.38, 0.54), "reload_s": 0.95}],
		"Sable": [{"trigger": "tap_charge", "charge": 0.0}, {"trigger": "tap_charge", "charge": 1.0, "charging": true}],
		"Kest": [{"trigger": "lob_snap", "window": "idle"}, {"trigger": "lob_snap", "window": "open"}],
		"Tarn": [{"trigger": "beats", "beat": 0, "window": "idle"}, {"trigger": "beats", "beat": 2, "window": "open"}],
		"Tally": [{"trigger": "stamp", "window": "idle"}, {"trigger": "stamp", "window": "open"}],
		"Cannon": [{"trigger": "lock", "painted": false}, {"trigger": "lock", "painted": true, "lock_stage": "rail", "lock_bracket": 0.0}],
	}
	var seen := {}
	for pilot in frames:
		for i in 2:
			var look := _silhouette(AimReticle.cadence_marks(frames[pilot][i], Palette.SAND, INF))
			if look.is_empty():
				continue
			var key := str(look)
			_t.check("%s %s: a silhouette no other pilot has" % [pilot, ["at rest", "open"][i]],
				not seen.has(key) or seen[key] == pilot, "%s matches %s" % [key, seen.get(key, "")])
			seen[key] = pilot


func _other_triggers() -> void:
	for trig in ["hold_auto", "", "bogus"]:
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
	var lock := {"trigger": "lock", "painted": true, "lock_stage": "pulse", "lock_bracket": 0.6, "hold": 0.1, "recover": 0.0}
	var lock_later := lock.duplicate()
	lock_later["recover"] = 0.3
	_t.eq("the Cannon's key ignores the recover timer", AimReticle.cadence_key(lock), AimReticle.cadence_key(lock_later))
	lock_later["lock_bracket"] = 0.5
	_t.check("the Cannon's key changes as the brackets close", AimReticle.cadence_key(lock) != AimReticle.cadence_key(lock_later))
	var tarn := {"trigger": "beats", "beat": 2, "window": "waiting", "window_t": 0.1, "cooldown": 0.4}
	var tarn_later := tarn.duplicate()
	tarn_later["window_t"] = 0.2
	tarn_later["cooldown"] = 0.3
	_t.eq("Tarn's key ignores the window's clock", AimReticle.cadence_key(tarn), AimReticle.cadence_key(tarn_later))
	var kest := {"trigger": "lob_snap", "window": "hit", "snap_token": 3}
	_t.check("Kest's key changes once when the hit's flash ends",
		AimReticle.cadence_key(kest, 0.0) == AimReticle.cadence_key(kest, AimReticle.HIT_FLASH * 0.5)
		and AimReticle.cadence_key(kest, 0.0) != AimReticle.cadence_key(kest, AimReticle.HIT_FLASH))
	var tally := {"trigger": "stamp", "window": "waiting", "stamp_streak": 2, "window_t": 0.1}
	_t.check("Tally's key changes once when the PAID flash ends",
		AimReticle.cadence_key(tally, 0.0) != AimReticle.cadence_key(tally, AimReticle.HIT_FLASH))
	_t.eq("only a hit the driver does not hold is named", AimReticle.cadence_hit({"trigger": "beats", "window": "hit"}), [])


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

	# Kest's snap: one redraw as it lands, one as its flash ends, still between and after.
	reticle.cadence = {"trigger": "lob_snap", "window": "hit", "snap_token": 4}
	before = draws.n
	await _frames(1)
	_t.check("Kest's snap redraws as it lands", draws.n > before)
	before = draws.n
	await _frames(2)
	_t.eq("then the flash holds still", draws.n - before, 0)
	reticle.step(AimReticle.HIT_FLASH)
	before = draws.n
	await _frames(1)
	_t.eq("the flash ending redraws once", draws.n - before, 1)
	before = draws.n
	await _frames(3)
	_t.eq("then Kest's aim is clear and still", draws.n - before, 0)
	reticle.cadence = {"trigger": "lob_snap", "window": "hit", "snap_token": 5}
	before = draws.n
	await _frames(1)
	_t.check("the next throw's snap flashes again", draws.n > before)
	reticle.step(AimReticle.HIT_FLASH)
	before = draws.n
	await _frames(1)
	_t.eq("and its flash ends with one redraw", draws.n - before, 1)

	for frame in [{"trigger": "beats", "beat": 1, "window": "idle"}, {"trigger": "stamp", "window": "waiting", "stamp_streak": 0},
			{"trigger": "lock", "painted": false, "window": "idle"}]:
		reticle.cadence = frame
		await _frames(2)
		before = draws.n
		for i in 3:
			var again: Dictionary = frame.duplicate()
			again["cooldown"] = 0.1 * i
			again["window_t"] = 0.05 * i
			reticle.cadence = again
			await process_frame
		_t.eq("%s at rest: a fresh snapshot does not redraw" % frame["trigger"], draws.n - before, 0)

	reticle.cadence = {"trigger": "hold_auto", "cooldown": 0.05}
	await _frames(2)
	before = draws.n
	for i in 3:
		reticle.cadence = {"trigger": "hold_auto", "cooldown": 0.05 * i}
		await process_frame
	_t.eq("hold_auto's timers never redraw the reticle", draws.n - before, 0)
	reticle.queue_free()
