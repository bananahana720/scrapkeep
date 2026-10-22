extends SceneTree

# Ride-path dressing audit for one park map (Dressing lane, DRESSING-KITS.md "Evidence per park PR"). It boots the
# park stage like the game does (table "park"), rides the union of the map's lines.json pilot lines and floor line in
# steps, and at every sample puts the ball on the ground and the player's chase-camera pose behind it. It reports
#   - dressing in view per sample, by category (math over the built nodes, no render needed),
#   - which samples are BARE, and the longest bare run,
#   - draw calls and primitives at a spread of samples (OpenGL compatibility proxy, cloud llvmpipe, not a
#     frame-cost proof), with and without the "park_props" group, so the props-only delta falls out of one run,
#   - stills from the player camera at the barest samples plus fixed ones, replayable with --poses.
#
#   xvfb-run -a -s "-screen 0 1280x720x24" $GODOT_BIN --rendering-driver opengl3 --path sketches/core-loop \
#     --resolution 1280x720 --script res://tools/park_props_audit.gd -- --map=park_dam --out=<abs dir> \
#     [--step=25] [--stills=12] [--draws=40] [--counts-only] [--poses=<poses.json>] [--cam=rest|mid|fast]
#
# Writes <out>/<map>/samples.json, summary.json, stills.json, poses.json and <map>-<idx>-<x>_<z>.png, then runs
# tools/park_props_contact.py for the contact sheet. Needs a display unless --counts-only.
#
# What counts as dressing (each item is one entry with a world-space centre; kinds are distinct meshes or dress_kind):
#   props     nodes in group "park_props": every MultiMesh instance, every MeshInstance3D; kind = meta dress_kind
#             (on the visual or an ancestor up to the group node), else the mesh.
#   clutter   SetDressing batches (presentation.set_dressing.batches), air motes excluded; per MultiMesh instance.
#   scatter   the stage's GroundScatter MultiMeshes; per instance.
#   anchors   the "Posts" MultiMesh of each ParkRows anchor field; per instance.
#   rows      a ParkRows Park_* or Landmark_* node with built GLB visuals (greybox stand-ins, colliders and ride
#             sensors skipped), one item per row at the union of its meshes. Split by the row's budget class:
#             the park JSON row's "budget", else ParkRecipes.ROWS[recipe].budget, else "landform". Only budget
#             "detail" (workings kits and the like) is `rows`; landform, park_large and hero_landmark rows are
#             `landforms`, counted for the record but not dressing and not in the bare rule.
#   scenery   children of the stage's SpillwayScenery, DigScenery, HighdraftScenery and Cottonwoods nodes: a
#             MultiMesh counts per instance, any other child as one item (a tree is one). Fx and mist nodes skipped.
# An item is in view when its centre is inside the camera frustum and within the range; engine visibility ranges
# (begin/end measured to the node's bounds centre) are honoured.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkProps := preload("res://src/presentation/park_props.gd")

const NEAR_M := 60.0
const FAR_M := 120.0
const DEDUP_M := 10.0
# A sample is BARE when props+clutter+scenery+rows(non-landform) within NEAR_M in view is below BARE_MIN_NEAR,
# or distinct kinds within FAR_M in view is below BARE_MIN_KINDS.
const BARE_MIN_NEAR := 5
const BARE_MIN_KINDS := 4
# The density bar (project-guide/coord/AMBITION-BRIEF.md, "Lived-in parks"): every 150 m of track has at least 3 distinct prop kinds
# visible within 60 m of the player camera. Exempt windows are named in _density_exempt.
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
# The chase camera (src/movement/chase_camera.gd): the anchor is the ball plus 0.8 m up; the arm runs back and up at
# pitch -0.30 rad (player pitch default, no bias) and is 7.5 m at rest to 10.5 m at speed (speed_arm), the lens 65 to
# 80 degrees (FOV_REST, FOV_FAST), far 700. "mid" is half speed, the default for a ride.
const CAMERAS := {"rest": {"arm": 7.5, "fov": 65.0}, "mid": {"arm": 9.0, "fov": 72.5}, "fast": {"arm": 10.5, "fov": 80.0}}
const CAM_UP := 0.8
const CAM_PITCH := -0.30
const CAM_FAR := 700.0
const DRAW_LABEL := "OpenGL compatibility proxy, cloud llvmpipe, not a frame-cost proof"

