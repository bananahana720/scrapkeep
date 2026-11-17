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
#             Where a pylon can bite (pylon_bite.gd, terrain.gd's old-map rule on the same 2 m grid
#             normals) the colour map also moves toward the pylon tint, so the concrete-grey slope
#             reads as it does on the old maps. _load computes that from heights, for baked and
#             unbaked parks alike; it is not stored in the bake (PARK.md says "the bake calls": this
#             is the load step of the same data), so no bake binary changes.
#             Each multiplier comes from one rule on a reference board's material and lit-ground
#             patches (board_multiplier(): the material's hue, a value scaled by material over ground,
#             capped at the floor's own, since a colour map cannot brighten); tailings and basalt are then
#             darkened for the 3060 render (linear_scaled(), render_corrected()). The colour map is
#             feathered over 8 m texels (feather()), so a slot border or the square's edge fades
#             instead of stepping; the texel grid is fixed, so a straight border fades over 8 to 16 m
#             by where it falls, and a stamp narrower than about 16 m loses tint by its position.
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
# A tile's Jolt mesh shape (12,800 triangles, about 7 ms on the 4080, 8.8 ms on the cloud) is
# built where it is first used. Added cold, that is the add_child on the main thread: one tile a
# frame put the flume's attach over 7 ms of _process for ~100 frames (#512 4080 probe). So a
# played build makes each tile's shape and holder on the main thread during the map gaps (a few
# a frame, ~0.3 ms each), has Jolt build them on SHAPE_TASKS pool threads through a shape query
# on a private, never-stepped space (try_build caches the result on the shape), and only then
# adds the bodies, which take the built shape as is. The holder takes its shape before the build: in a
# debug build CollisionShape3D.set_shape sets the shape's debug colour, which re-sends the faces
# and drops a built shape. A whole build (finish(), every bot run) adds cold, as before.
#
# The Terrain3D node is not this node's child: a new Terrain3D spends about 135 ms of main
# thread on its first frame (measured headless, any settings), which no launch can afford. So
# terrain.gd makes two at setup with make_render() (the active stage's and the next one's) and
# lends one to each park stage; attaching replaces the node's four regions in place.

signal built

# False in headless bot runs (bot_options.gd): the four render regions are only ever drawn, so a
# stage builds its collider tiles and heights alone. Nothing reads a region but Terrain3D's draw.
static var draw_regions := true

