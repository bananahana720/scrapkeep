extends SceneTree

# The look harness: every wave 12 look unit and judge renders named subjects through it.
# Subjects and cameras live in look_subjects.gd (one row per subject); this file stages them.
#
# Render (native display; on card 1 through tools/coordinator/gpu_queue.sh --gpu 1 --need 3000 --display --shared):
#   godot --rendering-driver vulkan --display-driver x11 --gpu-index $SCRAPKEEP_GPU_INDEX --path sketches/core-loop
#     --resolution 1920x1080 --script res://tools/look_harness.gd -- --subject=<name>[,<name>...]|--all --out=<abs dir>
#     [--tick=N] [--preset=high|low|target] [--variant=<label>] [--class=N]
#     [--hide-ui=0] [--baseline=<sha7>] [--pair --base=<sha7>] [--baseline-root=<abs dir>]
#   Writes <out>/<subject>/<camera>.png and <out>/<subject>/frames.json, and <out>/run.json over the run.
#   Subjects of one group render in one boot; several groups run one child process per group.
#   The tree pauses on the subject's physics tick (its row's tick, or --tick) before the first frame,
#   so a re-run draws the same tick. Each frame records its metrics (near-black share, flat-sky share:
#   the single most common colour, mean luminance) and the ball's screen box; a frame over its row's
#   dead_frame limits is dead, and any dead frame makes the run exit 1 naming subject/camera.
#   The ball (the scale mannequin) is placed beside each camera's target, on the floor under it,
#   for every subject that is not a ui row. Its point is a function of the camera row alone: a
#   point the row pins ("ball": {camera: offset from the target}), else ball_candidates(eye,
#   target) tried in order against static colliders only (enemy, Warden and rigid bodies are
#   skipped), never where the staging left the ball or where the previous camera put it. With
#   --base, the base run's recorded point wins, so both sides of a pair show the ball on one spot.
#   Whether the ball shows is the render's answer, not a ray's: the frame is drawn again with the
#   ball hidden and ball.visible is the share of its screen disk that changed (ball_seen); an
#   actor or prop frame under SEEN_SHARE fails the run as NO_BALL.
#   --baseline=<sha7>  renders into <baseline root>/<sha7>/ (default root artifacts/local/alpha/baselines).
#   --pair --base=<sha7>  after rendering, writes <out>/pairs/<subject>__<camera>/{a,b}.png and
#     <out>/pairs/key.json; which side is the baseline is the subject/camera coin (look_subjects.coin),
#     never printed. A subject whose base and head frames.json name different adapters is not paired.
#     A missing or empty baseline fails the run before it renders (exit 2), and a run that makes
#     0 pairs fails after it (exit 1); either prints the reason (pair_problem).
#   Every frames.json in a run must name the run's adapter; a drift fails the run.
#   Non-ui subjects hide the Moss bubble and the world prompts (presentation.hide_ui) unless --hide-ui=0.
# Frame strips (MOTION-SPEC row 217): --frames=N renders N consecutive frames of every camera of a non-ui
#   subject at a fixed --fps (default 60), for the strobe, bank, rope and slam reads a still cannot show.
#     --frames=N          the strip length (1..600); without it every flag below is refused (exit 2).
#     --fps=F             the fixed rate: frame i is i/F seconds after frame 0, whatever the wall clock.
#     --speed=M [--dir=x,y,z]   roll at M m/s along dir (default forward, -Z; made tangent to a
#                         --contact-normal). The ball stays on its camera's point (a treadmill):
#                         the speed drives the roll, the stretch and the pod's heading, not travel.
#     --pod-yaw=DEG       the pod's world yaw, held around the game's own steering each frame (0 faces -Z);
#                         a subject with no pod warns and records "pod_yaw_applied": false.
#     --contact-normal=x,y,z   the surface under the ball (a park wall: its normal); the squash axis
#                         and the rolling axis follow it, and the ball counts as grounded.
#     --anchor=x,y,z | --anchor-rel=x,y,z   hook the harpoon line there (world point, or an offset
#                         from the ball) and set the rope taut.
#     --squash-tick=N [--squash=A]   frame 0 is N physics ticks (1/90 s) after a slam or landing
#                         squash of amount A (default 0.45, the peak) along the contact normal (else up).
#   Not stepped: player_fx (trails, speed rings, sound words) and the camera, so those freeze across a strip.
#   The tree stays paused: each frame steps the ball's roll, the pod, the juice springs and the line
#   by exactly 1/F s, so spin and squash advance between frames. Writes <out>/<subject>/<camera>/f0000.png
#   and a frames.json row per frame (id <camera>_f0000, "frame": {index, time, fps, overrides}). Ball
#   visibility is measured on frame 0 and shared by the strip ("seen_of": 0). Stills are untouched by
#   these flags: a run without --frames writes the same files as before.
# Serve: --serve --out=<abs dir> renders each <out>/requests/<id>.json ({"subjects": [...]} or
#   {"quit": true}) and answers <out>/answers/<id>.json, for units with many render cycles.
# Boss smoke: --boss=bowl|waking|mind boots on the native display, enters that world's last stage
#   and its arena as the bot does (flow.enter_stage, then flow.enter_boss), runs 300 physics ticks
#   and prints one BOSS_SMOKE line with the device (sketch-export runs it per boss on Vulkan).
# Silhouette helper for asset tests: subject_bounds(node) is the world AABB of the visible meshes
#   under it; facing(node, eye) is the angle in degrees between the node's forward (-Z) and the
#   direction to the camera eye; a subject faces a named view when facing() is under 90.
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const OffscreenWindow := preload("res://tools/offscreen_window.gd")
const Subjects := preload("res://tools/look_subjects.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")

const SIZE := Vector2i(1920, 1080)
const METRIC_SIZE := Vector2i(480, 270)
const BLACK_LEVEL := 24
const DRAW_FRAMES := 12
const SEED := 280928
const BOSS_TICKS := 300
# A collider this close to the eye (the camera inside or against it) does not pull the ball in.
const NEAR_PULL := 4.0
const BOSSES := {"bowl": 1, "waking": 2, "mind": 3}
# ball_seen: a pixel changed when a channel moves more than SEEN_DELTA with the ball hidden; the
# ball shows when SEEN_SHARE of its on-screen disk changed; at most SEEN_SAMPLES pixels are read.
const SEEN_DELTA := 12.0 / 255.0
const SEEN_SHARE := 0.2
const SEEN_SAMPLES := 4096

var out := ""
var requested: Array = []
var all := false
var group_arg := ""
var tick_override := -1
var preset := ""
var variant := ""
var class_index := 1
var baseline := ""
var pair := false
var base := ""
var baseline_root := ""
var serve := false
var hide_ui := true
var boss := ""
var strip := {"frames": 0}
var strip_args: Array = []

var game
var cam: Camera3D
var ticks := 0
var failures := 0
var _anchors := {}
var _pins := {}
var _yaw_probe := {}


func _initialize() -> void:
	OffscreenWindow.apply(root)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		elif a.begins_with("--subject="): requested = Array(a.trim_prefix("--subject=").split(",", false))
		elif a == "--all": all = true
		elif a.begins_with("--group="): group_arg = a.trim_prefix("--group=")
		elif a.begins_with("--tick="): tick_override = int(a.trim_prefix("--tick="))
		elif a.begins_with("--preset="): preset = a.trim_prefix("--preset=")
		elif a.begins_with("--variant="): variant = a.trim_prefix("--variant=")
		elif a.begins_with("--class="): class_index = int(a.trim_prefix("--class="))
		elif a.begins_with("--baseline="): baseline = a.trim_prefix("--baseline=")
		elif a == "--pair": pair = true
		elif a.begins_with("--base="): base = a.trim_prefix("--base=")
		elif a.begins_with("--baseline-root="): baseline_root = a.trim_prefix("--baseline-root=")
		elif a == "--serve": serve = true
		elif a.begins_with("--hide-ui="): hide_ui = a.trim_prefix("--hide-ui=") != "0"
		elif a.begins_with("--boss="): boss = a.trim_prefix("--boss=")
	for a in OS.get_cmdline_user_args():
		if Subjects.FRAME_FLAGS.any(func(f): return String(a).begins_with(f)):
			strip_args.append(a)
	strip = Subjects.frame_options(strip_args)
	if not (strip["problems"] as Array).is_empty():
		printerr("look_harness: ", "; ".join(strip["problems"]))
		quit(2)
		return
	if baseline_root.is_empty():
		baseline_root = ProjectSettings.globalize_path("res://").path_join("../../artifacts/local/alpha/baselines").simplify_path()
	if not baseline.is_empty():
		out = baseline_root.path_join(baseline)
	if DisplayServer.get_name() == "headless":
		printerr("look_harness: needs a native display (run through gpu_queue.sh --display)")
		quit(2)
		return
	if boss.is_empty() and out.is_empty():
		printerr("look_harness: needs --out or --baseline")
		quit(2)
		return
	if pair and base.is_empty():
		printerr("look_harness: --pair needs --base=<sha7>")
		quit(2)
		return
	if pair:
		var why := pair_problem(baseline_root.path_join(base))
		if not why.is_empty():
			printerr("look_harness: --pair FAIL: ", why)
			quit(2)
			return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out)
	_main.call_deferred()


func _physics_process(_delta: float) -> bool:
	if not paused:
		ticks += 1
	return false


