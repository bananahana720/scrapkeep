extends "res://src/combat/counter.gd"

const FxLibrary := preload("res://src/presentation/fx_library.gd")

const PIT_RADIUS := 4.5
const PIT_REACH := 1.4
const LEAD := 0.7
const CENTRE_PULL := 2.5
const RATING_BASE := 1.6
const RATING_PER_THREAT := 0.4
const HP := 50.0

const BASE_LIVE_SECONDS := 3.0
const REPULSE_WARN := 0.75
const REPULSE_RADIUS := 6.0
const REPULSE_REACH := 2.4
const REPULSE_DAMAGE := 12.0
const REPULSE_SHOVE := 14.0
const PUNT_SPEED := 36.0
const PUNT_SEARCH_RANGE := 40.0
const PUNT_HIT_RADIUS := 2.4
const PUNT_BLAST_RADIUS := 7.0
const PUNT_DAMAGE := 55.0
const PUNT_KNOCK := 22.0
const PUNT_LIFE := 1.6

signal disc_punted(at: Vector3, hits: int)

var rating := RATING_BASE
var windup_pose_enabled := true
var polarity_flips := 0
var repulse_blasts := 0
var disc_punts := 0
var last_punt_hits := 0
var _stack: Node3D
var _body: MeshInstance3D
var _top_disc: MeshInstance3D
var _top_rest := Vector3.ZERO
var _disc_material: StandardMaterial3D
var _top_link: MeshInstance3D
var _polarity_flip := false
var _flip_t := 0.0
var _flip_center := Vector3.ZERO
var _deployed_disc: MeshInstance3D
var _deployed_base := Transform3D.IDENTITY
var _slam_bus: Node


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	super(target_ref, terrain_ref, root_ref, live_ref, threat, spec_ref)
	_slam_bus = world_root.get_node_or_null("GameEvents") if world_root != null else null
	if _slam_bus != null and not _slam_bus.slammed.is_connected(_on_player_slammed):
		_slam_bus.slammed.connect(_on_player_slammed)


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.2
	warn_seconds = 1.1
	live_seconds = BASE_LIVE_SECONDS
	rest_seconds = 3.5
	attack_range = 26.0
	rating = RATING_BASE + RATING_PER_THREAT * (threat - 1.0)


const BODY_LEAN := 0.22
const HOIST := 1.4
const SPIN := TAU * 1.25
const CORE_EMISSION := 0.6
const LINK_FOOT := 0.5
const LINK_RADIUS := 0.16
const CASING_HALF_HEIGHT := 0.10
const DEPLOYED_PROFILE := 1.5
const DISC_RADIUS := 1.05

static var _warned_asset := false
static var _shared: Dictionary = {}


func _build_tool() -> void:
	_crew.free()
	_crew = null
	var parts := _parts()
	var dress := Node3D.new()
	dress.name = "MagTrapperBody"
	_visual_parent().add_child(dress)
	_body = MeshInstance3D.new()
	_body.name = "Cart"
	_body.mesh = parts["body"]
	_body.set_surface_override_material(parts["flash"], _material)
	dress.add_child(_body)
	_stack = Node3D.new()
	_stack.name = "MagStack"
	_stack.position = parts["pivot"]
	dress.add_child(_stack)
	var discs := MeshInstance3D.new()
	discs.name = "MagDiscs"
	discs.mesh = parts["discs"]
	_disc_material = Palette.solid(Color.WHITE)
	_disc_material.vertex_color_use_as_albedo = true
	discs.set_surface_override_material(parts["disc_paint"], _disc_material)
	_stack.add_child(discs)
	_top_disc = MeshInstance3D.new()
	_top_disc.name = "MagTopDisc"
	_top_disc.mesh = parts["top"]
	_top_rest = parts["top_position"]
	_top_disc.position = _top_rest
	_top_disc.set_surface_override_material(parts["top_paint"], _disc_material)
	_stack.add_child(_top_disc)
	var mast := CylinderMesh.new()
	mast.top_radius = LINK_RADIUS
	mast.bottom_radius = LINK_RADIUS
	mast.height = 1.0
	mast.radial_segments = 8
	mast.rings = 1
	_top_link = MeshInstance3D.new()
	_top_link.name = "MagTopLink"
	_top_link.mesh = mast
	_top_link.material_override = Palette.solid(Palette.CHARCOAL)
	_stack.add_child(_top_link)


