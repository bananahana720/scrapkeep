extends SceneTree

# Gate for the park ground's pylon-bite tint (step 3 of the park ground): a vertex whose 2 m grid
# normal a pylon can bite (the rule terrain.gd tints the old maps by, now in pylon_bite.gd) wears a
# colour-map multiplier slot_mult.lerp(tint / D, w), with D the mean albedo the auto-shader draws
# there; cells with no biting corner keep step 2's slot tint.
# The expected values are recomputed here from ground.heights with the old formula inline, not by
# calling park_terrain.gd's bite code. Parks go through make_render, start, finish; the unbaked path
# is driven by a fake map whose sample() is a ramp.
# park_pit also skips the tint inside the footprints of its six berm rows (PylonBite.BERM_ROWS, padded 2 m): a LOOK
# rule. The berm flanks stay bitable (a ball at their foot bites them) but untinted by design, so the tint
# under-reports them (coordinator 6342820238 item 3, 6345347272 item 4, NEEDS 6350588099). The expected values below
# apply an independently written copy of that mask; every other park has none. Headless Terrain3D draws nothing, so this reads
# the colour maps.

const T := preload("res://tests/support/t.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")
const PylonBite := preload("res://src/world/pylon_bite.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Palette := preload("res://src/core/palette.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const MaterialSlots := preload("res://src/presentation/material_slots.gd")

const PARKS := ["park_pit", "park_sinkhole", "park_test"]
# The parks with no berm mask, loaded only to check the mask stays off.
const OTHER_PARKS := ["park_dam", "park_flume", "park_sinkhole", "park_crown", "park_islands"]
const BERM_ROWS := ["dump_berm_east", "dump_berm_west", "rim_road_berm", "haul_ramp_berm", "wash_berm", "bench3_west_berm"]
const BERM_PAD := 2.0
const CELLS := 800
# Cells from another slot or the edge within which the colour map is feathered (park_ground_surface_test.gd).
const DEEP := 5
const SIDE := 801
const REGION := 1024
const SAMPLES := 150
const BYTE := 1.0 / 255.0 + 0.0001
const FACE := 0.866
# The two textures' mean albedo, as park_terrain.gd's GROUND_STRATA_MEAN and GROUND_FLOOR_MEAN document.
const STRATA_MEAN := Color(0.731, 0.535, 0.366)
const FLOOR_MEAN := Color(0.7327, 0.5977, 0.4117)

var t := T.new("park_ground_bite_test")


# Terrain3D wants a plain ramp from the unbaked path: a slope of 0.8 (about 38.7 degrees) for 0 < x < 40.
class Ramp:
	extends RefCounted
	func sample(x: float, _z: float) -> Array:
		return [0.8 * clampf(x, 0.0, 40.0), Color(0.5, 0.4, 0.3)]


# A saddle, steep and bent in both x and z, so a cell's b-c and a-d diagonals disagree.
class Saddle:
	extends RefCounted
	func sample(x: float, z: float) -> Array:
		return [0.03 * clampf(x, -60.0, 60.0) * clampf(z, -60.0, 60.0), Color(0.5, 0.4, 0.3)]


# A steep slope along x everywhere (2 m up per metre), so the play square's x edges bite with clamped neighbours.
class Wall:
	extends RefCounted
	func sample(x: float, _z: float) -> Array:
		return [2.0 * x, Color(0.5, 0.4, 0.3)]


class World:
	extends Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_pin_strata_mean()
	_check_rule()
	_check_old_map()
	var holder := Node3D.new()
	root.add_child(holder)
	var camera := Camera3D.new()
	holder.add_child(camera)
	camera.make_current()
	for id in PARKS:
		await process_frame
		var render: Node3D = ParkTerrain.make_render(holder, "Render_" + id)
		var ground := ParkTerrain.new()
		holder.add_child(ground)
		ground.start(id, null, false, render)
		await process_frame
		_check_park(id, ground, render)
		ground.queue_free()
		render.queue_free()
	await process_frame
	var render: Node3D = ParkTerrain.make_render(holder, "Render_ramp")
	var ground := ParkTerrain.new()
	holder.add_child(ground)
	ground.start("no_such_park", Ramp.new(), false, render)
	await process_frame
	_check_ramp(ground, render)
	ground.queue_free()
	render.queue_free()
	await process_frame
	render = ParkTerrain.make_render(holder, "Render_saddle")
	ground = ParkTerrain.new()
	holder.add_child(ground)
	ground.start("no_such_park", Saddle.new(), false, render)
	await process_frame
	_check_saddle(ground, render)
	ground.queue_free()
	render.queue_free()
	await process_frame
	render = ParkTerrain.make_render(holder, "Render_wall")
	ground = ParkTerrain.new()
	holder.add_child(ground)
	ground.start("no_such_park", Wall.new(), false, render)
	await process_frame
	_check_wall(ground, render)
	ground.queue_free()
	render.queue_free()
	await process_frame
	await _check_planted_and_others(holder)
	quit(t.verdict())


# GROUND_STRATA_MEAN is the true mean of the strata texture, recomputed here over every pixel.
func _pin_strata_mean() -> void:
	var row: Dictionary = MaterialSlots.row("ground")
	# A copy: headless, get_image() hands back the texture's own image, and the decompress and
	# convert below would change the format Terrain3D later reads from it.
	var img: Image = PaletteMaterials.look_texture(row.textures.strata_map).get_image().duplicate()
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	var data := img.get_data()
	var n := data.size() / 4
	var sum := [0, 0, 0]
	for p in n:
		sum[0] += data[p * 4]
		sum[1] += data[p * 4 + 1]
		sum[2] += data[p * 4 + 2]
	var mean := Color(sum[0] / 255.0 / n, sum[1] / 255.0 / n, sum[2] / 255.0 / n)
	print("strata mean measured over %d pixels: %s" % [n, mean])
	var declared = (ParkTerrain as GDScript).get_script_constant_map().get("GROUND_STRATA_MEAN", Color.MAGENTA)
	t.check("GROUND_STRATA_MEAN = strata texture mean over %d pixels, within 0.002" % n, absf(declared.r - mean.r) <= 0.002 and absf(declared.g - mean.g) <= 0.002 and absf(declared.b - mean.b) <= 0.002, "got %s, want %s" % [declared, mean])
	t.check("the test's STRATA_MEAN matches the declared one", declared == STRATA_MEAN, str(declared))


func _old_weight(n_y: float) -> float:
	return clampf((FACE - n_y) * 6.0, 0.0, 0.8) if n_y < FACE else 0.0


func _check_rule() -> void:
	var sweep := [1.0, 0.95, 0.9, FACE + 0.0001, FACE, FACE - 0.00001, 0.85, 0.8, 0.74, 0.7328, 0.7326, 0.6, 0.3, 0.0, -0.5]
	var bad := 0
	for y in sweep:
		if not is_equal_approx(PylonBite.weight(y), _old_weight(y)):
			bad += 1
	t.eq("PylonBite.weight equals the old formula over %d normals" % sweep.size(), bad, 0)
	t.eq("PylonBite.weight is 0 at exactly FACE", PylonBite.weight(FACE), 0.0)
	t.check("PylonBite.weight is above 0 just below FACE", PylonBite.weight(FACE - 0.00001) > 0.0)
	t.near("PylonBite.weight caps at 0.8 on a very steep face", PylonBite.weight(0.2), 0.8, 0.0)
	t.eq("PylonBite.FACE", PylonBite.FACE, FACE)
	var want := Palette.VERDIGRIS.lerp(Palette.CHARCOAL, 0.25)
	t.check("PylonBite.tint = VERDIGRIS.lerp(CHARCOAL, 0.25)", PylonBite.tint().is_equal_approx(want) and PylonBite.tint() == want, str(PylonBite.tint()))


# terrain.gd's mesh colours for a small ramp map, against base.lerp(tint, w) from the heights.
func _check_old_map() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var terrain := Terrain.new()
	var map := Ramp.new()
	var heights: PackedFloat32Array = terrain._build_ground(holder, map)
	var body: Node = holder.get_node("Ground")
	var view: MeshInstance3D = body.get_children().filter(func(n): return n is MeshInstance3D)[0]
	var colors: PackedColorArray = view.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var side := 201
	var base := Color(0.5, 0.4, 0.3)
	var tint := Palette.VERDIGRIS.lerp(Palette.CHARCOAL, 0.25)
	var bitten := 0
	var bad := 0
	var flat := 0
	for j in side:
		for i in side:
			var idx := j * side + i
			var left: float = heights[idx - (1 if i > 0 else 0)]
			var right: float = heights[idx + (1 if i < side - 1 else 0)]
			var back: float = heights[idx - (side if j > 0 else 0)]
			var front: float = heights[idx + (side if j < side - 1 else 0)]
			var n := Vector3(left - right, 4.0, back - front).normalized()
			var want := base
			if n.y < FACE:
				want = base.lerp(tint, clampf((FACE - n.y) * 6.0, 0.0, 0.8))
				bitten += 1
			else:
				flat += 1
			# The mesh keeps its vertex colours as 8-bit channels, so they match to a byte.
			if not _same(colors[idx], Color(want.r, want.g, want.b, 1.0)):
				bad += 1
	t.check("old map: the ramp has biting and flat vertices", bitten > 0 and flat > 0, "%d, %d" % [bitten, flat])
	t.eq("old map: %d vertex colours (%d biting) equal base.lerp(tint, w) from the heights" % [colors.size(), bitten], bad, 0)
	holder.queue_free()


# One grid vertex's n.y and weight from the heights, terrain.gd's rule written out again.
func _grid(h: PackedFloat32Array, mask := PackedByteArray()) -> Array:
	var ny := PackedFloat32Array()
	var w := PackedFloat32Array()
	ny.resize(SIDE * SIDE)
	w.resize(SIDE * SIDE)
	for j in SIDE:
		for i in SIDE:
			var idx := j * SIDE + i
			var left: float = h[idx - (1 if i > 0 else 0)]
			var right: float = h[idx + (1 if i < SIDE - 1 else 0)]
			var back: float = h[idx - (SIDE if j > 0 else 0)]
			var front: float = h[idx + (SIDE if j < SIDE - 1 else 0)]
			var n := Vector3(left - right, 4.0, back - front).normalized()
			ny[idx] = n.y
			w[idx] = 0.0 if not mask.is_empty() and mask[idx] == 1 else _old_weight(n.y)
	return [ny, w]


# The berm rows' footprint mask on the 2 m grid, written out again from park_pit.json: along = (sin a, cos a),
# across = (cos a, -sin a), half length and half width plus BERM_PAD. Empty for every other map.
func _mask(id: String) -> PackedByteArray:
	var mask := PackedByteArray()
	if id != "park_pit":
		return mask
	mask.resize(SIDE * SIDE)
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/park_pit.json"))
	var rows := 0
	for r in data["park_rows"]:
		if not BERM_ROWS.has(String(r["id"])):
			continue
		rows += 1
		var at := Vector2(float(r["at"][0]), float(r["at"][1]))
		var a := deg_to_rad(float(r["yaw_deg"]))
		var along := Vector2(sin(a), cos(a))
		var across := Vector2(cos(a), -sin(a))
		var hl := float(r["size"][0]) * 0.5 + BERM_PAD
		var hw := float(r["size"][2]) * 0.5 + BERM_PAD
		for j in SIDE:
			for i in SIDE:
				var d := Vector2(-CELLS + 2 * i, -CELLS + 2 * j) - at
				if absf(d.dot(along)) <= hl and absf(d.dot(across)) <= hw:
					mask[j * SIDE + i] = 1
	t.eq("park_pit has six berm rows", rows, 6)
	return mask


# The height span of the 5 by 5 grid vertices around (i, j) (4 m each way), edges clamped; picks the tall-wall control.
func _relief(h: PackedFloat32Array, i: int, j: int) -> float:
	var lo := INF
	var hi := -INF
	for e in range(maxi(j - 2, 0), mini(j + 2, SIDE - 1) + 1):
		for d in range(maxi(i - 2, 0), mini(i + 2, SIDE - 1) + 1):
			lo = minf(lo, h[e * SIDE + d])
			hi = maxf(hi, h[e * SIDE + d])
	return hi - lo


# slot_mult.lerp(tint / D, w) with D = STRATA.lerp(FLOOR, clamp(2 n_y - 1)), per channel, clamped.
func _expect(mult: Color, n_y: float, w: float) -> Color:
	var d := STRATA_MEAN.lerp(FLOOR_MEAN, clampf(2.0 * n_y - 1.0, 0.0, 1.0))
	var tint := Palette.VERDIGRIS.lerp(Palette.CHARCOAL, 0.25)
	return Color(clampf(lerpf(mult.r, tint.r / d.r, w), 0.0, 1.0), clampf(lerpf(mult.g, tint.g / d.g, w), 0.0, 1.0),
			clampf(lerpf(mult.b, tint.b / d.b, w), 0.0, 1.0), 127.0 / 255.0)


# The feathered slot multiplier a vertex starts from is a byte-rounded mip average: within 3/255 of the
# slot's own multiplier where the cells around are all one slot, and the bite error adds no more.
const TOL := 3.0 / 255.0 + 0.0001


func _near(a: Color, b: Color, tol: float) -> bool:
	return absf(a.r - b.r) <= tol and absf(a.g - b.g) <= tol and absf(a.b - b.b) <= tol and absf(a.a - b.a) <= tol


# True when every cell within DEEP cells of (i, j) is the same slot and the window is inside the square,
# so the feathered colour there is that slot's multiplier.
func _uniform(surface: PackedByteArray, i: int, j: int) -> bool:
	if i < DEEP or j < DEEP or i >= CELLS - DEEP or j >= CELLS - DEEP:
		return false
	var slot := surface[j * CELLS + i]
	for dj in range(-DEEP, DEEP + 1):
		for di in range(-DEEP, DEEP + 1):
			if surface[(j + dj) * CELLS + i + di] != slot:
				return false
	return true


func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= BYTE and absf(a.g - b.g) <= BYTE and absf(a.b - b.b) <= BYTE and absf(a.a - b.a) <= BYTE


func _pixel(render: Node3D, x: int, z: int) -> Color:
	var loc := Vector2i(floori(x / float(REGION)), floori(z / float(REGION)))
	var region: Object = render.data.get_region(loc)
	return region.get_color_map().get_pixel(x - loc.x * REGION, z - loc.y * REGION)


# The four 1 m vertices of cell (i, j) against what the grid corners say they should be.
func _cell_bad(render: Node3D, grid: Array, i: int, j: int, mult: Color) -> int:
	var ny: PackedFloat32Array = grid[0]
	var w: PackedFloat32Array = grid[1]
	var a := j * SIDE + i
	var b := a + 1
	var c := a + SIDE
	var bad := 0
	# [dx, dz, first corner, second corner]: the corner itself, two edge midpoints, the b-c diagonal's midpoint.
	var plan := [[0, 0, a, a], [1, 0, a, b], [0, 1, a, c], [1, 1, b, c]]
	for p in plan:
		var wp: float = (w[p[2]] + w[p[3]]) * 0.5
		var yp: float = (ny[p[2]] + ny[p[3]]) * 0.5
		var got := _pixel(render, -CELLS + 2 * i + p[0], -CELLS + 2 * j + p[1])
		if not _near(got, _expect(mult, yp, wp), TOL):
			bad += 1
	return bad


func _check_park(id: String, ground: Node, render: Node3D) -> void:
	var surface := FileAccess.get_file_as_bytes("res://assets/park/" + id + "/surface.bin")
	var mask := _mask(id)
	var masked := 0
	for m in mask:
		masked += m
	t.eq("%s: the ground masked the vertices the test's own footprints do" % id, ground.bite_masked, masked)
	t.check("%s: the berm mask is %s" % [id, "on" if id == "park_pit" else "off"], (masked > 0) == (id == "park_pit"), str(masked))
	var grid := _grid(ground.heights, mask)
	var w: PackedFloat32Array = grid[1]
	var biting_cells: Array[int] = []
	var biting_slot_cells: Array[int] = []
	var flat_cells: Array[int] = []
	var biting_vertices := 0
	var per_slot := {}
	for v in w.size():
		if w[v] > 0.0:
			biting_vertices += 1
	for j in CELLS:
		for i in CELLS:
			var a := j * SIDE + i
			var k := j * CELLS + i
			if w[a] > 0.0 or w[a + 1] > 0.0 or w[a + SIDE] > 0.0 or w[a + SIDE + 1] > 0.0:
				biting_cells.append(k)
				if surface[k] >= 2 and surface[k] <= 4:
					biting_slot_cells.append(k)
					per_slot[surface[k]] = per_slot.get(surface[k], 0) + 1
			else:
				flat_cells.append(k)
	print("%s: %d biting grid vertices, %d biting cells, %d of them concrete/tailings/basalt %s, %d flat cells" % [id, biting_vertices, biting_cells.size(), biting_slot_cells.size(), per_slot, flat_cells.size()])
	t.check(id + " has biting vertices (steep walls)", biting_vertices > 0, str(biting_vertices))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261023
	var groups := {"biting": biting_cells, "biting slot": biting_slot_cells, "flat": flat_cells}
	for name in groups:
		var cells: Array[int] = groups[name]
		if cells.is_empty():
			print("%s: no %s cells to sample" % [id, name])
			continue
		# Draw seeded cells whose 11 by 11 neighbourhood is one slot (so the feathered slot multiplier is
		# the slot's own), until SAMPLES are checked or 6000 draws are spent.
		var bad := 0
		var n := 0
		var draws := 0
		while n < SAMPLES and draws < 6000:
			draws += 1
			var k := cells[rng.randi_range(0, cells.size() - 1)]
			if not _uniform(surface, k % CELLS, k / CELLS):
				continue
			n += 1
			bad += _cell_bad(render, grid, k % CELLS, k / CELLS, ParkTerrain.slot_tint(surface[k]))
		print("%s: %s cells with a one-slot neighbourhood checked: %d of %d draws" % [id, name, n, draws])
		t.eq("%s %s cells: %d sampled, vertices off the expected multiplier" % [id, name, n], bad, 0)
		# park_test's concrete is thin stamps with no one-slot neighbourhood among the biting ones.
		if id != "park_test" or name != "biting slot":
			t.check("%s %s cells: at least 100 checked" % [id, name], n >= 100, str(n))
	# A vertex that actually moved: the biting corner differs from the plain slot tint.
	var moved := 0
	for s in mini(SAMPLES, biting_cells.size()):
		var k := biting_cells[rng.randi_range(0, biting_cells.size() - 1)]
		var a := (k / CELLS) * SIDE + k % CELLS
		if w[a] > 0.1 and not _near(_pixel(render, -CELLS + 2 * (k % CELLS), -CELLS + 2 * (k / CELLS)), ParkTerrain.slot_tint(surface[k]), 3.0 / 255.0):
			moved += 1
	t.check(id + " strongly biting corners differ from the plain slot tint", moved > 0, str(moved))
	if id == "park_pit":
		_check_berms_and_walls(ground, render, surface, mask, true)


# The unbaked path: a ramp of slope 0.8 for 0 < x < 40 over a flat plain.
func _check_ramp(ground: Node, render: Node3D) -> void:
	t.check("ramp park is unbaked", not ground.baked)
	var slope := 0.8
	var steep_y := 1.0 / sqrt(1.0 + slope * slope)
	var edge_y := 4.0 / sqrt(1.6 * 1.6 + 16.0)
	t.check("the ramp is steeper than 30 degrees", steep_y < cos(deg_to_rad(30.0)), str(steep_y))
	var white := Color(1.0, 1.0, 1.0, 127.0 / 255.0)
	var w_steep := _old_weight(steep_y)
	# Interior grid vertex x = 10 (i = 405), z = 0: the whole slope, so a vertex of its own and its midpoints.
	var want := _expect(white, steep_y, w_steep)
	t.check("ramp: vertex (10, 0) is the exact multiplier %s" % want, _same(_pixel(render, 10, 0), want), str(_pixel(render, 10, 0)))
	t.check("ramp: vertex (11, 0), an edge midpoint, is the same", _same(_pixel(render, 11, 0), want), str(_pixel(render, 11, 0)))
	t.check("ramp: vertex (11, 1), the diagonal midpoint, is the same", _same(_pixel(render, 11, 1), want), str(_pixel(render, 11, 1)))
	t.check("ramp: the multiplier darkens (tint / D < 1 on red)", want.r < 1.0, str(want))
	# The foot at x = 0 does not bite itself (its flat side halves the slope); x = 2 does. Cell x 0..2 blends.
	t.check("ramp: the foot grid vertex (0, 0) has no bite", edge_y >= FACE and _same(_pixel(render, 0, 0), white), str(_pixel(render, 0, 0)))
	var foot := _expect(white, (edge_y + steep_y) * 0.5, (0.0 + w_steep) * 0.5)
	t.check("ramp: edge midpoint (1, 0) is the mean of corners x = 0 and x = 2", _same(_pixel(render, 1, 0), foot), "%s vs %s" % [_pixel(render, 1, 0), foot])
	var diag := _expect(white, (edge_y + steep_y) * 0.5, (0.0 + w_steep) * 0.5)
	t.check("ramp: diagonal midpoint (1, 1) is the mean of corners b and c", _same(_pixel(render, 1, 1), diag), "%s vs %s" % [_pixel(render, 1, 1), diag])
	t.check("ramp: flat vertex (-100, 0) keeps the white default", _same(_pixel(render, -100, 0), white), str(_pixel(render, -100, 0)))
	t.check("ramp: flat vertex (300, 200) keeps the white default", _same(_pixel(render, 300, 200), white), str(_pixel(render, 300, 200)))
	t.check("ramp: the top (x = 100) is flat", _same(_pixel(render, 100, 0), white), str(_pixel(render, 100, 0)))


# A saddle: in cells where b-c and a-d would give different colours, vertex (2i+1, 2j+1) wears the b-c one.
func _check_saddle(ground: Node, render: Node3D) -> void:
	var grid := _grid(ground.heights)
	var ny: PackedFloat32Array = grid[0]
	var w: PackedFloat32Array = grid[1]
	var white := Color(1.0, 1.0, 1.0, 127.0 / 255.0)
	var found := 0
	var bad_bc := 0
	var bad_cell := 0
	var equals_ad := 0
	for j in range(380, 440):
		for i in range(380, 440):
			var a := j * SIDE + i
			var b := a + 1
			var c := a + SIDE
			var d := c + 1
			var bc := _expect(white, (ny[b] + ny[c]) * 0.5, (w[b] + w[c]) * 0.5)
			var ad := _expect(white, (ny[a] + ny[d]) * 0.5, (w[a] + w[d]) * 0.5)
			if absf(bc.r - ad.r) + absf(bc.g - ad.g) + absf(bc.b - ad.b) < 6.0 / 255.0:
				continue
			found += 1
			var got := _pixel(render, -CELLS + 2 * i + 1, -CELLS + 2 * j + 1)
			if not _same(got, bc):
				bad_bc += 1
			if _same(got, ad):
				equals_ad += 1
			bad_cell += _cell_bad(render, grid, i, j, white)
	t.check("saddle: cells where the two diagonals disagree by 6/255 or more exist", found >= 20, str(found))
	t.eq("saddle: (2i+1, 2j+1) off the b-c mean in %d such cells" % found, bad_bc, 0)
	t.eq("saddle: (2i+1, 2j+1) that match the a-d mean instead", equals_ad, 0)
	t.eq("saddle: vertices of those cells off the expected multiplier", bad_cell, 0)


# A wall steep along x: grid x = -800 (i = 0) and x = 800 (i = 800) clamp one neighbour to themselves.
func _check_wall(ground: Node, render: Node3D) -> void:
	var white := Color(1.0, 1.0, 1.0, 127.0 / 255.0)
	# Edge: n = (h(x) - h(x + 2), 4, 0) = (-4, 4, 0); interior: (-8, 4, 0).
	var y_edge := 4.0 / sqrt(16.0 + 16.0)
	var y_in := 4.0 / sqrt(64.0 + 16.0)
	t.check("wall: the edge vertex bites (n.y %.3f < FACE)" % y_edge, y_edge < FACE)
	var w_edge := _old_weight(y_edge)
	var w_in := _old_weight(y_in)
	var edge_mult := _expect(white, y_edge, w_edge)
	var in_mult := _expect(white, y_in, w_in)
	t.check("wall: the clamped edge multiplier differs from the interior's (so a missed clamp fails)", not _same(edge_mult, in_mult), "%s vs %s" % [edge_mult, in_mult])
	# x = -800 is vertex (i = 0): weight and n.y of grid vertex 0 itself.
	var want0 := _expect(white, y_edge, w_edge)
	t.check("wall: vertex (-800, 0) (grid i = 0, left neighbour clamped) is the clamped-normal multiplier", _same(_pixel(render, -800, 0), want0), "%s vs %s" % [_pixel(render, -800, 0), want0])
	var mid0 := _expect(white, (y_edge + y_in) * 0.5, (w_edge + w_in) * 0.5)
	t.check("wall: vertex (-799, 0) is the mean of grid i = 0 and i = 1", _same(_pixel(render, -799, 0), mid0), "%s vs %s" % [_pixel(render, -799, 0), mid0])
	# x = +800 is grid i = 800 (right neighbour clamped); the 1 m vertex x = 799 is the mean of i = 799 and 800.
	var mid800 := _expect(white, (y_edge + y_in) * 0.5, (w_edge + w_in) * 0.5)
	t.check("wall: vertex (799, 0) is the mean of grid i = 799 and the clamped i = 800", _same(_pixel(render, 799, 0), mid800), "%s vs %s" % [_pixel(render, 799, 0), mid800])
	var grid := _grid(ground.heights)
	t.eq("wall: edge cell i = 0 matches the recomputed grid", _cell_bad(render, grid, 0, 400, white), 0)
	t.eq("wall: edge cell i = 799 matches the recomputed grid", _cell_bad(render, grid, 799, 400, white), 0)


# The berm samples: every second vertex inside a berm footprint with a pylon-biting slope (old weight above 0) and a
# one-slot neighbourhood, so a missing mask would tint it.
func _berm_samples(h: PackedFloat32Array, surface: PackedByteArray, mask: PackedByteArray) -> Array:
	var out := []
	var count := 0
	for j in range(1, SIDE - 1):
		for i in range(1, SIDE - 1):
			if mask[j * SIDE + i] == 0 or _old_weight(_ny(h, i, j)) <= 0.0 or not _uniform(surface, i, j):
				continue
			count += 1
			if count % 2 == 0:
				out.append([i, j])
	return out


func _ny(h: PackedFloat32Array, i: int, j: int) -> float:
	var idx := j * SIDE + i
	var dx: float = h[idx - 1] - h[idx + 1]
	var dz: float = h[idx - SIDE] - h[idx + SIDE]
	return 4.0 / sqrt(dx * dx + 16.0 + dz * dz)


# Tall walls outside the berm footprints: pylon-biting slopes (old weight 0.5 or more) with 10 m or more of relief
# in their 5 by 5 window.
func _wall_samples(h: PackedFloat32Array, surface: PackedByteArray, mask: PackedByteArray) -> Array:
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261022
	var tries := 0
	while out.size() < 200 and tries < 400000:
		tries += 1
		var i := rng.randi_range(8, SIDE - 9)
		var j := rng.randi_range(8, SIDE - 9)
		if mask[j * SIDE + i] == 1 or _old_weight(_ny(h, i, j)) < 0.5 or _relief(h, i, j) < 10.0 or not _uniform(surface, i, j):
			continue
		out.append([i, j])
	return out


# masked true: the berm samples wear their slot's colour (their old weight is above 0, so this is not vacuous) and
# the wall samples outside the footprints wear the old-rule tint. masked false (the planted control, berm_rows = {}):
# the same berm samples are tinted again, so the berm check would fail.
func _check_berms_and_walls(ground: Node, render: Node3D, surface: PackedByteArray, mask: PackedByteArray, masked: bool) -> void:
	var h: PackedFloat32Array = ground.heights
	var label := "mask on" if masked else "mask off (planted control)"
	var berms := _berm_samples(h, surface, mask)
	var walls := _wall_samples(h, surface, mask)
	var berm_clean := 0
	var berm_tinted := 0
	for s in berms:
		var mult := ParkTerrain.slot_tint(surface[s[1] * CELLS + s[0]])
		if _near(_pixel(render, -CELLS + 2 * s[0], -CELLS + 2 * s[1]), mult, TOL):
			berm_clean += 1
		else:
			berm_tinted += 1
	var wall_bad := 0
	for s in walls:
		var mult := ParkTerrain.slot_tint(surface[s[1] * CELLS + s[0]])
		var ny := _ny(h, s[0], s[1])
		if not _near(_pixel(render, -CELLS + 2 * s[0], -CELLS + 2 * s[1]), _expect(mult, ny, _old_weight(ny)), TOL):
			wall_bad += 1
	print("park_pit berms (%s): %d samples, %d untinted, %d tinted; %d wall samples, %d off the old-rule tint" % [label, berms.size(), berm_clean, berm_tinted, walls.size(), wall_bad])
	t.check("park_pit berm samples: at least 150 (%s)" % label, berms.size() >= 150, str(berms.size()))
	t.check("park_pit wall samples: at least 100 (%s)" % label, walls.size() >= 100, str(walls.size()))
	if masked:
		t.eq("park_pit berm samples tinted with the mask on (the tint under-reports berm flanks by design)", berm_tinted, 0)
	else:
		t.eq("park_pit berm samples left untinted with the mask off", berm_clean, 0)
	t.eq("park_pit tall walls wear the old-rule tint (%s): samples off it" % label, wall_bad, 0)


# The planted control (an empty mask re-tints the berms) and the parks that name no rows (no vertices masked).
func _check_planted_and_others(holder: Node3D) -> void:
	var render: Node3D = ParkTerrain.make_render(holder, "Render_pit_off")
	var ground := ParkTerrain.new()
	holder.add_child(ground)
	ground.berm_rows = {}
	ground.start("park_pit", null, false, render)
	await process_frame
	t.eq("an empty berm mask masks no vertex", ground.bite_masked, 0)
	_check_berms_and_walls(ground, render, FileAccess.get_file_as_bytes("res://assets/park/park_pit/surface.bin"), _mask("park_pit"), false)
	ground.queue_free()
	render.queue_free()
	await process_frame
	for id in OTHER_PARKS:
		render = ParkTerrain.make_render(holder, "Render_" + id)
		ground = ParkTerrain.new()
		holder.add_child(ground)
		ground.start(id, null, false, render)
		await process_frame
		var weights := 0
		var h: PackedFloat32Array = ground.heights
		for j in range(1, SIDE - 1, 2):
			for i in range(1, SIDE - 1, 2):
				weights += 1 if _old_weight(_ny(h, i, j)) > 0.0 else 0
		print("%s: berm mask off, %d vertices masked, %d of the sampled quarter bite" % [id, ground.bite_masked, weights])
		t.eq("%s names no berm rows: no vertex masked, so its tint is the old rule's" % id, ground.bite_masked, 0)
		t.check("%s has biting vertices the old rule tints" % id, weights > 0, str(weights))
		ground.queue_free()
		render.queue_free()
		await process_frame
