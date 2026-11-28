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
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
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
	if _game != null:
		for child in _game.find_children("*", "Node3D", true, false):
			if is_instance_valid(child) and (child is EnemyMotion.ShiftOverTag or child.name.begins_with("DeathScatter")):
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
	var ring := boss.find_child("ForemanSyncRing", true, false) as MeshInstance3D
	var ring_mat := ring.material_override as StandardMaterial3D if ring != null else null
	_t.check("sync ring is an opaque shared ArrayMesh (no PrimitiveMesh)",
		ring != null and ring.mesh is ArrayMesh and not (ring.mesh is PrimitiveMesh)
		and ring_mat != null and ring_mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
		and is_equal_approx(ring_mat.albedo_color.a, 1.0))
	_t.check("before horn: nearby chasers start outside formation radius", not _all_in_formation(boss, chasers))
	# Advance to right before the horn while the ball rolls laterally to prove the horn never stuns it.
	boss.prime_horn(0.1)
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
	broken_boss.prime_horn(0.1)
	var b_horn := -1
	for tick in 180:
		_game.player.reset_to(_ball_at, Vector3.ZERO)
		await physics_frame
		if broken_boss.horns >= 1 and b_horn < 0:
			b_horn = tick
		if b_horn >= 0 and tick - b_horn >= beat_ticks:
			break
	_t.check("planted broken snap fails formation radius check", not _all_in_formation(broken_boss, broken_chasers))

	# Planted broken case 2: a real chaser held/pinned at its post-beat spot fails never-held.
	var pinned_pos := broken_chasers.map(func(c): return c.global_position)
	for tick in 45:
		_game.player.reset_to(_ball_at, Vector3.ZERO)
		broken_chasers[0].global_position = pinned_pos[0]
		broken_chasers[0].velocity = Vector3.ZERO
		await physics_frame
	var pinned_moved := []
	for i in broken_chasers.size():
		pinned_moved.append(_flat_dist(broken_chasers[i].global_position, pinned_pos[i]))
	_t.check("planted pinned chaser fails never-held check", not _crew_never_held(pinned_moved, 0),
		"pinned_moved=%s" % str(pinned_moved))
	_clear()