const MaterialSlots := preload("res://src/presentation/material_slots.gd")
const Palette := preload("res://src/core/palette.gd")
const PylonBite := preload("res://src/world/pylon_bite.gd")
const ParkStamps := preload("res://src/world/park/park_stamps.gd")
const ThreadGuard := preload("res://src/core/thread_guard.gd")
const GROUND_FLOOR_ID := 0
const GROUND_STRATA_ID := 1
# Metres per tile of the floor texture: sandstone.gdshader's floor_metres default (:9), which the
# `ground` slot leaves alone (palette.gd sets only strata_metres, from triplanar_scale).
const GROUND_FLOOR_METRES := 5.0
# The old haul track turns west below the Eye. At the siphon a scoured wash follows the
# outside of the low return, under the high trough. Both are wear in the actual ground
# colour map: no mesh to clip through, collider, live warning, or material change.
const HAUL_TRACKS := {
	"park_dam": [[Vector2(-7, 205), Vector2(-5, 246), Vector2(-82, 287)]],
	"park_flume": [
		[Vector2(12, 222), Vector2(14, 266), Vector2(69, 310)],
		# The trestle's stand of timbers obscures the far bank on approach. A worn
		# turn starts beside the working face and continues to the near lip.
		[Vector2(-168, -129), Vector2(-166, -93), Vector2(-186, -57)],
	],
}

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
# Main-thread time a frame may spend making tile shapes ahead (_shapes_ahead): about 0.3 ms each on the cloud.
const SHAPE_BUDGET_USEC := 2000
# Terrain3D's control map: bit 2 is the hole bit (Terrain3DUtil.enc_hole).
const HOLE_BIT := 4
# Bit 0 is the auto bit: the auto-shader picks the base or overlay texture by slope.
const AUTO_BIT := 1
# surface.bin slots (park_stamps.gd SURFACE_SLOTS) that tint the colour map. Slots 0, 1 and 5 (net) stay white.
const SLOT_CONCRETE := 2
const SLOT_TAILINGS := 3
const SLOT_BASALT := 4
# Each tinted slot's colour-map multiplier comes from board_multiplier() on two patches of one
# reference board: the material and the lit ground beside it (sRGB box means, ImageMagick
# `convert <board> -crop WxH+X+Y -resize 1x1!`, each crop checked by eye). The rule: chromaticity is
# the material's (g/r, b/r); the target's luminance is the floor texture's times material / ground;
# a target brighter than the floor in any channel is scaled down until none is, because RGBA8 caps a
# multiplier at 1; the multiplier is target / GROUND_FLOOR_MEAN. The values below are board_multiplier()
# of the numbers cited, then darkened where the 3060 render asked for it (tailings by linear_scaled(),
# basalt by render_corrected()), stored as literals (the surface test pins each).
# Tailings: docs/art/reference/dig/dig-landmark-headframe-noon.jpg, the worked pit floor at noon.
# Material and ground are the same floor: crops 120x40+1150+700, 120x40+880+600 and 100x30+1150+620
# read 242,169,113, 245,172,117 and 245,172,116 (median 245,172,116). The value ratio is 1, so red
# stays at 1 and only the hue moves toward oxide: target (0.733, 0.514, 0.347), L* 59.5, multiplier
# (1.0, 0.861, 0.843). Ground over horizon (coordinator #241 6353059714, bar 1): the noon pit frame
# (day_arc_capture 4-stage3-noon) reads its near floor, which is tailings (surface.bin of park_pit, the
# cells 10 to 18 m behind the ball), at L* 66.7 against the horizon haze's 73.8, a gap of 7.1 where 10 is
# wanted. TAILINGS_NOON_SCALE darkens the multiplier in linear light (linear_scaled(), the space
# Terrain3D multiplies in); the cast model of artifacts/local/valcap/cast_model.py puts 0.65 at about
# -6 to -7 L* on that floor (gap about 13). The model fits the bench poorly (chroma too high), so
# the scale is a prediction to confirm on the 3060, not a measurement. Tailings also tints park_sinkhole
# and park_islands; they darken with it.
const TAILINGS_NOON_SCALE := 0.65
const MULT_TAILINGS := Color(0.827, 0.710, 0.695, float(COLOR_ALPHA_BYTE) / 255.0)
# Basalt: docs/art/reference/dig/dig-landmark-sinkhole-afternoon.jpg. The basalt cap, crops
# 120x40+960+215 and 100x40+1180+210, reads 104,95,95 and 98,90,91 (mean 101,92.5,93); the lit pale
# limestone in the same board, crop 80x60+1120+330, reads 153,126,111. Capped: board_multiplier() gives
# (0.610, 0.685, 1.0), target L* 45.1. Render-corrected (#241 6352984236, the 3060 render bench of
# d19c9120): crop 600x200 at x 340, y 480 of a 1280x720 frame, poses 801 and 803 of park_props_audit
# --map=park_sinkhole, read L*/a*/b* 52.49/+7.1/+12.2 and 52.27/+7.2/+12.2 against the board patch
# (101, 93, 93), L* 40.2/+2.7/+0.7 (the bench's rounding of the crop mean above; the half byte of green
# moves the multiplier by under 0.002): 12 L* too bright and too warm, the stage's afternoon light and haze
# sitting between the multiplier and the pixel. render_corrected() scales the multiplier by board over
# rendered (mean of the two poses), per channel in linear light, because Terrain3D samples _color_maps
# with source_color and multiplies it into the albedo after decoding. One render pass, measured once on
# the 3060; the cast is assumed multiplicative.
const MULT_BASALT := Color(0.426, 0.535, 0.898, float(COLOR_ALPHA_BYTE) / 255.0)
# Concrete: docs/art/reference/spillway/spillway-landmarks-flume-carry.jpg. The pale concrete ramp, crop
# 60x14+1080+410, reads 239,194,148; the lit sand ground, crops 100x30+880+600 and 100x30+600+640,
# read 244,167,102 and 242,167,103 (mean 243,167,102.5). Concrete is paler than the ground, which a
# multiplier cannot show: only blue reaches the floor's value, so concrete draws as a less orange sand,
# target (0.665, 0.540, 0.412), L* 59.5, about 5.6 below the sand around it. Pale concrete (L* 71)
# cannot be shown: desaturating the orange floor under a cap of 1 must lower its luminance. A concrete
# texture is the real fix.
const MULT_CONCRETE := Color(0.907, 0.903, 1.0, float(COLOR_ALPHA_BYTE) / 255.0)
# The floor texture's mean albedo (packed-sand-floor.webp, every pixel of the base level): the
# floor is what flat ground draws, so a multiplier times this is the colour a cell's mean lands on.
# Steep ground draws strata, whose mean is slightly darker (see GROUND_STRATA_MEAN).
const GROUND_FLOOR_MEAN := Color(0.7327, 0.5977, 0.4117)
# The strata texture's mean albedo (the imported sandstone-strata texture, measured over its pixels):
# what a fully steep vertex draws before the colour map.
const GROUND_STRATA_MEAN := Color(0.731, 0.535, 0.366)
# The colour map is feathered over 8 m: the per-cell multipliers are padded with FEATHER_PAD white
# cells (so a tint at the play square's edge fades toward the apron), box-filtered to 8 m texels (mip
# level FEATHER_LEVEL) and bilinearly stretched back to 1 m vertices. The texel grid is fixed, so a
# straight border fades over 8 to 16 m depending on where it falls, and a stamp narrower than about
# 16 m loses tint depending on its position.
const FEATHER_PAD := 4
const FEATHER_LEVEL := 2
# One-metre pixels of padding on each side of feather()'s image: vertex m is at pixel m + this.
const FEATHER_MARGIN := 2 * FEATHER_PAD
# Terrain3D's default colour map is white with alpha 127/255, which leaves roughness unchanged.
const COLOR_ALPHA_BYTE := 127
# n.y < FACE exactly when dx^2 + dz^2 > (2 STEP)^2 * (1 / FACE^2 - 1), n = (dx, 2 STEP, dz) normalised.
const BITE_G2 := 4.0 * STEP * STEP * (1.0 / (PylonBite.FACE * PylonBite.FACE) - 1.0)
const COLLISION_DISABLED := 0
const MESH_LODS := 7
const MESH_SIZE := 48
# Terrain3DRegion map types for update_maps: colour, height, control. Colour goes first,
# MAP_GAP_FRAMES after the regions are added: rebuilt the frame after the last add, the flume's
# colour array took 24.8 ms on the 4080 at the Warden prebuild, and 7.8 ms after a 30-frame gap.
const MAP_TYPES := [2, 0, 1]
const MAP_GAP_FRAMES := 10
# The pool threads a threaded build takes, leaving the rest to the renderer and Jolt (see _pump).
static var build_tasks := maxi(1, OS.get_processor_count() / 2)
# The pool threads the tile shape build takes (_shapes_ahead). On build_tasks the 100 Jolt builds (~7 ms each on the 4080)
# finished in about four frames and those frames drew slow (draw 5.5-7.3 ms, net 17-21; #607 6540029016, #609's row): two
# threads spread the same work over ~350 ms (20-30 frames), still well before the bodies are wanted.
const SHAPE_TASKS := 2

