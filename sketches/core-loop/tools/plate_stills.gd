extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const Secrets := preload("res://src/core/secrets.gd")

# Stills of World 1's lore plates (W45 P8) in the running game, so two builds compare plate for plate: a free camera
# at each plate's row spot, posed from the ground and the decks round the spot alone (never from the plate), so one
# seed gives one pose in every build; then the chase camera behind a frozen ball a few metres short of an unread
# plate, and the same view once the plate is read. HUD shown in the chase shots, hidden in the plate shots. Needs a
# rendered display. On the Mac, start it only with Godot's embedded display (no window on screen):
#
#   $GODOT_BIN --embedded --rendering-driver metal --resolution 1920x1080 --audio-driver Dummy --path sketches/core-loop \
#     --script res://tools/plate_stills.gd -- --out=<absolute dir> [--shots=dam_era_haul_sign,chase_unread]
#
# Writes <out>/<shot>.png and shots.json (each shot's eye, target and the plate's position when one stands there).

const SIZE := Vector2i(1920, 1080)
const SEED := 280928
const PLATES := {
	"park_dam": ["dam_era_incline_tally", "dam_era_haul_sign", "dam_dedication_plaque", "dam_era_gate_flags", "ancient_eye_marks"],
	"park_flume": ["dam_era_trestle_tag", "dam_era_flume_survey", "dam_era_rim_milepost", "dam_era_annex_dial"],
}
# The chase shots' plate: on open sandstone, off every deck.
const CHASE := {"map": "park_dam", "fragment": "dam_era_survey_deck", "back_m": 8.0, "turn": -0.3}
const EYE_OUT_M := 6.5
const EYE_UP_M := 2.5
const REACH_M := 40.0

