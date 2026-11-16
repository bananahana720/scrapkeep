extends RefCounted

# A run filmed as the player's eyes meet it (tools/self_play.gd --self-play-film=<dir>): the picture
# on the screen at the moments a player has to read it, saved as frames with one row of ground
# truth each, so a reader who has never seen the game can say what the screen told them and a
# judge can set that beside what the game knew. It only reads the game.
#
# It needs a rendered display (a real one, or xvfb with --rendering-driver opengl3): under
# --headless there is no picture and setup() refuses. Run it with --fixed-fps so its seconds are
# game seconds whatever the renderer's speed.
#
# Unless `live` is set it draws only the frames it keeps (the engine's render loop is off between
# them), which is what makes a software renderer fast enough: a whole stage films in minutes, not
# hours. That is the one thing it changes, and it is why a film is never a frame-time reading and
# under-shows GPU particles (they advance only on a drawn frame). A PC film runs live.
#
# Frames (why, in the row and the file name):
#   screen-<state>   each flow state as it opens, SETTLE_S after and again LATE_S after
#   held             the game paused (a kit pick, the briefing, a ceremony, the pause menu):
#                    SETTLE_S after, then every HELD_STEP_S while it stays held, HELD_MAX times
#   roam             every `every` seconds of play, so quiet stretches are seen too
#   plate            the objective plate changed
#   prompt-<verb>    a key prompt or first-meet tip drew (once a verb)
#   page             a page the player turned (the prologue's lines), when the driver says so
#   offer / reward / warden / arena   a kit pick offered, the reward gates, a Warden engaged,
#                    the boss arena entered
#   cleared / phase-<n> / boss-down   a stage's Warden broken, a boss phase begun, the boss beaten:
#                    the ends of fights, which a player sees and a ten second gap can miss
#   hit-<n>          a hit of BIG_HIT of the hull or more, or the run's first: the LEAD_S before
#                    it from a rolling buffer (was the attack on the screen before it landed?),
#                    then the frame after
#   death            the same lead-in for the killing hit, then the death screen
# Rows go to film.ndjson in the folder, one a frame: t (game seconds filmed), file, why, flow,
# paused, stage, stage_s, plate (the HUD's objective words), hp, hp_max, mass, pos, lens (the camera's
# position), ball_on_screen, arm {wanted, hit, body: what stopped the arm, or null} and slots (each
# ability slot to ready, cooling, empty, unavailable, jammed, active or dimmed-for-set-piece),
# and for a hit its source and amount. The reader is not shown the rows.
# Evidence limit: the picture is this machine's renderer. In the cloud that is a software
# renderer: words, layout, marks and what is on screen read true; colour, light, bloom and
# frame pacing do not, and belong to a PC film.

const SETTLE_S := 0.5
const LATE_S := 2.5
const HELD_STEP_S := 2.0
const HELD_MAX := 4
const RING_STEP_S := 0.4
const LEAD_S := 2.0
const BIG_HIT := 0.1
const HIT_GAP_S := 6.0
const MAX_HITS := 16
const QUALITY := 0.82
const NEAR_S := 0.25

var frames := 0
var drawn := 0

var _game
var _dir := ""
var _every := 10.0
var _rows: FileAccess
var _t := 0.0
var _state := ""
var _plate := ""
var _roam_at := 0.0
var _ring := []
var _ring_at := 0.0
var _due := []
var _verbs := {}
var _hits := 0
var _hit_at := -100.0
var _first_hit := true
var _live := false
# Pictures asked for this frame, taken once it has drawn: [why, extra, into the buffer?].
var _asked := []
var _held := false
var _held_shots := 0
var _held_next := 0.0
var _shot_at := -1.0


