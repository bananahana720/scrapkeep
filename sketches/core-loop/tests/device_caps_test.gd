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
	_check_cap_pure()
	_check_refill_pure()
	_check_recall_pure()
	_check_live_minis()
	_check_live_thrown()
	_check_live_sentry()
	_check_live_recall()
	_check_cleared()
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
		_t.check("%s reached its cap" % kind, worst[kind] == ledger.cap(kind), "peak %d, cap %d" % [worst[kind], ledger.cap(kind)])


# A destroyed device leaves the count at once; its slot comes back after the row's refill.
func _check_refill_pure() -> void:
	for kind in _rows():
		var row: Dictionary = _rows()[kind]
		var ledger = Devices.new()
		var ids := []
		for i in ledger.cap(kind):
			ids.append(int(ledger.deploy(kind, Vector3.ZERO)["id"]))
		_t.eq("%s fills to cap" % kind, ledger.count(kind), ledger.cap(kind))
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
	for kind in _rows():
		var row: Dictionary = _rows()[kind]
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
	_combat._rebuild_patterns()


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


# Live Sentry Post: one turret per dismount, replaced by the next; it expires on its knob;
# its slot refills after the row's refill time.
func _check_live_sentry() -> void:
	if _devices() == null:
		return
	_as_class("pylon_engineer")
	var row: Dictionary = _rows()["sentry"]
	var knobs: Dictionary = _game.player.tree._knobs
	knobs["sentry"] = 4.0
	# The pylon face the pilot steps off is beside the pilot, inside the leash.
	_game.player.kit.mount_face = _game.player.ball_position()
	_combat._on_dismounted_sentry(Vector3.ZERO)
	_t.check("dismount leaves a sentry", not _combat._sentry.is_empty())
	_t.eq("one sentry counted", _devices().count("sentry"), 1)
	for i in 3:
		_combat._on_dismounted_sentry(Vector3.ZERO)
	_t.eq("sentries never above the cap", _devices().count("sentry"), _devices().cap("sentry"))
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
	var row: Dictionary = _rows()["sentry"]
	_combat._sentry["at"] = owner + Vector3(float(row["leash_m"]) + 5.0, 0.0, 0.0)
	_combat._sentry["left"] = 99.0
	var t := 0.0
	while not _combat._sentry.is_empty() and t < LIMIT:
		_combat._step_devices(STEP)
		t += STEP
	_t.near("live sentry recall matches the row", t, float(row["recall_after"]), STEP + 0.0001)
	_t.eq("recalled sentry leaves the count", _devices().count("sentry"), 0)
	_as_class("demolitions_caster")
	var mini_row: Dictionary = _rows()["mini"]
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
