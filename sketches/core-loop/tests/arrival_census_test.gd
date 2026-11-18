# smoke: bots timeout=1800s
extends SceneTree

const Game := preload("res://src/game.gd")
const Driver := preload("res://tools/bot_driver.gd")
const Census := preload("res://tools/arrival_census.gd")
const Children := preload("res://tests/trees/child_runs.gd")
const LockRows := preload("res://src/world/lock_rows.gd")
const StageLocks := preload("res://src/world/stage_locks.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const Chaser := preload("res://src/combat/chaser.gd")
const T := preload("res://tests/support/t.gd")
const RESULT := "ARRIVAL_RUN "
const SCRIPT := "res://tests/arrival_census_test.gd"

var t := T.new("arrival_census_test")
var census := Census.new()
var game
var driver
var stage_reached := 0
var role := ""
var case_seed := 1
var yard_waves: Array = []
var seconds := 0.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--arrival-case")
	if index < 0:
		_parent.call_deferred()
		return
	role = args[index + 1]
	case_seed = int(args[index + 2])
	_start.call_deferred()


func _start() -> void:
	SimClock.ticks = true
	seed(case_seed)
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.run.run_seed_override = case_seed
	game.events.enemy_spawned.connect(func(body: Node3D, kind: String):
		if game.run.stage in [1, 2]:
			census.spawned(body, kind, game.run.stage))
	game.presentation.audio.bake_opening_now()
	if role.begins_with("park_"):
		await _yard()
	else:
		driver = Driver.new(game, role, case_seed)
		driver.start()


func _physics_process(delta: float) -> bool:
	if game == null or game.flow == null:
		return false
	if game.run.stage > 2:
		if driver != null:
			_finish("world_1_clear")
		return false
	stage_reached = maxi(stage_reached, game.run.stage)
	census.sample(game.camera.cam, delta)
	if driver != null:
		seconds += delta
		if driver.tick(delta):
			_finish(driver.outcome)
		elif seconds > 1200.0:
			t.check("bot reached an ending within 1200 s of play", false)
			_finish("budget")
	return false


func _finish(ending: String) -> void:
	var row := census.ordinary_reading(ending) if driver != null else census.reading()
	row.merge({"case": role, "seed": case_seed, "stage": stage_reached, "ending": ending, "yard_waves": yard_waves})
	print(RESULT + JSON.stringify(row))
	quit(t.verdict())


# The rider can time a yard out. Exercise each real lock separately, retaining
# the actual spawned membership of each wave. These are staged, never bot runs.
func _yard() -> void:
	game.flow.press_start()
	game.flow.choose_class(0)
	if role == "park_flume":
		game.flow.enter_stage(2, Vector3.ZERO, false)
	for i in 8:
		await physics_frame
	var locks = game.flow.gate
	var lock: Dictionary = LockRows.row(role).lock
	var beacon: Vector3 = game.flow.beacon.global_position
	var spot := beacon - Vector3.BACK * (float(lock.within_m) * StageLocks.LOCK_ANY_SLOPE_SHARE - 10.0)
	game.player.reset_to(game.ctx.terrain.drop_point(spot.x, spot.z, 1.0), Vector3.ZERO)
	game.camera.snap(beacon - spot)
	for wave in lock.waves:
		var crew: Array = []
		for tick in 1000:
			await physics_frame
			crew = locks.crew_alive()
			if not crew.is_empty():
				break
		var kinds := crew.map(func(e): return String(e.kind))
		var ordinal := yard_waves.size() + 1
		if not t.eq("%s wave %d" % [role, ordinal], kinds, wave):
			break
		var ids := crew.map(func(e): return e.get_instance_id())
		# Give each wave its share of the lock duration. Preserve missing
		# observations when we clear survivors to exercise the next wave.
		var window: float = float(lock.max_s) / lock.waves.size() - float(lock.wave_gap_s) - 1.0
		var observed := {}
		for tick in maxi(1, floori(window * Engine.physics_ticks_per_second)):
			await physics_frame
			observed = census.reading(ids)
			if observed.seen == ids.size() and observed.warnings == ids.size():
				break
		t.eq("the census registered every member of wave %d" % ordinal, observed.crews, wave.size())
		observed.merge({"wave": ordinal, "kinds": kinds})
		yard_waves.append(observed)
		for enemy in crew:
			if is_instance_valid(enemy) and not enemy.is_dead():
				enemy._die()
	_finish("staged")


func _fixture() -> Dictionary:
	var scene := Node3D.new()
	root.add_child(scene)
	var cam := Camera3D.new()
	scene.add_child(cam)
	var crew := Chaser.new()
	crew.process_mode = Node.PROCESS_MODE_DISABLED
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 4.0
	collider.shape = capsule
	crew.add_child(collider)
	scene.add_child(crew)
	var behind := Census.new()
	crew.position = Vector3.BACK * 30.0
	behind.spawned(crew, "chaser")
	behind.sample(cam, 0.0)
	t.eq("live crew 30 m behind the ball", behind.reading().pop_ins, 0)

	var front := Census.new()
	crew.position = Vector3.FORWARD * 30.0
	front.spawned(crew, "chaser")
	front.sample(cam, 0.0)
	front.sample(cam, 0.1)
	var plant := int(front.reading().pop_ins)
	t.eq("live crew 30 m ahead counts exactly once", plant, 1)

	var wall := StaticBody3D.new()
	var solid := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 8, 2)
	solid.shape = box
	wall.add_child(solid)
	wall.position = Vector3.FORWARD * 15.0
	scene.add_child(wall)
	await physics_frame
	await physics_frame
	var hidden := Census.new()
	hidden.spawned(crew, "chaser")
	hidden.sample(cam, 0.1)
	t.eq("terrain hides a projected live crew", hidden.reading().seen, 0)
	# Lower the obstruction until the crown clears it but the origin does not.
	wall.position.y = -3.5
	await physics_frame
	await physics_frame
	var crown := Census.new()
	crown.spawned(crew, "chaser")
	crown.sample(cam, 0.1)
	t.eq("visible crown reveals a live crew while its centre is hidden", crown.reading().pop_ins, 1)
	wall.position.x = 20.0
	await physics_frame
	await physics_frame
	crew.set_meta("arrival_state", "entering")
	hidden.sample(cam, 0.1)
	t.eq("one glimpse before forced removal leaves the warning unmeasured", hidden.reading().short_unwarned, 1)
	hidden.sample(cam, Chaser.WINDUP)
	t.eq("the visible crew has already accumulated its warning lead", hidden.reading().short_unwarned, 0)
	crew.set_meta("arrival_state", "live")
	crew.attack_phase.emit({"phase": "windup"})
	hidden.sample(cam, 0.1)
	t.eq("crew visible while entering never pops in", hidden.reading().pop_ins, 0)
	t.near("only visible time before the first warning counts", hidden.reading().seen_before_warning_s, Chaser.WINDUP)
	var mixed := _ordinary_plant(scene, cam, hidden)
	scene.free()
	return {"live_ahead": plant, "ordinary_unseen": mixed}


