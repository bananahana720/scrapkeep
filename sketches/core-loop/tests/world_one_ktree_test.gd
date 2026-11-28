extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Sticky := preload("res://src/combat/sticky.gd")
const WorldOneCards := preload("res://src/core/trees/world_one_cards.gd")

# Kest's world-one kit (BUILD-SYSTEMS.md, ### Kest), K1 to K6, and the shared card table.
#   - Flag on: the pick screen shows the six Codex lines and the offers match the tree
#     (root pair, then the children of the first pick). Flag off: every card of all three
#     classes shows the node's own effect, compared with the base strings copied below from
#     b2897d3. Under the flag, a node with no row (Sable, Rivet) still shows its own effect.
#   - Each retained effect, through the real combat: K1 five live charges on 2.5 s fuses;
#     K2 sight share 0.3; K3 charges carry the 2 m knob as their reach and spring at a hull
#     gap of 1.9 m, not 2.1 m; K4 a slam scatters five; K5 gliding keeps the cloak; K6 a
#     throw keeps it. K5 and K6 are exclusive.
#   - The four identities, each producing its named behaviour: route trapper K1 to K3,
#     dive bomber K1 to K4, gliding infiltrator K2 to K5, ambusher K2 to K6.
#
# Evidence limit: a fixture on the real Game; nothing here says the paths feel different.
# K5's Riveted Shell inversion is built, so the K5 card shows its Codex line like the rest.

const BASE_EFFECT := {
	"k_trapper": "Charges wait longer; five can be live",
	"k_ghost": "Cloaked, machines only spot you up close",
	"k_tripwire": "Charges trigger from two metres away",
	"k_demo_expert": "Demo slams scatter five charges",
	"k_smoke_trail": "Gliding keeps you cloaked",
	"k_ambush": "Throwing no longer breaks your cloak",
}
const CODEX := {
	"k_cluster": "Throws scatter three small charges sharing snap.",
	"k_keg": "One wide slow keg breaks tough props.",
	"k_trapper": "Charges wait longer. Five can wait at once.",
	"k_ghost": "Cloaked, machines spot you only up close.",
	"k_tripwire": "Charges spring when machines approach.",
	"k_smoke_trail": "Glide cloaked. Steer sharper while you glide.",
}
const LANDING := Vector3(6.0, 0.0, 6.0)

