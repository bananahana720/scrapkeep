# smoke: timeout=300s (one full attack and recovery per pack kind)
extends SceneTree

# SQ1 pack telegraph record (W13-INTEGRATION-3.md SQ1): every pack-kind attack has one
# record (pre-shoot, recovery, cooldown, radius, marker class, band class) in
# src/combat/telegraph_record.gd.
# - Structure: one row per pack kind, fields filled and finite, a known marker class and
#   band class, pre-shoot at or above the reaction floor, and a pre-shoot outside its class
#   band only with a logged reason.
# - The record matches the code: a counter.gd kind's pre-shoot is its warn_seconds and its
#   cooldown is rest_seconds less the shared recovery; the three other pack kinds retain
#   their existing warning and cycle constants.
# - Ordinary attacks read one recovery value: every pack kind's recovery read is
#   TelegraphRecord.RECOVERY, and one live attack per kind ends in a recovery that lasts
#   RECOVERY within one tick, standing still, with no new warning inside it. The report
#   prints each kind's recovery before (the record's recovery_before) and after (measured).
# - Warden attacks sit on the listed exception set: every warden-group ATTACK_ROWS id is on
#   it, and no pack attack is.
# - LEGIBILITY section 2's pack list equals the record on every kind.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Roster := preload("res://src/combat/roster.gd")
const Counter := preload("res://src/combat/counter.gd")
const Chaser := preload("res://src/combat/chaser.gd")
const Lobber := preload("res://src/combat/lobber.gd")
const Swarm := preload("res://src/combat/swarm.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const ChallengeDials := preload("res://src/core/challenge_dials.gd")
const T := preload("res://tests/support/t.gd")
const RECORD_PATH := "res://src/combat/telegraph_record.gd"
const LEGIBILITY_PATH := "res://design-v3/LEGIBILITY.md"

const SPEED := 8
const BASE_TICKS := 90
const OFFSET := Vector3(12.0, 0.0, 0.0)
# The ballast heavy holds its rim instead of closing on the ball, so it stands in its slam reach.
const BALLAST_OFFSET := Vector3(3.5, 0.0, 0.0)
const FRAME_LIMIT := 1500
# Standing: a hover unit settles a few centimetres after a dive; a walk would cover
# walk_speed x RECOVERY, about 2.9 m.
const STILL := 0.25

var _game
var _test := T.new("pack_telegraph_record_test")
var _record
var _ball_at := Vector3.ZERO
var _tick := 1.0 / 90.0
var _phases: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _boot() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	# The ball is held still, so world 1's silt boils arm under it. In about 1 run in 12 one erupted
	# beside a recovering swarm, and its knock scattered the drones (swarm_remnant.knock), which read
	# as the pack moving and warning in its recovery. Only the pack's own tail is measured here.
	ChallengeDials.set_overrides({"hazard.boil_by_stage": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]})
	_game.ctx.rng.seed = 11
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _frames(3)
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()
	for node in [_game.presentation, _game.hud, _game.screens, _game.notes, _game.panel, _game.camera, _game.world,
			_game.build, _game.boss, _game.beacon, _game.run_log, _game.codex, _game.progress]:
		if node != null:
			node.process_mode = Node.PROCESS_MODE_DISABLED
	Engine.physics_ticks_per_second = BASE_TICKS * SPEED
	Engine.max_physics_steps_per_frame = SPEED * 2
	Engine.time_scale = float(SPEED)
	await _frames(2)
	# The step a node is handed, time scale included.
	_tick = root.get_physics_process_delta_time()
	var ctx = _game.ctx
	_ball_at = ctx.terrain.drop_point(ctx.terrain.spawn_point(1).x, ctx.terrain.spawn_point(1).z, 1.05)


func _pack_kinds() -> Array:
	var kinds: Array = []
	for id in Roster.ROWS:
		var kind := String(id)
		# The Warden, the vault and the miniboss keep their own records; a row with no
		# telegraph (the Linker, the Foreman) never attacks.
		if kind in ["warden", "vault", "miniboss"] or int(Roster.row(kind)["telegraph"]) < 0:
			continue
		# A kind whose row has no telegraph never attacks (the Splitter only buds its pods).
		if int(Roster.row(kind).get("telegraph", 0)) == -1:
			continue
		if kind in ["chaser", "lobber"] or _game.combat.fleet.makes(kind):
			kinds.append(kind)
	return kinds


