extends "res://tools/ev_rec_kills.gd"
# Scratch only, never committed (job 23): the event recorder plus rows for Brindle's entrance close-up.
# Each frame it reads presentation.close_up() and logs inset_up / inset_down on a change, and logs which
# flourish kinds are live when the panel goes up; also boss phase rows from the mix state.

var _inset_on := false
var _mix_last := ""
# Clip run only (GPUWIN_CLIP_DIR set): saves every frame as a PNG for 300 frames from the arena entry,
# which perturbs frame timing, so timing runs leave it unset.
var _clip_dir := ""
var _clip_left := 0
var _clip_n := 0
var _clip_hooked = null


func _initialize() -> void:
	_clip_dir = OS.get_environment("GPUWIN_CLIP_DIR")
	process_frame.connect(_entr_tick)
	super._initialize()


func _entr_tick() -> void:
	if _game == null or not is_instance_valid(_game) or _game.get("presentation") == null:
		return
	var pres = _game.presentation
	if _clip_dir != "" and _clip_hooked != _game and _game.get("ctx") != null and _game.ctx.get("events") != null:
		_clip_hooked = _game
		_game.ctx.events.boss_arena_entered.connect(func(): _clip_left = 300)
	if _clip_left > 0:
		_clip_left -= 1
		_clip_n += 1
		root.get_texture().get_image().save_png("%s/f%04d.png" % [_clip_dir, _clip_n])
	var on: bool = pres.has_method("close_up") and pres.close_up()
	var live := []
	if pres.get("flourish") != null and pres.flourish.has_method("live_kinds"):
		live = pres.flourish.live_kinds()
	var showing: bool = live.has("inset")
	if showing != _inset_on:
		_inset_on = showing
		_ev_add("inset_up" if showing else "inset_down", ",".join(live.map(func(k): return String(k))) + " close_up=" + str(on))
	if pres.get("audio") != null:
		var m: String = pres.audio.mix_state()
		if m != _mix_last:
			_mix_last = m
			_ev_add("mix", m)
