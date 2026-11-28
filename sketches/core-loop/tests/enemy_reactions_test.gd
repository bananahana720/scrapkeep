extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const BossTarget := preload("res://src/boss/boss_target.gd")
const KINDS := ["chaser", "lobber", "mag_trapper", "winch_drone", "deflector", "plated_brute"]
const T := preload("res://tests/support/t.gd")
const ReactRows := preload("res://tests/unit/react_rows_case.gd")

const GUN_FRAMES := 18
const RAM_FRAMES := 90
const LINE_FRAMES := 18
const REST_FRAMES := 27

var _game
var _t := T.new("enemy_reactions_test")


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _boot() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.ctx.rng.seed = 11
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	# The screen's real-time hit stop has separate tests; count simulation frames here.
	_game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _frames(3)
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()


func _spawn(kind: String, index: int, enabled := true):
	var enemy = _game.combat.spawn_enemy(kind, Vector3(-100.0 + 12.0 * index, 38.0, -90.0))
	enemy.hp = 100000.0
	enemy.reactions_enabled = enabled
	# Counter's handedness comes from instance-id parity, not the run's seed.
	# Pin the same handedness in both control runs to compare the visual seam alone.
	if "_strafe" in enemy:
		enemy._strafe = 1.0
	return enemy


func _hit(enemy, kind: String, impact := "") -> void:
	var row: Dictionary = EventKinds.impact(impact if impact != "" else kind)
	_game.combat.deal_hit(enemy, kind, 1.0, Vector3.RIGHT, row["knock"], "", "", impact)


func _tilt(enemy) -> float:
	return rad_to_deg(acos(clampf(enemy.reaction_pivot.basis.y.dot(Vector3.UP), -1.0, 1.0)))


func _signed_lean(enemy) -> float:
	var to: Vector3 = _game.player.ball_position() - enemy.global_position
	to.y = 0.0
	var up: Vector3 = enemy.global_basis * enemy.reaction_pivot.basis.y
	return rad_to_deg(asin(clampf(up.dot(to.normalized()), -1.0, 1.0)))


func _rest(enemy) -> bool:
	return enemy.reaction_pivot == null or enemy.reaction_pivot.transform == Transform3D.IDENTITY


func _reaction_checks() -> void:
	var enemies := []
	var gun_peaks := []
	var ram_peaks := []
	for i in KINDS.size():
		var enemy = _spawn(KINDS[i], i)
		enemies.append(enemy)
		gun_peaks.append(0.0)
		ram_peaks.append(0.0)
		_hit(enemy, "runner")
		var meshes: Array = enemy.find_children("*", "MeshInstance3D", true, false)
		var under: bool = not meshes.is_empty()
		for mesh in meshes:
			under = under and enemy.reaction_pivot.is_ancestor_of(mesh)
		var shapes: Array = enemy.find_children("*", "CollisionShape3D", true, false)
		for shape in shapes:
			under = under and shape.get_parent() == enemy
		_t.check("ER-8 " + KINDS[i], under, "%d meshes below pivot; colliders remain on body" % meshes.size())
	for frame in GUN_FRAMES:
		await physics_frame
		for i in enemies.size():
			gun_peaks[i] = maxf(gun_peaks[i], _tilt(enemies[i]))
	for i in enemies.size():
		_t.check("ER-2 gun " + KINDS[i], gun_peaks[i] > 1.0 and _rest(enemies[i]), "peak %.3f deg; identity after 18 physics frames" % gun_peaks[i])
		_hit(enemies[i], "ram")
	for frame in RAM_FRAMES:
		await physics_frame
		for i in enemies.size():
			ram_peaks[i] = maxf(ram_peaks[i], _tilt(enemies[i]))
	for i in enemies.size():
		_t.check("ER-2 ram " + KINDS[i], ram_peaks[i] > gun_peaks[i] + 0.5 and _rest(enemies[i]), "gun %.3f deg; ram %.3f deg; identity after 90 physics frames" % [gun_peaks[i], ram_peaks[i]])
	# Read the actual contact route: knock() then strike(), outside _hit().
	var contact = enemies[0]
	contact.knock(Vector3.RIGHT, EventKinds.IMPACT["ram"]["knock"])
	_game.combat.strike(contact, "ram", 1.0)
	await _frames(3)
	_t.check("ER-2 direct ram contact", _tilt(contact) > gun_peaks[0] + 0.5, "%.3f deg from strike()" % _tilt(contact))
	await _frames(RAM_FRAMES)
	for enemy in enemies:
		enemy.free()