enum Phase { IDLE, LOADING, BUILDING, ATTACHING, READY }

var map_id := ""
var baked := false
var heights := PackedFloat32Array()
# PylonBite.BERM_ROWS (map id -> row ids whose footprint the bite tint skips); a test sets {} to disable it before start().
var berm_rows: Dictionary = PylonBite.BERM_ROWS
# Grid vertices the berm rows' footprints exclude from the bite tint, and the 0/1 mask itself (empty when no rows apply).
var bite_masked := 0
var _bite_mask := PackedByteArray()
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
var _tile_usec := 0

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
var _map_wait := 0
var _next_tile := 0
var _tiles_root: Node3D
# The played build's tile holders (CollisionShape3D with its shape), made ahead and built on the pool; null until made.
var _holders: Array = []
var _next_shape := 0
var _shape_group := -1
var _shape_space := RID()
var _shape_state: PhysicsDirectSpaceState3D
var _shape_rids: Array[RID] = []


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


# The colour-map multiplier of a vertex a pylon can bite. The colour map multiplies the albedo, and
# the auto-shader draws strata toward floor by a = clamp(2 * n_y - 1, 0, 1) (auto_slope 1, no height
# reduction), so the mean albedo there is D = STRATA_MEAN.lerp(FLOOR_MEAN, a). The old maps' rule is
# final = base.lerp(tint, w) with base = D * slot_mult, hence slot_mult.lerp(tint / D, w) per channel,
# clamped to a colour map's range. Alpha stays at the default so roughness is unchanged.
static func bite_multiplier(slot_mult: Color, n_y: float, w: float) -> Color:
	var a := clampf(2.0 * n_y - 1.0, 0.0, 1.0)
	var d := GROUND_STRATA_MEAN.lerp(GROUND_FLOOR_MEAN, a)
	var tint := PylonBite.tint()
	return Color(
			clampf(lerpf(slot_mult.r, tint.r / d.r, w), 0.0, 1.0),
			clampf(lerpf(slot_mult.g, tint.g / d.g, w), 0.0, 1.0),
			clampf(lerpf(slot_mult.b, tint.b / d.b, w), 0.0, 1.0),
			float(COLOR_ALPHA_BYTE) / 255.0)


