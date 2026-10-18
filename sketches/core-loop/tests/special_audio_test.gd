extends SceneTree

const Audio := preload("res://src/presentation/audio.gd")
const SpecialAudio := preload("res://src/presentation/special_audio.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const T := preload("res://tests/support/t.gd")

# The kill-first specials' hooks (INTEGRATION.md section 7, item 5): the presence loop is a
# player of its own on the enemy and at most two sound, nearest first; the tell sounds on its
# own frame, never queued to a beat; the break follows death and the splitter picks by how it
# was rammed; the spawn cue is queued to the next beat. Cue decisions are read from cue_log.

class FakeCtx:
	extends RefCounted
	var events: Node

class FakeSpecial:
	extends Node3D
	signal special_tell(moment: String)
	signal died(where: Vector3, scrap: int)
	var rammed_at_ground := false

var _t := T.new("special_audio_test")
var _nodes: Array = []


func _initialize() -> void:
	_t.eq("heard keeps the two nearest", SpecialAudio.heard({1: 30.0, 2: 5.0, 3: 12.0}), [2, 3])
	_t.eq("heard with one special", SpecialAudio.heard({7: 1.0}), [7])
	_t.eq("heard with none", SpecialAudio.heard({}), [])
	_t.eq("a tie goes to the lower id", SpecialAudio.heard({4: 3.0, 2: 3.0, 9: 3.0}), [2, 4])
	_t.eq("foreman break", SpecialAudio.cue("foreman", "break"), "foreman_break")
	_t.eq("splitter rammed", SpecialAudio.cue("splitter", "break", true), "splitter_break_split")
	_t.eq("splitter clean", SpecialAudio.cue("splitter", "break", false), "splitter_break_clean")
	_t.eq("linker tell", SpecialAudio.cue("linker", "tell"), "linker_tell")
	_t.check("a chaser is no special", not SpecialAudio.is_special("chaser"))
	_t.check("the dispatcher is", SpecialAudio.is_special("dispatcher"))


func _process(_delta: float) -> bool:
	var events := GameEvents.new()
	var ctx := FakeCtx.new()
	ctx.events = events
	var audio := Audio.new()
	audio.setup(ctx)
	audio.bake_now()
	_nodes.append_array([events, audio])
	var kinds := ["foreman", "dispatcher", "linker"]
	var enemies: Array = []
	for i in 3:
		var e := FakeSpecial.new()
		root.add_child(e)
		e.global_position = Vector3(5.0 * (i + 1), 0, 0)
		enemies.append(e)
		audio.cue_log.clear()
		audio._on_enemy_spawned(e, kinds[i])
		var spawn_cue: Array = audio.cue_log[0] if not audio.cue_log.is_empty() else []
		_t.check("%s spawn is queued to the beat" % kinds[i], spawn_cue.size() > 2 and spawn_cue[1] == kinds[i] + "_spawn" and spawn_cue[2] == "beat", str(spawn_cue))
		_t.check("%s carries its own presence player" % kinds[i], e.get_node_or_null("SpecialPresence") is AudioStreamPlayer3D)
	audio._tend_specials()
	var ids := enemies.map(func(e): return e.get_instance_id())
	_t.eq("the two nearest are heard", audio.specials_heard, [ids[0], ids[1]])
	_t.check("the third loop is silent", not enemies[2].get_node("SpecialPresence").playing)
	_t.check("the nearest loop plays", enemies[0].get_node("SpecialPresence").playing)
	enemies[2].global_position = Vector3(1, 0, 0)
	audio._tend_specials()
	_t.eq("a closer special takes the slot", audio.specials_heard, [ids[2], ids[0]])
	_t.check("the displaced loop stops", not enemies[1].get_node("SpecialPresence").playing and enemies[2].get_node("SpecialPresence").playing)
	_t.check("the loop has its own player, not the combat pool", enemies[0].get_node("SpecialPresence").stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)

	audio._last_start.clear()
	audio.cue_log.clear()
	enemies[0].special_tell.emit("tell")
	_t.check("the tell sounds now, not on a beat", audio.cue_log.size() == 1 and audio.cue_log[0][1] == "foreman_tell" and audio.cue_log[0][2] == "now", str(audio.cue_log))

	audio.cue_log.clear()
	enemies[0].died.emit(Vector3.ZERO, 0)
	_t.check("the break follows death", audio.cue_log.size() == 1 and audio.cue_log[0][1] == "foreman_break", str(audio.cue_log))
	_t.check("the dead special's loop is stopped", not enemies[0].get_node("SpecialPresence").playing)
	audio.cue_log.clear()
	enemies[0].died.emit(Vector3.ZERO, 0)
	_t.check("a second death signal is ignored", audio.cue_log.is_empty())

	var splitter_cues: Array = []
	for rammed in [true, false]:
		var s := FakeSpecial.new()
		root.add_child(s)
		s.rammed_at_ground = rammed
		audio._on_enemy_spawned(s, "splitter")
		audio._last_start.clear()
		audio.cue_log.clear()
		s.died.emit(Vector3.ZERO, 0)
		splitter_cues.append(audio.cue_log[0][1] if not audio.cue_log.is_empty() else "")
	_t.eq("the splitter breaks by how it was rammed", splitter_cues, ["splitter_break_split", "splitter_break_clean"])

	var gone: Node3D = enemies[1]
	gone.free()
	audio._tend_specials()
	_t.check("a freed special leaves the table", not audio._specials.has(ids[1]))
	for n in enemies:
		if is_instance_valid(n):
			n.free()
	for node in _nodes:
		node.free()
	quit(_t.verdict())
	return true
