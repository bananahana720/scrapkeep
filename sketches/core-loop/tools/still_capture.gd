extends SceneTree

const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Palette := preload("res://src/core/palette.gd")


const SETTLE_FRAMES := 4
const PROGRESS := [0.25, 0.5, 0.95]


class FlatGround:
	func height(_x: float, _z: float) -> float:
		return 0.0


var _out := ""
var _control := false
var _ground := FlatGround.new()
var _view: SubViewport
var _world: Node3D
var _shots: Array = []
var _index := 0
var _wait := 0
var _current: Array = []
var _shooting := false
var _written: Array = []
var _cam: Camera3D
var _probes := {}
var _front_probe := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg == "--control":
			_control = true
		elif arg == "--telegraph=haze":
			Threat.set_haze(true)
	if _out == "":
		push_error("still_capture: --out=<dir> is required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_build_world()
	_plan()


func _build_world() -> void:
	_view = SubViewport.new()
	_view.size = Vector2i(1920, 1080)
	_view.msaa_3d = Viewport.MSAA_2X
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view.own_world_3d = true
	root.add_child(_view)
	_world = Node3D.new()
	_view.add_child(_world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.1, 0.1, 0.12)
	_world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	_world.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	floor.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Palette.SANDSTONE
	floor.material_override = mat
	_world.add_child(floor)
	var cam := Camera3D.new()
	cam.fov = 60.0
	_world.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 17.0, 17.0), Vector3(0.0, 0.0, -1.0))
	cam.current = true
	_cam = cam


func _plan() -> void:
	_shots.append({"name": "empty", "make": func(): return []})
	for p in PROGRESS:
		var tag := "%02d" % int(round(p * 100.0))
		_shots.append({"name": "instant-ring-" + tag, "make": func(): return _progress(Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3.ZERO, 6.0), p)})
		_shots.append({"name": "instant-wedge-" + tag, "make": func(): return _progress(Telegraph.wedge(_world, _ground, Threat.Type.INSTANT, Vector3(0.0, 0.0, 4.0), Vector3.FORWARD, 9.0, 35.0), p)})
		_shots.append({"name": "instant-lane-" + tag, "make": func(): return _progress(Telegraph.lane(_world, _ground, Threat.Type.INSTANT, Vector3(-2.0, 0.0, 6.0), Vector3(0.2, 0.0, -1.0), 14.0, 4.0), p)})
		_shots.append({"name": "lane-lane-" + tag, "make": func(): return _progress(Telegraph.lane(_world, _ground, Threat.Type.LANE, Vector3(2.0, 0.0, 6.0), Vector3(-0.2, 0.0, -1.0), 14.0, 3.0), p)})
		_shots.append({"name": "lane-wedge-" + tag, "make": func(): return _progress(Telegraph.wedge(_world, _ground, Threat.Type.LANE, Vector3(0.0, 0.0, 4.0), Vector3.FORWARD, 9.0, 30.0), p)})
		_shots.append({"name": "projectile-ring-" + tag, "make": func(): return _projectile(p)})
		_shots.append({"name": "wave-ring-" + tag, "make": func(): return _wave(p)})
	_shots.append({"name": "wave-ring-arming", "make": func(): return _wave(-0.5)})
	_shots.append({"name": "overlap-5ring-50", "make": func(): return _overlap(0.0)})
	_shots.append({"name": "overlap-5ring-50-density1", "make": func(): return _overlap(1.0)})
	_shots.append({"name": "overlap-mixed-50", "make": func(): return _mixed(0.5)})
	_shots.append({"name": "overlap-mixed-live", "make": func(): return _mixed(1.0)})
	_shots.append({"name": "overlap-live-pending-front", "cam": Vector3(0.0, 17.0, 17.0), "make": func(): return _live_over_pending()})
	_shots.append({"name": "overlap-live-pending-back", "cam": Vector3(0.0, 17.0, -14.0), "make": func(): return _live_over_pending()})
	_shots.append({"name": "overlap-front-live", "make": func(): return _front_over_live()})
	if _control:
		_shots.append({"name": "control-instant-ring-50--no-stripe-motion", "make": func(): return _control_ring(func(layers: Dictionary):
			layers["stripe_motion"].visible = false)})
		_shots.append({"name": "control-instant-ring-50--band", "make": func(): return _control_ring(func(layers: Dictionary):
			var clip: Vector4 = layers["stripe_motion"].get_instance_shader_parameter("clip")
			layers["stripe_motion"].set_instance_shader_parameter("clip", clip + Vector4(0.4, 0.0, 0.0, 0.0)))})
		_shots.append({"name": "control-instant-ring-50--no-keyline", "make": func(): return _control_ring(func(layers: Dictionary):
			layers["under"].visible = false)})


