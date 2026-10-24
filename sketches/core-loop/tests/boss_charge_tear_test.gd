extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")

# Brindle's charge is a lane threat: its hum sounds on the frame the lane is drawn and holds,
# and its tear plays on the frame the lane goes live, which is the tick the hull starts to
# run; the held hum stops there, so there is no silent gap between hum and tear. The tear
# means fire (SOUND-STORY section 7), so its offset from the charge is zero for the full
# tell (CHARGE_WARN) and for the cued hook turn (FightPhases.CUED_WARN) alike. Before this
# test the tear sat 0.42 s into a one-shot hum: about 1 s early on a full charge and 0.18 s
# early on a hook turn (Codex review of main d561e6eb, top ten #8).
#
# Driven tick by tick in phase 3, one frame per tick so the deferred warning runs.

const DT := 1.0 / 90.0
const SECONDS := 40.0

var _game
var _boss
var _audio
var _failures := 0
var _started := false
# hazard id -> {"drawn": clock, "warn": s, "cued": bool, "hum": clock, "tear": clock, "live": clock, "run": bool,
#   "held": the hum was still held on the tick before live, "cut": it stopped on the live tick}
var _charges := {}


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null or _started:
		return false
	_started = true
	_drive()
	return false


func _sounds(sound: String) -> int:
	return _audio.cue_log.filter(func(c): return c[0] == "threat_lane" and c[1] == sound and c[2] == "now").size()


func _stops() -> int:
	return _audio.cue_log.filter(func(c): return c[0] == "threat_lane" and c[1] == "threat_hum" and c[2] == "stop").size()


func _drive() -> void:
	Harness.install(_game)
	_boss = _game.boss
	_audio = _game.presentation.audio
	_audio.bake_now()
	_game.ctx.calm = false
	_game.player.source = Intent.Scripted.new()
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	_boss.set_physics_process(false)
	_boss.jump_to_phase(3)
	var until: float = _boss.clock + SECONDS
	while _boss.clock < until:
		var hums := _sounds("threat_hum")
		var stops := _stops()
		var tears := _sounds("threat_tear")
		var before := {}
		var held := {}
		for h in _boss.active_hazards():
			before[h.get_instance_id()] = h.state
			held[h.get_instance_id()] = _audio.lane_hums.has(h.get_instance_id())
		Harness.put_ball(_game, _boss.arena.point_at(0.0, 30.0, 1.0))
		_boss.advance(DT)
		_game.run.heal(1000.0)
		if _game.run.mass < 200.0:
			_game.run.add_scrap(300, Vector3.ZERO)
		var torn := _sounds("threat_tear") - tears
		var went_live := 0
		for h in _boss.active_hazards():
			if h.shape != Hazard.Shape.LANE:
				continue
			var id: int = h.get_instance_id()
			if not _charges.has(id):
				_charges[id] = {"drawn": _boss.clock, "warn": h.warn_seconds, "cued": h.cued, "hum": -1.0, "tear": -1.0, "live": -1.0, "run": false, "held": false, "cut": false}
			if h.is_live() and before.get(id, Hazard.WARN) == Hazard.WARN:
				went_live += 1
				_charges[id]["live"] = _boss.clock
				_charges[id]["run"] = _boss._charge.get("hazard") == h and _boss._charge.get("state") == "run"
				_charges[id]["held"] = held.get(id, false)
				_charges[id]["cut"] = not _audio.lane_hums.has(id) and _stops() == stops + 1
				if torn > 0:
					_charges[id]["tear"] = _boss.clock
		if torn != went_live:
			_report("tear only on a live tick", false, "clock %.3f: %d tears for %d lanes going live" % [_boss.clock, torn, went_live])
		await process_frame
		if _sounds("threat_hum") > hums:
			for id in _charges:
				if _charges[id]["hum"] < 0.0:
					_charges[id]["hum"] = _boss.clock
	_finish()
	print("boss_charge_tear_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)


func _finish() -> void:
	var full := 0
	var cued := 0
	var bad: Array = []
	for id in _charges:
		var c: Dictionary = _charges[id]
		if c["live"] < 0.0:
			continue
		if c["cued"]:
			cued += 1
		else:
			full += 1
		var hum_lead: float = c["tear"] - c["hum"]
		if c["tear"] != c["live"] or not c["run"] or c["hum"] != c["drawn"] or absf(hum_lead - c["warn"]) > DT + 1e-4 \
				or not c["held"] or not c["cut"]:
			bad.append(c)
	_report("charges seen", full >= 2 and cued >= 1,
		"%d full charges and %d cued hook turns went live in %.0f s of phase 3" % [full, cued, SECONDS])
	_report("tear is fire time", bad.is_empty(),
		"every charge's hum sounded on its draw tick and held to the tick the lane went live and the hull ran, where it stopped and the tear played, one tell apart; mismatches=%s" % [bad])
	var hold: float = SfxBank.samples("threat_hum").size() / float(SfxBank.RATE)
	_report("hum outlasts the longest charge tell", hold > Rules.CHARGE_WARN + 0.5,
		"threat_hum holds %.2f s; Brindle's full tell is %.2f s at tell_mult 1" % [hold, Rules.CHARGE_WARN])
