extends SceneTree

# Gate for the park ground's surface (step 2 of the park ground): every vertex of a park's four
# Terrain3D regions has the control map's auto bit (hole vertices keep the hole bit too), and the
# colour map carries each concrete, tailings and basalt cell's multiplier (a ratio between two patches
# of one reference board, pinned here from the raw sRGB numbers) feathered over 8 m: a cell 5 or more
# cells from another slot and from the play edge wears its slot's multiplier, no 1 m step at a real
# slot border or the square's edge exceeds the full difference over 8 plus 2/255, and the apron
# beyond the margin stays white. Alpha stays at Terrain3D's default 127/255 throughout.
# The parks are built through the real path (make_render, start, finish). Headless Terrain3D draws
# nothing, so this reads the maps, not pixels.

const T := preload("res://tests/support/t.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")
const Palette := preload("res://src/core/palette.gd")
const MaterialSlots := preload("res://src/presentation/material_slots.gd")

const PARKS := ["park_pit", "park_sinkhole", "park_test"]
# Terrain3D's control word: bit 0 auto, bit 2 hole (the addon's shader DECODE_AUTO and hole test).
const AUTO_BIT := 1
const HOLE_BIT := 4
const CELLS := 800
const REGION := 1024
const SAMPLES := 2500
const CELL_SAMPLES := 150
const BYTE := 1.0 / 255.0 + 0.0001
# A deep cell's colour is a byte-rounded mip average of equal cells, within 2/255 of its multiplier.
const TOL := 2.0 / 255.0 + 0.0001
# Cells from any other slot or the edge that count as "deep": the feather's 4 cells plus the bilinear support.
const DEEP := 5
const MARGIN := 8

var t := T.new("park_ground_surface_test")
var _mults := {}
var _floor_mean := Color.WHITE
var _hole_cells_seen := 0
# Per cell of the park under test: 1 where a corner of the 2 m grid has a pylon-bite weight above 0.
# Those vertices move toward the pylon tint (park_ground_bite_test.gd), so they count as borders here.
var _bite := PackedByteArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_pin_floor_mean()
	_pin_mults()
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
		_check_park(id, render, ground.heights)
		ground.queue_free()
		render.queue_free()
		await process_frame
	_check_planted()
	t.check("some park checked has hole cells", _hole_cells_seen > 0, str(_hole_cells_seen))
	quit(t.verdict())


# GROUND_FLOOR_MEAN is the true mean of the floor texture's base level, recomputed here over every pixel.
func _pin_floor_mean() -> void:
	var row: Dictionary = MaterialSlots.row("ground")
	# A copy: headless, get_image() hands back the texture's own image, and the decompress and
	# convert below would change the format Terrain3D later reads from it.
	var img: Image = Palette.look_texture(row.textures.floor_map).get_image().duplicate()
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
	var declared = (ParkTerrain as GDScript).get_script_constant_map().get("GROUND_FLOOR_MEAN", Color.MAGENTA)
	t.check("GROUND_FLOOR_MEAN = floor texture mean over %d pixels, within 2/255" % n, absf(declared.r - mean.r) <= 2.0 / 255.0 and absf(declared.g - mean.g) <= 2.0 / 255.0 and absf(declared.b - mean.b) <= 2.0 / 255.0, "got %s, want %s" % [declared, mean])
	_floor_mean = mean


# The three multipliers, from the reference boards' raw sRGB patch means (park_terrain.gd's comments
# cite the crops): material / lit ground, with the floor texture's mean as the ground's own chromaticity
# for the tailings (red kept at 1), and clamped to what an RGBA8 colour map can hold.
func _pin_mults() -> void:
	var fm := _floor_mean
	# Tailings: the board floor 245,172,116 against the floor texture's g/r and b/r.
	var tailings := Color(1.0, (172.0 / 245.0) / (fm.g / fm.r), (116.0 / 245.0) / (fm.b / fm.r), 0.5)
	# Basalt: the cap 101,93,93 over the lit limestone 153,126,111.
	var basalt := Color(101.0 / 153.0, 93.0 / 126.0, 93.0 / 111.0, 0.5)
	# Concrete: the ramp 239,194,148 over the lit sand 243,167,102.5, each channel at most 1.
	var concrete := Color(minf(239.0 / 243.0, 1.0), minf(194.0 / 167.0, 1.0), minf(148.0 / 102.5, 1.0), 0.5)
	_mults = {2: concrete, 3: tailings, 4: basalt}
	for slot in _mults:
		var want: Color = _mults[slot]
		var got := ParkTerrain.slot_tint(slot)
		t.check("slot %d multiplier = board ratio %s" % [slot, want], absf(got.r - want.r) <= 0.002 and absf(got.g - want.g) <= 0.002 and absf(got.b - want.b) <= 0.002, "got %s" % got)
		t.near("slot %d multiplier alpha is Terrain3D's default 127/255" % slot, got.a, 127.0 / 255.0, 0.0001)
		var target := _park_target(slot)
		_near_color("slot %d target = multiplier * floor mean" % slot, target, Color(got.r * fm.r, got.g * fm.g, got.b * fm.b))
	t.check("the tailings multiplier keeps red at 1 and darkens green and blue", ParkTerrain.slot_tint(3).r == 1.0 and ParkTerrain.slot_tint(3).g < 1.0 and ParkTerrain.slot_tint(3).b < 1.0)
	t.check("the tailings target is much lighter than the old charcoal tint", _park_target(3).g > 0.45, str(_park_target(3)))


