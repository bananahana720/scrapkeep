extends SceneTree

# W46-12: the Slag Bowl's stand crew (stand_crew.gd) hold Fleet clipboards that answer the fight. Each property is a
# check that also runs on a planted broken case, which it must fail:
#   no collider    - nothing under the crew or the yard's crowds collides, and a physics query at a board hits nothing;
#                    planted: a body at a board.
#   never a target - nothing under them is in a group the game aims at or reads as a threat; planted: a fan in "enemy".
#   reacts         - Brindle's own turns (boss_phase_changed) play the clash beat, a combo pumps the boards, the rout
#                    hides then peeks; planted: a second crew seated on the same fans but on no bus.
#   hides no tell  - through every frame of the clash beat's freeze no boss tell is live and none is cued, even
#                    with a crane telegraph warning when the turn lands; the chase's turn, which cues the eject's
#                    catch mark on its frame, plays its clash with no freeze. Planted: the same freeze asked while a
#                    Furnace telegraph warns.
# Evidence limit: headless, the real boss and juice on the test clock; how the beat reads is the stills' job.

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const StandCrew := preload("res://src/presentation/stand_crew.gd")
const T := preload("res://tests/support/t.gd")

const TARGET_GROUPS := ["enemy", "threat", "telegraph", "enemy_shot", "world_telegraphs"]
# Long enough for phase 1's first crane telegraph (INTRO_SECONDS 3 s) or the Furnace's first lead after its beat.
const TELL_WAIT_FRAMES := 900

var t := T.new("stand_crew_test")
var game
var _tells := 0


