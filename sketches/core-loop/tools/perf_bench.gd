extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const Parts := preload("res://src/build/parts.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Warden := preload("res://src/combat/warden.gd")
const Director := preload("res://src/world/director.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")


const Flow := preload("res://src/core/flow.gd")

const WARM_FRAMES := 120
const RECORD_FRAMES := 600
const SWAP_FRAMES_MAX := 3000
const LANDED_FRAMES := 30
const HARD_TIMEOUT := 600.0
const SCENES := {
	"s1": {"packs": 1, "per_type": 0, "warden": false, "view": "fight"},
	"s2": {"packs": 3, "per_type": 4, "warden": false, "view": "fight"},
	"s3": {"packs": 6, "per_type": 8, "warden": true, "view": "fight"},
	"p1": {"packs": 0, "per_type": 0, "warden": false, "view": "stand", "table": "park"},
	"p2": {"packs": 0, "per_type": 0, "warden": false, "view": "swap", "table": "park"},
	"p3": {"packs": 0, "per_type": 0, "warden": false, "view": "carve", "table": "park"},
	"level-sites": {"packs": 0, "per_type": 0, "warden": false, "view": "sites", "table": "park"},
}
const CARVE_EVERY := 60
const FLAT_LIFT := 40.0
const FLAT_AHEAD := 30.0
const FLAT_THICK := 30.0
const SLOPE_HIT_SECONDS := 0.18
const CARVE_BUDGET_MS := 16.7
const LEVEL_DEG := 0.5
const SLOPE_WANT_DEG := 15.0
const SLOPE_MIN_DEG := 6.0
const SLOPE_MAX_DEG := 25.0
const SLOPE_REACH := 50.0
const PLANTS := ["no-carve", "no-flat", "late-flat", "stand-late", "no-slope"]
const RivetKit := preload("res://src/combat/rivet_kit.gd")
const Hitscan := preload("res://src/combat/hitscan.gd")
const TerrainFaces := preload("res://src/combat/terrain_faces.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const PlayerBall := preload("res://src/movement/player_ball.gd")
const ABLATIONS := ["no-music", "no-audio", "no-vfx", "no-telegraph-draw", "no-hud", "no-enemy-ai", "no-trails", "cold-band", "no-machine-fx", "no-stills"]
const PACK_ORDER := ["grounded", "strung", "netted", "rebound", "reeled", "wobble", "flung", "cupped"]
const EXTRA_COPIES := ["spiral_wave", "chain_arc", "cross_split", "gatling_heart", "double_feed", "arc_coil"]
const RIVET_SEED := 1
const LOAD_CHECK_EVERY := 30
const KEYS := ["frame_ms", "process_ms", "physics_ms", "ticks", "harness_ms", "perf_process_ms",
	"perf_physics_ms", "nodes", "draws", "gpu_ms", "render_cpu_ms"]


class SilentBand extends MusicEngine:
	var skipped_mixes := 0

	func _mix(_offset: int, _n: int) -> void:
		skipped_mixes += 1

	func _finish(_frames: int) -> void:
		out_music.fill(Vector2.ZERO)
		out_stinger.fill(Vector2.ZERO)


class Probe extends Node:
	var bench

	func _process(_delta: float) -> void:
		bench._process_end()

	func _physics_process(_delta: float) -> void:
		bench._physics_end()


var _out := ""
var _scene_id := ""
var _off := {}
var _native := false
var _game
var _driver
var _probe: Probe
var _render_rid: RID
var _start_usec := 0
var _phase := "boot"
var _phase_usec := 0
var _granted: Array = []
var _load_slots: Array = []
var _threats: Array = []
var _painters: Array = []
var _warden_note := ""
var _frame := 0
var _samples: Array = []
var _errors: Array = []
var _materials_at_record := 0
var _load_ok := true
var _proc_start := 0
var _phys_start := 0
var _phys_acc := 0
var _ticks := 0
var _last_end := 0
var _harness_usec := 0
var _perf_updates := 0
var _last_perf := -1.0
var _probe_open := {}
var _probe_close := {}
var _ablation_notes := {}
var _series := ""
var _table := ""
var _warm_frames := WARM_FRAMES
var _warm_seconds := 0.0
var _warm_usec := 0
var _sound_ready_s := -1.0
var _view := "fight"
var _memory := {}
var _segment := ""
var _segment_at := {}
var _landed := 0
var _swap := {}
var _carves: Array = []
var _pending: Array = []
var _hits_seen := 0
var _stand_heading := Vector3.FORWARD
var _flat_at := Vector3.INF
var _slope_at := Vector3.INF
var _slope_sites: Array = []
var _slots := 0
var _pilot := ""
var _plant := ""
var _sites_seed := 7301
var _sites_count := 80
var _sites_scale := 0.0
var _carve_open := {}
var _terrain_open := {}


func _initialize() -> void:
	var settings := {}
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		if "=" in arg:
			settings[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
		elif arg.substr(2) in ABLATIONS:
			_off[arg.substr(2)] = true
		else:
			printerr("perf_bench: unknown switch " + arg)
			quit(2)
			return
	_scene_id = settings.get("scene", "")
	_series = settings.get("series", "")
	_warm_frames = int(settings.get("warm-frames", str(WARM_FRAMES)))
	_warm_seconds = float(settings.get("warm-seconds", "0"))
	_out = settings.get("out", "")
	_table = String(settings.get("table", ""))
	_pilot = String(settings.get("pilot", ""))
	_plant = String(settings.get("plant", ""))
	_sites_seed = int(settings.get("seed", str(_sites_seed)))
	_sites_count = int(settings.get("sites", str(_sites_count)))
	_sites_scale = float(settings.get("landing-scale", "0"))
	if _plant != "" and not _plant in PLANTS:
		printerr("perf_bench: unknown --plant=" + _plant)
		quit(2)
		return
	if not SCENES.has(_scene_id) or not _out.is_absolute_path() or not _out.ends_with(".json"):
		printerr("perf_bench: needs -- --scene=s1|s2|s3|p1|p2|p3|level-sites --out=<absolute .json path>")
		quit(2)
		return
	_view = String(SCENES[_scene_id]["view"])
	if _table == "":
		_table = String(SCENES[_scene_id].get("table", ""))
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	_native = DisplayServer.get_name() != "headless"
	for asset in ["shell_sable", "shell_rivet", "shell_kest"]:
		if load("res://assets/models/" + asset + ".glb") == null:
			printerr("perf_bench: import this project with --headless --editor --import first")
			quit(2)
			return
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	if _native:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# A window that cannot draw (headless) sleeps this long per frame by default (6900 us),
	OS.low_processor_usage_mode_sleep_usec = 0
	_render_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_render_rid, true)
	seed(RIVET_SEED)
	_game = Game.new()
	_game.test_mode = true
	_game.table = _table
	root.add_child(_game)
	_probe = Probe.new()
	_probe.bench = self
	_probe.name = "PerfProbe"
	_probe.process_priority = 1 << 30
	_probe.process_physics_priority = 1 << 30
	_probe.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_probe)
	process_frame.connect(func(): _proc_start = Time.get_ticks_usec())
	physics_frame.connect(func(): _phys_start = Time.get_ticks_usec())
	if _off.has("no-enemy-ai") or _off.has("no-telegraph-draw"):
		node_added.connect(func(node: Node): _ablate_new.call_deferred(node))
	_start_usec = Time.get_ticks_usec()


func _seconds_since(usec: int) -> float:
	return (Time.get_ticks_usec() - usec) / 1000000.0


func _process(delta: float) -> bool:
	var begin := Time.get_ticks_usec()
	if _seconds_since(_start_usec) > HARD_TIMEOUT:
		_errors.append("timeout in phase " + _phase)
		_finish()
		return false
	if _game == null or _game.flow == null:
		return false
	match _phase:
		"boot":
			if _off.has("no-music"):
				_game.presentation.audio.engine = SilentBand.new()
			_driver = BotDriver.new(_game, "skipper", RIVET_SEED)
			if _pilot != "":
				var index: int = BotDriver.class_index_for(RIVET_SEED, _pilot)
				if index < 0:
					printerr("perf_bench: no pilot " + _pilot)
					quit(2)
					return false
				_driver.class_index = index
			_driver.start()
			if _view != "fight":
				_game.ctx.calm = true
			_phase = "drop"
			_phase_usec = begin
		"drop":
			if _game.flow.in_stage() and _seconds_since(_phase_usec) > 1.5:
				_grant()
				_phase = "settle"
				_phase_usec = begin
		"settle":
			if _sound_ready_s < 0.0 and _game.presentation.audio.sound_ready:
				_sound_ready_s = _seconds_since(_start_usec)
			if _seconds_since(_phase_usec) > 2.0 and _sound_ready_s >= 0.0:
				_prebake_band()
				_build_scene()
				_apply_ablations()
				_phase = "warm"
				_frame = 0
		"warm", "record":
			_maintain_load()
			_step_threats(delta)
			if _off.has("no-vfx") and _game.combat.effects != null:
				_game.combat.effects.clear()
			if _view == "swap" and _phase == "record":
				_step_swap()
			if _view == "sites" and _phase == "record" and _frame == 3:
				_level_sites()
				quit(0 if _errors.is_empty() else 1)
				return false
			if _view == "carve" and _phase == "record" and _plant != "no-carve":
				if _frame % CARVE_EVERY == CARVE_EVERY - 1:
					_step_carve()
				elif _frame % CARVE_EVERY == CARVE_EVERY / 2 - 1:
					_step_flat()
				elif _frame % CARVE_EVERY == CARVE_EVERY * 3 / 4 - 1:
					_step_slope()
	_harness_usec = Time.get_ticks_usec() - begin
	return false


func _physics_process(_delta: float) -> bool:
	if _game == null or _game.run == null or _driver == null or paused:
		return false
	_game.run.hp = _game.run.max_hp
	if _phase in ["settle", "warm", "record"]:
		if _view == "fight":
			_hold_fire()
		else:
			_driver.source.hold = {}
	return false


func _physics_end() -> void:
	_watch_hits()
	_phys_acc += Time.get_ticks_usec() - _phys_start
	_ticks += 1


func _process_end() -> void:
	var now := Time.get_ticks_usec()
	var frame_usec := now - _last_end
	var had_frame := _last_end > 0
	_last_end = now
	var sample := {
		"frame_ms": frame_usec / 1000.0, "process_ms": (now - _proc_start) / 1000.0,
		"physics_ms": _phys_acc / 1000.0, "ticks": _ticks, "harness_ms": _harness_usec / 1000.0,
		"perf_process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"perf_physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME) if _native else -1.0,
		"gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(_render_rid) if _native else -1.0,
		"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(_render_rid) if _native else -1.0,
	}
	_phys_acc = 0
	_ticks = 0
	if not had_frame or not _phase in ["warm", "record"]:
		return
	_frame += 1
	if _phase == "warm":
		if _frame == 1:
			_warm_usec = Time.get_ticks_usec()
		if _frame >= _warm_frames and _seconds_since(_warm_usec) >= _warm_seconds:
			_phase = "record"
			_frame = 0
			_probe_open = _checks()
			_open_counts()
			_memory["at_open"] = _snapshot()
			_materials_at_record = Threat.Painter.materials_built
		return
	if sample["perf_process_ms"] != _last_perf:
		_perf_updates += 1
		_last_perf = sample["perf_process_ms"]
	sample["segment"] = _segment
	_samples.append(sample)
	if _frame % LOAD_CHECK_EVERY == 0:
		_check_load()
	if _record_done():
		_probe_close = _checks()
		_memory["at_close"] = _snapshot()
		if Threat.Painter.materials_built != _materials_at_record:
			_errors.append("%d mark materials were built during the recorded window (warm-up missed a key)" % (Threat.Painter.materials_built - _materials_at_record))
		_finish()


