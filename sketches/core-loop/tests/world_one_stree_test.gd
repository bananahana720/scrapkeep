extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const TreeProblems := preload("res://tests/support/tree_problems.gd")
const Augments := preload("res://src/movement/augments.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Sable := preload("res://src/core/trees/sable.gd")
const Rivet := preload("res://src/core/trees/rivet.gd")
const Kest := preload("res://src/core/trees/kest.gd")
const WorldOneCards := preload("res://src/core/trees/world_one_cards.gd")

# Sable's world-one kit (BUILD-SYSTEMS.md, ### Sable), S1 to S6, and the world-one node-table seam.
#   - Seam: with tree.world_one on, nodes() reads Sable.NODES_WORLD_ONE (NODES with index 3 the
#     world-one Face Runner); off, or for Rivet and Kest, it reads NODES exactly. world.gd sets
#     the flag beside max_depth.
#   - Flag on: Sable is offered S1 and S2, then under S1 Coil Hook and Face Runner, under S2 Arc
#     Nest and Bulwark. Cards show Codex's lines for S1, S2, S3, S5 and S6; S4 keeps its own
#     effect (its Codex line names the Riveted Shell inversion, which needs hot-wired part H1).
#     Flag off: Live Wire sits in Face Runner's place, Face Runner is at depth 3 with a 1 s
#     lock, and every card is the node's own effect.
#   - Each retained effect: vault discharge, double mount reach, Coil Hook fling with the mass
#     bonus once under 45 m/s, one extra turret chain jump, mounted CC immunity without damage
#     immunity; Face Runner restores one air jump per valid vault and locks that face for 1.5 s.
#   - The three identities: wall cannonball S1 to S3, ninja platformer S1 to S4, mobile siege
#     S2 to S5 or S6.
#
# Evidence limit: a fixture on the real Game and Augments rules against real walls in the real
# physics space; nothing here says the paths feel different.

const CLASS_ID := "pylon_engineer"
const RUN := Vector3(5000.0, 60.0, 0.0)
const REACH_RUN := Vector3(5000.0, 60.0, 300.0)
const BASE_EFFECT := {
	"s_cannonball": "Vault kicks set off a small discharge",
	"s_beachhead": "Plant a pylon from twice as far",
	"s_coil_hook": "Letting go of the rope flings you",
	"s_live_wire": "Discharge fills twice as fast airborne",
	"s_arc_nest": "Turret arcs reach one more machine",
	"s_bulwark": "On a wall, nothing shoves or snares you",
}
const CODEX := {
	"s_static_flutter": "Three sparks on tap. Six pulses charged.",
	"s_rail_lance": "Longer charge fires one piercing arc lance.",
	"s_cannonball": "Kick off a wall to zap what's near. Scrap makes you heavier. Heavier launches farther.",
	"s_beachhead": "Grab a wall from twice as far.",
	"s_face_runner": "Kick off a wall to jump again. Steer sharper after each kick.",
	"s_bulwark": "On a wall, nothing shoves or snares you.",
}

var _game
var _combat
var _player
var _ws
var _wall: StaticBody3D
var _reach_wall: StaticBody3D
var _failures := 0
var _booted := false


class Body:
	extends RefCounted
	var transform := Transform3D.IDENTITY
	var linear_velocity := Vector3.ZERO
	var angular_velocity := Vector3.ZERO
	var step := 1.0 / 60.0
	var space: PhysicsDirectSpaceState3D

	func get_space_state() -> PhysicsDirectSpaceState3D:
		return space


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	# A wall whose face is 1.5 m from RUN (a vault target), and one whose face is 3.25 m from
	# REACH_RUN: past the base mount reach (1 + 1.5 = 2.5 m) and inside the doubled one (4 m).
	_wall = _make_wall(RUN + Vector3(2.0, 0.0, 0.0))
	_reach_wall = _make_wall(REACH_RUN + Vector3(1.0 + Augments.FACE_REACH * 1.5 + 0.5, 0.0, 0.0))


func _make_wall(at: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 40.0, 40.0)
	shape.shape = box
	wall.add_child(shape)
	wall.collision_layer = 1
	wall.position = at
	root.add_child(wall)
	return wall


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
	_sable()
	_seam()
	_offers_and_cards()
	_retained()
	_face_runner()
	_duplicate_guard()
	_identities()
	print("world_one_stree_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _flag(on: bool) -> void:
	_game.ctx.tuning.set_option("world_one_builds", "on" if on else "off")


func _sable() -> void:
	var def: Resource = ClassDef.by_id(CLASS_ID)
	_game.run.class_def = def
	_player.fit_class(def)
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.queue_free()


# A fresh Sable tree holding exactly these picks, two depths under the flag, four without.
func _take(picks: Array, on := true, depth := 2) -> void:
	_flag(on)
	var tree = _player.tree
	tree.reset(CLASS_ID)
	tree.max_depth = depth
	tree.world_one = on
	_player.kit.mounted = false
	for id in picks:
		tree.open_checkpoint()
		tree.pick(id)
	_arm_mass(on)


# The mass the ball carries, at full: the mass verb reads flag and S1/S2's mass_launch knob.
func _arm_mass(on: bool) -> void:
	_player.mass_of = func() -> float: return Augments.MASS_FULL
	_player.heft_of = func(): return 1.0 + Augments.MASS_FULL / Augments.MASS_HEFT_DIVISOR
	_player._read_mass()
	_player.kit.mass_gap = 0.0
	_player.kit.vault_faces.clear()


func _seam() -> void:
	# The world.gd line: the pick opener sets world_one beside max_depth, from the launch flag.
	_flag(true)
	_game.world._open_pick(99)
	var on_set: bool = _player.tree.world_one and _player.tree.max_depth == UpgradeTree.WORLD_ONE_DEPTHS
	_flag(false)
	_game.world._open_pick(99)
	var off_set: bool = not _player.tree.world_one and _player.tree.max_depth == UpgradeTree.DEPTHS
	_check("world.gd sets world_one beside max_depth", on_set and off_set, "flag on -> world_one %s, flag off -> %s" % [on_set, off_set])
	var base: Array = UpgradeTree.nodes(CLASS_ID)
	var wo: Array = UpgradeTree.nodes(CLASS_ID, true)
	var same_elsewhere := wo.size() == base.size() and base.size() == 30
	for i in range(6, base.size()):
		if wo[i] != base[i]:
			same_elsewhere = false
	var wo_ids := wo.slice(0, 6).map(func(n): return n["id"])
	_check("NODES_WORLD_ONE puts Depth-1 keystones and moved perks in 0..5, matches NODES past 5",
		same_elsewhere and wo_ids == ["s_static_flutter", "s_rail_lance", "s_cannonball", "s_face_runner", "s_beachhead", "s_bulwark"]
		and base[3]["id"] == "s_live_wire" and wo == Sable.NODES_WORLD_ONE and base == Sable.NODES,
		"world-one 0..5 %s vs base[3] %s" % [wo_ids, base[3]["id"]])
	var runner: Dictionary = wo[3]
	_check("world-one Face Runner data", runner["knob"] == {"vault_air": true} and UpgradeTree.KNOBS["vault_lock"]["default"] == 1.5
		and not runner["knob"].has("vault_lock"), "knobs %s, default lock %.1f" % [runner["knob"], UpgradeTree.KNOBS["vault_lock"]["default"]])
	var other_ok := UpgradeTree.nodes("runner_gunner", true) == Rivet.NODES_WORLD_ONE and UpgradeTree.nodes("demolitions_caster", true) == Kest.NODES_WORLD_ONE
	_check("world-one tables wired for Rivet and Kest while flag-off keeps NODES",
		other_ok and UpgradeTree.nodes("runner_gunner", false) == Rivet.NODES and UpgradeTree.nodes("demolitions_caster", false) == Kest.NODES,
		"Rivet and Kest read NODES_WORLD_ONE with the flag on and NODES with the flag off")
	_check("flag off reads NODES", UpgradeTree.nodes(CLASS_ID, false) == Sable.NODES and UpgradeTree.TREES[CLASS_ID] == Sable.NODES and Sable.NODES[9]["id"] == "s_face_runner"
		and Sable.NODES[9]["knob"]["vault_lock"] == 1.0, "TREES and NODES untouched, base Face Runner at index 9 with lock %.1f" % Sable.NODES[9]["knob"]["vault_lock"])
	var problems := TreeProblems.problems(CLASS_ID, true)
	_check("world-one Sable tree passes the node rules", problems.is_empty(), "%s" % [problems])


func _card_lines(picks: Array, on: bool) -> Array:
	_take(picks, on)
	_game.ctx.tuning.set_option("hotwire_shell", "on")
	_player.tree.open_checkpoint()
	_ws.open_pick()
	var out: Array = []
	for card in _ws.pick.cards():
		out.append([card.node_id(), card.effect_text()])
	_ws.close_pick()
	_game.ctx.tuning.set_option("hotwire_shell", "off")
	return out


func _offers_and_cards() -> void:
	var pairs := {"": ["s_static_flutter", "s_rail_lance"], "s_static_flutter": ["s_cannonball", "s_face_runner"], "s_rail_lance": ["s_beachhead", "s_bulwark"]}
	for parent in pairs:
		var picks: Array = [] if parent == "" else [parent]
		var lines := _card_lines(picks, true)
		var ids: Array = lines.map(func(l): return l[0])
		var tree_ids: Array = _player.tree.offered(CLASS_ID, 1 if parent == "" else 2).map(func(n): return n["id"])
		var label: String = parent if parent != "" else "start"
		_check("offers (flag on, after %s)" % label, ids == pairs[parent] and ids == tree_ids, "cards %s, tree %s, want %s" % [ids, tree_ids, pairs[parent]])
		var same := true
		for l in lines:
			same = same and l[1] == CODEX[l[0]]
		_check("codex lines (flag on, after %s)" % label, same, "%s" % [lines])
	_check("S4 has a card row", WorldOneCards.has_row("s_face_runner") and WorldOneCards.has_row("s_cannonball") and WorldOneCards.has_row("s_bulwark"), "rows for S1 to S6")
	# Flag off: Live Wire in S4's place, every card the node's own effect.
	var off_pairs := {"": ["s_cannonball", "s_beachhead"], "s_cannonball": ["s_coil_hook", "s_live_wire"], "s_beachhead": ["s_arc_nest", "s_bulwark"]}
	var off_ok := true
	var off_bad := ""
	var count := 0
	for parent in off_pairs:
		var lines := _card_lines([] if parent == "" else [parent], false)
		var ids: Array = lines.map(func(l): return l[0])
		if ids != off_pairs[parent]:
			off_ok = false
			off_bad = "offers %s after %s" % [ids, parent]
		for l in lines:
			count += 1
			if l[1] != BASE_EFFECT[l[0]]:
				off_ok = false
				off_bad = "%s: %s" % [l[0], l[1]]
	_check("flag off, base offers and cards exactly", off_ok and count == 6, "%d cards%s" % [count, "" if off_ok else "; " + off_bad])
	# Flag off still offers Face Runner at depth 3, under Live Wire.
	_take(["s_cannonball", "s_live_wire"], false, 3)
	_player.tree.open_checkpoint()
	var d3: Array = _player.tree.offered(CLASS_ID, 3).map(func(n): return n["id"])
	_check("flag off, Face Runner at depth 3 under Live Wire", "s_face_runner" in d3 and UpgradeTree.index_of(CLASS_ID, "s_face_runner") == 9, "depth 3 offers %s" % [d3])


# --- fixtures --------------------------------------------------------------

func _body(at: Vector3, velocity: Vector3) -> Body:
	var b := Body.new()
	b.space = root.world_3d.direct_space_state
	b.transform = Transform3D(Basis.IDENTITY, at)
	b.linear_velocity = velocity
	return b


# One vault kick off the RUN wall from the air; returns the kit's state after.
func _vault(air_actions := 0) -> Dictionary:
	var p = _player
	p.kit.set_on(Augments.VAULT, true)
	p.kit.hooked = false
	p.kit.mounted = false
	p.state.grounded = false
	p.state.jump_buffer = 1.0
	p.state.air_actions = air_actions
	var before: int = p.kit.vault_faces.size()
	var b := _body(RUN, Vector3(0, 0, -20.0))
	Augments._vault(p.kit, p.state, _game.ctx.tuning, Basis.IDENTITY, b)
	var key: String = p.kit.last_vault_face
	return {"kicked": p.kit.vault_faces.size() > before or (key != "" and p.kit.vault_faces.has(key) and p.kit.vault_faces[key] > 0.0),
		"air": p.state.air_actions, "lock": float(p.kit.vault_faces.get(key, 0.0)), "key": key}


func _fling(speed: float) -> float:
	var p = _player
	p.kit.hooked = true
	p.state.velocity = Vector3(0, 0, -speed)
	p._fling()
	p.kit.hooked = false
	return p.state.velocity.length()


func _reach_found() -> bool:
	var b := _body(REACH_RUN, Vector3.ZERO)
	return not Augments._steepest_face(b, Augments.WORLD_MASK, _player.tree.knob("mount_reach")).is_empty()


func _chain_jumps() -> int:
	return int(_combat._patterns[Weapons.PYLON_TURRET].chain_jumps)


# A vault fact on the bus; true when the discharge proc answers with an arc burst.
func _vault_discharges() -> bool:
	_combat.last_burst = {}
	_combat._proc_ready.clear()
	var enemy: Node3D = _combat.spawn_enemy("chaser", _player.ball_position() + Vector3(3.0, 0.0, 0.0))
	_game.events.vault_kicked.emit(_player.ball_position(), 20.0)
	var fired: bool = not _combat.last_burst.is_empty() and _combat.last_burst.get("kind", "") == "arc"
	enemy.remove_from_group("enemy")
	enemy.queue_free()
	return fired


# Mounted, a knock; true when it landed. Damage goes through the run's own door.
func _mounted_cc() -> Dictionary:
	_player.kit.mounted = true
	var landed: bool = _player.crowd_control("knock", Vector3.ZERO)
	var hp_before: float = _game.run.hp
	# Scrap the test's kills left on the ball would soak the hit before the hull sees it.
	var mass_before: float = _game.run.mass
	_game.run.mass = 0.0
	_game.run.damage(1.0, "stree_test")
	var hurt: bool = _game.run.hp < hp_before
	_game.run.hp = hp_before
	_game.run.mass = mass_before
	_player.kit.mounted = false
	return {"landed": landed, "hurt": hurt}


func _retained() -> void:
	# Base control: no picks.
	_take([])
	var base_reach := _reach_found()
	var base_chain := _chain_jumps()
	var base_fling_no_picks := _fling(20.0)
	_check("control: no picks, no discharge, no fling, base reach", not _vault_discharges() and base_fling_no_picks == 20.0 and not base_reach,
		"fling %.1f, reach wall found %s" % [base_fling_no_picks, base_reach])
	# Depth-1 left (s_static_flutter): 3 sparks on tap, 6 pulses charged, keeps mass_launch.
	_take(["s_static_flutter"])
	var flutter_p: Resource = _combat.pattern(Weapons.ARC_CASTER)
	_check("s_static_flutter configures 3 sparks and 6 pulses with mass_launch",
		flutter_p.spark_count == 3 and flutter_p.charge_pulses == 6 and _player.tree.knob("mass_launch"),
		"sparks %d, pulses %d, mass_launch %s" % [flutter_p.spark_count, flutter_p.charge_pulses, _player.tree.knob("mass_launch")])
	# Depth-1 right (s_rail_lance): 1.15 s charge, 2 pierce, no chain, keeps mass_launch.
	_take(["s_rail_lance"])
	var lance_p: Resource = _combat.pattern(Weapons.ARC_CASTER)
	_check("s_rail_lance configures piercing non-chaining lance with mass_launch",
		lance_p.charge_pierce == 2 and lance_p.charge_no_chain and is_equal_approx(lance_p.charge_s, 1.00) and _player.tree.knob("mass_launch"),
		"charge_s %.2f, pierce %d, no_chain %s, mass_launch %s" % [lance_p.charge_s, lance_p.charge_pierce, lance_p.charge_no_chain, _player.tree.knob("mass_launch")])
	# Moved Depth-2 under Flutter (s_cannonball): vault discharge.
	_take(["s_static_flutter", "s_cannonball"])
	_check("S1 moved under Flutter: vault kick sets off a discharge", _vault_discharges() and _player.tree.knob("mass_launch"), "arc burst on vault_kicked, mass_launch %s" % _player.tree.knob("mass_launch"))
	# Moved Depth-2 under Rail Lance (s_beachhead): double reach finds the wall 3.25 m out.
	_take(["s_rail_lance", "s_beachhead"])
	var reach := _reach_found()
	_check("S2 moved under Rail Lance: double mount reach", reach and not base_reach and is_equal_approx(_player.tree.knob("mount_reach"), 2.0) and _player.tree.knob("mass_launch"),
		"wall 3.25 m out found %s, base found %s, reach knob %.1f" % [reach, base_reach, _player.tree.knob("mount_reach")])
	# Flag off: base S3 (Coil Hook) and S5 (Arc Nest) stay intact.
	_take(["s_cannonball", "s_coil_hook"], false)
	var flat := _fling(20.0)
	_check("S3 flag off: fling only, no mass", is_equal_approx(flat, 30.0), "20 in, %.1f out" % flat)
	_take(["s_beachhead", "s_arc_nest"], false)
	var chain := _chain_jumps()
	_check("S5 flag off: one extra turret chain jump", chain == base_chain + 1, "%d chain jumps, base %d" % [chain, base_chain])
	# S6 under Rail Lance: mounted CC immunity without damage immunity.
	_take(["s_rail_lance"])
	var plain := _mounted_cc()
	_take(["s_rail_lance", "s_bulwark"])
	var shrug := _mounted_cc()
	_player.kit.mounted = false
	var unmounted: bool = _player.crowd_control("knock", Vector3.ZERO)
	_check("S6 mounted, crowd control slides off", not shrug["landed"] and plain["landed"] and unmounted, "S6 mounted landed %s, Rail Lance alone landed %s, S6 unmounted landed %s" % [shrug["landed"], plain["landed"], unmounted])
	_check("S6 grants no damage immunity", shrug["hurt"], "hp dropped while mounted with S6: %s" % shrug["hurt"])


func _face_runner() -> void:
	_take(["s_static_flutter", "s_face_runner"])
	var first := _vault(0)
	_check("Face Runner restores one air jump per valid vault", first["kicked"] and first["air"] == 1, "air jumps 0 -> %d" % first["air"])
	_check("Face Runner locks the same face for 1.5 s", is_equal_approx(first["lock"], 1.5), "lock %.2f s" % first["lock"])
	var again := _vault(0)
	_check("a locked face gives no vault and no jump", not again["kicked"] or again["air"] == 0, "second kick air jumps %d" % again["air"])
	_player.kit.vault_faces.clear()
	var third := _vault(0)
	_check("a fresh face restores again", third["air"] == 1, "air jumps %d" % third["air"])
	# Flag off: base Face Runner at depth 3, same restore, a 1 s lock.
	_take(["s_cannonball", "s_live_wire", "s_face_runner"], false, 3)
	var base := _vault(0)
	_check("flag off: Face Runner at depth 3 keeps its 1 s lock", base["air"] == 1 and is_equal_approx(base["lock"], 1.0), "air jumps %d, lock %.2f s" % [base["air"], base["lock"]])
	# Without Face Runner, no restore.
	_take(["s_static_flutter", "s_cannonball"])
	var none := _vault(0)
	_check("control: without Face Runner a vault restores no jump", none["kicked"] and none["air"] == 0, "air jumps %d" % none["air"])


# Ids a pilot's table offers at more than one node within `cap` depths. World-one Face Runner
# (index 3) and the base Face Runner (index 9) share an id; that is safe only while the depth
# cap keeps index 9 out of reach.
func _offerable_dupes(table: Array, cap: int) -> Array:
	var seen := {}
	var dupes := []
	for i in table.size():
		if UpgradeTree.depth_of(i) > cap:
			continue
		var id: String = table[i]["id"]
		if seen.has(id) and not dupes.has(id):
			dupes.append(id)
		seen[id] = true
	return dupes


func _duplicate_guard() -> void:
	var table: Array = UpgradeTree.nodes(CLASS_ID, true)
	var cap: int = UpgradeTree.WORLD_ONE_DEPTHS
	var base_depth: int = UpgradeTree.depth_of(9)
	var live := _offerable_dupes(table, cap)
	_check("no id offerable at two depths within the world-one cap", live.is_empty(), "cap %d, duplicates %s" % [cap, live])
	# The cap is what keeps base Face Runner (index 9) unreachable: it must stay below its depth
	# while the world-one table still holds the id at index 3 and index 9.
	var stays: bool = table[9]["id"] == "s_face_runner" and table[3]["id"] == "s_face_runner"
	_check("cap below base Face Runner's depth while it stays in the table", not stays or cap < base_depth, "cap %d, index 9 at depth %d, held %s" % [cap, base_depth, stays])
	# The guard itself: a scratch cap of 3 must trip it.
	var raised := _offerable_dupes(table, base_depth)
	_check("guard trips when the cap reaches base Face Runner", raised == ["s_face_runner"], "cap %d reports %s" % [base_depth, raised])


func _identities() -> void:
	# Static Flutter + Cannonball: 3-spark flutter and vault discharge.
	_take(["s_static_flutter", "s_cannonball"])
	var d := _vault_discharges()
	_check("identity flutter cannonball", d and _combat.pattern(Weapons.ARC_CASTER).spark_count == 3 and _player.tree.path() == ["s_static_flutter", "s_cannonball"],
		"path %s, vault discharge %s, sparks %d" % [_player.tree.path(), d, _combat.pattern(Weapons.ARC_CASTER).spark_count])
	# Static Flutter + Face Runner: 3-spark flutter, an air jump back, the 1.5 s lock.
	_take(["s_static_flutter", "s_face_runner"])
	var v := _vault(0)
	_check("identity ninja platformer", _combat.pattern(Weapons.ARC_CASTER).spark_count == 3 and v["air"] == 1 and is_equal_approx(v["lock"], 1.5) and _player.tree.path() == ["s_static_flutter", "s_face_runner"],
		"path %s, air jumps %d, lock %.1f s" % [_player.tree.path(), v["air"], v["lock"]])
	# Rail Lance + Beachhead: piercing lance, double mount reach.
	_take(["s_rail_lance", "s_beachhead"])
	var reach5 := _reach_found()
	_check("identity mobile siege, Beachhead", reach5 and _combat.pattern(Weapons.ARC_CASTER).charge_pierce == 2 and _player.tree.path() == ["s_rail_lance", "s_beachhead"],
		"path %s, long reach %s, pierce %d" % [_player.tree.path(), reach5, _combat.pattern(Weapons.ARC_CASTER).charge_pierce])
	# Rail Lance + Bulwark: piercing lance, mounted CC immunity.
	_take(["s_rail_lance", "s_bulwark"])
	var cc := _mounted_cc()
	_check("identity mobile siege, Bulwark", _combat.pattern(Weapons.ARC_CASTER).charge_pierce == 2 and not cc["landed"] and cc["hurt"] and _player.tree.path() == ["s_rail_lance", "s_bulwark"],
		"path %s, cc landed %s, hurt %s" % [_player.tree.path(), cc["landed"], cc["hurt"]])
	# The two Rail Lance children exclude each other.
	var third: bool = _player.tree.pick("s_beachhead")
	_check("Beachhead and Bulwark exclusive", not third, "second pick accepted %s" % third)
