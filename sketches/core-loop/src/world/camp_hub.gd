extends Node

# The walkable camp: the hub ring built from assets/models/camp/*.glb, placed by camp_layout.gd (the port of
# tools/blender/camp/layout.py). The title's K opens it as a walk mode of the camp page (screens.gd toggle_camp): the
# player's ball rolls round the plaza and the stations, each station is a ball-only Area3D zone with a prompt card, and
# its key opens the station's existing page. The flow stays on the title; the run logic never sees the walk.
#
# Where it stands: the whole hub sits at HUB_ORIGIN, far from every stage's terrain (the stages are inside a 1.6 km
# square about the origin, the bay is at y -2000), so nothing overlaps and the ball can never roll onto a stage. The
# ChaseCamera far plane is 700 m, so a stage is never drawn from here.
#
# What it builds, once, on the first walk: every GLB piece (its drawn views, its detail shells with fade ranges, and its
# "-col" mesh as a world-layer StaticBody3D, all through park_recipes.gd's helpers), a ground disc and rim berm, the
# cottonwoods, Moss's jukebox and hover barge (recipe_props.gd), a light at chosen light_* sockets, and the zones.
#
# Living camp (W46-14), refreshed on every walk from the profile: the freed pilots stand round the fire pit (all but the
# one the gate launches), each saying one line on the caller plate as the ball rolls past (pilot_quipped hands the
# caller id and the words to whoever voices them), and every B-side found stands as a record sleeve in the bin by Moss's
# jukebox. All of it is drawn only: no collider, no target, the layout and its solids as they were.
#
# Public API for the features that plug in (camp_skee.gd, camp_trial.gd, camp_sandbox.gd and the like):
#   root          the hub's top node, at HUB_ORIGIN; layout coordinates are local to it.
#   piece(id)     the placed instance of a GLB stem ("camp_skee_lane"), or null.
#   socket(id, n) the global Transform3D of socket n on piece id (IDENTITY when absent).
#   add_station() a zone, prompt card and key; add_zone() the same without a prompt.
#   walk_entered / walk_left, ball, game.
#   FEATURES      preloads, each with `static func attach(hub)`, called once after the hub is built.

