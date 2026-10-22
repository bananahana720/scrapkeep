extends Node3D

# A park stage's ground (design-v3/PARK.md section 3, K-UNITS KB4): the bake under
# assets/park/<map_id>/ drawn as Terrain3D render regions and collided by our own trimesh tiles.
#
#   render    four Terrain3D regions of 1024 vertices at 1 m, (-1,-1) to (0,0), cover -1024..1023.
#             Inside the play square a vertex is the 2 m grid's two-triangle surface (the 1 m points
#             fall on grid vertices, edge midpoints and the b-c diagonal's midpoint, so the view lies
#             on the collider); outside it is apron.bin. Hole cells mark their four 1 m vertices.
#             Every vertex has the control map's auto bit, so Terrain3D's auto-shader draws sand floor
#             flat and strata steep, as the non-park ground does. surface.bin's concrete, tailings and
#             basalt cells (slots 2 to 4) tint the colour map, which multiplies the albedo, so a floor
#             cell reads near that slot's colour; the other slots stay white (net never tints it).
#             Each multiplier is a ratio between two patches of one reference board (MULT_*), and the
#             colour map is feathered over 8 m (feather()), so a slot border or the square's edge
#             fades instead of stepping.
#             Terrain3D collision stays 0 (DISABLED): it never makes a second height source.
#   collider  100 tiles of 160 m (80 by 80 cells of the 2 m grid), each a ConcavePolygonShape3D with
#             the two triangles and winding terrain.gd uses for the old maps; a hole cell has none.
#   heights   the 801 by 801 grid terrain.gd's height() interpolates; under is the floor of each
#             hole cell (under.bin), which height() reads there.
#
# A park file with no bake yet (the KD0 stand-in) stands on its map's sample() plain over the
# whole square, with no holes, so a park table still plays end to end.
#
# start(threaded) loads the bake and builds every region image and tile face list on
# WorkerThreadPool; the main thread only adds the finished pieces, one region or up to five
# tiles a frame inside an 8 ms budget, then emits built. finish() completes any of it at once.
#
# The Terrain3D node is not this node's child: a new Terrain3D spends about 135 ms of main
# thread on its first frame (measured headless, any settings), which no launch can afford. So
# terrain.gd makes two at setup with make_render() (the active stage's and the next one's) and
# lends one to each park stage; attaching replaces the node's four regions in place.

signal built

