extends SceneTree

const Game := preload("res://src/game.gd")
const Enemy := preload("res://src/combat/enemy.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")

# An enemy's state reads on its body from STATE_ROWS (C5). A plated enemy shows before the hit
# whether it will break (a live rim and crack, pulsing) or glance (a steady slate rim, no
# crack); a glance answers with the glancing row's burst in slate; a wind-up a hit broke
# answers with the interrupted row's star in the live colour, once a second at most, and
# never for a death or a wind-up that ran its course. No cue draws amber or the class colour.

const OFFSET := Vector3(8.0, 0.0, 0.0)
const CLASS_COLOUR := Color("b77843")
const TICK_LIMIT := 600
const STAGES := 6

var _game
var _ctx
var _vfx
var _marks
var _failures := 0
var _stage := -1
var _ticks := 0
var _ball := Vector3.ZERO
var _unit: Node3D
var _acted := false
var _done := false
var _phases: Array = []
var _star_seen := 0
var _drawn_before := 0
var _pulse_brute: Node3D
var _pulse_mat: StandardMaterial3D
var _pulse_before := 0.0
var _slate_brute: Node3D
var _slate_before := 0.0


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
		_plate_checks()
		_glance_check()
		_dedupe_check()
		_scan_check()
		return _next_stage()
	_ticks += 1
	_pulse_check()
	_observe()
	if _done or _ticks > TICK_LIMIT:
		_judge()
		return _next_stage()
	return false


func _setup() -> void:
	_ctx = _game.ctx
	_ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_vfx = _game.presentation.vfx
	_marks = _game.presentation.status_marks
	var spawn: Vector3 = _ctx.terrain.spawn_point(1)
	_ball = _ctx.terrain.drop_point(spawn.x, spawn.z, 1.05)


func _next_stage() -> bool:
	if is_instance_valid(_unit):
		_unit.queue_free()
	_stage += 1
	if _stage >= STAGES:
		print("status_marks_test: %s" % ("PASS" if _failures == 0 else "FAIL"))
		quit(0 if _failures == 0 else 1)
		return true
	_ticks = 0
	_acted = false
	_done = false
	_phases = []
	_star_seen = 0
	_drawn_before = _marks.drawn
	_game.player.reset_to(_ball)
	var kind := "mag_trapper" if _stage == 1 else ("lobber" if _stage == 4 else "chaser")
	var at: Vector3 = _ball + OFFSET
	_unit = _ctx.spawner.spawn_enemy(kind, _ctx.terrain.drop_point(at.x, at.z, 1.8))
	if kind == "mag_trapper":
		_unit._rest = 0.3
	if kind == "lobber":
		_unit._clock = 3.0
	_unit.attack_phase.connect(_on_phase)
	return false


func _on_phase(facts: Dictionary) -> void:
	_phases.append(facts["phase"])
	if facts["phase"] != "cancelled":
		return
	for g in _vfx._glyphs:
		if is_zero_approx(g["t"]) and g["node"].visible and g["node"].mesh == _vfx._meshes["star"] and g["color"] == EventKinds.state_color("interrupted"):
			_star_seen += 1


# The rim pulse rides the physics tick, so it is judged after real ticks, not by a direct call.
func _pulse_check() -> void:
	if _ticks != 3 or _pulse_brute == null:
		return
	var moved: bool = _pulse_brute.tint_state == "amber" and not is_equal_approx(_pulse_mat.emission_energy_multiplier, _pulse_before)
	_report("c5_1_amber_pulse", moved, "amber: three physics ticks move the rim %.3f to %.3f" % [_pulse_before, _pulse_mat.emission_energy_multiplier])
	var steady: bool = _slate_brute.tint_state == "slate" and is_equal_approx((_slate_brute._tint_materials[0] as StandardMaterial3D).emission_energy_multiplier, _slate_before)
	_report("c5_1_slate_steady", steady, "slate: three physics ticks leave the rim steady at %.3f" % _slate_before)
	_pulse_brute.queue_free()
	_slate_brute.queue_free()
	_pulse_brute = null


