# smoke: timeout=330s
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")

# Contacts met in one physics tick end in one game state whatever order they arrive in.
# contact_order_test tries 3 of the 6 orders of a pair or trio on real physics; this one
# builds up to four contacts from a fixed seed, runs EVERY order (2, 6 or 24) on a fresh game
# and compares each snapshot with the first.
#
# Contacts are of two sorts:
# - A touch (an enemy the ball meets): listed to the real RigidBall._note_enemies through a fake
#   physics state in arrival order, then told through the real _on_body_entered, so the game's
#   own sort (Contact.meets_first) is what is under test.
# - A direct fact (an enemy's hit on the hull, a pickup, a hazard): applied through the public
#   door the game uses for it, at its place in the arrival order.
# Events are compared as a multiset: the game promises no order between independent facts, and
# the touches' own order is already pinned by the state they leave. Whether the raw event lists
# also agree is printed as a note.
# Planted control: the same sets with the sort bypassed (touches told in arrival order) must
# show an order-dependent state, or the comparison proves nothing.
# Evidence limit: the physics server is faked, so this shows the game's rules agree; it does
# not show what a real server lists.

const SEED := 4301
# 2 + 6 + 6 + 24 + 24 over SETS: a fixed count, so the check cannot agree with itself.
const ORDERS_EXPECTED := 62

# Each set is a list of contact kinds. Touches: heavy (rebounds the ball), kill (a ram that
# kills), soft (a ram that does not kill), stomp (a drop onto an enemy below). Direct: hit,
# pickup, hazard.
const SETS := [
	["heavy", "heavy"],
	["heavy", "kill", "pickup"],
	["heavy", "heavy", "stomp"],
	["heavy", "heavy", "kill", "hit"],
	["stomp", "kill", "soft", "hazard"],
]
# Control sets: two rebounds off bodies at different angles leave the ball going the way the
# LAST one pushed it, so the sort must matter here, and the unsorted run must show it.
const CONTROL_SETS := [["heavy", "heavy"], ["heavy", "heavy", "stomp"]]
# Written by _process (a render frame, so its timing is not the game's state): the drawn roll.
const RENDER_ONLY := {"player._roll": true}
# A pickup before damage (a hazard here) lets the scrap absorb part of it (run_state.gd _damage_armored); the
# game orders them by process order, not by a physics server list, so this pair is not part of
# the "same state" claim. The test pins that the comparison can see it.
const KNOWN_PAIR := ["pickup", "hazard"]
const TOUCHES := ["heavy", "kill", "soft", "stomp"]


# A physics state that lists the given enemies as contacts, in the given order.
class FakeState extends PhysicsDirectBodyState3DExtension:
	var listed: Array = []
	var origin := Vector3.ZERO

	func _get_contact_count() -> int:
		return listed.size()

	func _get_contact_collider_object(index: int) -> Object:
		return listed[index]

	func _get_transform() -> Transform3D:
		return Transform3D(Basis.IDENTITY, origin)


