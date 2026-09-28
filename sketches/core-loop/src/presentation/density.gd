extends RefCounted

# The density governor (design-v3/FEEL-READABILITY.md §1.1-1.2, §8, §9 unit F1a). One
# scalar per frame, `density` in 0 to 1, read by every P5 (player effects) and P7
# (ambient) emitter from this one place. It never touches P0 to P3: the ball, hostile
# committed geometry, the three reads and the exits, and player committed targeting
# geometry are exempt from every governor, always. P4 (rewards/pickups) is thinned only
# past density 0.8 and is out of this unit's write set (F4a/F4b own that content). P6
# (hostile area fills) unions past four overlapping fills (§1.3.1); see
# `threat_grammar.gd`'s union functions for that half of the contract.
#
# This file holds the single typed ledger (pool/count caps) and the one shed order so
# every presentation module reads the same numbers instead of keeping a second counter.
# Each module (vfx.gd, bolts.gd) samples the live scene itself (threats/enemies in view,
# its own effects alive) and keeps its own `Governor`, because nothing upstream of this
# unit's write set (game.gd, context.gd) yet threads one shared instance through ctx;
# every Governor reads the same formula and bands here, so they agree.

# --- The raw scalar (§1.2) -----------------------------------------------------------

const THREAT_WEIGHT := 0.35
const THREAT_SCALE := 6.0
const FX_WEIGHT := 0.35
const FX_SCALE := 40.0
const ENEMY_WEIGHT := 0.3
const ENEMY_SCALE := 12.0

const RISE_SECONDS := 0.25
const FALL_SECONDS := 0.6

# density = clamp(0.35 * threats_in_view/6 + 0.35 * fx_alive/40 + 0.3 * enemies_in_view/12, 0, 1)
static func raw(threats_in_view: int, fx_alive: int, enemies_in_view: int) -> float:
	var d := THREAT_WEIGHT * float(threats_in_view) / THREAT_SCALE \
		+ FX_WEIGHT * float(fx_alive) / FX_SCALE \
		+ ENEMY_WEIGHT * float(enemies_in_view) / ENEMY_SCALE
	return clampf(d, 0.0, 1.0)


# --- Per-frame caps table (§1.2) ------------------------------------------------------
# Bands are inclusive of their lower edge; density 1.0 stays in the top band. "saturation"
# is §1.2's P5 colour column (finding 9/10): the band's HSV saturation held against the
# glyph/burst/trail colour's own saturation (a scale, not an absolute floor, so a colour
# that starts under 1.0 does not get boosted), value untouched.
const BANDS := [
	{"max": 0.4, "alpha": 0.9, "size": 1.0, "lifetime": 1.0, "ambient": "on", "saturation": 1.0,
		"coalesce_ms": 0, "coalesce_m": 0.0, "scale_per_extra": 0.0, "scale_cap": 1.0},
	{"max": 0.7, "alpha": 0.6, "size": 0.85, "lifetime": 0.7, "ambient": "quarter", "saturation": 0.7,
		"coalesce_ms": 120, "coalesce_m": 4.0, "scale_per_extra": 1.2, "scale_cap": 2.5},
	{"max": 1.01, "alpha": 0.35, "size": 0.7, "lifetime": 0.5, "ambient": "off", "saturation": 0.4,
		"coalesce_ms": 200, "coalesce_m": 6.0, "scale_per_extra": 1.2, "scale_cap": 2.5},
]

# Hysteresis (finding 9, §6.1): the 0.4/0.7 band edges used to be hard thresholds with no
# enter/exit gap, so density hovering right at one flipped every discrete cap (alpha,
# size, lifetime, coalescing, saturation) frame to frame. A boundary must be cleared by
# HYSTERESIS_MARGIN in the direction of travel before the reported band moves; sitting
# still at the edge keeps the last band. This is process-lifetime static state, which is
# fine here: every caller reads the one shared governor's density each frame (finding
# 2/9), so there is only ever one meaningful band stream to track (both vfx.gd and
# bolts.gd land on the same band, not two independent flickers).
const HYSTERESIS_MARGIN := 0.02
static var _band_index := 0


static func band(density: float) -> Dictionary:
	while _band_index < BANDS.size() - 1 and density >= float(BANDS[_band_index]["max"]) + HYSTERESIS_MARGIN:
		_band_index += 1
	while _band_index > 0 and density < float(BANDS[_band_index - 1]["max"]) - HYSTERESIS_MARGIN:
		_band_index -= 1
	return BANDS[_band_index]