func _control_ring(defect: Callable) -> Array:
	var nodes := _progress(Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3.ZERO, 6.0), 0.5)
	defect.call(nodes[0].painter()._layers)
	return nodes


const CROSS := Vector3(0.0, 0.0, 1.5)
const LIVE_ONLY := Vector3(0.0, 0.0, -6.0)
const PENDING_ONLY := Vector3(6.0, 0.0, 1.5)
const PATCH := 36


func _live_over_pending() -> Array:
	var pending: Node3D = _progress(Telegraph.lane(_world, _ground, Threat.Type.LANE, Vector3(-8.0, 0.0, 1.5), Vector3.RIGHT, 16.0, 8.0), 0.95)[0]
	var live: Node3D = _progress(Telegraph.lane(_world, _ground, Threat.Type.LANE, Vector3(0.0, 0.0, -9.5), Vector3.BACK, 16.0, 8.0), 1.0)[0]
	return [pending, live]


const FRONT_CENTRE := Vector3(0.0, 0.0, -4.0)
const FRONT_IN_LANE := Vector3(0.0, 0.0, 1.0)
const FRONT_OUT_OF_LANE := Vector3(0.0, 0.0, -9.0)
const LANE_ONLY := Vector3(-8.0, 0.0, 1.5)
const FRONT_PATCH := 6


func _front_over_live() -> Array:
	var live: Node3D = _progress(Telegraph.lane(_world, _ground, Threat.Type.LANE, Vector3(-14.0, 0.0, 1.5), Vector3.RIGHT, 28.0, 8.0), 1.0)[0]
	var wave: Node3D = _wave(0.5, FRONT_CENTRE)[0]
	return [live, wave]


func _small_mean(image: Image, point: Vector3) -> Color:
	var at := Vector2i(_cam.unproject_position(point))
	var sum := Vector3.ZERO
	var count := 0
	for y in range(at.y - FRONT_PATCH, at.y + FRONT_PATCH):
		for x in range(at.x - FRONT_PATCH, at.x + FRONT_PATCH):
			var c := image.get_pixel(x, y)
			sum += Vector3(c.r, c.g, c.b)
			count += 1
	sum /= count
	return Color(sum.x, sum.y, sum.z)


func _patch_mean(image: Image, point: Vector3) -> Color:
	var at := Vector2i(_cam.unproject_position(point))
	var sum := Vector3.ZERO
	var count := 0
	for y in range(at.y - PATCH, at.y + PATCH):
		for x in range(at.x - PATCH, at.x + PATCH):
			var c := image.get_pixel(x, y)
			sum += Vector3(c.r, c.g, c.b)
			count += 1
	sum /= count
	return Color(sum.x, sum.y, sum.z)


func _probe(image: Image, name: String) -> void:
	if name == "overlap-front-live":
		_front_probe = {"in_lane": _small_mean(image, FRONT_IN_LANE), "out_of_lane": _small_mean(image, FRONT_OUT_OF_LANE), "lane_only": _small_mean(image, LANE_ONLY)}
		return
	if not name.begins_with("overlap-live-pending"):
		return
	_probes[name] = {"cross": _patch_mean(image, CROSS), "live_only": _patch_mean(image, LIVE_ONLY), "pending_only": _patch_mean(image, PENDING_ONLY)}


