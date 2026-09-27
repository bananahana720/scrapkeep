extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Warden := preload("res://src/combat/warden.gd")

# Shred (Andrew, 2026-09-27): every landed hit strips plating for a while, in
# proportion to its punch, and the strips stack and bleed off. Through the live game
# with held runner fire on Warden III's body from 14 m, in simulated seconds:
# 1. Skipper floor. The base kit's fire (7 damage, 12 a second, no parts) for
#    SKIPPER_SECONDS never takes Warden III's plating to its bolt damage or below.
# 2. Engaged. With the power curve's engaged parts, the same fire strips a fresh
#    Warden III to its bolt damage or below in ENGAGED_MIN to ENGAGED_MAX seconds.
# 3. HUD. Every tick of that fire, plating_of reads base minus shred, flow's
#    warden_plating() matches it, and the objective line's plating number drops.
# 4. Decay. Fire stops, and shred is back to 0 within DECAY_MAX seconds.
# 5. Synergy and weak points. A synergy strike shreds by its punch; a weak point that
#    reads 0 stays 0 under shred.
# 6. Brindle. The real boss module's hull sheds by the same path, and its crane magnet
#    (0 to a weapon) stays 0.
# 7. Vault. A stage-3 vault is plated above stage 3's Warden, and it sheds too.

const ENGAGED := ["hot_rivets", "cross_split", "loose_trigger", "slag_rounds", "double_feed",
	"spiral_wave", "frost_vane", "chain_arc", "focus_lens", "sunforged_core", "rime_heart", "gatling_heart", "horizon_optic"]
const STAND_OFF := 14.0
const SKIPPER_SECONDS := 20.0
const ENGAGED_MIN := 4.0
const ENGAGED_MAX := 8.0
const DECAY_MAX := 8.0
const BRINDLE_HITS := 20

var _game
var _combat
var _source := Intent.Scripted.new()
var _failures := 0
var _phase := "setup"
var _sim := 0.0
var _wait := 0
var _warden: Node3D
var _anchor := Vector3.ZERO
var _hits := 0
var _min_plating := INF
var _max_shred := 0.0
var _bolt := 0.0
var _stripped_at := -1.0
var _hud_ticks := 0
var _hud_bad := 0
var _hud_first := ""
var _objective_before := ""
var _objective_after := ""
var _seams_skipper := -1
var _seams_stripped := -1


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
	match _phase:
		"setup":
			_setup()
			if not _combat.has_method("shred_of"):
				_report("api", false, "combat has no shred_of(enemy)")
				return _finish()
			_start_fire("skipper")
		"skipper":
			_sim += delta
			_hold()
			_min_plating = minf(_min_plating, _warden.plating - _combat.shred_of(_warden))
			_max_shred = maxf(_max_shred, _combat.shred_of(_warden))
			if _sim >= SKIPPER_SECONDS:
				_report("skipper_floor", _hits > 100 and _max_shred >= 1.0 and _min_plating > _bolt,
					"base runner fire (%.1f damage) for %.0f s, %d hits on Warden III (plating %.0f): shred peaked at %.1f (needs 1+, chips strip too), plating never below %.1f (needs above %.1f)"
						% [_bolt, SKIPPER_SECONDS, _hits, _warden.plating, _max_shred, _min_plating, _bolt])
				_seams_skipper = _lit_seams()
				_check_synergy()
				for part in ENGAGED:
					_game.run.add_part(part, "test")
				_warden = _enter_stage_3()
				_start_fire("engaged")
		"engaged":
			_sim += delta
			_hold()
			_check_hud()
			var plating: float = _combat.plating_of(_warden)
			if _stripped_at < 0.0 and plating <= _bolt:
				_stripped_at = _sim
				_seams_stripped = _lit_seams()
				_objective_after = _game.flow.objective_text()
			if _stripped_at >= 0.0 or _sim > ENGAGED_MAX + 4.0:
				_report("engaged", _stripped_at >= ENGAGED_MIN and _stripped_at <= ENGAGED_MAX,
					"engaged build (%.1f damage x %d bolts at %.0f a second) stripped Warden III from %.0f to %.1f, at or below its bolt, after %s (needs %.0f to %.0f s)"
						% [_bolt, _combat.last_shot.get("bolts", 0), _combat._rate(_combat.active_weapon()), _warden.plating, plating,
							("%.2f s" % _stripped_at) if _stripped_at >= 0.0 else "never", ENGAGED_MIN, ENGAGED_MAX])
				_report("hud", _hud_ticks > 30 and _hud_bad == 0 and _objective_before.contains("plating %d" % int(_warden.plating))
						and _objective_after.contains("plating %d" % int(_combat.plating_of(_warden))) and _objective_after != _objective_before,
					"%d ticks: plating_of = max(0, base - shred) and flow.warden_plating() matched it on %d (mismatches %d%s); objective '%s' became '%s'"
						% [_hud_ticks, _hud_ticks - _hud_bad, _hud_bad, _hud_first, _objective_before, _objective_after])
				_report("seams", _seams_skipper == 0 and _seams_stripped > 0,
					"glowing seams on the jaws: %d lit at the skipper's %.0f%% strip, %d lit at the engaged %.0f%% strip (needs 0, then some)"
						% [_seams_skipper, 100.0 * _max_shred / _warden.plating, _seams_stripped, 100.0 * _warden.shred_fraction()])
				_source.hold = {}
				_max_shred = _combat.shred_of(_warden)
				_phase = "decay"
				_sim = 0.0
		"decay":
			_sim += delta
			_game.player.reset_to(_anchor)
			if _combat.shred_of(_warden) <= 0.0 or _sim > DECAY_MAX + 4.0:
				var back: bool = _combat.shred_of(_warden) <= 0.0 and _combat.plating_of(_warden) == _warden.plating
				_report("decay", back and _sim <= DECAY_MAX,
					"fire stopped at shred %.1f; shred reached 0 after %.2f s and plating_of read %.0f again (needs within %.0f s)"
						% [_max_shred, _sim, _combat.plating_of(_warden), DECAY_MAX])
				_check_vault()
				_game.flow.enter_boss(Vector3.ZERO)
				_phase = "boss"
				_wait = 0
		"boss":
			_wait += 1
			if _wait == 10:
				_check_brindle()
				return _finish()
	return false


