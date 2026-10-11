extends SceneTree
# KC5 look capture for the flooded-cavern family. Run on card 1 through gpu_queue.sh:
#   godot --rendering-driver vulkan --display-driver x11 --gpu-index $SCRAPKEEP_GPU_INDEX --path sketches/core-loop
#     --resolution 1280x720 --script <this file> -- --out=<abs dir>
# For each recipe: a ball mannequin on the ride line, three chase cameras (close, mid, far), and three variants:
#   full  = park_recipes.place with the base and both detail shells (the recipe as the game places it)
#   bare  = the base only (shows what the shells add)
#   grey  = the greybox:flooded_cavern stand-in of the same row (the "before" of the wave 12 pair method)
# Writes <out>/<recipe>/<camera>_<variant>.png, blind pairs <out>/pairs/<recipe>__<camera>__<kind>/{a,b}.png with the side
# chosen by a hash coin, <out>/pairs/key.json (read AFTER reading the pairs), and one contact sheet per recipe
# <out>/sheet_<recipe>.png with the pairs as rows (a left, b right) and no key on it. Lights: one DirectionalLight3D only.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")

const SIZE := Vector2i(1280, 720)
const SHEET_CELL := Vector2i(640, 360)
const DRAW_FRAMES := 10
# cameras: name -> [eye, target, fov, relative]. relative = offsets from the ball (a chase view); else recipe space.
const RECIPES := {
	"cenote_pool": {"size": [70.0, 20.0, 60.0], "ball_z": 13.0,
		"cameras": {"close": [Vector3(0, 3.2, -8.5), Vector3(0, -0.2, 9.0), 62.0, true],
			"mid": [Vector3(20, 16.0, -20.0), Vector3(0, -8.0, 30.0), 62.0, false],
			"far": [Vector3(58, 40.0, -62.0), Vector3(0, -6.0, 35.0), 55.0, false]}},
	"flooded_shaft": {"size": [80.0, 24.0, 16.0], "ball_z": 14.0,
		"cameras": {"close": [Vector3(0, 3.0, -8.0), Vector3(0, -0.5, 10.0), 66.0, true],
			"mid": [Vector3(7.0, 13.0, -14.0), Vector3(0, -6.0, 34.0), 66.0, false],
			"far": [Vector3(30.0, 36.0, -40.0), Vector3(0, -6.0, 40.0), 58.0, false]}},
	"cavern_shell": {"size": [190.0, 16.0, 30.0], "ball_z": 20.0,
		"cameras": {"close": [Vector3(0, 3.2, -8.5), Vector3(0, 0.0, 10.0), 62.0, true],
			"mid": [Vector3(15.0, 18.0, -22.0), Vector3(0, -6.0, 55.0), 62.0, false],
			"far": [Vector3(48.0, 72.0, -72.0), Vector3(0, -4.0, 100.0), 58.0, false]}},
}
const PAIRS := [["full", "grey", "close"], ["full", "grey", "mid"], ["full", "grey", "far"], ["full", "bare", "close"], ["full", "bare", "mid"]]

