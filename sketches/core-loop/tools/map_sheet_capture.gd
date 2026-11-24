extends SceneTree

# Sheets for the two picture halves of the map standard (project-guide/handoff/shared/world1/map-audit.md section G):
# point 1's picture ("point at the landmark", "light or wall?") and point 8b's silhouettes ("count the machines"). The
# real game on a world 1 park (the dam or the flume) with its own chase camera and the HUD hidden; the ball is frozen at
# each pose and the camera snapped behind it.
#
#   beam        8 poses on the riding lines: the drop-in, five on the ride in, then about 150 m and about 50 m from the
#               landmark's beam (the 50 m pose is the PF-28 near-fade read: light, not a wall). The camera faces the
#               ride (the graph's shortest way to the landmark, LOOK_STEPS nodes ahead), turned in to MAX_BEARING_DEG
#               of the beam at most, so the beam stands in frame but not at its centre. --control=1 hides the beam
#               (AncientBeam.visible = false) and changes nothing else.
#   silhouette  6 fight poses on the riding lines, spread from the drop-in to the landmark, each with 2 to 5 real world 1
#               machines staged ahead of the ball. The ground, sky and scenery draw flat in SKY (a fog that swallows
#               every fogged material) and each machine draws unshaded black with fog off, so a blind reader counts
#               black shapes. --control=1 hides one machine a pose, so a fair count reads one short.
#
#   $GODOT_BIN --path sketches/core-loop --resolution 1920x1080 --script res://tools/map_sheet_capture.gd -- \
#     --map=park_dam|park_flume --mode=beam|silhouette --out=<absolute dir> [--control=1]
#
# Run it with a scratch HOME and XDG folders (macOS keeps user:// under HOME); on the Mac only through
# scripts/gate/display-run.mjs once this tool is qualified there. It refuses a headless display (exit 2).
# Writes pose_01.png and on, sheet_<mode>[_control].png (tiles labelled with what each pose is), blind_sheet.png
# (the same tiles numbered only, so the reader learns neither distances, counts nor which run it is) and frames.json.
# Exit 0 done, 2 bad arguments or no display, 3 the output folder, 4 the game or a pose failed.
#
# Limits. The machines are staged: spawned through the game's own spawner where each pose puts them, given STAGE_TICKS
# to settle, then stilled (process off), so none attacks and none is mid-move. A staged pose is kept only when every
# machine is in frame, unblocked from the lens by ground, and apart from the others on screen; otherwise the next line
# node near that point of the ride is tried. Calm is on, so no director pack joins; any other enemy is hidden and
# counted in frames.json. Beam poses read the stage graph's LINE nodes with SIGHT_OK, none roofed; a NEAR_M pose no
# line reaches stands on open sighted ground instead and records on_line false.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const LandmarkBeam := preload("res://src/presentation/landmark_beam.gd")

# The stage index each world 1 park plays as (park_defs.gd).
const MAPS := {"park_dam": 1, "park_flume": 2}
const MODES := ["beam", "silhouette"]
const SIZE := Vector2i(1920, 1080)
const TILE := Vector2i(640, 360)
const LABEL_H := 34
const BEAM_POSES := 8
# The last two beam poses stand this far from the beam's axis; RIDE_POSES evenly between the drop-in and the first.
const NEAR_M := [150.0, 50.0]
const RIDE_POSES := 5
# Two poses stand at least this far apart.
const POSE_GAP_M := 40.0
# A NEAR_M pose no riding-line node reaches within this many metres stands on the nearest open, sighted ground the
# ball can reach instead (the flume's lines end at its beacon, 99 m from the beam), and its record says so.
const NEAR_TOLERANCE_M := 20.0
const LOOK_STEPS := 5
const MAX_BEARING_DEG := 40.0
const EYE_LIFT := 1.2
const SETTLE := 40
# Silhouette staging: machines a pose, in pose order; the kinds go round in this order.
const COUNTS := [3, 5, 2, 4, 3, 5]
const KINDS := ["chaser", "lobber", "swatter", "hooker", "netcaster", "boom_tender"]
const SPREAD_M := 7.0
const NEAR_STAND_M := 22.0
const DEPTH_STEP_M := 9.0
const STAND_LIFT := 1.0
const STAGE_TICKS := 10
const TRIES := 8
const SCREEN_MARGIN := 24.0
const SKY := Color(0.78, 0.86, 0.93)
const INK := Color(0.0, 0.0, 0.0)

