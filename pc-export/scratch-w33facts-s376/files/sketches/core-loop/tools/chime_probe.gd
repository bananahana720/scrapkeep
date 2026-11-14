extends "res://tools/ace_bounce_tail.gd"
# Scratch only, never committed (job 18): during an ACE bounce, at --chime-after seconds, grant the three Live Wire
# parts (live_line, beacon_lamp, echo_locator) so the arc set completes and the "Set complete" banner and chime run.
# Logs a chime_grant fact: [t, "chime_grant", sample from bounce start, mix state, stage].

var _chime_after := -1.0
var _chime_done := false
const PARTS := ["live_line", "beacon_lamp", "echo_locator"]


func _physics_process(delta: float) -> bool:
	var out := super(delta)
	if _chime_done or _driver == null or _game == null or _game.ctx == null:
		return out
	if _chime_after < 0.0:
		_chime_after = float(_settings.get("chime-after", "20"))
	if _now() < _chime_after:
		return out
	_chime_done = true
	var audio = _game.presentation.audio
	_facts.append([_now(), "chime_grant", audio.engine.clock - _base_sample, audio.mix_state(), audio._stage_now])
	var build = _game.ctx.get("build")
	if build != null:
		build.set_completed.connect(func(id: String, _t: String, _x: String, _c: Color): _facts.append([_now(), "set_completed", id]))
	var banner = _game.presentation.get("banner")
	if banner != null:
		banner.came_up.connect(func(key: String): _facts.append([_now(), "banner_up", key, _game.presentation.audio.mix_state()]))
	# Pre-mark the part finds as seen so only the set banner queues (scratch run, scratch save dir).
	if banner != null:
		for part in PARTS:
			banner._mark_seen("part:" + part)
	for part in PARTS:
		_game.ctx.run.add_part(part, "probe")
	# Drop the queued part banners (headless runs use the plain banner style, which ignores seen),
	# clear the one on screen, and let the set banner come up at the next calm moment.
	var bn = _game.presentation.get("banner")
	if bn != null:
		bn._queue = bn._queue.filter(func(item: Array): return not String(item[6]).begins_with("part:"))
		bn.dismiss(false)
		bn._next()
	_facts.append([_now(), "parts_after", _game.ctx.run.parts.duplicate() if _game.ctx.run.get("parts") != null else []])
	return out