var _out := ""
var _frames: Dictionary = {}
var _keys: Array = []
var _cams: Dictionary = {}
var _floors: Dictionary = {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(SIZE)
	for id in RECIPES:
		for variant in ["full", "bare", "grey"]:
			await _render(id, variant)
		_pairs(id)
	var f := FileAccess.open(_out.path_join("pairs/key.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_keys, "  "))
	f.close()
	quit(0)


func _row(id: String) -> Dictionary:
	return {"id": "look_" + id, "element": "flooded_cavern", "at": [0.0, 0.0], "y": 0.0, "size": RECIPES[id]["size"], "yaw_deg": 0.0,
		"ride_fact": "", "recipe": id, "budget": "park_large"}


func _render(id: String, variant: String) -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.46, 0.55, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.8, 0.72)
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, -28, 0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	world.add_child(sun)
	var row := _row(id)
	var node: Node3D
	if variant == "grey":
		node = ParkRecipes.place_greybox(row, "flooded_cavern", world)
	elif variant == "bare":
		var p := ParkRecipes.paths(id, "park_large")
		var parts := {"base": [(load(p["base"]) as PackedScene).instantiate()], "shells": []}
		node = ParkRecipes.place_parts(row, parts, world)
		for s: Node in parts["base"]:
			s.free()
	else:
		node = ParkRecipes.place(row, world)
	# A flat apron of the ground before the lip, so the ball's approach and the entry read.
	var apron := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(RECIPES[id]["size"][2] + 40.0, 80.0)
	apron.mesh = plane
	apron.position = Vector3(0, -0.02, -40.0)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.74, 0.6, 0.42)
	apron.material_override = gm
	world.add_child(apron)
	await physics_frame
	await physics_frame
	var ball_z: float = RECIPES[id]["ball_z"]
	var floor_y: float = _floor_at(world, 0.0, ball_z) if variant != "grey" else float(_floors[id])
	_floors[id] = floor_y
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	ball.mesh = sphere
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("8bf0d3")
	bm.emission_enabled = true
	bm.emission = Color("8bf0d3")
	bm.emission_energy_multiplier = 0.25
	ball.material_override = bm
	var ball_at := Vector3(0, floor_y + 1.0, ball_z)
	ball.position = ball_at
	world.add_child(ball)
	for cam_name in RECIPES[id]["cameras"]:
		var c: Array = RECIPES[id]["cameras"][cam_name]
		var cam := Camera3D.new()
		cam.fov = c[2]
		cam.far = 900.0
		world.add_child(cam)
		var key := "%s/%s" % [id, cam_name]
		if variant == "full":
			var anchor := Vector3(0, floor_y + 1.0, ball_z) if c[3] else Vector3.ZERO
			_cams[key] = [c[0] + anchor, c[1] + anchor]
		cam.global_position = _cams[key][0]
		cam.look_at(_cams[key][1], Vector3.UP)
		cam.current = true
		for k in DRAW_FRAMES:
			await process_frame
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var path := _out.path_join("%s/%s_%s.png" % [id, cam_name, variant])
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		img.save_png(path)
		_frames["%s/%s/%s" % [id, cam_name, variant]] = img
		cam.queue_free()
	world.queue_free()
	await process_frame


func _floor_at(world: Node3D, x: float, z: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 60, z), Vector3(x, -60, z))
	q.collision_mask = 1
	var hit := world.get_world_3d().direct_space_state.intersect_ray(q)
	return float(hit["position"].y) if not hit.is_empty() else 0.0


func _coin(label: String) -> bool:
	return (label.hash() & 1) == 1


func _pairs(id: String) -> void:
	var sheet := Image.create(SHEET_CELL.x * 2, SHEET_CELL.y * PAIRS.size(), false, Image.FORMAT_RGBA8)
	var row := 0
	for pair in PAIRS:
		var label := "%s__%s__%s-vs-%s" % [id, pair[2], pair[0], pair[1]]
		var left_is_first := _coin(label)
		var first: Image = _frames["%s/%s/%s" % [id, pair[2], pair[0]]]
		var second: Image = _frames["%s/%s/%s" % [id, pair[2], pair[1]]]
		var a := first if left_is_first else second
		var b := second if left_is_first else first
		var dir := _out.path_join("pairs/" + label)
		DirAccess.make_dir_recursive_absolute(dir)
		a.save_png(dir.path_join("a.png"))
		b.save_png(dir.path_join("b.png"))
		_keys.append({"pair": label, "a": pair[0] if left_is_first else pair[1], "b": pair[1] if left_is_first else pair[0]})
		for side in 2:
			var src: Image = a if side == 0 else b
			var small := src.duplicate() as Image
			small.resize(SHEET_CELL.x, SHEET_CELL.y, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(small, Rect2i(Vector2i.ZERO, SHEET_CELL), Vector2i(side * SHEET_CELL.x, row * SHEET_CELL.y))
		row += 1
	sheet.save_png(_out.path_join("sheet_%s.png" % id))