var opts := {}
var game
var graph
var beam: Node3D
var records: Array = []
var failed := ""
var _ink: StandardMaterial3D


func _initialize() -> void:
	opts = parse_args(OS.get_cmdline_user_args())
	if not opts["ok"] or DisplayServer.get_name() == "headless":
		printerr("map_sheet_capture: %s" % (opts.get("error", "") if not opts["ok"] else "needs a rendered display"))
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(opts["out"]) != OK:
		quit(3)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


# {ok, map, mode, out, control, error} from the user arguments.
static func parse_args(args: PackedStringArray) -> Dictionary:
	var o := {"ok": false, "map": "", "mode": "", "out": "", "control": false, "error": ""}
	for arg in args:
		if arg.begins_with("--map="):
			o["map"] = arg.trim_prefix("--map=")
		elif arg.begins_with("--mode="):
			o["mode"] = arg.trim_prefix("--mode=")
		elif arg.begins_with("--out="):
			o["out"] = arg.trim_prefix("--out=")
		elif arg.begins_with("--control="):
			var v := arg.trim_prefix("--control=")
			if v not in ["0", "1"]:
				o["error"] = "--control takes 0 or 1"
				return o
			o["control"] = v == "1"
		else:
			o["error"] = "unknown argument %s" % arg
			return o
	if not MAPS.has(o["map"]):
		o["error"] = "--map must be one of %s" % ", ".join(MAPS.keys())
	elif o["mode"] not in MODES:
		o["error"] = "--mode must be beam or silhouette"
	elif not String(o["out"]).is_absolute_path() or String(o["out"]).begins_with("res://") or String(o["out"]).begins_with("user://"):
		o["error"] = "--out must be an absolute folder"
	else:
		o["ok"] = true
	return o


