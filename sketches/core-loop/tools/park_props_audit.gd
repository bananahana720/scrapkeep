extends SceneTree


const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkProps := preload("res://src/presentation/park_props.gd")
const AppShell := preload("res://src/core/app_shell.gd")

const NEAR_M := 60.0
const FAR_M := 120.0
const DEDUP_M := 10.0
const BARE_MIN_NEAR := 5
const BARE_MIN_KINDS := 4
const DENSITY_WINDOW_M := 150.0
const DENSITY_MIN_KINDS := 3
const DENSITY_TAIL_MIN_M := 75.0
const ENGAGE_RING_M := 25.0
const STILL_SPACING_M := 100.0
const FIXED_STILLS := 4
const CATS := ["props", "clutter", "scatter", "anchors", "rows", "scenery", "landforms"]
const C_PROPS := 0
const C_CLUTTER := 1
const C_SCATTER := 2
const C_ANCHORS := 3
const C_ROWS := 4
const C_SCENERY := 5
const C_LAND := 6
const PROPS_GROUP := "park_props"
const SCENERY_ROOTS := ["SpillwayScenery", "DigScenery", "HighdraftScenery", "Cottonwoods"]
const SCENERY_SKIP := ["DigFx", "WaterMist"]
const SIZE := Vector2i(1280, 720)
const CAMERAS := {"rest": {"arm": 7.5, "fov": 65.0}, "mid": {"arm": 9.0, "fov": 72.5}, "fast": {"arm": 10.5, "fov": 80.0}}
const CAM_UP := 0.8
const CAM_PITCH := -0.30
const CAM_FAR := 700.0
const SETTLE_DRAWN := 3
const SETTLE_JUMP_FRAMES := 12
const SETTLE_JUMP_M := 60.0
const V_RANGE_M := 5.0
const V_OUTSIDE_M := 1.5
const V_BEARINGS := [0.0, 45.0, -45.0, 90.0, -90.0, 135.0, -135.0, 180.0]
const V_TERRAIN_SAMPLES := 10
const V_PROP_SAMPLES := 80
const V_CENTRE_SKIP_M := 0.3
const V_FOV := 72.5
const V_BALL_BEHIND_M := 8.0
const V_CHASE_SIDE_M := 2.5
const V_EYE_UP := 1.8
const V_DIFF := 8
const V_LITTER_MIN_H := 0.3
const V_ROWS_RANGE_M := 150.0
const V_ROWS_GRID := 7
const DRAW_LABEL := "OpenGL compatibility proxy, cloud llvmpipe, not a frame-cost proof"

var map_id := ""
var out_root := ""
var step := 25.0
var still_count := 12
var draw_count := 40
var counts_only := false
var poses_file := ""
var cam_name := "mid"
var vignettes := false
var spot_filter: Array = []
var subject_kind := ""
var _prev_cam := Vector3.INF
var open_spaces: Array = []
var _probe := {}

var game
var cam: Camera3D
var stage_index := 0
var park: Dictionary = {}
var started_msec := 0