static func _parts() -> Dictionary:
	if not _shared.is_empty():
		return _shared
	var scene := (load("res://assets/models/world_one/enemy_mag_trapper.glb") as PackedScene).instantiate()
	var charcoal := Palette.solid(Palette.CHARCOAL)
	var painted := Palette.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	var core := Palette.solid(Palette.HAZARD, CORE_EMISSION)
	var flash := 0
	var disc_paint := 0
	var top_paint := 0
	var meshes := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh.duplicate()
		for i in mesh.get_surface_count():
			var surface_material := mesh.surface_get_material(i)
			if surface_material == null and not _warned_asset:
				_warned_asset = true
				push_warning("mag_trapper: surface has no material; using default finish")
			var slot := surface_material.resource_name if surface_material != null else ""
			if slot == "fleet_paint":
				flash = i
			elif slot == "paint" and node.name == "MagDiscs":
				disc_paint = i
			elif slot == "paint" and node.name == "MagTopDisc":
				top_paint = i
			mesh.surface_set_material(i, core if slot == "class_accent" else (painted if slot == "paint" else charcoal))
		meshes[node.name] = mesh
	_shared = {"body": meshes["MagTrapperBody"], "discs": meshes["MagDiscs"], "flash": flash, "disc_paint": disc_paint,
		"top": meshes["MagTopDisc"], "top_paint": top_paint,
		"top_position": (scene.find_child("MagTopDisc", true, false) as Node3D).position,
		"pivot": (scene.find_child("MagStack", true, false) as Node3D).position}
	scene.free()
	return _shared


func _update_flash(delta: float) -> void:
	super(delta)
	if _disc_material == null:
		return
	if strike_flashing():
		_show_strike(_disc_material, Color.WHITE)
		return
	_disc_material.albedo_color = Color.WHITE.lerp(Color(1.0, 1.0, 0.85), FlashGuard.whiten(_flash))
	_disc_material.emission_enabled = _flash > 0.0
	_disc_material.emission = EventKinds.role_color("neutral")
	_disc_material.emission_energy_multiplier = FlashGuard.spike(0.0, _flash * 2.0)


func _commit(_to_ball: Vector3) -> Node3D:
	var aim: Vector3 = _ball() + target.planar_velocity() * LEAD
	_facing(aim - global_position)
	return _commit_ring(Threat.Type.INSTANT, aim, PIT_RADIUS, PIT_REACH)


func _go_live() -> void:
	_deployed_disc = null
	var pit := telegraph()
	if pit == null or not windup_pose_enabled:
		return
	var disc := MeshInstance3D.new()
	disc.name = "DeployedDisc"
	disc.mesh = _top_disc.mesh
	pit.add_child(disc)
	var at: Vector3 = pit.center
	var x := Vector3.RIGHT * DISC_RADIUS
	var z := Vector3.BACK * DISC_RADIUS
	var rise_x := Telegraph.ground_under(terrain, at + x) - Telegraph.ground_under(terrain, at - x)
	var rise_z := Telegraph.ground_under(terrain, at + z) - Telegraph.ground_under(terrain, at - z)
	var normal := Vector3(-rise_x, 2.0 * DISC_RADIUS, -rise_z).normalized()
	var basis := Basis(Quaternion(Vector3.UP, normal)).scaled_local(Vector3(1.0, DEPLOYED_PROFILE, 1.0))
	disc.global_transform = Transform3D(basis, at + basis.y * CASING_HALF_HEIGHT)
	_deployed_disc = disc
	_deployed_base = disc.global_transform


func _gap_ready() -> bool:
	if not is_inside_tree():
		return true
	if world_root != null and is_instance_valid(world_root) and world_root.has_meta(AttackBudget.OFF_META):
		return true
	var tree := get_tree()
	if not tree.root.has_meta(AttackBudget.LAST_META):
		return true
	return Engine.get_physics_frames() - int(tree.root.get_meta(AttackBudget.LAST_META)) >= AttackBudget.gap_frames()


func _start_polarity_flip(pit: Node3D) -> void:
	var center: Vector3 = pit.center
	if is_inside_tree():
		var tree := get_tree()
		tree.root.set_meta(AttackBudget.LAST_META, Engine.get_physics_frames())
		tree.root.set_meta(AttackBudget.VOLLEY_META, AttackBudget.volley_of(self))
	var saved_disc: MeshInstance3D = _deployed_disc if is_instance_valid(_deployed_disc) else null
	if saved_disc != null and saved_disc.get_parent() == pit:
		pit.remove_child(saved_disc)
	_clear_telegraph()
	_telegraph = Telegraph.ring(world_root, terrain, Threat.Type.INSTANT, center, REPULSE_RADIUS, REPULSE_REACH, Palette.HAZARD)
	_telegraph.warn_seconds = REPULSE_WARN
	_voice(_telegraph)
	if saved_disc != null:
		_telegraph.add_child(saved_disc)
		saved_disc.global_transform = _deployed_base
	_polarity_flip = true
	_flip_t = 0.0
	_flip_center = center
	polarity_flips += 1
	live_seconds = maxf(live_seconds, _t + REPULSE_WARN + 0.15)
	if world_root != null and is_inside_tree():
		FxLibrary.burst(world_root, "brass_spark", center + Vector3.UP * 0.4, 12)


