extends "res://src/world/device.gd"

const Parts := preload("res://src/build/parts.gd")

# A cracked wall and the buried cache behind it, the secrets family (LOOP-REDESIGN
# section 9): a verdigris concrete pocket with a charcoal groove, its open side walled
# off by a cracked face. The wall is the ask. Meet it at BREAK_SPEED, or sprinting at
# SPRINT_SPEED, or land a smash beside it, and it crumbles the tick before contact, so
# the ball keeps its speed; slower, it is a wall. The sealed cache's gauge is how fast
# you are coming at the wall, so the ring filling says what the wall wants.
#
# Inside, E opens the chest (the one place on the map you stop on purpose) and three
# parts rise on pedestals; roll onto one to take it and the others sink.

const BREAK_SPEED := 18.0
const SPRINT_SPEED := 8.0
const WALL_REACH := 3.0
const SLAM_REACH := 7.0
const HALF_W := 6.0
const HALF_D := 5.0
const HEIGHT := 6.0
const SINK := 1.5
const PICKS := 3
const PICK_RARITIES := ["common", "rare"]
# Left of the chest, the chest itself, right of it: along the back wall, so the ball
# that stopped to open it is clear of all three.
const PEDESTALS := [Vector3(-4.0, 0.0, -3.0), Vector3(0.0, 0.0, -3.5), Vector3(4.0, 0.0, -3.0)]
const PEDESTAL_REACH := 1.7

enum { SEALED, OPEN, PICKING, TAKEN }

var state := SEALED
var offers: Array = []
var taken := ""
var _wall: Node3D
var _lid: Node3D
var _pedestals: Array = []
var _inside: Array = []


func _init() -> void:
	family = "secret"


func build() -> void:
	var concrete := Palette.striped(Palette.VERDIGRIS, Palette.CHARCOAL)
	var groove := Palette.solid(Palette.CHARCOAL)
	var tall := HEIGHT + SINK
	var mid := tall * 0.5 - SINK
	box(Vector3(HALF_W * 2.0 + 2.0, tall, 1.0), Vector3(0.0, mid, -HALF_D - 0.5), concrete, true)
	for s in [-1.0, 1.0]:
		box(Vector3(1.0, tall, HALF_D * 2.0 + 2.0), Vector3(s * (HALF_W + 0.5), mid, 0.0), concrete, true)
	box(Vector3(HALF_W * 2.0 + 2.0, 1.0, HALF_D * 2.0 + 2.0), Vector3(0.0, HEIGHT + 0.5, 0.0), concrete, true)
	box(Vector3(HALF_W * 2.0 + 2.2, 0.35, 0.3), Vector3(0.0, HEIGHT * 0.55, HALF_D + 1.05), groove)
	_wall = box(Vector3(HALF_W * 2.0, tall, 1.0), Vector3(0.0, mid, HALF_D + 0.5), Palette.striped(Palette.SANDSTONE, Palette.VERDIGRIS), true)
	for k in 3:
		var crack := box(Vector3(HALF_W * 1.3, 0.2, 1.1), Vector3(0.0, -1.2 + k * 1.6, 0.0), groove, false, _wall)
		crack.rotation.z = 0.5 - k * 0.45
	var chest := Vector3(0.0, 0.0, -HALF_D + 1.2)
	chest.y = ground_y(chest)
	box(Vector3(2.0, 1.2, 1.4), chest + Vector3.UP * 0.6, Palette.solid(Palette.VERDIGRIS))
	box(Vector3(2.05, 0.18, 1.45), chest + Vector3.UP * 0.8, groove)
	_lid = box(Vector3(2.1, 0.3, 1.5), chest + Vector3.UP * 1.35, Palette.solid(Palette.VERDIGRIS))
	for spot in PEDESTALS:
		var at: Vector3 = spot + Vector3.UP * ground_y(spot)
		var pedestal := Node3D.new()
		pedestal.position = at
		pedestal.visible = false
		add_child(pedestal)
		cylinder(0.8, 0.6, Vector3.UP * 0.3, Palette.solid(Palette.CHARCOAL), pedestal)
		var gem := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.45
		sm.height = 0.9
		sm.radial_segments = 4
		sm.rings = 2
		gem.mesh = sm
		gem.position = Vector3.UP * 1.4
		pedestal.add_child(gem)
		var label := WorldPrompt.new()
		label.attach(pedestal, Vector3.UP * 2.6, Interactables.REACH * 2.0)
		pedestal.add_child(label)
		_pedestals.append({"node": pedestal, "gem": gem, "label": label, "at": at})
	ctx.events.slammed.connect(_on_slammed)


