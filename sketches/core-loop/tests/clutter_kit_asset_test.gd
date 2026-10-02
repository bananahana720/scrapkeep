extends SceneTree

const PATH := "res://assets/models/world_one/clutter_kit.glb"
const Palette := preload("res://src/core/palette.gd")
# Longest side, triangle cap, minimum height/longest side.
const LIMITS := {
	"rock_a": [0.25, 0.6, 40, 0.15], "rock_b": [0.25, 0.6, 40, 0.15],
	"rock_c": [0.25, 0.6, 40, 0.15], "slab_a": [0.6, 1.2, 50, 0.08],
	"slab_b": [0.6, 1.2, 50, 0.15], "plate_a": [0.4, 0.8, 60, 0.15],
	"plate_b": [0.4, 0.8, 60, 0.15], "stub_a": [0.45, 0.6, 72, 0.15],
	"tuft_a": [0.25, 0.4, 24, 0.15], "tuft_b": [0.25, 0.4, 24, 0.15],
}
const SLOTS := ["paint", "fleet_paint", "bare_metal"]
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s -> %s" % ["PASS" if ok else "FAIL", label, "PASS" if ok else "FAIL"])


func _run() -> void:
	var path := OS.get_environment("SCRAPKEEP_TEST_CLUTTER")
	if path.is_empty():
		path = ProjectSettings.globalize_path(PATH)
	var state := GLTFState.new()
	var doc := GLTFDocument.new()
	var err := doc.append_from_file(path, state)
	_check(err == OK, "CK-1 GLB parses")
	if err != OK:
		_done()
		return
	var names: Array = []
	var raw_nodes: Array = state.json.get("nodes", [])
	var raw_ok := raw_nodes.size() == LIMITS.size()
	for n: Dictionary in raw_nodes:
		names.append(n.get("name", ""))
		raw_ok = raw_ok and n.has("mesh") and not n.has("children")
		raw_ok = raw_ok and not n.has("translation") and not n.has("rotation") and not n.has("scale") and not n.has("matrix")
	names.sort()
	var wanted := LIMITS.keys()
	wanted.sort()
	_check(raw_ok and names == wanted, "CK-1 exactly ten named single-mesh nodes at the origin: %s" % [names])
	var scene := doc.generate_scene(state) as Node3D
	_check(scene != null, "CK-1 GLB generates a scene")
	if scene == null:
		_done()
		return
	root.add_child(scene)
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	_check(meshes.size() == LIMITS.size(), "CK-1 engine sees ten mesh instances")
	var proportions := {}
	for node: MeshInstance3D in meshes:
		if not LIMITS.has(str(node.name)):
			_check(false, "CK-1 unknown mesh %s" % node.name)
			continue
		proportions[str(node.name)] = _inspect(node)
	for pair in [["rock_a", "rock_b"], ["rock_a", "rock_c"], ["rock_b", "rock_c"]]:
		if not proportions.has(pair[0]) or not proportions.has(pair[1]):
			_check(false, "CK-5 missing rock")
			continue
		var a: Vector3 = proportions[pair[0]]
		var b: Vector3 = proportions[pair[1]]
		# Also compare sorted dimensions, so rotating a clone cannot make it a new silhouette.
		var aa := [a.x, a.y, a.z]
		var bb := [b.x, b.y, b.z]
		aa.sort()
		bb.sort()
		var different := false
		for i in 3:
			different = different or absf(aa[i] - bb[i]) / maxf(aa[i], bb[i]) > 0.15
		_check(different, "CK-5 %s / %s normalized proportions %s / %s differ by over 15%%" % [pair[0], pair[1], aa, bb])
	scene.free()
	if path == ProjectSettings.globalize_path(PATH):
		var packed := load(PATH) as PackedScene
		_check(packed != null, "CK-1 Godot imported resource loads")
		if packed != null:
			var imported := packed.instantiate()
			_check(imported.find_children("*", "MeshInstance3D", true, false).size() == 10, "CK-1 imported resource retains ten meshes")
			imported.free()
	_done()


