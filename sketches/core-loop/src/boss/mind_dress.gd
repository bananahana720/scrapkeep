extends Node3D

const AppShell := preload("res://src/core/app_shell.gd")
const BossModel := preload("res://src/boss/boss_model.gd")
const Warden := preload("res://src/combat/warden.gd")

# The Mind's body: the open crown over the pad (boss_mind_base.glb) and the combat seat's kit
# (boss_mind_kit.glb) under the choir Warden. Visual only. mind.gd still owns every attack,
# hazard and hand; this node reads that state each physics frame and cues the clip that
# matches it, so a body cue starts on the frame its hazard commits, goes live and ends.
# The lens follows the Warden's real open choir seat (family_point_at) and never moves a
# collider. A missing GLB makes attach() return null and the stub's Warden body stays.

const BASE := "res://assets/models/bosses/boss_mind_base.glb"
const KIT := "res://assets/models/bosses/boss_mind_kit.glb"
# Test seam: a test points these at a missing file to prove the stub body stays.
static var base_path := BASE
static var kit_path := KIT


static func reset_for_tests() -> void:
	base_path = BASE
	kit_path = KIT
const BASE_PARTS := ["CombatSeat", "CrownFrame", "Mantle0", "Mantle5"]
const KIT_PARTS := ["CombatSeat", "LensRoot", "Shutter0", "PulseLip", "FamilyRecoil", "EmitterL", "BracePlate", "RushCollar"]
const FAMILY_CLIPS := {"lane": "lane_warn", "split_lane": "split_lane_warn", "rush": "rush_warn", "plate": "plate_warn"}
# Phase p breaks one more mantle: phase 2 sheds the first, 3 the second, 4 the third.
const PHASE_CLIPS := {2: "phase_break", 3: "phase_break_2", 4: "phase_break_3"}
# All hands (Andrew, 2026-10-18): the crew were the Mind's hands, so a body built as a hand
# carries the old roster's stencils on its fingers and clocks one out per phase, little finger
# (04) first, and its defeat sets a glove down by the empty place. A base with these clips
# plays them in place of the mantle breaks and final_quiet; one without them keeps those.
const CLOCK_OUT_CLIPS := {2: "clock_out_04", 3: "clock_out_03", 4: "clock_out_02"}
const DEFEAT_CLIP := "glove_down"
const SHUTTERS := ["Shutter0", "Shutter1", "Shutter2", "Shutter3", "Shutter4", "Shutter5"]
# How fast the lens settles onto a new choir seat; the clips' own change is 0.6 s.
const LENS_SETTLE := 8.0
# How far a warn clip may be stretched or squeezed to fit its sim timer.
const WARN_SPEED_MIN := 0.5
const WARN_SPEED_MAX := 2.0

var module
var base: Node3D
var kit: Node3D
var _base_anim: AnimationPlayer
var _kit_anim: AnimationPlayer
var _lens_anim: AnimationPlayer
var _pulse_anim: AnimationPlayer
var _lens: Node3D
var _recoil: Node3D
var _open := false
var _charging := false
var _phase := 1
var _attack_seen := 0
var _hands_seen := 0
var _current := {}
var _defeated := false
var _lens_placed := false


# Reads the base and kit ahead on loader threads while the approach runs (mind.gd's prepare_arena):
# loading them took 18 to 31 ms of the boss-entry frame on the cloud (scrapkeep#241).
static func prepare() -> void:
	# Headless loads stay on the main thread: the dummy rasterizer's mesh RIDs are not thread-safe.
	if AppShell.headless():
		return
	for path in [base_path, kit_path]:
		if ResourceLoader.exists(path) and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(path)


# Teardown: collects the files prepare() asked for that attach never took.
static func settle() -> void:
	for path in [base_path, kit_path]:
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_get(path)


static func attach(owner_module):
	preload("res://src/presentation/quiet_gun.gd").attach(owner_module)
	# The loader thread's copies, held so load_scene's load() finds them in the cache.
	var _read := [_take(base_path), _take(kit_path)]
	var base_scene := BossModel.load_scene(base_path)
	var kit_scene := BossModel.load_scene(kit_path)
	if base_scene == null or kit_scene == null or not _has_parts(base_scene, BASE_PARTS) or not _has_parts(kit_scene, KIT_PARTS):
		if base_scene != null:
			base_scene.free()
		if kit_scene != null:
			kit_scene.free()
		return null
	var dress = new()
	dress.name = "MindDress"
	dress.module = owner_module
	owner_module.add_child(dress)
	dress.global_position = owner_module.pad.global_position + Vector3.UP * owner_module.PAD_THICK * 0.5
	dress.setup(base_scene, kit_scene)
	return dress


# A file prepare() asked for, from its loader thread (waiting if it is still loading); null when
# nothing asked, and load_scene loads it.
static func _take(path: String) -> Resource:
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		return ResourceLoader.load_threaded_get(path)
	return null


static func _has_parts(scene: Node, parts: Array) -> bool:
	for part in parts:
		if scene.find_child(part, true, false) == null:
			return false
	return true


