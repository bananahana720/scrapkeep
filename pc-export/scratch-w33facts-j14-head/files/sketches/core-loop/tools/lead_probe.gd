extends "res://tools/ace_bounce_648.gd"
# Scratch only, never committed (job 14): the tracked bounce plus a 4 Hz log of the recorded band's lead
# (other stem) gain from ace_sequencer.parameter_gain("other"), with mode, section and the release flags.
# Rows go to <out>.lead.tsv: seconds, mode, section, gain, parameter_released, lead_returned, mix state.

var _lead_rows := PackedStringArray()
var _lead_next := 0.0


func _physics_process(delta: float) -> bool:
	var out := super(delta)
	if _game == null or _game.presentation == null:
		return out
	var audio = _game.presentation.audio
	var t := _now()
	if t < 0.0 or t < _lead_next or audio.ace == null:
		return out
	_lead_next = t + 0.25
	var a = audio.ace
	_lead_rows.append("%.2f\t%s\t%s\t%.3f\t%s\t%s\t%s" % [t, a.mode, a.section, a.parameter_gain("other"),
		a.parameter_released, a.lead_returned, audio.mix_state()])
	return out


func _finalize() -> void:
	var f := FileAccess.open(String(_settings["out"]) + ".lead.tsv", FileAccess.WRITE)
	if f != null:
		f.store_string("t\tmode\tsection\tgain\treleased\treturned\tstate\n" + "\n".join(_lead_rows) + "\n")
		f.close()
