extends SceneTree

const Director := preload("res://src/world/director.gd")
const Cards := preload("res://src/core/director_cards.gd")
const Park := preload("res://src/core/park_defs.gd")
const Alpha := preload("res://src/core/alpha_defs.gd")
const Stage := preload("res://src/core/stage_defs.gd")
const Slice := preload("res://src/core/slice_defs.gd")
const T := preload("res://tests/support/t.gd")
const SEEDS := 20
const SECONDS := 30 * 60
const H := 0.5
const EXPECTED_FIXED_CHECKS := 1126  # 2026-10-23 (w19 Spillway roster): six more park packs priced (dam 5, flume 6), was 1120. 2026-10-19 (W18-PLATEPRESS): two plate_press packs priced, was 1118. 2026-10-18 (W18-PACKS): eight park packs priced, was 1110. 2026-10-18 (W18-DISP): five dispatcher card checks; was 1105. 2026-10-17 (stage/alpha-w16): three Foreman shift packs and two pit jaw packs; was 1100

var _t := T.new("director_credit_test")


func _initialize() -> void:
	for table in [Park, Alpha, Stage, Slice]:
		var defaults := true
		for row in table.DEFS:
			var d = Director.new(0)
			d.use_row(row)
			defaults = defaults and d.get("mode") == "interval"
		_t.check("every %s row defaults to interval" % table.resource_path.get_file(), defaults)
	var probe = Director.new(0)
	var api: bool = probe.get("mode") != null and probe.has_method("income_per_second") and probe.has_method("credit_pack_cost")
	_t.check("credit mode and accounting API exist", api)
	if not api:
		quit(_t.verdict())
		return
	_cards()
	_boundaries()
	_calibration()
	_cap_income_sweep()
	_sweeps()
	_held_crowd_sweep()
	_t.eq("expected check count", _t.checks + 1, EXPECTED_FIXED_CHECKS + Director.KIND_NAMES.size())
	quit(_t.verdict())


func _director(seed_value: int, row: Dictionary, mode: String, terrain := false):
	var d = Director.new(seed_value)
	var source := row.duplicate(true)
	if not terrain:
		source["map"] = ""
	d.use_row(source)
	d.threat = row.get("threat", 1.0)
	d.authored = row.get("packs", [])
	d.elite = row.get("elite", {})
	d.elite_arrival = row.get("elite_arrival", Park.ELITE_ARRIVAL)
	d.set("mode", mode)
	return d


func _cards() -> void:
	var path := "res://src/core/director_cards.gd"
	_t.check("card source exists", ResourceLoader.exists(path))
	if not ResourceLoader.exists(path):
		return
	var cards = load(path)
	for kind in Director.KIND_NAMES:
		var card: Dictionary = cards.CARDS.get(kind, {})
		var cost := float(card.get("cost", 0))
		var weight := float(card.get("weight", 0))
		var stage_cap = card.get("stage_cap", 0)
		var singleton: float = cards.cost([kind])
		_t.check("supported kind %s has a purchasable explicit card" % kind,
			cards.CARDS.size() == Director.KIND_NAMES.size() and is_finite(cost) and cost > 0.0 and is_finite(weight) and weight > 0.0
			and typeof(stage_cap) == TYPE_INT and stage_cap > 0 and is_finite(singleton) and singleton > 0.0,
			"cost=%s weight=%s stage_cap=%s singleton=%s" % [cost, weight, stage_cap, singleton])
	var d = _director(7, Park.of(1), "credit")
	for row in Park.DEFS:
		for pack in row.packs + [row.elite]:
			var price: float = d.credit_pack_cost(pack.kinds, pack == row.elite)
			_t.check("park stage %d pack %s has a finite positive explicit price" % [row.stage, pack.id],
				is_finite(price) and price > 0.0, "kinds=%s price=%s" % [pack.kinds, price])
	var normal := 0.0
	for kind in Park.ELITE.kinds:
		normal += cards.CARDS[kind].cost
	_t.near("elite costs its multiplier", d.credit_pack_cost(Park.ELITE.kinds, true), normal * cards.ELITE_MULTIPLIER)
	_t.check("unknown kinds never receive a fallback price", not is_finite(d.credit_pack_cost(["unpriced"])))
	var oversized := []
	for member in cards.CARDS["chaser"].stage_cap + 1:
		oversized.append("chaser")
	_t.check("stage_cap rejects an oversized kind group", not is_finite(d.credit_pack_cost(oversized)))
	# The dispatcher card (cost 4, stage_cap 1): purchasable alone, INF doubled or unpriced beside it.
	_t.near("a dispatcher costs 4", d.credit_pack_cost(["dispatcher"]), 4.0)
	_t.near("a dispatcher with a chaser costs 5", d.credit_pack_cost(["chaser", "dispatcher"]), 5.0)
	_t.check("two dispatchers in one purchase are INF", not is_finite(d.credit_pack_cost(["dispatcher", "dispatcher"])))
	_t.check("an unpriced kind beside a dispatcher is INF", not is_finite(d.credit_pack_cost(["dispatcher", "unpriced"])))
	_t.near("an elite dispatcher pack doubles", d.credit_pack_cost(["dispatcher"], true), 4.0 * cards.ELITE_MULTIPLIER)
	var expected_price := 0.0
	for kind in Park.PACKS[0].kinds:
		expected_price += cards.CARDS[kind].cost
	_t.near("prices do not scale with dial", d.credit_pack_cost(Park.PACKS[0].kinds), expected_price)
	d.stage_time = 1800.0
	d.spike = true
	_t.near("prices still fixed at highest dial", d.credit_pack_cost(Park.PACKS[0].kinds), expected_price)
	var free = _director(8, {}, "credit")
	free.advance(120.0, 0)
	_t.check("credit also schedules unauthored arrivals", not free.arrivals.is_empty() and free.get("credits_spent") > 0.0)
	free.stage_time = 0.0
	var target_share: float = free.lobber_share()
	var lobbers := 0
	for draw in 2000:
		var pack: Dictionary = free._draw_credit()
		lobbers += int(pack.id == "lobber")
		free._last_pack_id = pack.id
	_t.check("unauthored kind weights preserve the tier-zero lobber share", absf(float(lobbers) / 2000.0 - target_share) <= 0.03, "lobbers=%d/2000 target=%s tolerance=0.03" % [lobbers, target_share])