var map_id := ""
var out_root := ""
var step := 25.0
var still_count := 12
var draw_count := 40
var counts_only := false
var poses_file := ""
var cam_name := "mid"
# --open=x:z:r:<reason>,... : ruled open spaces (centre and radius, metres) whose windows are exempt from the density bar,
# each with a reason the audit checks instead of trusting (coordinator ruling #241 6329579296). The reason is everything after
# the third colon: runout:<kicker> (a kicker run-out lies within 40 m of the window centre) or no_cell (the audit's own probe
# finds no legal cell in the view cone of any pose in the window). A missing or unknown reason exits 2; a window whose reason
# fails is judged on its kinds like any other and listed in the summary's density_open_rejected.
var open_spaces: Array = []
const OPEN_RUNOUT_M := 40.0
var _probe := {}

var game
var cam: Camera3D
var stage_index := 0
var park: Dictionary = {}
var started_msec := 0

# Items: centre, category, kind id and owning node record.
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
			for part in a.trim_prefix("--open=").split(",", false):
				var f := part.split(":", true, 3)
				var reason := String(f[3]) if f.size() == 4 else ""
				if f.size() != 4 or not (reason == "no_cell" or (reason.begins_with("runout:") and reason.length() > 7)):
					printerr("park_props_audit: --open entry '%s' wants x:z:r:no_cell or x:z:r:runout:<kicker>" % part)
					quit(2)
					return
				open_spaces.append([Vector2(float(f[0]), float(f[1])), float(f[2]), reason])
		elif a == "--counts-only":
			counts_only = true
	if map_id == "" or out_root == "" or not CAMERAS.has(cam_name):
		printerr("park_props_audit: pass --map=<park map> --out=<absolute dir> [--cam=rest|mid|fast]")
		quit(2)
		return
	if DisplayServer.get_name() == "headless" and not counts_only:
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
		await _drawn(3)
		var png := ""
		if still_idx.has(idx):
			png = "%s-%d-%d_%d.png" % [map_id, idx, int(round(s["x"])), int(round(s["z"]))]
			root.get_texture().get_image().save_png(dir.path_join(png))
			stills.append({"file": png, "idx": idx, "x": s["x"], "z": s["z"], "yaw": s["yaw"], "line": s["line"], "along_m": s["along_m"],
				"props_120": s["total_120"], "core_60": s["core_60"], "kinds_120": s["kinds_120"], "bare": s["bare"], "void": s["void"]})
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


# ---- collecting the dressing ----

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
				# A vignette's merged far LOD: one draw, but every member prop counts where it stands.
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
			var posts := row.find_child("Posts", false, false)
			if posts is MultiMeshInstance3D:
				_add_multi(posts, C_ANCHORS, "anchor:" + str(row.get_meta("anchor_kit", "field")))
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


# The props views a camera pose draws, by "hero|vignette|litter / LOD / height tier": views in range (the end margin included) whose
# bounds meet the frustum, which is what the renderer submits (one draw each). Tier is the view's dress_tier meta.
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


# ---- the ride path ----

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
		out.append({"idx": int(p["idx"]), "line": p.get("line", ""), "along_m": p.get("along_m", 0.0), "x": float(p["x"]), "z": float(p["z"]), "yaw": float(p["yaw"])})
	return out


func _place(s: Dictionary) -> void:
	var x: float = s["x"]
	var z: float = s["z"]
	var ground: float = game.ctx.terrain.height(x, z)
	s["y"] = snappedf(ground, 0.01)
	var body = game.player.body()
	body.global_position = Vector3(x, ground + 1.0, z)
	body.linear_velocity = Vector3.ZERO
	var anchor := Vector3(x, ground + 1.0 + CAM_UP, z)
	var basis := Basis(Vector3.UP, float(s["yaw"])) * Basis(Vector3.RIGHT, CAM_PITCH)
	cam.global_transform = Transform3D(basis, anchor + basis * Vector3(0.0, 0.0, float(CAMERAS[cam_name]["arm"])))
	cam.fov = CAMERAS[cam_name]["fov"]


# ---- counting ----

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


