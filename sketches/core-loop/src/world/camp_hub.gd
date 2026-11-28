extends Node


const Recipes := preload("res://src/world/park/park_recipes.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const Layout := preload("res://src/world/camp_layout.gd")
const Palette := preload("res://src/core/palette.gd")
const PhysicsLayers := preload("res://src/core/physics_layers.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const Glyphs := preload("res://src/ui/glyphs.gd")
const Bindings := preload("res://src/core/bindings.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const PilotStory := preload("res://src/core/pilot_story.gd")
const ScrapbookStore := preload("res://src/core/scrapbook_store.gd")
const RadioTakes := preload("res://src/core/radio_takes.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const CallerTile := preload("res://src/ui/caller_tile.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const WorldFxAnchor := preload("res://src/presentation/world_fx/world_fx_anchor.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const CampCraftMeshes := preload("res://src/presentation/craft/camp_craft_meshes.gd")

const FEATURES: Array = [
	preload("res://src/world/camp_skee.gd"),
	preload("res://src/world/camp_trial.gd"),
	preload("res://src/world/camp_sandbox.gd"),
	preload("res://src/ui/camp_enemy_picker.gd"),
	preload("res://src/world/camp_ring.gd"),
	preload("res://src/ui/camp_scrapbook.gd"),
]

const GLB_DIR := "res://assets/models/camp/"
const HUB_ORIGIN := Vector3(3000.0, 0.0, 3000.0)
const GROUND_R := 270.0
const GROUND_THICK := 4.0
const BERM_SEGMENTS := 72
const BERM_HEIGHT := 6.0
const BERM_DEPTH := 10.0
const BERM_STAGGER_M := 0.06
const SHELL_RANGES := [[150.0, 20.0], [60.0, 8.0]]
const ZONE_RADIUS := 2.5
const FALL_BELOW := -25.0
const MAX_LIGHTS := 24
const SOLID_TOP_M := 4.0
const SHELLED := ["camp_launch_gate", "camp_lockers", "camp_moss_stall", "camp_skee_lane"]
const ON_PLAZA := ["camp_shortcut", "camp_skee_lane", "camp_trial_track"]
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

const CREW_SPOTS := [[148.0, 12.0], [172.0, 12.0], [138.0, 16.5], [182.0, 16.5], [160.0, 21.5], [160.0, 9.6]]
const CREW_ZONE_M := 6.0
const CREW_SCALE := 1.6
const CREW_FIRE := [160.0, 15.0]
const CREW_FADE_M := 80.0
const CREW_FADE_MARGIN_M := 10.0
const CREW_IDLE_CLIP := "idle_loop"
const CREW_TALK_CLIP := "big_cheer"
const CREW_OFFSET_S := 0.7
const QUIP_HOLD_S := 2.2
const QUIP_PER_WORD_S := 0.28
const QUIP_FADE_S := 0.3
const QUIP_WIDTH := 330.0
const BIN_AT := Vector3(1.9, 0.0, 0.9)
const BIN_LIFT := 0.55
const BIN_STEP := Vector3(0.0, 0.0, 1.35)
const BIN_SLOTS := 24
const BIN_MAX := 3
const BIN_SIZE := Vector3(0.66, 0.3, 1.2)
const SLEEVE_SIDE := 0.5
const SLEEVE_STEP := 0.045
const SLEEVE_LEAN := 0.16
const SLEEVE_INKS := [Palette.COPPER, Palette.BRASS, Palette.VERDIGRIS, Palette.OLD_VERDIGRIS, Palette.SAND,
	Palette.LEDGER_CREAM, Palette.SLATE, Palette.TURQUOISE, Palette.APRICOT, Palette.SODIUM, Palette.RUST]

signal walk_entered
signal walk_left
signal station_entered(id: String)
signal station_left(id: String)
signal pilot_quipped(speaker: String, row_id: String, words: String)

var game
var ball
var camp_store
var root: Node3D
var built := false
var walking := false
var pet_reactions := 0
var light_count := 0
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
var _crew := {}
var _quipped := {}
var _pair_played_this_walk := false
var _quip: Control
var _quip_tile
var _quip_label: Label
var _quip_hold := 0.0
var _quip_tween: Tween
var _bins: MultiMeshInstance3D
var _sleeves: MultiMeshInstance3D
var _shelved: Array = []
var _prompt_device := ""
var _prompt_interact := ""


func setup(game_ref) -> void:
	name = "CampHub"
	game = game_ref
	ball = game.player
	process_mode = Node.PROCESS_MODE_PAUSABLE


func piece(id: String) -> Node3D:
	return _pieces.get(id)


var _missing_sockets := {}

func socket(id: String, socket_name: String) -> Transform3D:
	var holder: Node3D = _pieces.get(id)
	if holder == null:
		return Transform3D.IDENTITY
	var marker := holder.get_node_or_null("Sockets/" + socket_name) as Node3D
	if marker == null:
		if not _missing_sockets.has(id + "/" + socket_name):
			_missing_sockets[id + "/" + socket_name] = true
			push_warning("camp_hub: %s has no socket %s; placing at the origin" % [id, socket_name])
		return Transform3D.IDENTITY
	return marker.global_transform


func has_socket(id: String, socket_name: String) -> bool:
	var holder: Node3D = _pieces.get(id)
	return holder != null and holder.get_node_or_null("Sockets/" + socket_name) != null


func add_station(id: String, at: Vector3, label: String, key: String, radius: float, on_press: Callable) -> void:
	var verb := key if Bindings.VERBS.has(key) else ""
	var glyph := _verb_glyph(verb) if verb != "" else key
	_zones[id] = {"label": label, "key": glyph, "verb": verb, "on_press": on_press, "area": _make_zone(id, at, radius), "enter": Callable()}


func _verb_glyph(verb: String) -> String:
	return Glyphs.of(verb)


func _zone_glyph(zone: Dictionary) -> String:
	var verb := String(zone.get("verb", ""))
	if verb != "":
		var glyph := _verb_glyph(verb)
		zone["key"] = glyph
		return glyph
	return String(zone.get("key", ""))


func _zone_keycode(zone: Dictionary) -> int:
	var verb := String(zone.get("verb", ""))
	if verb != "" and Bindings.VERBS.has(verb):
		var actions: Dictionary = Bindings.VERBS[verb]["actions"]
		var action := String(actions.keys()[0])
		if InputMap.has_action(action):
			for event in InputMap.action_get_events(action):
				if event is InputEventKey:
					var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
					if code != KEY_NONE:
						return code
	var glyph := _zone_glyph(zone)
	return OS.find_keycode_from_string(Keycap.label(glyph)) if glyph != "" else KEY_NONE


func _zone_matches_key(zone: Dictionary, keycode: int) -> bool:
	if keycode == KEY_NONE:
		return false
	var verb := String(zone.get("verb", ""))
	if verb != "" and Bindings.VERBS.has(verb):
		var actions: Dictionary = Bindings.VERBS[verb]["actions"]
		var action := String(actions.keys()[0])
		if InputMap.has_action(action):
			var saw_key := false
			for event in InputMap.action_get_events(action):
				if event is InputEventKey:
					saw_key = true
					var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
					if code == keycode:
						return true
			if saw_key:
				return false
	return _zone_keycode(zone) == keycode


func set_label(id: String, label: String) -> void:
	if not _zones.has(id) or _zones[id]["label"] == label:
		return
	_zones[id]["label"] = label
	_refresh_prompts()


func add_zone(id: String, at: Vector3, radius: float, on_enter := Callable(), on_exit := Callable()) -> void:
	_zones[id] = {"label": "", "key": "", "verb": "", "on_press": Callable(), "area": _make_zone(id, at, radius), "enter": on_enter, "exit": on_exit}


func zone_ids() -> Array:
	return _zones.keys()


func zone_position(id: String) -> Vector3:
	var area: Area3D = _zones[id]["area"]
	return area.global_position


func inside_ids() -> Array[String]:
	return _inside


func inside(id: String) -> bool:
	return id in _inside


func confirm_key() -> int:
	for id in _inside:
		var zone: Dictionary = _zones[id]
		if _zone_glyph(zone) != "":
			return _zone_keycode(zone)
	return KEY_NONE


func press_key(keycode: int) -> bool:
	for id in _inside:
		var zone: Dictionary = _zones[id]
		if _zone_glyph(zone) != "" and _zone_matches_key(zone, keycode):
			var press: Callable = zone["on_press"]
			if press.is_valid():
				press.call()
			return true
	return false


func press_station(id: String) -> bool:
	if not walking or not (id in _inside) or not _zones.has(id):
		return false
	var press: Callable = _zones[id]["on_press"]
	if press.is_valid():
		press.call()
		return true
	return false


func _input(event: InputEvent) -> void:
	if not _takes_station_input():
		return
	var id := _station_for(event)
	if id != "" and press_station(id):
		get_viewport().set_input_as_handled()


func _takes_station_input() -> bool:
	if not walking or game == null or game.screens == null or not game.screens.walk_live():
		return false
	var take = game.get("launch_take")
	return take == null or not take.busy()


func _station_for(event: InputEvent) -> String:
	var interact := event.is_action_pressed("cl_interact")
	var pad := event as InputEventJoypadButton
	var pad_launch := pad != null and pad.pressed and (pad.button_index == JOY_BUTTON_A or pad.is_action_pressed("cl_jump"))
	if not interact and not pad_launch:
		return ""
	for id in _inside:
		var zone: Dictionary = _zones[id]
		if _zone_glyph(zone) == "":
			continue
		if interact and String(zone.get("verb", "")) == "interact":
			return id
		if pad_launch and id == "gate":
			return id
	return ""


func prompt_words() -> Array:
	var out := []
	for id in _inside:
		if _zone_glyph(_zones[id]) != "":
			out.append(_zones[id]["label"])
	return out


func prompts_shown() -> bool:
	return _prompts != null and _prompts.visible and _prompt_box.get_child_count() > 0


func set_prompts_visible(shown: bool) -> void:
	if _prompts != null:
		_prompts.visible = shown and walking


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
	_pair_played_this_walk = false
	_cached_journal_pages_ready = false
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


var _pet_idle := 0.0


func _process(delta: float) -> void:
	if _quip_hold > 0.0:
		_quip_hold -= delta
		if _quip_hold <= 0.0:
			_end_quip(false)
	if walking and not _inside.is_empty():
		var now_interact := Glyphs.of("interact")
		if Glyphs.device != _prompt_device or now_interact != _prompt_interact:
			_refresh_prompts()
	if walking and is_instance_valid(_pet) and (_pet_tween == null or not _pet_tween.is_valid()):
		if EnemyMotion.motion_scale > 0.0:
			_pet_idle += delta
			var breath := sin(_pet_idle * 3.1) * 0.045 * EnemyMotion.motion_scale
			_pet.scale = Vector3(1.0 - breath * 0.5, 1.0 + breath, 1.0 - breath * 0.5)
		else:
			_pet.scale = Vector3.ONE


func _physics_process(_delta: float) -> void:
	if not walking:
		return
	if game.player.ball_position().y < HUB_ORIGIN.y + FALL_BELOW:
		_place_ball()


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


func _place(stem: String, xf: Transform3D, with_shells := false, key := "") -> Node3D:
	var path := ModelVariants.path(GLB_DIR + stem + ".glb")
	var scenes := Recipes.load_glb(path)
	if scenes.is_empty():
		push_warning("camp_hub: %s is missing, it stays out" % path)
		return null
	var scene: Node = scenes[0]
	var holder := Node3D.new()
	holder.name = stem if key == "" else key
	root.add_child(holder)
	holder.transform = xf
	var body := Recipes.collider_body(holder)
	Recipes.attach_views(scene, holder, body, Transform3D.IDENTITY)
	if with_shells:
		for k in 2:
			var shell_scenes := Recipes.load_glb(GLB_DIR + "%s_detail%d.glb" % [stem, k + 1])
			for shell: Node in shell_scenes:
				for view in Recipes.attach_views(shell, holder, body, Transform3D.IDENTITY):
					Recipes.set_visibility_range(view, 0.0, SHELL_RANGES[k][0], SHELL_RANGES[k][1])
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
		marker.transform = Recipes.relative_transform(node, scene)
	scene.free()
	if ON_PLAZA.has(stem):
		Recipes.lift_drawn(holder, Recipes.SURFACE_LAYER_M)
	if not _pieces.has(stem):
		_pieces[stem] = holder
	return holder


func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "CampGround"
	ground.collision_layer = PhysicsLayers.NONE
	ground.collision_mask = PhysicsLayers.NONE
	ground.set_collision_layer_value(PhysicsLayers.WORLD_LAYER, true)
	root.add_child(ground)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = GROUND_R
	cylinder.height = GROUND_THICK
	shape.shape = cylinder
	shape.position.y = -GROUND_THICK * 0.5
	ground.add_child(shape)
	var disc := MeshInstance3D.new()
	disc.name = "SandstoneDisc"
	disc.mesh = CampCraftMeshes.sandstone_plaza_mesh(GROUND_R, GROUND_THICK, 96)
	disc.material_override = CampCraftMeshes.sandstone_material()
	disc.position.y = -GROUND_THICK * 0.5 - Recipes.SURFACE_LAYER_M * 3.0
	ground.add_child(disc)
	var chord := TAU * GROUND_R / BERM_SEGMENTS * 1.08
	for i in BERM_SEGMENTS:
		var angle := TAU * i / BERM_SEGMENTS
		var tall := BERM_HEIGHT + BERM_STAGGER_M * float(i % 2)
		var at := Vector3(sin(angle) * (GROUND_R - BERM_DEPTH * 0.5), tall * 0.5, -cos(angle) * (GROUND_R - BERM_DEPTH * 0.5))
		var segment := Transform3D(Basis(Vector3.UP, -angle), at)
		var box := BoxShape3D.new()
		box.size = Vector3(chord, tall, BERM_DEPTH)
		var collider := CollisionShape3D.new()
		collider.shape = box
		collider.transform = segment
		ground.add_child(collider)
	var berm_ring := MeshInstance3D.new()
	berm_ring.name = "CampBermRing"
	berm_ring.mesh = CampCraftMeshes.perimeter_berm_mesh(GROUND_R, BERM_SEGMENTS, BERM_HEIGHT, BERM_DEPTH, BERM_STAGGER_M)
	berm_ring.material_override = CampCraftMeshes.berm_material()
	ground.add_child(berm_ring)


func _place_layout() -> void:
	_place("camp_plaza", Transform3D.IDENTITY)
	_place("camp_shortcut", Layout.place(Layout.SHORTCUT_AT, 0.0))
	var glbs := {"gate": "camp_launch_gate", "lockers": "camp_lockers", "achieve": "camp_trophy_wall",
		"settings": "camp_settings_console", "skee": "camp_skee_lane", "pet": "camp_pet_pen", "moss": "camp_moss_stall"}
	for sid in glbs:
		var st: Dictionary = Layout.station(sid)
		_place(glbs[sid], Layout.place(st.at, st.yaw), glbs[sid] in SHELLED)
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
	var camp_fx := WorldFxAnchor.make("camp")
	if camp_fx != null:
		camp_fx.name = "CampFireFx"
		root.add_child(camp_fx)
		if has_socket("camp_fire_pit", "light_0"):
			camp_fx.position = to_local_point(socket("camp_fire_pit", "light_0").origin)
		elif _pieces.has("camp_fire_pit"):
			camp_fx.position = (_pieces["camp_fire_pit"] as Node3D).position + Vector3(0.0, 0.5, 0.0)


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
			var body := Recipes.collider_body(holder)
			var shape := CollisionShape3D.new()
			shape.shape = hull
			body.add_child(shape)
	_pieces[key] = holder


static func solid_hull(view: MeshInstance3D) -> ConvexPolygonShape3D:
	if view == null or view.mesh == null:
		return null
	var tris := PackedVector3Array()
	for v in view.mesh.get_faces():
		tris.append(view.transform * v)
	return Recipes.band_hull(tris, -INF, SOLID_TOP_M)


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
		add_station("radio", console.global_transform * Vector3(-2.6, 1.0, -0.8), "Radio", "key_r", 3.0, func(): screens.toggle_radio())
	var board: Node3D = _pieces.get("camp_shift_board")
	if board != null:
		add_station("dispatch", board.global_position + Vector3(0.0, 1.0, 0.0), "Work orders", "key_o", 3.5, func(): screens.toggle_work_orders())
	var tarp: Node3D = _pieces.get("camp_tarp")
	if tarp != null:
		add_station("logbook", tarp.global_position + Vector3(0.0, 1.0, 0.0), "Logbook", "key_l", 3.5, func(): screens.toggle_logbook())
	var pen: Node3D = _pieces.get("camp_pet_pen")
	if pen != null:
		add_zone("pet", pen.global_transform * Vector3(0.0, 1.0, 2.0), 6.0, _pet_react)


func _station(id: String, stem: String, socket_name: String, label: String, key: String, radius: float, offset: Vector3, on_press: Callable) -> void:
	if not has_socket(stem, socket_name):
		push_warning("camp_hub: %s has no %s socket, so the %s station stays out" % [stem, socket_name, label])
		return
	add_station(id, socket(stem, socket_name).origin + offset, label, key, radius, on_press)


func _make_zone(id: String, at: Vector3, radius: float) -> Area3D:
	var area := Area3D.new()
	area.name = "Zone_" + id
	area.collision_layer = PhysicsLayers.NONE
	area.collision_mask = PhysicsLayers.NONE
	area.set_collision_mask_value(PhysicsLayers.BALL_LAYER, true)
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
	_prompt_device = Glyphs.device
	_prompt_interact = Glyphs.of("interact")
	for child in _prompt_box.get_children():
		_prompt_box.remove_child(child)
		child.queue_free()
	_prompt_buttons.clear()
	for id in _inside:
		var zone: Dictionary = _zones[id]
		var glyph := _zone_glyph(zone)
		if glyph == "":
			continue
		var card := ChoiceButton.new("station_" + id, glyph, zone["label"])
		card.name = "Card_" + id
		card.focus_mode = Control.FOCUS_NONE
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if String(zone.get("verb", "")) != "":
			card.pressed.connect(press_station.bind(id))
		else:
			card.pressed.connect(game.screens._press.bind(glyph))
		_prompt_box.add_child(card)
		_prompt_buttons[id] = card


func card_for(id: String) -> Button:
	return _prompt_buttons.get(id)


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
	_pet.scale = Vector3.ONE
	_pet_tween = _pet.create_tween()
	_pet_tween.set_parallel(false)
	var squashed := Vector3(1.16, 0.82, 1.16)
	var stretched := Vector3(0.88, 1.18, 0.88)
	var motion_on := EnemyMotion.motion_scale > 0.0
	_pet_tween.tween_property(_pet, "rotation:y", heading, 0.16)
	if motion_on:
		_pet_tween.parallel().tween_property(_pet, "scale", squashed, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for hop in 2:
		var land := start + step * float(hop + 1) * 0.5
		_pet_tween.tween_property(_pet, "position", Vector3(land.x, 0.58, land.z), 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if motion_on:
			_pet_tween.parallel().tween_property(_pet, "scale", stretched, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_pet_tween.tween_property(_pet, "position", Vector3(land.x, 0.0, land.z), 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if motion_on:
			_pet_tween.parallel().tween_property(_pet, "scale", squashed, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if motion_on:
		_pet_tween.tween_property(_pet, "scale", Vector3.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(root):
		FxLibrary.burst(root, "brass_spark", _pet.global_position + Vector3.UP * 0.8, 8, Palette.BRASS)
		FxLibrary.burst(root, "steam_puff", _pet.global_position + Vector3.UP * 0.2, 4)
	var audio = game.audio()
	if audio != null:
		audio.chirp("primer_set")


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
			_zones["crew_" + String(def.id)]["area"].set_deferred("monitoring", stands)
			_face_fire(figure)


func crew_standing() -> Array:
	return _crew.keys().filter(func(id): return (_crew[id] as Node3D).visible)


func crew_figure(class_id: String) -> Node3D:
	return _crew.get(class_id)


func crew_spot(index: int) -> Vector3:
	var spot: Array = CREW_SPOTS[index]
	return Layout.at(spot[0], spot[1])


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
	holder.set_meta("rest_yaw", holder.rotation.y)
	_stand_on_plaza(holder)
	_crew[String(def.id)] = holder
	add_zone("crew_" + String(def.id), holder.global_position + Vector3.UP, CREW_ZONE_M, _quip_from.bind(String(def.id)))
	return holder


func _stand_on_plaza(holder: Node3D) -> void:
	var to_hub := root.global_transform.affine_inverse()
	var foot := INF
	for view: MeshInstance3D in holder.find_children("*", "MeshInstance3D", true, false):
		if view.mesh != null:
			foot = minf(foot, (to_hub * view.global_transform * view.mesh.get_aabb()).position.y)
	var top := plaza_top(Vector2(holder.position.x, holder.position.z)) if _pieces.has("camp_plaza") else -INF
	if foot < INF:
		holder.position.y += (top if top > -INF else 0.0) - foot


func _quip_from(class_id: String) -> void:
	var figure: Node3D = _crew.get(class_id)
	if not walking or figure == null or not figure.visible or _quipped.has(class_id):
		return
	var flying_def = game.gate_pilot() if game != null and game.has_method("gate_pilot") else null
	var flying_id := String(flying_def.id) if flying_def != null else ""
	var codex = game.get("codex") if game != null else null
	var pair_blocked: bool = _pair_played_this_walk or (game != null and game.get("bot_driven") == true)
	var pages := _journal_pages()
	var beat := PilotStory.pick_camp_beat(flying_id, class_id, crew_standing(), camp_store, codex, pages, walks, pair_blocked)
	if beat.is_empty():
		return
	_quipped[class_id] = true
	if bool(beat.get("consumes_pair_budget", false)):
		_pair_played_this_walk = true
		var cid := String(beat.get("codex_id", ""))
		if cid != "" and codex != null and codex.has_method("mark_known"):
			codex.mark_known(cid)
		var skey := String(beat.get("settle_key", ""))
		if skey != "" and camp_store != null and camp_store.has_method("settle"):
			camp_store.settle(skey)
	var lines: Array = beat.get("lines", [])
	var speaker := String(beat.get("speaker", lines[0]["speaker"] if not lines.is_empty() else ""))
	var words := String(beat.get("text", lines[0]["text"] if not lines.is_empty() else ""))
	if lines.size() > 1:
		var second: Dictionary = lines[1]
		var reply_who := String(LoreRows.SPEAKERS.get(String(second["speaker"]), String(second["speaker"])))
		words = "%s\n%s: %s" % [String(lines[0]["text"]), reply_who, String(second["text"])]
	var audio = game.audio() if game != null and game.has_method("audio") else null
	var voice_s: float = audio.call_in("camp_quip", speaker, words) if audio != null else 0.0
	_show_quip(speaker, words, voice_s)
	_face_ball(figure)
	pilot_quipped.emit(speaker, String(beat["id"]), words)


var _cached_journal_pages: Array = []
var _cached_journal_pages_ready := false


func _journal_pages() -> Array:
	if _cached_journal_pages_ready:
		return _cached_journal_pages
	_cached_journal_pages_ready = true
	var dir: String = game.storage_dir if game != null and game.get("storage_dir") != null else ""
	if dir == "":
		_cached_journal_pages = []
	else:
		_cached_journal_pages = ScrapbookStore.new(dir).summaries()
	return _cached_journal_pages


func _face_ball(figure: Node3D) -> void:
	var to_ball: Vector3 = root.global_basis.inverse() * (ball.ball_position() - figure.global_position)
	if Vector2(to_ball.x, to_ball.z).length() > 0.01:
		var heading := atan2(-to_ball.x, -to_ball.z)
		_turn(figure).tween_property(figure, "rotation:y", figure.rotation.y + angle_difference(figure.rotation.y, heading), 0.25) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var animator = figure.get_meta("animator") if figure.has_meta("animator") else null
	if animator is AnimationPlayer and (animator as AnimationPlayer).has_animation(CREW_TALK_CLIP):
		(animator as AnimationPlayer).play(CREW_TALK_CLIP)
		if (animator as AnimationPlayer).has_animation(CREW_IDLE_CLIP):
			(animator as AnimationPlayer).queue(CREW_IDLE_CLIP)


func _face_fire(figure: Node3D) -> void:
	_turn(figure).kill()
	figure.rotation.y = float(figure.get_meta("rest_yaw", figure.rotation.y))


func _turn(figure: Node3D) -> Tween:
	var last = figure.get_meta("turn") if figure.has_meta("turn") else null
	if last is Tween and (last as Tween).is_valid():
		(last as Tween).kill()
	var turn := figure.create_tween()
	figure.set_meta("turn", turn)
	return turn


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


func _show_quip(speaker: String, words: String, voice_s := 0.0) -> void:
	if _quip == null:
		return
	_quip_tile.pilots = game.flow.classes if game.flow != null else []
	if not _quip_tile.present(speaker, String(LoreRows.SPEAKERS.get(speaker, speaker)), voice_s):
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


func quip_words() -> String:
	return _quip_label.text if _quip != null and _quip.visible else ""


func quip_caller() -> String:
	return String(_quip_tile.speaker) if _quip != null and _quip.visible else ""


func _build_records() -> void:
	var cabinet: Node3D = _pieces.get("moss_jukebox")
	if cabinet == null:
		return
	var shelf := Node3D.new()
	shelf.name = "Records"
	cabinet.add_child(shelf)
	_bins = _multi("Bins", bin_mesh(), _record_material("record_bin", false), shelf)
	_sleeves = _multi("Sleeves", sleeve_mesh(), _record_material("record_sleeve", true), shelf)
	_sleeves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
		var at := bin_at + Vector3(0.0, BIN_LIFT + 0.05, z)
		_sleeves.multimesh.set_instance_transform(i, Transform3D(lean, at))
		_sleeves.multimesh.set_instance_color(i, sleeve_ink(String(_shelved[i])))


static func sleeve_ink(id: String) -> Color:
	return SLEEVE_INKS[absi(hash(id)) % SLEEVE_INKS.size()]


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
