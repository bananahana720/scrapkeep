extends SceneTree

# 2026-10-11 (PC-TARN ruling 2): contact gets a rate budget; 32 checks including the contact stream and the pinned cap and burst.

const T := preload("res://tests/support/t.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")

# The ultimate meter's rules (design-v3/SKILL-BAR.md section 4 and section 9), wave P-B unit
# B3, 2026-10-10. Pure rules, no scene: the weights per source, the weapon rate limit, the cap
# with overflow lost, no decay, speed by tier, the lock while a set piece rides, spend and
# refund, and the stage-entry mark a retry restores. Loaded by path so the red run fails loud
# on a missing file. Evidence limit: the rule, not a played fill time (B4's bots own those).
# 2026-10-11 (w13 B3b): near misses get a rate limit like weapon hits (NEAR_MISS_RATE_CAP 0.05
# points per s, NEAR_MISS_BURST 4.0, one near miss). B4's bot measured the hold-fire camper's
# median first fill at 41.1 s over seeds 1 to 16 against the 180 s band, 69 to 95 of its first
# 100 points from near misses at 4.0 each. Check 01 follows the new constants; checks 21 to 24 are
# the camper-path cap and the chainer stream.
# 2026-10-11 (w13 B3b, second change): a chain link pays once per enemy per CHAIN_LINK_GAP
# (1.0 s of meter time; UltimateMeter.chain_link). Tally's losing seeds 1, 3 and 4 at the Brindle
# boss earned 852 to 2719 chain_link points in one run, biting the same boss about 13 times a
# second. A first try paid once per enemy per chain: seeds 2 to 4 won but seed 1 stalled at the
# Brindle boss with 2 set pieces in 420 s, while the base meter won it with 24 in the run. Checks
# 25 to 28; check 24's chainer links three distinct enemies a chain.

var _t := T.new("ultimate_meter_test")


func _initialize() -> void:
	var Meter = load("res://src/core/ultimate_meter.gd")
	_t.check("00 the meter script loads", Meter != null)
	if Meter == null:
		quit(_t.verdict())
		return
	var m = Meter.new()

	# 1. The constants of section 9.
	_t.eq("01 cap 100, weapon rate cap 0.4 per s, near miss rate cap 0.05 per s holding 4", [m.CAP, m.WEAPON_RATE_CAP,
		m.get("NEAR_MISS_RATE_CAP"), m.get("NEAR_MISS_BURST")], [100.0, 0.4, 0.05, 4.0])
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

	# 10. The camper path is capped (w13 B3b): near misses at the old camper rate, one every 2 s for
	# 60 s (120 points at 4.0 each unlimited), pay at most 50.
	m.reset()
	for i in 600:
		m.tick(0.1, SpeedTier.CRUISE)
		if i % 20 == 0:
			m.add("near_miss")
	_t.check("21 a near miss every 2 s for 60 s pays at most 50 points", m.value <= 50.0, "%.2f points" % m.value)
	m.reset()
	for i in 1800:
		m.tick(0.1, SpeedTier.CRUISE)
		if i % 10 == 0:
			m.add("near_miss")
	_t.check("22 a near miss every second for 180 s pays at most 4 + 0.05 per s", m.value <= 4.0 + 0.05 * 180.0 + 0.0001,
		"%.2f points" % m.value)
	m.reset()
	m.add("near_miss")
	for i in 800:
		m.tick(0.1, SpeedTier.CRUISE)
	_t.near("23 after 80 s quiet a near miss pays its full 4 again", m.add("near_miss"), 4.0)

	# 11. The chainer still fills fast: every 6 s a smash on a x2 chain and two chain links, blazing
	# throughout, a near miss every 3 s, fills in under 60 s.
	m.reset()
	var filled_at := -1.0
	for i in 600:
		m.tick(0.1, SpeedTier.BLAZING)
		if i % 60 == 0:
			m.add("smash", 2.0)
			_link(m, 1, 1)
			_link(m, 2, 2)
			_link(m, 3, 3)
		if i % 30 == 0:
			m.add("near_miss")
		if m.full() and filled_at < 0.0:
			filled_at = float(i + 1) * 0.1
	_t.check("24 a chaining stream fills in under 60 s", filled_at > 0.0 and filled_at < 60.0, "full at %.1f s, %.1f points" % [filled_at, m.value])

	# 12. A chain link pays once per enemy per CHAIN_LINK_GAP (1.0 s); combo 1 pays nothing.
	_t.check("25 the meter has chain_link(enemy_id, combo) and CHAIN_LINK_GAP 1.0", m.has_method("chain_link")
		and m.get("CHAIN_LINK_GAP") == 1.0)
	m.reset()
	_link(m, 7, 1)
	var bite := 2
	for i in 100:
		m.tick(0.1, SpeedTier.CRUISE)
		_link(m, 7, bite)
		bite += 1
	_t.check("26 ten bites a second on one enemy for 10 s pay one link a second", m.value <= 2.0 * 11.0 + 0.0001 and m.value >= 2.0 * 9.0,
		"%.2f points" % m.value)
	m.reset()
	for k in 4:
		_link(m, 10 + k, k + 1)
	_link(m, 11, 5)
	_t.near("27 four distinct enemies in one chain pay three links; a repeat inside the gap pays nothing", m.value, 6.0)
	for i in 11:
		m.tick(0.1, SpeedTier.CRUISE)
	_link(m, 11, 6)
	_t.near("28 the same enemy pays again once the gap has passed", m.value, 8.0)

	m.reset()
	var contact_cap = m.get("CONTACT_RATE_CAP")
	var contact_burst = m.get("CONTACT_BURST")
	var contact_seconds := 60.0
	for i in int(contact_seconds * 2.0):
		m.tick(0.5, SpeedTier.CRUISE)
		m.add("contact")
	_t.check("29 two contacts per second stay within the contact rate plus burst", contact_cap != null and contact_burst != null
		and m.value <= float(contact_cap) * contact_seconds + float(contact_burst) + 0.0001,
		"%.3f points over %.1f s, cap %s, burst %s" % [m.value, contact_seconds, contact_cap, contact_burst])
	# PC-TARN ruling values (2026-10-11), chosen against the skill-bar pacing run. Check 29 holds for any
	# cap, so these pin the numbers; re-pin with a new pacing receipt.
	_t.near("30 contact cap is the PC-TARN ruling value", float(contact_cap) if contact_cap != null else -1.0, 0.14)
	_t.near("31 contact burst is the PC-TARN ruling value", float(contact_burst) if contact_burst != null else -1.0, 2.0)

	quit(_t.verdict())


# The meter's chain-link entry, or the plain add before it existed (the red run).
func _link(meter, enemy_id: int, combo: int) -> void:
	if meter.has_method("chain_link"):
		meter.chain_link(enemy_id, combo)
	elif combo > 1:
		meter.add("chain_link")