func _inspect(node: MeshInstance3D) -> Vector3:
	var box := AABB()
	var first := true
	var triangles: Array = []
	var up_sum := 0.0
	var down_sum := 0.0
	var up_area := 0.0
	var down_area := 0.0
	var paint_found := false
	var nearest_signal := INF
	var vertex_count := 0
	var sand_luma := _luma(Palette.SAND.srgb_to_linear())
	for surface in node.mesh.get_surface_count():
		var mat := node.get_active_material(surface) as StandardMaterial3D
		var slot := mat.resource_name if mat != null else "missing"
		_check(mat != null and slot in SLOTS and not mat.emission_enabled, "CK-3 %s surface %d slot %s has no emission" % [node.name, surface, slot])
		var arrays := node.mesh.surface_get_arrays(surface)
		var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		for col in colors:
			vertex_count += 1
			for signal_colour in [Palette.AMBER, Palette.ARC, Palette.HAZARD]:
				nearest_signal = minf(nearest_signal, _lab(col).distance_to(_lab(signal_colour.srgb_to_linear())))
		var is_paint := slot == "paint"
		if is_paint:
			paint_found = true
			_check(colors.size() == pos.size(), "CK-6 %s paint surface has vertex colours (%d colours, %d positions, enabled=%s)" % [node.name, colors.size(), pos.size(), mat.vertex_color_use_as_albedo])
		var colour_ok := mat != null and _luma(mat.albedo_color.srgb_to_linear()) <= sand_luma + 0.0001
		if slot == "fleet_paint":
			var colour := mat.albedo_color
			colour_ok = colour_ok and absf(colour.r - Palette.RUST.r) < 0.005 and absf(colour.g - Palette.RUST.g) < 0.005 and absf(colour.b - Palette.RUST.b) < 0.005
		elif slot == "bare_metal":
			var colour := mat.albedo_color
			colour_ok = colour_ok and absf(colour.r - colour.g) < 0.08 and colour.b <= colour.g + 0.08
		if is_paint:
			colour_ok = not colors.is_empty()
			for col in colors:
				colour_ok = colour_ok and _luma(col) <= sand_luma + 0.0001 and col.a > 0.999
				# Dry earth and straw keep R >= G >= B; KC-2 measures gameplay colour distance.
				colour_ok = colour_ok and col.r >= col.g and col.g >= col.b
		_check(colour_ok, "CK-3 %s surface %d stays below sand brightness in muted earth/metal colours" % [node.name, surface])
		for v in pos:
			var at := node.global_transform * v
			box = AABB(at, Vector3.ZERO) if first else box.expand(at)
			first = false
		var count := idx.size() if not idx.is_empty() else pos.size()
		for i in range(0, count, 3):
			var ids := [idx[i], idx[i + 1], idx[i + 2]] if not idx.is_empty() else [i, i + 1, i + 2]
			var a := node.global_transform * pos[ids[0]]
			var b := node.global_transform * pos[ids[1]]
			var c := node.global_transform * pos[ids[2]]
			var normal: Vector3 = (normals[ids[0]] + normals[ids[1]] + normals[ids[2]]).normalized()
			var area := (b - a).cross(c - a).length() * 0.5
			triangles.append([a, b, c, normal, slot])
			if is_paint and colors.size() == pos.size():
				var mean := (_luma(colors[ids[0]]) + _luma(colors[ids[1]]) + _luma(colors[ids[2]])) / 3.0
				if normal.y > 0.15:
					up_sum += mean * area
					up_area += area
				elif normal.y < -0.15:
					down_sum += mean * area
					down_area += area
	_check(vertex_count > 0 and nearest_signal >= 20.0, "KC-2 %s nearest gameplay colour CIE76 %.6f >= 20" % [node.name, nearest_signal])
	var size := box.size
	var longest := maxf(size.x, maxf(size.y, size.z))
	var limits: Array = LIMITS[str(node.name)]
	print("CK_METRIC %s triangles=%d size=%s lowest_y=%.6f" % [node.name, triangles.size(), size, box.position.y])
	_check(triangles.size() > 0 and triangles.size() <= limits[2], "CK-2 %s triangles %d <= %d" % [node.name, triangles.size(), limits[2]])
	_check(longest >= limits[0] and longest <= limits[1], "CK-2 %s longest %.6f within %.2f..%.2f" % [node.name, longest, limits[0], limits[1]])
	_check(absf(box.position.y) <= 0.01, "CK-2 %s lowest y %.6f within 1 cm of ground" % [node.name, box.position.y])
	_check(size.x > 0.001 and size.z > 0.001 and size.y >= longest * limits[3], "CK-4 %s height %.6f >= %.2f of longest %.6f" % [node.name, size.y, limits[3], longest])
	if str(node.name).begins_with("tuft_"):
		_check(size.y >= 0.25 and size.y <= 0.4, "CK-2 %s tuft height %.6f within 0.25..0.4" % [node.name, size.y])
	if str(node.name).begins_with("plate_"):
		var thickness := _plate_thickness(triangles)
		_check(thickness >= 0.03 - 0.00001, "CK-4 %s physical thickness %.6f m >= 0.030000 m" % [node.name, thickness])
	if str(node.name) == "stub_a":
		_check(size.y >= 0.45 and size.y <= 0.6, "KC-3 stub_a height %.6f within 0.45..0.6 m" % size.y)
		var inside_sectors := {}
		var rim_y := box.end.y
		for face: Array in triangles:
			var centre: Vector3 = (face[0] + face[1] + face[2]) / 3.0
			var radial := Vector3(centre.x, 0.0, centre.z)
			var normal: Vector3 = face[3]
			var near_top := maxf(face[0].y, maxf(face[1].y, face[2].y)) >= rim_y - 0.04
			if near_top and radial.length() > 0.025 and radial.length() < 0.06 and normal.dot(-radial.normalized()) > 0.8:
				inside_sectors[int(floor(wrapf(atan2(centre.z, centre.x), 0.0, TAU) / (TAU / 6.0)))] = true
		_check(inside_sectors.size() == 6, "KC-3 stub_a inward-facing inside ring near top covers %d/6 sectors" % inside_sectors.size())
	var up := up_sum / up_area if up_area > 0.0 else 0.0
	if str(node.name).begins_with("rock_") or str(node.name).begins_with("slab_") or str(node.name).begins_with("tuft_"):
		_check(up_area > 0.0 and up / sand_luma >= 0.45 and up / sand_luma <= 0.95, "KC-1 %s up-facing mean luminance %.6f / sand %.6f = %.6f within 0.45..0.95" % [node.name, up, sand_luma, up / sand_luma])
	if paint_found:
		var down := down_sum / down_area if down_area > 0.0 else 0.0
		_check(up_area > 0.0 and down_area > 0.0 and up > down + 0.000001, "CK-6 %s area-weighted upward mean %.6f > downward mean %.6f" % [node.name, up, down])
	return size / longest if longest > 0.0 else Vector3.ZERO