func _prebake_band() -> void:
	if _off.has("cold-band"):
		return
	var audio = _game.presentation.audio
	if audio.live_output:
		audio._finish_opening()
		if audio._rest_task >= 0:
			WorkerThreadPool.wait_for_task_completion(audio._rest_task)
			audio._rest_task = -1
	else:
		MusicEngine.prepare_opening()
		MusicEngine.prepare_rest()


func _grant() -> void:
	var pool := Parts.offer_pool(_game.run.class_id(), ["common", "uncommon", "rare", "rare_plus"])
	for id in Parts.CATALOGUE:
		if id in pool:
			_granted.append(id)
	for id in EXTRA_COPIES:
		if id in pool:
			_granted.append(id)
	for id in _granted:
		_game.run.add_part(id, "stress")


func _ground(p: Vector3, lift := 2.4) -> Vector3:
	return _game.ctx.terrain.drop_point(p.x, p.z, lift)


func _build_stand() -> void:
	var terrain = _game.ctx.terrain
	var drop_in: Vector3 = terrain.spawn_point(1)
	_game.player.reset_to(_ground(drop_in))
	_game.player.set_frozen(true)
	var mark: Vector3 = terrain.landmark_point(1)
	var heading := Vector3.FORWARD
	if mark != Vector3.INF and Vector2(mark.x - drop_in.x, mark.z - drop_in.z).length() > 1.0:
		heading = Vector3(mark.x - drop_in.x, 0.0, mark.z - drop_in.z).normalized()
	_game.camera.snap(heading)
	_stand_heading = heading
	if _scene_id == "p3":
		var slab := StaticBody3D.new()
		slab.collision_layer = 1
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(90.0, FLAT_THICK, 90.0)
		shape.shape = box
		slab.add_child(shape)
		_game.add_child(slab)
		var ball: Vector3 = _ground(drop_in)
		_flat_at = ball + heading * FLAT_AHEAD + Vector3.UP * FLAT_LIFT
		slab.global_position = _flat_at - Vector3.UP * (1.0 + FLAT_THICK * 0.5)
	if _scene_id == "p3":
		_slope_sites = _slope_candidates(_ground(drop_in))
	_swap["landmark"] = [mark.x, mark.y, mark.z] if mark != Vector3.INF else []
	_swap["drop_in"] = [drop_in.x, drop_in.y, drop_in.z]