func setup(base_scene: Node3D, kit_scene: Node3D) -> void:
	base = base_scene
	kit = kit_scene
	base.name = "MindBase"
	kit.name = "MindKit"
	add_child(base)
	module.warden.add_child(kit)
	kit.position = Vector3.DOWN * Warden.HALF_HEIGHT
	_base_anim = BossModel.player_of(base)
	_kit_anim = BossModel.player_of(kit)
	BossModel.own_clips(_base_anim)
	BossModel.own_clips(_kit_anim)
	BossModel.loop_clip(_kit_anim, "attention")
	_lens = kit.find_child("LensRoot", true, false)
	_recoil = kit.find_child("FamilyRecoil", true, false)
	# Code owns where the lens is and what it faces; the lens shutters and the pulse lip each
	# get their own player so a stagger or a pulse can run beside any family cue.
	BossModel.strip_tracks(_kit_anim, "LensRoot")
	_lens_anim = BossModel.split_player(_kit_anim, ["stagger_open"], SHUTTERS)
	_pulse_anim = BossModel.split_player(_kit_anim, ["pulse_warn", "pulse"], ["PulseLip"])
	BossModel.hide_warden_body(module.warden)
	BossModel.play(_kit_anim, "attention")


func _physics_process(delta: float) -> void:
	if module == null or not is_instance_valid(module):
		queue_free()
		return
	var warden = module.warden
	if is_instance_valid(warden):
		BossModel.hide_warden_body(warden)
		_step_lens(warden, delta)
		var open: bool = warden.staggered()
		if open != _open:
			_open = open
			BossModel.play(_lens_anim, "stagger_open", not open)
		var charging: bool = warden._charging
		if charging != _charging:
			_charging = charging
			BossModel.play(_pulse_anim, "pulse_warn" if charging else "pulse")
	var phase: int = module.phase
	if phase != _phase:
		if phase > _phase and PHASE_CLIPS.has(phase):
			if not BossModel.play(_base_anim, CLOCK_OUT_CLIPS[phase]):
				BossModel.play(_base_anim, PHASE_CLIPS[phase])
		_phase = phase
	_step_attack()
	if module.state == module.DEFEATED and not _defeated:
		_defeated = true
		if not BossModel.play(_base_anim, DEFEAT_CLIP):
			BossModel.play(_base_anim, "final_quiet")
		BossModel.play(_kit_anim, "final_quiet")


# The lens sits on the seat the Warden has open and faces the ball.
func _step_lens(warden, delta: float) -> void:
	var seat: Vector3 = warden.family_point_at()
	if _lens_placed:
		_lens.global_position = _lens.global_position.lerp(seat, 1.0 - exp(-LENS_SETTLE * delta))
	else:
		_lens.global_position = seat
		_lens_placed = true
	var to: Vector3 = module.ctx.player.ball_position() - _lens.global_position
	if to.length() > 0.5:
		_lens.global_basis = Basis.looking_at(to.normalized(), Vector3.UP if absf(to.normalized().y) < 0.95 else Vector3.FORWARD)


# One clip per committed attack: the warn on commit, the snap when its hazard goes live, the
# release when every hazard of the attack is done.
func _step_attack() -> void:
	if module.attack_count != _attack_seen and not module.attacks.is_empty():
		_attack_seen = module.attack_count
		_current = {"attack": module.attacks.back(), "struck": false}
		var family: String = String(_current["attack"]["family"])
		_aim(_current["attack"])
		var warn_clip: String = FAMILY_CLIPS.get(family, "lane_warn")
		BossModel.play(_kit_anim, warn_clip, false, -1.0, _warn_speed(warn_clip, _current["attack"]))
		_hands_seen = module.hands.size()
		return
	if _current.is_empty():
		return
	var live := false
	var done := true
	for h in _current["attack"]["hazards"]:
		if is_instance_valid(h):
			live = live or h.is_live()
			done = done and h.is_done()
	if live and not _current["struck"]:
		_current["struck"] = true
		BossModel.play(_kit_anim, "family_strike")
	elif done:
		var sent: bool = module.hands.size() > _hands_seen
		_hands_seen = module.hands.size()
		BossModel.play(_kit_anim, "hand_send" if sent else "recovery")
		_current = {}


# From phase 2 the sim tightens each warn below its clip's authored length, so the strike cut
# the clip short. The clip is stretched to end exactly when the hazard's own warn timer does;
# the timer itself is only read.
func _warn_speed(clip: String, attack: Dictionary) -> float:
	var hazards: Array = attack["hazards"]
	if hazards.is_empty() or not is_instance_valid(hazards[0]) or not _kit_anim.has_animation(clip):
		return 1.0
	var warn: float = hazards[0].warn_seconds
	if warn <= 0.0:
		return 1.0
	return clampf(_kit_anim.get_animation(clip).length / warn, WARN_SPEED_MIN, WARN_SPEED_MAX)


# Emitters yaw to the committed bearing: a lane's heading, or the middle of a plate's sector.
func _aim(attack: Dictionary) -> void:
	for h in attack["hazards"]:
		if not is_instance_valid(h):
			continue
		var dir := Vector3.ZERO
		if h.shape == h.Shape.LANE:
			dir = h.heading
		elif h.shape == h.Shape.SECTOR:
			var angle: float = (h.a_from + h.a_to) * 0.5
			dir = Vector3(cos(angle), 0.0, sin(angle))
		if dir.length() > 0.1:
			_recoil.global_basis = Basis.looking_at(dir.normalized(), Vector3.UP)
		return