func _finite(v) -> bool:
	return (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and is_finite(float(v))


# --- Structure ---------------------------------------------------------------------------

func _structure(kinds: Array) -> void:
	_test.check("shared recovery constant", _finite(_record.RECOVERY) and float(_record.RECOVERY) > 0.0,
		"RECOVERY %.2f s (start value, comps/roboquest/enemies-and-telegraphs.md:61)" % _record.RECOVERY)
	_test.check("reaction floor", absf(float(_record.REACTION_FLOOR) - 0.4) < 0.0001, "REACTION_FLOOR %.2f s" % _record.REACTION_FLOOR)
	_test.check("bands", _record.BANDS.size() == 3 and _record.BANDS.has("area_burst") and _record.BANDS.has("projectile") and _record.BANDS.has("ray"),
		"BANDS %s" % [_record.BANDS])
	_test.check("rows exist", _record.ROWS.size() == kinds.size() and kinds.size() >= 10,
		"%d rows for %d pack kinds" % [_record.ROWS.size(), kinds.size()])
	var seen := {}
	for id in _record.ROWS:
		var row: Dictionary = _record.ROWS[id]
		var kind := String(row.get("kind", ""))
		var problems: Array = []
		if not kind in kinds:
			problems.append("kind %s is not a pack kind" % kind)
		if seen.has(kind):
			problems.append("kind twice")
		seen[kind] = true
		for field in ["pre_shoot", "cooldown", "radius", "recovery_before"]:
			if not _finite(row.get(field)) or float(row.get(field)) < 0.0:
				problems.append(field)
		if not String(row.get("marker", "")) in _record.MARKERS:
			problems.append("marker")
		if not _record.BANDS.has(String(row.get("band", ""))):
			problems.append("band")
		if float(row.get("pre_shoot", 0.0)) < float(_record.REACTION_FLOOR):
			problems.append("pre_shoot under the floor")
		if not _record.in_band(id) and String(row.get("reason", "")).strip_edges() == "":
			problems.append("outside its band with no reason")
		if not EventKinds.ATTACK_ROWS.has(id) or String(EventKinds.ATTACK_ROWS[id]["owner"]) != kind:
			problems.append("attack row %s is not %s's" % [id, kind])
		var recovery: float = _record.recovery(kind)
		if not _finite(recovery):
			problems.append("recovery")
		_test.check(id + " " + kind + " record row", problems.is_empty(), "problems %s" % [problems])
	for kind in kinds:
		_test.check(kind + " record uses shared recovery", absf(_record.recovery(kind) - float(_record.RECOVERY)) < 0.0001,
			"record %.2f s, shared %.2f s" % [_record.recovery(kind), _record.RECOVERY])


# --- The record against the code -------------------------------------------------------

func _spawn(kind: String):
	_game.player.reset_to(_ball_at)
	var at: Vector3 = _ball_at + (BALLAST_OFFSET if kind == "ballast_heavy" else OFFSET)
	# The mind hand braces against the ball's top habit; give it one to read.
	if kind == "mind_hand":
		_game.combat.fleet.habits.add("ram", 5.0)
	return _game.combat.spawn_enemy(kind, _game.ctx.terrain.drop_point(at.x, at.z, 1.8))


func _clear_field() -> void:
	for group in ["enemy", "enemy_shot", "telegraph"]:
		for node in get_nodes_in_group(group):
			if is_instance_valid(node):
				node.free()


func _own_numbers(kind: String) -> Dictionary:
	match kind:
		"chaser":
			return {"pre_shoot": Chaser.WINDUP, "cooldown": Chaser.REST, "recovery": Chaser.RECOVER}
		"lobber":
			return {"pre_shoot": Lobber.FLIGHT, "cooldown": Lobber.CYCLE - Lobber.TELEGRAPH}
		"swarm_remnant":
			return {"pre_shoot": Swarm.LOCK_WARN, "cooldown": Swarm.REST}
	return {}


func _on_phase(facts: Dictionary) -> void:
	_phases.append([Engine.get_physics_frames(), String(facts["phase"])])


func _recovering(enemy, swarm) -> bool:
	if enemy is Chaser:
		return enemy.state == Chaser.State.RECOVER
	var clock = swarm if swarm != null else enemy
	if clock.has_method("recovering"):
		return clock.recovering()
	return false


func _recovery_read(enemy, swarm) -> float:
	if enemy is Chaser:
		return Chaser.RECOVER
	var value = (swarm if swarm != null else enemy).get("recovery_seconds")
	return float(value) if value != null else -1.0


func _warning(enemy, swarm) -> bool:
	if swarm != null:
		return swarm.state != Swarm.State.FORMING or swarm.lane() != null
	if enemy is Chaser:
		return enemy.state != Chaser.State.RECOVER
	if enemy is Lobber:
		return enemy.charge > 0.0 or enemy.shots > 1
	return enemy.phase != Counter.Phase.ROAM


# One live attack per pack kind: measure its actual standing tail, including every drone.
func _recovery(kind: String) -> Dictionary:
	_phases.clear()
	var enemy = _spawn(kind)
	for unit in get_nodes_in_group("enemy"):
		unit.hp = 1.0e6
	enemy.attack_phase.connect(_on_phase)
	var swarm = enemy.get("swarm") if kind == "swarm_remnant" else null
	if enemy is Counter or enemy is Chaser:
		enemy._rest = 0.0
	if enemy is Lobber:
		enemy._clock = Lobber.CYCLE - _tick * 0.5
	if swarm != null:
		swarm._rest = 0.0
		swarm.t = Swarm.FORM_MAX
	var diving := false
	var ended := -1
	var frames := 0
	var positions := {}
	var drift := 0.0
	var warned_inside := false
	var ball_hold := _ball_at
	var out := {"skip": "no recover in %d frames" % FRAME_LIMIT}
	for f in FRAME_LIMIT:
		await physics_frame
		if f % 60 == 59:
			_game.player.reset_to(ball_hold)
		if not is_instance_valid(enemy):
			out = {"skip": "unit gone"}
			break
		if ended < 0:
			if swarm != null:
				if diving and swarm.state == Swarm.State.FORMING:
					ended = Engine.get_physics_frames()
				diving = swarm.state == Swarm.State.DIVING
			for p in _phases:
				if enemy is Chaser and p[1] == "strike":
					ball_hold = _ball_at + Vector3(0.0, 0.0, 8.0)
					_game.player.reset_to(ball_hold)
				if swarm == null and p[1] == "recover":
					ended = int(p[0])
			if ended >= 0:
				# A Dispatcher's landed chaser is a new unit with its own attack, not part of the tail.
				for unit in get_nodes_in_group("enemy"):
					if not unit.has_meta("dispatched_by"):
						positions[unit] = unit.global_position
				if _recovering(enemy, swarm):
					frames = 1
					# An expired cycle must still be unable to start another attack in the tail.
					if enemy is Lobber:
						enemy._clock = Lobber.CYCLE - _tick * 0.5
					if swarm != null:
						swarm._rest = 0.0
						swarm.t = Swarm.FORM_MAX
				else:
					out = {"seconds": 0.0, "drift": 0.0, "warned_inside": false, "reads": _recovery_read(enemy, swarm)}
					break
			continue
		if _recovering(enemy, swarm):
			frames += 1
			for unit in positions:
				var flat: Vector3 = unit.global_position - Vector3(positions[unit])
				drift = maxf(drift, Vector2(flat.x, flat.z).length())
			if _warning(enemy, swarm):
				warned_inside = true
		else:
			out = {"seconds": float(frames) * _tick, "drift": drift, "warned_inside": warned_inside,
				"reads": _recovery_read(enemy, swarm)}
			break
	_clear_field()
	await physics_frame
	return out


func _against_code(kinds: Array) -> void:
	print("kind | attack | recovery before s | recovery after (measured) s | shared read s | drift m")
	for kind in kinds:
		var id: String = _record.id_of(kind)
		var row: Dictionary = _record.ROWS.get(id, {})
		if kind in ["chaser", "lobber", "swarm_remnant"]:
			var own := _own_numbers(kind)
			var ok: bool = not own.is_empty() and absf(float(row.get("pre_shoot", -1.0)) - float(own["pre_shoot"])) < 0.0001 \
				and absf(float(row.get("cooldown", -1.0)) - float(own["cooldown"])) < 0.0001
			_test.check(kind + " existing warn and cycle numbers match the record", ok, "record %s, code %s" % [row, own])
			await _check_recovery(kind, id, row)
			continue
		var probe = _spawn(kind)
		var is_counter: bool = probe is Counter
		var warn: float = probe.warn_seconds if is_counter else -1.0
		var rest: float = probe.rest_seconds if is_counter else -1.0
		var reads: float = float(probe.get("recovery_seconds")) if probe.get("recovery_seconds") != null else -1.0
		var probe_wants: bool = is_counter and probe._wants_attack(Vector3.FORWARD * 4.0)
		_clear_field()
		await physics_frame
		_test.check(kind + " is a counter.gd kind", is_counter, "script %s" % kind)
		if not is_counter:
			continue
		_test.check(kind + " pre-shoot is its warn", absf(float(row.get("pre_shoot", -1.0)) - warn) < 0.0001,
			"record %.2f, warn_seconds %.2f" % [row.get("pre_shoot", -1.0), warn])
		if _record.PLAYER_STARTED.has(id):
			_test.check(kind + " is player-started with no cooldown", float(row.get("cooldown", -1.0)) == 0.0 and not probe_wants,
				"record cooldown %.2f, attacks on its own %s" % [row.get("cooldown", -1.0), probe_wants])
			continue
		_test.check(kind + " cooldown is its rest less the recovery", absf(float(row.get("cooldown", -1.0)) - (rest - float(_record.RECOVERY))) < 0.0001,
			"record %.2f, rest_seconds %.2f - recovery %.2f" % [row.get("cooldown", -1.0), rest, _record.RECOVERY])
		_test.check(kind + " reads the shared recovery", absf(reads - float(_record.RECOVERY)) < 0.0001,
			"recovery_seconds %.2f, RECOVERY %.2f" % [reads, _record.RECOVERY])
		await _check_recovery(kind, id, row)


func _check_recovery(kind: String, id: String, row: Dictionary) -> void:
	var m := await _recovery(kind)
	if m.has("skip"):
		_test.check(kind + " recovery measured", false, String(m["skip"]))
		return
	print("%s | %s | recovery before %.2f | after %.3f | read %.2f | drift %.3f" % [kind, id,
		row.get("recovery_before", -1.0), m["seconds"], m["reads"], m["drift"]])
	_test.check(kind + " reads the shared recovery", absf(float(m["reads"]) - float(_record.RECOVERY)) < 0.0001,
		"recovery read %.2f, RECOVERY %.2f" % [m["reads"], _record.RECOVERY])
	_test.check(kind + " recovery lasts the shared value", absf(float(m["seconds"]) - float(_record.RECOVERY)) <= _tick + 0.0001,
		"measured %.3f s, RECOVERY %.2f s, within one tick" % [m["seconds"], _record.RECOVERY])
	_test.check(kind + " stands still and starts nothing in recovery", float(m["seconds"]) > 0.0 and float(m["drift"]) <= STILL and not bool(m["warned_inside"]),
		"drift %.3f m (at most %.2f), warned inside %s" % [m["drift"], STILL, m["warned_inside"]])


# --- Exceptions and LEGIBILITY ---------------------------------------------------------

func _exceptions() -> void:
	var warden_ids: Array = []
	for id in EventKinds.ATTACK_ROWS:
		if String(EventKinds.ATTACK_ROWS[id]["group"]) == "warden":
			warden_ids.append(String(id))
	var missing: Array = warden_ids.filter(func(id): return not _record.WARDEN_EXCEPTIONS.has(id))
	var pack: Array = _record.WARDEN_EXCEPTIONS.keys().filter(func(id): return _record.ROWS.has(id))
	print("Warden exception set: %s" % [_record.WARDEN_EXCEPTIONS.keys()])
	_test.check("every Warden attack on the exception set", missing.is_empty() and not warden_ids.is_empty(),
		"%d warden rows, missing %s" % [warden_ids.size(), missing])
	_test.check("no pack attack on the exception set", pack.is_empty(), "pack ids on it %s" % [pack])
	for id in _record.WARDEN_EXCEPTIONS:
		_test.check(String(id) + " exception reason", String(_record.WARDEN_EXCEPTIONS[id]).strip_edges() != "",
			String(_record.WARDEN_EXCEPTIONS[id]))


func _legibility() -> void:
	var rows := {}
	var text := FileAccess.get_file_as_string(LEGIBILITY_PATH)
	var in_section := false
	for line in text.split("\n"):
		if line.begins_with("## "):
			in_section = line.begins_with("## 2.")
			continue
		if not in_section or not line.begins_with("| E"):
			continue
		var cells: Array = []
		for cell in line.split("|"):
			cells.append(cell.strip_edges().replace("`", ""))
		if cells.size() >= 8:
			rows[cells[1]] = {"kind": cells[2], "marker": cells[3], "band": cells[4], "pre_shoot": cells[5], "recovery": cells[7]}
	var mismatched: Array = []
	for id in _record.ROWS:
		var row: Dictionary = _record.ROWS[id]
		var want := {"kind": String(row["kind"]), "marker": String(row["marker"]), "band": String(row["band"]),
			"pre_shoot": "%.2f" % float(row["pre_shoot"]), "recovery": "%.2f" % _record.recovery(String(row["kind"]))}
		if rows.get(id, {}) != want:
			mismatched.append("%s record %s legibility %s" % [id, want, rows.get(id, "missing")])
	_test.check("LEGIBILITY section 2 lists every record row", mismatched.is_empty() and rows.size() == _record.ROWS.size(),
		"%d LEGIBILITY rows, %d record rows; mismatched %s" % [rows.size(), _record.ROWS.size(), mismatched])


func _run() -> void:
	if not ResourceLoader.exists(RECORD_PATH):
		_test.check("telegraph record exists", false, "%s missing" % RECORD_PATH)
		quit(_test.verdict())
		return
	_record = load(RECORD_PATH)
	await _boot()
	var kinds := _pack_kinds()
	_structure(kinds)
	_exceptions()
	_legibility()
	await _against_code(kinds)
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = BASE_TICKS
	_game.free()
	quit(_test.verdict())
