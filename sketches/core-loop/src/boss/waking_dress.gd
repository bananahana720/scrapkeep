extends Node3D

const BossModel := preload("res://src/boss/boss_model.gd")
const Warden := preload("res://src/combat/warden.gd")

# The Waking's body: the hanging architecture (boss_waking_base.glb) and the combat seat's
# kit (boss_waking_kit.glb). Visual only. waking.gd still owns the floors, the drop timing
# and the Warden's seat; this node reads that state every physics frame and cues the clip
# that matches it, never a timer of its own. The architecture stays at the pit's centre;
# the kit rides under the Warden, so the core sits exactly at the Warden's family point.
# When either GLB is missing attach() returns null and the stub's Warden body is untouched.

const BASE := "res://assets/models/bosses/boss_waking_base.glb"
const KIT := "res://assets/models/bosses/boss_waking_kit.glb"
const COLLARS := ["CollarSpoil", "CollarSeam", "CollarBedrock"]
# Floor k's collar and the clips that warn of its drop and show it.
const FLOOR_CLIPS := [["floor_warn", "floor_drop"], ["floor_warn_seam", "floor_drop_seam"], ["floor_warn_bedrock", "floor_drop_bedrock"]]
# The pulse clips key only these parts; they ride their own players so a charge beside a floor
# warn neither cuts the collar's rise nor leaves floor_drop starting from a half-raised collar.
const PULSE_KIT := ["PressureLip0", "PressureLip1", "PressureLip2"]
const PULSE_BASE := ["IntakeVane0", "IntakeVane1", "IntakeVane2"]
const PULSE_CLIPS := ["pulse_warn", "pulse"]
# The vanes also move in these base clips, so their tracks ride the vane player with the pulse.
const VANE_CLIPS := PULSE_CLIPS + ["sleeping", "wake", "pit_defeat"]
const CORE := ["CoreShutter0", "CoreShutter1", "CoreShutter2", "CoreLive", "CoreUnready", "ReactorCore"]
# Test seam: a test points these at a missing file to prove the stub body stays.
static var base_path := BASE
static var kit_path := KIT


static func reset_for_tests() -> void:
	base_path = BASE
	kit_path = KIT
const BASE_PARTS := ["CombatSeat", "SpineInner", "IntakeVane0", "IntakeVane1", "IntakeVane2"]
const KIT_PARTS := ["CombatSeatAnchor", "CoreShutter0", "CoreLive", "CoreUnready", "PressureLip0", "CollarSpoil"]

var module
var base: Node3D
var kit: Node3D
var _base_anim: AnimationPlayer
var _kit_anim: AnimationPlayer
var _core_anim: AnimationPlayer
var _pulse_kit_anim: AnimationPlayer
var _pulse_base_anim: AnimationPlayer
var _seat: Node3D
var _open := false
var _charging := false
var _dropping := 0
var _defeated := false


# Builds the dress for a Waking module that has entered its arena; null leaves the stub body.
static func attach(owner_module):
	var base_scene := BossModel.load_scene(base_path)
	var kit_scene := BossModel.load_scene(kit_path)
	if base_scene == null or kit_scene == null or not _has_parts(base_scene, BASE_PARTS) or not _has_parts(kit_scene, KIT_PARTS):
		if base_scene != null:
			base_scene.free()
		if kit_scene != null:
			kit_scene.free()
		return null
	var dress = new()
	dress.name = "WakingDress"
	dress.module = owner_module
	owner_module.add_child(dress)
	dress.global_position = owner_module._center
	dress.setup(base_scene, kit_scene)
	return dress


static func _has_parts(scene: Node, parts: Array) -> bool:
	for part in parts:
		if scene.find_child(part, true, false) == null:
			return false
	return true


func setup(base_scene: Node3D, kit_scene: Node3D) -> void:
	base = base_scene
	kit = kit_scene
	base.name = "WakingBase"
	kit.name = "WakingKit"
	add_child(base)
	# The kit's root is the floor under the seat: the Warden stands HALF_HEIGHT above it.
	module.warden.add_child(kit)
	kit.position = Vector3.DOWN * Warden.HALF_HEIGHT
	_seat = base.find_child("CombatSeat", true, false)
	_base_anim = BossModel.player_of(base)
	_kit_anim = BossModel.player_of(kit)
	BossModel.own_clips(_base_anim)
	BossModel.own_clips(_kit_anim)
	# Each collar keeps the pose its own floor clips leave; the spine keeps the length the last
	# floor drop gave it, instead of every other clip resetting it.
	for i in COLLARS.size():
		BossModel.strip_except(_kit_anim, COLLARS[i], FLOOR_CLIPS[i])
	BossModel.strip_except(_base_anim, "SpineInner", FLOOR_CLIPS[0] + FLOOR_CLIPS[1] + FLOOR_CLIPS[2] + ["pit_defeat"])
	# The core opens on its own player so a floor or pulse clip never closes it mid-stagger.
	_core_anim = BossModel.split_player(_kit_anim, ["core_open"], CORE)
	_pulse_kit_anim = BossModel.split_player(_kit_anim, PULSE_CLIPS, PULSE_KIT)
	_pulse_base_anim = BossModel.split_player(_base_anim, VANE_CLIPS, PULSE_BASE)
	BossModel.hide_warden_body(module.warden)
	_both("wake")


func _physics_process(_delta: float) -> void:
	if module == null or not is_instance_valid(module):
		queue_free()
		return
	var warden = module.warden
	if is_instance_valid(warden):
		BossModel.hide_warden_body(warden)
		_seat.global_position = warden.global_position
		var open: bool = warden.staggered()
		if open != _open:
			_open = open
			BossModel.play(_core_anim, "core_open", not open)
		var charging: bool = warden._charging
		if charging != _charging:
			_charging = charging
			var pulse := "pulse_warn" if charging else "pulse"
			BossModel.play(_pulse_base_anim, pulse)
			BossModel.play(_pulse_kit_anim, pulse)
	var dropping: int = module._dropping
	if dropping != _dropping:
		if dropping != 0:
			_both(FLOOR_CLIPS[dropping - 1][0])
		else:
			_both(FLOOR_CLIPS[_dropping - 1][1])
		_dropping = dropping
	if module.state == module.DEFEATED and not _defeated:
		_defeated = true
		BossModel.play(_base_anim, "pit_defeat")
		BossModel.play(_pulse_base_anim, "pit_defeat")


func _both(clip: String) -> void:
	BossModel.play(_base_anim, clip)
	BossModel.play(_kit_anim, clip)
	if clip in VANE_CLIPS:
		BossModel.play(_pulse_base_anim, clip)
