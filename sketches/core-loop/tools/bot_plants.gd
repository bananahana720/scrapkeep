extends RefCounted

# Test-only plants for the anti-kiting gates' controls (card G-A; scrapkeep#241 comment 6367573974): a planted positive
# must read PASS and a held-out negative FAIL, or the gate is broken. Plants live in the bot tool layer only, behind
# `--plant=name=value[,name=value]` on tools/bot_run.gd; nothing ships. Without the flag no plant object exists, and
# bot_run touches nothing of it.
#
#   pack_damage=K          Pack damage to the ball x K: the mobs.damage_mult dial (src/core/challenge_dials.gd), set as a
#                          programmatic override, so the Warden, the vault and the Mind's hand keep their damage.
#   damage=K               Every hit on the ball x K, whatever its source: the run's defend_hook is wrapped to scale the
#                          hit before the set piece's own defence reads it. Used on one arm of an A/B control.
#   packs_passive=1        Pack units never commit an attack. Each tick every enemy but the Warden is clocked out of the
#                          attacker budget (attack_budget.gd clock_out), which is the gate every counter and Dispatcher
#                          chaser asks before an attack; and mobs.damage_mult is 0, so a unit that does not ask (a
#                          shooter) cannot hurt the ball either. The Warden still fights.
#   hide_pack_telegraphs=1 The driver cannot see the telegraphs of units other than the Warden (bot_driver.gd
#                          _hazards); the game still draws them.
#   rut=K                  A stand-in for the approved rut meter, gate 1's positive control: once a game second, a ball
#                          whose net flat travel over the last RUT_WINDOW_S is under RUT_SPAN_M (it is circling or
#                          shuttling over the same ground) takes K x RUT_SHARE of its max hull, through run.damage as
#                          source "rut_plant", so it counts as a hit; scrap armour is bypassed for it. Pack damage x4 could not make circling lose:
#                          the circling arm stalled to the cap on all six stages, on stage 2 without one hit.
#
#   drain=K                An untelegraphed drain, the telegraph-share number's positive control (fairness.telegraph_share):
#                          once a game second on a stage after the game's own first hit, whatever the ball is doing, it takes
#                          K x DRAIN_SHARE of its max hull, source "drain_plant". rut above does the same only to a ball that circles, which a skipper
#                          never does, so it cannot move the number on an ordinary run.
#   fast_tax=K             A stand-in for a world that taxes a rolling ball, the stop-against-move number's positive control
#                          (the bot record's fairness.stop_tax): once a game second, a ball at or above cruise speed takes
#                          K x FAST_TAX_SHARE of its max hull, source "fast_tax_plant", so the hull is lost while moving.
#   ringless=K             A pack that spawns with no arrival ring, the first-hit number's positive control (fairness.
#                          first_hit_s): the tick a stage's contact opens (bot_driver.contact_open), the ball takes K x
#                          RINGLESS_SHARE of its max hull, source "ringless_plant", as the ambush an unringed spawn would land.
#
# rut, drain, fast_tax and ringless drain the hull straight through run.damage, which is a hit that no telegraph announced, so
# they also move the telegraph share (fairness.telegraph_share) down.
#
# pack_damage and packs_passive both own mobs.damage_mult, so they cannot be combined.

const AttackBudget := preload("res://src/combat/attack_budget.gd")

const NAMES := ["pack_damage", "damage", "packs_passive", "hide_pack_telegraphs", "rut", "drain", "fast_tax", "ringless"]
const DRAIN_SHARE := 0.01
const FAST_TAX_SHARE := 0.02
const RINGLESS_SHARE := 0.05
const RUT_WINDOW_S := 10.0
# Wider than the orbit ring at the outer edge of its band (2 x (14 + 3) m), so a full lap never clears it.
const RUT_SPAN_M := 36.0
const RUT_SHARE := 0.05

var values := {}
var _wrapped := Callable()
var _game
var _driver
# rut: one flat ball position per game second, oldest first, and the stage they belong to.
var _rut_trail: Array = []
var _rut_clock := 0.0
var _rut_stage := -1
var _tax_clock := 0.0
var _tax_stage := -1
var _drain_clock := 0.0
var _drain_stage := -1
var _ringless_stage := -1
var _hurt := false


# "a=1,b=2" -> {a: 1.0, b: 2.0}. An error string in "error" when a name or a value is not accepted.
static func parse(text: String) -> Dictionary:
	var out := {}
	for pair in text.split(",", false):
		var eq := pair.find("=")
		if eq <= 0:
			return {"error": "'%s' is not name=value" % pair}
		var name := pair.substr(0, eq).strip_edges()
		var raw := pair.substr(eq + 1).strip_edges()
		if name not in NAMES:
			return {"error": "unknown plant '%s'; use %s" % [name, ", ".join(NAMES)]}
		if not raw.is_valid_float() or float(raw) < 0.0:
			return {"error": "plant %s needs a non-negative number, not '%s'" % [name, raw]}
		out[name] = float(raw)
	if out.has("pack_damage") and out.has("packs_passive"):
		return {"error": "pack_damage and packs_passive both set mobs.damage_mult"}
	if out.is_empty():
		return {"error": "--plant= names no plant"}
	return out