# False when there is no picture to film or the folder cannot be made.
func setup(game, dir: String, every: float, live := false, world_scale := 1.0) -> bool:
	if DisplayServer.get_name() == "headless":
		push_error("eye-film: no picture under --headless; run with a display (xvfb and --rendering-driver opengl3)")
		return false
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		push_error("eye-film: cannot make %s" % dir)
		return false
	_game = game
	_dir = dir
	_every = maxf(every, 1.0)
	_rows = FileAccess.open(dir.path_join("film.ndjson"), FileAccess.WRITE)
	var events = game.events
	events.player_hit.connect(_on_hit)
	events.player_died.connect(_on_died)
	events.warden_engaged.connect(_on_warden)
	events.boss_arena_entered.connect(_on_arena)
	events.reward_offered.connect(_on_reward)
	events.tree_offered.connect(_on_offer)
	events.prompt_shown.connect(_on_prompt)
	events.stage_cleared.connect(_on_cleared)
	events.boss_phase_changed.connect(_on_phase)
	events.boss_defeated.connect(_on_boss_down)
	_live = live
	# The world drawn at a fraction of the window, the HUD and every word at full size: for a
	# software renderer, where the world's pixels are the cost and the words are the reading.
	if world_scale < 1.0:
		game.get_viewport().scaling_3d_scale = clampf(world_scale, 0.25, 1.0)
	RenderingServer.frame_post_draw.connect(_drawn)
	if not _live:
		RenderingServer.render_loop_enabled = false
	return _rows != null


# Once a physics tick, paused or not: a paused screen is still a screen the player reads.
func step(delta: float) -> void:
	if _game == null or _game.flow == null:
		return
	_t += delta
	var state: String = _game.flow.state_name()
	if state != _state:
		_state = state
		_later(SETTLE_S, "screen-%s" % state)
		_later(LATE_S, "screen-%s-late" % state)
	var held: bool = _game.get_tree().paused
	if held != _held:
		_held = held
		_held_shots = 0
		_held_next = _t + SETTLE_S
	if _held and _held_shots < HELD_MAX and _t >= _held_next:
		_held_shots += 1
		_held_next = _t + HELD_STEP_S
		_shoot("held")
	if _game.flow.in_play() and not _held:
		var plate := _plate_words()
		if plate != _plate:
			_plate = plate
			_later(0.8, "plate")
		if _t - _roam_at >= _every:
			_roam_at = _t
			_shoot("roam")
		if _t - _ring_at >= RING_STEP_S:
			_ring_at = _t
			_ask("", {}, true)
	var still_due := []
	for entry in _due:
		if _t >= entry[0]:
			_shoot(entry[1], entry[2])
		else:
			still_due.append(entry)
	_due = still_due


func _later(after: float, why: String, extra := {}) -> void:
	_due.append([_t + after, why, extra])


func _on_hit(amount: float, source: String) -> void:
	var run = _game.run
	var big: bool = amount >= BIG_HIT * float(run.max_hp)
	if not (big or _first_hit) or _hits >= MAX_HITS or _t - _hit_at < HIT_GAP_S:
		return
	_first_hit = false
	_hits += 1
	_hit_at = _t
	var extra := {"source": source, "amount": snappedf(amount, 0.1)}
	_lead_in("hit-%d" % _hits, extra)
	_later(0.3, "hit-%d-after" % _hits, extra)


func _on_died() -> void:
	_lead_in("death", {})
	_later(SETTLE_S, "death-after")
	_later(LATE_S, "death-screen")


func _on_warden(_stage: int) -> void:
	_later(SETTLE_S, "warden")
	_later(LATE_S, "warden-late")


func _on_arena() -> void:
	_later(SETTLE_S, "arena")
	_later(LATE_S, "arena-late")


func _on_cleared(_stage: int) -> void:
	_later(SETTLE_S, "cleared")
	_later(LATE_S, "cleared-late")


func _on_phase(phase: int, _name: String) -> void:
	_later(SETTLE_S, "phase-%d" % phase)


func _on_boss_down() -> void:
	_later(SETTLE_S, "boss-down")
	_later(LATE_S, "boss-down-late")


func _on_reward(_offers: Array) -> void:
	_later(SETTLE_S, "reward")


func _on_offer(_class_id: String, _depth: int, _choices: Array) -> void:
	_later(SETTLE_S, "offer")


func _on_prompt(verb: String) -> void:
	if _verbs.has(verb):
		return
	_verbs[verb] = true
	_later(0.6, "prompt-%s" % verb.validate_filename())


