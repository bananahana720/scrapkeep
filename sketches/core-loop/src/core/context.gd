extends RefCounted

const GameEvents := preload("res://src/core/game_events.gd")
const BuffLedger := preload("res://src/core/buff_ledger.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const RunState := preload("res://src/core/run_state.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const PlayerBall := preload("res://src/movement/player_ball.gd")
const ChaseCamera := preload("res://src/movement/chase_camera.gd")

# Everything a module may touch, handed to each module's setup(ctx). Modules talk to
# the spine and to each other only through these refs and the GameEvents bus; none
# reaches into another module's folder. CONTRACTS.md is the reading guide.

# Live active run-only temporary buffs and counters (never persisted to saves).
var buffs: BuffLedger = BuffLedger.new():
	set(value):
		if buffs != null and buffs != value:
			buffs.bind_events(null)
		buffs = value
		if buffs != null and is_instance_valid(events):
			buffs.bind_events(events)
		if is_instance_valid(player) and player.get("abilities") != null and player.abilities.has_method("bind_buffs"):
			player.abilities.bind_buffs(buffs)
var events: GameEvents:
	set(value):
		events = value
		if buffs != null:
			buffs.bind_events(value if is_instance_valid(value) else null)
var run: RunState
var tuning: Tuning
var player: PlayerBall:
	set(value):
		if is_instance_valid(player) and player != value and player.get("abilities") != null and player.abilities.has_method("bind_buffs"):
			player.abilities.bind_buffs(null)
		player = value
		if is_instance_valid(value) and value.get("abilities") != null and value.abilities.has_method("bind_buffs"):
			value.abilities.bind_buffs(buffs)
var camera: ChaseCamera
# The flow state machine (src/core/flow.gd), read-only for modules: in_play(),
# state_name(), stage(), stage_def(). A node, so it and the context do not hold
# each other in a reference cycle.
var flow: Node
# The stage geometry, owned by world (writer D) and set by world.setup(ctx). The spine
# reads it only through the terrain API in CONTRACTS.md.
var terrain: RefCounted
# The combat module (writer A) behind the spawner API: spawn_enemy(kind, at) and
# strike(enemy, kind, force). Set by combat.setup(ctx).
var spawner: Node
# The build module (writer B), set by build.setup(ctx). Read it through has_method;
# builds from before this field existed use ctx.get_meta("build"), which build() also
# reads.
var build: Node
# The persistent codex (src/core/codex.gd): declare entries, mark discoveries.
var codex: Node
# The run log (src/core/run_log.gd). Flow asks it to close the open run before run state resets.
var run_log: Node
# The player profile (src/core/profile.gd), loaded by the game at boot. Only the game, the UI and
# core read it; movement, combat, build, world and boss never do (profile_purity_test).
var profile: RefCounted
# The settle-once ledger (src/core/progress.gd), set by the game; flow reconciles it on resume.
var progress: Node
# The boss module (wave 4), set by src/boss/boss.gd's setup when that file exists.
# Flow calls enter_arena(entry_velocity) on it after stage 3's launch.
var boss: Node
# The stage table the run reads: COUNT, BOSS, of(stage), is_last(stage). Game swaps it at
# build time (--table=), so no module preloads a table of its own.
var stages = StageDefs
# The node modules add their world children to.
var root: Node3D
# The stage's heft destructibles (src/world/destructibles.gd), set by world on each stage entry and null
# outside a stage. Blast sources reach it through break_props only.
var destructibles: Node
# One seeded stream per run for anything a module randomizes.
var rng := RandomNumberGenerator.new()
# Set by the spine tests that measure momentum: while true, modules spawn no enemies
# and apply no world pushes, so a speed check measures the ball and the seams alone.
var calm := false
# Is the screen busy (src/ui/screen_busy.gd): the one gate for every card that can wait.
var screen_busy: Node
# The game was launched with --dev: the dev keys (F1, F3, F4, F6) answer.
var dev := false

var _hit_stop: Callable


func _init(hit_stop_impl := Callable()) -> void:
	_hit_stop = hit_stop_impl


func build_module() -> Node:
	if build != null:
		return build
	return get_meta("build") if has_meta("build") else null


# Shots aim from the lens rest: kick, shake and the Screen shake row move the picture, never the aim (W16-1).
func aim_origin() -> Vector3:
	return camera.aim_origin()


func aim_forward() -> Vector3:
	return camera.aim_forward()


# The level direction the player faces: the view's yaw with no pitch, unit length. It is the
# read side of camera.snap(heading), and the one call simulation code makes for it, so no
# module reads the camera's basis. A context with no camera faces Vector3.FORWARD.
func heading() -> Vector3:
	return -camera.yaw_basis().z if camera != null else Vector3.FORWARD


# True when combat is present: the spawner exists and can spawn_enemy. Test stand-ins
# for the spawner only need that method.
func can_spawn() -> bool:
	return spawner != null and spawner.has_method("spawn_enemy")


# One blast a source already resolved: `radius` is the ring it committed, never a second one. Breaks every
# destructible the ring reaches that the run's heft class plus one meets. Safe with no stage standing.
func break_props(at: Vector3, radius: float, source: String) -> void:
	if destructibles != null and is_instance_valid(destructibles):
		destructibles.on_blast(at, radius, source, 1, run.heft_class() if run != null else -1)


# A short freeze on a big player-caused hit, for weight. The spine caps it at 60 ms
# and never stacks two, so juice can never become an obstruction.
func hit_stop(seconds: float) -> void:
	if _hit_stop.is_valid():
		_hit_stop.call(seconds)
