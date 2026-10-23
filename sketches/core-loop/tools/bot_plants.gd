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
#
# pack_damage and packs_passive both own mobs.damage_mult, so they cannot be combined.

const AttackBudget := preload("res://src/combat/attack_budget.gd")

const NAMES := ["pack_damage", "damage", "packs_passive", "hide_pack_telegraphs"]

var values := {}
var _wrapped := Callable()
var _game
var _driver


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
