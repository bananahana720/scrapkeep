extends "res://tools/bot_run.gd"
# Scratch (untracked, never committed): PR #729 goal plate film on the PC. A bot run (park table)
# plays; this records a JPG frame every 3rd tick (30 fps of game time at --fixed-fps 90) while
# something the PR changed is on screen, with one TSV row of ground truth per saved frame.
#   -- --shots=<abs dir> [--hold-hp=1] [bot_run flags]
# Reads only, except --hold-hp=1 which keeps the ball's hull full so the bot reaches every fight.

const EdgeMarkersS := preload("res://src/ui/edge_markers.gd")
const ObjectiveViewS := preload("res://src/ui/objective_view.gd")

var _sg: Dictionary = {}
var _dir := ""
var _rows: FileAccess
var _tick := 0
var _saved := 0
var _post := 0
var _hold := false
var _said_size := false
var _phase := 0
var _img_size := Vector2.ZERO


func _initialize() -> void:
	_sg = _parse(OS.get_cmdline_user_args())
	_dir = String(_sg.get("shots", ""))
	_hold = String(_sg.get("hold-hp", "0")) == "1"
	if DisplayServer.get_name() == "headless" or _dir == "":
		printerr("d729: needs a rendered display and --shots=<abs dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_dir.path_join("frames"))
	_rows = FileAccess.open(_dir.path_join("trace.tsv"), FileAccess.WRITE)
	_rows.store_line("frame\ttick\tstage\tstage_t\tflow\tgoal_id\tplate_words\tdone\tdone_left\tplate_rect\ttick_rect\tmarks\ttargets\tsite\tphase\twhy")
	super._initialize()


func _physics_process(delta: float) -> bool:
	var over: bool = super._physics_process(delta)
	_tick += 1
	if _game == null or _game.flow == null or _game.hud == null:
		return over
	if not _said_size:
		_said_size = true
		print("d729: window=", DisplayServer.window_get_size(), " visible_rect=", root.get_visible_rect(),
			" texture=", root.get_texture().get_size(), " stretch_aspect=", root.content_scale_aspect, " content_size=", root.content_scale_size)
		_game.events.boss_phase_changed.connect(func(p: int, n: String):
			_phase = p
			print("d729: boss phase ", p, " ", n, " at tick ", _tick))
	if _hold and _game.run != null:
		_game.run.hp = _game.run.max_hp
	if over:
		_rows.flush()
		print("d729: saved ", _saved, " frames")
		return over
	if _tick % 3 != 0:
		return over
	var why := _why()
	if why != "":
		_post = 60
	elif _post > 0:
		_post -= 1
		why = "post"
	if why == "":
		return over
	_save(why)
	return over


func _why() -> String:
	var hud = _game.hud
	if not _game.flow.in_play() and _game.flow.state_name() != "boss":
		return ""
	if hud._done.showing():
		return "done"
	var goal: String = hud.objective_reading()["id"]
	if goal in ["break_yard_crew", "break_clamp_crews", "ride_sheet", "line_fight", "smash_core", "break_guard", "break_warden",
			"shoot_magnets", "slam_caps", "bait_charge", "ram_scooter", "break_brindle", "find_activity"]:
		return "row:" + goal
	if _game.flow.state_name() == "boss":
		return "boss"
	for m in hud.edge_markers._shown:
		if m.has("box"):
			return "mark"
	var near := _near_site()
	if not near.is_empty() and float(near["m"]) < 110.0:
		return "site"
	return ""


func _near_site() -> Dictionary:
	var acts = _game.world.activities if _game.world != null else null
	if acts == null:
		return {}
	var ball: Vector3 = _game.player.shown_position()
	var best := {}
	for s in acts.sites:
		if not is_instance_valid(s):
			continue
		var m := Vector2(s.global_position.x - ball.x, s.global_position.z - ball.z).length()
		if best.is_empty() or m < float(best["m"]):
			best = {"id": String(s.id), "m": m, "started": s.started, "done": s.done, "failed": s.failed}
	return best


func _screen_rect(c: Control, local: Rect2) -> Rect2:
	var t: Transform2D = c.get_screen_transform()
	var laid: Vector2 = _game.hud._laid_out
	var k: Vector2 = _img_size / laid
	var a: Vector2 = t * local.position * k
	var b: Vector2 = t * local.end * k
	return Rect2(a, b - a).abs()


static func _r(r: Rect2) -> String:
	return "%d,%d,%d,%d" % [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)]