# park_terrain.gd's target for a slot, or magenta where it declares none (so the check fails, not parses).
func _park_target(slot: int) -> Color:
	var script: GDScript = ParkTerrain
	var has := script.get_script_method_list().any(func(m): return m.name == "slot_target")
	return script.call("slot_target", slot) if has else Color.MAGENTA


func _near_color(label: String, got: Color, want: Color) -> void:
	t.check(label, absf(got.r - want.r) <= BYTE and absf(got.g - want.g) <= BYTE and absf(got.b - want.b) <= BYTE, "got %s, want %s" % [got, want])


# What the colour map should hold for a surface slot: its multiplier, white where untinted.
func _tint(slot: int) -> Color:
	if not _mults.has(slot):
		return Color(1.0, 1.0, 1.0, 0.5)
	return _mults[slot]


func _near(a: Color, b: Color, tol: float) -> bool:
	return absf(a.r - b.r) <= tol and absf(a.g - b.g) <= tol and absf(a.b - b.b) <= tol and absf(a.a - b.a) <= tol


func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= BYTE and absf(a.g - b.g) <= BYTE and absf(a.b - b.b) <= BYTE and absf(a.a - b.a) <= BYTE


# The surface slot under a 1 m vertex, or -1 outside the play square's cells (the apron, and the +800 edge).
func _slot_at(surface: PackedByteArray, x: int, z: int) -> int:
	if x < -CELLS or x >= CELLS or z < -CELLS or z >= CELLS:
		return -1
	return surface[((z + CELLS) >> 1) * CELLS + ((x + CELLS) >> 1)]


# Marks every cell with a corner whose normal is steeper than the pylon's face (terrain.gd's rule).
func _mark_bite(h: PackedFloat32Array) -> void:
	var side := CELLS + 1
	var steep := PackedByteArray()
	steep.resize(side * side)
	for j in side:
		for i in side:
			var idx := j * side + i
			var left: float = h[idx - (1 if i > 0 else 0)]
			var right: float = h[idx + (1 if i < side - 1 else 0)]
			var back: float = h[idx - (side if j > 0 else 0)]
			var front: float = h[idx + (side if j < side - 1 else 0)]
			if Vector3(left - right, 4.0, back - front).normalized().y < 0.866:
				steep[idx] = 1
	_bite.resize(CELLS * CELLS)
	for j in CELLS:
		for i in CELLS:
			var a := j * side + i
			_bite[j * CELLS + i] = 1 if steep[a] + steep[a + 1] + steep[a + side] + steep[a + side + 1] > 0 else 0