func _observe() -> void:
	if not is_instance_valid(_unit):
		_done = true
		return
	var state: String = _unit.state_name() if _unit.has_method("state_name") else ""
	var windup := "warn" if _stage == 1 else "windup"
	match _stage:
		0, 1, 5:
			if not _acted and state == windup and _unit.telegraph() != null:
				_acted = true
				if _stage == 0:
					# What the ball's ram contact does (player_ball._on_enemy_touched): the shove,
					# then the struck signal game.gd wires into combat's strike().
					_unit.knock(Vector3.RIGHT + Vector3.UP * 0.35, 24.0)
					_game.player.struck.emit(_unit, "ram", 14.0)
				else:
					_unit.knock(Vector3.RIGHT, 400.0)
			elif _acted and state in ["roam", "recover"]:
				_done = true
		4:
			if not _acted and _phases.has("windup"):
				_acted = true
				# Out of range but on the map: off it, the fall rescue would bring the ball back
				# beside the lobber on the same tick.
				_game.player.reset_to(_ctx.terrain.drop_point(_ball.x, _ball.z + 120.0, 1.05))
			elif _acted and _phases.has("cancelled"):
				_done = true
		2:
			if state == "windup":
				_unit.take_damage(100000.0)
				_done = true
		3:
			if not _acted and state == "windup" and _unit.telegraph() != null:
				_acted = true
				_game.player.reset_to(_ball + Vector3(0.0, 0.0, -40.0))
			elif _acted and state == "recover":
				_done = true


func _judge() -> void:
	var drawn: int = _marks.drawn - _drawn_before
	match _stage:
		0, 1, 5:
			var who := "chaser" if _stage != 1 else "mag trapper"
			var how := "ram_strike" if _stage == 0 else "knock"
			var tag := "%s_%s" % [who.replace(" ", "_"), how]
			_report("c5_4_%s_cancel" % tag, _phases == ["windup", "cancelled"], "a %s broken by a %s publishes %s" % [who, how, _phases])
			_report("c5_4_%s_star" % tag, drawn == 1 and _star_seen == 1,
				"one interrupted star (a live-colour star glyph in the pool at the break) for the %s by %s: drawn %d, seen %d" % [who, how, drawn, _star_seen])
		4:
			_report("c5_4_lobber_range_no_star", _phases == ["windup", "cancelled"] and drawn == 0 and _star_seen == 0,
				"a lobber whose target leaves range mid-charge publishes %s and draws %d stars (no hit broke it)" % [_phases, drawn])
		2:
			_report("c5_4_killed_no_star", _phases == ["windup", "cancelled"] and drawn == 0, "a chaser killed in its wind-up publishes %s and draws %d stars" % [_phases, drawn])
		3:
			_report("c5_4_complete_no_star", _phases == ["windup", "strike", "recover"] and drawn == 0, "a wind-up that completes publishes %s and draws %d stars" % [_phases, drawn])


func _draws(node: Node) -> int:
	var n := 0
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		if mi.get_parent() != null and mi.get_parent().name == "PlateCrack":
			continue
		n += mi.mesh.get_surface_count()
	return n


func _plate_materials(node: Node) -> Array:
	return node._tint_materials


func _crack_colours(node: Node) -> Array:
	var out: Array = []
	for crack in node._cracks:
		for stroke in crack.get_children():
			out.append(((stroke as MeshInstance3D).material_override as StandardMaterial3D).albedo_color)
	return out