const MaterialSlots := preload("res://src/presentation/material_slots.gd")
const Palette := preload("res://src/core/palette.gd")
const GROUND_FLOOR_ID := 0
const GROUND_STRATA_ID := 1
# Metres per tile of the floor texture: sandstone.gdshader's floor_metres default (:9), which the
# `ground` slot leaves alone (palette.gd sets only strata_metres, from triplanar_scale).
const GROUND_FLOOR_METRES := 5.0
const HALF := 800.0
const STEP := 2.0
const CELLS := 800
const SIDE := 801
const REGION_SIZE := 1024
const VERTEX_SPACING := 1.0
const REGIONS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]
const APRON_HALF := 1024
const APRON_SIDE := 2048
const TILE_CELLS := 80
const TILE_M := TILE_CELLS * STEP
const TILES_PER_SIDE := CELLS / TILE_CELLS
const TILE_COUNT := TILES_PER_SIDE * TILES_PER_SIDE
const REGION_COUNT := 4
const PIECES := REGION_COUNT + TILE_COUNT
const TILES_PER_FRAME := 5
const ATTACH_BUDGET_USEC := 8000
# Terrain3D's control map: bit 2 is the hole bit (Terrain3DUtil.enc_hole).
const HOLE_BIT := 4
# Bit 0 is the auto bit: the auto-shader picks the base or overlay texture by slope.
const AUTO_BIT := 1
# surface.bin slots (park_stamps.gd SURFACE_SLOTS) that tint the colour map. Slots 0, 1 and 5 (net) stay white.
const SLOT_CONCRETE := 2
const SLOT_TAILINGS := 3
const SLOT_BASALT := 4
# Each tinted slot's colour-map multiplier is one ratio between two patches of one reference board:
# the material over the lit ground in the same board (sRGB box means, ImageMagick
# `convert <board> -crop WxH+X+Y -resize 1x1!`, each crop checked by eye). The colour map multiplies
# the albedo and RGBA8 caps a multiplier at 1, so it can only darken or move hue.
# Tailings: docs/art/reference/dig/dig-landmark-headframe-noon.jpg, the worked pit floor at noon.
# Crops 120x40+1150+700, 120x40+880+600 and 100x30+1150+620 read 242,169,113, 245,172,117 and
# 245,172,116 (median 245,172,116). The multiplier keeps red at 1 and gives green and blue the board
# floor's chromaticity (g/r and b/r) over the floor texture's own, so only the hue moves toward oxide:
# a target of about (0.733, 0.514, 0.347), L* 59.5 against the floor's 65.1.
const MULT_TAILINGS := Color(1.0, 0.861, 0.843, float(COLOR_ALPHA_BYTE) / 255.0)
# Basalt: docs/art/reference/dig/dig-landmark-sinkhole-afternoon.jpg. The basalt cap, crops
# 120x40+960+215 and 100x40+1180+210, reads 104,95,95 and 98,90,91 (mean 101,93,93); the lit pale
# limestone in the same board, crop 80x60+1120+330, reads 153,126,111. Cap / limestone, L* 47.8.
const MULT_BASALT := Color(0.660, 0.738, 0.838, float(COLOR_ALPHA_BYTE) / 255.0)
# Concrete: docs/art/reference/spillway/spillway-landmarks-flume-carry.jpg. The pale concrete ramp, crop
# 60x14+1080+410, reads 239,194,148; the lit sand ground, crops 100x30+880+600 and 100x30+600+640,
# read 244,167,102 and 242,167,103. The raw ratio is (0.984, 1.162, 1.444), but concrete is paler than
# the ground and a multiplier cannot exceed 1, so green and blue clamp to 1 and concrete draws close to
# the floor. A concrete texture is the real fix.
const MULT_CONCRETE := Color(0.984, 1.0, 1.0, float(COLOR_ALPHA_BYTE) / 255.0)
# The floor texture's mean albedo (packed-sand-floor.webp, every pixel of the base level): the
# floor is what flat ground draws, so a multiplier times this is the colour a cell's mean lands on.
# Steep ground draws strata, whose mean is slightly darker (0.731, 0.535, 0.366).
const GROUND_FLOOR_MEAN := Color(0.7327, 0.5977, 0.4117)
# The colour map is feathered over 8 m: the per-cell multipliers are padded with FEATHER_PAD white
# cells (so a tint at the play square's edge fades toward the apron), box-filtered to 8 m texels (mip
# level FEATHER_LEVEL) and bilinearly stretched back to 1 m vertices.
const FEATHER_PAD := 4
const FEATHER_LEVEL := 2
# One-metre pixels of padding on each side of feather()'s image: vertex m is at pixel m + this.
const FEATHER_MARGIN := 2 * FEATHER_PAD
# Terrain3D's default colour map is white with alpha 127/255, which leaves roughness unchanged.
const COLOR_ALPHA_BYTE := 127
const COLLISION_DISABLED := 0
const MESH_LODS := 7
const MESH_SIZE := 48
# Terrain3DRegion map types for update_maps: height, control, colour.
const MAP_TYPES := [0, 1, 2]

enum Phase { IDLE, LOADING, BUILDING, ATTACHING, READY }

var map_id := ""
var baked := false
var heights := PackedFloat32Array()
var holes := PackedByteArray()
var under := PackedFloat32Array()
var terrain3d: Node3D
var tiles: Array[StaticBody3D] = []
# Pieces (regions and tiles) built on a thread other than the main one.
var worker_pieces := 0
var phase := Phase.IDLE
# The longest main-thread _process step of a threaded build, and where it was; and the longest
# whole frame while it built, or since meter() (the swap test reads these: PARK.md section 9's
# 33 ms cap).
var slowest_usec := 0
var slowest_step := ""
var frame_usec_max := 0
var _last_frame_usec := 0
var _meter_frames := 0

