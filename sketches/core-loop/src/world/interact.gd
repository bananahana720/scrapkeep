extends Node3D

const Interactables := preload("res://src/world/interactables.gd")
const RollThrough := preload("res://src/world/roll_through.gd")
const TravelDevice := preload("res://src/world/travel_device.gd")

# The interact key's system (LOOP-REDESIGN section 9). Each physics tick it finds the
# device E would reach, runs that device's consent and steps every device. The player
# asks claims() before it lets E mount a pylon, so an interactable in reach always wins
# over a face. World creates it; its devices are the stage's map's PLACEMENTS plus any a map
# module registers (the lift, writer L1).
#
# Consent, by the family row:
#   roll   E inside the lane arms the device's RollThrough; it fires on the mouth.
#   hold   E held HOLD_SECONDS, the class ring round the reticle filling; release or
#          leave reach first and nothing happens, so a tap never fires.
#   press  E once.
#
# Facts (game_events.gd): interact_armed when consent is given, interact_fired when the
# device acts; the altar adds ambush_ended and the crate bet_resolved.

const DEVICES := {
	"ambush_altar": preload("res://src/world/ambush_altar.gd"),
	"cracked_cache": preload("res://src/world/cracked_cache.gd"),
	"bet_crate": preload("res://src/world/bet_crate.gd"),
	# Stake devices (SI2): one script, its kind read from the spec's `device`. Each draws
	# from luck(spec id), the stream bet_crate.gd uses, so a restart rebuilds the same offer.
	"trade_chest": preload("res://src/world/stake_devices.gd"),
	"blood_shrine": preload("res://src/world/stake_devices.gd"),
	"healing_ward": preload("res://src/world/stake_devices.gd"),
}

var ctx
var devices: Array = []
# The device E reaches this tick, or null, and the lock it keeps (see find_target).
var target = null
var lock = null
var _hold := {}
var _last_ball := Vector3.INF
var _owned: Array = []


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Interact"
	ctx.events.stage_entered.connect(_on_stage_entered)
	ctx.events.stage_content_cleared.connect(func(_reason: String): clear())


func _on_stage_entered(stage: int, _retry: bool) -> void:
	clear()
	for spec in Interactables.PLACEMENTS.get(String(ctx.stages.of(stage).get("map", "")), []):
		var device: Node3D = DEVICES[spec["device"]].new()
		add_child(device)
		var at: Vector2 = spec["at"]
		device.global_position = ctx.terrain.drop_point(at.x, at.y, 0.0)
		var face: Vector2 = spec.get("face", Vector2(0.0, 1.0))
		device.rotation.y = atan2(face.x, face.y)
		device.setup(ctx, self, spec)
		_owned.append(device)
		devices.append(device)
	# A map's relic_spot holds a cache that always offers a relic, its cracked wall facing the
	# spawn. This handler runs before world.gd swaps the terrain in, and the cache reads the
	# ground under its chest and pedestals as it builds, so it is built once the swap is done.
	var m = ctx.terrain.map_for(stage)
	if not "relic_spot" in m:
		return
	_place_relic_cache.call_deferred(stage)


# Deferred from _on_stage_entered, so it can land after this node or its game is gone.
func _place_relic_cache(stage: int) -> void:
	if not is_inside_tree() or ctx == null:
		return
	if ctx.terrain.stage != stage or ctx.run.stage != stage:
		return
	if _owned.any(func(d): return is_instance_valid(d) and d.id == "relic_cache"):
		return
	var m = ctx.terrain.map_for(stage)
	if not "relic_spot" in m:
		return
	var spot: Vector2 = m.relic_spot
	var face: Vector2 = (m.spawn - spot).normalized()
	var cache: Node3D = DEVICES["cracked_cache"].new()
	cache.relic_guaranteed = true
	add_child(cache)
	cache.global_position = ctx.terrain.ground_callable(stage).call(spot.x, spot.y, 0.0)
	cache.rotation.y = atan2(face.x, face.y)
	cache.setup(ctx, self, {"id": "relic_cache", "device": "cracked_cache", "at": spot, "face": face})
	_owned.append(cache)
	devices.append(cache)


# Frees this system's own devices. A registered device stays registered: it is live
# only while it is visible in the tree, so one under a parked stage root sleeps.
func clear() -> void:
	for device in _owned:
		if is_instance_valid(device):
			device.stand_down()
			device.queue_free()
	devices = devices.filter(func(d): return is_instance_valid(d) and not d in _owned)
	_owned.clear()
	target = null
	lock = null
	_hold = {}
	_last_ball = Vector3.INF


# A device built by someone else joins the E routing for as long as it lives. The lift
# adopts roll-through this way (CONTRACTS, Interact seam).
func register(device: Node3D) -> void:
	if not device in devices:
		devices.append(device)


func unregister(device: Node3D) -> void:
	devices.erase(device)


