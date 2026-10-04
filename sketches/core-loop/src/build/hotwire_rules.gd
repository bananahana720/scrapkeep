extends RefCounted

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
