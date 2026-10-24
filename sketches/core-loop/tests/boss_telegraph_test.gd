extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Hazard := preload("res://src/boss/hazard.gd")

# Every Brindle attack is announced at least 1.0 s before it can land, and it lands only
# inside the geometry it drew. The ball is put inside each new threat the moment it is
# committed, so a hit that came early or outside its drawing would show up. Covers the
# crane sweeps, the slag rings and the charges. Driven tick by tick.
#
# A cued follow-up (fight_phases.gd: the Furnace reprise, the Scuttle hook turn) draws a
# short tell, at least FightPhases.CUED_WARN, after its ratchet cue; its 1.0 s is counted
# from the cue, which is announced on attack_cued.

const DT := 1.0 / 90.0
const MIN_WARN := 1.0
const PHASE_SECONDS := [26.0, 26.0, 30.0]
const FAMILIES := {"brindle_slag": "slag", "brindle_charge": "charge", "crane": "crane"}

var _game
var _boss
var _failures := 0
var _started := false
var _hits := {"crane": [], "slag": [], "charge": []}
var _announced: Array = []
var _seen := {}
# attack id -> [boss clock at the cue, seconds it announced]; cued -> the follow-ups seen.
var _cues := {}
var _cued := {"slag": 0, "charge": 0}
var _short_cued := 0


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
	Harness.install(_game)
	_boss = _game.boss
	_game.ctx.calm = false
	_game.player.source = Intent.Scripted.new()
	_game.events.player_hit.connect(func(_a: float, source: String): _record(source))
	_game.events.scrap_lost.connect(func(_a: int, _at: Vector3, _t: int, cause: String): _record(cause))
	_game.events.attack_cued.connect(func(_fight: String, id: String, s: float): _cues[id] = [_boss.clock, s])
	_game.events.boss_attack_telegraphed.connect(func(id: String, s: float): _announced.append([id, _ahead(id, s)]))
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	for phase in 3:
		if phase > 0:
			_boss.jump_to_phase(phase + 1)
		var until: float = _boss.clock + PHASE_SECONDS[phase]
		while _boss.clock < until:
			_expose()
			_boss.advance(DT)
			_game.run.heal(1000.0)
			if _game.run.mass < 200.0:
				_game.run.add_scrap(300, Vector3.ZERO)
	_finish()
	print("boss_telegraph_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return false


# The newest threat decides where the ball sits: inside it from the tick it is drawn.
func _expose() -> void:
	var newest = null
	for h in _boss.active_hazards():
		if h.cued and not _seen.has(h.get_instance_id()):
			_cued["slag" if h.attack_id.begins_with("slag") else "charge"] += 1
			if h.warn_seconds < FightPhases.CUED_WARN - 1e-6:
				_short_cued += 1
		_seen[h.get_instance_id()] = h.attack_id
		if newest == null or h.age < newest.age:
			newest = h
	var spot: Vector3
	if newest == null:
		var ship: Vector3 = _boss.ship.global_position
		var out: Vector3 = Vector3(ship.x - _boss.arena.global_position.x, 0.0, ship.z - _boss.arena.global_position.z).normalized()
		spot = ship + out * 10.0
	else:
		match newest.shape:
			Hazard.Shape.SECTOR:
				var mid: float = lerpf(newest.a_from, newest.a_to, 0.5)
				spot = newest.centre + Vector3(cos(mid), 0.0, sin(mid)) * (newest.r_in + newest.r_out) * 0.5
			Hazard.Shape.ANNULUS:
				spot = newest.centre + Vector3(-1.0, 0.0, 0.0) * (newest.r_in + newest.r_out) * 0.5
			Hazard.Shape.LANE:
				spot = newest.centre + newest.heading * newest.length * 0.6
	Harness.put_ball(_game, Vector3(spot.x, _boss.arena.ground(spot) + 1.0, spot.z))
	_game.player.body().external_accel = Vector3.ZERO


func _record(source: String) -> void:
	if not FAMILIES.has(source):
		return
	var family: String = FAMILIES[source]
	var ball: Vector3 = _game.player.ball_position()
	var drawn := -1.0
	for h in _boss.active_hazards():
		if h.attack_id.begins_with(family) and h.is_live() and h.contains(ball):
			drawn = maxf(drawn, h.warn_seconds + (FightPhases.CUE_LEAD if h.cued else 0.0))
	_hits[family].append(drawn)


# Seconds from the first warning to the hit: the bus's own, or, for a follow-up its cue
# announced within CUE_LEAD, the cue's own lead.
func _ahead(id: String, seconds: float) -> float:
	for key in _cues:
		var since: float = _boss.clock - float(_cues[key][0])
		if id.begins_with(String(key)) and since <= FightPhases.CUE_LEAD + 0.02:
			return maxf(seconds, float(_cues[key][1]))
	return seconds


func _finish() -> void:
	_report("cued follow-ups", _cued["slag"] >= 1 and _cued["charge"] >= 1 and _short_cued == 0,
		"%d Furnace reprises and %d Scuttle hook turns, %d drawn under %.1f s"
			% [_cued["slag"], _cued["charge"], _short_cued, FightPhases.CUED_WARN])
	for family in ["crane", "slag", "charge"]:
		var hits: Array = _hits[family]
		var early: Array = hits.filter(func(w): return w < MIN_WARN)
		_report("%s telegraph" % family, hits.size() >= 2 and early.is_empty(),
			"%d %s hits, each inside a live committed area drawn for at least %.1f s before it went live (%d outside or early)"
				% [hits.size(), family, MIN_WARN, early.size()])
	var short := _announced.filter(func(a): return a[1] < MIN_WARN)
	_report("announced ahead", _announced.size() == _seen.size() and short.is_empty(),
		"%d threats committed and %d announced on the bus, the shortest %.2f s ahead"
			% [_seen.size(), _announced.size(), _announced.map(func(a): return a[1]).min() if not _announced.is_empty() else -1.0])