# The qualifying crew is the one that just entered, accumulated the lead and
# warned. Exercise the same ordinary-ride branch that judges real child runs.
func _fixture_receipt(measure, ending: String) -> Dictionary:
	var ride: Dictionary = measure.ordinary_reading(ending)
	ride["case"] = "skipper"
	return _receipt([ride], true)


func _ordinary_plant(scene: Node3D, cam: Camera3D, measure) -> Dictionary:
	var good := _fixture_receipt(measure, "world_1_clear")
	t.check("one qualified crew can pass an ordinary ride", good.pass)
	t.check("a rider death preserves a fully observed crew", _fixture_receipt(measure, "died").pass)
	t.check("an unfinished ride stays partial with a qualified crew", not _fixture_receipt(measure, "stalled").coverage_complete)
	var missed := Chaser.new()
	missed.process_mode = Node.PROCESS_MODE_DISABLED
	missed.position = Vector3.BACK * 30.0
	scene.add_child(missed)
	measure.spawned(missed, "chaser")
	missed.take_damage(missed.hp)
	missed.free()
	measure.sample(cam, 0.0)
	var mixed := _fixture_receipt(measure, "world_1_clear")
	var ride: Dictionary = mixed.runs[0]
	t.eq("one warned and one unseen spawn both have a disposition", ride.members.size(), 2)
	t.eq("first crew was seen before its warning", ride.members[0].observation, "warned")
	t.eq("unseen death between samples stays in the ride", [ride.members[1].fate, ride.members[1].observation], ["died", "unseen"])
	t.check("a qualifying crew cannot cover an unseen death", not mixed.coverage_complete and not mixed.pass)
	t.check("a rider death still accounts for the missed crew", not _fixture_receipt(measure, "lost").coverage_complete)
	# Removal without a death and a still-live crew on a partial ride are
	# distinct fates. Both retain the observation made before the ride ends.
	var removed := Chaser.new()
	removed.process_mode = Node.PROCESS_MODE_DISABLED
	removed.set_meta("arrival_state", "entering")
	removed.position = Vector3.FORWARD * 30.0
	scene.add_child(removed)
	measure.spawned(removed, "chaser")
	measure.sample(cam, 0.0)
	removed.free()
	var partial: Dictionary = measure.ordinary_reading("stalled")
	t.eq("partial ride preserves each fate in spawn order",
		partial.members.map(func(member): return member.fate), ["present_at_end", "died", "removed"])
	t.eq("a despawn after a brief glimpse remains unresolved", partial.members[2].observation, "short_unwarned")
	return mixed


