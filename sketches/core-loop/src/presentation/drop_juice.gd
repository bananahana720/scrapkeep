extends Node3D

const Palette := preload("res://src/core/palette.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")

# The v3 drop mode's own juice (LOOP-REDESIGN section 7, "Belongs to the loop modes"),
# kept apart from the universal layer W11 owns (juice.gd, vfx.gd). Every piece reads a
# bus fact or the Warden's drop record (warden_drop.gd), so nothing here decides an
# outcome, and none of it exists outside a drop-mode fight:
#   - It is open now: a class-colour beam stands on the core while the window runs,
#     BEAM_PER_SECOND tall per second left, so it shrinks as the window runs out and a
#     longer window (a bonus core, a held door) reads as a taller beam.
#   - The landing: DROP_HIT_STOP of hit-stop (the spine caps it at 60 ms), an FOV punch,
#     a chunk of the god falling off, the reward ladder one rung per segment lost, and
#     the rebound's spring snap pitched by the arrival speed.
#   - The held door: each weapon hit that holds it ticks, climbing.
#   - I dodged it: the near-miss whip and a short streak behind the ball.
#   - The cage (section 8, Anticipation 4): the break reward hangs over the Warden in a
#     cage of the gate toppers' rarity frames, one frame more per bonus core, and drops
#     when the Warden breaks.

const BEAM_PER_SECOND := 6.0
const BEAM_RADIUS := 0.7
const DROP_HIT_STOP := 0.06
const CAGE_RISE := 9.0
const CAGE_RADIUS := 2.2
const CAGE_TIERS := ["common", "uncommon", "rare"]
const CHUNK_SECONDS := 2.2
const STREAK_SECONDS := 0.3

var ctx
var audio
var beam: MeshInstance3D
var cage: Node3D
var chunks := 0
var drops_heard := 0
var near_misses_heard := 0

var _beam_mat: StandardMaterial3D
var _held := 0
var _cage_frames := -1


func setup(ctx_ref, audio_ref) -> void:
	ctx = ctx_ref
	audio = audio_ref
	name = "DropJuice"
	_beam_mat = Palette.unshaded(Color(Palette.SAND, 0.55))
	beam = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = BEAM_RADIUS
	mesh.bottom_radius = BEAM_RADIUS
	mesh.height = 1.0
	beam.mesh = mesh
	beam.material_override = _beam_mat
	beam.visible = false
	add_child(beam)
	var events = ctx.events
	events.warden_state_changed.connect(_on_state)
	events.warden_window_held.connect(_on_held)
	events.warden_drop_landed.connect(_on_drop)
	events.warden_near_miss.connect(_on_near_miss)
	events.stage_entered.connect(func(_stage: int, _retry: bool): _clear_cage())
	events.beacon_unsealed.connect(func(_stage: int): _release_cage())


func _drop_record():
	var warden = ctx.flow.warden if ctx.flow != null else null
	if not is_instance_valid(warden):
		return null
	return warden.get("drop")


func _process(_delta: float) -> void:
	var drop = _drop_record()
	var left: float = drop.window_left() if drop != null else 0.0
	beam.visible = left > 0.0
	if beam.visible:
		var height := BEAM_PER_SECOND * left
		var at: Vector3 = drop.warden.family_point_at()
		beam.scale = Vector3(1.0, height, 1.0)
		beam.global_position = at + Vector3.UP * height * 0.5
		_beam_mat.albedo_color = Color(ctx.player.class_color(), 0.6)
	if drop != null:
		_dress_cage(drop)


func _on_state(state: String, _at: Vector3) -> void:
	audio.play("warden_state_changed")
	if state == "open":
		_held = 0


func _on_held(_at: Vector3, _seconds_left: float) -> void:
	_held += 1
	audio.play("warden_window_held", -4.0, pow(2.0, Harmony.pentatonic_step(mini(_held, 10)) / 12.0))


func _on_drop(at: Vector3, speed: float, segments_left: int, segments: int) -> void:
	drops_heard += 1
	ctx.hit_stop(DROP_HIT_STOP)
	ctx.camera.punch_fov(clampf(6.0 + speed * 0.2, 6.0, 14.0), 0.35)
	ctx.camera.shake(0.6)
	audio.play("warden_drop_landed")
	var rung := segments - segments_left
	audio.play("warden_drop_landed", -2.0, pow(2.0, Harmony.pentatonic_step(rung + 5) / 12.0), "SFX", "part_get")
	audio.play("warden_drop_landed", -3.0, clampf(speed / 25.0, 0.8, 1.6), "SFX", "pylon_eject")
	_chunk(at)


