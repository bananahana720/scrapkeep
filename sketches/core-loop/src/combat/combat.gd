extends Node

const Chaser := preload("res://src/combat/chaser.gd")
const Lobber := preload("res://src/combat/lobber.gd")
const Projectile := preload("res://src/combat/projectile.gd")
const Hitscan := preload("res://src/combat/hitscan.gd")
const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# Writer A's module: class weapons and specials, enemies, damage, drops and the
# miniboss. This is the spine's minimal stub. Both classes fire v2's zap as a basic
# hitscan weapon, the special is a short arc pulse, enemies take damage and die, and
# the camera goes to the shoulder view while mounted. It is also the spawner behind
# ctx.spawner. A replaces this folder wholesale; see CONTRACTS.md.

const WEAPON_RANGE := 70.0
const WEAPON_DAMAGE := 14.0
const WEAPON_KNOCK := 22.0
const WEAPON_COOLDOWN := 0.2
const BEAM_SHOW := 0.12
const SPECIAL_RADIUS := 10.0
const SPECIAL_DAMAGE := 20.0
const SPECIAL_COOLDOWN := 4.0
const MINIBOSS_HP := 320.0

# Ball contacts: base damage plus a share of the contact's force.
const STRIKE_DAMAGE := {
	"stomp": [30.0, 1.1],
	"ram": [14.0, 1.3],
	"slam": [0.0, 1.2],
}

var ctx

var _cooldown := 0.0
var _special_cooldown := 0.0
var _beam: MeshInstance3D
var _spark: MeshInstance3D
var _beam_show := 0.0


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Combat"
	ctx.spawner = self
	ctx.events.stage_entered.connect(_on_stage_entered)
	ctx.events.mounted.connect(func(_at: Vector3, _banked: float): ctx.camera.shoulder_target = 1.0)
	ctx.events.dismounted.connect(func(_v: Vector3): ctx.camera.shoulder_target = 0.0)
	_build_beam()


# Spawner API. kind is "chaser", "lobber" or "miniboss".
func spawn_enemy(kind: String, at: Vector3) -> Node3D:
	var enemy: Node3D
	if kind == "lobber":
		var lobber := Lobber.new()
		ctx.root.add_child(lobber)
		lobber.setup(ctx.player, 26.0 * _threat(), 4)
		lobber.fired.connect(_on_lobber_fired)
		enemy = lobber
	else:
		var chaser := Chaser.new()
		ctx.root.add_child(chaser)
		if kind == "miniboss":
			chaser.setup(ctx.player, MINIBOSS_HP * _threat(), 2.3, 20.0, 24)
		else:
			chaser.setup(ctx.player, 40.0 * _threat(), 1.0, 9.0, 3)
		enemy = chaser
	enemy.global_position = at
	enemy.hit_player.connect(func(amount: float): ctx.run.damage(amount, kind))
	enemy.died.connect(func(where: Vector3, scrap: int): ctx.run.record_kill(kind, where, scrap))
	ctx.events.enemy_spawned.emit(enemy, kind)
	return enemy


# Spawner API: a hit the spine or a weapon made, resolved into damage exactly once.
# The bus fact goes out before the damage so a kill never publishes a freed node.
func strike(enemy: Node3D, kind: String, force: float) -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	ctx.events.enemy_struck.emit(enemy, kind, force)
	var amount := force
	if STRIKE_DAMAGE.has(kind):
		var row: Array = STRIKE_DAMAGE[kind]
		amount = row[0] + force * row[1]
	enemy.take_damage(amount)


func _threat() -> float:
	return ctx.flow.stage_def()["threat"]


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_special_cooldown = maxf(0.0, _special_cooldown - delta)
	if ctx == null or not ctx.flow.in_play() or ctx.run.class_def == null:
		return
	var intent = ctx.player.intent
	if intent.fire_held and _cooldown <= 0.0:
		_fire()
	if intent.special_pressed and _special_cooldown <= 0.0:
		_special()


func _fire() -> void:
	_cooldown = WEAPON_COOLDOWN
	var weapon: String = ctx.run.class_def.weapon_id
	var kind := "arc" if weapon == "arc_caster" else "runner"
	var shot := Hitscan.cast(ctx.root.get_world_3d().direct_space_state, ctx.aim_origin(), ctx.aim_forward(),
		ctx.player.ball_position(), WEAPON_RANGE)
	_show_beam(shot["from"], shot["to"])
	ctx.events.shot_fired.emit(weapon, shot["from"], shot["to"])
	var enemy: Node3D = shot["enemy"]
	if enemy == null:
		return
	var away: Vector3 = enemy.global_position - shot["from"]
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	enemy.knock(away + Vector3.UP * 0.3, WEAPON_KNOCK)
	enemy.flash()
	strike(enemy, kind, WEAPON_DAMAGE)


func _special() -> void:
	_special_cooldown = SPECIAL_COOLDOWN
	var at: Vector3 = ctx.player.ball_position()
	ctx.events.special_used.emit(ctx.run.class_def.special_id, at)
	var kind := "turret" if ctx.player.kit.mounted else "runner"
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.global_position.distance_to(at) <= SPECIAL_RADIUS:
			enemy.knock(enemy.global_position - at, WEAPON_KNOCK)
			strike(enemy, kind, SPECIAL_DAMAGE)


func _on_lobber_fired(origin: Vector3, launch_velocity: Vector3) -> void:
	var shot := Projectile.new()
	shot.add_to_group("enemy_shot")
	ctx.root.add_child(shot)
	shot.setup(ctx.player, ctx.terrain, origin, launch_velocity)
	shot.hit_player.connect(func(amount: float): ctx.run.damage(amount, "lobber"))


# A stage entry or retry starts the fight clean.
func _on_stage_entered(_stage: int, _retry: bool) -> void:
	for node in get_tree().get_nodes_in_group("enemy"):
		node.queue_free()
	for node in get_tree().get_nodes_in_group("enemy_shot"):
		node.queue_free()
	ctx.camera.shoulder_target = 0.0
	_cooldown = 0.0
	_special_cooldown = 0.0


func _process(delta: float) -> void:
	_beam_show = maxf(0.0, _beam_show - delta)
	_beam.visible = _beam_show > 0.0
	_spark.visible = _beam.visible


func _build_beam() -> void:
	var tint := EventKinds.color("shot_fired")
	_beam = MeshInstance3D.new()
	_beam.mesh = ImmediateMesh.new()
	_beam.material_override = Palette.unshaded(tint)
	_beam.visible = false
	add_child(_beam)
	# Seen from behind the ball the beam runs almost along the view, so the spark at
	# the far end is what actually shows where the shot landed.
	_spark = MeshInstance3D.new()
	var spark := SphereMesh.new()
	spark.radius = 0.45
	spark.height = 0.9
	_spark.mesh = spark
	_spark.material_override = Palette.unshaded(tint)
	_spark.visible = false
	add_child(_spark)


func _show_beam(from: Vector3, to: Vector3) -> void:
	var line: ImmediateMesh = _beam.mesh
	line.clear_surfaces()
	line.surface_begin(Mesh.PRIMITIVE_LINES)
	line.surface_add_vertex(from)
	line.surface_add_vertex(to)
	line.surface_end()
	_spark.global_position = to
	_beam_show = BEAM_SHOW
