extends RefCounted

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")


static func boot(tree: SceneTree):
	var game := Game.new()
	game.test_mode = true
	game.table = "alpha"
	tree.root.add_child(game)
	for tick in 600:
		if game.flow != null:
			break
		await tree.physics_frame
	if game.flow != null:
		game.ctx.calm = true
		Harness.boot(game)
	return game


static func lighting(game) -> Dictionary:
	var env: Environment = game.ctx.terrain.environment
	var sun: DirectionalLight3D
	for light in game.find_children("*", "DirectionalLight3D", true, false):
		if light.name != "SkyFill":
			sun = light
			break
	return {"sky": env.sky.get_instance_id(), "background": env.background_mode, "ambient": env.ambient_light_color,
		"energy": env.ambient_light_energy, "exposure": env.tonemap_exposure,
		"saturation": env.adjustment_saturation, "fog": env.fog_density,
		"sun_color": sun.light_color, "sun_rotation": sun.rotation_degrees.snapped(Vector3.ONE * 0.0001), "sun_visible": sun.visible}


static func check_lighting(t, label: String, game, expected: Dictionary) -> void:
	var actual := lighting(game)
	var changed := []
	for key in expected:
		if actual[key] != expected[key]:
			changed.append(key)
	t.check(label, changed.is_empty(), "changed %s" % str(changed))
