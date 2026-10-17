extends SceneTree

const Game := preload("res://src/game.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Lobber := preload("res://src/combat/lobber.gd")
const Chaser := preload("res://src/combat/chaser.gd")

# Attack facts, packet 1 (DESIGN-NOTES, "Attack facts, enemies"): a mapped enemy's attack
# publishes attack_phase with a unique instance id, its ATTACK_ROWS id, its phase and the
# committed geometry and progress the telegraph draws and tests.
# - Chaser: windup, strike, recover on row E01; two overlapping lunges get two ids; the
#   published geometry equals what the telegraph tests at 25, 50 and 95 percent.
# - A knocked or killed wind-up publishes cancelled.
# - Lobber (packet 2): windup with uncommitted aim whose progress equals lobber.gd's public
#   charge on every tick and reads nothing of the muzzle glow; then strike, committed with
#   geometry equal to the shell Telegraph's own descriptor (hit test agreeing inside, on the
#   edge and outside the landing ring); then recover, on row E02; a kill in the wind-up cancels.
# - Damage: a chaser lunge that lands emits hit_player with Chaser.DAMAGE.
# - A counter (the mag trapper) publishes the same phases from its own loop, row E05.
# - Nothing about the attacks changes: TIMELINE below is captured from base 1c2f777 (md5 of the text), where
#   the same scenario ran with no facts.

const TICK_LIMIT := 480
const OFFSET := Vector3(8.0, 0.0, 0.0)
const FRACTIONS := [0.25, 0.5, 0.95]
const TIMELINE_STAGES := [0, 1, 2, 3, 4, 5, 6]
const LAST_STAGE := 7
const TIMELINE_GOLDEN := "31b06bf983e69dd05bff824779147fe1"

var _game
var _ctx
var _failures := 0
var _stage := -1
var _ticks := 0
var _ball := Vector3.ZERO
var _log: Array = []
var _units: Array = []
var _open := {}
var _max_open := 0
var _all_ids: Array = []
var _sampled := {}
var _timeline: Array = []
var _last_state := {}
var _stage_done := false
var _acted := false
var _seen := {}
var _hits: Array = []
var _shell := {}
var _charge_ticks := 0
var _charge_bad: Array = []
var _glow_bad: Array = []
var _glow_ticks := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if _stage < 0:
		_setup()
		return _next_stage()
	_ticks += 1
	_observe()
	if _stage_done or _ticks > TICK_LIMIT:
		_judge()
		return _next_stage()
	return false


func _setup() -> void:
	_ctx = _game.ctx
	_ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	var spawn: Vector3 = _ctx.terrain.spawn_point(1)
	_ball = _ctx.terrain.drop_point(spawn.x, spawn.z, 1.05)


func _next_stage() -> bool:
	for unit in _units:
		if is_instance_valid(unit):
			unit.queue_free()
	_units.clear()
	_stage += 1
	_ticks = 0
	_log = []
	_open.clear()
	_sampled.clear()
	_last_state.clear()
	_stage_done = false
	_acted = false
	_seen = {}
	# Each stage is its own encounter: the attacker budget's 0.2 s gap between warnings (SQ2) must
	# not carry over from the last stage's cancelled windup into this one's first ask.
	root.remove_meta("attack_budget_last")
	if _stage > LAST_STAGE:
		return _finish()
	_game.player.reset_to(_ball)
	match _stage:
		0:
			_spawn("chaser", OFFSET)
			_spawn("chaser", Vector3(0.0, 0.0, 8.0))
		1, 2:
			_spawn("chaser", OFFSET)
		3, 4:
			_spawn("lobber", Vector3(15.0, 0.0, 0.0))
			_units[0]._clock = Lobber.CYCLE - Lobber.TELEGRAPH + 0.05
		5, 6:
			_spawn("mag_trapper", OFFSET)
			_units[0]._rest = 0.3
		7:
			_hits = []
			_spawn("chaser", OFFSET)
			_units[0].hit_player.connect(func(amount: float, shove: Vector3) -> void: _hits.append([amount, shove.snappedf(0.01)]))
	return false


func _spawn(kind: String, offset: Vector3) -> void:
	var at: Vector3 = _ball + offset
	var unit: Node3D = _ctx.spawner.spawn_enemy(kind, _ctx.terrain.drop_point(at.x, at.z, 1.8))
	_units.append(unit)
	_log.append([])
	if unit.has_signal("attack_phase"):
		unit.attack_phase.connect(_on_phase.bind(_units.size() - 1))


func _on_phase(facts: Dictionary, index: int) -> void:
	_log[index].append(facts)
	if _stage == 3 and facts["phase"] == "strike":
		_capture_shell()
	_all_ids.append([_stage, facts["instance"], facts["phase"]])
	if facts["phase"] == "windup":
		_open[facts["instance"]] = true
		_max_open = maxi(_max_open, _open.size())
	else:
		if facts["phase"] == "cancelled" or facts["phase"] == "recover":
			_open.erase(facts["instance"])


# At the strike the shell already exists: keep its Telegraph's own descriptor and check the
# published geometry against that Telegraph's hit test right away, while the ring is live.
func _capture_shell() -> void:
	for shell in get_nodes_in_group("enemy_shot"):
		if shell.get("ring") != null and is_instance_valid(shell.ring):
			var d: Dictionary = shell.ring.descriptor()
			_shell = {"descriptor": d, "agree": _agree_ring(d, shell.ring)}


func _agree_ring(d: Dictionary, tele: Node3D) -> bool:
	var points: Array = []
	for f in [0.0, 0.5, 0.98, 1.02, 1.5]:
		points.append(d["centre"] + Vector3.RIGHT * d["r_out"] * f)
		points.append(d["centre"] + Vector3.BACK * d["r_out"] * f)
	for p in points:
		var q := _ground(p)
		if _inside(d, q) != tele.contains(q):
			return false
	return true


func _phases(index: int) -> Array:
	var phases: Array = []
	for facts in _log[index]:
		phases.append(facts["phase"])
	return phases


func _observe() -> void:
	var first = _units[0]
	if not is_instance_valid(first):
		_stage_done = true
		print("unit freed at stage %d tick %d" % [_stage, _ticks])
		return
	# The timeline reads only what exists on base: the enemy's own state and lane.
	if is_instance_valid(first) and first.has_method("state_name"):
		var now: String = first.state_name()
		if _last_state.get(first, "") != now:
			_last_state[first] = now
			if _stage in TIMELINE_STAGES:
				# A lunge ends on contact, which jitters by a tick between runs, so recover carries no tick.
				_timeline.append("s%d:%s:%s" % [_stage, "-" if now == "recover" and _stage == 0 else str(_ticks), now])
		var tele = first.telegraph()
		if tele != null and _stage == 0 and not _sampled.has("lane"):
			_sampled["lane"] = true
			_timeline.append("lane %s %s %.2f %.2f" % [tele.center.snappedf(0.01), tele.dir.snappedf(0.01), tele.length, tele.width])
	if is_instance_valid(first) and first.get("shots") != null and _stage == 3 and first.shots > 0 and not _sampled.has("shot"):
		_sampled["shot"] = true
		_timeline.append("s%d:%d:fired" % [_stage, _ticks])
	if _stage == 3:
		_observe_charge(first)
	var state: String = first.state_name() if first.has_method("state_name") else ""
	if state != "":
		_seen[state] = true
	# Every trigger below reads the enemy's own state, never a fact, so base runs the same worlds.
	match _stage:
		0:
			if not _acted and _units[0].telegraph() != null and _units[1].telegraph() != null:
				_acted = true
				_game.player.reset_to(_ball + Vector3(0.0, 0.0, -40.0))
			_sample_chaser(_units[0])
			if _seen.has("recover") and is_instance_valid(_units[1]) and _units[1].state_name() == "recover" and state == "recover":
				_stage_done = true
		1:
			if not _acted and state == "windup" and first.telegraph() != null:
				_acted = true
				first.knock(Vector3.RIGHT, 400.0)
			elif _acted and state == "recover":
				_stage_done = true
		2:
			if state == "windup":
				first.take_damage(100000.0)
				_stage_done = true
		3:
			if first.shots > 0:
				_stage_done = true
		4:
			if first._muzzle_material.emission_energy_multiplier > 1.5:
				first.take_damage(100000.0)
				_stage_done = true
		5:
			if _seen.has("live") and state == "roam":
				_stage_done = true
		6:
			if not _acted and state == "warn" and first.telegraph() != null:
				_acted = true
				first.knock(Vector3.RIGHT, 400.0)
			elif _acted and state == "roam":
				_stage_done = true
		7:
			if not _hits.is_empty() and state == "recover":
				_stage_done = true


# Each tick of the wind-up, the fact's progress must be the lobber's public charge, and
# moving the muzzle glow away from its formula must not move the fact.
func _observe_charge(lobber) -> void:
	var facts: Dictionary = lobber.attack_facts()
	if facts.is_empty() or facts["phase"] != "windup":
		return
	_charge_ticks += 1
	if not is_equal_approx(float(facts["progress"]), lobber.charge):
		_charge_bad.append("tick %d: progress %.4f vs charge %.4f" % [_ticks, facts["progress"], lobber.charge])
	# Force the glow off its formula and poll again in this same tick, so a fact that read the
	# glow would pick the forced value up; the fact must still equal the charge.
	lobber._muzzle_material.emission_energy_multiplier = 77.0
	lobber._facts_poll()
	_glow_ticks += 1
	var forced: Dictionary = lobber.attack_facts()
	if forced.is_empty() or not is_equal_approx(float(forced["progress"]), lobber.charge):
		_glow_bad.append("tick %d: progress %s vs charge %.4f" % [_ticks, forced.get("progress", "none"), lobber.charge])


func _inside(d: Dictionary, p: Vector3) -> bool:
	var flat := Vector3(p.x - d["centre"].x, 0.0, p.z - d["centre"].z)
	if d["form"] == "lane":
		var along := flat.dot(d["dir"])
		if along < d["back"] or along > d["length"]:
			return false
		return (flat - d["dir"] * along).length() <= d["half_width"]
	return flat.length() >= d["r_in"] and flat.length() <= d["r_out"]


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, Telegraph.ground_under(_ctx.terrain, p) + 0.5, p.z)


