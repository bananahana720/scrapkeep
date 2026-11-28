extends SceneTree
# F6 2026-10-04: magnet_break and the Warden cap stomp are gone with the plating fight.

const AttackBudget := preload("res://src/combat/attack_budget.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const CodexEntries := preload("res://src/combat/codex_entries.gd")
const PilotBlocks := preload("res://tests/support/pilot_blocks.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")

# Combat's "enemy" codex entries: complete as data (id, category, name, hint, clue,
# text, owner, participants), and each one detected by combat's own code when the
# trick is pulled. Each trick is staged directly on the live game.

const REQUIRED := ["id", "category", "name", "hint", "clue", "text", "owner", "participants"]

# 2026-10-04: the default alpha table's stage 2 Warden fights by posture with no lesson,
# so it has no caps; the cap-stomp trick runs on the legacy table's caps Warden.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

class StateDouble extends RefCounted:
	var grounded := true

	func on_floor() -> bool:
		return grounded


class BallDouble extends RefCounted:
	var state := StateDouble.new()
	var at := Vector3.ZERO

	func ball_position() -> Vector3:
		return at


var _game
var _combat
var _source := Intent.Scripted.new()
var _failures := 0
var _step := 0
var _clock := 0.0
var _lobber: Node3D
# The wave 9 units still waiting on the ball's teleport, and where the ball started.
var _w9_units := {}
var _w9_home := Vector3.ZERO
var _roof_fall: Node3D
# Set by the last case; a script error that aborts a case leaves it false.
var _last_case_ran := false


func _initialize() -> void:
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	match _step:
		0:
			_setup()
			_data()
			_instant_tricks()
			_w7_tricks()
			_w9_settle()
			_step = 1
		1:
			# The ball's teleports land on a physics tick: first onto the floor, then off the
			# lane and the mark at cruise.
			_clock += delta
			if _game.player.ball_position().distance_to(_w9_home) < 0.5 or _clock > 1.0:
				_w9_tricks()
				_step = 2
		2:
			_clock += delta
			if _game.player.ball_position().distance_to(_w9_home) > 3.0 or _clock > 1.0:
				_w9_after_move()
				_start_shell()
				_step = 3
		3:
			_clock += delta
			var roof_done: bool = not is_instance_valid(_roof_fall) or _combat.discovered.has("roof_drop")
			if (_combat.discovered.has("shell_return") and roof_done) or _clock > 4.0:
				_report("roof_drop", _combat.discovered.has("roof_drop"),
					"a rammed prop's roof crushed the drill crew under it")
				_report("shell_return", _combat.discovered.has("shell_return"),
					"a batted shell landed on its own lobber and killed it (%.2f s after the bat)" % _clock)
				_warden_tricks()
				return _finish()
	return false


func _setup() -> void:
	_combat = _game.ctx.spawner
	_game.ctx.calm = true
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0


func _data() -> void:
	var ids := {}
	var complete := true
	for entry in _combat.codex_entries():
		for key in REQUIRED:
			var value = entry.get(key)
			var empty: bool = value == null or (value is String and value == "") or (value is Array and value.is_empty())
			complete = complete and not empty
		complete = complete and entry["category"] == "enemy"
		ids[entry["id"]] = true
	_report("data", complete and ids.size() == CodexEntries.ENTRIES.size() and ids.size() >= 5,
		"%d enemy entries, unique ids, every field filled: %s" % [ids.size(), ids.keys()])


func _chaser(offset: float, hp: float) -> Node3D:
	var ctx = _game.ctx
	var at: Vector3 = ctx.terrain.spawn_point(1) + Vector3(offset, 0.0, 60.0)
	var enemy: Node3D = ctx.spawner.spawn_enemy("chaser", ctx.terrain.drop_point(at.x, at.z, 1.6))
	enemy.hp = hp
	enemy.max_hp = hp
	return enemy


func _instant_tricks() -> void:
	var lunging := _chaser(0.0, 500.0)
	lunging.state = lunging.State.WINDUP
	_combat.strike(lunging, "ram", 14.0)
	_report("counter_ram", _combat.discovered.has("counter_ram"), "a ram on a chaser mid wind-up")

	for i in 3:
		_combat.strike(_chaser(4.0 * (i + 1), 10.0), "ram", 14.0)
	_report("crush_chain", _combat.discovered.has("crush_chain"), "three unplated one-hit ram kills in the same second")

	_game.events.dismounted.emit(Vector3(12.0, 4.0, 0.0))
	_combat.strike(_chaser(-8.0, 5.0), "runner", 10.0)
	_report("parting_shot", _combat.discovered.has("parting_shot"), "a laser kill right after a slingshot dismount")


# v2 W7: each counter's opportunity, found through the unit's own code path.
func _w7_tricks() -> void:
	var ctx = _game.ctx
	var fleet = _combat.fleet
	var base: Vector3 = ctx.terrain.spawn_point(1) + Vector3(20.0, 0.0, 40.0)
	var hooker: Node3D = ctx.spawner.spawn_enemy("hooker", ctx.terrain.drop_point(base.x, base.z, 1.6))
	hooker._catch(0.0, Vector3.ZERO, hooker.anchor())
	fleet.holds.snap(hooker, "speed")
	_report("tether_snap", _combat.discovered.has("tether_snap"), "a tether held, then snapped by speed")

	var dish: Node3D = ctx.spawner.spawn_enemy("deflector", ctx.terrain.drop_point(base.x + 8.0, base.z, 1.6))
	dish.phase = dish.Phase.LIVE
	dish._go_live()
	dish.rebounds = 1
	dish._rebound_v = Vector3(-9.0, 0.0, 0.0)
	dish._window = 0.3
	_game.events.jumped.emit(false)
	_report("shield_vault", _combat.discovered.has("shield_vault") and dish.vaults == 1,
		"a jump in a deflector's rebound window vaulted at %.1f m/s" % dish.last_vault_speed)

	var at: Vector3 = base + Vector3(-12.0, 0.0, 0.0)
	var lead: Node3D = ctx.spawner.spawn_enemy("swarm_remnant", ctx.terrain.drop_point(at.x, at.z, 1.4))
	var victim: Node3D = ctx.spawner.spawn_enemy("chaser", ctx.terrain.drop_point(at.x + 2.5, at.z, 1.6))
	lead.swarm.state = lead.swarm.State.SCATTERED
	lead._lead_into_pin()
	_combat._pin_step(_game.get_tree().get_nodes_in_group("enemy"))
	_report("awaiting_operator", _combat.discovered.has("awaiting_operator"),
		"a scattered drone led into a chaser pinned it (%d pins)" % _combat.pins)

	var hand: Node3D = ctx.spawner.spawn_enemy("mind_hand", ctx.terrain.drop_point(base.x, base.z - 10.0, 1.8))
	fleet.habits.add("ram", 5.0)
	hand._commit(Vector3(0.0, 0.0, 5.0))
	_report("what_it_learned", _combat.discovered.has("what_it_learned") and fleet.mind_memory.size() == 1,
		"a Mind's hand read the ram habit and quoted it: %s" % [fleet.mind_memory])
	for node in [hooker, dish, victim, hand]:
		if is_instance_valid(node):
			node.queue_free()
	for drone in lead.swarm.drones:
		if is_instance_valid(drone):
			drone.queue_free()


# Wave 9: the Dig and Highdraft units, each driven through its own attack. The drill,
# cutter and anchor finish now; the burrower, kite and lamps finish once the ball has
# moved off the lane and the mark at cruise speed (_w9_after_move).
func _w9_settle() -> void:
	var home: Vector3 = _game.player.ball_position()
	_w9_home = _game.ctx.terrain.drop_point(home.x, home.z, 1.05)
	_game.player.reset_to(_w9_home)
	_clock = 0.0


func _w9_tricks() -> void:
	var ctx = _game.ctx
	var fleet = _combat.fleet
	var home: Vector3 = _game.player.ball_position()

	var rig: Node3D = _w9_spawn("drill_crew", home + Vector3(10.0, 0.0, 6.0))
	rig._warn(_w9_to(rig))
	_combat.strike(rig, "slam", 14.0)
	_report("bore_breach", _combat.discovered.has("bore_breach") and rig.stopped == 1,
		"a slam on a drill crew mid-bore stopped it (stopped %d)" % rig.stopped)
	# 2026-10-17 (damage families, PR #65): a hit past the rig's plating reads its armour.
	_combat.strike(rig, "test_bolt", 40.0, "", "weapon")
	_report("armour_plated", _combat.discovered.has("armour_plated"), "a full hit on a plated drill crew reads it")

	var cutter: Node3D = _w9_spawn("line_cutter", home + Vector3(-10.0, 0.0, 8.0))
	cutter._warn(_w9_to(cutter))
	cutter.phase = cutter.Phase.LIVE
	cutter._go_live()
	cutter._t = cutter.FLIGHT + 0.01
	cutter._live(0.0)
	_report("line_cut", _combat.discovered.has("line_cut") and cutter.dodged == 1,
		"an unhooked ball in the landing ring dodged the cutter (dodged %d)" % cutter.dodged)

	var crew: Node3D = _w9_spawn("anchor_crew", home + Vector3(0.0, 0.0, 10.0))
	crew._warn(_w9_to(crew))
	crew.phase = crew.Phase.LIVE
	crew._go_live()
	var hooked: bool = fleet.holds.held(crew)
	fleet.holds.snap(crew, "jump")
	_report("deck_winch", _combat.discovered.has("deck_winch") and hooked and crew.broken_by == "jump",
		"an anchor crew hooked the ball (%s), then a jump slipped it (%s)" % [hooked, crew.broken_by])
	# A Foreman knocked out while its crew stands clocks them out.
	var foreman: Node3D = _w9_spawn("foreman", home + Vector3(-8.0, 0.0, -14.0))
	var hand: Node3D = _w9_spawn("chaser", home + Vector3(-12.0, 0.0, -14.0))
	foreman._claimed = true
	foreman._hire(hand)
	foreman.take_damage(1.0e6)
	_report("shift_over", _combat.discovered.has("shift_over") and AttackBudget.clocked_out(hand),
		"a Foreman fell with its crew standing (crew clocked out %s)" % AttackBudget.clocked_out(hand))
	var splitter: Node3D = _w9_spawn("splitter", home + Vector3(-8.0, 0.0, -6.0))
	splitter.hp = 1.0
	_combat.strike(splitter, "stomp", 30.0)
	_report("split_pop", _combat.discovered.has("split_pop") and splitter.get_meta("split", true) == false,
		"a stomp killed a Splitter clean (split %s)" % splitter.get_meta("split", null))
	# A pod whose ring held the ball at its fuse blows up on an empty ring.
	var pod: Node3D = _w9_spawn("splitter_pod", home + Vector3(-12.0, 0.0, 6.0))
	pod._warn(_w9_to(pod))
	pod._ring_had_ball = true
	pod.phase = pod.Phase.LIVE
	pod._go_live()
	_report("fuse_pod", _combat.discovered.has("fuse_pod") and pod.blasts == 1,
		"a ball out of a pod's ring when it blew (blasts %d)" % pod.blasts)
	for node in [rig, cutter, crew, hand]:
		if is_instance_valid(node):
			node.queue_free()

	# A rammed prop drops its roof on the drill crew sheltering under it. The roof lands
	# after its warning, so it reports beside the shell (step 3).
	var shoring: Node3D = _w9_spawn("prop_crew", home + Vector3(-16.0, 0.0, -12.0))
	shoring.set_physics_process(false)
	var mate: Node3D = _w9_spawn("drill_crew", shoring.roof_centre())
	mate.set_physics_process(false)
	_roof_fall = shoring.knock_prop()
	_w10_pack_tricks(home)
	_spillway_tricks(home)

	var burrower: Node3D = _w9_spawn("burrower", home + Vector3(8.0, 0.0, 0.0))
	burrower._warn(_w9_to(burrower))
	var kite: Node3D = _w9_spawn("kite_drone", home + Vector3(0.0, 0.0, 8.0))
	kite._warn(_w9_to(kite))
	var lamps: Node3D = _w9_spawn("lamp_swarm", home + Vector3(-5.0, 0.0, 0.0))
	lamps._warn(_w9_to(lamps))
	lamps.phase = lamps.Phase.LIVE
	lamps._go_live()
	_w9_units = {"burrower": burrower, "kite": kite, "lamps": lamps,
		"lane_had_ball": burrower._ring_had_ball, "mark_had_ball": kite.telegraph().contains(home)}
	var away := Vector3(0.0, 0.0, -4.0)
	_game.player.reset_to(home + away, away.normalized() * 1.2 * ctx.tuning.f("cruise"))
	_clock = 0.0


func _w9_after_move() -> void:
	var burrower: Node3D = _w9_units["burrower"]
	# The lane is learned by leaving the floor: the ball is off it as the burst lands.
	_game.player.state.grounded = false
	burrower.phase = burrower.Phase.LIVE
	burrower._go_live()
	_report("burrow_lane", _combat.discovered.has("burrow_lane") and _w9_units["lane_had_ball"] and burrower.bursts == 1,
		"the ring held the ball at commit (%s) and the burst came up empty" % _w9_units["lane_had_ball"])

	var kite: Node3D = _w9_units["kite"]
	kite.phase = kite.Phase.LIVE
	kite._go_live()
	kite._t = kite.DIVE + 0.01
	kite._live(0.0)
	_report("thermal_dive", _combat.discovered.has("thermal_dive") and _w9_units["mark_had_ball"] and kite.dives == 1,
		"the mark held the ball (%s) and the dive landed after it left" % _w9_units["mark_had_ball"])

	var lamps: Node3D = _w9_units["lamps"]
	if lamps.phase == lamps.Phase.LIVE:
		lamps._live(1.0 / 90.0)
	_report("lure_bloom", _combat.discovered.has("lure_bloom"),
		"a ball at cruise inside the bloom went through the light (tier %d)" % _game.player.speed_tier())
	for key in ["burrower", "kite", "lamps"]:
		if is_instance_valid(_w9_units[key]):
			_w9_units[key].queue_free()
	_w9_units.clear()
	_game.player.reset_to(_w9_home)


# Wave 10 (ST4): the alpha packs' and elite's Fleet crews, each through its own code.
func _w10_pack_tricks(home: Vector3) -> void:
	var fleet = _combat.fleet
	var trap: Node3D = _w9_spawn("mag_trapper", home + Vector3(6.0, 0.0, -6.0))
	trap._warn(_w9_to(trap))
	trap.phase = trap.Phase.LIVE
	_combat.heft_override = trap.rating + 0.5
	trap._live(0.0)
	_combat.heft_override = 1.0
	_report("heavy_roll", _combat.discovered.has("heavy_roll") and not fleet.holds.held(trap),
		"a ball past the disc's rating %.1f rolled through its pit unheld" % trap.rating)

	var brute: Node3D = _w9_spawn("plated_brute", home + Vector3(-8.0, 0.0, -6.0))
	_combat.strike(brute, "slam", 80.0)
	var popped: int = brute.plates_popped
	_combat.strike(brute, "slam", 80.0)
	_report("plate_peel", _combat.discovered.has("plate_peel") and popped == 1,
		"the first breaking hit popped the plate (%d), the second reached the body" % popped)

	fleet.holds.immune_left = 0.0
	var drone: Node3D = _w9_spawn("winch_drone", home + Vector3(0.0, 0.0, -10.0))
	drone._warn(_w9_to(drone))
	drone.phase = drone.Phase.LIVE
	drone._go_live()
	var winched: bool = fleet.holds.held(drone)
	fleet.holds.snap(drone, "jump")
	_report("cable_snap", _combat.discovered.has("cable_snap") and winched and drone.broken_by == "jump",
		"a winch drone hooked the ball (%s), then a jump snapped the cable (%s)" % [winched, drone.broken_by])

	# 2026-10-17 (world rosters): a slam on a pit jaw's open jaw shuts it.
	var jaw: Node3D = _w9_spawn("pit_jaw", home + Vector3(10.0, 0.0, -2.0))
	jaw._warn(_w9_to(jaw))
	_game.events.slammed.emit(jaw.telegraph().center, 1.0, 1.0)
	_report("jaw_slam", _combat.discovered.has("jaw_slam") and jaw.slam_kills == 1,
		"a slam on the open jaw shut it (slam_kills %d)" % jaw.slam_kills)
	# 2026-10-18 (w17 fix): 8cdcd49 gave the Linker its codex row; a bolt on its cable cuts it.
	var linker: Node3D = _w9_spawn("linker", home + Vector3(12.0, 0.0, 10.0))
	_combat.strike(linker, "bolt", 5.0, "cable")
	_report("cable_cut", _combat.discovered.has("cable_cut") and linker.cut and linker.cut_by == "struck",
		"a bolt on a Linker's cable cut it (cut %s by %s)" % [linker.cut, linker.cut_by])
	# 2026-10-21 (Systems B, wave 18): the catch trap and Dispatcher are reachable now, so their rows open here.
	# A player break of the cup (a boost, a smash, a hook out) opens cup_break.
	var cup: Node3D = _w9_spawn("catch_trap", home + Vector3(-12.0, 0.0, 10.0))
	cup._on_hold_released(cup.get_instance_id(), "cup", "boost")
	_report("cup_break", _combat.discovered.has("cup_break") and cup.broken_by == "boost",
		"a boost out of a catch trap's cup broke its hold (broken_by %s)" % cup.broken_by)
	# 2026-10-21: the swatter is reachable (plate_press packs); a boost out of its bat opens paddle_ride.
	var swatter: Node3D = _w9_spawn("swatter", home + Vector3(-14.0, 0.0, 10.0))
	swatter._on_hold_released(swatter.get_instance_id(), "paddle_bat", "boost")
	_report("paddle_ride", _combat.discovered.has("paddle_ride") and swatter.broken_by == "boost",
		"a boost out of a swatter's bat broke its hold (broken_by %s)" % swatter.broken_by)
	# A Dispatcher killed after at least one drop cuts its stream.
	var dispatcher: Node3D = _w9_spawn("dispatcher", home + Vector3(14.0, 0.0, 10.0))
	dispatcher._go_live()
	var dropped: int = dispatcher.drops
	_combat.strike(dispatcher, "slam", 100000.0)
	_report("stream_cut", _combat.discovered.has("stream_cut") and dropped > 0,
		"a Dispatcher that dropped %d chaser(s) was killed" % dropped)
	for node in [trap, brute, drone, jaw, linker, cup, swatter, dispatcher]:
		if is_instance_valid(node):
			node.queue_free()


# 2026-10-24 (Spillway roster, PR #402): the four world 1 crews and the soaked armour, each
# through its own detector with the ball parked grounded at home. The FAST rows set the tier
# the unit reads on that one call and put it back after.
func _spillway_tricks(home: Vector3) -> void:
	var fleet = _combat.fleet
	var player = _game.player
	var tier: int = player.state.tier

	var layer: Node3D = _w9_spawn("jolt_layer", home + Vector3(6.0, 0.0, 6.0))
	layer.target = player
	layer._warn(_w9_to(layer))
	layer.phase = layer.Phase.LIVE
	player.state.tier = SpeedTier.FAST
	layer._live(layer.field.until_pulse() + 0.01)
	player.state.tier = tier
	_report("mat_slip", _combat.discovered.has("mat_slip") and layer.field.outcomes == ["speed"] and layer.jolts == 0,
		"a FAST ball on a jolt layer's mat slipped its pulse by speed (outcomes %s, jolts %d)" % [layer.field.outcomes, layer.jolts])

	fleet.holds.clear()
	var flap: Node3D = _w9_spawn("ramp_flipper", home + Vector3(-6.0, 0.0, 6.0))
	flap.target = player
	flap._warn(_w9_to(flap))
	player.state.tier = SpeedTier.FAST
	flap.phase = flap.Phase.LIVE
	flap._t = 0.0
	flap._go_live()
	player.state.tier = tier
	_report("flap_ride", _combat.discovered.has("flap_ride") and flap.rides == 1 and flap.broken_by == "speed" and not fleet.holds.held(flap),
		"a FAST ball rode a sluice flap, never held (rides %d, broken by %s)" % [flap.rides, flap.broken_by])

	fleet.holds.clear()
	fleet.holds.immune_left = 0.0
	var hooker: Node3D = _w9_spawn("hooker", home + Vector3(8.0, 0.0, -2.0))
	hooker._catch(0.0, Vector3.ZERO, hooker.anchor())
	var tethered: bool = fleet.holds.held(hooker)
	player.kit.anchor_body = null
	_game.events.grapple_fired.emit(player.ball_position() + Vector3(0.0, 4.0, 6.0))
	_report("hook_out", _combat.discovered.has("hook_out") and tethered and hooker.broken_by == "hook",
		"a harpoon bite on a post snapped a hooker's tether (held %s, broken by %s)" % [tethered, hooker.broken_by])

	fleet.holds.clear()
	var boom: Node3D = _w9_spawn("boom_tender", home + Vector3(5.0, 0.0, 2.0))
	boom.target = player
	boom._warn(_w9_to(boom))
	player.state.tier = SpeedTier.FAST
	boom.phase = boom.Phase.LIVE
	boom._t = 0.0
	boom._live(1.0 / 60.0)
	player.state.tier = tier
	var touched: int = boom.pops
	_report("boom_pop", _combat.discovered.has("boom_pop") and touched >= 1 and boom.pinned == 0,
		"a FAST ball in a boom tender's lane burst %d float(s), never pinned" % touched)
	# The ball stands in at each float in turn, the pass a full FAST sweep down the lane makes;
	# the lane, tier and SWEEP gates are the boom_pop row's above.
	for i in boom.FLOAT_OUT.size():
		boom._bowl_through(boom.float_position(i))
	_report("boom_strike", _combat.discovered.has("boom_strike") and boom.strikes == 1,
		"the ball went through all five floats in one sweep (strikes %d)" % boom.strikes)

	var soaked := _chaser(-14.0, 500.0)
	_combat.strike(soaked, "arc", 20.0, "", "weapon")
	_report("armour_wet", _combat.discovered.has("armour_wet"), "a full arc hit on a soaked chaser reads it")
	fleet.holds.clear()
	for node in [layer, flap, hooker, boom, soaked]:
		if is_instance_valid(node):
			node.queue_free()


func _w9_spawn(kind: String, at: Vector3) -> Node3D:
	var ctx = _game.ctx
	return ctx.spawner.spawn_enemy(kind, ctx.terrain.drop_point(at.x, at.z, 1.6))


func _w9_to(unit: Node3D) -> Vector3:
	var to: Vector3 = _game.player.ball_position() - unit.global_position
	to.y = 0.0
	return to


func _start_shell() -> void:
	var ctx = _game.ctx
	var at: Vector3 = ctx.terrain.spawn_point(1) + Vector3(-30.0, 0.0, 20.0)
	_lobber = ctx.spawner.spawn_enemy("lobber", ctx.terrain.drop_point(at.x, at.z, 2.4))
	var landing: Vector3 = ctx.terrain.spawn_point(1)
	_combat._on_lobber_fired(_lobber.global_position + Vector3.UP * 2.6, landing, 1.9, _lobber)
	var shells: Array = _game.get_tree().get_nodes_in_group("enemy_shot")
	var batted := false
	for shell in shells:
		batted = batted or _combat._bat(shell)
	_report("bat", batted, "a shell in flight was batted back toward its lobber")
	_clock = 0.0


func _warden_tricks() -> void:
	_game.flow.enter_stage(2, Vector3.ZERO, false)
	_game.run.set_max_hp(99999.0)
	var ctx = _game.ctx
	var warden: Node3D = ctx.spawner.spawn_enemy("warden", ctx.terrain.beacon_point(2))
	_report("posture warden", warden.fight() == "posture", "the stage 2 Warden fights on posture; caps and the magnet are gone")
	_w10_warden_tricks(warden)
	_game.player.chain.combo = 3
	_game.events.line_state_changed.emit("chain_link", null, Vector3.ZERO, "")
	_report("chain", _combat.discovered.has("chain"), "a third link in one chain")
	_game.player.chain.combo = 0
	var all_found := true
	var pending_ok := true
	var pilot_rows := PilotBlocks.ids("res://src/combat/codex_entries.gd")
	for id in CodexEntries.ids():
		# 2026-10-12 (W13 coordinator): P-C kit rows (marked blocks in codex_entries.gd) need a
		# pilot's kit, which this staging does not equip; each pilot's kit tests open its own.
		if id in pilot_rows:
			continue
		# 2026-10-10 (wave 13, B6): the five skill bar rows need an ultimate and a loaded bite, which
		# this staging does not run; tests/discovery_skill_bar_test.gd opens each on its trigger.
		if id in ["loaded_line", "set_piece", "set_piece_core", "set_piece_cash_in", "set_piece_breakout"]:
			continue
		# 2026-10-17 (Highdraft roster): a ring-out needs a rim and a gap sling a gap, which this flat
		# staging lacks; tests/highdraft_roster_test.gd opens each on the stage 5 islands.
		if id in ["ring_out", "gap_sling"]:
			continue
		# 2026-10-22 (weak points 2c): plate_drop needs a fitter at an open hatch mid-fight, which this staging
		# never sets up; tests/boss_weak_crew_test.gd opens plate_drop on a reel knock-off.
		if id == "plate_drop":
			continue
		# 2026-10-04 (wave 9): detector-pending entries declare a hint but no enemy fires them yet.
		if CodexEntries.DETECTOR_PENDING.has(id):
			pending_ok = pending_ok and not _combat.discovered.has(id)
			continue
		all_found = all_found and _combat.discovered.has(id)
	_report("all", all_found, "discovered this run: %s" % [_combat.discovery_log])
	_report("pending stay undiscovered", pending_ok, "detector-pending: %s" % [CodexEntries.DETECTOR_PENDING])
	_last_case_ran = true


# Wave 10 (ST4): the Warden's shared trick and one per variant, unit-level on the stage 2
# Warden with its variant set in place (a variant's own setup is warden_variants_test's).
func _w10_warden_tricks(warden: Node3D) -> void:
	# The stage's ball is still dropping in, so a stand-in ball hops 3 m over the lane.
	var player = warden.target
	var hop := BallDouble.new()
	hop.at = warden.global_position + Vector3(-6.0, 3.0, 0.0)
	hop.at.y = _game.ctx.terrain.height(hop.at.x, hop.at.z) + 3.0
	warden.target = hop
	warden.variant = "meltdown"
	warden._leave_slag()
	hop.state.grounded = true
	warden._step_slag(warden.SLAG_WARN + 0.01)
	var rolled: bool = _combat.discovered.has("slag_hop")
	hop.state.grounded = false
	warden._step_slag(0.0)
	warden.target = player
	_report("slag_hop", _combat.discovered.has("slag_hop") and not rolled,
		"a ball 3 m over a burning slag lane, not one rolling in it (rolled fired %s)" % rolled)

	warden.variant = "choir"
	_combat.fleet.habits.add("ram", 5.0)
	for i in 8:
		if warden.staggered():
			break
		warden.on_struck("guard_rack", "", warden.judge_hit("guard_rack", 0.0, false, 0))
	var braced: Array = warden.braced_kinds
	var chunks: int = warden.chunks_left()
	# A core hit lands the frame after the stagger opens; this stands in for that next frame.
	warden._posture.stagger_frame = -1
	warden.on_struck("slam", "", warden.judge_hit("slam", 200.0, true, 2))
	_report("choir_switch", _combat.discovered.has("choir_switch") and braced == ["ram"],
		"a slam on a choir Warden braced against %s" % [braced])
	_report("warden_shatter", _combat.discovered.has("warden_shatter") and warden.chunks_left() == chunks - 1,
		"a smash on the open core took a chunk (%d to %d)" % [chunks, warden.chunks_left()])

	warden.variant = "brood"
	var at: Vector3 = warden.global_position + Vector3(9.0, 0.0, 0.0)
	warden.guard = _combat.fleet.spawn_guard(warden.global_position, _game.ctx.terrain.drop_point(at.x, at.z, 1.4), "lamp_swarm")
	warden._guard_wait = warden.GUARD_RESPAWN
	var lamps: int = warden.guard.alive().size()
	for lamp in warden.guard.alive():
		lamp.hp = 1.0
		_combat.strike(lamp, "slam", 80.0)
	warden._step_guard(0.0)
	_report("brood_dark", _combat.discovered.has("brood_dark") and lamps == 1 and warden.guard.alive().is_empty(),
		"a brood Warden's lamp guard (%d) was put out and went dark" % lamps)


func _finish() -> bool:
	if not _last_case_ran:
		_report("ran to the end", false, "the Warden cases aborted before the last check")
	var ok := _failures == 0
	print("combat_codex_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true