# The colour-map multiplier of a surface material from two patches of one reference board, given as raw
# sRGB bytes (0 to 255, may be fractional): the material, and the lit ground beside it.
#   chromaticity  the material's g/r and b/r;
#   value         target luminance Y = Y(GROUND_FLOOR_MEAN) * Y(material) / Y(ground), with
#                 Y = 0.2126 R + 0.7152 G + 0.0722 B on sRGB-decoded channels, solved for the red that
#                 gives it at that chromaticity;
#   cap           if a target channel exceeds the floor's, scale the target down until the largest
#                 channel ratio is 1 (a colour map cannot brighten);
#   multiplier    target / GROUND_FLOOR_MEAN, alpha at the default.
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


# A multiplier scaled by k in linear light (decode, multiply, encode; alpha kept, result in [0, 1]).
static func linear_scaled(mult: Color, k: float) -> Color:
	return Color(
			clampf(_encode(_linear(mult.r) * k), 0.0, 1.0),
			clampf(_encode(_linear(mult.g) * k), 0.0, 1.0),
			clampf(_encode(_linear(mult.b) * k), 0.0, 1.0),
			mult.a)


# board_multiplier() corrected for what the stage renders. The shader samples _color_maps with
# source_color (the addon's generated main shader, ALBEDO = albedo * color_map.rgb), so a multiplier is
# sRGB-decoded and multiplied in linear light, and the correction is too:
#   rendered  a crop's mean L*a*b* (D65), converted to linear sRGB;
#   board     the board patch's raw sRGB bytes (0 to 255), decoded to linear;
#   ratio     board / rendered per channel;
#   result    encode(decode(mult) * ratio), clamped to [0, 1], alpha kept.
# A render equal to the board returns mult; a warmer render lowers red relative to blue.
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


# Luminance of sRGB-encoded channels (each 0 to 1), decoded to linear first.
static func _luma(r: float, g: float, b: float) -> float:
	return 0.2126 * _linear(r) + 0.7152 * _linear(g) + 0.0722 * _linear(b)


