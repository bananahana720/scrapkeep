extends Node3D


signal built

static var draw_regions := true

const MaterialSlots := preload("res://src/presentation/material_slots.gd")
const Palette := preload("res://src/core/palette.gd")
const PylonBite := preload("res://src/world/pylon_bite.gd")
const ParkStamps := preload("res://src/world/park/park_stamps.gd")
const ThreadGuard := preload("res://src/core/thread_guard.gd")
const GROUND_FLOOR_ID := 0
const GROUND_STRATA_ID := 1
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
const SHAPE_BUDGET_USEC := 2000
const HOLE_BIT := 4
const AUTO_BIT := 1
const SLOT_CONCRETE := 2
const SLOT_TAILINGS := 3
const SLOT_BASALT := 4
const TAILINGS_NOON_SCALE := 0.65
const MULT_TAILINGS := Color(0.827, 0.710, 0.695, float(COLOR_ALPHA_BYTE) / 255.0)
const MULT_BASALT := Color(0.426, 0.535, 0.898, float(COLOR_ALPHA_BYTE) / 255.0)
const MULT_CONCRETE := Color(0.907, 0.903, 1.0, float(COLOR_ALPHA_BYTE) / 255.0)
const GROUND_FLOOR_MEAN := Color(0.7327, 0.5977, 0.4117)
const GROUND_STRATA_MEAN := Color(0.731, 0.535, 0.366)
const FEATHER_PAD := 4
const FEATHER_LEVEL := 2
const FEATHER_MARGIN := 2 * FEATHER_PAD
const WEAR_DARKEN := 0.23
const WEAR_CORE := 0.25
const WEAR_RIPPLE := 0.21
const WEAR_RIPPLE_PER_M := 0.23
const WEAR_FADE_IN := 0.10
const WEAR_FADE_OUT_FROM := 0.82
const COLOR_ALPHA_BYTE := 127
const BITE_G2 := 4.0 * STEP * STEP * (1.0 / (PylonBite.FACE * PylonBite.FACE) - 1.0)
const COLLISION_DISABLED := 0
const MESH_LODS := 7
const MESH_SIZE := 48
const MAP_TYPES := [2, 0, 1]
const MAP_GAP_FRAMES := 10
static var build_tasks := maxi(1, OS.get_processor_count() / 2)


static func reset_for_tests() -> void:
	draw_regions = true
	build_tasks = maxi(1, OS.get_processor_count() / 2)
const SHAPE_TASKS := 2

enum Phase { IDLE, LOADING, BUILDING, ATTACHING, READY }

var map_id := ""
var baked := false
var heights := PackedFloat32Array()
var berm_rows: Dictionary = PylonBite.BERM_ROWS
var bite_masked := 0
var _bite_mask := PackedByteArray()
var holes := PackedByteArray()
var under := PackedFloat32Array()
var terrain3d: Node3D
var tiles: Array[StaticBody3D] = []
var worker_pieces := 0
var phase := Phase.IDLE
var slowest_usec := 0
var slowest_step := ""
var frame_usec_max := 0
var _last_frame_usec := 0
var _meter_frames := 0
var _tile_usec := 0

var _map: RefCounted
var _apron := PackedFloat32Array()
var _apron_rows := PackedInt32Array()
var _hole_cells := PackedInt32Array()
var _tints: Image
var _regions: Array = []
var _faces: Array = []
var _task := -1
var _group := -1
var _lock := Mutex.new()
var _next_region := 0
var _next_map := 0
var _map_wait := 0
var _next_tile := 0
var _tiles_root: Node3D
var _holders: Array = []
var _next_shape := 0
var _shape_group := -1
var _shape_space := RID()
var _shape_state: PhysicsDirectSpaceState3D
var _shape_rids: Array[RID] = []


static func slot_target(slot: int) -> Color:
	var m := slot_tint(slot)
	return Color(m.r * GROUND_FLOOR_MEAN.r, m.g * GROUND_FLOOR_MEAN.g, m.b * GROUND_FLOOR_MEAN.b)


