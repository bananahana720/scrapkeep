extends RefCounted

const Augments := preload("res://src/augments.gd")

# Which augments are fitted, and the live state of the ones that have any. Every
# augment is on at spawn: this sketch exists to find out which of them are fun.
var enabled := {}

var hooked := false
var anchor := Vector3.ZERO
var anchor_normal := Vector3.ZERO
var rope := 0.0
var aim := Augments.no_aim()

var dash_ready := true
var dash_cooldown := 0.0
var gliding := false

var slamming := false
var slam_fall := 0.0
var slam_velocity := Vector3.ZERO
var slam_landed := 0.0
var slam_flat := 0.0

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


func _init() -> void:
	for spec in Augments.SPECS:
		enabled[spec["key"]] = true


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
	dash_cooldown = maxf(0.0, dash_cooldown - delta)


# A mode switch or respawn must never leave the ball pinned somewhere it no longer is.
func release_holds() -> void:
	plant_time = 0.0
	mounted = false
	mount_planted = false


func clear_runtime() -> void:
	for spec in Augments.SPECS:
		_stop(spec["key"])
	release_holds()
	dash_ready = true
	dash_cooldown = 0.0
	slam_landed = 0.0
	mount_block = 0.0


func _stop(key: String) -> void:
	match key:
		Augments.GRAPPLE:
			hooked = false
			aim = Augments.no_aim()
		Augments.DASH:
			dash_ready = true
		Augments.GLIDE:
			gliding = false
		Augments.SLAM:
			slamming = false
			slam_fall = 0.0
			plant_time = 0.0
		Augments.PYLON:
			mounted = false