static func alpha_cap(density: float) -> float:
	return float(band(density)["alpha"])


static func size_cap(density: float) -> float:
	return float(band(density)["size"])


static func lifetime_cap(density: float) -> float:
	return float(band(density)["lifetime"])


static func saturation_cap(density: float) -> float:
	return float(band(density)["saturation"])


# color's saturation scaled toward grey by the band's saturation column (finding 10),
# value (brightness) held. A no-op at density 0 (saturation 1.0).
static func apply_saturation(color: Color, density: float) -> Color:
	var factor := saturation_cap(density)
	if factor >= 0.999:
		return color
	return Color.from_hsv(color.h, color.s * factor, color.v, color.a)


# 1.0 on, 0.4 at the middle band, 0.0 off. No P7 ambient emitter exists in this sketch
# yet; a future one multiplies its rate/alpha by this fraction.
static func ambient_fraction(density: float) -> float:
	match String(band(density)["ambient"]):
		"on":
			return 1.0
		"quarter":
			return 0.4
		_:
			return 0.0


static func coalesce_window(density: float) -> Dictionary:
	var b := band(density)
	return {"ms": int(b["coalesce_ms"]), "metres": float(b["coalesce_m"]),
		"scale_per_extra": float(b["scale_per_extra"]), "scale_cap": float(b["scale_cap"])}


# Multipliers normalised so density 0 gives 1.0, i.e. "no change from today's look" when
# the governor is idle. alpha_cap(0) is 0.9, not 1.0, so alpha needs the divide; size and
# lifetime already start at 1.0. Divides by the constant BANDS[0] alpha, not alpha_cap(0.0):
# alpha_cap(0.0) would call the hysteretic band() with a density of 0 every time, which is
# only ever a normalisation constant here, not a real reading, and would otherwise yank
# the shared sticky band index back toward band 0 on every single call (finding 9).
static func alpha_factor(density: float) -> float:
	return alpha_cap(density) / float(BANDS[0]["alpha"])


static func size_factor(density: float) -> float:
	return size_cap(density)


static func lifetime_factor(density: float) -> float:
	return lifetime_cap(density)


# --- Priority classes (§1.1): what the governor may touch ------------------------------
# false: never governed (P0-P3). "thin_high": only past density 0.8 (P4, owned by F4).
# "union": unions past 4 overlapping fills instead of fading (P6, see threat_grammar.gd).
# true: governed continuously by the bands above (P5, P7).
const GOVERNED := {
	"P0": false, "P1": false, "P2": false, "P3": false,
	"P4": "thin_high", "P5": true, "P6": "union", "P7": true,
}


static func is_shed_exempt(priority_class: String) -> bool:
	var governed: Variant = GOVERNED.get(priority_class, true)
	return typeof(governed) == TYPE_BOOL and governed == false


# --- The shed order (§8) ---------------------------------------------------------------
# Ambient P7 is removed first, then Systems' active-effect order. Never sheds the ball,
# hostile edges/fronts, window aperture, objective, hold gauge, kicker lips or player
# committed targeting geometry (all P0-P3, exempt above).
const SHED_ORDER := [
	"ambient_p7",
	"bolt_tails",
	"synergy_evolution_rings",
	"pin_trails_and_fountains",
	"drone_rack_seams",
]


# Hysteresis on the "sheds at all" gate (finding 9): without it, density crossing 0.4 by
# a hair (say 0.399 to 0.401) jumps shed_step from 0 straight to 1 (ceil() has no ramp-in
# right at the edge), flipping ambient_p7 on the same flicker the band() edges had. Once
# active it takes dropping below SHED_LEAVE to clear, matching the fix's own example
# (enter 0.42, leave 0.36). The ramp above 0.4 stays a plain function of density -- once
# active, every density above 0.4 already gives at least one step on its own, so this only
# gates the entry, not the climb through SHED_ORDER's later steps.
const SHED_ENTER := 0.42
const SHED_LEAVE := 0.36
static var _shed_active := false


# How many steps of SHED_ORDER are in effect at this density: 0 below the gate, climbing
# to every step by density 1.0. Always a prefix of SHED_ORDER, never skips or reorders.
static func shed_step(density: float) -> int:
	if density >= SHED_ENTER:
		_shed_active = true
	elif density < SHED_LEAVE:
		_shed_active = false
	if not _shed_active:
		return 0
	var span := clampf((density - 0.4) / 0.6, 0.0, 1.0)
	return clampi(int(ceil(span * SHED_ORDER.size())), 0, SHED_ORDER.size())


