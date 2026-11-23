extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Pattern := preload("res://src/combat/pattern.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Bolts := preload("res://src/combat/bolts.gd")
const Effects := preload("res://src/combat/effects.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Palette := preload("res://src/core/palette.gd")

# The visual-clarity caps under the heaviest stack a run can reach: spiral wave and two
# cross splits on the runner's laser, with every rate and range tier that makes bolts
# pile up. Held fire into open sky for SECONDS must never put more than
# Bolts.MAX_LIVE bolts on screen, must keep firing at full rate (the cap retires old
# bolts, it never stalls the trigger), and every draw-order rule that keeps our own
# effects under enemy telegraphs must hold.

const SECONDS := 3.0
const STACK := ["spiral_wave", "cross_split", "cross_split", "rate_tier", "rate_tier", "rate_tier", "range_tier", "range_tier"]

var _game
var _source := Intent.Scripted.new()
var _failures := 0
var _started := false
var _clock := 0.0
var _peak := 0
var _shots := 0
var _volley_sizes := {}


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	var combat = _game.ctx.spawner
	if not _started:
		_started = true
		_game.ctx.calm = true
		_game.player.source = _source
		_game.events.shot_fired.connect(func(_w: String, _f: Vector3, _t: Vector3):
			_shots += 1
			var size: int = combat.last_shot["bolts"]
			_volley_sizes[size] = _volley_sizes.get(size, 0) + 1)
		_game.flow.press_start()
		_game.flow.choose_class(1)
		_game.run.set_max_hp(99999.0)
		for part in STACK:
			_game.run.add_part(part, "test")
		# Cap test saturates Bolts.MAX_LIVE via continuous hold_auto volley stress (PILOT-CADENCE §4).
		combat._patterns[Weapons.RAPID_LASER].trigger = Pattern.TRIGGER_HOLD_AUTO
		_source.hold = {"fire_held": true}
		return false
	# Look up into open sky so every bolt flies its full range.
	_game.camera.pitch = 0.45
	_clock += delta
	_peak = maxi(_peak, combat.live_projectiles())
	if _clock < SECONDS:
		return false
	_source.hold = {}
	var p: Resource = combat.pattern(Weapons.RAPID_LASER)
	var lifetime: float = p.range_m / p.speed
	var uncapped := int(p.rate * p.volley_size() * lifetime)
	_report("stack", p.volley_size() == 9 and p.rate <= Pattern.MAX_RATE,
		"spiral + 2 cross + 3 rate + 2 range: %d bolts a volley, %.1f volleys/s, %.2f s flight; uncapped that is ~%d live"
			% [p.volley_size(), p.rate, lifetime, uncapped])
	_report("cap", _peak <= Bolts.MAX_LIVE and combat.bolts.peak_live <= Bolts.MAX_LIVE and uncapped > Bolts.MAX_LIVE,
		"peak live player bolts %d over %.0f s of held fire (cap %d)" % [_peak, SECONDS, Bolts.MAX_LIVE])
	_report("retire", combat.bolts.retired > 0, "the cap retired %d of the oldest bolts instead of refusing new ones" % combat.bolts.retired)
	var expected := int(p.rate * SECONDS)
	_report("rate", _shots >= expected - 3, "%d volleys in %.0f s at %.1f/s (needs >= %d): the cap never stalls the trigger"
		% [_shots, SECONDS, p.rate, expected - 3])
	_report("volley", _volley_sizes.keys().size() == 1 and _volley_sizes.has(9), "volley sizes seen %s" % [_volley_sizes])

	var order_ok := Bolts.PRIORITY < Telegraph.PRIORITY and Effects.PRIORITY < Telegraph.PRIORITY
	var tele_mat := Telegraph.material(0.5)
	_report("draw_order", order_ok and tele_mat.no_depth_test and tele_mat.render_priority == Telegraph.PRIORITY,
		"bolts draw at %d and effects at %d, under telegraphs at %d with no depth test"
			% [Bolts.PRIORITY, Effects.PRIORITY, Telegraph.PRIORITY])
	var faded := Bolts.crowd_alpha(Bolts.MAX_LIVE)
	_report("crowd_fade", faded < Bolts.crowd_alpha(4) and faded >= Bolts.ALPHA_CROWDED,
		"bolt alpha %.2f alone, %.2f at the cap" % [Bolts.crowd_alpha(4), faded])
	var no_hazard := true
	for weapon in Weapons.ALL:
		no_hazard = no_hazard and Weapons.color(weapon) != Palette.HAZARD
	_report("colour", no_hazard, "no player weapon draws in HAZARD, the telegraph colour")
	var ok := _failures == 0
	print("combat_cap_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true