# The buffer's frames before now, oldest first, then the frame of the moment itself.
func _lead_in(why: String, extra: Dictionary) -> void:
	for kept in _ring:
		_save(kept[1], "%s-lead" % why, kept[2], extra, float(kept[0]))
	_ring.clear()
	_shoot(why, extra)


# One picture a moment: a frame asked for within NEAR_S of the last kept one shows the same
# screen, so only a hit or a death is kept that close.
func _shoot(why: String, extra := {}) -> void:
	if _t - _shot_at < NEAR_S and not (why.begins_with("hit-") or why.begins_with("death")):
		return
	_shot_at = _t
	_ask(why, extra, false)


# A page the player turned (the prologue's lines): the new page, once it has settled.
func page() -> void:
	_later(SETTLE_S, "page")


# Ask for this frame's picture; it is taken in _drawn, once the frame has been drawn.
func _ask(why: String, extra: Dictionary, into_ring: bool) -> void:
	_asked.append([why, extra, into_ring, _t, _truth()])
	RenderingServer.render_loop_enabled = true


func _drawn() -> void:
	if _asked.is_empty():
		return
	drawn += 1
	var picture: Image = _game.get_viewport().get_texture().get_image()
	for asked in _asked:
		if asked[2]:
			_ring.append([asked[3], picture, asked[4]])
			while _ring.size() > int(LEAD_S / RING_STEP_S):
				_ring.pop_front()
		else:
			_save(picture, asked[0], asked[4], asked[1], asked[3])
	_asked.clear()
	if not _live:
		RenderingServer.render_loop_enabled = false


func _save(picture: Image, why: String, truth: Dictionary, extra: Dictionary, at: float) -> void:
	if picture == null or picture.is_empty():
		return
	frames += 1
	var file := "%04d-%s.jpg" % [frames, why]
	if picture.save_jpg(_dir.path_join(file), QUALITY) != OK:
		return
	var row := {"t": snappedf(at, 0.01), "file": file, "why": why}
	row.merge(truth)
	row.merge(extra)
	_rows.store_line(JSON.stringify(row))
	_rows.flush()


# What the game knew at this frame: never shown to the reader.
func _truth() -> Dictionary:
	var run = _game.run
	var ball: Vector3 = _game.player.ball_position() if _game.player != null else Vector3.ZERO
	return {"flow": _game.flow.state_name(), "paused": _game.get_tree().paused, "stage": run.stage, "stage_s": snappedf(run.stage_time, 0.1),
		"plate": _plate_words(), "hp": snappedf(run.hp, 0.1), "hp_max": snappedf(run.max_hp, 0.1), "mass": snappedf(run.mass, 0.1),
		"pos": [snappedf(ball.x, 0.1), snappedf(ball.y, 0.1), snappedf(ball.z, 0.1)]}.merged(view_truth())


# Where the lens is, whether the ball is in the picture, what the arm reached and each ability
# slot's word: what a reader needs to say why a picture is jammed or a slot is grey.
func view_truth() -> Dictionary:
	var out := {"lens": null, "ball_on_screen": false, "arm": null, "slots": {}}
	var rig = _game.get("camera")
	if rig != null and rig.cam != null:
		var at: Vector3 = rig.cam.global_position
		out["lens"] = [snappedf(at.x, 0.1), snappedf(at.y, 0.1), snappedf(at.z, 0.1)]
		if _game.player != null:
			out["ball_on_screen"] = rig.shows(_game.player.ball_position())
		out["arm"] = rig.arm_reading()
	var bar = _game.hud.ability_bar if _game.hud != null else null
	if bar != null:
		var words: Dictionary = bar.slot_words()
		var abilities = _game.player.get("abilities") if _game.player != null else null
		for id in words:
			if words[id] == "unavailable" and abilities != null and abilities.silenced(id):
				words[id] = "jammed"
		out["slots"] = words
	return out


func _plate_words() -> String:
	if _game.hud == null or not _game.flow.in_play():
		return ""
	return String(_game.hud.objective_reading().get("words", ""))
