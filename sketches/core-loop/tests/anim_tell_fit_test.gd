extends SceneTree
# Tell-fit gate (Animation lane unit A4; AMBITION-BRIEF "Rigs and motion"). A baked clip that the
# game plays as the tell of a committed telegraph must fit the window it is cued for. Every window below is read from
# the game constant that commits it, every length from the real GLB (Animation.length), every
# blend from the table the game plays with; nothing is retyped here except the 0.6 s floor.
#
# Rules
#   covers : clip length >= window. A clip that ends before its window leaves the telegraph
#            unanimated (the pose holds its last key, or the loop restarts mid-tell).
#   fits   : clip length <= window, for tells authored to end exactly on the strike
#            (brindle_animation.py:18-21 gives crane_warn and charge_warn (1.4, 1.4): duration and
#            key-pose second are the same). The Warden and Waking pulse_warn are 2.0 s = the
#            telegraph. Not asserted for the swarm `pulse` (charge then slam, hero_assets.gd:46-47)
#            or the kill-first tells (authored to their SOUND, kill_first_motion.py header).
#   peak   : blend <= window - TELL_FLOOR, for the boss tables only (BossModel.BLENDS; not the
#            Wardens, see _wardens). A clip eases in over its blend (BossModel.play,
#            boss_model.gd:182), so the tell only reads at
#            full weight once the blend is over; that must leave at least TELL_FLOOR before the
#            strike. TELL_FLOOR is 0.6 s: "Every lethal attack has a readable tell of at least 0.6 s"
#            (project-guide/handoff/DECISIONS.md:146, section 5 Enemies and difficulty).
#   key    : slag_warn is 9 s (2.5 s warn + 6 s live, brindle_animation.py:15,20,160); its
#            key pose must land on SLAG_WARN, so the SlagThroat track must have a key there.
#
# Windows are the BASE constants. ChallengeDials.tell (boss.gd:587) can shorten a boss window at
# runtime and BossModel.play(speed) stretches the clip to follow; that is outside this gate.
#
# KNOWN is every mismatch measured on base 20da407 (2026-10-21), with the unit that owns the fix.
# A KNOWN row must still fail: if the fix lands and the row stays, the test fails as stale, so
# the table only shrinks. A KNOWN key that no check visited also fails.

