extends SceneTree

# Gate for the park ground's surface (step 2 of the park ground): every vertex of a park's four
# Terrain3D regions has the control map's auto bit (hole vertices keep the hole bit too), and the
# colour map tints the cells of surface.bin's concrete, tailings and basalt slots by target / the
# floor texture's mean (alpha at Terrain3D's default 127/255) while the other slots, the net and the
# apron stay white.
# The parks are built through the real path (make_render, start, finish); the targets are pinned to
# their sources. Headless Terrain3D draws nothing, so this reads the maps, not pixels.

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

var t := T.new("park_ground_surface_test")
var _targets := {}
var _floor_mean := Color.WHITE
var _hole_cells_seen := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_pin_floor_mean()
	_pin_targets()
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
		_check_park(id, render)
		ground.queue_free()
		render.queue_free()
		await process_frame
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


# The three targets, read from their sources and not from park_terrain.gd's constants.
func _pin_targets() -> void:
	var gpw := FileAccess.get_file_as_string("res://assets/materials/gpw_workshop.gdshader")
	var m := RegEx.create_from_string("uniform vec4 base_color : source_color = vec4\\(([0-9.]+), ([0-9.]+), ([0-9.]+),").search(gpw)
	t.check("gpw_workshop.gdshader declares base_color", m != null)
	var concrete := Color.WHITE
	if m != null:
		concrete = Color(float(m.get_string(1)), float(m.get_string(2)), float(m.get_string(3)))
		_near_color("concrete target = gpw_workshop base_color = VERDIGRIS", concrete, Palette.VERDIGRIS)
	var cinder := FileAccess.get_file_as_string("res://assets/materials/dig_stone/cinder.gdshader")
	var dark := RegEx.create_from_string("uniform vec3 grit_dark : source_color = vec3\\(([0-9.]+), ([0-9.]+), ([0-9.]+)\\)").search(cinder)
	var light := RegEx.create_from_string("uniform vec3 grit_light : source_color = vec3\\(([0-9.]+), ([0-9.]+), ([0-9.]+)\\)").search(cinder)
	t.check("cinder.gdshader declares grit_dark and grit_light", dark != null and light != null)
	var basalt := Color.WHITE
	if dark != null and light != null:
		var d := Color(float(dark.get_string(1)), float(dark.get_string(2)), float(dark.get_string(3)))
		var l := Color(float(light.get_string(1)), float(light.get_string(2)), float(light.get_string(3)))
		basalt = d.lerp(l, 0.5)
	var dig := FileAccess.get_file_as_string("res://src/world/map_dig.gd")
	t.check("map_dig.gd's pit floor tint is CHARCOAL.lerp(RUST, 0.4)", dig.contains("tint = Palette.CHARCOAL.lerp(Palette.RUST, 0.4)"))
	var tailings := Palette.CHARCOAL.lerp(Palette.RUST, 0.4)
	_targets = {2: concrete, 3: tailings, 4: basalt}
	for slot in _targets:
		var c: Color = _targets[slot]
		t.check("slot %d tint needs no clamp (target < floor mean)" % slot, c.r < _floor_mean.r and c.g < _floor_mean.g and c.b < _floor_mean.b, str(c))
	_near_color("park_terrain basalt target = mean of grit_dark and grit_light", _park_target(4), basalt)
	_near_color("park_terrain tailings target = CHARCOAL.lerp(RUST, 0.4)", _park_target(3), tailings)
	_near_color("park_terrain concrete target = pinned base_color", _park_target(2), concrete)


# park_terrain.gd's target for a slot, or magenta where it declares none (so the check fails, not parses).
func _park_target(slot: int) -> Color:
	var script: GDScript = ParkTerrain
	var has := script.get_script_method_list().any(func(m): return m.name == "slot_target")
	return script.call("slot_target", slot) if has else Color.MAGENTA


func _near_color(label: String, got: Color, want: Color) -> void:
	t.check(label, absf(got.r - want.r) <= BYTE and absf(got.g - want.g) <= BYTE and absf(got.b - want.b) <= BYTE, "got %s, want %s" % [got, want])


# What the colour map should hold for a surface slot: target / the floor mean per channel, white where untinted.
func _tint(slot: int) -> Color:
	if not _targets.has(slot):
		return Color(1.0, 1.0, 1.0, 0.5)
	var c: Color = _targets[slot]
	return Color(minf(c.r / _floor_mean.r, 1.0), minf(c.g / _floor_mean.g, 1.0), minf(c.b / _floor_mean.b, 1.0), 0.5)


