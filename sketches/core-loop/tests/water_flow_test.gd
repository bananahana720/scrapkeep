extends SceneTree

# The spillway water runs (spill_water.gdshader, SpillwayScenery.flow_at), checked on the built
# meshes of both world 1 water surface kinds: the spill sheets and the tailrace.
# What it shows: at t and t + 0.5 s every vertex's pattern offset differs; on every sloped face the
# flow points down the slope (negative dot with the uphill direction, worked out here on its own);
# a steeper face runs faster; the flat tailrace drifts away from the falls; reduced motion slows the
# flow and does not stop it; the shader source carries the same flow as flow_at and reads TIME; and
# both surfaces are built with the boot's scenery from one shader that writes no ALPHA, so their
# pipelines compile at boot like before and nothing compiles at the first sight of water.
# What it cannot show: pixels (the headless runner draws with the dummy renderer, so no frame is
# rendered or compared), and whether the water looks good. The shader is checked through its
# GDScript twin and its source text, not by running it on a GPU.
# Plant: SCRAPKEEP_WATER_FLOW_PLANT=freeze freezes time here (the twin's clock and TIME in the
# source); the test must then fail.

const Terrain := preload("res://src/world/terrain.gd")
const Scenery := preload("res://src/presentation/spillway_scenery.gd")
const SHADER_PATH := "res://src/presentation/spill_water.gdshader"
const KINDS := ["SpillSheets", "Tailrace"]
# Vertex counts of the two built meshes (assets/models/world_one/water_edges.glb), and how many of
# each are sloped and flat: the sheets are all fall, the tailrace all level.
const VERTICES := {"SpillSheets": 72, "Tailrace": 34}
const SLOPED_VERTICES := {"SpillSheets": 72, "Tailrace": 0}
const FLAT_VERTICES := {"SpillSheets": 0, "Tailrace": 34}
const T0 := 0.2
const STEP := 0.5
# A face counts as sloped above this sine of its slope, and as flat below FLAT.
const SLOPED := 0.2
const FLAT := 0.05

var failures := 0
var frozen := OS.get_environment("SCRAPKEEP_WATER_FLOW_PLANT") == "freeze"


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])


func _offset(normal: Vector3, drift: Vector2, time_s: float) -> Vector3:
	return Scenery.flow_offset(normal, drift, 0.0 if frozen else time_s)


