extends SceneTree

# SR8 (W13-INTEGRATION-3.md, device caps). Rules:
# - Every quick autonomous device kind has one row in Devices.ROWS: a cap, a refill time,
#   a leash range and a recall time. The deployed count of a kind never goes above its cap.
# - A device that is destroyed, expires or is recalled leaves the count at once; its slot
#   comes back after the row's refill time (refill 0 means at once).
# - A device further than the row's leash from its owner for the row's recall time is
#   recalled: it leaves without acting (a sticky charge is not detonated).
# - The ledger is per attempt: no names, no persistence, cleared with the fight (no crew).
# Live: Kest's sticky and mini charges (sticky.gd) and Sable's Sentry Post (combat.gd).

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const T := preload("res://tests/support/t.gd")

const DEVICES_PATH := "res://src/core/devices.gd"
const SEED := 8008
const OPS := 1000
const STEP := 1.0 / 60.0
const LIMIT := 30.0
# 2026-10-12 SR8 round 3: 216 existing checks plus 128 run-end lifecycle checks.
const EXPECTED_CHECKS := 344
# The lab rows, pinned here so a drift in Devices.ROWS fails the test instead of moving the
# expectation with it. Change a value here only together with its start value in devices.gd
# (comps/ror2/companions.md). sticky's cap is Kest's kit knob default (Weapons.STICKY_MAX_LIVE).
const LAB_ROWS := {
	"sticky": {"cap": 3, "refill": 0.0, "leash_m": 60.0, "recall_after": 1.0},
	"mini": {"cap": 8, "refill": 0.0, "leash_m": 60.0, "recall_after": 1.0},
	"sentry": {"cap": 1, "refill": 2.0, "leash_m": 60.0, "recall_after": 1.0},
	"kest_mine": {"cap": 10, "refill": 0.0, "leash_m": 60.0, "recall_after": 1.0},
	"kest_raid": {"cap": 64, "refill": 0.0, "leash_m": 60.0, "recall_after": 1.0},
	"sable_stake": {"cap": 11, "refill": 0.0, "leash_m": 60.0, "recall_after": 1.0},
}

var _t := T.new("device_caps_test")
var _game
var _combat
var _ticks := 0
var Devices


func _initialize() -> void:
	if ResourceLoader.exists(DEVICES_PATH):
		Devices = load(DEVICES_PATH)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_setup()
		return false
	if _ticks < 12:
		return false
	if not _t.check("devices table exists", Devices != null, DEVICES_PATH):
		quit(_t.verdict())
		return true
	_check_table()
	_check_pinned()
	_check_cap_pure()
	_check_refill_pure()
	_check_recall_pure()
	_check_live_minis()
	_check_live_thrown()
	_check_external_charge_exit()
	_check_live_sentry()
	_check_live_recall()
	_check_live_kit_payloads()
	_check_live_stakes()
	_check_cleared()
	_check_run_ended()
	_t.eq("expected check count", _t.checks + 1, EXPECTED_CHECKS)
	quit(_t.verdict())
	return true


func _setup() -> void:
	var ctx = _game.ctx
	ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	var spawn: Vector3 = ctx.terrain.spawn_point(1)
	var anchor := Vector3(spawn.x, ctx.terrain.height(spawn.x, spawn.z) + 1.05, spawn.z)
	_game.player.reset_to(anchor)
	_game.player.body().global_position = anchor
	_combat = ctx.spawner


func _rows() -> Dictionary:
	return (Devices as Script).get_script_constant_map().get("ROWS", {})