func _check_park(id: String, render: Node3D, heights: PackedFloat32Array) -> void:
	_mark_bite(heights)
	var dir := "res://assets/park/" + id
	var surface := FileAccess.get_file_as_bytes(dir + "/surface.bin")
	var holes := FileAccess.get_file_as_bytes(dir + "/holes.bin")
	t.eq(id + " surface.bin size", surface.size(), CELLS * CELLS)
	var deep := _deep_cells(surface)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261022
	var bad_auto := 0
	var bad_color := 0
	var first := ""
	var seen := {}
	for loc in ParkTerrain.REGIONS:
		var region: Object = render.data.get_region(loc)
		if not t.check("%s region %s exists" % [id, loc], region != null):
			continue
		var control: Image = region.get_control_map()
		var color: Image = region.get_color_map()
		t.eq("%s region %s colour map format RGBA8" % [id, loc], color.get_format(), Image.FORMAT_RGBA8)
		var x0 := loc.x * REGION
		var z0 := loc.y * REGION
		var points: Array[Vector2i] = [Vector2i(0, 0), Vector2i(REGION - 1, 0), Vector2i(0, REGION - 1), Vector2i(REGION - 1, REGION - 1)]
		# The play square's edges and the +800 edge.
		for edge in [-CELLS - 9, -CELLS - 8, -CELLS, -CELLS + 1, CELLS - 2, CELLS - 1, CELLS, CELLS + 1, CELLS + 8, CELLS + 9]:
			for along in [-CELLS, -1, 0, 1, CELLS - 1, CELLS]:
				points.append(Vector2i(edge - x0, along - z0))
				points.append(Vector2i(along - x0, edge - z0))
		for n in SAMPLES:
			points.append(Vector2i(rng.randi_range(0, REGION - 1), rng.randi_range(0, REGION - 1)))
		var checked := 0
		for p in points:
			if p.x < 0 or p.x >= REGION or p.y < 0 or p.y >= REGION:
				continue
			var x := x0 + p.x
			var z := z0 + p.y
			var word := control.get_data().decode_u32((p.y * REGION + p.x) * 4)
			checked += 1
			if word & AUTO_BIT == 0:
				bad_auto += 1
				if first.is_empty():
					first = "no auto bit at (%d, %d)" % [x, z]
			var slot := _slot_at(surface, x, z)
			var want := Color(1.0, 1.0, 1.0, 0.5)
			if slot >= 0:
				# Cells near another slot or the edge are feathered: the bound check below covers them.
				if deep[((z + CELLS) >> 1) * CELLS + ((x + CELLS) >> 1)] == 0:
					continue
				want = _tint(slot)
			elif x >= -CELLS - MARGIN - 1 and x <= CELLS + MARGIN and z >= -CELLS - MARGIN - 1 and z <= CELLS + MARGIN:
				continue
			seen[slot] = int(seen.get(slot, 0)) + 1
			if not _near(color.get_pixel(p.x, p.y), want, TOL):
				bad_color += 1
				if first.is_empty():
					first = "colour %s at (%d, %d) slot %d, want %s" % [color.get_pixel(p.x, p.y), x, z, slot, want]
		t.check("%s region %s checked 2000+ vertices" % [id, loc], checked >= 2000, str(checked))
	var colour_checked := 0
	for slot in seen:
		colour_checked += int(seen[slot])
	print("%s: random vertices colour-checked per slot (feathered ones skipped, -1 is the far apron): %s" % [id, seen])
	t.check(id + " colour-checked 2000+ deep or far-apron vertices", colour_checked >= 2000, str(colour_checked))
	t.eq(id + " vertices without the auto bit", bad_auto, 0)
	t.eq(id + " vertices with the wrong colour " + first, bad_color, 0)
	_check_cells(id, render, surface, deep, rng)
	_check_boundaries(id, render, surface, rng)
	_check_holes(id, render, holes)


func _vertex(render: Node3D, x: int, z: int) -> Array:
	var loc := Vector2i(floori(x / float(REGION)), floori(z / float(REGION)))
	var region: Object = render.data.get_region(loc)
	var px := x - loc.x * REGION
	var pz := z - loc.y * REGION
	return [region.get_control_map().get_data().decode_u32((pz * REGION + px) * 4), region.get_color_map().get_pixel(px, pz)]


# 1 for each cell DEEP or more cells (Chebyshev) from any other slot and from the play edge. A cell is
# a boundary when a 4-neighbour differs; a window with no boundary cell holds one slot.
func _deep_cells(surface: PackedByteArray) -> PackedByteArray:
	var edge := PackedInt32Array()
	edge.resize(CELLS * CELLS)
	for j in CELLS:
		for i in CELLS:
			var k := j * CELLS + i
			var slot := surface[k]
			if _bite[k] == 1:
				edge[k] = 1
			if (i < CELLS - 1 and surface[k + 1] != slot) or (j < CELLS - 1 and surface[k + CELLS] != slot):
				edge[k] = 1
				if i < CELLS - 1 and surface[k + 1] != slot:
					edge[k + 1] = 1
				if j < CELLS - 1 and surface[k + CELLS] != slot:
					edge[k + CELLS] = 1
	# Window sums with a horizontal then a vertical running total.
	var wide := 2 * DEEP + 1
	var rows := PackedInt32Array()
	rows.resize(CELLS * CELLS)
	for j in CELLS:
		var run := 0
		for i in range(0, mini(DEEP, CELLS)):
			run += edge[j * CELLS + i]
		for i in CELLS:
			if i + DEEP < CELLS:
				run += edge[j * CELLS + i + DEEP]
			if i - DEEP - 1 >= 0:
				run -= edge[j * CELLS + i - DEEP - 1]
			rows[j * CELLS + i] = run
	var deep := PackedByteArray()
	deep.resize(CELLS * CELLS)
	for i in CELLS:
		var run := 0
		for j in range(0, mini(DEEP, CELLS)):
			run += rows[j * CELLS + i]
		for j in CELLS:
			if j + DEEP < CELLS:
				run += rows[(j + DEEP) * CELLS + i]
			if j - DEEP - 1 >= 0:
				run -= rows[(j - DEEP - 1) * CELLS + i]
			if run == 0 and i >= DEEP and i < CELLS - DEEP and j >= DEEP and j < CELLS - DEEP:
				deep[j * CELLS + i] = 1
	return deep