func _setup() -> void:
	_combat = _game.ctx.spawner
	var ctx = _game.ctx
	ctx.calm = true
	ctx._hit_stop = Callable()
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.flow.force_warden = true
	_game.events.enemy_struck.connect(func(enemy: Node3D, _kind: String, _force: float):
		if enemy == _warden:
			_hits += 1)
	_warden = _enter_stage_3()


# A fresh stage-3 entry seals it with flow's own Warden, the one the objective line reads.
func _enter_stage_3() -> Node3D:
	_game.flow.enter_stage(3, Vector3.ZERO, false)
	_game.run.set_max_hp(99999.0)
	return _game.flow.warden


func _start_fire(phase: String) -> void:
	var ctx = _game.ctx
	var heading: Vector3 = ctx.terrain.entry_heading(3)
	_anchor = _warden.global_position - heading * STAND_OFF
	_anchor.y = ctx.terrain.height(_anchor.x, _anchor.z) + 1.05
	_game.player.reset_to(_anchor)
	_game.player.body().global_position = _anchor
	var weapon: String = _combat.active_weapon()
	_bolt = _combat.pattern(weapon).damage * _combat._damage_mod(weapon)
	_objective_before = _game.flow.objective_text()
	_source.hold = {"fire_held": true}
	_hits = 0
	_phase = phase
	_sim = 0.0


func _hold() -> void:
	_game.player.reset_to(_anchor)
	var cam = _game.camera
	var d: Vector3 = (_warden.global_position - cam.aim_origin()).normalized()
	cam.yaw = atan2(-d.x, -d.z)
	cam.pitch = clampf(asin(d.y), -1.25, 0.55)


# Seam strokes the Warden's look is drawing; they are MeshInstance3D, never colliders.
func _lit_seams() -> int:
	var lit := 0
	for level in _warden._look._seams:
		for seam in level:
			if (seam as MeshInstance3D).visible:
				lit += 1
	return lit