func _main() -> void:
	if not Subjects.station_errors.is_empty():
		printerr("look_harness: ", "; ".join(Subjects.station_errors))
		quit(2)
		return
	if not boss.is_empty():
		quit(await _boss_smoke(boss))
		return
	if serve:
		quit(_serve())
		return
	if all:
		requested = Subjects.names()
	for n in requested:
		if not Subjects.SUBJECTS.has(n):
			printerr("look_harness: unknown subject ", n)
			quit(2)
			return
	if requested.is_empty():
		printerr("look_harness: needs --subject=, --all, --serve or --boss=")
		quit(2)
		return
	if Subjects.is_strip(strip) and requested.any(func(n): return Subjects.SUBJECTS[n]["kind"] == "ui"):
		printerr("look_harness: --frames needs actor, prop or scene subjects, not ui rows")
		quit(2)
		return
	var groups := _groups_of(requested)
	if not group_arg.is_empty() or groups.size() == 1:
		await _run_group(groups[0] if group_arg.is_empty() else group_arg)
		quit(failures)
		return
	quit(_render_children(requested, out))


# ---------------------------------------------------------------- runs, children, summary
static func _groups_of(subjects: Array) -> Array:
	var groups: Array = []
	for g in Subjects.GROUPS:
		if subjects.any(func(n): return Subjects.SUBJECTS[n]["group"] == g):
			groups.append(g)
	return groups


# The Mac executable chooses embedded startup before it reads --display-driver.
# A child rendering another capture group must make the same choice as its parent.
static func child_display_args(platform: String, display: String) -> Array:
	var driver := display.to_lower()
	if platform == "macOS" and driver == "embedded":
		return ["--embedded", "--debug", "--skip-breakpoints", "--ignore-error-breaks", "--audio-driver", "Dummy", "--display-driver", driver]
	return ["--display-driver", driver]


func _render_children(subjects: Array, dir: String) -> int:
	var logs := dir.path_join("_logs")
	DirAccess.make_dir_recursive_absolute(logs)
	# OS.get_cmdline_args() drops the engine's own flags (a child given only those rendered on
	# card 0 while the parent ran on card 1), so each child gets the parent's renderer, display
	# and the queue's card index explicitly.
	var engine_args := child_display_args(OS.get_name(), DisplayServer.get_name())
	engine_args.append_array(["--path", ProjectSettings.globalize_path("res://"), "--rendering-driver", RenderingServer.get_current_rendering_driver_name(),
		"--resolution", "%dx%d" % [SIZE.x, SIZE.y], "--script", "res://tools/look_harness.gd"])
	if OS.has_environment("SCRAPKEEP_GPU_INDEX"):
		engine_args.append_array(["--gpu-index", OS.get_environment("SCRAPKEEP_GPU_INDEX")])
	var rows: Array = []
	for g in _groups_of(subjects):
		var mine: Array = subjects.filter(func(n): return Subjects.SUBJECTS[n]["group"] == g)
		var args := engine_args.duplicate()
		args.append_array(["--", "--out=" + dir, "--group=" + g, "--subject=" + ",".join(mine), "--class=%d" % class_index])
		if tick_override >= 0: args.append("--tick=%d" % tick_override)
		if not preset.is_empty(): args.append("--preset=" + preset)
		if not variant.is_empty(): args.append("--variant=" + variant)
		args.append_array(strip_args)
		if not base.is_empty(): args.append_array(["--base=" + base, "--baseline-root=" + baseline_root])
		var started := Time.get_ticks_msec()
		var output: Array = []
		var rc := OS.execute(OS.get_executable_path(), args, output, true)
		var wall := (Time.get_ticks_msec() - started) / 1000.0
		var f := FileAccess.open(logs.path_join(g + ".log"), FileAccess.WRITE)
		f.store_string("\n".join(output))
		f.close()
		print("group %s rc=%d wall=%.1f s subjects=%d" % [g, rc, wall, mine.size()])
		rows.append({"group": g, "rc": rc, "wall_s": wall, "subjects": mine})
	return _summarize(subjects, dir, rows)


func _summarize(subjects: Array, dir: String, groups: Array) -> int:
	var dead: Array = []
	var missing: Array = []
	var no_ball: Array = []
	var adapter := RenderingServer.get_video_adapter_name()
	var drift: Array = []
	for n in subjects:
		var fj := dir.path_join(n).path_join("frames.json")
		if not FileAccess.file_exists(fj):
			missing.append(n)
			continue
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fj))
		if doc["adapter"] != adapter:
			drift.append("%s on %s" % [n, doc["adapter"]])
		for fr in doc["frames"]:
			if fr["dead"]:
				dead.append("%s/%s" % [n, fr["id"]])
			if Subjects.needs_ball(n) and (not fr["ball"]["in_frame"] or not fr["ball"].get("seen", false)):
				no_ball.append("%s/%s" % [n, fr["id"]])
	var failed_groups: Array = groups.filter(func(r): return r["rc"] != 0).map(func(r): return r["group"])
	var pair_why := _pair(subjects, dir) if pair else ""
	var doc := {"tool": "look_harness.gd", "variant": variant, "preset": preset, "adapter": adapter, "subjects": subjects.size(), "groups": groups,
		"dead": dead, "missing": missing, "ball_out_of_frame": no_ball, "adapter_drift": drift, "failed_groups": failed_groups, "pair_problem": pair_why}
	var f := FileAccess.open(dir.path_join("run.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "\t"))
	f.close()
	for d in dead: print("DEAD ", d)
	for m in missing: print("MISSING ", m)
	for b in no_ball: print("NO_BALL ", b)
	for a in drift: print("ADAPTER_DRIFT ", a, " (run on ", adapter, ")")
	var bad := not dead.is_empty() or not missing.is_empty() or not failed_groups.is_empty() or not no_ball.is_empty() or not drift.is_empty() or not pair_why.is_empty()
	print("look_harness: %s subjects=%d dead=%d missing=%d no_ball=%d adapter_drift=%d failed_groups=%d adapter=%s" % ["FAIL" if bad else "PASS", subjects.size(), dead.size(), missing.size(), no_ball.size(), drift.size(), failed_groups.size(), adapter])
	return 1 if bad else 0


func _serve() -> int:
	var inbox := out.path_join("requests")
	var answers := out.path_join("answers")
	DirAccess.make_dir_recursive_absolute(inbox)
	DirAccess.make_dir_recursive_absolute(answers)
	print("look_harness: serving ", inbox)
	while true:
		var files := Array(DirAccess.get_files_at(inbox)).filter(func(f): return f.ends_with(".json"))
		files.sort()
		for file in files:
			var path := inbox.path_join(file)
			var req = JSON.parse_string(FileAccess.get_file_as_string(path))
			DirAccess.remove_absolute(path)
			if not (req is Dictionary):
				continue
			if req.get("quit", false):
				return 0
			var subjects: Array = (req.get("subjects", []) as Array).filter(func(n): return Subjects.SUBJECTS.has(n))
			var dir := out.path_join(file.get_basename())
			var rc := _render_children(subjects, dir)
			var ans := FileAccess.open(answers.path_join(file), FileAccess.WRITE)
			ans.store_string(JSON.stringify({"rc": rc, "dir": dir, "subjects": subjects}))
			ans.close()
		OS.delay_msec(250)
	return 0


# ---------------------------------------------------------------- frames
static func frame_metrics(img: Image) -> Dictionary:
	var small: Image = img.duplicate()
	if small.get_format() != Image.FORMAT_RGB8:
		small.convert(Image.FORMAT_RGB8)
	small.resize(METRIC_SIZE.x, METRIC_SIZE.y, Image.INTERPOLATE_NEAREST)
	var data := small.get_data()
	var n := data.size() / 3
	var black := 0
	var luma := 0.0
	var counts := {}
	for i in n:
		var r := data[i * 3]
		var g := data[i * 3 + 1]
		var b := data[i * 3 + 2]
		if r < BLACK_LEVEL and g < BLACK_LEVEL and b < BLACK_LEVEL:
			black += 1
		luma += 0.2126 * r + 0.7152 * g + 0.0722 * b
		var key := (r << 16) | (g << 8) | b
		counts[key] = counts.get(key, 0) + 1
	var top := 0
	var top_key := 0
	for k in counts:
		if counts[k] > top:
			top = counts[k]
			top_key = k
	return {"black": float(black) / n, "sky": float(top) / n, "sky_rgb": [top_key >> 16, (top_key >> 8) & 255, top_key & 255], "luma": luma / n / 255.0}


static func is_dead(metrics: Dictionary, limits: Dictionary) -> bool:
	return metrics["black"] > limits["black"] or metrics["sky"] > limits["sky"]


# The rule's two ball points for a camera, in the order tried: beside the target on the
# camera's right, then its left (side grows with distance), both moved toward the eye for a far
# view and behind the target for a close one. Eye and target alone decide them.
static func ball_candidates(eye: Vector3, target: Vector3) -> Array:
	var to_eye := eye - target
	var dist := to_eye.length()
	var right := Basis.looking_at(target - eye, Vector3.UP).x
	var side := clampf(dist * 0.22, 1.5, 24.0)
	var toward := to_eye.normalized() * clampf((dist - 8.0) * 0.35, -2.0, 8.0)
	return [target + right * side + toward, target - right * side + toward]


# Camera name to the ball point a frames.json recorded, for --base.
static func ball_pins(frames_doc: Dictionary) -> Dictionary:
	var pins := {}
	for fr in frames_doc.get("frames", []):
		var at = (fr.get("ball", {}) as Dictionary).get("at", null)
		if at is Array and at.size() == 3:
			pins[String(fr["id"])] = Vector3(at[0], at[1], at[2])
	return pins


# Share of the ball's on-screen disk (bbox from ball_box) whose pixels differ between the frame
# with the ball and the same frame with the ball hidden: 0 when a wall or the frame edge hides
# it, near 1 when it is in plain view. Physics rays cannot answer this, because visual-only
# meshes (the pit's rock bands, the cache shell) have no collider.
static func ball_seen(on: Image, off: Image, bbox: Array) -> float:
	if bbox.size() != 4 or on.get_size() != off.get_size():
		return 0.0
	var r: float = bbox[2] * 0.5
	var cx: float = bbox[0] + r
	var cy: float = bbox[1] + r
	var x0 := maxi(0, floori(bbox[0]))
	var y0 := maxi(0, floori(bbox[1]))
	var x1 := mini(on.get_width(), ceili(bbox[0] + bbox[2]))
	var y1 := mini(on.get_height(), ceili(bbox[1] + bbox[3]))
	var stride := maxi(1, ceili(sqrt(bbox[2] * bbox[3] / float(SEEN_SAMPLES))))
	var total := 0
	var changed := 0
	for y in range(y0, y1, stride):
		for x in range(x0, x1, stride):
			if (x + 0.5 - cx) * (x + 0.5 - cx) + (y + 0.5 - cy) * (y + 0.5 - cy) > r * r:
				continue
			total += 1
			var a := on.get_pixel(x, y)
			var b := off.get_pixel(x, y)
			if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) > SEEN_DELTA:
				changed += 1
	return 0.0 if total == 0 else float(changed) / total


# Screen box of a sphere of radius r at p, in viewport pixels; in_frame when it overlaps the frame.
static func ball_box(camera: Camera3D, p: Vector3, r: float, size: Vector2i) -> Dictionary:
	if camera.is_position_behind(p):
		return {"in_frame": false, "bbox": []}
	var c := camera.unproject_position(p)
	var e := camera.unproject_position(p + camera.global_basis.y * r)
	var rad := maxf(1.0, c.distance_to(e))
	var box := Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0)
	var inside := box.intersects(Rect2(Vector2.ZERO, Vector2(size)))
	return {"in_frame": inside, "bbox": [snappedf(box.position.x, 0.1), snappedf(box.position.y, 0.1), snappedf(box.size.x, 0.1), snappedf(box.size.y, 0.1)]}