func _slope_candidates(from: Vector3) -> Array:
	var terrain = _game.ctx.terrain
	var found: Array = []
	var x := from.x - SLOPE_REACH
	while x <= from.x + SLOPE_REACH:
		var z := from.z - SLOPE_REACH
		while z <= from.z + SLOPE_REACH:
			var away := Vector2(x - from.x, z - from.z).length()
			if away <= SLOPE_REACH and away >= 12.0:
				var gx: float = (terrain.height(x + 2.0, z) - terrain.height(x - 2.0, z)) / 4.0
				var gz: float = (terrain.height(x, z + 2.0) - terrain.height(x, z - 2.0)) / 4.0
				var angle := rad_to_deg(atan(sqrt(gx * gx + gz * gz)))
				if angle >= SLOPE_MIN_DEG and angle <= SLOPE_MAX_DEG:
					found.append([absf(angle - SLOPE_WANT_DEG), x, z])
			z += 2.0
		x += 2.0
	found.sort()
	var out: Array = []
	for c in found.slice(0, 12):
		out.append(_ground(Vector3(c[1], 0.0, c[2])))
	return out


func _step_carve() -> void:
	var kit = _kit()
	if kit == null:
		_errors.append("p3 needs Rivet: the combat has no RivetKit")
		return
	var at: Vector3 = _game.player.ball_position()
	var breach := _slots % 2 == 0
	_slots += 1
	if breach:
		_landing(kit, at, "stand")
		return
	var heading := _stand_heading
	var row := _row(at, "full_cut", "stand")
	var built: int = kit.terrain.builds
	var begin := Time.get_ticks_usec()
	kit.full_cut(at, heading, 1.0)
	kit._step_cuts(Engine.get_physics_frames() + kit.cut_ticks)
	row["landing_ms"] = snappedf((Time.get_ticks_usec() - begin) / 1000.0, 0.001)
	row["ms"] = row["landing_ms"]
	row["builds"] = kit.terrain.builds - built
	row["parts"] = ((kit.volume_indicator.shapes.get("rivet_scar", {}) as Dictionary).get("cells", []) as Array).size()
	_carves.append(row)


func _row(at: Vector3, kind: String, where: String) -> Dictionary:
	var heading := _stand_heading
	var row := {"frame": _frame, "kind": kind, "where": where, "at": [at.x, at.y, at.z], "heading": [heading.x, heading.y, heading.z],
		"landing_tick": Engine.get_physics_frames()}
	var space: PhysicsDirectSpaceState3D = _game.ctx.root.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 6.0, Hitscan.WORLD)
	var hit := space.intersect_ray(ray)
	if not hit.is_empty():
		var normal: Vector3 = hit["normal"]
		row["normal"] = [snappedf(normal.x, 0.0001), snappedf(normal.y, 0.0001), snappedf(normal.z, 0.0001)]
		row["angle_deg"] = snappedf(rad_to_deg(acos(clampf(normal.y, -1.0, 1.0))), 0.01)
	return row


func _landing(kit, at: Vector3, where: String) -> void:
	var ult = _game.combat.ultimate
	if ult != null:
		ult._plan = {"legs": []}
	var row := _row(at, "breach", where)
	var built: int = kit.terrain.builds
	var hits_before: int = kit.carve_stats["breach_hits"]
	var queued: int = kit._late.size()
	var saved: int = kit.late_work
	if (_plant == "late-flat" and where == "slab") or (_plant == "stand-late" and where == "stand"):
		kit.late_work = 1
	var begin := Time.get_ticks_usec()
	kit.landing("p3", at, 1.0, 1.0)
	row["landing_ms"] = snappedf((Time.get_ticks_usec() - begin) / 1000.0, 0.001)
	kit.late_work = saved
	row["builds"] = kit.terrain.builds - built
	row["level"] = bool(kit.last_landing["level"])
	row["tick_ms"] = []
	if kit._late.size() > queued:
		row["late"] = kit._late.back()
		_pending.append(row)
	else:
		row["shares"] = 1
		row["work"] = int(kit.last_landing.get("work", 0))
		row["hit_in_call"] = int(kit.carve_stats["breach_hits"]) - hits_before
		if int(row["hit_in_call"]) == 1:
			row["hit_tick"] = Engine.get_physics_frames()
			row["ticks"] = int(row["hit_tick"]) - int(row["landing_tick"])
		else:
			_errors.append("p3: a %s Breach finished its carve in the landing call but its hit count rose %d (want 1)" % [where, int(row["hit_in_call"])])
	row["ms"] = row["landing_ms"]
	_hits_seen = kit.carve_stats["breach_hits"]
	_carves.append(row)


func _watch_hits() -> void:
	var kit = _kit()
	if kit == null or _pending.is_empty():
		return
	var tick_ms := snappedf((Time.get_ticks_usec() - _phys_start) / 1000.0, 0.001)
	for row in _pending:
		(row["tick_ms"] as Array).append(tick_ms)
		row["ms"] = maxf(float(row["ms"]), tick_ms)
	var hits: int = kit.carve_stats["breach_hits"]
	while hits > _hits_seen and not _pending.is_empty():
		var row: Dictionary = _pending.pop_front()
		_hits_seen += 1
		row["hit_tick"] = Engine.get_physics_frames()
		row["ticks"] = int(row["hit_tick"]) - int(row["landing_tick"])
		row["shares"] = int((row["late"] as Dictionary).get("shares", 0))
		row["work"] = int((row["late"] as Dictionary).get("work", 0))
		row.erase("late")
	_hits_seen = hits


func _step_slope() -> void:
	var kit = _kit()
	if kit == null or _plant == "no-slope":
		return
	if _slope_at == Vector3.INF:
		var space: PhysicsDirectSpaceState3D = _game.ctx.root.get_world_3d().direct_space_state
		for site: Vector3 in _slope_sites:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(site + Vector3.UP * 0.5, site + Vector3.DOWN * 6.0, Hitscan.WORLD))
			var face_deg := rad_to_deg(acos(clampf((hit["normal"] as Vector3).y, -1.0, 1.0))) if not hit.is_empty() else 0.0
			if face_deg >= SLOPE_MIN_DEG and face_deg <= 30.0:
				_slope_at = site
				_swap["slope_at"] = [site.x, site.y, site.z]
				break
		if _slope_at == Vector3.INF:
			return
	_landing(kit, _slope_at, "slope")


func _step_flat() -> void:
	var kit = _kit()
	if kit == null or _flat_at == Vector3.INF or _plant == "no-flat":
		return
	_landing(kit, _flat_at, "slab")


func _carve_stats() -> void:
	var kit = _game.combat.get_node_or_null("RivetKit")
	if kit == null:
		return
	for row in _carves:
		var at := Vector3(row["at"][0], row["at"][1], row["at"][2])
		var heading := Vector3(row["heading"][0], row["heading"][1], row["heading"][2])
		var breach: bool = row["kind"] == "breach"
		var reach: float = kit.breach_reach() if breach else Weapons.FULL_CUT_REACH
		var half: float = acos(PlayerBall.SKID_CONE) if breach else deg_to_rad(Weapons.FULL_CUT_DEG * 0.5)
		var sector: Dictionary = kit._sector_cells(at, heading, reach, half, 0.0 if breach else Weapons.FULL_CUT_WIDTH, Weapons.BREACH_INNER if breach else 0.0)
		var found: Dictionary = kit._terrain_near(at, sector["cells"])
		row["faces"] = (found["faces"] as Array).size()
		row["merged"] = TerrainFaces.merge(found["faces"]).size()
		if breach:
			row["level_merged"] = TerrainFaces.merge_level(found["faces"], RivetKit.LEVEL_GROUND_DEG, RivetKit.LEVEL_TOLERANCE_DEG, RivetKit.LEVEL_DEVIATION).size()
		row.erase("heading")
		row.erase("late")


