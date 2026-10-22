extends Node3D

# A park stage's ground (design-v3/PARK.md section 3, K-UNITS KB4): the bake under
# assets/park/<map_id>/ drawn as Terrain3D render regions and collided by our own trimesh tiles.
#
#   render    four Terrain3D regions of 1024 vertices at 1 m, (-1,-1) to (0,0), cover -1024..1023.
#             Inside the play square a vertex is the 2 m grid's two-triangle surface (the 1 m points
#             fall on grid vertices, edge midpoints and the b-c diagonal's midpoint, so the view lies
#             on the collider); outside it is apron.bin. Hole cells mark their four 1 m vertices.
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
const ThreadGuard := preload("res://src/core/thread_guard.gd")
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
var _regions: Array = []
var _faces: Array = []
var _task := -1
var _group := -1
var _lock := Mutex.new()
var _next_region := 0
var _next_map := 0
var _next_tile := 0
var _tiles_root: Node3D


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
	# Step 1 draws texture 0 (sand floor) everywhere: the regions' control maps are untouched, so
	# no cell has the auto bit and Terrain3D takes texture 0 at blend 0. The auto-shader is set
	# up for step 2, which sets that bit: the overlay (flat) is the floor, the base (steep) the
	# strata, auto_slope 1.0 putting the half-way blend at normal.y 0.75, near the middle (0.755) of
	# sandstone.gdshader's strata ramp smoothstep(0.58, 0.93, normal.y). Height reduction is off.
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


func _build_region(location: Vector2i) -> Array:
	var x0 := location.x * REGION_SIZE
	var z0 := location.y * REGION_SIZE
	var h := heights
	var data := PackedFloat32Array()
	data.resize(REGION_SIZE * REGION_SIZE)
	var inner := int(HALF)
	var low := INF
	var high := -INF
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
			if v < low:
				low = v
			if v > high:
				high = v
	var control := PackedInt32Array()
	control.resize(REGION_SIZE * REGION_SIZE)
	for k in _hole_cells:
		var px := -inner + 2 * (k % CELLS) - x0
		var pz := -inner + 2 * (k / CELLS) - z0
		for dz in 2:
			for dx in 2:
				var cx := px + dx
				var cz := pz + dz
				if cx >= 0 and cx < REGION_SIZE and cz >= 0 and cz < REGION_SIZE:
					control[cz * REGION_SIZE + cx] = HOLE_BIT
	return [location, Image.create_from_data(REGION_SIZE, REGION_SIZE, false, Image.FORMAT_RF, data.to_byte_array()),
		Image.create_from_data(REGION_SIZE, REGION_SIZE, false, Image.FORMAT_RF, control.to_byte_array()), color_map(),
		Vector2(low, high)]


# The color map sanitize_maps makes for a region without one (white, roughness 0.5, mipmapped). Made here, on the worker,
# it is plain Image data; left to sanitize_maps on the main thread it cost 37 to 88 ms a region on the cloud.
static func color_map() -> Image:
	var image := Image.create_empty(REGION_SIZE, REGION_SIZE, true, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 0.5))
	return image


# A region's Terrain3DRegion from the worker's [location, height map, control map, color map, height range], made on
# the main thread: it is the addon's object (GDExtension, its source is not in this repo), so no worker makes or sets one.
# set_height_map always works out the height range itself (14 ms a region on the cloud, a preset range or not); set_data
# takes the maps and the worker's range as given, the same region state the setters leave, in 0.02 ms. With the worker's
# color map _attach_step's sanitize has nothing left to make. Maps without a range (or a color map) take the setters.
static func _make_region(maps: Array) -> Object:
	if not ThreadGuard.main_only("park_terrain region"):
		return null
	var region: Object = ClassDB.instantiate("Terrain3DRegion")
	region.set_region_size(REGION_SIZE)
	region.set_vertex_spacing(VERTEX_SPACING)
	region.set_location(maps[0])
	if maps.size() > 4:
		var data: Dictionary = region.get_data()
		data["height_map"] = maps[1]
		data["control_map"] = maps[2]
		data["color_map"] = maps[3]
		data["height_range"] = maps[4]
		data["modified"] = true
		region.set_data(data)
		return region
	region.set_height_map(maps[1])
	region.set_control_map(maps[2])
	if maps.size() > 3:
		region.set_color_map(maps[3])
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
			_regions.fill(null)
			_next_region = REGION_COUNT
			_next_map = MAP_TYPES.size()
		if deadline >= 0:
			return
	if _next_region < _regions.size():
		# A region a frame: making it with its maps, then the sanitize and the add.
		var region: Object = _make_region(_regions[_next_region])
		region.sanitize_maps()
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
