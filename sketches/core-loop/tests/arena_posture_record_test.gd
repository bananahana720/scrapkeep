extends SceneTree

const Game := preload("res://src/game.gd")
const SliceDefs := preload("res://src/core/slice_defs.gd")
const SliceSweep := preload("res://tools/posture_sweep.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const BossPosture := preload("res://src/core/boss_posture.gd")
const MindBands := preload("res://tests/posture_bands_mind_test.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

var game
var published := []


func _initialize() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	_run()


func _run() -> void:
	var t := T.new("arena_posture_record_test")
	_slice_ratio_regression(t)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.flow.force_warden = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(1)
	game.events.posture_changed.connect(func(_enemy, value: float, _open: bool): published.append(value))
	for stage in [3, 4, 5, 6]:
		game.flow.enter_stage(stage, Vector3.ZERO, false)
		await physics_frame
		await physics_frame
		var warden = game.flow.warden
		var row: Dictionary = AlphaDefs.DEFS[stage - 1]
		var numbers: Dictionary = row["posture"]
		t.eq("stage %d owns its arena posture" % stage, warden.spec["posture"], numbers)
		t.check("stage %d records contact gain" % stage, float(numbers.get("contact_gain_scale", 0.0)) > 0.0)
		t.check("stage %d records contact floor" % stage, numbers.has("contact_gain_floor"))
		t.eq("stage %d keeps plating" % stage, warden.plating, row["warden_plating"])
		t.eq("stage %d keeps health" % stage, warden.max_hp, row["warden_hp"])
		var pair: Dictionary = AlphaDefs.DEFS[2 if stage < 5 else 4]["posture"]
		for key in ["contact_gain_scale", "contact_gain_floor", "drain_rate"]:
			t.eq("stage %d shares family %s" % [stage, key], numbers.get(key), pair.get(key))
		for ratio in [0.35, 0.75]:
			warden = await _fresh(stage, t)
			t.eq("stage %d isolated contact starts with untouched live posture" % stage, warden.posture(), 0.0)
			t.eq("stage %d setup reads contact gain" % stage, warden._posture.contact_gain_scale, float(numbers.get("contact_gain_scale", 0.0)))
			t.eq("stage %d setup reads contact floor" % stage, warden._posture.contact_gain_floor, float(numbers.get("contact_gain_floor", 0.0)))
			t.eq("stage %d setup reads drain rate" % stage, warden._posture.drain_rate, float(numbers.get("drain_rate", BossPosture.DRAIN_RATE)))
			game.player.reset_to(warden.global_position + Vector3.UP * 80.0)
			game.combat.heft_override = 1.0
			var damage: Array = game.combat.STRIKE_DAMAGE["ram"]
			var force: float = (ratio * warden.plating - damage[0]) / damage[1]
			var baseline: float = BossPosture.BASE["ram"] * pow(clampf(ratio, BossPosture.MULT_MIN, BossPosture.MULT_MAX), float(numbers["curve"]))
			var scale := float(numbers.get("contact_gain_scale", 0.0))
			var floor_ratio := float(numbers.get("contact_gain_floor", 0.0))
			var expected := minf(BossPosture.FULL, baseline * (1.0 + scale * maxf(0.0, ratio - floor_ratio)))
			published.clear()
			game.combat.strike(warden, "ram", force)
			t.near("stage %d landed ram ratio %.2f follows record" % [stage, ratio], warden.posture(), expected, 0.001)
			t.check("stage %d publishes landed posture" % stage, not published.is_empty() and absf(float(published.back()) - expected) < 0.001,
				"bar %.3f, expected %.3f, events %s" % [warden.posture(), expected, published])
			if ratio == 0.75:
				t.check("stage %d grown contact gains at least three times legacy" % stage, warden.posture() >= 3.0 * baseline,
					"landed %.3f, legacy %.3f" % [warden.posture(), baseline])
			else:
				t.near("stage %d light contact retains legacy gain" % stage, warden.posture(), baseline, 0.001)
			await physics_frame
		if stage < 5:
			for ratio in [0.50, 0.58, 0.60]:
				warden = await _fresh(stage, t)
				game.player.reset_to(warden.global_position + Vector3.UP * 80.0)
				var damage: Array = game.combat.STRIKE_DAMAGE["ram"]
				var force: float = (ratio * warden.plating - damage[0]) / damage[1]
				game.combat.strike(warden, "ram", force)
				if ratio == 0.50:
					var expected: float = BossPosture.BASE["ram"] * pow(ratio, float(numbers["curve"]))
					t.near("stage %d moderate small contact retains legacy gain" % stage, warden.posture(), expected, 0.001)
				else:
					t.check("stage %d medium grown contact %.2f fills at least half the bar" % [stage, ratio], warden.posture() >= BossPosture.FULL / 2.0,
						"landed %.3f, two contacts need %.3f each" % [warden.posture(), BossPosture.FULL / 2.0])
				await physics_frame
		if stage >= 5:
			warden = await _fresh(stage, t)
			game.player.reset_to(warden.global_position + Vector3.UP * 80.0)
			var damage: Array = game.combat.STRIKE_DAMAGE["ram"]
			var force: float = (0.60 * warden.plating - damage[0]) / damage[1]
			game.combat.strike(warden, "ram", force)
			t.check("stage %d medium Mind contact leaves room for another hit" % stage, warden.posture() > 0.0 and warden.posture() < BossPosture.FULL,
				"landed %.3f of %.3f" % [warden.posture(), BossPosture.FULL])
			warden = await _fresh(stage, t)
			var expected := minf(BossPosture.FULL, BossPosture.BASE["ram"] * pow(0.60, float(numbers["curve"]))
				* (1.0 + float(numbers["contact_gain_scale"]) * maxf(0.0, 0.60 - float(numbers["contact_gain_floor"]))))
			published.clear()
			game.combat.strike(warden, "ram", force)
			t.near("stage %d live regeneration case first lands record gain" % stage, warden.posture(), expected, 0.001)
			t.check("stage %d regeneration case publishes landed gain" % stage, not published.is_empty() and absf(float(published.back()) - expected) < 0.001)
			warden._posture.posture = 50.0
			warden._posture.step(BossPosture.DRAIN_DELAY + 1.0)
			var drain := float(numbers.get("drain_rate", BossPosture.DRAIN_RATE))
			t.check("stage %d records reduced regeneration" % stage, drain < BossPosture.DRAIN_RATE and drain > 0.0)
			t.near("stage %d regeneration follows record" % stage, warden.posture(), 50.0 - drain)
		var weapon_rule := BossPosture.new(numbers)
		var weapon_hit := {"kind": "arc", "punch": 0.75 * warden.plating, "plating": warden.plating}
		t.near("stage %d weapon gain stays unchanged" % stage, float(weapon_rule.judge(weapon_hit)["gain"]),
			BossPosture.OTHER_BASE * pow(0.75, float(numbers["curve"])))
	for stage in [1, 2]:
		var numbers: Dictionary = AlphaDefs.DEFS[stage - 1]["posture"]
		t.check("reactor stage %d has no new contact fields" % stage, not numbers.has("contact_gain_scale") and not numbers.has("contact_gain_floor"))
	var legacy := BossPosture.new()
	var hit := {"kind": "ram", "punch": 75.0, "plating": 100.0}
	t.near("missing fields preserve other Wardens", float(legacy.judge(hit)["gain"]), BossPosture.BASE["ram"] * 0.75)
	t.check("Mind enables its small median pin", MindBands.EXPECT_SMALL_S > 0.0)
	t.check("Mind enables its grown median pin", MindBands.EXPECT_GROWN_S > 0.0)
	var quarantine := FileAccess.get_file_as_string("res://tests/QUARANTINE.tsv")
	t.check("Mind remains a smoke failure when red", not quarantine.contains("posture_bands_mind_test\t"))
	t.check("reactor remains a smoke failure when red", not quarantine.contains("posture_bands_reactor_test\t"))
	game.free()
	await _slice_record_regression(t)
	quit(t.verdict())


func _fresh(stage: int, t):
	game.flow.enter_stage(stage, Vector3.ZERO, false)
	await physics_frame
	await physics_frame
	var warden = game.flow.warden
	var numbers: Dictionary = AlphaDefs.DEFS[stage - 1]["posture"]
	t.eq("stage %d fresh setup starts empty" % stage, warden.posture(), 0.0)
	t.eq("stage %d fresh setup reads contact gain" % stage, warden._posture.contact_gain_scale, float(numbers.get("contact_gain_scale", 0.0)))
	t.eq("stage %d fresh setup reads contact floor" % stage, warden._posture.contact_gain_floor, float(numbers.get("contact_gain_floor", 0.0)))
	t.eq("stage %d fresh setup reads drain rate" % stage, warden._posture.drain_rate, float(numbers.get("drain_rate", BossPosture.DRAIN_RATE)))
	game.player.reset_to(warden.global_position + Vector3.UP * 80.0)
	game.combat.heft_override = 1.0
	return warden


func _slice_ratio_regression(t) -> void:
	var source := FileAccess.get_file_as_string("res://tests/posture_bands_test.gd")
	# 9ea4c6ef made the factor a constant (GROWTH, 1.85x for the first Warden); read it from the source too.
	var pattern := RegEx.create_from_string('t\\.check\\("over the sweep seeds small takes at least %\\.2f times grown\'s time" % GROWTH, ([^\\n]+),\\n')
	var growth_found := RegEx.create_from_string('const GROWTH := ([0-9.]+)').search(source)
	t.check("slice growth factor is readable", growth_found != null)
	var growth := float(growth_found.get_string(1)) if growth_found != null else 2.0
	var found := pattern.search(source)
	t.check("slice ratio assertion is executable", found != null)
	if found == null:
		return
	var assertion := Expression.new()
	var parsed := assertion.parse(found.get_string(1), PackedStringArray(["small", "grown", "swept", "swept_grown", "GROWTH"]))
	t.eq("slice ratio assertion parses", parsed, OK)
	if parsed != OK:
		return
	var cases := [
		{"name": "saved pass cannot hide live miss", "saved": [80.6, 33.1], "live_ms": [51400, 27100]},
		{"name": "live passing control", "saved": [80.6, 33.1], "live_ms": [80600, 33100]},
		{"name": "saved miss cannot hide live pass", "saved": [51.4, 27.1], "live_ms": [80600, 33100]},
	]
	for case in cases:
		var live: Array = case["live_ms"]
		var saved: Array = case["saved"]
		var expected: bool = int(live[1]) > 0 and float(live[0]) >= growth * float(live[1])
		var swept := {"small_median_s": str(saved[0]), "grown_median_s": str(saved[1])}
		var actual = assertion.execute([float(live[0]) / 1000.0, float(live[1]) / 1000.0, swept, float(saved[1]), growth])
		t.check("slice %s evaluates" % case["name"], not assertion.has_execute_failed())
		t.eq("slice %s" % case["name"], actual, expected)


func _slice_record_regression(t) -> void:
	var row: Dictionary = SliceDefs.of(1)
	var numbers: Dictionary = row["posture"]
	var ram_base := float(numbers.get("base", {}).get("ram", BossPosture.BASE["ram"]))
	var scale := float(numbers.get("contact_gain_scale", 0.0))
	var floor_ratio := float(numbers.get("contact_gain_floor", 0.0))
	t.check("slice records light-contact separation", ram_base < float(BossPosture.BASE["ram"]) and ram_base > 0.0)
	t.check("slice records grown-contact compensation", scale > 0.0 and numbers.has("contact_gain_floor"))
	var table := SliceSweep.Table.new()
	table.plating = float(row["warden_plating"])
	table.posture = {"curve": float(numbers["curve"]), "ram_shatters": bool(numbers["ram_shatters"])}
	var measured: Dictionary = table.of(1)["posture"]
	for key in ["base", "contact_gain_scale", "contact_gain_floor"]:
		t.eq("slice sweep preserves owner %s" % key, measured.get(key), numbers.get(key))
	t.eq("slice sweep leaves owner posture untouched", SliceDefs.of(1)["posture"], numbers)
	game = Game.new()
	game.test_mode = true
	game.table = "slice"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.flow.force_warden = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(1)
	game.events.posture_changed.connect(func(_enemy, value: float, _open: bool): published.append(value))
	for ratio in [0.35, 1.0, 1.10]:
		game.flow.enter_stage(1, Vector3.ZERO, false)
		await physics_frame
		await physics_frame
		var warden = game.flow.warden
		t.eq("slice normal setup reads record contact base", warden._posture.base["ram"], ram_base)
		t.eq("slice normal setup reads record contact scale", warden._posture.contact_gain_scale, scale)
		t.eq("slice normal setup reads record contact floor", warden._posture.contact_gain_floor, floor_ratio)
		t.eq("slice keeps owner health", warden.max_hp, row["warden_hp"])
		t.eq("slice keeps owner plating", warden.plating, row["warden_plating"])
		game.player.reset_to(warden.global_position + Vector3.UP * 80.0)
		game.combat.heft_override = 1.0
		var damage: Array = game.combat.STRIKE_DAMAGE["ram"]
		var force: float = (ratio * warden.plating - damage[0]) / damage[1]
		var legacy: float = BossPosture.BASE["ram"] * ratio * ratio
		var expected: float = ram_base * ratio * ratio * (1.0 + scale * maxf(0.0, ratio - floor_ratio))
		published.clear()
		game.combat.strike(warden, "ram", force)
		t.near("slice landed contact %.2f follows owner arithmetic" % ratio, warden.posture(), expected, 0.001)
		t.check("slice publishes landed posture %.2f" % ratio, not published.is_empty() and absf(float(published.back()) - expected) < 0.001)
		if ratio < 1.0:
			t.check("slice light contact still moves posture with less buildup", warden.posture() > 0.0 and warden.posture() < legacy and not is_equal_approx(warden.posture(), legacy))
		elif ratio == 1.0:
			t.near("slice matched contact keeps inherited bar progression", warden.posture(), legacy, 0.001)
		else:
			t.check("slice grown contact retains at least legacy weight", warden.posture() >= legacy)
		var swept_rule := BossPosture.new(measured)
		var hit := {"kind": "ram", "punch": ratio * warden.plating, "plating": warden.plating}
		t.near("slice measured gain equals normal setup", float(swept_rule.judge(hit)["gain"]), expected, 0.001)
	game.free()