# Report table, then structure: every kind has a finite, positive cap and leash and a
# non-negative refill and recall time; validate_rows catches a broken row.
func _check_table() -> void:
	var rows := _rows()
	_t.check("ROWS has rows", rows.size() >= 3, "kinds %s" % [rows.keys()])
	print("kind      cap  refill_s  leash_m  recall_s")
	for kind in rows:
		var row: Dictionary = rows[kind]
		print("%-9s %3d  %8.2f  %7.1f  %8.2f" % [kind, int(row.get("cap", -1)), float(row.get("refill", -1.0)),
			float(row.get("leash_m", -1.0)), float(row.get("recall_after", -1.0))])
		var ok: bool = int(row.get("cap", 0)) >= 1 and is_finite(float(row.get("refill", NAN))) and float(row.get("refill", -1.0)) >= 0.0 \
			and is_finite(float(row.get("leash_m", NAN))) and float(row.get("leash_m", 0.0)) > 0.0 \
			and is_finite(float(row.get("recall_after", NAN))) and float(row.get("recall_after", -1.0)) >= 0.0
		_t.check("%s row is sound" % kind, ok, var_to_str(row))
	for kind in ["sticky", "mini", "sentry"]:
		_t.check("%s has a row" % kind, rows.has(kind))
	_t.eq("validate_rows passes the shipped table", Devices.validate_rows(), [])
	var broken: Dictionary = rows.duplicate(true)
	broken["sentry"]["cap"] = 0
	_t.check("validate_rows catches a zero cap", not Devices.validate_rows(broken).is_empty())
	broken = rows.duplicate(true)
	broken["mini"]["refill"] = NAN
	_t.check("validate_rows catches a NaN refill", not Devices.validate_rows(broken).is_empty())


# Every shipped row and a fresh ledger's default cap equal the pinned lab row, field by field,
# and no kind ships without a pinned row.
func _check_pinned() -> void:
	var rows := _rows()
	_t.eq("ROWS kinds match the lab rows", _sorted(rows.keys()), _sorted(LAB_ROWS.keys()))
	var ledger = Devices.new()
	for kind in LAB_ROWS:
		var lab: Dictionary = LAB_ROWS[kind]
		var row: Dictionary = rows.get(kind, {})
		_t.eq("%s cap matches the lab row" % kind, int(row.get("cap", -1)), int(lab["cap"]))
		_t.eq("%s ledger cap matches the lab row" % kind, int(ledger.cap(kind)), int(lab["cap"]))
		for field in ["refill", "leash_m", "recall_after"]:
			_t.near("%s %s matches the lab row" % [kind, field], float(row.get(field, -1.0)), float(lab[field]), 0.0001)


func _sorted(a: Array) -> Array:
	var out := a.duplicate()
	out.sort()
	return out


# Seeded random deploys, destructions, expiries and steps on a fresh ledger: the count of
# every kind stays at or under its cap and live plus refilling never passes it.
func _check_cap_pure() -> void:
	var rows := _rows()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var ledger = Devices.new()
	var ids := {}
	var worst := {}
	var over := 0
	for kind in rows:
		ids[kind] = []
		worst[kind] = 0
		for i in int(rows[kind]["cap"]):
			ids[kind].append(ledger.deploy(kind, Vector3.ZERO)["id"])
		worst[kind] = ledger.count(kind)
	for i in OPS:
		var kind: String = rows.keys()[rng.randi_range(0, rows.size() - 1)]
		var roll := rng.randi_range(0, 9)
		if roll < 6:
			var out: Dictionary = ledger.deploy(kind, Vector3(rng.randf_range(-5.0, 5.0), 0.0, 0.0))
			if int(out.get("id", 0)) > 0:
				ids[kind].append(out["id"])
			for gone in out.get("evicted", []):
				ids[kind].erase(gone)
		elif roll < 8 and not ids[kind].is_empty():
			var pick: int = ids[kind][rng.randi_range(0, ids[kind].size() - 1)]
			ledger.remove(pick, ["destroyed", "expired"][rng.randi_range(0, 1)])
			ids[kind].erase(pick)
		else:
			ledger.step(rng.randf_range(0.0, 0.5), Vector3.ZERO)
		for k in rows:
			var n: int = ledger.count(k)
			worst[k] = maxi(worst[k], n)
			if n > ledger.cap(k) or n + ledger.refilling(k) > ledger.cap(k) or n != ids[k].size():
				over += 1
	_t.eq("count never above cap (%d seeded ops)" % OPS, over, 0)
	for kind in rows:
		_t.check("%s reached its lab cap" % kind, worst[kind] == int(LAB_ROWS[kind]["cap"]), "peak %d, lab cap %d" % [worst[kind], int(LAB_ROWS[kind]["cap"])])