var _map: RefCounted
var _apron := PackedFloat32Array()
var _apron_rows := PackedInt32Array()
var _hole_cells := PackedInt32Array()
# The 2 m cells' slot multipliers feathered onto 1 m vertices (feather(): the play square plus an 8 m margin, 1616 square RGBA8),
# or null when the park has no surface.bin.
var _tints: Image
var _regions: Array = []
var _faces: Array = []
var _task := -1
var _group := -1
var _lock := Mutex.new()
var _next_region := 0
var _next_map := 0
var _next_tile := 0
var _tiles_root: Node3D


# The colour a tinted surface slot's cell lands on: its multiplier times the floor texture's mean.
static func slot_target(slot: int) -> Color:
	var m := slot_tint(slot)
	return Color(m.r * GROUND_FLOOR_MEAN.r, m.g * GROUND_FLOOR_MEAN.g, m.b * GROUND_FLOOR_MEAN.b)


# The colour-map multiplier of a surface slot (alpha at the default, so roughness is unchanged);
# white for slots that do not tint.
static func slot_tint(slot: int) -> Color:
	match slot:
		SLOT_CONCRETE:
			return MULT_CONCRETE
		SLOT_TAILINGS:
			return MULT_TAILINGS
		SLOT_BASALT:
			return MULT_BASALT
	return Color(1.0, 1.0, 1.0, float(COLOR_ALPHA_BYTE) / 255.0)


# The 800 by 800 per-cell multiplier image as a one-metre-vertex image, feathered over 8 m: pad with
# white, box-filter to 8 m texels, bilinear back up. The result is 1616 square: it keeps the padding, so
# a tint at the square's edge fades to white over the apron's first 8 m instead of stepping. Padded
# pixel p covers metres 2 (p - FEATHER_PAD) from the square's edge, a texel covers 8 m, and bilinear
# resize maps a destination pixel's area onto the same metres (checked: a block of cells fades
# symmetrically about its centre), so vertex m (the 1 m pixel from -800 + m) is pixel m + FEATHER_MARGIN.
static func feather(cells: Image) -> Image:
	var side := CELLS + 2 * FEATHER_PAD
	var padded := Image.create(side, side, false, Image.FORMAT_RGBA8)
	padded.fill(Color(1.0, 1.0, 1.0, float(COLOR_ALPHA_BYTE) / 255.0))
	padded.blit_rect(cells, Rect2i(0, 0, CELLS, CELLS), Vector2i(FEATHER_PAD, FEATHER_PAD))
	padded.generate_mipmaps()
	var texels := side >> FEATHER_LEVEL
	var from := padded.get_mipmap_offset(FEATHER_LEVEL)
	var level := Image.create_from_data(texels, texels, false, Image.FORMAT_RGBA8, padded.get_data().slice(from, from + texels * texels * 4))
	# An 8 m texel is 8 one-metre pixels.
	level.resize(texels * 8, texels * 8, Image.INTERPOLATE_BILINEAR)
	return level


static func bake_dir(id: String) -> String:
	return "res://assets/park/%s" % id


static func has_bake(id: String) -> bool:
	return FileAccess.file_exists(bake_dir(id) + "/bake.json")


func is_ready() -> bool:
	return phase == Phase.READY