# Seeded deep cells of every slot present: all four vertices carry that slot's multiplier.
func _check_cells(id: String, render: Node3D, surface: PackedByteArray, deep: PackedByteArray, rng: RandomNumberGenerator) -> void:
	var by_slot := {}
	for k in surface.size():
		if not by_slot.has(surface[k]):
			by_slot[surface[k]] = []
		by_slot[surface[k]].append(k)
	var counts := {}
	for slot in by_slot:
		# Draw seeded deep cells until CELL_SAMPLES are checked, or the slot has none left to draw.
		var pool: Array = by_slot[slot].filter(func(k): return deep[k] == 1)
		var bad := 0
		var n := mini(CELL_SAMPLES, pool.size())
		for s in n:
			var k: int = pool[rng.randi_range(0, pool.size() - 1)]
			for dz in 2:
				for dx in 2:
					var v := _vertex(render, -CELLS + 2 * (k % CELLS) + dx, -CELLS + 2 * (k / CELLS) + dz)
					if not _near(v[1], _tint(slot), TOL):
						bad += 1
		counts[slot] = n
		t.eq("%s slot %d cells (%d in the bake, %d deep) wear their multiplier on all four vertices" % [id, slot, by_slot[slot].size(), pool.size()], bad, 0)
		if n >= 100:
			t.check("%s slot %d: at least 100 deep cells checked" % [id, slot], true, "%d checked of %d deep" % [n, pool.size()])
			continue
		# Thin stamps (the pit's concrete) have too few deep cells: check 100 of the slot's cells against the
		# hull of all multipliers present (a feathered colour lies between them) and say so.
		var near_bad := 0
		# Biting cells move toward the pylon tint, outside the hull: the bite test owns them.
		var calm: Array = by_slot[slot].filter(func(k): return _bite[k] == 0)
		var near_n := mini(CELL_SAMPLES, calm.size())
		var lo := Color(1, 1, 1)
		var hi := Color(0, 0, 0)
		for other in by_slot:
			var m := _tint(other)
			lo = Color(minf(lo.r, m.r), minf(lo.g, m.g), minf(lo.b, m.b))
			hi = Color(maxf(hi.r, m.r), maxf(hi.g, m.g), maxf(hi.b, m.b))
		for s in near_n:
			var k: int = calm[rng.randi_range(0, calm.size() - 1)]
			var c: Color = _vertex(render, -CELLS + 2 * (k % CELLS), -CELLS + 2 * (k / CELLS))[1]
			if c.r < lo.r - TOL or c.r > hi.r + TOL or c.g < lo.g - TOL or c.g > hi.g + TOL or c.b < lo.b - TOL or c.b > hi.b + TOL:
				near_bad += 1
		t.eq("%s slot %d has only %d deep cells; %d of its cells stay inside the multiplier hull (cells off it)" % [id, slot, pool.size(), near_n], near_bad, 0)
		t.check("%s slot %d: at least 100 cells checked against the hull" % [id, slot], near_n >= 100, str(near_n))
	print("%s: deep cells checked per slot: %s" % [id, counts])


# The largest per-channel difference between the multipliers of any two slots in a set.
func _full_diff(slots: Array) -> Array:
	var diff := [0.0, 0.0, 0.0]
	for a in slots:
		for b in slots:
			var ca := _tint(a)
			var cb := _tint(b)
			diff[0] = maxf(diff[0], absf(ca.r - cb.r))
			diff[1] = maxf(diff[1], absf(ca.g - cb.g))
			diff[2] = maxf(diff[2], absf(ca.b - cb.b))
	return diff