# A destroyed device leaves the count at once; its slot comes back after the row's refill.
func _check_refill_pure() -> void:
	for kind in LAB_ROWS:
		var row: Dictionary = LAB_ROWS[kind]
		var ledger = Devices.new()
		var ids := []
		for i in ledger.cap(kind):
			ids.append(int(ledger.deploy(kind, Vector3.ZERO)["id"]))
		_t.eq("%s fills to the lab cap" % kind, ledger.count(kind), int(row["cap"]))
		ledger.remove(ids[0], "destroyed")
		_t.eq("%s destroyed leaves the count" % kind, ledger.count(kind), ledger.cap(kind) - 1)
		ledger.remove(ids[0], "destroyed")
		_t.eq("%s double removal is a no-op" % kind, ledger.count(kind), ledger.cap(kind) - 1)
		var waited := 0.0
		var out: Dictionary = ledger.deploy(kind, Vector3.ZERO)
		while int(out.get("id", 0)) <= 0 and waited < LIMIT:
			ledger.step(STEP, Vector3.ZERO)
			waited += STEP
			out = ledger.deploy(kind, Vector3.ZERO)
		_t.near("%s refill matches the row" % kind, waited, float(row["refill"]), STEP + 0.0001)
		_t.eq("%s refilled slot does not evict" % kind, out.get("evicted", []), [])


# A device past the leash for the row's recall time is recalled; inside it never is, and
# coming back inside resets the wait.
func _check_recall_pure() -> void:
	for kind in LAB_ROWS:
		var row: Dictionary = LAB_ROWS[kind]
		var far := Vector3(float(row["leash_m"]) + 5.0, 0.0, 0.0)
		var ledger = Devices.new()
		var id: int = ledger.deploy(kind, far)["id"]
		var waited := 0.0
		var recalled := []
		while recalled.is_empty() and waited < LIMIT:
			recalled = ledger.step(STEP, Vector3.ZERO)
			waited += STEP
		_t.near("%s recall matches the row" % kind, waited, maxf(STEP, float(row["recall_after"])), STEP + 0.0001)
		_t.check("%s recall names the device" % kind, recalled.size() == 1 and int(recalled[0].get("id", 0)) == id
			and recalled[0].get("kind") == kind, var_to_str(recalled))
		_t.eq("%s recalled leaves the count" % kind, ledger.count(kind), 0)
		var near_ledger = Devices.new()
		near_ledger.deploy(kind, Vector3(float(row["leash_m"]) - 1.0, 0.0, 0.0))
		var stray := 0
		for i in int(LIMIT / STEP / 3.0):
			stray += near_ledger.step(STEP, Vector3.ZERO).size()
		_t.eq("%s inside the leash is never recalled" % kind, stray, 0)
		var back = Devices.new()
		var back_id: int = back.deploy(kind, far)["id"]
		var half := maxf(0.0, float(row["recall_after"]) * 0.6)
		var t := 0.0
		while t < half:
			back.step(STEP, Vector3.ZERO)
			t += STEP
		back.move(back_id, Vector3.ZERO)
		back.step(STEP, Vector3.ZERO)
		back.move(back_id, far)
		var again := 0
		t = 0.0
		while t < half:
			again += back.step(STEP, Vector3.ZERO).size()
			t += STEP
		if float(row["recall_after"]) > 2.0 * STEP:
			_t.eq("%s return inside resets the wait" % kind, again, 0)


func _as_class(id: String) -> void:
	var def: Resource = ClassDef.by_id(id)
	_game.run.class_def = def
	_game.player.fit_class(def)
	_combat.sticky.clear()
	_combat.rebuild_patterns()


func _devices():
	return _combat.get("devices")


# Live minis (sticky.gd drop, the slam and proc charges): the manager never holds more
# than the mini cap, the ledger counts what the manager holds, and an evicted charge goes
# off on the next step rather than vanishing.
func _check_live_minis() -> void:
	_t.check("combat holds a device ledger", _devices() != null, "combat.devices")
	if _devices() == null:
		return
	_as_class("demolitions_caster")
	var base: Vector3 = _game.player.ball_position() + Vector3(0.0, -0.9, 0.0)
	var cap: int = _devices().cap("mini")
	var over := 0
	var mismatch := 0
	for i in cap * 3:
		_combat.sticky.drop(base + Vector3(float(i) * 0.3, 0.0, 0.0), 0.0, 1.0, 99.0, 99.0)
		if _combat.sticky.live(true).size() > cap:
			over += 1
		if _devices().count("mini") != _combat.sticky.live(true).size():
			mismatch += 1
	_t.eq("live minis never above the cap", over, 0)
	_t.eq("ledger counts the live minis", mismatch, 0)
	var evicted: Array = _combat.sticky.step(STEP, null, [])
	_t.eq("evicted minis go off on the next step", evicted.size(), cap * 2)
	var before: int = _devices().count("mini")
	_combat.sticky.take(_combat.sticky.live(true)[0])
	_t.eq("a destroyed mini leaves the count", _devices().count("mini"), before - 1)
	_combat.sticky.clear()
	_t.eq("cleared minis leave the count", _devices().count("mini"), 0)


