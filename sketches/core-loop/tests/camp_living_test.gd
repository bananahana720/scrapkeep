extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const CampLayout := preload("res://src/world/camp_layout.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const RadioTakes := preload("res://src/core/radio_takes.gd")
const TuneRows := preload("res://src/core/tune_rows.gd")
const T := preload("res://tests/support/t.gd")

# The living camp (W46-14, camp_hub.gd), on the real title's walk:
#   - every freed pilot but the one the gate launches stands round the fire pit, and nobody else does: a pilot the
#     profile has not freed is not there, and the gate's own pilot is the ball;
#   - a standing pilot is drawn only: no collider, no body, no area of their own, never in a target group, and the
#     camp's colliders are the ones it had before the crew came;
#   - each stands on the plaza, at their own spot;
#   - the ball rolling up to one puts their line on the caller plate (caller id and words from LoreRows.CAMP_QUIPS)
#     and sends pilot_quipped once a walk, however often the ball comes back; the next walk they speak again;
#   - the pilot who speaks turns their face (the model's -Z) to the ball; a new walk stands everyone facing the fire, and
#     a pilot not standing has a quip zone that does not listen;
#   - the B-sides the profile has found, and only those, stand as sleeves in the record bin by the jukebox, in the
#     order they were found, drawn as one MultiMesh each for the bins and the sleeves, from code-built meshes;
#   - a new walk picks up a change of gate pilot and a new B-side.

var _t := T.new("camp_living_test")
var _game
var _hub
var _said: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _put(at: Vector3) -> void:
	_game.player.reset_to(at)
	_game.player.body().global_position = at
	await _physics(4)


# The ball set down 2.5 m from a pilot, on the plaza side.
func _beside(class_id: String) -> void:
	var figure: Node3D = _hub.crew_figure(class_id)
	var toward: Vector3 = _hub.root.global_position - figure.global_position
	toward.y = 0.0
	await _put(figure.global_position + toward.normalized() * 2.5 + Vector3.UP * 1.3)


# How square a figure faces a point once its turn has run out: the figure's face (-Z) against the way to the point, on
# the ground, 1 for dead on, -1 for its back.
func _faces(figure: Node3D, at: Vector3) -> float:
	var turn = figure.get_meta("turn") if figure.has_meta("turn") else null
	if turn is Tween and (turn as Tween).is_valid():
		(turn as Tween).custom_step(1.0)
	var face := -figure.global_basis.z
	var to := at - figure.global_position
	return Vector2(face.x, face.z).normalized().dot(Vector2(to.x, to.z).normalized())


func _away() -> void:
	await _put(_hub.spawn_position())


func _b_sides(count: int, skip := 0) -> Array:
	var out: Array = []
	for id in TuneRows.ids() + RadioTakes.take_ids():
		if String(RadioTakes.track(String(id)).get("tier", "")) == "b-side":
			if skip > 0:
				skip -= 1
				continue
			out.append(String(id))
			if out.size() == count:
				break
	return out


func _not_b_side() -> String:
	for id in TuneRows.ids() + RadioTakes.take_ids():
		if String(RadioTakes.track(String(id)).get("tier", "")) == "take":
			return String(id)
	return ""


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_hub = _game.camp_hub
	var profile = _game.ctx.profile
	profile.unlock_pilot("runner_gunner")
	profile.unlock_pilot("tally")
	var found := _b_sides(3)
	var other := _not_b_side()
	_t.check("the catalogue has b-sides and a take to plant", found.size() == 3 and other != "", "%s / %s" % [found, other])
	profile.hear_tune(found[0])
	profile.hear_tune(other)
	profile.hear_tune(found[1])
	profile.hear_tune(found[2])
	_hub.pilot_quipped.connect(func(speaker: String, row_id: String, words: String): _said.append([speaker, row_id, words]))

	_game._screen_key(KEY_K)
	await _frames(5)
	_t.check("K enters the walk", _hub.walking and _hub.built, "")
	var flying = _game.gate_pilot()
	_t.eq("the gate launches Sable on this profile", String(flying.id), "pylon_engineer")
	var standing: Array = _hub.crew_standing()
	standing.sort()
	_t.eq("the freed pilots stand, and not the one the gate launches", standing, ["runner_gunner", "tally"])
	_t.check("a pilot not yet freed is not built", _hub.crew_figure("demolitions_caster") == null and not _hub.zone_ids().has("crew_demolitions_caster"), "")

	# Drawn only: no collider, no body, no area under a figure; no target group; the camp's colliders are its own.
	for id in ["runner_gunner", "tally"]:
		var figure: Node3D = _hub.crew_figure(id)
		var solids := figure.find_children("*", "CollisionObject3D", true, false) + figure.find_children("*", "CollisionShape3D", true, false)
		_t.check("%s has no collider, body or area" % id, solids.is_empty(), str(solids))
		var grouped := ([figure] + figure.find_children("*", "", true, false)).filter(func(n: Node): return not n.get_groups().is_empty())
		_t.check("%s is in no group (never a target)" % id, grouped.is_empty(), str(grouped.map(func(n): return n.get_groups())))
		var to_hub: Transform3D = _hub.root.global_transform.affine_inverse()
		var foot := INF
		for view: MeshInstance3D in figure.find_children("*", "MeshInstance3D", true, false):
			foot = minf(foot, (to_hub * view.global_transform * view.mesh.get_aabb()).position.y)
		var top: float = _hub.plaza_top(Vector2(figure.position.x, figure.position.z))
		_t.check("%s stands on the plaza" % id, absf(foot - top) < 0.02, "foot %.3f, plaza %.3f" % [foot, top])
		var index: int = _game.flow.classes.map(func(d): return String(d.id)).find(id)
		var spot: Vector3 = _hub.crew_spot(index)
		_t.check("%s stands at their own spot" % id, Vector2(figure.position.x, figure.position.z).distance_to(Vector2(spot.x, spot.z)) < 0.01, str(figure.position))
	for shape: CollisionShape3D in _hub.root.find_children("*", "CollisionShape3D", true, false):
		var path := String(_hub.root.get_path_to(shape))
		if path.begins_with("Crew_") or path.contains("Records"):
			_t.check("no collider under the crew or the records", false, path)

	# The quip: the ball rolls up to Rivet.
	await _beside("runner_gunner")
	await _frames(2)
	var rivet := LoreRows.camp_quip("runner_gunner")
	_t.eq("Rivet's caller id is on the plate", _hub.quip_caller(), "rivet")
	_t.eq("the plate shows Rivet's line for this walk", _hub.quip_words(), LoreRows.camp_quip_text(rivet, _hub.walks))
	_t.check("the line is one of Rivet's", (rivet["text"] as Array).has(_hub.quip_words()), _hub.quip_words())
	_t.eq("pilot_quipped hands out the caller id, the row and the words", _said, [["rivet", "camp.quip.rivet", _hub.quip_words()]])
	_t.check("the plate is the caller plate, in Rivet's colour", _hub._quip_tile.speaker == "rivet" and _hub._quip_tile.visible, "")
	_t.check("Rivet turns to face the ball (a pilot model's face is its -Z)", _faces(_hub.crew_figure("runner_gunner"), _game.player.body().global_position) > 0.99,
		"%.3f" % _faces(_hub.crew_figure("runner_gunner"), _game.player.body().global_position))
	await _away()
	await _beside("runner_gunner")
	_t.eq("once a walk: coming back says nothing new", _said.size(), 1)
	await _beside("tally")
	_t.eq("Tally speaks too", _said.size() == 2 and _said[1][0] == "tally", true)
	var fire: Vector3 = _hub.root.global_transform * CampLayout.at(_hub.CREW_FIRE[0], _hub.CREW_FIRE[1])
	_t.check("Tally faces the ball, not the fire, after the turn", _faces(_hub.crew_figure("tally"), _game.player.body().global_position) > 0.99, "")
	_hub._process(30.0)
	if _hub._quip_tween != null and _hub._quip_tween.is_valid():
		_hub._quip_tween.custom_step(_hub.QUIP_FADE_S + 0.1)
	await _frames(1)
	_t.eq("the plate goes after its time", _hub.quip_words(), "")

	# The records.
	_t.eq("the bin holds the found b-sides, in the order found, and no take", _hub.shelved_records(), found)
	var records: Node3D = _hub.piece("moss_jukebox").get_node("Records")
	var sleeves := records.get_node("Sleeves") as MultiMeshInstance3D
	var bins := records.get_node("Bins") as MultiMeshInstance3D
	_t.eq("one sleeve a b-side, in one MultiMesh", sleeves.multimesh.instance_count, 3)
	_t.eq("one bin", bins.multimesh.instance_count, 1)
	_t.check("sleeve and bin are code-built meshes, not primitives", sleeves.multimesh.mesh is ArrayMesh and bins.multimesh.mesh is ArrayMesh, "")
	# A headless run keeps no MultiMesh colours, so the inks are read where the hub picks them.
	for ink: Color in _hub.SLEEVE_INKS:
		_t.check("a sleeve ink is no purple (ruling ci)", ink.s < 0.15 or ink.h * 360.0 < 300.0 or ink.h * 360.0 > 330.0, ink.to_html())
	var inked := true
	for id in found:
		inked = inked and _hub.SLEEVE_INKS.has(_hub.sleeve_ink(id)) and _hub.sleeve_ink(id) == _hub.sleeve_ink(String(id) + "")
	_t.check("a sleeve's colour is its id's pick of the inks, the same every time", inked, "")

	# A new walk: Rivet flew last, so the gate launches Rivet and Sable stands; a new b-side joins the bin.
	_game._screen_key(KEY_K)
	await _frames(3)
	_t.check("K leaves the walk", not _hub.walking, "")
	profile.set_last_pilot("runner_gunner")
	var fourth: String = _b_sides(1, 3)[0]
	profile.hear_tune(fourth)
	var walks_before: int = _hub.walks
	_game._screen_key(KEY_K)
	await _frames(5)
	standing = _hub.crew_standing()
	standing.sort()
	_t.eq("the next walk stands the crew round the new gate pilot", standing, ["pylon_engineer", "tally"])
	_t.check("a new walk starts with the crew facing the fire again", _faces(_hub.crew_figure("tally"), fire) > 0.99
		and _faces(_hub.crew_figure("pylon_engineer"), fire) > 0.99, "%.3f" % _faces(_hub.crew_figure("tally"), fire))
	_t.check("the hidden pilot's quip zone stops listening, the standing ones listen",
		not (_hub._zones["crew_runner_gunner"]["area"] as Area3D).monitoring and (_hub._zones["crew_tally"]["area"] as Area3D).monitoring
		and (_hub._zones["crew_pylon_engineer"]["area"] as Area3D).monitoring, "")
	_t.eq("the walk count steps", _hub.walks, walks_before + 1)
	_t.eq("the new b-side joins the bin", _hub.shelved_records(), found + [fourth])
	_t.eq("four sleeves", sleeves.multimesh.instance_count, 4)
	await _beside("tally")
	_t.check("a new walk, a new line", _said.size() == 3 and _said[2][0] == "tally"
		and _said[2][2] == LoreRows.camp_quip_text(LoreRows.camp_quip("tally"), _hub.walks), str(_said))
	quit(_t.verdict())