func _save(why: String) -> void:
	var hud = _game.hud
	var img := root.get_texture().get_image()
	if _img_size != Vector2(img.get_size()):
		print("d729: image size ", img.get_size(), " texture ", root.get_texture().get_size(), " window ", DisplayServer.window_get_size(), " visible_rect ", root.get_visible_rect(), " laid ", hud._laid_out, " at tick ", _tick)
	_img_size = Vector2(img.get_size())
	var name := "f%06d.jpg" % _saved
	img.save_jpg(_dir.path_join("frames").path_join(name), 0.92)
	var shown: Dictionary = hud.plate_shown()
	var goal: Dictionary = hud.objective_reading()
	var ov: Control = hud._objective
	var plate := _screen_rect(ov, Rect2(Vector2.ZERO, ov.size))
	var icon_x: float = (ov.size.x - ov._row_width()) * 0.5
	var tick := _screen_rect(ov, Rect2(Vector2(icon_x, 0.0), Vector2(ObjectiveViewS.ICON, ObjectiveViewS.ICON)))
	var em: Control = hud.edge_markers
	var marks := PackedStringArray()
	for m in em._shown:
		if not m.has("box"):
			continue
		var box: Rect2 = m["box"]
		var tr := EdgeMarkersS.tag_rect(box, String(m["tag"]), bool(m.get("under", false))) if String(m["tag"]) != "" else Rect2()
		marks.append("%s|box=%s|tag=%s|under=%s" % [String(m["tag"]) if String(m["tag"]) != "" else "-", _r(_screen_rect(em, box)), _r(_screen_rect(em, tr)) if String(m["tag"]) != "" else "-", str(m.get("under", false))])
	var targets := PackedStringArray()
	var cam: Camera3D = _game.camera.cam
	var list: Array = []
	var warden = _game.flow.warden if is_instance_valid(_game.flow.warden) else null
	var driver = warden.get("mount_driver") if warden != null else null
	if driver != null and driver.has_method("plate_targets"):
		list.append_array(driver.plate_targets(warden))
	var boss = _game.ctx.boss
	if is_instance_valid(boss) and boss.has_method("plate_targets"):
		list.append_array(boss.plate_targets())
	var k: Vector2 = _img_size / Vector2(root.get_visible_rect().size)
	for t in list:
		var at: Vector3 = t["at"]
		var p := "behind" if cam.is_position_behind(at) else "%d,%d" % [roundi(cam.unproject_position(at).x * k.x), roundi(cam.unproject_position(at).y * k.y)]
		targets.append("%s@%s" % [String(t["what"]), p])
	var near := _near_site()
	var site := "-" if near.is_empty() else "%s:%dm:started=%s:done=%s:failed=%s" % [near["id"], int(near["m"]), str(near["started"]), str(near["done"]), str(near["failed"])]
	_rows.store_line("%s\t%d\t%d\t%.2f\t%s\t%s\t%s\t%s\t%.2f\t%s\t%s\t%s\t%s\t%s\t%d\t%s" % [name, _tick, _game.run.stage, _game.run.stage_time, _game.flow.state_name(),
		String(goal["id"]), String(shown["words"]), String(shown.get("done", "")), hud._done._left, _r(plate), _r(tick),
		";".join(marks), ";".join(targets), site, _phase, why])
	_saved += 1
	if _saved % 300 == 0:
		_rows.flush()
		print("d729: saved ", _saved, " tick ", _tick, " stage ", _game.run.stage, " ", _game.flow.state_name(), " ", String(goal["id"]))