static func _linear(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


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
	material.set_shader_param("noise_texture", patch_noise())
	dress_floor(node, "")
	return node


# Floor patches (4080 park stills, acb55972: the dam read as flat sand from above): Terrain3D's macro variation
# multiplies the albedo by two noise reads at two scales, so a park in FLOOR_PATCHES gets wind-scoured and
# wash-stained patches of tens of metres, weighted by the ground's normal y (macro_variation_slope 0), so flat floor
# takes the full tint, a strata slope part of it and a sheer face none.
# Every other park keeps white multipliers, which draw exactly as before. The shader runs it either way: no draw,
# no vertex and no texture slot is added.
const FLOOR_PATCHES := {
	"park_dam": {"scour": Color(0.72, 0.64, 0.57), "stain": Color(0.88, 0.76, 0.64), "scour_scale": 0.05, "stain_scale": 0.11},
}
const PATCH_NOISE_PX := 256
static var _patch_noise: Texture2D


# The macro noise every park render node shares: one seamless 256 px simplex tile, made once at setup.
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


# Sets render's floor patches for park id (FLOOR_PATCHES), or white multipliers for a park without a row.
static func dress_floor(render: Node3D, id: String) -> void:
	var row: Dictionary = FLOOR_PATCHES.get(id, {})
	var material: Object = render.material
	material.set_shader_param("enable_macro_variation", not row.is_empty())
	material.set_shader_param("macro_variation1", row.get("scour", Color.WHITE))
	material.set_shader_param("macro_variation2", row.get("stain", Color.WHITE))
	material.set_shader_param("noise1_scale", float(row.get("scour_scale", 0.04)))
	material.set_shader_param("noise2_scale", float(row.get("stain_scale", 0.076)))
	material.set_shader_param("macro_variation_slope", 0.0)


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
	_end_shape_build()


func _notification(what: int) -> void:
	# Holders made ahead but never added are off the tree: a stage freed mid-attach frees them here.
	if what == NOTIFICATION_PREDELETE:
		# Before _exit_tree on a free(): the pool may still be building these holders' shapes.
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
				# On half the pool: on every thread the 104 pieces held off the renderer's own pool work, 20 to
				# 23 ms of render CPU on the 4080 the frame the flume's build started at the dam Warden's engage;
				# at low priority the build ran long enough to lift dam p99 (#595 rows on 09b0a2d0 and 084266bb).
				_group = WorkerThreadPool.add_group_task(_build_piece, PIECES, build_tasks, true, "park_terrain build %s" % map_id)
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
	for track in HAUL_TRACKS.get(map_id, []):
		_wear_track(track)


func _wear_track(track: Array) -> void:
	var start: Vector2 = track[0]
	var bend: Vector2 = track[1]
	var end: Vector2 = track[2]
	for z in range(int(start.y), int(end.y) + 1):
		# Both bends sit halfway along Z, so t gives the quadratic's exact world Z.
		var t := inverse_lerp(start.y, end.y, float(z))
		var x_mid := lerpf(lerpf(start.x, bend.x, t), lerpf(bend.x, end.x, t), t)
		var depth := smoothstep(0.0, 0.10, t) * (1.0 - smoothstep(0.82, 1.0, t))
		var half_width := 2.8 + 0.6 * sin(float(z) * 0.23)
		for x in range(floori(x_mid - half_width), ceili(x_mid + half_width) + 1):
			var edge := 1.0 - smoothstep(0.25, 1.0, absf(float(x) - x_mid) / half_width)
			var pixel := Vector2i(x, z) + Vector2i.ONE * (int(HALF) + FEATHER_MARGIN)
			var tint := _tints.get_pixelv(pixel)
			var old_alpha := tint.a
			tint = tint.darkened(depth * edge * 0.23)
			tint.a = old_alpha
			_tints.set_pixelv(pixel, tint)


# The normal y of grid vertex (i, j) from its four neighbours' heights (edges clamped), as terrain.gd.
func _normal_y(i: int, j: int) -> float:
	var idx := j * SIDE + i
	var dx := heights[idx - (1 if i > 0 else 0)] - heights[idx + (1 if i < SIDE - 1 else 0)]
	var dz := heights[idx - (SIDE if j > 0 else 0)] - heights[idx + (SIDE if j < SIDE - 1 else 0)]
	return 2.0 * STEP / sqrt(dx * dx + 4.0 * STEP * STEP + dz * dz)


# The 0/1 mask over the grid of the footprints of this map's PylonBite.BERM_ROWS (park_stamps.gd's frame, padded by
# PylonBite.BERM_PAD_M); empty when the map names none, so every other park skips it. Rows are read from the park's
# own JSON.
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
		# A pad on a yawed footprint reaches up to pad * (|sin| + |cos|) <= pad * sqrt(2) past the unpadded bounds per axis.
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


# A grid vertex past BITE_G2: store its n.y and weight and flag the (up to four) cells that touch it.
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


# Patches the colour image's vertices (feather()'s layout) where a pylon can bite, except inside the pit berm rows'
# footprints (PylonBite.BERM_ROWS: a look rule, those flanks stay bitable but untinted). The normal is terrain.gd's, from the
# four neighbouring heights of each 2 m grid vertex (edges clamped); only cells with a biting corner
# are touched. A cell's four 1 m vertices take the weight and n.y of the grid points they sit on
# (_build_region's heights: the corner, an edge midpoint, or the b-c diagonal's midpoint, the
# diagonal the collider's two triangles share), and the multiplier is made from those.
# Most vertices are flat, so pass 1 only compares the squared slope with BITE_G2 and does the sqrt and
# the weight for the few past it; pass 2 visits just the cells those touch. Each vertex's slot
# multiplier is the feathered pixel already in the image.
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
		# Columns 1 to SIDE - 2 need no edge clamp; columns 0 and SIDE - 1 clamp their x neighbour in the
		# second loop. Both call _mark for a vertex past the threshold.
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
		# A corner that never passed the threshold has weight 0 and no stored n.y: compute it here.
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
			# The slot multiplier is the feathered pixel already there (byte / 255), so the bite composes
			# with the feather and no step appears at a slot border.
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


# A region's color map as sanitize_maps leaves it (mipmapped, alpha at COLOR_ALPHA_BYTE): white, or with tints (feather()'s
# image) blitted at (x, z) and the mipmaps made from that. Made here, on the worker, it is plain Image data; left to
# sanitize_maps on the main thread the white map cost 37 to 88 ms a region on the cloud, and a tinted one's mipmaps as much.
static func color_map(tints: Image = null, x := 0, z := 0) -> Image:
	if tints == null:
		var white := Image.create_empty(REGION_SIZE, REGION_SIZE, true, Image.FORMAT_RGBA8)
		white.fill(Color(1.0, 1.0, 1.0, float(COLOR_ALPHA_BYTE) / 255.0))
		return white
	# Cell (i, j)'s vertices are at -800 + 2i + (0, 1); the feathered image starts FEATHER_MARGIN metres before -800.
	var color := Image.create_empty(REGION_SIZE, REGION_SIZE, false, Image.FORMAT_RGBA8)
	color.fill(Color(1.0, 1.0, 1.0, float(COLOR_ALPHA_BYTE) / 255.0))
	color.blit_rect(tints, Rect2i(Vector2i.ZERO, tints.get_size()), Vector2i(x, z))
	color.generate_mipmaps()
	return color


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
			if draw_regions:
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
	# The built handlers (terrain._on_park_built: the park rows' Placer, perch zones, scenery) take a frame of
	# their own: on the last tile's frame they made the flume's f5874, 26-28 ms on the 4080.
	if added > 0 and deadline >= 0:
		return
	phase = Phase.READY
	set_process(false)
	built.emit()


# Whether one more collider tile (or, in _shapes_ahead, one more holder) fits this frame: up to TILES_PER_FRAME,
# inside the deadline, and, after the first, only when the last one's cost still fits (a cold tile's Jolt shape is ~7 ms).
static func tile_fits(added: int, now: int, deadline: int, last_usec: int) -> bool:
	return added < TILES_PER_FRAME and now <= deadline and (added == 0 or now + last_usec <= deadline)


# The played build's shapes ahead of their bodies: makes up to TILES_PER_FRAME holders a step (tile_fits on
# SHAPE_BUDGET_USEC), then builds them all on the pool. True once every shape is built and the bodies may go in.
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
			# A tile wholly in holes has no shape to build (Jolt's _build returns null and the query would error).
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


# Worker: Jolt builds tile i's mesh shape, caching it on the shape (JoltShape3D.try_build, under its own mutex). The
# private space is never stepped and holds no body, so the query touches nothing the main thread uses. Static, so a
# worker inside it holds no call lock on this node: a debug build refuses free() on a node mid-call ("Attempted to free a
# locked object"), which skipped the PREDELETE wait and hung a stage freed mid-build (2 of ~50 test runs).
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