# Compares the published geometry with the telegraph's own hit test on points inside,
# on the edge and outside the shape.
func _agree(d: Dictionary, tele: Node3D) -> bool:
	var points: Array = []
	if d["form"] == "lane":
		var side: Vector3 = d["dir"].cross(Vector3.UP)
		for f in FRACTIONS:
			var on: Vector3 = d["centre"] + d["dir"] * d["length"] * f
			points.append(on)
			points.append(on + side * d["half_width"] * 0.95)
			points.append(on + side * d["half_width"] * 1.05)
		points.append(d["centre"] - d["dir"] * 0.5)
		points.append(d["centre"] + d["dir"] * (d["length"] + 0.5))
	else:
		for f in FRACTIONS:
			points.append(d["centre"] + Vector3.RIGHT * d["r_out"] * f)
		points.append(d["centre"] + Vector3.RIGHT * d["r_out"] * 1.05)
	for p in points:
		var q := _ground(p)
		if _inside(d, q) != tele.contains(q):
			return false
	return true


func _sample_chaser(unit: Node) -> void:
	var tele = unit.telegraph()
	var facts: Dictionary = unit.attack_facts() if unit.has_method("attack_facts") else {}
	if tele == null or facts.is_empty():
		return
	for f in FRACTIONS:
		var key := "sample%s" % f
		if not _sampled.has(key) and tele.progress >= f:
			var d: Dictionary = facts["geometry"]
			var same: bool = d == tele.descriptor() and absf(float(facts["progress"]) - tele.progress) < 0.0001
			_sampled[key] = same and _agree(d, tele)
			_sampled[key + "d"] = "progress %.3f, geometry equal %s, hit test agrees %s" % [tele.progress, same, _agree(d, tele)]


