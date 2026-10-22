extends Node

const Warden := preload("res://src/combat/warden.gd")
const Roster := preload("res://src/combat/roster.gd")
const Arena := preload("res://src/boss/arena.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const CodexEntries := preload("res://src/boss/codex_entries.gd")

# The stand-in fight for a boss whose own fight is not written yet. The Waking (waking.gd)
# and the Mind (mind.gd) extend this file and run its fight until theirs land; test doubles
# use it directly. It answers BossContract.MODULE the way Brindle does, but the whole fight
# is one posture Warden on a flat pad: hits fill its bar, a full bar staggers it and opens
# its core, and a contact on the open core takes one of four chunks. The last chunk is the
# win. Flow builds this module itself, so setup never claims ctx.boss; flow points ctx.boss
# here only while this module's arena is the one entered.

enum { IDLE, FIGHT, DEFEATED }
const PAD_RADIUS := 36.0
const PAD_THICK := 2.0
# The ball lands this far from the Warden, rolling at it.
const ENTRY_R := 26.0
const ENTRY_LIFT := 2.0
const RESCUE_DEPTH := 10.0
# The Warden's numbers when the spawner has no warden_spec for this stage.
const FALLBACK_SPEC := {"plating": 120.0, "hp": 1200.0}

var ctx
var state := IDLE
var clock := 0.0
var pad: StaticBody3D
var warden: Node3D
# The Warden's posture as last published; the stub has no fleet to publish it for the Warden.
var _posture_seen: Array = []
# The fight's PHASE_MIN_SECONDS (Brindle's, boss_rules.gd), times the dial <boss>.phase_min_by_phase
# (a multiplier, identity 1.0): a chunk lost before its phase has lasted that many seconds holds the
# phase, and the Warden's bar fills only to warden.gd HOLD_CAP (_apply_posture asks hold_active; every hit
# still lands, none staggers) until the minimum has passed; the next contact then staggers (a bolt, or a bar
# drained in the hold, may take more). A subclass names its dial prefix in _hold_boss() and its seconds in
# _hold_minimums(); "" turns the hold off.
var _phase_started := 0.0
var _phase_open_at := 0.0
var _chunks_lost_seen := 0
# Whether the build was a monster build when the fight began (warden.gd monster_build, latched at entry).
# The hold's exemption reads this, not the live heft, which climbs with the scrap picked up in the fight.
var _entry_monster := false
# Per fight (reset at entry): seconds held, and seconds the hold was the binding constraint (from the
# first frame of a hold with the bar at the cap to its end: the build had already earned the break).
var hold_s := 0.0
var hold_bound_s := 0.0
var _hold_capped := false


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "StubBoss"
	ctx.events.stage_entered.connect(func(_stage: int, _retry: bool): exit_arena())
	ctx.events.run_started.connect(func(_class_id: String): exit_arena())
	ctx.events.flow_changed.connect(func(flow_state: String):
		if flow_state in ["title", "class_select", "summary"]:
			exit_arena())


func active() -> bool:
	return state == FIGHT


func enter_arena(entry_velocity: Vector3) -> void:
	exit_arena()
	var center := Arena.place(ctx.terrain, ctx.run.stage)
	_build_pad(center)
	warden = Warden.new()
	ctx.root.add_child(warden)
	warden.global_position = center
	warden.setup(ctx.player, self, ctx.root, Callable(ctx.flow, "in_play"), 1.0, _warden_spec())
	warden.died.connect(_on_warden_died)
	warden.set_meta("plate_name", String(_row().get("name", "Warden")))
	_posture_seen = _posture_signature()
	state = FIGHT
	clock = 0.0
	_phase_started = 0.0
	_phase_open_at = 0.0
	_chunks_lost_seen = 0
	hold_s = 0.0
	hold_bound_s = 0.0
	_hold_capped = false
	latch_monster()
	_place_ball(center, entry_velocity)
	ctx.flow.boss_active = true
	ctx.flow.boss_plating = live_plating()
	ctx.events.boss_arena_entered.emit()


func exit_arena() -> void:
	if is_instance_valid(warden):
		warden.queue_free()
	warden = null
	if is_instance_valid(pad):
		pad.collision_layer = 0
		pad.queue_free()
	pad = null
	if state != DEFEATED:
		state = IDLE


func _physics_process(delta: float) -> void:
	if active():
		clock += delta
		_hold_update()
		_hold_meter(delta)
		ctx.flow.boss_plating = live_plating()
		_publish_posture()


# The dial prefix of this boss's phase_min_by_phase ("waking", "mind"); "" means no hold.
func _hold_boss() -> String:
	return ""


# The seconds each phase must last, one per chunk (the last is unused).
func _hold_minimums() -> Array:
	return []


# Notes a chunk lost since the last look: the phase it ended began at _phase_started, and the next
# opens at the later of now and that start plus the dial's seconds for the phase just played.
func _hold_update() -> void:
	if _hold_boss() == "" or not is_instance_valid(warden):
		return
	var lost: int = BossPosture.CHUNKS - warden.chunks_left()
	if lost > _chunks_lost_seen:
		_chunks_lost_seen = lost
		var minimums := _hold_minimums()
		var minimum := 0.0
		if warden.chunks_left() > 0 and not minimums.is_empty():
			minimum = float(minimums[clampi(lost - 1, 0, minimums.size() - 1)]) * ChallengeDials.by_phase(_hold_boss() + ".phase_min_by_phase", lost)
		_phase_open_at = maxf(clock, _phase_started + minimum)
		_phase_started = _phase_open_at


func _hold_meter(delta: float) -> void:
	if not hold_active() or not is_instance_valid(warden):
		_hold_capped = false
		return
	hold_s += delta
	_hold_capped = _hold_capped or warden.posture() >= Warden.HOLD_CAP - 0.001
	if _hold_capped:
		hold_bound_s += delta


# True while held with the bar at the cap: the break waits only for the minimum.
func hold_capped() -> bool:
	return hold_active() and is_instance_valid(warden) and warden.posture() >= Warden.HOLD_CAP - 0.001


# Seconds until the held phase opens (0 when not held).
func hold_left() -> float:
	return maxf(0.0, _phase_open_at - clock) if hold_active() else 0.0


# Reads the build's monster status now and keeps it for the hold. Called at entry; tests call it after
# they set a Warden's monster_heft.
func latch_monster() -> void:
	_entry_monster = is_instance_valid(warden) and warden.monster_build()


# True while a lost chunk's phase has not yet played its minimum: the Warden is closed. A build that
# was a monster build at entry (latch_monster) is never held, so an overpowered build still breaks the
# fight faster than an ordinary one; an ordinary build stays held however much heft it picks up.
func hold_active() -> bool:
	_hold_update()
	return clock < _phase_open_at and not _entry_monster


# The chunks the fight reads as left: a held chunk still counts, so the phase, the floor and the
# attacks wait for the minimum. Identical to warden.chunks_left() when nothing is held.
func shown_chunks_left() -> int:
	return warden.chunks_left() + (1 if hold_active() else 0)


# A stage Warden publishes posture_changed and weak_point_opened through its fleet; the
# stub's has none, so the stub does it on the same signature, as Brindle does for his hull.
# That is what the ring, the stagger chord and the plate's redraw listen for. The run log
# ignores it because the arena is open (run_log's _in_arena).
func _publish_posture() -> void:
	if not is_instance_valid(warden) or not warden.has_method("posture"):
		return
	var now := _posture_signature()
	if now == _posture_seen:
		return
	var opened: bool = warden.staggered() and not _posture_seen[1]
	_posture_seen = now
	ctx.events.posture_changed.emit(warden, warden.posture(), warden.staggered())
	if opened:
		ctx.events.weak_point_opened.emit(warden.family_point(), warden.family_point_at(), BossPosture.STAGGER_SECONDS)


func _posture_signature() -> Array:
	if not is_instance_valid(warden) or not warden.has_method("posture"):
		return [0, false, BossPosture.CHUNKS, false]
	return [floori(warden.posture()), warden.staggered(), warden.chunks_left(), warden.chunk_cracked()]


# The boss row this fight names and narrates: the current world's row as flow reads it. A
# boss that extends the stub answers its own Worlds.BOSSES row instead.
func _row() -> Dictionary:
	return ctx.flow.boss_row(ctx.stages.world_of(ctx.run.stage))


func _warden_spec() -> Dictionary:
	var spec: Dictionary = FALLBACK_SPEC.duplicate()
	if ctx.spawner != null and ctx.spawner.has_method("warden_spec"):
		spec = ctx.spawner.warden_spec(ctx.run.stage).duplicate()
	spec["stage"] = ctx.run.stage
	spec["fight"] = "posture"
	spec["lesson"] = "plate"
	spec["family"] = Roster.REACTOR
	spec["reach"] = PAD_RADIUS
	# The arena Warden has no fleet, so it reads the pilot's heft from here (Warden.pilot_heft).
	if _hold_boss() != "":
		spec["posture_hold"] = Callable(self, "hold_active")
	spec["heft"] = func() -> float: return float(ctx.run.heft()) if ctx != null and ctx.run != null else 0.0
	return spec


func _build_pad(center: Vector3) -> void:
	pad = StaticBody3D.new()
	pad.name = "StubBossPad"
	pad.collision_layer = 1
	pad.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = PAD_RADIUS
	cylinder.height = PAD_THICK
	shape.shape = cylinder
	pad.add_child(shape)
	var mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = PAD_RADIUS
	disc.bottom_radius = PAD_RADIUS
	disc.height = PAD_THICK
	mesh.mesh = disc
	pad.add_child(mesh)
	ctx.root.add_child(pad)
	pad.global_position = center - Vector3.UP * PAD_THICK * 0.5


func _place_ball(center: Vector3, entry_velocity: Vector3) -> void:
	var at := center + Vector3(0.0, ENTRY_LIFT, ENTRY_R)
	var heading := Vector3.FORWARD
	var flat := maxf(Vector2(entry_velocity.x, entry_velocity.z).length(), ctx.tuning.f("cruise"))
	ctx.player.reset_to(at, heading * flat)
	ctx.player.body().global_position = at
	if ctx.camera != null and ctx.camera.has_method("snap"):
		ctx.camera.snap(heading)


func _on_warden_died(_at: Vector3, _scrap: int) -> void:
	if state != FIGHT:
		return
	state = DEFEATED
	warden = null
	ctx.flow.boss_active = false
	ctx.events.boss_defeated.emit()


func _discover(id: String, at: Vector3) -> void:
	if ctx.codex != null and ctx.codex.has_method("mark_discovered"):
		ctx.codex.mark_discovered(id, at)


# --- The terrain the Warden stands on, and combat's arena ground -----------------------

func _top() -> float:
	return pad.global_position.y + PAD_THICK * 0.5 if is_instance_valid(pad) else -INF


func height(x: float, z: float) -> float:
	return ground_height_at(Vector3(x, 0.0, z))


func drop_point(x: float, z: float, clearance := 1.8) -> Vector3:
	return Vector3(x, height(x, z) + clearance, z)


func ground_height_at(point: Vector3) -> float:
	if is_instance_valid(pad):
		return _top()
	if ctx.terrain != null and ctx.terrain.has_method("height"):
		return ctx.terrain.height(point.x, point.z)
	return point.y


# --- Flow's arena rescue and the HUD's live read ----------------------------------------

func floor_y() -> float:
	return _top() - RESCUE_DEPTH


func rescue_point(near = null) -> Vector3:
	var from: Vector3 = near if near is Vector3 else ctx.player.ball_position()
	if not is_instance_valid(pad):
		return from
	var center := pad.global_position
	var flat := Vector2(from.x - center.x, from.z - center.z)
	flat = flat.normalized() * ENTRY_R if flat.length() > 0.01 else Vector2(0.0, ENTRY_R)
	return Vector3(center.x + flat.x, _top() + ENTRY_LIFT, center.z + flat.y)


func live_plating() -> float:
	if not is_instance_valid(warden) or warden.staggered():
		return 0.0
	return warden.plating_now()


func music_state() -> Dictionary:
	if not active() or not is_instance_valid(warden):
		return {}
	return {
		"in_phase": 1.0 if warden.staggered() else clampf(warden.posture() / 100.0, 0.0, 1.0),
		"held": false,
		"phase_seconds": 0.0,
	}


func objective_text() -> String:
	var row := _row()
	var who := String(row.get("name", "the boss"))
	match state:
		DEFEATED:
			return String(row.get("victory", "%s is down." % who))
		FIGHT:
			if is_instance_valid(warden) and warden.staggered():
				return "%s is staggered: hit its open core." % who
			var chunks: int = warden.chunks_left() if is_instance_valid(warden) else 0
			return "Fill %s's bar to stagger it. %d chunks left." % [who, chunks]
	return ""
