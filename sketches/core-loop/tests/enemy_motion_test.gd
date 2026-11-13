extends SceneTree

# GP6: every roster kind idles between attacks and breaks apart when it dies, from one
# WindupRows row. The idle moves the model pivot only and stops for the wind-up; the
# scatter outlives the enemy without moving its died tick, and frees itself.
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Roster := preload("res://src/combat/roster.gd")
const WindupRows := preload("res://src/presentation/windup_rows.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const WindupPoses := preload("res://src/presentation/windup_poses.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const T := preload("res://tests/support/t.gd")
const SCENE_KINDS := ["chaser", "mag_trapper", "winch_drone"]
# Coordinator call 2026-10-18: the death range below (3 to 8 parts, 0.4 to 0.7 s) is for
# full enemy bodies. These kinds are sub-parts of another enemy, so their death is checked
# for a valid style only. Each entry names its reason.
const DEATH_SUB_PARTS := {
	"splitter_pod": "a Splitter sub-part that pops, not a full enemy body",
}
const IDLE_FRAMES := 240

var _game
var _t := T.new("enemy_motion_test")


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
	_game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _frames(3)
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()


func _spawn(kind: String, index: int):
	var enemy = _game.combat.spawn_enemy(kind, Vector3(-100.0 + 12.0 * index, 38.0, -90.0))
	enemy.hp = 100000.0
	return enemy


# Coordinator call 2026-10-18: a closed roster pose may live on the enemy's own body (its
# `_pose` read, WIRE-OR-CUT.md) instead of in WindupPoses. The body counts only if its
# behaviour script overrides `_pose` with real work, or names the pose id where it draws it
# (prop_crew.gd's e31_prop_kicked). An inherited or empty `_pose` does not count, so a row
# whose pose neither WindupPoses nor its body provides still fails.
func _body_owns_pose(owner: String, pose: String) -> bool:
	var path := String(Roster.ROWS.get(owner, {}).get("script", "res://src/combat/%s.gd" % owner))
	# 2026-10-23: the rogue fleet machines share one script (combat/rogue.gd).
	if owner.begins_with("rogue_"):
		path = "res://src/combat/rogue.gd"
	if not FileAccess.file_exists(path):
		return false
	var source := FileAccess.get_file_as_string(path)
	if source.contains(pose):
		return true
	var at := source.find("\nfunc _pose(")
	if at < 0:
		return false
	var body_start := source.find("\n", at + 1)
	var next_func := source.find("\nfunc ", body_start)
	var body := source.substr(body_start, (next_func if next_func >= 0 else source.length()) - body_start)
	for line in body.split("\n"):
		var code := line.strip_edges()
		if code != "" and not code.begins_with("#") and code != "pass":
			return true
	return false


# GP6-1: the ranges are the brief's, written here and not read from EnemyMotion.
func _rows() -> void:
	# 2026-10-23: plus one row per rogue fleet machine (combat/rogue.gd ROWS).
	_t.eq("every roster kind has a row", WindupRows.ROWS.size(), Roster.ROWS.size() + 3)
	for kind in WindupRows.ROWS:
		var spec: Dictionary = WindupRows.ROWS[kind]
		var idle = spec.get("idle")
		var idle_ok: bool = idle is Dictionary and String(idle.get("style", "")) in ["bob", "sway", "breathe", "hover", "tick"] \
			and (idle.get("amplitude") is float) and float(idle.amplitude) >= 0.02 and float(idle.amplitude) <= 0.08 \
			and (idle.get("beats") is float or idle.get("beats") is int) and float(idle.beats) > 0.0
		_t.check("GP6-1 idle " + kind, idle_ok, str(idle))
		var death = spec.get("death")
		var style_ok: bool = death is Dictionary and String(death.get("style", "")) in ["scatter", "collapse", "spin_down", "pop"] \
			and death.get("parts") is int and death.get("seconds") is float
		var death_ok: bool = style_ok and (DEATH_SUB_PARTS.has(kind) or (int(death.parts) >= 3 and int(death.parts) <= 8 \
			and float(death.seconds) >= 0.4 and float(death.seconds) <= 0.7))
		_t.check("GP6-1 death " + kind, death_ok, str(death) + ("" if not DEATH_SUB_PARTS.has(kind) else " (full-body range exempt: %s)" % DEATH_SUB_PARTS[kind]))
	_t.check("GP6-1 vault", WindupRows.ROWS.vault.idle.style == "tick" and WindupRows.ROWS.vault.death.style == "collapse", "vault ticks and collapses")
	# Every concrete roster attack pose has a whole-body pose, and nothing names a pose no row has.
	var named := {}
	var missing: Array = []
	for id in EventKinds.ATTACK_ROWS:
		var attack: Dictionary = EventKinds.ATTACK_ROWS[id]
		named[attack["pose"]] = true
		var own_rig: bool = not WindupRows.ROWS.get(attack["owner"], {}).get("pose", {}).is_empty()
		if attack["group"] == "enemy" and not attack["open"].has("pose") and not own_rig and not WindupPoses.has_pose(attack["pose"]) \
				and not _body_owns_pose(String(attack["owner"]), String(attack["pose"])):
			missing.append(attack["pose"])
	var stray: Array = WindupPoses.POSES.keys().filter(func(k): return not named.has(k))
	_t.check("GP6-1 roster wind-up poses", missing.is_empty() and stray.is_empty(), "missing %s, stray %s" % [missing, stray])
	_t.check("GP6-1 swarm pose", EnemyMotion.pose_basis(WindupRows.ROWS.swarm_remnant) != Basis.IDENTITY
		and EnemyMotion.pose_basis(WindupRows.ROWS.chaser) == Basis.IDENTITY, "only the swarm remnant's row carries a wind-up pose")
	GraphicsPreset.current = "low"
	var low := EnemyMotion.part_count(WindupRows.ROWS.miniboss.death)
	GraphicsPreset.current = "high"
	_t.check("GP6-1 low preset budget", low == EnemyMotion.LOW_PART_CAP and EnemyMotion.part_count(WindupRows.ROWS.miniboss.death) == 8, "low %d, high 8" % low)


func _shapes(enemy) -> Array:
	var out: Array = []
	for child in enemy.get_children():
		if child is CollisionShape3D:
			out.append(child.transform)
	return out


# GP6-2: the idle moves the pivot inside the row's amplitude (beside a walking kind's gait), the colliders never move, and every
# frame with an open attack has a zero idle offset.
func _idle_scene() -> void:
	var enemies: Array = []
	for i in SCENE_KINDS.size():
		enemies.append(_spawn(SCENE_KINDS[i], i))
	await _frames(2)
	var shapes: Array = enemies.map(func(e): return _shapes(e))
	var peaks := [0.0, 0.0, 0.0]
	var inside := [true, true, true]
	var windup_zero := true
	var windup_frames := 0
	var lean := 0.0
	var released := false
	for frame in IDLE_FRAMES:
		if frame == IDLE_FRAMES / 2:
			enemies[0]._begin_windup(Vector3.FORWARD)
		await physics_frame
		for i in enemies.size():
			var enemy = enemies[i]
			var origin: Vector3 = enemy.reaction_pivot.transform.origin
			var turned: float = enemy.reaction_pivot.transform.basis.get_rotation_quaternion().angle_to(Quaternion.IDENTITY)
			if enemy.winding_up():
				windup_frames += 1
				# The offset fades over IDLE_FADE_OUT (never up), then holds at zero.
				var faded: bool = windup_frames > 20
				windup_zero = windup_zero and (not faded or (origin == Vector3.ZERO and enemy.idle_offset == Vector3.ZERO)) and origin.length() <= float(WindupRows.ROWS[SCENE_KINDS[i]].idle.amplitude) + 0.0001
				if i == 0:
					lean = maxf(lean, turned)
			elif i == 0 and windup_frames > 0 and turned > 0.01:
				released = true
			else:
				# A walking kind's pivot also carries its gait (enemy_gait_test), so read its idle's own offset.
				var idle: Vector3 = enemy.idle_offset if enemy._gait != null else origin
				peaks[i] = maxf(peaks[i], idle.length())
				inside[i] = inside[i] and idle.length() <= float(WindupRows.ROWS[SCENE_KINDS[i]].idle.amplitude) + 0.0001
	for i in enemies.size():
		var amp := float(WindupRows.ROWS[SCENE_KINDS[i]].idle.amplitude)
		_t.check("GP6-2 idle " + SCENE_KINDS[i], inside[i] and peaks[i] > amp * 0.5, "peak %.4f m within %.3f m" % [peaks[i], amp])
		_t.check("GP6-2 collider " + SCENE_KINDS[i], _shapes(enemies[i]) == shapes[i], "collision shapes keep their local transforms")
	_t.check("GP6-2 wind-up holds", windup_zero and windup_frames > 0, "%d open-attack frames, offset faded to zero" % windup_frames)
	# ATTACK_ROWS E01 e01_brace_back: the chaser leans back into its lunge, then snaps through it.
	_t.check("GP6-2 wind-up leans into its pose", lean > deg_to_rad(8.0), "peak lean %.1f deg" % rad_to_deg(lean))
	_t.check("GP6-2 strike snaps through its release", released)
	_t.check("GP6-2 release settles to rest", enemies[0].reaction_pivot.transform.basis.is_equal_approx(Basis.IDENTITY) or enemies[0].winding_up(),
		str(enemies[0].reaction_pivot.transform.basis))
	for enemy in enemies:
		enemy.free()


func _scatter_of(parent: Node) -> Array:
	return parent.get_children().filter(func(n): return n.get_script() == EnemyMotion)


# GP6-3 and GP6-4: the killing tick emits died and queues the enemy, as before; the
# scatter has the row's pieces, lands on the floor a grounded body stood on, and is gone within
# its life (the row's seconds plus the landing rest) plus one frame.
func _death(kind: String, index: int, label: String) -> void:
	var enemy = _spawn(kind, index)
	await _frames(2)
	var parent: Node = enemy.get_parent()
	var died_frame := [-1]
	enemy.died.connect(func(_at: Vector3, _scrap: int): died_frame[0] = Engine.get_physics_frames())
	var before := _scatter_of(parent).size()
	var kill_frame := Engine.get_physics_frames()
	enemy.take_damage(enemy.hp + 1.0)
	_t.check(label + " died tick", died_frame[0] == kill_frame and enemy.is_queued_for_deletion(), "died on frame %d, killed on %d; queued for deletion" % [died_frame[0], kill_frame])
	var made := _scatter_of(parent)
	var death: Dictionary = WindupRows.ROWS[kind].death
	var scatter: Node = made[made.size() - 1] if made.size() > before else null
	_t.check(label + " pieces " + kind, scatter != null and scatter.get_child_count() == int(death.parts), "%d pieces, row %d" % [0 if scatter == null else scatter.get_child_count(), death.parts])
	if scatter == null:
		return
	var ref: WeakRef = weakref(scatter)
	# A grounded body's pieces land and rest before they go (W1-86); life() is the row's seconds plus that rest.
	var limit := ceili(float(scatter.life()) * Engine.physics_ticks_per_second) + 1
	var under := 0
	var frames := 0
	# A piece leaves by shrinking and never through the instance's transparency: a fade sends an
	# opaque surface to the blended pass, and the first piece of a look to go there made the
	# renderer build pipelines while the frame waited (enemy_motion.gd SHRINK).
	var full: float = (scatter.get_child(0) as Node3D).basis.get_scale().length()
	var sizes: Array[float] = []
	var faded := 0
	while ref.get_ref() != null and frames <= limit + 30:
		await physics_frame
		frames += 1
		var live = ref.get_ref()
		if live != null and not live.is_queued_for_deletion():
			sizes.append((live.get_child(0) as Node3D).basis.get_scale().length() / full)
			for piece in live.get_children():
				if piece is GeometryInstance3D and piece.transparency > 0.0:
					faded += 1
			for piece in live._pieces:
				var mi: Node3D = piece.node
				if mi.position.y < live.floor_at(mi, float(piece.low) * mi.basis.get_scale().x) - 0.001:
					under += 1
	_t.check(label + " freed " + kind, ref.get_ref() == null and frames <= limit, "freed after %d frames, limit %d" % [frames, limit])
	_t.check(label + " pieces never sink through the floor " + kind, under == 0, "%d piece samples under the ground" % under)
	var shrinks := sizes.size() >= 4
	for i in range(1, sizes.size()):
		shrinks = shrinks and sizes[i] <= sizes[i - 1] + 0.0001
	# Full size through the first third of its life (SHRINK starts at the half), nearly gone at the end.
	var third: float = sizes[sizes.size() / 3] if shrinks else -1.0
	_t.check(label + " pieces shrink away " + kind, shrinks and sizes[0] > 0.99 and third > 0.99 and sizes[sizes.size() - 1] < 0.2 and faded == 0,
		"first %.2f, a third in %.2f, last %.2f of full size over %d ticks; %d faded piece samples" % [sizes[0] if not sizes.is_empty() else -1.0, third, sizes[sizes.size() - 1] if not sizes.is_empty() else -1.0, sizes.size(), faded])


func _reduced() -> void:
	EnemyMotion.motion_scale = 0.0
	var enemy = _spawn("winch_drone", 5)
	var still := true
	for i in 120:
		await physics_frame
		still = still and enemy.idle_offset == Vector3.ZERO and enemy.reaction_pivot.transform.origin == Vector3.ZERO
	_t.check("GP6-4 reduced motion", still, "120 frames with zero idle offset")
	enemy.free()
	await _death("winch_drone", 6, "GP6-4")
	EnemyMotion.motion_scale = 1.0


func _run() -> void:
	_rows()
	await _boot()
	EnemyMotion.headless_idle = true
	await _idle_scene()
	await _death("chaser", 3, "GP6-3")
	await _death("mag_trapper", 4, "GP6-3")
	await _reduced()
	EnemyMotion.headless_idle = false
	quit(_t.verdict())