func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= BYTE and absf(a.g - b.g) <= BYTE and absf(a.b - b.b) <= BYTE and absf(a.a - b.a) <= BYTE


# The surface slot under a 1 m vertex, or -1 outside the play square's cells (the apron, and the +800 edge).
func _slot_at(surface: PackedByteArray, x: int, z: int) -> int:
	if x < -CELLS or x >= CELLS or z < -CELLS or z >= CELLS:
		return -1
	return surface[((z + CELLS) >> 1) * CELLS + ((x + CELLS) >> 1)]


func _check_park(id: String, render: Node3D) -> void:
	var dir := "res://assets/park/" + id
	var surface := FileAccess.get_file_as_bytes(dir + "/surface.bin")
	var holes := FileAccess.get_file_as_bytes(dir + "/holes.bin")
	t.eq(id + " surface.bin size", surface.size(), CELLS * CELLS)
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
		# The play square's edges and the +800 edge, where a cell has no 1 m vertex of its own.
		for edge in [-CELLS, -CELLS + 1, CELLS - 2, CELLS - 1, CELLS, CELLS + 1]:
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
			var want := _tint(slot)
			seen[slot] = true
			if not _same(color.get_pixel(p.x, p.y), want):
				bad_color += 1
				if first.is_empty():
					first = "colour %s at (%d, %d) slot %d, want %s" % [color.get_pixel(p.x, p.y), x, z, slot, want]
		t.check("%s region %s checked 2000+ vertices" % [id, loc], checked >= 2000, str(checked))
	t.eq(id + " vertices without the auto bit", bad_auto, 0)
	t.eq(id + " vertices with the wrong colour " + first, bad_color, 0)
	_check_cells(id, render, surface, rng)
	_check_border(id, render, surface)
	_check_holes(id, render, holes)


func _vertex(render: Node3D, x: int, z: int) -> Array:
	var loc := Vector2i(floori(x / float(REGION)), floori(z / float(REGION)))
	var region: Object = render.data.get_region(loc)
	var px := x - loc.x * REGION
	var pz := z - loc.y * REGION
	return [region.get_control_map().get_data().decode_u32((pz * REGION + px) * 4), region.get_color_map().get_pixel(px, pz)]


# Seeded cells of every slot present: all four vertices carry that slot's tint.
func _check_cells(id: String, render: Node3D, surface: PackedByteArray, rng: RandomNumberGenerator) -> void:
	var by_slot := {}
	for k in surface.size():
		if not by_slot.has(surface[k]):
			by_slot[surface[k]] = []
		by_slot[surface[k]].append(k)
	for slot in by_slot:
		var cells: Array = by_slot[slot]
		var bad := 0
		for n in mini(CELL_SAMPLES, cells.size()):
			var k: int = cells[rng.randi_range(0, cells.size() - 1)]
			for dz in 2:
				for dx in 2:
					var v := _vertex(render, -CELLS + 2 * (k % CELLS) + dx, -CELLS + 2 * (k / CELLS) + dz)
					if not _same(v[1], _tint(slot)):
						bad += 1
		t.eq("%s slot %d cells (%d in the bake) wear their tint on all four vertices" % [id, slot, cells.size()], bad, 0)


# A planted control per axis: a tinted cell beside a cell of another slot (+x, then +z), so a
# one-vertex shift along either axis fails.
func _check_border(id: String, render: Node3D, surface: PackedByteArray) -> void:
	for axis in ["x", "z"]:
		var step := 1 if axis == "x" else CELLS
		var tinted := -1
		for k in surface.size():
			var room := k % CELLS < CELLS - 1 if axis == "x" else k / CELLS < CELLS - 1
			if _targets.has(surface[k]) and room and surface[k + step] != surface[k]:
				tinted = k
				break
		if not t.check("%s has a tinted cell beside another slot along %s" % [id, axis], tinted >= 0):
			continue
		var x := -CELLS + 2 * (tinted % CELLS)
		var z := -CELLS + 2 * (tinted / CELLS)
		var inside: Color = _vertex(render, x + 1, z)[1] if axis == "x" else _vertex(render, x, z + 1)[1]
		var across: Color = _vertex(render, x + 2, z)[1] if axis == "x" else _vertex(render, x, z + 2)[1]
		t.check("%s %s border: the tinted cell's vertex is tinted" % [id, axis], _same(inside, _tint(surface[tinted])) and not _same(inside, _tint(0)), str(inside))
		t.check("%s %s border: the neighbour across the slot border is not" % [id, axis], _same(across, _tint(surface[tinted + step])) and not _same(across, inside), str(across))


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