class PuntedDisc extends Node3D:
	var owner_ref: WeakRef
	var target_enemy: Node3D
	var heading := Vector3.FORWARD
	var terrain_ref
	var combat_ref
	var root_ref: Node3D
	var speed := 36.0
	var blast_radius := 7.0
	var hit_radius := 2.4
	var damage := 55.0
	var knock_force := 22.0
	var life := 1.6
	var _age := 0.0
	var _visual: MeshInstance3D

	func setup_visual(disc_mesh: Mesh) -> void:
		if disc_mesh == null:
			return
		_visual = MeshInstance3D.new()
		_visual.name = "PuntedDiscMesh"
		_visual.mesh = disc_mesh
		_visual.material_override = Palette.solid(Palette.AMBER, 1.4)
		_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_visual)

	func _physics_process(delta: float) -> void:
		_age += delta
		var goal_valid: bool = is_instance_valid(target_enemy) and (not target_enemy.has_method("is_dead") or not bool(target_enemy.is_dead()))
		if goal_valid:
			var to_goal := target_enemy.global_position - global_position
			to_goal.y = 0.0
			if to_goal.length() > 0.1:
				heading = to_goal.normalized()
		global_position += heading * speed * delta
		if terrain_ref != null and terrain_ref.has_method("height"):
			global_position.y = float(terrain_ref.height(global_position.x, global_position.z)) + 0.35
		if _visual != null:
			_visual.rotate_y(TAU * 4.0 * delta)
		if goal_valid:
			var flat := Vector2(target_enemy.global_position.x - global_position.x, target_enemy.global_position.z - global_position.z).length()
			if flat <= hit_radius:
				_detonate()
				return
		if _age >= life:
			_detonate()

	func _detonate() -> void:
		var hits := 0
		if is_inside_tree():
			for enemy in get_tree().get_nodes_in_group(GROUP):
				if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
					continue
				var flat := Vector2(enemy.global_position.x - global_position.x, enemy.global_position.z - global_position.z).length()
				if flat > blast_radius:
					continue
				hits += 1
				var out: Vector3 = enemy.global_position - global_position
				out.y = 0.0
				var dir := out.normalized() if out.length() > 0.1 else heading
				if combat_ref != null and is_instance_valid(combat_ref) and combat_ref.has_method("strike"):
					combat_ref.strike(enemy, "ram", damage, "", "disc_punt")
				elif enemy.has_method("take_damage"):
					enemy.take_damage(damage)
				if enemy.has_method("knock"):
					enemy.knock(dir + Vector3.UP * 0.25, knock_force)
		if root_ref != null and is_instance_valid(root_ref):
			FxLibrary.burst(root_ref, "brass_spark", global_position + Vector3.UP * 0.3, 18)
			FxLibrary.burst(root_ref, "slam_dust", global_position, 14)
		var trapper = owner_ref.get_ref() if owner_ref != null else null
		if trapper != null and is_instance_valid(trapper):
			trapper.last_punt_hits = hits
			trapper.disc_punted.emit(global_position, hits)
		queue_free()


func _nearest_pack_target(from: Vector3) -> Node3D:
	if not is_inside_tree():
		return null
	var best: Node3D = null
	var best_d := PUNT_SEARCH_RANGE
	for enemy in get_tree().get_nodes_in_group(GROUP):
		if enemy == self or not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		var d := Vector2(enemy.global_position.x - from.x, enemy.global_position.z - from.z).length()
		if d < best_d:
			best_d = d
			best = enemy as Node3D
	if best == null and not _dead:
		var self_d := Vector2(global_position.x - from.x, global_position.z - from.z).length()
		if self_d <= PUNT_SEARCH_RANGE:
			best = self
	return best


func _punt_disc() -> void:
	if not _polarity_flip:
		return
	_polarity_flip = false
	disc_punts += 1
	broken_by = "smash"
	if world_root != null and is_inside_tree():
		var puck := PuntedDisc.new()
		puck.name = "PuntedMagDisc"
		puck.owner_ref = weakref(self)
		puck.terrain_ref = terrain
		puck.combat_ref = fleet.combat if fleet != null and is_instance_valid(fleet) else null
		puck.root_ref = world_root
		puck.speed = PUNT_SPEED
		puck.blast_radius = PUNT_BLAST_RADIUS
		puck.hit_radius = PUNT_HIT_RADIUS
		puck.damage = PUNT_DAMAGE
		puck.knock_force = PUNT_KNOCK
		puck.life = PUNT_LIFE
		var pack_target := _nearest_pack_target(_flip_center)
		puck.target_enemy = pack_target
		if pack_target != null:
			var to_pack := pack_target.global_position - _flip_center
			to_pack.y = 0.0
			puck.heading = to_pack.normalized() if to_pack.length() > 0.1 else Vector3.FORWARD
		else:
			var player = _player()
			var pvel: Vector3 = player.planar_velocity() if player != null else Vector3.FORWARD
			puck.heading = pvel.normalized() if pvel.length() > 0.5 else Vector3.FORWARD
		world_root.add_child(puck)
		puck.global_position = _flip_center + Vector3.UP * 0.35
		puck.setup_visual(_top_disc.mesh if _top_disc != null else null)
		FxLibrary.burst(world_root, "brass_spark", _flip_center + Vector3.UP * 0.4, 14)
	if fleet != null:
		fleet.discover("heavy_roll", _real_ball())


