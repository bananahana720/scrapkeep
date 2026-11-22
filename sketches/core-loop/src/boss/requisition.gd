extends Node3D

const AppShell := preload("res://src/core/app_shell.gd")
const Palette := preload("res://src/core/palette.gd")
const Target := preload("res://src/boss/boss_target.gd")
const ChaseCamera := preload("res://src/movement/chase_camera.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const BossModel := preload("res://src/boss/boss_model.gd")
const BakeLook := preload("res://src/presentation/bake_look.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")

# The Requisition: a rolling furnace-fortress several times the ball's height, with
# Brindle's glass cockpit on its stern. This node is its body and its pieces, and it
# decides nothing: boss.gd moves it, swings its cranes and asks its pieces what they
# are. Its hull is kinematic, so it shoves the ball with weight and is never pushed.

const HULL := Vector3(9.0, 5.0, 14.0)
const DECK := 5.0
const CAP_SPOTS := [Vector3(0.0, 5.4, -4.5), Vector3(-2.6, 5.4, 0.8), Vector3(2.6, 5.4, 0.8)]
const CRANE_PIVOTS := [Vector3(-4.5, 7.5, -2.0), Vector3(4.5, 7.5, 2.0)]
const MAGNET_REST := 6.0
const MAGNET_HANG := 4.5
const CAP_SIZE := Vector3(2.2, 0.8, 2.2)
# Brindle's name plate shows while the camera is within this of its anchor: the bowl's
# whole width, so it never drops out mid-fight.
const PLATE_REACH := 160.0
const PLATE_LIFT := DECK + 4.0
# The charge shove's cutaway: a camera body whose box, grown by CUTAWAY_MARGIN, meets the column CUTAWAY_COLUMN metres
# up from the rider turns every mesh it stands for to this transparency.
const CUTAWAY_TRANSPARENCY := 0.88
const CUTAWAY_COLUMN := 12.0
const CUTAWAY_MARGIN := 1.0
# The fortress and its scooter (recipes in tools/blender/bosses). The primitives below stay
# built and are only hidden when the model loads, so a missing GLB leaves the old boxes.
const MODEL := "res://assets/models/bosses/boss_brindle.glb"
const SCOOTER_MODEL := "res://assets/models/bosses/boss_brindle_scooter.glb"
# Test seam: a test points these at a missing file to prove the primitive fallback builds.
static var model_path := MODEL
static var scooter_path := SCOOTER_MODEL
# The model parts the loader needs; a model that lacks any of them is dropped, not half used.
# The model parts drawn_boxes() lists.
const BODY_PARTS := ["Hull", "BowRam", "CockpitShield", "CraneMasts", "CraneElbowPort", "CraneElbowStarboard", "DeckDressing",
	"Armour0", "Armour1", "Armour2", "Armour3"]
# The drums and hatches on the hull's sides: one box together, in the hull's own frame.
const FITTING_PARTS := ["DrumL0", "DrumL1", "DrumL2", "DrumL3", "DrumR0", "DrumR1", "DrumR2", "DrumR3", "HatchL", "HatchR"]
const MODEL_PARTS := ["Hull", "CockpitShield", "CraneMasts", "CranePort", "CraneStarboard", "CableSpans", "MagnetSocketPort",
	"MagnetSocketStarboard", "MagnetPort", "MagnetStarboard", "Cap0", "Cap1", "Cap2", "Armour0", "Armour1", "Armour2", "Armour3"]

var hull
var magnets: Array = []
var caps: Array = []
var heading := Vector3.FORWARD
# Brindle's name plate: a screen prompt the HUD keeps in the prompts band (CONTRACTS,
# UI regions), anchored to the ship and, in the chase, to the scooter.
var plate: WorldPrompt

var _cables: Array = []
var _magnet_mats: Array = []
var _cap_meshes: Array = []
var _plates: Array = []
var _cockpit: MeshInstance3D
var _hull_prim_mat: StandardMaterial3D
# The model and its parts, when it loaded; null model means the primitives are the body.
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
var _model_shield: Node3D
var _bracing := false
var _pending_hides := {}
# [node, local AABB] of each drawn part, found once (drawn_boxes).
var _drawn_parts: Array = []
# One camera-only body per drawn box, [body, node, local AABB], so the chase camera meets what is drawn.
var _camera_bodies: Array = []
var _shoved_rider: Node3D


func build(boss) -> void:
	name = "Requisition"
	hull = Target.new()
	hull.setup(boss, "hull", "hull", HULL, Vector2(6.0, 3.0))
	hull.position = Vector3.UP * HULL.y * 0.5
	add_child(hull)
	hull.body_boxes = drawn_boxes
	_hull_prim_mat = Palette.solid(Palette.RUST)
	_box(hull, HULL, _hull_prim_mat, Vector3.ZERO)
	for side in [-1.0, 1.0]:
		for z in [-3.5, 3.5]:
			var plate_mat := Palette.solid(Color("5d6b78"))
			hull.tint_with(plate_mat)
			_plate_mats.append(plate_mat)
			_plates.append(_box(hull, Vector3(0.4, 3.2, 6.0), plate_mat, Vector3(side * (HULL.x * 0.5 + 0.2), 0.3, z)))
	_cockpit = _box(self, Vector3(3.0, 2.2, 3.0), Palette.water(Palette.ARC), Vector3(0.0, DECK + 1.1, 4.8))
	_box(self, Vector3(1.2, 1.0, 1.0), Palette.solid(Palette.AMBER, 0.4), Vector3(0.0, DECK + 1.0, 4.8))
	for i in CAP_SPOTS.size():
		var cap = Target.new()
		cap.setup(boss, "cap", "cap_%d" % (i + 1), CAP_SIZE, Vector2(1.2, 1.2))
		cap.position = CAP_SPOTS[i]
		add_child(cap)
		var mat := Palette.solid(Palette.CHARCOAL)
		cap.tint_with(mat)
		_cap_mats.append(mat)
		_cap_meshes.append(_cylinder(cap, 1.1, CAP_SIZE.y, mat))
		caps.append(cap)
	for i in CRANE_PIVOTS.size():
		_box(self, Vector3(0.8, 3.0, 0.8), Palette.solid(Palette.COPPER), CRANE_PIVOTS[i] - Vector3.UP * 1.5)
		var magnet = Target.new()
		magnet.setup(boss, "magnet", "magnet_%s" % ["port", "starboard"][i], Vector3.ZERO, Vector2(1.5, 1.5))
		add_child(magnet)
		var mat := Palette.solid(Palette.VERDIGRIS)
		_magnet_mats.append(mat)
		_cylinder(magnet, 1.4, 0.9, mat)
		magnets.append(magnet)
		var cable := MeshInstance3D.new()
		cable.name = "CableSpan%d" % i
		cable.mesh = _cable_mesh()
		cable.material_override = Palette.solid(Palette.CHARCOAL)
		cable.material_override.vertex_color_use_as_albedo = true
		add_child(cable)
		_cables.append(cable)
	_dress()
	plate = WorldPrompt.new()
	plate.name = "BrindlePlate"
	plate.attach(self, Vector3.UP * PLATE_LIFT, PLATE_REACH)
	add_child(plate)
	_build_camera_bodies()


# The chase camera's arm and lift probe see layer 4 only for the ship, not the layer-3 hull (the
# placeholder box is hidden when the model loads). The bodies follow their drawn parts each physics tick.
func _build_camera_bodies() -> void:
	drawn_boxes()
	for part in _drawn_parts:
		# A cable's 0.25 m swing across the arm would snap the lens in; other readers still see it in drawn_boxes().
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


# During a charge shove the rider can pass through the hull. Each camera body standing over the ball goes
# see-through whole, with every mesh it stands for (so the hull goes with its fittings), and the rest stay opaque.
func follow_shoved_rider(rider: Node3D) -> void:
	_shoved_rider = rider
	_follow_drawn_parts()


func _physics_process(_delta: float) -> void:
	_follow_drawn_parts()


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
		# The close chase lens is above the ball. A one-radius column covers
		# the moving cage even when the arm pivot trails the sideways shove.
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
	# Alternating collars give the working cable a ribbed profile along local Z.
	for band in 6:
		var z0 := -0.5 + band / 6.0
		var z1 := -0.5 + (band + 1) / 6.0
		var r0 := 0.10 if band % 2 == 0 else 0.125
		var r1 := 0.125 if band % 2 == 0 else 0.10
		for side in 8:
			var a := TAU * side / 8.0
			var b := TAU * (side + 1) / 8.0
			var points := [Vector3(cos(a) * r0, sin(a) * r0, z0), Vector3(cos(b) * r0, sin(b) * r0, z0),
				Vector3(cos(b) * r1, sin(b) * r1, z1), Vector3(cos(a) * r1, sin(a) * r1, z1)]
			for index in [0, 2, 1, 0, 3, 2]:
				surface.set_color(Color.WHITE if band % 2 == 0 else Color(1.4, 1.4, 1.4))
				surface.add_vertex(points[index])
	surface.generate_normals()
	return surface.commit()


# The ship's drawn body as a short list of oriented boxes, [Transform3D, AABB] pairs, each part's own
# box in its own frame, so a turned ship keeps tight boxes (one world box around a 9 x 14 m hull grows
# to 16.5 x 16.5 m at 45 degrees). The loaded model's body parts are listed (BODY_PARTS: the hull and bow
# ram, the cockpit shield, the crane masts and elbows, the deck dressing, the armour panels; one box for
# the drums and hatches on the hull's sides) with the crane cables, which are drawn outside every
# piece's own shape. Without the model: the hull piece's primitives, the cockpit and the crane posts.
# Left out: the magnets, caps and sockets (strike pieces of their own, in group "enemy"), the name plate
# and the posture ring. The parts and their local boxes are found once; a call reads each part's live
# transform and skips a hidden one (a shed armour panel, folded cranes). The hull piece's own box is the
# 9 x 5 x 14 m placeholder, hidden by render layer when the model loads, so it is not what the ship looks
# like. player_fx keeps hit words off these boxes (PF-26). Empty before the build.
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
			# The drums turn with the idle clip, so their box is grown past a drum's corners.
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


# Places the ship with its bow along `dir`, on whatever ground is under it.
func move_to(at: Vector3, dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() > 0.01:
		heading = flat.normalized()
	global_transform = Transform3D(Basis.looking_at(heading, Vector3.UP), at)


func pivot(i: int) -> Vector3:
	return to_global(CRANE_PIVOTS[i])


# Where a magnet hangs when its crane is idle: out past the side of the hull, below its pivot.
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
	# The glow lives on the cap's tint material, which its target owns, so a hit hands it back.
	for cap in caps:
		cap.set_rest_glow(Palette.HAZARD, 1.2 if open else 0.0)
	# The model's caps lift with the enter_furnace clip; the glow is the same tint material.


func shed_armour() -> void:
	for plate in _plates:
		(plate as MeshInstance3D).visible = false
	_show_model_parts("armour", _model_armour, false, "enter_scuttle")


# The phase-entry clips fold the model's cranes, blow its armour off and flip its shield; hiding those parts
# on the entry frame cut the clip before it was seen, so a hide waits for the clip to end, on the
# player's own clock, or for another clip to cut it. Showing is immediate and cancels a pending hide.
func _show_model_parts(group: String, parts: Array, on: bool, clip: String) -> void:
	_pending_hides.erase(group)
	var waits := not on and clip != "" and _anim != null and _anim.has_animation(clip)
	if on or not waits or parts.is_empty() or not (parts[0] as Node3D).visible:
		for part in parts:
			(part as Node3D).visible = on
		return
	_pending_hides[group] = {"parts": parts, "clip": clip}


# animation_finished (ended) or animation_started (another clip took over): hides waiting on
# `clip` run, as do those whose clip was cut by a different one.
func _flush_hides(clip: StringName, ended: bool) -> void:
	for group in _pending_hides.keys():
		var row: Dictionary = _pending_hides[group]
		if (String(clip) == row["clip"]) != ended:
			continue
		_pending_hides.erase(group)
		for part in row["parts"]:
			if is_instance_valid(part):
				(part as Node3D).visible = false


# Where the cockpit sits on the stern, for the HUD's pointer (boss.gd plate_targets).
func cockpit_point() -> Vector3:
	return _cockpit.global_position


# `clip` names a phase-entry clip that flips the model's shield away; the hide waits for it.
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


# Loads the fortress GLB over the primitives. Any missing part drops the model, so a broken
# or older GLB leaves the primitive fortress exactly as it was.
# The dressing below casts parts without checking: every MODEL_PARTS node must exist, the
# Armour and Cap parts the material arrays reach must be meshes, and CableSpans a Node3D. A
# model that misses any keeps the primitive body instead of crashing on the boss-entry frame.
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
		# Cap lift is the enter_furnace beat; the dip a later clip would reset it to is not.
		BossModel.strip_tracks(_anim, "Cap0", ["drone_deploy"])
		BossModel.strip_tracks(_anim, "Cap1", ["drone_deploy"])
		BossModel.strip_tracks(_anim, "Cap2", ["drone_deploy"])
	_model_shield = model.find_child("CockpitShield", true, false)
	_model_bow_ram = model.find_child("BowRam", true, false) as MeshInstance3D
	_model_cranes = [model.find_child("CraneMasts", true, false), model.find_child("CranePort", true, false),
		model.find_child("CraneStarboard", true, false), model.find_child("MagnetSocketPort", true, false),
		model.find_child("MagnetSocketStarboard", true, false)]
	# The procedural cable spans the real distance; the model's static span would double it.
	(model.find_child("CableSpans", true, false) as Node3D).visible = false
	_model_magnets = [model.find_child("MagnetSocketPort", true, false), model.find_child("MagnetSocketStarboard", true, false)]
	_model_magnet_meshes = [model.find_child("MagnetPort", true, false), model.find_child("MagnetStarboard", true, false)]
	# The plating tint (slate or amber) and the hit flash live on the same materials the
	# primitive plates and caps used, laid over the model's steel surface so the read survives.
	for i in _plate_mats.size():
		var panel := model.find_child("Armour%d" % i, true, false) as MeshInstance3D
		panel.set_surface_override_material(0, _plate_mats[i])
		_model_armour.append(panel)
	for i in _cap_mats.size():
		(model.find_child("Cap%d" % i, true, false) as MeshInstance3D).set_surface_override_material(0, _cap_mats[i])
	_cue("idle_roll", 0)


# Plays a clip once per (clip, token), so a per-frame caller never restarts it; a new token,
# such as a new committed hazard, plays it again. A missing clip is a quiet no-op.
func cue(clip: String, token := 0) -> void:
	_cue(clip, token)


# W1-106 (A11): visible hull brace ahead of the Scuttle's hook turn. Crouches and pitches the
# drawn fortress bow-down, plays the charge_warn pull-back clip, and lights the BowRam's M4
# signal lip in HAZARD so the brace reads on High and Low presets without moving any collider.
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
		_cue("charge_warn", token)


func bracing() -> bool:
	return _bracing


func _cue(clip: String, token: int) -> void:
	if model == null or _anim == null:
		return
	var key := "%s:%d" % [clip, token]
	if key == _cue_key:
		return
	_cue_key = key
	BossModel.play(_anim, clip)


# A one-shot cue that ran out with nothing queued behind it hands the drums back to the idle
# roll, so they stop freezing after the first crane. Reduced motion adds no idle, as for the
# enemies; the cue key is left alone, so no cue replays.
func _resume_idle(clip: StringName) -> void:
	# The hull the pilot has ejected from lies empty, so its drums stay still.
	if EnemyMotion.motion_scale <= 0.0 or clip in [&"idle_roll", &"eject"] or _anim.assigned_animation != clip:
		return
	BossModel.play(_anim, "idle_roll")


# The phase's entry clip: the idle roll, the furnace's open caps, the scuttle's shed armour.
func cue_phase(phase: int) -> void:
	_cue(["idle_roll", "enter_furnace", "enter_scuttle"][clampi(phase, 1, 3) - 1], phase)


# The scooter that leaves the hull. Null when the model is missing: the caller keeps its box.
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


# The fortress and the scooter, read and instanced ahead by warm(), by file path until _dress or
# dress_scooter takes them: loading and dressing the fortress took 31 ms of the boss-entry
# frame on the cloud. Each instance already owns its clips.
static var _ahead := {}
static var _ahead_reads := {}
# A model warm() is dressing: path -> [its instance, the views still to colour and dress].
static var _dressing := {}


# A step of that work a call, while the world's last stage runs (boss.gd's warm_arena); true
# once both are ready. A played game reads the files on a loader thread; headless reads them
# here, since the dummy rasterizer's mesh RIDs are not thread-safe (as mind_dress.gd).
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
		# The instance, then its colour and the bake's look a view a call: the model dressed whole in
		# one call was a 71-77 ms frame on the 4080 at the flume Warden's engage.
		if not _dressing.has(path):
			var scene := BossModel.load_scene(path, false)
			_dressing[path] = [scene, scene.find_children("*", "MeshInstance3D", true, false) if scene != null else []]
			return false
		var views: Array = _dressing[path][1]
		if not views.is_empty():
			var view: MeshInstance3D = views.pop_back()
			BossModel.colour_view(view)
			BakeLook.warm_view(view)
			return false
		_ahead[path] = _finish(_dressing[path][0])
		_dressing.erase(path)
		return false
	return true


# Frees what warm() holds outside the tree, when the run that read it goes.
static func drop_ahead() -> void:
	for scene in _ahead.values():
		if scene != null:
			scene.free()
	_ahead.clear()
	_ahead_reads.clear()
	for entry in _dressing.values():
		if entry[0] != null:
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


# A coloured scene dressed by the bake's look, with its own clips.
static func _finish(scene: Node3D) -> Node3D:
	if scene != null:
		BakeLook.dress(scene)
		var player := BossModel.player_of(scene)
		if player != null:
			BossModel.own_clips(player)
	return scene


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