func _check_snap_edge_cases() -> void:
	var beat_ticks := ceili(Foreman.HORN_LEAD * Engine.physics_ticks_per_second)

	# 1. Winding-up chaser is skipped by snap, rejects rally_to, and does not bend the other chaser's arc.
	_clear()
	var boss = _game.combat.spawn_enemy("foreman", _at(0.0, 0.0, 2.0))
	boss.hp = 99999.0
	var winder = _game.combat.spawn_enemy("chaser", _at(-6.0, 18.0, 1.6))
	winder.hp = 99999.0
	var free_chaser = _game.combat.spawn_enemy("chaser", _at(11.0, -3.0, 1.6))
	free_chaser.hp = 99999.0
	var synced_lists := []
	boss.synced.connect(func(members: Array): synced_lists.append(members.duplicate()))
	var windup_seen := false
	for tick in 120:
		_game.player.reset_to(_ball_at, Vector3.ZERO)
		await physics_frame
		if winder.winding_up():
			windup_seen = true
			break
	_t.check("chaser enters real wind-up near the ball", windup_seen)
	_t.check("rally_to refuses a winding-up chaser", not winder.rally_to(_at(0.0, 4.0, 1.6), 0.4))
	boss.prime_horn(0.03)
	var horn_tick := -1
	for tick in 120:
		_game.player.reset_to(_ball_at, Vector3.ZERO)
		await physics_frame
		if boss.horns >= 1 and horn_tick < 0:
			horn_tick = tick
		if horn_tick >= 0 and tick - horn_tick >= beat_ticks:
			break
	_t.check("snap skips winding-up chaser and syncs only the free chaser",
		synced_lists.size() == 1 and winder not in synced_lists[0] and free_chaser in synced_lists[0],
		"synced=%d" % (synced_lists[0].size() if synced_lists.size() == 1 else -1))
	var forward := Vector3(_ball_at.x - boss.global_position.x, 0.0, _ball_at.z - boss.global_position.z).normalized()
	var to_free := Vector3(free_chaser.global_position.x - boss.global_position.x, 0.0, free_chaser.global_position.z - boss.global_position.z).normalized()
	_t.check("skipped winding-up chaser does not bend remaining chaser's center slot",
		to_free.dot(forward) > 0.9, "dot=%.3f" % to_free.dot(forward))

	# 2. Knocked-back chaser is skipped by snap, and light knock still ticks _rally_left down.
	_clear()
	var kboss = _game.combat.spawn_enemy("foreman", _at(0.0, 0.0, 2.0))
	kboss.hp = 99999.0
	var knocked = _game.combat.spawn_enemy("chaser", _at(-10.0, -3.0, 1.6))
	knocked.hp = 99999.0
	var ready = _game.combat.spawn_enemy("chaser", _at(10.0, -3.0, 1.6))
	ready.hp = 99999.0
	var ksync := []
	kboss.synced.connect(func(members: Array): ksync.append(members.duplicate()))
	await _frames(15)
	knocked.knock(Vector3.RIGHT, 12.0)
	_t.check("rally_to refuses a knocked-back chaser", not knocked.rally_to(_at(0.0, 4.0, 1.6), 0.4))
	kboss.prime_horn(0.02)
	for tick in 30:
		_game.player.reset_to(_ball_at, Vector3.ZERO)
		await physics_frame
		if kboss.horns >= 1:
			break
	_t.check("snap skips knocked-back chaser and syncs the ready chaser",
		ksync.size() == 1 and knocked not in ksync[0] and ready in ksync[0] and not knocked.is_rallying())

	# Light knock (between 1.0 and RALLY_INTERRUPT_KNOCK) must count _rally_left down instead of freezing it.
	_clear()
	var light_c = _game.combat.spawn_enemy("chaser", _at(-12.0, -4.0, 1.6))
	light_c.hp = 99999.0
	await _frames(15)
	var accepted: bool = light_c.rally_to(_at(14.0, -4.0, 1.6), 0.25)
	for tick in 32:
		_game.player.reset_to(_ball_at, Vector3.ZERO)
		if tick % 4 == 0:
			light_c.knock(Vector3.RIGHT, 3.0)
		await physics_frame
	_t.check("light knock does not freeze rally timer into a late sprint", accepted and not light_c.is_rallying())

	# 3. Shift Boss dying mid-beat cancels crew rally.
	_clear()
	var dboss = _game.combat.spawn_enemy("foreman", _at(0.0, 0.0, 2.0))
	var dcrew := [_game.combat.spawn_enemy("chaser", _at(-13.0, -3.0, 1.6)), _game.combat.spawn_enemy("chaser", _at(13.0, -3.0, 1.6))]
	for c in dcrew:
		c.hp = 99999.0
	await _frames(6)
	dboss.prime_horn(0.03)
	for tick in 30:
		_game.player.reset_to(_ball_at, Vector3.ZERO)
		await physics_frame
		if dboss.horns >= 1:
			break
	var rallying_before_die := dcrew.all(func(c): return c.is_rallying())
	dboss.take_damage(1.0e6)
	_t.check("Shift Boss dying mid-beat cancels crew rally", rallying_before_die and dcrew.all(func(c): return not c.is_rallying()))

	# 4. Shift Boss freed mid-beat (_exit_tree) cancels crew rally too.
	_clear()
	var fboss = _game.combat.spawn_enemy("foreman", _at(0.0, 0.0, 2.0))
	var fcrew := [_game.combat.spawn_enemy("chaser", _at(-13.0, -3.0, 1.6)), _game.combat.spawn_enemy("chaser", _at(13.0, -3.0, 1.6))]
	for c in fcrew:
		c.hp = 99999.0
	await _frames(6)
	fboss.prime_horn(0.03)
	for tick in 30:
		_game.player.reset_to(_ball_at, Vector3.ZERO)
		await physics_frame
		if fboss.horns >= 1:
			break
	var rallying_before_free := fcrew.all(func(c): return c.is_rallying())
	fboss.free()
	_t.check("Shift Boss freed mid-beat cancels crew rally",
		rallying_before_free and fcrew.all(func(c): return not c.is_rallying() and not c.has_meta("foreman")))
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
		var tag_mesh: Mesh = (meshes[0] as MeshInstance3D).mesh if meshes.size() == 1 else null
		var tag_mat := (meshes[0] as MeshInstance3D).material_override as StandardMaterial3D if meshes.size() == 1 else null
		_t.check("gag is one ArrayMesh draw with satin brass finish (no PrimitiveMesh)",
			meshes.size() == 1 and tag_mesh is ArrayMesh and not (tag_mesh is PrimitiveMesh)
			and (meshes[0] as MeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and tag_mat != null and tag_mat.has_meta("brass_finish")
			and is_equal_approx(tag_mat.roughness, PaletteMaterials.BRASS_FINISH.roughness)
			and is_equal_approx(tag_mat.metallic, PaletteMaterials.BRASS_FINISH.metallic)
			and tag_mat.vertex_color_use_as_albedo)
		# Planted broken collider on tag fails the no-collider check.
		var plant_shape := CollisionShape3D.new()
		tag.add_child(plant_shape)
		_t.check("planted collider on gag is caught", not _tag_has_no_collider(tag))
		plant_shape.free()
		# Step through flight, spin, grounded bounce, and clean self-free.
		var ref: WeakRef = weakref(tag)
		var start_basis: Basis = tag.visual_basis()
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
			if not live.visual_basis().is_equal_approx(start_basis):
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

	# Tag exemptions: non-ordinary kinds, boss pieces and ring-outs pop no tag.
	_clear()
	var probe_parent := Node3D.new()
	root.add_child(probe_parent)
	var probe := Node3D.new()
	probe_parent.add_child(probe)
	for exempt in ["vault", "warden", "miniboss", "rogue_crane", "rogue_skip", "rogue_tender", "brindle_hull"]:
		_t.check("tag exempts %s" % exempt, EnemyMotion.pop_shift_tag(probe, exempt, Vector3.RIGHT) == null)
	probe_parent.free()
	var ring_victim = _game.combat.spawn_enemy("chaser", _at(0.0, 0.0, 1.6))
	var ring_parent: Node = ring_victim.get_parent()
	ring_victim.ringed_out = true
	ring_victim.take_damage(1.0e6)
	var ring_tags := ring_parent.get_children().filter(func(n): return n is EnemyMotion.ShiftOverTag and not n.is_queued_for_deletion())
	_t.eq("ring-out pops no tag", [EnemyMotion.live_tag_count(), ring_tags.size()], [0, 0])

	# Tag cap: 20 downed machines in one tick stay within MAX_TAGS (8 default, 4 on low preset).
	_clear()
	var saved_preset := GraphicsPreset.current
	GraphicsPreset.current = "high"
	var first_tags := []
	var tag_parent: Node = null
	for i in 20:
		var c = _game.combat.spawn_enemy("chaser", _at(-10.0 + float(i % 5) * 4.0, -6.0 + float(i / 5) * 4.0, 1.6))
		tag_parent = c.get_parent()
		c.take_damage(1.0e6)
		if i == 0:
			first_tags = tag_parent.get_children().filter(func(n): return n is EnemyMotion.ShiftOverTag)
	await _frames(2)
	var live_default := tag_parent.get_children().filter(func(n): return n is EnemyMotion.ShiftOverTag and not n.is_queued_for_deletion())
	_t.eq("20 deaths in one tick cap at MAX_TAGS on default preset", [EnemyMotion.live_tag_count(), live_default.size()], [EnemyMotion.MAX_TAGS, EnemyMotion.MAX_TAGS])
	_t.check("oldest tag freed when cap hit", first_tags.size() == 1 and not is_instance_valid(first_tags[0]))

	_clear()
	GraphicsPreset.current = "low"
	for i in 20:
		var c = _game.combat.spawn_enemy("chaser", _at(-10.0 + float(i % 5) * 4.0, -6.0 + float(i / 5) * 4.0, 1.6))
		tag_parent = c.get_parent()
		c.take_damage(1.0e6)
	await _frames(2)
	var live_low := tag_parent.get_children().filter(func(n): return n is EnemyMotion.ShiftOverTag and not n.is_queued_for_deletion())
	GraphicsPreset.current = saved_preset
	_t.eq("20 deaths in one tick cap at half MAX_TAGS on low preset", [EnemyMotion.live_tag_count(), live_low.size()], [EnemyMotion.MAX_TAGS / 2, EnemyMotion.MAX_TAGS / 2])
	_clear()


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
	await _check_snap_edge_cases()
	await _check_shift_over_gag()
	_game.free()
	quit(_t.verdict())