var ix := PackedFloat32Array()
var iy := PackedFloat32Array()
var iz := PackedFloat32Array()
var icat := PackedInt32Array()
var ikind := PackedInt32Array()
var inode := PackedInt32Array()
var nodes: Array = []
var kind_ids := {}
var kind_names: Array = []
var props_nodes: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			map_id = a.trim_prefix("--map=")
		elif a.begins_with("--out="):
			out_root = a.trim_prefix("--out=")
		elif a.begins_with("--step="):
			step = float(a.trim_prefix("--step="))
		elif a.begins_with("--stills="):
			still_count = int(a.trim_prefix("--stills="))
		elif a.begins_with("--draws="):
			draw_count = int(a.trim_prefix("--draws="))
		elif a.begins_with("--poses="):
			poses_file = a.trim_prefix("--poses=")
		elif a.begins_with("--cam="):
			cam_name = a.trim_prefix("--cam=")
		elif a.begins_with("--open="):
			var parsed := ParkProps.parse_open(a.trim_prefix("--open="))
			if parsed.has("error"):
				printerr("park_props_audit: " + String(parsed["error"]))
				quit(2)
				return
			open_spaces.append_array(parsed["spaces"])
		elif a == "--counts-only":
			counts_only = true
		elif a == "--vignettes":
			vignettes = true
		elif a.begins_with("--subject-kind="):
			subject_kind = a.trim_prefix("--subject-kind=")
		elif a.begins_with("--spots="):
			spot_filter = Array(a.trim_prefix("--spots=").split(",", false))
	if map_id == "" or out_root == "" or not CAMERAS.has(cam_name):
		printerr("park_props_audit: pass --map=<park map> --out=<absolute dir> [--cam=rest|mid|fast]")
		quit(2)
		return
	if vignettes and (counts_only or poses_file != ""):
		printerr("park_props_audit: --vignettes draws its own poses: no --counts-only or --poses")
		quit(2)
		return
	if AppShell.headless() and not counts_only:
		printerr("park_props_audit: needs a display for draws and stills (xvfb-run, opengl3), or --counts-only")
		quit(2)
		return
	for row in ParkDefs.DEFS:
		if String(row.get("map", "")) == map_id:
			stage_index = int(row["stage"])
	if stage_index == 0:
		printerr("park_props_audit: %s is not a park table map" % map_id)
		quit(2)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _drawn(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _run() -> void:
	seed(171019)
	started_msec = Time.get_ticks_msec()
	if vignettes and ParkProps.load_json(ParkProps.file_path(map_id)).is_empty():
		printerr("park_props_audit: %s has no props file (%s), nothing to do for --vignettes" % [map_id, ParkProps.file_path(map_id)])
		quit(2)
		return
	park = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/%s.json" % map_id))
	var lines = JSON.parse_string(FileAccess.get_file_as_string("res://assets/park/%s/lines.json" % map_id))
	if not park is Dictionary or not lines is Dictionary:
		printerr("park_props_audit: no park file or lines.json for %s" % map_id)
		quit(1)
		return
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	game.ground_behind_menu = false
	root.add_child(game)
	while game.flow == null:
		await process_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	if stage_index != 1:
		game.flow.enter_stage(stage_index, Vector3.ZERO, false)
	var waited := 0
	var terrain = game.ctx.terrain
	while waited < 2400 and not (terrain.rows_ready(stage_index) and terrain.is_ready(stage_index) and game.presentation.set_dressing != null and game.presentation.set_dressing.batches.size() > 0 and game.flow.state_name() == "stage"):
		await process_frame
		waited += 1
	var pp = game.presentation.park_props
	if pp != null:
		pp.finish()
	await _frames(30)
	print("park_props_audit: %s built in %d frames, flow %s" % [map_id, waited, game.flow.state_name()])
	game.player.body().freeze = true
	cam = Camera3D.new()
	cam.far = CAM_FAR
	cam.fov = CAMERAS[cam_name]["fov"]
	game.add_child(cam)
	cam.make_current()
	if not counts_only:
		game.presentation.hide_ui()
	if vignettes:
		await _run_vignettes()
		return
	_collect()
	var tally := [0, 0, 0, 0, 0, 0, 0]
	for c in icat:
		tally[c] += 1
	print("park_props_audit: %d items in %d nodes, %d kinds, by category %s %s" % [ix.size(), nodes.size(), kind_names.size(), CATS, tally])

	var samples: Array
	var line_info := {}
	if poses_file != "":
		samples = _samples_from_poses()
	else:
		var built := _ride_samples(lines, line_info)
		samples = built
	if samples.is_empty():
		printerr("park_props_audit: no samples")
		quit(1)
		return
	for s in samples:
		_place(s)
		s.merge(_count(), true)
	_flag_bare(samples)
	_flag_void(samples)

	var still_idx: Array = []
	var draw_idx: Array = []
	if not counts_only:
		if poses_file != "":
			for s in samples:
				still_idx.append(int(s["idx"]))
		else:
			still_idx = _pick_stills(samples)
		draw_idx = still_idx.duplicate()
		var wanted := mini(draw_count, samples.size())
		for k in wanted:
			var i := int(round(float(k) * float(samples.size() - 1) / maxf(1.0, float(wanted - 1)))) if wanted > 1 else 0
			var idx := int(samples[i]["idx"])
			if not draw_idx.has(idx):
				draw_idx.append(idx)
		draw_idx.sort()
	var by_idx := {}
	for s in samples:
		by_idx[int(s["idx"])] = s
	var dir := out_root.path_join(map_id)
	DirAccess.make_dir_recursive_absolute(dir)
	var stills: Array = []
	var has_props := not props_nodes.is_empty()
	for idx in draw_idx:
		var s: Dictionary = by_idx[idx]
		_place(s)
		await _frames(2)
		await _drawn(_settle_frames())
		var png := ""
		if still_idx.has(idx):
			png = "%s-%d-%d_%d.png" % [map_id, idx, int(round(s["x"])), int(round(s["z"]))]
			root.get_texture().get_image().save_png(dir.path_join(png))
			stills.append({"file": png, "idx": idx, "x": s["x"], "z": s["z"], "yaw": s["yaw"], "line": s["line"], "along_m": s["along_m"],
				"props_120": s["total_120"], "core_60": s["core_60"], "kinds_120": s["kinds_120"], "bare": s["bare"], "void": s["void"]})
			if s.has("cam"):
				stills.back()["cam"] = s["cam"]
				stills.back()["look"] = s["look"]
		s["draw_calls"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		s["primitives"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		if has_props:
			_set_props_visible(false)
			await _drawn(3)
			s["draw_calls_no_props"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			s["primitives_no_props"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			_set_props_visible(true)
		else:
			s["draw_calls_no_props"] = s["draw_calls"]
			s["primitives_no_props"] = s["primitives"]
		s["props_breakdown"] = _props_breakdown()
		print("park_props_audit: sample %d draws %d prims %d%s" % [idx, s["draw_calls"], s["primitives"], " still " + png if png != "" else ""])

	var summary := _summary(samples, draw_idx, line_info)
	summary["runtime_s"] = snappedf((Time.get_ticks_msec() - started_msec) / 1000.0, 0.1)
	summary["adapter"] = RenderingServer.get_video_adapter_name()
	summary["draw_label"] = DRAW_LABEL
	_write(dir.path_join("samples.json"), {"map": map_id, "stage": stage_index, "constants": _constants(), "samples": samples})
	_write(dir.path_join("summary.json"), summary)
	if not counts_only:
		_write(dir.path_join("stills.json"), {"map": map_id, "stills": stills})
		_write(dir.path_join("poses.json"), {"map": map_id, "poses": stills})
		var py := ProjectSettings.globalize_path("res://tools/park_props_contact.py")
		var res := []
		var code := OS.execute("python3", [py, dir], res, true)
		print("park_props_audit: contact sheet exit %d %s" % [code, "".join(res).strip_edges()])
	print("park_props_audit: done %s in %.0f s" % [map_id, summary["runtime_s"]])
	quit(0)


func _constants() -> Dictionary:
	return {"near_m": NEAR_M, "far_m": FAR_M, "dedup_m": DEDUP_M, "step_m": step, "bare_min_core_near": BARE_MIN_NEAR, "bare_min_kinds_far": BARE_MIN_KINDS,
		"bare_rule": "BARE if (props+clutter+scenery+rows) within near_m in view < bare_min_core_near, or distinct kinds within far_m in view < bare_min_kinds_far",
		"camera": {"name": cam_name, "arm_m": CAMERAS[cam_name]["arm"], "fov": CAMERAS[cam_name]["fov"], "pitch_rad": CAM_PITCH, "up_m": CAM_UP, "far": CAM_FAR,
			"source": "src/movement/chase_camera.gd: speed_arm 7.5..10.5, FOV_REST 65..FOV_FAST 80, pitch -0.30, anchor +0.8 m; mid = half speed"},
		"categories": CATS, "draw_label": DRAW_LABEL}


func _kind_id(name: String) -> int:
	if not kind_ids.has(name):
		kind_ids[name] = kind_names.size()
		kind_names.append(name)
	return kind_ids[name]


func _mesh_name(mesh: Mesh) -> String:
	if mesh == null:
		return "none"
	return mesh.resource_path if mesh.resource_path != "" else "mesh#%d" % mesh.get_instance_id()


func _register(node: Node3D, centre: Vector3) -> int:
	nodes.append({"begin": node.visibility_range_begin if node is GeometryInstance3D else 0.0,
		"end": node.visibility_range_end if node is GeometryInstance3D else 0.0, "centre": centre})
	return nodes.size() - 1


func _push(p: Vector3, cat: int, kind: int, node_i: int) -> void:
	ix.append(p.x)
	iy.append(p.y)
	iz.append(p.z)
	icat.append(cat)
	ikind.append(kind)
	inode.append(node_i)


func _add_multi(view: MultiMeshInstance3D, cat: int, kind_name := "") -> void:
	var mm := view.multimesh
	if mm == null or mm.mesh == null or not view.is_visible_in_tree():
		return
	var n := mm.instance_count if mm.visible_instance_count < 0 else mini(mm.visible_instance_count, mm.instance_count)
	if n <= 0:
		return
	var kind := _kind_id(kind_name if kind_name != "" else _mesh_name(mm.mesh))
	var gx := view.global_transform
	var ni := _register(view, gx * view.get_aabb().get_center())
	var ctr := mm.mesh.get_aabb().get_center()
	var buf := mm.buffer
	if buf.size() < n * 12 and view.has_meta("instance_buffer"):
		buf = view.get_meta("instance_buffer")
	if buf.size() >= n * 12:
		var stride := buf.size() / mm.instance_count
		for i in n:
			var o := i * stride
			var local := Vector3(buf[o] * ctr.x + buf[o + 1] * ctr.y + buf[o + 2] * ctr.z + buf[o + 3],
				buf[o + 4] * ctr.x + buf[o + 5] * ctr.y + buf[o + 6] * ctr.z + buf[o + 7],
				buf[o + 8] * ctr.x + buf[o + 9] * ctr.y + buf[o + 10] * ctr.z + buf[o + 11])
			_push(gx * local, cat, kind, ni)
	else:
		for i in n:
			_push(gx * (mm.get_instance_transform(i) * ctr), cat, kind, ni)


func _add_mesh(mi: MeshInstance3D, cat: int, kind_name := "") -> void:
	if mi.mesh == null or not mi.is_visible_in_tree():
		return
	var kind := _kind_id(kind_name if kind_name != "" else _mesh_name(mi.mesh))
	var centre := mi.global_transform * mi.get_aabb().get_center()
	_push(centre, cat, kind, _register(mi, centre))


func _visuals(from: Node, skip_names: Array = []) -> Array:
	var out := []
	var stack := [from]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n != from and skip_names.has(String(n.name)):
			continue
		if n is MeshInstance3D or n is MultiMeshInstance3D:
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out


func _dress_kind(visual: Node, top: Node) -> String:
	var n := visual
	while n != null:
		if n.has_meta("dress_kind"):
			return String(n.get_meta("dress_kind"))
		if n == top:
			break
		n = n.get_parent()
	return ""


func _row_budgets() -> Dictionary:
	var out := {}
	for key in park:
		var rows = park[key]
		if rows is Array:
			for row in rows:
				if row is Dictionary and row.has("id") and (row.has("recipe") or row.has("budget")):
					var recipe := String(row.get("recipe", ""))
					out[String(row["id"])] = {"budget": String(row.get("budget", ParkRecipes.ROWS.get(recipe, {}).get("budget", "landform"))), "recipe": recipe}
	return out


func _collect() -> void:
	props_nodes = get_nodes_in_group(PROPS_GROUP)
	for top in props_nodes:
		for v in _visuals(top):
			var k := _dress_kind(v, top)
			if v.has_meta("dress_member_pos"):
				var at: PackedVector3Array = v.get_meta("dress_member_pos")
				var names: PackedStringArray = v.get_meta("dress_member_kinds")
				var ni := _register(v, v.global_transform * v.get_aabb().get_center())
				for m in at.size():
					_push(at[m], C_PROPS, _kind_id(names[m]), ni)
			elif v is MultiMeshInstance3D:
				_add_multi(v, C_PROPS, k)
			else:
				_add_mesh(v, C_PROPS, k)
	var dressing = game.presentation.set_dressing
	for view in dressing.batches:
		if view.multimesh != null and not view.multimesh.use_custom_data:
			_add_multi(view, C_CLUTTER)
	var stage_root: Node = game.get_node_or_null("Stage%d" % stage_index)
	if stage_root == null:
		printerr("park_props_audit: no Stage%d node, scatter, rows and scenery skipped" % stage_index)
		return
	var scatter := stage_root.find_child("GroundScatter", true, false)
	if scatter != null:
		for v in scatter.find_children("*", "MultiMeshInstance3D", true, false):
			_add_multi(v, C_SCATTER)
	var budgets := _row_budgets()
	var rows := stage_root.find_child("ParkRows", true, false)
	if rows != null:
		for row in rows.get_children():
			if not row is Node3D:
				continue
			var found_posts := false
			for child in row.get_children():
				if child is MultiMeshInstance3D and (child.name == "Posts" or String(child.name).begins_with("Posts_")):
					_add_multi(child, C_ANCHORS, "anchor:" + str(row.get_meta("anchor_kit", "field")))
					found_posts = true
			if found_posts:
				continue
			var id := String(row.name).trim_prefix("Park_").trim_prefix("Landmark_")
			var recipe := str(row.get_meta("park_recipe", ""))
			var meta: Dictionary = budgets.get(id, {})
			var budget := str(meta.get("budget", "hero_landmark" if String(row.name).begins_with("Landmark_") else "landform"))
			if recipe == "" and meta.has("recipe"):
				recipe = str(meta["recipe"])
			if recipe.begins_with("greybox"):
				continue
			var box := AABB()
			var first := true
			var range_end := 0.0
			for v in _visuals(row, ["Collider", "Ride", "Greybox"]):
				if not v.is_visible_in_tree() or v is Label3D:
					continue
				var local: AABB = v.get_aabb()
				if v is MeshInstance3D and v.mesh == null:
					continue
				var world: AABB = v.global_transform * local
				box = world if first else box.merge(world)
				if first:
					range_end = v.visibility_range_end
				first = false
			if first:
				continue
			var cat := C_ROWS if budget == "detail" else C_LAND
			var ni := nodes.size()
			nodes.append({"begin": 0.0, "end": range_end, "centre": box.get_center()})
			_push(box.get_center(), cat, _kind_id("row:" + (recipe if recipe != "" else id)), ni)
	for sname in SCENERY_ROOTS:
		for sc in stage_root.find_children(sname, "Node3D", true, false):
			for child in sc.get_children():
				if SCENERY_SKIP.has(String(child.name)) or not child is Node3D:
					continue
				if child is MultiMeshInstance3D:
					_add_multi(child, C_SCENERY)
					continue
				var box2 := AABB()
				var first2 := true
				var kname := ""
				for v in _visuals(child):
					if not v.is_visible_in_tree():
						continue
					if v is MeshInstance3D and v.mesh == null:
						continue
					var world2: AABB = v.global_transform * v.get_aabb()
					box2 = world2 if first2 else box2.merge(world2)
					if first2:
						kname = _mesh_name(v.mesh) if v is MeshInstance3D else _mesh_name(v.multimesh.mesh)
					first2 = false
				if first2:
					continue
				var ni2 := nodes.size()
				nodes.append({"begin": 0.0, "end": 0.0, "centre": box2.get_center()})
				_push(box2.get_center(), C_SCENERY, _kind_id(kname), ni2)


func _props_breakdown() -> Dictionary:
	var cp := cam.global_position
	var planes := cam.get_frustum()
	var out := {}
	for n in props_nodes:
		if not is_instance_valid(n) or not n is GeometryInstance3D or not n.is_visible_in_tree():
			continue
		var view: GeometryInstance3D = n
		var box: AABB = view.global_transform * view.get_aabb()
		var d := cp.distance_to(box.get_center())
		if d < view.visibility_range_begin - view.visibility_range_begin_margin or (view.visibility_range_end > 0.0 and d > view.visibility_range_end + view.visibility_range_end_margin):
			continue
		var inside := true
		for pl in planes:
			var far_corner := box.position + Vector3(box.size.x if pl.normal.x < 0.0 else 0.0, box.size.y if pl.normal.y < 0.0 else 0.0, box.size.z if pl.normal.z < 0.0 else 0.0)
			if pl.is_point_over(far_corner):
				inside = false
				break
		if not inside:
			continue
		var group := "hero" if view.get_meta("dress_class", "") == "dress_hero" else ("litter" if view.get_parent().name == "Litter" else "vignette")
		var key := "%s/L%d/%s" % [group, int(view.get_meta("dress_lod", -1)), String(view.get_meta("dress_tier", "?"))]
		out[key] = int(out.get(key, 0)) + 1
	return out


func _set_props_visible(on: bool) -> void:
	for n in props_nodes:
		if is_instance_valid(n) and n is Node3D:
			n.visible = on


func _run_vignettes() -> void:
	var file := ParkProps.load_json(ParkProps.file_path(map_id))
	var kit := ParkProps.load_json(String(file.get("kit", "")))
	var terrain = game.ctx.terrain
	var pmap = terrain.map_for(stage_index)
	var ground: Callable = terrain.ground_callable(stage_index)
	var list: Array = ParkProps.expand(file, kit, pmap, ground, ParkProps.context(pmap, ground, stage_index))
	var pp = game.presentation.park_props
	if pp != null and pp.instances.size() != list.size():
		printerr("park_props_audit: expand gave %d instances, the built stage has %d" % [list.size(), pp.instances.size()])
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var ball_rid: RID = game.player.body().get_rid()
	var dir := out_root.path_join(map_id)
	DirAccess.make_dir_recursive_absolute(dir)
	var spots: Array = file.get("spots", [])
	var rows: Array = []
	var poses: Array = []
	var stills: Array = []
	var skipped: Array = []
	var blocked_all := 0
	var null_px := 0
	var zero_px := 0
	for si in spots.size():
		var spot: Dictionary = spots[si]
		var id := String(spot["id"])
		if not spot_filter.is_empty() and not spot_filter.has(id):
			continue
		var subject_i := -1
		for k in list.size():
			if not list[k]["litter"] and String(list[k]["vignette"]) == id and (subject_kind == "" or String(list[k]["kind"]) == subject_kind):
				subject_i = k
				break
		if subject_i < 0:
			skipped.append(id)
			if subject_kind == "":
				printerr("park_props_audit: spot %s has no instance (template missing?)" % id)
			continue
		var subject: Dictionary = list[subject_i]
		var spos: Vector3 = subject["pos"]
		var centre := spos + Vector3(0.0, float(subject["height"]) * 0.5, 0.0)
		var front := deg_to_rad(float(spot.get("yaw_deg", 0.0)))
		var eye_m := maxf(V_RANGE_M, float(subject["radius"]) + V_OUTSIDE_M)
		var near: Array = []
		for k in list.size():
			var other: Dictionary = list[k]
			var opos: Vector3 = other["pos"]
			if other["litter"] and float(other["height"]) < V_LITTER_MIN_H:
				continue
			if Vector2(opos.x - centre.x, opos.z - centre.z).length() < eye_m + float(other["radius"]) + 1.0:
				near.append(k)
		var blocked: Array = []
		var pick := {}
		for off in V_BEARINGS:
			var a := front + deg_to_rad(off)
			var d := Vector2(sin(a), cos(a))
			var eye := Vector3(centre.x + eye_m * d.x, 0.0, centre.z + eye_m * d.y)
			eye.y = terrain.height(eye.x, eye.z) + V_EYE_UP
			var why := _sight_block(eye, centre, list, near, subject_i, terrain, space, ball_rid)
			if why == "":
				pick = {"off": off, "a": a, "d": d, "eye": eye}
				break
			blocked.append({"bearing_deg": off, "reason": why})
		var all_blocked := pick.is_empty()
		if all_blocked:
			blocked_all += 1
			var fd := Vector2(sin(front), cos(front))
			var fe := Vector3(centre.x + eye_m * fd.x, 0.0, centre.z + eye_m * fd.y)
			fe.y = terrain.height(fe.x, fe.z) + V_EYE_UP
			pick = {"off": 0.0, "a": front, "d": fd, "eye": fe}
		var bd: Vector2 = pick["d"]
		var eye_pos: Vector3 = pick["eye"]
		var to_c := (centre - eye_pos).normalized()
		var eye_ball := eye_pos - to_c * V_BALL_BEHIND_M
		var ba: float = float(pick["a"]) + PI * 0.5
		var chase_ball := Vector2(centre.x + eye_m * bd.x + V_CHASE_SIDE_M * sin(ba), centre.z + eye_m * bd.y + V_CHASE_SIDE_M * cos(ba))
		var frames := {
			"eye": {"idx": si * 2, "x": eye_ball.x, "z": eye_ball.z, "yaw": atan2(-(centre.x - eye_pos.x), -(centre.z - eye_pos.z)),
				"cam": [eye_pos.x, eye_pos.y, eye_pos.z], "look": [centre.x, centre.y, centre.z]},
			"chase": {"idx": si * 2 + 1, "x": chase_ball.x, "z": chase_ball.y, "yaw": float(pick["a"])}}
		var row := {"id": id, "template": String(spot.get("template", "")), "subject_kind": subject["kind"], "subject_v": subject["v"],
			"C": [snappedf(centre.x, 0.01), snappedf(centre.y, 0.01), snappedf(centre.z, 0.01)], "radius_m": snappedf(float(subject["radius"]), 0.01),
			"height_m": snappedf(float(subject["height"]), 0.01), "front_deg": float(spot.get("yaw_deg", 0.0)), "eye_m": snappedf(eye_m, 0.01), "bearing_deg": pick["off"],
			"blocked": blocked, "blocked_all": all_blocked, "isolated": false}
		var handle := _isolate(pp, subject)
		row["isolated"] = not handle.is_empty()
		for fname in ["eye", "chase"]:
			var s: Dictionary = frames[fname]
			s["line"] = "vignette:" + id
			s["along_m"] = 0.0
			_place(s)
			await _frames(2)
			await _drawn(_settle_frames())
			var png := "%s-v%d-%s-%s.png" % [map_id, si, id, fname]
			var shot := _grab()
			shot.save_png(dir.path_join(png))
			var box := _aabb(subject)
			var res := {"png": png, "rows_in_view": _rows_in_view(file, terrain), "subject_px": null, "subject_share": null, "aabb_share": snappedf(float(box["share"]), 0.00001),
				"frame_diff_px": null, "noise_px": null}
			if not handle.is_empty():
				await _drawn(3)
				var control := _grab()
				_set_hidden(handle, true)
				await _drawn(3)
				var bare_shot := _grab()
				_set_hidden(handle, false)
				var whole := Rect2i(0, 0, shot.get_width(), shot.get_height())
				var px := _diff_px(shot, bare_shot, box["rect"], control)
				res["subject_px"] = px
				res["subject_share"] = snappedf(float(px) / float(shot.get_width() * shot.get_height()), 0.00001)
				res["frame_diff_px"] = _diff_px(shot, bare_shot, whole, null)
				res["noise_px"] = _diff_px(shot, control, box["rect"], null)
				if px == 0:
					zero_px += 1
			else:
				null_px += 1
			row[fname] = res
			var pose := {"idx": s["idx"], "line": s["line"], "along_m": 0.0, "x": snappedf(float(s["x"]), 0.001), "z": snappedf(float(s["z"]), 0.001),
				"yaw": snappedf(float(s["yaw"]), 0.00001), "file": png}
			if s.has("cam"):
				pose["cam"] = s["cam"].map(func(v): return snappedf(float(v), 0.001))
				pose["look"] = s["look"].map(func(v): return snappedf(float(v), 0.001))
			poses.append(pose)
			var caption := "%s %s %s%s px %s aabb %.1f%%" % [id, fname, str(pick["off"]), " BLOCKED" if all_blocked else "", str(res["subject_px"]), float(res["aabb_share"]) * 100.0]
			var still := pose.duplicate()
			still["caption"] = caption
			stills.append(still)
		rows.append(row)
		print("park_props_audit: %s bearing %s %s eye px %s chase px %s" % [id, str(pick["off"]), "BLOCKED_ALL" if all_blocked else "ok", str(row["eye"]["subject_px"]), str(row["chase"]["subject_px"])])
	var summary := {"mode": "vignettes", "map": map_id, "stage": stage_index, "spots_in_file": spots.size(), "spots_rendered": rows.size(), "spots_skipped": skipped,
		"blocked_all": blocked_all, "subject_px_note": "px inside the projected box, minus pixels that move between two unchanged renders; a guide", "frames_without_isolation": null_px, "frames_zero_subject_px": zero_px, "constants": _constants(),
		"adapter": RenderingServer.get_video_adapter_name(), "runtime_s": snappedf((Time.get_ticks_msec() - started_msec) / 1000.0, 0.1)}
	var rule := "lead prop: the first instance of the spot's vignette" if subject_kind == "" else "first instance of kind %s in the spot; spots without it skipped" % subject_kind
	summary["subject_rule"] = rule
	_write(dir.path_join("vignettes.json"), {"map": map_id, "stage": stage_index, "subject_rule": rule, "rows": rows})
	_write(dir.path_join("poses.json"), {"map": map_id, "poses": poses})
	_write(dir.path_join("stills.json"), {"map": map_id, "stills": stills})
	_write(dir.path_join("summary.json"), summary)
	var res_out := []
	var code := OS.execute("python3", [ProjectSettings.globalize_path("res://tools/park_props_contact.py"), dir], res_out, true)
	print("park_props_audit: contact sheet exit %d %s" % [code, "".join(res_out).strip_edges()])
	print("park_props_audit: done %s vignettes in %.0f s" % [map_id, summary["runtime_s"]])
	quit(0)


func _sight_block(eye: Vector3, centre: Vector3, list: Array, near: Array, subject_i: int, terrain, space: PhysicsDirectSpaceState3D, ball_rid: RID) -> String:
	for k in near:
		if k != subject_i and _in_cylinder(eye, list[k]):
			return "inside:%s/%s" % [list[k]["vignette"], list[k]["kind"]]
	for i in range(1, V_TERRAIN_SAMPLES + 1):
		var p := eye.lerp(centre, float(i) / float(V_TERRAIN_SAMPLES + 1))
		if terrain.height(p.x, p.z) > p.y:
			return "terrain"
	for i in range(V_PROP_SAMPLES + 1):
		var p2 := eye.lerp(centre, float(i) / float(V_PROP_SAMPLES))
		if p2.distance_to(centre) <= V_CENTRE_SKIP_M:
			continue
		for k in near:
			if k != subject_i and _in_cylinder(p2, list[k]):
				return "prop:%s/%s" % [list[k]["vignette"], list[k]["kind"]]
	var query := PhysicsRayQueryParameters3D.create(eye, centre)
	query.exclude = [ball_rid]
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		return "collider:%s" % String((hit["collider"] as Node).name)
	return ""


func _rows_in_view(file: Dictionary, terrain) -> Array:
	var spec := {"fov_deg": cam.fov, "aspect": float(SIZE.x) / float(SIZE.y)}
	var view := cam.global_transform
	var out: Array = []
	var park_file: Dictionary = park
	for row: Dictionary in park_file.get("park_rows", []):
		if not row.get("at") is Array or not row.get("size") is Array:
			continue
		var centre := Vector2(float(row["at"][0]), float(row["at"][1]))
		var half := ParkMap.footprint_half_extents(row)
		var yaw := deg_to_rad(float(row.get("yaw_deg", 0.0)))
		var seen := false
		for i in V_ROWS_GRID:
			for j in V_ROWS_GRID:
				var local := Vector2(lerpf(-half.x, half.x, float(i) / float(V_ROWS_GRID - 1)), lerpf(-half.y, half.y, float(j) / float(V_ROWS_GRID - 1)))
				var w := centre + local.rotated(-yaw)
				if ParkProps.cell_visible(view, spec, Vector3(w.x, terrain.height(w.x, w.y), w.y), V_ROWS_RANGE_M):
					seen = true
					break
			if seen:
				break
		if seen:
			out.append(String(row["id"]))
	for row: Dictionary in park_file.get("contraption_rows", []):
		if not row.get("at") is Array:
			continue
		var c := Vector2(float(row["at"][0]), float(row["at"][1]))
		var r := float(row.get("radius", 0.0))
		var pts: Array = [c]
		for k in 8:
			pts.append(c + Vector2.from_angle(k * TAU / 8.0) * r)
		for w2: Vector2 in pts:
			if ParkProps.cell_visible(view, spec, Vector3(w2.x, terrain.height(w2.x, w2.y), w2.y), V_ROWS_RANGE_M):
				out.append(String(row["id"]))
				break
	return out


func _in_cylinder(p: Vector3, inst: Dictionary) -> bool:
	var at: Vector3 = inst["pos"]
	if p.y < at.y or p.y > at.y + float(inst["height"]):
		return false
	return Vector2(p.x - at.x, p.z - at.z).length() <= float(inst["radius"])


func _grab() -> Image:
	var img := root.get_texture().get_image()
	if img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	return img


func _diff_px(a: Image, b: Image, rect: Rect2i, ignore: Image) -> int:
	var da := a.get_data()
	var db := b.get_data()
	if da == db:
		return 0
	var dc := ignore.get_data() if ignore != null else PackedByteArray()
	var w := a.get_width()
	var count := 0
	for y in range(maxi(rect.position.y, 0), mini(rect.end.y, a.get_height())):
		for x in range(maxi(rect.position.x, 0), mini(rect.end.x, w)):
			var i := (y * w + x) * 3
			if absi(da[i] - db[i]) > V_DIFF or absi(da[i + 1] - db[i + 1]) > V_DIFF or absi(da[i + 2] - db[i + 2]) > V_DIFF:
				if dc.is_empty() or not (absi(da[i] - dc[i]) > V_DIFF or absi(da[i + 1] - dc[i + 1]) > V_DIFF or absi(da[i + 2] - dc[i + 2]) > V_DIFF):
					count += 1
	return count


func _isolate(pp, inst: Dictionary) -> Dictionary:
	if pp == null:
		return {}
	var holder: Node = pp.get_node_or_null("Vignette_" + String(inst["vignette"]))
	if holder == null:
		return {}
	var pos: Vector3 = inst["pos"]
	var views: Array = []
	var multi: Array = []
	for child in holder.get_children():
		if String(child.get_meta("dress_kind", "")) != String(inst["kind"]):
			continue
		if child is MeshInstance3D and inst["class"] == ParkProps.HERO:
			if child.transform.origin.distance_to(pos) < 0.01:
				views.append(child)
		elif child is MultiMeshInstance3D and inst["class"] != ParkProps.HERO and int(child.get_meta("dress_lod", 9)) < 2:
			var mm: MultiMesh = child.multimesh
			for i in mm.instance_count:
				var t := mm.get_instance_transform(i)
				if t.origin.distance_to(pos) < 0.01:
					multi.append([child, i, t])
	if views.is_empty() and multi.is_empty():
		return {}
	return {"views": views, "multi": multi}


func _set_hidden(handle: Dictionary, hidden: bool) -> void:
	for v in handle["views"]:
		v.visible = not hidden
	for m in handle["multi"]:
		var t: Transform3D = m[2]
		m[0].multimesh.set_instance_transform(m[1], Transform3D(Basis.from_scale(Vector3.ZERO), t.origin) if hidden else t)


func _aabb(inst: Dictionary) -> Dictionary:
	var at: Vector3 = inst["pos"]
	var r := float(inst["radius"])
	var h := float(inst["height"])
	var inv := cam.global_transform.affine_inverse()
	var corners: Array = []
	for i in 8:
		corners.append(inv * (at + Vector3(r if (i & 1) != 0 else -r, h if (i & 4) != 0 else 0.0, r if (i & 2) != 0 else -r)))
	var pts: Array = []
	var near := 0.05
	for i in 8:
		for bit in [1, 2, 4]:
			var j: int = i ^ bit
			if j < i:
				continue
			var a: Vector3 = corners[i]
			var b: Vector3 = corners[j]
			var ia := a.z <= -near
			var ib := b.z <= -near
			if ia:
				pts.append(a)
			if ib:
				pts.append(b)
			if ia != ib:
				pts.append(a.lerp(b, (-near - a.z) / (b.z - a.z)))
	if pts.is_empty():
		return {"share": 0.0, "rect": Rect2i()}
	var tan_half := tan(deg_to_rad(cam.fov) * 0.5)
	var aspect := float(SIZE.x) / float(SIZE.y)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p: Vector3 in pts:
		var nx := p.x / (-p.z) / (tan_half * aspect)
		var ny := p.y / (-p.z) / tan_half
		lo = Vector2(minf(lo.x, nx), minf(lo.y, ny))
		hi = Vector2(maxf(hi.x, nx), maxf(hi.y, ny))
	lo = Vector2(clampf(lo.x, -1.0, 1.0), clampf(lo.y, -1.0, 1.0))
	hi = Vector2(clampf(hi.x, -1.0, 1.0), clampf(hi.y, -1.0, 1.0))
	var x0 := int(floor((lo.x + 1.0) * 0.5 * SIZE.x)) - 4
	var x1 := int(ceil((hi.x + 1.0) * 0.5 * SIZE.x)) + 4
	var y0 := int(floor((1.0 - hi.y) * 0.5 * SIZE.y)) - 4
	var y1 := int(ceil((1.0 - lo.y) * 0.5 * SIZE.y)) + 4
	return {"share": (hi.x - lo.x) * (hi.y - lo.y) / 4.0, "rect": Rect2i(x0, y0, x1 - x0, y1 - y0)}


func _place_of(id: String) -> Vector2:
	if id == "drop_in":
		var s = park.get("spawn", {}).get("at")
		return Vector2(float(s[0]), float(s[1])) if s is Array else Vector2.INF
	if id == "landmark":
		var b = park.get("landmark", {}).get("beacon")
		return Vector2(float(b[0]), float(b[1])) if b is Array else Vector2.INF
	for key in park:
		var rows = park[key]
		if rows is Array:
			for row in rows:
				if row is Dictionary and String(row.get("id", "")) == id and row.get("at") is Array:
					return Vector2(float(row.at[0]), float(row.at[1]))
	return Vector2.INF


func _line_points(spec: Dictionary) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for point in spec.get("waypoints", []):
		var at: Vector2 = _place_of(point) if point is String else Vector2(float(point[0]), float(point[1]))
		if at == Vector2.INF:
			printerr("park_props_audit: waypoint %s does not resolve" % str(point))
		else:
			pts.append(at)
	return pts


func _ride_samples(lines: Dictionary, info: Dictionary) -> Array:
	var named: Array = [["floor", lines.get("floor", {})]]
	for key in lines.get("pilots", {}):
		named.append([key, lines["pilots"][key]])
	var kept: Array = []
	var lengths := {}
	for entry in named:
		var pts := _line_points(entry[1])
		var total := 0.0
		for i in range(1, pts.size()):
			total += pts[i].distance_to(pts[i - 1])
		lengths[entry[0]] = snappedf(total, 0.1)
		var s := 0.0
		var seg := 1
		var walked := 0.0
		while s <= total and seg < pts.size():
			while seg < pts.size() - 1 and walked + pts[seg].distance_to(pts[seg - 1]) < s:
				walked += pts[seg].distance_to(pts[seg - 1])
				seg += 1
			var a := pts[seg - 1]
			var b := pts[seg]
			var l := a.distance_to(b)
			var p := a.lerp(b, clampf((s - walked) / maxf(l, 0.001), 0.0, 1.0))
			var ok := true
			for k in kept:
				if Vector2(k["x"], k["z"]).distance_to(p) < DEDUP_M:
					ok = false
					break
			if ok:
				var t := (b - a).normalized()
				kept.append({"line": entry[0], "along_m": snappedf(s, 0.1), "x": snappedf(p.x, 0.1), "z": snappedf(p.y, 0.1), "yaw": atan2(-t.x, -t.y)})
			s += step
	for i in kept.size():
		kept[i]["idx"] = i
	info["line_lengths_m"] = lengths
	info["union_samples"] = kept.size()
	return kept


func _samples_from_poses() -> Array:
	var data = JSON.parse_string(FileAccess.get_file_as_string(poses_file))
	var out: Array = []
	for p in data.get("poses", []):
		var s := {"idx": int(p["idx"]), "line": p.get("line", ""), "along_m": p.get("along_m", 0.0), "x": float(p["x"]), "z": float(p["z"]), "yaw": float(p["yaw"])}
		if p.get("cam") is Array and p.get("look") is Array:
			s["cam"] = p["cam"]
			s["look"] = p["look"]
		out.append(s)
	return out


func _place(s: Dictionary) -> void:
	var x: float = s["x"]
	var z: float = s["z"]
	var ground: float = game.ctx.terrain.height(x, z)
	s["y"] = snappedf(ground, 0.01)
	var body = game.player.body()
	body.global_position = Vector3(x, ground + 1.0, z)
	body.linear_velocity = Vector3.ZERO
	if s.has("cam"):
		var at := Vector3(float(s["cam"][0]), float(s["cam"][1]), float(s["cam"][2]))
		var target := Vector3(float(s["look"][0]), float(s["look"][1]), float(s["look"][2]))
		cam.global_transform = Transform3D(Basis.looking_at(target - at, Vector3.UP), at)
		cam.fov = V_FOV
		body.global_position = at - (target - at).normalized() * V_BALL_BEHIND_M
		return
	var anchor := Vector3(x, ground + 1.0 + CAM_UP, z)
	var basis := Basis(Vector3.UP, float(s["yaw"])) * Basis(Vector3.RIGHT, CAM_PITCH)
	cam.global_transform = Transform3D(basis, anchor + basis * Vector3(0.0, 0.0, float(CAMERAS[cam_name]["arm"])))
	cam.fov = CAMERAS[cam_name]["fov"]


func _settle_frames() -> int:
	var at := cam.global_position
	var far := _prev_cam == Vector3.INF or at.distance_to(_prev_cam) > SETTLE_JUMP_M
	_prev_cam = at
	return SETTLE_JUMP_FRAMES if far else SETTLE_DRAWN


func _count() -> Dictionary:
	var cp := cam.global_position
	var planes := cam.get_frustum()
	var ok := PackedByteArray()
	ok.resize(nodes.size())
	for i in nodes.size():
		var d := cp.distance_to(nodes[i]["centre"])
		ok[i] = 1 if d >= nodes[i]["begin"] and (nodes[i]["end"] <= 0.0 or d <= nodes[i]["end"]) else 0
	var c120 := [0, 0, 0, 0, 0, 0, 0]
	var c60 := [0, 0, 0, 0, 0, 0, 0]
	var k120 := {}
	var k60 := {}
	var pk60 := {}
	var far2 := FAR_M * FAR_M
	var near2 := NEAR_M * NEAR_M
	for i in ix.size():
		var dx := ix[i] - cp.x
		if absf(dx) > FAR_M:
			continue
		var dz := iz[i] - cp.z
		if absf(dz) > FAR_M:
			continue
		var dy := iy[i] - cp.y
		var d2 := dx * dx + dy * dy + dz * dz
		if d2 > far2 or ok[inode[i]] == 0:
			continue
		var p := Vector3(ix[i], iy[i], iz[i])
		var inside := true
		for pl in planes:
			if pl.is_point_over(p):
				inside = false
				break
		if not inside:
			continue
		var cat := icat[i]
		c120[cat] += 1
		if cat != C_LAND:
			k120[ikind[i]] = true
		if d2 <= near2:
			if cat == C_PROPS:
				pk60[kind_names[ikind[i]]] = true
			c60[cat] += 1
			if cat != C_LAND:
				k60[ikind[i]] = true
	var out := {}
	var t120 := 0
	var t60 := 0
	for c in CATS.size():
		out[CATS[c] + "_120"] = c120[c]
		out[CATS[c] + "_60"] = c60[c]
		if c != C_LAND:
			t120 += c120[c]
			t60 += c60[c]
	out["total_120"] = t120
	out["total_60"] = t60
	out["core_60"] = c60[C_PROPS] + c60[C_CLUTTER] + c60[C_SCENERY] + c60[C_ROWS]
	out["kinds_120"] = k120.size()
	out["kinds_60"] = k60.size()
	out["prop_kinds_60"] = pk60.keys()
	return out


func _flag_bare(samples: Array) -> void:
	for s in samples:
		s["bare"] = int(s["core_60"]) < BARE_MIN_NEAR or int(s["kinds_120"]) < BARE_MIN_KINDS


const VOID_VIEW_M := 60.0
const VOID_HALF_FOV_DEG := 35.0
const VOID_VERTICAL_M := 40.0
const VOID_GROUND_SHARE := 0.2


func _flag_void(samples: Array) -> void:
	for s in samples:
		var forward := Vector2(-sin(float(s["yaw"])), -cos(float(s["yaw"])))
		var side := Vector2(-forward.y, forward.x)
		var ball_y: float = game.ctx.terrain.height(float(s["x"]), float(s["z"])) + 1.0
		var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
		var hit := 0
		var total := 0
		for d in [10.0, 20.0, 30.0, 40.0, 50.0, 60.0]:
			for lateral in [-1.0, -0.5, 0.0, 0.5, 1.0]:
				var at: Vector2 = Vector2(float(s["x"]), float(s["z"])) + forward * d + side * lateral * d * tan(deg_to_rad(VOID_HALF_FOV_DEG))
				var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, ball_y + VOID_VERTICAL_M, at.y), Vector3(at.x, ball_y - VOID_VERTICAL_M, at.y))
				total += 1
				if not space.intersect_ray(query).is_empty():
					hit += 1
		s["void"] = float(hit) / float(total) < VOID_GROUND_SHARE


func _pick_stills(samples: Array) -> Array:
	var picked: Array = []
	var order := range(samples.size())
	order.sort_custom(func(a, b):
		var sa: Dictionary = samples[a]
		var sb: Dictionary = samples[b]
		if sa["core_60"] != sb["core_60"]:
			return sa["core_60"] < sb["core_60"]
		if sa["kinds_120"] != sb["kinds_120"]:
			return sa["kinds_120"] < sb["kinds_120"]
		return a < b)
	var barest := maxi(0, still_count - FIXED_STILLS)
	for i in order:
		if picked.size() >= barest:
			break
		var far_enough := true
		for j in picked:
			if Vector2(samples[i]["x"], samples[i]["z"]).distance_to(Vector2(samples[j]["x"], samples[j]["z"])) < STILL_SPACING_M:
				far_enough = false
				break
		if far_enough:
			picked.append(i)
	for k in FIXED_STILLS:
		var i := int(round((k + 0.5) * float(samples.size()) / float(FIXED_STILLS)))
		i = clampi(i, 0, samples.size() - 1)
		if not picked.has(i):
			picked.append(i)
	var out: Array = []
	for i in picked:
		out.append(int(samples[i]["idx"]))
	out.sort()
	return out


func _sorted(values: Array) -> Array:
	var v := values.duplicate()
	v.sort()
	return v


func _pct(values: Array, q: float) -> float:
	if values.is_empty():
		return 0.0
	var v := _sorted(values)
	var pos := q * float(v.size() - 1)
	var lo := int(floor(pos))
	var hi := int(ceil(pos))
	return snappedf(lerpf(float(v[lo]), float(v[hi]), pos - lo), 0.01)


func _column(samples: Array, key: String) -> Array:
	var out := []
	for s in samples:
		if s.has(key):
			out.append(s[key])
	return out


func _summary(samples: Array, draw_idx: Array, info: Dictionary) -> Dictionary:
	var sm := {"map": map_id, "stage": stage_index, "samples": samples.size(), "step_m": step, "poses_replayed": poses_file != "",
		"constants": _constants(), "items_collected": ix.size(), "kinds_collected": kind_names.size()}
	sm.merge(info)
	sm["union_line_km"] = snappedf(float(samples.size()) * step / 1000.0, 0.01) if poses_file == "" else null
	var by_cat := {}
	for c in CATS:
		by_cat[c] = {"median_120": _pct(_column(samples, c + "_120"), 0.5), "p10_120": _pct(_column(samples, c + "_120"), 0.1),
			"median_60": _pct(_column(samples, c + "_60"), 0.5), "p10_60": _pct(_column(samples, c + "_60"), 0.1)}
	sm["in_view_by_category"] = by_cat
	sm["dressing_in_view_120"] = {"median": _pct(_column(samples, "total_120"), 0.5), "p10": _pct(_column(samples, "total_120"), 0.1)}
	sm["dressing_in_view_60"] = {"median": _pct(_column(samples, "total_60"), 0.5), "p10": _pct(_column(samples, "total_60"), 0.1)}
	sm["core_in_view_60"] = {"median": _pct(_column(samples, "core_60"), 0.5), "p10": _pct(_column(samples, "core_60"), 0.1)}
	sm["distinct_kinds_120"] = {"median": _pct(_column(samples, "kinds_120"), 0.5), "p10": _pct(_column(samples, "kinds_120"), 0.1)}
	var bare := 0
	var run := 0
	var longest := 0
	var prev_line := ""
	var prev_along := -1e9
	for s in samples:
		var contiguous: bool = s["line"] == prev_line and float(s["along_m"]) - prev_along <= step * 1.5
		if s["bare"]:
			bare += 1
			run = run + 1 if contiguous and run > 0 else 1
			longest = maxi(longest, run)
		else:
			run = 0
		prev_line = s["line"]
		prev_along = float(s["along_m"])
	sm["bare_samples"] = bare
	sm["bare_share_pct"] = snappedf(100.0 * bare / samples.size(), 0.1)
	sm["longest_bare_run_m"] = longest * step
	var bare_ground := 0
	var ground_poses := 0
	var gruns := 0
	var glongest := 0
	var voids := 0
	var gline := ""
	var galong := -1e9
	for s in samples:
		var contiguous: bool = s["line"] == gline and float(s["along_m"]) - galong <= step * 1.5
		if s["void"]:
			voids += 1
			gruns = 0
		else:
			ground_poses += 1
			if s["bare"]:
				bare_ground += 1
				gruns = gruns + 1 if contiguous and gruns > 0 else 1
				glongest = maxi(glongest, gruns)
			else:
				gruns = 0
		gline = s["line"]
		galong = float(s["along_m"])
	sm["void_poses"] = voids
	sm["bare_ground_share"] = snappedf(100.0 * bare_ground / maxf(1.0, ground_poses), 0.1)
	sm["longest_bare_ground_run_m"] = glongest * step
	var draws := _column(samples, "draw_calls")
	var prims := _column(samples, "primitives")
	var deltas := []
	var pdeltas := []
	for s in samples:
		if s.has("draw_calls"):
			deltas.append(int(s["draw_calls"]) - int(s["draw_calls_no_props"]))
			pdeltas.append(int(s["primitives"]) - int(s["primitives_no_props"]))
	sm["draw_samples"] = draws.size()
	sm["draw_calls"] = {"median": _pct(draws, 0.5), "p95": _pct(draws, 0.95), "max": (_sorted(draws).back() if not draws.is_empty() else 0)}
	sm["primitives"] = {"median": _pct(prims, 0.5), "p95": _pct(prims, 0.95), "max": (_sorted(prims).back() if not prims.is_empty() else 0)}
	sm["props_only_draw_delta"] = {"median": _pct(deltas, 0.5), "max": (_sorted(deltas).back() if not deltas.is_empty() else 0), "park_props_nodes": props_nodes.size()}
	sm["props_only_primitive_delta"] = {"median": _pct(pdeltas, 0.5), "max": (_sorted(pdeltas).back() if not pdeltas.is_empty() else 0)}
	sm["draw_sample_idx"] = draw_idx
	sm.merge(_density(samples))
	var peak := -1
	var peak_at := {}
	for s in samples:
		if s.has("draw_calls") and int(s["draw_calls"]) - int(s["draw_calls_no_props"]) > peak:
			peak = int(s["draw_calls"]) - int(s["draw_calls_no_props"])
			peak_at = {"idx": s["idx"], "x": s["x"], "z": s["z"], "delta": peak, "breakdown": s.get("props_breakdown", {})}
	sm["props_peak_pose"] = peak_at
	return sm


func _density(samples: Array) -> Dictionary:
	var by_line := {}
	for s in samples:
		if not by_line.has(s["line"]):
			by_line[s["line"]] = []
		by_line[s["line"]].append(s)
	var windows := 0
	var exempt := 0
	var passed := 0
	var reasons := {}
	var fails: Array = []
	var rejected: Array = []
	var checked := 0
	var line_names := by_line.keys()
	line_names.sort()
	for line in line_names:
		var list: Array = by_line[line]
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["along_m"]) < float(b["along_m"]))
		var end_m := float(list.back()["along_m"])
		var start := 0.0
		while start < end_m:
			var stop := minf(start + DENSITY_WINDOW_M, end_m)
			if stop - start < (DENSITY_WINDOW_M if start + DENSITY_WINDOW_M <= end_m else DENSITY_TAIL_MIN_M):
				break
			var kinds := {}
			var window_poses: Array = []
			var mid: Dictionary = {}
			var best := INF
			for smp in list:
				var a := float(smp["along_m"])
				if a < start or a >= start + DENSITY_WINDOW_M:
					continue
				window_poses.append(smp)
				for k in smp.get("prop_kinds_60", []):
					kinds[k] = true
				if absf(a - (start + stop) * 0.5) < best:
					best = absf(a - (start + stop) * 0.5)
					mid = smp
			start += DENSITY_WINDOW_M
			if mid.is_empty():
				continue
			windows += 1
			var why := _density_exempt(Vector2(mid["x"], mid["z"]))
			if why == "open":
				checked += 1
				var verdict := _check_open(Vector2(mid["x"], mid["z"]), window_poses)
				if String(verdict["why"]) == "":
					why = "open:" + String(verdict["kind"])
				else:
					why = ""
					rejected.append({"at": [mid["x"], mid["z"]], "r": verdict["r"], "reason": verdict["reason"], "why": verdict["why"], "cell": verdict["cell"]})
			if why != "":
				exempt += 1
				reasons[why] = int(reasons.get(why, 0)) + 1
			elif kinds.size() >= DENSITY_MIN_KINDS:
				passed += 1
			else:
				fails.append({"line": line, "start_m": start - DENSITY_WINDOW_M, "kinds": kinds.size(), "at": [mid["x"], mid["z"]]})
	var counted := windows - exempt
	return {"density_windows": windows, "density_exempt": exempt, "density_exempt_by": reasons, "density_pass": passed,
		"density_fail_windows": fails, "density_open_checked": checked, "density_open_rejected": rejected, "density_share": snappedf(float(passed) / maxf(1.0, counted), 0.001),
		"density_rule": "%d+ distinct park-prop kinds in view within %.0f m per %.0f m window" % [DENSITY_MIN_KINDS, NEAR_M, DENSITY_WINDOW_M]}


func _check_open(at: Vector2, window_poses: Array) -> Dictionary:
	var space: Array = []
	for candidate in open_spaces:
		if (candidate[0] as Vector2).distance_to(at) <= float(candidate[1]):
			space = candidate
			break
	var reason: String = space[2]
	var kind := "runout" if reason.begins_with("runout:") else ("filled" if reason.begins_with("filled:") else "no_cell")
	var out := {"kind": kind, "reason": reason, "r": space[1], "why": "", "cell": null}
	if _probe.is_empty():
		var world := ParkProps.world_for(map_id)
		var file := ParkProps.load_json(ParkProps.file_path(map_id))
		var kit_path := String(file.get("kit", "res://assets/models/park/props/%s/manifest.json" % map_id.trim_prefix("park_")))
		var probe_c := ParkProps.context(world["map"], world["ground"], world["stage"])
		var probe_kit := ParkProps.load_json(kit_path)
		var placed: Array = ParkProps.expand(file, probe_kit, world["map"], world["ground"], probe_c) if reason.begins_with("filled:") or _filled_open() else []
		_probe = {"c": probe_c, "kit": probe_kit, "file": file, "placed": placed}
	var poses: Array = []
	for smp in window_poses:
		poses.append({"x": smp["x"], "z": smp["z"], "yaw": smp["yaw"]})
	var cam_spec := {"arm": CAMERAS[cam_name]["arm"], "pitch": CAM_PITCH, "up": CAM_UP, "fov_deg": CAMERAS[cam_name]["fov"], "aspect": float(SIZE.x) / float(SIZE.y)}
	var decided := ParkProps.open_reason(_probe["c"], _probe["kit"], _probe["file"], reason, at, poses, cam_spec, _probe["placed"])
	out["why"] = "" if decided["ok"] else String(decided["why"])
	out["cell"] = decided["cell"]
	return out


func _filled_open() -> bool:
	return open_spaces.any(func(space: Array) -> bool: return String(space[2]).begins_with("filled:"))


func _density_exempt(at: Vector2) -> String:
	var rows := {}
	for row in park.get("park_rows", []):
		rows[row["id"]] = row
	for home in park.get("home_rows", []):
		var site := String(home.get("site", ""))
		if rows.has(site) and ParkMap.footprint_contains(rows[site], at, ENGAGE_RING_M):
			return "arena"
		for act in park.get("activity_rows", []):
			if act.get("id") == site and Vector2(float(act["at"][0]), float(act["at"][1])).distance_to(at) <= ENGAGE_RING_M:
				return "arena"
	if park.has("landmark") and ParkMap.footprint_contains(park["landmark"], at, ENGAGE_RING_M):
		return "arena"
	for act in park.get("activity_rows", []):
		if String(act.get("activity", "")) == "enemy_camp" and Vector2(float(act["at"][0]), float(act["at"][1])).distance_to(at) <= ENGAGE_RING_M:
			return "camp"
	for ev in park.get("event_rows", []):
		var row = rows.get(String(ev.get("site", "")))
		if row != null and ParkMap.footprint_contains(row, at, float(ev.get("hold_clear_m", 0.0))):
			return "telegraph"
	for space in open_spaces:
		if (space[0] as Vector2).distance_to(at) <= float(space[1]):
			return "open"
	return ""


func _write(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