var _out := ""
var _only: Array = []
var _game
var _cam: Camera3D
var _record := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			_only = Array(arg.trim_prefix("--shots=").split(","))
	if _out.is_empty() or DisplayServer.get_name() == "headless":
		printerr("plate_stills: needs a rendered display and -- --out=<absolute dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_main.call_deferred()


func _main() -> void:
	seed(SEED)
	GraphicsPreset.apply("high")
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await process_frame
	await process_frame
	_game.run.run_seed_override = 1
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(999999.0)
	_game.player.source = Intent.Scripted.new()
	_cam = Camera3D.new()
	_cam.near = 0.1
	_cam.far = 2000.0
	_cam.fov = 60.0
	_game.add_child(_cam)
	for map_id in ["park_dam", "park_flume"]:
		if not await _enter(map_id):
			quit(1)
			return
		# The chase shots keep the HUD, and hide_ui() is one way, so they come first.
		if map_id == CHASE["map"] and (_only.is_empty() or _only.has("chase_unread") or _only.has("chase_read")):
			await _chase_shots()
		for fragment in PLATES[map_id]:
			if _only.is_empty() or _only.has(fragment):
				await _plate_shot(map_id, fragment)
	var f := FileAccess.open(_out.path_join("shots.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_record, " "))
	f.close()
	quit(0)


func _enter(map_id: String) -> bool:
	var stage := 0
	for row in ParkDefs.DEFS:
		if String(row.get("map", "")) == map_id:
			stage = int(row["stage"])
	if stage != 1:
		_game.flow.enter_stage(stage, Vector3.ZERO, false)
	var terrain = _game.ctx.terrain
	for i in 3000:
		await process_frame
		if terrain.rows_ready(stage) and terrain.is_ready(stage) and _game.flow.in_play() and i > 120:
			for k in 10:
				await physics_frame
			return true
	printerr("plate_stills: %s never built" % map_id)
	return false


# The row spot a plate's fragment names, unmoved by any nudge, so the pose is the same in every build.
func _spot(fragment: String) -> Vector2:
	var park: Dictionary = _game.ctx.terrain.map().park
	var landmark: Dictionary = park.get("landmark", {})
	if String(landmark.get("fragment", "")) == fragment:
		var dock: Array = landmark.get("bay_dock", {}).get("at", landmark.get("beacon", landmark.get("at", [0, 0])))
		return Vector2(float(dock[0]), float(dock[1]))
	for row: Dictionary in park.get("park_rows", []):
		if String(row.get("fragment", "")) == fragment:
			return Vector2(float(row["at"][0]), float(row["at"][1]))
	return Vector2.INF


# The highest static world face under (x, z), any static body at all: it only places the camera over the ground,
# so one pose serves every build. It is not the seat test's ground, nor terrain.gd top_surface.
func _top(x: float, z: float) -> float:
	var ground: float = _game.ctx.terrain.height(x, z)
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, ground + REACH_M, z), Vector3(x, ground - 1.0, z), 1)
	var space: PhysicsDirectSpaceState3D = _game.get_world_3d().direct_space_state
	for i in 6:
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			break
		if hit.collider is StaticBody3D:
			return hit.position.y
		query.exclude = query.exclude + [hit.rid]
	return ground


func _plate(fragment: String) -> Node3D:
	var note: String = Secrets.PLATES.get(fragment, "")
	for p in _game.world.activities.plates:
		if p.note == note:
			return p
	return null


func _freeze_ball_away() -> void:
	_game.player.set_frozen(true)
	_game.player.body().global_position = Vector3(-400, 400, -400)


# The eye stands EYE_OUT_M off the spot on the side whose surface is lowest (down a slope, off a deck's middle
# toward its edge), EYE_UP_M over the spot's surface, and looks at the spot.
func _plate_shot(map_id: String, fragment: String) -> void:
	var spot := _spot(fragment)
	if spot == Vector2.INF:
		printerr("plate_stills: no row carries ", fragment)
		return
	_freeze_ball_away()
	_game.presentation.hide_ui()
	var at := Vector3(spot.x, _top(spot.x, spot.y), spot.y)
	var best := Vector3.INF
	for k in 8:
		var a := TAU * float(k) / 8.0 + PI / 8.0
		var x := spot.x + cos(a) * EYE_OUT_M
		var z := spot.y + sin(a) * EYE_OUT_M
		var y := _top(x, z)
		if best == Vector3.INF or y < best.y:
			best = Vector3(x, y, z)
	var eye := Vector3(best.x, maxf(best.y, at.y) + EYE_UP_M, best.z)
	_cam.global_position = eye
	_cam.look_at(at)
	_cam.make_current()
	for terrain in root.find_children("*", "Terrain3D", true, false):
		terrain.set_camera(_cam)
	await _save(fragment, _cam, at)


# The chase camera behind a frozen ball back_m short of the plate, facing it; then the plate is read and shot again.
func _chase_shots() -> void:
	var p := _plate(CHASE["fragment"])
	if p == null:
		printerr("plate_stills: no plate for ", CHASE["fragment"])
		return
	var plate: Vector3 = p.global_position
	var from := Vector2(plate.x, plate.z) + Vector2(0.0, -1.0) * float(CHASE["back_m"])
	var ball := Vector3(from.x, _top(from.x, from.y) + 1.0, from.y)
	_game.player.set_frozen(false)
	_game.player.reset_to(ball)
	_game.player.set_frozen(true)
	# Turned a little off the plate, so the ball does not stand between the camera and it.
	var to := plate - ball
	_game.camera.yaw = atan2(-to.x, -to.z) + float(CHASE["turn"])
	_game.camera.cam.make_current()
	for terrain in root.find_children("*", "Terrain3D", true, false):
		terrain.set_camera(_game.camera.cam)
	p.read = false
	if _game.world.activities.has_method("_show_plate"):
		_game.world.activities._show_plate(p)
	await _save("chase_unread", _game.camera.cam, plate)
	_game.world.activities.read_plate(p)
	await _save("chase_read", _game.camera.cam, plate)


func _save(id: String, cam: Camera3D, at: Vector3) -> void:
	for f in 150:
		await process_frame
	var eye := cam.global_position
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(id + ".png"))
	var row := {"eye": [eye.x, eye.y, eye.z], "at": [at.x, at.y, at.z]}
	var p := _plate(id) if not id.begins_with("chase") else _plate(CHASE["fragment"])
	if p != null:
		row["plate"] = [p.global_position.x, p.global_position.y, p.global_position.z]
		row["read"] = p.read
	_record[id] = row
	print("PLATE_STILL ", id, " ", JSON.stringify(row))
