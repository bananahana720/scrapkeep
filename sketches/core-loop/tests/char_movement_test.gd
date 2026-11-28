extends SceneTree

const GameEvents := preload("res://src/core/game_events.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const PlayerBall := preload("res://src/movement/player_ball.gd")
const Augments := preload("res://src/movement/augments.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const Contact := preload("res://src/movement/contact.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")

# The class movement kits on the real rigid ball in a small fixture world: two facing
# walls, a heavy post and open floor. Sable's vault kick exit speed, cap and per-face
# lock; the bowling-ball rebound off something heavier, its refresh and what it may cost;
# Rivet's sprint shutting the crowd-control door; Kest's blink; Sable's RMB grapple.

const WALL_A := -30.0
const WALL_B := -10.0
const POST := Vector3(40.0, 1.0, 0.0)
const OPEN := Vector3(90.0, 1.0, 0.0)
const TOLERANCE := 0.05


# An enemy stand-in heavy enough to bounce the ball: it only has to weigh something and
# take a shove.
class Post:
	extends CharacterBody3D

	var weight := 5.0
	var radius := 1.0
	var knocks := 0

	func knock(_direction: Vector3, _force: float) -> void:
		knocks += 1

	func flash() -> void:
		pass


var _world: Node3D
var _events
var _player
var _source := Intent.Scripted.new()
var _failures := 0
var _steps := []
var _index := 0
var _ticks := 0
var _facts := {"vault_kicked": [], "enemy_rebounded": [], "sprint_started": [], "cc_ignored": [], "blink_used": []}
var _record := {}


func _initialize() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	_box(Vector3(400.0, 2.0, 400.0), Vector3(0.0, -1.0, 0.0))
	_box(Vector3(2.0, 40.0, 60.0), Vector3(WALL_A - 1.0, 20.0, 0.0))
	_box(Vector3(2.0, 40.0, 60.0), Vector3(WALL_B + 1.0, 20.0, 0.0))
	var post := Post.new()
	post.add_to_group("enemy")
	post.collision_layer = 0
	post.set_collision_layer_value(3, true)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	shape.shape = sphere
	post.add_child(shape)
	_world.add_child(post)
	post.position = POST
	_events = GameEvents.new()
	_world.add_child(_events)
	for kind in _facts:
		var list: Array = _facts[kind]
		_events.connect(kind, func(a = null, b = null): list.append([a, b]))
	_player = PlayerBall.new()
	_world.add_child(_player)
	_player.setup(Tuning.new(), _events, Vector3(0.0, 50.0, 0.0))
	_player.source = _source
	_steps = [
		[_vault_at.bind(20.0, WALL_A, 1.0), 4, _check_vault.bind("vault 20", 20.0)],
		[_vault_at.bind(30.0, WALL_A + 0.0, 1.0), 4, _check_vault.bind("vault 30", 30.0)],
		[_ping_start, 4, _noop],
		[_ping_b, 4, _noop],
		[_ping_a_locked, 4, _check_locked],
		[_noop, 130, _noop],
		[_ping_a_again, 4, _check_unlocked],
		[_rebound_start, 60, _check_rebound],
		[_sprint_start, 20, _sprint_mid],
		[_noop, 5, _sprint_release],
		[_noop, 3, _check_sprint],
		[_blink_start, 3, _check_blink],
		[_grapple_start, 3, _check_grapple],
	]


func _box(size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_world.add_child(body)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _index >= _steps.size():
		print("char_movement_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
		quit(0 if _failures == 0 else 1)
		return true
	var step: Array = _steps[_index]
	if _ticks == 0:
		(step[0] as Callable).call()
	_ticks += 1
	if _ticks >= int(step[1]):
		(step[2] as Callable).call()
		_index += 1
		_ticks = 0
	return false


func _noop() -> void:
	pass


func _fit(id: String) -> void:
	_player.fit_class(ClassDef.by_id(id))


# Moves the ball without the reset's kit clear, so face locks and charges survive.
func _place(at: Vector3, velocity: Vector3) -> void:
	_player.body().teleport(at, velocity)


# In the air 1.8 m off a wall's face, flying into it at speed, Space pressed.
func _vault_at(speed: float, face_x: float, side: float) -> void:
	_fit("pylon_engineer")
	_player.reset_to(Vector3(face_x + side * 1.8, 15.0, 0.0), Vector3(-side * speed, 0.0, 0.0))
	_player.body().global_position = Vector3(face_x + side * 1.8, 15.0, 0.0)
	_record = {"kicks": _facts["vault_kicked"].size(), "planar_in": speed}
	_source.press = {"jump_pressed": true}


func _check_vault(label: String, incoming: float) -> void:
	var kicks: Array = _facts["vault_kicked"]
	var fired: float = kicks[-1][1] if kicks.size() > _record["kicks"] else -1.0
	var want := minf(Augments.VAULT_CAP, incoming * UpgradeTree.VAULT_GAIN)
	var speed: float = _player.state.velocity.length()
	var planar: float = _player.planar_velocity().length()
	_report(label, kicks.size() == _record["kicks"] + 1 and absf(fired - want) <= want * TOLERANCE and absf(speed - want) <= want * TOLERANCE \
			and planar >= incoming,
		"incoming %.0f m/s: kick published %.1f, ball leaves at %.1f (want %.1f, cap %.0f); planar %.1f never below the %.0f it came in with"
			% [incoming, fired, speed, want, Augments.VAULT_CAP, planar, incoming])


func _ping_start() -> void:
	_fit("pylon_engineer")
	_player.reset_to(Vector3(WALL_A + 1.8, 15.0, 0.0), Vector3(-20.0, 0.0, 0.0))
	_player.body().global_position = Vector3(WALL_A + 1.8, 15.0, 0.0)
	_record = {"start": _facts["vault_kicked"].size()}
	_source.press = {"jump_pressed": true}


func _ping_b() -> void:
	_place(Vector3(WALL_B - 1.8, 15.0, 0.0), Vector3(20.0, 0.0, 0.0))
	_source.press = {"jump_pressed": true}


func _ping_a_locked() -> void:
	_place(Vector3(WALL_A + 1.8, 15.0, 0.0), Vector3(-30.0, 0.0, 0.0))
	_source.press = {"jump_pressed": true}


func _check_locked() -> void:
	var kicks: int = _facts["vault_kicked"].size() - _record["start"]
	var speed: float = _player.state.velocity.length()
	_report("face lock", kicks == 2 and speed < 35.0,
		"A then B kick (%d kicks); back at A inside %.1f s nothing kicks and the ball stays at %.1f m/s, no 54 m/s ping-pong"
			% [kicks, UpgradeTree.VAULT_FACE_COOLDOWN, speed])


func _ping_a_again() -> void:
	_place(Vector3(WALL_A + 1.8, 15.0, 0.0), Vector3(-20.0, 0.0, 0.0))
	_source.press = {"jump_pressed": true}


func _check_unlocked() -> void:
	var kicks: int = _facts["vault_kicked"].size() - _record["start"]
	_report("face unlocks", kicks == 3, "after %.1f s face A kicks again (%d kicks in all)" % [UpgradeTree.VAULT_FACE_COOLDOWN, kicks])


# Kest rolls into the heavy post with her blink spent and no air jump left: the rebound
# must hand both back and cost no more than restitution keeps.
func _rebound_start() -> void:
	_fit("demolitions_caster")
	var at := Vector3(POST.x - 12.0, 1.0, 0.0)
	_player.reset_to(at, Vector3(20.0, 0.0, 0.0))
	_player.body().global_position = at
	_player.abilities.spend(AbilityState.MOVEMENT)
	_record = {"rebounds": _facts["enemy_rebounded"].size()}
	_events.enemy_rebounded.connect(_on_rebound, CONNECT_ONE_SHOT)


# The velocity going in (the one the ball uses to size a contact) and the one handed back.
func _on_rebound(_enemy: Node3D, _speed: float) -> void:
	_record["in"] = _player.pre_contact_velocity(Vector3.RIGHT)
	_record["out"] = _player.state.velocity


func _check_rebound() -> void:
	var rebounds: int = _facts["enemy_rebounded"].size() - _record["rebounds"]
	var v_in: Vector3 = _record.get("in", Vector3.ZERO)
	var v_out: Vector3 = _record.get("out", Vector3.ZERO)
	var before := Vector2(v_in.x, v_in.z).length()
	var planar := Vector2(v_out.x, v_out.z).length()
	var cost := Contact.contact_cost(v_in, Vector3(-1.0, 0.0, 0.0))
	var away: bool = v_out.x < 0.0
	_report("rebound", rebounds == 1 and away and _player.abilities.ready(AbilityState.MOVEMENT) and _player.state.air_actions == 1,
		"rolled into a weight-5 post at heft 1: %d rebound, leaving away from it; blink charge back %s, air jump %d"
			% [rebounds, _player.abilities.ready(AbilityState.MOVEMENT), _player.state.air_actions])
	_report("rebound momentum", before > 10.0 and planar >= before - cost - 0.05,
		"planar %.2f m/s out of %.2f in: the drop %.2f stays within the player's own contact cost %.2f"
			% [planar, before, before - planar, cost])


func _sprint_start() -> void:
	_fit("runner_gunner")
	var at := OPEN
	_player.reset_to(at, Vector3(0.0, 0.0, -10.0))
	_player.body().global_position = at
	_record = {"sprints": _facts["sprint_started"].size(), "blinks": _facts["blink_used"].size()}
	_source.hold = {"movement_held": true}
	_source.press = {"movement_pressed": true}


func _sprint_mid() -> void:
	var v: Vector3 = _player.state.velocity
	var landed: bool = _player.crowd_control("knock", Vector3(400.0, 0.0, 0.0))
	var slowed: bool = _player.crowd_control("slow")
	_record["immune"] = not landed and not slowed and _player.kit.sprinting and is_equal_approx(_player.state.cruise_boost, Augments.SPRINT_CRUISE)
	_record["v"] = v


func _sprint_release() -> void:
	_record["drift"] = absf(_player.state.velocity.x - (_record["v"] as Vector3).x)
	_source.hold = {}


func _check_sprint() -> void:
	var landed: bool = _player.crowd_control("slow")
	var sprints: int = _facts["sprint_started"].size() - _record["sprints"]
	_report("sprint", sprints == 1 and _record["immune"] and _record["drift"] < 0.5 and _facts["cc_ignored"].size() == 2 \
			and not _player.kit.sprinting and landed and _facts["blink_used"].size() == _record["blinks"],
		"RMB held: %d sprint, a 400 m/s^2 knock and a slow both ignored (%d cc_ignored, sideways drift %.2f m/s), cruise x%.2f; released, a slow lands again; no blink"
			% [sprints, _facts["cc_ignored"].size(), _record["drift"], Augments.SPRINT_CRUISE])


func _blink_start() -> void:
	_fit("demolitions_caster")
	var at := OPEN + Vector3(0.0, 0.0, 60.0)
	_player.reset_to(at, Vector3.ZERO)
	_player.body().global_position = at
	_player.drive_basis = Basis.IDENTITY
	_record = {"from": at, "sprints": _facts["sprint_started"].size()}
	_source.press = {"movement_pressed": true}


func _check_blink() -> void:
	var moved: Vector3 = _player.ball_position() - _record["from"]
	var planar: float = _player.planar_velocity().length()
	_report("blink", absf(-moved.z - Augments.BLINK_DISTANCE) < 0.6 and absf(moved.x) < 0.2 and planar >= _player.tuning.f("dash_impulse") - 0.5 \
			and _facts["sprint_started"].size() == _record["sprints"] and not _player.abilities.ready(AbilityState.MOVEMENT),
		"RMB moved Kest %.2f m along the aim (want %.0f), leaving at %.1f m/s; the charge is spent and no sprint started"
			% [-moved.z, Augments.BLINK_DISTANCE, planar])


func _grapple_start() -> void:
	_fit("pylon_engineer")
	var at := Vector3(WALL_A + 12.0, 1.0, 0.0)
	_player.reset_to(at, Vector3.ZERO)
	_player.body().global_position = at
	_player.kit.aim = {"state": Augments.AIM_REACH, "point": Vector3(WALL_A, 10.0, 0.0), "normal": Vector3.RIGHT}
	_source.press = {"harpoon_pressed": true}


func _check_grapple() -> void:
	var hooked: bool = _player.kit.hooked
	_source.press = {"harpoon_released": true}
	_report("grapple on RMB", hooked, "Sable's RMB hooks the aimed wall through the harpoon intent (RMB is harpoon_pressed)")
