extends Node

const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")
const ActiveOffers := preload("res://src/combat/actives/active_offers.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Palette := preload("res://src/core/palette.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")

# The active slot: one racked active on F (Bindings "active"), behind --actives (off by
# default). It holds charges that refill over time and from kills, so fighting feeds it,
# and while the ultimate meter sits full each kill banks one overflow piece for the next fire
# instead of throwing the points away ("Overpowered pays"). Combat owns this node
# (combat.actives); the HUD reads slot_record(); the field-lock unit ("Jam") calls lock().

const REFUSE_NONE := "empty"
const REFUSE_COOLING := "cooling"
const REFUSE_JAMMED := "jammed"
# A dropped active racks again when the ball rolls within PICKUP of it, once the ball has first
# been REARM away from it, so the drop under the ball never swaps straight back.
const PICKUP := 2.5
const REARM := 4.0

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
# Actives dropped by a swap, lying where the ball stood: {id, charges, progress, at, armed, node}.
var dropped: Array = []
# The rack as the current attempt began (a stage, or an arena), so a retry rewinds it with the
# run's parts and cogs: {id, charges, progress, bonus, granted}.
var _saved := {}


func setup(context, owner_combat) -> void:
	ctx = context
	combat = owner_combat
	for id in ActiveDefs.ROWS:
		var kind = ActiveDefs.ROWS[id]["kind"].new()
		kind.setup(ctx, combat)
		_kinds[id] = kind
	ctx.events.run_started.connect(func(_class_id: String): reset())
	ctx.events.enemy_killed.connect(_on_killed)
	ctx.events.stage_content_cleared.connect(func(reason: String):
		_clear_flight()
		_clear_dropped()
		_attempt(reason == "arena_retry"))
	ctx.events.stage_entered.connect(func(_stage: int, retry: bool):
		_clear_dropped()
		_attempt(retry))
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
	_saved = {}
	_clear_flight()
	_clear_dropped()


# Racks `id`, replacing whatever was racked. Arrives full unless `fill` is false (the opening starter).
func rack(id: String, fill := true) -> bool:
	if _row(id).is_empty():
		return false
	active_id = id
	charges = int(_row(id)["max_charges"]) if fill else 0
	progress = 0.0
	return true


# Takes an offered active (a gate, the vault or Moss's shelf, by its offer id or its active id):
# racks it full, and the active it replaces drops at `at` keeping its charges, so rolling back
# over it swaps again without a free refill. A drop lasts the stage; a gate launches the ball on,
# so taking a gate's active leaves the old one behind for good. False when it is not an active or
# already racked.
func take(id: String, at: Vector3) -> bool:
	var new_id := ActiveOffers.active_of(id) if ActiveOffers.is_offer(id) else id
	if new_id == active_id or _row(new_id).is_empty():
		return false
	_cancel_windup()
	var old := {"id": active_id, "charges": charges, "progress": progress}
	rack(new_id)
	_granted = true
	if old["id"] != "":
		_drop(old, at)
	return true


# Every active a draw may offer; a test may add rows.
func rows() -> Dictionary:
	return ActiveDefs.ROWS


# The actives this run already holds, racked or lying dropped: a draw never offers them.
func held() -> Array:
	var out: Array = [active_id] if active_id != "" else []
	for entry in dropped:
		out.append(entry["id"])
	return out


# A fresh attempt saves the rack; a retry rewinds it to that save, as run_state rewinds the
# parts and cogs that paid for what it racked.
func _attempt(retry: bool) -> void:
	if not retry:
		_saved = {"id": active_id, "charges": charges, "progress": progress, "bonus": bonus, "granted": _granted}
		return
	if _saved.is_empty():
		return
	_cancel_windup()
	active_id = _saved["id"]
	charges = _saved["charges"]
	progress = _saved["progress"]
	bonus = _saved["bonus"]
	_granted = _saved["granted"]


func row_of(id: String) -> Dictionary:
	return _row(id)


# An electric field's Jam: no fire for `seconds` (the longest lock wins). A wind-up in progress
# is cancelled and its charge refunded.
func lock(seconds: float) -> void:
	_locked = maxf(_locked, seconds)
	_cancel_windup()


# A wind-up in progress stops and refunds its charge.
func _cancel_windup() -> void:
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
			rack(ActiveDefs.STARTER, false)
	_locked = maxf(0.0, _locked - delta)
	if active_id != "":
		# Cell Bracket panels raise the recharge rate (the build's active_recharge mod).
		var rate: float = ctx.tuning.mod("active_recharge") if ctx.tuning != null else 1.0
		_recharge(delta * rate / float(_row(active_id)["recharge"]))
	for id in _kinds:
		_kinds[id].step(delta)
	_step_dropped(delta)
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
	var row := _row(active_id)
	var count: int = _kinds[active_id].fire(self, row, bonus)
	# Open Frame (the Highdraft Roosts set, maker_sets.gd): an active fired in the air fires twice.
	if ctx.build != null and ctx.build.has_method("maker_fires_twice") and ctx.build.maker_fires_twice():
		count += int(_kinds[active_id].fire(self, row, bonus))
	if bonus > 0: ctx.events.overflow_cashed.emit(active_id, bonus)
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


func _drop(record: Dictionary, at: Vector3) -> void:
	var entry := record.duplicate()
	entry["at"] = at
	entry["armed"] = false
	entry["node"] = _drop_node(entry["id"], at)
	dropped.append(entry)


func _step_dropped(delta: float) -> void:
	if dropped.is_empty() or ctx.player == null:
		return
	var ball: Vector3 = ctx.player.ball_position()
	for entry in dropped.duplicate():
		if is_instance_valid(entry["node"]):
			entry["node"].rotate_y(delta * 1.8)
		var gap := ball.distance_to(entry["at"])
		if not entry["armed"]:
			entry["armed"] = gap >= REARM
		elif gap <= PICKUP:
			_pick_up(entry, ball)
			return


func _pick_up(entry: Dictionary, ball: Vector3) -> void:
	dropped.erase(entry)
	if is_instance_valid(entry["node"]):
		entry["node"].queue_free()
	_cancel_windup()
	var old := {"id": active_id, "charges": charges, "progress": progress}
	active_id = entry["id"]
	charges = int(entry["charges"])
	progress = float(entry["progress"])
	if old["id"] != "":
		_drop(old, ball)


func _clear_dropped() -> void:
	for entry in dropped:
		if is_instance_valid(entry["node"]):
			entry["node"].queue_free()
	dropped.clear()


# The dropped active on the ground: its rarity's star, spinning, with its name as a prompt.
func _drop_node(id: String, at: Vector3) -> Node3D:
	if combat == null or not combat.is_inside_tree():
		return null
	var row := _row(id)
	var tint: Color = ItemGen.RARITY.get(ItemGen.resolve_rarity(String(row.get("rarity", "rare"))), ItemGen.RARITY["rare"])["color"]
	var node := Node3D.new()
	node.name = "DroppedActive"
	combat.add_child(node)
	node.global_position = at + Vector3.UP * 1.2
	var star := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(1.2, 1.4, 0.3)
	star.mesh = prism
	star.material_override = Palette.solid(tint, 2.6)
	node.add_child(star)
	var label := WorldPrompt.new()
	label.name = "Prompt"
	label.text = "%s\n%s" % [row.get("name", ""), ActiveOffers.mark(row)]
	label.set_parts(String(row.get("name", "")), "Roll over it to rack it\n" + ActiveOffers.mark(row), ActiveOffers.ICON)
	label.attach(node, Vector3(0.0, 1.4, 0.0), 30.0)
	node.add_child(label)
	return node


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
