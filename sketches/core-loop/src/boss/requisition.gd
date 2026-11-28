extends Node3D

const AppShell := preload("res://src/core/app_shell.gd")
const Palette := preload("res://src/core/palette.gd")
const Target := preload("res://src/boss/boss_target.gd")
const ChaseCamera := preload("res://src/movement/chase_camera.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const BossModel := preload("res://src/boss/boss_model.gd")
const BakeLook := preload("res://src/presentation/bake_look.gd")
const InkOutline := preload("res://src/presentation/ink_outline.gd")
const EnemyBossCraft := preload("res://src/presentation/craft/enemy_boss_craft.gd")
const PropMotionRig := preload("res://src/presentation/prop_motion_rig.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const Comfort := preload("res://src/core/comfort.gd")

const HULL := Vector3(9.0, 5.0, 14.0)
const DECK := 5.0
const CAP_SPOTS := [Vector3(0.0, 5.4, -4.5), Vector3(-2.6, 5.4, 0.8), Vector3(2.6, 5.4, 0.8)]
const CRANE_PIVOTS := [Vector3(-4.5, 7.5, -2.0), Vector3(4.5, 7.5, 2.0)]
const MAGNET_REST := 6.0
const MAGNET_HANG := 4.5
const CAP_SIZE := Vector3(2.2, 0.8, 2.2)
const PLATE_REACH := 160.0
const PLATE_LIFT := DECK + 4.0
const CUTAWAY_TRANSPARENCY := 0.88
const CUTAWAY_COLUMN := 12.0
const CUTAWAY_MARGIN := 1.0
const MODEL := "res://assets/models/bosses/boss_brindle.glb"
const SCOOTER_MODEL := "res://assets/models/bosses/boss_brindle_scooter.glb"
static var model_path := MODEL
static var scooter_path := SCOOTER_MODEL


static func reset_for_tests() -> void:
	drop_ahead()
	model_path = MODEL
	scooter_path = SCOOTER_MODEL
const BODY_PARTS := ["Hull", "BowRam", "CockpitShield", "CraneMasts", "CraneElbowPort", "CraneElbowStarboard", "DeckDressing",
	"Armour0", "Armour1", "Armour2", "Armour3"]
const FITTING_PARTS := ["DrumL0", "DrumL1", "DrumL2", "DrumL3", "DrumR0", "DrumR1", "DrumR2", "DrumR3", "HatchL", "HatchR"]
const MODEL_PARTS := ["Hull", "CockpitShield", "CraneMasts", "CranePort", "CraneStarboard", "CableSpans", "MagnetSocketPort",
	"MagnetSocketStarboard", "MagnetPort", "MagnetStarboard", "Cap0", "Cap1", "Cap2", "Armour0", "Armour1", "Armour2", "Armour3"]

var hull
var magnets: Array = []
var caps: Array = []
var heading := Vector3.FORWARD
var plate: WorldPrompt

var _cables: Array = []
var _magnet_mats: Array = []
var _cap_meshes: Array = []
var _plates: Array = []
var _cockpit: MeshInstance3D
var _hull_prim_mat: StandardMaterial3D
var model: Node3D
var _prims: Array = []
var _anim: AnimationPlayer
var _cue_key := ""
var _plate_mats: Array = []
var _cap_mats: Array = []
var _model_cranes: Array = []
var _model_armour: Array = []
var _model_magnets: Array = []
var _model_magnet_meshes: Array = []
var _model_bow_ram: MeshInstance3D
var _model_hull: MeshInstance3D
var _model_shield: Node3D
var _bracing := false
var _strike_flash_left := 0.0
var _strike_flash_duration := 0.22
var _strike_flash_color := Palette.HAZARD
var _pending_hides := {}
var _drawn_parts: Array = []
var _camera_bodies: Array = []
var _shoved_rider: Node3D
var _magnet_visuals: Array = []
var _magnet_rigs: Array[PropMotionRig] = []
var _magnet_prev_pos: Array[Vector3] = []
var _magnet_pos_ready: Array[bool] = []


func build(boss) -> void:
	name = "Requisition"
	var legacy_box_seam := model_path != MODEL and not ResourceLoader.exists(model_path)
	hull = Target.new()
	hull.setup(boss, "hull", "hull", HULL, Vector2(6.0, 3.0))
	hull.position = Vector3.UP * HULL.y * 0.5
	add_child(hull)
	hull.body_boxes = drawn_boxes
	_hull_prim_mat = Palette.solid(Palette.RUST)
	if legacy_box_seam:
		_box(hull, HULL, _hull_prim_mat, Vector3.ZERO)
	else:
		_craft_part(hull, EnemyBossCraft.brindle_hull_mesh(HULL), _hull_prim_mat, Vector3.ZERO, "BrindleHullCraft")
	for side in [-1.0, 1.0]:
		for z in [-3.5, 3.5]:
			var plate_mat := EnemyBossCraft.brindle_armour_material(Target.SLATE)
			hull.tint_with(plate_mat)
			_plate_mats.append(plate_mat)
			var plate_size := Vector3(0.4, 3.2, 6.0)
			var plate_at := Vector3(side * (HULL.x * 0.5 + 0.2), 0.3, z)
			if legacy_box_seam:
				_plates.append(_box(hull, plate_size, plate_mat, plate_at))
			else:
				_plates.append(_craft_part(hull, EnemyBossCraft.brindle_armour_plate(plate_size), plate_mat, plate_at, "BrindleArmourCraft"))
	if legacy_box_seam:
		_cockpit = _box(self, Vector3(3.0, 2.2, 3.0), Palette.water(Palette.ARC), Vector3(0.0, DECK + 1.1, 4.8))
		_box(self, Vector3(1.2, 1.0, 1.0), Palette.solid(Palette.AMBER, 0.4), Vector3(0.0, DECK + 1.0, 4.8))
	else:
		_cockpit = _craft_part(self, EnemyBossCraft.brindle_cockpit_canopy(Vector3(3.0, 2.2, 3.0)), Palette.water(Palette.ARC), Vector3(0.0, DECK + 1.1, 4.8), "BrindleCockpitCraft")
		_craft_part(self, EnemyBossCraft.brindle_cockpit_console(Vector3(1.2, 1.0, 1.0)), EnemyBossCraft.craft_shader_material("brindle_console", "plasma_conduit_core", Palette.CHARCOAL, Palette.COPPER, 0.62, 0.35, Palette.AMBER, 0.9), Vector3(0.0, DECK + 1.0, 4.8), "BrindleConsoleCraft")
	for i in CAP_SPOTS.size():
		var cap = Target.new()
		cap.setup(boss, "cap", "cap_%d" % (i + 1), CAP_SIZE, Vector2(1.2, 1.2))
		cap.position = CAP_SPOTS[i]
		add_child(cap)
		var mat := Palette.solid(Palette.CHARCOAL)
		cap.tint_with(mat)
		_cap_mats.append(mat)
		if legacy_box_seam:
			_cap_meshes.append(_cylinder(cap, 1.1, CAP_SIZE.y, mat))
		else:
			_cap_meshes.append(_craft_part(cap, EnemyBossCraft.brindle_vent_cap(1.1, CAP_SIZE.y), mat, Vector3.ZERO, "BrindleCapCraft%d" % i))
		caps.append(cap)
	for i in CRANE_PIVOTS.size():
		if legacy_box_seam:
			_box(self, Vector3(0.8, 3.0, 0.8), Palette.solid(Palette.COPPER), CRANE_PIVOTS[i] - Vector3.UP * 1.5)
		else:
			_craft_part(self, EnemyBossCraft.brindle_crane_post(Vector3(0.8, 3.0, 0.8)), EnemyBossCraft.craft_shader_material("brindle_crane_post", "oxidized_hull_plating", Palette.COPPER, Palette.RUST, 0.64, 0.40), CRANE_PIVOTS[i] - Vector3.UP * 1.5, "BrindleCranePost%d" % i)
		var magnet = Target.new()
		magnet.setup(boss, "magnet", "magnet_%s" % ["port", "starboard"][i], Vector3.ZERO, Vector2(1.5, 1.5))
		add_child(magnet)
		var mat := Palette.solid(Palette.VERDIGRIS)
		_magnet_mats.append(mat)
		var mag_visual: MeshInstance3D
		if legacy_box_seam:
			mag_visual = _cylinder(magnet, 1.4, 0.9, mat)
		else:
			mag_visual = _craft_part(magnet, EnemyBossCraft.brindle_magnet_housing(1.4, 0.9), mat, Vector3.ZERO, "BrindleMagnetCraft%d" % i)
		_magnet_visuals.append(mag_visual)
		magnets.append(magnet)
		var cable := MeshInstance3D.new()
		cable.name = "CableSpan%d" % i
		cable.mesh = _cable_mesh()
		var cable_mat := Palette.solid(Palette.CHARCOAL)
		cable_mat.vertex_color_use_as_albedo = true
		Palette.surface_grain(cable_mat)
		cable.material_override = cable_mat
		add_child(cable)
		_cables.append(cable)
	_dress()
	_bind_magnet_rigs()
	plate = WorldPrompt.new()
	plate.name = "BrindlePlate"
	plate.owner_placed = true
	plate.visible = false
	plate.attach(self, Vector3.UP * PLATE_LIFT, PLATE_REACH)
	add_child(plate)
	_build_camera_bodies()


func _build_camera_bodies() -> void:
	drawn_boxes()
	for part in _drawn_parts:
		if part[0] in _cables:
			continue
		var body := ChaseCamera.camera_body()
		body.name = "CameraBox"
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		body.add_child(shape)
		add_child(body)
		_camera_bodies.append([body, part[0], part[1], Vector3.ZERO, part[2] if part.size() > 2 else [part[0]]])
	_follow_drawn_parts()


func follow_shoved_rider(rider: Node3D) -> void:
	_shoved_rider = rider
	_follow_drawn_parts()


func _physics_process(delta: float) -> void:
	_follow_drawn_parts()
	step_magnet_motion(delta)
	_step_strike_flash(delta)


func _bind_magnet_rigs() -> void:
	_magnet_rigs.clear()
	_magnet_prev_pos.clear()
	_magnet_pos_ready.clear()
	for i in magnets.size():
		var visual: Node3D = null
		if model != null and i < _model_magnet_meshes.size() and is_instance_valid(_model_magnet_meshes[i]):
			visual = _model_magnet_meshes[i] as Node3D
		elif i < _magnet_visuals.size() and is_instance_valid(_magnet_visuals[i]):
			visual = _magnet_visuals[i] as Node3D
		var rig := PropMotionRig.new()
		if visual != null and PropMotionRig.is_visual_pivot(visual):
			rig.add_part("magnet_%d" % i, visual, {
				"sway": true,
				"sway_stiffness": 22.0,
				"sway_damping": 4.4,
				"sway_gain": 0.036,
				"sway_max_rad": 0.38,
				"sway_ambient_amp": 0.028,
				"sway_ambient_hz": 0.42,
				"sway_phase": float(i) * PI * 0.5,
				"jolt_stiffness": 135.0,
				"jolt_damping": 11.5,
				"jolt_max_offset": 0.28,
				"jolt_rot_gain": 0.48,
			})
			var target_node = magnets[i]
			if target_node != null and target_node.has_signal("struck_impulse"):
				target_node.struck_impulse.connect(func(dir: Vector3, strength: float):
					rig.apply_impulse(dir, strength))
		_magnet_rigs.append(rig)
		_magnet_prev_pos.append(Vector3.ZERO)
		_magnet_pos_ready.append(false)


func step_magnet_motion(delta: float) -> void:
	var dt := maxf(delta, 0.0001)
	var calm := Comfort.reduced_motion
	for i in mini(magnets.size(), _magnet_rigs.size()):
		var rig: PropMotionRig = _magnet_rigs[i]
		var cur_pos: Vector3 = (magnets[i] as Node3D).global_position
		var vel := Vector3.ZERO
		if _magnet_pos_ready[i]:
			vel = (cur_pos - _magnet_prev_pos[i]) / dt
		_magnet_prev_pos[i] = cur_pos
		_magnet_pos_ready[i] = true
		rig.step(delta, vel)


func magnet_motion_rig(i: int) -> PropMotionRig:
	return _magnet_rigs[i] if i >= 0 and i < _magnet_rigs.size() else null


func _follow_drawn_parts() -> void:
	for row in _camera_bodies:
		var node: Node3D = row[1]
		var body: AnimatableBody3D = row[0]
		var shape: CollisionShape3D = body.get_child(0)
		var live: bool = is_instance_valid(node) and node.is_visible_in_tree()
		shape.disabled = not live
		if not live:
			continue
		var at: Transform3D = node.global_transform
		var box: AABB = row[2]
		var scale := at.basis.get_scale().abs()
		body.global_transform = Transform3D(at.basis.orthonormalized(), at * box.get_center())
		var size := (box.size * scale).max(Vector3.ONE * 0.05)
		if not size.is_equal_approx(row[3]):
			(shape.shape as BoxShape3D).size = size
			row[3] = size
		var covering := false
		if is_instance_valid(_shoved_rider):
			var ball := body.to_local(_shoved_rider.global_position)
			var above := body.to_local(_shoved_rider.global_position + Vector3.UP * CUTAWAY_COLUMN)
			covering = AABB(-size * 0.5, size).grow(CUTAWAY_MARGIN).intersects_segment(ball, above) != null
		var layer := 0 if covering else ChaseCamera.CAMERA_BODY_BIT
		if body.collision_layer != layer:
			body.collision_layer = layer
			for mesh in row[4]:
				mesh.transparency = CUTAWAY_TRANSPARENCY if covering else 0.0


static func _cable_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 8
	for band in 6:
		var z0 := -0.5 + band / 6.0
		var z1 := -0.5 + (band + 1) / 6.0
		var r0 := 0.10 if band % 2 == 0 else 0.125
		var r1 := 0.125 if band % 2 == 0 else 0.10
		var v0 := float(band) * 0.75
		var v1 := float(band + 1) * 0.75
		var col := Color.WHITE if band % 2 == 0 else Color(1.4, 1.4, 1.4)
		for side in sides:
			var a := TAU * side / float(sides)
			var b := TAU * (side + 1) / float(sides)
			var u0 := float(side) / float(sides)
			var u1 := float(side + 1) / float(sides)
			var points := [
				Vector3(cos(a) * r0, sin(a) * r0, z0),
				Vector3(cos(b) * r0, sin(b) * r0, z0),
				Vector3(cos(b) * r1, sin(b) * r1, z1),
				Vector3(cos(a) * r1, sin(a) * r1, z1),
			]
			var uvs := [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]
			for index in [0, 2, 1, 0, 3, 2]:
				surface.set_uv(uvs[index])
				surface.set_color(col)
				surface.add_vertex(points[index])
	var r_cap := 0.10
	var c_front := Vector3(0.0, 0.0, -0.5)
	var c_back := Vector3(0.0, 0.0, 0.5)
	for side in sides:
		var a := TAU * side / float(sides)
		var b := TAU * (side + 1) / float(sides)
		var pa0 := Vector3(cos(a) * r_cap, sin(a) * r_cap, -0.5)
		var pb0 := Vector3(cos(b) * r_cap, sin(b) * r_cap, -0.5)
		for row in [[c_front, Vector2(0.5, 0.5)], [pa0, Vector2(0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5)], [pb0, Vector2(0.5 + cos(b) * 0.5, 0.5 + sin(b) * 0.5)]]:
			surface.set_uv(row[1])
			surface.set_color(Color.WHITE)
			surface.add_vertex(row[0])
		var pa1 := Vector3(cos(a) * r_cap, sin(a) * r_cap, 0.5)
		var pb1 := Vector3(cos(b) * r_cap, sin(b) * r_cap, 0.5)
		for row in [[c_back, Vector2(0.5, 0.5)], [pb1, Vector2(0.5 + cos(b) * 0.5, 0.5 + sin(b) * 0.5)], [pa1, Vector2(0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5)]]:
			surface.set_uv(row[1])
			surface.set_color(Color.WHITE)
			surface.add_vertex(row[0])
	surface.generate_normals()
	surface.generate_tangents()
	return surface.commit()


func drawn_boxes() -> Array:
	if _drawn_parts.is_empty():
		_find_drawn_parts()
	var out: Array = []
	for part in _drawn_parts:
		var node: Node3D = part[0]
		if is_instance_valid(node) and node.is_visible_in_tree():
			out.append([node.global_transform, part[1]])
	return out


func _find_drawn_parts() -> void:
	var nodes: Array = []
	if model != null:
		for part in BODY_PARTS:
			var found := model.find_child(part, true, false)
			if found != null:
				nodes.append(found)
		var hull_mesh := model.find_child("Hull", true, false) as Node3D
		var fittings := AABB()
		var fitting_meshes := []
		var any := false
		for part in FITTING_PARTS:
			var f := model.find_child(part, true, false) as VisualInstance3D
			if f != null and hull_mesh != null:
				fitting_meshes.append(f)
				var local: AABB = hull_mesh.global_transform.affine_inverse() * f.global_transform * f.get_aabb()
				fittings = local if not any else fittings.merge(local)
				any = true
		if any:
			_drawn_parts.append([hull_mesh, fittings.grow(0.6), fitting_meshes])
	else:
		for prim in _prims:
			var owner_piece = prim.get_parent()
			if not (owner_piece is Target) or owner_piece == hull:
				nodes.append(prim)
	nodes.append_array(_cables)
	for node in nodes:
		if node is VisualInstance3D and (node as VisualInstance3D).layers != 0:
			var box: AABB = (node as VisualInstance3D).get_aabb()
			if box.size != Vector3.ZERO:
				_drawn_parts.append([node, box])


func move_to(at: Vector3, dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() > 0.01:
		heading = flat.normalized()
	global_transform = Transform3D(Basis.looking_at(heading, Vector3.UP), at)


func pivot(i: int) -> Vector3:
	return to_global(CRANE_PIVOTS[i])


func magnet_rest(i: int) -> Vector3:
	var p: Vector3 = CRANE_PIVOTS[i]
	var out := Vector3(signf(p.x) * MAGNET_REST, p.y - MAGNET_HANG + 2.0, p.z)
	return to_global(out)


func set_magnet(i: int, at: Vector3, glow: float) -> void:
	magnets[i].global_position = at
	var mat: StandardMaterial3D = _magnet_mats[i]
	mat.emission_enabled = glow > 0.0
	mat.emission = Palette.HAZARD
	mat.emission_energy_multiplier = 2.5 * glow
	if model != null:
		(_model_magnets[i] as Node3D).global_position = at
		BossModel.signal_glow(_model_magnet_meshes[i], Palette.HAZARD, 2.5 * glow)
	var from := pivot(i)
	var cable: MeshInstance3D = _cables[i]
	var span := at - from
	if span.length() < 0.1:
		cable.visible = false
		return
	cable.visible = true
	cable.global_transform = Transform3D(Basis.looking_at(span.normalized(), Vector3.UP if absf(span.normalized().y) < 0.99 else Vector3.RIGHT)
		.scaled_local(Vector3(1.0, 1.0, span.length())), from + span * 0.5)


func show_cranes(on: bool) -> void:
	for i in magnets.size():
		magnets[i].visible = on
		_cables[i].visible = on
	_show_model_parts("cranes", _model_cranes, on, "enter_furnace")


func open_caps(open: bool) -> void:
	for mesh in _cap_meshes:
		(mesh as MeshInstance3D).position.y = 0.25 if open else 0.0
	for cap in caps:
		cap.set_rest_glow(Palette.HAZARD, 1.2 if open else 0.0)


func shed_armour() -> void:
	for plate in _plates:
		(plate as MeshInstance3D).visible = false
	_show_model_parts("armour", _model_armour, false, "enter_scuttle")


func _show_model_parts(group: String, parts: Array, on: bool, clip: String) -> void:
	_pending_hides.erase(group)
	var waits := not on and clip != "" and _anim != null and _anim.has_animation(clip)
	if on or not waits or parts.is_empty() or not (parts[0] as Node3D).visible:
		for part in parts:
			(part as Node3D).visible = on
		return
	_pending_hides[group] = {"parts": parts, "clip": clip}


func _flush_hides(clip: StringName, ended: bool) -> void:
	for group in _pending_hides.keys():
		var row: Dictionary = _pending_hides[group]
		if (String(clip) == row["clip"]) != ended:
			continue
		_pending_hides.erase(group)
		for part in row["parts"]:
			if is_instance_valid(part):
				(part as Node3D).visible = false


func cockpit_point() -> Vector3:
	return _cockpit.global_position


func cockpit_open(open: bool, clip := "") -> void:
	_cockpit.visible = not open
	if _model_shield != null:
		_show_model_parts("shield", [_model_shield], not open, clip)


func set_readout(text: String, color: Color, anchor: Node3D = null, lift := PLATE_LIFT) -> void:
	plate.text = text
	plate.add_theme_color_override("font_color", color)
	var to: Node3D = anchor if anchor != null else self
	if plate.anchor != to:
		plate.attach(to, Vector3.UP * lift, PLATE_REACH)


static func model_fits(loaded: Node, plates: int, caps: int) -> bool:
	for part in MODEL_PARTS:
		if loaded.find_child(part, true, false) == null:
			return false
	if not (loaded.find_child("CableSpans", true, false) is Node3D):
		return false
	for pair in [["Armour", plates], ["Cap", caps]]:
		for i in int(pair[1]):
			if not (loaded.find_child("%s%d" % [pair[0], i], true, false) is MeshInstance3D):
				return false
	return true


func _dress() -> void:
	var loaded := _take_ahead(model_path)
	if loaded == null:
		return
	if not model_fits(loaded, _plate_mats.size(), _cap_mats.size()):
		loaded.free()
		return
	model = loaded
	model.name = "BrindleModel"
	add_child(model)
	for mesh in _prims:
		BossModel.hide_primitive(mesh)
	_anim = BossModel.player_of(model)
	if _anim != null:
		BossModel.loop_clip(_anim, "idle_roll")
		_anim.animation_finished.connect(_flush_hides.bind(true))
		_anim.animation_started.connect(_flush_hides.bind(false))
		_anim.animation_finished.connect(_resume_idle)
		BossModel.strip_tracks(_anim, "Cap0", ["drone_deploy"])
		BossModel.strip_tracks(_anim, "Cap1", ["drone_deploy"])
		BossModel.strip_tracks(_anim, "Cap2", ["drone_deploy"])
	_model_shield = model.find_child("CockpitShield", true, false)
	_model_hull = model.find_child("Hull", true, false) as MeshInstance3D
	_model_bow_ram = model.find_child("BowRam", true, false) as MeshInstance3D
	_model_cranes = [model.find_child("CraneMasts", true, false), model.find_child("CranePort", true, false),
		model.find_child("CraneStarboard", true, false), model.find_child("MagnetSocketPort", true, false),
		model.find_child("MagnetSocketStarboard", true, false)]
	(model.find_child("CableSpans", true, false) as Node3D).visible = false
	_model_magnets = [model.find_child("MagnetSocketPort", true, false), model.find_child("MagnetSocketStarboard", true, false)]
	_model_magnet_meshes = [model.find_child("MagnetPort", true, false), model.find_child("MagnetStarboard", true, false)]
	for i in _plate_mats.size():
		var panel := model.find_child("Armour%d" % i, true, false) as MeshInstance3D
		panel.set_surface_override_material(0, _plate_mats[i])
		_model_armour.append(panel)
	for i in _cap_mats.size():
		(model.find_child("Cap%d" % i, true, false) as MeshInstance3D).set_surface_override_material(0, _cap_mats[i])
	_cue("idle_roll", 0)


func cue(clip: String, token := 0) -> void:
	_cue(clip, token)


const BRACE_DROP := 0.35
const BRACE_PITCH := -0.075
const BRACE_GLOW := 3.0


func set_hook_brace(on: bool, token := 0) -> void:
	var changed := on != _bracing
	_bracing = on
	if model != null:
		model.position.y = -BRACE_DROP if on else 0.0
		model.rotation.x = BRACE_PITCH if on else 0.0
		BossModel.signal_glow(_model_bow_ram, Palette.HAZARD, BRACE_GLOW if on else 0.0)
	if _hull_prim_mat != null:
		_hull_prim_mat.emission_enabled = on
		_hull_prim_mat.emission = Palette.HAZARD
		_hull_prim_mat.emission_energy_multiplier = 1.6 if on else 0.0
	if on and changed:
		_cue("charge_warn", token, "hook")


func bracing() -> bool:
	return _bracing


func trigger_strike_flash(color := Palette.HAZARD, duration := 0.22) -> void:
	_strike_flash_color = color
	_strike_flash_duration = maxf(0.05, duration * (0.75 if FlashGuard.on else 1.0))
	_strike_flash_left = _strike_flash_duration
	_apply_strike_flash(1.0)


func strike_flashing() -> bool:
	return _strike_flash_left > 0.0


func _step_strike_flash(delta: float) -> void:
	if _strike_flash_left <= 0.0:
		return
	_strike_flash_left = maxf(0.0, _strike_flash_left - delta)
	var frac := _strike_flash_left / maxf(_strike_flash_duration, 0.001)
	_apply_strike_flash(frac)


func _apply_strike_flash(frac: float) -> void:
	var scale := 0.45 if FlashGuard.on else 1.0
	var hull_energy := 1.45 * frac * scale
	var ram_energy := maxf(BRACE_GLOW if _bracing else 0.0, 2.2 * frac * scale)
	if model != null:
		if _model_hull != null:
			BossModel.signal_glow(_model_hull, _strike_flash_color, hull_energy)
		if _model_bow_ram != null:
			BossModel.signal_glow(_model_bow_ram, _strike_flash_color if frac > 0.0 else Palette.HAZARD, ram_energy)
	if _hull_prim_mat != null:
		var prim_energy := maxf(1.6 if _bracing else 0.0, 1.5 * frac * scale)
		_hull_prim_mat.emission_enabled = prim_energy > 0.001
		_hull_prim_mat.emission = _strike_flash_color if frac > 0.0 else Palette.HAZARD
		_hull_prim_mat.emission_energy_multiplier = prim_energy


func _cue(clip: String, token: int, tag := "") -> void:
	if model == null or _anim == null:
		return
	var key := "%s:%d:%s" % [clip, token, tag] if tag != "" else "%s:%d" % [clip, token]
	if key == _cue_key:
		return
	_cue_key = key
	BossModel.play(_anim, clip)


func _resume_idle(clip: StringName) -> void:
	if Comfort.reduced_motion or clip in [&"idle_roll", &"eject"] or _anim.assigned_animation != clip:
		return
	BossModel.play(_anim, "idle_roll")


func cue_phase(phase: int) -> void:
	_cue(["idle_roll", "enter_furnace", "enter_scuttle"][clampi(phase, 1, 3) - 1], phase)


static func dress_scooter(parent: Node3D) -> AnimationPlayer:
	var loaded := _take_ahead(scooter_path)
	if loaded == null:
		return null
	loaded.name = "ScooterModel"
	parent.add_child(loaded)
	var player := BossModel.player_of(loaded)
	if player != null:
		BossModel.loop_clip(player, "chase")
	return player


static var _ahead := {}
static var _ahead_reads := {}
static var _dressing := {}


# Godot's headless dummy rasterizer mesh RIDs are not thread-safe; keep loads on the main thread.
static func warm() -> bool:
	for path in [model_path, scooter_path]:
		if _ahead.has(path):
			continue
		if not _ahead_reads.has(path):
			if not ResourceLoader.exists(path):
				_ahead_reads[path] = null
			elif AppShell.headless():
				_ahead_reads[path] = load(path)
			else:
				var status := ResourceLoader.load_threaded_get_status(path)
				if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
					ResourceLoader.load_threaded_request(path)
					return false
				if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					return false
				_ahead_reads[path] = ResourceLoader.load_threaded_get(path) if status == ResourceLoader.THREAD_LOAD_LOADED else null
			return false
		if not _dressing.has(path):
			var scene := BossModel.load_scene(path, false)
			_dressing[path] = [scene, scene.find_children("*", "MeshInstance3D", true, false) if scene != null else []]
			return false
		var views: Array = _dressing[path][1]
		if not views.is_empty():
			var view: MeshInstance3D = views.pop_back()
			BossModel.colour_view(view)
			BakeLook.warm_view(view)
			if view.mesh != null:
				InkOutline.hull(BakeLook.tangent_safe(view.mesh))
			return false
		_ahead[path] = _finish(_dressing[path][0])
		_dressing.erase(path)
		return false
	return true


static func drop_ahead() -> void:
	for scene in _ahead.values():
		if is_instance_valid(scene):
			scene.free()
	_ahead.clear()
	_ahead_reads.clear()
	for entry in _dressing.values():
		if is_instance_valid(entry[0]):
			entry[0].free()
	_dressing.clear()


static func _take_ahead(path: String) -> Node3D:
	if not _ahead.has(path):
		return _instance(path)
	var scene: Node3D = _ahead[path]
	_ahead.erase(path)
	_ahead_reads.erase(path)
	return scene


static func _instance(path: String) -> Node3D:
	var scene := BossModel.load_scene(path, false)
	if scene != null:
		for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			BossModel.colour_view(view)
	return _finish(scene)


static func _finish(scene: Node3D) -> Node3D:
	if scene != null:
		BakeLook.dress(scene)
		InkOutline.apply(scene, "boss")
		var player := BossModel.player_of(scene)
		if player != null:
			BossModel.own_clips(player)
	return scene


func _craft_part(parent: Node3D, array_mesh: ArrayMesh, mat: Material, at: Vector3, node_name: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = array_mesh
	mesh.material_override = mat
	mesh.position = at
	parent.add_child(mesh)
	_prims.append(mesh)
	return mesh


func _box(parent: Node3D, size: Vector3, mat: Material, at: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = at
	parent.add_child(mesh)
	_prims.append(mesh)
	return mesh


func _cylinder(parent: Node3D, r: float, h: float, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = h
	mesh.mesh = cyl
	mesh.material_override = mat
	parent.add_child(mesh)
	_prims.append(mesh)
	return mesh