func _boundaries() -> void:
	for threat in [1.0, 1.4, 100.0]:
		var d = _director(9, Park.of(1), "credit")
		d.threat = threat
		var unchanged := true
		for time in [0.0, 45.0, 90.0, 1800.0]:
			d.stage_time = time
			for spike in [false, true]:
				d.spike = spike
				unchanged = unchanged and d.hp_scale() == threat
		_t.check("credit health stays stage threat %.1f at every dial" % threat, unchanged)
	var d = _director(10, Park.of(1), "credit")
	d.paused = true
	d.advance(30.0, 0)
	_t.check("pause accrues no income and schedules nothing", d.get("credits_accrued") == 0.0 and d.arrivals.is_empty())
	d.paused = false
	d.stage_time = 90.0
	d.advance(30.0, d.cap())
	_t.check("cap binds: no income or purchase", d.get("credits_accrued") == 0.0 and d.get("credits_spent") == 0.0)
	d.set("credits", Cards.CARDS["chaser"].cost)
	d._next_pack = {"id": "reserved_singleton", "kinds": ["chaser"]}
	d.threat = 100.0
	d.advance(H, 23)
	_t.eq("pending fixture creates exactly one future arrival", d.arrivals.size(), 1)
	_t.check("pending fixture arrival is still in the future", d.arrivals.size() == 1 and d.arrivals[0].left > H)
	var spent: float = d.get("credits_spent")
	var accrued: float = d.get("credits_accrued")
	d.advance(H, 23)
	_t.near("live plus reserved cap accrues no income", d.credits_accrued, accrued)
	_t.near("live plus reserved cap spends nothing", d.credits_spent, spent)
	d.advance(H, 24)
	_t.near("external cap never spends more", d.get("credits_spent"), spent)
	var transition = _director(12, Park.of(1), "credit")
	transition.threat = 100.0
	transition.credits = Cards.CARDS["chaser"].cost
	transition._next_pack = {"id": "due_singleton", "kinds": ["chaser"]}
	transition.advance(0.0, 23)
	_t.eq("due fixture creates exactly one reserved arrival", transition.arrivals.size(), 1)
	var transition_spent: float = transition.credits_spent
	var due_now: Array = transition.advance(Director.ARRIVAL, 23)
	_t.eq("reserved arrival becomes exactly one due spawn", due_now.size(), 1)
	_t.check("due transition leaves no pending arrivals", transition.arrivals.is_empty())
	_t.near("live plus due cap accrues no income", transition.credits_accrued, 0.0)
	_t.near("live plus due cap spends nothing", transition.credits_spent, transition_spent)
	var held = _director(11, Park.of(1), "credit")
	held._next_pack = Park.PACKS[1]
	held.credits = 1000.0
	var balance_before: float = held.credits
	var expected_income: float = H * Director.Cards.I0 * (1.0 + Director.Cards.K * 0)
	held.advance(H, held.cap() - 1)
	_t.near("below cap retained pack earns income despite insufficient whole-pack room", held.credits_accrued, expected_income)
	_t.near("below cap retained pack adds income to balance", held.credits, balance_before + expected_income)
	_t.near("below cap retained pack spends nothing", held.credits_spent, 0.0)
	_t.check("below cap retained whole pack waits without placement", held.arrivals.is_empty() and held._next_pack == Park.PACKS[1])
	var park = _director(913, Park.of(1), "credit", true)
	park.play_rect = Rect2(-800, -800, 1600, 1600)
	var at: Vector2 = park._park_map.beacon
	var due := 0
	for step in 120:
		due += park.advance(H, 0, at).size()
	_t.check("credit uses real park corridor-safe fallback", due > 0 and park.get("credits_spent") > 0.0)
	var partial = _director(913, Park.of(1), "credit", true)
	partial.play_rect = park.play_rect
	partial.break_home("culvert_chasers")
	partial._next_pack = Park.PACKS[0]
	var full_price := 0.0
	for kind in Park.PACKS[0].kinds:
		full_price += Cards.CARDS[kind].cost
	var placed_price: float = Cards.CARDS["lobber"].cost
	partial.set("credits", full_price)
	partial.advance(0.0, 0, at)
	_t.check("only queued members are charged after home break", partial.get("credits_spent") == placed_price and partial.arrivals.size() == 1 and partial.packs[0].kinds == ["lobber"])
	partial._next_pack = {"id": "stopped", "kinds": ["chaser"]}
	partial.advance(0.0, 0, at)
	_t.check("zero placed members spend nothing and retain the draw", partial.get("credits_spent") == placed_price and partial._next_pack.id == "stopped")


