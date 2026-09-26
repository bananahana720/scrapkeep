extends RefCounted

# Every number the stage loop argues about lives here, so the tier clock, the
# caches, the director and combat cannot drift apart. Nothing here touches the
# ball's movement tuning, which is the accepted ball-lab feel.

const TIER_SECONDS := 45.0
const CHARGE_SECONDS := 60.0
const CHARGE_RADIUS := 30.0

const PLAYER_HP := 100.0
const REGEN_DELAY := 5.0
const REGEN_RATE := 7.0

const MAGNET_RANGE := 6.0
const PICKUP_RANGE := 1.9
const SCRAP_PER_PICKUP := 1

const RAM_DAMAGE_PER_SPEED := 1.7
const STOMP_DAMAGE := 26.0

const FOES := {
	"chaser": {"hp": 26.0, "speed": 7.0, "contact": 9.0, "scrap": 3, "scale": 1.0},
	"lobber": {"hp": 18.0, "speed": 0.0, "contact": 6.0, "scrap": 4, "scale": 1.1},
	"miniboss": {"hp": 260.0, "speed": 6.0, "contact": 20.0, "scrap": 30, "scale": 2.4},
}


# RoR2's cost curve in miniature: the same cache costs steeply more the longer you
# stay, which is the whole question this sketch exists to ask.
static func cache_cost(tier: int) -> int:
	return int(round(25.0 * pow(maxf(1.0, float(tier)), 1.25)))


static func foe_health(kind: String, tier: int) -> float:
	return float(FOES[kind]["hp"]) * (1.0 + 0.32 * (tier - 1))


static func foe_contact_damage(kind: String, tier: int) -> float:
	return float(FOES[kind]["contact"]) * (1.0 + 0.18 * (tier - 1))


static func spawn_interval(tier: int, charging: bool) -> float:
	var interval: float = 7.0 / (1.0 + 0.45 * (tier - 1))
	return interval * 0.4 if charging else interval


static func spawn_budget(tier: int, charging: bool) -> int:
	var cap := 6 + 3 * (tier - 1)
	return mini(30, cap * 2 if charging else cap)


static func lobber_share(tier: int) -> float:
	return clampf(0.15 + 0.07 * (tier - 1), 0.0, 0.5)


static func tier_of(stage_time: float) -> int:
	return 1 + int(stage_time / TIER_SECONDS)