# Live thrown charges (Kest's weapon): the cap is the kit's sticky_max_live times the lob
# count, unchanged; the ledger holds it and counts every throw.
func _check_live_thrown() -> void:
	if _devices() == null:
		return
	_as_class("demolitions_caster")
	var landing: Vector3 = _game.player.ball_position() + Vector3(6.0, -0.9, 0.0)
	var knob := int(_game.player.tree.knob("sticky_max_live")) if _game.player.tree.has_method("knob") else -1
	var over := 0
	var mismatch := 0
	for i in 10:
		_combat._throw_sticky(landing + Vector3(0.0, 0.0, float(i) * 0.4))
		if _combat.sticky.live().size() > _devices().cap("sticky"):
			over += 1
		if _devices().count("sticky") != _combat.sticky.live().size():
			mismatch += 1
	_t.eq("live thrown never above the cap", over, 0)
	_t.eq("ledger counts the thrown charges", mismatch, 0)
	if knob > 0:
		_t.eq("thrown cap is the kit's sticky_max_live", _devices().cap("sticky"), knob)
	_t.eq("ten throws hold the cap", _combat.sticky.live().size(), _devices().cap("sticky"))
	_combat.sticky.clear()


# External destruction must release ordinary charges too, before their next step. Test
# both freeing the node and leaving the tree, then repeat take() beside a live survivor.
func _check_external_charge_exit() -> void:
	if _devices() == null:
		return
	_as_class("demolitions_caster")
	var manager = _combat.sticky
	var at: Vector3 = _game.player.ball_position()
	for mini in [false, true]:
		var kind := "mini" if mini else "sticky"
		for freed in [true, false]:
			var label := "%s external %s" % [kind, "free" if freed else "exit"]
			var charge: Dictionary = manager.drop(at, 0.0, 1.0, 99.0, 99.0) if mini \
				else manager.throw(at, at, 0.0, 1.0, 99.0, false)
			var survivor: Dictionary = manager.drop(at, 0.0, 1.0, 99.0, 99.0) if mini \
				else manager.throw(at, at, 0.0, 1.0, 99.0, false)
			var id := int(charge["device_id"])
			var node: Node3D = charge["node"]
			_t.eq("%s starts with two slots" % label, _devices().count(kind), 2)
			if freed:
				node.free()
			else:
				manager.remove_child(node)
			_t.eq("%s immediately releases its slot" % label, _devices().count(kind), 1)
			_t.eq("%s removes its ledger id" % label, _devices().kind_of(id), "")
			_t.eq("%s immediately leaves the manager" % label, manager.charges.has(charge), false)
			_t.eq("%s next step returns no detonation" % label, manager.step(STEP, null, []), [])
			_t.eq("%s next step preserves only the survivor" % label, manager.charges, [survivor])
			manager.take(charge)
			manager.take(charge)
			_t.eq("%s repeated take preserves the other slot" % label, _devices().count(kind), 1)
			_t.eq("%s repeated take preserves the manager" % label, manager.charges, [survivor])
			_t.eq("%s does not create refill debt" % label, _devices().refilling(kind), 0)
			if not freed:
				node.free()
			manager.clear()
			_t.eq("%s survivor cleanup releases its slot" % label, _devices().count(kind), 0)
		# take() releases first; the later tree-exit signal must be a no-op too.
		var taken: Dictionary = manager.drop(at, 0.0, 1.0, 99.0, 99.0) if mini \
			else manager.throw(at, at, 0.0, 1.0, 99.0, false)
		var taken_node: Node3D = taken["node"]
		manager.take(taken)
		_t.eq("%s take releases before node exit" % kind, _devices().count(kind), 0)
		taken_node.free()
		_t.eq("%s take then exit keeps zero slots" % kind, _devices().count(kind), 0)
		_t.eq("%s take then exit keeps manager empty" % kind, manager.charges, [])


