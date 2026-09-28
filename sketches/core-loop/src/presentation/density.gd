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
# Bands are inclusive of their lower edge; density 1.0 stays in the top band.
const BANDS := [
	{"max": 0.4, "alpha": 0.9, "size": 1.0, "lifetime": 1.0, "ambient": "on",
		"coalesce_ms": 0, "coalesce_m": 0.0, "scale_per_extra": 0.0, "scale_cap": 1.0},
	{"max": 0.7, "alpha": 0.6, "size": 0.85, "lifetime": 0.7, "ambient": "quarter",
		"coalesce_ms": 120, "coalesce_m": 4.0, "scale_per_extra": 1.2, "scale_cap": 2.5},
	{"max": 1.01, "alpha": 0.35, "size": 0.7, "lifetime": 0.5, "ambient": "off",
		"coalesce_ms": 200, "coalesce_m": 6.0, "scale_per_extra": 1.2, "scale_cap": 2.5},
]


static func band(density: float) -> Dictionary:
	for b in BANDS:
		if density < float(b["max"]):
			return b
	return BANDS[BANDS.size() - 1]


static func alpha_cap(density: float) -> float:
	return float(band(density)["alpha"])


static func size_cap(density: float) -> float:
	return float(band(density)["size"])


static func lifetime_cap(density: float) -> float:
	return float(band(density)["lifetime"])


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
# lifetime already start at 1.0.
static func alpha_factor(density: float) -> float:
	return alpha_cap(density) / alpha_cap(0.0)


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


# How many steps of SHED_ORDER are in effect at this density: 0 below 0.4, climbing to
# every step by density 1.0. Always a prefix of SHED_ORDER, never skips or reorders.
static func shed_step(density: float) -> int:
	if density < 0.4:
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