func _check_hud() -> void:
	if _warden.unplated_by_magnet():
		return
	_hud_ticks += 1
	var want := maxf(0.0, _warden.plating - _combat.shred_of(_warden))
	var got: float = _combat.plating_of(_warden)
	var flow: float = _game.flow.warden_plating()
	if absf(got - want) > 0.001 or absf(flow - got) > 0.001:
		_hud_bad += 1
		if _hud_first == "":
			_hud_first = "; first at %.2f s: want %.2f, plating_of %.2f, flow %.2f" % [_sim, want, got, flow]


# A synergy strike on the skipper's Warden: shred rises by its punch times the rate.
# The stage-3 magnet reads 0 to a weapon while it tugs; forced into the tug here, it
# must still read 0 with the body shredded, and the body must read base minus shred.
func _check_synergy() -> void:
	var before: float = _combat.shred_of(_warden)
	_combat.strike(_warden, "synergy", 60.0)
	var gained: float = _combat.shred_of(_warden) - before
	_report("synergy", gained > 0.0 and absf(gained - 60.0 * _combat.SHRED_PER_PUNCH) < 0.01,
		"a synergy strike of punch 60 added %.3f shred (needs 60 x %.4f = %.3f)" % [gained, _combat.SHRED_PER_PUNCH, 60.0 * _combat.SHRED_PER_PUNCH])
	_warden.magnet_state = Warden.Magnet.TUG
	var weak: Dictionary = _combat.resolve(_warden, "runner", 7.0, "magnet")
	var body: Dictionary = _combat.resolve(_warden, "runner", 7.0)
	_warden.magnet_state = Warden.Magnet.IDLE
	var shred: float = _combat.shred_of(_warden)
	_report("weak_point", weak["plating"] == 0.0 and absf(body["plating"] - (_warden.plating - shred)) < 0.001,
		"with shred %.1f the tugging magnet met plating %.1f (needs 0) and the body %.1f (needs %.1f)"
			% [shred, weak["plating"], body["plating"], _warden.plating - shred])


func _check_vault() -> void:
	var ctx = _game.ctx
	var at: Vector3 = ctx.terrain.beacon_point(3) + Vector3(30.0, 0.0, 30.0)
	var vault: Node3D = ctx.spawner.spawn_enemy("vault", at)
	var base: float = vault.plating
	var warden_plating: float = _warden.plating
	for i in 10:
		_combat.strike(vault, "runner", 20.0)
	var shred: float = _combat.shred_of(vault)
	_report("vault", base > warden_plating and shred > 0.0 and absf(_combat.plating_of(vault) - (base - shred)) < 0.001,
		"stage-3 vault plating %.0f above Warden III's %.0f; ten 20-damage hits shredded %.1f, plating_of %.1f"
			% [base, warden_plating, shred, _combat.plating_of(vault)])
	vault.free()


func _check_brindle() -> void:
	var boss = _game.ctx.get("boss")
	if boss == null or boss.ship == null or not is_instance_valid(boss.ship.hull):
		_report("brindle", false, "no real boss hull after enter_boss")
		return
	var hull: Node3D = boss.ship.hull
	var base: float = hull.plating_now()
	for i in BRINDLE_HITS:
		_combat.strike(hull, "runner", 16.0)
	var shred: float = _combat.shred_of(hull)
	var met: Dictionary = _combat.resolve(hull, "runner", 16.0)
	_report("brindle", shred > 0.0 and absf(met["plating"] - maxf(0.0, base - shred)) < 0.001
			and absf(_combat.plating_of(hull) - maxf(0.0, base - shred)) < 0.001,
		"real boss hull (plating %.0f) after %d 16-damage hits: shred %.1f, resolve met %.1f, plating_of %.1f"
			% [base, BRINDLE_HITS, shred, met["plating"], _combat.plating_of(hull)])
	var magnet: Node3D = boss.ship.magnets[0]
	for i in BRINDLE_HITS:
		_combat.strike(magnet, "runner", 16.0)
	var weak: Dictionary = _combat.resolve(magnet, "runner", 16.0)
	_report("brindle_weak", weak["plating"] == 0.0,
		"crane magnet after %d hits (shred %.1f) meets a weapon at plating %.1f (needs 0)" % [BRINDLE_HITS, _combat.shred_of(magnet), weak["plating"]])


func _finish() -> bool:
	_source.hold = {}
	var ok := _failures == 0
	print("combat_shred_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true