func _max_by_ground() -> Dictionary:
	var out := {"flat": 0.0, "slope": 0.0, "full_cut": 0.0, "slab": 0.0, "stand": 0.0, "slope_site": 0.0}
	for row in _carves:
		var ms: float = float(row.get("ms", 0.0))
		if row["kind"] == "full_cut":
			out["full_cut"] = maxf(out["full_cut"], ms)
			continue
		var cls := "flat" if int(row.get("shares", 0)) == 1 else "slope"
		out[cls] = maxf(out[cls], ms)
		out["slope_site" if row["where"] == "slope" else row["where"]] = maxf(out["slope_site" if row["where"] == "slope" else row["where"]], ms)
	return out


func _where_summary() -> Dictionary:
	var out := {}
	for where in ["slab", "stand", "slope"]:
		var rows := _carves.filter(func(r): return r["kind"] == "breach" and r["where"] == where)
		var landing := 0.0
		var shares := 0
		var ticks := 0
		var angle := 0.0
		var work := 0
		for r in rows:
			work = maxi(work, int(r.get("work", 0)))
			landing = maxf(landing, float(r["landing_ms"]))
			shares = maxi(shares, int(r.get("shares", 0)))
			ticks = maxi(ticks, int(r.get("ticks", 0)))
			angle = maxf(angle, float(r.get("angle_deg", 0.0)))
		out[where] = {"n": rows.size(), "landing_ms_max": landing, "shares_max": shares, "ticks_max_measured": ticks, "angle_deg_max": angle, "work_max": work}
	return out


func _kit():
	return _game.combat.get_node_or_null("RivetKit")


func _open_counts() -> void:
	var kit = _kit()
	if kit == null:
		return
	if _scene_id == "p3" and kit._rivet():
		kit.warm_cycle()
	_carve_open = kit.carve_stats.duplicate()
	_terrain_open = {"builds": kit.terrain.builds, "hits": kit.terrain.hits, "warm_cycles": kit.warm_cycles}


func _window_counts() -> Dictionary:
	var kit = _kit()
	if kit == null or _carve_open.is_empty():
		return {}
	var carves := {}
	for key in kit.carve_stats:
		carves[key] = int(kit.carve_stats[key]) - int(_carve_open[key])
	var terrain := {"builds": kit.terrain.builds - int(_terrain_open["builds"]), "hits": kit.terrain.hits - int(_terrain_open["hits"]),
		"warm_cycles": kit.warm_cycles - int(_terrain_open["warm_cycles"])}
	return {"carve_window": carves, "terrain_window": terrain, "rivet": kit._rivet()}


func _gate_carves(counts: Dictionary) -> void:
	if not _scene_id in ["p1", "p3"]:
		return
	if counts.is_empty():
		_errors.append("%s: no RivetKit counts: the carve check cannot fire" % _scene_id)
		return
	var carves: Dictionary = counts["carve_window"]
	var terrain: Dictionary = counts["terrain_window"]
	var fired: int = int(carves["full_cut"]) + int(carves["breach_started"])
	if not bool(counts["rivet"]):
		_errors.append("%s: the pilot is not Rivet, so no carve or warm-up can run" % _scene_id)
	if _scene_id == "p1":
		if fired != 0 or int(carves["shares"]) != 0:
			_errors.append("p1 is the no-carve control but %d carves fired" % fired)
		if int(terrain["warm_cycles"]) < 1 and bool(counts["rivet"]):
			_errors.append("p1: no terrain warm-up cycle ran in the window, so the cache guard did not fire")
	else:
		if int(carves["full_cut"]) < 1:
			_errors.append("p3: no Full Cut committed in the window")
		if int(carves["breach_flat"]) < 1:
			_errors.append("p3: no flat-ground Breach carve in the window (%d started, %d uncut)" % [int(carves["breach_started"]), int(carves["breach_uncut"])])
		if int(carves["breach_slope"]) < 1:
			_errors.append("p3: no slope Breach carve in the window")
		var limit := int(ceil(SLOPE_HIT_SECONDS * Engine.physics_ticks_per_second))
		var hit := {"slab": 0, "stand": 0, "slope": 0}
		var level_deg: float = RivetKit.LEVEL_GROUND_DEG
		for row in _carves:
			if row["kind"] != "breach" or not row.has("ticks"):
				continue
			var where: String = row["where"]
			hit[where] += 1
			var angle := float(row.get("angle_deg", 99.0))
			if where == "slope":
				if int(row["ticks"]) > limit:
					_errors.append("p3: a slope Breach hit %d ticks after landing, measured (the ruling: within %d, %.2f s)" % [int(row["ticks"]), limit, SLOPE_HIT_SECONDS])
				if int(row.get("shares", 0)) < 2:
					_errors.append("p3: a slope Breach (%.2f degrees) finished in %d share; the slope site must keep the late path" % [angle, int(row.get("shares", 0))])
				if angle <= level_deg:
					_errors.append("p3: the slope site is level ground (%.2f degrees, level is under %.1f)" % [angle, level_deg])
				continue
			if int(row["ticks"]) != 0 or int(row.get("hit_in_call", 0)) != 1:
				_errors.append("p3: a level-ground (%s) Breach hit %d ticks after landing, measured (the ruling: the same tick)" % [where, int(row["ticks"])])
			if where == "slab" and angle > LEVEL_DEG:
				_errors.append("p3: the slab is not level (%.2f degrees)" % angle)
			if where == "stand" and angle > level_deg:
				_errors.append("p3: the stand is not level ground (%.2f degrees, level is under %.1f)" % [angle, level_deg])
		for where in hit:
			if int(hit[where]) < 1:
				_errors.append("p3: no %s Breach hit; each location needs one" % where)
		if int(carves["breach_hits"]) < 1:
			_errors.append("p3: no Breach carve hit in the window")
		if int(carves["shares"]) < 1:
			_errors.append("p3: no carve share ran in the window")
		if _carves.is_empty():
			_errors.append("p3: no carve rows recorded")
		if not _pending.is_empty():
			_errors.append("p3: %d queued Breach carves never hit inside the window" % _pending.size())
	if bool(counts["rivet"]) and int(terrain["builds"]) > 0:
		_errors.append("%s: the terrain cache started %d builds in %d warm-up cycles while Rivet stood (bound 0)" % [_scene_id, int(terrain["builds"]), int(terrain["warm_cycles"])])


func _record_done() -> bool:
	if _view != "swap":
		return _frame >= RECORD_FRAMES
	if _frame >= SWAP_FRAMES_MAX:
		_errors.append("p2 reached %d frames in segment %s without landing" % [SWAP_FRAMES_MAX, _segment])
		return true
	return _frame >= RECORD_FRAMES and _segment == "after"


func _resident() -> int:
	var count := 0
	for root in _game.ctx.terrain._roots:
		if root != null:
			count += 1
	return count