var _failures := 0
var _runs := 0
var _tags := {}
var _noise := {}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [label, detail, "ok" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _initialize() -> void:
	_run()


func _permutations(items: Array) -> Array:
	if items.size() <= 1:
		return [items.duplicate()]
	var out := []
	for i in items.size():
		var rest := items.duplicate()
		var head = rest.pop_at(i)
		for tail in _permutations(rest):
			out.append([head] + tail)
	return out


func _never() -> bool:
	return false


func _boot() -> Node:
	var game = Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	for i in 54:
		await physics_frame
	game.run.set_max_hp(100.0)
	game.run.hp = 100.0
	game.ctx.spawner.heft_override = 1.0
	var def: Resource = ClassDef.by_id("pylon_engineer")
	game.run.class_def = def
	game.player.fit_class(def)
	for enemy in get_nodes_in_group("enemy"):
		if not enemy.get("kind") in ["warden", "vault"]:
			enemy.queue_free()
	for i in 18:
		await physics_frame
	return game


func _place(game: Node, set: Array, rng_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var combat = game.ctx.spawner
	var player = game.player
	var ball: Vector3 = player.ball_position()
	var made := []
	_tags.clear()
	var slot := -1
	for kind in set:
		slot += 1
		var at := ball
		var enemy: Node3D
		match kind:
			"stomp":
				at = ball + Vector3(rng.randf_range(-0.2, 0.2), -1.4 - 0.1 * slot, rng.randf_range(-0.2, 0.2))
			"hit":
				at = ball + Vector3(-9.0, 0.0, 3.0 * slot)
			"pickup", "hazard":
				made.append(null)
				continue
			_:
				# Distinct distances ahead of the ball, so nearest-first is never a tie.
				at = ball + Vector3(1.4 + 0.45 * slot + rng.randf_range(0.0, 0.1), 0.0, rng.randf_range(-0.5, 0.5) + 0.25 * slot)
		enemy = combat.spawn_enemy("chaser", at)
		enemy.live = Callable(self, "_never")
		match kind:
			"heavy":
				enemy.weight = 3.0
				enemy.hp = 1000000.0
				enemy.max_hp = 1000000.0
			"kill":
				enemy.weight = 0.5
				enemy.hp = 1.0
				enemy.max_hp = 1.0
			"soft", "stomp", "hit":
				enemy.weight = 0.5
				enemy.hp = 1000000.0
				enemy.max_hp = 1000000.0
		_tags[enemy.get_instance_id()] = "%s#%d" % [kind, slot]
		made.append(enemy)
	return made


func _label(value) -> String:
	if value is Object and is_instance_valid(value):
		return String(_tags.get(value.get_instance_id(), value.get_class()))
	return "freed"


func _plain(value):
	match typeof(value):
		TYPE_FLOAT:
			return snappedf(value, 0.0001)
		TYPE_VECTOR3:
			return "(%.3f, %.3f, %.3f)" % [value.x, value.y, value.z]
		TYPE_VECTOR2:
			return "(%.3f, %.3f)" % [value.x, value.y]
		TYPE_OBJECT:
			return _label(value)
		TYPE_ARRAY:
			return value.map(func(item): return _plain(item))
		TYPE_DICTIONARY:
			var out := {}
			var keys: Array = value.keys()
			keys.sort_custom(func(a, b): return str(a) < str(b))
			for key in keys:
				var shown = _tags.get(key, key) if typeof(key) == TYPE_INT else key
				out[str(shown)] = _plain(value[key])
			return out
		TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return null
		_:
			return value


# Every script variable of `object`, as plain values keyed "<prefix>.<name>".
func _dump(prefix: String, object: Object, into: Dictionary) -> void:
	if object == null or not is_instance_valid(object):
		into[prefix] = "freed"
		return
	for info in object.get_property_list():
		if not (info["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var name: String = info["name"]
		var value = object.get(name)
		if value is Object and not (value is Node3D):
			continue
		into["%s.%s" % [prefix, name]] = _plain(value)


func _record_signals(source: Object, prefix: String, log: Array) -> void:
	for info in source.get_signal_list():
		var name: String = info["name"]
		if ClassDB.class_has_signal(source.get_class(), name):
			continue
		var arity: int = info["args"].size()
		var tag := "%s.%s" % [prefix, name]
		var note := func(args: Array): log.append([tag, _plain(args)])
		match arity:
			0: source.connect(name, func(): note.call([]))
			1: source.connect(name, func(a): note.call([a]))
			2: source.connect(name, func(a, b): note.call([a, b]))
			3: source.connect(name, func(a, b, c): note.call([a, b, c]))
			4: source.connect(name, func(a, b, c, d): note.call([a, b, c, d]))
			_: source.connect(name, func(a, b, c, d, e): note.call([a, b, c, d, e]))


func _snapshot(game: Node, made: Array, log: Array) -> Dictionary:
	var out := {}
	var player = game.player
	_dump("run", game.run, out)
	_dump("player", player, out)
	_dump("state", player.state, out)
	_dump("kit", player.kit, out)
	_dump("chain", player.chain, out)
	_dump("redline", player.redline, out)
	_dump("rigid", player.body(), out)
	out["ball.pending_velocity"] = _plain(player.body().get("_pending_velocity"))
	out["ball.pending_position"] = _plain(player.body().get("_pending_position"))
	out["ball.velocity"] = _plain(player.body().linear_velocity)
	for enemy in made:
		if enemy != null:
			_dump("enemy " + _label(enemy), enemy, out)
			out["enemy %s.valid" % _label(enemy)] = is_instance_valid(enemy)
			if is_instance_valid(enemy):
				out["enemy %s.is_dead" % _label(enemy)] = enemy.is_dead()
				out["enemy %s.position" % _label(enemy)] = _plain(enemy.global_position)
	# The multiset of events, as sorted lines.
	var lines := log.map(func(row): return "%s %s" % [row[0], JSON.stringify(row[1])])
	var sorted := lines.duplicate()
	sorted.sort()
	out["events (multiset)"] = sorted
	return {"state": out, "events_in_order": lines}


# One fresh game, one arrival order. `bypass` plants the control: touches told in arrival order
# with no sort.
func _order(set: Array, order: Array, bypass: bool) -> Dictionary:
	var game := await _boot()
	var made := _place(game, set, SEED)
	var player = game.player
	var ball: Node = player.body()
	var log := []
	_record_signals(game.events, "events", log)
	_record_signals(player, "player", log)
	for enemy in made:
		if enemy != null:
			_record_signals(enemy, "enemy", log)
	ball.recent_velocities.clear()
	ball.recent_velocities.append(Vector3(30.0, -1.0, 0.0))
	ball.recent_velocities.append(Vector3(2.0, -20.0, 0.0))
	player.state.velocity = Vector3(30.0, -1.0, 0.0)
	var touches := order.filter(func(slot): return set[slot] in TOUCHES)
	var fake := FakeState.new()
	fake.origin = ball.global_position
	if not bypass:
		for slot in touches:
			fake.listed.append(made[slot])
		ball.set("_touching", {})
	# The ball's own signal, one per enemy it reports: proof the sorted path ran (review, 16 Nov).
	var reported := [0]
	if not bypass:
		ball.enemy_touched.connect(func(_enemy, _normal): reported[0] += 1)
	var told := false
	for slot in order:
		match set[slot]:
			"heavy", "kill", "soft", "stomp":
				if bypass:
					player.touch_body(made[slot])
				elif not told:
					told = true
					ball.call("_note_enemies", fake)
					ball.call("_on_body_entered", made[touches[0]])
			"hit":
				made[slot].hit_player.emit(40.0, Vector3(-2.0, 0.0, 0.0))
			"pickup":
				game.run.add_scrap(7, ball.global_position)
				game.run.add_cogs(2)
			"hazard":
				game.run.damage(35.0, "hazard")
	var snap := _snapshot(game, made, log)
	snap["reported"] = reported[0]
	snap["touches"] = touches.size()
	game.queue_free()
	await physics_frame
	return snap


func _diff(a: Dictionary, b: Dictionary) -> Array:
	var out := []
	var keys := {}
	for key in a:
		keys[key] = true
	for key in b:
		keys[key] = true
	for key in keys:
		if not a.has(key) or not b.has(key) or str(a[key]) != str(b[key]):
			out.append("%s: %s vs %s" % [key, str(a.get(key, "<absent>")).left(120), str(b.get(key, "<absent>")).left(120)])
	out.sort()
	return out


# Every order of `set` against the first; returns how many orders ran and the findings.
func _all_orders(set: Array, bypass: bool, noise: Dictionary) -> Dictionary:
	var indexes := []
	for i in set.size():
		indexes.append(i)
	var orders := _permutations(indexes)
	var first := {}
	var findings := []
	var list_differs := 0
	var ran := 0
	for order in orders:
		var snap := await _order(set, order, bypass)
		ran += 1
		_runs += 1
		if not bypass and snap["reported"] != snap["touches"]:
			findings.append([order, ["the ball reported %d of %d touches" % [snap["reported"], snap["touches"]]]])
		if first.is_empty():
			first = snap
			continue
		var diff := _diff(first["state"], snap["state"]).filter(func(row): return not noise.has(row.split(":")[0]))
		if str(first["events_in_order"]) != str(snap["events_in_order"]):
			list_differs += 1
		if not diff.is_empty():
			findings.append([order, diff])
	return {"ran": ran, "expected": orders.size(), "findings": findings, "list_differs": list_differs}


func _run() -> void:
	# Noise: keys that differ between two games run through the SAME order (ids, clocks).
	var probe_set: Array = SETS[3]
	var probe_order := [0, 1, 2, 3]
	var a := await _order(probe_set, probe_order, false)
	var b := await _order(probe_set, probe_order, false)
	var noise := RENDER_ONLY.duplicate()
	for row in _diff(a["state"], b["state"]):
		noise[row.split(":")[0]] = true
	print("same order twice: %d keys differ between fresh games and are left out: %s" % [noise.size(), str(noise.keys())])
	_check("determinism: same order twice, state keys compared", a["state"].size() > 100 and noise.size() <= 8, "%d keys, %d noisy" % [a["state"].size(), noise.size()])

	var total_expected := 0
	var total_ran := 0
	for set in SETS:
		var result := await _all_orders(set, false, noise)
		total_expected += result["expected"]
		total_ran += result["ran"]
		var detail := "%d orders ran, %d differ from the first" % [result["ran"], result["findings"].size()]
		if not result["findings"].is_empty():
			var worst: Array = result["findings"][0]
			detail += "; first differing order %s, fields: %s" % [str(worst[0]), str(worst[1].slice(0, 6))]
		_check("same state: " + "+".join(set), result["findings"].is_empty() and result["ran"] == result["expected"], detail)
		print("note: %s event lists in raw order differ in %d of %d orders" % ["+".join(set), result["list_differs"], result["ran"]])
	_check("orders ran", total_ran == ORDERS_EXPECTED and total_expected == ORDERS_EXPECTED, "%d orders of %d expected (2+6+24 per set)" % [total_ran, total_expected])

	# Planted control: no sort. At least one set must show an order-dependent state.
	var control_hits := 0
	var control_ran := 0
	for set in CONTROL_SETS:
		var result := await _all_orders(set, true, noise)
		control_ran += result["ran"]
		control_hits += result["findings"].size()
		print("control (no sort) %s: %d of %d orders differ; e.g. %s" % ["+".join(set), result["findings"].size(), result["ran"], str(result["findings"][0] if not result["findings"].is_empty() else [])])
	_check("planted control fails the comparison", control_ran > 0 and control_hits > 0, "%d of %d unsorted orders differ" % [control_hits, control_ran])

	# A real, documented dependence the comparison must be able to see.
	var known := await _all_orders(KNOWN_PAIR, false, noise)
	var named: String = known["findings"][0][1][0] if not known["findings"].is_empty() else "none"
	_check("known dependence seen: pickup then hazard", known["ran"] == 2 and not known["findings"].is_empty() and str(known["findings"][0][1]).contains("run.hp"), "differs in %s" % named.left(80))

	print("contact_orders_all_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures > 0 else 0)
