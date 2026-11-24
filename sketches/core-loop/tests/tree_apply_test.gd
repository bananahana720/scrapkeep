# smoke: solo timeout=300s (every node of every pilot tree in the real game; about 190 s alone, 2026-10-12)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const Weapons := preload("res://src/combat/weapons.gd")

# Every node of the three trees in the real game (calm, stage 1): a fresh run offers
# depth 1 on the bus, the path to the node is picked through the ball's tree with
# tree_offered and tree_picked published, and then the node's own effect is live
# where the game reads it (the slot's ability id and stockpile, the knob readers in the
# kit and combat, combat's weapon pattern, the branch tags). Each proc is fired through
# its real bus signal and must do its action once, then hold for its gap. A new run
# reverts all of it. Then the three swaps are played (Crater Slam spends F on a slam,
# Point Blank draws half the blast, Sticky Rain throws three), and a charge upgrade an
# item gave survives a swap and a stockpile pick.
#
# Evidence limit: effects are read where the game reads them and procs are driven
# through the bus, not played; tree_play_test plays every build, and nothing here says
# anything about feel or balance.
# Re-pinned 2026-10-10 (wave P-B unit B1, design-v3/SKILL-BAR.md section 10): the bar's
# fifth slot, the line skill, is restored and compared like the other four, and the
# ultimate id, which apply_pick can now swap, must come back to the pilot's row. A special
# proc is measured on the slot that pays for the special (Tally's pooled pressure).

