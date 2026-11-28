extends "res://src/combat/counter.gd"

signal special_tell(moment: String)

const MODEL := "res://assets/models/world_one/enemy_linker.glb"
const DamageDoor := preload("res://src/combat/damage_door.gd")
const CUES := "res://src/combat/special_cues.gd"
const HP := 120.0
const BOOM := 3.6
const BRACE_SLACK := 1.2
const LET_GO_MARGIN := 1.0
const LINK_RANGE := 18.0
const RELINK_S := 1.0
const SCAN_S := 0.5
const DISH_TURN := deg_to_rad(110.0)
const BLOCK_HALF := deg_to_rad(70.0)
const DISH_CLEAR := 2.4
const DISH_PLATING := 999.0
const CABLE_RADIUS := 0.6
const CABLE_TOUCH := 1.2
const IDLE_CLIPS := {"idle": true, "braced": true}
const BLENDS := {"idle": {"brace": 0.12, "slack": 0.12, "braced": 0.12}, "brace": {"braced": 0.1},
	"braced": {"slack": 0.12, "idle": 0.12}, "slack": {"idle": 0.15, "brace": 0.12}}

var partner: Node3D = null
var braced := false
var cut := false
var braces := 0
var cut_by := ""
var dish_yaw := 0.0

var _combat
var _linked := false
var _scan := 0.0
var _relink := 0.0
var _model: Node3D
var _dish: Node3D
var _cable: MeshInstance3D
var _cable_material: StandardMaterial3D
var _skeleton: Skeleton3D
var _aim_bone := -1
var _anim: AnimationPlayer
var _sockets := {}


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 6
	weight = 2.0
	walk_speed = 2.6
	interruptible = false
	_combat = fleet.combat if fleet != null else null


func _wants_attack(_to_ball: Vector3) -> bool:
	return false


func _roam(_to_ball: Vector3) -> Vector3:
	if not _alive(partner):
		return Vector3.ZERO
	var to_seat := seat() - global_position
	to_seat.y = 0.0
	if to_seat.length() < 0.4:
		return Vector3.ZERO
	return to_seat.normalized() * walk_speed


func seat() -> Vector3:
	var from_ball: Vector3 = partner.global_position - _ball()
	from_ball.y = 0.0
	if from_ball.length() < 0.1:
		from_ball = partner.global_position - global_position
		from_ball.y = 0.0
	return partner.global_position + from_ball.normalized() * BOOM


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _dead or cut or not _in_play() or target == null:
		return
	if not _alive(partner):
		_unlink()
		_relink -= delta
		_scan -= delta
		if _relink <= 0.0 and _scan <= 0.0:
			_scan = SCAN_S
			_link(_find_partner())
		return
	var to_partner: Vector3 = partner.global_position - global_position
	to_partner.y = 0.0
	if to_partner.length() > 0.1:
		rotation.y = atan2(-to_partner.z, to_partner.x)
	_turn_dish(delta)
	var off_seat := absf(to_partner.length() - BOOM)
	if off_seat <= BRACE_SLACK and not braced:
		_brace()
	elif off_seat > BRACE_SLACK + LET_GO_MARGIN and braced:
		_slack()
	_aim_model()


func _turn_dish(delta: float) -> void:
	var to_ball: Vector3 = _real_ball() - partner.global_position
	to_ball.y = 0.0
	if to_ball.length() < 0.1:
		return
	var want := atan2(to_ball.x, to_ball.z)
	dish_yaw += clampf(wrapf(want - dish_yaw, -PI, PI), -DISH_TURN * delta, DISH_TURN * delta)


func guarding(enemy: Node3D) -> bool:
	return braced and holds_partner(enemy)


func holds_partner(enemy: Node3D) -> bool:
	return not cut and not _dead and enemy == partner


func blocks(kind: String) -> bool:
	if not _alive(partner) or not guarding(partner):
		return false
	if kind in ["stomp", "slam"]:
		return false
	var ball := _real_ball()
	if ball.y - partner.global_position.y > DISH_CLEAR:
		return false
	var to_ball := ball - partner.global_position
	to_ball.y = 0.0
	if to_ball.length() < 0.1:
		return false
	var off := absf(wrapf(atan2(to_ball.x, to_ball.z) - dish_yaw, -PI, PI))
	if off > BLOCK_HALF:
		return false
	return true


func dish_dir() -> Vector3:
	return Vector3(sin(dish_yaw), 0.0, cos(dish_yaw))


func cable_ends() -> Array:
	return [_socket_at("cable_base"), _socket_at("cable_dish")]


func weak_points() -> Array:
	if cut or _dead:
		return []
	return [{"id": "cable", "at": _socket_at("cable_cut"), "radius": CABLE_RADIUS}]


