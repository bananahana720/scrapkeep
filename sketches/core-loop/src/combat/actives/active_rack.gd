extends Node

const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")

# The active slot: one racked active on F (Bindings "active"), behind --actives (off by
# default). It holds charges that refill over time and from kills, so fighting feeds it,
# and while the ultimate meter sits full each kill banks one overflow piece for the next fire
# instead of throwing the points away ("Overpowered pays"). Combat owns this node
# (combat.actives); the HUD reads slot_record(); the field-lock unit ("Jam") calls lock().

const REFUSE_NONE := "empty"
const REFUSE_COOLING := "cooling"
const REFUSE_JAMMED := "jammed"

var ctx
var combat
var active_id := ""
var charges := 0
# 0 to 1 toward the next charge.
var progress := 0.0
# Overflow pieces banked for the next fire.
var bonus := 0
var fires := 0
var _locked := 0.0
# A big active's wind-up: seconds left, 0 when none is winding.
var winding := 0.0
var _granted := false
var _kinds := {}


func setup(context, owner_combat) -> void:
	ctx = context
	combat = owner_combat
	for id in ActiveDefs.ROWS:
		var kind = ActiveDefs.ROWS[id]["kind"].new()
		kind.setup(ctx, combat)
		_kinds[id] = kind
	ctx.events.run_started.connect(func(_class_id: String): reset())
	ctx.events.enemy_killed.connect(_on_killed)
	ctx.events.stage_content_cleared.connect(func(_reason: String): _clear_flight())
	ctx.events.player_died.connect(_clear_flight)


func enabled() -> bool:
	return ctx != null and ctx.tuning != null and ctx.tuning.option("actives") == "on"


func reset() -> void:
	active_id = ""
	charges = 0
	progress = 0.0
	bonus = 0
	fires = 0
	_locked = 0.0
	winding = 0.0
	_granted = false
	_clear_flight()


# Racks `id` full, replacing whatever was racked.
func rack(id: String) -> bool:
	if not ActiveDefs.ROWS.has(id):
		return false
	active_id = id
	charges = int(_row(id)["max_charges"])
	progress = 0.0
	return true


# An electric field's Jam: no fire for `seconds` (the longest lock wins). A wind-up in progress
# is cancelled and its charge refunded.
func lock(seconds: float) -> void:
	_locked = maxf(_locked, seconds)
	if winding > 0.0:
		winding = 0.0
		charges = mini(charges + 1, int(_row(active_id)["max_charges"]))
		if _kinds[active_id].has_method("cancel"):
			_kinds[active_id].cancel()


func locked() -> bool:
	return _locked > 0.0


func _physics_process(delta: float) -> void:
	if not enabled() or ctx.flow == null or not ctx.flow.in_play() or ctx.run.class_def == null:
		return
	if not _granted:
		_granted = true
		if active_id == "":
			rack(ActiveDefs.STARTER)
	_locked = maxf(0.0, _locked - delta)
	if active_id != "":
		_recharge(delta / float(_row(active_id)["recharge"]))
	for id in _kinds:
		_kinds[id].step(delta)
	if winding > 0.0:
		winding -= delta
		if winding <= 0.0:
			winding = 0.0
			_release()
	elif ctx.player.intent.active_pressed:
		press()


# The F press. Returns "" when it fired, else the refusal reason it announced.
func press() -> String:
	var reason := ""
	if active_id == "":
		reason = REFUSE_NONE
	elif winding > 0.0:
		reason = REFUSE_COOLING
	elif locked():
		reason = REFUSE_JAMMED
	elif charges < 1:
		reason = REFUSE_COOLING
	if reason != "":
		ctx.events.verb_failed.emit("active", reason, ctx.player.ball_position())
		return reason
	var row := _row(active_id)
	charges -= 1
	if float(row["windup"]) > 0.0:
		winding = float(row["windup"])
		if _kinds[active_id].has_method("begin"):
			_kinds[active_id].begin(self, row)
		return ""
	_release()
	return ""


func _release() -> void:
	var count: int = _kinds[active_id].fire(self, _row(active_id), bonus)
	bonus = 0
	fires += 1
	ctx.events.active_fired.emit(active_id, ctx.player.ball_position(), count)


func _recharge(amount: float) -> void:
	var cap := int(_row(active_id)["max_charges"])
	if charges >= cap:
		progress = 0.0
		return
	progress += amount
	while progress >= 1.0 and charges < cap:
		charges += 1
		progress -= 1.0
	if charges >= cap:
		progress = 0.0


func _on_killed(_kind: String, _at: Vector3, _scrap: int) -> void:
	if not enabled() or active_id == "" or not ctx.flow.in_play():
		return
	var row := _row(active_id)
	_recharge(float(row["kill_charge"]))
	var meter = ctx.player.abilities.meter if ctx.player != null and ctx.player.abilities != null else null
	if meter != null and meter.full():
		bonus = mini(bonus + 1, int(row["bonus_cap"]))


# The active's row; a test may override it to wind up an active that fires on the press.
func _row(id: String) -> Dictionary:
	return ActiveDefs.row(id)


func _clear_flight() -> void:
	winding = 0.0
	for id in _kinds:
		_kinds[id].clear()


# The bar's chip for the racked active, in AbilitySlots' record shape, or {} with none racked.
func slot_record() -> Dictionary:
	if not enabled() or active_id == "":
		return {}
	var row := _row(active_id)
	var cap := int(row["max_charges"])
	var state := "unavailable" if locked() else ("active" if winding > 0.0 else ("ready" if charges > 0 else "cooling"))
	return {"id": "active_" + active_id, "icon": "cat_damage", "key": "key_f", "group": "chip",
		"cooldown_frac": 0.0 if charges >= cap else clampf(1.0 - progress, 0.0, 1.0),
		"charges": charges, "max_charges": cap, "state": state, "gauge": 0.0, "bonus": bonus}