func _plate_checks() -> void:
	var live := EventKinds.state_color("will_break")
	var slate := EventKinds.role_color("slate")
	var brute: Node3D = _ctx.spawner.spawn_enemy("plated_brute", Vector3(0, 30, 0))
	var mat := brute.get_node("ReactionPivot/BrutePlates").material_override as StandardMaterial3D
	var crack := brute.get_node("ReactionPivot/BrutePlates/PlateCrack") as Node3D
	brute.set_tint("amber")
	var amber_energy := mat.emission_energy_multiplier
	var amber_draws := _draws(brute)
	_report("c5_1_amber_live_colour", mat.emission_enabled and mat.emission == live and live == Palette.live() and mat.emission != CLASS_COLOUR,
		"amber rim emission %s is the live colour %s, not the class colour" % [mat.emission, live])
	_report("c5_1_amber_crack", crack.visible and _crack_colours(brute).all(func(c): return c == live), "amber: the crack shows, in the live colour")
	_report("c5_1_amber_idle_off", not brute.is_processing(), "set_tint amber does not turn idle processing on")
	_pulse_brute = _ctx.spawner.spawn_enemy("plated_brute", Vector3(0, 30, -20))
	_pulse_brute.plating = 0.0
	_pulse_brute.set_tint("amber")
	_pulse_mat = _pulse_brute._tint_materials[0]
	_pulse_before = _pulse_mat.emission_energy_multiplier
	_slate_brute = _ctx.spawner.spawn_enemy("plated_brute", Vector3(0, 30, -40))
	_slate_brute.plating = 0.0
	_slate_brute.set_tint("slate")
	_slate_before = (_slate_brute._tint_materials[0] as StandardMaterial3D).emission_energy_multiplier
	brute._pulse_rim(0.125)
	_report("c5_1_pulse_swing", is_equal_approx(mat.emission_energy_multiplier, Enemy.PLATE_GLOW_LIVE * (1.0 + Enemy.PULSE_DEPTH)),
		"a quarter period at 2 Hz lifts the rim to %.3f" % mat.emission_energy_multiplier)
	brute.set_tint("slate")
	_report("c5_1_slate_rim", mat.emission_enabled and mat.emission == slate and mat.emission_energy_multiplier > 0.0 and mat.emission_energy_multiplier < amber_energy,
		"slate rim emission %s at energy %.2f (live %.2f)" % [mat.emission, mat.emission_energy_multiplier, amber_energy])
	_report("c5_1_slate_no_crack", not crack.visible, "slate: no crack")
	brute.set_tint("")
	_report("c5_1_rest", not mat.emission_enabled and is_zero_approx(mat.emission_energy_multiplier) and not crack.visible and mat.albedo_color == Enemy.PLATE_CLOSED,
		"set_tint empty leaves the plate at rest")
	_report("c5_1_body_and_draws", not brute._material.emission_enabled and _draws(brute) == amber_draws,
		"the body never glows and the draw count holds at %d" % amber_draws)
	var bad: Array = []
	var miniboss: Node3D = _ctx.spawner.spawn_enemy("miniboss", Vector3(40, 30, 0))
	for enemy in [brute, miniboss]:
		for state in ["amber", "slate", ""]:
			enemy.set_tint(state)
			for m in _plate_materials(enemy):
				var e := (m as StandardMaterial3D).emission
				if (m as StandardMaterial3D).emission_enabled and (e == Palette.AMBER or e == CLASS_COLOUR):
					bad.append("%s/%s" % [enemy.kind, state])
			for c in _crack_colours(enemy):
				if c == Palette.AMBER or c == CLASS_COLOUR:
					bad.append("%s/%s crack" % [enemy.kind, state])
	_report("c5_2_no_amber", bad.is_empty() and _plate_materials(miniboss).size() > 0, "no plate emission or crack on a brute or miniboss is amber or the class colour %s" % [bad])
	var warden: Node3D = _ctx.spawner.spawn_enemy("warden", Vector3(80, 30, 0))
	warden.set_tint("amber")
	var jaw: StandardMaterial3D = warden._look.plate_material
	print("warden (report only): amber jaw emission %s enabled %s energy %.2f" % [jaw.emission, jaw.emission_enabled, jaw.emission_energy_multiplier])
	var was := warden.is_processing()
	warden.set_tint("slate")
	_report("c5_1_warden_keeps_processing", was and warden.is_processing(), "a default-table Warden told slate still processes (was %s, now %s), so its look and kit still update" % [was, warden.is_processing()])
	warden.set_tint("")
	_report("c5_1_warden_keeps_processing_rest", warden.is_processing(), "and told empty it still processes")
	for enemy in [brute, miniboss, warden]:
		enemy.queue_free()