static func slot_tint(slot: int) -> Color:
	match slot:
		SLOT_CONCRETE:
			return MULT_CONCRETE
		SLOT_TAILINGS:
			return MULT_TAILINGS
		SLOT_BASALT:
			return MULT_BASALT
	return Color(1.0, 1.0, 1.0, float(COLOR_ALPHA_BYTE) / 255.0)


static func bite_multiplier(slot_mult: Color, n_y: float, w: float) -> Color:
	var a := clampf(2.0 * n_y - 1.0, 0.0, 1.0)
	var d := GROUND_STRATA_MEAN.lerp(GROUND_FLOOR_MEAN, a)
	var tint := PylonBite.tint()
	return Color(
			clampf(lerpf(slot_mult.r, tint.r / d.r, w), 0.0, 1.0),
			clampf(lerpf(slot_mult.g, tint.g / d.g, w), 0.0, 1.0),
			clampf(lerpf(slot_mult.b, tint.b / d.b, w), 0.0, 1.0),
			float(COLOR_ALPHA_BYTE) / 255.0)


static func board_multiplier(material: Vector3, ground: Vector3) -> Color:
	var m := material / 255.0
	var g := ground / 255.0
	var want := _luma(GROUND_FLOOR_MEAN.r, GROUND_FLOOR_MEAN.g, GROUND_FLOOR_MEAN.b) * _luma(m.x, m.y, m.z) / _luma(g.x, g.y, g.z)
	var gr := m.y / m.x
	var br := m.z / m.x
	var lo := 0.0
	var hi := 4.0
	for i in 60:
		var mid := (lo + hi) * 0.5
		if _luma(mid, mid * gr, mid * br) < want:
			lo = mid
		else:
			hi = mid
	var target := Vector3(lo, lo * gr, lo * br)
	var f := GROUND_FLOOR_MEAN
	var worst := maxf(target.x / f.r, maxf(target.y / f.g, target.z / f.b))
	if worst > 1.0:
		target /= worst
	return Color(target.x / f.r, target.y / f.g, target.z / f.b, float(COLOR_ALPHA_BYTE) / 255.0)


static func linear_scaled(mult: Color, k: float) -> Color:
	return Color(
			clampf(_encode(_linear(mult.r) * k), 0.0, 1.0),
			clampf(_encode(_linear(mult.g) * k), 0.0, 1.0),
			clampf(_encode(_linear(mult.b) * k), 0.0, 1.0),
			mult.a)


static func render_corrected(mult: Color, rendered_lab: Vector3, board_srgb: Vector3) -> Color:
	var rendered := _lab_to_linear(rendered_lab)
	var board := Vector3(_linear(board_srgb.x / 255.0), _linear(board_srgb.y / 255.0), _linear(board_srgb.z / 255.0))
	return Color(
			clampf(_encode(_linear(mult.r) * board.x / rendered.x), 0.0, 1.0),
			clampf(_encode(_linear(mult.g) * board.y / rendered.y), 0.0, 1.0),
			clampf(_encode(_linear(mult.b) * board.z / rendered.z), 0.0, 1.0),
			mult.a)


static func _lab_to_linear(lab: Vector3) -> Vector3:
	var fy := (lab.x + 16.0) / 116.0
	var fx := fy + lab.y / 500.0
	var fz := fy - lab.z / 200.0
	var x := 0.95047 * _lab_finv(fx)
	var y := _lab_finv(fy)
	var z := 1.08883 * _lab_finv(fz)
	return Vector3(
			3.2404542 * x - 1.5371385 * y - 0.4985314 * z,
			-0.9692660 * x + 1.8760108 * y + 0.0415560 * z,
			0.0556434 * x - 0.2040259 * y + 1.0572252 * z)