# Live Sentry Post: one turret per dismount, replaced by the next; it expires on its knob;
# its slot refills after the row's refill time.
func _check_live_sentry() -> void:
	if _devices() == null:
		return
	_as_class("pylon_engineer")
	var row: Dictionary = LAB_ROWS["sentry"]
	var knobs: Dictionary = _game.player.tree._knobs
	knobs["sentry"] = 4.0
	# The pylon face the pilot steps off is beside the pilot, inside the leash.
	_game.player.kit.mount_face = _game.player.ball_position()
	_combat._on_dismounted_sentry(Vector3.ZERO)
	_t.check("dismount leaves a sentry", not _combat._sentry.is_empty())
	_t.eq("one sentry counted", _devices().count("sentry"), 1)
	for i in 3:
		_combat._on_dismounted_sentry(Vector3.ZERO)
	_t.eq("sentries never above the lab cap", _devices().count("sentry"), int(row["cap"]))
	var t := 0.0
	while not _combat._sentry.is_empty() and t < LIMIT:
		_combat._tick_sentry(STEP)
		_combat._step_devices(STEP)
		t += STEP
	_t.near("sentry expires on its knob", t, 4.0, STEP + 0.0001)
	_t.eq("expired sentry leaves the count", _devices().count("sentry"), 0)
	var waited := 0.0
	_combat._on_dismounted_sentry(Vector3.ZERO)
	while _combat._sentry.is_empty() and waited < LIMIT:
		_combat._step_devices(STEP)
		waited += STEP
		_combat._on_dismounted_sentry(Vector3.ZERO)
	_t.near("sentry refill matches the row", waited, float(row["refill"]), STEP + 0.0001)
	knobs.erase("sentry")


# Live recall: a sentry or a mini left past the leash leaves after the row's recall time,
# and a recalled charge does not go off.
func _check_live_recall() -> void:
	if _devices() == null or _combat._sentry.is_empty():
		_t.check("a sentry stands for the recall check", false)
		return
	var owner: Vector3 = _game.player.ball_position()
	var row: Dictionary = LAB_ROWS["sentry"]
	_combat._sentry["at"] = owner + Vector3(float(row["leash_m"]) + 5.0, 0.0, 0.0)
	_combat._sentry["left"] = 99.0
	var t := 0.0
	while not _combat._sentry.is_empty() and t < LIMIT:
		_combat._step_devices(STEP)
		t += STEP
	_t.near("live sentry recall matches the row", t, float(row["recall_after"]), STEP + 0.0001)
	_t.eq("recalled sentry leaves the count", _devices().count("sentry"), 0)
	_as_class("demolitions_caster")
	var mini_row: Dictionary = LAB_ROWS["mini"]
	var booms := [0]
	var count := func(_at: Vector3, _crit: bool): booms[0] += 1
	_game.events.sticky_detonated.connect(count)
	var far: Vector3 = owner + Vector3(float(mini_row["leash_m"]) + 5.0, 0.0, 0.0)
	_combat.sticky.drop(far, 0.0, 1.0, 99.0, 99.0)
	t = 0.0
	while not _combat.sticky.live(true).is_empty() and t < LIMIT:
		_combat._step_devices(STEP)
		t += STEP
	_game.events.sticky_detonated.disconnect(count)
	_t.near("live mini recall matches the row", t, float(mini_row["recall_after"]), STEP + 0.0001)
	_t.eq("a recalled mini does not go off", booms[0], 0)
	_t.eq("recalled mini leaves the count", _devices().count("mini"), 0)