func _glance_check() -> void:
	var brute: Node3D = _ctx.spawner.spawn_enemy("plated_brute", Vector3(0, 30, 20))
	var before: int = _vfx.spawned.get("strike_deflected", 0)
	_game.events.strike_deflected.emit(brute, "ram", 5.0, 40.0)
	var found := 0
	for g in _vfx._glyphs:
		if is_zero_approx(g["t"]) and g["node"].visible and g["color"] == EventKinds.role_color("slate") and g["node"].mesh == _vfx._meshes[String(EventKinds.state_row("glancing")["shape"])]:
			found += 1
	_report("c5_3_glance", found == 1 and _vfx.spawned.get("strike_deflected", 0) == before + 1,
		"a glance draws %d slate glyph in the glancing row's shape, spawned +%d" % [found, _vfx.spawned.get("strike_deflected", 0) - before])
	brute.queue_free()


func _break(dummy: Node3D) -> void:
	_marks._on_phase({"phase": "windup"}, dummy)
	dummy.knock(Vector3.RIGHT, 1.0)
	_marks._on_phase({"phase": "cancelled"}, dummy)


func _dedupe_check() -> void:
	var dummy: Node3D = _ctx.spawner.spawn_enemy("chaser", Vector3(0, 30, 40))
	var before: int = _marks.drawn
	_break(dummy)
	_break(dummy)
	_report("c5_4_one_per_second", _marks.drawn == before + 1, "two breaks in one second draw %d star" % [_marks.drawn - before])
	_marks._clock += 1.01
	_break(dummy)
	_report("c5_4_next_second", _marks.drawn == before + 2, "a break a second later draws again")
	_marks._clock += 1.01
	_marks._on_phase({"phase": "windup"}, dummy)
	_marks._on_phase({"phase": "cancelled"}, dummy)
	_report("c5_4_unhit_no_star", _marks.drawn == before + 2, "a wind-up no hit broke draws no star")
	var id := dummy.get_instance_id()
	var tracked: bool = _marks._last.has(id) and _marks._wound.has(id)
	dummy.free()
	_report("c5_4_pruned", tracked and not _marks._last.has(id) and not _marks._wound.has(id), "the per-enemy records drop the enemy when it leaves the tree (held before: %s)" % tracked)


func _body(path: String, from: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	var start := text.find(from)
	if start < 0:
		return ""
	var stop := text.find("\n\n\n", start)
	var next := text.find("\nfunc ", start + 1)
	if next >= 0 and (stop < 0 or next < stop):
		stop = next
	return text.substr(start, (stop if stop >= 0 else text.length()) - start)


func _scan_check() -> void:
	var enemy := "res://src/combat/enemy.gd"
	var parts := {
		"status_marks.gd": FileAccess.get_file_as_string("res://src/presentation/status_marks.gd"),
		"enemy set_tint": _body(enemy, "func set_tint("),
		"enemy _paint_plate": _body(enemy, "static func _paint_plate("),
		"enemy _pulse_rim": _body(enemy, "func _pulse_rim("),
		"enemy _add_crack": _body(enemy, "func _add_crack("),
		"vfx _on_deflected": _body("res://src/presentation/vfx.gd", "func _on_deflected("),
	}
	var bad: Array = []
	var literal := RegEx.create_from_string("Color\\(|Palette\\.(?!unshaded)")
	for name in parts:
		if String(parts[name]).is_empty():
			bad.append("%s: not found" % name)
		elif literal.search(String(parts[name])) != null:
			bad.append(name)
	_report("c5_5_no_colour_literals", bad.is_empty(), "no Color( or Palette. in the three states' draw code %s" % [bad])
