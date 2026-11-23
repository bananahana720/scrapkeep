extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Interact := preload("res://src/world/interact.gd")
const StakeDevices := preload("res://src/world/stake_devices.gd")
const Fabricators := preload("res://src/build/fabricators.gd")
const Parts := preload("res://src/build/parts.gd")

# SI2 stake devices (W13-INTEGRATION-3 SI2): a trade chest, a blood shrine and a healing
# ward each state what is paid and what is won before commitment, and none charges scrap.
#
# The model sweep, in the running game as Rivet in calm, over 20 seeds (run seed and run
# id), every device kind, every way it may be paid and every tier, each tier taken once:
#   - the cost shown (the offer and its prompt words) equals the cost charged, 100%;
#   - payout tier is monotone with cost: health shares 25/50/75% of max health or a cogs
#     price read from Fabricators.off_shelf_price, never a scrap price;
#   - no option can kill: a health price is refused unless the hull keeps the stated floor;
#   - an offer is a pure function of the device's luck stream (Interact.luck_seed), so a
#     stage restart replays it.
# The trade spots' bodies (W46-14, ruling ci), placed through the same registry:
#   - the foreman's kindness is one cached cast mesh and one glow mesh per device, the same resources on every kindness,
#     no primitive mesh; its chest stands on the greybox chest's own collider and its ward, like the greybox ward, on none;
#   - the keeper's gamble is the greybox body with its bolts and its chalk added, the same colliders as a plain device;
#   - the owner changes no offer: a device's offer is make_offer's from its luck stream, owner or not;
#   - the kindness's offer, the first time the ball reaches it, is one world_fact("kindness_offered") at its reach point
#     with the pilot's motif one note wrong (exactly one cue); once, however often the ball comes back; a gamble sends
#     none; its glow swells in its own copy of the glow material and hands back to the shared one, which never moves.
# Then in the game: one trade chest placed by the interact system's own registry, taken
# with a held E, charges what it showed; a second hold buys nothing (one purchase per
# device per stage); a stage restart refunds the stake and rebuilds the same offer.

const RIVET := 1
const SEEDS := 20