func _check_live_kit_payloads() -> void:
	_as_class("demolitions_caster")
	var ult = _combat.ultimate
	var owner: Vector3 = _game.player.ball_position()
	var booms := [0]
	var hear := func(_at: Vector3, _crit: bool): booms[0] += 1
	_game.events.sticky_detonated.connect(hear)
	for pair in [["minelayer", "kest_mine"], ["air_raid", "kest_raid"]]:
		ult.clear_payloads()
		ult._id = pair[0]
		var kind: String = pair[1]
		var cap: int = LAB_ROWS[kind]["cap"]
		var over := 0
		var mismatches := 0
		for i in cap * 3:
			ult._drop(owner + Vector3.RIGHT * 5.0, 0.0, 0.0)
			if ult.payloads.charges.size() > cap:
				over += 1
			if _devices().count(kind) != ult.payloads.charges.size():
				mismatches += 1
		_t.eq("%s live count never exceeds its cap" % kind, over, 0)
		_t.eq("%s ledger equals live payloads" % kind, mismatches, 0)
		_t.eq("%s fills its own kind" % kind, _devices().count(kind), cap)
		_t.eq("%s does not spend normal mini slots" % kind, _devices().count("mini"), 0)
		ult.take_charge(ult.payloads.charges[0])
		_t.eq("%s destroyed payload leaves immediately" % kind, _devices().count(kind), cap - 1)
		var destroyed: Dictionary = ult.payloads.charges[0]
		destroyed["node"].free()
		_t.eq("%s external destruction leaves the count" % kind, _devices().count(kind), cap - 2)
		_t.eq("%s external destruction leaves the manager" % kind, ult.payloads.charges.has(destroyed), false)
		var charge: Dictionary = ult.payloads.charges[0]
		charge["pos"] = owner + Vector3.RIGHT * 65.0
		booms[0] = 0
		_combat._step_devices(0.99)
		_t.eq("%s stays before recall deadline" % kind, _devices().count(kind), cap - 2)
		_combat._step_devices(0.01)
		_t.eq("%s recalled payload leaves the world" % kind, ult.payloads.charges.has(charge), false)
		_t.eq("%s recalled payload leaves the count" % kind, _devices().count(kind), cap - 3)
		_t.eq("%s recall never detonates" % kind, booms[0], 0)
		ult.clear_payloads()
		_t.eq("%s clear releases every slot" % kind, _devices().count(kind), 0)
	_game.events.sticky_detonated.disconnect(hear)
	ult._id = ""


func _check_live_stakes() -> void:
	_as_class("pylon_engineer")
	var stakes = _combat.ultimate.stakes
	stakes.set_physics_process(false)
	stakes.fold()
	var kind := "sable_stake"
	var cap: int = LAB_ROWS[kind]["cap"]
	var owner: Vector3 = _game.player.ball_position()
	var over := 0
	var mismatches := 0
	for i in cap * 3:
		stakes.plant(owner + Vector3.RIGHT * 5.0)
		if stakes.nodes.size() > cap:
			over += 1
		if _devices().count(kind) != stakes.nodes.size():
			mismatches += 1
	_t.eq("stakes never exceed the table cap", over, 0)
	_t.eq("stake ledger matches physical stakes", mismatches, 0)
	_t.eq("stakes fill their own kind", _devices().count(kind), cap)
	stakes.nodes[0].free()
	_t.eq("external stake destruction leaves the count", _devices().count(kind), cap - 1)
	_t.eq("external stake destruction leaves the manager", stakes.nodes.size(), cap - 1)
	var stake = stakes.nodes[0]
	stake.global_position = owner + Vector3.RIGHT * 65.0
	_combat._step_devices(0.99)
	_t.eq("stake stays before recall deadline", _devices().count(kind), cap - 1)
	_combat._step_devices(0.01)
	_t.eq("recalled stake leaves the manager", stakes.nodes.has(stake), false)
	_t.eq("recalled stake leaves the count", _devices().count(kind), cap - 2)
	stakes.arm()
	stakes.step(5.99)
	_t.eq("stakes survive before authored lifetime", _devices().count(kind), cap - 2)
	stakes.step(0.01)
	_t.eq("expired stakes leave every slot", _devices().count(kind), 0)
	stakes.plant(owner)
	stakes.fold()
	_t.eq("fold releases stake slots", _devices().count(kind), 0)
	stakes.set_physics_process(true)


# The ledger is per attempt: a new attempt starts every kind empty with no slot refilling.
func _check_cleared() -> void:
	if _devices() == null:
		return
	_combat.sticky.drop(_game.player.ball_position(), 0.0, 1.0, 99.0, 99.0)
	_game.events.stage_content_cleared.emit("test")
	var left := 0
	for kind in _rows():
		left += _devices().count(kind) + _devices().refilling(kind)
	_t.eq("a new attempt clears every device and slot", left, 0)


