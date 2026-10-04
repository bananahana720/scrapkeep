extends SceneTree

# Rule: an assembled escape corridor opens one 2 s window after a survived hit at
# <=25% hull, never revives or changes retries, and recharges only on a new zone.
# The charge survives JSON and the opaque entrance document; sim steps expire the window.

const Companion := preload("res://src/core/companion.gd")
const RunState := preload("res://src/core/run_state.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Hud := preload("res://src/ui/hud.gd")

var _failures := 0
var _buses: Array[Node] = []


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _model(with_escape := true) -> Companion:
	var model := Companion.new()
	model.acquire("ram_prow")
	model.acquire("escape_vent" if with_escape else "primer_coil")
	model.assemble(["ram_prow", "escape_vent" if with_escape else "primer_coil"])
	return model


func _run(armor := false) -> RunState:
	var bus := GameEvents.new()
	_buses.append(bus)
	var run := RunState.new(bus)
	run.armor_mode = armor
	run.run_id = "escape-test"
	run._loaded_class_id = "rivet"
	run.companion = _model().to_dict()
	run.companion["future_field"] = "keep"
	run.retries = 3
	run.retries_spent = {1: 2, 2: 1}
	return run


func _read(run: RunState) -> Companion:
	var model := Companion.new()
	_report("companion parses", model.from_dict(run.companion), "run's opaque dictionary remains valid")
	return model


func _initialize() -> void:
	_report("low hull matches HUD", RunState.ESCAPE_LOW_HULL == Hud.LOW_HEALTH,
		"threshold %.2f, HUD %.2f" % [RunState.ESCAPE_LOW_HULL, Hud.LOW_HEALTH])
	_report("window tuning", RunState.ESCAPE_WINDOW_SECONDS == 2.0,
		"two seconds ends before the five-second regeneration delay")
	_report("bus row", GameEvents.signal_names().has("escape_window")
		and EventKinds.has("escape_window") and EventKinds.GRAMMAR_SIGNALS.has("escape_window"),
		"one dedicated, registered event awaits its presentation consumer")
	for armor in [false, true]:
		_check_hits(armor)
		_check_kill(armor)
	_check_unassembled()
	_check_round_trip()
	_check_reentrancy()
	for bus in _buses:
		bus.free()
	print("companion_escape_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _check_hits(armor: bool) -> void:
	var run := _run(armor)
	var windows := []
	var published := []
	run.events.escape_window.connect(func(seconds: float):
		windows.append(seconds)
		published.append(run.escape_window_active and run.companion["escape_spent"]))
	run.max_hp = 200.0
	run.hp = 60.0
	run.damage(9.0, "above")
	_report("above threshold", run.hp == 51.0 and windows.is_empty() and _read(run).escape_ready(),
		"armour %s: 51/200 hull keeps the charge" % armor)
	run.damage(1.0, "threshold")
	_report("survived boundary fires once", run.hp == 50.0 and windows == [2.0]
		and published == [true] and run.escape_window_active and _read(run).escape_spent(),
		"armour %s: 50/200 hull, events %s, committed before publishing %s" % [armor, windows, published])
	_report("retry facts untouched", run.retries == 3 and run.retries_spent == {1: 2, 2: 1},
		"opening the window spends/refills no retry")
	run.advance(0.75)
	run.damage(1.0, "second")
	_report("second low-hull hit stays spent", windows == [2.0] and run.escape_window_left == 1.25,
		"armour %s: events %s, %.2f seconds left; no refresh" % [armor, windows, run.escape_window_left])
	run.advance(1.25)
	_report("sim expiry", not run.escape_window_active and run.escape_window_left == 0.0,
		"stepped exactly two seconds; charge remains spent")
	run.damage(1.0, "expired")
	_report("expiry does not recharge", windows == [2.0] and _read(run).escape_spent(),
		"another low hit after expiry still publishes nothing")
	run.events.stage_entered.emit(run.stage, true)
	run.damage(1.0, "retry")
	_report("retry does not recharge", windows == [2.0] and _read(run).escape_spent(),
		"retry entry keeps the zone's spent charge")
	run.events.stage_entered.emit(2, false)
	_report("new zone rearms", _read(run).escape_ready() and not _read(run).escape_spent()
		and not run.escape_window_active and run.companion["future_field"] == "keep",
		"non-retry stage entry resets spent and retains opaque fields")
	run.damage(1.0, "next_zone")
	_report("new zone fires once", windows == [2.0, 2.0] and run.escape_window_active,
		"events %s" % str(windows))
	run.events.stage_entered.emit(2, true)
	_report("retry clears live window", not run.escape_window_active and _read(run).escape_spent(),
		"the brief window does not ride through a retry")
	if armor:
		var absorbed := _run(true)
		absorbed.hp = 20.0
		absorbed.mass = 100.0
		absorbed.damage(1.0, "absorbed")
		_report("armour-only hit at low hull", absorbed.hp == 20.0 and absorbed.escape_window_active,
			"the existing damage contract counts an absorbed hit as a hit")


func _check_kill(armor: bool) -> void:
	var run := _run(armor)
	var windows := []
	var deaths := []
	run.events.escape_window.connect(func(seconds: float): windows.append(seconds))
	run.events.player_died.connect(func(): deaths.append(true))
	run.hp = 10.0
	run.damage(10.0, "killing")
	_report("killing hit never escapes", run.hp == 0.0 and not run.alive() and windows.is_empty()
		and deaths == [true] and not _read(run).escape_spent() and not run.escape_window_active,
		"armour %s: dead, one death, zero windows or charge spent" % armor)
	_report("death leaves retries alone", run.retries == 3 and run.retries_spent == {1: 2, 2: 1},
		"escape hook never revives or alters retry bookkeeping")
	var active := _run(armor)
	active.hp = 26.0
	active.damage(1.0, "open")
	active.damage(25.0, "kill_after_open")
	_report("death closes prior window", active.hp == 0.0 and active.escape_window_left == 0.0
		and not active.escape_window_active, "a previously open window cannot survive death")


func _check_unassembled() -> void:
	for state in [{}, _model(false).to_dict()]:
		var run := _run()
		run.companion = state
		var windows := []
		run.events.escape_window.connect(func(seconds: float): windows.append(seconds))
		run.hp = 26.0
		run.damage(1.0, "no_escape")
		_report("no escape socket", windows.is_empty() and not run.escape_window_active,
			"empty or ram/primer assembly opens nothing")
	var owned := _model()
	owned.unassemble()
	_report("acquired is not assembled", not owned.escape_ready(), "owned escape piece has no ready socket")
	owned.assemble(["ram_prow", "escape_vent"])
	owned.spend_escape()
	owned.unassemble()
	owned.assemble(["escape_vent", "ram_prow"])
	_report("reassembly cannot recharge", owned.escape_spent() and not owned.escape_ready(),
		"only new zone entry or a new run resets the charge")
	var run := _run()
	run.companion = _model().to_dict()
	run.companion["sockets"] = []
	run.hp = 26.0
	run.damage(1.0, "owned_only")
	_report("unassembled hit", not run.escape_window_active and not _read(run).escape_spent(),
		"acquiring without equipping never fires")


func _check_round_trip() -> void:
	var run := _run()
	run.hp = 26.0
	run.damage(1.0, "save")
	var model := _read(run)
	var copy := Companion.new()
	var parsed = JSON.parse_string(JSON.stringify(model.to_dict()))
	_report("spent JSON round trip", copy.from_dict(parsed) and copy.escape_spent() and not copy.escape_ready(),
		"both charge facts round-trip through to_dict/from_dict")
	var legacy := model.to_dict()
	legacy.erase("escape_spent")
	_report("legacy charge loads", copy.from_dict(legacy) and copy.escape_spent(),
		"wave 3 escape_ready=false maps to spent without recharging")
	var before := copy.to_dict()
	var bad := before.duplicate(true)
	bad["escape_spent"] = "true"
	var wrong_type := not copy.from_dict(bad)
	bad["escape_spent"] = false
	_report("bad charge is atomic", wrong_type and not copy.from_dict(bad) and copy.to_dict() == before,
		"wrong types and contradictory ready/spent facts change nothing")
	run.snapshot(Vector3.ZERO, Vector3.ZERO, 0.0)
	var doc = JSON.parse_string(JSON.stringify(run.to_entrance_doc()))
	var loaded := _run()
	_report("entrance keeps spent", loaded.from_entrance_doc(doc) and _read(loaded).escape_spent()
		and loaded.companion["future_field"] == "keep" and not loaded.escape_window_active,
		"opaque companion survives entrance JSON; transient window is not saved")
	loaded.damage(1.0, "loaded")
	_report("loaded charge cannot fire", not loaded.escape_window_active,
		"loading a spent companion leaves it spent")
	copy.reset()
	_report("new model reset", not copy.escape_spent() and not copy.escape_ready() and copy.sockets.is_empty(),
		"new run clears charge and assembly")


func _check_reentrancy() -> void:
	var run := _run()
	var windows := []
	run.events.escape_window.connect(func(seconds: float):
		windows.append(seconds)
		if windows.size() == 1:
			run.damage(1.0, "listener_hit"))
	run.hp = 26.0
	run.damage(1.0, "open")
	_report("listener cannot proc recursively", windows == [2.0] and run.hp == 24.0 and _read(run).escape_spent(),
		"reentrant hit sees the committed spent flag, one window only")
