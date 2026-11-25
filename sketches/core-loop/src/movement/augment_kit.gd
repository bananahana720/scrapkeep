extends RefCounted

const Augments := preload("res://src/movement/augments.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")

var enabled := {}
var movement_id := ""
var smash_id := ""
var smash_flavour := ""
var abilities = AbilityState.new()
var tree = UpgradeTree.new()
var cloaked := false

var hooked := false
var anchor := Vector3.ZERO
var anchor_normal := Vector3.ZERO
var rope := 0.0
var aim := Augments.no_aim()

var on_body := false
var anchor_body: Node3D = null
var anchor_offset := Vector3.ZERO
var line_state := Augments.LINE_IDLE
var winching := false
var reel_body: Node3D = null
var reel_left := 0.0
var line_end := ""
var smash_left := 0.0
var smash_floor := 0.0
var line_closing := 0.0
var lock_body: Node3D = null
var grip := ""
var pole_time := 0.0
var rewind_left := 0.0

var gliding := false

var slamming := false
var slam_fall := 0.0
var slam_velocity := Vector3.ZERO
var slam_landed := 0.0
var slam_flat := 0.0
var brake_from_ground := false

var plant_time := 0.0
var plant_total := 0.0
var plant_at := Vector3.ZERO
var plant_normal := Vector3.UP
var plant_exit := Vector3.ZERO
var plant_jump := false
var plant_boost := false

var mounted := false
var mount_point := Vector3.ZERO
var mount_face := Vector3.ZERO
var mount_normal := Vector3.ZERO
var mount_block := 0.0
var mount_planted := false
var mount_banked := 0.0
var dismount_fired := false
var dismount_velocity := Vector3.ZERO
var slingshot = AbilityState.Gauge.new(Augments.SLINGSHOT_CHARGE)
var slingshot_aim := {}

var vault_faces := {}
var last_vault_face := ""
var vault_aim := {}

var mass_on := false
var mass_q := 0.0
var mass_gap := 0.0

var sprinting := false
var sprint_left := 0.0

var facts: Array = []


func _init() -> void:
	fit(Augments.DEFAULT_MOVEMENT, "")


func fit(movement: String, smash: String) -> void:
	movement_id = movement
	smash_id = smash
	smash_flavour = AbilityState.ABILITIES.get(smash, {}).get("flavour", "")
	var keys: Array = AbilityState.ABILITIES.get(movement, {}).get("augments", []) + Augments.SHARED
	keys = keys + [Augments.GRAPPLE]
	for spec in Augments.SPECS:
		set_on(spec["key"], spec["key"] in keys)


func knob(name: String):
	return tree.knob(name)


func on(key: String) -> bool:
	return enabled.get(key, false)


func set_on(key: String, value: bool) -> void:
	enabled[key] = value
	if not value:
		_stop(key)


func toggle(key: String) -> bool:
	set_on(key, not on(key))
	return enabled[key]


func tick_timers(delta: float) -> void:
	mount_block = maxf(0.0, mount_block - delta)
	reel_left = maxf(0.0, reel_left - delta)
	if reel_left <= 0.0:
		reel_body = null
	rewind_left = maxf(0.0, rewind_left - delta)
	mass_gap = maxf(0.0, mass_gap - delta)
	for key in vault_faces.keys():
		vault_faces[key] -= delta
		if vault_faces[key] <= 0.0:
			vault_faces.erase(key)


func refresh_vault() -> void:
	vault_faces.erase(last_vault_face)


func release_holds() -> void:
	plant_time = 0.0
	mounted = false
	mount_planted = false
	dismount_fired = false
	slingshot.cancel()


func drop_line(end := "let_go") -> void:
	if hooked:
		line_end = end
	hooked = false
	on_body = false
	anchor_body = null
	grip = ""
	pole_time = 0.0
	line_state = Augments.LINE_IDLE
	winching = false
	smash_left = 0.0
	smash_floor = 0.0
	line_closing = 0.0


func clear_runtime() -> void:
	for spec in Augments.SPECS:
		_stop(spec["key"])
	release_holds()
	slam_landed = 0.0
	brake_from_ground = true
	mount_block = 0.0
	mount_banked = 0.0
	vault_faces.clear()
	reel_body = null
	reel_left = 0.0
	mass_gap = 0.0
	last_vault_face = ""
	vault_aim = {}
	slingshot_aim = {}
	lock_body = null
	rewind_left = 0.0
	facts.clear()


func _stop(key: String) -> void:
	match key:
		Augments.GRAPPLE:
			drop_line("reset")
			aim = Augments.no_aim()
		Augments.GLIDE:
			gliding = false
		Augments.SLAM:
			slamming = false
			slam_fall = 0.0
			plant_time = 0.0
		Augments.PYLON:
			mounted = false
			slingshot.cancel()
		Augments.SPRINT:
			sprinting = false
			sprint_left = 0.0
			abilities.slot(AbilityState.MOVEMENT).active = false
		Augments.VAULT:
			vault_aim = {}
