extends SceneTree

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Highdraft := preload("res://src/world/map_highdraft.gd")

# The Highdraft's own light (VX1): the editor-like grid floor is hidden, a cream cloud deck lies
# under the islands, the key follows the stage's time of day, the net draws its woven bone
# surface inside an amber edge, and weather sails stand in the stage after ten simulated
# seconds. Colours are derived here from the D2 sheet's hexes, not read from the code's table.
# Evidence limit: headless structure and values; no render, no capture, no feel claim.

const SHEET_CREAM := Color("ece7da")
const SHEET_AMBER := Color("e5a044")
const SHEET_BONE := Color("d2c5a5")
const SHEET_COOL := Color("a9b6c0")
const TOLERANCE := 0.1
const SAIL_SECONDS := 10.0

var _t := T.new("highdraft_light_test")


func _initialize() -> void:
	call_deferred("_run")


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= TOLERANCE and absf(a.g - b.g) <= TOLERANCE and absf(a.b - b.b) <= TOLERANCE


func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	for tick in 600:
		if game.flow != null:
			break
		await physics_frame
	if not _t.check("real game booted", game.flow != null):
		game.free()
		quit(_t.verdict())
		return
	game.flow.enter_stage(5, Vector3.ZERO, false)
	await physics_frame
	var stage: Node3D = game.ctx.terrain.geometry_root(5)
	var scenery: Node3D = stage.get_node("HighdraftScenery")

	var shown: Array[String] = []
	for node: Node in stage.find_children("*", "Node3D", true, false):
		var label := String(node.name).to_lower()
		if (label.contains("grid") or label.contains("floor")) and (node as Node3D).is_visible_in_tree():
			shown.append(String(stage.get_path_to(node)))
	var ground_views := stage.get_node("Ground").find_children("*", "MeshInstance3D", true, false)
	var ground_drawn := ground_views.any(func(view): return (view as Node3D).is_visible_in_tree())
	_t.check("no grid floor draws in the Highdraft", shown.is_empty() and not ground_drawn,
		"visible: %s, ground mesh drawn: %s" % [", ".join(shown), ground_drawn])
	var relief := scenery.get_node_or_null("IslandRelief") as MeshInstance3D
	_t.check("the island relief still draws the ground the ball can reach", relief != null and relief.is_visible_in_tree()
		and relief.mesh.get_aabb().size.y > 5.0)

	var lowest := INF
	for skin: MeshInstance3D in scenery.find_children("IslandSkin_*", "MeshInstance3D", false, false):
		lowest = minf(lowest, (skin.global_transform * skin.mesh.get_aabb()).position.y)
	lowest = minf(lowest, Highdraft.NET_H)
	var deck := scenery.get_node_or_null("Sky/CloudPlane") as MeshInstance3D
	_t.check("a cloud deck lies below the lowest island and the catch plane", deck != null and deck.is_visible_in_tree()
		and deck.global_position.y < lowest and lowest < INF, "deck %s, lowest %.1f" % [deck.global_position if deck != null else "none", lowest])
	_t.check("the cloud deck never collides", deck != null and deck.find_children("*", "CollisionObject3D", true, false).is_empty()
		and not (deck.get_parent() is CollisionObject3D))
	var cloud := deck.material_override as StandardMaterial3D if deck != null else null
	var cloud_sh := deck.material_override as ShaderMaterial if deck != null else null
	var cloud_tex: Texture2D = cloud.albedo_texture if cloud != null else (cloud_sh.get_shader_parameter("cloud_tex") as Texture2D if cloud_sh != null else null)
	var cloud_ok: bool = cloud_tex != null and (
		(cloud != null and _near(cloud_tex.get_image().get_pixel(0, 0), SHEET_CREAM.lerp(SHEET_COOL, 0.3)))
		or (cloud_sh != null and _near(Color(cloud_sh.get_shader_parameter("cloud_tint")), SHEET_CREAM))
	)
	_t.check("the cloud deck is cream with soft noise", cloud_ok)

	var holder := stage.get_parent()
	var key: DirectionalLight3D = null
	var fill: DirectionalLight3D = null
	var lights := holder.find_children("*", "DirectionalLight3D", false, false)
	for light: DirectionalLight3D in lights:
		if light.name == "SkyFill":
			fill = light
		elif key == null:
			key = light
	# 2026-10-13: KE7 merge 4cb6571, PARK.md:629 replaces Highdraft morning with golden/dusk.
	# Pin the merged TIME_ROWS values independently; the sheet still owns cloud, fill and net.
	_t.eq("the stage 5 key is golden-hour amber", key.light_color if key != null else null, Color("ffa35c"))
	_t.check("the key is low and casts shadows", key != null and key.shadow_enabled
		and key.rotation_degrees.is_equal_approx(Vector3(-16.0, 20.0, 0.0)), "rotation %s" % (key.rotation_degrees if key != null else Vector3.ZERO))
	_t.near("the golden-hour key keeps its time-row energy", key.light_energy if key != null else -1.0, 1.9)
	_t.check("the fill is the sheet's cool sky", fill != null and _near(fill.light_color, SHEET_COOL))
	_t.eq("one key plus the existing fill", lights.size(), 2)
	var env: Environment = game.ctx.terrain.environment
	_t.eq("stage 5 ambient follows golden hour", env.ambient_light_color, Color("e0b58a"))
	_t.eq("stage 5 ambient energy follows golden hour", env.ambient_light_energy, 0.25)

	var tiles := scenery.get_node("NetDeck").find_children("Tiles_*", "MultiMeshInstance3D", false, false)
	var woven := not tiles.is_empty()
	for tile: MultiMeshInstance3D in tiles:
		var weave := tile.material_override as ShaderMaterial
		woven = woven and weave != null and weave.shader.resource_path.ends_with("net_catch.gdshader") \
			and _near(weave.get_shader_parameter("cord_tint"), SHEET_BONE)
	_t.check("every net bowl chunk draws the woven bone material", woven, "%d chunks" % tiles.size())
	var edges := scenery.get_node_or_null("NetDeck/NetEdges") as MultiMeshInstance3D
	var edge := edges.material_override as StandardMaterial3D if edges != null else null
	# 2026-10-09 (wave 12 vx-ground): the edge wears Palette.nosing_material(), amber and charcoal 45 degree
	# bands from the slot table, so the amber is the stripe at pixel (0, 0), not the albedo colour.
	var band: Color = edge.albedo_texture.get_image().get_pixel(0, 0) if edge != null and edge.albedo_texture != null else Color.BLACK
	_t.check("the net edge is the catch amber", edge != null and _near(band, SHEET_AMBER),
		"edge band %s" % band)

	var ticks := int(SAIL_SECONDS * Engine.physics_ticks_per_second)
	for tick in ticks:
		await physics_frame
	var sails: Array[String] = []
	for node: Node in stage.find_children("*", "Node3D", true, false):
		var label := String(node.name)
		if not (label.begins_with("Sail_") or label == "HighdraftWeatherSail") or not (node as Node3D).is_visible_in_tree():
			continue
		var size := 0.0
		for view: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			size = maxf(size, (view.global_transform * view.mesh.get_aabb()).size.length())
		if size > 1.0:
			sails.append("%s at %s, %.1f m" % [label, (node as Node3D).global_position.snapped(Vector3.ONE * 0.1), size])
	print("sails after %d ticks: %s" % [ticks, "; ".join(sails)])
	_t.check("weather sails stand in the stage after ten simulated seconds", sails.size() >= 1, "%d sails" % sails.size())
	var capture := scenery.get_node_or_null("SailCapture") as Node3D
	var framed := false
	if capture != null:
		var ahead := -capture.global_transform.basis.z
		for node: Node in scenery.find_children("Sail_*", "Node3D", false, false):
			var to := (node as Node3D).global_position + Vector3.UP * 1.2 - capture.global_position
			framed = framed or (to.length() < 12.0 and ahead.dot(to.normalized()) > 0.95)
	_t.check("a capture viewpoint frames one sail", framed)
	game.free()
	quit(_t.verdict())