# A roll-through travel device around a fire callable (ball, velocity) -> void. Under
# `parent` (a stage's geometry root) it is registered for good and sleeps while that
# stage is parked; with no parent it is this stage's own and goes at the next change.
func travel(device_id: String, mouth: Vector3, heading: Vector3, on_fire: Callable, parent: Node = null) -> Node3D:
	var device := TravelDevice.new()
	(parent if parent != null else self).add_child(device)
	device.global_position = mouth
	device.setup_travel(ctx, self, device_id, RollThrough.new(mouth, heading), on_fire)
	register(device)
	if parent == null:
		_owned.append(device)
	return device


static func live(device) -> bool:
	return is_instance_valid(device) and device.is_inside_tree() and device.is_visible_in_tree()


func _forward() -> Vector3:
	return -ctx.player.drive_basis.z


# The device E would reach now. While a hold runs it is the held device, as long as its
# lock holds. Otherwise the nearest ready device it can lock, and failing that the last
# lock while it holds, so a device the ball has just passed keeps E.
func find_target():
	if ctx == null or not ctx.flow.in_stage():
		return null
	var ball: Vector3 = ctx.player.ball_position()
	if not _hold.is_empty():
		var held = _hold["device"]
		return held if live(held) and held.ready_now() and held.holds_lock(ball) else null
	var forward := _forward()
	var best = null
	var best_d := INF
	for device in devices:
		if not live(device) or not device.ready_now() or not device.acquirable(ball, forward):
			continue
		var d: float = ball.distance_to(device.reach_point())
		if d < best_d:
			best = device
			best_d = d
	if best == null and live(lock) and lock.ready_now() and lock.holds_lock(ball):
		best = lock
	return best


# The player's question before E mounts: does an interactable take this press? A lock
# beyond REACH yields when Sable has a face to mount (face_in_reach).
func claims(face_in_reach := false) -> bool:
	var device = find_target()
	return device != null and (not face_in_reach or device.near(ctx.player.ball_position()))


# The class ring round the reticle while a hold arms, 0 to 1.
func hold_fraction() -> float:
	return clampf(float(_hold.get("seconds", 0.0)) / Interactables.HOLD_SECONDS, 0.0, 1.0) if not _hold.is_empty() else 0.0


func _physics_process(delta: float) -> void:
	if ctx == null or not ctx.flow.in_stage():
		_hold = {}
		target = null
		lock = null
		_last_ball = Vector3.INF
		return
	var ball: Vector3 = ctx.player.ball_position()
	var intent = ctx.player.intent
	target = find_target()
	lock = target
	if intent.interact_pressed and target != null:
		_consent(target)
	_step_hold(delta, intent.mount_held)
	for device in devices.duplicate():
		if not is_instance_valid(device):
			devices.erase(device)
			continue
		if not live(device):
			continue
		if device.roll != null and device.roll.step(_last_ball, ball):
			fire(device)
		device.tick(delta)
		device.show_prompt(device == target)
	_last_ball = ball


func _consent(device) -> void:
	match String(Interactables.row(device.family)["consent"]):
		"roll":
			device.roll.arm()
			_armed(device)
		"hold":
			_hold = {"device": device, "seconds": 0.0}
		_:
			_armed(device)
			fire(device)


func _step_hold(delta: float, held: bool) -> void:
	if _hold.is_empty():
		return
	var device = _hold["device"]
	if not held or not is_instance_valid(device) or device != target:
		_hold = {}
		return
	_hold["seconds"] += delta
	if _hold["seconds"] >= Interactables.HOLD_SECONDS:
		_hold = {}
		_armed(device)
		fire(device)


func _armed(device) -> void:
	ctx.events.interact_armed.emit(device.family, device.id, device.reach_point())


# A device that acts at once returns true from fire(); one with a beat before it acts
# (the crate's spin) calls fired() itself when it does.
func fire(device) -> void:
	if device.fire():
		fired(device)


func fired(device) -> void:
	ctx.events.interact_fired.emit(device.family, device.id, device.reach_point())


# The one stream of luck a device draws from this stage (a bet, a cache's picks). Its
# seed is the run's seed, the run's id, the stage and the device (luck_seed). A stage
# restart replays the same luck, so restarting never re-rolls a result; another run
# (another run_id; game.gd's SEED is one constant) rolls differently; the run log keeps
# run_id, so a replay that restores it matches. Only the id's drawn half is hashed, not its
# clock second, so a seeded run repeats whenever it runs. ctx.rng is never touched, so a
# draw cannot shift the gates' rolls.
func luck(device_id: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = luck_seed(ctx.rng.seed, ctx.run.run_id, ctx.run.stage, device_id)
	return rng


static func luck_seed(run_seed: int, run_id: String, stage: int, device_id: String) -> int:
	return hash([run_seed, run_id.get_slice("-", run_id.get_slice_count("-") - 1), stage, device_id])