func _on_player_slammed(at: Vector3, _strength: float, _flatness: float) -> void:
	if not _polarity_flip or _dead or phase != Phase.LIVE:
		return
	var flat := Vector2(at.x - _flip_center.x, at.z - _flip_center.z).length()
	if flat <= REPULSE_RADIUS + 1.5:
		_punt_disc()


func _live(delta: float) -> bool:
	var pit := telegraph()
	if pit == null:
		return false
	var player = _player()
	var ball := _real_ball()
	if _polarity_flip:
		if player != null and player.kit.slamming and player.state.on_floor():
			var flat := Vector2(ball.x - _flip_center.x, ball.z - _flip_center.z).length()
			if flat <= REPULSE_RADIUS + 1.5:
				_punt_disc()
				return false
		_flip_t += delta
		var u := clampf(_flip_t / REPULSE_WARN, 0.0, 1.0)
		pit.set_progress(u)
		if is_instance_valid(_deployed_disc):
			var flip_basis := _deployed_base.basis.rotated(Vector3.RIGHT, PI * u).rotated(Vector3.UP, TAU * 2.0 * u)
			_deployed_disc.global_transform = Transform3D(flip_basis, _deployed_base.origin + Vector3.UP * (0.75 * sin(u * PI)))
		if _flip_t >= REPULSE_WARN:
			repulse_blasts += 1
			if pit.contains(ball):
				var out: Vector3 = ball - pit.center
				out.y = 0.0
				var dir := out.normalized() if out.length() > 0.1 else Vector3.FORWARD
				hit_player.emit(REPULSE_DAMAGE, dir * REPULSE_SHOVE + Vector3.UP * 4.0)
			if world_root != null and is_inside_tree():
				FxLibrary.burst(world_root, "brass_spark", pit.center + Vector3.UP * 0.4, 16)
				FxLibrary.burst(world_root, "slam_dust", pit.center, 12)
			return false
		return true
	if not pit.contains(ball) or player.heft() >= rating:
		if _holding():
			_release("left")
		if pit.contains(ball) and fleet != null:
			fleet.discover("heavy_roll", ball)
		if pit.contains(ball) and player.heft() >= rating and _gap_ready():
			_start_polarity_flip(pit)
		return true
	if not _holding() and not _catch():
		return true
	var to_centre: Vector3 = pit.center - ball
	to_centre.y = 0.0
	_pull(to_centre * CENTRE_PULL)
	return true


func _on_end() -> void:
	_polarity_flip = false
	_flip_t = 0.0
	_deployed_disc = null
	live_seconds = BASE_LIVE_SECONDS


func _exit_tree() -> void:
	if is_instance_valid(_slam_bus) and _slam_bus.slammed.is_connected(_on_player_slammed):
		_slam_bus.slammed.disconnect(_on_player_slammed)
	super._exit_tree()


func _on_broken(_method: String) -> void:
	if fleet != null:
		fleet.discover("heavy_roll", _real_ball())


func _pose() -> void:
	if _top_disc == null:
		return
	var t := 0.0
	if windup_pose_enabled and not is_dead() and not is_queued_for_deletion():
		if phase == Phase.WARN:
			t = clampf(_warn_progress(), 0.0, 1.0)
		elif phase == Phase.LIVE and _t == 0.0:
			t = 1.0
	var raised := t * t * (3.0 - 2.0 * t)
	_body.rotation.x = -BODY_LEAN * raised
	_top_disc.position = _top_rest + Vector3.UP * HOIST * raised
	_top_disc.rotation.y = SPIN * t * t
	var head := _top_disc.position.y
	_top_link.scale = Vector3(1.0, maxf(head - LINK_FOOT, 0.0001), 1.0)
	_top_link.position = Vector3(_top_disc.position.x, (head + LINK_FOOT) * 0.5, _top_disc.position.z)
	_top_disc.visible = not windup_pose_enabled or phase != Phase.LIVE or is_dead() or is_queued_for_deletion()
	_top_link.visible = _top_disc.visible
