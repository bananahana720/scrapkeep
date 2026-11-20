extends SubViewportContainer

const Palette := preload("res://src/core/palette.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const CosmeticWear := preload("res://src/core/cosmetic_wear.gd")
const PilotAntics := preload("res://src/presentation/pilot_antics.gd")
const PilotReactions := preload("res://src/presentation/pilot_reactions.gd")
const HighdraftFx := preload("res://src/presentation/highdraft_fx.gd")
const ModelKit := preload("res://src/world/model_kit.gd")
const YARD_KIT := "res://assets/models/world_one/bay_kit.glb"
const WorldGrade := preload("res://src/presentation/world_grade.gd")

# The class card's portrait and live ability preview: the pilot's real hero shell
# (hero_assets.gd's glb, painted by its own paint()) in a tiny world of its own. The
# framing follows the visual track's key art (storyboards 10 to 12): the sphere large
# in the upper part, caught mid-action, over a quiet dark floor the card's words sit on.
# At rest the card holds one frame of the pilot's signature move, gently bobbing, the
# pilot turned three-quarters to you. While the card is open the camera pulls back and
# the whole move loops, the camera trailing the sphere at mid range: Sable hooks a wall pylon, swings on the taut line and launches
# like a cannonball; Rivet sprints through a crowd with the laser firing, then blasts;
# Kest lobs sticky charges, blinks out in smoke, draws the line and rides its own blast
# up, then glides down on its vanes. The remembered cannon calls a lane, kicks back on a
# split, plates, then rushes and rings the ground. Tally lays three ledger plates in a
# climbing stair, hops them, spins up the flywheel and stamps the slam. The motion is scripted here, not the game's ball
# and abilities, which need the whole run around them; the model, colours and shapes
# are the game's (ring, chevron, burst, lane).

const LOOP := 3.6
# The menu stages' exposure under the run's grade (Grading G4, #254). Measured under llvmpipe: the
# AgX exposure at which each pilot's preview keeps its old Filmic mean L* crossed at 1.65 to 2.21
# (tally the high end, its pale plates compress under AgX); 1.75 is the median, within 1 L* for five
# pilots, -3.6 for tally. The customize bench's crossings sit near 1.70, so it shares the value.
const MENU_EXPOSURE := 1.75
# The loop phase each card holds at rest: the key art's moment.
const REST := {"pylon_engineer": 0.54, "runner_gunner": 0.3, "demolitions_caster": 0.64, "tarn": 0.3,
	"remembered_cannon": 0.22, "tally": 0.3}
const BOB := 0.08
const REST_SPIN := 2.5
# How far the resting pilot turns from its heading toward the camera.
const FACE_CAMERA := 0.55
const NEAR_OFFSET := Vector3(-0.3, 0.5, 5.0)
const NEAR_LOOK := Vector3(0.0, -0.75, 0.0)
const NEAR_FOV := 42.0
const FOLLOW_OFFSET := Vector3(-0.4, 1.0, 5.9)
const FOLLOW_LOOK := Vector3(0.0, -0.2, 0.0)
const FOLLOW_FOV := 44.0
const FOLLOW_RATE := 5.0
const FLOOR := 6.0
const WALL_X := -2.8
const ANCHOR := Vector3(-2.45, 3.4, 0.0)
const TETHER := 2.7

# Reduced motion (Game.set_reduced_motion keeps it current): the cap and charge pulses hold at rest.
static var reduced_motion := false

var def: Resource
# 0 at rest, 1 fully open; the card eases it.
var open := 0.0
var clock := 0.0
var ball: Node3D
# An equipped paint's cosmetic id; colours only the shell's paint slot, never the class accent.
var paint_id := "":
	set(value):
		paint_id = value
		if _core != null:
			_sync_variant()
			_paint_shell()
# The equipped shell variant's asset id, "" for the default cage. Setting it refits the shell
# through HeroAssets.fit_shell_into, the game's own loader (CUSTOMIZE.md section 7).
var variant := "":
	set(value):
		if value == variant:
			return
		variant = value
		if _core != null and _shell_rec.size() > 0:
			_refit_shell()
# The heft class shown, 1 to 5; layers show up to it.
var heft_class := 1:
	set(value):
		heft_class = clampi(value, 1, 5)
		if _painter != null and not _shell_rec.is_empty():
			_painter.set_heft_class(_shell_rec, heft_class, is_inside_tree())

var _shell_rec := {}
var _viewport: SubViewport
var _camera: Camera3D
var _core: Node3D
var _pod: Node3D
var _pilot: Node3D
var _props := {}
var _last := Vector3.ZERO
var _heading := 0.0
var _rest_at := Vector3.ZERO
var _follow := Vector3.ZERO
var _time := 0.0
var _painter
var _animator: AnimationPlayer
var _focused := false
# The clip the last first-focus started ("" when none), for tests and tools.
var last_focus_clip := ""
# Where the once-per-profile unlock is recorded (ui_profile.gd); resolved from the game when unset.
var ui_profile = null
var antic
var look_weight := 0.0
var _look := {"yaw": 0.0, "pitch": 0.2, "dist": LOOK_DIST}
var _look_idle := LOOK_HOLD
var look_dragging := false
# --profile=sitting: the unlock plays on the first focus of every launch instead.
var sitting := false
const UNLOCK_CLIP := "unlock"
const UNLOCK_SEEN := "unlock_clip_"
const BASE_BLEND: float = PilotReactions.BASE_BLEND
# At rest the pilot climbs out and does their bit (pilot_antics.gd) every ANTIC_PERIOD seconds,
# each card on its own phase so a row of cards never moves in step; never in the first period,
# so a card you just opened on shows its still first.
const ANTIC_PERIOD := 9.0
# Look closer: drag with the right mouse button or the right stick to orbit the pilot, wheel
# (while dragging) to zoom; the view drifts back LOOK_HOLD seconds after you let go.
const LOOK_DIST := 3.2
const LOOK_NEAR := 1.4
const LOOK_FAR := 6.0
const LOOK_HOLD := 1.4
const LOOK_RATE := 6.0
const LOOK_DRAG := 0.009
# Classes whose unlock played this launch under --profile=sitting.
static var _sitting_unlocks := {}


func _init(class_def: Resource = null, size_hint := Vector2(380.0, 260.0)) -> void:
	def = class_def
	stretch = true
	custom_minimum_size = size_hint
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.size = Vector2i(size_hint)
	add_child(_viewport)
	_build_stage()
	if def != null and HeroAssets.SHELLS.has(def.id):
		_build_shell()
		_build_props()
		clock = _rest_phase() * LOOP
		_pose(_rest_phase() - 0.01)
		_pose(_rest_phase())
		_rest_at = ball.position
		_follow = _rest_at
		_frame(0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _painter != null:
		_painter.free()


func playing() -> bool:
	return open > 0.5


func _rest_phase() -> float:
	return REST.get(def.id, 0.5) if def != null else 0.5


func _build_stage() -> void:
	var tint: Color = def.color if def != null else Palette.SAND
	_camera = Camera3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.SAND
	env.ambient_light_energy = WorldLook.PREVIEW.energy
	WorldGrade.menu(env, MENU_EXPOSURE)
	_camera.environment = env
	_viewport.add_child(_camera)
	preview_lights(_viewport, tint, true)
	var ground := CylinderMesh.new()
	ground.top_radius = FLOOR
	ground.bottom_radius = FLOOR
	ground.height = 0.1
	_mesh(ground, _mat(Palette.CHARCOAL.lerp(Palette.VERDIGRIS, 0.2), 0.0, 1.0, false), Vector3(0.0, -0.05, 0.0)).name = "TurntableFloor"
	_mesh(_torus(FLOOR - 0.06, FLOOR + 0.02), _mat(tint, 1.0), Vector3.ZERO).name = "TurntableRim"


# The lights of a UI preview's own world: the sun and, with rim, a class-tinted rim from behind.
# Both are directional and live under a SubViewport with own_world_3d that its screen owns, so
# no stage change frees them (lint L6). The customize page's live preview takes the sun only.
static func preview_lights(viewport: Node, tint: Color, rim_light: bool) -> Array:
	var made: Array = []
	var sun := DirectionalLight3D.new()
	sun.name = "PreviewSun"
	sun.rotation_degrees = WorldLook.PREVIEW.sun_rotation
	sun.light_energy = WorldLook.PREVIEW.sun_energy
	viewport.add_child(sun)
	made.append(sun)
	if rim_light:
		# The class-tinted rim from behind is directional: the preview closes with its screen, and a
		# positional light freed with it is the stage-freed light class.
		var rim := DirectionalLight3D.new()
		rim.name = "PreviewRim"
		rim.rotation_degrees = WorldLook.PREVIEW.rim_rotation
		rim.light_color = tint
		rim.light_energy = WorldLook.PREVIEW.rim_energy
		rim.shadow_enabled = false
		viewport.add_child(rim)
		made.append(rim)
	return made


func _build_shell() -> void:
	if _painter == null:
		_painter = HeroAssets.previewing()
	ball = Node3D.new()
	ball.name = "Shell"
	_viewport.add_child(ball)
	# The game's one loader path (hero_assets.gd fit_shell_into): base, heft layers, variant.
	_shell_rec = _painter.fit_shell_into(ball, def.id, variant, heft_class, _tints())
	if _shell_rec.is_empty():
		_build_primitive_shell()
		return
	_core = _shell_rec.core
	_pod = _shell_rec.pod
	_fit_pilot()


# Swaps the shell for the current variant, keeping the ball and its pose.
func _refit_shell() -> void:
	if antic != null:
		antic.seat()
	var at := _core.transform
	var facing := _pod.rotation.y
	for node in [_core, _pod]:
		ball.remove_child(node)
		node.free()
	_pilot = null
	_shell_rec = _painter.fit_shell_into(ball, def.id, variant, heft_class, _tints())
	if _shell_rec.is_empty():
		_build_primitive_shell()
		return
	_core = _shell_rec.core
	_pod = _shell_rec.pod
	_core.transform = at
	_pod.rotation.y = facing
	_fit_pilot()
	_paint_shell()


# The card's profile, read from the nearest ancestor that holds one (class_card.gd _profile),
# so the card shows the equipped variant without the card knowing about variants.
func _sync_variant() -> void:
	var node := get_parent()
	while node != null:
		var profile = node.get("_profile")
		if profile != null:
			var worn := CosmeticWear.worn(profile, def.id, "shell")
			variant = String(Cosmetics.row(worn).get("asset", "")) if worn != "" else ""
			return
		node = node.get_parent()


func _tints() -> Dictionary:
	var tints := {"class": def.color}
	if paint_id != "" and _painter != null:
		var tint = _painter.paint_tint(def.id, paint_id)
		if tint != null:
			tints["paint"] = tint
	return tints


# The game's pilot for this class (hero_assets.gd fit_pilot_into), seated the way
# gameplay seats it between reactions (seat_pilot).
func _fit_pilot() -> void:
	var fitted: Dictionary = _painter.fit_pilot_into(_pod, def.id, def.color)
	if fitted.is_empty():
		return
	_pilot = fitted.pilot
	_animator = fitted.get("animator")
	antic = PilotAntics.new({"holder": ball, "core": _core, "pod": _pod, "pilot": _pilot, "animator": _animator}, def.id)
	seat_pilot()


# PILOT-CLIPS section 3 rule 9: the card shows a living pilot, idle_loop from its first frame
# (the same still as before) when the GLB has it; else animator stopped, bones at rest pose.
# Returns the clip now playing, or "".
func seat_pilot() -> String:
	return PilotReactions.seat_idle(_animator, _pilot)


# PILOT-CLIPS section 1.4: the first focus after the pilot unlocks plays unlock, once per
# profile (ui_profile seen/mark_seen, id unlock_clip_<class>), or once per launch under
# --profile=sitting; then the pilot goes back to idle_loop. Returns the clip it started, or "".
func focus_clip() -> String:
	if _animator == null or _pilot == null or def == null or not _animator.has_animation(UNLOCK_CLIP) or not _unlock_due():
		return ""
	_animator.play(UNLOCK_CLIP, BASE_BLEND if _animator.is_playing() else 0.0)
	_animator.advance(0.0)
	if not _animator.animation_finished.is_connected(_on_clip_finished):
		_animator.animation_finished.connect(_on_clip_finished)
	return UNLOCK_CLIP


# The card opening (open past half, as playing() reads it) is a focus; each opening asks once.
func track_focus() -> void:
	if playing() and not _focused:
		_focused = true
		last_focus_clip = focus_clip()
	elif not playing():
		_focused = false


func _on_clip_finished(_clip: StringName) -> void:
	seat_pilot()


func _unlock_due() -> bool:
	_resolve_launch()
	var node := get_parent()
	while node != null:
		if node.get("locked") == true:
			return false
		node = node.get_parent()
	if sitting:
		if _sitting_unlocks.has(def.id):
			return false
		_sitting_unlocks[def.id] = true
		return true
	if ui_profile == null:
		return false
	var seen_id: String = UNLOCK_SEEN + String(def.id)
	if ui_profile.seen(seen_id):
		return false
	ui_profile.mark_seen(seen_id)
	return true


# The launch's tuning and the HUD's profile, from the game above the card, unless set already.
func _resolve_launch() -> void:
	var node := get_parent()
	while node != null:
		var tuning = node.get("tuning")
		if tuning != null and tuning.has_method("sitting"):
			sitting = sitting or tuning.sitting()
			var hud = node.get("hud")
			if ui_profile == null and hud != null and hud.get("profile") != null:
				ui_profile = hud.profile
			return
		node = node.get_parent()


func _build_primitive_shell() -> void:
	var core := MeshInstance3D.new()
	core.name = "Core"
	core.mesh = _sphere(0.98)
	var mat := _mat(def.color, 0.0, 1.0, false)
	mat.resource_name = "class_accent"
	core.mesh.material = mat
	ball.add_child(core)
	_core = core
	_pod = Node3D.new()
	_pod.name = "Pod"
	ball.add_child(_pod)


func _paint_shell() -> void:
	var tints := _tints()
	if not _shell_rec.is_empty():
		_shell_rec["tints"] = tints
	_painter.paint(_core, tints)
	_painter.paint(_pod, tints)
	if _pilot != null:
		_painter.paint(_pilot, {"class": def.color})


func _build_props() -> void:
	match def.id:
		"pylon_engineer":
			var wall := _yard_piece("BayYardWall", Vector3(4.0, 6.0, 1.2), BoxMesh.new(), Palette.SANDSTONE)
			wall.position = Vector3(WALL_X - 0.6, 3.0, 0.0)
			wall.rotation.y = PI * 0.5
			_props["post"] = _yard_piece("BayPost", Vector3(0.48, 0.9, 0.48), CylinderMesh.new(), Palette.VERDIGRIS)
			_prop("cap", _torus(0.26, 0.4), def.color, 1.8)
			_prop("tether", _stick(0.05), Palette.SAND.darkened(0.3), 0.0, false)
			_prop("discharge", _torus(0.9, 1.0), def.color, 1.8)
			for i in 3:
				_prop("trail%d" % i, _torus(0.5, 0.62), def.color, 1.4)
				_prop("dust%d" % i, _sphere(0.5), Palette.SAND, 0.0)
		"runner_gunner", "tarn":
			for i in 3:
				_props["dummy%d" % i] = _yard_piece("BayPin", Vector3(0.55, 1.2, 0.55), CylinderMesh.new(), Palette.RUST)
				_prop("bolt%d" % i, _stick(0.07), def.color, 2.6)
				_prop("dust%d" % i, _sphere(0.5), Palette.SANDSTONE, 0.0)
			for i in 4:
				_prop("chevron%d" % i, _chevron(), def.color, 1.6)
			_prop("blast", _torus(0.9, 1.05), def.color, 1.8)
		"demolitions_caster":
			for i in 3:
				_prop("charge%d" % i, _sphere(0.24), def.color, 2.0)
				_prop("boom%d" % i, _burst(), def.color, 2.2)
			for i in 5:
				_prop("smoke%d" % i, _sphere(0.6), Palette.SAND.darkened(0.25), 0.0)
			var lane := BoxMesh.new()
			lane.size = Vector3(1.0, 0.04, 0.9)
			_prop("lane", lane, def.color, 1.2)
		"remembered_cannon":
			var lane := BoxMesh.new()
			lane.size = Vector3(1.0, 0.04, 1.1)
			_prop("lane", lane, def.color, 1.2)
			for i in 2:
				var split := BoxMesh.new()
				split.size = Vector3(1.0, 0.04, 0.5)
				_prop("split%d" % i, split, def.color, 1.0)
			var plate := CylinderMesh.new()
			plate.top_radius = 1.6
			plate.bottom_radius = 1.6
			plate.height = 0.04
			plate.radial_segments = 3
			_prop("plate", plate, def.color, 1.2)
			_prop("ring", _torus(0.9, 1.05), def.color, 1.8)
			_prop("bolt", _stick(0.09), def.color, 2.6)
		"tally":
			for i in 3:
				var card := BoxMesh.new()
				card.size = Vector3(1.3, 0.14, 1.1)
				_prop("plate%d" % i, card, Palette.LEDGER, 0.0)
			_prop("surge", _torus(1.1, 1.25), def.color, 1.8)
			var stamp := BoxMesh.new()
			stamp.size = Vector3(1.8, 0.04, 1.8)
			_prop("stamp", stamp, def.color, 1.2)
			_prop("slam", _torus(0.9, 1.05), def.color, 1.8)


func _process(delta: float) -> void:
	if ball == null:
		return
	_time += delta
	# Before track_focus: seating a pilot stops its animator, which would cut a first-focus unlock.
	_step_antic()
	track_focus()
	_step_look(delta)
	if playing():
		clock += delta
	else:
		clock = _rest_phase() * LOOP
	_pose(fmod(clock, LOOP) / LOOP)
	if not playing():
		ball.position.y += BOB * sin(_time * 2.2)
		_core.rotate(Vector3.UP.cross(Vector3(sin(_heading), 0.0, cos(_heading))).normalized(), -REST_SPIN * delta)
		var toward := _camera.global_position - ball.position
		_pod.rotation.y = lerp_angle(_heading, atan2(-toward.x, -toward.z), FACE_CAMERA)
	_follow = _follow.lerp(ball.position, 1.0 - exp(-FOLLOW_RATE * delta))
	_frame(smoothstep(0.0, 1.0, open))


func _frame(k: float) -> void:
	var at := (_rest_at + NEAR_OFFSET).lerp(_follow + FOLLOW_OFFSET, k)
	_camera.fov = lerpf(NEAR_FOV, FOLLOW_FOV, k)
	_camera.transform = Transform3D(Basis.looking_at((_rest_at + NEAR_LOOK).lerp(_follow + FOLLOW_LOOK, k) - at), at)
	if look_weight > 0.001:
		var centre := ball.position + Vector3(0.0, 0.3, 0.0)
		var dir := Vector3(sin(_look.yaw) * cos(_look.pitch), sin(_look.pitch), cos(_look.yaw) * cos(_look.pitch))
		var eye: Vector3 = centre + dir * float(_look.dist)
		_camera.transform = _camera.transform.interpolate_with(Transform3D(Basis.looking_at(centre - eye), eye),
			smoothstep(0.0, 1.0, look_weight))


# The rest-pose antic: off while the card is open (the signature move owns the ball then).
func _step_antic() -> void:
	if antic == null:
		return
	var was_out: bool = antic.out
	var t := -1.0
	if not playing() and _time >= ANTIC_PERIOD and not HighdraftFx.preferred:
		var phase := fmod(_time + float(hash(String(def.id)) % 1000) / 1000.0 * ANTIC_PERIOD, ANTIC_PERIOD)
		t = (phase - (ANTIC_PERIOD - PilotAntics.LENGTH)) / PilotAntics.LENGTH
	antic.apply(t)
	if was_out and not antic.out:
		seat_pilot()


func looking() -> bool:
	return look_dragging or _look_idle < LOOK_HOLD


func _step_look(delta: float) -> void:
	if not look_dragging:
		_look_idle += delta
	var goal := 1.0 if looking() else 0.0
	look_weight = move_toward(look_weight, goal, LOOK_RATE * delta * (1.0 if goal > look_weight else 0.35))


func look_drag(rel: Vector2) -> void:
	if not looking():
		_look = {"yaw": -0.3, "pitch": 0.2, "dist": LOOK_DIST}
	_look.yaw = float(_look.yaw) - rel.x * LOOK_DRAG
	_look.pitch = clampf(float(_look.pitch) + rel.y * LOOK_DRAG, -0.2, 1.2)
	_look_idle = 0.0


func look_zoom(step: float) -> void:
	if not looking():
		look_drag(Vector2.ZERO)
	_look.dist = clampf(float(_look.dist) * pow(0.88, step), LOOK_NEAR, LOOK_FAR)
	_look_idle = 0.0


# Poses the scene at loop phase t, 0 to 1.
func _pose(t: float) -> void:
	for prop in _props.values():
		prop.visible = false
	ball.visible = true
	match def.id:
		"pylon_engineer":
			_sable(t)
		"runner_gunner", "tarn":
			_rivet(t)
		"demolitions_caster":
			_kest(t)
		"remembered_cannon":
			_cannon(t)
		"tally":
			_tally(t)
	_roll()


func _sable(t: float) -> void:
	var start := Vector3(3.6, 1.0, 0.6)
	var land := Vector3(4.2, 1.0, 0.9)
	var plant := _span(t, 0.18, 0.24)
	if plant > 0.0:
		_show("post", ANCHOR - Vector3(0.1, 0.0, 0.0), Vector3(1.0, maxf(plant, 0.01), 1.0), 1.0, Vector3(0.0, 0.0, PI * 0.5))
		_show("cap", ANCHOR + Vector3(0.35 * plant, 0.0, 0.0), Vector3.ONE * (1.0 + (0.0 if reduced_motion else 0.25 * sin(t * 40.0))), 1.0, Vector3(0.0, 0.0, PI * 0.5))
	var burst := _span(t, 0.2, 0.34)
	if burst > 0.0 and burst < 1.0:
		_show("discharge", ANCHOR + Vector3(0.1, 0.0, 0.0), Vector3.ONE * lerpf(0.5, 4.0, burst), 1.0 - burst, Vector3(0.0, 0.0, PI * 0.5))
		for i in 3:
			var drift := Vector3(0.5 + 0.4 * i, (float(i) - 1.0) * 0.8, (float(i) - 1.0) * 0.6) * burst * 1.6
			_show("dust%d" % i, ANCHOR + drift, Vector3.ONE * lerpf(0.4, 1.3, burst), 0.7 * (1.0 - burst))
	if t < 0.22:
		var f := _ease_out(_span(t, 0.0, 0.22))
		ball.position = start.lerp(_swing(0.45), f) + Vector3(0.0, 1.6 * sin(f * PI), 0.0)
	elif t < 0.56:
		ball.position = _swing(lerpf(0.45, 1.9, _ease_in(_span(t, 0.22, 0.56))))
		_line("tether", ball.position, ANCHOR + Vector3(0.35, 0.0, 0.0))
	elif t < 0.88:
		var f := _span(t, 0.56, 0.88)
		ball.position = _arc(_swing(1.9), land, 3.2, f)
		for i in 3:
			var at := _span(t, 0.6 + 0.06 * i, 0.88)
			if at > 0.0 and at < 1.0:
				var spot := _arc(_swing(1.9), land, 3.2, _span(0.6 + 0.06 * i, 0.56, 0.88))
				_show("trail%d" % i, spot, Vector3.ONE * lerpf(0.6, 1.4, at), 1.0 - at, Vector3(PI * 0.5, 0.0, 0.0))
	else:
		ball.position = land.lerp(start, _span(t, 0.88, 1.0))


# The pendulum under the wall anchor: theta 0 hangs straight down, positive swings out.
static func _swing(theta: float) -> Vector3:
	return ANCHOR + Vector3(sin(theta), -cos(theta), 0.25 * sin(theta)) * TETHER


func _rivet(t: float) -> void:
	var start := Vector3(-5.0, 1.0, 0.3)
	var stop := Vector3(4.2, 1.0, 0.3)
	var dummies := [Vector3(-1.2, 0.6, 0.3), Vector3(0.6, 0.6, -0.2), Vector3(2.2, 0.6, 0.6)]
	ball.position = start.lerp(stop, _ease_in(_span(t, 0.1, 0.5)))
	if t < 0.5:
		for i in 3:
			var f := fmod(t * 9.0 + i / 3.0, 1.0)
			var muzzle := ball.position + Vector3(1.1, 0.25, 0.0)
			_line("bolt%d" % i, muzzle + Vector3(6.0 * f, 0.0, 0.0), muzzle + Vector3(6.0 * f + 1.3, 0.0, 0.0))
	for i in 3:
		var home: Vector3 = dummies[i]
		# When the eased sprint reaches this dummy.
		var since := t - lerpf(0.1, 0.5, sqrt(_span(home.x, start.x, stop.x)))
		if since < 0.0:
			_show("dummy%d" % i, home)
		elif since < 0.3:
			var f := since / 0.3
			var side := 1.0 if i % 2 == 0 else -1.0
			_show("dummy%d" % i, home + Vector3(2.4 * f, 3.2 * 4.0 * f * (1.0 - f), side * 2.0 * f), Vector3.ONE,
				1.0, Vector3(f * 7.0, f * 5.0, f * 3.0 * side))
		elif t > 0.86:
			_show("dummy%d" % i, home, Vector3.ONE * maxf(_span(t, 0.86, 0.96), 0.01))
	if t >= 0.1 and t < 0.55:
		for i in 4:
			_show("chevron%d" % i, ball.position - Vector3(1.1 + 0.8 * i, 0.9, 0.0), Vector3.ONE * (1.0 - 0.15 * i), 1.0 - 0.22 * i)
		for i in 3:
			var kick := fmod(t * 6.0 + i / 3.0, 1.0)
			_show("dust%d" % i, ball.position + Vector3(-1.0 - 1.6 * kick, -0.6 + 0.9 * kick, (float(i) - 1.0) * 0.7),
				Vector3.ONE * lerpf(0.4, 1.2, kick), 0.6 * (1.0 - kick))
	var blast := _span(t, 0.52, 0.72)
	if blast > 0.0 and blast < 1.0:
		_show("blast", stop + Vector3(0.0, -0.8, 0.0), Vector3.ONE * lerpf(0.8, 4.5, blast), 1.0 - blast)
	if t > 0.9:
		ball.position = stop.lerp(start, _span(t, 0.9, 1.0))


func _kest(t: float) -> void:
	var start := Vector3(-3.4, 1.0, 1.0)
	var blinked := Vector3(0.1, 1.0, 1.0)
	var apex := Vector3(1.2, 5.6, 0.6)
	var land := Vector3(-2.6, 1.0, 1.2)
	var spots := [Vector3(0.4, 0.24, -0.2), Vector3(1.8, 0.24, -0.2), Vector3(3.2, 0.24, -0.2)]
	for i in 3:
		var thrown := _span(t, 0.03 + 0.07 * i, 0.1 + 0.07 * i)
		var fired := _span(t, 0.56 + 0.05 * i, 0.68 + 0.05 * i)
		if thrown > 0.0 and fired <= 0.0:
			var ready := 0.25 * sin(t * 50.0) if thrown >= 1.0 and not reduced_motion else 0.0
			_show("charge%d" % i, _arc(start, spots[i], 2.2, thrown), Vector3.ONE * (1.0 + ready))
		if fired > 0.0 and fired < 1.0:
			_show("boom%d" % i, spots[i] + Vector3(0.0, 0.5, 0.0), Vector3.ONE * lerpf(0.4, 2.6, fired), 1.0 - fired,
				Vector3(0.0, fired * 2.0, 0.0))
	var puff := _span(t, 0.28, 0.46)
	if puff > 0.0 and puff < 1.0:
		for i in 5:
			var drift := Vector3(cos(i * 1.3), 0.3 + 0.2 * i, sin(i * 1.3)) * 0.8 * puff
			_show("smoke%d" % i, start + drift, Vector3.ONE * lerpf(0.5, 1.6, puff), 0.8 * (1.0 - puff))
	var lane := _span(t, 0.42, 0.54)
	if lane > 0.0 and t < 0.74:
		var from: Vector3 = spots[0] - Vector3(0.8, 0.2, 0.0)
		var length: float = (spots[2].x - spots[0].x + 1.6) * lane
		_show("lane", from + Vector3(length * 0.5, 0.0, 0.0), Vector3(maxf(length, 0.01), 1.0, 1.0), 0.55)
	var glide := 0.0
	if t < 0.3:
		ball.position = start
	elif t < 0.38:
		ball.position = start
		ball.visible = t < 0.31
	elif t < 0.57:
		ball.position = blinked
	elif t < 0.7:
		ball.position = blinked.lerp(apex, _ease_out(_span(t, 0.57, 0.7)))
	elif t < 0.93:
		glide = 1.0
		var f := _span(t, 0.7, 0.93)
		ball.position = apex.lerp(land, f) + Vector3(0.0, 0.5 * sin(f * PI * 3.0) * (1.0 - f), 0.0)
	else:
		ball.position = land.lerp(start, _span(t, 0.93, 1.0))
	for vane in ["VaneL", "VaneR"]:
		var node := _pod.find_child(vane, true, false) as Node3D
		if node != null:
			node.rotation.z = (1.0 if vane == "VaneL" else -1.0) * glide * PI * 0.5


func _cannon(t: float) -> void:
	var start := Vector3(-3.0, 1.0, 0.4)
	var kicked := start - Vector3(2.4, 0.0, 0.0)
	var landing := start + Vector3(1.5, 0.0, 0.0)
	if t < 0.3:
		ball.position = start
	elif t < 0.42:
		ball.position = start.lerp(kicked, _ease_out(_span(t, 0.3, 0.42)))
	elif t < 0.7:
		ball.position = kicked
	elif t < 0.84:
		ball.position = _arc(kicked, landing, 2.0, _span(t, 0.7, 0.84))
	elif t < 0.96:
		ball.position = landing
	else:
		ball.position = landing.lerp(start, _span(t, 0.96, 1.0))
	if t > 0.05 and t < 0.5:
		var length := 7.0 * _span(t, 0.05, 0.2)
		_show("lane", start + Vector3(length * 0.5, -0.95, 0.0), Vector3(maxf(length, 0.01), 1.0, 1.0), 0.6)
	if t >= 0.2 and t < 0.3:
		var at := start + Vector3(7.0 * _span(t, 0.2, 0.3), 0.0, 0.0)
		_line("bolt", at, at + Vector3(1.4, 0.0, 0.0))
	if t >= 0.3 and t < 0.55:
		var alpha := 1.0 - _span(t, 0.42, 0.55)
		for i in 2:
			var side := 1.0 if i == 0 else -1.0
			_show("split%d" % i, ball.position + Vector3(-1.4, -0.95, side * 0.6), Vector3(2.8, 1.0, 1.0), alpha,
				Vector3(0.0, side * 0.35, 0.0))
	if t >= 0.5 and t < 0.7:
		var scale_by := lerpf(0.3, 1.0, _span(t, 0.5, 0.6))
		_show("plate", ball.position + Vector3(1.4, -0.95, 0.0), Vector3.ONE * scale_by, 0.6 * (1.0 - _span(t, 0.6, 0.7)))
	if t >= 0.84 and t < 0.96:
		var f := _span(t, 0.84, 0.96)
		_show("ring", landing + Vector3(0.0, -0.8, 0.0), Vector3.ONE * lerpf(0.8, 4.0, f), 1.0 - f)


# Tally: three card strokes climb a stair of ledger plates (Gather, Link, Balance Due),
# the flywheel surges on the top step, then the stamp slams down and bounces.
func _tally(t: float) -> void:
	var start := Vector3(-3.0, 1.0, 0.4)
	var tops := [Vector3(-1.6, 0.45, 0.4), Vector3(-0.3, 0.95, 0.4), Vector3(1.0, 1.45, 0.4)]
	var slam := Vector3(2.6, 1.0, 0.4)
	for i in 3:
		var stroke := _span(t, 0.04 + 0.1 * i, 0.08 + 0.1 * i)
		if stroke > 0.0 and t < 0.8:
			var top: Vector3 = tops[i]
			_show("plate%d" % i, top - Vector3(0.0, 0.07, 0.0), Vector3(1.0, maxf(_ease_out(stroke), 0.01), 1.0),
				1.0 - _span(t, 0.7, 0.8))
	var standing := start
	for i in 3:
		var hop := _span(t, 0.08 + 0.1 * i, 0.14 + 0.1 * i)
		if hop > 0.0:
			var top: Vector3 = tops[i]
			standing = _arc(standing, top + Vector3(0.0, 1.0, 0.0), 0.8, hop)
	if t < 0.62:
		ball.position = standing
	elif t < 0.72:
		ball.position = _arc(tops[2] + Vector3(0.0, 1.0, 0.0), slam, 1.6, _ease_in(_span(t, 0.62, 0.72)))
	elif t < 0.82:
		ball.position = slam + Vector3(0.0, 0.5 * sin(_span(t, 0.72, 0.82) * PI), 0.0)
	else:
		ball.position = slam.lerp(start, _span(t, 0.82, 1.0))
	var surge := _span(t, 0.4, 0.6)
	if surge > 0.0 and surge < 1.0:
		_pod.rotation.y = _heading + TAU * 2.0 * _ease_in(surge)
		_show("surge", ball.position + Vector3(0.0, -0.2, 0.0), Vector3.ONE * lerpf(0.7, 1.4, surge), 1.0 - surge * surge)
	var struck := _span(t, 0.72, 0.84)
	if struck > 0.0 and struck < 1.0:
		_show("stamp", slam + Vector3(0.0, -0.95, 0.0), Vector3.ONE * lerpf(1.3, 1.0, struck), 0.8 * (1.0 - struck))
		_show("slam", slam + Vector3(0.0, -0.8, 0.0), Vector3.ONE * lerpf(0.8, 3.6, struck), 1.0 - struck)


func _roll() -> void:
	var step := ball.position - _last
	_last = ball.position
	step.y = 0.0
	var dist := step.length()
	if dist < 0.0001 or dist > 3.0:
		return
	var axis := Vector3.UP.cross(step / dist)
	_core.transform.basis = Basis(axis, dist) * _core.transform.basis
	# The pod faces -z (hero_assets.gd _steer_pod).
	_heading = atan2(-step.x, -step.z)
	_pod.rotation.y = lerp_angle(_pod.rotation.y, _heading, 0.25)


func _show(id: String, at: Vector3, scale_by := Vector3.ONE, alpha := 1.0, spin := Vector3.ZERO) -> void:
	var prop: Node3D = _props[id]
	prop.visible = true
	prop.position = at
	prop.rotation = spin
	prop.scale = scale_by
	if prop is MeshInstance3D:
		(prop.material_override as StandardMaterial3D).albedo_color.a = alpha


# Stretches a unit stick from a to b.
func _line(id: String, a: Vector3, b: Vector3) -> void:
	var prop: MeshInstance3D = _props[id]
	var span := b - a
	if span.length() < 0.01:
		return
	prop.visible = true
	prop.position = (a + b) * 0.5
	var up := span.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	prop.basis = Basis(side, up * span.length(), side.cross(up))
	(prop.material_override as StandardMaterial3D).albedo_color.a = 1.0


# These are the practice pieces Moss sets out in his bay. Pose the holder so the
# mesh keeps its fitted size as the post grows or a pin tumbles.
func _yard_piece(part: String, size: Vector3, fallback: PrimitiveMesh, color: Color) -> Node3D:
	var holder := Node3D.new()
	holder.name = part
	_viewport.add_child(holder, true)
	var view := ModelKit.part(YARD_KIT, [part], part, holder)
	if view == null:
		view = MeshInstance3D.new()
		view.name = "MissingYardPiece"
		view.mesh = fallback
		view.material_override = _mat(color, 0.0, 1.0, false)
		holder.add_child(view)
	view.scale = size / view.mesh.get_aabb().size
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return holder


func _prop(id: String, mesh: Mesh, color: Color, emit: float, fade := true) -> void:
	var prop := _mesh(mesh, _mat(color, emit, 1.0, fade), Vector3.ZERO)
	prop.name = id
	prop.visible = false
	_props[id] = prop


func _mesh(mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_viewport.add_child(node)
	return node


func _mat(color: Color, emit: float, alpha := 1.0, fade := true) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, alpha)
	mat.roughness = 0.7
	if fade:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emit
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


static func _arc(from: Vector3, to: Vector3, height: float, f: float) -> Vector3:
	return from.lerp(to, f) + Vector3(0.0, height * 4.0 * f * (1.0 - f), 0.0)


static func _torus(inner: float, outer: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	return mesh


static func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


# A unit-tall rod, stretched by _line.
static func _stick(radius: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 1.0
	return mesh


# A flat chevron on the ground, pointing +x: Rivet's shape.
static func _chevron() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [Vector3(-0.35, 0.0, -0.6), Vector3(0.15, 0.0, 0.0), Vector3(-0.35, 0.0, 0.6),
		Vector3(0.0, 0.0, 0.6), Vector3(0.5, 0.0, 0.0), Vector3(0.0, 0.0, -0.6)]
	for tri in [[0, 1, 5], [5, 1, 4], [1, 2, 3], [1, 3, 4]]:
		for i in tri:
			st.set_normal(Vector3.UP)
			st.add_vertex(pts[i])
	return st.commit()


# Three crossed bars: Kest's starburst, the class row's `burst` shape.
static func _burst() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var angle := PI * i / 3.0
		var along := Vector3(cos(angle), sin(angle), 0.0)
		var across := Vector3(-sin(angle), cos(angle), 0.0) * 0.12
		var quad := [-along - across, along - across, along + across, -along + across]
		for tri in [[0, 1, 2], [0, 2, 3], [2, 1, 0], [3, 2, 0]]:
			for j in tri:
				st.set_normal(Vector3.BACK)
				st.add_vertex(quad[j])
	return st.commit()


static func _span(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


static func _ease_out(f: float) -> float:
	return 1.0 - (1.0 - f) * (1.0 - f)


static func _ease_in(f: float) -> float:
	return f * f