func _initialize() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	Harness.start_run(game)
	game.run.set_max_hp(999999.0)
	Harness.enter(game, Vector3(18, 0, 0))
	await physics_frame
	game.events.boss_attack_telegraphed.connect(func(_id, _s): _tells += 1)
	game.events.attack_cued.connect(func(_f, _id, _s): _tells += 1)
	var arena: Node3D = game.boss.arena
	var crew = arena.get_node_or_null("StandCrew")
	var yard = arena.get_node_or_null(StandCrew.YARD_PATH)
	if not t.check("the bowl seats its stand crew", crew != null and yard != null):
		_finish()
		return
	var fans: MultiMeshInstance3D = yard.get_node(StandCrew.FANS)
	t.check("every fan holds a board", crew.board_count() == fans.multimesh.instance_count and crew.board_count() > 0,
		"%d boards, %d fans" % [crew.board_count(), fans.multimesh.instance_count])
	var drawn := crew.find_children("*", "GeometryInstance3D", true, false)
	t.check("the boards are one batched mesh, casting no shadow", drawn.size() == 1 and drawn[0] is MultiMeshInstance3D
		and drawn[0].cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%d drawn nodes" % drawn.size())
	_rest_in_hand(crew, yard, fans)
	await _colliders(crew, yard)
	_targets(crew, yard)
	# The tells first, on the fresh fight: a jump back to phase 1 keeps its broken chunk, and a held phase never attacks.
	await _no_tell(crew)
	await _reacts(crew, arena)
	_rout(crew)
	_finish()


# --- In hand ---------------------------------------------------------------------------------

func _rest_in_hand(crew, yard, fans: MultiMeshInstance3D) -> void:
	var seats: Array = yard.seats[yard.crowds.find(fans)]
	var worst := 0.0
	for i in crew.board_count():
		var seat: Transform3D = crew.boards.transform * seats[i].rest
		var hand: Vector3 = seat * StandCrew.REST
		worst = maxf(worst, crew.board_transform(i).origin.distance_to(hand))
	t.check("at rest each fan holds its board at the chest", worst < 0.01, "worst %.3f m" % worst)
	var near := INF
	for i in crew.board_count():
		var at: Vector3 = crew.board_transform(i).origin
		near = minf(near, Vector2(at.x, at.z).length())
	t.check("every board stands behind the rim wall, off the fight's floor", near > 62.0, "nearest %.1f m from the centre" % near)


# --- No collider -----------------------------------------------------------------------------

func _colliders(crew, yard) -> void:
	var crowds: Array = [crew]
	for crowd in yard.find_children("Crew*", "MultiMeshInstance3D", false, false):
		crowds.append(crowd)
	t.check("the crowds are the yard's two crews and the boards", crowds.size() == 3, str(crowds.map(func(n): return n.name)))
	var at: Vector3 = crew.global_transform * crew.board_transform(0).origin
	t.check("no collider: nothing under the crowds collides, and a query at a board hits nothing",
		_collider_free(crowds) and _query_hits(at).is_empty(), str(_query_hits(at)))
	var planted := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	planted.add_child(shape)
	crew.add_child(planted)
	planted.global_position = at
	await physics_frame
	t.check("planted: a body at a board fails the no-collider check", not (_collider_free(crowds) and _query_hits(at).is_empty()),
		"%d hits" % _query_hits(at).size())
	planted.free()


func _collider_free(nodes: Array) -> bool:
	for node: Node in nodes:
		if node is CollisionObject3D or not node.find_children("*", "CollisionObject3D", true, false).is_empty():
			return false
	return true


func _query_hits(at: Vector3) -> Array:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.4
	query.shape = sphere
	query.transform = Transform3D(Basis(), at)
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_areas = true
	return game.boss.arena.get_world_3d().direct_space_state.intersect_shape(query)


# --- Never a target --------------------------------------------------------------------------

func _targets(crew, yard) -> void:
	var nodes: Array = [crew, yard]
	t.check("never a target: no crowd node is in a group the game aims at or reads as a threat", _target_free(nodes))
	var fans: Node = yard.get_node(StandCrew.FANS)
	fans.add_to_group("enemy")
	t.check("planted: a fan in the enemy group fails the never-a-target check", not _target_free(nodes))
	fans.remove_from_group("enemy")


func _target_free(nodes: Array) -> bool:
	for group in TARGET_GROUPS:
		for member in game.get_tree().get_nodes_in_group(group):
			for node: Node in nodes:
				if member == node or node.is_ancestor_of(member):
					return false
	return true


# --- Reacts ----------------------------------------------------------------------------------

func _reacts(crew, arena: Node3D) -> void:
	var planted = StandCrew.build(arena)
	planted.bind(null, Callable())
	await _idle(crew)
	var rest: Transform3D = crew.held(0)
	game.boss.jump_to_phase(2)
	t.check("reacts: Brindle's turn into the Furnace plays the clash beat", _reacting(crew, "clash"), crew.reacting())
	t.check("the clash snaps the boards overhead on the turn's frame", crew.held(0).origin.y > rest.origin.y + 0.3,
		"%.2f -> %.2f in the fan's frame" % [rest.origin.y, crew.held(0).origin.y])
	t.check("planted: a crew on no bus fails the reacts check", not _reacting(planted, "clash"), planted.reacting())
	planted.free()
	_step(crew, StandCrew.CLASH_SECONDS + 1.0 / 60.0)
	t.eq("the clash is a one-second beat", crew.reacting(), "")
	t.check("after it the boards are back at rest", crew.held(0).origin.distance_to(StandCrew.REST) < 0.01)
	await process_frame

	game.events.line_state_changed.emit("chain_link", null, Vector3.ZERO, "")
	t.eq("one link is not a combo", crew.reacting(), "")
	game.events.line_state_changed.emit("chain_link", null, Vector3.ZERO, "")
	t.eq("reacts: the second link of a chain pumps the boards", crew.reacting(), "score")
	game.events.line_state_changed.emit("chain_end", null, Vector3.ZERO, "")
	_settle(crew)
	game.events.line_state_changed.emit("chain_link", null, Vector3.ZERO, "")
	t.eq("a chain's end starts the count over", crew.reacting(), "")
	game.events.line_state_changed.emit("chain_link", null, Vector3.ZERO, "")
	t.eq("the next chain's second link pumps them again", crew.reacting(), "score")
	game.events.boss_phase_changed.emit(3, "scuttle")
	game.events.line_state_changed.emit("chain_link", null, Vector3.ZERO, "")
	t.eq("a turn takes over a combo, and a combo never cuts the clash short", crew.reacting(), "clash")
	game.events.line_state_changed.emit("chain_end", null, Vector3.ZERO, "")
	_settle(crew)
	await _idle(crew)
	t.check("idle, the crew does no per-frame work", not crew.is_processing())


# A crew is reacting as it should: the beat's name.
func _reacting(crew, kind: String) -> bool:
	return crew.reacting() == kind


# --- Hides no tell ---------------------------------------------------------------------------

func _no_tell(crew) -> void:
	var juice = game.presentation.juice
	# A fresh fight: phase 1, run until a crane telegraph warns, then turn with it on screen.
	game.boss.jump_to_phase(1)
	var warned := await _until_tell()
	t.check("setup: a phase 1 telegraph is warning when the turn lands", warned and _live_tells() > 0, "live %d" % _live_tells())
	juice.reset_stops()
	var logged: int = juice.hit_stop_log.size()
	game.boss.jump_to_phase(2)
	var at_turn := _live_tells()
	var window := await _freeze_window()
	var asks := _asks(juice, logged)
	t.check("the turn asks juice for the two-frame freeze, and it is sent", asks.size() == 1
		and is_equal_approx(float(asks[0][1]), StandCrew.CLASH_FREEZE) and window.frames > 0,
		"asks %s, frozen frames %d" % [str(asks), window.frames])
	t.check("hides no tell: through the freeze no boss tell is live and none is cued", _hides_none(window, at_turn),
		"at the turn %d live; in the freeze %d live, %d cued" % [at_turn, window.live, window.cued])

	# Planted: the same freeze asked while a Furnace telegraph warns must fail the check.
	var furnace := await _until_tell()
	juice.reset_stops()
	var planted_at := _live_tells()
	juice.request_hit_stop(StandCrew.CLASH_FREEZE, StandCrew.FREEZE_FACT)
	var planted := await _freeze_window()
	t.check("planted: a freeze over a warning Furnace telegraph fails the hides-no-tell check", furnace and planted.frames > 0
		and not _hides_none(planted, planted_at), "frozen %d, live %d" % [planted.frames, planted.live])

	# The guard on its own: a turn whose frame also cues a tell asks for nothing.
	juice.reset_stops()
	logged = juice.hit_stop_log.size()
	game.events.boss_phase_changed.emit(3, "scuttle")
	game.events.attack_cued.emit("brindle", "charge", 1.0)
	await process_frame
	t.check("a tell cued with a turn calls its freeze off", _asks(juice, logged).is_empty(), str(_asks(juice, logged)))

	# The chase: the eject's catch mark is cued on the turn's frame, so the clash plays and the freeze is called off.
	juice.reset_stops()
	logged = juice.hit_stop_log.size()
	_tells = 0
	game.boss.jump_to_phase(4)
	var chase := await _freeze_window()
	t.check("the chase's turn plays the clash", crew.reacting() == "clash", crew.reacting())
	t.check("its eject tell is cued on the turn, so no freeze is asked", _tells > 0 and _asks(juice, logged).is_empty()
		and chase.frames == 0, "tells %d, asks %s, frozen %d" % [_tells, str(_asks(juice, logged)), chase.frames])


# Last: the rout hands the run on, so it is stepped by hand and no frame runs after it.
func _rout(crew) -> void:
	_settle(crew)
	game.events.boss_defeated.emit()
	t.eq("reacts: the rout hides every face behind its board", crew.reacting(), "rout")
	_step(crew, StandCrew.PEEK_AT - 0.05)
	var hid: Vector3 = crew.held(0).origin
	_step(crew, 0.3)
	var peek: Vector3 = crew.held(0).origin
	t.check("one beat later the boards dip and the crew peek over", peek.y < hid.y - 0.2, "%.2f -> %.2f" % [hid.y, peek.y])


func _hides_none(window: Dictionary, at_turn: int) -> bool:
	return at_turn == 0 and window.live == 0 and window.cued == 0


# Steps the fight until a boss tell is cued; true when one was.
func _until_tell() -> bool:
	_tells = 0
	for i in TELL_WAIT_FRAMES:
		await physics_frame
		if _tells > 0 and _live_tells() > 0:
			return true
	return false


# The freeze, frame by frame: how many physics frames it held, the most boss tells live in any of them, and the
# tells cued inside it. The deferred ask lands at the end of the turn's frame.
func _freeze_window() -> Dictionary:
	await process_frame
	var out := {"frames": 0, "live": 0, "cued": 0}
	for i in 12:
		var frozen := is_equal_approx(Engine.time_scale, Game.HIT_STOP_SCALE)
		if not frozen and out.frames > 0:
			break
		var before := _tells
		if frozen:
			out.frames += 1
			out.live = maxi(out.live, _live_tells())
		await physics_frame
		if frozen:
			out.cued += _tells - before
	return out


func _live_tells() -> int:
	var live := 0
	for h in game.boss.active_hazards():
		if h.is_hostile():
			live += 1
	return live


func _asks(juice, from: int) -> Array:
	return juice.hit_stop_log.slice(from).filter(func(row): return String(row[2]) == StandCrew.FREEZE_FACT and float(row[1]) > 0.0)


func _step(crew, seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		crew._process(1.0 / 60.0)


func _settle(crew) -> void:
	for i in 600:
		if crew.reacting() == "":
			return
		crew._process(1.0 / 60.0)


# Real frames until the crew and the yard's cheer are both done.
func _idle(crew) -> void:
	for i in 900:
		if not crew.is_processing():
			return
		await process_frame


func _finish() -> void:
	Engine.time_scale = 1.0
	game.free()
	quit(t.verdict())