func _on_near_miss(at: Vector3) -> void:
	near_misses_heard += 1
	audio.play("warden_near_miss", 0.0, 1.35)
	var v: Vector3 = ctx.player.state.velocity
	var back := -v.normalized() if v.length() > 1.0 else Vector3.UP
	var streak := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.25, 0.25, 4.0)
	streak.mesh = mesh
	streak.material_override = Palette.unshaded(Color(ctx.player.class_color(), 0.8))
	add_child(streak)
	streak.global_position = at + back * 2.5
	streak.look_at(at + back * 5.0, Vector3.UP if absf(back.y) < 0.95 else Vector3.RIGHT)
	var tween := streak.create_tween()
	tween.tween_property(streak, "scale", Vector3(0.1, 0.1, 1.6), STREAK_SECONDS)
	tween.tween_callback(streak.queue_free)


# A piece of the god falls off: a slate chunk off the core's rim, tumbling to the floor.
func _chunk(at: Vector3) -> void:
	chunks += 1
	var chunk := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.4, 0.9, 1.1)
	chunk.mesh = mesh
	chunk.material_override = Palette.solid(Palette.CHARCOAL.lerp(Palette.VERDIGRIS, 0.35))
	add_child(chunk)
	var out := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	chunk.global_position = at + out * 2.2
	var floor_y: float = ctx.terrain.height(at.x + out.x * 5.0, at.z + out.z * 5.0) + 0.45
	var tween := chunk.create_tween().set_parallel(true)
	tween.tween_property(chunk, "global_position", Vector3(at.x + out.x * 5.0, floor_y, at.z + out.z * 5.0), 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(chunk, "rotation", Vector3(randf_range(2.0, 5.0), randf_range(-3.0, 3.0), randf_range(2.0, 5.0)), 0.7)
	tween.chain().tween_interval(CHUNK_SECONDS)
	tween.chain().tween_callback(chunk.queue_free)


# The cage over the Warden: one topper frame per gate tier the stage's cores buy.
func _dress_cage(drop) -> void:
	var frames := 1 + mini(int(ctx.run.bonus_cores), CAGE_TIERS.size() - 1)
	if cage != null and frames == _cage_frames:
		return
	if cage == null:
		cage = Node3D.new()
		cage.name = "BreakCage"
		add_child(cage)
		cage.global_position = drop.warden.global_position + Vector3.UP * CAGE_RISE
		for i in 4:
			var bar := MeshInstance3D.new()
			var bm := CylinderMesh.new()
			bm.top_radius = 0.08
			bm.bottom_radius = 0.08
			bm.height = 3.0
			bar.mesh = bm
			bar.material_override = Palette.solid(Palette.COPPER)
			var a := TAU * i / 4.0
			bar.position = Vector3(cos(a) * CAGE_RADIUS, 0.0, sin(a) * CAGE_RADIUS)
			cage.add_child(bar)
		var hoop := MeshInstance3D.new()
		var hm := TorusMesh.new()
		hm.inner_radius = CAGE_RADIUS - 0.12
		hm.outer_radius = CAGE_RADIUS + 0.12
		hoop.mesh = hm
		hoop.material_override = Palette.solid(Palette.COPPER)
		hoop.position = Vector3.UP * 1.5
		cage.add_child(hoop)
	for child in cage.get_children():
		if child.name.begins_with("Frame"):
			child.queue_free()
	for i in frames:
		var tier: String = CAGE_TIERS[i]
		var topper: MeshInstance3D = RewardGates._topper(tier, Palette.solid(Palette.AMBER if tier != "common" else Palette.SAND, 2.0))
		topper.name = "Frame%d" % i
		topper.position = Vector3((i - (frames - 1) * 0.5) * 1.1, 0.0, 0.0)
		cage.add_child(topper)
	_cage_frames = frames


func _release_cage() -> void:
	if cage == null:
		return
	var falling := cage
	cage = null
	_cage_frames = -1
	var ground: float = ctx.terrain.height(falling.global_position.x, falling.global_position.z) + 1.5
	var tween := falling.create_tween()
	tween.tween_property(falling, "global_position:y", ground, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.5)
	tween.tween_callback(falling.queue_free)


func _clear_cage() -> void:
	if cage != null:
		cage.queue_free()
	cage = null
	_cage_frames = -1