func _judge() -> void:
	match _stage:
		0:
			_judge_chaser_pair()
		1:
			var ph := _phases(0)
			_report("chaser_knock_cancels", ph == ["windup", "cancelled"],
				"a knocked wind-up publishes %s" % [ph])
		2:
			_report("chaser_kill_cancels", _phases(0) == ["windup", "cancelled"],
				"a killed wind-up publishes %s" % [_phases(0)])
		3:
			_judge_lobber()
		4:
			_report("lobber_kill_cancels", _phases(0) == ["windup", "cancelled"],
				"a killed lobber wind-up publishes %s" % [_phases(0)])
		5:
			var facts: Array = _log[0]
			var ph := _phases(0)
			_report("counter_phases", ph == ["windup", "strike", "recover"], "the mag trapper publishes %s" % [ph])
			_report("counter_row", facts.size() > 0 and facts[0]["row"] == "E05", "row %s" % [facts[0]["row"] if facts.size() > 0 else "none"])
		7:
			_judge_damage()
		6:
			_report("counter_cancel", _phases(0) == ["windup", "cancelled"], "a knocked counter wind-up publishes %s" % [_phases(0)])


func _judge_chaser_pair() -> void:
	for i in 2:
		var facts: Array = _log[i]
		_report("chaser%d_phases" % i, _phases(i) == ["windup", "strike", "recover"], "phases %s" % [_phases(i)])
		_report("chaser%d_row" % i, facts.size() > 0 and facts[0]["row"] == "E01" and facts[0]["owner"] == "chaser",
			"row %s" % [facts[0]["row"] if facts.size() > 0 else "none"])
		var ids := {}
		for f in facts:
			ids[f["instance"]] = true
		_report("chaser%d_one_instance" % i, ids.size() == 1, "one instance across the attack: %s" % [ids.keys()])
	var a: Array = _log[0]
	var b: Array = _log[1]
	_report("distinct_ids", a.size() > 0 and b.size() > 0 and a[0]["instance"] != b[0]["instance"],
		"two lunges got instances %s and %s" % [a[0]["instance"] if a.size() > 0 else "none", b[0]["instance"] if b.size() > 0 else "none"])
	_report("overlap", _max_open >= 2, "%d attacks open at once" % _max_open)
	var unique := {}
	var windups := 0
	for entry in _all_ids:
		if entry[2] == "windup":
			windups += 1
			unique[entry[1]] = true
	_report("ids_unique", windups >= 2 and unique.size() == windups, "%d wind-ups, %d distinct instances" % [windups, unique.size()])
	for f in FRACTIONS:
		var key := "sample%s" % f
		_report("geometry_%d" % int(f * 100.0), _sampled.get(key, false), String(_sampled.get(key + "d", "never sampled")))
	var strike: Dictionary = a[1] if a.size() > 1 else {}
	_report("strike_live", strike.get("progress", 0.0) >= 1.0 and strike.get("geometry", {}).get("live", false),
		"strike carries progress %s and live %s" % [strike.get("progress", "none"), strike.get("geometry", {}).get("live", "none")])