var _game
var _player
var _combat
var _source := Intent.Scripted.new()
var _failures := 0
var _done := false
var _offers: Array = []
var _picked: Array = []
var _struck := 0
var _shots := 0
var _specials: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _done or _game.flow == null:
		return false
	_done = true
	_game.ctx.calm = true
	_game.tuning.set_option("world_one_builds", "off")
	_player = _game.player
	_combat = _game.combat
	_player.source = _source
	var events = _game.events
	events.tree_offered.connect(func(c: String, d: int, ids: Array): _offers.append([c, d, ids]))
	events.tree_picked.connect(func(c: String, id: String, d: int): _picked.append([c, id, d]))
	events.enemy_struck.connect(func(_e: Node3D, _k: String, _f: float): _struck += 1)
	events.shot_fired.connect(func(_w: String, _a: Vector3, _b: Vector3): _shots += 1)
	events.special_used.connect(func(id: String, _at: Vector3): _specials.append(id))
	_game.flow.press_start()
	_game.flow.choose_class(0)
	for def in ClassDef.all():
		var bad := []
		for n in UpgradeTree.nodes(def.id):
			var why := _node_applies_and_reverts(def, n)
			if why != "":
				bad.append("%s: %s" % [n["id"], why])
		_report("%s nodes apply and revert" % def.display_name, bad.is_empty(),
			"%d of 30 nodes applied on their path and reverted on a new run; failures %s" % [30 - bad.size(), bad])
	_crater()
	_point_blank()
	_sticky_rain_and_items()
	print("tree_apply_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _new_run(def) -> void:
	_clear_enemies()
	_combat.sticky.clear()
	_game.run.class_def = def
	_game.flow.new_run()
	var at: Vector3 = _game.ctx.terrain.spawn_point(1)
	_player.reset_to(at)
	_player.body().global_position = at


func _clear_enemies() -> void:
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.queue_free()


func _spawn_ring(count: int) -> Array:
	var out := []
	var at: Vector3 = _player.ball_position()
	for i in count:
		var angle := TAU * float(i) / float(count)
		var flat := at + Vector3(cos(angle), 0.0, sin(angle)) * 3.0
		out.append(_combat.spawn_enemy("chaser", Vector3(flat.x, _game.ctx.terrain.height(flat.x, flat.z) + 1.5, flat.z)))
	return out


# Picks the path to a node as the game offers it: depth 1 at the run's start, then one
# checkpoint per depth. Returns "" or what went wrong.
func _pick_path(def, node_id: String) -> String:
	var tree = _player.tree
	var path := UpgradeTree.path_to(def.id, node_id)
	for depth in range(1, path.size() + 1):
		if depth > 1:
			tree.open_checkpoint()
		var offer: Array = _offers.back() if not _offers.is_empty() else []
		if offer.size() != 3 or offer[0] != def.id or offer[1] != depth or not path[depth - 1] in offer[2]:
			return "depth %d offer %s" % [depth, offer]
		if not tree.pick(path[depth - 1]) or _picked.back() != [def.id, path[depth - 1], depth]:
			return "depth %d pick %s, last tree_picked %s" % [depth, path[depth - 1], _picked.back() if not _picked.is_empty() else null]
	return ""


func _expected_pattern(weapon: String, path: Array, def) -> Resource:
	var p: Resource = Weapons.base(weapon).transformed(_combat.active_transformers())
	for id in path:
		var ops: Dictionary = UpgradeTree.node(def.id, id).get("pattern", {})
		if ops.has(weapon):
			p._apply(ops[weapon])
	p._clamp()
	return p


func _node_applies_and_reverts(def, n: Dictionary) -> String:
	_new_run(def)
	if _offers.back() != [def.id, 1, [UpgradeTree.nodes(def.id)[0]["id"], UpgradeTree.nodes(def.id)[1]["id"]]]:
		return "run start offered %s" % [_offers.back()]
	var why := _pick_path(def, n["id"])
	if why != "":
		return why
	var path := UpgradeTree.path_to(def.id, n["id"])
	var abilities = _player.abilities
	for slot in n.get("swap", {}):
		# Q's ultimate is not a bar slot: apply_pick writes it to ultimate_id, as _is_plain reads it.
		var held: String = abilities.ultimate_id if slot == AbilityState.ULTIMATE else abilities.id_of(slot)
		if held != n["swap"][slot]:
			return "slot %s holds %s" % [slot, held]
	for slot in n.get("charges", {}):
		var extra := 0
		for id in path:
			extra += int(UpgradeTree.node(def.id, id).get("charges", {}).get(slot, 0))
		if abilities.slot(slot).max_charges != 1 + extra or abilities.slot(slot).charges != 1 + extra:
			return "slot %s stockpile %d/%d" % [slot, abilities.slot(slot).charges, abilities.slot(slot).max_charges]
	for k in n.get("knob", {}):
		var want = n["knob"][k]
		if UpgradeTree.KNOBS[k].get("time", false):
			want = maxf(AbilityState.COOLDOWN_FLOOR, float(want))
		if _player.kit.knob(k) != want or _combat._knob(k) != want:
			return "knob %s reads %s in the kit, %s in combat" % [k, _player.kit.knob(k), _combat._knob(k)]
	for w in n.get("pattern", {}):
		var live: Resource = _combat._patterns[w]
		var want := _expected_pattern(w, path, def)
		var plain: Resource = Weapons.base(w).transformed(_combat.active_transformers())
		var changed := false
		for part in n["pattern"][w]:
			for key in n["pattern"][w][part]:
				if not is_equal_approx(float(live.get(key)), float(want.get(key))):
					return "pattern %s.%s is %s, want %s" % [w, key, live.get(key), want.get(key)]
				changed = changed or not is_equal_approx(float(live.get(key)), float(plain.get(key)))
		if not changed:
			return "pattern %s unchanged" % w
	for p in n.get("proc", []):
		why = _proc_fires(p)
		if why != "":
			return why
	var tags: PackedStringArray = _player.tree.branch_tags()
	for t in n["tags"]:
		if not tags.has(t):
			return "branch_tags %s lacks %s" % [tags, t]
	_new_run(def)
	return _is_plain(def)


# The untouched kit, as a fresh run must leave it.
func _is_plain(def) -> String:
	var tree = _player.tree
	var abilities = _player.abilities
	if not tree.path().is_empty() or not tree.procs().is_empty() or not tree.branch_tags().is_empty():
		return "new run kept picks %s" % [tree.path()]
	for k in UpgradeTree.KNOBS:
		if _player.kit.knob(k) != UpgradeTree.KNOBS[k]["default"]:
			return "new run kept knob %s = %s" % [k, _player.kit.knob(k)]
	var ids := {"weapon": def.weapon_id, "movement": def.movement_id, "special": def.special_id, "smash": def.smash_id,
		"line": def.line_id}
	if abilities.ultimate_id != def.ultimate_id:
		return "new run kept ultimate %s" % abilities.ultimate_id
	for slot in AbilityState.SLOTS:
		# A plain slot holds one charge, except a pressure weapon (Tally's reader), whose row
		# names its own cap (wave 15, 2026-10-05).
		var plain_cap: int = int(AbilityState.ABILITIES.get(ids[slot], {}).get("pressure", 1))
		if abilities.id_of(slot) != ids[slot] or abilities.slot(slot).max_charges != plain_cap:
			return "new run slot %s is %s with %d charges" % [slot, abilities.id_of(slot), abilities.slot(slot).max_charges]
	for w in Weapons.ALL:
		var plain: Resource = Weapons.base(w).transformed(_combat.active_transformers())
		for key in ["count", "spread_deg", "arms", "spin_deg", "damage", "rate", "chain_jumps", "chain_range", "bolt_radius"]:
			if not is_equal_approx(float(_combat._patterns[w].get(key)), float(plain.get(key))):
				return "new run kept pattern %s.%s = %s" % [w, key, _combat._patterns[w].get(key)]
	if _player.kit.movement_id != def.movement_id or _player.kit.smash_id != def.smash_id:
		return "new run kit %s / %s" % [_player.kit.movement_id, _player.kit.smash_id]
	return ""


# Emits the proc's real bus fact twice in one tick: the action must happen once.
func _proc_fires(p: Dictionary) -> String:
	var enemies := _spawn_ring(3)
	var abilities = _player.abilities
	var events = _game.events
	var args := []
	for info in events.get_signal_list():
		if info["name"] != p["on"]:
			continue
		for arg in info["args"]:
			match arg["type"]:
				TYPE_OBJECT: args.append(enemies[0])
				TYPE_VECTOR3: args.append(_player.ball_position())
				TYPE_FLOAT: args.append(10.0)
				TYPE_INT: args.append(1)
				TYPE_BOOL: args.append(false)
				TYPE_STRING: args.append("test")
				_: args.append(null)
	var measure := func() -> float:
		match p["do"]:
			"discharge", "blast", "detonate": return float(_struck)
			"volley": return float(_shots)
			"charge": return float(_combat.sticky.charges.size())
			"grant_special", "refund_special":
				var payer = abilities.slot(abilities.pool_of(AbilityState.SPECIAL))
				return payer.charges + payer.recharge * 0.001
			"grant_move", "refund_move": return abilities.slot(AbilityState.MOVEMENT).charges + abilities.slot(AbilityState.MOVEMENT).recharge * 0.001
			"overdrive": return _combat._overdrive
			"air": return float(_player.state.air_actions)
		return 0.0
	# Tally's special pays from slot 1's pressure, which a smash also refills on its own
	# (combat's _grant_pressure), so a pooled special primes two charges down and is judged
	# by the step: the first emit must gain more than the second, inside the gap.
	var pooled: bool = p["do"] in ["grant_special", "refund_special"] and abilities.pool_of(AbilityState.SPECIAL) != AbilityState.SPECIAL
	var prime := func() -> void:
		match p["do"]:
			"grant_special", "refund_special":
				abilities.spend(AbilityState.SPECIAL)
				if pooled:
					abilities.spend(AbilityState.SPECIAL)
			"grant_move", "refund_move": abilities.spend(AbilityState.MOVEMENT)
			"overdrive": _combat._overdrive = 0.0
			"air": _player.state.air_actions = 0
	prime.call()
	var before: float = measure.call()
	events.callv("emit_signal", [p["on"]] + args)
	var once: float = measure.call()
	prime.call()
	var primed: float = measure.call()
	events.callv("emit_signal", [p["on"]] + args)
	var twice: float = measure.call()
	_clear_enemies()
	_combat.sticky.clear()
	if not once > before:
		return "proc %s on %s did nothing (%s -> %s)" % [p["do"], p["on"], before, once]
	if pooled and twice - primed >= once - before:
		return "proc %s on %s fired twice inside its gap (%s -> %s, then %s -> %s)" % [p["do"], p["on"], before, once, primed, twice]
	if not pooled and twice > primed and not p["do"] in ["discharge", "blast", "detonate", "volley", "charge"]:
		return "proc %s on %s fired twice inside its gap" % [p["do"], p["on"]]
	if p["do"] in ["discharge", "blast", "detonate", "volley", "charge"] and twice - once > 0.0:
		return "proc %s on %s fired twice inside its gap (%s -> %s)" % [p["do"], p["on"], once, twice]
	return ""


func _crater() -> void:
	var def = ClassDef.by_id("pylon_engineer")
	_new_run(def)
	var why := _pick_path(def, "s_crater")
	var abilities = _player.abilities
	_spawn_ring(3)
	var charges_before: int = abilities.slot(AbilityState.SPECIAL).charges
	_specials.clear()
	var struck_before := _struck
	_game.events.slammed.emit(_player.ball_position(), 1.0, 1.0)
	var spent: bool = abilities.slot(AbilityState.SPECIAL).charges == charges_before - 1
	var ok: bool = why == "" and abilities.id_of(AbilityState.SMASH) == "crater_slam" and _player.kit.smash_flavour == "arc" \
		and spent and _specials.has("detonation_gauge") and _struck > struck_before
	_report("crater slam", ok, "path %s; smash %s (%s landing); F charges %d -> %d; special_used %s; %d enemies struck"
		% [why if why != "" else "picked", abilities.id_of(AbilityState.SMASH), _player.kit.smash_flavour, charges_before,
			abilities.slot(AbilityState.SPECIAL).charges, _specials, _struck - struck_before])
	_clear_enemies()


func _point_blank() -> void:
	var def = ClassDef.by_id("runner_gunner")
	_new_run(def)
	var plain: Dictionary = _combat._specials["overdrive_blast"]["geometry"].call(1.0)
	var why := _pick_path(def, "r_point_blank")
	var id: String = _player.abilities.id_of(AbilityState.SPECIAL)
	var shape: Dictionary = _combat._specials[id]["geometry"].call(1.0) if _combat._specials.has(id) else {}
	var ok: bool = why == "" and id == "point_blank" and not shape.is_empty() \
		and is_equal_approx(float(shape["radius"]), float(plain["radius"]) * Weapons.POINT_BLANK_RADIUS)
	_report("point blank", ok, "path %s; F plays %s; full blast radius %.1f m against %.1f m"
		% [why if why != "" else "picked", id, float(shape.get("radius", -1.0)), float(plain["radius"])])


func _sticky_rain_and_items() -> void:
	var def = ClassDef.by_id("demolitions_caster")
	_new_run(def)
	var abilities = _player.abilities
	abilities.set_max_charges(AbilityState.WEAPON, 3)
	var why := _pick_path(def, "k_minefield")
	var after_stockpile: int = abilities.slot(AbilityState.WEAPON).max_charges
	if why == "":
		_player.tree.open_checkpoint()
		if not _player.tree.pick("k_sticky_rain"):
			why = "Sticky Rain not offered after Minefield"
	var after_swap: int = abilities.slot(AbilityState.WEAPON).max_charges
	_report("item charges kept", why == "" and after_stockpile == 4 and after_swap == 4,
		"an item's 3 LMB charges, then Minefield: %d, then the Sticky Rain swap: %d (path %s)"
			% [after_stockpile, after_swap, why if why != "" else "picked"])
	var before: int = _combat.sticky.charges.size()
	var landing: Vector3 = _player.ball_position() + Vector3(0.0, -0.5, -8.0)
	_combat._throw_sticky(landing)
	var thrown: int = _combat.sticky.charges.size() - before
	_report("sticky rain", abilities.id_of(AbilityState.WEAPON) == "sticky_rain" and thrown == 3,
		"LMB plays %s; one throw left %d charges" % [abilities.id_of(AbilityState.WEAPON), thrown])
	_combat.sticky.clear()
