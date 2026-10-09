extends SceneTree

# VX3: the three dark places (the Waking pit rig, a pylon wall segment, the cracked cache)
# on every quality preset. Light count and total energy sit inside the recorded ranges, and
# 2026-10-09 re-pin (LIGHT-FIX): the pit total energy falls from 79-80 to 60.2 (measured) because the rim pool
# lights drop from 2.2 to 1.0 each (arena_waking_dress.gd LIGHTS.rim_pool); the light set stays 50.
# no floor carries a glow; no emissive anywhere in them wears a telegraph colour.
# Headless: this reads the light and material inputs; the rendered 18% floor is the capture's.

const Probe := preload("res://tests/support/lighting_harness.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const Palette := preload("res://src/core/palette.gd")
const StageMap := preload("res://src/world/stage_map.gd")
const Cache := preload("res://src/world/cracked_cache.gd")
const T := preload("res://tests/support/t.gd")
const PRESETS := ["low", "high", "target"]
# [min count, max count, min energy, max energy] per place; the same on every preset.
const RANGES := {
	"waking_pit": [50, 50, 60.0, 60.5],
	"pylon_wall": [0, 0, 0.0, 0.0],
	# 2026-10-08: cache light removed (freed per-cache light crashed Forward+); its glow is emission.
	"cache": [0, 0, 0.0, 0.0],
}
const TELEGRAPH := [Palette.HAZARD, Palette.ARC, Palette.AMBER]
var _t := T.new("cache_waking_pylon_lit_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = await Probe.boot(self)
	_waking(game)
	_pylon()
	_cache(game)
	Preset.apply("high")
	game.free()
	quit(_t.verdict())


func _lights(nodes: Array) -> Dictionary:
	var count := 0
	var energy := 0.0
	for node: Node in nodes:
		var found: Array = node.find_children("*", "Light3D", true, false)
		if node is Light3D:
			found.append(node)
		for light: Light3D in found:
			if light.visible and light.light_energy > 0.0:
				count += 1
				energy += light.light_energy
	return {"count": count, "energy": energy}


func _in_range(place: String, preset: String, nodes: Array) -> void:
	var got := _lights(nodes)
	var row: Array = RANGES[place]
	_t.check("%s on %s has %d to %d lights" % [place, preset, row[0], row[1]],
		got.count >= row[0] and got.count <= row[1], "count %d" % got.count)
	_t.check("%s on %s carries %.1f to %.1f light energy" % [place, preset, row[2], row[3]],
		got.energy >= row[2] - 0.001 and got.energy <= row[3] + 0.001, "energy %.2f" % got.energy)


func _materials(view: GeometryInstance3D) -> Array:
	var mesh: Mesh = view.mesh if view is MeshInstance3D else (view.multimesh.mesh if view is MultiMeshInstance3D and view.multimesh != null else null)
	var result := []
	if view.material_override != null:
		result.append(view.material_override)
	if mesh != null:
		for s in mesh.get_surface_count():
			if view is MeshInstance3D and view.get_surface_override_material(s) != null:
				result.append(view.get_surface_override_material(s))
			elif mesh.surface_get_material(s) != null:
				result.append(mesh.surface_get_material(s))
	return result


func _emission(material: Material) -> Variant:
	if material is BaseMaterial3D and material.emission_enabled and material.emission_energy_multiplier > 0.0:
		return material.emission
	if material is ShaderMaterial and material.shader != null and material.shader.code.contains("EMISSION"):
		return Color.WHITE
	return null


func _telegraph(color: Color) -> bool:
	for hue: Color in TELEGRAPH:
		if Vector3(color.r - hue.r, color.g - hue.g, color.b - hue.b).length() < 0.2:
			return true
	return false


func _no_glow(place: String, nodes: Array, floors: Array) -> void:
	var telegraph := 0
	for node: Node in nodes:
		for view: GeometryInstance3D in node.find_children("*", "GeometryInstance3D", true, false):
			for material in _materials(view):
				var glow = _emission(material)
				if glow != null and _telegraph(glow):
					telegraph += 1
	_t.eq("%s wears no telegraph-coloured emissive" % place, telegraph, 0)
	var glowing := 0
	for floor_node: Node in floors:
		var views: Array = floor_node.find_children("*", "GeometryInstance3D", true, false)
		if floor_node is GeometryInstance3D:
			views.append(floor_node)
		for view: GeometryInstance3D in views:
			for material in _materials(view):
				if _emission(material) != null:
					glowing += 1
	_t.eq("%s floors carry no glow" % place, glowing, 0)


func _waking(game) -> void:
	Preset.apply("high")
	Harness.enter_world(game, 2)
	var mod = Harness.module(game, 2)
	var dress = mod._arena_dress
	if not _t.check("Waking pit rig dresses", dress != null):
		return
	var bodies: Array = [mod.pad] + mod._floor_bodies.values()
	var floors := []
	for body: Node in bodies:
		for child in body.get_children():
			if child is MeshInstance3D or String(child.name) in ["PitDressing", "FloorDressing"]:
				floors.append(child)
	for preset in PRESETS:
		Preset.apply(preset)
		_in_range("waking_pit", preset, [dress] + bodies)
		_no_glow("waking_pit on " + preset, [dress] + bodies, floors)
	var floor_material := (floors.filter(func(n): return n is MeshInstance3D)[0] as MeshInstance3D).material_override as ShaderMaterial
	_t.check("pit floor is tiled plate at 4 m or finer", floor_material.get_shader_parameter("panel_pitch") <= 4.0)
	_t.check("pit floor plate seams are at least 0.12 m", floor_material.get_shader_parameter("seam_width") >= 0.12)
	var stone := dress._materials["stone"] as ShaderMaterial
	var flat: Vector3 = stone.get_shader_parameter("flat_color")
	_t.check("pit stone albedo is lifted to 0.50 or above", Color(flat.x, flat.y, flat.z).get_luminance() >= 0.50, "luminance %.3f" % Color(flat.x, flat.y, flat.z).get_luminance())
	for pool: OmniLight3D in mod._floor_bodies[1].find_children("RimPool*", "OmniLight3D", true, false):
		_t.check("rim pool reaches the floor centre", pool.omni_range > Vector2(pool.position.x, pool.position.z).length())
	mod.exit_arena()


func _pylon() -> void:
	for preset in PRESETS:
		Preset.apply(preset)
		var parent := Node3D.new()
		root.add_child(parent)
		StageMap.pylon_wall(parent, Vector3.ZERO, 12.0, 6.0, 0.0)
		_in_range("pylon_wall", preset, [parent])
		_no_glow("pylon_wall on " + preset, [parent], [])
		var wall := parent.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var mat := wall.material_override as ShaderMaterial
		_t.check("pylon wall keeps the lifted concrete on " + preset, mat != null and mat.shader.code.contains("const float CONCRETE_VALUE_GAIN = 1.65;"))
		parent.free()


func _cache(game) -> void:
	for preset in PRESETS:
		Preset.apply(preset)
		var cache := Cache.new() as Node3D
		root.add_child(cache)
		cache.position = Vector3(0, 40, 0)
		cache.setup(game.ctx, game.world.interact, {"id": "vx3_cache_" + preset})
		_in_range("cache", preset, [cache])
		_no_glow("cache on " + preset, [cache], [])
		var finished := 0
		var marks := 0
		for view: MeshInstance3D in cache.find_children("*", "MeshInstance3D", true, false):
			for s in view.mesh.get_surface_count():
				var material := view.get_active_material(s)
				var shader_finish := material is ShaderMaterial and String(material.resource_name).begins_with("gpw_")
				if shader_finish:
					finished += 1
				# The amber signpost is painted into the vertex colours; the finish must still read them.
				var colours = view.mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]
				if colours != null and shader_finish and material.shader.code.contains("COLOR.rgb"):
					for c: Color in colours:
						if c.r > 0.5 and c.r > c.g and c.g > c.b and c.r - c.b > 0.3:
							marks += 1
		_t.check("cache shell and chest wear the workshop finish on " + preset, finished >= 4, "finished %d" % finished)
		_t.check("cache keeps its amber signpost marks on " + preset, marks >= 1, "marks %d" % marks)
		cache.stand_down()
		cache.free()