func contact_part(ball: Vector3, _kind: String) -> String:
	if cut or _dead:
		return ""
	var ends := cable_ends()
	var near := Geometry3D.get_closest_point_to_segment(ball, ends[0], ends[1])
	return "cable" if near.distance_to(ball) <= CABLE_TOUCH else ""


func on_struck(_kind: String, part: String, _result: Dictionary) -> void:
	if part == "cable":
		cut_cable("struck")


func _on_harpoon_bit(enemy: Node3D, _at: Vector3) -> void:
	if enemy == self:
		cut_cable("harpoon")


func cut_cable(how: String) -> void:
	if cut or _dead:
		return
	cut = true
	cut_by = how
	_unlink()
	special_tell.emit("cut")
	if fleet != null and is_instance_valid(fleet):
		fleet.discover("cable_cut", global_position)
	if _anim != null and _anim.has_animation("cut"):
		_anim.play("cut")
	else:
		_drop_dish()
	if is_instance_valid(_cable) and _skeleton == null:
		_cable.visible = false


func _find_partner() -> Node3D:
	var best: Node3D = null
	var best_score := -INF
	for node in get_tree().get_nodes_in_group(GROUP):
		var enemy := node as Node3D
		if enemy == null or enemy == self or not _alive(enemy) or not _can_partner(enemy):
			continue
		var d := enemy.global_position.distance_to(global_position)
		if d > LINK_RANGE:
			continue
		var score := float(enemy.get("weight")) * 100.0 - d
		if score > best_score:
			best_score = score
			best = enemy
	return best


func _can_partner(enemy: Node3D) -> bool:
	var other_kind := String(enemy.get("kind"))
	if other_kind in ["linker", "vault", "warden"] or not Roster.has(other_kind) or Roster.is_boss_piece(other_kind) \
			or Roster.is_ancient(Roster.faction_of(other_kind)):
		return false
	return _combat == null or _combat.guard_holder(enemy) == null


func _link(enemy: Node3D) -> void:
	if enemy == null or (_combat != null and not _combat.guard(enemy, self)):
		return
	partner = enemy
	_linked = true
	var to_ball: Vector3 = _real_ball() - partner.global_position
	dish_yaw = atan2(to_ball.x, to_ball.z)


func _unlink() -> void:
	if not _linked:
		return
	_linked = false
	if braced:
		_slack()
	if _combat != null:
		_combat.unguard(partner if is_instance_valid(partner) else null, self)
	partner = null
	_relink = RELINK_S


func _brace() -> void:
	braced = true
	braces += 1
	if ResourceLoader.exists(CUES):
		load(CUES).tell(self)
	else:
		special_tell.emit("tell")
	_play("brace", "braced")
	_light_cable(true)


func _slack() -> void:
	braced = false
	_play("slack", "idle")
	_light_cable(false)


static func _alive(enemy) -> bool:
	return not DamageDoor.dead(enemy)


func _build_tool() -> void:
	_crew.free()
	_crew = null
	if _reaction_bus != null:
		_reaction_bus.harpoon_bit.connect(_on_harpoon_bit)
	if ResourceLoader.exists(MODEL):
		_build_model()
	else:
		_build_greybox()
	_play("idle")


func _build_model() -> void:
	_model = (load(MODEL) as PackedScene).instantiate()
	_model.name = "LinkerModel"
	_visual_parent().add_child(_model)
	var painted := Palette.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	for found in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := found as MeshInstance3D
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var surface := mesh.mesh.surface_get_material(i)
			var slot := surface.resource_name if surface != null else ""
			if slot == "fleet_paint":
				mesh.set_surface_override_material(i, _material)
			elif slot == "requisition_tag" and mesh.name == "LinkerCable":
				_cable_material = Palette.solid(Palette.BRASS)
				mesh.set_surface_override_material(i, _cable_material)
			else:
				mesh.set_surface_override_material(i, painted)
	_dish = _model.find_child("LinkerDish", true, false) as Node3D
	_cable = _model.find_child("LinkerCable", true, false) as MeshInstance3D
	var skeletons := _model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_skeleton = skeletons[0] as Skeleton3D
		_aim_bone = _skeleton.find_bone("DishAim")
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	_anim = players[0] as AnimationPlayer if not players.is_empty() else null
	if _anim != null:
		_ease_clips()
	for socket in ["cable_base", "cable_dish", "cable_cut", "partner_spot"]:
		var node := _model.find_child(socket, true, false) as Node3D
		if node != null:
			_sockets[socket] = node