var _game
var _source := Intent.Scripted.new()
var _failures := 0
var _steps: Array = []
var _index := 0
var _ticks := 0
var _entered := false
var _device
var _before := {}
var _first_offer := {}
var _bodies_at := {}
var _facts: Array = []
var _cue_mark := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if _steps.is_empty():
		_begin()
		return false
	if _index >= _steps.size():
		print("stake_devices_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
		quit(0 if _failures == 0 else 1)
		return true
	var step: Array = _steps[_index]
	if not _entered:
		_entered = true
		_ticks = 0
		(step[0] as Callable).call()
		return false
	_ticks += 1
	if _ticks < int(step[1]):
		return false
	(step[2] as Callable).call()
	_index += 1
	_entered = false
	return false


func _begin() -> void:
	_game.player.source = _source
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(RIVET)
	_steps = [
		[_noop, 30, _noop],
		[_place, 8, _hold_e],
		[_noop, 45, _check_bought],
		[_noop, 1, _hold_e],
		[_noop, 45, _check_once],
		[_restart, 4, _check_restart],
		[_noop, 1, _sweep],
		[_bodies, 10, _check_bodies],
		[_away, 6, _noop],
		[_back, 10, _check_once_offered],
		[_to_gamble, 10, _check_gamble_silent],
	]


func _noop() -> void:
	pass


func _luck(run_seed: int, run_id: String, device_id: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = Interact.luck_seed(run_seed, run_id, 1, device_id)
	return rng


# What a payout is worth on one ladder: a part's power tier read from Parts, else its number.
func _rank(o: Dictionary) -> float:
	if String(o["win_kind"]) == "part":
		var d: Resource = Parts.def(String(o["win"]))
		return float(d.tier) if d != null else -1.0
	return float(o["win"])


func _stat(run, cost_kind: String) -> float:
	match cost_kind:
		"hp":
			return run.hp
		"cogs":
			return float(run.cogs)
		"cores":
			return float(run.bonus_cores)
	return NAN


func _sweep() -> void:
	var run = _game.run
	var takes := 0
	var shown_ok := 0
	var monotone_ok := 0
	var ladders := 0
	var floor_ok := 0
	var floor_cases := 0
	var replay_ok := 0
	var scrap_priced := 0
	var priced_from_table := 0
	var cog_offers := 0
	var paid_ok := 0
	var parts_seen := {}
	var kinds_seen := {}
	var stated_floor := 0
	for i in SEEDS:
		var run_seed := 1000 + i
		var run_id := "si2-r%d" % i
		for kind in StakeDevices.KINDS:
			kinds_seen[kind] = true
			for pay in StakeDevices.pays(kind):
				# The whole ladder is offered first, as a pocket of three would stand at once.
				var ladder: Array = []
				for tier in StakeDevices.TIERS:
					var device_id := "%s_%s_%d" % [kind, pay, tier]
					var o: Dictionary = StakeDevices.make_offer(kind, tier, pay, run, _luck(run_seed, run_id, device_id))
					var again: Dictionary = StakeDevices.make_offer(kind, tier, pay, run, _luck(run_seed, run_id, device_id))
					if o == again:
						replay_ok += 1
					if String(o.get("cost_kind", "")) == "scrap":
						scrap_priced += 1
					if String(o.get("win_kind", "")) == "part":
						parts_seen[String(o["win"])] = true
					if String(o.get("cost_kind", "")) == "cogs":
						cog_offers += 1
						var tier_of: int = Parts.def(String(o["win"])).tier if Parts.def(String(o["win"])) != null else -1
						var table := Fabricators.off_shelf_price(tier_of, 0)
						if int(o["cost"]) == table:
							priced_from_table += 1
					ladder.append(o)
				for o: Dictionary in ladder:
					var tier: int = o["tier"]
					# Take it once from a known hull and wallet.
					run.hp = run.max_hp * (0.2 if kind == "healing_ward" else 1.0)
					run.cogs = 1000
					run.bonus_cores = StakeDevices.TIERS.size()
					var cost_kind := String(o["cost_kind"])
					var before := _stat(run, cost_kind)
					var scrap_before: int = run.scrap
					var hp_before: float = run.hp
					var max_before: float = run.max_hp
					var parts_before: int = run.parts.size()
					var shown_words: String = StakeDevices.offer_words(o)
					var r: Dictionary = StakeDevices.take(o, run, Vector3.ZERO)
					takes += 1
					var charged := before - _stat(run, cost_kind)
					# A max-health part the payout bolts on raises the hull by its gain (set_max_hp).
					if cost_kind == "hp":
						charged += run.max_hp - max_before
					if bool(r.get("ok", false)) and is_equal_approx(charged, float(o["cost"])) and int(r.get("charged", -1)) == int(o["cost"]) and shown_words.contains(str(int(o["cost"]))):
						shown_ok += 1
					else:
						print("  shown/charged mismatch: %s %s tier %d shown %s words \"%s\" charged %.2f result %s" % [kind, pay, tier, o.get("cost"), shown_words, charged, r])
					var paid := false
					match String(o["win_kind"]):
						"part":
							# An evolution the new part completes may follow it onto the list.
							paid = run.parts.size() > parts_before and String(run.parts[parts_before]) == String(o["win"]) and _rank(o) == float(tier)
						"scrap":
							paid = run.scrap - scrap_before == int(o["win"])
						"heal":
							paid = is_equal_approx(run.hp - hp_before, minf(float(o["win"]), run.max_hp - hp_before))
					if paid and run.alive():
						paid_ok += 1
					else:
						print("  payout mismatch: %s %s tier %d offer %s" % [kind, pay, tier, o])
					# The floor: one HP short of cost plus floor is refused and changes nothing;
					# exactly cost plus floor is taken and leaves the hull at the floor.
					if cost_kind == "hp":
						floor_cases += 1
						var fl: float = float(o.get("floor", -1))
						stated_floor = int(o.get("floor", -1))
						run.hp = float(o["cost"]) + fl - 1.0
						var short_hp: float = run.hp
						var refused: bool = not StakeDevices.can_take(o, run) and not bool(StakeDevices.take(o, run, Vector3.ZERO).get("ok", true)) and run.hp == short_hp
						run.hp = float(o["cost"]) + fl
						var max_at: float = run.max_hp
						var taken: bool = StakeDevices.can_take(o, run) and bool(StakeDevices.take(o, run, Vector3.ZERO).get("ok", false))
						if refused and taken and is_equal_approx(run.hp - (run.max_hp - max_at), fl) and fl > 0.0 and run.alive() and int(o.get("floor", -1)) == int(fl):
							floor_ok += 1
						else:
							print("  floor breach: %s %s tier %d cost %s floor %.1f hp %.1f refused %s taken %s" % [kind, pay, tier, o["cost"], fl, run.hp, refused, taken])
					else:
						var wallet := float(o["cost"]) - 1.0
						if cost_kind == "cogs":
							run.cogs = int(wallet)
						else:
							run.bonus_cores = int(wallet)
						var refused_wallet: bool = not StakeDevices.can_take(o, run) and not bool(StakeDevices.take(o, run, Vector3.ZERO).get("ok", true)) and _stat(run, cost_kind) == wallet
						floor_cases += 1
						if refused_wallet:
							floor_ok += 1
						else:
							print("  short wallet bought: %s %s tier %d" % [kind, pay, tier])
				ladders += 1
				var mono := true
				for t in range(1, ladder.size()):
					mono = mono and float(ladder[t]["cost"]) >= float(ladder[t - 1]["cost"]) and _rank(ladder[t]) >= _rank(ladder[t - 1])
				mono = mono and (float(ladder[-1]["cost"]) > float(ladder[0]["cost"]) or _rank(ladder[-1]) > _rank(ladder[0]))
				if mono:
					monotone_ok += 1
				else:
					print("  ladder not monotone: %s %s %s" % [kind, pay, ladder.map(func(o): return [o["cost"], _rank(o)])])
	run.hp = run.max_hp
	run.cogs = 0
	run.bonus_cores = 0
	_report("three kinds", kinds_seen.size() == 3 and kinds_seen.has("trade_chest") and kinds_seen.has("blood_shrine") and kinds_seen.has("healing_ward"),
		"device kinds %s" % [kinds_seen.keys()])
	_report("cost shown equals cost charged", takes > 0 and shown_ok == takes,
		"%d of %d takes over %d seeds charged exactly the shown cost, named in the prompt" % [shown_ok, takes, SEEDS])
	_report("the stated payout lands", takes > 0 and paid_ok == takes, "%d of %d takes paid what the offer showed" % [paid_ok, takes])
	_report("payout monotone with cost", ladders > 0 and monotone_ok == ladders, "%d of %d tier ladders rise in cost and payout together" % [monotone_ok, ladders])
	_report("no option can kill", floor_cases > 0 and floor_ok == floor_cases and stated_floor > 0,
		"%d of %d short-hull or short-wallet cases refused, exact cost plus floor %d HP leaves the floor" % [floor_ok, floor_cases, stated_floor])
	_report("no scrap price", scrap_priced == 0, "%d offers priced in scrap" % scrap_priced)
	_report("cogs prices off the shelf", cog_offers > 0 and priced_from_table == cog_offers, "%d of %d cogs prices equal Fabricators.off_shelf_price" % [priced_from_table, cog_offers])
	_report("an offer replays from its stream", replay_ok == takes and parts_seen.size() >= 2,
		"%d of %d offers rebuilt identically from the same seed; %d distinct parts across seeds" % [replay_ok, takes, parts_seen.size()])


# A trade chest the interact registry builds, 4 m ahead of the ball, which looks at it.
func _place() -> void:
	var interact = _game.world.interact
	var ball: Vector3 = _game.player.ball_position()
	var at: Vector3 = _game.ctx.terrain.drop_point(ball.x, ball.z + 10.0, 0.0)
	_device = Interact.DEVICES["trade_chest"].new()
	interact.add_child(_device)
	_device.global_position = at
	_device.setup(_game.ctx, interact, {"id": "si2_chest", "device": "trade_chest", "tier": 2, "pay": "health", "at": Vector2(at.x, at.z)})
	interact.register(_device)
	_first_offer = _device.offer.duplicate()
	var front: Vector3 = _device.global_position + _device.global_basis.z * 4.0
	var spot: Vector3 = _game.ctx.terrain.drop_point(front.x, front.z, 1.05)
	_game.player.reset_to(spot, Vector3.ZERO)
	_game.player.body().global_position = spot
	_game.player.set_frozen(true)
	_game.camera.snap(-_device.global_basis.z)
	_game.run.hp = _game.run.max_hp
	_before = {"hp": _game.run.hp, "parts": _game.run.parts.size()}


func _hold_e() -> void:
	_source.press["mount_pressed"] = true
	_source.hold["mount_held"] = true


func _check_bought() -> void:
	_source.hold = {}
	var o: Dictionary = _device.offer
	var charged: float = float(_before["hp"]) - _game.run.hp
	_report("held E buys what it showed", _device.spent and is_equal_approx(charged, float(o.get("cost", -1))) and _game.run.parts.size() == int(_before["parts"]) + 1 and String(_game.run.parts[-1]) == String(o.get("win", "")),
		"chest showed \"%s\": charged %.1f HP, parts %d -> %d, spent %s" % [_device.words(), charged, _before["parts"], _game.run.parts.size(), _device.spent])
	_before = {"hp": _game.run.hp, "parts": _game.run.parts.size()}


func _check_once() -> void:
	_source.hold = {}
	_report("one purchase per device per stage", not _device.ready_now() and _game.run.hp == float(_before["hp"]) and _game.run.parts.size() == int(_before["parts"]),
		"a second hold: hp %.1f (was %.1f), parts %d (was %d)" % [_game.run.hp, _before["hp"], _game.run.parts.size(), _before["parts"]])


# R: the run rewinds to the stage start and the stage's devices are rebuilt; a chest built
# from the same spec makes the same offer.
func _restart() -> void:
	_source.hold = {}
	_game.flow.retry_stage()
	var interact = _game.world.interact
	interact.unregister(_device)
	_device.queue_free()
	_device = Interact.DEVICES["trade_chest"].new()
	interact.add_child(_device)
	_device.setup(_game.ctx, interact, {"id": "si2_chest", "device": "trade_chest", "tier": 2, "pay": "health"})
	interact.register(_device)


func _check_restart() -> void:
	_report("a restart replays the same offer", _device.offer == _first_offer and _device.ready_now() and _game.run.retries == 1,
		"after retry %d the chest offers %s (first %s)" % [_game.run.retries, _device.offer, _first_offer])



# --- the bodies ---

func _new_device(id: String, kind: String, pay: String, owner: String, at: Vector3, tier := 1):
	var interact = _game.world.interact
	var device = Interact.DEVICES[kind].new()
	interact.add_child(device)
	device.global_position = at
	var spec := {"id": id, "device": kind, "tier": tier, "pay": pay, "at": Vector2(at.x, at.z)}
	if owner != "":
		spec["owner"] = owner
	device.setup(_game.ctx, interact, spec)
	interact.register(device)
	_bodies_at[id] = device
	return device


func _shapes(device) -> Array:
	var out: Array = []
	for shape: CollisionShape3D in device.find_children("*", "CollisionShape3D", true, false):
		out.append([(shape.shape as BoxShape3D).size if shape.shape is BoxShape3D else shape.shape.get_class(), (shape.get_parent() as Node3D).position])
	return out


func _bodies() -> void:
	_game.run.hp = _game.run.max_hp
	_game.run.cogs = 500
	var ball: Vector3 = _game.player.ball_position()
	var drop := func(dx: float, dz: float) -> Vector3: return _game.ctx.terrain.drop_point(ball.x + dx, ball.z + dz, 0.0)
	var kindness = _new_device("w46_kindness_chest", "trade_chest", "cogs", "kindness", drop.call(0.0, 10.0), 2)
	_new_device("w46_kindness_chest_b", "trade_chest", "cogs", "kindness", drop.call(40.0, 10.0), 2)
	_new_device("w46_kindness_ward", "healing_ward", "cores", "kindness", drop.call(-40.0, 10.0))
	_new_device("w46_plain_ward", "healing_ward", "cores", "", drop.call(-40.0, 40.0))
	_new_device("w46_gamble_chest", "trade_chest", "health", "gamble", drop.call(40.0, 40.0), 2)
	_new_device("w46_plain_chest", "trade_chest", "health", "", drop.call(0.0, 60.0), 2)
	_new_device("w46_gamble_shrine", "blood_shrine", "health", "gamble", drop.call(80.0, 40.0))
	_game.ctx.events.world_fact.connect(func(kind: String, at: Vector3): _facts.append([kind, at]))
	var audio = _game.audio()
	_cue_mark = audio.cue_log_total if audio != null else 0
	_face(kindness)


# The ball set 4 m in front of a device, looking at it, so the interact system reaches it.
func _face(device) -> void:
	var front: Vector3 = device.global_position + device.global_basis.z * 4.0
	var spot: Vector3 = _game.ctx.terrain.drop_point(front.x, front.z, 1.05)
	_game.player.set_frozen(false)
	_game.player.reset_to(spot, Vector3.ZERO)
	_game.player.body().global_position = spot
	_game.player.set_frozen(true)
	_game.camera.snap(-device.global_basis.z)


func _check_bodies() -> void:
	var kindness = _bodies_at["w46_kindness_chest"]
	var twin = _bodies_at["w46_kindness_chest_b"]
	var ward = _bodies_at["w46_kindness_ward"]
	var body := kindness.get_node_or_null("KindnessBody") as MeshInstance3D
	var glow := kindness.get_node_or_null("KindnessGlow") as MeshInstance3D
	var twin_glow := twin.get_node("KindnessGlow") as MeshInstance3D
	_report("kindness body", body != null and glow != null and body.mesh is ArrayMesh and glow.mesh is ArrayMesh
		and body.material_override == StakeDevices.cast_material() and twin_glow.material_override == StakeDevices.glow_material(), "a cast mesh and a glow mesh")
	_report("kindness shares its meshes and materials", twin.get_node("KindnessBody").mesh == body.mesh and twin_glow.mesh == glow.mesh
		and twin.get_node("KindnessBody").material_override == body.material_override, "one cached mesh per piece")
	# The swell lights the offering device's own copy; the shared glow, on its twin, stays at rest.
	var own := glow.material_override as StandardMaterial3D
	_report("the swell is the offering kindness's own, the shared glow stays at rest", own != StakeDevices.glow_material()
		and own.emission == StakeDevices.glow_material().emission and is_equal_approx(StakeDevices.glow_material().emission_energy_multiplier, StakeDevices.KINDNESS_GLOW),
		"%s / %.2f" % [own, StakeDevices.glow_material().emission_energy_multiplier])
	kindness._pulse.custom_step(StakeDevices.PULSE_S + 0.1)
	_report("settled, the kindness draws the shared glow again", glow.material_override == StakeDevices.glow_material(), str(glow.material_override))
	var prims: Array = []
	for id in ["w46_kindness_chest", "w46_kindness_ward"]:
		for view: MeshInstance3D in _bodies_at[id].find_children("*", "MeshInstance3D", true, false):
			if view.mesh is PrimitiveMesh:
				prims.append("%s/%s" % [id, view.name])
	_report("kindness draws no primitive", prims.is_empty(), str(prims))
	_report("kindness chest stands on the greybox chest's collider", _shapes(kindness) == _shapes(_bodies_at["w46_plain_chest"]), str(_shapes(kindness)))
	_report("kindness ward has the greybox ward's colliders (none)", _shapes(ward) == _shapes(_bodies_at["w46_plain_ward"]), str(_shapes(ward)))
	var gamble = _bodies_at["w46_gamble_chest"]
	_report("gamble is bolted and chalked", gamble.get_node_or_null("GambleBolts") != null and gamble.get_node_or_null("GambleChalk") != null
		and _bodies_at["w46_gamble_shrine"].get_node_or_null("GambleChalk") != null, "")
	_report("gamble keeps the greybox colliders", _shapes(gamble) == _shapes(_bodies_at["w46_plain_chest"]), str(_shapes(gamble)))
	var same := true
	for id in _bodies_at:
		var device = _bodies_at[id]
		var o: Dictionary = StakeDevices.make_offer(device.kind, int(device.spec.get("tier", 1)), String(device.spec.get("pay", "")), _game.run,
			_game.world.interact.luck(id), _game.ctx.tuning != null and _game.ctx.tuning.option("marked_hull") == "on")
		same = same and o == device.offer
	_report("an owner changes no offer", same, "every device's offer is make_offer's")
	_report("the kindness made its offer once, on the bus", _facts.size() == 1 and _facts[0][0] == StakeDevices.KINDNESS_FACT
		and (_facts[0][1] as Vector3).is_equal_approx(kindness.reach_point()) and kindness.offered(), str(_facts))
	var audio = _game.audio()
	_report("the game has audio to hear the chime", audio != null, "")
	if audio != null:
		var cues: Array = audio.cues_since(_cue_mark).filter(func(row: Array): return String(row[1]) == "kindness_chime")
		_report("its sound is the sterile on-grid kindness chime, once", cues.size() == 1 and cues[0][1] == "kindness_chime",
			str(cues))


func _away() -> void:
	_face(_bodies_at["w46_plain_chest"])


func _back() -> void:
	_face(_bodies_at["w46_kindness_chest"])


func _check_once_offered() -> void:
	_report("the offer is made once", _facts.size() == 1, str(_facts))


func _to_gamble() -> void:
	_face(_bodies_at["w46_gamble_chest"])


func _check_gamble_silent() -> void:
	_report("a gamble makes no kindness offer", _facts.size() == 1 and not _bodies_at["w46_gamble_chest"].offered(), str(_facts))
