extends SceneTree

const Director := preload("res://src/world/director.gd")
const Cards := preload("res://src/world/director_cards.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const T := preload("res://tests/support/t.gd")

# KE9, the credit director. On a park table, authored arrivals are paid from a credit balance that
# income refills at I0 * (1 + K * effective_tier()); the alpha table keeps the interval clock. Checks:
# the income formula and its inputs; the mode each table gets; a calibration against today's interval
# rate on park stage 1 at tiers 0 and 2 (within 10 percent); credits spent within 5 percent of the
# income integral over 30 stepped minutes on 20 seeds, with never more than HARD_CAP enemies alive;
# and card prices for every authored pack. Health stays on the stage threat (checked in _check_health).
# Expected check count: 22. The test fails on any other count.

const H := 1.0 / 30.0
const CALIBRATE_SECONDS := 600.0
const SWEEP_SECONDS := 1800.0
const SEEDS := 20
const CAP_SECONDS := 300.0
const LIFETIME := 20.0
const CALIBRATE_TOLERANCE := 0.10
const SPEND_TOLERANCE := 0.05
const EXPECTED_CHECKS := 22

var _t := T.new("director_credit_test")


func _initialize() -> void:
	_check_income()
	_check_mode()
	_check_cards()
	_check_calibration()
	_check_conservation()
	_check_hard_cap()
	_check_health()
	if _t.checks != EXPECTED_CHECKS:
		print("director_credit_test: FAIL (%d checks, expected %d)" % [_t.checks, EXPECTED_CHECKS])
		quit(1)
		return
	quit(_t.verdict())


# A park-table director on stage 1, the park row's threat and pacing, in the given mode.
func _park_director(seed_value: int, mode: String) -> Director:
	var row: Dictionary = ParkDefs.of(1)
	var d := Director.new(seed_value)
	d.use_row(row, "")
	d.threat = float(row["threat"])
	d.play_rect = Rect2(-1000.0, -1000.0, 2000.0, 2000.0)
	# The world's _author_director wiring: the park table's packs and elite reach the director.
	d.authored = ParkDefs.packs()
	d.elite = ParkDefs.elite()
	d.elite_arrival = ParkDefs.elite_arrival()
	d.mode = mode
	return d


# Holds the tier at 0 or 2 by pinning stage_time before each step.
func _packs_per_minute(d: Director, tier: int, seconds: float) -> float:
	var steps := int(seconds / H)
	var stage_time := 0.0 if tier == 0 else 90.0
	for i in steps:
		d.stage_time = stage_time
		d.advance(H, 0)
	return float(d.packs.size()) / (seconds / 60.0)


func _check_income() -> void:
	var d := Director.new(1)
	d.threat = 1.0
	for tier in [0, 1, 2]:
		d.stage_time = 0.0 if tier == 0 else (45.0 if tier == 1 else 90.0)
		var want: float = Director.CREDIT_I0 * (1.0 + Director.CREDIT_K * float(tier))
		_t.near("income at tier %d" % tier, d.income(), want, 0.000001)
	d.threat = 1.5
	d.stage_time = 0.0
	_t.near("income ignores threat", d.income(), Director.CREDIT_I0, 0.000001)


func _check_mode() -> void:
	var alpha := Director.new(2)
	alpha.use_row(AlphaDefs.of(1), "")
	_t.eq("alpha table keeps the interval clock", alpha.mode, "interval")
	var park := _park_director(3, "credit")
	park.use_row(ParkDefs.of(1), "")
	_t.eq("park table runs credit", park.mode, "credit")
	Director.mode_override = "interval"
	var forced := Director.new(4)
	forced.use_row(ParkDefs.of(1), "")
	_t.eq("--director=interval overrides the park table", forced.mode, "interval")
	Director.mode_override = ""


func _check_cards() -> void:
	var packs: Array = ParkDefs.packs()
	var all_priced := true
	for pack in packs:
		if Cards.cost_of(pack) <= 0.0:
			all_priced = false
	_t.check("every authored pack has a positive card cost", all_priced)
	var elite: Dictionary = ParkDefs.elite()
	_t.near("elite cost is the elite multiplier times its members", Cards.cost_of(elite, true),
		Cards.ELITE_MULT * Cards.base_cost(elite["kinds"]), 0.000001)


func _check_calibration() -> void:
	for tier in [0, 2]:
		var interval_rate := _packs_per_minute(_park_director(1, "interval"), tier, CALIBRATE_SECONDS)
		var credit_rate := _packs_per_minute(_park_director(1, "credit"), tier, CALIBRATE_SECONDS)
		var gap := absf(credit_rate - interval_rate) / maxf(interval_rate, 0.0001)
		_t.check("tier %d credit rate within 10 percent of today's interval rate" % tier,
			gap <= CALIBRATE_TOLERANCE and interval_rate > 0.0 and credit_rate > 0.0,
			"interval %.2f, credit %.2f packs per minute, gap %.3f" % [interval_rate, credit_rate, gap])


func _check_conservation() -> void:
	var worst_gap := 0.0
	var least_spent := INF
	var max_alive := 0
	var identity_ok := true
	var steps := int(SWEEP_SECONDS / H)
	for seed_index in SEEDS:
		var d := _park_director(seed_index + 1, "credit")
		var recent: Array[float] = []
		var now := 0.0
		for i in steps:
			now += H
			while not recent.is_empty() and recent[0] < now - LIFETIME:
				recent.pop_front()
			var due := d.advance(H, recent.size(), Vector2.ZERO)
			for spawn in due:
				recent.append(now)
			max_alive = maxi(max_alive, recent.size())
		var income: float = d.credit_income
		var spent: float = d.credit_spent
		least_spent = minf(least_spent, spent)
		worst_gap = maxf(worst_gap, absf(income - spent) / maxf(income, 0.0001))
		if absf(spent + d.credits + d.credit_overflow - income) > 0.000001:
			identity_ok = false
	_t.check("credits spent within 5 percent of the income integral, 20 seeds, 30 minutes",
		worst_gap <= SPEND_TOLERANCE and least_spent > 0.0,
		"worst gap %.4f, least spent %.1f credits" % [worst_gap, least_spent])
	_t.check("spent, balance and overflow add up to the income integral", identity_ok)
	_t.check("never more than HARD_CAP alive", max_alive <= Director.HARD_CAP,
		"peak alive %d of cap %d" % [max_alive, Director.HARD_CAP])


#  The cap is reached at the top tier with a spiked, heavy ball: 24 alive, never more, with the bank
# kept full so only the cap can hold a pack. The check fails if the cap never reaches HARD_CAP.
func _check_hard_cap() -> void:
	var d := _park_director(11, "credit")
	d.threat = 1.5
	d.spike = true
	d.heft_class = 3
	d.stage_time = 90.0
	_t.eq("cap reaches HARD_CAP at the top tier, spiked, heavy ball", d.cap(), Director.HARD_CAP)
	var recent: Array[float] = []
	var now := 0.0
	var peak := 0
	var over := false
	for i in int(CAP_SECONDS / H):
		now += H
		while not recent.is_empty() and recent[0] < now - LIFETIME:
			recent.pop_front()
		d.credits = Director.CREDIT_BANK
		for spawn in d.advance(H, recent.size(), Vector2.ZERO):
			recent.append(now)
		peak = maxi(peak, recent.size())
		over = over or recent.size() + d.arrivals.size() > Director.HARD_CAP
	_t.check("alive plus pending never exceeds HARD_CAP, and the cap is reached",
		not over and peak >= Director.HARD_CAP - 4,
		"peak alive %d of cap %d" % [peak, Director.HARD_CAP])


# Health reads the stage threat after credits were spent, at tier 0 and at the spiked top tier. The
# planted control: income differs from the threat, so a hp_scale that read income would fail the equality.
func _check_health() -> void:
	for start in [0.0, 90.0]:
		var d := _park_director(7, "credit")
		d.threat = 1.5
		d.spike = start > 0.0
		d.stage_time = start
		for i in int(300.0 / H):
			d.advance(H, 0)
		_t.check("credits were spent before the health read (start %d s)" % int(start), d.credit_spent > 0.0)
		_t.near("health equals the threat after credit spend, effective tier %d" % d.effective_tier(),
			d.hp_scale(), 1.5, 0.000001)
		_t.check("planted control: income differs from the threat", absf(d.income() - d.threat) > 0.1,
			"income %.3f, threat %.2f" % [d.income(), d.threat])
