extends SceneTree
# smoke: solo timeout=300s

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const LockRows := preload("res://src/world/lock_rows.gd")
const Director := preload("res://src/world/event_director.gd")
const Redline := preload("res://src/combat/redline.gd")
const Rogue := preload("res://src/combat/rogue.gd")
const WaveCross := preload("res://src/world/wave_cross.gd")
const Palette := preload("res://src/core/palette.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const T := preload("res://tests/support/t.gd")

# Backlog W1-108: five sounds the player must act on each get a visible twin that starts with the
# sound and is gone after it (ruling cx, LEGIBILITY section 13).
# - the yard's wave whistle (arena_wave): the registry row's cross, held up where the crew drops from
#   (not a floor ring, ruling on the colour law), at each spot the next wave lands on while the gap
#   runs, gone the tick the crew lands; overtime's whistle shows the same cross through the same call;
# - ancient_stirring and sluice_siren: the director's announced fact carries the same place as the
#   world fact on the same tick, and the world turns it into an edge marker that stays until the
#   event starts (already in place before this row; these checks hold it);
# - the heat kettle (audio.gd _tend_kettle): redline.gd's kettle_pulse flashes over the same last
#   KETTLE_S of the fuse, and is 0 outside it; player_fx draws it on the shell's rim in the hazard colour;
# - the rogue's cue (attack_cued): its core burns brass for the CUE_LEAD beat, from the physics tick that
#   emits the cue.

class Map:
	extends RefCounted
	var park := {}

var _t := T.new("sound_twin_sites_test")
var _facts: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(1)
	_kettle()
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	await process_frame
	game.player.source = Intent.Scripted.new()
	game.events.world_fact.connect(func(kind: String, at: Vector3): _facts.append({"kind": kind, "at": at}))
	game.flow.press_start()
	game.flow.choose_class(0)
	for i in 8:
		await physics_frame
	_stirring_and_siren(game)
	await _kettle_drawn(game)
	_rogue_cue(game)
	await _whistle(game)
	await _held_cross(game)
	game.free()
	await process_frame
	quit(_t.verdict())


func _count(kind: String) -> int:
	return _facts.filter(func(f): return f["kind"] == kind).size()


# --- the heat kettle ---------------------------------------------------------------------
func _kettle() -> void:
	var r := Redline.new()
	r.set_mode(Redline.ON)
	r.value = Redline.MAX
	var window: float = float(r.get_script().get_script_constant_map().get("KETTLE_S", -1.0))
	var audio_source := FileAccess.get_file_as_string("res://src/presentation/audio.gd")
	_t.check("kettle: audio.gd does not define its own window (one home, redline.gd)", audio_source.length() > 0 and not audio_source.contains("const KETTLE_S") and audio_source.contains("Redline.KETTLE_S"))
	_t.check("kettle: the window is 2 s", is_equal_approx(window, 2.0), str(window))
	_t.check("kettle: the shell has a flash to show", r.has_method("kettle_pulse"))
	if not r.has_method("kettle_pulse"):
		return
	_t.near("kettle: dark while the fuse is longer than the whistle", r.call("kettle_pulse"), 0.0)
	r.waited = Redline.COOK_OFF_S - window
	_t.check("kettle: fuse_left matches the whistle's first frame", is_equal_approx(r.fuse_left(), window))
	_t.near("kettle: lit on the whistle's first frame", r.call("kettle_pulse"), 1.0)
	var lit := 0
	var dark := 0
	var samples := 0
	for i in 200:
		r.waited = Redline.COOK_OFF_S - window + float(i) / 200.0 * (window - 0.01)
		samples += 1
		var p: float = r.call("kettle_pulse")
		if p > 0.6:
			lit += 1
		elif p < 0.4:
			dark += 1
	_t.check("kettle: it beats over the window, lit and dark", samples == 200 and lit > 20 and dark > 20, "lit %d dark %d" % [lit, dark])
	r.waited = Redline.COOK_OFF_S
	_t.near("kettle: dark once the fuse is spent", r.call("kettle_pulse"), 0.0)
	r.value = 40.0
	_t.near("kettle: dark when the shell cooled below redline", r.call("kettle_pulse"), 0.0)


# --- ancient_stirring and sluice_siren ---------------------------------------------------
func _fixture_row(id: String, kind: String, family: String, form: String) -> Dictionary:
	return {"id": id, "kind": kind, "family": family, "site": "site", "trigger": {"on": "clock_tier", "value": 1},
		"weight": 1.0, "telegraph": {"lead_s": 3.0, "form": form, "on_bar": false}, "live_s": 4.0,
		"effect": {}, "route_change": {"closes": [], "opens": []}, "hold_clear_m": 12.0,
		"cooldown_s": 2.0, "once": true, "music_cue": {"telegraph": "riser_" + family, "land": "drop_" + family}}


func _stirring_and_siren(game) -> void:
	for case in [["ancient_stirring", "machine_eruption", "ancient"], ["sluice_siren", "sluice_surge", "industrial"]]:
		var form: String = case[0]
		var map := Map.new()
		var site := Vector2(40.0, 30.0)
		map.park = {"map": "fixture", "event_rows": [_fixture_row("twin_" + form, case[1], case[2], form)], "weather_rows": [],
			"park_rows": [{"id": "site", "at": [site.x, site.y], "y": 0.0, "size": [20, 2, 20], "yaw_deg": 0}],
			"routes": [{"id": "main", "from": "drop_in", "to": "landmark", "via": []}]}
		var d = Director.new(1, {}, map, 14.0, func(_x, _z): return 0.0)
		var far := Vector3(1000.0, 1.0, 1000.0)
		var announced := {}
		var world_fact := {}
		var steps := 0
		for i in 60:
			steps += 1
			for f in d.advance(0.05, far, Vector3.ZERO, {"clock_tier": 4, "grounded": true}):
				if f.kind == "announced":
					announced = f
				elif f.kind == "world" and f.fact == form:
					world_fact = f
			if not world_fact.is_empty():
				break
		_t.check(form + ": the announce and the sound's fact come on one tick", steps > 0 and not announced.is_empty() and not world_fact.is_empty())
		if announced.is_empty() or world_fact.is_empty():
			continue
		_t.check(form + ": both name the same finite place with a lead", announced.at == world_fact.at and announced.at.is_finite() and announced.seconds > 0.0,
			"at %s seconds %s" % [announced.at, announced.seconds])
		game.world._publish([announced])
		game.hud.edge_markers.step_incoming(0.0)
		var marks: Array = game.hud.edge_markers.targets().filter(func(m): return m["kind"] == "event_announced")
		var place: Vector3 = game.world._announced_at(announced)
		_t.check(form + ": an edge marker points at the place while the sound plays", marks.size() == 1 and marks[0]["at"] == place, str(marks))
		game.world._publish([{"kind": "started", "id": announced.id}])
		marks = game.hud.edge_markers.targets().filter(func(m): return m["kind"] == "event_announced")
		_t.check(form + ": the marker is gone once the event starts", marks.is_empty(), str(marks))


# --- the rogue's cue ----------------------------------------------------------------------
func _rogue_cue(game) -> void:
	game.ctx.calm = true
	var kind: String = Rogue.ROWS.keys()[0]
	var rogue = game.ctx.spawner.spawn_enemy(kind, Vector3(0, 40, 0))
	rogue.set_physics_process(false)
	rogue.live = func(): return true
	var cued := []
	game.events.attack_cued.connect(func(fight: String, attack: String, _s: float): cued.append([fight, attack]))
	rogue.enter_phase(2)
	rogue._enter(Rogue.State.STALK)
	rogue._begin_attack(Vector3(0, 0, -10))
	rogue.state = Rogue.State.STRIKE
	rogue._clock = 99.0
	rogue._physics_process(0.016)
	_t.check("rogue: the cue sounds on the real physics step", rogue.state == Rogue.State.CUE and cued.size() == 1, str(cued))
	_t.check("rogue: the core shows the cue on that same step", rogue.has_method("cue_showing") and rogue.call("cue_showing"))
	rogue._physics_process(Rogue.CUE_LEAD + 0.001)
	_t.check("rogue: the cue is gone once the attack commits", rogue.state == Rogue.State.WIND and not (rogue.has_method("cue_showing") and rogue.call("cue_showing")),
		rogue.state_name())
	rogue.state = Rogue.State.STRIKE
	rogue._clock = 99.0
	rogue._physics_process(0.016)
	_t.check("rogue: a vented window after the second attack is not the cue", rogue.state == Rogue.State.WEAK and not (rogue.has_method("cue_showing") and rogue.call("cue_showing")))
	rogue._clear_telegraph()
	rogue.free()


# --- the yard's wave whistle --------------------------------------------------------------
func _whistle(game) -> void:
	var locks = game.flow.gate
	var row: Dictionary = LockRows.row("park_dam")["lock"]
	var beacon: Vector3 = game.flow.beacon.global_position
	var spot := beacon + Vector3(0.0, 0.0, -float(row["within_m"]) * 0.75 + 10.0)
	var ground: Vector3 = game.ctx.terrain.drop_point(spot.x, spot.z, 1.0)
	game.player.reset_to(ground, Vector3.ZERO)
	var waited := 0
	while locks.lock_state == "armed" and waited < 240:
		await physics_frame
		waited += 1
	_t.eq("whistle: the yard shut", locks.lock_state, "locked")
	var waves: Array = row["waves"]
	_facts.clear()
	_t.check("whistle: no ring before the whistle", not (locks.has_method("has_wave_marks") and locks.call("has_wave_marks")))
	for enemy in locks.crew_alive():
		enemy._die()
	var loops := 0
	while _count("arena_wave") == 0 and loops < 60:
		await physics_frame
		loops += 1
	_t.eq("whistle: the whistle sounded", _count("arena_wave"), 1)
	var shown: bool = locks.has_method("has_wave_marks") and locks.call("has_wave_marks")
	_t.check("whistle: a mark shows on the whistle's frame", shown)
	if shown:
		var marks: Node3D = locks.get_node("ArenaWaveMarks")
		var crosses: Array = marks.get_children()
		var spots: Array = locks.call("_wave_spots", 1)
		_t.eq("whistle: one mark per member of the next wave", crosses.size(), (waves[1] as Array).size())
		var at_spots := crosses.size() == spots.size() and crosses.size() > 0
		var high := crosses.size() > 0
		var not_floor_ring := crosses.size() > 0
		var colour := crosses.size() > 0
		var wanted: Color = EventKinds.world_row("arena_wave")["color"]
		for i in mini(crosses.size(), spots.size()):
			var cross: MeshInstance3D = crosses[i]
			at_spots = at_spots and (cross.global_position - spots[i]).length() < 0.05
			var p := cross.global_position
			high = high and p.y - game.ctx.terrain.height(p.x, p.z) >= 1.5
			var box: AABB = cross.mesh.get_aabb()
			var mat := cross.material_override as StandardMaterial3D
			not_floor_ring = not_floor_ring and not (cross.mesh is TorusMesh) and box.size.y > 1.0 and box.size.z < 0.01 \
				and mat.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED and cross.rotation.is_zero_approx()
			colour = colour and mat.albedo_color.is_equal_approx(wanted)
		_t.check("whistle: each mark is on a landing spot", at_spots)
		_t.check("whistle: each mark is at least 1.5 m above the ground", high)
		_t.check("whistle: the mark is a camera-facing cross, not a floor ring", not_floor_ring)
		_t.check("whistle: the mark's colour is the registry row's colour", colour and wanted.is_equal_approx(Palette.HAZARD))
		_t.eq("whistle: the mark's shape is the registry row's shape", String(marks.get("shape")), String(EventKinds.world_row("arena_wave")["shape"]))
		_t.eq("whistle: the registry shape is a cross", String(EventKinds.world_row("arena_wave")["shape"]), "cross")
	var ticks := 0
	while locks.crew_alive().is_empty() and ticks < 900:
		await physics_frame
		ticks += 1
	_t.eq("whistle: the next wave landed", locks.crew_alive().size(), (waves[1] as Array).size())
	_t.check("whistle: the rings are gone once the crew lands", not (locks.has_method("has_wave_marks") and locks.call("has_wave_marks")))


# --- the kettle drawn on the shell, and overtime's whistle -------------------------------------
func _kettle_drawn(game) -> void:
	var red = game.player.get("redline")
	var fx = game.presentation.player_fx
	_t.check("kettle drawn: the game has a shell with heat and a rim", red != null and fx != null)
	if red == null or fx == null:
		return
	red.set_mode(Redline.ON)
	red.value = Redline.MAX
	fx._shell_band = 3
	var hazard := Palette.HAZARD
	var checked := 0
	var quiet_ok := true
	var beat_hi := 0
	var beat_lo := 0
	for window in [false, true]:
		for i in 40:
			red.value = Redline.MAX
			red.waited = (Redline.COOK_OFF_S - Redline.KETTLE_S + float(i) * 0.04) if window else 0.0
			fx._draw_overdrive(0.016)
			var rim: Color = fx._rim_mat.get_shader_parameter("rim")
			var heat: float = fx._rim_mat.get_shader_parameter("heat")
			var pulse: float = red.kettle_pulse()
			checked += 1
			var base: Color = fx.shell_color(red)
			if not window:
				quiet_ok = quiet_ok and rim.is_equal_approx(base) and pulse == 0.0
			else:
				quiet_ok = quiet_ok and rim.is_equal_approx(base.lerp(hazard, pulse)) and heat >= fx.shell_heat() - 0.001
				if pulse > 0.9:
					beat_hi += 1
					quiet_ok = quiet_ok and rim.is_equal_approx(base.lerp(hazard, pulse)) and heat > 0.95
				elif pulse < 0.1:
					beat_lo += 1
					quiet_ok = quiet_ok and heat <= fx.shell_heat() + 0.1 and absf(rim.r - base.r) + absf(rim.g - base.g) + absf(rim.b - base.b) < 0.4
	_t.check("kettle drawn: the rim beats to full heat in the hazard colour over the whistle window, and is the shell colour before it", checked == 80 and beat_hi > 0 and beat_lo > 0 and quiet_ok, "hi %d lo %d" % [beat_hi, beat_lo])
	# Reduce flashes (flash_guard.gd): the beat runs 4 to 10 Hz, past WCAG 2.3.1's three flashes a second.
	# With the toggle on, count the rim's swings over the window, sampled well above 10 Hz.
	FlashGuard.on = true
	var swings := 0
	var samples := 0
	var tinted := 0
	var last_heat := -1.0
	var last_dir := 0
	for i in 200:
		red.value = Redline.MAX
		red.waited = Redline.COOK_OFF_S - Redline.KETTLE_S + float(i) * 0.01
		fx._draw_overdrive(0.016)
		var g_heat: float = fx._rim_mat.get_shader_parameter("heat")
		var g_rim: Color = fx._rim_mat.get_shader_parameter("rim")
		samples += 1
		tinted += 1 if g_rim.is_equal_approx(fx.shell_color(red).lerp(hazard, 1.0)) else 0
		if last_heat >= 0.0 and absf(g_heat - last_heat) > 0.001:
			var dir := 1 if g_heat > last_heat else -1
			if last_dir != 0 and dir != last_dir:
				swings += 1
			last_dir = dir
		last_heat = g_heat
	FlashGuard.on = false
	_t.check("kettle drawn, reduce flashes: no swing faster than 3 a second, and the hazard colour still shows", samples == 200 and swings <= 6 and tinted > 150, "%d swings in 2 s, %d of %d samples tinted" % [swings, tinted, samples])
	red.clear()
	red.set_mode(Redline.OFF)


# A cross with a hold (overtime's whistle) frees itself once the hold is over.
func _held_cross(game) -> void:
	var camera: Camera3D = root.get_camera_3d()
	var view := root.get_visible_rect().size
	var near_spot := camera.project_position(view * 0.5, 2.0)
	var far_spot := camera.project_position(view * 0.5, 180.0)
	var warning := WaveCross.mark(game, [near_spot, far_spot], 1.0)
	var near_mark: MeshInstance3D = warning.get_child(0)
	var far_mark: MeshInstance3D = warning.get_child(1)
	var near_span := _height_share(camera, near_mark, view.y)
	var far_span := _height_share(camera, far_mark, view.y)
	_t.check("near mark fits 8% of screen height and the distant cross keeps its world size",
		near_span <= 0.081 and near_span > 0.07 and far_span > 0.0 and far_span < 0.04,
		"near %.4f, far %.4f" % [near_span, far_span])
	var vertices: PackedVector3Array = near_mark.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_t.check("all four near tips end clear of the middle", vertices.size() == 16
		and Array(vertices).all(func(v): return v.length() > 0.6))
	warning._physics_process(0.5)
	_t.check("the capped mark still closes as the crew arrives", _height_share(camera, near_mark, view.y) < near_span * 0.8)
	warning.free()
	var held: Node3D = WaveCross.mark(game, [Vector3(0.0, 5.0, 0.0)], 0.0, 0.2)
	_t.check("held cross: it shows", is_instance_valid(held) and held.get_child_count() == 1)
	var frames := 0
	while is_instance_valid(held) and frames < 120:
		await physics_frame
		frames += 1
	_t.check("held cross: it frees itself after its hold", not is_instance_valid(held) and frames > 5, str(frames))


func _height_share(camera: Camera3D, mark: MeshInstance3D, screen_height: float) -> float:
	var span := mark.mesh.get_aabb().size.y * mark.scale.y
	var centre := camera.unproject_position(mark.global_position)
	return camera.unproject_position(mark.global_position + span * camera.global_basis.y).distance_to(centre) / screen_height
