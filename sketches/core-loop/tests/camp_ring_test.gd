extends SceneTree

const Game := preload("res://src/game.gd")
const Profile := preload("res://src/core/profile.gd")
const Records := preload("res://src/world/camp_records.gd")
const SurvivalCount := preload("res://src/world/survival_count.gd")
const T := preload("res://tests/support/t.gd")

# The camp ring (camp_ring.gd): the best count per pilot in the camp's records, and the ring
# itself against a real Game on the title state and the real camp hub's practice yard.

var _t := T.new("camp_ring_test")
var _kills := 0
var _deaths := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_records()
	await _ring()
	quit(_t.verdict())


func _records() -> void:
	var records := Records.new(null)
	_t.eq("no best before a count is cleared", records.ring_best("pylon_engineer"), 0)
	_t.check("a first count is a best", records.submit_ring("pylon_engineer", 3), "3")
	_t.check("a lower or equal count is not", not records.submit_ring("pylon_engineer", 3) and not records.submit_ring("pylon_engineer", 2), "3 again, 2")
	_t.check("each pilot keeps their own best", records.ring_best("pylon_engineer") == 3 and records.ring_best("someone_else") == 0, "per pilot")
	_t.check("a count of 0 is never a best", not records.submit_ring("someone_else", 0), "0")
	var merged: Dictionary = Profile._merge_camp({"ring": {"a": 4, "b": 2}, "skee_best": 90}, {"ring": {"a": 3, "b": 6, "c": 1}})
	_t.eq("two saves merge to the higher count per pilot", merged.get("ring"), {"a": 4, "b": 6, "c": 1})
	_t.eq("a merge keeps the other records", merged.get("skee_best"), 90)
	var doc := {"camp": {"ring": {"a": "many"}, "skee_best": 90}}
	Profile._sanitize_records(doc)
	_t.check("a malformed ring record is dropped, the rest kept", not doc["camp"].has("ring") and doc["camp"].get("skee_best") == 90, str(doc))


func _ring() -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	await process_frame
	await physics_frame
	var hub = game.camp_hub
	hub.ensure_built()
	var sandbox: Node = hub.root.get_node("CampSandbox")
	var ring: Node = hub.root.get_node_or_null("CampRing")
	_t.check("the ring is a feature of the camp", ring != null, "CampRing")
	if ring == null:
		return
	# Records of this test's own, so the saved best cannot colour it.
	ring.records = Records.new(null)
	var yard: Vector3 = hub.piece("camp_sandbox_yard").global_position
	var box: Vector3 = hub.socket("camp_call_box", "interact").origin
	var post: Vector3 = ring.board.global_position
	_t.check("the post stands inside the fence, away from the call box", Vector2(post.x - yard.x, post.z - yard.z).length() < 21.0 and Vector2(post.x - box.x, post.z - box.z).length() > 8.0, str(post))
	_t.eq("a quiet board with no best shows nothing", ring.board.text, "")
	game.events.enemy_killed.connect(func(_k, _a, _s): _kills += 1)
	game.events.player_died.connect(func(): _deaths += 1)

	ring.begin()
	_t.check("nothing starts off the walk", not ring.running(), "title")
	game.screens.toggle_camp()
	await physics_frame
	ring.begin()
	_t.check("nothing starts outside the yard", not ring.running(), "plaza")
	await _put(game, yard + Vector3.UP * 1.5)
	sandbox.met_override = []
	ring.begin()
	# The gap between counts is the rule's; a short one keeps the test short.
	var short: Dictionary = SurvivalCount.RULE.duplicate(true)
	short["gate_s"] = 0.05
	ring.count.rule = short
	_t.check("the post starts count 1", ring.running() and ring.count.count == 1 and ring.board.text == "1", ring.board.text)
	var first: Array = SurvivalCount.new(1, "ring").pack(1)
	await _frames(int(ceil(first.size() * 0.4 * 60.0)) + 20)
	_t.eq("count 1's machines climb in, met or not", sandbox.live_count(), first.size())
	var edge_ok := true
	for enemy in sandbox.live:
		edge_ok = edge_ok and enemy.has_meta("sandbox_slot")
	_t.check("each is a yard machine, so standing one is not meeting it", edge_ok, "sandbox_slot")
	ring.begin()
	_t.eq("the post does nothing mid-count", ring.count.count, 1)

	# Clear the floor: the count is cleared, and the next climbs in after the gap.
	for enemy in sandbox.live.duplicate():
		enemy.queue_free()
	await _frames(4)
	_t.check("an empty floor clears the count", ring.count.cleared == 1 and ring.count.gate_open, "cleared %d" % ring.count.cleared)
	await _frames(8)
	_t.check("the next count climbs in on its own", ring.count.count == 2 and ring.board.text == "2" and (sandbox.live_count() > 0 or not ring._owed.is_empty()), ring.board.text)

	# Wrecked: the ring ends, the best is the last count cleared, the yard is empty and whole.
	sandbox.hurt(1000.0)
	await _frames(3)
	_t.check("a wreck ends the ring", not ring.running(), "wreck")
	_t.eq("the last count cleared is the pilot's best", ring.best(), 1)
	_t.eq("the quiet board shows it", ring.board.text, "BEST 1")
	_t.check("the yard is empty and the hull whole", sandbox.live_count() == 0 and sandbox.hull == sandbox.HULL, "%d up" % sandbox.live_count())

	# Leaving the yard ends it too, and a lower count leaves the best alone.
	await _put(game, yard + Vector3.UP * 1.5)
	ring.begin()
	_t.check("the post starts it again", ring.running(), "again")
	await _put(game, yard + Vector3(60.0, 1.5, 0.0))
	await _frames(3)
	_t.check("leaving the yard ends the ring", not ring.running() and sandbox.live_count() == 0, "left")
	_t.eq("no count cleared leaves the best alone", ring.best(), 1)
	_t.check("the ring is no run: no kill, no death", _kills == 0 and _deaths == 0, "%d kills %d deaths" % [_kills, _deaths])
	game.screens.toggle_camp()
	await physics_frame
	game.queue_free()
	await process_frame


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _put(game, at: Vector3) -> void:
	game.player.reset_to(at)
	game.player.body().global_position = at
	await physics_frame
	await physics_frame