# End the run directly with every kind live. Landed payloads must leave even when
# the inherited ultimate abort returns from IDLE or only ends RECOVER.
func _check_run_ended() -> void:
	var ult = _combat.ultimate
	var stakes = ult.stakes
	stakes.set_physics_process(false)
	var booms := [0]
	var stages := [0]
	var hear := func(_at: Vector3, _crit: bool): booms[0] += 1
	var stage_clear := func(_reason: String): stages[0] += 1
	_game.events.sticky_detonated.connect(hear)
	_game.events.stage_content_cleared.connect(stage_clear)
	for phase in [ult.IDLE, ult.RECOVER]:
		var label := "run end %s" % ["IDLE" if phase == ult.IDLE else "RECOVER"]
		_combat.sticky.clear()
		ult.clear_payloads()
		stakes.fold()
		_devices().clear()
		_as_class("pylon_engineer")
		_game.player.tree._knobs["sentry"] = 4.0
		_game.player.kit.mount_face = _game.player.ball_position()
		_combat._on_dismounted_sentry(Vector3.ZERO)
		_as_class("demolitions_caster")
		var at: Vector3 = _game.player.ball_position()
		var sticky: Dictionary = _combat.sticky.throw(at, at, 0.0, 1.0, 99.0, false)
		var mini: Dictionary = _combat.sticky.drop(at, 0.0, 1.0, 99.0, 99.0)
		ult._id = "minelayer"
		var mine: Dictionary = ult._drop(at, 0.0, 1.0)
		ult._id = "air_raid"
		var raid: Dictionary = ult._drop(at, 0.0, 1.0)
		# _drop creates flight payloads; landing makes these persistent, armed payloads.
		for charge in [mine, raid]:
			charge["_inert"] = false
			charge["fuse"] = 6.0
		var stake = stakes.plant(at)
		stakes.arm()
		var ids := {"sticky": int(sticky["device_id"]), "mini": int(mini["device_id"]),
			"sentry": int(_combat._sentry["id"]), "kest_mine": int(mine["device_id"]),
			"kest_raid": int(raid["device_id"]), "sable_stake": int(stake.device_id)}
		var nodes := [sticky["node"], mini["node"], mine["node"], raid["node"], stake]
		for kind in LAB_ROWS:
			_t.eq("%s starts with live %s" % [label, kind], _devices().count(kind), 1)
			_t.eq("%s starts with registered %s" % [label, kind], _devices().kind_of(ids[kind]), kind)
		_t.check("%s starts with all physical nodes in the tree" % label,
			nodes.all(func(node): return is_instance_valid(node) and node.is_inside_tree()))
		_t.eq("%s starts with two landed payloads" % label, ult.payloads.charges.size(), 2)
		ult._id = "minelayer"
		ult._phase = phase
		_t.eq("%s starts in the intended ultimate phase" % label, ult._phase, phase)
		booms[0] = 0
		stages[0] = 0
		_game.events.run_ended.emit(phase == ult.RECOVER)
		_t.eq("%s never emits stage clear" % label, stages[0], 0)
		_check_run_end_empty(label + " immediate", ids, booms[0])
		_game.events.run_ended.emit(phase == ult.RECOVER)
		# clear() queues deletion. Force those later exits now, after repeated cleanup.
		for node in nodes:
			if is_instance_valid(node):
				node.free()
		_t.eq("%s next sticky step returns no detonation" % label, _combat.sticky.step(STEP, null, []), [])
		ult._step_payloads(STEP)
		stakes.step(STEP)
		_combat._step_devices(STEP)
		_combat._tick_sentry(STEP)
		_check_run_end_empty(label + " repeated and node exits", ids, booms[0])
		_t.eq("%s repeated cleanup never emits stage clear" % label, stages[0], 0)
	_game.events.sticky_detonated.disconnect(hear)
	_game.events.stage_content_cleared.disconnect(stage_clear)
	ult._id = ""
	stakes.set_physics_process(true)


func _check_run_end_empty(label: String, ids: Dictionary, booms: int) -> void:
	_t.eq("%s sticky manager empty" % label, _combat.sticky.charges, [])
	_t.eq("%s payload manager empty" % label, _combat.ultimate.payloads.charges, [])
	_t.eq("%s stake manager empty" % label, _combat.ultimate.stakes.nodes.size(), 0)
	_t.eq("%s sentry manager empty" % label, _combat._sentry, {})
	for kind in LAB_ROWS:
		_t.eq("%s %s live count zero" % [label, kind], _devices().count(kind), 0)
		_t.eq("%s %s refill count zero" % [label, kind], _devices().refilling(kind), 0)
		_t.eq("%s %s ledger id absent" % [label, kind], _devices().kind_of(ids[kind]), "")
	_t.eq("%s never detonates" % label, booms, 0)
