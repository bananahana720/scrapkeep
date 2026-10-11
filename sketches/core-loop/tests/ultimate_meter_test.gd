extends SceneTree

const T := preload("res://tests/support/t.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")

# The ultimate meter's rules (design-v3/SKILL-BAR.md section 4 and section 9), wave P-B unit
# B3, 2026-10-10. Pure rules, no scene: the weights per source, the weapon rate limit, the cap
# with overflow lost, no decay, speed by tier, the lock while a set piece rides, spend and
# refund, and the stage-entry mark a retry restores. Loaded by path so the red run fails loud
# on a missing file. Evidence limit: the rule, not a played fill time (B4's bots own those).

var _t := T.new("ultimate_meter_test")


func _initialize() -> void:
	var Meter = load("res://src/core/ultimate_meter.gd")
	_t.check("00 the meter script loads", Meter != null)
	if Meter == null:
		quit(_t.verdict())
		return
	var m = Meter.new()

	# 1. The constants of section 9.
	_t.eq("01 cap 100, weapon rate cap 0.4 per s", [m.CAP, m.WEAPON_RATE_CAP], [100.0, 0.4])
	_t.eq("02 the weights of section 4", [m.WEIGHTS["weapon"], m.WEIGHTS["contact"], m.WEIGHTS["smash"], m.WEIGHTS["chain_link"],
		m.WEIGHTS["near_miss"], m.WEIGHTS["kill"], m.WEIGHTS["stagger"], m.WEIGHTS["shatter"], m.WEIGHTS["fast"], m.WEIGHTS["blazing"]],
		[0.25, 2.0, 5.0, 2.0, 4.0, 1.0, 8.0, 12.0, 0.5, 1.2])

	# 2. Each discrete source adds its weight times the amount.
	m.reset()
	m.add("contact")
	m.add("smash", 2.5)
	m.add("chain_link")
	m.add("near_miss")
	m.add("kill")
	m.add("stagger")
	m.add("shatter")
	_t.near("03 contact 2 + smash 5 x2.5 + link 2 + near miss 4 + kill 1 + stagger 8 + shatter 12", m.value, 41.5)
	_t.eq("04 sources keep points by source", [m.sources["contact"], m.sources["smash"], m.sources["shatter"]], [2.0, 12.5, 12.0])
	_t.eq("05 an unknown source adds nothing", m.add("bogus"), 0.0)

	# 3. Weapon hits: 0.25 each, but never more than 0.4 points a second over time.
	m.reset()
	for i in 1200:
		m.tick(0.1, SpeedTier.CRUISE)
		for k in 2:
			m.add("weapon")
	_t.check("06 120 s of 20 hits a second pays at most 0.4 per s", m.value <= 0.4 * 120.0 + 0.5 + 0.0001 and m.value >= 0.4 * 120.0 - 0.5,
		"%.3f points" % m.value)
	m.reset()
	m.add("weapon")
	_t.near("07 one fresh weapon hit pays its 0.25", m.value, 0.25)
	m.reset()
	for i in 1800:
		m.tick(0.1, SpeedTier.CRUISE)
		for k in 5:
			m.add("weapon")
	_t.check("08 the hold-fire camper on weapons alone needs 180 s or more for a full meter", m.value < m.CAP,
		"%.1f points after 180 s" % m.value)

	# 4. Speed by tier: fast 0.5 per s, blazing 1.2 per s, cruise nothing.
	m.reset()
	for i in 100:
		m.tick(0.1, SpeedTier.FAST)
	var fast: float = m.value
	m.reset()
	for i in 100:
		m.tick(0.1, SpeedTier.BLAZING)
	var blazing: float = m.value
	m.reset()
	for i in 100:
		m.tick(0.1, SpeedTier.CRUISE)
	_t.check("09 10 s fast pays 5, blazing 12, cruise 0", absf(fast - 5.0) < 0.001 and absf(blazing - 12.0) < 0.001 and m.value == 0.0,
		"fast %.3f, blazing %.3f, cruise %.3f" % [fast, blazing, m.value])

	# 5. Cap at 100, overflow lost, full() and fraction().
	m.reset()
	for i in 8:
		m.add("shatter")
	var before_full: bool = m.full()
	var got: float = m.add("shatter")
	_t.check("10 the cap holds at 100 and the overflow is lost", m.value == 100.0 and absf(got - 4.0) < 0.001 and not before_full,
		"value %.2f, the last add paid %.2f" % [m.value, got])
	_t.eq("11 full and fraction at the cap", [m.full(), m.fraction()], [true, 1.0])
	_t.eq("12 a full meter takes no more", m.add("kill"), 0.0)

	# 6. No decay: time alone at walk speed never drains it.
	m.reset()
	m.add("stagger")
	for i in 600:
		m.tick(0.1, SpeedTier.WALK)
	_t.near("13 no decay over 60 s", m.value, 8.0)

	# 7. Locked (a set piece rides): nothing fills it.
	m.locked = true
	m.add("shatter")
	m.tick(1.0, SpeedTier.BLAZING)
	_t.near("14 a locked meter does not fill", m.value, 8.0)
	m.locked = false

	# 8. Spend and refund.
	m.reset()
	_t.eq("15 spend refuses below full", [m.spend(), m.value], [false, 0.0])
	for i in 9:
		m.add("shatter")
	m.add("stagger")
	_t.eq("16 spend at full empties it", [m.spend(), m.value], [true, 0.0])
	m.refund(m.CAP)
	_t.eq("17 a full refund fills it again", [m.value, m.full()], [100.0, true])
	m.refund(50.0)
	_t.eq("18 a refund never passes the cap", m.value, 100.0)

	# 9. Stage entry and retry.
	m.reset()
	m.add("stagger")
	m.mark_entry()
	m.add("shatter")
	m.locked = true
	m.restore_entry()
	_t.eq("19 a retry restores the stage-entry value and unlocks", [m.value, m.locked], [8.0, false])
	m.reset()
	_t.eq("20 a new run starts at 0 with no sources", [m.value, m.sources], [0.0, {}])

	quit(_t.verdict())