func attach(game, driver, planted: Dictionary) -> void:
	_game = game
	_driver = driver
	values = planted
	if values.has("pack_damage"):
		ChallengeDials.set_overrides({"mobs.damage_mult": float(values["pack_damage"])})
	if values.has("packs_passive") and float(values["packs_passive"]) > 0.0:
		ChallengeDials.set_overrides({"mobs.damage_mult": 0.0})
	if float(values.get("hide_pack_telegraphs", 0.0)) > 0.0:
		driver.hide_pack_telegraphs = true
	step()


# Once a tick, before the driver's. Idempotent.
func step() -> void:
	if values.has("rut"):
		_rut(float(values["rut"]))
	if values.has("drain"):
		_steady_drain(float(values["drain"]))
	if values.has("fast_tax"):
		_fast_tax(float(values["fast_tax"]))
	if values.has("ringless"):
		_ringless(float(values["ringless"]))
	if values.has("damage"):
		_wrap_damage(float(values["damage"]))
	if float(values.get("packs_passive", 0.0)) > 0.0:
		for node in _game.get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(node) and node != _game.flow.warden:
				AttackBudget.clock_out(node, 1.0)


# The ultimate re-sets the hook whenever it is rebuilt, so the wrap is checked every tick.
func _wrap_damage(scale: float) -> void:
	var run = _game.run
	if run == null or (_wrapped.is_valid() and run.defend_hook == _wrapped):
		return
	var previous: Callable = run.defend_hook
	_wrapped = func(amount: float, hp: float) -> float:
		return float(previous.call(amount * scale, hp)) if previous.is_valid() else amount * scale
	run.defend_hook = _wrapped


func _rut(scale: float) -> void:
	var run = _game.run
	if run == null or not _game.flow.in_stage() or not run.alive():
		return
	if _rut_stage != run.stage:
		_rut_stage = run.stage
		_rut_trail.clear()
		_rut_clock = float(run.stage_time)
	if float(run.stage_time) < _rut_clock:
		return
	_rut_clock += 1.0
	var ball: Vector3 = _game.player.ball_position()
	_rut_trail.append(Vector2(ball.x, ball.z))
	if _rut_trail.size() > int(RUT_WINDOW_S) + 1:
		_rut_trail.pop_front()
	if _rut_trail.size() <= int(RUT_WINDOW_S):
		return
	if (_rut_trail.back() as Vector2).distance_to(_rut_trail.front()) < RUT_SPAN_M:
		# The drain goes to the hull: scrap armour would absorb it and the circling ball picks the spill back up
		# (the pit, seed 1: 1,577 drained, 59 reached the hull).
		var armored: bool = run.armor_mode
		run.armor_mode = false
		run.damage(scale * RUT_SHARE * float(run.max_hp), "rut_plant")
		run.armor_mode = armored


# Hull straight off the ball, past scrap armour (armour would absorb it and the spill be picked back up).
func _drain(share: float, source: String) -> void:
	var run = _game.run
	var armored: bool = run.armor_mode
	run.armor_mode = false
	run.damage(share * float(run.max_hp), source)
	run.armor_mode = armored


# drain and fast_tax start with the first hit the game itself landed, so the first-hit reading stays the game's own.
func _after_first_hit() -> bool:
	var run = _game.run
	if run != null and float(run.hp) < float(run.max_hp) - 0.001:
		_hurt = true
	return _hurt


func _steady_drain(scale: float) -> void:
	var run = _game.run
	if run == null or not _game.flow.in_stage() or not run.alive() or not _after_first_hit():
		return
	if _drain_stage != run.stage:
		_drain_stage = run.stage
		_drain_clock = float(run.stage_time)
	if float(run.stage_time) < _drain_clock:
		return
	_drain_clock += 1.0
	_drain(scale * DRAIN_SHARE, "drain_plant")


func _fast_tax(scale: float) -> void:
	var run = _game.run
	if run == null or not _game.flow.in_stage() or not run.alive() or not _after_first_hit():
		return
	if _tax_stage != run.stage:
		_tax_stage = run.stage
		_tax_clock = float(run.stage_time)
	if float(run.stage_time) < _tax_clock:
		return
	_tax_clock += 1.0
	if _game.player.planar_velocity().length() >= _game.player.tuning.f("cruise"):
		_drain(scale * FAST_TAX_SHARE, "fast_tax_plant")


func _ringless(scale: float) -> void:
	var run = _game.run
	if run == null or _driver == null or not _game.flow.in_stage() or not run.alive():
		return
	if _ringless_stage != run.stage and _driver.contact_open():
		_ringless_stage = run.stage
		_drain(scale * RINGLESS_SHARE, "ringless_plant")
