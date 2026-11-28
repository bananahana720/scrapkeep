# 2026-10-09 VX-FX: thermal motes at half density (thermal_ride JUICE row: idle 9, occupied 27, low idle 3), SEEDS:88; streaks unchanged.
extends SceneTree

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Fx := preload("res://src/presentation/highdraft_fx.gd")
const Scenery := preload("res://src/presentation/highdraft_scenery.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
var t := T.new("highdraft_fx_test")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	for tick in 600:
		if game.flow != null:
			break
		await physics_frame
	if not t.check("real game booted", game.flow != null):
		game.free()
		quit(t.verdict())
		return
	t.eq("no Highdraft FX at boot", game.find_children("WindEffects", "Node3D", true, false).size(), 0)
	game.flow.enter_stage(5, Vector3.ZERO, false)
	await physics_frame
	var stage: Node3D = game.ctx.terrain.geometry_root(5)
	var scenery := stage.get_node("HighdraftScenery")
	var presence := scenery.get_node("Presence")
	var fx := scenery.get_node("WindEffects")
	t.eq("stage 5 builds three column effects", fx.thermals.size(), 3)
	t.eq("FX contain no physics bodies", fx.find_children("*", "CollisionObject3D", true, false).size(), 0)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.ctx.player.body().freeze = true
	var column: Dictionary = fx.thermals[0]
	var base: Vector3 = column.presence.base
	game.ctx.player.reset_to(base + Vector3.UP * 16.0, Vector3(4.0, -2.0, 3.0))
	var before_velocity: Vector3 = game.ctx.player.state.velocity
	presence._process(1.0 / 60.0)
	t.check("real ball occupies thermal", column.occupied and column.presence.state == "occupied",
		"ball %s, base %s, presence visible %s" % [game.ctx.player.ball_position(), base, presence.is_visible_in_tree()])
	t.eq("occupied shader state", column.material.get_shader_parameter("occupied"), 1.0)
	t.eq("occupied motes denser", column.views[0].multimesh.visible_instance_count, 27)
	t.eq("occupied streaks denser", column.views[1].multimesh.visible_instance_count, 18)
	t.eq("presentation preserves ball velocity", game.ctx.player.state.velocity, before_velocity)
	game.ctx.player.reset_to(base + Vector3(12.0, 16.0, 0.0))
	presence._process(1.0 / 60.0)
	t.check("leaving thermal returns to idle", not column.occupied)
	t.eq("idle motes", column.views[0].multimesh.visible_instance_count, 9)
	# A real ball falls onto the actual net point under the vent. Read its body's position,
	# not the unmoving PlayerBall parent. Also exercise the rescue crossing from below.
	var contact := base + Vector3.UP
	game.ctx.player.reset_to(contact + Vector3.UP * 4.0)
	presence._process(1.0 / 60.0)
	game.ctx.player.reset_to(contact)
	presence._process(1.0 / 60.0)
	t.check("landing starts a local net catch", not fx.active_catches.is_empty())
	if not fx.active_catches.is_empty():
		var material: ShaderMaterial = fx.active_catches[0].material
		var sag: Vector4 = material.get_shader_parameter("catch_point")
		t.near("catch uses ball X", sag.x, contact.x)
		t.near("catch uses ball Z", sag.y, contact.z)
		t.near("catch maximum deflection", sag.z, 0.15)
		fx.step(0.2, contact)
		var middle: Vector4 = material.get_shader_parameter("catch_point")
		t.check("spring returns toward rest", middle.z > 0.0 and middle.z < sag.z)
		fx.step(0.21, contact)
		t.near("sag uniform returns to rest", (material.get_shader_parameter("catch_point") as Vector4).z, 0.0)
		fx.step(0.1, contact)
		t.eq("completed catch retires", fx.active_catches.size(), 0)
	fx.step(0.01, contact - Vector3.UP * 3.0)
	fx.step(0.01, contact)
	t.check("net rescue also gives a catch", not fx.active_catches.is_empty())
	fx.step(0.5, contact)
	fx.catch_at(Vector3(32.0, 11.0, 60.0))
	t.check("catch crosses a chunk seam", fx.active_catches.size() >= 2)
	fx.step(0.5, contact)
	fx.catch_at(Vector3(0.0, 29.0, 0.0))
	t.eq("island landing cannot sag the net", fx.active_catches.size(), 0)
	game.ctx.player.reset_to(base + Vector3(12.0, 16.0, 0.0))
	presence._process(1.0 / 60.0)
	GraphicsPreset.apply("low")
	t.eq("low idle motes reduced", column.views[0].multimesh.visible_instance_count, 3)
	t.eq("low idle streaks reduced", column.views[1].multimesh.visible_instance_count, 2)
	GraphicsPreset.apply("high")
	var start: Transform3D = fx.cloud_placements[0]
	var fog: float = game.ctx.terrain.environment.fog_density
	var sky: Sky = game.ctx.terrain.environment.sky
	fx.step(10.0, Vector3.INF)
	var shifted: Transform3D = fx.cloud_placements[0]
	t.check("cloud drifts slowly", shifted.origin.distance_to(start.origin) > 0.5 and shifted.origin.distance_to(start.origin) < 2.1)
	t.near("cloud altitude unchanged", shifted.origin.y, start.origin.y)
	fx.clock = 100000.0
	fx.step(0.2, Vector3.INF)
	var cloud_ok := true
	for i in fx.clouds.multimesh.instance_count:
		var at: Vector3 = fx.cloud_placements[i].origin
		cloud_ok = cloud_ok and absf(at.x) <= Fx.CLOUD_WRAP and absf(at.z) <= Fx.CLOUD_WRAP and at.y == -26.0
	t.check("clouds wrap within their visual bounds", cloud_ok)
	t.eq("motion does not touch fog", game.ctx.terrain.environment.fog_density, fog)
	t.check("motion does not touch sky", game.ctx.terrain.environment.sky == sky)
	fx.frozen = true
	var frozen: float = fx.clock
	fx.step(1.0, contact)
	t.eq("capture clock freezes", fx.clock, frozen)
	fx.frozen = false
	for barge in game.world.contraptions[5].barges:
		for marker in ["HighdraftWeatherSail", "HighdraftPennant"]:
			var sail: Node = barge.deck.get_node_or_null(marker)
			t.check("barge carries animated %s" % marker, sail != null)
			if sail != null:
				var animation: AnimationPlayer = sail.find_children("*", "AnimationPlayer", true, false)[0]
				t.eq("%s loops" % marker, animation.get_animation(animation.current_animation).loop_mode, Animation.LOOP_LINEAR)
	# Drop the actual unfrozen physics ball. Disable render polling to prove the existing
	# landing signal carries the catch even when no rendered frame samples the contact.
	presence.set_process(false)
	game.process_mode = Node.PROCESS_MODE_INHERIT
	game.ctx.player.body().freeze = false
	game.ctx.player.reset_to(contact + Vector3.UP * 3.0, Vector3.DOWN * 12.0)
	var caught := false
	for tick in 90:
		await physics_frame
		if not fx.active_catches.is_empty():
			caught = true
			break
	t.check("real physics landing catches without render polling", caught)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.ctx.player.body().freeze = true
	game.flow.enter_stage(6, Vector3.ZERO, false)
	t.check("stage 6 builds FX on entry", game.ctx.terrain.geometry_root(6).get_node_or_null("HighdraftScenery/WindEffects") != null)
	game.flow.enter_stage(1, Vector3.ZERO, false)
	t.check("stage exit hides Highdraft", not scenery.is_visible_in_tree())
	game.free()
	_fallback()
	quit(t.verdict())


func _fallback() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var presence := Scenery.Updater.new()
	scene.add_child(presence)
	Fx.shader_dir = "res://assets/materials/highdraft_missing/"
	var fx := Fx.install(scene, presence, preload("res://src/world/map_highdraft.gd").new())
	t.eq("missing shader adds no effects", fx, null)
	t.eq("missing shader leaves scenery intact", scene.get_child_count(), 1)
	Fx.shader_dir = Fx.SHADER_DIR
	var warnings := Scenery._warned.size()
	Scenery.dir = "res://assets/models/highdraft_fx_missing/"
	t.eq("missing sail retains existing scenery", Scenery._scene("prop_sail.glb"), null)
	t.eq("repeated missing sail also falls back", Scenery._scene("prop_sail.glb"), null)
	t.eq("one warning recorded per missing asset", Scenery._warned.size(), warnings + 1)
	Scenery.dir = Scenery.DIR
	scene.free()