func _build_greybox() -> void:
	_model = Node3D.new()
	_model.name = "LinkerGreybox"
	_visual_parent().add_child(_model)
	var post := _cylinder(0.35, 2.4, Palette.RUST, Vector3(0.0, 0.1, 0.0), 0.0, _model)
	post.material_override = _material
	_box(Vector3(BOOM + 0.6, 0.22, 0.22), Palette.CHARCOAL, Vector3(BOOM * 0.5, 1.75, 0.0), 0.0, _model)
	_dish = Node3D.new()
	_dish.name = "LinkerDish"
	_dish.position = Vector3(BOOM, 1.6, 0.95)
	_model.add_child(_dish)
	var face := _cylinder(1.35, 0.12, Palette.CHARCOAL, Vector3(0.0, 0.0, 0.7), 0.0, _dish)
	face.rotation.x = deg_to_rad(62.0)
	_cable = _box(Vector3(0.08, 0.08, 1.0), Palette.BRASS, Vector3.ZERO, 0.0, _model)
	_cable_material = _cable.material_override as StandardMaterial3D
	_add_socket("cable_base", _model, Vector3(0.42, -0.35, 0.0))
	_add_socket("cable_dish", _dish, Vector3(0.0, 0.0, 0.25))
	_add_socket("cable_cut", _model, Vector3.ZERO)
	_add_socket("partner_spot", _model, Vector3(BOOM, -1.1, 0.0))
	_fit_greybox_cable()


func _add_socket(socket: String, parent: Node3D, at: Vector3) -> void:
	var node := Node3D.new()
	node.name = socket
	node.position = at
	parent.add_child(node)
	_sockets[socket] = node


func _fit_greybox_cable() -> void:
	if _model == null or _model.name != "LinkerGreybox" or not _model.is_inside_tree():
		return
	var a: Vector3 = _sockets["cable_base"].position
	var b: Vector3 = _model.to_local(_sockets["cable_dish"].global_position)
	var span := b - a
	_sockets["cable_cut"].position = a.lerp(b, 0.5)
	_cable.position = a.lerp(b, 0.5)
	if span.length() > 0.01:
		var up := Vector3.UP if absf(span.normalized().y) < 0.99 else Vector3.RIGHT
		_cable.basis = Basis.looking_at(span.normalized(), up) * Basis.from_scale(Vector3(1.0, 1.0, span.length()))


func _socket_at(socket: String) -> Vector3:
	var node: Node3D = _sockets.get(socket)
	if node == null or not node.is_inside_tree():
		return global_position
	return node.global_position


func _aim_model() -> void:
	var relative := wrapf(dish_yaw - rotation.y, -PI, PI)
	if _skeleton != null and _aim_bone >= 0:
		_skeleton.set_bone_pose_rotation(_aim_bone, _skeleton.get_bone_rest(_aim_bone).basis.get_rotation_quaternion() \
			* Quaternion(Vector3.UP, relative))
	elif is_instance_valid(_dish):
		_dish.rotation.y = relative
	_fit_greybox_cable()


func _light_cable(on: bool) -> void:
	if _cable_material == null:
		return
	_cable_material.emission_enabled = on
	_cable_material.emission = EventKinds.role_color("live")
	_cable_material.emission_energy_multiplier = PLATE_GLOW_LIVE if on else 0.0


func _ease_clips() -> void:
	for clip in IDLE_CLIPS:
		if _anim.has_animation(clip) and not Comfort.reduced_motion:
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for from in BLENDS:
		for to in BLENDS[from]:
			if _anim.has_animation(from) and _anim.has_animation(to):
				_anim.set_blend_time(from, to, BLENDS[from][to])


func _play(clip: String, then := "") -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	_anim.play(clip)
	if then != "" and _anim.has_animation(then):
		_anim.queue(then)


func _drop_dish() -> void:
	if not is_instance_valid(_dish):
		return
	var tween := create_tween()
	var floor_y := -1.1 + 0.2
	var roll := Vector3(0.0, floor_y - _dish.position.y, 0.0)
	tween.tween_property(_dish, "position", _dish.position + roll, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_dish, "position", _dish.position + roll + Vector3(1.6, 0.0, 0.8), 0.9).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_dish, "rotation", _dish.rotation + Vector3(PI * 0.5, 0.0, PI * 1.5), 0.9)


func _die() -> void:
	_unlink()
	super._die()


func _exit_tree() -> void:
	if _linked and _combat != null and is_instance_valid(_combat):
		_combat.unguard(partner if is_instance_valid(partner) else null, self)
	if is_instance_valid(_reaction_bus) and _reaction_bus.harpoon_bit.is_connected(_on_harpoon_bit):
		_reaction_bus.harpoon_bit.disconnect(_on_harpoon_bit)
	super._exit_tree()