func _parent() -> void:
	var plants := await _fixture()
	if OS.get_environment("PLANT") == "ordinary_unseen":
		var planted: Dictionary = plants.ordinary_unseen
		planted["plant"] = "ordinary_unseen"
		print("RECEIPT " + JSON.stringify(planted))
		t.check("planted ordinary ride meets the arrival promise", planted.pass)
		quit(t.verdict())
		return
	if OS.get_environment("PLANT") == "live_ahead":
		var plant := int(plants.live_ahead)
		print("RECEIPT " + JSON.stringify({"pop_ins": plant, "pass": false, "plant": "live_ahead"}))
		t.eq("arrival floor on the planted live crew", plant, 0)
		quit(t.verdict())
		return
	var jobs := []
	for policy in ["skipper", "camper"]:
		for run_seed in range(1, 5):
			jobs.append({"script": SCRIPT, "args": ["--arrival-case", policy, str(run_seed)]})
	for park in ["park_dam", "park_flume"]:
		jobs.append({"script": SCRIPT, "args": ["--arrival-case", park, "1"]})
	var results := Children.run(jobs, 510.0, 4)
	var rows := []
	var bot_stages := {}
	for i in jobs.size():
		var result: Dictionary = results[i]
		var args: Array = jobs[i].args
		var label := "%s seed %s" % [args[1], args[2]]
		var summary := Children.summary(result)
		t.check(label + " ran clean", result.code == 0 and summary.errors.is_empty() and not result.timed_out, str(summary.errors.slice(0, 2)))
		var row: Dictionary = {}
		for line in String(result.log).split("\n"):
			if line.begins_with(RESULT):
				row = JSON.parse_string(line.trim_prefix(RESULT))
		if not t.check(label + " reported its arrivals", row.get("case") == args[1] and row.get("seed") == int(args[2]) and row.get("crews", 0) > 0):
			continue
		rows.append(row)
		if args[1] in ["skipper", "camper"]:
			bot_stages[args[1]] = maxi(bot_stages.get(args[1], 0), int(row.stage))
	t.check("bot runs measured first warnings", rows.filter(func(r): return r["case"] in ["skipper", "camper"] and r.warnings > 0).size() == 8)
	var complete := t.failures == 0 and rows.size() == jobs.size()
	complete = complete and bot_stages.get("skipper", 0) == 2 and bot_stages.get("camper", 0) == 2
	print("RECEIPT " + JSON.stringify(_receipt(rows, complete)))
	quit(t.verdict())


func _receipt(rows: Array, complete: bool) -> Dictionary:
	var pop_ins := 0
	var minimum = null
	for row: Dictionary in rows:
		if row["case"] in ["skipper", "camper"]:
			# A rider's death ends a measured run. A driver cap is partial.
			if row.ending not in ["world_1_clear", "lost", "died", "won"]:
				complete = false
			var members: Array = row.members
			if members.size() != row.crews or not row.crew_coverage_complete:
				complete = false
		else:
			for wave in row.yard_waves:
				if not wave.crew_coverage_complete:
					complete = false
		pop_ins += int(row.pop_ins)
		if row.seen_before_warning_s != null and (minimum == null or row.seen_before_warning_s < minimum):
			minimum = row.seen_before_warning_s
	return {"coverage_complete": complete, "pop_ins": pop_ins, "seen_before_warning_s": minimum, "runs": rows,
		"pass": complete and pop_ins == 0 and minimum != null and minimum + 0.000001 >= Chaser.WINDUP}