static func park_data(map_id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/%s.json" % map_id))


static func load_graph(map_id: String):
	return ParkGraph.read(ParkMap.graph_path_for("%s.json" % map_id))


static func flat_distance(a: Vector3, axis: Vector2) -> float:
	return Vector2(a.x - axis.x, a.z - axis.y).length()


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized()


# Signed angle in degrees from a flat heading to the direction from eye to the axis, positive to the right.
static func bearing_deg(heading: Vector3, eye: Vector3, axis: Vector2) -> float:
	var to := Vector2(axis.x - eye.x, axis.y - eye.z)
	var h := Vector2(heading.x, heading.z)
	if to.length_squared() < 1e-6 or h.length_squared() < 1e-6:
		return 0.0
	# With x right of a -z forward, a positive cross of heading onto the target is a turn to the right.
	return rad_to_deg(atan2(h.x * to.y - h.y * to.x, h.dot(to)))


# The heading turned toward the axis until it is within max_deg of it.
static func clamp_toward(heading: Vector3, eye: Vector3, axis: Vector2, max_deg: float) -> Vector3:
	var b := bearing_deg(heading, eye, axis)
	if absf(b) <= max_deg:
		return flat(heading)
	var turn := deg_to_rad(b - signf(b) * max_deg)
	return flat(heading.rotated(Vector3.UP, -turn))


# Riding-line nodes a pose may stand on: LINE, not roofed, a finite way to the landmark, and (when sight is asked)
# SIGHT_OK. Decks are left out when ground_only is set, so staged machines stand on the terrain.
static func line_nodes(g, need_sight: bool, ground_only: bool, need := ParkGraph.LINE) -> PackedInt32Array:
	var out := PackedInt32Array()
	for n in g.node_count():
		var f: int = g.flags(n)
		if f & need == 0 or f & ParkGraph.UNDER != 0:
			continue
		if need_sight and f & ParkGraph.SIGHT_OK == 0:
			continue
		if ground_only and (f & ParkGraph.DECK != 0 or n >= ParkGraph.SIDE * ParkGraph.SIDE):
			continue
		if not is_finite(g.d_landmark_node(n)):
			continue
		out.append(n)
	return out


# The way the ride goes from a node: LOOK_STEPS ground steps down the landmark distance field, flattened. Toward the
# axis when the walk goes nowhere.
static func ride_heading(g, node: int, axis: Vector2) -> Vector3:
	var at := node
	for i in LOOK_STEPS:
		var best := -1
		var best_d: float = g.d_landmark_node(at)
		for e in range(g.off[at], g.off[at + 1]):
			var m: int = g.to[e]
			if g.d_landmark_node(m) < best_d:
				best_d = g.d_landmark_node(m)
				best = m
		if best < 0:
			break
		at = best
	var h := flat(g.position(at) - g.position(node))
	if h == Vector3.ZERO:
		var p: Vector3 = g.position(node)
		h = flat(Vector3(axis.x - p.x, 0.0, axis.y - p.z))
	return h


# The candidate nearest target metres from the axis that stands POSE_GAP_M clear of every taken pose; ties go to the
# shorter ride to the landmark, then the lower node. -1 when none.
static func _pick(g, nodes: PackedInt32Array, axis: Vector2, target: float, taken: Array) -> int:
	var best := -1
	var best_key := Vector3(INF, INF, INF)
	for n in nodes:
		var p: Vector3 = g.position(n)
		if taken.any(func(q: Vector3): return Vector2(q.x - p.x, q.z - p.z).length() < POSE_GAP_M):
			continue
		var key := Vector3(absf(flat_distance(p, axis) - target), g.d_landmark_node(n), n)
		if key < best_key:
			best_key = key
			best = n
	return best


static func _pose(id: String, kind: String, at: Vector3, heading: Vector3, axis: Vector2, node: int, on_line := true) -> Dictionary:
	var h := clamp_toward(heading, at, axis, MAX_BEARING_DEG)
	return {"id": id, "kind": kind, "node": node, "at": at, "heading": h, "ride_heading": flat(heading),
		"distance_m": flat_distance(at, axis), "bearing_deg": bearing_deg(h, at, axis), "on_line": on_line}


# The 8 beam poses for a park: the drop-in, RIDE_POSES evenly spaced (by distance from the beam) between it and the
# first NEAR_M, then one pose at each NEAR_M. axis is the beam's foot on the ground plane.
static func beam_poses(g, park: Dictionary, axis: Vector2) -> Array:
	var poses: Array = []
	var spawn := Vector2(park["spawn"]["at"][0], park["spawn"]["at"][1])
	var drop_node: int = g.nearest(spawn)
	var drop := Vector3(spawn.x, g.position(drop_node).y, spawn.y)
	poses.append(_pose("pose_01", "drop_in", drop, ParkMap.facing(float(park["spawn"]["heading_deg"])), axis, drop_node))
	var nodes := line_nodes(g, true, false)
	var open := line_nodes(g, true, false, ParkGraph.OPEN)
	var taken: Array = [drop]
	var d0 := flat_distance(drop, axis)
	var targets: Array = []
	for k in range(1, RIDE_POSES + 1):
		targets.append(["ride", lerpf(d0, NEAR_M[0], float(k) / float(RIDE_POSES + 1))])
	for near in NEAR_M:
		targets.append(["near_%d" % int(near), near])
	for t in targets:
		var n := _pick(g, nodes, axis, float(t[1]), taken)
		var on_line := true
		if String(t[0]) != "ride" and (n < 0 or absf(flat_distance(g.position(n), axis) - float(t[1])) > NEAR_TOLERANCE_M):
			n = _pick(g, open, axis, float(t[1]), taken)
			on_line = false
		if n < 0:
			return []
		var p: Vector3 = g.position(n)
		taken.append(p)
		poses.append(_pose("pose_%02d" % (poses.size() + 1), t[0], p, ride_heading(g, n, axis), axis, n, on_line))
	return poses


# Silhouette poses: COUNTS.size() points spread evenly along the ride (by d_spawn among ground line nodes), each with
# up to TRIES candidate nodes nearest that point of the ride, the first one first.
static func fight_poses(g, axis: Vector2) -> Array:
	var nodes := Array(line_nodes(g, false, true)).filter(func(n): return is_finite(g.d_spawn_node(n)))
	nodes.sort_custom(func(a, b): return g.d_spawn_node(a) < g.d_spawn_node(b) or (g.d_spawn_node(a) == g.d_spawn_node(b) and a < b))
	var out: Array = []
	if nodes.is_empty():
		return out
	var count := COUNTS.size()
	for i in count:
		var mid := clampi(int(round((float(i) + 0.5) / float(count) * float(nodes.size() - 1))), 0, nodes.size() - 1)
		var tries: Array = []
		var step := 0
		while tries.size() < TRIES and step < nodes.size():
			for j in [mid + step, mid - step] if step > 0 else [mid]:
				if j < 0 or j >= nodes.size() or tries.size() >= TRIES:
					continue
				var n: int = nodes[j]
				var p: Vector3 = g.position(n)
				if tries.any(func(q: Dictionary): return Vector2(q["at"].x - p.x, q["at"].z - p.z).length() < SPREAD_M * 2.0):
					continue
				tries.append(_pose("pose_%02d" % (i + 1), "fight", p, ride_heading(g, n, axis), axis, n))
			step += 3
		out.append({"count": int(COUNTS[i]), "tries": tries})
	return out


# Where each of n machines stands relative to the ball: Vector2(metres ahead, metres to the right). Alternate rows
# stand DEPTH_STEP_M deeper, so neighbours do not hide one another.
static func slot_offsets(n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append(Vector2(NEAR_STAND_M + float(i % 2) * DEPTH_STEP_M, (float(i) - float(n - 1) * 0.5) * SPREAD_M))
	return out


static func kind_for(pose_index: int, slot: int) -> String:
	return KINDS[(pose_index * 2 + slot) % KINDS.size()]


# Which machine a control run hides at a pose.
static func hidden_slot(pose_index: int, n: int) -> int:
	return pose_index % n


# How many machines a pose shows: the full count, or one fewer under --control=1.
static func shown_count(full: int, control: bool) -> int:
	return full - 1 if control else full


# Columns and rows of a contact sheet for count tiles: 4x2 for the 8 beam poses, 2x2 up to 4, else 3 across.
static func sheet_grid(count: int) -> Vector2i:
	if count == BEAM_POSES:
		return Vector2i(4, 2)
	if count <= 4:
		return Vector2i(2, ceili(count / 2.0))
	return Vector2i(3, ceili(count / 3.0))


# Two screen rectangles that do not touch.
static func apart(a: Rect2, b: Rect2) -> bool:
	return not a.grow(4.0).intersects(b)


func _run() -> void:
	seed(280928)
	GraphicsPreset.apply("high")
	var park := park_data(opts["map"])
	graph = load_graph(opts["map"])
	if park.is_empty() or graph == null:
		return _fail("no park file or graph for %s" % opts["map"])
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	var waited := 0
	while game.flow == null and waited < 600:
		waited += 1
		await process_frame
	if game.flow == null:
		return _fail("the game never built its flow")
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(1)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	var stage: int = MAPS[opts["map"]]
	if stage != 1:
		game.flow.enter_stage(stage, Vector3.ZERO, false)
	for i in 900:
		await process_frame
		if game.ctx.terrain.is_ready(1) and game.flow.in_play() and i > 120:
			break
	var map = game.ctx.terrain.map()
	var title := String(map.title) if map != null and "title" in map else ""
	if title != opts["map"]:
		return _fail("the game plays %s, not %s" % [title, opts["map"]])
	for i in 600:
		beam = root.find_child("AncientBeam", true, false)
		if beam != null:
			break
		await process_frame
	if beam == null:
		return _fail("%s has no landmark beam" % opts["map"])
	game.presentation.hide_ui()
	var axis := Vector2(beam.bottom.x, beam.bottom.z)
	if opts["mode"] == "beam":
		await _beam_mode(park, axis)
	else:
		await _silhouette_mode(axis)
	if failed != "":
		return
	await _sheets()
	if failed != "":
		return
	var file := FileAccess.open(String(opts["out"]).path_join("frames.json"), FileAccess.WRITE)
	if file == null:
		quit(3)
		return
	file.store_string(JSON.stringify({"tool": "map_sheet_capture.gd", "map": opts["map"], "mode": opts["mode"],
		"control": opts["control"], "size": [SIZE.x, SIZE.y], "adapter": RenderingServer.get_video_adapter_name(),
		"driver": RenderingServer.get_current_rendering_driver_name(), "beam_axis": [axis.x, axis.y],
		"beam_bottom_y": beam.bottom.y, "beam_top_y": beam.top_y, "frames": records, "limits": _limits()}, "\t"))
	file.close()
	quit(0)


func _beam_mode(park: Dictionary, axis: Vector2) -> void:
	var poses := beam_poses(graph, park, axis)
	if poses.size() != BEAM_POSES:
		return _fail("only %d beam poses on %s" % [poses.size(), opts["map"]])
	beam.visible = not opts["control"]
	for pose: Dictionary in poses:
		await _place(pose["at"], pose["heading"])
		var cam: Camera3D = root.get_viewport().get_camera_3d()
		var mid := Vector3(axis.x, beam.bottom.y + beam.height() * 0.25, axis.y)
		var path := await _shot(pose["id"])
		if path == "":
			return
		var rec := _pose_record(pose, cam)
		rec["beam_visible"] = beam.is_visible_in_tree()
		rec["beam_core_alpha"] = LandmarkBeam.near_alpha(LandmarkBeam.CORE_ALPHA, flat_distance(cam.global_position, axis))
		rec["beam_on_screen"] = not cam.is_position_behind(mid) and Rect2(Vector2.ZERO, Vector2(SIZE)).has_point(cam.unproject_position(mid))
		rec["beam_screen"] = _screen(cam, mid)
		rec["label"] = "%d  %s  %d m" % [records.size() + 1, String(pose["kind"]).replace("_", " "), roundi(float(pose["distance_m"]))]
		rec["sha256"] = FileAccess.get_sha256(path)
		records.append(rec)


func _silhouette_mode(axis: Vector2) -> void:
	beam.visible = false
	_ink = StandardMaterial3D.new()
	_ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ink.albedo_color = INK
	_ink.disable_fog = true
	_ink.disable_receive_shadows = true
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	cam.environment = _flat_sky()
	for node in game.player.find_children("*", "GeometryInstance3D", true, false):
		node.visible = false
	var poses := fight_poses(graph, axis)
	if poses.size() != COUNTS.size():
		return _fail("only %d fight poses on %s" % [poses.size(), opts["map"]])
	for i in poses.size():
		var full: int = poses[i]["count"]
		var staged: Array = []
		var kept: Dictionary = {}
		for pose: Dictionary in poses[i]["tries"]:
			await _place(pose["at"], pose["heading"])
			cam = root.get_viewport().get_camera_3d()
			staged = await _stage(pose, i, full)
			var why := _staging_fault(cam, staged)
			if why == "":
				kept = pose
				break
			print("map_sheet_capture: %s node %d skipped: %s" % [pose["id"], pose["node"], why])
			_unstage(staged)
			staged = []
		if kept.is_empty():
			return _fail("pose %d: no staging kept every machine in frame, unblocked and apart" % (i + 1))
		var foreign := 0
		for node in get_nodes_in_group("enemy"):
			if node is Node3D and not staged.has(node) and node.visible:
				node.visible = false
				foreign += 1
		var hidden := hidden_slot(i, full) if opts["control"] else -1
		for s in staged.size():
			_ink_over(staged[s])
			staged[s].visible = s != hidden
		var path := await _shot(kept["id"])
		if path == "":
			return
		var rec := _pose_record(kept, cam)
		rec["full_count"] = full
		rec["shown_count"] = shown_count(full, opts["control"])
		rec["hidden_slot"] = hidden
		rec["foreign_enemies_hidden"] = foreign
		rec["machines"] = []
		for s in staged.size():
			var m: Node3D = staged[s]
			rec["machines"].append({"slot": s, "kind": m.get_meta("map_sheet_kind"), "shown": s != hidden,
				"at": _v(m.global_position), "screen_rect": _rect_json(_screen_rect(cam, m))})
		rec["label"] = "%d  %d of %d shown" % [i + 1, rec["shown_count"], full]
		rec["sha256"] = FileAccess.get_sha256(path)
		records.append(rec)
		_unstage(staged)
		await _ticks(2)


# An environment where every fogged surface (ground, rock, water, sky, props) draws as SKY.
func _flat_sky() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = false
	env.ssao_enabled = false
	env.ssr_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false
	env.adjustment_enabled = false
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = SKY
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.0
	env.fog_density = 8.0
	env.fog_aerial_perspective = 0.0
	env.fog_sky_affect = 1.0
	env.fog_height_density = 0.0
	return env


func _stage(pose: Dictionary, pose_index: int, n: int) -> Array:
	var h: Vector3 = pose["heading"]
	var right := h.cross(Vector3.UP).normalized()
	var ball: Vector3 = pose["at"]
	var out: Array = []
	var offsets := slot_offsets(n)
	for s in n:
		var o: Vector2 = offsets[s]
		var p: Vector3 = ball + h * o.x + right * o.y
		p.y = game.ctx.terrain.height(p.x, p.z) + STAND_LIFT
		var kind := kind_for(pose_index, s)
		var m: Node3D = game.ctx.spawner.spawn_enemy(kind, p)
		m.set_meta("map_sheet_kind", kind)
		out.append(m)
	await _ticks(STAGE_TICKS)
	for m: Node3D in out:
		if is_instance_valid(m):
			m.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(4)
	return out.filter(func(m): return is_instance_valid(m))


# "" when every machine is in frame, clear of the ground from the lens and apart on screen; else why not.
func _staging_fault(cam: Camera3D, staged: Array) -> String:
	if staged.size() == 0:
		return "nothing staged"
	var rects: Array = []
	var space := cam.get_world_3d().direct_space_state
	var screen := Rect2(Vector2.ONE * SCREEN_MARGIN, Vector2(SIZE) - Vector2.ONE * SCREEN_MARGIN * 2.0)
	var ball_rid: RID = game.player.body().get_rid()
	for m: Node3D in staged:
		var r := _screen_rect(cam, m)
		if r.size == Vector2.ZERO or not screen.encloses(r):
			return "%s out of frame" % m.get_meta("map_sheet_kind")
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, _centre(m))
		q.exclude = [ball_rid]
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and hit["collider"] != m:
			return "%s hidden behind %s" % [m.get_meta("map_sheet_kind"), hit["collider"]]
		for other: Rect2 in rects:
			if not apart(r, other):
				return "%s overlaps another machine on screen" % m.get_meta("map_sheet_kind")
		rects.append(r)
	return ""


func _ink_over(m: Node3D) -> void:
	for node in m.find_children("*", "GeometryInstance3D", true, false):
		if node is MeshInstance3D or node is MultiMeshInstance3D or node is CSGShape3D:
			node.material_override = _ink
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			node.visible = false


func _unstage(staged: Array) -> void:
	for m in staged:
		if is_instance_valid(m):
			m.queue_free()


func _meshes(m: Node3D) -> Array:
	return m.find_children("*", "MeshInstance3D", true, false).filter(func(v): return v.is_visible_in_tree() and v.mesh != null)


func _centre(m: Node3D) -> Vector3:
	var box := _box(m)
	return box.get_center() if box.size != Vector3.ZERO else m.global_position


func _box(m: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for v: MeshInstance3D in _meshes(m):
		var b: AABB = v.global_transform * v.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _screen_rect(cam: Camera3D, m: Node3D) -> Rect2:
	var box := _box(m)
	if box.size == Vector3.ZERO:
		return Rect2()
	var r := Rect2()
	for i in 8:
		var corner := box.get_endpoint(i)
		if cam.is_position_behind(corner):
			return Rect2()
		var p := cam.unproject_position(corner)
		r = Rect2(p, Vector2.ZERO) if i == 0 else r.expand(p)
	return r


func _place(point: Vector3, heading: Vector3) -> void:
	var body = game.player.body()
	body.freeze = false
	game.player.reset_to(point + Vector3.UP * EYE_LIFT)
	await _ticks(2)
	body.freeze = true
	game.camera.snap(heading)
	await _frames(SETTLE)


func _shot(id: String) -> String:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var path := String(opts["out"]).path_join("%s.png" % id)
	var img := root.get_texture().get_image()
	if _blank(img):
		_fail("%s rendered blank" % id)
		return ""
	if img.save_png(path) != OK:
		_fail("could not save %s" % path)
		return ""
	return path


# A frame whose sampled pixels are all one colour is no picture.
static func _blank(img: Image) -> bool:
	var first := img.get_pixel(0, 0)
	for y in range(0, img.get_height(), 37):
		for x in range(0, img.get_width(), 41):
			if not img.get_pixel(x, y).is_equal_approx(first):
				return false
	return true


func _pose_record(pose: Dictionary, cam: Camera3D) -> Dictionary:
	var f := -cam.global_transform.basis.z
	return {"id": pose["id"], "kind": pose["kind"], "node": pose["node"], "ball": _v(pose["at"] + Vector3.UP * EYE_LIFT),
		"distance_m": snappedf(float(pose["distance_m"]), 0.1), "landmark_bearing_deg": snappedf(float(pose["bearing_deg"]), 0.1), "on_line": pose["on_line"],
		"ride_heading": _v(pose["ride_heading"]), "camera": {"position": _v(cam.global_position), "forward": _v(f),
		"fov": cam.fov, "far": cam.far, "yaw": game.camera.yaw, "pitch": game.camera.pitch}, "png": "%s.png" % pose["id"]}


func _screen(cam: Camera3D, p: Vector3) -> Array:
	if cam.is_position_behind(p):
		return []
	var s := cam.unproject_position(p)
	return [snappedf(s.x / SIZE.x, 0.001), snappedf(s.y / SIZE.y, 0.001)]


# The contact sheets: labelled (sheet_<mode>[_control].png) and numbered only (blind_sheet.png).
func _sheets() -> void:
	var grid := sheet_grid(records.size())
	var name := "sheet_%s%s.png" % [opts["mode"], "_control" if opts["control"] else ""]
	for labelled in [true, false]:
		var view := SubViewport.new()
		view.size = Vector2i(grid.x * TILE.x, grid.y * (TILE.y + LABEL_H))
		view.transparent_bg = false
		view.render_target_update_mode = SubViewport.UPDATE_ONCE
		var back := ColorRect.new()
		back.color = Color(0.1, 0.1, 0.1)
		back.size = Vector2(view.size)
		view.add_child(back)
		for i in records.size():
			var img := Image.load_from_file(String(opts["out"]).path_join(records[i]["png"]))
			img.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
			var tile := TextureRect.new()
			tile.texture = ImageTexture.create_from_image(img)
			var at := Vector2((i % grid.x) * TILE.x, (i / grid.x) * (TILE.y + LABEL_H))
			tile.position = at
			view.add_child(tile)
			var label := Label.new()
			label.text = String(records[i]["label"]) if labelled else str(i + 1)
			label.add_theme_font_size_override("font_size", 22)
			label.add_theme_color_override("font_color", Color.WHITE)
			label.position = at + Vector2(10, TILE.y + 3)
			view.add_child(label)
		root.add_child(view)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var path := String(opts["out"]).path_join(name if labelled else "blind_sheet.png")
		if view.get_texture().get_image().save_png(path) != OK:
			return _fail("could not save %s" % path)
		view.queue_free()


func _limits() -> String:
	if opts["mode"] == "beam":
		return "The real game and its chase camera, HUD hidden, ball frozen at each pose and the camera snapped to it. Poses are riding-line graph nodes; the camera faces the ride turned in to %d degrees of the beam at most. The control hides the beam node alone." % int(MAX_BEARING_DEG)
	return "Machines are staged through the game's spawner, settled %d ticks and stilled, not fighting. Ground and scenery draw flat sky through a dense fog; machines draw unshaded black. The control hides one machine a pose." % STAGE_TICKS


func _fail(why: String) -> void:
	if failed != "":
		return
	failed = why
	push_error("map_sheet_capture: %s" % why)
	quit(4)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


static func _v(p: Vector3) -> Array:
	return [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)]


static func _rect_json(r: Rect2) -> Array:
	return [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)]
