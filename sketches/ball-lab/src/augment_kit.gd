extends RefCounted

const Augments := preload("res://src/augments.gd")

# Which augments are fitted, and the live state of the ones that have any. Every
# augment is on at spawn: this sketch exists to find out which of them are fun.
var enabled := {}

var hooked := false
var anchor := Vector3.ZERO
var rope := 0.0
var aim_point = null

var dash_ready := true
var gliding := false

var slamming := false
var slam_fall := 0.0
var slam_landed := 0.0

var clinging := false
var cling_normal := Vector3.ZERO
var cling_block := 0.0


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
	cling_block = maxf(0.0, cling_block - delta)


func clear_runtime() -> void:
	for spec in Augments.SPECS:
		_stop(spec["key"])
	dash_ready = true
	slam_landed = 0.0
	cling_block = 0.0


func _stop(key: String) -> void:
	match key:
		Augments.GRAPPLE:
			hooked = false
			aim_point = null
		Augments.DASH:
			dash_ready = true
		Augments.GLIDE:
			gliding = false
		Augments.SLAM:
			slamming = false
			slam_fall = 0.0
		Augments.CLING:
			clinging = false
