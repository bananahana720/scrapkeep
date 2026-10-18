# smoke: solo (builds the ending fly-over twice)
extends SceneTree

# Rule (src/ui/ending_sequence.gd, unit ST3): world k's fly-over shows world k's two ENDING lines
# in order, the credits show close then sign, and the Dig fly-over carries built Dig scenery
# even when the run never entered the Dig. Every ENDING line is at most 14 words.

const Game := preload("res://src/game.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const Sequence := preload("res://src/ui/ending_sequence.gd")
const Worlds := preload("res://src/core/worlds.gd")
const T := preload("res://tests/support/t.gd")

const MAX_WORDS := 14
# Each world's first line names what that world's win left behind.
const ANCHORS := {1: "Brindle", 2: "Waking", 3: "Mind"}

var _t := T.new("ending_copy_test")
var _game


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_copy_table()
	await _boot()
	await _frames(2)
	_game.flow.enter_stage(StageDefs.COUNT, Vector3.ZERO, false)
	await _frames(2)
	_t.check("fixture has no Dig geometry", not _game.ctx.terrain.is_built(StageDefs.first_of(2)))
	_force_win()
	var seq = _game.screens.ending_sequence
	if not _t.check("ending sequence starts", is_instance_valid(seq) and seq.active):
		_finish()
		return
	seq.set_process(false)
	_play_copy(seq)
	seq.skip()
	await _dig_case([], 3, false)
	await _dig_case([3], 3, false)
	await _dig_case([3, 4], 4, true)
	_finish()


# Fresh run that visits the given stages, then wins; the Dig fly-over must show the stage's rig.
func _dig_case(visit: Array, want_stage: int, deep: bool) -> void:
	await _boot()
	await _frames(2)
	for stage in visit:
		_game.flow.enter_stage(stage, Vector3.ZERO, false)
	_game.flow.enter_stage(StageDefs.COUNT, Vector3.ZERO, false)
	await _frames(2)
	_force_win()
	var seq = _game.screens.ending_sequence
	seq.set_process(false)
	_dig_scenery(seq, "visit %s" % [visit], want_stage, deep)
	seq.skip()


func _boot() -> void:
	if is_instance_valid(_game):
		_game.free()
	_game = Game.new()
	_game.test_mode = true
	_game.table = "default"
	root.add_child(_game)
	await _frames(5)
	_game.bot_driven = false
	_game.ctx.calm = true
	# The fly-over is the ending when the crater lap cannot place (flow._begin_ending); victory_lap_test owns the lap.
	_game.flow.victory_lap = false
	_game.flow.press_start()
	_game.flow.choose_class(1)


func _copy_table() -> void:
	var lines: Array = []
	for world in Worlds.ROWS:
		var rows: Array = Worlds.ENDING.log[int(world.id)]
		_t.eq("world %d has two lines" % int(world.id), rows.size(), 2)
		_t.check("ST3-1 world %d's first line is about its own world" % int(world.id), String(rows[0]).contains(ANCHORS[int(world.id)]), String(rows[0]))
		lines.append_array(rows)
	lines.append_array(Worlds.ENDING.close)
	lines.append(Worlds.ENDING.sign)
	_t.eq("close has two lines", Worlds.ENDING.close.size(), 2)
	var longest := 0
	var fragment := false
	for line in lines:
		longest = maxi(longest, String(line).split(" ", false).size())
		fragment = fragment or String(line).to_lower().contains("fragment")
	_t.check("every ENDING line is at most %d words" % MAX_WORDS, longest <= MAX_WORDS, "longest %d" % longest)
	_t.check("no ENDING line says fragment", not fragment)
	_t.eq("no ENDING line repeats", _unique(lines).size(), lines.size())


func _play_copy(seq) -> void:
	var seen: Array = []
	var step := 0.25
	var t := 0.0
	var phase_seen: Array = []
	while t < Sequence.TOTAL_SECONDS - 0.5:
		t += step
		seq.advance(t - seq.elapsed)
		if not phase_seen.has(seq.phase):
			phase_seen.append(seq.phase)
		if seq.phase != "flyover" and seq._copy.visible and seq._copy.text != "" and not _tail_is(seen, seq._copy.text):
			seen.append(seq._copy.text)
	var want: Array = []
	for world in Worlds.ROWS:
		want.append_array(Worlds.ENDING.log[int(world.id)])
	want.append_array(Worlds.ENDING.close)
	want.append(Worlds.ENDING.sign)
	_t.eq("ST3-1 copy plays each world's rows, then close, then sign, once each", seen, want)
	_t.eq("phases run fly-over, copy, credits", phase_seen, ["flyover", "copy", "credits"])


func _dig_scenery(seq, label: String, want_stage: int, deep: bool) -> void:
	seq._enter_world(1)
	_t.eq("ST3-2 %s: the Dig fly-over uses stage %d" % [label, want_stage], seq.stages[1], want_stage)
	_t.eq("ST3-2 %s: deep rig is %s" % [label, deep], seq._dig_deep, deep)
	var scenery: Node = seq.worlds[1].get_node_or_null("DigScenery")
	_t.check("ST3-2 %s: the Dig holder has DigScenery" % label, scenery != null)
	var meshes := 0
	if scenery != null:
		meshes = scenery.find_children("*", "MeshInstance3D", true, false).size() \
			+ scenery.find_children("*", "MultiMeshInstance3D", true, false).size()
	_t.check("ST3-2 %s: the Dig scenery has draw nodes" % label, meshes > 0, "%d draw nodes" % meshes)
	_t.check("%s: the Dig holder is the visible world" % label, seq.worlds[1].visible)
	for local in [2.5, 6.0, 11.0]:
		seq.advance(Sequence.WORLD_SECONDS + local - seq.elapsed)
		var inside := 0
		var total := 0
		for view in scenery.find_children("*", "MultiMeshInstance3D", true, false):
			for origin in view.get_meta("origins", PackedVector3Array()):
				total += 1
				var world_at: Vector3 = view.global_transform * origin
				if not seq.camera.is_position_behind(world_at) and seq.camera.is_position_in_frustum(world_at):
					inside += 1
		_t.check("ST3-2 %s: Dig scenery is in frame at %.1f s" % [label, local], inside > 0, "%d of %d placements in frame" % [inside, total])


func _tail_is(seen: Array, text: String) -> bool:
	return not seen.is_empty() and seen[-1] == text


func _unique(lines: Array) -> Array:
	var out: Array = []
	for line in lines:
		if not out.has(line):
			out.append(line)
	return out


func _force_win() -> void:
	_game.flow._set_state(_game.flow.BOSS)
	_game.events.boss_defeated.emit()
	_game.flow.physics_step(_game.flow.VICTORY_SECONDS + 0.01)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _finish() -> void:
	_game.free()
	quit(_t.verdict())