func _run() -> void:
	if frozen:
		print("PLANT water flow frozen: this run must fail")
	var world := Node3D.new()
	root.add_child(world)
	var terrain := Terrain.new()
	terrain.build(world)
	var scenery := Scenery.build(terrain.geometry_root(1))
	var shader := load(SHADER_PATH) as Shader

	var views := {}
	for child in scenery.get_children():
		var mat := (child as GeometryInstance3D).material_override if child is GeometryInstance3D else null
		if mat is ShaderMaterial and (mat as ShaderMaterial).shader == shader:
			views[String(child.name)] = child
	_check(views.keys().size() == KINDS.size() and KINDS.all(func(k): return views.has(k)),
		"%d water surface kinds wear spill_water, one shader resource: %s" % [KINDS.size(), views.keys()])

	var speeds := {}
	for kind in KINDS:
		if not views.has(kind):
			continue
		var view: MeshInstance3D = views[kind]
		# Unset reads back null (the uniform's default, zero drift).
		var set_drift = (view.material_override as ShaderMaterial).get_shader_parameter("drift")
		var drift: Vector2 = set_drift if set_drift != null else Vector2.ZERO
		var arrays := view.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var moved := 0
		var sloped := 0
		var downhill := 0
		var flat := 0
		var away := 0
		var total_speed := 0.0
		for i in vertices.size():
			var n := normals[i].normalized()
			var flow := Scenery.flow_at(n, drift)
			total_speed += flow.length()
			if (_offset(n, drift, T0 + STEP) - _offset(n, drift, T0)).length() > 0.01:
				moved += 1
			var steep := sqrt(maxf(0.0, 1.0 - n.y * n.y))
			if steep > SLOPED:
				sloped += 1
				var uphill := Vector3.UP - n * n.y
				if flow.dot(uphill) < 0.0:
					downhill += 1
			elif steep < FLAT:
				flat += 1
				if drift != Vector2.ZERO and Vector2(flow.x, flow.z).dot(drift) > 0.0:
					away += 1
		speeds[kind] = total_speed / maxf(1.0, vertices.size())
		print("%s: %d vertices, %d sloped, %d flat, drift %s, mean speed %.3f m/s" % [kind, vertices.size(), sloped, flat, drift, speeds[kind]])
		_check(vertices.size() == VERTICES[kind] and sloped == SLOPED_VERTICES[kind] and flat == FLAT_VERTICES[kind],
			"%s has its pinned %d vertices, %d sloped and %d flat" % [kind, VERTICES[kind], SLOPED_VERTICES[kind], FLAT_VERTICES[kind]])
		_check(vertices.size() > 0 and moved == vertices.size(), "%s: every vertex's pattern moves between t and t + %.1f s (%d of %d)" % [kind, STEP, moved, vertices.size()])
		_check(downhill == sloped, "%s: flow runs downhill on every sloped face (%d of %d)" % [kind, downhill, sloped])
		if kind == "Tailrace":
			_check(drift.length() > 0.0 and flat > 0 and away == flat, "Tailrace: flat water drifts away from the falls (%d of %d)" % [away, flat])
	if speeds.has("SpillSheets") and speeds.has("Tailrace"):
		_check(speeds["SpillSheets"] > speeds["Tailrace"] * 2.0, "the spill sheets run faster than the tailrace (%.2f against %.2f m/s)" % [speeds["SpillSheets"], speeds["Tailrace"]])

	# A steeper face runs faster, with no drift, at 10, 30, 60 and 85 degrees.
	var last := -1.0
	var rising := true
	for degrees in [10.0, 30.0, 60.0, 85.0]:
		var normal := Vector3(sin(deg_to_rad(degrees)), cos(deg_to_rad(degrees)), 0.0)
		var travelled := (_offset(normal, Vector2.ZERO, T0 + STEP) - _offset(normal, Vector2.ZERO, T0)).length()
		rising = rising and travelled > last
		last = travelled
	_check(rising, "a steeper slope carries the pattern further in %.1f s" % STEP)

	var steep_normal := Vector3(0.0, 0.2, 1.0).normalized()
	var full := (_offset(steep_normal, Vector2.ZERO, T0 + STEP) - _offset(steep_normal, Vector2.ZERO, T0)).length()
	Scenery.set_water_calm(true)
	var calm := (_offset(steep_normal, Vector2.ZERO, T0 + STEP) - _offset(steep_normal, Vector2.ZERO, T0)).length()
	Scenery.set_water_calm(false)
	_check(calm > 0.0 and calm < full, "reduced motion slows the flow and does not stop it (%.3f against %.3f m)" % [calm, full])

	var source := shader.code
	if frozen:
		source = source.replace("TIME", "0.0")
	_check(source.contains("TIME * water_flow_scale"), "the shader's pattern runs on TIME scaled by water_flow_scale")
	_check(source.contains("global uniform float water_flow_scale;") and ProjectSettings.has_setting("shader_globals/water_flow_scale"),
		"water_flow_scale is a project shader global")
	_check(source.contains("vec3 downhill = vec3(n.x*n.y, n.y*n.y - 1.0, n.z*n.y);")
		and source.contains("flow = downhill * FALL_SPEED + vec3(drift.x, 0.0, drift.y) * (1.0 - steep);")
		and source.contains("const float FALL_SPEED = %.1f;" % Scenery.WATER_FALL_SPEED)
		and source.contains("const float FLOW_PERIOD = %.1f;" % Scenery.WATER_FLOW_PERIOD),
		"the shader's flow matches SpillwayScenery.flow_at")

	# Same render state as before: opaque (no ALPHA write), one render mode, no defines, so the
	# boot's scenery build compiles the only pipelines it needs.
	_check(source.contains("render_mode cull_disabled;") and not source.contains("ALPHA") and not source.contains("#define"),
		"the water stays one opaque shader with its old render mode")
	_check(scenery.get_parent() == terrain.geometry_root(1), "the water is built with the scenery, which game.gd builds at boot for every spillway stage")

	print("water_flow_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures > 0 else 0)