func _judge_lobber() -> void:
	var facts: Array = _log[0]
	_report("lobber_phases", _phases(0) == ["windup", "strike", "recover"], "phases %s" % [_phases(0)])
	if facts.size() < 3:
		return
	_report("lobber_row", facts[0]["row"] == "E02" and facts[0]["owner"] == "lobber", "row %s" % facts[0]["row"])
	_report("lobber_uncommitted", facts[0]["committed"] == false and facts[0]["geometry"].is_empty() and facts[0]["progress"] > 0.0,
		"wind-up aim uncommitted: committed %s, geometry %s, progress %.3f" % [facts[0]["committed"], facts[0]["geometry"], facts[0]["progress"]])
	var strike: Dictionary = facts[1]
	var ring: Dictionary = _shell.get("descriptor", {})
	_report("lobber_strike_committed", strike["committed"] == true and not ring.is_empty() and strike["geometry"] == ring,
		"strike committed %s with geometry equal to the shell telegraph's descriptor: %s" % [strike["committed"], strike["geometry"] == ring])
	_report("lobber_strike_form", ring.get("form", "") == "radial" and is_equal_approx(float(ring.get("r_out", 0.0)), 3.6),
		"the ring is the shell's blast ring: %s r_out %s" % [ring.get("form", "none"), ring.get("r_out", "none")])
	_report("lobber_hit_test", _shell.get("agree", false), "published ring agrees with the shell telegraph's hit test at 0, 50, 98, 102 and 150 percent of radius")
	_report("lobber_recover_committed", facts[2]["committed"] == true and facts[2]["geometry"] == ring, "recover keeps the committed ring")
	_report("lobber_progress_is_charge", _charge_ticks >= 5 and _charge_bad.is_empty(),
		"wind-up progress equals the public charge on %d ticks %s" % [_charge_ticks, _charge_bad.slice(0, 3)])
	_report("lobber_glow_independent", _glow_ticks >= 5 and _glow_bad.is_empty(),
		"the glow was forced to 77 and the fact re-polled in the same tick on %d wind-up ticks; progress still equalled the charge %s" % [_glow_ticks, _glow_bad.slice(0, 3)])
	var src := FileAccess.get_file_as_string("res://src/combat/enemy.gd")
	_report("lobber_no_glow_inversion", not src.contains("_muzzle") \
			and not src.contains("LOBBER_GLOW") and not src.contains("LOBBER_MIN_CHARGE"),
		"enemy.gd names neither the muzzle material nor the glow constants")
	_report("lobber_instance", facts[0]["instance"] == facts[1]["instance"] and facts[1]["instance"] == facts[2]["instance"], "one instance")


func _judge_damage() -> void:
	_report("chaser_damage", _hits.size() == 1 and is_equal_approx(_hits[0][0], 9.0) and is_equal_approx(Chaser.DAMAGE, 9.0),
		"a landed lunge emits hit_player %s (base: one hit of 9.0)" % [_hits])


func _finish() -> bool:
	var line := "|".join(PackedStringArray(_timeline))
	print("TIMELINE %s" % line)
	_report("timeline", line.md5_text() == TIMELINE_GOLDEN, "attack timing and lane geometry match base (md5 %s)" % line.md5_text())
	var ok := _failures == 0
	print("attack_facts_enemy_test: %s" % ("PASS" if ok else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if ok else 1)
	return true