# A Terrain3D render node for park stages, added under parent (which must be in the tree):
# 1024-vertex regions at 1 m, the clipmap of PARK.md section 3, collision off. Its mode set
# before it enters the tree is dropped, so it goes to 0 right after, before any region exists.
static func make_render(parent: Node, label: String) -> Node3D:
	var node: Node3D = ClassDB.instantiate("Terrain3D")
	node.name = label
	node.mesh_lods = MESH_LODS
	node.mesh_size = MESH_SIZE
	node.visible = false
	parent.add_child(node)
	node.collision.mode = COLLISION_DISABLED
	node.region_size = REGION_SIZE
	node.vertex_spacing = VERTEX_SPACING
	node.assets = ground_assets()
	var material: Object = node.material
	# The regions' control maps carry the auto bit everywhere (_build_region), so the auto-shader
	# picks the texture: the overlay (flat) is the floor, the base (steep) the strata. auto_slope 1.0
	# puts the half-way blend at normal.y 0.75, near the middle (0.755) of sandstone.gdshader's
	# strata ramp smoothstep(0.58, 0.93, normal.y). Height reduction is off.
	material.auto_shader = true
	material.set_shader_param("auto_base_texture", GROUND_STRATA_ID)
	material.set_shader_param("auto_overlay_texture", GROUND_FLOOR_ID)
	material.set_shader_param("auto_slope", 1.0)
	material.set_shader_param("auto_height_reduction", 0.0)
	return node


# A Terrain3DAssets for one park render node, from the `ground` slot so the park and the non-park
# ground draw the same two textures at the same near-layer tile sizes (the non-park shader's far
# layers, macro tint and ruts are not matched): texture 0 is the slot's floor_map every
# GROUND_FLOOR_METRES, texture 1 its strata_map every triplanar_scale metres. Terrain3D samples a
# texture at world xz * uv_scale * the control map's scale, which is 0.5 at control 0 (DECODE_SCALE
# in the addon's shader; lightweight.gdshader:313 writes the same * 0.5), so uv_scale is 2 / metres.
# Each node gets its own list (an asset list keeps one terrain back-pointer); the textures are shared.
static func ground_assets() -> Object:
	var row: Dictionary = MaterialSlots.row("ground")
	var assets: Object = ClassDB.instantiate("Terrain3DAssets")
	var ids: Array = [row.textures.floor_map, row.textures.strata_map]
	var metres: Array = [GROUND_FLOOR_METRES, float(row.triplanar_scale)]
	for i in ids.size():
		var asset: Object = ClassDB.instantiate("Terrain3DTextureAsset")
		asset.name = ids[i]
		asset.albedo_texture = Palette.look_texture(ids[i])
		asset.uv_scale = 2.0 / float(metres[i])
		assets.set_texture(i, asset)
	return assets


# render: the Terrain3D node this stage draws into (make_render), or null to collide only.
func start(id: String, map: RefCounted, threaded: bool, render: Node3D = null) -> void:
	map_id = id
	_map = map
	terrain3d = render
	baked = has_bake(id)
	name = "Ground"
	_regions.resize(REGION_COUNT)
	_faces.resize(TILE_COUNT)
	if threaded:
		phase = Phase.LOADING
		_task = WorkerThreadPool.add_task(_load, false, "park_terrain load %s" % id)
		set_process(true)
	else:
		_load()
		phase = Phase.BUILDING
		_group = WorkerThreadPool.add_group_task(_build_piece, PIECES, -1, true, "park_terrain build %s" % id)
		finish()


# Completes whatever is left on the calling (main) thread: the swap's fallback when the next
# stage is read before its build is done, and the setup build.
func finish() -> void:
	if phase == Phase.READY:
		return
	if phase == Phase.LOADING:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_group = WorkerThreadPool.add_group_task(_build_piece, PIECES, -1, true, "park_terrain build %s" % map_id)
		phase = Phase.BUILDING
	if phase == Phase.BUILDING:
		WorkerThreadPool.wait_for_group_task_completion(_group)
		_group = -1
		phase = Phase.ATTACHING
	while phase == Phase.ATTACHING:
		_attach_step(-1)


func _ready() -> void:
	set_process(phase == Phase.LOADING or phase == Phase.BUILDING or phase == Phase.ATTACHING)


func _exit_tree() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	if _group != -1:
		WorkerThreadPool.wait_for_group_task_completion(_group)
		_group = -1


