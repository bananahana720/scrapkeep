# smoke: solo timeout=360s fixed-fps=90 (50 solo spawns of each pack kind, about 1,100 attacks; 260 s wall measured 2026-10-11 on a loaded machine)
extends SceneTree

# SQ1 pack-kind telegraph timing (W13-INTEGRATION-3.md SQ1; the lab measure of
# comps/gunfire/enemies-and-bosses.md:89 and comps/roboquest/enemies-and-telegraphs.md:110).
# The Warden kinds keep their own telegraph_timing_<kind>_test files (decisions.tsv 486c).
#
# Each pack kind is spawned alone, 50 times, beside a ball held still on one spot. Per spawn:
# - telegraph start is the tick its committed geometry first exists: the attack-facts windup
#   with geometry (counter.gd kinds, the chaser), the shell ring's release (the lobber, whose
#   wind-up is a charge on its body), or the formation lane's lock (the swarm remnant);
# - damage onset is the first tick that geometry can hurt: the strike fact, which opens the
#   live window (a thrown tool still flies after it, so its flight is extra margin), the
#   shell's landing, or the formation's dive;
# - lead = onset - start, at least TelegraphRecord.REACTION_FLOOR on every spawn, and within
#   one tick of the record's pre_shoot; no hit lands on the ball before onset;
# - overlap = intersection over union, on a ground grid, of the area drawn at telegraph start
#   (the windup descriptor, the fields the painter reads) and the area the hit test holds at
#   onset (Telegraph.contains; a wave's front swept over its run); at least OVERLAP_FLOOR;
# - the marker class read from the committed geometry and the band class read from the attack
#   type equal the record's, the same on all 50 spawns, and the radius matches the record.
# LEGIBILITY section 2's pack list must equal this report on every kind.
#
# Speed: every physics step stays 1/90 s (time_scale / ticks per second); the test runs
# SPEED steps per wall tick and checks the step length before it trusts a single number.
# Presentation, HUD and world props are paused: nothing they own times an attack.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Roster := preload("res://src/combat/roster.gd")
const Counter := preload("res://src/combat/counter.gd")
const Lobber := preload("res://src/combat/lobber.gd")
const Swarm := preload("res://src/combat/swarm.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const T := preload("res://tests/support/t.gd")
const RECORD_PATH := "res://src/combat/telegraph_record.gd"
const LEGIBILITY_PATH := "res://design-v3/LEGIBILITY.md"

const SPAWNS := 50
const SPEED := 8
const BASE_TICKS := 90
const OFFSET := Vector3(12.0, 0.0, 0.0)
# The ballast heavy holds its rim instead of closing on the ball, so it stands in its slam reach.
const BALLAST_OFFSET := Vector3(3.5, 0.0, 0.0)
const LOBBER_OFFSET := Vector3(15.0, 0.0, 0.0)
const FRAME_LIMIT := 600
const GRID := 16
# A wave's front is swept over this many evenly spaced ages from leaving to its rim.
const WAVE_SAMPLES := 9
# The control: the same drawn area moved this share of its size must fall under the floor.
const CONTROL_SHIFT := 0.5

var _game
var _test := T.new("telegraph_timing_pack_test")
var _record
var _ball_at := Vector3.ZERO
var _tick := 1.0 / 90.0
var _facts: Array = []
var _hits: Array = []
var _landed := -1
# The overlap control runs on the first measured spawn of each kind.
var _control_due := false


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _boot() -> bool:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
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
	return _test.check("one physics step is 1/90 s", absf(_tick - 1.0 / float(BASE_TICKS)) < 0.000001,
		"step %.6f s at %d ticks/s and time scale %.1f" % [_tick, Engine.physics_ticks_per_second, Engine.time_scale])


# The pack kinds: every roster kind the spawner builds, less the set pieces (the Warden, the
# vault) and the surge miniboss, which the event director sends as its own beat, and any
# row with no telegraph (the Linker never attacks).
func _pack_kinds() -> Array:
	var kinds: Array = []
	for id in Roster.ROWS:
		var kind := String(id)
		if kind in ["warden", "vault", "miniboss"] or int(Roster.row(kind)["telegraph"]) < 0:
			continue
		# A kind whose row has no telegraph never attacks (the Splitter only buds its pods).
		if int(Roster.row(kind).get("telegraph", 0)) == -1:
			continue
		if kind in ["chaser", "lobber"] or _game.combat.fleet.makes(kind):
			kinds.append(kind)
	return kinds


# --- Geometry --------------------------------------------------------------------------

# Whether a ground point lies in the area a descriptor draws (the painter's fields).
func _drawn(d: Dictionary, p: Vector3) -> bool:
	var c: Vector3 = d["centre"]
	var flat := Vector3(p.x - c.x, 0.0, p.z - c.z)
	if String(d["form"]) == "lane":
		var dir: Vector3 = d["dir"]
		var along := flat.dot(dir)
		if along < -float(d.get("back", 0.0)) or along > float(d["length"]):
			return false
		return (flat - dir * along).length() <= float(d["half_width"])
	var r := flat.length()
	if r > float(d["r_out"]) or r < float(d["r_in"]):
		return false
	var span := float(d["a1"]) - float(d["a0"])
	if span >= TAU - 0.0001 or r < 0.01:
		return true
	var a := fposmod(atan2(flat.z, flat.x) - float(d["a0"]), TAU)
	return a <= span


func _bounds(d: Dictionary) -> Rect2:
	var c: Vector3 = d["centre"]
	if String(d["form"]) == "lane":
		var dir: Vector3 = d["dir"]
		var tip: Vector3 = c + dir * float(d["length"])
		var side := Vector3(-dir.z, 0.0, dir.x) * float(d["half_width"])
		var box := Rect2(Vector2(c.x, c.z), Vector2.ZERO)
		for q in [c + side, c - side, tip + side, tip - side]:
			box = box.expand(Vector2(q.x, q.z))
		return box
	var r := float(d["r_out"])
	return Rect2(Vector2(c.x - r, c.z - r), Vector2(2.0 * r, 2.0 * r))


func _ground(x: float, z: float, terrain) -> Vector3:
	var p := Vector3(x, 0.0, z)
	p.y = Telegraph.ground_under(terrain, p) + 0.3
	return p


# Intersection over union of the drawn area (descriptor at telegraph start) and the hurt area
# (the live node's hit test at onset; a wave swept over its front's run).
func _overlap(drawn: Dictionary, tele: Node3D) -> float:
	var box := _bounds(drawn).merge(_bounds(tele.descriptor())).grow(0.5)
	var terrain = tele.terrain
	var ages: Array = [null]
	if tele.type == Threat.Type.WAVE:
		ages = []
		var run: float = tele.radius / maxf(tele.speed, 0.001)
		for i in WAVE_SAMPLES:
			ages.append(tele.warn_seconds + run * float(i) / float(WAVE_SAMPLES - 1))
	var saved_age: float = tele.age
	var both := 0
	var either := 0
	for ix in GRID:
		for iz in GRID:
			var x := box.position.x + box.size.x * (float(ix) + 0.5) / float(GRID)
			var z := box.position.y + box.size.y * (float(iz) + 0.5) / float(GRID)
			var p := _ground(x, z, terrain)
			var drawn_in := _drawn(drawn, p)
			var hurt_in := false
			for age in ages:
				if age != null:
					tele.age = age
				if tele.contains(p):
					hurt_in = true
					break
			if drawn_in and hurt_in:
				both += 1
			if drawn_in or hurt_in:
				either += 1
	tele.age = saved_age
	return float(both) / float(maxi(either, 1))


# The drawn area moved sideways by CONTROL_SHIFT of its size: a telegraph that drew here
# would not mean what it shows, and the overlap measure must say so.
func _shifted(d: Dictionary) -> Dictionary:
	var moved := d.duplicate()
	var size: float = float(d["half_width"]) * 2.0 if String(d["form"]) == "lane" else float(d["r_out"]) * 2.0
	var side := Vector3.RIGHT
	if String(d["form"]) == "lane":
		var dir: Vector3 = d["dir"]
		side = Vector3(-dir.z, 0.0, dir.x)
	moved["centre"] = Vector3(d["centre"]) + side * size * CONTROL_SHIFT
	return moved


# --- One spawn ---------------------------------------------------------------------------

func _on_facts(facts: Dictionary) -> void:
	_facts.append({"frame": Engine.get_physics_frames(), "phase": facts["phase"], "row": facts["row"],
		"geometry": facts["geometry"], "committed": facts["committed"]})


func _on_hit(amount: float, _shove: Vector3) -> void:
	if amount > 0.0:
		_hits.append(Engine.get_physics_frames())


func _clear_field() -> void:
	for group in ["enemy", "enemy_shot", "telegraph"]:
		for node in get_nodes_in_group(group):
			if is_instance_valid(node):
				node.free()


func _spawn(kind: String):
	_game.player.reset_to(_ball_at)
	var at: Vector3 = _ball_at + (LOBBER_OFFSET if kind == "lobber" else BALLAST_OFFSET if kind == "ballast_heavy" else OFFSET)
	# The mind hand braces against the ball's top habit; give it one to read.
	if kind == "mind_hand":
		_game.combat.fleet.habits.add("ram", 5.0)
	var enemy = _game.combat.spawn_enemy(kind, _game.ctx.terrain.drop_point(at.x, at.z, 1.8))
	return enemy


# One spawn of a kind, alone on the field: {lead, overlap, drawn, row, early, ...} or {"skip"}.
func _measure(kind: String) -> Dictionary:
	_facts.clear()
	_hits.clear()
	_landed = -1
	var enemy = _spawn(kind)
	if enemy == null:
		return {"skip": "spawn returned null"}
	var units: Array = get_nodes_in_group("enemy")
	for unit in units:
		unit.hp = 1.0e6
		if unit.has_signal("hit_player"):
			unit.hit_player.connect(_on_hit)
	enemy.attack_phase.connect(_on_facts)
	if enemy is Counter:
		enemy._rest = 0.0
	if kind == "lobber":
		enemy._clock = Lobber.CYCLE - _tick * 0.5
	var swarm = enemy.get("swarm") if kind == "swarm_remnant" else null
	if swarm != null:
		swarm._rest = 0.0
		swarm.t = Swarm.FORM_MAX
	var out := {"skip": "no attack in %d frames" % FRAME_LIMIT}
	var start := -1
	var drawn := {}
	var tele: Node3D = null
	var shell = null
	var control := -1.0
	for f in FRAME_LIMIT:
		await physics_frame
		var now := Engine.get_physics_frames()
		if f % 60 == 59:
			_game.player.reset_to(_ball_at)
		if swarm != null:
			if start < 0 and swarm.state == Swarm.State.LOCKED and swarm.lane() != null:
				start = now
				tele = swarm.lane()
				drawn = tele.descriptor()
			elif start >= 0 and swarm.state == Swarm.State.DIVING:
				out = {"start": start, "onset": now, "drawn": drawn, "row": "E17", "overlap": _overlap(drawn, tele)}
				break
			continue
		if kind == "lobber":
			if start < 0:
				for fact in _facts:
					if fact["phase"] == "strike" and bool(fact["committed"]):
						start = int(fact["frame"])
						drawn = fact["geometry"]
						for s in get_nodes_in_group("enemy_shot"):
							if s.get("lobber") == enemy and is_instance_valid(s.get("ring")):
								shell = s
						if shell != null:
							shell.hit_player.connect(_on_hit)
							shell.exploded.connect(func(_at: Vector3, _r: float, _hit: bool): _landed = Engine.get_physics_frames())
			elif shell != null and is_instance_valid(shell) and is_instance_valid(shell.ring) \
					and float(shell._age) + _tick * 1.5 >= float(shell.flight) and not out.has("overlap_pre"):
				out["overlap_pre"] = _overlap(drawn, shell.ring)
			if _landed >= 0:
				out = {"start": start, "onset": _landed, "drawn": drawn, "row": "E02", "overlap": float(out.get("overlap_pre", 0.0))}
				break
			continue
		for fact in _facts:
			if start < 0 and fact["phase"] == "windup" and bool(fact["committed"]):
				start = int(fact["frame"])
				drawn = fact["geometry"]
				tele = enemy.telegraph() if is_instance_valid(enemy) else null
			if start >= 0 and fact["phase"] == "strike":
				var live: Node3D = enemy.telegraph() if is_instance_valid(enemy) else null
				out = {"start": start, "onset": int(fact["frame"]), "drawn": drawn, "row": fact["row"],
					"overlap": _overlap(drawn, live) if live != null else 0.0, "same_node": live == tele}
				if live != null and _control_due:
					_control_due = false
					out["control"] = _overlap(_shifted(drawn), live)
				break
		if out.has("onset"):
			break
	if out.has("onset"):
		out["lead"] = float(int(out["onset"]) - int(out["start"])) * _tick
		out["early"] = _hits.filter(func(h): return h < int(out["onset"])).size()
	_clear_field()
	await physics_frame
	return out


# --- LEGIBILITY section 2 ---------------------------------------------------------------

# The pack list rows under section 2: | id | kind | marker | band | pre-shoot | ... |
func _legibility_rows() -> Dictionary:
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
		# cells[0] is empty (the leading pipe).
		if cells.size() >= 6:
			rows[cells[1]] = {"kind": cells[2], "marker": cells[3], "band": cells[4], "pre_shoot": cells[5]}
	return rows


# --- Run --------------------------------------------------------------------------------

func _run() -> void:
	if not ResourceLoader.exists(RECORD_PATH):
		_test.check("telegraph record exists", false, "%s missing" % RECORD_PATH)
		quit(_test.verdict())
		return
	_record = load(RECORD_PATH)
	if not await _boot():
		quit(_test.verdict())
		return
	var kinds := _pack_kinds()
	var recorded: Array = []
	for id in _record.ROWS:
		recorded.append(String(_record.ROWS[id]["kind"]))
	recorded.sort()
	var sorted_kinds := kinds.duplicate()
	sorted_kinds.sort()
	_test.check("one record per pack kind", recorded == sorted_kinds,
		"%d pack kinds %s; record kinds %s" % [kinds.size(), sorted_kinds, recorded])
	var report := {}
	var outside: Array = []
	print("kind | attack | spawns | lead min/max s | record pre-shoot | overlap min | marker | band | radius | early hits")
	for kind in kinds:
		var id: String = _record.id_of(kind)
		var rec: Dictionary = _record.ROWS.get(id, {})
		# A player-started attack never comes from a solo spawn; its own test drives it
		# (enemy_prop_crew_test: one INSTANT disc the roof's size, landing after its warning).
		if _record.PLAYER_STARTED.has(id):
			report[id] = {"kind": kind, "marker": String(rec.get("marker", "")), "band": String(rec.get("band", "")), "pre_shoot": "%.2f" % rec.get("pre_shoot", -1.0)}
			print("%s | %s | player-started, measured by its own test" % [kind, id])
			continue
		var leads: Array = []
		var overlaps: Array = []
		var markers := {}
		var bands := {}
		var radii := {}
		var rows := {}
		var early := 0
		var skips: Array = []
		var controls: Array = []
		_control_due = true
		for n in SPAWNS:
			var m := await _measure(kind)
			if m.has("control"):
				controls.append(float(m["control"]))
			if m.has("skip"):
				skips.append(m["skip"])
				continue
			leads.append(float(m["lead"]))
			overlaps.append(float(m["overlap"]))
			markers[_record.marker_of(m["drawn"])] = true
			bands[_record.band_of(int(m["drawn"]["type"]))] = true
			radii[snappedf(_record.size_of(m["drawn"]), 0.01)] = true
			rows[String(m["row"])] = true
			early += int(m["early"])
		var ok_count := leads.size() == SPAWNS
		var lead_min: float = leads.min() if ok_count else 0.0
		var lead_max: float = leads.max() if ok_count else 0.0
		var overlap_min: float = overlaps.min() if ok_count else 0.0
		var marker: String = String(markers.keys()[0]) if markers.size() == 1 else "mixed %s" % [markers.keys()]
		var band: String = String(bands.keys()[0]) if bands.size() == 1 else "mixed %s" % [bands.keys()]
		var radius: float = float(radii.keys().max()) if not radii.is_empty() else 0.0
		report[id] = {"kind": kind, "marker": marker, "band": band, "pre_shoot": "%.2f" % rec.get("pre_shoot", -1.0)}
		print("%s | %s | %d | %.3f/%.3f | %.2f | %.3f | %s | %s | %s | %d" % [kind, id, leads.size(), lead_min, lead_max,
			float(rec.get("pre_shoot", -1.0)), overlap_min, marker, band, radii.keys(), early])
		_test.check(kind + " 50 solo spawns attacked", ok_count, "%d of %d attacked; skips %s" % [leads.size(), SPAWNS, skips.slice(0, 2)])
		if not ok_count:
			outside.append(kind)
			continue
		var lead_ok: bool = lead_min >= float(_record.REACTION_FLOOR) - 0.0001
		var overlap_ok: bool = overlap_min >= float(_record.OVERLAP_FLOOR)
		if not (lead_ok and overlap_ok and early == 0):
			outside.append(kind)
		_test.check(kind + " lead at least the reaction floor", lead_ok,
			"min lead %.3f s over %d spawns, floor %.2f s" % [lead_min, SPAWNS, _record.REACTION_FLOOR])
		_test.check(kind + " lead matches the record", absf(lead_min - float(rec.get("pre_shoot", -1.0))) <= _tick + 0.0001
				and absf(lead_max - lead_min) <= _tick + 0.0001,
			"lead %.3f..%.3f s, record pre_shoot %.2f s, within one tick" % [lead_min, lead_max, float(rec.get("pre_shoot", -1.0))])
		_test.check(kind + " telegraph and damage areas overlap", overlap_ok,
			"min intersection over union %.3f over %d spawns, floor %.2f" % [overlap_min, SPAWNS, _record.OVERLAP_FLOOR])
		if kind != "lobber" and kind != "swarm_remnant":
			_test.check(kind + " overlap control: a moved drawing fails", controls.size() == 1 and float(controls[0]) < float(_record.OVERLAP_FLOOR),
				"drawn area moved %.0f%% of its size: overlap %s, floor %.2f" % [CONTROL_SHIFT * 100.0, controls, _record.OVERLAP_FLOOR])
		_test.check(kind + " no hit before onset", early == 0, "%d hits landed before damage onset" % early)
		_test.check(kind + " one attack row", rows.size() == 1 and rows.has(id), "rows seen %s, record %s" % [rows.keys(), id])
		_test.check(kind + " one marker class from the committed geometry", markers.size() == 1 and marker == String(rec.get("marker", "")),
			"measured %s, record %s" % [marker, rec.get("marker", "")])
		_test.check(kind + " band class from the attack type", bands.size() == 1 and band == String(rec.get("band", "")),
			"measured %s, record %s" % [band, rec.get("band", "")])
		var want_radius := float(rec.get("radius", -1.0))
		_test.check(kind + " radius matches the record", radii.size() == 1 and absf(radius - want_radius) <= 0.011,
			"measured %s, record %.2f" % [radii.keys(), want_radius])
	_test.check("zero kinds outside", outside.is_empty() and not kinds.is_empty(),
		"%d kinds measured, outside: %s" % [kinds.size(), outside])
	var legibility := _legibility_rows()
	var mismatched: Array = []
	for id in report:
		if not legibility.has(id) or legibility[id] != report[id]:
			mismatched.append("%s report %s legibility %s" % [id, report[id], legibility.get(id, "missing")])
	for id in legibility:
		if not report.has(id):
			mismatched.append("%s in LEGIBILITY only" % id)
	_test.check("LEGIBILITY section 2 equals the report", mismatched.is_empty() and legibility.size() == report.size(),
		"%d LEGIBILITY rows, %d report rows; mismatched %s" % [legibility.size(), report.size(), mismatched])
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = BASE_TICKS
	_game.free()
	quit(_test.verdict())