# The largest 1 m step per channel (horizontal and vertical neighbours) over a window of vertices.
func _max_step(read: Callable, x0: int, z0: int, w: int, h: int) -> Array:
	var step := [0.0, 0.0, 0.0]
	for z in range(z0, z0 + h):
		for x in range(x0, x0 + w):
			var c: Color = read.call(x, z)
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var o: Color = read.call(x + d.x, z + d.y)
				step[0] = maxf(step[0], absf(c.r - o.r))
				step[1] = maxf(step[1], absf(c.g - o.g))
				step[2] = maxf(step[2], absf(c.b - o.b))
	return step


# Real slot borders: no step between 1 m neighbours in a window around them exceeds the full multiplier
# difference over 8 plus 2/255, per channel (the feather spreads a border over 8 m).
func _check_boundaries(id: String, render: Node3D, surface: PackedByteArray, rng: RandomNumberGenerator) -> void:
	var pick: int = {"park_pit": 3, "park_sinkhole": 4, "park_test": 2}[id]
	var found: Array[int] = []
	for k in surface.size():
		if surface[k] == pick and k % CELLS > 30 and k % CELLS < CELLS - 30 and k / CELLS > 30 and k / CELLS < CELLS - 30 and surface[k + 1] != pick:
			found.append(k)
	if not t.check("%s has a slot %d cell with another slot to its +x side" % [id, pick], not found.is_empty()):
		return
	var read := func(x: int, z: int) -> Color: return _vertex(render, x, z)[1]
	var worst := [0.0, 0.0, 0.0]
	var worst_diff := [0.0, 0.0, 0.0]
	var done := 0
	var tries := 0
	while done < 3 and tries < 4000:
		tries += 1
		var k := found[rng.randi_range(0, found.size() - 1)]
		var cx := -CELLS + 2 * (k % CELLS)
		var cz := -CELLS + 2 * (k / CELLS)
		var present := {}
		var biting := false
		for dj in range(-14, 15):
			for di in range(-14, 15):
				present[surface[k + dj * CELLS + di]] = true
				biting = biting or _bite[k + dj * CELLS + di] == 1
		if biting:
			continue
		done += 1
		var diff := _full_diff(present.keys())
		var step := _max_step(read, cx - 24, cz - 24, 48, 48)
		for c in 3:
			t.check("%s border near vertex (%d, %d) channel %d: max step %.4f <= diff %.4f / 8 + 2/255" % [id, cx, cz, c, step[c], diff[c]], step[c] <= diff[c] / 8.0 + 2.0 / 255.0 + 0.0001)
			worst[c] = maxf(worst[c], step[c])
			worst_diff[c] = maxf(worst_diff[c], diff[c])
		if maxf(diff[0], maxf(diff[1], diff[2])) >= 0.05:
			t.check("%s border near (%d, %d) is a real border (some channel steps 1/255 or more)" % [id, cx, cz], maxf(step[0], maxf(step[1], step[2])) >= 1.0 / 255.0)
	t.eq("%s: real borders without a pylon bite in the window, of 3 wanted (%d draws)" % [id, tries], done, 3)
	print("%s: max 1 m step over 3 real borders (r, g, b): %s of full difference %s" % [id, worst, worst_diff])