const Recipes := preload("res://src/world/park/park_recipes.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const Layout := preload("res://src/world/camp_layout.gd")
const Palette := preload("res://src/core/palette.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const RadioTakes := preload("res://src/core/radio_takes.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const CallerTile := preload("res://src/ui/caller_tile.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")

# Features that plug into the hub. Each is a script with `static func attach(hub)`.
const FEATURES: Array = [
	preload("res://src/world/camp_skee.gd"),
	preload("res://src/world/camp_trial.gd"),
	preload("res://src/world/camp_sandbox.gd"),
	preload("res://src/world/camp_ring.gd"),
	preload("res://src/ui/camp_scrapbook.gd"),
]

const GLB_DIR := "res://assets/models/camp/"
const HUB_ORIGIN := Vector3(3000.0, 0.0, 3000.0)
# The ground is deliberate: a sandstone disc under and round the whole camp, with its own collision, so the plaza
# model only has to cover the ring. Its rim is a berm of wall segments so the ball cannot roll off into nothing.
const GROUND_R := 270.0
const GROUND_THICK := 4.0
const BERM_SEGMENTS := 72
const BERM_HEIGHT := 6.0
const BERM_DEPTH := 10.0
const BERM_STAGGER_M := 0.06
# The detail shells fade out by distance, like the park's (asset_budgets.json park_large shells).
const SHELL_RANGES := [[150.0, 20.0], [60.0, 8.0]]
const ZONE_RADIUS := 2.5
const FALL_BELOW := -25.0
const MAX_LIGHTS := 24
# A solid prop collides up to here: a cottonwood's trunk and root flare, not its crown (boughs start at 4 m).
const SOLID_TOP_M := 4.0
# The pieces that have detail shells beside them.
const SHELLED := ["camp_launch_gate", "camp_lockers", "camp_moss_stall", "camp_skee_lane"]
# Pieces laid flat on the plaza or the sandstone disc: their floors share the plaza's plane where they overlap it, so their
# drawn views stand one surface layer up (park_recipes.gd SURFACE_LAYER_M) and do not z-fight (clip audit, 30 Oct).
const ON_PLAZA := ["camp_shortcut", "camp_skee_lane", "camp_trial_track"]
# Lights: piece stem -> [socket names, kind]. The lamp posts and the fire pit light the plaza; the stall, the wall, the
# console, the gate and the lane keep two or three each; the rest of their bulbs stay emissive enamel.
const LIGHTS := {
	"camp_lamp_post": [["light_0"], "lamp"],
	"camp_fire_pit": [["light_0"], "fire"],
	"camp_moss_stall": [["light_0", "light_1"], "lamp"],
	"camp_trophy_wall": [["light_0", "light_1"], "lamp"],
	"camp_settings_console": [["light_0"], "lamp"],
	"camp_launch_gate": [["light_tree_0", "light_marquee_00", "light_marquee_08"], "marquee"],
	"camp_skee_lane": [["light_00", "light_08"], "marquee"],
}
const LIGHT_KINDS := {
	"lamp": {"color": Color("ffd9a0"), "energy": 2.2, "range": 16.0},
	"fire": {"color": Color("ff9a3c"), "energy": 3.0, "range": 18.0},
	"marquee": {"color": Color("e5a044"), "energy": 2.6, "range": 20.0},
}

# The crew round the fire: one spot per roster place, [bearing, radius] in the layout's terms (camp_layout.gd), about
# the fire pit at bearing 160 and the benches either side of it, so the ball's way through the plaza stays open. A
# pilot stands at their own spot every walk. The ball within CREW_ZONE_M has them say their line, once a walk.
const CREW_SPOTS := [[148.0, 12.0], [172.0, 12.0], [138.0, 16.5], [182.0, 16.5], [160.0, 21.5], [160.0, 9.6]]
const CREW_ZONE_M := 6.0
const CREW_SCALE := 1.6
const CREW_FIRE := [160.0, 15.0]
# Past this the crew is not drawn (they are a few hundred triangles' worth of skin each, not a landmark).
const CREW_FADE_M := 80.0
const CREW_FADE_MARGIN_M := 10.0
# The loop a standing pilot idles in (the freed pilot's idle at the rescue cage, rescue_site.gd), each pilot CREW_OFFSET_S
# further into it than the last so the crew never moves in unison (that is the Foreman's look), and the clip they
# strike when they speak, back to the idle after.
const CREW_IDLE_CLIP := "idle_loop"
const CREW_TALK_CLIP := "big_cheer"
const CREW_OFFSET_S := 0.7
# A quip's card stays QUIP_HOLD_S plus QUIP_PER_WORD_S a word, then fades over QUIP_FADE_S.
const QUIP_HOLD_S := 2.2
const QUIP_PER_WORD_S := 0.28
const QUIP_FADE_S := 0.3
const QUIP_WIDTH := 330.0
# The record bins by the jukebox, in the jukebox socket's frame (+Z its face): BIN_AT is the first bin's centre, the
# next stand BIN_STEP along. A bin stands on legs BIN_LIFT high, a shelf at the cabinet's side, and holds BIN_SLOTS
# sleeves upright, SLEEVE_STEP apart, leaning back, so their tops and the front one's face show over its walls.
const BIN_AT := Vector3(1.9, 0.0, 0.9)
const BIN_LIFT := 0.55
const BIN_STEP := Vector3(0.0, 0.0, 0.9)
const BIN_SLOTS := 24
const BIN_MAX := 3
const BIN_SIZE := Vector3(0.66, 0.3, 1.2)
const SLEEVE_SIDE := 0.5
const SLEEVE_STEP := 0.045
const SLEEVE_LEAN := 0.16
# Sleeve colours: album-cover pop from the palette, none of them a colour that means a thing in play (no hazard red,
# no relic amber, no reward cobalt or arc, never the Kindness purple). A sleeve's colour is its id's, the same every walk.
const SLEEVE_INKS := [Palette.COPPER, Palette.BRASS, Palette.VERDIGRIS, Palette.OLD_VERDIGRIS, Palette.SAND,
	Palette.LEDGER_CREAM, Palette.SLATE, Palette.TURQUOISE, Palette.APRICOT, Palette.SODIUM, Palette.RUST]

signal walk_entered
signal walk_left
signal station_entered(id: String)
signal station_left(id: String)
# A freed pilot in the camp said their line: who (a LoreRows.SPEAKERS id, what a voice reads), the quip row's id and
# the words on the plate. The line is silent until something that voices callers hooks this.
signal pilot_quipped(speaker: String, row_id: String, words: String)

var game
var ball
# The store that keeps the camp's records; game.gd hands it in (the profile layer stays out of src/world).
var camp_store
var root: Node3D
var built := false
var walking := false
var pet_reactions := 0
var light_count := 0
# Walks taken this session: a quip's line steps through its list by it.
var walks := 0

var _pieces := {}
var _zones := {}
var _inside: Array[String] = []
var _prompts: CanvasLayer
var _prompt_box: VBoxContainer
var _prompt_buttons := {}
var _clock: Label
var _pet: Node3D
var _pet_home := Vector3.ZERO
var _pet_tween: Tween
var _look_owner: Node3D
var _spawn := Vector3.ZERO
# The crew: class id -> the figure's holder; who has spoken this walk; the quip card and its plate.
var _crew := {}
var _quipped := {}
var _quip: Control
var _quip_tile
var _quip_label: Label
var _quip_hold := 0.0
var _quip_tween: Tween
# The records: the bins' and the sleeves' MultiMeshes, and the ids standing in them, in the order they were found.
var _bins: MultiMeshInstance3D
var _sleeves: MultiMeshInstance3D
var _shelved: Array = []


func setup(game_ref) -> void:
	name = "CampHub"
	game = game_ref
	ball = game.player
	process_mode = Node.PROCESS_MODE_PAUSABLE


# --- the public API ---

func piece(id: String) -> Node3D:
	return _pieces.get(id)


# Sockets already warned about, so a missing one warns once.
var _missing_sockets := {}

func socket(id: String, socket_name: String) -> Transform3D:
	var holder: Node3D = _pieces.get(id)
	if holder == null:
		return Transform3D.IDENTITY
	var marker := holder.get_node_or_null("Sockets/" + socket_name) as Node3D
	if marker == null:
		# camp_hub_test checks every socket a feature reads; this is the release-build net.
		if not _missing_sockets.has(id + "/" + socket_name):
			_missing_sockets[id + "/" + socket_name] = true
			push_warning("camp_hub: %s has no socket %s; placing at the origin" % [id, socket_name])
		return Transform3D.IDENTITY
	return marker.global_transform


func has_socket(id: String, socket_name: String) -> bool:
	var holder: Node3D = _pieces.get(id)
	return holder != null and holder.get_node_or_null("Sockets/" + socket_name) != null


# A zone with a prompt card and a key. `at` is a global position; radius is the sphere's, metres; key is a Keycap id
# ("key_m"); on_press runs when the key, the card or the pad's confirm button is pressed inside the zone.
func add_station(id: String, at: Vector3, label: String, key: String, radius: float, on_press: Callable) -> void:
	_zones[id] = {"label": label, "key": key, "on_press": on_press, "area": _make_zone(id, at, radius), "enter": Callable()}


# A station's prompt word, changed after it is built (the gate names the pilot it launches).
func set_label(id: String, label: String) -> void:
	if not _zones.has(id) or _zones[id]["label"] == label:
		return
	_zones[id]["label"] = label
	_refresh_prompts()


# A zone with no prompt: it only reports the ball coming and going.
func add_zone(id: String, at: Vector3, radius: float, on_enter := Callable(), on_exit := Callable()) -> void:
	_zones[id] = {"label": "", "key": "", "on_press": Callable(), "area": _make_zone(id, at, radius), "enter": on_enter, "exit": on_exit}


# --- zone queries, for the screens, the pad and the tests ---

func zone_ids() -> Array:
	return _zones.keys()


func zone_position(id: String) -> Vector3:
	var area: Area3D = _zones[id]["area"]
	return area.global_position


func inside_ids() -> Array[String]:
	return _inside


func inside(id: String) -> bool:
	return id in _inside


# The keycode of the first prompted zone the ball is in, KEY_NONE when none: the pad's confirm button presses it.
func confirm_key() -> int:
	for id in _inside:
		var key: String = _zones[id]["key"]
		if key != "":
			return OS.find_keycode_from_string(Keycap.label(key))
	return KEY_NONE


# Runs the press of the prompted zone the ball is in whose key is keycode. False when none matches.
func press_key(keycode: int) -> bool:
	for id in _inside:
		var key: String = _zones[id]["key"]
		if key != "" and OS.find_keycode_from_string(Keycap.label(key)) == keycode:
			var press: Callable = _zones[id]["on_press"]
			if press.is_valid():
				press.call()
			return true
	return false


func prompt_words() -> Array:
	var out := []
	for id in _inside:
		if _zones[id]["key"] != "":
			out.append(_zones[id]["label"])
	return out


func prompts_shown() -> bool:
	return _prompts != null and _prompts.visible and _prompt_box.get_child_count() > 0


# Whether the prompt cards show: off while a page covers the walk.
func set_prompts_visible(shown: bool) -> void:
	if _prompts != null:
		_prompts.visible = shown and walking


# --- the walk ---

func enter_walk() -> void:
	if walking:
		return
	ensure_built()
	walking = true
	root.visible = true
	_set_zones_monitoring(true)
	var stage = _title_stage()
	if stage != null:
		stage.set_camp_walk(true)
	_look_owner = Node3D.new()
	_look_owner.name = "CampLook"
	add_child(_look_owner)
	GraphicsPreset.enter_world(_look_owner, game.ctx.terrain.environment, WorldLook.CAMP, "camp")
	_place_ball()
	if game.has_method("gate_label"):
		set_label("gate", game.gate_label())
	walks += 1
	_quipped.clear()
	_stand_crew()
	_shelve_records()
	_prompts.visible = true
	walk_entered.emit()


func leave_walk() -> void:
	if not walking:
		return
	walking = false
	_inside.clear()
	_refresh_prompts()
	set_clock("")
	_end_quip(true)
	_set_zones_monitoring(false)
	root.visible = false
	_prompts.visible = false
	GraphicsPreset.clear_lighting(game.ctx.terrain.environment, "camp")
	if is_instance_valid(_look_owner):
		_look_owner.queue_free()
	var player = game.player
	player.set_frozen(true)
	var home: Vector3 = game.ctx.terrain.spawn_point(1)
	player.reset_to(home)
	game.camera.snap(game.ctx.terrain.entry_heading(1))
	var stage = _title_stage()
	if stage != null:
		stage.set_camp_walk(false)
	walk_left.emit()


func spawn_position() -> Vector3:
	return _spawn


func _place_ball() -> void:
	var player = game.player
	player.set_frozen(false)
	player.reset_to(_spawn)
	game.camera.snap(Vector3(0.0, 0.0, -1.0))


func _title_stage():
	var presentation = game.get("presentation")
	return presentation.get("title_stage") if presentation != null else null


func _process(delta: float) -> void:
	if _quip_hold > 0.0:
		_quip_hold -= delta
		if _quip_hold <= 0.0:
			_end_quip(false)


func _physics_process(_delta: float) -> void:
	if not walking:
		return
	if game.player.ball_position().y < HUB_ORIGIN.y + FALL_BELOW:
		_place_ball()


# --- building ---

func ensure_built() -> void:
	if built:
		return
	built = true
	root = Node3D.new()
	root.name = "CampRoot"
	root.position = HUB_ORIGIN
	root.visible = false
	add_child(root)
	_build_ground()
	_place_layout()
	_spawn = to_global_spawn()
	_build_lights()
	_build_stations()
	_build_prompts()
	_build_quip()
	_build_records()
	for feature in FEATURES:
		feature.attach(self)


func to_global_spawn() -> Vector3:
	var at := HUB_ORIGIN + Vector3(0.0, 1.2, 0.0)
	if has_socket("camp_plaza", "spawn"):
		at = socket("camp_plaza", "spawn").origin + Vector3(0.0, 0.2, 0.0)
	return at


# One GLB placed under root at xf (layout space): views, shells, collision and socket markers.
func _place(stem: String, xf: Transform3D, with_shells := false, key := "") -> Node3D:
	var path := ModelVariants.path(GLB_DIR + stem + ".glb")
	var scenes := Recipes._load(path)
	if scenes.is_empty():
		push_warning("camp_hub: %s is missing, it stays out" % path)
		return null
	var scene: Node = scenes[0]
	var holder := Node3D.new()
	holder.name = stem if key == "" else key
	root.add_child(holder)
	holder.transform = xf
	var body := Recipes._body(holder)
	Recipes._views(scene, holder, body, Transform3D.IDENTITY)
	if with_shells:
		for k in 2:
			var shell_scenes := Recipes._load(GLB_DIR + "%s_detail%d.glb" % [stem, k + 1])
			for shell: Node in shell_scenes:
				for view in Recipes._views(shell, holder, body, Transform3D.IDENTITY):
					Recipes._range(view, 0.0, SHELL_RANGES[k][0], SHELL_RANGES[k][1])
				shell.free()
	var markers := Node3D.new()
	markers.name = "Sockets"
	holder.add_child(markers)
	for node: Node3D in scene.find_children("*", "Node3D", true, false):
		if node is MeshInstance3D or node is CollisionShape3D or node is StaticBody3D:
			continue
		if String(node.name).ends_with(Recipes.COL_SUFFIX):
			continue
		var marker := Marker3D.new()
		marker.name = node.name
		markers.add_child(marker)
		marker.transform = Recipes._relative(node, scene)
	scene.free()
	if ON_PLAZA.has(stem):
		Recipes._lift_drawn(holder, Recipes.SURFACE_LAYER_M)
	if not _pieces.has(stem):
		_pieces[stem] = holder
	return holder


func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "CampGround"
	ground.collision_layer = 0
	ground.collision_mask = 0
	ground.set_collision_layer_value(Recipes.WORLD_LAYER, true)
	root.add_child(ground)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = GROUND_R
	cylinder.height = GROUND_THICK
	shape.shape = cylinder
	shape.position.y = -GROUND_THICK * 0.5
	ground.add_child(shape)
	var sand := StandardMaterial3D.new()
	sand.albedo_color = Palette.SANDSTONE
	sand.roughness = 1.0
	var disc := MeshInstance3D.new()
	disc.name = "SandstoneDisc"
	var mesh := CylinderMesh.new()
	mesh.top_radius = GROUND_R
	mesh.bottom_radius = GROUND_R
	mesh.height = GROUND_THICK
	mesh.radial_segments = 96
	mesh.rings = 1
	mesh.material = sand
	disc.mesh = mesh
	disc.position.y = -GROUND_THICK * 0.5
	ground.add_child(disc)
	var berm_material := StandardMaterial3D.new()
	berm_material.albedo_color = Palette.SANDSTONE.darkened(0.18)
	berm_material.roughness = 1.0
	var chord := TAU * GROUND_R / BERM_SEGMENTS * 1.08
	for i in BERM_SEGMENTS:
		var angle := TAU * i / BERM_SEGMENTS
		# Neighbours overlap by the chord's 8%, so odd segments stand BERM_STAGGER_M taller: two tops in one plane z-fight.
		var tall := BERM_HEIGHT + BERM_STAGGER_M * float(i % 2)
		var at := Vector3(sin(angle) * (GROUND_R - BERM_DEPTH * 0.5), tall * 0.5, -cos(angle) * (GROUND_R - BERM_DEPTH * 0.5))
		var segment := Transform3D(Basis(Vector3.UP, -angle), at)
		var box := BoxShape3D.new()
		box.size = Vector3(chord, tall, BERM_DEPTH)
		var collider := CollisionShape3D.new()
		collider.shape = box
		collider.transform = segment
		ground.add_child(collider)
		var view := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = box.size
		box_mesh.material = berm_material
		view.mesh = box_mesh
		view.transform = segment
		ground.add_child(view)


func _place_layout() -> void:
	_place("camp_plaza", Transform3D.IDENTITY)
	_place("camp_shortcut", Layout.place(Layout.SHORTCUT_AT, 0.0))
	var glbs := {"gate": "camp_launch_gate", "lockers": "camp_lockers", "achieve": "camp_trophy_wall",
		"settings": "camp_settings_console", "skee": "camp_skee_lane", "pet": "camp_pet_pen", "moss": "camp_moss_stall"}
	for sid in glbs:
		var st: Dictionary = Layout.station(sid)
		_place(glbs[sid], Layout.place(st.at, st.yaw), glbs[sid] in SHELLED)
	# Moss's jukebox stands at the stall's jukebox socket; his hover barge is parked out past the ring.
	var jukebox_at := socket("camp_moss_stall", "jukebox")
	_prop("moss_jukebox", Transform3D(jukebox_at.basis, to_local_point(jukebox_at.origin)), true)
	_prop("moss_hover_barge", Layout.place(Layout.BARGE_AT, deg_to_rad(Layout.BARGE_YAW_DEG)), false)
	for tree: Array in Layout.TREES:
		_prop("cottonwood", Layout.place(Vector3(tree[0], 0.0, tree[1]), deg_to_rad(tree[0] + tree[1])), true)
	_place("camp_trial_track", Layout.place(Layout.TRIAL_AT, 0.0))
	_place("camp_sandbox_yard", Layout.place(Layout.SANDBOX_AT, deg_to_rad(90.0)))
	_place("camp_trial_arch", Layout.place(Layout.TRIAL_AT + Vector3(-16.0, 0.08, 8.0), 0.0))
	_place("camp_call_box", Layout.place(Layout.SANDBOX_AT + Vector3(17.6, 0.0, -6.0), deg_to_rad(90.0)))
	var pen: Dictionary = Layout.station("pet")
	var home := socket("camp_pet_pen", "pet_home")
	_pet_home = to_local_point(home.origin) if has_socket("camp_pet_pen", "pet_home") else pen.at * 0.95
	_pet = _place("camp_pet", Layout.place(_pet_home, pen.yaw + 0.6))
	var toys := ["camp_toy_ball", "camp_toy_wrench", "camp_toy_tire"]
	for k in toys.size():
		var at: Vector3 = pen.at * 0.9 + Vector3(2.5 * cos(k * 2.1), 0.0, 2.5 * sin(k * 2.1))
		_seat(_place(toys[k], Layout.place(at, k * 1.3)))
	for row: Array in Layout.DRESSING:
		var p: Vector3 = Layout.at(row[1], row[2])
		_place(row[0], Layout.place(p, Layout.yaw_to_centre(p.x, p.z) + deg_to_rad(row[3])))


# Stands a loose piece's lowest drawn point on the plaza's collider below it (the plaza's top, not y 0: a fixed 0.3 m left
# the wrench floating 0.12 m and the tire in the plaza's lip; clip audit, 30 Oct). A piece with no plaza under it stays.
func _seat(holder: Node3D) -> void:
	if holder == null or not _pieces.has("camp_plaza"):
		return
	var foot := INF
	for view: MeshInstance3D in holder.find_children("*", "MeshInstance3D", true, false):
		if view.mesh != null:
			foot = minf(foot, (holder.transform * view.transform * view.mesh.get_aabb()).position.y)
	var top := plaza_top(Vector2(holder.position.x, holder.position.z))
	if foot < INF and top > -INF:
		holder.position.y += top - foot


# The plaza collider's highest face over local point at (x, z), -INF where none is.
func plaza_top(at: Vector2) -> float:
	var top := -INF
	var plaza: Node3D = _pieces["camp_plaza"]
	for shape: CollisionShape3D in plaza.find_children("*", "CollisionShape3D", true, false):
		var poly := shape.shape as ConcavePolygonShape3D
		if poly == null:
			continue
		var xf := plaza.transform * (shape.get_parent() as Node3D).transform * shape.transform
		var faces := poly.get_faces()
		for i in range(0, faces.size(), 3):
			var a := xf * faces[i]
			var b := xf * faces[i + 1]
			var c := xf * faces[i + 2]
			var hit = Geometry3D.ray_intersects_triangle(Vector3(at.x, 100.0, at.y), Vector3.DOWN, a, b, c)
			if hit != null:
				top = maxf(top, (hit as Vector3).y)
	return top


func to_local_point(global_point: Vector3) -> Vector3:
	return global_point - HUB_ORIGIN


# A picture-driven recipe prop (recipe_props.gd) at xf under root: its base views and shells, and for a solid one a hull
# collider round the first base mesh (a cabinet, a trunk) up to SOLID_TOP_M. A box round the whole mesh took a tree's
# boughs down to the ground: 8.4 by 6.6 m of invisible wall round a 1.2 m trunk (tools/qa/collision_sweep.gd, 30 Oct).
func _prop(key: String, xf: Transform3D, solid: bool) -> void:
	var holder := Node3D.new()
	holder.name = "Prop_" + key
	root.add_child(holder)
	holder.transform = xf
	var views := RecipeProps.base(key, holder, Transform3D.IDENTITY)
	RecipeProps.shells(key, holder, Transform3D.IDENTITY)
	if solid and not views.is_empty():
		var hull := solid_hull(views[0] as MeshInstance3D)
		if hull != null:
			var body := Recipes._body(holder)
			var shape := CollisionShape3D.new()
			shape.shape = hull
			body.add_child(shape)
	_pieces[key] = holder


# The hull of the first view's triangles cut at SOLID_TOP_M, in its holder's space (park_recipes.gd _band_hull), or null.
static func solid_hull(view: MeshInstance3D) -> ConvexPolygonShape3D:
	# A base view that is not a mesh, or carries none, has no hull: the piece stands without a solid.
	if view == null or view.mesh == null:
		return null
	var tris := PackedVector3Array()
	for v in view.mesh.get_faces():
		tris.append(view.transform * v)
	return Recipes._band_hull(tris, -INF, SOLID_TOP_M)


func _build_lights() -> void:
	for stem in LIGHTS:
		var row: Array = LIGHTS[stem]
		var kind: Dictionary = LIGHT_KINDS[row[1]]
		for holder: Node3D in root.get_children().filter(func(n): return n.name.begins_with(stem) and n is Node3D):
			for socket_name: String in row[0]:
				var marker := holder.get_node_or_null("Sockets/" + socket_name) as Node3D
				if marker == null or light_count >= MAX_LIGHTS:
					continue
				var light := OmniLight3D.new()
				light.name = "Light_" + socket_name
				light.light_color = kind.color
				light.light_energy = kind.energy
				light.omni_range = kind.range
				light.omni_attenuation = 1.2
				light.shadow_enabled = false
				holder.add_child(light)
				light.global_transform = Transform3D(Basis.IDENTITY, marker.global_position)
				light_count += 1


func _build_stations() -> void:
	var screens = game.screens
	var lift := Vector3(0.0, 0.0, 0.0)
	_station("gate", "camp_launch_gate", "launch_trigger", "Launch", "key_space", 3.0, lift, func(): game.launch_from_gate())
	_station("lockers", "camp_lockers", "interact", "Customize", "key_c", ZONE_RADIUS, lift, func(): screens.walk_customize())
	_station("moss", "camp_moss_stall", "interact", "Companion", "key_m", ZONE_RADIUS, lift, func(): screens.walk_companion())
	_station("settings", "camp_settings_console", "interact", "Settings", "key_s", ZONE_RADIUS, lift, func(): screens.toggle_settings())
	_station("achieve", "camp_trophy_wall", "interact", "Trophy wall", "key_a", ZONE_RADIUS, lift, func(): screens.toggle_achievements())
	var cabinet: Node3D = _pieces.get("moss_jukebox")
	if cabinet != null:
		add_station("jukebox", cabinet.global_position + Vector3(0.0, 1.0, 0.0), "Jukebox", "key_j", 3.0, func(): screens.toggle_jukebox())
	var console: Node3D = _pieces.get("camp_settings_console")
	if console != null:
		# The radio mast stands at the console's back left corner (stations.py console()).
		add_station("radio", console.global_transform * Vector3(-2.6, 1.0, -0.8), "Radio", "key_r", 3.0, func(): screens.toggle_radio())
	var pen: Node3D = _pieces.get("camp_pet_pen")
	if pen != null:
		add_zone("pet", pen.global_transform * Vector3(0.0, 1.0, 2.0), 6.0, _pet_react)


func _station(id: String, stem: String, socket_name: String, label: String, key: String, radius: float, offset: Vector3, on_press: Callable) -> void:
	if not has_socket(stem, socket_name):
		push_warning("camp_hub: %s has no %s socket, so the %s station stays out" % [stem, socket_name, label])
		return
	add_station(id, socket(stem, socket_name).origin + offset, label, key, radius, on_press)


# --- zones ---

func _make_zone(id: String, at: Vector3, radius: float) -> Area3D:
	var area := Area3D.new()
	area.name = "Zone_" + id
	area.collision_layer = 0
	area.collision_mask = 0
	area.set_collision_mask_value(Recipes.BALL_LAYER, true)
	area.monitorable = false
	area.monitoring = walking
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	area.add_child(shape)
	root.add_child(area)
	area.global_position = at
	area.body_entered.connect(_on_enter.bind(id))
	area.body_exited.connect(_on_exit.bind(id))
	return area


func _set_zones_monitoring(on: bool) -> void:
	for id in _zones:
		(_zones[id]["area"] as Area3D).set_deferred("monitoring", on)


func _is_ball(body: Node) -> bool:
	return body == ball.body()


func _on_enter(body: Node3D, id: String) -> void:
	if not walking or not _is_ball(body) or id in _inside:
		return
	_inside.append(id)
	var entered: Callable = _zones[id].get("enter", Callable())
	if entered.is_valid():
		entered.call()
	_refresh_prompts()
	station_entered.emit(id)


func _on_exit(body: Node3D, id: String) -> void:
	if not _is_ball(body) or not id in _inside:
		return
	_inside.erase(id)
	var left: Callable = _zones[id].get("exit", Callable())
	if left.is_valid():
		left.call()
	_refresh_prompts()
	station_left.emit(id)


# --- the prompt cards ---

func _build_prompts() -> void:
	_prompts = CanvasLayer.new()
	_prompts.name = "CampPrompts"
	_prompts.layer = 6
	_prompts.visible = false
	add_child(_prompts)
	_prompt_box = VBoxContainer.new()
	_prompt_box.name = "Cards"
	_prompt_box.alignment = BoxContainer.ALIGNMENT_END
	_prompt_box.add_theme_constant_override("separation", 8)
	_prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_box.anchor_left = 0.5
	_prompt_box.anchor_right = 0.5
	_prompt_box.anchor_top = 1.0
	_prompt_box.anchor_bottom = 1.0
	_prompt_box.offset_left = -160.0
	_prompt_box.offset_right = 160.0
	_prompt_box.offset_top = -190.0
	_prompt_box.offset_bottom = -110.0
	_prompts.add_child(_prompt_box)
	_clock = Label.new()
	_clock.name = "Clock"
	_clock.visible = false
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.anchor_left = 0.5
	_clock.anchor_right = 0.5
	_clock.offset_left = -140.0
	_clock.offset_right = 140.0
	_clock.offset_top = 18.0
	_clock.add_theme_font_override("font", UiFonts.mono())
	_clock.add_theme_font_size_override("font_size", 24)
	_clock.add_theme_color_override("font_color", Palette.SAND)
	_clock.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_clock.add_theme_constant_override("outline_size", 6)
	_prompts.add_child(_clock)


# The walk HUD's one-line clock, top centre, for a live trial lap; "" hides it.
func set_clock(text: String) -> void:
	if _clock == null:
		return
	_clock.text = text
	_clock.visible = text != ""


func clock_text() -> String:
	return _clock.text if _clock != null and _clock.visible else ""


func _refresh_prompts() -> void:
	if _prompt_box == null:
		return
	for child in _prompt_box.get_children():
		_prompt_box.remove_child(child)
		child.queue_free()
	_prompt_buttons.clear()
	for id in _inside:
		var zone: Dictionary = _zones[id]
		if zone["key"] == "":
			continue
		var card := ChoiceButton.new("station_" + id, zone["key"], zone["label"])
		card.name = "Card_" + id
		card.focus_mode = Control.FOCUS_NONE
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.pressed.connect(game.screens._press.bind(zone["key"]))
		_prompt_box.add_child(card)
		_prompt_buttons[id] = card


func card_for(id: String) -> Button:
	return _prompt_buttons.get(id)


# --- the pet ---

# Rolling into the pen: the pet hops toward the ball, turns to it and chirps (the companion's ready chirp).
func _pet_react() -> void:
	if _pet == null or not is_instance_valid(_pet):
		return
	pet_reactions += 1
	var to_ball: Vector3 = ball.ball_position() - _pet.global_position
	to_ball.y = 0.0
	var distance := to_ball.length()
	var heading := atan2(to_ball.x, to_ball.z)
	var step := to_ball.normalized() * clampf(distance - 3.0, 0.0, 3.0) if distance > 0.01 else Vector3.ZERO
	var start := _pet.position
	if _pet_tween != null and _pet_tween.is_valid():
		_pet_tween.kill()
	_pet.position = Vector3(_pet.position.x, 0.0, _pet.position.z)
	_pet_tween = _pet.create_tween()
	_pet_tween.set_parallel(false)
	_pet_tween.tween_property(_pet, "rotation:y", heading, 0.18)
	for hop in 2:
		var land := start + step * float(hop + 1) * 0.5
		_pet_tween.tween_property(_pet, "position", Vector3(land.x, 0.55, land.z), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_pet_tween.tween_property(_pet, "position", Vector3(land.x, 0.0, land.z), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var audio = game.audio()
	if audio != null:
		audio.chirp("primer_set")


# --- the crew round the fire ---

# Who stands this walk: every pilot the profile has freed, but the one the gate launches (the ball is them). A pilot
# is built at their spot the first walk they stand, and shown or hidden after.
func _stand_crew() -> void:
	var flying = game.gate_pilot() if game.has_method("gate_pilot") else null
	var classes: Array = game.flow.classes if game.flow != null else []
	for i in mini(classes.size(), CREW_SPOTS.size()):
		var def = classes[i]
		var stands: bool = def != flying and game.pilot_unlocked(def) and not LoreRows.camp_quip(String(def.id)).is_empty()
		var figure: Node3D = _crew.get(String(def.id))
		if stands and figure == null:
			figure = _build_figure(def, i)
		if figure != null:
			figure.visible = stands


# The pilots standing now, by class id.
func crew_standing() -> Array:
	return _crew.keys().filter(func(id): return (_crew[id] as Node3D).visible)


func crew_figure(class_id: String) -> Node3D:
	return _crew.get(class_id)


func crew_spot(index: int) -> Vector3:
	var spot: Array = CREW_SPOTS[index]
	return Layout.at(spot[0], spot[1])


# One pilot: the pilot's own model at rest (hero_assets.gd fit_pilot_into, as the title's deck builds them), painted in
# their colour, facing the fire, standing on the plaza, faded out past CREW_FADE_M, and their quip zone.
func _build_figure(def, index: int) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Crew_" + String(def.id)
	root.add_child(holder)
	var at := crew_spot(index)
	var fire := Layout.at(CREW_FIRE[0], CREW_FIRE[1])
	holder.transform = Layout.place(at, Layout.yaw_to_centre(at.x - fire.x, at.z - fire.z) + PI)
	var pod := Node3D.new()
	pod.name = "Pod"
	pod.scale = Vector3.ONE * CREW_SCALE
	holder.add_child(pod)
	var painter := HeroAssets.new()
	var fitted: Dictionary = painter.fit_pilot_into(pod, String(def.id), def.color)
	painter.free()
	if fitted.is_empty():
		holder.queue_free()
		return null
	var animator := fitted.animator as AnimationPlayer
	if animator != null:
		animator.stop()
		for skeleton: Skeleton3D in fitted.pilot.find_children("*", "Skeleton3D", true, false):
			skeleton.reset_bone_poses()
		if animator.has_animation(CREW_IDLE_CLIP):
			animator.play(CREW_IDLE_CLIP)
			animator.seek(fmod(CREW_OFFSET_S * index, animator.current_animation_length), true)
	for view: GeometryInstance3D in holder.find_children("*", "GeometryInstance3D", true, false):
		view.visibility_range_end = CREW_FADE_M
		view.visibility_range_end_margin = CREW_FADE_MARGIN_M
		view.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	holder.set_meta("animator", animator)
	_stand_on_plaza(holder)
	_crew[String(def.id)] = holder
	add_zone("crew_" + String(def.id), holder.global_position + Vector3.UP, CREW_ZONE_M, _quip_from.bind(String(def.id)))
	return holder


# Sets a figure's lowest drawn point on the plaza under it (or the sandstone disc's top where no plaza is). The figure's
# views sit deep under its holder, so this reads them in the hub's frame, where _seat reads direct children.
func _stand_on_plaza(holder: Node3D) -> void:
	var to_hub := root.global_transform.affine_inverse()
	var foot := INF
	for view: MeshInstance3D in holder.find_children("*", "MeshInstance3D", true, false):
		if view.mesh != null:
			foot = minf(foot, (to_hub * view.global_transform * view.mesh.get_aabb()).position.y)
	var top := plaza_top(Vector2(holder.position.x, holder.position.z)) if _pieces.has("camp_plaza") else -INF
	if foot < INF:
		holder.position.y += (top if top > -INF else 0.0) - foot


# The ball rolled up to a standing pilot: their line goes up on the plate, once a walk, and they turn to the ball.
func _quip_from(class_id: String) -> void:
	var figure: Node3D = _crew.get(class_id)
	if not walking or figure == null or not figure.visible or _quipped.has(class_id):
		return
	var row := LoreRows.camp_quip(class_id)
	if row.is_empty():
		return
	_quipped[class_id] = true
	var words := LoreRows.camp_quip_text(row, walks)
	var speaker := String(row["speaker"])
	_show_quip(speaker, words)
	_face_ball(figure)
	pilot_quipped.emit(speaker, String(row["id"]), words)


func _face_ball(figure: Node3D) -> void:
	var to_ball: Vector3 = ball.ball_position() - figure.global_position
	if Vector2(to_ball.x, to_ball.z).length() > 0.01:
		var turn := figure.create_tween()
		turn.tween_property(figure, "rotation:y", atan2(to_ball.x, to_ball.z), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var animator = figure.get_meta("animator", null)
	if animator is AnimationPlayer and (animator as AnimationPlayer).has_animation(CREW_TALK_CLIP):
		(animator as AnimationPlayer).play(CREW_TALK_CLIP)
		if (animator as AnimationPlayer).has_animation(CREW_IDLE_CLIP):
			(animator as AnimationPlayer).queue(CREW_IDLE_CLIP)


# --- the quip card: the caller plate (caller_tile.gd, the call-ins' own) beside a line, upper left ---

func _build_quip() -> void:
	_quip = Control.new()
	_quip.name = "Quip"
	_quip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quip.visible = false
	_quip.position = Vector2(28.0, 150.0)
	_prompts.add_child(_quip)
	var panel := PanelContainer.new()
	panel.name = "Line"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(CallerTile.SIDE - 10.0, 12.0)
	_quip.add_child(panel)
	_quip_label = Label.new()
	_quip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quip_label.custom_minimum_size = Vector2(QUIP_WIDTH, 0.0)
	_quip_label.add_theme_font_override("font", UiFonts.bold())
	_quip_label.add_theme_font_size_override("font_size", UiTokens.BODY)
	_quip_label.add_theme_color_override("font_color", Palette.SAND)
	_quip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_quip_label)
	_quip_tile = CallerTile.new()
	_quip_tile.name = "Caller"
	_quip.add_child(_quip_tile)


func _show_quip(speaker: String, words: String) -> void:
	if _quip == null:
		return
	CallerTile.reduced_motion = false
	_quip_tile.pilots = game.flow.classes if game.flow != null else []
	if not _quip_tile.present(speaker, String(LoreRows.SPEAKERS.get(speaker, speaker))):
		return
	var panel := _quip.get_node("Line") as PanelContainer
	var style := UiTokens.plate(_quip_tile.tint())
	style.content_margin_left = 24.0
	panel.add_theme_stylebox_override("panel", style)
	_quip_label.text = words
	_quip_hold = QUIP_HOLD_S + QUIP_PER_WORD_S * words.split(" ", false).size()
	if _quip_tween != null and _quip_tween.is_valid():
		_quip_tween.kill()
	_quip.modulate.a = 1.0
	_quip.visible = true


func _end_quip(now: bool) -> void:
	_quip_hold = 0.0
	if _quip == null or not _quip.visible:
		return
	if _quip_tween != null and _quip_tween.is_valid():
		_quip_tween.kill()
	if now:
		_quip.visible = false
		_quip_tile.clear()
		return
	_quip_tween = _quip.create_tween()
	_quip_tween.tween_property(_quip, "modulate:a", 0.0, QUIP_FADE_S)
	_quip_tween.tween_callback(func():
		_quip.visible = false
		_quip_tile.clear())


# The line on the plate now, "" when none is up; and who says it.
func quip_words() -> String:
	return _quip_label.text if _quip != null and _quip.visible else ""


func quip_caller() -> String:
	return String(_quip_tile.speaker) if _quip != null and _quip.visible else ""


# --- the records: found B-sides as sleeves in the bins by Moss's jukebox ---

# The bins and the sleeves are two MultiMeshes, one draw each, whatever the count. Each walk restocks them.
func _build_records() -> void:
	var cabinet: Node3D = _pieces.get("moss_jukebox")
	if cabinet == null:
		return
	var shelf := Node3D.new()
	shelf.name = "Records"
	cabinet.add_child(shelf)
	_bins = _multi("Bins", bin_mesh(), _record_material("record_bin", false), shelf)
	_sleeves = _multi("Sleeves", sleeve_mesh(), _record_material("record_sleeve", true), shelf)


func _multi(node_name: String, mesh: Mesh, material: Material, parent: Node3D) -> MultiMeshInstance3D:
	var view := MultiMeshInstance3D.new()
	view.name = node_name
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	view.multimesh = multi
	view.material_override = material
	parent.add_child(view)
	return view


# The B-sides the camp's records hold, in the order they were found: a jukebox record that is no rare pressing, or
# a radio take of the b-side tier (radio_takes.gd track).
func found_b_sides() -> Array:
	var ids: Array = camp_store.tune_ids() if camp_store != null and camp_store.has_method("tune_ids") else []
	return ids.filter(func(id): return String(RadioTakes.track(String(id)).get("tier", "")) == "b-side")


func shelved_records() -> Array:
	return _shelved.duplicate()


func _shelve_records() -> void:
	if _sleeves == null:
		return
	_shelved = found_b_sides().slice(0, BIN_SLOTS * BIN_MAX)
	var bins := clampi(ceili(float(_shelved.size()) / BIN_SLOTS), 1, BIN_MAX)
	_bins.multimesh.instance_count = bins
	for b in bins:
		_bins.multimesh.set_instance_transform(b, Transform3D(Basis.IDENTITY, BIN_AT + BIN_STEP * b))
		_bins.multimesh.set_instance_color(b, Color.WHITE)
	_sleeves.multimesh.instance_count = _shelved.size()
	var lean := Basis(Vector3.RIGHT, -SLEEVE_LEAN)
	for i in _shelved.size():
		var slot := i % BIN_SLOTS
		var bin_at := BIN_AT + BIN_STEP * floori(float(i) / BIN_SLOTS)
		var z := -BIN_SIZE.z * 0.5 + 0.08 + SLEEVE_STEP * slot
		# Each sleeve stands on the bin floor, its face to the jukebox's front, the next one behind it.
		var at := bin_at + Vector3(0.0, BIN_LIFT + 0.05, z)
		_sleeves.multimesh.set_instance_transform(i, Transform3D(lean, at))
		var id := String(_shelved[i])
		_sleeves.multimesh.set_instance_color(i, SLEEVE_INKS[absi(hash(id)) % SLEEVE_INKS.size()])


# A bin: an open crate, BIN_SIZE outside, its walls 4 cm, on four legs BIN_LIFT high, centred on x and z, feet at y 0.
static func bin_mesh() -> ArrayMesh:
	return RecipeProps.piece("camp_record_bin", func(st: SurfaceTool):
		var h := BIN_SIZE * 0.5
		var wall := 0.04
		var y0 := BIN_LIFT
		var tone := Color(0.82, 0.82, 0.82)
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg := Vector3(sx * (h.x - 0.05), 0.0, sz * (h.z - 0.05))
				RecipeProps.add_hull(st, RecipeProps.bevel_box(leg - Vector3(0.035, 0.0, 0.035), leg + Vector3(0.035, y0, 0.035), 0.008), tone)
		RecipeProps.add_hull(st, RecipeProps.bevel_box(Vector3(-h.x, y0, -h.z), Vector3(h.x, y0 + 0.05, h.z), 0.01), tone)
		for sx: float in [-1.0, 1.0]:
			var x0 := sx * h.x - wall * 0.5 - sx * wall * 0.5
			RecipeProps.add_hull(st, RecipeProps.bevel_box(Vector3(x0, y0, -h.z), Vector3(x0 + wall, y0 + BIN_SIZE.y, h.z), 0.012))
		for sz: float in [-1.0, 1.0]:
			var z0 := sz * h.z - wall * 0.5 - sz * wall * 0.5
			RecipeProps.add_hull(st, RecipeProps.bevel_box(Vector3(-h.x, y0, z0), Vector3(h.x, y0 + BIN_SIZE.y * (0.6 if sz > 0.0 else 1.0), z0 + wall), 0.012)))


# A sleeve: a thin square card, face +Z and -Z, standing on its bottom edge, a printed band across its face a shade
# darker, and the record's black edge showing over the top. One material, so the tint comes from the instance.
static func sleeve_mesh() -> ArrayMesh:
	return RecipeProps.piece("camp_record_sleeve", func(st: SurfaceTool):
		var s := SLEEVE_SIDE
		var t := 0.016
		RecipeProps.add_hull(st, RecipeProps.bevel_box(Vector3(-s * 0.5, 0.0, -t * 0.5), Vector3(s * 0.5, s, t * 0.5), 0.004))
		for face in [1.0, -1.0]:
			RecipeProps.add_hull(st, RecipeProps.bevel_box(Vector3(-s * 0.5 + 0.002, s * 0.58, face * t * 0.5 - 0.001), Vector3(s * 0.5 - 0.002, s * 0.7, face * t * 0.5 + 0.001), 0.0), Color(0.55, 0.55, 0.55))
		var disc := RecipeProps.prism(Vector3.ZERO, 16, s * 0.46, s * 0.46, -0.004, 0.004)
		RecipeProps.add_hull(st, disc, Color(0.07, 0.07, 0.08), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, s * 0.6, 0.0))))


static func _record_material(material_name: String, sleeve: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = material_name
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE if sleeve else Palette.COPPER.darkened(0.35)
	mat.roughness = 0.55 if sleeve else 0.85
	return mat