# A void pose has no usable ground in view: fewer than VOID_GROUND_SHARE of a grid over the view cone (to VOID_VIEW_M
# ahead, VOID_HALF_FOV_DEG each side) lies within VOID_VERTICAL_M of the ball's height. Reporting only; BARE is unchanged.
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
				# The terrain's height function is a smooth floor even where nothing is built, so ask the physics world.
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


# ---- the summary ----

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
	# Ground-only view of the same rule: BARE poses on real ground, and the longest contiguous run of them.
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
	# The props-only peak pose: its breakdown by group / LOD / tier.
	var peak := -1
	var peak_at := {}
	for s in samples:
		if s.has("draw_calls") and int(s["draw_calls"]) - int(s["draw_calls_no_props"]) > peak:
			peak = int(s["draw_calls"]) - int(s["draw_calls_no_props"])
			peak_at = {"idx": s["idx"], "x": s["x"], "z": s["z"], "delta": peak, "breakdown": s.get("props_breakdown", {})}
	sm["props_peak_pose"] = peak_at
	return sm


# The density bar. Per line, 150 m windows of its samples (full windows, and a tail of at least DENSITY_TAIL_MIN_M); a window's kinds are
# the union of the park-prop kinds (group "park_props" only, not set dressing) in view within 60 m at any of its sample poses. Samples
# are the audit's deduplicated union (a stretch shared by two lines belongs to the first, floor first). A window is exempt when its
# midpoint (the window's sample nearest the middle) lies in:
#   arena      the footprint of a home_rows site (park row, or the activity row's point) or the landmark row, grown by ENGAGE_RING_M
#   camp       an activity_rows enemy_camp (the camp's `at` point), grown by ENGAGE_RING_M (the validator's camp ring)
#   telegraph  the footprint of an event_rows site (park row), grown by the event's hold_clear_m (0 when absent)
#   open       a --open=x:z:r:<reason> space whose reason checks out (runout:<kicker> or no_cell, see _check_open); a failed reason is not exempt
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


# Verifies the --open space holding `at` against its reason: {kind, reason, r, why ("" when it holds), cell}.
func _check_open(at: Vector2, window_poses: Array) -> Dictionary:
	var space: Array = []
	for candidate in open_spaces:
		if (candidate[0] as Vector2).distance_to(at) <= float(candidate[1]):
			space = candidate
			break
	var reason: String = space[2]
	var out := {"kind": "runout" if reason.begins_with("runout:") else "no_cell", "reason": reason, "r": space[1], "why": "", "cell": null}
	if _probe.is_empty():
		var world := ParkProps.world_for(map_id)
		var c := ParkProps.context(world["map"], world["ground"], world["stage"])
		var file := ParkProps.load_json(ParkProps.file_path(map_id))
		var kit_path := String(file.get("kit", "res://assets/models/park/props/%s/manifest.json" % map_id.trim_prefix("park_")))
		var kit := ParkProps.load_json(kit_path)
		_probe = {"c": c, "kit": kit, "kind": ParkProps.probe_kind_of(kit)}
	var ctx = _probe["c"]
	if reason.begins_with("runout:"):
		out["why"] = ParkProps.runout_near(ctx, reason.trim_prefix("runout:"), at, OPEN_RUNOUT_M)
		return out
	if String(_probe["kind"]) == "":
		out["why"] = "no kit to probe with"
		return out
	var fov_v := deg_to_rad(float(CAMERAS[cam_name]["fov"]))
	var fov_h := rad_to_deg(2.0 * atan(tan(fov_v * 0.5) * float(SIZE.x) / float(SIZE.y)))
	var poses: Array = []
	for smp in window_poses:
		poses.append({"x": smp["x"], "z": smp["z"], "yaw": smp["yaw"], "arm": CAMERAS[cam_name]["arm"], "pitch": CAM_PITCH})
	var cells := ParkProps.cone_legal_cells(ctx, _probe["kit"], String(_probe["kind"]), poses, fov_h, NEAR_M)
	if not cells.is_empty():
		out["cell"] = [cells[0].x, cells[0].y]
		out["why"] = "probe kind %s has a legal cell at (%.0f, %.0f) in the view cone" % [_probe["kind"], cells[0].x, cells[0].y]
	return out


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
