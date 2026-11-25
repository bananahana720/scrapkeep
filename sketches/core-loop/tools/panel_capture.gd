extends SceneTree

const Panels := preload("res://src/build/panels.gd")
const PanelShell := preload("res://src/build/panel_shell.gd")
const Palette := preload("res://src/core/palette.gd")


const SIZE := Vector2i(1280, 720)
const SETTLE_FRAMES := 40
const PLAY_ARM := 9.0
const PLAY_PITCH := -0.30
const PLAY_FOV := 70.0
const MIXED := ["vent_louvre", "hull_tile", "winch_drum", "splash_skirt", "ram_bumper"]
const READ_BUDGET := 0.08
const MIN_SHARE := 0.03
const ROLLS := [Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0), Vector3(0.0, PI * 0.66, 0.0), Vector3(1.1, 2.3, 0.4)]
const SEED := 7

var _out := ""
var _view: SubViewport
var _cam: Camera3D
var _shell
var _shots: Array = []
var _index := 0
var _wait := 0
var _report := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	if _out == "":
		push_error("panel_capture: --out=<dir> is required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_view = SubViewport.new()
	_view.size = SIZE
	_view.msaa_3d = Viewport.MSAA_2X
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view.own_world_3d = true
	root.add_child(_view)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("8fa3ad")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	_view.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0.0)
	sun.shadow_enabled = true
	_view.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	ground.mesh = plane
	ground.position.y = -1.0
	ground.material_override = Palette.solid(Color("6b6255"), 0.0)
	_view.add_child(ground)
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	ball.mesh = sphere
	ball.material_override = Palette.solid(Palette.CHARCOAL.lerp(Palette.SLATE, 0.4), 0.0)
	_view.add_child(ball)
	_shell = PanelShell.new()
	_view.add_child(_shell)
	_cam = Camera3D.new()
	_cam.current = true
	_view.add_child(_cam)
	_plan()


func _plan() -> void:
	_shots.append({"name": "play-0", "group": "play-0", "held": [], "cam": "play", "roll": Vector3.ZERO})
	for n in [3, 5]:
		_shots.append({"name": "top-%d" % n, "held": MIXED.slice(0, n), "cam": "top", "roll": Vector3.ZERO})
		_rolled("play-%d" % n, MIXED.slice(0, n))
	for n in [4, 10, 32, 70]:
		var held := []
		for i in n:
			held.append(Panels.ids()[i % Panels.ids().size()])
		_rolled("play-%d" % n, held)
	for id in Panels.ids():
		_rolled("lineup-%s" % id, [id, id, id])
	_rolled("control-play-5--hidden", MIXED, true)


func _rolled(group: String, held: Array, hide := false) -> void:
	for r in ROLLS.size():
		_shots.append({"name": "%s-r%d" % [group, r], "group": group, "held": held, "cam": "play", "roll": ROLLS[r], "hide": hide})


func _stage(shot: Dictionary) -> void:
	_shell.show_panels(shot["held"], SEED)
	_shell.visible = not shot.get("hide", false)
	_shell.rotation = shot["roll"]
	if shot["cam"] == "top":
		_cam.fov = 40.0
		_cam.position = Vector3(0.0, 7.0, 0.001)
		_cam.look_at(Vector3.ZERO, Vector3.FORWARD)
	else:
		_cam.fov = PLAY_FOV
		_cam.position = Vector3(0.0, sin(-PLAY_PITCH) * PLAY_ARM + 0.6, cos(PLAY_PITCH) * PLAY_ARM)
		_cam.look_at(Vector3(0.0, 0.6, 0.0))


func _process(_delta: float) -> bool:
	if _index >= _shots.size():
		_finish()
		return true
	if _wait == 0:
		_stage(_shots[_index])
	_wait += 1
	if _wait < SETTLE_FRAMES:
		return false
	var image := _view.get_texture().get_image()
	image.save_png(_out.path_join("%s.png" % _shots[_index]["name"]))
	_shots[_index]["image"] = image
	_wait = 0
	_index += 1
	return false


func _changed(a: Image, b: Image) -> float:
	var centre := _cam.unproject_position(Vector3.ZERO)
	var radius := (_cam.unproject_position(Vector3(1.0, 0.0, 0.0)) - centre).x
	var half := radius * 1.8
	var hit := 0
	for y in range(int(centre.y - half), int(centre.y + half)):
		for x in range(int(centre.x - half), int(centre.x + half)):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.12:
				hit += 1
	return float(hit) / (PI * radius * radius)


func _finish() -> void:
	_stage({"held": [], "cam": "play", "roll": Vector3.ZERO})
	var bare: Image = _shots[0]["image"]
	var groups := {}
	for shot in _shots:
		if shot["cam"] != "play" or shot["group"] == "play-0":
			continue
		groups.get_or_add(shot["group"], []).append(_changed(shot["image"], bare))
	var rows := []
	var ok := true
	for group in groups:
		var shares: Array = groups[group]
		var mean: float = shares.reduce(func(acc, v): return acc + v, 0.0) / shares.size()
		var low: float = shares.min()
		var control: bool = group.begins_with("control-")
		var reads := mean >= READ_BUDGET and low >= MIN_SHARE
		var pass_row := reads != control
		ok = ok and pass_row
		rows.append({"still": group, "mean": snappedf(mean, 0.0001), "min": snappedf(low, 0.0001), "reads": reads, "control": control, "pass": pass_row})
		print("%-28s mean %.3f min %.3f %s%s" % [group, mean, low, "reads" if reads else "BLANK", " (control)" if control else ""])
	_report = {"budget": READ_BUDGET, "min_share": MIN_SHARE, "rows": rows, "pass": ok}
	var file := FileAccess.open(_out.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_report, "  "))
	file.close()
	print("panel_capture: %s, %d stills in %s" % ["PASS" if ok else "FAIL", _shots.size(), _out])
	quit(0 if ok else 1)
