extends RefCounted


const AttackBudget := preload("res://src/combat/attack_budget.gd")

const NAMES := ["pack_damage", "damage", "packs_passive", "hide_pack_telegraphs", "rut", "drain", "fast_tax", "ringless", "scrap"]
const DRAIN_SHARE := 0.01
const FAST_TAX_SHARE := 0.02
const RINGLESS_SHARE := 0.05
const SCRAP_PER_S := 10.0
const SCRAP_EVERY_S := 10.0
const RUT_WINDOW_S := 10.0
const RUT_SPAN_M := 36.0
const RUT_SHARE := 0.05

var values := {}
var _wrapped := Callable()
var _game
var _driver
var _rut_trail: Array = []
var _rut_clock := 0.0
var _rut_stage := -1
var _tax_clock := 0.0
var _tax_stage := -1
var _drain_clock := 0.0
var _drain_stage := -1
var _ringless_stage := -1
var _scrap_clock := 0.0
var _scrap_stage := -1
var _hurt := false


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


func step() -> void:
	if values.has("rut"):
		_rut(float(values["rut"]))
	if values.has("drain"):
		_steady_drain(float(values["drain"]))
	if values.has("fast_tax"):
		_fast_tax(float(values["fast_tax"]))
	if values.has("ringless"):
		_ringless(float(values["ringless"]))
	if values.has("scrap"):
		_scrap_theft(float(values["scrap"]))
	if values.has("damage"):
		_wrap_damage(float(values["damage"]))
	if float(values.get("packs_passive", 0.0)) > 0.0:
		for node in _game.get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(node) and node != _game.flow.warden:
				AttackBudget.clock_out(node, 1.0)


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
		var armored: bool = run.armor_mode
		run.armor_mode = false
		run.damage(scale * RUT_SHARE * float(run.max_hp), "rut_plant")
		run.armor_mode = armored


func _drain(share: float, source: String) -> void:
	var run = _game.run
	var armored: bool = run.armor_mode
	run.armor_mode = false
	run.damage(share * float(run.max_hp), source)
	run.armor_mode = armored


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


func _scrap_theft(scale: float) -> void:
	var run = _game.run
	if run == null or not _game.flow.in_stage() or not run.alive() or not _after_first_hit():
		return
	if _scrap_stage != run.stage:
		_scrap_stage = run.stage
		_scrap_clock = float(run.stage_time)
	if float(run.stage_time) < _scrap_clock:
		return
	_scrap_clock += SCRAP_EVERY_S
	run.lose_scrap(maxi(1, roundi(scale * SCRAP_PER_S)), _game.player.ball_position(), "scrap_plant")


func _ringless(scale: float) -> void:
	var run = _game.run
	if run == null or _driver == null or not _game.flow.in_stage() or not run.alive():
		return
	if _ringless_stage != run.stage and _driver.contact_open():
		_ringless_stage = run.stage
		_drain(scale * RINGLESS_SHARE, "ringless_plant")
