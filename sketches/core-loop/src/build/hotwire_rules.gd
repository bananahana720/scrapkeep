extends RefCounted

# The two hot-wired parts' numbers, in one place. Since the fold (systems audit pass D, Andrew
# 11 Nov 2026) a hot-wired part is a rare part on the ladder: the first Warden broken in each
# world puts it up as a striped gate beside the pair, with no Fit / Recycle screen, and it waits
# at the gates until it is taken (build.gd). Its card words are filled from the numbers here.
#
# H1, Riveted Shell: held, the armour goes RIVETED_ARMOUR times as far per scrap again and
# airborne steering takes RIVETED_AIR_FACTOR again (build.gd shell_rest_factor).
const RIVETED_ARMOUR := 2.0
const RIVETED_AIR_FACTOR := 0.75

# Hot-wired H2, Spark Tread (design-v3/research/build-systems/BUILD-SYSTEMS.md, H2): a small
# pure activation table that build.gd reads. Fitted when the run holds the part and
# --hotwire-tread is not off. While fitted, the first eligible attack after each RECOVERY
# seconds deals BONUS more direct damage, if the ball rolls at least MIN_CRUISE_SHARE of
# cruise and has mass left; ordinary rolling wear runs at WEAR_SCALE. Zero mass switches the
# bonus off, never the wear rule (wear takes nothing at zero mass anyway).
#
# Eligible kinds are the ball's own signature contacts, a ram, a slam and a stomp, one per
# attack: every strike of the same kind in the same physics frame shares one activation.
# The per-pilot list in BUILD-SYSTEMS.md (Sable's vault discharge and first weapon hit after a
# slingshot, Kest's throw) has no strike kind of its own yet, so it is not read here.

const PART := "spark_tread"
const BONUS := 0.75
const RECOVERY := 3.0
const MIN_CRUISE_SHARE := 0.5
const WEAR_SCALE := 2.0
const ELIGIBLE := ["ram", "slam", "stomp"]


static func fitted(parts: Array, flag: String) -> bool:
	return PART in parts and flag != "off"


static func wear_scale(is_fitted: bool) -> float:
	return WEAR_SCALE if is_fitted else 1.0


# True when this attack takes the bonus: an eligible kind, the recovery spent, rolling fast
# enough and mass left.
static func eligible(kind: String, recovery_left: float, speed: float, cruise: float, mass: float) -> bool:
	return kind in ELIGIBLE and recovery_left <= 0.0 and mass > 0.0 and cruise > 0.0 \
		and speed >= cruise * MIN_CRUISE_SHARE


# The extra direct damage on top of an attack's own punch.
static func bonus_damage(punch: float) -> float:
	return punch * BONUS


# A hot-wired row's words with its numbers filled in: {armor}, {armor_x}, {steer}, {wear},
# {wear_x} and {bonus}.
static func fill(text: String) -> String:
	var mult_text := _times(RIVETED_ARMOUR)
	var wear_text := _times(WEAR_SCALE)
	return text.replace("{armor}", "Double" if is_equal_approx(RIVETED_ARMOUR, 2.0) else mult_text + "x") \
		.replace("{armor_x}", mult_text).replace("{steer}", str(int(round((1.0 - RIVETED_AIR_FACTOR) * 100.0)))) \
		.replace("{wear}", "Double" if is_equal_approx(WEAR_SCALE, 2.0) else wear_text + "x") \
		.replace("{wear_x}", wear_text).replace("{bonus}", str(int(round(BONUS * 100.0))))


static func _times(value: float) -> String:
	return "%d" % int(value) if is_equal_approx(value, round(value)) else "%.1f" % value