func _lean_checks() -> void:
	for i in KINDS.size():
		var enemy = _spawn(KINDS[i], i)
		_game.events.line_state_changed.emit("latched_body", enemy, enemy.global_position, "")
		await _frames(LINE_FRAMES)
		var lean := _signed_lean(enemy)
		_t.check("ER-4 held " + KINDS[i], lean >= 6.0 and lean <= 15.0, "%.3f deg toward ball after 18 physics frames" % lean)
		_game.events.line_state_changed.emit("smash_committed", enemy, enemy.global_position, "")
		await _frames(LINE_FRAMES)
		_t.check("ER-4 brace " + KINDS[i], _signed_lean(enemy) < 0.0, "%.3f deg" % _signed_lean(enemy))
		_game.events.line_state_changed.emit("let_go", null, Vector3.ZERO, "")
		await _frames(REST_FRAMES)
		_t.check("ER-4 let_go " + KINDS[i], _rest(enemy), "identity after 27 physics frames")
		_game.events.line_state_changed.emit("latched_body", enemy, enemy.global_position, "")
		await _frames(LINE_FRAMES)
		_hit(enemy, "runner")
		await _frames(3)
		var composed: Quaternion = enemy.reaction_pivot.quaternion
		var reaction: Quaternion = enemy._react_pose
		_t.check("hit and lean compose " + KINDS[i], not composed.is_equal_approx(reaction) and enemy._line_lean == 1.0 and reaction != Quaternion.IDENTITY)
		var before: Transform3D = enemy.reaction_pivot.transform
		_hit(enemy, "ram")
		_t.check("new hit starts without snap " + KINDS[i], enemy.reaction_pivot.transform == before and enemy._react_start == reaction)
		_game.events.line_state_changed.emit("broke", null, Vector3.ZERO, "wall")
		await _frames(RAM_FRAMES)
		_game.events.line_state_changed.emit("latched_body", enemy, enemy.global_position, "")
		await _frames(LINE_FRAMES)
		_game.events.line_state_changed.emit("broke", null, Vector3.ZERO, "wall")
		await _frames(REST_FRAMES)
		_t.check("ER-4 broke " + KINDS[i], _rest(enemy), "identity after 27 physics frames")
		enemy.free()


func _trace(enabled: bool) -> Array:
	await _boot()
	var enemies := []
	var trace_kinds := KINDS + ["mind_hand"]
	for i in trace_kinds.size():
		enemies.append(_spawn(trace_kinds[i], i, enabled))
	var trace := []
	for frame in 90:
		if frame in [0, 14, 28, 50]:
			var hit: String = {0: "runner", 14: "ram", 28: "proc", 50: "overdrive"}[frame]
			for enemy in enemies:
				_hit(enemy, "runner" if hit in ["proc", "overdrive"] else hit, hit)
		if frame == 35:
			_game.events.line_state_changed.emit("latched_body", enemies[0], enemies[0].global_position, "")
		if frame == 47:
			_game.events.line_state_changed.emit("smash_committed", enemies[0], Vector3.ZERO, "")
		if frame == 59:
			_game.events.line_state_changed.emit("broke", null, Vector3.ZERO, "")
		await physics_frame
		var tick := []
		for enemy in enemies:
			var shape: CollisionShape3D = enemy.find_children("*", "CollisionShape3D", true, false)[0]
			var point: Vector3 = enemy.lens_point() if enemy.kind == "mind_hand" else Vector3.ZERO
			tick.append([enemy.global_position, enemy.velocity, shape.global_transform, shape.transform, point])
		trace.append(tick)
	_game.free()
	_game = null
	return trace