func _dist(a: Color, b: Color) -> float:
	return (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0 * 255.0


func check_live_over_pending() -> bool:
	if not _probes.has("overlap-live-pending-front") or not _probes.has("overlap-live-pending-back"):
		return true
	var f: Dictionary = _probes["overlap-live-pending-front"]
	var b: Dictionary = _probes["overlap-live-pending-back"]
	var sides := _dist(f["cross"], b["cross"])
	var apart := minf(_dist(f["live_only"], f["pending_only"]), _dist(b["live_only"], b["pending_only"]))
	var near_live := true
	for probe in [f, b]:
		near_live = near_live and _dist(probe["cross"], probe["live_only"]) < _dist(probe["cross"], probe["pending_only"])
	var ok := sides <= LIVE_SIDES_MAX and apart >= LIVE_APART_MIN and near_live
	print("live over pending: overlap front vs back differ by %.2f (max %.1f), live and pending are %.2f apart (min %.1f), overlap nearer live than pending: %s -> %s"
		% [sides, LIVE_SIDES_MAX, apart, LIVE_APART_MIN, near_live, "PASS" if ok else "FAIL"])
	var f2 := FileAccess.open(_out.path_join("live-over-pending.json"), FileAccess.WRITE)
	f2.store_string(JSON.stringify({"front": _dump(f), "back": _dump(b), "sides": sides, "apart": apart, "near_live": near_live, "pass": ok}, " "))
	f2.close()
	return ok


func check_front_over_live() -> bool:
	if _front_probe.is_empty():
		return true
	var inside: Color = _front_probe["in_lane"]
	var outside: Color = _front_probe["out_of_lane"]
	var band: Color = _front_probe["lane_only"]
	var same := _dist(inside, outside)
	var apart := _dist(outside, band)
	var ok := apart >= FRONT_APART_MIN and same <= apart * FRONT_SAME_SHARE and _dist(inside, band) > same
	print("front over live: front in the band vs on bare ground differ by %.2f, front vs the bare band %.2f apart (min %.1f), allowed share %.2f -> %s"
		% [same, apart, FRONT_APART_MIN, FRONT_SAME_SHARE, "PASS" if ok else "FAIL"])
	var f := FileAccess.open(_out.path_join("front-over-live.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"in_lane": _dump(_front_probe), "same": same, "apart": apart, "pass": ok}, " "))
	f.close()
	return ok


const FRONT_APART_MIN := 20.0
const FRONT_SAME_SHARE := 0.2


func _dump(probe: Dictionary) -> Dictionary:
	var out := {}
	for key in probe:
		out[key] = probe[key].to_html(false)
	return out


const LIVE_SIDES_MAX := 6.0
const LIVE_APART_MIN := 5.0


func _mixed(lane_progress: float) -> Array:
	var nodes: Array = []
	nodes.append(_progress(Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3(-2.0, 0.0, 0.0), 6.0), 0.5)[0])
	nodes.append(_progress(Telegraph.lane(_world, _ground, Threat.Type.LANE, Vector3(-9.0, 0.0, 3.0), Vector3(1.0, 0.0, -0.35), 18.0, 3.0), lane_progress)[0])
	nodes.append_array(_wave(0.5, Vector3(3.0, 0.0, -2.0)))
	return nodes


func _progress(node: Node3D, p: float) -> Array:
	node.set_progress(p)
	return [node]


func _projectile(p: float) -> Array:
	var node := Telegraph.ring(_world, _ground, Threat.Type.PROJECTILE, Vector3.ZERO, 3.5)
	node.set_flight(Vector3(12.0, 1.5, -12.0), 6.0)
	node.set_progress(p)
	return [node]


func _wave(share: float, at := Vector3.ZERO) -> Array:
	var node := Telegraph.wave(_world, _ground, at, 10.0, 6.0, 0.5)
	if share < 0.0:
		node.age = 0.5 * -share
	else:
		node.age = node.warn_seconds + share * node.radius / node.speed
	node.set_progress(node.age / node.warn_seconds)
	return [node]


func _overlap(density: float) -> Array:
	_set_fill_scale(1.0 if density <= 0.0 else _fill_scale(density))
	var nodes: Array = []
	for i in 5:
		nodes.append(_progress(Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3(-3.0 + 1.5 * i, 0.0, -0.5 * i), 6.0), 0.5)[0])
	return nodes


func _fill_scale(density: float) -> float:
	if not ResourceLoader.exists("res://src/presentation/density.gd"):
		return 1.0
	return load("res://src/presentation/density.gd").fill_scale(density)


func _set_fill_scale(value: float) -> void:
	if ProjectSettings.has_setting("shader_globals/threat_fill_scale"):
		RenderingServer.global_shader_parameter_set(&"threat_fill_scale", value)


func _process(_delta: float) -> bool:
	if _out == "":
		return true
	if _wait > 0:
		_wait -= 1
		return false
	if _shooting:
		var image := _view.get_texture().get_image()
		var path := _out.path_join(String(_shots[_index]["name"]) + ".png")
		_probe(image, String(_shots[_index]["name"]))
		image.save_png(path)
		_written.append({"name": _shots[_index]["name"], "size": [image.get_width(), image.get_height()]})
		for node in _current:
			node.free()
		_current = []
		_shooting = false
		_set_fill_scale(1.0)
		_index += 1
	if _index >= _shots.size():
		var f := FileAccess.open(_out.path_join("stills.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify({"stills": _written, "engine": Engine.get_version_info()["string"],
			"adapter": RenderingServer.get_video_adapter_name()}, " "))
		f.close()
		print("still_capture: wrote %d stills to %s" % [_written.size(), _out])
		var live_ok := check_live_over_pending()
		var front_ok := check_front_over_live()
		quit(0 if live_ok and front_ok else 1)
		return true
	_cam.look_at_from_position(_shots[_index].get("cam", Vector3(0.0, 17.0, 17.0)),
		CROSS if _shots[_index].has("cam") else Vector3(0.0, 0.0, -1.0))
	_current = _shots[_index]["make"].call()
	_shooting = true
	_wait = SETTLE_FRAMES
	return false
