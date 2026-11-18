extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Augments := preload("res://src/movement/augments.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const WearTrail := preload("res://src/combat/wear_trail.gd")
const WorldOneCards := preload("res://src/core/trees/world_one_cards.gd")

# Rivet's world-one kit (BUILD-SYSTEMS.md, ### Rivet), R1 to R6, and Run and Gun's wear trail.
#   - Flag on: Rivet is offered R1 and R2 at depth 1 and the right children at depth 2; the cards
#     show Codex's lines for R1 to R5; R6 keeps its own effect line because Codex's line promises
#     the Riveted Shell cancellation, which needs hot-wired part H1 (not built).
#   - Each retained effect: R1 two bolts at 0.6 with at least 3 degrees of spread; R2 the
#     half-scale sprint-start blast with its 1 s gap; R3 one 6 m chain at 0.9; R4 half sprint
#     drain while firing (driven through the real sprint step); R5 sprint punch 1.5, no enemy
#     rebound, walls still colliding; R6 one extra sprint charge.
#   - The trail (--world-one-builds=on, --wear=on, R4): one patch per whole unit of wear, at 14
#     damage, 1 m radius (from the hull), 2 s life, six live, one hit per enemy per 0.5 s across
#     all patches, only on ground the ball is on, no enemy_struck (so no item), no patch from a
#     patch. Wear off, or the flag off, or a build without R4: no patches.
#   - Flag off: Rivet's tree, drain and cards match base.
#   - The three identities: running gunner R1 to R3 or R4, bowling bruiser R2 to R5, hit-and-run
#     bruiser R2 to R6.
#
# Evidence limit: a fixture on the real Game; nothing here says the trail reads well on screen or
# that the paths feel different. The trail's visuals and sputter are not asserted beyond the
# signal that carries them.

const BASE_EFFECT := {
	"r_gunline": "The laser fires twin bolts",
	"r_juggernaut": "Starting a sprint blasts machines back",
	"r_tracer": "Laser hits hop to a neighbour",
	"r_run_gun": "Firing while sprinting drains it half as fast",
	"r_ram_fins": "Sprinting, you ram instead of bouncing",
	"r_second_wind": "Bank two sprint charges",
}
const CODEX := {
	"r_gunline": "Your laser fires twin bolts.",
	"r_juggernaut": "Starting a sprint blasts machines back.",
	"r_tracer": "Running fire jumps to a neighbour.",
	"r_run_gun": "Sustain fire. Worn scrap sparks behind you.",
	"r_ram_fins": "Sprint through bodies instead of bouncing.",
	"r_second_wind": "Bank two sprints. Heavy fins open during sprint.",
}
const CLASS := "runner_gunner"

var _game
var _combat
var _player
var _ws
var _failures := 0
var _booted := false
var _trail
var _struck := 0
var _kills := 0


class Body:
	extends RefCounted
	var transform := Transform3D.IDENTITY
	var linear_velocity := Vector3.ZERO


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _booted:
		_booted = true
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_combat = _game.combat
		_player = _game.player
		_ws = _game.get_node("Workshop")
		return false
	_rivet()
	_cards()
	_retained()
	_drain()
	_ram()
	_trail_checks()
	_flag_off()
	_identities()
	print("world_one_rtree_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _flag(on: bool) -> void:
	_game.ctx.tuning.set_option("world_one_builds", "on" if on else "off")


func _rivet() -> void:
	var def: Resource = ClassDef.by_id(CLASS)
	_game.run.class_def = def
	_player.fit_class(def)
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.queue_free()
	var at: Vector3 = _game.ctx.terrain.spawn_point(1)
	_player.reset_to(at)
	_player.body().global_position = at
	_trail = _combat.wear_trail
	_game.events.enemy_struck.connect(func(_e, _k, _f): _struck += 1)
	_game.events.enemy_killed.connect(func(_k, _a, _s): _kills += 1)


# A fresh Rivet tree holding exactly these picks (two depths, as the profile allows).
func _take(picks: Array) -> bool:
	var tree = _player.tree
	tree.reset(CLASS)
	tree.max_depth = UpgradeTree.WORLD_ONE_DEPTHS
	var ok := true
	for id in picks:
		tree.open_checkpoint()
		ok = tree.pick(id) and ok
	return ok


# Like _take without the world-one depth cap, for a node the pilot's two depths never reach.
func _take_deep(picks: Array) -> void:
	var tree = _player.tree
	tree.reset(CLASS)
	tree.max_depth = picks.size()
	for id in picks:
		tree.open_checkpoint()
		tree.pick(id)


func _card_lines(picks: Array) -> Array:
	_take(picks)
	_game.ctx.tuning.set_option("hotwire_shell", "on")
	_player.tree.open_checkpoint()
	_ws.open_pick()
	var out: Array = []
	for card in _ws.pick.cards():
		out.append([card.node_id(), card.effect_text()])
	_ws.close_pick()
	_game.ctx.tuning.set_option("hotwire_shell", "off")
	return out


func _cards() -> void:
	_flag(true)
	var pairs := {"": ["r_gunline", "r_juggernaut"], "r_gunline": ["r_tracer", "r_run_gun"], "r_juggernaut": ["r_ram_fins", "r_second_wind"]}
	var seen := 0
	for parent in pairs:
		var lines := _card_lines([] if parent == "" else [parent])
		var ids: Array = lines.map(func(l): return l[0])
		var tree_ids: Array = _player.tree.offered(CLASS, 1 if parent == "" else 2).map(func(n): return n["id"])
		_check("offers (flag on, after %s)" % (parent if parent != "" else "start"), ids == pairs[parent] and ids == tree_ids, "cards %s, tree %s" % [ids, tree_ids])
		var same := true
		for l in lines:
			same = same and l[1] == CODEX[l[0]]
		_check("codex lines, R6 ruling text (after %s)" % (parent if parent != "" else "start"), same, "%s" % [lines])
		seen += lines.size()
	_check("six Rivet cards seen, R6 has a row", seen == 6 and WorldOneCards.has_row("r_second_wind") and WorldOneCards.has_row("r_run_gun"), "%d cards" % seen)


func _pattern() -> Resource:
	return _combat.pattern(Weapons.RAPID_LASER)


func _retained() -> void:
	_flag(true)
	_take([])
	var base := _pattern()
	var base_charges: int = _player.abilities.slot(AbilityState.MOVEMENT).max_charges
	# R1: two bolts at 0.6 damage, at least 3 degrees spread.
	_take(["r_gunline"])
	var p := _pattern()
	_check("R1 twin bolts", p.count == base.count + 1 and p.count == 2 and is_equal_approx(p.damage, base.damage * 0.6) and p.spread_deg >= 3.0,
		"count %d (base %d), damage %.2f (base %.2f), spread %.1f" % [p.count, base.count, p.damage, base.damage, p.spread_deg])
	# R2: the half-scale start blast, 1 s gap.
	_take(["r_juggernaut"])
	var blast := _procs_of("blast")
	_check("R2 start blast", blast.size() == 1 and blast[0]["on"] == "sprint_started" and is_equal_approx(blast[0]["scale"], 0.5) and is_equal_approx(blast[0]["gap"], 1.0),
		"%s" % [blast])
	# R3: one 6 m chain at 0.9 (over R1's 0.6).
	_take(["r_gunline", "r_tracer"])
	p = _pattern()
	_check("R3 one 6 m chain at 0.9", p.chain_jumps == base.chain_jumps + 1 and p.chain_range >= 6.0 and is_equal_approx(p.damage, base.damage * 0.6 * 0.9),
		"jumps %d (base %d), range %.1f, damage %.3f" % [p.chain_jumps, base.chain_jumps, p.chain_range, p.damage])
	# R4: half drain knob.
	_take(["r_gunline", "r_run_gun"])
	_check("R4 half drain knob", is_equal_approx(_player.tree.knob("sprint_fire_drain"), 0.5), "knob %s" % _player.tree.knob("sprint_fire_drain"))
	# R5: punch 1.5, no enemy rebound knob.
	_take(["r_juggernaut", "r_ram_fins"])
	_check("R5 knobs", is_equal_approx(_player.tree.knob("sprint_punch"), 1.5) and _player.tree.knob("sprint_no_rebound") == true, "punch %s, no rebound %s" % [_player.tree.knob("sprint_punch"), _player.tree.knob("sprint_no_rebound")])
	# R6: one extra sprint charge, and it is R6's own effect.
	_take(["r_juggernaut", "r_second_wind"])
	var charges: int = _player.abilities.slot(AbilityState.MOVEMENT).max_charges
	_check("R6 one extra sprint charge", charges == base_charges + 1, "%d charges, base %d" % [charges, base_charges])
	# R3 and R4, R5 and R6 are exclusive.
	_take(["r_gunline", "r_tracer"])
	var third: bool = _player.tree.pick("r_run_gun")
	_take(["r_juggernaut", "r_ram_fins"])
	var fourth: bool = _player.tree.pick("r_second_wind")
	_check("R3/R4 and R5/R6 exclusive", not third and not fourth, "second pick accepted %s, %s" % [third, fourth])


func _procs_of(action: String) -> Array:
	return _player.tree.procs().filter(func(r): return r["do"] == action)


# Sprint drain through the real sprint step: firing halves it, not firing does not.
func _drain_of(fire: bool) -> float:
	var kit = _player.kit
	kit.set_on(Augments.SPRINT, true)
	kit.sprinting = true
	kit.sprint_left = 2.0
	var intent := Intent.new()
	intent.fire_held = fire
	intent.movement_held = true
	var b := Body.new()
	# 2026-10-09 BUGFIX-MOVEMENT F001 gave _sprint an aim basis (the kick follows the roll, the aim when still);
	# this drain check measures stamina, not direction, so the identity aim keeps the old reading.
	Augments._sprint(kit, _player.state, _game.ctx.tuning, intent, Basis.IDENTITY, b, 0.5)
	var used: float = 2.0 - kit.sprint_left
	kit.sprinting = false
	return used


func _drain() -> void:
	_flag(true)
	_take([])
	var base_fire := _drain_of(true)
	_take(["r_gunline", "r_run_gun"])
	var fire := _drain_of(true)
	var still := _drain_of(false)
	_check("R4 half drain while firing", is_equal_approx(fire, base_fire * 0.5) and is_equal_approx(still, base_fire) and base_fire > 0.0,
		"firing %.3f (base %.3f), not firing %.3f" % [fire, base_fire, still])


# R5 through the real rebound test: a heavy enemy rebounds a sprinting ball at base and not
# with Ram Fins; walls are not read by the knob (one reader, the enemy test).
func _ram() -> void:
	_flag(true)
	var enemy: Node3D = _combat.spawn_enemy("chaser", _player.ball_position() + Vector3(4.0, 0.0, 4.0))
	enemy.weight = 1000.0
	_player.kit.sprinting = true
	_take([])
	var base_rebounds: bool = _player._rebounds_off(enemy)
	_take(["r_juggernaut", "r_ram_fins"])
	var ram_rebounds: bool = _player._rebounds_off(enemy)
	_player.kit.sprinting = false
	var walking: bool = _player._rebounds_off(enemy)
	_check("R5 no enemy rebound while sprinting", base_rebounds and not ram_rebounds and walking, "base %s, ram fins %s, not sprinting %s" % [base_rebounds, ram_rebounds, walking])
	var src := FileAccess.get_file_as_string("res://src/movement/player_ball.gd")
	_check("R5 walls untouched", src.count("sprint_no_rebound") == 1, "the knob has %d reader in player_ball.gd, the enemy rebound test" % src.count("sprint_no_rebound"))
	enemy.remove_from_group("enemy")
	enemy.queue_free()


# --- The trail ----------------------------------------------------------------------

func _armed(picks: Array, wear: bool, flag := true) -> void:
	_flag(flag)
	_game.ctx.tuning.set_option("scrap_mode", "armor")
	_game.ctx.tuning.set_option("wear", "on" if wear else "off")
	_game.run.armor_mode = true
	_game.run.wear_on = _game.ctx.tuning.wear_on()
	_game.run.mass = 500.0
	_take(picks)
	_trail.patches.clear()
	_trail._last_hit.clear()
	_trail.hits = 0
	_player.state.grounded = true


# Wear `units` whole units off the ball through the real wear step.
func _wear(units: int) -> void:
	var cruise: float = _game.ctx.tuning.f("cruise")
	_game.run.wear_step(units / (_game.run.WEAR_PER_MINUTE / 60.0) + 0.001, cruise, cruise, true)


func _foe(planar: float, hp := 500.0) -> Node3D:
	var e: Node3D = _combat.spawn_enemy("chaser", _player.ball_position() + Vector3(planar, 0.0, 0.0))
	e.hp = hp
	e.global_position = _player.ball_position() + Vector3(planar, 0.0, 0.0)
	return e


func _drop(e: Node3D) -> void:
	e.remove_from_group("enemy")
	e.queue_free()


func _trail_checks() -> void:
	var r4 := ["r_gunline", "r_run_gun"]
	# One patch per whole unit of wear, on the ball's own ground.
	_armed(r4, true)
	var heard := []
	_trail.patched.connect(func(at): heard.append(at))
	var mass_before: float = _game.run.mass
	_wear(3)
	var lost: float = mass_before - _game.run.mass
	var ball: Vector3 = _player.ball_position()
	var on_path := true
	for patch in _trail.patches:
		on_path = on_path and patch["at"].is_equal_approx(_combat._floor_at(ball)) and ball.y - patch["at"].y <= WearTrail.FLOOR_REACH and patch["at"].y < ball.y
	_check("one patch per unit of wear, one sputter each", lost == 3.0 and _trail.patches.size() == 3 and heard.size() == 3 and on_path,
		"%.0f units worn, %d patches, %d sputters, on the ball's ground %s" % [lost, _trail.patches.size(), heard.size(), on_path])
	# Cap of six, oldest retired.
	_armed(r4, true)
	_wear(9)
	_check("at most six live", _trail.patches.size() == 6 and WearTrail.MAX_LIVE == 6, "%d live after nine units" % _trail.patches.size())
	# Airborne wear leaves nothing; ground far below leaves nothing.
	_armed(r4, true)
	_player.state.grounded = false
	_wear(2)
	_check("airborne wear makes no patch", _trail.patches.is_empty(), "%d patches" % _trail.patches.size())
	# Ground more than FLOOR_REACH below the ball: nothing.
	_player.state.grounded = true
	var real_floor: Callable = _trail._floor_at
	_trail._floor_at = func(at: Vector3) -> Vector3: return Vector3(at.x, at.y - WearTrail.FLOOR_REACH - 1.0, at.z)
	_wear(2)
	_check("ground far below makes no patch", _trail.patches.is_empty(), "%d patches with the floor %.1f m below" % [_trail.patches.size(), WearTrail.FLOOR_REACH + 1.0])
	_trail._floor_at = real_floor
	_player.state.grounded = true
	# Damage and radius: 14 inside the hull reach, nothing outside it.
	_armed(r4, true)
	_wear(1)
	var near := _foe(0.6)
	var reach: float = WearTrail.RADIUS + float(near.get("radius"))
	near.global_position = _player.ball_position() + Vector3(reach - 0.1, 0.0, 0.0)
	var far := _foe(reach + 0.4)
	_struck = 0
	_kills = 0
	var live_before: int = _trail.patches.size()
	var wear_before: float = _game.run.metrics["wear_loss"]
	_trail.step(0.05, [near, far])
	_check("14 damage inside the radius, none outside", is_equal_approx(500.0 - near.hp, WearTrail.DAMAGE) and far.hp == 500.0 and WearTrail.DAMAGE == 14.0 and WearTrail.RADIUS == 1.0,
		"near lost %.1f, far lost %.1f, reach %.2f m" % [500.0 - near.hp, 500.0 - far.hp, reach])
	_check("no item proc, no patch from a patch, no water", _struck == 0 and _trail.patches.size() == live_before and _game.run.metrics["wear_loss"] == wear_before and not _trail_source_touches_procs(),
		"%d enemy_struck, %d patches (was %d), wear unchanged" % [_struck, _trail.patches.size(), live_before])
	_check("no kill event from a trail hit", _kills == 0, "%d enemy_killed" % _kills)
	# A patch deals its full 14 to a 30 hp enemy.
	_armed(r4, true)
	_wear(1)
	var mid := _foe(0.6, 30.0)
	_trail.step(0.05, [mid])
	_check("a patch deals 14 to a 30 hp enemy", is_equal_approx(mid.hp, 16.0) and is_instance_valid(mid) and mid.last_damage_source == "", "hp %.1f, source '%s'" % [mid.hp, mid.last_damage_source])
	_drop(mid)
	# A patch kills a 10 hp enemy: scrap and run.kills count it, no item, shrapnel or Rampage sees it.
	var build = _game.ctx.get_meta("build")
	var refunds := [0]
	_combat._actions["refund_move"] = func(_s: float): refunds[0] += 1
	build.sheet.transformers.append("shrapnel_bloom")
	_armed(r4, true)
	_take_deep(UpgradeTree.path_to(CLASS, "r_rampage", true))
	_combat._proc_ready.clear()
	_wear(1)
	var frail := _foe(0.6, 10.0)
	_kills = 0
	_struck = 0
	var kills_before: int = _game.run.kills
	var scrap_before: int = build.scrap.count()
	var pending_before: int = build.bus.pending.size()
	var bloom_before: int = build._kills.size()
	var flag_seen := [false]
	var watch: Callable = func(_k, _a, _s): flag_seen[0] = _game.run.last_kill_triggerless
	_game.events.enemy_killed.connect(watch)
	var spark_before: float = float(_combat.delivered_damage()["by_action"].get("spark", 0.0))
	var over_before: float = float(_combat.delivered_damage()["overkill"])
	_trail.step(0.05, [frail])
	_game.events.enemy_killed.disconnect(watch)
	_check("spark kill counts in run.kills and enemy_killed", _game.run.kills == kills_before + 1 and _kills == 1 and flag_seen[0], "run.kills +%d, %d enemy_killed, flag during emit %s" % [_game.run.kills - kills_before, _kills, flag_seen[0]])
	_check("spark kill drops scrap", build.scrap.count() > scrap_before, "%d -> %d scrap items" % [scrap_before, build.scrap.count()])
	_check("spark kill posts no ON_KILL", build.bus.pending.size() == pending_before, "%d pending (was %d)" % [build.bus.pending.size(), pending_before])
	_check("spark kill records no shrapnel_bloom kill", build._kills.size() == bloom_before, "%d kills recorded (was %d)" % [build._kills.size(), bloom_before])
	_check("flag clear after the emit", not _game.run.last_kill_triggerless, "last_kill_triggerless %s" % _game.run.last_kill_triggerless)
	# Rampage's refund rides the same gate: the patch kill above gave none, an ordinary kill does.
	_check("spark kill gives no Rampage refund", refunds[0] == 0 and not _procs_of("refund_move").is_empty(), "%d refunds, %d rampage procs" % [refunds[0], _procs_of("refund_move").size()])
	var refunds_spark: int = refunds[0]
	_combat._proc_ready.clear()
	_game.run.record_kill("chaser", _player.ball_position(), 3)
	_check("ordinary kill gives the Rampage refund", refunds[0] == refunds_spark + 1, "%d refunds" % (refunds[0] - refunds_spark))
	# M0 ledger: the kill above removed 10 of a 14 patch; the ledger counts the HP removed, not 14.
	var led: Dictionary = _combat.delivered_damage()
	var spark_gain: float = float(led["by_action"].get("spark", 0.0)) - spark_before
	_check("trail damage lands in the delivered-damage ledger with the HP removed", is_equal_approx(spark_gain, 10.0) and is_equal_approx(float(led["overkill"]) - over_before, 4.0) and float(led["by_source"].get("persistent_actor", 0.0)) >= 10.0,
		"a 14 patch on 10 hp: spark +%.1f, overkill +%.1f, persistent_actor %.1f" % [spark_gain, float(led["overkill"]) - over_before, float(led["by_source"].get("persistent_actor", 0.0))])
	var total_before: float = float(led["total"])
	var hits_before: int = int(led["hits"])
	var ledger_foe := _foe(0.6, 500.0)
	_wear(1)
	_trail.step(0.05, [ledger_foe])
	_check("a patch adds one ledger hit of 14", is_equal_approx(float(led["total"]) - total_before, 14.0) and int(led["hits"]) == hits_before + 1, "total +%.1f, hits +%d" % [float(led["total"]) - total_before, int(led["hits"]) - hits_before])
	_drop(ledger_foe)
	# A strike-sourced kill of a 10 hp enemy does the item, bloom, scrap and count.
	_armed(r4, true)
	var normal := _foe(0.6, 10.0)
	build._last_strike_kind = "ram"
	pending_before = build.bus.pending.size()
	bloom_before = build._kills.size()
	scrap_before = build.scrap.count()
	kills_before = _game.run.kills
	_combat.strike(normal, "ram", 1.0)
	_check("strike kill posts ON_KILL, bloom record, scrap and counts", build.bus.pending.size() > pending_before and build._kills.size() == bloom_before + 1 and build.scrap.count() > scrap_before and _game.run.kills == kills_before + 1,
		"pending %d (was %d), bloom %d (was %d), scrap %d (was %d), run.kills +%d" % [build.bus.pending.size(), pending_before, build._kills.size(), bloom_before, build.scrap.count(), scrap_before, _game.run.kills - kills_before])
	build.sheet.transformers.erase("shrapnel_bloom")
	# One hit per enemy per 0.5 s across every patch.
	_armed(r4, true)
	_wear(3)
	near.hp = 500.0
	_trail._last_hit.clear()
	_trail.hits = 0
	_trail._clock = 10.0
	_trail.step(0.1, [near])
	_trail.step(0.1, [near])
	_trail.step(0.25, [near])
	var early: int = _trail.hits
	_trail.step(0.1, [near])
	_trail.step(0.1, [near])
	_check("one hit per enemy per 0.5 s across patches", early == 1 and _trail.hits == 2 and is_equal_approx(500.0 - near.hp, 28.0),
		"%d hit by 0.45 s, %d by 0.65 s with three patches on it, lost %.0f" % [early, _trail.hits, 500.0 - near.hp])
	# Two seconds of life.
	_armed(r4, true)
	_wear(1)
	_trail.step(1.9, [])
	var alive_19: int = _trail.patches.size()
	_trail.step(0.2, [])
	_check("patch lives two seconds", alive_19 == 1 and _trail.patches.is_empty() and WearTrail.LIFE == 2.0, "%d at 1.9 s, %d at 2.1 s" % [alive_19, _trail.patches.size()])
	# Wear off: the durability prototype's own gate, R4 makes no patches.
	_armed(r4, false)
	var worn: float = _game.run.metrics["wear_loss"]
	_wear(3)
	_check("wear off, no patches", _trail.patches.is_empty() and _game.run.metrics["wear_loss"] == worn, "%d patches, wear %s" % [_trail.patches.size(), _game.run.metrics["wear_loss"] - worn])
	# A build without R4 makes none.
	_armed(["r_gunline", "r_tracer"], true)
	_wear(3)
	_check("no R4, no patches", _trail.patches.is_empty() and _game.run.metrics["wear_loss"] >= 3.0, "%d patches, wear %s" % [_trail.patches.size(), _game.run.metrics["wear_loss"]])
	_drop(near)
	_drop(far)


func _trail_source_touches_procs() -> bool:
	var src := FileAccess.get_file_as_string("res://src/combat/wear_trail.gd")
	for word in [".strike(", "element_resolved", "water", "electri"]:
		var lines: Array = Array(src.split("\n")).filter(func(l): return not l.strip_edges().begins_with("#") and l.contains(word))
		if not lines.is_empty():
			return true
	return false


func _flag_off() -> void:
	# Flag off, wear on, R4: no patches, base drain, base cards.
	_armed(["r_gunline", "r_run_gun"], true, false)
	_wear(4)
	_check("flag off makes no patches", _trail.patches.is_empty() and _game.run.metrics["wear_loss"] >= 4.0, "%d patches, wear %s" % [_trail.patches.size(), _game.run.metrics["wear_loss"]])
	var fire := _drain_of(true)
	_check("flag off keeps base drain for R4", is_equal_approx(fire, 0.25), "firing drain %.3f of 0.5 s" % fire)
	var ok := true
	var bad := ""
	var count := 0
	for parent in [[], ["r_gunline"], ["r_juggernaut"]]:
		for l in _card_lines(parent):
			count += 1
			if l[1] != BASE_EFFECT[l[0]]:
				ok = false
				bad = "%s: %s" % [l[0], l[1]]
	_check("flag off cards match base", ok and count == 6, "%d cards %s" % [count, bad])
	var tree_ok := true
	for i in UpgradeTree.nodes(CLASS).size():
		tree_ok = tree_ok and UpgradeTree.nodes(CLASS, false)[i] == UpgradeTree.nodes(CLASS, true)[i]
	# TR1 (2026-10-04): every pilot now declares NODES_WORLD_ONE, so Rivet has a table; the
	# flag-off tree must still equal the base table.
	_check("flag off tree is the base table", tree_ok and UpgradeTree.WORLD_ONE_TABLES.has(CLASS), "Rivet has a world-one table and the flag-off tree is unchanged")


func _identities() -> void:
	_armed([], true)
	var base_charges: int = _player.abilities.slot(AbilityState.MOVEMENT).max_charges
	# Running gunner, Tracer Rounds: twin bolts that chain.
	_armed(["r_gunline", "r_tracer"], true)
	var p := _pattern()
	_check("identity running gunner, Tracer", p.count == 2 and p.chain_jumps >= 1 and _player.tree.path() == ["r_gunline", "r_tracer"], "count %d, chain %d" % [p.count, p.chain_jumps])
	# Running gunner, Run and Gun: twin bolts, half drain, and a trail that appears with wear.
	_armed(["r_gunline", "r_run_gun"], true)
	p = _pattern()
	_wear(2)
	_check("identity running gunner, Run and Gun", p.count == 2 and is_equal_approx(_drain_of(true), 0.25) and _trail.patches.size() == 2,
		"count %d, %d patches" % [p.count, _trail.patches.size()])
	# Bowling bruiser: blast on sprint start, ram through bodies.
	_armed(["r_juggernaut", "r_ram_fins"], true)
	_check("identity bowling bruiser", _procs_of("blast").size() == 1 and _player.tree.knob("sprint_no_rebound") == true and is_equal_approx(_player.tree.knob("sprint_punch"), 1.5),
		"blast procs %d, ram %s" % [_procs_of("blast").size(), _player.tree.knob("sprint_no_rebound")])
	# Hit-and-run bruiser: blast on entry, a second charge for the escape.
	_armed(["r_juggernaut", "r_second_wind"], true)
	var charges: int = _player.abilities.slot(AbilityState.MOVEMENT).max_charges
	_check("identity hit-and-run bruiser", _procs_of("blast").size() == 1 and charges == base_charges + 1, "blast procs %d, charges %d (base %d)" % [_procs_of("blast").size(), charges, base_charges])