static func write_pairs(subjects: Array, base_dir: String, head_dir: String, pair_dir: String) -> int:
	DirAccess.make_dir_recursive_absolute(pair_dir)
	var key := {"base": base_dir, "head": head_dir, "pairs": {}}
	var made := 0
	for n in subjects:
		var adapters := [_adapter_of(base_dir.path_join(n)), _adapter_of(head_dir.path_join(n))]
		for shot in Subjects.SUBJECTS[n]["cameras"]:
			if adapters[0] != adapters[1]:
				key["pairs"]["%s__%s" % [n, shot[0]]] = "adapter_mismatch: base %s, head %s" % adapters
				continue
			var file: String = shot[0] + ".png"
			var bp := base_dir.path_join(n).path_join(file)
			var hp := head_dir.path_join(n).path_join(file)
			if not FileAccess.file_exists(bp) or not FileAccess.file_exists(hp):
				key["pairs"]["%s__%s" % [n, shot[0]]] = "missing"
				continue
			var d := pair_dir.path_join("%s__%s" % [n, shot[0]])
			DirAccess.make_dir_recursive_absolute(d)
			var base_is_a := Subjects.coin(n, shot[0])
			DirAccess.copy_absolute(bp if base_is_a else hp, d.path_join("a.png"))
			DirAccess.copy_absolute(hp if base_is_a else bp, d.path_join("b.png"))
			key["pairs"]["%s__%s" % [n, shot[0]]] = {"a": "base" if base_is_a else "head", "b": "head" if base_is_a else "base"}
			made += 1
	var f := FileAccess.open(pair_dir.path_join("key.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(key, "\t"))
	f.close()
	print("pairs: %d written to %s (key in key.json)" % [made, pair_dir])
	return made


# Pairs the run against --base and returns why the pairing proved nothing, "" when it made pairs.
func _pair(subjects: Array, dir: String) -> String:
	var base_dir := baseline_root.path_join(base)
	var why := pair_problem(base_dir)
	if why.is_empty():
		why = pair_problem(base_dir, write_pairs(subjects, base_dir, dir, dir.path_join("pairs")))
	if not why.is_empty():
		printerr("look_harness: --pair FAIL: ", why)
	return why


# Why a blind pair against base_dir proves nothing: the baseline is missing, empty, or (made
# given) yielded no pair. "" when it is sound.
static func pair_problem(base_dir: String, made := -1) -> String:
	if not DirAccess.dir_exists_absolute(base_dir):
		return "baseline %s does not exist" % base_dir
	if DirAccess.get_directories_at(base_dir).is_empty() and DirAccess.get_files_at(base_dir).is_empty():
		return "baseline %s is empty" % base_dir
	if made == 0:
		return "0 pairs against baseline %s (key.json names each refusal)" % base_dir
	return ""


# A pair is only fair on one card and driver: the adapter a subject folder's frames.json names.
static func _adapter_of(dir: String) -> String:
	var fj := dir.path_join("frames.json")
	if not FileAccess.file_exists(fj):
		return ""
	var doc = JSON.parse_string(FileAccess.get_file_as_string(fj))
	return String(doc.get("adapter", "")) if doc is Dictionary else ""


# ---------------------------------------------------------------- silhouette helper
static func subject_bounds(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "GeometryInstance3D", true, false):
		if not m.is_visible_in_tree() or not (m is MeshInstance3D or m is MultiMeshInstance3D):
			continue
		if m.get_aabb().size == Vector3.ZERO:
			continue
		var b: AABB = m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if n is MeshInstance3D and first:
		box = n.global_transform * n.get_aabb()
	return box


static func facing(n: Node3D, eye: Vector3) -> float:
	var fwd := -n.global_basis.z
	var to_eye := eye - n.global_position
	fwd.y = 0.0
	to_eye.y = 0.0
	if fwd.length() < 0.0001 or to_eye.length() < 0.0001:
		return 0.0
	return rad_to_deg(fwd.normalized().angle_to(to_eye.normalized()))


# ---------------------------------------------------------------- staging
func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _gh(x: float, z: float) -> float:
	return game.ctx.terrain.height(x, z)


func _boot(warden := false, table := "alpha") -> void:
	seed(SEED)
	game = Game.new()
	game.name = "Game"
	game.test_mode = true
	game.table = table
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	await process_frame
	game.ctx.calm = true
	game.flow.force_warden = warden
	game.flow.press_start()
	game.flow.choose_class(class_index)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	cam = Camera3D.new()
	cam.far = 1800.0
	cam.near = 0.05
	game.add_child(cam)


func _boot_play(stage := 1, warden := false) -> void:
	await _boot(warden)
	await _frames(60)
	if stage != 1:
		await _stage(stage)


func _stage(stage: int) -> void:
	game.flow.enter_stage(stage, Vector3.ZERO, false)
	await _frames(40)
	game.player.body().freeze = true


func _anchor(name: String, point: Vector3, node: Node3D = null, radius := 1.0) -> void:
	_anchors[name] = {"point": point, "basis": node.global_basis if node != null else Basis.IDENTITY, "radius": radius}


func _wants(subject: String) -> bool:
	return requested.has(subject)


func _wait_tick(subject: String) -> Dictionary:
	var want: int = tick_override if tick_override >= 0 else int(Subjects.SUBJECTS[subject]["tick"])
	var late := want > 0 and ticks > want
	while ticks < want:
		await physics_frame
	return {"tick": ticks, "wanted": want, "late": late}


# The ball, frozen, moved under the paused tree to the camera row's point: the body for physics
# and the visual root (the parent of the juice node), which _process places and a paused tree no
# longer updates. The point, in order: the --base run's recorded point for this camera; the
# row's pin ("ball": {camera: offset from the target}) on the floor under it; else the first of
# ball_candidates the eye sees past static colliders, else the first pulled in front of the
# static collider that hides it. Rays skip enemies, the Warden and rigid bodies, so where they
# stand at the tick cannot move the ball, and nothing reads where the staging left it.
func _place_ball(subject: String, shot_name: String, eye: Vector3, target: Vector3) -> Dictionary:
	if Subjects.SUBJECTS[subject]["group"] == "staged":
		var at: Vector3 = game.player.ball_position()
		_ball_root().global_position = at
		return {"at": at, "placed": "station"}
	var how := "rule"
	var p := Vector3.INF
	var pinned: Dictionary = Subjects.SUBJECTS[subject].get("ball", {})
	if _pins.has(shot_name):
		p = _pins[shot_name]
		how = "base"
	elif pinned.has(shot_name):
		p = _on_floor(target + pinned[shot_name])
		how = "row"
	else:
		var cands := ball_candidates(eye, target)
		var first := _on_floor(cands[0])
		p = first
		if _hidden(eye, first):
			var second := _on_floor(cands[1])
			if not _hidden(eye, second):
				p = second
			else:
				var hit := _ray(eye, first)
				if not hit.is_empty() and eye.distance_to(hit["position"]) > NEAR_PULL:
					var h: Vector3 = hit["position"]
					p = _on_floor(h + (eye - h).normalized() * (Tuning.RADIUS + 0.4))
	var body: RigidBody3D = game.player.body()
	body.freeze = true
	body.global_position = p
	_ball_root().global_position = p
	return {"at": p, "placed": how}


func _ball_root() -> Node3D:
	return game.player.juice_node().get_parent() as Node3D


# A ray against the stage's static colliders: the player, enemies (the Warden is one) and rigid
# bodies are skipped, so the answer is the same whatever moved before the tick.
func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var skip: Array[RID] = [game.player.body().get_rid()]
	for i in 16:
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.exclude = skip
		var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			return hit
		var c = hit.get("collider")
		if not (c is CharacterBody3D or c is RigidBody3D):
			return hit
		skip.append(hit["rid"])
	return {}


# The floor under p: the nearest surface below a point just above it, so a stacked arena
# puts the ball on the floor the target stands on, not the slab over it; a longer cast when
# nothing is under that, and p itself when the floor would leave the frame.
func _on_floor(p: Vector3) -> Vector3:
	for up in [2.0, 30.0]:
		var hit := _ray(p + Vector3.UP * up, p + Vector3.DOWN * 80.0)
		if not hit.is_empty():
			var on_floor: Vector3 = hit["position"] + Vector3.UP * Tuning.RADIUS
			return on_floor if cam.is_position_in_frustum(on_floor) else p
	return p


func _hidden(eye: Vector3, p: Vector3) -> bool:
	var hit := _ray(eye, p)
	return not hit.is_empty() and eye.distance_to(hit["position"]) < eye.distance_to(p) - Tuning.RADIUS


func _shoot(subject: String, extra := {}) -> void:
	if not _wants(subject):
		return
	var row: Dictionary = Subjects.SUBJECTS[subject]
	var ui: bool = row["kind"] == "ui"
	var dir := out.path_join(subject)
	DirAccess.make_dir_recursive_absolute(dir)
	var tick: Dictionary = await _wait_tick(subject)
	var was_paused := paused
	paused = true
	if not ui:
		for n in root.find_children("*", "CanvasLayer", true, false): n.visible = false
		for l in root.find_children("*", "Label3D", true, false): l.visible = false
		if hide_ui:
			game.presentation.hide_ui()
	_pins = {}
	var base_frames := baseline_root.path_join(base).path_join(subject).path_join("frames.json")
	if not base.is_empty() and FileAccess.file_exists(base_frames):
		_pins = ball_pins(JSON.parse_string(FileAccess.get_file_as_string(base_frames)))
	var recs: Array = []
	for shot in row.cameras:
		var v := Subjects.resolve(subject, shot, _anchors)
		if extra.has("mast") and shot[0] == "numerical_aim":
			v.fov = game.camera.cam.fov
		var ball := {"in_frame": false, "bbox": []}
		var settled := _check_stage_yaw(subject, String(shot[0]))
		var started := Time.get_ticks_msec()
		if not ui:
			cam.global_position = v["eye"]
			cam.look_at(v["target"], Vector3.UP)
			cam.fov = v["fov"]
			cam.current = true
			var placed := _place_ball(subject, String(shot[0]), v["eye"], v["target"])
			var p: Vector3 = placed["at"]
			ball = ball_box(cam, p, Tuning.RADIUS, SIZE)
			ball["at"] = [p.x, p.y, p.z]
			ball["placed"] = placed["placed"]
		if Subjects.is_strip(strip) and not ui:
			recs.append_array(await _strip_camera(subject, shot, v, dir, ball))
			continue
		for i in DRAW_FRAMES:
			await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var png := dir.path_join(String(shot[0]) + ".png")
		img.save_png(png)
		if not ui:
			# The same frame without the ball: what changed inside its disk is what showed.
			_ball_root().visible = false
			for i in DRAW_FRAMES:
				await RenderingServer.frame_post_draw
			var off := root.get_texture().get_image()
			_ball_root().visible = true
			ball["visible"] = snappedf(ball_seen(img, off, ball["bbox"]), 0.001) if ball["in_frame"] else 0.0
			ball["seen"] = ball["in_frame"] and ball["visible"] >= SEEN_SHARE
		var m := frame_metrics(img)
		var dead := is_dead(m, Subjects.dead_limits(subject))
		recs.append({"id": shot[0], "eye": [v["eye"].x, v["eye"].y, v["eye"].z], "target": [v["target"].x, v["target"].y, v["target"].z], "fov": v["fov"],
			"file": String(shot[0]) + ".png", "sha256": FileAccess.get_sha256(png), "metrics": m, "dead": dead, "ball": ball,
			"wall_ms": Time.get_ticks_msec() - started, "stage_yaw": settled})
		if dead:
			printerr("DEAD frame %s/%s black=%.3f sky=%.3f" % [subject, shot[0], m["black"], m["sky"]])
	var doc := {"tool": "look_harness.gd", "subject": subject, "group": row["group"], "stage": row["stage"], "class": class_index, "kind": row["kind"],
		"owner": row["owner"], "variant": variant, "preset": preset, "tick": tick, "adapter": RenderingServer.get_video_adapter_name(),
		"rendering": RenderingServer.get_current_rendering_method(), "extra": extra, "frames": recs}
	if Subjects.is_strip(strip):
		doc["strip"] = {"frames": strip["frames"], "fps": strip["fps"], "args": strip_args}
	var f := FileAccess.open(dir.path_join("frames.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "\t"))
	f.close()
	paused = was_paused
	print("snap ", subject, " ", recs.size(), " tick ", tick["tick"])



# ---------------------------------------------------------------- frame strips
# The nodes a strip steps, by role; hero and line_view may be absent (a stub in the test).
func _strip_rig() -> Dictionary:
	var player = game.player
	var hero = game.presentation.hero_assets
	return {"player": player, "mesh": player.roll_node().get_parent(), "juice": game.presentation.juice, "hero": hero,
		"line_view": game.presentation.line_view, "pod": hero.shell_of(player).get("pod") if hero != null else null,
		"core": hero.shell_of(player).get("core") if hero != null else null}


# Frame 0: the overrides that are states rather than rates. Returns the anchor it hooked, if any.
static func strip_begin(rig: Dictionary, o: Dictionary, ball_at: Vector3) -> Dictionary:
	var player = rig["player"]
	var resolved := {}
	(rig["mesh"] as Node3D).basis = Basis.IDENTITY
	var dir := Subjects.travel_dir(o)
	player.state.velocity = dir * float(o.get("speed", 0.0))
	var n: Vector3 = (o["contact_normal"] as Vector3).normalized() if o.has("contact_normal") else Vector3.UP
	player.state.contact_normal = n
	player.state.grounded = o.has("contact_normal")
	var juice = rig["juice"]
	juice.squash(0.0, Vector3.UP)
	if o.has("squash_tick"):
		juice.squash(float(o.get("squash", Subjects.MAX_SQUASH)), n)
		juice._process(float(o["squash_tick"]) / Subjects.PHYSICS_HZ)
	if o.has("anchor") or o.has("anchor_rel"):
		var a: Vector3 = o["anchor"] if o.has("anchor") else ball_at + (o["anchor_rel"] as Vector3)
		player.kit.hooked = true
		player.kit.anchor = a
		player.kit.rope = ball_at.distance_to(a)
		resolved["anchor"] = [a.x, a.y, a.z]
	if o.has("pod_yaw"):
		var pod = rig.get("pod")
		resolved["pod_yaw_applied"] = pod != null and is_instance_valid(pod)
		if not resolved["pod_yaw_applied"]:
			printerr("look_harness: --pod-yaw ignored: this subject has no pod (recorded as pod_yaw_applied false)")
	# Frame 0 shows exactly the state its row records: the same presentation pass as a step, for no time.
	_strip_present(rig, o, 0.0)
	return resolved


# The game's own per-frame code for dt, with the pod yaw override set before it (so the gyro and the
# lattice solve against the overridden yaw) and again after it (the pod's own steering turns it).
static func _strip_present(rig: Dictionary, o: Dictionary, dt: float) -> void:
	_strip_pod(rig, o)
	if rig.get("hero") != null:
		rig["hero"]._process(dt)
	rig["juice"]._process(dt)
	_strip_pod(rig, o)
	# The pod's steering lerped the yaw toward the heading before the override put it back, so the
	# gyro and lattice it solved are off by that turn: solve them again at the held yaw.
	var pod = rig.get("pod")
	if o.has("pod_yaw") and rig.get("hero") != null and pod != null and is_instance_valid(pod):
		var gyro := (pod as Node3D).get_node_or_null("Gyro") as Node3D
		var core = rig.get("core")
		if gyro != null and gyro.has_node("GyroInner") and core != null and is_instance_valid(core):
			rig["hero"].counter_tilt(pod, gyro, core)
	if rig.get("line_view") != null and rig["player"].kit.hooked:
		rig["line_view"].step(dt)


# Frame i of a strip: the begin pose for 0, else one step. Returns what the begin resolved.
static func strip_frame(rig: Dictionary, o: Dictionary, i: int, ball_at: Vector3) -> Dictionary:
	if i == 0:
		return strip_begin(rig, o, ball_at)
	strip_step(rig, o, 1.0 / float(o["fps"]))
	return {}


static func _strip_pod(rig: Dictionary, o: Dictionary) -> void:
	var pod = rig.get("pod")
	if o.has("pod_yaw") and pod != null and is_instance_valid(pod):
		(pod as Node3D).rotation.y = deg_to_rad(float(o["pod_yaw"]))


# One frame on: the roll turns by speed * dt / r, then the game's own per-frame code runs for dt
# (the pod's steering and the gyro, the juice springs, the line), then the held pod yaw is set.
static func strip_step(rig: Dictionary, o: Dictionary, dt: float) -> void:
	var mesh: Node3D = rig["mesh"]
	mesh.basis = (Subjects.spin_step(o, dt) * mesh.basis).orthonormalized()
	_strip_present(rig, o, dt)

func _strip_camera(subject: String, shot: Array, v: Dictionary, dir: String, ball: Dictionary) -> Array:
	var cam_dir := dir.path_join(String(shot[0]))
	DirAccess.make_dir_recursive_absolute(cam_dir)
	var rig := _strip_rig()
	var at := Vector3(ball["at"][0], ball["at"][1], ball["at"][2])
	var resolved := {}
	var recs: Array = []
	for i in int(strip["frames"]):
		var started := Time.get_ticks_msec()
		var began := strip_frame(rig, strip, i, at)
		if i == 0:
			resolved = began
			for k in DRAW_FRAMES:
				await RenderingServer.frame_post_draw
		else:
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
		var file := "f%04d.png" % i
		var img := root.get_texture().get_image()
		var png := cam_dir.path_join(file)
		img.save_png(png)
		if i == 0:
			_ball_root().visible = false
			for k in DRAW_FRAMES:
				await RenderingServer.frame_post_draw
			var off := root.get_texture().get_image()
			_ball_root().visible = true
			ball["visible"] = snappedf(ball_seen(img, off, ball["bbox"]), 0.001) if ball["in_frame"] else 0.0
			ball["seen"] = ball["in_frame"] and ball["visible"] >= SEEN_SHARE
			ball["seen_of"] = 0
			for k in 2:
				await RenderingServer.frame_post_draw
		var m := frame_metrics(img)
		var dead := is_dead(m, Subjects.dead_limits(subject))
		var frame := Subjects.frame_row(strip, i)
		frame["resolved"] = resolved
		recs.append({"id": "%s_f%04d" % [shot[0], i], "camera": shot[0], "eye": [v["eye"].x, v["eye"].y, v["eye"].z], "target": [v["target"].x, v["target"].y, v["target"].z],
			"fov": v["fov"], "file": "%s/%s" % [shot[0], file], "sha256": FileAccess.get_sha256(png), "metrics": m, "dead": dead, "ball": ball.duplicate(),
			"wall_ms": Time.get_ticks_msec() - started, "stage_yaw": {}, "frame": frame})
		if dead:
			printerr("DEAD frame %s/%s black=%.3f sky=%.3f" % [subject, recs[-1]["id"], m["black"], m["sky"]])
	var player = rig["player"]
	player.kit.hooked = false
	player.state.velocity = Vector3.ZERO
	player.state.contact_normal = Vector3.UP
	player.state.grounded = false
	return recs


func _run_group(group: String) -> void:
	_anchors = {}
	match group:
		"staged": await _staged()
		"smalls": await _smalls()
		"pickup": await _pickup()
		"dig_fx": await _dig_fx()
		"hd_fx": await _hd_fx()
		"hd_redo": await _hd_redo()
		"arenas": await _arenas()
		"arw2": await _arw2()
		"devices": await _devices()
		"props": await _props()
		"bay": await _bay()
		"cages": await _cages()
		"scrap": await _scrap()
		"workshop": await _workshop()
		"dig_deep": await _dig_deep()
		"title": await _title()
		"title2": await _title2()
		"ending": await _ending()
		"customize": await _customize()
		"cge": await _cge()
		"warden_bodies": await _warden_bodies()
		_:
			printerr("look_harness: unknown group ", group)
			failures += 1
	if group_arg.is_empty():
		failures += _summarize(requested, out, [{"group": group, "rc": failures, "wall_s": 0.0, "subjects": requested}])


# One fresh park per station keeps the tick, seed and spawns independent of selection order.
func _staged() -> void:
	for subject in requested:
		var row: Dictionary = Subjects.SUBJECTS[subject]
		if row.group != "staged":
			continue
		if game != null:
			game.free()
			game = null
			await process_frame
		ticks = 0
		await _boot(false, "park")
		if game.flow.stage() != int(row.stage):
			await _stage(int(row.stage))
		if row.has("mast_angle_deg"):
			_enter_station_bowl()
			await physics_frame
		var timing := await _wait_tick(subject)
		if timing.tick != timing.wanted or game.ctx.stages != Game.TABLES.park or game.flow.stage() != int(row.stage):
			printerr("look_harness: %s needs park stage %s at tick %s (actual stage %s, tick %s)" % [subject, row.stage, timing.wanted, game.flow.stage(), ticks])
			failures += 1
			continue
		var point := _station_point(row, row.point)
		var entry := _station_point(row, row.ball_position)
		var extra := {"table": game.table, "stage": game.flow.stage()}
		if row.has("mast_angle_deg"):
			var pose := _mast_pose(row)
			if pose.is_empty():
				printerr("look_harness: %s requires a physical hit on the %.0f-degree Brindle mast" % [subject, row.mast_angle_deg])
				failures += 1
				continue
			point = pose.target
			entry = pose.entry
			_anchor("mast_eye", pose.eye)
			extra.mast = pose.receipt
		_anchor("station", point)
		var body: RigidBody3D = game.player.body()
		body.freeze = false
		game.player.reset_to(entry, row.ball_velocity)
		var spawned := []
		for spawn in row.spawns:
			var actor: Node3D = game.combat.spawn_enemy(spawn.kind, _station_point(row, spawn.point))
			if actor == null or actor.get("kind") != spawn.kind:
				printerr("look_harness: %s could not stage %s" % [subject, spawn.kind])
				failures += 1
				break
			var at := actor.global_position
			spawned.append({"kind": spawn.kind, "at": [at.x, at.y, at.z]})
		if spawned.size() == row.spawns.size():
			extra.spawns = spawned
			extra.ball_velocity = _coordinates(body.linear_velocity)
			await _shoot(subject, extra)


func _enter_station_bowl() -> void:
	game.flow.enter_boss(Vector3.ZERO)
	game.ctx.boss.set_physics_process(false)


static func _coordinates(point: Vector3) -> Array:
	return [point.x, point.y, point.z]


# Match the numerical grapple station. Floor, ramps and four masts share Bowl's body.
func _mast_pose(row: Dictionary) -> Dictionary:
	if not game.flow.in_arena or game.flow.state != game.flow.BOSS:
		return {}
	var arena: Node3D = game.ctx.boss.get("arena")
	if not is_instance_valid(arena) or arena.name != &"SlagBowl":
		return {}
	var bowl := arena.get_node_or_null("Bowl") as StaticBody3D
	if bowl == null:
		return {}
	var target: Vector3 = arena.global_position + row.bowl_target_local
	var entry: Vector3 = arena.global_position + row.bowl_entry_local
	var eye: Vector3 = entry - row.ball_velocity.normalized() * 6.0 + Vector3.UP * 3.0
	var hit := _ray(eye, target)
	if hit.get("collider") != bowl or target.distance_to(hit.position) > 2.0:
		return {}
	var shape := bowl.shape_owner_get_owner(bowl.shape_find_owner(hit.shape)) as CollisionShape3D
	if shape == null or not shape.shape is CylinderShape3D:
		return {}
	var cylinder := shape.shape as CylinderShape3D
	var axis := arena.to_local(shape.global_position)
	var angle := deg_to_rad(float(row.mast_angle_deg))
	var expected_axis := Vector2(cos(angle), sin(angle)) * 27.0
	if Vector2(axis.x, axis.z).distance_to(expected_axis) > 0.01 or not is_equal_approx(cylinder.radius, 1.0) or not is_equal_approx(cylinder.height, 20.0):
		return {}
	return {"entry": entry, "target": target, "eye": eye, "receipt": {
		"flow_state": "BOSS", "in_arena": game.flow.in_arena, "arena": str(arena.get_path()),
		"arena_origin": _coordinates(arena.global_position), "collider": str(bowl.get_path()),
		"shape_index": hit.shape, "shape_type": cylinder.get_class(), "radius": cylinder.radius,
		"height": cylinder.height, "angle_deg": fposmod(rad_to_deg(atan2(axis.z, axis.x)), 360.0),
		"hit": _coordinates(hit.position), "target": _coordinates(target), "entry": _coordinates(entry),
		"aim_eye": _coordinates(eye)}}


func _station_point(row: Dictionary, point: Vector3) -> Vector3:
	if row.get("terrain_relative", false):
		point.y += _gh(point.x, point.z)
	return point


func _smalls() -> void:
	await _boot_play(1)
	var b: Vector3 = game.player.ball_position()
	game.player.body().freeze = true
	var mb = game.combat.spawn_enemy("miniboss", Vector3(b.x + 22, _gh(b.x + 22, b.z + 10) + 6, b.z + 10))
	var rm = game.combat.spawn_enemy("swarm_remnant", Vector3(b.x + 50, _gh(b.x + 50, b.z + 10) + 3, b.z + 10))
	var vt = game.combat.spawn_enemy("vault", Vector3(b.x + 80, _gh(b.x + 80, b.z + 10) + 4, b.z + 10))
	await _frames(90)
	for e in [mb, rm, vt]:
		if is_instance_valid(e): e.set_physics_process(false)
	_anchor("miniboss", mb.global_position + Vector3(0, 3.0, 0), mb)
	await _shoot("pmb_miniboss_stalk", {"state": "STALK"})
	for st in [["pmb_miniboss_crouch", mb.State.SLAM_CROUCH, 0.5, 10], ["pmb_miniboss_leap", mb.State.SLAM_LEAP, 0.3, 10], ["pmb_miniboss_charge_brace", mb.State.CHARGE_BRACE, 1.0, 10], ["pmb_miniboss_vented", mb.State.WEAK, 1.0, 40]]:
		mb.state = st[1]
		mb._clock = st[2]
		for i in st[3]: mb._pose(0.05)
		await _shoot(st[0], {"state": st[0]})
	var pack: Array = []
	for n in root.find_children("*", "CharacterBody3D", true, false):
		if str(n.get("kind")) == "swarm_remnant":
			pack.append(n)
			n.set_physics_process(false)
	var rc := Vector3.ZERO
	for n in pack: rc += n.global_position
	rc /= maxf(1.0, pack.size())
	var near = pack[0]
	for n in pack:
		if n.global_position.distance_to(rc) < near.global_position.distance_to(rc): near = n
	_anchor("pack", rc, near)
	_anchor("one", near.global_position, near)
	await _shoot("psv_swarm_remnant", {"seam": "lit (default)", "pack": pack.size()})
	for n in pack: n.set_seamless(false)
	await _shoot("psv_swarm_remnant_scattered", {"seam": "set_seamless(false)"})
	_anchor("vault", vt.global_position + Vector3(0, 1.5, 0), vt)
	await _shoot("psv_vault")


func _pickup() -> void:
	await _boot_play(1)
	game.flow.enter_boss(Vector3(18, 0, 0))
	await _frames(60)
	var bs = game.boss
	var at: Vector3 = bs.ship.global_position + Vector3(30, 0, 0)
	var g: float = bs.arena.ground(at)
	for i in 3:
		bs._spawn_pickup(Vector3(at.x + i * 2.5, g + 0.9, at.z), 3 + i * 4, "kill")
	await _frames(20)
	game.player.body().freeze = true
	_anchor("pickup", Vector3(at.x + 2.5, g + 0.9, at.z))
	await _shoot("psv_brindle_pickup", {"values": [3, 7, 11]})


func _dig_fx() -> void:
	await _boot_play(3)
	var terrain = game.ctx.terrain
	var stage_root: Node3D = terrain.geometry_root(3)
	var fx = stage_root.get_node("DigScenery/DigFx")
	var face: Vector3 = fx.to_global(fx.faces[0])
	game.player.reset_to(face + Vector3(3, 2, 0))
	game.player.body().freeze = true
	await _frames(80)
	fx.freeze_rupture(0.18)
	_anchor("face", face)
	await _shoot("fxd_grit_lamps", {"face": [face.x, face.y, face.z]})
	fx.clear()
	game.player.reset_to(Vector3(0, 40, 0))
	game.player.body().freeze = true
	var plate: Dictionary = terrain.map().breach_plates[0]
	var centre: Vector2 = plate["rect"].get_center()
	var cover: Node3D = stage_root.get_node("BreachPlate_" + String(plate["id"]))
	var at := Vector3(centre.x, cover.get_meta("home").y, centre.y)
	game.world._on_slammed(at, 20, 1)
	await _frames(11)
	fx.freeze_rupture(0.18)
	_anchor("plate", at)
	await _shoot("fxd_rupture_mid", {"plate": plate["id"], "ruptures": fx.ruptures.size(), "bursts": fx.bursts.size()})
	var other: Dictionary = terrain.map().breach_plates[1]
	var oc: Vector2 = other["rect"].get_center()
	var ocover: Node3D = stage_root.get_node("BreachPlate_" + String(other["id"]))
	_anchor("other_plate", Vector3(oc.x, ocover.get_meta("home").y, oc.y))
	await _shoot("fxd_unbroken_plate", {"plate": other["id"]})


func _hd_fx() -> void:
	await _boot_play(5)
	var sc: Node3D = game.ctx.terrain.geometry_root(5).get_node("HighdraftScenery")
	var fx = sc.get_node("WindEffects")
	var presence = sc.get_node("Presence")
	var column: Dictionary = fx.thermals[0]
	var b0: Vector3 = column.presence.base
	game.player.reset_to(b0 + Vector3.UP * 14.0)
	game.player.body().freeze = true
	for i in 70:
		presence._process(1.0 / 60.0)
		await physics_frame
	fx.frozen = true
	_anchor("thermal_0", b0)
	await _shoot("fxh_thermal_occupied", {"occupied": column.occupied})
	fx.frozen = false
	game.player.reset_to(b0 + Vector3(26, 14, 0))
	game.player.body().freeze = true
	for i in 4:
		presence._process(1.0 / 60.0)
		await physics_frame
	await _frames(40)
	fx.frozen = true
	_anchor("thermal_1", fx.thermals[1].presence.base)
	await _shoot("fxh_thermal_idle", {"column": 1})
	fx.frozen = false
	var contact := b0 + Vector3(0, 1, 0)
	fx.catch_at(contact)
	fx.step(0.1, contact)
	fx.frozen = true
	_anchor("contact", contact)
	await _shoot("fxh_net_sag", {"catches": fx.active_catches.size()})
	fx.frozen = false
	fx.step(25.0, Vector3.INF)
	fx.frozen = true
	await _shoot("fxh_clouds_sails", {"cloud_step_s": 25.0})


func _hd_redo() -> void:
	await _boot_play(5)
	var sc: Node3D = game.ctx.terrain.geometry_root(5).get_node("HighdraftScenery")
	await _shoot("hdr_island_bridge")
	var ac: Vector3 = sc.get_node("AnchorEye_0").global_position
	var am: Vector3 = sc.get_node("AnchorMast_0").global_position
	_anchor("anchor_0", ac)
	_anchor("mast_0", am)
	_anchor("mast_mid", (am + ac) * 0.5)
	_anchor("anchor_1", sc.get_node("AnchorEye_1").global_position)
	_anchor("anchor_2", sc.get_node("AnchorEye_2").global_position)
	await _shoot("hdr_anchors")
	var props: Node3D = sc.get_node("Props")
	for pname in ["prop_crate", "prop_spool", "prop_lamp_body", "prop_bearing", "prop_clamp", "prop_pot"]:
		var mm := props.get_node_or_null(pname) as MultiMeshInstance3D
		if mm != null and mm.multimesh.instance_count > 0:
			_anchor(pname, (mm.global_transform * mm.multimesh.get_instance_transform(0)).origin)
	await _shoot("hdr_props")
	_anchor("sail_spawn", sc.get_node("Sail_spawn").global_position)
	_anchor("sail_vault", sc.get_node("Sail_vault").global_position)
	await _shoot("hdr_sails")
	for t in ["a", "b", "c"]:
		_anchor("vent_" + t, (sc.get_node("Vent_thermal_" + t) as Node3D).global_position)
	await _shoot("hdr_thermals")
	await _shoot("hdr_net")
	await _shoot("hdr_sky")
	_anchor("barge_0", game.world.contraptions[5].barges[0]["body"].global_position)
	await _shoot("swp_barge")


func _enter_boss_of(world: int) -> void:
	game.flow.enter_stage(game.ctx.stages.last_of(world), Vector3.ZERO, false)
	await _frames(20)
	game.flow.enter_boss(Vector3.ZERO)
	await _frames(90)


func _arenas() -> void:
	await _boot(false)
	await _frames(20)
	game.flow.enter_boss(Vector3(18, 0, 0))
	await _frames(60)
	game.player.body().freeze = true
	_anchor("arena", game.boss.arena.global_position)
	await _shoot("arb_bowl")
	await _shoot("swp_kicker_wedge")
	if not (_wants("arw_pit") or _wants("arm_crown")):
		return
	await _enter_boss_of(2)
	game.player.body().freeze = true
	_anchor("pit", game.flow._boss_module()._center)
	await _shoot("arw_pit")
	await _enter_boss_of(3)
	game.player.body().freeze = true
	_anchor("pad", game.flow._boss_module().pad.global_position + Vector3(0, 1, 0))
	await _shoot("arm_crown")


func _arw2() -> void:
	await _boot(true)
	await _frames(20)
	await _enter_boss_of(2)
	var m = game.flow._boss_module()
	game.player.body().freeze = true
	var b: Vector3 = game.player.ball_position()
	_anchor("pit", m._center)
	_anchor("warden", m.warden.global_position)
	_anchor("ball", b)
	await _shoot("arw_pit_b", {"warden": [m.warden.global_position.x, m.warden.global_position.y, m.warden.global_position.z]})


# KF8a: one park Warden per kind (spec "harpoon_anchor": true), dressed in its recipe body by
# hero_assets.gd, 60 m apart and out of the ball's reach so no pulse runs; each shoots alone.
# The mind hangs from the island: lifted 14 m so the hand and its lens clear the ground.
func _warden_bodies() -> void:
	await _boot_play(1)
	var b: Vector3 = game.player.ball_position()
	game.player.body().freeze = true
	var rows := [["warden_body_reactor", "reactor", 1, "dam_face", 0.0], ["warden_body_swarm", "swarm", 3, "headframe", 0.0],
		["warden_body_mind", "mind", 5, "under_island", 14.0]]
	var made: Array = []
	for i in rows.size():
		var r: Array = rows[i]
		var warden = preload("res://src/combat/warden.gd").new()
		game.ctx.root.add_child(warden)
		warden.global_position = Vector3(b.x + 50.0 + 60.0 * i, 0.0, b.z + 40.0)
		var spec: Dictionary = game.ctx.spawner.fleet.dress("warden", {"family": r[1], "stage": r[2], "plating": 90.0, "hp": 650.0, "reach": 30.0})
		spec.merge({"harpoon_anchor": true, "family": r[1], "mounting": r[3], "variant": ""}, true)
		warden.setup(game.player, game.ctx.terrain, game.ctx.root, Callable(game.flow, "in_play"), 1.0, spec)
		warden.global_position.y += r[4]
		warden.home = warden.global_position
		made.append(warden)
	await _frames(30)
	for w in made:
		w.set_physics_process(false)
	for i in rows.size():
		for j in made.size():
			made[j].visible = j == i
		var w: Node3D = made[i]
		# 2026-10-11 (w13 KF7c round 4): the body keeps the yaw it settled to turning to the ball at its
		# default spot (the game frame); _shoot measures it per camera against WARDEN_BODY_STAGE_YAW.
		_yaw_probe = {rows[i][0]: [w, rows[i][1]]} if Subjects.WARDEN_BODY_STAGE_YAW.has(rows[i][0]) else {}
		if _yaw_probe.size() > 0:
			await _settle_yaw(w, rows[i][1], b)
		var centre: Vector3 = w.global_position + (Vector3.DOWN * 4.0 if rows[i][1] == "mind" else Vector3.ZERO)
		_anchor("warden", centre, w)
		var bx := subject_bounds(game.presentation.hero_assets.warden_of(w).get("body", w))
		_anchor("warden_bounds", bx.get_center(), null, bx.size.length() * 0.5)
		var dressed: bool = not game.presentation.hero_assets.warden_of(w).get("body", null) == null
		if not dressed:
			printerr("look_harness: %s is not dressed in its body (clamp kit shown)" % rows[i][0])
			failures += 1
		await _shoot(rows[i][0], {"family": rows[i][1], "mounting": rows[i][3], "body": dressed})
		_yaw_probe = {}


# 2026-10-11 (w13 KF7c round 4): put the ball back at its default spot b (the previous subject's last
# camera leaves it elsewhere, and the bodies turn to it while the tree runs between subjects, which
# made the yaw depend on the run's subject order) and wait until the body's yaw holds still for 10
# physics frames: the reactor's jaws turn at a rate (warden_look _turn_jaws) and converge slowly,
# the mind turns at once. The settled yaw is the one WARDEN_BODY_STAGE_YAW records.
func _settle_yaw(w: Node3D, kind: String, b: Vector3) -> void:
	var pbody: RigidBody3D = game.player.body()
	pbody.freeze = true
	pbody.global_position = b
	_ball_root().global_position = b
	var prev := INF
	var still := 0
	for k in 1500:
		await physics_frame
		var y := _body_yaw(w, kind)
		still = still + 1 if absf(angle_difference(deg_to_rad(y), deg_to_rad(prev))) < deg_to_rad(0.002) else 0
		prev = y
		if still >= 10:
			break


# 2026-10-11 (w13 KF7c round 4): the game frame. The reactor and the mind turn to the ball at runtime
# (hero_assets _update_warden_body: the reactor's +X; _hold_mind: the Pose's -Z) and the read cameras
# stage the ball as the player's camera does (default spot, WARDEN_BODY_BALL rows), so the body's yaw
# is whatever that staging settles it to. WARDEN_BODY_STAGE_YAW holds the measured value per camera;
# the recipes' silhouette checks turn each read direction by it. A camera whose settled yaw is more
# than 0.5 degree off its constant (or missing) fails the run: the check would score another frame.
func _check_stage_yaw(subject: String, shot: String) -> Dictionary:
	if not _yaw_probe.has(subject):
		return {}
	var w: Node3D = _yaw_probe[subject][0]
	var got := _body_yaw(w, String(_yaw_probe[subject][1]))
	var table: Dictionary = Subjects.WARDEN_BODY_STAGE_YAW[subject]
	var want := float(table.get(shot, INF))
	var off := rad_to_deg(absf(angle_difference(deg_to_rad(got), deg_to_rad(want)))) if table.has(shot) else INF
	print("look_harness: %s %s stage_yaw=%.3f want=%s off=%s (look_subjects.gd WARDEN_BODY_STAGE_YAW)" % [subject, shot, got, str(want), str(off)])
	if not off <= 0.5:
		printerr("look_harness: %s %s settled at yaw %.3f, constant %s: the silhouette check scores another frame" % [subject, shot, got, str(want)])
		failures += 1
	return {"stage_yaw": snappedf(got, 0.001), "stage_yaw_want": want}


# The yaw (degrees) of the node that carries the body recipe's frame: its -Z's heading in world.
func _body_yaw(w: Node3D, kind: String) -> float:
	var rec: Dictionary = game.presentation.hero_assets.warden_of(w)
	var node = rec.get("body", null)
	if kind == "mind" and node != null:
		node = (node as Node3D).find_child("Pose", true, false)
	if node == null:
		return INF
	var f: Vector3 = (node as Node3D).global_basis * Vector3(0, 0, -1)
	return rad_to_deg(atan2(-f.x, -f.z))


func _spawn_devices(b: Vector3) -> Dictionary:
	var made := {}
	var i := 0
	for row in [["cache", preload("res://src/world/cracked_cache.gd")], ["bet", preload("res://src/world/bet_crate.gd")], ["altar", preload("res://src/world/ambush_altar.gd")]]:
		var d = row[1].new()
		game.add_child(d)
		var x: float = b.x - 14 + i * 14
		var z: float = b.z + 26
		d.global_position = Vector3(x, _gh(x, z), z)
		d.setup(game.ctx, game.world.interact, {"id": "w7_" + row[0]})
		made[row[0]] = d
		i += 1
	return made


func _devices() -> void:
	await _boot_play(2)
	game.player.body().freeze = true
	var made := _spawn_devices(game.player.ball_position())
	await _frames(30)
	for k in made:
		_anchor(k, (made[k] as Node3D).global_position + Vector3(0, 1.4, 0))
		await _shoot("gpd_" + k, {"stage": 2})
	var cache = made["cache"]
	cache.fire()
	await _frames(60)
	_anchor("cache", (cache as Node3D).global_position + Vector3(0, 1.4, 0))
	await _shoot("gpd_cache_fired", {"state": "fire() called"})


func _props() -> void:
	await _boot_play(1)
	game.player.body().freeze = true
	var walls := []
	for body in game.ctx.terrain.geometry_root(1).find_children("*", "StaticBody3D", true, false):
		for m in body.get_children():
			if m is MeshInstance3D and m.mesh is BoxMesh and absf(m.mesh.size.z - 1.6) < 0.01 and m.mesh.size.y >= 4.0:
				walls.append(body)
	if walls.is_empty():
		printerr("look_harness: no Spillway relay wall")
		failures += 1
	else:
		var w: Node3D = walls[0]
		_anchor("wall", w.global_position + Vector3(0, 3, 0), w)
		await _shoot("gpw_pylon_spillway", {"walls": walls.size()})
	if not (_wants("gpw_pylon_reach_w") or _wants("gpw_pylon_reach_e")):
		return
	await _stage(2)
	for wp in [Vector3(-64, 0, -105), Vector3(52, 0, 80)]:
		var tag := "w" if wp.x < 0 else "e"
		_anchor("reach_" + tag, Vector3(wp.x, _gh(wp.x, wp.z) + 4, wp.z))
		await _shoot("gpw_pylon_reach_" + tag, {"at": [wp.x, wp.z]})


func _bay() -> void:
	await _boot_play(1)
	for n in ["cv2_camp_bay_stage2", "cv2_camp_bay", "swp_bay"]:
		if not _wants(n):
			continue
		var st := int(Subjects.SUBJECTS[n]["stage"])
		await _stage(st)
		var offers: Array = []
		for slot in game.ctx.terrain.map().gate_slots:
			var sa: Vector2 = slot["at"]
			offers.append({"at": Vector3(sa.x, _gh(sa.x, sa.y), sa.y), "facing": slot["facing"], "width": 8.0})
		var docked: bool = game.world.bay.dock(offers, Callable(game.ctx.terrain, "height"), null)
		await _frames(40)
		var box := subject_bounds(game.world.bay)
		print("bay stage ", st, " offers ", offers.size(), " docked ", docked, " aabb ", box)
		if not docked or box.size == Vector3.ZERO:
			printerr("look_harness: the bay did not dock on stage %d" % st)
			failures += 1
			continue
		_anchor("bay", box.get_center(), null, maxf(box.size.x, box.size.z) * 0.8 + 6.0)
		_anchor("bay_jukebox", game.world.bay._barge.to_global(Vector3(game.world.bay.JUKEBOX.x, 1.3, game.world.bay.JUKEBOX.y + 1.6)), game.world.bay._barge)
		await _shoot(n, {"docked": docked, "offers": offers.size(), "aabb": [box.position.x, box.position.y, box.position.z, box.size.x, box.size.y, box.size.z]})


func _cages() -> void:
	await _boot_play(1)
	game.player.body().freeze = true
	var cage = game.find_child("RescueSites", true, false).cages[0]
	_anchor("cage", cage.global_position + Vector3(0, 1.6, 0), cage)
	await _frames(20)
	await _shoot("cag_rivet_locked", {"state": "locked"})
	cage.fire()
	cage.tick(1.0)
	game.player.body().freeze = true
	await _frames(45)
	await _shoot("cag_rivet_freeing", {"state": "freeing"})
	cage.tick(1.5)
	await _frames(45)
	await _shoot("cag_rivet_freed", {"state": "freed"})
	_anchor("fab", game.build.fabricators.records()[0]["node"].global_position, game.build.fabricators.records()[0]["node"])
	await _shoot("swp_fabricator_hoop")
	if not (_wants("cag_dig_locked") or _wants("cag_dig_freeing")):
		return
	await _stage(3)
	cage = game.find_child("RescueSites", true, false).cages[0]
	_anchor("cage", cage.global_position + Vector3(0, 1.6, 0), cage)
	await _shoot("cag_dig_locked", {"state": "locked", "quest": cage.quest})
	cage.fire()
	cage.tick(1.0)
	await _frames(45)
	await _shoot("cag_dig_freeing", {"state": "freeing"})


func _scrap() -> void:
	await _boot_play(1)
	game.player.body().freeze = true
	var items: Array = game.find_child("Scrap", true, false).get_children().filter(func(n): return n is MeshInstance3D and n.visible)
	var a: Node3D = items[0]
	_anchor("scrap_a", a.global_position)
	await _shoot("scr_spillway_a", {"item": str(a.name), "variant": a.get_meta("scrap_variant", "")})
	for it in items:
		var k := "v_" + str(it.get_meta("scrap_variant", "?"))
		if not _anchors.has(k):
			_anchor(k, (it as Node3D).global_position)
	await _shoot("scr_variants")
	if not _wants("scr_dig"):
		return
	await _stage(3)
	items = game.find_child("Scrap", true, false).get_children().filter(func(n): return n is MeshInstance3D and n.visible)
	_anchor("scrap_dig", (items[0] as Node3D).global_position)
	await _shoot("scr_dig", {"scrap_count": items.size()})


func _workshop() -> void:
	await _boot_play(1)
	game.player.body().freeze = true
	_anchor("ball", game.player.ball_position())
	var caches: Array = []
	for n in game.find_children("*", "Node3D", true, false):
		if n.get_script() == preload("res://src/world/cracked_cache.gd"):
			var shell: Node = n.find_child("CacheShell", false, false)
			caches.append({"path": str(n.get_path()), "at": [n.global_position.x, n.global_position.y, n.global_position.z],
				"shell_overlay": shell != null and (shell as GeometryInstance3D).material_overlay != null})
	await _shoot("wog_spillway", {"cracked_caches": caches})
	await _shoot("swp_cottonwood")
	if not (_wants("wog_reach") or _wants("cache_activity") or _wants("swp_valve_wheel")):
		return
	await _stage(2)
	_anchor("ball", game.player.ball_position())
	var tw: Vector3 = game.ctx.terrain.map_for(2).TOWER
	_anchor("tower", Vector3(tw.x, _gh(tw.x, tw.z), tw.z))
	await _shoot("wog_reach")
	await _shoot("swp_valve_wheel")
	var cache = game.find_child("Activity_cracked_cache", true, false)
	if cache == null:
		printerr("look_harness: no Activity_cracked_cache")
		failures += 1
		return
	_anchor("cache", (cache as Node3D).global_position + Vector3(0, 1.5, 0))
	await _shoot("cache_activity")


func _dig_deep() -> void:
	await _boot_play(4)
	_anchor("spawn", game.ctx.terrain.spawn_point(4))
	await _shoot("dig_deep_floor")


func _title() -> void:
	seed(SEED)
	game = Game.new()
	game.name = "Game"
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	await process_frame
	await physics_frame
	await _shoot("ttl_title", {"state": "title"})
	await _shoot("ttl_title_b", {"state": "title, +2.5 s of camera drift"})
	game.flow.press_start()
	await _shoot("ttl_class_select", {"state": game.flow.state_name()})


func _title2() -> void:
	seed(SEED)
	game = Game.new()
	game.name = "Game"
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	await process_frame
	await physics_frame
	await _frames(30)
	var d = game.presentation.get_node("TitleStage")
	for n in root.find_children("*", "CanvasLayer", true, false):
		if n != d._layer: n.visible = false
	await _shoot("ttl_stage_only", {"note": "menu layers hidden, title stage picture only"})
	d.set_process(false)
	for nm in ["SableShell", "RivetShell", "KestShell", "SPIL9", "Ball"]:
		var subject: String = "ttl_stage_" + String(nm).to_lower()
		var h: Node3D = d.stage.get_node_or_null(nm)
		if h == null or not _wants(subject):
			continue
		var shot: Array = Subjects.SUBJECTS[subject]["cameras"][0]
		var c: Vector3 = h.global_position + Vector3(0, 0.6, 0)
		d.camera.position = c + shot[1]
		d.camera.look_at(c + shot[2])
		await _frames(3)
		await _shoot(subject, {"node": nm, "camera_at": [d.camera.position.x, d.camera.position.y, d.camera.position.z]})


func _ending() -> void:
	const StageDefs := preload("res://src/core/stage_defs.gd")
	seed(SEED)
	game = Game.new()
	game.test_mode = true
	game.table = "default"
	var folder := "user://ending-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(folder)
	game.run_store_path = folder.path_join("run.json")
	root.add_child(game)
	await _frames(5)
	game.bot_driven = false
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(1)
	await _frames(3)
	for world in StageDefs.worlds():
		game.flow.enter_stage(StageDefs.first_of(world), Vector3.ZERO, false)
	game.flow.enter_stage(StageDefs.COUNT, Vector3.ZERO, false)
	await _frames(3)
	game.flow._set_state(game.flow.BOSS)
	game.events.boss_defeated.emit()
	game.flow.physics_step(game.flow.VICTORY_SECONDS + 0.01)
	var seq = game.screens.ending_sequence
	if not (is_instance_valid(seq) and seq.active):
		printerr("look_harness: ending did not start")
		failures += 1
		return
	seq.set_process(false)
	var order: Array = Subjects.in_group("ending")
	order.sort_custom(func(a, b): return Subjects.SUBJECTS[a]["elapsed"] < Subjects.SUBJECTS[b]["elapsed"])
	for n in order:
		seq.advance(float(Subjects.SUBJECTS[n]["elapsed"]) - seq.elapsed)
		await RenderingServer.frame_post_draw
		await _shoot(n, {"elapsed": seq.elapsed, "phase": seq.phase, "world": seq.world_index})
	seq.skip()


func _customize() -> void:
	const Push := preload("res://tests/workshop/push.gd")
	seed(SEED)
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await process_frame
	await _frames(5)
	game.ctx.calm = true
	var profile = game.ctx.profile
	profile.unlock_cosmetic("trail_plum_curl")
	profile.unlock_cosmetic("companion_paint_forge")
	profile.unlock_cosmetic("decal_fern")
	game._screen_key(KEY_K)
	await _frames(3)
	var page = game.screens.camp_page().get_node("CustomizePage")
	Push.key(root, KEY_C)
	await _frames(5)
	await _shoot("cus_page_default", {"equipped": "nothing yet"})
	page.focus("trail")
	page.press("trail")
	page.focus("companion_paint")
	page.press("companion_paint")
	await _frames(5)
	await _shoot("cus_page_equipped", {"trail": profile.equipped(page.pilot, "trail")})
	page.focus("decal")
	page.press("decal")
	await _frames(5)
	await _shoot("cus_page_decal", {"decal": profile.equipped(page.pilot, "decal")})


# ---------------------------------------------------------------- Hoberman mecha per pilot (PD-0)
# Each pilot boots once (its row's "pilot" is the class index), the ball stands frozen on the
# floor under where it spawned, and each row shows its heft class's layers. Heft rows also carry
# that class's chunk load; rule rows ("chunks": false) carry none, as ROSTER-LOOK section 3 rules
# 1 to 3 measure. Every row is posed chase from behind: the Pod faces -Z, away from the cge eyes,
# its WeaponRing aims straight ahead and the gimbal follows the Core against the posed Pod.
const CGE_MASS := {1: 0.0, 3: 60.0, 5: 400.0}


func _cge() -> void:
	for pilot in 6:
		var mine: Array = Subjects.in_group("cge").filter(func(n): return int(Subjects.SUBJECTS[n]["pilot"]) == pilot and _wants(n))
		if mine.is_empty():
			continue
		mine.sort_custom(func(a, b): return int(Subjects.SUBJECTS[a]["heft"]) < int(Subjects.SUBJECTS[b]["heft"]))
		if game != null:
			game.free()
			game = null
			await process_frame
		class_index = pilot
		await _boot_play(1)
		var body: RigidBody3D = game.player.body()
		body.freeze = true
		# The spawn leaves the ball in the air; the anchor is the floor under it, so the camera
		# target and the pinned ball agree and the far eye keeps the whole ball in frame.
		var at: Vector3 = game.player.ball_position()
		var floor_hit := _ray(at + Vector3.UP * 2.0, at + Vector3.DOWN * 80.0)
		if not floor_hit.is_empty():
			at = floor_hit["position"] + Vector3.UP * Tuning.RADIUS
		body.global_position = at
		_ball_root().global_position = at
		var hero = game.presentation.hero_assets
		for n in mine:
			var heft := int(Subjects.SUBJECTS[n]["heft"])
			var chunks: bool = Subjects.SUBJECTS[n].get("chunks", true)
			game.build.accretion.show_build(CGE_MASS[heft] if chunks else 0.0, [], [], heft)
			hero.set_heft_class(hero.shell_of(game.player).get("shell", {}), heft, false)
			paused = false
			await _frames(5)
			await _wait_tick(n)
			paused = true
			_pose_chase(hero)
			_anchor("ball", at)
			await _shoot(n, {"pilot": pilot, "heft": heft, "chunks": chunks, "pose": "chase", "shell": hero.shell_of(game.player).get("class", "")})
		paused = false


func _pose_chase(hero) -> void:
	var rec: Dictionary = hero.shell_of(game.player)
	var pod = rec.get("pod")
	var core = rec.get("core")
	if pod == null or not is_instance_valid(pod):
		return
	(pod as Node3D).global_rotation = Vector3.ZERO
	var ring := (pod as Node3D).get_node_or_null("WeaponRing") as Node3D
	if ring != null:
		ring.rotation = Vector3.ZERO
	var gyro := (pod as Node3D).get_node_or_null("Gyro") as Node3D
	if gyro != null and gyro.has_node("GyroInner") and core != null and is_instance_valid(core):
		hero.counter_tilt(pod, gyro, core)


# ---------------------------------------------------------------- boss smoke
func _boss_smoke(id: String) -> int:
	if not BOSSES.has(id):
		printerr("look_harness: unknown boss ", id)
		return 2
	await _boot(false)
	await _frames(20)
	var world: int = BOSSES[id]
	var stage: int = game.ctx.stages.last_of(world)
	if game.ctx.stages.world_of(game.ctx.run.stage) != world or game.ctx.run.stage != stage:
		game.flow.enter_stage(stage, Vector3.ZERO, false)
		await _frames(20)
	game.flow.enter_boss(Vector3.ZERO)
	var start := ticks
	await _frames(BOSS_TICKS)
	var in_arena: bool = game.flow.in_arena
	print("BOSS_SMOKE boss=%s stage=%d ticks=%d in_arena=%s rendering=%s driver=%s device=%s %s" % [id, stage, ticks - start, in_arena,
		RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name(), "PASS" if in_arena else "FAIL"])
	return 0 if in_arena else 1