func _process(_delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	if _last_frame_usec > 0:
		frame_usec_max = maxi(frame_usec_max, t0 - _last_frame_usec)
	_last_frame_usec = t0
	var was := phase
	_pump()
	var spent := Time.get_ticks_usec() - t0
	if spent > slowest_usec:
		slowest_usec = spent
		slowest_step = "%s region %d map %d tile %d" % [Phase.keys()[was], _next_region, _next_map, _next_tile]
	if phase == Phase.READY:
		_meter_frames -= 1
		if _meter_frames <= 0:
			_last_frame_usec = 0
			set_process(false)


# Times the next frames whole (the wall time between this node's _process calls): terrain.gd
# calls it on the swap, so frame_usec_max then holds the longest frame after the landing.
func meter(frames: int) -> void:
	frame_usec_max = 0
	_last_frame_usec = 0
	_meter_frames = frames
	set_process(true)


func _pump() -> void:
	match phase:
		Phase.LOADING:
			if WorkerThreadPool.is_task_completed(_task):
				WorkerThreadPool.wait_for_task_completion(_task)
				_task = -1
				_group = WorkerThreadPool.add_group_task(_build_piece, PIECES, -1, true, "park_terrain build %s" % map_id)
				phase = Phase.BUILDING
		Phase.BUILDING:
			if WorkerThreadPool.is_group_task_completed(_group):
				WorkerThreadPool.wait_for_group_task_completion(_group)
				_group = -1
				phase = Phase.ATTACHING
		Phase.ATTACHING:
			_attach_step(Time.get_ticks_usec() + ATTACH_BUDGET_USEC)


# The floor of the hole cell under (x, z), or NAN where the cell is ground.
static func hole_floor(hole_bytes: PackedByteArray, floors: PackedFloat32Array, x: float, z: float) -> float:
	if hole_bytes.is_empty():
		return NAN
	var i := clampi(int(floorf((x + HALF) / STEP)), 0, CELLS - 1)
	var j := clampi(int(floorf((z + HALF) / STEP)), 0, CELLS - 1)
	var k := j * CELLS + i
	return floors[k] if hole_bytes[k] == 1 else NAN


# --- Worker side: pure data, no scene tree, no servers. ---

func _load() -> void:
	var dir := bake_dir(map_id)
	if baked:
		heights = _read_zstd(dir + "/ground.bin", SIDE * SIDE * 4).to_float32_array()
		_apron = _read_zstd(dir + "/apron.bin", (APRON_SIDE * APRON_SIDE - (SIDE * 2 - 1) * (SIDE * 2 - 1)) * 4).to_float32_array()
		holes = FileAccess.get_file_as_bytes(dir + "/holes.bin")
		var floors := FileAccess.get_file_as_bytes(dir + "/under.bin").to_float32_array()
		under.resize(CELLS * CELLS)
		var n := 0
		for k in holes.size():
			if holes[k] == 1:
				under[k] = floors[n]
				_hole_cells.append(k)
				n += 1
		_load_tints(dir + "/surface.bin")
		_apron_rows.resize(APRON_SIDE)
		var at := 0
		for j in APRON_SIDE:
			_apron_rows[j] = at
			at += APRON_SIDE if absi(j - APRON_HALF) > int(HALF) else APRON_SIDE - (SIDE * 2 - 1)
	else:
		heights.resize(SIDE * SIDE)
		for j in SIDE:
			var z := -HALF + j * STEP
			for i in SIDE:
				heights[j * SIDE + i] = float(_map.sample(-HALF + i * STEP, z)[0])


func _load_tints(path: String) -> void:
	var surface := FileAccess.get_file_as_bytes(path)
	if surface.size() != CELLS * CELLS:
		return
	var lookup := PackedByteArray()
	for slot in 6:
		var c := slot_tint(slot)
		lookup.append_array(PackedByteArray([roundi(c.r * 255.0), roundi(c.g * 255.0), roundi(c.b * 255.0), COLOR_ALPHA_BYTE]))
	var pixels := PackedByteArray()
	pixels.resize(CELLS * CELLS * 4)
	pixels.fill(255)
	for k in surface.size():
		var slot := surface[k]
		pixels[k * 4 + 3] = COLOR_ALPHA_BYTE
		if slot >= SLOT_CONCRETE and slot <= SLOT_BASALT:
			var at := k * 4
			var from := slot * 4
			pixels[at] = lookup[from]
			pixels[at + 1] = lookup[from + 1]
			pixels[at + 2] = lookup[from + 2]
	var image := Image.create_from_data(CELLS, CELLS, false, Image.FORMAT_RGBA8, pixels)
	_tints = feather(image)


static func _read_zstd(path: String, size: int) -> PackedByteArray:
	var file := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		push_error("park_terrain: cannot read %s" % path)
		return PackedByteArray()
	var bytes := file.get_buffer(size)
	file.close()
	return bytes


func _build_piece(p: int) -> void:
	if p < REGION_COUNT:
		_regions[p] = _build_region(REGIONS[p])
	else:
		_faces[p - REGION_COUNT] = _build_tile(p - REGION_COUNT)
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		_lock.lock()
		worker_pieces += 1
		_lock.unlock()


func _build_region(location: Vector2i) -> Object:
	var x0 := location.x * REGION_SIZE
	var z0 := location.y * REGION_SIZE
	var h := heights
	var data := PackedFloat32Array()
	data.resize(REGION_SIZE * REGION_SIZE)
	var inner := int(HALF)
	for row in REGION_SIZE:
		var z := z0 + row
		var base := row * REGION_SIZE
		var z_in := absi(z) <= inner
		var gz := z + inner
		var j := gz >> 1
		var odd_z := (gz & 1) == 1
		for col in REGION_SIZE:
			var x := x0 + col
			var v := 0.0
			if z_in and absi(x) <= inner:
				var gx := x + inner
				var i := gx >> 1
				var a := j * SIDE + i
				if (gx & 1) == 0:
					v = h[a] if not odd_z else (h[a] + h[a + SIDE]) * 0.5
				else:
					v = (h[a] + h[a + 1]) * 0.5 if not odd_z else (h[a + 1] + h[a + SIDE]) * 0.5
			else:
				v = _outside(x, z)
			data[base + col] = v
	var control := PackedInt32Array()
	control.resize(REGION_SIZE * REGION_SIZE)
	control.fill(AUTO_BIT)
	for k in _hole_cells:
		var px := -inner + 2 * (k % CELLS) - x0
		var pz := -inner + 2 * (k / CELLS) - z0
		for dz in 2:
			for dx in 2:
				var cx := px + dx
				var cz := pz + dz
				if cx >= 0 and cx < REGION_SIZE and cz >= 0 and cz < REGION_SIZE:
					control[cz * REGION_SIZE + cx] = AUTO_BIT | HOLE_BIT
	var region: Object = ClassDB.instantiate("Terrain3DRegion")
	region.set_region_size(REGION_SIZE)
	region.set_vertex_spacing(VERTEX_SPACING)
	region.set_location(location)
	region.set_height_map(Image.create_from_data(REGION_SIZE, REGION_SIZE, false, Image.FORMAT_RF, data.to_byte_array()))
	region.set_control_map(Image.create_from_data(REGION_SIZE, REGION_SIZE, false, Image.FORMAT_RF, control.to_byte_array()))
	if _tints != null:
		# Cell (i, j)'s vertices are at -800 + 2i + (0, 1); the feathered image starts FEATHER_MARGIN metres before -800.
		var color := Image.create(REGION_SIZE, REGION_SIZE, false, Image.FORMAT_RGBA8)
		color.fill(Color(1.0, 1.0, 1.0, float(COLOR_ALPHA_BYTE) / 255.0))
		color.blit_rect(_tints, Rect2i(Vector2i.ZERO, _tints.get_size()), Vector2i(-inner - FEATHER_MARGIN - x0, -inner - FEATHER_MARGIN - z0))
		region.set_color_map(color)
	region.sanitize_maps()
	region.calc_height_range()
	return region


# A 1 m point outside the play square: the apron ring from the bake, or the grid's edge when
# the park has no bake yet.
func _outside(x: int, z: int) -> float:
	if _apron.is_empty():
		var cx := clampf(float(x), -HALF, HALF)
		var cz := clampf(float(z), -HALF, HALF)
		var i := clampi(int((cx + HALF) / STEP), 0, CELLS)
		var j := clampi(int((cz + HALF) / STEP), 0, CELLS)
		return heights[j * SIDE + i]
	var ja := z + APRON_HALF
	var ia := x + APRON_HALF
	var start := _apron_rows[ja]
	if absi(z) > int(HALF):
		return _apron[start + ia]
	var left := APRON_HALF - int(HALF)
	return _apron[start + ia] if ia < left else _apron[start + left + ia - (APRON_HALF + int(HALF) + 1)]


func _build_tile(t: int) -> PackedVector3Array:
	var i0 := (t % TILES_PER_SIDE) * TILE_CELLS
	var j0 := (t / TILES_PER_SIDE) * TILE_CELLS
	var h := heights
	var faces := PackedVector3Array()
	faces.resize(TILE_CELLS * TILE_CELLS * 6)
	var w := 0
	var has_holes := not holes.is_empty()
	for j in range(j0, j0 + TILE_CELLS):
		var z := -HALF + j * STEP
		for i in range(i0, i0 + TILE_CELLS):
			if has_holes and holes[j * CELLS + i] == 1:
				continue
			var x := -HALF + i * STEP
			var a := j * SIDE + i
			var va := Vector3(x, h[a], z)
			var vb := Vector3(x + STEP, h[a + 1], z)
			var vc := Vector3(x, h[a + SIDE], z + STEP)
			var vd := Vector3(x + STEP, h[a + SIDE + 1], z + STEP)
			# Clockwise from above, as terrain.gd's old-map collider: a trimesh collides on front faces.
			faces[w] = va
			faces[w + 1] = vb
			faces[w + 2] = vc
			faces[w + 3] = vb
			faces[w + 4] = vd
			faces[w + 5] = vc
			w += 6
	faces.resize(w)
	return faces


# --- Main thread: add the finished pieces, inside a time budget (deadline -1 means no budget). ---

func _attach_step(deadline: int) -> void:
	if _tiles_root == null:
		_tiles_root = Node3D.new()
		_tiles_root.name = "Tiles"
		add_child(_tiles_root)
		# Without a render node (a parent off the scene tree) the collider still stands.
		if terrain3d == null or terrain3d.data == null:
			push_warning("park_terrain: %s has no Terrain3D render node; collider only" % map_id)
			terrain3d = null
			_next_region = REGION_COUNT
			_next_map = MAP_TYPES.size()
		if deadline >= 0:
			return
	if _next_region < _regions.size():
		var region: Object = _regions[_next_region]
		if terrain3d.data.has_region(region.get_location()):
			terrain3d.data.remove_regionl(region.get_location(), false)
		terrain3d.data.add_region(region, false)
		_regions[_next_region] = null
		_next_region += 1
		if deadline >= 0:
			return
	if _next_region < _regions.size():
		return
	if _next_map < MAP_TYPES.size():
		terrain3d.data.update_maps(MAP_TYPES[_next_map], true, false)
		_next_map += 1
		if deadline >= 0:
			return
	if _next_map < MAP_TYPES.size():
		return
	var added := 0
	while _next_tile < TILE_COUNT:
		if deadline >= 0 and (added >= TILES_PER_FRAME or Time.get_ticks_usec() > deadline):
			return
		_add_tile(_next_tile)
		_faces[_next_tile] = null
		_next_tile += 1
		added += 1
	phase = Phase.READY
	set_process(false)
	built.emit()


func _add_tile(t: int) -> void:
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(_faces[t])
	var holder := CollisionShape3D.new()
	holder.shape = shape
	var body := StaticBody3D.new()
	body.name = "Tile%d_%d" % [t % TILES_PER_SIDE, t / TILES_PER_SIDE]
	body.add_child(holder)
	_tiles_root.add_child(body)
	tiles.append(body)