static func _lab_finv(t: float) -> float:
	return t * t * t if t * t * t > 0.008856 else (t - 16.0 / 116.0) / 7.787


static func _encode(c: float) -> float:
	return c * 12.92 if c <= 0.0031308 else 1.055 * pow(c, 1.0 / 2.4) - 0.055


static func _luma(r: float, g: float, b: float) -> float:
	return 0.2126 * _linear(r) + 0.7152 * _linear(g) + 0.0722 * _linear(b)


static func _linear(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


static func feather(cells: Image) -> Image:
	var side := CELLS + 2 * FEATHER_PAD
	var padded := Image.create(side, side, false, Image.FORMAT_RGBA8)
	padded.fill(Color(1.0, 1.0, 1.0, float(COLOR_ALPHA_BYTE) / 255.0))
	padded.blit_rect(cells, Rect2i(0, 0, CELLS, CELLS), Vector2i(FEATHER_PAD, FEATHER_PAD))
	padded.generate_mipmaps()
	var texels := side >> FEATHER_LEVEL
	var from := padded.get_mipmap_offset(FEATHER_LEVEL)
	var level := Image.create_from_data(texels, texels, false, Image.FORMAT_RGBA8, padded.get_data().slice(from, from + texels * texels * 4))
	level.resize(texels * 8, texels * 8, Image.INTERPOLATE_BILINEAR)
	return level


static func bake_dir(id: String) -> String:
	return "res://assets/park/%s" % id


static func has_bake(id: String) -> bool:
	return FileAccess.file_exists(bake_dir(id) + "/bake.json")


func is_ready() -> bool:
	return phase == Phase.READY


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
	material.auto_shader = true
	material.set_shader_param("auto_base_texture", GROUND_STRATA_ID)
	material.set_shader_param("auto_overlay_texture", GROUND_FLOOR_ID)
	material.set_shader_param("auto_slope", 1.0)
	material.set_shader_param("auto_height_reduction", 0.0)
	material.set_shader_param("noise_texture", patch_noise())
	dress_floor(node, "")
	return node


const FLOOR_PATCHES := {
	"park_dam": {"scour": Color(0.72, 0.64, 0.57), "stain": Color(0.88, 0.76, 0.64), "scour_scale": 0.05, "stain_scale": 0.11},
}
const PATCH_NOISE_PX := 256
static var _patch_noise: Texture2D


static func patch_noise() -> Texture2D:
	if _patch_noise == null:
		var noise := FastNoiseLite.new()
		noise.seed = 1871
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.012
		noise.fractal_octaves = 3
		var image := noise.get_seamless_image(PATCH_NOISE_PX, PATCH_NOISE_PX)
		image.generate_mipmaps()
		_patch_noise = ImageTexture.create_from_image(image)
	return _patch_noise


static func dress_floor(render: Node3D, id: String) -> void:
	var row: Dictionary = FLOOR_PATCHES.get(id, {})
	var material: Object = render.material
	material.set_shader_param("enable_macro_variation", not row.is_empty())
	material.set_shader_param("macro_variation1", row.get("scour", Color.WHITE))
	material.set_shader_param("macro_variation2", row.get("stain", Color.WHITE))
	material.set_shader_param("noise1_scale", float(row.get("scour_scale", 0.04)))
	material.set_shader_param("noise2_scale", float(row.get("stain_scale", 0.076)))
	material.set_shader_param("macro_variation_slope", 0.0)


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


func start(id: String, map: RefCounted, threaded: bool, render: Node3D = null) -> void:
	map_id = id
	_map = map
	terrain3d = render if draw_regions else null
	if terrain3d != null:
		dress_floor(render, id)
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
	_end_shape_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_end_shape_build()
		for holder in _holders:
			if holder != null:
				(holder as Node).free()


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
				_group = WorkerThreadPool.add_group_task(_build_piece, PIECES, build_tasks, true, "park_terrain build %s" % map_id)
				phase = Phase.BUILDING
		Phase.BUILDING:
			if WorkerThreadPool.is_group_task_completed(_group):
				WorkerThreadPool.wait_for_group_task_completion(_group)
				_group = -1
				phase = Phase.ATTACHING
		Phase.ATTACHING:
			_attach_step(Time.get_ticks_usec() + ATTACH_BUDGET_USEC)


static func hole_floor(hole_bytes: PackedByteArray, floors: PackedFloat32Array, x: float, z: float) -> float:
	if hole_bytes.is_empty():
		return NAN
	var i := clampi(int(floorf((x + HALF) / STEP)), 0, CELLS - 1)
	var j := clampi(int(floorf((z + HALF) / STEP)), 0, CELLS - 1)
	var k := j * CELLS + i
	return floors[k] if hole_bytes[k] == 1 else NAN


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
	_apply_bite()


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
	if _map != null and "park" in _map:
		paint_wear(_tints, _map.park.get("wear_rows", []))


static func paint_wear(tints: Image, rows: Array) -> void:
	var origin := Vector2i.ONE * (int(HALF) + FEATHER_MARGIN)
	var size := tints.get_size()
	for row: Dictionary in rows:
		var line := PackedVector2Array()
		for p in row["points"]:
			line.append(Vector2(p[0], p[1]))
		var length := 0.0
		for i in range(1, line.size()):
			length += line[i - 1].distance_to(line[i])
		if length <= 0.0:
			continue
		var half_mean: float = float(row["width_m"]) * 0.5
		var reach := half_mean * (1.0 + WEAR_RIPPLE)
		var strength := {}
		var base := 0.0
		for i in range(1, line.size()):
			var a := line[i - 1]
			var seg := line[i] - a
			var seg_len := seg.length()
			if seg_len <= 0.0:
				continue
			var lo := (Vector2(minf(a.x, line[i].x), minf(a.y, line[i].y)) - Vector2.ONE * reach).floor()
			var hi := (Vector2(maxf(a.x, line[i].x), maxf(a.y, line[i].y)) + Vector2.ONE * reach).ceil()
			for z in range(maxi(int(lo.y), -origin.y), mini(int(hi.y), size.y - 1 - origin.y) + 1):
				for x in range(maxi(int(lo.x), -origin.x), mini(int(hi.x), size.x - 1 - origin.x) + 1):
					var at := Vector2(x, z)
					var along := clampf((at - a).dot(seg) / (seg_len * seg_len), 0.0, 1.0)
					var arc := base + along * seg_len
					var half := half_mean * (1.0 + WEAR_RIPPLE * sin(arc * WEAR_RIPPLE_PER_M))
					var edge := 1.0 - smoothstep(WEAR_CORE, 1.0, at.distance_to(a + seg * along) / half)
					if edge <= 0.0:
						continue
					var t := arc / length
					var depth := smoothstep(0.0, WEAR_FADE_IN, t) * (1.0 - smoothstep(WEAR_FADE_OUT_FROM, 1.0, t))
					var pixel := Vector2i(x, z) + origin
					strength[pixel] = maxf(strength.get(pixel, 0.0), depth * edge)
			base += seg_len
		for pixel: Vector2i in strength:
			var tint := tints.get_pixelv(pixel)
			var old_alpha := tint.a
			tint = tint.darkened(float(strength[pixel]) * WEAR_DARKEN)
			tint.a = old_alpha
			tints.set_pixelv(pixel, tint)


func _normal_y(i: int, j: int) -> float:
	var idx := j * SIDE + i
	var dx := heights[idx - (1 if i > 0 else 0)] - heights[idx + (1 if i < SIDE - 1 else 0)]
	var dz := heights[idx - (SIDE if j > 0 else 0)] - heights[idx + (SIDE if j < SIDE - 1 else 0)]
	return 2.0 * STEP / sqrt(dx * dx + 4.0 * STEP * STEP + dz * dz)


func _berm_mask() -> PackedByteArray:
	bite_masked = 0
	var ids: Array = berm_rows.get(map_id, [])
	if ids.is_empty():
		return PackedByteArray()
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/%s.json" % map_id))
	var mask := PackedByteArray()
	if not data is Dictionary:
		return mask
	mask.resize(SIDE * SIDE)
	for row: Dictionary in data.get("park_rows", []):
		if not ids.has(String(row["id"])):
			continue
		var f := ParkStamps.frame(row)
		var box := ParkStamps.bounds(f)
		var pad := PylonBite.BERM_PAD_M
		var reach := pad * sqrt(2.0)
		var i0 := maxi(floori((box[0] - reach + HALF) / STEP), 0)
		var i1 := mini(ceili((box[2] + reach + HALF) / STEP), SIDE - 1)
		var j0 := maxi(floori((box[1] - reach + HALF) / STEP), 0)
		var j1 := mini(ceili((box[3] + reach + HALF) / STEP), SIDE - 1)
		var rel_x: float = f["length"] * 0.5 + pad
		var rel_z: float = f["width"] * 0.5 + pad
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var d: Vector2 = Vector2(-HALF + i * STEP, -HALF + j * STEP) - (f["at"] as Vector2)
				if absf(d.dot(f["along"])) <= rel_x and absf(d.dot(f["across"])) <= rel_z and mask[j * SIDE + i] == 0:
					mask[j * SIDE + i] = 1
					bite_masked += 1
	return mask


func _mark(i: int, j: int, dx: float, dz: float, weights: PackedFloat32Array, ny: PackedFloat32Array, flagged: PackedByteArray, cells: PackedInt32Array) -> void:
	if not _bite_mask.is_empty() and _bite_mask[j * SIDE + i] == 1:
		return
	var y := 2.0 * STEP / sqrt(dx * dx + 4.0 * STEP * STEP + dz * dz)
	ny[j * SIDE + i] = y
	weights[j * SIDE + i] = PylonBite.weight(y)
	for cj in range(maxi(j - 1, 0), mini(j, CELLS - 1) + 1):
		for ci in range(maxi(i - 1, 0), mini(i, CELLS - 1) + 1):
			var k := cj * CELLS + ci
			if flagged[k] == 0:
				flagged[k] = 1
				cells.append(k)


func _apply_bite() -> void:
	_bite_mask = _berm_mask()
	var weights := PackedFloat32Array()
	var ny := PackedFloat32Array()
	weights.resize(SIDE * SIDE)
	ny.resize(SIDE * SIDE)
	var flagged := PackedByteArray()
	flagged.resize(CELLS * CELLS)
	var cells := PackedInt32Array()
	var h := heights
	for j in SIDE:
		var up := SIDE if j > 0 else 0
		var down := SIDE if j < SIDE - 1 else 0
		var row := j * SIDE
		for i in range(1, SIDE - 1):
			var idx := row + i
			var dx := h[idx - 1] - h[idx + 1]
			var dz := h[idx - up] - h[idx + down]
			if dx * dx + dz * dz > BITE_G2:
				_mark(i, j, dx, dz, weights, ny, flagged, cells)
		for i: int in [0, SIDE - 1]:
			var idx := row + i
			var dx := h[idx - (1 if i > 0 else 0)] - h[idx + (1 if i < SIDE - 1 else 0)]
			var dz := h[idx - up] - h[idx + down]
			if dx * dx + dz * dz > BITE_G2:
				_mark(i, j, dx, dz, weights, ny, flagged, cells)
	_bite_mask = PackedByteArray()
	if cells.is_empty():
		return
	var pixels := PackedByteArray()
	if _tints != null:
		pixels = _tints.get_data()
	else:
		pixels.resize((CELLS * 2 + 2 * FEATHER_MARGIN) * (CELLS * 2 + 2 * FEATHER_MARGIN) * 4)
		pixels.fill(255)
		for p in range(3, pixels.size(), 4):
			pixels[p] = COLOR_ALPHA_BYTE
	var row_px := CELLS * 2 + 2 * FEATHER_MARGIN
	for k in cells:
		var i := k % CELLS
		var j := k / CELLS
		var a := j * SIDE + i
		var b := a + 1
		var c := a + SIDE
		var ya := ny[a] if weights[a] > 0.0 else _normal_y(i, j)
		var yb := ny[b] if weights[b] > 0.0 else _normal_y(i + 1, j)
		var yc := ny[c] if weights[c] > 0.0 else _normal_y(i, j + 1)
		for q in 4:
			var w := 0.0
			var y := 0.0
			match q:
				0:
					w = weights[a]
					y = ya
				1:
					w = (weights[a] + weights[b]) * 0.5
					y = (ya + yb) * 0.5
				2:
					w = (weights[a] + weights[c]) * 0.5
					y = (ya + yc) * 0.5
				3:
					w = (weights[b] + weights[c]) * 0.5
					y = (yb + yc) * 0.5
			var at := ((2 * j + (q >> 1) + FEATHER_MARGIN) * row_px + 2 * i + (q & 1) + FEATHER_MARGIN) * 4
			var m := bite_multiplier(Color(pixels[at] / 255.0, pixels[at + 1] / 255.0, pixels[at + 2] / 255.0), y, w)
			pixels[at] = roundi(m.r * 255.0)
			pixels[at + 1] = roundi(m.g * 255.0)
			pixels[at + 2] = roundi(m.b * 255.0)
			pixels[at + 3] = COLOR_ALPHA_BYTE
	_tints = Image.create_from_data(row_px, row_px, false, Image.FORMAT_RGBA8, pixels)


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
		if draw_regions:
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
	return [location, Image.create_from_data(REGION_SIZE, REGION_SIZE, false, Image.FORMAT_RF, data.to_byte_array()),
		Image.create_from_data(REGION_SIZE, REGION_SIZE, false, Image.FORMAT_RF, control.to_byte_array()),
		color_map(_tints, -inner - FEATHER_MARGIN - x0, -inner - FEATHER_MARGIN - z0), Vector2(low, high)]


static func color_map(tints: Image = null, x := 0, z := 0) -> Image:
	if tints == null:
		var white := Image.create_empty(REGION_SIZE, REGION_SIZE, true, Image.FORMAT_RGBA8)
		white.fill(Color(1.0, 1.0, 1.0, float(COLOR_ALPHA_BYTE) / 255.0))
		return white
	var color := Image.create_empty(REGION_SIZE, REGION_SIZE, false, Image.FORMAT_RGBA8)
	color.fill(Color(1.0, 1.0, 1.0, float(COLOR_ALPHA_BYTE) / 255.0))
	color.blit_rect(tints, Rect2i(Vector2i.ZERO, tints.get_size()), Vector2i(x, z))
	color.generate_mipmaps()
	return color


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
			faces[w] = va
			faces[w + 1] = vb
			faces[w + 2] = vc
			faces[w + 3] = vb
			faces[w + 4] = vd
			faces[w + 5] = vc
			w += 6
	faces.resize(w)
	return faces


func _attach_step(deadline: int) -> void:
	if _tiles_root == null:
		_tiles_root = Node3D.new()
		_tiles_root.name = "Tiles"
		add_child(_tiles_root)
		if terrain3d == null or terrain3d.data == null:
			if draw_regions:
				push_warning("park_terrain: %s has no Terrain3D render node; collider only" % map_id)
			terrain3d = null
			_regions.fill(null)
			_next_region = REGION_COUNT
			_next_map = MAP_TYPES.size()
		if deadline >= 0:
			return
	if _next_region < _regions.size():
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
		if deadline >= 0 and _map_wait < MAP_GAP_FRAMES:
			_map_wait += 1
			_shapes_ahead(deadline)
			return
		_map_wait = 0
		terrain3d.data.update_maps(MAP_TYPES[_next_map], true, false)
		_next_map += 1
		if deadline >= 0:
			return
	if _next_map < MAP_TYPES.size():
		return
	if deadline >= 0 and not _shapes_ahead(deadline):
		return
	_end_shape_build()
	var added := 0
	while _next_tile < TILE_COUNT:
		var now := Time.get_ticks_usec()
		if deadline >= 0 and not tile_fits(added, now, deadline, _tile_usec):
			return
		_add_tile(_next_tile)
		_tile_usec = Time.get_ticks_usec() - now
		_faces[_next_tile] = null
		_next_tile += 1
		added += 1
	if added > 0 and deadline >= 0:
		return
	phase = Phase.READY
	set_process(false)
	built.emit()


static func tile_fits(added: int, now: int, deadline: int, last_usec: int) -> bool:
	return added < TILES_PER_FRAME and now <= deadline and (added == 0 or now + last_usec <= deadline)


func _shapes_ahead(deadline: int) -> bool:
	if _next_shape < TILE_COUNT:
		if _holders.is_empty():
			_holders.resize(TILE_COUNT)
			_shape_rids.resize(TILE_COUNT)
		var made := 0
		var last := 0
		var end := mini(deadline, Time.get_ticks_usec() + SHAPE_BUDGET_USEC)
		while _next_shape < TILE_COUNT:
			var now := Time.get_ticks_usec()
			if not tile_fits(made, now, end, last):
				return false
			_holders[_next_shape] = _holder(_faces[_next_shape])
			# Jolt's _build returns null for empty shapes (all-hole tiles), and intersect_shape errors on invalid RIDs.
			if not (_faces[_next_shape] as PackedVector3Array).is_empty():
				_shape_rids[_next_shape] = (_holders[_next_shape] as CollisionShape3D).shape.get_rid()
			last = Time.get_ticks_usec() - now
			_next_shape += 1
			made += 1
		_shape_space = PhysicsServer3D.space_create()
		_shape_state = PhysicsServer3D.space_get_direct_state(_shape_space)
		_shape_group = WorkerThreadPool.add_group_task(_build_shape.bind(_shape_state, _shape_rids), TILE_COUNT, mini(SHAPE_TASKS, build_tasks), true, "park_terrain shapes %s" % map_id)
		return false
	return _shape_group == -1 or WorkerThreadPool.is_group_task_completed(_shape_group)


# Static worker: Godot debug builds forbid free() on a node mid-call ("Attempted to free a locked object"), which hangs if freed mid-build.
static func _build_shape(i: int, state: PhysicsDirectSpaceState3D, rids: Array[RID]) -> void:
	if not rids[i].is_valid():
		return
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape_rid = rids[i]
	state.intersect_shape(query, 1)


func _end_shape_build() -> void:
	if _shape_group != -1:
		WorkerThreadPool.wait_for_group_task_completion(_shape_group)
		_shape_group = -1
	if _shape_space.is_valid():
		_shape_state = null
		PhysicsServer3D.free_rid(_shape_space)
		_shape_space = RID()


static func _holder(faces: PackedVector3Array) -> CollisionShape3D:
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var holder := CollisionShape3D.new()
	# Assign shape before Jolt prebuild: Godot debug builds set debug color on CollisionShape3D.set_shape(), invalidating the built shape.
	holder.shape = shape
	return holder


func _add_tile(t: int) -> void:
	var holder: CollisionShape3D = _holders[t] if t < _holders.size() and _holders[t] != null else _holder(_faces[t])
	if t < _holders.size():
		_holders[t] = null
	var body := StaticBody3D.new()
	body.name = "Tile%d_%d" % [t % TILES_PER_SIDE, t / TILES_PER_SIDE]
	body.add_child(holder)
	_tiles_root.add_child(body)
	tiles.append(body)