func _snapshot() -> Dictionary:
	var rss_kb := -1
	var status := FileAccess.open("/proc/self/status", FileAccess.READ)
	while status != null and rss_kb < 0:
		var line := status.get_line()
		if line.begins_with("VmRSS:"):
			rss_kb = int(line.split(":")[1].strip_edges().split(" ")[0])
		elif line == "" and status.eof_reached():
			break
	var mb := 1.0 / 1048576.0
	return {
		"frame": _frame, "segment": _segment, "stage": _game.ctx.terrain.stage, "resident_stages": _resident(),
		"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) * mb, 0.01),
		"static_max_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC_MAX) * mb, 0.01),
		"video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) * mb, 0.01),
		"texture_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) * mb, 0.01),
		"buffer_mb": snappedf(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) * mb, 0.01),
		"rss_mb": snappedf(rss_kb / 1024.0, 0.01),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
	}


func _enter_segment(segment: String) -> void:
	_segment = segment
	_segment_at[segment] = _frame + 1


func _step_swap() -> void:
	var terrain = _game.ctx.terrain
	match _segment:
		"":
			_memory["one_stage"] = _snapshot()
			_enter_segment("build")
			var started := Time.get_ticks_usec()
			terrain.prepare(2)
			_swap["prepare_ms"] = (Time.get_ticks_usec() - started) / 1000.0
		"build":
			var ground = terrain.park_ground(2)
			var scatter: Node = terrain.geometry_root(2).get_node_or_null("GroundScatter") if terrain.is_ready(2) else null
			if ground == null or not terrain.is_ready(2) or not terrain.rows_ready(2) or scatter == null or not scatter.is_ready():
				return
			_memory["two_stages"] = _snapshot()
			_swap["build_ground_frame_max_ms"] = ground.frame_usec_max / 1000.0
			_swap["build_ground_step_max_ms"] = ground.slowest_usec / 1000.0
			_swap["build_ground_step_at"] = ground.slowest_step
			_swap["build_worker_pieces"] = ground.worker_pieces
			_swap["build_scatter_step_max_ms"] = scatter.slowest_usec / 1000.0
			_swap["build_scatter_frame_max_ms"] = scatter.frame_usec_max / 1000.0
			var rows: Node = terrain.park_rows(2)
			_swap["build_rows_step_max_ms"] = rows.slowest_usec / 1000.0
			_swap["build_rows_frame_max_ms"] = rows.frame_usec_max / 1000.0
			_swap["build_rows_threaded_loads"] = rows.threaded_loads
			_enter_segment("flight")
			_game.player.set_frozen(false)
			_game.flow._set_state(Flow.LAUNCH)
			_game.world._on_reward_chosen("")
			_swap["launched"] = _game.flow._launched
		"flight":
			if terrain.stage != 2:
				return
			_swap["use_ms"] = terrain.last_use_usec / 1000.0
			_swap["stage_1_freed"] = terrain.park_ground(1) == null
			_enter_segment("landing")
		"landing":
			if not _game.player.state.grounded:
				_landed = 0
				return
			_landed += 1
			if _landed < LANDED_FRAMES:
				return
			_memory["after_swap"] = _snapshot()
			var ground = terrain.park_ground(2)
			_swap["after_ground_frame_max_ms"] = ground.frame_usec_max / 1000.0
			_enter_segment("after")


func _build_scene() -> void:
	if _view != "fight":
		_build_stand()
		return
	var scene: Dictionary = SCENES[_scene_id]
	var home: Vector3 = _game.ctx.terrain.beacon_point(1) + Vector3(0, 0, 22)
	_game.player.reset_to(_ground(home))
	_game.camera.snap(Vector3.FORWARD)
	var ball: Vector3 = _ground(home)
	for i in int(scene["packs"]):
		var row: Dictionary = Director.PACKS[PACK_ORDER[i % PACK_ORDER.size()]]
		var centre := ball + Vector3.FORWARD * (16.0 + 4.0 * float(i / 3)) + Vector3.RIGHT * (-9.0 + 9.0 * float(i % 3))
		var kinds := [row["controller"], row["punisher"], "chaser", "chaser"]
		for k in kinds.size():
			var spot := centre + Vector3.RIGHT * (float(k) - 1.5) * 2.2
			var enemy: Node3D = _game.ctx.spawner.spawn_enemy(String(kinds[k]), _ground(spot))
			if enemy != null:
				_load_slots.append({"node": enemy, "kind": String(kinds[k]), "offset": spot - ball})
	_commit_threats(scene, ball)


func _commit_threats(scene: Dictionary, ball: Vector3) -> void:
	var n := int(scene["per_type"])
	var fwd := Vector3.FORWARD
	var right := fwd.cross(Vector3.UP).normalized()
	var terrain = _game.ctx.terrain
	var parent: Node = _game.ctx.root
	for i in n:
		var a := deg_to_rad(-60.0 + 120.0 * (float(i) + 0.5) / float(n))
		var dir := fwd.rotated(Vector3.UP, a)
		var near := 6.0 + 3.0 * float(i % 3)
		var ring = Telegraph.ring(parent, terrain, Threat.Type.INSTANT, ball + dir * near, 6.0)
		ring.set_meta("warn", 2.5)
		_threats.append(ring)
		_threats.append(Telegraph.wave(parent, terrain, ball + dir * (near + 8.0), 10.0, 6.0, 0.5))
		var land := ball + dir.rotated(Vector3.UP, 0.25) * (near + 4.0)
		var shell = Telegraph.ring(parent, terrain, Threat.Type.PROJECTILE, land, 3.5)
		shell.set_flight(_ground(land + dir * 18.0 + right * 4.0, 1.5), 6.0)
		shell.set_meta("warn", 2.0)
		_threats.append(shell)
		var lane_from := ball + dir.rotated(Vector3.UP, -0.3) * (near + 14.0)
		var lane = Telegraph.lane(parent, terrain, Threat.Type.LANE, lane_from, ball - lane_from, 16.0, 3.0)
		lane.set_meta("warn", 2.0)
		_threats.append(lane)
	if bool(scene["warden"]):
		_wake_warden(ball, fwd)


func _wake_warden(ball: Vector3, fwd: Vector3) -> void:
	var warden = _game.flow.warden
	if warden == null or not is_instance_valid(warden):
		_warden_note = "fallback: no live Warden, 4 extra instant rings"
		for i in 4:
			var at := ball + fwd.rotated(Vector3.UP, deg_to_rad(-30.0 + 20.0 * i)) * 12.0
			_threats.append(Telegraph.ring(_game.ctx.root, _game.ctx.terrain, Threat.Type.INSTANT, at, 6.0))
		return
	var at := ball + fwd * 16.0
	at.y = Telegraph.ground_under(_game.ctx.terrain, at)
	warden.global_position = at
	warden.max_hp = 1000000.0
	warden.hp = warden.max_hp
	warden.set("_pulse_clock", Warden.PULSE_CYCLE - Warden.PULSE_TELEGRAPH)
	_warden_note = "moved to 16 m ahead, pulse charge started, HP raised"


func _step_threats(delta: float) -> void:
	for node in _threats:
		if not is_instance_valid(node):
			continue
		if node.type == Threat.Type.WAVE:
			if node.is_spent():
				node.age = 0.0
			node.step(delta)
		else:
			node.age = fposmod(node.age + delta, float(node.get_meta("warn", 2.0)))
			node.set_progress(minf(node.age / float(node.get_meta("warn", 2.0)), 0.95))