const T := preload("res://tests/support/t.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const BossModel := preload("res://src/boss/boss_model.gd")
const WakingBoss := preload("res://src/boss/waking.gd")
const WakingDress := preload("res://src/boss/waking_dress.gd")
const WardenCls := preload("res://src/combat/warden.gd")
const ForemanCls := preload("res://src/combat/foreman.gd")
const DispatcherCls := preload("res://src/combat/dispatcher.gd")
const SplitterCls := preload("res://src/combat/splitter.gd")
const WardenDress := preload("res://src/presentation/warden_dress.gd")

const M := "res://assets/models/"
const TELL_FLOOR := 0.6
# Float32 lengths (1.39999997615814 for 1.4) and 30 fps key times: a millisecond is far below a frame.
const EPS := 0.001

# id -> measured cause and owner. Ids are "<glb stem> <clip> <rule>".
const KNOWN := {
	# Dispatcher: the sim commits the drop WARN = SUCK + FLIGHT = 1.2 s (dispatcher.gd:49-53) but
	# the `tell` clip is 1.0 s (kill_first_motion.py:11-13 "tell 1.0": authored to the sound).
	# Owner: A6 Dispatcher tell retime (wave 19, proposed on #241).
	"enemy_dispatcher tell covers": "A6 Dispatcher tell retime: clip 1.0 s < WARN 1.2 s; kill_first_motion.py header",
}

var t := T.new("anim_tell_fit_test")
var _seen := {}
var _held: Array = []
var _players := {}


func _initialize() -> void:
	_run.call_deferred()


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null


func _player(path: String) -> AnimationPlayer:
	if _players.has(path):
		return _players[path]
	var res := load(path)
	var player: AnimationPlayer = null
	if res is PackedScene:
		var inst: Node = (res as PackedScene).instantiate()
		_held.append(inst)
		player = _find_player(inst)
	_players[path] = player
	return player


func _clip(path: String, clip: String) -> Animation:
	var p := _player(path)
	if p == null or not p.has_animation(clip):
		return null
	return p.get_animation(clip)


# One gated fact. A KNOWN id must fail; any other must pass.
func _gate(id: String, ok: bool, detail: String) -> void:
	if KNOWN.has(id):
		_seen[id] = true
		t.check(id + " (KNOWN mismatch, remove the row once fixed)", not ok, "%s | %s" % [KNOWN[id], detail])
	else:
		t.check(id, ok, detail)


static func covers(length: float, window: float) -> bool:
	return length >= window - EPS


static func fits(length: float, window: float) -> bool:
	return length <= window + EPS


static func peak_readable(blend: float, window: float) -> bool:
	return blend <= window - TELL_FLOOR + EPS


# Rows: [glb, clip, window, source of the window, rules]. `rules` is a subset of covers, fits.
func _tell(glb: String, clip: String, window: float, source: String, rules: Array) -> void:
	var stem := glb.get_file().get_basename()
	var anim := _clip(glb, clip)
	if not t.check("%s has clip %s" % [stem, clip], anim != null, glb):
		return
	print("TELLFIT %s %s clip=%.3f s window=%.3f s (%s)" % [stem, clip, anim.length, window, source])
	if "covers" in rules:
		_gate("%s %s covers" % [stem, clip], covers(anim.length, window), "clip %.3f vs window %.3f (%s)" % [anim.length, window, source])
	if "fits" in rules:
		_gate("%s %s fits" % [stem, clip], fits(anim.length, window), "clip %.3f vs window %.3f (%s)" % [anim.length, window, source])


func _peak(stem: String, clip: String, blend: float, window: float, source: String) -> void:
	print("TELLFIT %s %s blend=%.3f s window=%.3f s latest-blend=%.3f s (%s)" % [stem, clip, blend, window, window - TELL_FLOOR, source])
	_gate("%s %s peak" % [stem, clip], peak_readable(blend, window),
		"blend %.2f s leaves %.2f s of full-weight tell, floor %.1f s (%s)" % [blend, window - blend, TELL_FLOOR, source])


func _run() -> void:
	_controls()
	_brindle()
	_wardens()
	_waking()
	_kill_first()
	for id in KNOWN:
		t.check("KNOWN row was checked: " + id, _seen.has(id), "a KNOWN id no check visited is stale")
	for inst in _held:
		inst.free()
	quit(t.verdict())


# Positive controls: the rules must flag a planted bad pair and pass a good one.
func _controls() -> void:
	t.check("control: covers flags a clip shorter than its window", not covers(1.0, 1.2))
	t.check("control: covers passes a clip equal to its window (float32 length)", covers(1.39999997615814, 1.4))
	t.check("control: fits flags a clip longer than its window", not fits(2.4, 2.0))
	t.check("control: peak flags a blend as long as the window", not peak_readable(2.0, 2.0))
	t.check("control: peak passes a 0.1 s blend in a 2.0 s window", peak_readable(0.1, 2.0))
	t.check("control: peak passes a blend that leaves exactly the floor", peak_readable(1.4, 2.0))


# Brindle (boss_brindle.glb). boss_rules.gd windows; clips cued by boss.gd (ship.cue, :591).
func _brindle() -> void:
	var b := M + "bosses/boss_brindle.glb"
	_tell(b, "crane_warn", Rules.CRANE_WARN, "boss_rules.gd:48 CRANE_WARN", ["covers", "fits"])
	_tell(b, "charge_warn", Rules.CHARGE_WARN, "boss_rules.gd:92 CHARGE_WARN", ["covers", "fits"])
	_tell(b, "drone_deploy", Rules.DRONE_WARN, "boss_rules.gd:84 DRONE_WARN", ["covers", "fits"])
	_tell(b, "slag_warn", Rules.SLAG_WARN, "boss_rules.gd:69 SLAG_WARN, 9 s clip = warn + live", ["covers"])
	# key: the throat reaches its held pose on SLAG_WARN (brindle_animation.py:20,157: keyed 0 ->
	# up .25 at 2.5 -> held to 8.5). The importer resamples, so read the pose, not a key: it must be
	# within a millimetre of the held value at SLAG_WARN and still well short of it (over 1 cm) halfway there.
	var slag := _clip(b, "slag_warn")
	if slag != null:
		var track := -1
		for i in slag.get_track_count():
			if String(slag.track_get_path(i)).ends_with("SlagThroat") and slag.track_get_type(i) == Animation.TYPE_POSITION_3D:
				track = i
		if t.check("slag_warn has a SlagThroat position track", track >= 0):
			var held: Vector3 = slag.position_track_interpolate(track, Rules.SLAG_WARN + Rules.SLAG_LIVE / 2.0)
			var at_warn: Vector3 = slag.position_track_interpolate(track, Rules.SLAG_WARN)
			var before: Vector3 = slag.position_track_interpolate(track, Rules.SLAG_WARN / 2.0)
			_gate("boss_brindle slag_warn key", at_warn.distance_to(held) <= EPS and before.distance_to(held) > 0.01,
				"throat %.4f m from its held pose at SLAG_WARN %.1f s, %.4f m at half" % [at_warn.distance_to(held), Rules.SLAG_WARN, before.distance_to(held)])
		_gate("boss_brindle slag_warn live", covers(slag.length, Rules.SLAG_WARN + Rules.SLAG_LIVE - EPS),
			"clip %.1f s holds warn + SLAG_LIVE %.1f s (boss_rules.gd:70)" % [slag.length, Rules.SLAG_WARN + Rules.SLAG_LIVE])
	_peak("boss_brindle", "crane_warn", BossModel.blend_for("crane_warn"), Rules.CRANE_WARN, "boss_model.gd:158 BLENDS")
	_peak("boss_brindle", "charge_warn", BossModel.blend_for("charge_warn"), Rules.CHARGE_WARN, "boss_model.gd:158 BLENDS")
	_peak("boss_brindle", "slag_warn", BossModel.blend_for("slag_warn"), Rules.SLAG_WARN, "boss_model.gd:158 BLENDS")
	_peak("boss_brindle", "drone_deploy", BossModel.blend_for("drone_deploy"), Rules.DRONE_WARN, "boss_model.gd:158 BLENDS")


# Wardens: the charge clip warden_dress.gd BODY_CHARGE plays against PULSE_TELEGRAPH.
func _wardens() -> void:
	var window: float = WardenCls.PULSE_TELEGRAPH
	for kind in WardenDress.BODY_CHARGE:
		var clip: String = WardenDress.BODY_CHARGE[kind]
		var glb: String = WardenDress.BODIES[kind]["body"] if WardenDress.BODIES.has(kind) else ""
		if not t.check("%s has a body GLB in WardenDress.BODIES" % kind, glb != "", kind):
			continue
		# The swarm's `pulse` is the 2.0 s charge then the 0.4 s slam (hero_assets.gd:46-47), so
		# it covers the telegraph but is longer than it.
		_tell(glb, clip, window, "warden.gd:71 PULSE_TELEGRAPH", ["covers"] if kind == "swarm" else ["covers", "fits"])
		# No blend rule for the Wardens (coordinator ruling): a blend as long as the telegraph
		# still has the body near peak displacement 0.6 s before the strike (measured on the Mind,
		# 91% vs 82% at blend 0.5); unit A2 owns that read with a displacement test.


# Waking (boss_waking_base.glb, boss_waking_kit.glb): waking_dress.gd plays pulse_warn on the
# Warden's charge (:113-117) and FLOOR_CLIPS on the floor drop (:17, :119-125).
func _waking() -> void:
	for glb in [M + "bosses/boss_waking_base.glb", M + "bosses/boss_waking_kit.glb"]:
		_tell(glb, "pulse_warn", WardenCls.PULSE_TELEGRAPH, "warden.gd:71 PULSE_TELEGRAPH", ["covers", "fits"])
		for pair in WakingDress.FLOOR_CLIPS:
			_tell(glb, pair[0], WakingBoss.FLOOR_WARN, "waking.gd:31 FLOOR_WARN", ["covers", "fits"])
	_peak("boss_waking", "pulse_warn", BossModel.blend_for("pulse_warn"), WardenCls.PULSE_TELEGRAPH, "boss_model.gd:159 BLENDS")
	for pair in WakingDress.FLOOR_CLIPS:
		_peak("boss_waking", pair[0], BossModel.blend_for(pair[0]), WakingBoss.FLOOR_WARN, "boss_model.gd:160 BLENDS")


# Kill-first specials: the tell clip covers the sim's lead. The clips are authored to their
# SOUND (kill_first_motion.py header), so only `covers` is a rule; the pairs are printed.
func _kill_first() -> void:
	_tell(M + "world_one/enemy_foreman.glb", "tell", ForemanCls.HORN_LEAD, "foreman.gd:33 HORN_LEAD", ["covers"])
	_tell(M + "world_one/enemy_dispatcher.glb", "tell", DispatcherCls.WARN, "dispatcher.gd:53 WARN = SUCK + FLIGHT", ["covers"])
	_tell(M + "world_one/enemy_splitter.glb", "tell", SplitterCls.POP_DELAY, "splitter.gd:52 POP_DELAY", ["covers"])