func _invariance() -> void:
	_game.free()
	_game = null
	var active := await _trace(true)
	var control := await _trace(false)
	var largest := 0.0
	var exact := true
	var lens_exact := true
	var lens_difference := 0.0
	for frame in active.size():
		for i in KINDS.size() + 1:
			var a: Array = active[frame][i]
			var b: Array = control[frame][i]
			exact = exact and a.slice(0, 4) == b.slice(0, 4)
			lens_exact = lens_exact and a[4] == b[4]
			lens_difference = maxf(lens_difference, a[4].distance_to(b[4]))
			largest = maxf(largest, a[0].distance_to(b[0]))
			largest = maxf(largest, a[1].distance_to(b[1]))
			for index in [2, 3]:
				var ta: Transform3D = a[index]
				var tb: Transform3D = b[index]
				largest = maxf(largest, ta.origin.distance_to(tb.origin))
				for axis in 3:
					largest = maxf(largest, ta.basis[axis].distance_to(tb.basis[axis]))
	_t.check("ER-3 exact physics control", exact and largest == 0.0, "seed 11; 6 slice kinds + mind hand x 90 physics frames; largest difference %.9f" % largest)
	_t.check("mind hand weak-point control", lens_exact and lens_difference == 0.0, "enabled versus disabled lens positions; largest difference %.9f" % lens_difference)
	await _boot()


func _structures() -> void:
	for kind in ["warden", "vault", "miniboss"]:
		var enemy = _spawn(kind, 7)
		for i in 20:
			_hit(enemy, ["runner", "ram", "stomp", "sticky", "proc"][i % 5])
			_game.events.line_state_changed.emit("latched_body", enemy, enemy.global_position, "")
			await physics_frame
			_t.check("ER-5 " + kind + " hit %d" % i, _rest(enemy), "identity")
		enemy.free()
	_game.boss.enter_arena(Vector3.ZERO)
	var pieces := []
	for node in get_nodes_in_group("enemy"):
		if node is BossTarget:
			pieces.append(node)
	_t.check("ER-5 real Brindle pieces exist", not pieces.is_empty(), "%d pieces" % pieces.size())
	for piece in pieces:
		for i in 20:
			_hit(piece, ["runner", "ram", "stomp", "sticky", "proc"][i % 5])
		_t.check("ER-5 " + piece.kind, not piece.has_method("react") and piece.get_node_or_null("ReactionPivot") == null, "20 mixed real combat hits; no pivot or reaction method")
	_game.free()
	_game = null
	await _boot()


func _mind_anchor() -> void:
	var hand = _spawn("mind_hand", 7)
	var peak := 0.0
	_hit(hand, "ram")
	for frame in RAM_FRAMES:
		await physics_frame
		peak = maxf(peak, _tilt(hand))
	_t.check("mind hand weak-point anchor", peak > 1.0 and hand._lens.get_parent() == hand,
		"body peak %.3f deg; lens remains on body" % peak)
	hand.free()


func _cleanup() -> void:
	var line_before: int = _game.events.line_state_changed.get_connections().size()
	var hit_before: int = _game.events.enemy_struck.get_connections().size()
	for i in 50:
		var enemy = _spawn(KINDS[i % KINDS.size()], 7)
		_hit(enemy, "ram")
		_game.events.line_state_changed.emit("latched_body", enemy, enemy.global_position, "")
		await physics_frame
		if i % 2 == 0:
			enemy.take_damage(enemy.hp + 1.0)
			await _frames(2)
		else:
			enemy.free()
	_game.events.line_state_changed.emit("broke", null, Vector3.ZERO, "")
	var line_after: int = _game.events.line_state_changed.get_connections().size()
	var hit_after: int = _game.events.enemy_struck.get_connections().size()
	_t.check("ER-6 cleanup 50 enemies", line_before == line_after and hit_before == hit_after, "line connections %d -> %d; hit connections %d -> %d" % [line_before, line_after, hit_before, hit_after])


func _run() -> void:
	_t.eq("physics frame rate", Engine.physics_ticks_per_second, 90)
	ReactRows.new().run(_t)
	await _boot()
	await _reaction_checks()
	await _lean_checks()
	await _invariance()
	await _structures()
	await _mind_anchor()
	await _cleanup()
	_game.free()
	quit(_t.verdict())