static func active_shed(density: float) -> Array:
	return SHED_ORDER.slice(0, shed_step(density))


# --- The typed ledger (§9, §8): one place other systems query instead of a second ------
# counter. Per-frame effect budgets and pool ceilings from §1.2 and §8.
const LEDGER := {
	"p5_glyphs": 40,             # of the 48 pool; 8 reserved for P2/P3 shapes sharing it
	"hit_sparks": 12,
	"kill_pops_per_250ms": 3,
	"speed_lines_tier3": 20,
	"trails": 1,
	"bodies": 30,
	"bolts": 64,
	"zap_lines": 12,
	"player_rings": 8,
	"pins": 12,
	"chunks": 36,
	"rigs": 3,
	"rule_bands": 3,
	"hostile_fill_union_past": 4,
}


static func cap(kind: String) -> int:
	return int(LEDGER.get(kind, -1))


# --- View helper, shared by every module that samples threats/enemies in view ----------
static func in_view(camera: Camera3D, at: Vector3, reach := 200.0) -> bool:
	if camera == null:
		return false
	if camera.is_position_behind(at) or camera.global_position.distance_to(at) > reach:
		return false
	var p := camera.unproject_position(at)
	var viewport := camera.get_viewport()
	if viewport == null:
		return false
	return Rect2(Vector2.ZERO, viewport.get_visible_rect().size).has_point(p)


static func count_in_view(camera: Camera3D, nodes: Array, reach := 200.0) -> int:
	if camera == null:
		return 0
	var count := 0
	for node in nodes:
		if node is Node3D and in_view(camera, (node as Node3D).global_position, reach):
			count += 1
	return count


# --- Smoothing state (§1.2): 0.25 s rise, 0.6 s fall, so density never flickers --------
class Governor:
	extends RefCounted

	var value := 0.0

	func update(delta: float, threats_in_view: int, fx_alive: int, enemies_in_view: int) -> float:
		# A nested class cannot call the outer script's static funcs unqualified, only
		# its consts, so the raw() formula is inlined here; it must stay identical to raw().
		var target := clampf(THREAT_WEIGHT * float(threats_in_view) / THREAT_SCALE
			+ FX_WEIGHT * float(fx_alive) / FX_SCALE
			+ ENEMY_WEIGHT * float(enemies_in_view) / ENEMY_SCALE, 0.0, 1.0)
		return update_raw(delta, target)

	func update_raw(delta: float, target: float) -> float:
		var seconds: float = RISE_SECONDS if target > value else FALL_SECONDS
		var rate: float = 1.0 / maxf(0.0001, seconds)
		value = move_toward(value, target, rate * delta)
		return value


# --- One shared scalar per frame (§1.2, §8, finding 2/9, fix round 2 finding 4/15) ------
# vfx.gd and bolts.gd each sample the live scene themselves (nothing upstream of this
# unit's write set threads one shared instance through ctx), but they must land on the
# same number, not two independent governors reading different fx counts off different
# cameras. This is that single instance. Fix round 1 let every caller advance the
# Governor immediately, which double-stepped the smoothing every frame (both callers run
# every frame, not just "that one frame" DESIGN-NOTES claimed) and let the first caller
# read a value computed off a partial fx total the second caller hadn't added in yet.
# Now a new frame's first contribute() call advances the Governor once, off the PREVIOUS
# frame's totals (one frame of lag, accepted so every caller in a frame reads the same
# number), then every call that frame only accumulates into the next step; every caller
# reads back the same already-advanced Governor.value.
static var _shared_frame := -1
static var _shared_threats := 0
static var _shared_enemies := 0
static var _shared_fx := 0
static var _shared_gov := Governor.new()
static var _shared_seen_frame := false


static func contribute(delta: float, threats_in_view: int, fx_alive: int, enemies_in_view: int) -> float:
	var frame := Engine.get_process_frames()
	if frame != _shared_frame:
		if _shared_seen_frame:
			_shared_gov.update(delta, _shared_threats, _shared_fx, _shared_enemies)
		_shared_seen_frame = true
		_shared_frame = frame
		_shared_threats = 0
		_shared_enemies = 0
		_shared_fx = 0
	_shared_threats = maxi(_shared_threats, threats_in_view)
	_shared_enemies = maxi(_shared_enemies, enemies_in_view)
	_shared_fx += fx_alive
	return _shared_gov.value


static func shared_density() -> float:
	return _shared_gov.value
