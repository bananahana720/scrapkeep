extends SceneTree

# W46-11 crews with character:
# 1. The Shift Boss's horn ("Quick sync.") snaps nearby chasers within FORMATION_RADIUS one beat
#    after the horn, never stuns or holds the ball, never holds the crew in place, and uses an
#    existing sound id with a recipe (foreman_tell).
# 2. A downed machine pops a "shift over" spinning brass tag with a grounded bounce, no gore, no
#    words, no collider and no gameplay clock read.
# 3. The lock rings (lock_rows.gd) keep asking a jump and a carve/fling with no plated or trapping
#    holding kind.
# 4. Planted broken cases fail every check.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const Foreman := preload("res://src/combat/foreman.gd")
const SpecialCues := preload("res://src/combat/special_cues.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const Roster := preload("res://src/combat/roster.gd")
const LockRows := preload("res://src/world/lock_rows.gd")
const T := preload("res://tests/support/t.gd")

const PLATED_KINDS := ["plated_brute", "miniboss", "drill_crew", "mind_hand", "vault", "warden"]
# ramp_flipper flings a slow ball and never traps it (W1-65, lock_rows.gd:19-22, stage_locks_test.gd:124-127).
const FLING_ONLY_KINDS := ["ramp_flipper"]
const CLOCK_TOKENS := ["SimClock", "Time.get_", "Engine.get_physics_frames", "run.seconds", "AttackBudget", "ctx.flow", "ctx.run"]

var _game
var _t := T.new("foreman_sync_test")
var _centre := Vector3.ZERO
var _ball_at := Vector3.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _boot() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.ctx.rng.seed = 11
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _frames(6)
	_clear()
	var beacon: Vector3 = _game.flow.beacon.global_position
	_centre = _game.ctx.terrain.drop_point(beacon.x, beacon.z - 125.0, 0.0)
	_ball_at = _game.ctx.terrain.drop_point(_centre.x, _centre.z + 24.0, 1.05)
	_game.player.reset_to(_ball_at, Vector3.ZERO)


func _clear() -> void:
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()
	if _game != null and _game.combat != null:
		for child in _game.combat.get_children():
			if child.name.begins_with(EnemyMotion.TAG_NAME) or child.name.begins_with("DeathScatter"):
				child.free()
	if root.has_meta(AttackBudget.LAST_META):
		root.remove_meta(AttackBudget.LAST_META)


func _at(dx: float, dz: float, lift := 1.8) -> Vector3:
	return _game.ctx.terrain.drop_point(_centre.x + dx, _centre.z + dz, lift)


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _all_in_formation(boss: Node3D, members: Array) -> bool:
	if members.is_empty():
		return false
	for m in members:
		if not is_instance_valid(m) or _flat_dist(m.global_position, boss.global_position) > Foreman.FORMATION_RADIUS:
			return false
	return true


static func _crew_never_held(post_displacements: Array, stuck_ticks: int) -> bool:
	if post_displacements.is_empty() or stuck_ticks > 0:
		return false
	for moved in post_displacements:
		if float(moved) < 1.0:
			return false
	return true


static func _tag_has_no_collider(tag: Node) -> bool:
	if tag == null:
		return false
	if tag is CollisionObject3D or tag is CollisionShape3D:
		return false
	return tag.find_children("*", "CollisionShape3D", true, false).is_empty() \
		and tag.find_children("*", "CollisionObject3D", true, false).is_empty()


static func _tag_has_no_words(tag: Node) -> bool:
	if tag == null:
		return false
	return tag.find_children("*", "Label3D", true, false).is_empty()


static func _tag_reads_no_game_clock(source: String) -> bool:
	for token in CLOCK_TOKENS:
		if source.contains(token):
			return false
	return true


static func _lock_waves_clean(waves: Array) -> bool:
	for wave in waves:
		for kind in wave:
			var id := String(kind)
			if id in PLATED_KINDS:
				return false
			var row: Dictionary = Roster.row(id)
			if bool(row.get("holds", false)) and id not in FLING_ONLY_KINDS:
				return false
	return true


func _check_horn_sound() -> void:
	var cue := SpecialCues.sound("foreman", SpecialCues.TELL)
	_t.eq("horn uses foreman_tell sound id", cue, "foreman_tell")
	_t.check("horn sound id has a recipe and plays its own sound", SfxBank.has_recipe(cue) and SfxBank.plays_own(cue), cue)


func _check_horn_snap_and_motion() -> void:
	_clear()
	var boss = _game.combat.spawn_enemy("foreman", _at(0.0, 0.0, 2.0))
	var offsets := [Vector3(-13.0, 0.0, -4.0), Vector3(13.5, 0.0, -3.0), Vector3(-1.5, 0.0, -12.0)]
	var chasers: Array = []
	for off in offsets:
		var c = _game.combat.spawn_enemy("chaser", _at(off.x, off.z, 1.6))
		c.hp = 99999.0
		chasers.append(c)
	var stranger = _game.combat.spawn_enemy("chaser", _at(-55.0, 0.0, 1.6))
	stranger.hp = 99999.0
	boss.hp = 99999.0
	var snapped := []
	boss.synced.connect(func(members: Array): snapped.append(members.duplicate()))
	await _frames(3)
	_t.check("before horn: nearby chasers start outside formation radius", not _all_in_formation(boss, chasers))
	# Advance to right before the horn while the ball rolls laterally to prove the horn never stuns it.
	boss._clock = Foreman.WIPE_EVERY - Foreman.HORN_LEAD - 0.1
	var horn_tick := -1
	var beat_ticks := ceili(Foreman.HORN_LEAD * Engine.physics_ticks_per_second)
	var ball_vel_before := Vector3(14.0, 0.0, 0.0)
	var ball_held := false
	var ball_stunned := false
	var stuck_ticks := 0
	for tick in 180:
		if horn_tick < 0:
			_game.player.reset_to(_ball_at, ball_vel_before)
		await physics_frame
		if boss.horns >= 1 and horn_tick < 0:
			horn_tick = tick
			var speed_after: float = Vector2(_game.player.state.velocity.x, _game.player.state.velocity.z).length()
			ball_stunned = speed_after < 10.0
			ball_held = not _game.combat.fleet.holds.active.is_empty()
		if horn_tick >= 0:
			var elapsed := tick - horn_tick
			# While rallying, chasers must actively move toward their slots (never pinned at 0 speed).
			for c in chasers:
				if c.is_rallying() and Vector2(c.velocity.x, c.velocity.z).length() < 1.0:
					stuck_ticks += 1
			if elapsed >= beat_ticks:
				break
	_t.eq("horn fired once and synced the three nearby chasers", [boss.horns, boss.syncs, snapped.size()], [1, 1, 1])
	_t.check("stranger far off was not synced", snapped.size() == 1 and stranger not in snapped[0])
	_t.check("horn snap does not stun or hold the ball", not ball_stunned and not ball_held)
	var dists := chasers.map(func(c): return snappedf(_flat_dist(c.global_position, boss.global_position), 0.01))
	_t.check("crew is within formation radius one beat after the horn", _all_in_formation(boss, chasers),
		"dists=%s limit=%.1f" % [str(dists), Foreman.FORMATION_RADIUS])
	_t.check("rally finishes by the beat so crew is not held in place", chasers.all(func(c): return not c.is_rallying()))
	# Keep running past the beat and confirm every chaser keeps moving/chasing toward the ball.
	var after_beat_pos := chasers.map(func(c): return c.global_position)
	_game.player.reset_to(_ball_at, Vector3.ZERO)
	await _frames(45)
	var post_moved := []
	for i in chasers.size():
		post_moved.append(_flat_dist(chasers[i].global_position, after_beat_pos[i]))
	_t.check("crew keeps moving after the formation snap (never held in place)", _crew_never_held(post_moved, stuck_ticks),
		"post_moved=%s stuck_ticks=%d" % [str(post_moved), stuck_ticks])

	# Planted broken case 1: cancelling the rally breaks the formation check.
	_clear()
	var broken_boss = _game.combat.spawn_enemy("foreman", _at(0.0, 0.0, 2.0))
	var broken_chasers: Array = []
	for off in offsets:
		var bc = _game.combat.spawn_enemy("chaser", _at(off.x, off.z, 1.6))
		bc.hp = 99999.0
		broken_chasers.append(bc)
	broken_boss.synced.connect(func(members: Array):
		for m in members:
			m.cancel_rally())
	await _frames(3)
	broken_boss._clock = Foreman.WIPE_EVERY - Foreman.HORN_LEAD - 0.1
	var b_horn := -1
	for tick in 180:
		_game.player.reset_to(_ball_at, Vector3.ZERO)
		await physics_frame
		if broken_boss.horns >= 1 and b_horn < 0:
			b_horn = tick
		if b_horn >= 0 and tick - b_horn >= beat_ticks:
			break
	_t.check("planted broken snap fails formation radius check", not _all_in_formation(broken_boss, broken_chasers))
	_t.check("planted stuck crew fails never-held check", not _crew_never_held([0.0, 0.0, 0.0], 5))
	_clear()


func _check_shift_over_gag() -> void:
	_clear()
	var victim = _game.combat.spawn_enemy("chaser", _at(0.0, 0.0, 1.6))
	await _frames(15)
	var parent: Node = victim.get_parent()
	var died_frame := [-1]
	victim.died.connect(func(_at_pos: Vector3, _scrap: int): died_frame[0] = Engine.get_physics_frames())
	var kill_frame := Engine.get_physics_frames()
	victim.take_damage(1.0e6)
	_t.check("gag does not shift died signal tick", died_frame[0] == kill_frame)
	var tags := parent.get_children().filter(func(n): return n.name.begins_with(EnemyMotion.TAG_NAME))
	_t.eq("downed machine pops one spinning brass tag", tags.size(), 1)
	if tags.size() == 1:
		var tag: Node3D = tags[0]
		_t.check("gag adds no collider", _tag_has_no_collider(tag))
		_t.check("gag adds no floating words (ruling cx)", _tag_has_no_words(tag))
		_t.check("gag is separate from DeathScatter script", tag.get_script() != EnemyMotion)
		var meshes := tag.find_children("*", "MeshInstance3D", true, false)
		_t.check("gag meshes disable shadow casting", not meshes.is_empty() and meshes.all(func(m: MeshInstance3D): return m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
		# Planted broken collider on tag fails the no-collider check.
		var plant_shape := CollisionShape3D.new()
		tag.add_child(plant_shape)
		_t.check("planted collider on gag is caught", not _tag_has_no_collider(tag))
		plant_shape.free()
		# Step through flight, spin, grounded bounce, and clean self-free.
		var ref: WeakRef = weakref(tag)
		var start_basis: Basis = tag._visual.basis
		var spun := false
		var peaked := false
		var start_y := tag.global_position.y
		var under := 0
		var max_bounces := 0
		var faded := 0
		var limit := ceili(tag.life() * Engine.physics_ticks_per_second) + 2
		var frames := 0
		while ref.get_ref() != null and frames <= limit + 30:
			await physics_frame
			frames += 1
			var live = ref.get_ref()
			if live == null or live.is_queued_for_deletion():
				continue
			if not live._visual.basis.is_equal_approx(start_basis):
				spun = true
			if live.global_position.y > start_y + 0.5:
				peaked = true
			if live.global_position.y < live.floor_y() - 0.001 and live.velocity.y <= 0.0:
				under += 1
			max_bounces = maxi(max_bounces, int(live.bounces))
			for m in live.find_children("*", "GeometryInstance3D", true, false):
				if m.transparency > 0.0:
					faded += 1
		_t.check("brass tag pops up, spins and bounces on the ground", peaked and spun and max_bounces >= 1,
			"peaked=%s spun=%s bounces=%d" % [peaked, spun, max_bounces])
		_t.check("brass tag never sinks under floor and never fades transparency", under == 0 and faded == 0,
			"under=%d faded=%d" % [under, faded])
		_t.check("brass tag frees itself on time", ref.get_ref() == null and frames <= limit,
			"freed after %d frames, limit %d" % [frames, limit])

	# Static + isolated check: ShiftOverTag and pop_shift_tag read no gameplay clock.
	var src := FileAccess.get_file_as_string("res://src/presentation/enemy_motion.gd")
	var start_idx := src.find("class ShiftOverTag")
	var end_idx := src.find("static func active()")
	var gag_src := src.substr(start_idx, (end_idx - start_idx) if end_idx > start_idx else src.length() - start_idx)
	_t.check("gag source reads no gameplay clock", start_idx > 0 and _tag_reads_no_game_clock(gag_src))
	_t.check("planted gameplay clock read is caught", not _tag_reads_no_game_clock(gag_src + "\nvar _x = SimClock.now()"))

	# Isolated bounce with no Game/RunState clock: proves pure delta-driven presentation.
	var bare := Node3D.new()
	root.add_child(bare)
	var dummy := Node3D.new()
	bare.add_child(dummy)
	dummy.global_position = Vector3(0.0, 1.0, 0.0)
	var iso = EnemyMotion.pop_shift_tag(dummy, "chaser", Vector3.RIGHT, func(_x: float, _z: float) -> float: return 0.0)
	var iso_ref: WeakRef = weakref(iso)
	var iso_bounces := 0
	for i in 120:
		await physics_frame
		var live = iso_ref.get_ref()
		if live != null and not live.is_queued_for_deletion():
			iso_bounces = maxi(iso_bounces, int(live.bounces))
	_t.check("isolated gag bounces on delta alone without any gameplay clock", iso != null and iso_bounces >= 1, "bounces=%d" % iso_bounces)
	bare.free()


func _check_lock_rows() -> void:
	for map in ["park_dam", "park_flume"]:
		var waves: Array = LockRows.row(map).get("lock", {}).get("waves", [])
		_t.check("%s lock waves have no plated or trapping holding kind" % map, _lock_waves_clean(waves), str(waves))
		var flat: Array = []
		for wave in waves:
			flat.append_array(wave)
		_t.check("%s lock rings ask a jump (jolt_layer) and a carve/fling (ramp_flipper)" % map,
			"jolt_layer" in flat and "ramp_flipper" in flat, str(flat))
	# Planted broken lock rows fail the rule check.
	_t.check("planted plated kind in lock wave fails", not _lock_waves_clean([["chaser", "plated_brute"]]))
	_t.check("planted holding kind in lock wave fails", not _lock_waves_clean([["chaser", "mag_trapper"]]))
	_t.check("planted boom_tender in lock wave fails", not _lock_waves_clean([["chaser", "boom_tender"]]))


func _run() -> void:
	_check_horn_sound()
	_check_lock_rows()
	await _boot()
	await _check_horn_snap_and_motion()
	await _check_shift_over_gag()
	_game.free()
	quit(_t.verdict())