func _maintain_load() -> void:
	var ball: Vector3 = _game.player.ball_position()
	if is_instance_valid(_game.flow.warden):
		_game.flow.warden.hp = _game.flow.warden.max_hp
	for slot in _load_slots:
		var enemy = slot["node"]
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.is_dead():
			slot["node"] = _game.ctx.spawner.spawn_enemy(slot["kind"], _ground(ball + slot["offset"]))
		elif enemy.global_position.distance_to(ball) > 35.0:
			enemy.global_position = _ground(ball + slot["offset"])


func _hold_fire() -> void:
	_driver.source.hold = {"fire_held": true, "move": Vector2(0.25, 0.25)}
	var ball: Vector3 = _game.player.ball_position()
	var best: Node3D = null
	var best_d := INF
	for node in get_nodes_in_group("enemy"):
		if not (node is Node3D) or not is_instance_valid(node) or node is Warden:
			continue
		var d := ball.distance_to((node as Node3D).global_position)
		if d < best_d and d < 40.0:
			best_d = d
			best = node
	if best == null:
		return
	var cam = _game.camera
	var flat := best.global_position - ball
	flat.y = 0.0
	if flat.length() < 0.3:
		return
	var step := 5.0 / Engine.physics_ticks_per_second
	var dyaw := clampf(wrapf(atan2(-flat.x, -flat.z) - cam.yaw, -PI, PI), -step, step)
	var dpitch := clampf(-0.30 - cam.pitch, -step, step)
	cam.look(Vector2(-dyaw / 0.0022, -dpitch / 0.0022))


func _check_load() -> void:
	var scene: Dictionary = SCENES[_scene_id]
	var enemies := _load_slots.filter(func(s): return is_instance_valid(s["node"]) and not s["node"].is_queued_for_deletion()).size()
	var threats := _threats.filter(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion()).size()
	if enemies != int(scene["packs"]) * 4 or threats < int(scene["per_type"]) * 4:
		_load_ok = false


func _apply_ablations() -> void:
	var presentation = _game.presentation
	var audio = presentation.audio
	var vfx = presentation.vfx
	if _off.has("no-audio"):
		audio.process_mode = Node.PROCESS_MODE_DISABLED
		audio.sound_ready = false
		for child in audio.get_children():
			if child is AudioStreamPlayer:
				child.stop()
		if node_added.is_connected(audio._on_node_added):
			node_added.disconnect(audio._on_node_added)
		_ablation_notes["no-audio"] = {"listeners_cut": _cut_listeners(audio)}
	if _off.has("no-vfx"):
		var effects = _game.combat.effects
		for node in [vfx, vfx.root, effects]:
			node.process_mode = Node.PROCESS_MODE_DISABLED
		vfx.root.visible = false
		effects.visible = false
		for line in [vfx._trail, vfx._lines]:
			line.visible = false
		vfx.edge.get_parent().visible = false
		presentation.juice.vfx = null
		_ablation_notes["no-vfx"] = {"listeners_cut": _cut_listeners(vfx)}
	if _off.has("no-machine-fx") and presentation.machine_fx != null:
		var machine = presentation.machine_fx
		machine.process_mode = Node.PROCESS_MODE_DISABLED
		machine.root.visible = false
		_ablation_notes["no-machine-fx"] = {"listeners_cut": _cut_listeners(machine)}
	if _off.has("no-hud"):
		_game.hud.process_mode = Node.PROCESS_MODE_DISABLED
		_game.hud.visible = false
		_ablation_notes["no-hud"] = {"listeners_cut": _cut_listeners(_game.hud)}
	if _off.has("no-trails"):
		vfx.trails = false
		vfx._trail.mesh.clear_surfaces()
		vfx._lines.mesh.clear_surfaces()
		vfx._trail_points.clear()
		vfx._streaks.clear()
	for node in get_nodes_in_group("enemy"):
		_ablate_new(node)
	for node in get_nodes_in_group("telegraph"):
		_ablate_new(node)


