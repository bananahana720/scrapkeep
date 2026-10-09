extends SceneTree

# VX7-1: the miniboss's five poses read without a label. Crouch sits at least 25% lower
# than stalk, leap lifts the body at least 80% of its standing height, only the
# charge-brace paints its shields with the threat stripe, and the vent ring sits on the
# core socket. Body height is the body bone's height above the soles (HALF_HEIGHT at rest).
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Miniboss := preload("res://src/combat/miniboss.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const T := preload("res://tests/support/t.gd")

var _game
var _t := T.new("miniboss_pose_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	var terrain = _game.ctx.terrain
	var at := Vector3(-100.0, 0.0, -90.0)
	at.y = terrain.height(at.x, at.z) + Miniboss.HALF_HEIGHT
	var boss = _game.ctx.spawner.spawn_enemy("miniboss", at)
	boss.set_physics_process(false)
	boss.global_position = at
	var rig: Skeleton3D = boss._pose_rig
	if not _t.check("VX7-1 model rig", rig != null, "GLB miniboss builds its pose rig"):
		quit(_t.verdict())
		return
	var body := rig.find_bone("MinibossBody")
	var halo := rig.find_bone("MinibossHalo")
	var poses := [["stalk", Miniboss.State.STALK, 0.0], ["slam_crouch", Miniboss.State.SLAM_CROUCH, Miniboss.SLAM_CROUCH],
		["slam_leap", Miniboss.State.SLAM_LEAP, 0.3], ["charge_brace", Miniboss.State.CHARGE_BRACE, Miniboss.CHARGE_BRACE],
		["charge", Miniboss.State.CHARGE, 0.4], ["weak", Miniboss.State.WEAK, 0.8]]
	var heights := {}
	var striped := {}
	var ring_gap := INF
	for pose in poses:
		boss.state = pose[1]
		boss._clock = pose[2]
		boss._model_pose(0.0)
		heights[pose[0]] = rig.get_bone_pose_position(body).y - rig.get_bone_rest(body).origin.y + Miniboss.HALF_HEIGHT
		var armour = boss.get("_armour")
		var shield: Material = armour.material_override if armour != null else null
		striped[pose[0]] = shield is StandardMaterial3D and (shield as StandardMaterial3D).albedo_texture == Threat.Painter.stripe_texture()
		if pose[0] == "weak":
			var ring: Vector3 = rig.global_transform * rig.get_bone_pose_position(halo)
			ring_gap = ring.distance_to(boss._core.global_position)
	var stalk: float = heights.stalk
	_t.check("VX7-1 crouch", heights.slam_crouch <= stalk * 0.75,
		"crouch body %.2f m vs stalk %.2f m (%.0f%% lower)" % [heights.slam_crouch, stalk, 100.0 * (1.0 - heights.slam_crouch / stalk)])
	_t.check("VX7-1 leap", heights.slam_leap >= stalk * 1.8,
		"leap body %.2f m vs stalk %.2f m (%.0f%% higher)" % [heights.slam_leap, stalk, 100.0 * (heights.slam_leap / stalk - 1.0)])
	var others := []
	for name in striped:
		if name != "charge_brace" and striped[name]:
			others.append(name)
	_t.check("VX7-1 brace stripe", striped.charge_brace and others.is_empty(),
		"charge_brace striped %s; other poses striped %s" % [striped.charge_brace, others])
	_t.check("VX7-1 vent ring", ring_gap <= 0.1, "vent ring %.3f m from the core socket" % ring_gap)
	boss.state = Miniboss.State.STALK
	boss._clock = 0.0
	boss._model_pose(0.0)
	var armour = boss.get("_armour")
	_t.check("VX7-1 stripe leaves", armour != null and armour.material_override == boss._model_plate_material,
		"stalk restores the shields' plating material")
	quit(_t.verdict())
