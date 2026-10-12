extends SceneTree

const Director := preload("res://src/world/director.gd")
const Park := preload("res://src/core/park_defs.gd")
const Alpha := preload("res://src/core/alpha_defs.gd")
const Stage := preload("res://src/core/stage_defs.gd")
const Slice := preload("res://src/core/slice_defs.gd")
const T := preload("res://tests/support/t.gd")
const SEEDS := 20
const SECONDS := 30 * 60
const H := 0.5
const EXPECTED_CHECKS := 674

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
	_sweeps()
	_t.eq("expected check count", _t.checks + 1, EXPECTED_CHECKS)
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
	var path := "res://src/world/director_cards.gd"
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
			cards.CARDS.size() == 22 and is_finite(cost) and cost > 0.0 and is_finite(weight) and weight > 0.0
			and typeof(stage_cap) == TYPE_INT and stage_cap > 0 and is_finite(singleton) and singleton > 0.0,
			"cost=%s weight=%s stage_cap=%s singleton=%s" % [cost, weight, stage_cap, singleton])
	var d = _director(7, Park.of(1), "credit")
	for row in Park.DEFS:
		for pack in row.packs + [row.elite]:
			var price: float = d.credit_pack_cost(pack.kinds, pack == row.elite)
			_t.check("park stage %d pack %s has a finite positive explicit price" % [row.stage, pack.id],
				is_finite(price) and price > 0.0, "kinds=%s price=%s" % [pack.kinds, price])
	var normal: float = d.credit_pack_cost(Park.ELITE.kinds, false)
	_t.near("elite costs its multiplier", d.credit_pack_cost(Park.ELITE.kinds, true), normal * cards.ELITE_MULTIPLIER)
	_t.check("unknown kinds never receive a fallback price", not is_finite(d.credit_pack_cost(["unpriced"])))
	_t.check("stage_cap rejects an oversized kind group", not is_finite(d.credit_pack_cost(["chaser", "chaser", "chaser", "chaser", "chaser"])))
	_t.near("prices do not scale with dial", d.credit_pack_cost(Park.PACKS[0].kinds), 5.0)
	d.stage_time = 1800.0
	d.spike = true
	_t.near("prices still fixed at highest dial", d.credit_pack_cost(Park.PACKS[0].kinds), 5.0)
	var free = _director(8, {}, "credit")
	free.advance(120.0, 0)
	_t.check("credit also schedules unauthored arrivals", not free.arrivals.is_empty() and free.get("credits_spent") > 0.0)
	free.stage_time = 0.0
	var lobbers := 0
	for draw in 2000:
		var pack: Dictionary = free._draw_credit()
		lobbers += int(pack.id == "lobber")
		free._last_pack_id = pack.id
	_t.check("unauthored kind weights preserve the tier-zero lobber share", absf(float(lobbers) / 2000.0 - 0.15) <= 0.03, "lobbers=%d/2000 target=0.15 tolerance=0.03" % lobbers)


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
	d.set("credits", 1000.0)
	d.threat = 100.0
	d.advance(H, 23)
	_t.check("pending arrivals reserve room at hard cap", d.arrivals.size() <= 1)
	var spent: float = d.get("credits_spent")
	d.advance(H, 24)
	_t.near("external cap never spends more", d.get("credits_spent"), spent)
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
	partial.set("credits", 5.0)
	partial.advance(0.0, 0, at)
	_t.check("only queued members are charged after home break", partial.get("credits_spent") == 2.0 and partial.arrivals.size() == 1 and partial.packs[0].kinds == ["lobber"])
	partial._next_pack = {"id": "stopped", "kinds": ["chaser"]}
	partial.advance(0.0, 0, at)
	_t.check("zero placed members spend nothing and retain the draw", partial.get("credits_spent") == 2.0 and partial._next_pack.id == "stopped")


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
	var cards = load("res://src/world/director_cards.gd")
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
					var dial := mini(int((time + H) / Director.TIER_SECONDS), Director.MAX_TIME_TIERS) + Director.SPIKE_TIERS
					var capacity: int = mini(24, int(round((6 + dial * 2) * row.threat * row.pressure.pack_scale)) + Director.HEFT_CAP_STEP * (50 - 1))
					if mode == "credit" and not d.paused and reserved < capacity:
						integral += H * cards.I0 * (1.0 + cards.K * dial)
					var due: Array = d.advance(H, live.size())
					for _spawn in due:
						# Hold the first crowd until minute 15, then run a deterministic lifetime arm.
						live.append(maxf(900.0, time + 18.0 + seed_value % 7))
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
