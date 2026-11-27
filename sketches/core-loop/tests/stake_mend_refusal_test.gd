extends SceneTree

const HullMark := preload("res://src/world/hull_mark.gd")
const RunState := preload("res://src/core/run_state.gd")
const Ward := preload("res://src/world/stake_devices.gd")
const Interact := preload("res://src/world/interact.gd")
const Interactables := preload("res://src/world/interactables.gd")

# The mend ward refuses, and charges nothing, when a heal would restore no health and lift
# no mark; a marked hull and a hurt hull still mend.

const TICK := 0.05

var _failures := 0


class FakeEvents:
	signal interact_armed(family: String, device_id: String, at: Vector3)
	signal interact_fired(family: String, device_id: String, at: Vector3)


class FakeFlow:
	func in_stage() -> bool:
		return true


class FakeIntent:
	var interact_pressed := false
	var mount_held := false


class FakePlayer:
	var drive_basis := Basis.IDENTITY
	var intent := FakeIntent.new()

	func ball_position() -> Vector3:
		return Vector3.ZERO


class FakeCtx:
	var run
	var tuning = null
	var terrain = null
	var events := FakeEvents.new()
	var flow := FakeFlow.new()
	var player := FakePlayer.new()
	var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_run.call_deferred()


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _run() -> void:
	var tier := 1
	# Full, unmarked hull: refused, nothing changes.
	var run := RunState.new()
	run.bonus_cores = 3
	var o := Ward.make_offer("healing_ward", tier, "cores", run, RandomNumberGenerator.new())
	var open := Ward.can_take(o, run)
	var r := Ward.take(o, run, Vector3.ZERO)
	_check("full hull refused", not open and not bool(r.get("ok", true)) and int(r.get("charged", -1)) == 0
		and run.bonus_cores == 3 and run.hp == run.max_hp and HullMark.held(run) == 0.0,
		"can_take %s, result %s, cores %d, hp %.1f/%.1f" % [open, r, run.bonus_cores, run.hp, run.max_hp])

	# Marked hull sitting at its lowered ceiling: allowed, ends full and unmarked, charged the cost.
	run = RunState.new()
	HullMark.stake(run, 30.0)
	run.hp = run.max_hp
	run.bonus_cores = 3
	var marked_max := run.max_hp
	o = Ward.make_offer("healing_ward", tier, "cores", run, RandomNumberGenerator.new())
	open = Ward.can_take(o, run)
	r = Ward.take(o, run, Vector3.ZERO)
	_check("marked hull mends", open and bool(r.get("ok", false)) and int(r.get("charged", -1)) == int(o["cost"])
		and run.bonus_cores == 3 - int(o["cost"]) and HullMark.held(run) == 0.0
		and run.max_hp > marked_max and is_equal_approx(run.hp, run.max_hp),
		"can_take %s, result %s, cores %d, hp %.1f/%.1f, mark %.1f" % [open, r, run.bonus_cores, run.hp, run.max_hp, HullMark.held(run)])

	# Hull below its ceiling: allowed as before.
	run = RunState.new()
	run.hp = run.max_hp - 40.0
	run.bonus_cores = 3
	var hurt := run.hp
	o = Ward.make_offer("healing_ward", tier, "cores", run, RandomNumberGenerator.new())
	open = Ward.can_take(o, run)
	r = Ward.take(o, run, Vector3.ZERO)
	_check("hurt hull mends", open and bool(r.get("ok", false)) and run.hp > hurt and run.bonus_cores == 3 - int(o["cost"]),
		"can_take %s, result %s, cores %d, hp %.1f -> %.1f" % [open, r, run.bonus_cores, hurt, run.hp])

	_devices()
	print("stake_mend_refusal_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _rig(tier: int, hp_lost: float, cores: int, marked := 0.0) -> Dictionary:
	var ctx := FakeCtx.new()
	ctx.run = RunState.new()
	if marked > 0.0:
		HullMark.stake(ctx.run, marked)
	ctx.run.hp = ctx.run.max_hp - hp_lost
	ctx.run.bonus_cores = cores
	var interact := Interact.new()
	interact.ctx = ctx
	interact.set_physics_process(false)
	root.add_child(interact)
	var ward := Ward.new()
	interact.add_child(ward)
	ward.global_position = Vector3(0.0, 0.0, -6.0)
	ward.setup(ctx, interact, {"id": "ward", "device": "healing_ward", "tier": tier, "pay": "cores"})
	interact.register(ward)
	var heard := {"armed": 0, "fired": 0}
	ctx.events.interact_armed.connect(func(_family: String, _id: String, _at: Vector3): heard["armed"] += 1)
	ctx.events.interact_fired.connect(func(_family: String, _id: String, _at: Vector3): heard["fired"] += 1)
	return {"ctx": ctx, "interact": interact, "ward": ward, "heard": heard}


func _hold(rig: Dictionary, seconds: float, press := true) -> void:
	var intent = rig["ctx"].player.intent
	intent.mount_held = true
	for i in ceili(seconds / TICK):
		intent.interact_pressed = press and i == 0
		rig["interact"]._physics_process(TICK)
	intent.interact_pressed = false


func _release(rig: Dictionary) -> void:
	rig["ctx"].player.intent.mount_held = false
	rig["interact"]._physics_process(TICK)


func _drop(rig: Dictionary) -> void:
	rig["interact"].free()


func _devices() -> void:
	var full := _rig(1, 0.0, 3)
	var ward = full["ward"]
	var run = full["ctx"].run
	_hold(full, Interactables.HOLD_SECONDS * 3.0)
	_check("device: a full hull's ward is not ready and its ring is empty", not ward.ready_now() and ward.gauge() == 0.0
		and ward.prompt.gauge == 0.0, "ready %s, gauge %s, drawn %s" % [ward.ready_now(), ward.gauge(), ward.prompt.gauge])
	_check("device: a full hull's ward shows no key and no price", ward.prompt.keycap == "" and ward.sign_words() == ""
		and full["interact"].target == null, "keycap '%s', sign '%s'" % [ward.prompt.keycap, ward.sign_words()])
	_check("device: a hold on a full hull's ward arms nothing, fires nothing and charges nothing",
		full["heard"] == {"armed": 0, "fired": 0} and run.bonus_cores == 3 and not ward.spent, "heard %s, cores %d" % [full["heard"], run.bonus_cores])
	var acted: bool = ward.fire()
	full["interact"].fire(ward)
	_check("device: a refused take is not a fire", not acted and full["heard"]["fired"] == 0 and not ward.spent
		and not bool(ward.last.get("ok", true)) and run.bonus_cores == 3, "fire() %s, heard %s, last %s" % [acted, full["heard"], ward.last])
	_drop(full)

	var poor := _rig(2, 40.0, 1)
	ward = poor["ward"]
	_hold(poor, Interactables.HOLD_SECONDS * 3.0)
	_check("device: a hurt hull one core short of two reads a half ring", not ward.ready_now() and is_equal_approx(ward.gauge(), 0.5)
		and is_equal_approx(ward.prompt.gauge, 0.5) and ward.prompt.keycap == "", "gauge %s, drawn %s" % [ward.gauge(), ward.prompt.gauge])
	_check("device: a hurt hull's ward keeps its price on the sign", ward.sign_words() == Ward.offer_words(ward.offer) and ward.sign_words() != "",
		"sign '%s'" % ward.sign_words())
	_check("device: a hold on a ward the hull cannot pay fires nothing", poor["heard"] == {"armed": 0, "fired": 0}
		and poor["ctx"].run.bonus_cores == 1 and not ward.fire(), "heard %s" % [poor["heard"]])
	poor["ctx"].run.bonus_cores = 0
	_check("device: no cores reads an empty ring", ward.gauge() == 0.0, "gauge %s" % ward.gauge())
	_drop(poor)

	var hurt := _rig(1, 40.0, 3)
	ward = hurt["ward"]
	run = hurt["ctx"].run
	var before: float = run.hp
	_check("device: a hurt hull that can pay reads a full ring and is ready", ward.ready_now() and is_equal_approx(ward.gauge(), 1.0)
		and ward.sign_words() == Ward.offer_words(ward.offer), "ready %s, gauge %s" % [ward.ready_now(), ward.gauge()])
	_hold(hurt, Interactables.HOLD_SECONDS + TICK * 2.0)
	_check("device: a full hold mends once, arms once and fires once", hurt["heard"] == {"armed": 1, "fired": 1} and ward.spent
		and run.bonus_cores == 2 and run.hp > before, "heard %s, cores %d, hp %.1f -> %.1f" % [hurt["heard"], run.bonus_cores, before, run.hp])
	_release(hurt)
	_hold(hurt, Interactables.HOLD_SECONDS * 3.0)
	_check("device: a spent ward takes no second payment", hurt["heard"] == {"armed": 1, "fired": 1} and run.bonus_cores == 2,
		"heard %s, cores %d" % [hurt["heard"], run.bonus_cores])
	_drop(hurt)

	var mended := _rig(1, 40.0, 3)
	ward = mended["ward"]
	run = mended["ctx"].run
	_hold(mended, Interactables.HOLD_SECONDS * 0.5)
	var filling: float = mended["interact"].hold_fraction()
	run.hp = run.max_hp
	_hold(mended, Interactables.HOLD_SECONDS * 3.0, false)
	_check("device: a hold lets go when the hull fills before it lands", filling > 0.0 and mended["interact"].hold_fraction() == 0.0
		and mended["heard"] == {"armed": 0, "fired": 0} and run.bonus_cores == 3 and not ward.spent,
		"filled to %.2f, then %.2f, heard %s, cores %d" % [filling, mended["interact"].hold_fraction(), mended["heard"], run.bonus_cores])
	_drop(mended)

	var marked := _rig(1, 0.0, 3, 30.0)
	ward = marked["ward"]
	_check("device: a marked hull at its lowered ceiling is offered the mend", ward.ready_now() and is_equal_approx(ward.gauge(), 1.0)
		and ward.sign_words() != "", "ready %s, gauge %s, sign '%s'" % [ward.ready_now(), ward.gauge(), ward.sign_words()])
	_drop(marked)