func _calibration() -> void:
	for dial in [0, 2]:
		var totals := {"interval": 0, "credit": 0}
		for seed_value in SEEDS:
			for mode in ["interval", "credit"]:
				var d = _director(seed_value, Park.of(1), mode)
				for step in int(600.0 / H):
					d.stage_time = dial * Director.TIER_SECONDS
					totals[mode] += d.advance(H, 0).size()
		var baseline: float = float(totals.interval) / SEEDS / 10.0
		var credit: float = float(totals.credit) / SEEDS / 10.0
		var error: float = absf(credit - baseline) / baseline
		print("CALIBRATION tier=%d seeds=%d interval_per_min=%.5f credit_per_min=%.5f error_pct=%.5f threshold_pct=10" % [dial, SEEDS, baseline, credit, error * 100.0])
		_t.check("stage 1 tier %d mean arrivals within 10 percent" % dial, baseline > 0.0 and error <= 0.10)


func _sweeps() -> void:
	var cards = load("res://src/core/director_cards.gd")
	for seed_value in SEEDS:
		for row in Park.DEFS:
			for mode in ["interval", "credit"]:
				var d = _director(seed_value, row, mode)
				d.heft_class = 50
				d.spike = true
				var live: Array[float] = []
				var peak := 0
				var max_reserved := 0
				var integral := 0.0
				for step in int(SECONDS / H):
					var time := step * H
					for death in live.duplicate():
						if death <= time:
							live.erase(death)
					# All rings here are valid future enemies, including arrivals due this step.
					var reserved: int = live.size() + d.arrivals.size()
					var dial := mini(int((time + H) / Director.TIER_SECONDS), Director.clock_tiers(d.dial_stage)) + Director.SPIKE_TIERS
					var capacity: int = mini(24, int(round((6 + dial * 2) * row.threat * row.pressure.pack_scale)) + Director.HEFT_CAP_STEP * (50 - 1))
					if mode == "credit" and not d.paused and reserved < capacity:
						integral += H * cards.I0 * (1.0 + cards.K * dial)
					var due: Array = d.advance(H, live.size())
					for _spawn in due:
						live.append(time + 18.0 + seed_value % 7)
					peak = maxi(peak, live.size())
					max_reserved = maxi(max_reserved, live.size() + d.arrivals.size())
				_t.check("seed %d stage %d %s hard cap 24 including rings" % [seed_value, row.stage, mode], max_reserved <= 24, "peak=%d reserved=%d" % [peak, max_reserved])
				if mode == "credit":
					var earned: float = d.get("credits_accrued")
					var spent: float = d.get("credits_spent")
					var error: float = absf(spent - earned) / maxf(earned, 0.0001)
					_t.check("seed %d stage %d spending within 5 percent of accrued income" % [seed_value, row.stage], earned > 0.0 and error <= 0.05, "income=%.5f spent=%.5f error_pct=%.5f" % [earned, spent, error * 100.0])
					_t.near("seed %d stage %d independent income integral" % [seed_value, row.stage], earned, integral, 0.00001)
					_t.near("seed %d stage %d balance conserved" % [seed_value, row.stage], earned - spent, d.get("credits"), 0.00001)
				print("PEAK seed=%d stage=%d mode=%s alive=%d reserved=%d seconds=%d" % [seed_value, row.stage, mode, peak, max_reserved, SECONDS])