var _game
var _combat
var _player
var _ws
var _failures := 0
var _booted := false


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
	_kest()
	_cards()
	_retained()
	_identities()
	_exclusive()
	print("world_one_ktree_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _flag(on: bool) -> void:
	_game.ctx.tuning.set_option("world_one_builds", "on" if on else "off")


func _kest() -> void:
	var def: Resource = ClassDef.by_id("demolitions_caster")
	_game.run.class_def = def
	_player.fit_class(def)
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.queue_free()
	_combat.sticky.clear()
	_combat.cloak_left = 0.0
	var at: Vector3 = _game.ctx.terrain.spawn_point(1)
	_player.reset_to(at)
	_player.body().global_position = at


# A fresh Kest tree holding exactly these picks (two depths, as the profile allows).
func _take(picks: Array) -> void:
	var tree = _player.tree
	tree.reset("demolitions_caster")
	tree.max_depth = UpgradeTree.WORLD_ONE_DEPTHS
	tree.world_one = _game.ctx.tuning.option("world_one_builds") == "on"
	for id in picks:
		tree.open_checkpoint()
		tree.pick(id)
	_combat.sticky.clear()
	_combat.cloak_left = 0.0
	_player.kit.gliding = false


func _card_lines(class_id: String, picks: Array) -> Array:
	_game.ctx.tuning.set_option("hotwire_shell", "on")
	var tree = _player.tree
	tree.reset(class_id)
	tree.max_depth = UpgradeTree.WORLD_ONE_DEPTHS
	tree.world_one = _game.ctx.tuning.option("world_one_builds") == "on"
	for id in picks:
		tree.open_checkpoint()
		tree.pick(id)
	tree.open_checkpoint()
	_ws.open_pick()
	var out: Array = []
	for card in _ws.pick.cards():
		out.append([card.node_id(), card.effect_text()])
	_game.ctx.tuning.set_option("hotwire_shell", "off")
	return out


func _cards() -> void:
	_flag(true)
	var pairs := {"": ["k_cluster", "k_keg"], "k_cluster": ["k_tripwire", "k_trapper"], "k_keg": ["k_smoke_trail", "k_ghost"]}
	var seen := 0
	for parent in pairs:
		var lines := _card_lines("demolitions_caster", [] if parent == "" else [parent])
		var ids: Array = lines.map(func(l): return l[0])
		var want: Array = pairs[parent]
		var tree_ids: Array = _player.tree.offered("demolitions_caster", 1 if parent == "" else 2).map(func(n): return n["id"])
		_check("offers match tree (flag on, after %s)" % (parent if parent != "" else "start"), ids == want and ids == tree_ids,
			"cards %s, tree %s, want %s" % [ids, tree_ids, want])
		var same := true
		for l in lines:
			same = same and l[1] == CODEX[l[0]]
		_check("codex lines (flag on, after %s)" % (parent if parent != "" else "start"), same, "%s" % [lines])
		seen += lines.size()
	_check("all six Kest cards seen", seen == 6, "%d cards" % seen)
	# A node with no row keeps its own copy under the flag.
	var other_ok := true
	var other := ""
	for class_id in ["runner_gunner"]:
		var wo: Array = UpgradeTree.nodes(class_id, true)
		for parent in [[], [wo[0]["id"]], [wo[1]["id"]]]:
			for l in _card_lines(class_id, parent):
				var own := String(UpgradeTree.node(class_id, l[0], true)["effect"])
				if not WorldOneCards.has_row(l[0]) and l[1] != own:
					other_ok = false
					other = "%s: %s vs %s" % [l[0], l[1], own]
	_check("no row, own effect (flag on, Rivet)", other_ok and not WorldOneCards.has_row("s_none"), other if other != "" else "every Rivet card reads its row or node effect")
	# Flag off: every card of every class is the node's own effect; Kest's equal the base strings.
	_flag(false)
	var off_ok := true
	var off_bad := ""
	var count := 0
	for class_id in UpgradeTree.TREES:
		var list: Array = UpgradeTree.nodes(class_id)
		for parent in [[], [list[0]["id"]], [list[1]["id"]]]:
			for l in _card_lines(class_id, parent):
				count += 1
				var want := String(BASE_EFFECT[l[0]]) if BASE_EFFECT.has(l[0]) else String(UpgradeTree.node(class_id, l[0])["effect"])
				if l[1] != want:
					off_ok = false
					off_bad = "%s: %s vs %s" % [l[0], l[1], want]
	# 2026-10-05: six cards per pilot tree, six pilots, the remembered cannon on its own tree.
	_check("flag off, base effects exactly", off_ok and count == 6 * UpgradeTree.TREES.size(), "%d cards%s" % [count, "" if off_ok else "; " + off_bad])
	var node_ok := true
	for id in BASE_EFFECT:
		node_ok = node_ok and String(UpgradeTree.node("demolitions_caster", id)["effect"]) == BASE_EFFECT[id]
	_check("node effect constants unchanged", node_ok, "Kest.NODES effects equal the base strings")
	_ws.close_pick()


# Throws one real charge and returns it.
func _throw() -> Dictionary:
	_combat._throw_sticky(LANDING)
	return _combat.sticky.live().back()


# Springs a charge with an enemy's hull `gap` metres from it. True when it goes off.
func _springs(charge: Dictionary, gap: float) -> bool:
	var probe: Node3D = _combat.spawn_enemy("chaser", Vector3(300.0, 20.0, 300.0))
	var hull: float = _combat.hull_radius(probe)
	charge["stuck"] = true
	charge["arm"] = 0.0
	charge["fuse"] = 100.0
	charge["pos"] = probe.global_position - Vector3(hull + gap, 0.0, 0.0)
	var gone: Array = _combat.sticky.step(0.001, null, [probe])
	var fired: bool = gone.has(charge)
	probe.remove_from_group("enemy")
	probe.queue_free()
	return fired


func _retained() -> void:
	_flag(true)
	# Base, no picks: the numbers the picks change.
	_take([])
	var base_reach: float = _combat._knob("sticky_reach")
	var base_fuse: float = _combat._knob("sticky_fuse")
	var base_live: int = int(_combat._knob("sticky_max_live"))
	var base_sight: float = _combat.cloak_sight()
	# Depth 1 left (k_cluster): scatters 3 charges per throw, 0.60 s floor, 0.7x radius.
	_take(["k_cluster"])
	_combat._throw_sticky(LANDING)
	var cluster_p: Resource = _combat.pattern(Weapons.STICKY_CHARGE)
	_check("k_cluster scatters 3 charges", _combat.sticky.live().size() == 3 and cluster_p.count == 3 and is_equal_approx(cluster_p.floor_s, 0.60),
		"live %d, count %d, floor %.2f" % [_combat.sticky.live().size(), cluster_p.count, cluster_p.floor_s])
	# Depth 1 right (k_keg): 1 live charge at a time, 1.40 s floor, 2x radius, breaks props.
	_take(["k_keg"])
	var keg_p: Resource = _combat.pattern(Weapons.STICKY_CHARGE)
	_throw()
	_throw()
	_check("k_keg holds 1 live charge and breaks props", _combat.sticky.live().size() == 1 and keg_p.max_live == 1 and keg_p.breaks_props and is_equal_approx(keg_p.floor_s, 1.40),
		"live %d, max_live %d, breaks_props %s, floor %.2f" % [_combat.sticky.live().size(), keg_p.max_live, keg_p.breaks_props, keg_p.floor_s])
	# Moved Depth 2 under Cluster (k_trapper): fuse 2.5, five live throws (15 sub-charges at count=3).
	_take(["k_cluster", "k_trapper"])
	var first := _throw()
	for i in 6:
		_throw()
	var live: int = _combat.sticky.live().size()
	_check("K1 moved under Cluster: fuse", is_equal_approx(float(first["fuse"]), 2.5) and not is_equal_approx(base_fuse, 2.5), "fuse %.2f, base %.2f" % [float(first["fuse"]), base_fuse])
	_check("K1 moved under Cluster: five live volleys (15 sub-charges)", live == 15 and base_live != 5, "%d live after throws, base cap %d" % [live, base_live])
	# Moved Depth 2 under Keg (k_ghost): sight share 0.3.
	_take(["k_keg", "k_ghost"])
	_check("K2 moved under Keg: cloak sight", is_equal_approx(_combat.cloak_sight(), 0.3) and not is_equal_approx(base_sight, 0.3), "sight %.2f, base %.2f" % [_combat.cloak_sight(), base_sight])
	# K3 under Cluster: reach knob carried by the charge; 1.9 m springs, 2.1 m does not; base reach does neither.
	_take(["k_cluster", "k_tripwire"])
	var wired := _throw()
	_check("K3 combat passes the knob as reach", is_equal_approx(float(wired["reach"]), 2.0) and is_equal_approx(base_reach, Sticky.CONTACT_REACH), "charge reach %.2f, knob %.2f, base %.2f" % [float(wired["reach"]), _combat._knob("sticky_reach"), base_reach])
	var at_19 := _springs(wired, 1.9)
	_combat.sticky.clear()
	var at_21 := _springs(_throw(), 2.1)
	_check("K3 springs within 2 m, not at 2.1 m", at_19 and not at_21, "gap 1.9 m fired %s, gap 2.1 m fired %s" % [at_19, at_21])
	_take(["k_cluster", "k_trapper"])
	var plain_19 := _springs(_throw(), 1.9)
	_check("K3 control: without it 1.9 m does not spring", not plain_19, "Cluster+Trapper only, gap 1.9 m fired %s" % plain_19)
	# K5 under Keg: gliding keeps the cloak.
	_take(["k_keg", "k_smoke_trail"])
	var glide := _glide_cloak()
	_take(["k_keg", "k_ghost"])
	var glide_without := _glide_cloak()
	_check("K5 glide keeps the cloak", glide and not glide_without, "K5 gliding cloaked %s, Ghost path gliding cloaked %s" % [glide, glide_without])
	# Flag off: base K4 and K6 still work untouched.
	_flag(false)
	_take([])
	var base_minis := _slam_count()
	_take(["k_trapper", "k_demo_expert"])
	var minis := _slam_count()
	_check("base K4 slam scatters five (flag off)", minis == 5 and base_minis != 5, "%d charges, base %d" % [minis, base_minis])
	_take(["k_ghost", "k_ambush"])
	var kept := _shot_keeps_cloak()
	_take(["k_ghost", "k_smoke_trail"])
	var broken := not _shot_keeps_cloak()
	_check("base K6 throw keeps the cloak (flag off)", kept and broken, "K6 kept %s, K5 path broke %s" % [kept, broken])


func _slam_count() -> int:
	_combat.sticky.clear()
	_game.events.demo_slammed.emit(_player.ball_position() + Vector3.DOWN * 0.9)
	return _combat.sticky.live(true).size()


func _glide_cloak() -> bool:
	_combat.cloak_left = 0.0
	_player.kit.gliding = true
	_combat._tick_cloak(0.016)
	var cloaked: bool = _combat.cloak_left > 0.0 and _player.kit.cloaked
	_player.kit.gliding = false
	_combat.cloak_left = 0.0
	return cloaked


func _shot_keeps_cloak() -> bool:
	_combat.cloak_left = 1.5
	_combat.sticky.clear()
	_combat._throw_sticky(LANDING)
	var kept: bool = _combat.cloak_left > 0.0
	_combat.cloak_left = 0.0
	return kept


func _identities() -> void:
	_flag(true)
	# Cluster + Tripwire: scattered charges that spring from 2 m.
	_take(["k_cluster", "k_tripwire"])
	_throw()
	var trap_live: Array = _combat.sticky.live()
	var trap_fires := _springs(trap_live.back(), 1.9)
	_check("identity cluster tripwire", trap_live.size() == 3 and trap_fires and _player.tree.path() == ["k_cluster", "k_tripwire"],
		"path %s, %d live, fires at 1.9 m %s" % [_player.tree.path(), trap_live.size(), trap_fires])
	# Cluster + Trapper: scattered charges with 5-volley live cap (15 sub-charges) and 2.5 s fuse.
	_take(["k_cluster", "k_trapper"])
	for i in 6:
		_throw()
	var dive_live: int = _combat.sticky.live().size()
	_check("identity cluster trapper", dive_live == 15 and _player.tree.path() == ["k_cluster", "k_trapper"],
		"path %s, %d live" % [_player.tree.path(), dive_live])
	# Keg + Smoke Trail: prop-breaking keg, gliding keeps the cloak.
	_take(["k_keg", "k_smoke_trail"])
	var inf := _glide_cloak()
	_check("identity keg smoke trail", inf and _combat.pattern(Weapons.STICKY_CHARGE).breaks_props and _player.tree.path() == ["k_keg", "k_smoke_trail"],
		"path %s, glide cloaked %s, breaks_props %s" % [_player.tree.path(), inf, _combat.pattern(Weapons.STICKY_CHARGE).breaks_props])
	# Keg + Ghost: prop-breaking keg, seen only close while cloaked.
	_take(["k_keg", "k_ghost"])
	_check("identity keg ghost", is_equal_approx(_combat.cloak_sight(), 0.3) and _combat.pattern(Weapons.STICKY_CHARGE).breaks_props and _player.tree.path() == ["k_keg", "k_ghost"],
		"path %s, sight %.2f, breaks_props %s" % [_player.tree.path(), _combat.cloak_sight(), _combat.pattern(Weapons.STICKY_CHARGE).breaks_props])


func _exclusive() -> void:
	_flag(true)
	_take(["k_keg", "k_smoke_trail"])
	var second: bool = _player.tree.pick("k_ghost")
	_check("Smoke Trail and Ghost exclusive (taken Smoke Trail)", not second and _player.tree.path() == ["k_keg", "k_smoke_trail"] and not is_equal_approx(_combat.cloak_sight(), 0.3),
		"second pick accepted %s, path %s, sight %.2f" % [second, _player.tree.path(), _combat.cloak_sight()])
	_take(["k_keg", "k_ghost"])
	var other: bool = _player.tree.pick("k_smoke_trail")
	_check("Smoke Trail and Ghost exclusive (taken Ghost)", not other and not _combat._knob("glide_cloak"), "second pick accepted %s, glide_cloak %s" % [other, _combat._knob("glide_cloak")])
	_take(["k_cluster"])
	var offered: Array = _player.tree.offered("demolitions_caster", 2).map(func(n): return n["id"])
	_check("Cluster never offers Smoke Trail or Ghost", not offered.has("k_smoke_trail") and not offered.has("k_ghost"), "offered %s" % [offered])
