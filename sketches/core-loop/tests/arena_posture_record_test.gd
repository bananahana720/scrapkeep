extends SceneTree

const Game := preload("res://src/game.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
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
			warden._posture = BossPosture.new(numbers)
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
			for ratio in [0.50, 0.60]:
				warden._posture = BossPosture.new(numbers)
				game.player.reset_to(warden.global_position + Vector3.UP * 80.0)
				var damage: Array = game.combat.STRIKE_DAMAGE["ram"]
				var force: float = (ratio * warden.plating - damage[0]) / damage[1]
				game.combat.strike(warden, "ram", force)
				if ratio == 0.50:
					var expected: float = BossPosture.BASE["ram"] * pow(ratio, float(numbers["curve"]))
					t.near("stage %d moderate small contact retains legacy gain" % stage, warden.posture(), expected, 0.001)
				else:
					t.check("stage %d medium grown contact fills at least half the bar" % stage, warden.posture() >= BossPosture.FULL / 2.0,
						"landed %.3f, two contacts need %.3f each" % [warden.posture(), BossPosture.FULL / 2.0])
				await physics_frame
		if stage >= 5:
			warden._posture = BossPosture.new(numbers)
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
	game.free()
	quit(t.verdict())