func stand_down() -> void:
	if ctx.events.slammed.is_connected(_on_slammed):
		ctx.events.slammed.disconnect(_on_slammed)


func reach_point() -> Vector3:
	return global_transform * Vector3(0.0, ground_y(Vector3(0.0, 0.0, -HALF_D + 1.2)) + 1.0, -HALF_D + 1.2)


func ready_now() -> bool:
	return state == OPEN


func gauge() -> float:
	return clampf(_approach() / BREAK_SPEED, 0.0, 1.0) if state == SEALED else -1.0


func terms() -> String:
	return "three parts"


func broken() -> bool:
	return state != SEALED


# The ball's speed into the wall's outer face, in m/s.
func _approach() -> float:
	var v: Vector3 = ctx.player.state.velocity
	return -v.dot(global_basis.z)


func tick(_delta: float) -> void:
	match state:
		SEALED:
			_watch_wall()
		PICKING:
			_watch_pedestals()


func _watch_wall() -> void:
	var local := to_local(ctx.player.ball_position())
	var toward := _approach()
	var ahead := local.z - (HALF_D + 1.0)
	if ahead < -1.0 or ahead > WALL_REACH + maxf(0.0, toward) / 30.0 or absf(local.x) > HALF_W + 1.0 or local.y > HEIGHT + 2.0:
		return
	if toward >= BREAK_SPEED or (ctx.player.kit.sprinting and toward >= SPRINT_SPEED):
		crumble()


func _on_slammed(at: Vector3, _strength: float, _flatness: float) -> void:
	if state != SEALED:
		return
	var local := to_local(at)
	if local.z > HALF_D and local.z < HALF_D + SLAM_REACH and absf(local.x) <= HALF_W + 1.0:
		crumble()


func crumble() -> void:
	if state != SEALED:
		return
	state = OPEN
	var at: Vector3 = _wall.global_position
	_wall.position += Vector3.DOWN * 400.0
	_wall.visible = false
	ctx.events.world_fact.emit("wall_crumbled", at)
	ctx.events.world_fact.emit("route_opened", at)


func fire() -> bool:
	state = PICKING
	_lid.position += Vector3(0.0, 0.6, -0.4)
	_lid.rotation.x = -0.9
	offers = Parts.roll(system.luck(id), PICK_RARITIES, ctx.run.class_id(), ctx.run.parts, PICKS)
	var ball: Vector3 = ctx.player.ball_position()
	_inside.clear()
	for i in _pedestals.size():
		var p: Dictionary = _pedestals[i]
		var shown := i < offers.size()
		p["node"].visible = shown
		_inside.append(_on(p, ball))
		if not shown:
			continue
		var d: Resource = Parts.def(offers[i])
		var rarity: String = d.rarity if d != null else "common"
		p["gem"].material_override = Palette.solid(Palette.BRASS if rarity.begins_with("rare") else Palette.ARC, 2.0)
		var words := Parts.display_name(offers[i]).split(" ", false)
		var icon: String = "cat_" + (d.icon_category if d != null and d.icon_category != "" else "utility")
		p["label"].set_parts(" ".join(words.slice(0, WorldPrompt.TITLE_WORDS)), "", icon)
	return true


func _on(p: Dictionary, ball: Vector3) -> bool:
	var at: Vector3 = to_global(p["at"])
	return Vector2(ball.x - at.x, ball.z - at.z).length() <= PEDESTAL_REACH and absf(ball.y - at.y) < 3.0


# A pedestal takes the ball that rolls onto it, not one already standing there when
# the chest opened, so opening never picks for you.
func _watch_pedestals() -> void:
	var ball: Vector3 = ctx.player.ball_position()
	for i in offers.size():
		var now := _on(_pedestals[i], ball)
		if now and not _inside[i]:
			take(i)
			return
		_inside[i] = now


func take(index: int) -> void:
	taken = offers[index]
	state = TAKEN
	spent = true
	for p in _pedestals:
		p["node"].visible = false
	ctx.run.add_part(taken, "cache")
