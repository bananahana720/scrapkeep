extends SceneTree
# smoke: timeout=300s (92-129 s in a gate chunk on the w31 and w32 boxes, 158 s alone on w30's, where the
# default 180 s cap killed it in the chunk)

const T := preload("res://tests/support/t.gd")
const Director := preload("res://src/world/director.gd")
const Counter := preload("res://src/combat/counter.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const Park := preload("res://src/core/park_defs.gd")
const Game := preload("res://src/game.gd")
const Profile := preload("res://src/core/profile.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Chaser := preload("res://src/combat/chaser.gd")
const Lobber := preload("res://src/combat/lobber.gd")
const Miniboss := preload("res://src/combat/miniboss.gd")

var t := T.new("run_tier_dials_test")
var limits := {}
var steps := {}
var game

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var constants: Dictionary = load("res://src/core/run_tier.gd").get_script_constant_map()
	var stage_constants: Dictionary = load("res://src/core/stage_defs.gd").get_script_constant_map()
	# Ruling al (HARD ladder): no run tier raises enemy health, so health has no cap and no world step.
	limits = {"health": 1.0,
		"damage": constants.get("DAMAGE_DIAL_CAP", 1.3),
		"aggression": constants.get("REST_DIAL_FLOOR", 0.75)}
	steps = stage_constants.get("RUN_TIER_DIAL_STEPS", {"damage": 0.1, "aggression": 0.1})
	t.check("no health dial cap", not constants.has("HEALTH_DIAL_CAP"))
	t.check("no health world step", not steps.has("health"))
	t.eq("named damage cap", constants.get("DAMAGE_DIAL_CAP"), 1.3)
	t.eq("named rest floor", constants.get("REST_DIAL_FLOOR"), 0.75)
	t.check("world steps in stage_defs", stage_constants.has("RUN_TIER_DIAL_STEPS"))
	for key in steps:
		t.check("positive world step " + key, float(steps[key]) > 0.0)
	_sweeps()
	_boundaries_and_base()
	await _production()
	game.free()
	quit(t.verdict())

func _same(label: String, got, want) -> void:
	t.check(label, var_to_bytes(got) == var_to_bytes(want), "byte equality")

# The oracle reads only the approved data, never a Director accessor.
func _expected(world: int, tier_value: int, dial_steps: Dictionary) -> Array:
	if tier_value == 0:
		return [1.0, 1.0, 1.0]
	return [1.0,
		minf(1.0 + world * float(dial_steps.damage), limits.damage),
		maxf(1.0 - world * float(dial_steps.aggression), limits.aggression)]

func _director(row: Dictionary, tier_value: int):
	var d = Director.new(701)
	d.use_row(row, "", func(): return tier_value)
	d.threat = float(row.threat)
	return d

func _measure(d) -> Array:
	var rest: float = d.rest_scale() if d.has_method("rest_scale") else 1.0
	var c := Counter.new()
	c.spec = {"rest_scale": rest}
	c.rest_seconds = 3.0
	c._end()
	var actual_rest := c._rest / 3.0
	c.free()
	return [d.hp_scale() / d.threat, d.damage_scale() if d.has_method("damage_scale") else 1.0, actual_rest]

func _sweeps() -> void:
	var row := {"world": 1, "threat": 1.25}
	var baseline = _director(row, 1)
	if not "dial_steps" in baseline:
		t.check("independent dial inputs exist", false)
		return
	baseline.dial_steps = {"damage": 0.0, "aggression": 0.0}
	var base := _measure(baseline)
	_same("all zero inputs are baseline", base, [1.0, 1.0, 1.0])
	for index in [1, 2]:
		var key: String = ["health", "damage", "aggression"][index]
		var saturation: float = (1.0 - float(limits[key])) if key == "aggression" else (float(limits[key]) - 1.0)
		var values := [0.0, float(steps[key]), saturation, saturation * 2.0, saturation * 10.0]
		for value in values:
			var d = _director(row, 1)
			d.dial_steps = baseline.dial_steps.duplicate()
			d.dial_steps[key] = value
			var got := _measure(d)
			var want := _expected(1, 1, d.dial_steps)
			t.near("sweep " + key + " expected at " + str(value), got[index], want[index])
			t.check("cap " + key + " at " + str(value), got[index] >= limits[key] if key == "aggression" else got[index] <= limits[key])
			for other in range(3):
				if other != index:
					_same("one-dial-only " + key + " leaves " + str(other), got[other], base[other])
			print("SWEEP %s input=%s outputs=%s" % [key, value, got])

func _boundaries_and_base() -> void:
	var previous := []
	var previous_world := 0
	for row in Park.DEFS:
		var base = _director(row, 0)
		for elapsed in [0.0, 45.0, 90.0, 180.0, 600.0]:
			base.stage_time = elapsed
			_same("tier-0 health stage %d time %s" % [row.stage, elapsed], base.hp_scale(), float(row.threat))
			_same("tier-0 damage/rest stage %d time %s" % [row.stage, elapsed], _measure(base).slice(1), [1.0, 1.0])
		var hard = _director(row, 1)
		var got := _measure(hard)
		var want := _expected(int(row.world), 1, steps)
		for index in range(3):
			t.near("world dial stage %d quantity %d" % [row.stage, index], got[index], want[index])
		if not previous.is_empty() and int(row.world) > previous_world:
			t.eq("world boundary leaves health", got[0], 1.0)
			t.check("world boundary damage dial", got[1] > previous[1])
			t.check("world boundary aggression dial", got[2] < previous[2])
			print("BOUNDARY stage %d->%d multipliers %s -> %s" % [int(row.stage) - 1, row.stage, previous, got])
		previous = got
		previous_world = int(row.world)
		_same("tier annotation preserves stage lists", RunTier.stage_row(row, 0), row)
		if base._park_map != null:
			# Directors share one parsed map per id (director.gd read_park), so each tier's rows are
			# held against a fresh parse of the park file: a tier that edited the shared rows fails here.
			var fresh = load("res://src/world/park/park_map.gd").new("res://src/world/park/%s.json" % String(row.map))
			_same("routes and pockets identical stage %d tier 0" % row.stage, base._park_map.park, fresh.park)
			_same("routes and pockets identical stage %d tier 1" % row.stage, hard._park_map.park, fresh.park)

func _production() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	await process_frame
	paused = true
	game.presentation.audio.process_mode = Node.PROCESS_MODE_DISABLED
	game.ctx.calm = true
	game.ctx.profile = Profile.new("user://run_tier_dials_test/unused.json")
	game.ctx.profile.load_profile()
	game.ctx.profile.can_save = false
	game.ctx.profile.earn("first_win", 1.0)
	var hits := []
	game.events.player_hit.connect(func(amount: float, source: String): hits.append([amount, source]))
	for tier_value in [0, 1]:
		game.flow._begin_run(ClassDef.all()[0])
		if tier_value == 1:
			t.check("production opt-in tier", game.flow.choose_run_tier(1))
		for row in Park.DEFS:
			if int(row.stage) != 1:
				game.flow.enter_stage(int(row.stage), Vector3(0.0, 0.0, 20.0), false)
			var want := _expected(int(row.world), tier_value, steps)
			var pos: Vector3 = game.player.ball_position()
			pos.y = game.combat.ground.height_at(pos) + 1.0
			game.player._rigid.global_position = pos
			var e = game.combat.spawn_enemy("chaser", pos)
			var hp_want: float = Chaser.HP * float(row.threat) if tier_value == 0 else Chaser.HP * (float(row.threat) * want[0])
			_same("production health tier %d stage %d" % [tier_value, row.stage], e.hp, hp_want)
			_same("production max health", e.max_hp, hp_want)
			game.run.armor_mode = false
			game.run.hp = 100.0
			hits.clear()
			e._begin_windup(Vector3.FORWARD)
			e._check_hit(e._telegraph)
			var damage_want: float = Chaser.DAMAGE if tier_value == 0 else Chaser.DAMAGE * want[1]
			# The stage's challenge dial rides on top of the tier (the dam ships mob hits at x1.5).
			damage_want *= ChallengeDials.stage_mult("mobs.damage", int(row.stage))
			_same("production delivered hit tier %d stage %d" % [tier_value, row.stage], hits, [[damage_want, "chaser"]])
			_same("production ball health after hit", game.run.hp, 100.0 - damage_want)
			for kind in ["lobber", "miniboss"]:
				var other = game.combat.spawn_enemy(kind, pos + Vector3.RIGHT * 5.0)
				var hp_base: float = Lobber.HP if kind == "lobber" else Miniboss.HP
				_same("production " + kind + " health", other.hp, hp_base * (float(row.threat) * want[0]))
				other.free()
			var counter = game.combat.spawn_enemy("mag_trapper", pos + Vector3.RIGHT * 10.0)
			var counter_constants: Dictionary = counter.get_script().get_script_constant_map()
			var rating_want: float = counter_constants.RATING_BASE + counter_constants.RATING_PER_THREAT * (float(row.threat) - 1.0)
			_same("health dial leaves counter tool rating", counter.rating, rating_want)
			var counter_hp: float = float(counter_constants.HP) * float(row.threat) if tier_value == 0 else float(counter_constants.HP) * (float(row.threat) * want[0])
			if tier_value == 0:
				_same("production counter health tier-0", counter.hp, counter_hp)
			else:
				t.near("production counter health tier-1", counter.hp, counter_hp)
			counter._end()
			var rest_want: float = counter.rest_seconds if tier_value == 0 else counter.rest_seconds * want[2]
			_same("production rest tier %d stage %d" % [tier_value, row.stage], counter._rest, rest_want)
			var warden = game.combat.spawn_enemy("warden", pos + Vector3.RIGHT * 20.0)
			_same("Warden stays excluded", warden.hp, float(game.combat.warden_spec(int(row.stage)).hp))
			game.run.hp = 100.0
			hits.clear()
			warden.hit_player.emit(9.0, Vector3.ZERO)
			_same("Warden damage stays excluded", hits, [[9.0, "warden"]])
			print("PRODUCTION tier=%d stage=%d hp=%s damage=%s rest=%s" % [tier_value, row.stage, e.hp, damage_want, counter._rest])
			warden.free()
			counter.free()
			e.free()
	paused = false