func _cap_income_sweep() -> void:
	# A four-member pack fills 24 exactly, isolating cap binding from retained-pack room.
	for seed_value in SEEDS:
		var d = _director(seed_value, Park.of(1), "credit")
		d.authored = [Park.PACKS[0]]
		d.elite = {}
		d.elite_arrival = 0
		d.heft_class = 50
		d.spike = true
		var live: Array[float] = []
		var integral := 0.0
		var peak_reserved := 0
		for step in int(SECONDS / H):
			var time := step * H
			for death in live.duplicate():
				if death <= time:
					live.erase(death)
			var reserved: int = live.size() + d.arrivals.size()
			var dial := mini(int((time + H) / Director.TIER_SECONDS), Director.clock_tiers(d.dial_stage)) + Director.SPIKE_TIERS
			if reserved < 24:
				integral += H * Cards.I0 * (1.0 + Cards.K * dial)
			for _spawn in d.advance(H, live.size()):
				live.append(maxf(900.0, time + 18.0 + seed_value % 7))
			peak_reserved = maxi(peak_reserved, live.size() + d.arrivals.size())
		var earned: float = d.credits_accrued
		var spent: float = d.credits_spent
		var error := absf(spent - earned) / maxf(earned, 0.0001)
		_t.check("cap accounting seed %d hard cap reached and respected" % seed_value, peak_reserved == 24)
		_t.check("cap accounting seed %d spending within 5 percent of accrued income" % seed_value,
			earned > 0.0 and error <= 0.05, "income=%.5f spent=%.5f error_pct=%.5f" % [earned, spent, error * 100.0])
		_t.near("cap accounting seed %d independent income integral" % seed_value, earned, integral, 0.00001)
		_t.near("cap accounting seed %d balance conserved" % seed_value, earned - spent, d.credits, 0.00001)


func _held_crowd_sweep() -> void:
	for seed_value in SEEDS:
		for row in Park.DEFS:
			var d = _director(seed_value, row, "credit")
			d.heft_class = 50
			d.spike = true
			var live: Array[float] = []
			var integral := 0.0
			var held_income := 0.0
			var held_integral := 0.0
			var held_balance := 0.0
			var held_spent := 0.0
			var release_spawns := 0
			var steady_spawns := 0
			for step in int(SECONDS / H):
				var time := step * H
				if time == 900.0:
					held_income = d.credits_accrued
					held_integral = integral
					held_balance = d.credits
					held_spent = d.credits_spent
				for death in live.duplicate():
					if death <= time:
						live.erase(death)
				var reserved: int = live.size() + d.arrivals.size()
				var dial := mini(int((time + H) / Director.TIER_SECONDS), Director.clock_tiers(d.dial_stage)) + Director.SPIKE_TIERS
				if reserved < 24:
					integral += H * Cards.I0 * (1.0 + Cards.K * dial)
				var due: Array = d.advance(H, live.size())
				for _spawn in due:
					live.append(maxf(900.0, time + 18.0 + seed_value % 7))
				if time >= 900.0 and time < 960.0:
					release_spawns += due.size()
				if time >= 1200.0:
					steady_spawns += due.size()
			_t.check("hold seed %d stage %d accumulation agrees with integral and balance" % [seed_value, row.stage],
				held_balance > 0.0 and absf(held_income - held_integral) <= 0.00001
				and absf(held_income - held_spent - held_balance) <= 0.00001,
				"income=%.5f integral=%.5f spent=%.5f balance=%.5f" % [held_income, held_integral, held_spent, held_balance])
			_t.near("hold seed %d stage %d independent income integral" % [seed_value, row.stage], d.credits_accrued, integral, 0.00001)
			_t.near("hold seed %d stage %d balance conserved" % [seed_value, row.stage], d.credits_accrued - d.credits_spent, d.credits, 0.00001)
			var steady_per_min := float(steady_spawns) / 10.0
			var ratio := float(release_spawns) / steady_per_min if steady_per_min > 0.0 else INF
			print("HOLD seed=%d stage=%d release_900_960_spawns=%d steady_1200_1800_spawns=%d steady_per_min=%.5f flood_ratio=%.5f" % [seed_value, row.stage, release_spawns, steady_spawns, steady_per_min, ratio])