# feather() on constructed per-cell images: one isolated tinted cell among white ones, and tint up to the edge.
func _check_planted() -> void:
	var white := Color(1.0, 1.0, 1.0, 0.5)
	var tailings := _tint(3)
	var cells := Image.create(CELLS, CELLS, false, Image.FORMAT_RGBA8)
	cells.fill(Color8(255, 255, 255, 127))
	var script: GDScript = ParkTerrain
	if not t.check("park_terrain.gd declares feather()", script.get_script_method_list().any(func(m): return m.name == "feather")):
		return
	cells.set_pixel(400, 400, Color(tailings.r, tailings.g, tailings.b, 127.0 / 255.0))
	var img: Image = script.call("feather", cells)
	var margin: int = script.get_script_constant_map().get("FEATHER_MARGIN", 8)
	t.eq("feather() of 800 cells is 1600 plus a margin each side", img.get_width(), CELLS * 2 + 2 * margin)
	var read := func(x: int, z: int) -> Color: return img.get_pixel(x + CELLS + margin, z + CELLS + margin)
	var diff := [absf(white.r - tailings.r), absf(white.g - tailings.g), absf(white.b - tailings.b)]
	# The cell (400, 400) covers vertices 0 and 1 on both axes.
	var step := _max_step(read, -20, -20, 40, 40)
	for c in 3:
		t.check("planted isolated cell channel %d: max step %.4f <= diff %.4f / 8 + 2/255" % [c, step[c], diff[c]], step[c] <= diff[c] / 8.0 + 2.0 / 255.0 + 0.0001)
		if diff[c] >= 0.01:
			t.check("planted isolated cell channel %d: no step reaches the full difference %.4f" % [c, diff[c]], step[c] < diff[c])
	var middle: Color = read.call(0, 0)
	t.check("planted isolated cell: its centre is tinted a little (an 8 m texel averages 1 cell in 16)", middle.g < white.g - 0.5 / 255.0 and middle.g > tailings.g + 0.05, str(middle))
	# A 4 by 4 cell block that fills one 8 m texel: the steepest fade, near the bound but under the full difference.
	cells.fill(Color8(255, 255, 255, 127))
	for j in range(400, 404):
		for i in range(400, 404):
			cells.set_pixel(i, j, Color(tailings.r, tailings.g, tailings.b, 127.0 / 255.0))
	var block: Image = script.call("feather", cells)
	var block_read := func(x: int, z: int) -> Color: return block.get_pixel(x + CELLS + margin, z + CELLS + margin)
	var block_step := _max_step(block_read, -20, -20, 48, 48)
	for c in [1, 2]:
		t.check("planted 4 by 4 block channel %d: step %.4f within [diff / 16, diff / 8 + 2/255]" % [c, block_step[c]], block_step[c] <= diff[c] / 8.0 + 2.0 / 255.0 + 0.0001 and block_step[c] >= diff[c] / 16.0)
		t.check("planted 4 by 4 block channel %d: no step reaches the full difference" % c, block_step[c] < diff[c])
	cells.fill(Color(tailings.r, tailings.g, tailings.b, 127.0 / 255.0))
	t.check("planted isolated cell: alpha stays 127", img.get_pixel(CELLS + margin, CELLS + margin).a8 == 127 and img.get_pixel(0, 0).a8 == 127)
	t.check("planted isolated cell: pixels 20 m away are white", _near(read.call(20, 0), white, TOL) and _near(read.call(0, -20), white, TOL))
	# Tint up to the square's edge fades to white over the margin, with bounded steps and a white last pixel.
	var all: Image = script.call("feather", cells)
	var edge_read := func(x: int, z: int) -> Color: return all.get_pixel(x + CELLS + margin, z + CELLS + margin)
	for c in 3:
		var along := 0.0
		for x in range(-CELLS - margin, -CELLS + 12):
			var a: Color = edge_read.call(x, 0)
			var b: Color = edge_read.call(x + 1, 0)
			var dc := [absf(a.r - b.r), absf(a.g - b.g), absf(a.b - b.b)]
			along = maxf(along, dc[c])
		t.check("tint up to the edge, channel %d: max step %.4f <= diff %.4f / 8 + 2/255" % [c, along, diff[c]], along <= diff[c] / 8.0 + 2.0 / 255.0 + 0.0001)
	t.check("tint up to the edge: 8 m outside it the colour is white", _near(edge_read.call(-CELLS - margin, 0), white, TOL), str(edge_read.call(-CELLS - margin, 0)))
	t.check("tint up to the edge: the edge vertex is partway", edge_read.call(-CELLS, 0).g < white.g - 0.01, str(edge_read.call(-CELLS, 0)))
	t.check("tint up to the edge: 8 m inside it is the full tint", _near(edge_read.call(-CELLS + 8, 0), tailings, TOL), str(edge_read.call(-CELLS + 8, 0)))
	t.check("tint up to the far edge: 8 m outside it is white", _near(edge_read.call(CELLS + margin - 1, 0), white, TOL), str(edge_read.call(CELLS + margin - 1, 0)))


func _check_holes(id: String, render: Node3D, holes: PackedByteArray) -> void:
	var seen := 0
	var bad := 0
	for k in holes.size():
		if holes[k] != 1 or k % 7 != 0:
			continue
		seen += 1
		for dz in 2:
			for dx in 2:
				var word: int = _vertex(render, -CELLS + 2 * (k % CELLS) + dx, -CELLS + 2 * (k / CELLS) + dz)[0]
				if word & HOLE_BIT == 0:
					bad += 1
	_hole_cells_seen += seen
	t.eq(id + " hole vertices missing the hole bit", bad, 0)
