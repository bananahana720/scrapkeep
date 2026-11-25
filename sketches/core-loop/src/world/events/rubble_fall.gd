extends Node3D


const FoleyAudio := preload("res://src/presentation/foley_audio.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const FloorRule := preload("res://src/combat/floor_rule.gd")
const WarningGap := preload("res://src/world/events/warning_gap.gd")

const LIVE_S := 0.25
const REACH_M := 3.5

signal landed(crushed: Array, hit_ball: bool)

var id := ""
var centre := Vector3.ZERO
var radius := 4.0
var warn_s := Hazard.MIN_WARN
var enemy_damage := 0.0
var terrain
var player
var on_ball := Callable()
var voice := ""
var tag := ""
var on_crush := Callable()
var spare_id := 0
var warn_sound := ""
var land_sound := ""
var land_lead := 0.0
var _land_played := false
var hazard: Hazard
var crushed: Array = []
var hit_ball := false
var waited := 0

var _slab: Node3D
var _slab_from := 0.0
var _done := false
var _landed := false


func configure(fall_id: String, at: Vector3, disc_radius: float, warn: float, terrain_ref, player_ref, ball_hit: Callable,
		damage_to_enemies := 0.0, slab: Node3D = null) -> void:
	id = fall_id
	centre = at
	radius = disc_radius
	warn_s = maxf(Hazard.MIN_WARN, warn)
	terrain = terrain_ref
	player = player_ref
	on_ball = ball_hit
	enemy_damage = damage_to_enemies
	name = "RubbleFall_%s" % fall_id
	if slab != null:
		_slab = slab
		add_child(slab)
		_slab_from = slab.global_position.y if slab.is_inside_tree() else slab.position.y


func committed() -> bool:
	return hazard != null


func _physics_process(delta: float) -> void:
	if _done:
		return
	if hazard == null:
		if not WarningGap.open(get_tree()):
			waited += 1
			return
		_commit()
		return
	hazard.step(delta)
	if land_sound != "" and not _land_played and hazard.age >= hazard.warn_seconds - land_lead:
		_land_played = true
		FoleyAudio.one_shot(land_sound, get_parent(), centre)
	if _slab != null:
		var t := clampf(hazard.age / hazard.warn_seconds, 0.0, 1.0)
		var floor_y := ground_at(centre)
		_slab.global_position.y = lerpf(_slab_from, floor_y + 0.3, t * t)
	if hazard.is_live():
		_land()
	if hazard.is_done():
		_finish()


func _commit() -> void:
	hazard = Hazard.new()
	hazard.ground = ground_at
	hazard.commit_annulus(id, Threat.Type.INSTANT, centre, Vector2(0.0, radius), REACH_M, warn_s, LIVE_S)
	hazard.owner_voice = voice
	hazard.mechanic_tag = tag
	add_child(hazard)
	WarningGap.stamp(get_tree(), self)
	if warn_sound != "":
		FoleyAudio.one_shot(warn_sound, get_parent(), centre)
	if _slab != null:
		_slab_from = _slab.global_position.y


func ground_at(point: Vector3) -> float:
	return float(terrain.height(point.x, point.z)) if terrain != null and is_instance_valid(terrain) else centre.y


func _land() -> void:
	if _landed:
		return
	_landed = true
	if player != null and is_instance_valid(player):
		var ball: Vector3 = player.ball_position()
		if hazard.contains(ball) and FloorRule.on_floor(player.state):
			hit_ball = true
			if on_ball.is_valid():
				on_ball.call()
	if enemy_damage > 0.0:
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
				continue
			if enemy.has_method("is_dead") and enemy.is_dead():
				continue
			if hazard.contains(enemy.global_position):
				crushed.append(enemy.get_instance_id())
				enemy.take_damage(enemy_damage)
	if on_crush.is_valid() and crushed.any(func(enemy_id: int) -> bool: return enemy_id != spare_id):
		on_crush.call(player.ball_position() if player != null and is_instance_valid(player) else centre)
	landed.emit(crushed, hit_ball)


func _finish() -> void:
	_done = true
	if hazard != null:
		hazard.finish()
	queue_free()