func _ablate_new(node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	if _off.has("no-enemy-ai") and node.is_in_group("enemy"):
		node.set_process(false)
		node.set_physics_process(false)
	if _off.has("no-telegraph-draw") and node.has_method("painter"):
		var painter = node.painter()
		if painter != null:
			painter.visible = false
			node.set("_painter", null)
			_painters.append(painter)


func _cut_listeners(owner: Object) -> int:
	var cut := 0
	var events: Object = _game.events
	for info in events.get_signal_list():
		for connection in events.get_signal_connection_list(info["name"]):
			var callable: Callable = connection["callable"]
			if callable.get_object() == owner:
				events.disconnect(info["name"], callable)
				cut += 1
	return cut


func _listeners_of(owner: Object) -> int:
	var count := 0
	var events: Object = _game.events
	for info in events.get_signal_list():
		for connection in events.get_signal_connection_list(info["name"]):
			if (connection["callable"] as Callable).get_object() == owner:
				count += 1
	return count


func _checks() -> Dictionary:
	var audio = _game.presentation.audio
	var vfx = _game.presentation.vfx
	var effects = _game.combat.effects
	var engine = audio.engine
	var spawned := 0
	for kind in vfx.spawned:
		spawned += int(vfx.spawned[kind])
	var emitting := 0
	for child in vfx.root.get_children():
		if child is CPUParticles3D and child.emitting:
			emitting += 1
	var music_peak := 0.0
	for v in engine.out_music:
		music_peak = maxf(music_peak, maxf(absf(v.x), absf(v.y)))
	var enemies_thinking := 0
	var enemy_positions := {}
	for node in get_nodes_in_group("enemy"):
		if node.is_physics_processing() or node.is_processing():
			enemies_thinking += 1
		if node is Node3D:
			enemy_positions[node.get_instance_id()] = (node as Node3D).global_position
	var meshes := {}
	var detached_visible := 0
	for painter in _painters:
		if is_instance_valid(painter):
			if painter.is_visible_in_tree():
				detached_visible += 1
			for layer in painter._layers:
				var mesh = painter._layers[layer].mesh
				meshes["%d:%s" % [painter.get_instance_id(), layer]] = mesh.get_instance_id() if mesh != null else 0
	var painters_visible := 0
	for node in get_nodes_in_group("telegraph"):
		var painter = node.painter() if node.has_method("painter") else null
		if painter != null and painter.is_visible_in_tree():
			painters_visible += 1
	return {
		"band_clock": engine.clock, "band_is_silent": engine is SilentBand,
		"band_skipped_mixes": engine.skipped_mixes if engine is SilentBand else -1,
		"band_out_peak": music_peak, "band_voices": engine.voice_count(),
		"audio_processing": audio.can_process(), "audio_listeners": _listeners_of(audio),
		"audio_cues_logged": audio.cue_log_total,
		"vfx_clock": vfx._clock, "vfx_processing": vfx.can_process(), "vfx_glyphs_spawned": spawned,
		"vfx_particles_emitting": emitting, "vfx_listeners": _listeners_of(vfx),
		"juice_has_vfx": _game.presentation.juice.vfx != null,
		"effects_processing": effects.can_process(),
		"trail_points": vfx._trail_points.size(), "speed_lines": vfx._streaks.size(),
		"hud_processing": _game.hud.can_process(), "hud_visible": _game.hud.visible,
		"hud_listeners": _listeners_of(_game.hud),
		"enemies": enemy_positions.size(), "enemies_thinking": enemies_thinking,
		"telegraphs": get_nodes_in_group("telegraph").size(), "painters_visible": painters_visible, "detached_painters_visible": detached_visible,
		"detached_painter_meshes": meshes, "_enemy_positions": enemy_positions,
	}


func _check_delta() -> Dictionary:
	if _probe_open.is_empty() or _probe_close.is_empty():
		return {}
	var a := _probe_open
	var b := _probe_close
	var moved := 0.0
	var tracked := 0
	for id in a["_enemy_positions"]:
		if b["_enemy_positions"].has(id):
			moved += (a["_enemy_positions"][id] as Vector3).distance_to(b["_enemy_positions"][id])
			tracked += 1
	var repainted := 0
	for key in a["detached_painter_meshes"]:
		if b["detached_painter_meshes"].get(key, -1) != a["detached_painter_meshes"][key]:
			repainted += 1
	var close := b.duplicate()
	close.erase("_enemy_positions")
	close.erase("detached_painter_meshes")
	return {
		"at_end": close,
		"band_clock_advanced": b["band_clock"] - a["band_clock"],
		"band_mixes_skipped_in_window": b["band_skipped_mixes"] - a["band_skipped_mixes"],
		"audio_cues_in_window": b["audio_cues_logged"] - a["audio_cues_logged"],
		"vfx_clock_advanced": b["vfx_clock"] - a["vfx_clock"],
		"vfx_glyphs_in_window": b["vfx_glyphs_spawned"] - a["vfx_glyphs_spawned"],
		"enemy_metres_moved": snappedf(moved, 0.01), "enemies_tracked": tracked,
		"detached_painters": a["detached_painter_meshes"].size(), "detached_painters_repainted": repainted,
	}


func _stats(key: String) -> Dictionary:
	var values: Array = _samples.map(func(s): return float(s[key]))
	if values.is_empty() or values.max() < 0.0:
		return {}
	values.sort()
	var total := 0.0
	for v in values:
		total += v
	return {"p50": snappedf(_pct(values, 0.5), 0.001), "p95": snappedf(_pct(values, 0.95), 0.001),
		"p99": snappedf(_pct(values, 0.99), 0.001), "mean": snappedf(total / values.size(), 0.001),
		"max": snappedf(values.back(), 0.001)}


static func _segment_stats(rows: Array) -> Dictionary:
	var out := {"n": rows.size()}
	if rows.is_empty():
		return out
	for key in ["frame_ms", "process_ms", "physics_ms", "render_cpu_ms", "gpu_ms", "draws"]:
		var values: Array = rows.map(func(s): return float(s[key]))
		values.sort()
		out[key] = {"p99": snappedf(_pct(values, 0.99), 0.001), "max": snappedf(values.back(), 0.001)}
	return out


static func _pct(sorted: Array, q: float) -> float:
	return sorted[mini(int(floor(q * (sorted.size() - 1) + 0.5)), sorted.size() - 1)]


func _finish() -> void:
	if _phase == "finished":
		return
	_phase = "finished"
	var counts := _window_counts()
	if _view == "carve":
		_carve_stats()
	_gate_carves(counts)
	if _samples.size() < RECORD_FRAMES:
		_errors.append("recorded %d of %d frames" % [_samples.size(), RECORD_FRAMES])
	var segments := {}
	if _view == "swap":
		for segment in ["build", "flight", "landing", "after"]:
			segments[segment] = _segment_stats(_samples.filter(func(s): return s["segment"] == segment))
		segments["flight_and_landing"] = _segment_stats(_samples.filter(func(s): return s["segment"] in ["flight", "landing"]))
	if not _load_ok:
		_errors.append("load fell below target during the window")
	var stats := {}
	for key in KEYS:
		stats[key] = _stats(key)
	var by_ticks := {}
	for n in [0, 1, 2, 3]:
		var frames: Array = _samples.filter(func(s): return int(s["ticks"]) == n).map(func(s): return float(s["frame_ms"]))
		if frames.is_empty():
			continue
		frames.sort()
		by_ticks[str(n)] = {"n": frames.size(), "p50": snappedf(_pct(frames, 0.5), 0.001), "p99": snappedf(_pct(frames, 0.99), 0.001)}
	if _series != "":
		var rows := PackedStringArray(["frame\tprocess_ms\tframe_ms\tphysics_ms\tticks\tharness_ms"])
		for i in _samples.size():
			var f: Dictionary = _samples[i]
			rows.append("%d\t%.3f\t%.3f\t%.3f\t%d\t%.3f" % [i, f["process_ms"], f["frame_ms"], f["physics_ms"], f["ticks"], f["harness_ms"]])
		var series_file := FileAccess.open(_series, FileAccess.WRITE)
		if series_file != null:
			series_file.store_string("\n".join(rows) + "\n")
			series_file.close()
	var ablations: Array = _off.keys()
	ablations.sort()
	var info := {
		"tool": "perf_bench", "scene": _scene_id, "table": _table, "scene_def": SCENES[_scene_id], "ablations": ablations,
		"errors": _errors, "valid": _errors.is_empty(),
		"godot": Engine.get_version_info()["string"], "display": DisplayServer.get_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"size": [root.get_texture().get_width(), root.get_texture().get_height()],
		"physics_hz": Engine.physics_ticks_per_second, "seed": RIVET_SEED,
		"warm_frames": _warm_frames, "warm_seconds": _warm_seconds, "record_frames": _samples.size(), "warden": _warden_note,
		"stills_taken": _game.run_moments.shots_taken if _game != null and _game.run_moments != null else -1,
		"sound_ready_at_s": snappedf(_sound_ready_s, 0.01), "parts_granted": _granted.size(), "telegraphs_committed": _threats.size(),
		"perf_monitor_value_changes": _perf_updates, "mark_materials": Threat.Painter.materials_built, "mark_materials_built_in_window": Threat.Painter.materials_built - _materials_at_record,
		"wall_seconds": snappedf(_seconds_since(_start_usec), 0.1),
		"source_sha256": {"res://tools/perf_bench.gd": FileAccess.get_sha256("res://tools/perf_bench.gd"),
			"res://src/presentation/vfx.gd": FileAccess.get_sha256("res://src/presentation/vfx.gd")},
		"stats": stats, "frame_ms_by_ticks": by_ticks,
		"ablation_notes": _ablation_notes, "checks": _check_delta(),
		"view": _view, "memory": _memory, "swap": _swap, "segments": segments, "segment_starts": _segment_at,
		"carve_window": counts.get("carve_window", {}), "terrain_window": counts.get("terrain_window", {}), "pilot": _pilot, "plant": _plant,
		"carves": _carves, "carve_budget_ms": CARVE_BUDGET_MS,
		"carve_max_ms_by": _max_by_ground(), "carve_where": _where_summary(),
		"carve_builds": _carves.reduce(func(n, c): return n + int(c.get("builds", 0)), 0),
		"notes": {"derived": "none: a queued carve's ticks to the hit are read from the kit's breach_hits count after its own _step_late, one physics tick at a time; a light (slab) carve's 0 ticks are its breach_hits rise inside the landing call (hit_in_call 1)",
			"old_keying_at_the_p3_stand": "planted keep_one_placement made 0 builds at this stand (Andrew's park shares no shape placed twice near it); the hitch fix is proven synthetically, by tests/rivet_warm_hitch_test.gd",
			"carve_time": "landing_ms is the landing call (first share, and the hit when light); tick_ms is each physics tick a queued carve was in (its later shares and its hit)"},
		"carve_max_ms": _carves.reduce(func(m, c): return maxf(m, float(c.get("ms", 0.0))), 0.0),
		"carves_over_budget": _carves.filter(func(c): return float(c.get("ms", 0.0)) > CARVE_BUDGET_MS).size(),
	}
	var file := FileAccess.open(_out, FileAccess.WRITE)
	if file == null:
		printerr("perf_bench: could not write " + _out)
		quit(1)
		return
	file.store_string(JSON.stringify(info, "  "))
	file.close()
	var where := _where_summary()
	if _scene_id == "p3":
		print("perf_bench: p3 stand Breach landing-share %.3f ms, %d shares, %d ticks to the hit (measured), ground angle max %.2f deg | slab Breach landing-share %.3f ms, %d shares, %d ticks (measured), angle max %.2f deg | slope Breach landing-share %.3f ms, %d shares, %d ticks (measured), angle max %.2f deg | work (parts) stand %d slab %d slope %d | max_ms %s" % [
			where["stand"]["landing_ms_max"], where["stand"]["shares_max"], where["stand"]["ticks_max_measured"], where["stand"]["angle_deg_max"],
			where["slab"]["landing_ms_max"], where["slab"]["shares_max"], where["slab"]["ticks_max_measured"], where["slab"]["angle_deg_max"],
			where["slope"]["landing_ms_max"], where["slope"]["shares_max"], where["slope"]["ticks_max_measured"], where["slope"]["angle_deg_max"],
			where["stand"]["work_max"], where["slab"]["work_max"], where["slope"]["work_max"], _max_by_ground()])
	print("perf_bench: %s carve_window %s terrain_window %s valid %s errors %s" % [_scene_id, counts.get("carve_window", {}), counts.get("terrain_window", {}), _errors.is_empty(), _errors])
	print("perf_bench: %s %s frame p50 %.2f p99 %.2f ms -> %s" % [_scene_id, ablations, stats["frame_ms"].get("p50", -1.0), stats["frame_ms"].get("p99", -1.0), _out])
	quit(0 if _errors.is_empty() else 1)


func _level_sites() -> void:
	var kit = _kit()
	if kit == null:
		_errors.append("level-sites needs Rivet: the combat has no RivetKit")
		return
	var ult = _game.combat.ultimate
	if ult != null:
		ult._plan = {"legs": []}
	kit.warm_cycle()
	kit.terrain.finish()
	var scale := _sites_scale if _sites_scale > 0.0 else 2.0
	kit.late_work = roundi(float(RivetKit.LATE_WORK) * scale / 2.0)
	var budget: int = kit.landing_work(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = _sites_seed
	var centre: Vector3 = _game.player.ball_position()
	var rows: Array = []
	var tries := 0
	while rows.size() < _sites_count and tries < 4000:
		tries += 1
		var p := centre + Vector3(rng.randf_range(-50.0, 50.0), 0.0, rng.randf_range(-50.0, 50.0))
		var heading := Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU)
		var at: Vector3 = _ground(p)
		var row := _site_landing(kit, at, heading, budget)
		if bool(row["level"]):
			row["at"] = [snappedf(at.x, 0.01), snappedf(at.y, 0.01), snappedf(at.z, 0.01)]
			rows.append(row)
	var stand: Array = []
	var stand_row := {}
	for i in 5:
		stand_row = _site_landing(kit, _game.player.ball_position(), _stand_heading, budget)
		stand.append(float(stand_row["landing_ms"]))
		rows.append(stand_row.merged({"stand": true}))
	stand.sort()
	var sample: Array = rows.filter(func(r): return not r.has("stand"))
	var built := 0
	for r in rows:
		built += int(r["builds"])
	if built > 0:
		_errors.append("level-sites: %d terrain builds started inside timed landings (the cache was not warm)" % built)
	if sample.size() < _sites_count:
		_errors.append("level-sites: found %d of %d level sites in %d tries" % [sample.size(), _sites_count, tries])
	var summary := {"budget": budget, "seed": _sites_seed, "sites": sample.size(), "tries": tries, "fit": sample.filter(func(r): return r["fit"]).size(),
		"all": _ms_stats(sample), "fitting": _ms_stats(sample.filter(func(r): return r["fit"])), "stand_landing_ms_median": stand[2],
		"stand_fit": stand_row["fit"], "stand_work": stand_row["work"], "builds": built, "valid": _errors.is_empty(), "errors": _errors}
	var file := FileAccess.open(_out, FileAccess.WRITE)
	file.store_string(JSON.stringify({"summary": summary, "rows": rows}, "\t"))
	file.close()
	print("perf_bench: level-sites %s" % [summary])


class SiteRide extends RefCounted:
	var heading := Vector3.FORWARD
	var mode := 0
	var velocity := Vector3.ZERO
	var release_speed := 0.0


func _site_landing(kit, at: Vector3, heading: Vector3, budget: int) -> Dictionary:
	var ult = _game.combat.ultimate
	var stub := SiteRide.new()
	stub.heading = heading
	ult._ride = stub
	var aimed: Vector3 = kit._flat(kit._heading()).normalized()
	var built: int = kit.terrain.builds
	var queued: int = kit._late.size()
	var hits: int = kit.carve_stats["breach_hits"]
	var begin := Time.get_ticks_usec()
	kit.landing("p3", at, 1.0, 1.0)
	var total := (Time.get_ticks_usec() - begin) / 1000.0
	ult._ride = null
	var last: Dictionary = kit.last_landing
	var row := {"level": bool(last["level"]), "fit": int(kit.carve_stats["breach_hits"]) == hits + 1, "shares": int(last["shares"]),
		"work": int(last.get("work", 0)), "landing_ms": snappedf(total, 0.001)}
	while kit._late.size() > queued:
		kit._late.pop_back()
	kit.selected_shapes.clear()
	var reach: float = kit.breach_reach()
	var t0 := Time.get_ticks_usec()
	var late: Dictionary = kit._carve_late("p3", at, aimed, reach, 1.0, 0.0)
	var t1 := Time.get_ticks_usec()
	var done: bool = kit._shade_late(late, budget)
	var t2 := Time.get_ticks_usec()
	if done:
		kit._breach(kit._late_shape(late), at, aimed, reach, 1.0, 0.0)
	var t3 := Time.get_ticks_usec()
	kit.selected_shapes.clear()
	row["carve_ms"] = snappedf((t1 - t0) / 1000.0, 0.001)
	row["share_ms"] = snappedf((t2 - t1) / 1000.0, 0.001)
	row["breach_ms"] = snappedf((t3 - t2) / 1000.0, 0.001)
	row["builds"] = kit.terrain.builds - built
	return row


func _ms_stats(rows: Array) -> Dictionary:
	if rows.is_empty():
		return {"n": 0}
	var v: Array = rows.map(func(r): return float(r["landing_ms"]))
	v.sort()
	return {"n": v.size(), "median_ms": v[v.size() / 2], "p90_ms": v[mini(v.size() - 1, int(ceil(v.size() * 0.9)) - 1)], "max_ms": v.back()}
