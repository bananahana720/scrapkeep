extends "res://tools/ace_bounce_tail.gd"
# Scratch only, never committed (job 26): during an ACE bounce, two call-ins in roaming (sable, then mind)
# and two in a fight (sable, then mind), through audio.call_in. Logs a callin fact per call:
# [t, "callin", speaker, scheduled sample from bounce start, grid origin from bounce start, grid_beat, mix, seconds].

const LINES := {"sable": "Line's hot. Going in.", "mind": "All hands. Report to the dam."}
var _plan := [["roam", "sable"], ["roam", "mind"], ["fight", "sable"], ["fight", "mind"]]
var _next_ok := 1.5


func _physics_process(delta: float) -> bool:
	var out := super(delta)
	if _plan.is_empty() or _driver == null or _game == null or _game.presentation == null:
		return out
	var audio = _game.presentation.audio
	if _now() < _next_ok or not audio._on_ace_grid():
		return out
	var want: String = _plan[0][0]
	var mix: String = audio.mix_state()
	var fight := mix in ["combat", "miniboss"] or mix.begins_with("boss")
	if (want == "roam" and mix != "roam") or (want == "fight" and (not fight or _now() < 12.0)):
		return out
	var speaker: String = _plan[0][1]
	var seconds: float = audio.call_in("call_in", speaker, LINES[speaker])
	var at := -1
	if seconds > 0.0 and not audio.cue_log.is_empty():
		at = int(audio.cue_log[audio.cue_log.size() - 1][3])
	_facts.append([_now(), "callin", speaker, at - _base_sample if at >= 0 else -1, audio.ace.origin - _base_sample,
		audio.ace.grid_beat, mix, snappedf(seconds, 0.001)])
	if seconds > 0.0:
		_plan.pop_front()
		_next_ok = _now() + seconds + 0.5
	else:
		_next_ok = _now() + 0.25
	return out
