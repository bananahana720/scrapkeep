extends Node3D

const Specs := preload("res://src/presentation/world_fx/world_fx_specs.gd")
const Kit := preload("res://src/presentation/world_fx/world_fx_kit.gd")
const Grain := preload("res://src/presentation/world_fx/world_fx_grain.gd")
const WorldSound := preload("res://src/presentation/world_fx/world_fx_sound.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")


static var live: Array[WeakRef] = []


static func reset_for_tests() -> void:
	live.clear()

@export var set_id := ""
var emitters: Array[GPUParticles3D] = []
var impostors: Array[MeshInstance3D] = []
var slotted := true
var level := 1.0
var paused := false
var low := false
var reduced_motion := false
var _clock := 0.0
var sound: AudioStreamPlayer3D
var voiced := false
var _puffing := false
var _loop_wait := 0.0


static func make(id: String, tint := Color.TRANSPARENT) -> Node3D:
	var a: Node3D = load("res://src/presentation/world_fx/world_fx_anchor.gd").new()
	a.set_id = id
	a.name = "WorldFx_%s" % id
	if tint.a > 0.0:
		a.set_meta("tint", tint)
	return a


func _ready() -> void:
	child_exiting_tree.connect(_on_child_exiting)
	for id in Specs.SETS.get(set_id, []):
		var p := Kit.build(id)
		if has_meta("tint"):
			p.set_meta("tint", get_meta("tint"))
			p.set_instance_shader_parameter(FxLibrary.TINT, get_meta("tint"))
		Grain.apply(p, Grain.run_seed)
		add_child(p)
		emitters.append(p)
		var imp: Dictionary = Specs.SPECS[id].get("impostor", {})
		if not imp.is_empty():
			var q := Kit.quad("dot", Vector2.ONE * float(imp["size"]), Specs.colour(imp["colour"]), "mix", float(imp["alpha"]), float(imp["size"]))
			q.name = "Impostor_%s" % id
			q.position = Vector3(0, float(imp.get("lift", 0.0)), 0)
			q.visible = false
			add_child(q)
			impostors.append(q)
	for extra in Specs.EXTRAS.get(set_id, []):
		var q := Kit.quad(extra["shape"], extra["size"], Specs.colour(extra["colour"]), "mix", float(extra["alpha"]), 12.0)
		q.name = "Extra_%s" % extra["shape"]
		q.position = extra["at"]
		add_child(q)
	sound = WorldSound.voice(set_id, self)
	live.append(weakref(self))
	_apply()


func _exit_tree() -> void:
	live = live.filter(func(r): return r.get_ref() != null and r.get_ref() != self)


func _on_child_exiting(node: Node) -> void:
	if node is GPUParticles3D:
		emitters.erase(node)
	elif node is MeshInstance3D:
		impostors.erase(node)
	elif node == sound:
		sound = null


func lod_m() -> float:
	var m := 0.0
	for p in emitters:
		m = maxf(m, float(Specs.SPECS[p.get_meta("world_fx")].get("lod_m", 200.0)))
	return m


func set_level(t: float, is_paused := false) -> void:
	level = clampf(t, 0.0, 1.0)
	paused = is_paused
	_apply()


func set_quality(is_low: bool, is_reduced: bool) -> void:
	low = is_low
	reduced_motion = is_reduced
	_apply()


func set_grain(seed: int) -> void:
	for p in emitters:
		Grain.apply(p, seed)
	_apply()


func fit(half: Vector2) -> void:
	for p in emitters:
		if Specs.SPECS[p.get_meta("world_fx")].get("fit", false):
			(p.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(half.x, 0.05, half.y)
			p.visibility_aabb = AABB(Vector3(-half.x - 4.0, -6.0, -half.y - 4.0), Vector3(half.x * 2.0 + 8.0, 12.0, half.y * 2.0 + 8.0))


func set_range(distance: float, has_slot: bool) -> void:
	slotted = has_slot and distance <= lod_m()
	for q in impostors:
		q.visible = distance > lod_m()
	_apply()


func has_voice() -> bool:
	return sound != null


func set_voiced(on: bool) -> void:
	voiced = on
	_tend_sound(0.0)


func _process(delta: float) -> void:
	_clock += delta
	var pulse_of := String(WorldSound.row(set_id).get("pulse_of", "")) if sound != null else ""
	for p in emitters:
		var s: Dictionary = Specs.SPECS[p.get_meta("world_fx")]
		if s.has("pulse"):
			var beat := Grain.pulse(p)
			var on := fmod(_clock, float(beat[0])) < float(beat[1])
			p.emitting = on and _wants(p)
			if p.get_meta("world_fx") == pulse_of:
				if on and not _puffing and voiced and p.emitting and is_visible_in_tree():
					WorldSound.tend(sound, float(WorldSound.row(set_id)["db"]))
					sound.play()
					WorldSound.heard(set_id, sound)
				_puffing = on
	_tend_sound(delta)


func _tend_sound(delta: float) -> void:
	if sound == null or WorldSound.row(set_id)["play"] != "loop":
		return
	var want := voiced and slotted and not paused and is_visible_in_tree()
	if not want:
		if sound.playing:
			sound.stop()
		return
	var r := WorldSound.row(set_id)
	WorldSound.tend(sound, lerpf(float(r.get("quiet_db", r["db"])), float(r["db"]), level))
	_loop_wait -= delta
	if not sound.playing:
		sound.play()
		_loop_wait = 0.0
	if _loop_wait <= 0.0:
		_loop_wait = sound.stream.get_length()
		WorldSound.heard(set_id, sound)


func _wants(p: GPUParticles3D) -> bool:
	return slotted and not paused and p.amount_ratio > 0.0


func _apply() -> void:
	for p in emitters:
		var s: Dictionary = Specs.SPECS[p.get_meta("world_fx")]
		var share := Grain.share(p, low, reduced_motion)
		if s.get("level", false):
			share *= lerpf(0.15, 1.0, level)
			p.speed_scale = lerpf(0.6, 1.6, level)
		p.amount_ratio = clampf(share, 0.0, 1.0)
		if not s.has("pulse"):
			p.emitting = _wants(p)