func _plate_thickness(triangles: Array) -> float:
	var minimum := INF
	var sampled := 0
	for face: Array in triangles:
		var normal: Vector3 = face[3]
		if face[4] != "fleet_paint" or normal.y <= 0.0:
			continue
		sampled += 1
		var gap := _parallel_cap_gap(face, triangles)
		minimum = minf(minimum, gap)
	return minimum if sampled > 0 and is_finite(minimum) else 0.0


func _parallel_cap_gap(face: Array, triangles: Array) -> float:
	var normal: Vector3 = face[3]
	for other: Array in triangles:
		var other_normal: Vector3 = other[3]
		if normal.dot(other_normal) > -0.9999:
			continue
		for order in [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]:
			var delta: Vector3 = face[0] - other[order[0]]
			var second: Vector3 = face[1] - other[order[1]]
			var third: Vector3 = face[2] - other[order[2]]
			if delta.distance_to(second) < 0.00001 and delta.distance_to(third) < 0.00001:
				# Corresponding corners share one translation, so the normal gap is constant
				# over the entire paired facet, including a locally thinned corner.
				return absf(delta.dot(normal))
	return 0.0


func _luma(c: Color) -> float:
	return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722


func _lab(c: Color) -> Vector3:
	var x := (0.4124564 * c.r + 0.3575761 * c.g + 0.1804375 * c.b) / 0.95047
	var y := (0.2126729 * c.r + 0.7151522 * c.g + 0.0721750 * c.b)
	var z := (0.0193339 * c.r + 0.1191920 * c.g + 0.9503041 * c.b) / 1.08883
	return Vector3(116.0 * _lab_curve(y) - 16.0, 500.0 * (_lab_curve(x) - _lab_curve(y)), 200.0 * (_lab_curve(y) - _lab_curve(z)))


func _lab_curve(value: float) -> float:
	return pow(value, 1.0 / 3.0) if value > 216.0 / 24389.0 else value * 841.0 / 108.0 + 4.0 / 29.0


func _done() -> void:
	print("clutter_kit_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
