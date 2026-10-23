extends Node

const FlourishRows := preload("res://src/presentation/flourish_rows.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const BossModel := preload("res://src/boss/boss_model.gd")
const Palette := preload("res://src/core/palette.gd")

# When an in-run flourish plays (flourish_rows.gd holds what each one shows; the player
# draws it). A row names its moment with "on" and is matched here against the bus:
#
#   arrival  boss_arena_entered for the row's boss, once per run (an arena retry plays
#            nothing: TONE-BIBLE, never replays on retry). It plays inside the boss's
#            BossRules.INTRO_SECONDS, when no attack can land, so it holds nothing.
#   phase    boss_phase_changed to one of the row's phases. It fits inside the 2.0 s
#            transition beat a later phase opens with (fight_phases.gd on #391).
#   rout     boss_defeated for the row's boss. Flow asks plan_victory() before it opens
#            the victory window, so the world stays in view for the rout's length and
#            the window grows by what the rout and a sign-on need past its own 2.5 s,
#            never more than HOLD_CAP.
#   sign_on  after the rout, when the row's achievement was earned during this fight
#            (Tarn signs on the day Brindle falls). It plays over the victory card.
#
# A row's trigger fields: on (one of the four above), boss (Worlds.BOSSES kind), phases
# (phase rows) and earned (sign-on rows). A row plays in full the first time a profile sees
# it and in its short form after that (the player keeps the seen key). Any skip cuts the
# hold it was paying for. A row's "world" {full, short} lists its world beats ("rise",
# "eject"), which are this module's: the player only draws the overlay. The hold a beat paid
# for is written into its entry in the run's "flourishes" meta, which the run log keeps.

const HOLD_CAP := 2.0
# The Requisition's arc over the bowl rim: it starts this far out and up from where it stands.
const RISE_OUT := 16.0
const RISE_UP := 12.0
const EJECT_UP := 11.0
const EJECT_OUT := 30.0
const EJECT_TURNS := 1.5
# How hard the slow-motion curve bends the eject's middle: 0 is linear, 1 stops at the apex.
const EJECT_SLOW := 0.75

var ctx
var player
var _played_this_run := {}
var _earned_in_fight := {}
var _chain: Array[String] = []
# The victory's rows (the rout and its chain), and the row whose own finish starts the next.
var _victory_ids := {}
var _chain_from := ""
# Per playing id: the seconds of the victory hold it is paying for and whether it is full.
var _playing := {}
var _world := []


func setup(ctx_ref, player_ref) -> void:
	ctx = ctx_ref
	player = player_ref
	name = "FlourishCues"
	var events = ctx.events
	events.run_started.connect(func(_class_id: String):
		_played_this_run.clear()
		_chain.clear())
	events.boss_arena_entered.connect(_on_arena_entered)
	events.boss_phase_changed.connect(_on_phase)
	events.achievement_earned.connect(func(id: String): _earned_in_fight[id] = true)
	events.flow_changed.connect(_on_flow_changed)
	if player != null and player.has_signal("finished"):
		player.finished.connect(_on_finished)
	if ctx.flow != null and "victory_plan" in ctx.flow:
		ctx.flow.victory_plan = plan_victory


func _boss_id() -> String:
	var row: Dictionary = ctx.flow.boss_row(ctx.stages.world_of(ctx.run.stage))
	return String(row.get("kind", ""))


func _on_arena_entered() -> void:
	_earned_in_fight.clear()
	for id in matching("arrival", _boss_id()):
		if _played_this_run.has(id):
			continue
		_played_this_run[id] = true
		_play(id)


func _on_phase(phase: int, _name: String) -> void:
	for id in matching("phase", _boss_id()):
		if phase in FlourishRows.row(id).get("phases", []):
			_play(id)


# Flow's hook at a boss's defeat, before it opens the victory window: {hold, veil}. hold
# is the seconds added to the window, veil how long the victory card waits so the rout
# plays over the world. Starts the rout.
func plan_victory() -> Dictionary:
	var boss := _boss_id()
	var routs := matching("rout", boss)
	if routs.is_empty():
		return {"hold": 0.0, "veil": 0.0}
	var rout := routs[0]
	_chain.clear()
	_victory_ids = {rout: true}
	_chain_from = rout
	for id in matching("sign_on", boss):
		if _earned_in_fight.has(String(FlourishRows.row(id).get("earned", ""))):
			_chain.append(id)
			_victory_ids[id] = true
	var base: float = ctx.flow.VICTORY_SECONDS
	var veil := length_of(rout)
	var total := veil
	for id in _chain:
		total += length_of(id)
	var hold := clampf(total - base, 0.0, HOLD_CAP)
	# Each beat pays for the part of the hold that falls inside it.
	var start := 0.0
	var paid := {}
	for id in [rout] + _chain:
		var end := start + length_of(id)
		paid[id] = clampf(minf(end, base + hold) - maxf(start, base), 0.0, hold)
		start = end
	# The rout starts now, over whatever was showing (a phase panel at most), so the veil
	# counts the same seconds the rout plays.
	if player != null:
		player.stop_all()
	_play(rout, paid[rout])
	for id in _chain:
		_playing[id] = {"held": paid[id]}
	return {"hold": hold, "veil": veil}


# The rows for a moment and a boss, in table order.
static func matching(on: String, boss: String) -> Array[String]:
	var out: Array[String] = []
	for id in FlourishRows.ROWS:
		var row: Dictionary = FlourishRows.ROWS[id]
		if String(row.get("on", "")) == on and String(row.get("boss", "")) == boss:
			out.append(String(id))
	return out


static func world_beats(id: String, short: bool) -> Array:
	return FlourishRows.row(id).get("world", {}).get("short" if short else "full", [])


func length_of(id: String) -> float:
	return FlourishRows.length(id, _short(id))


func _short(id: String) -> bool:
	var profile = ctx.get("profile")
	return profile != null and profile.is_seen(FlourishRows.SEEN_PREFIX + id)


func _play(id: String, held := 0.0) -> void:
	var full := not _short(id)
	if player == null or not player.play(id, _seed(), _anchors()):
		return
	_playing[id] = {"held": held, "full": full}
	for beat in world_beats(id, not full):
		_world_beat(beat)


func _seed() -> int:
	return int(ctx.run.run_seed) if ctx.run != null else 0


func _anchors() -> Dictionary:
	var out := {}
	var boss = ctx.get("boss")
	if boss != null:
		for key in ["ship", "scooter", "arena"]:
			var node = boss.get(key)
			if node is Node3D and is_instance_valid(node):
				out[key] = node
	if ctx.player != null and ctx.player.has_method("body"):
		out["ball"] = ctx.player.body()
	return out


func _on_finished(id: String, skipped: bool) -> void:
	if not _playing.has(id):
		return
	var info: Dictionary = _playing.get(id, {})
	_playing.erase(id)
	var held := float(info.get("held", 0.0))
	if skipped and _victory_ids.has(id):
		# A skipped beat gives back its hold and every hold the chain still owed.
		var owed := held
		for later in _chain:
			owed += float(_playing.get(later, {}).get("held", 0.0))
			_playing.erase(later)
		_chain.clear()
		_victory_ids.clear()
		if ctx.flow != null and ctx.flow.has_method("cut_victory"):
			ctx.flow.cut_victory(owed)
		held = 0.0
	# The player's record for this row is the last it finished; it joins the run meta next.
	if not player.played.is_empty() and String(player.played.back().get("id", "")) == id:
		player.played.back()["held"] = snappedf(held, 0.01)
	elif skipped:
		held = 0.0
	if not skipped and id == _chain_from and not _chain.is_empty():
		var next: String = _chain.pop_front()
		_chain_from = next
		_play(next, float(_playing.get(next, {}).get("held", 0.0)))


func _on_flow_changed(state: String) -> void:
	if state in ["title", "class_select", "summary", "dead"]:
		_chain.clear()
		_victory_ids.clear()
		_chain_from = ""
		_playing.clear()
		for node in _world:
			if is_instance_valid(node):
				node.queue_free()
		_world.clear()


func _reduced_motion() -> bool:
	return ctx.camera != null and bool(ctx.camera.get("reduced_motion"))


# --- World beats -----------------------------------------------------------------------

func _world_beat(beat: Dictionary) -> void:
	if _reduced_motion():
		return
	match String(beat.get("kind", "")):
		"rise":
			_rise(float(beat.get("at", 0.0)), float(beat.get("seconds", 1.0)))
		"eject":
			_eject(float(beat.get("at", 0.0)), float(beat.get("seconds", 1.6)))


# The Requisition crests the bowl rim: its model, never its hull, arcs in from outside and
# lands where the fight already has it. The ball enters on the far side and nothing can
# land before the intro ends, so the gap between body and hull is never touched.
func _rise(at: float, seconds: float) -> void:
	var boss = ctx.get("boss")
	var ship = boss.get("ship") if boss != null else null
	var arena = boss.get("arena") if boss != null else null
	if not (ship is Node3D) or not is_instance_valid(ship) or ship.get("model") == null or not (arena is Node3D):
		return
	var model: Node3D = ship.model
	var tween := create_tween()
	tween.tween_interval(at)
	tween.tween_method(func(f: float):
		if not is_instance_valid(model) or not is_instance_valid(ship) or not is_instance_valid(arena):
			return
		var out := Vector3(ship.global_position.x - arena.global_position.x, 0.0, ship.global_position.z - arena.global_position.z).normalized()
		var e := 1.0 - pow(1.0 - f, 3.0)
		var offset := out * RISE_OUT * (1.0 - e) + Vector3.UP * (RISE_UP * (1.0 - e) + 4.0 * sin(PI * e) * (1.0 - e))
		model.position = ship.global_basis.inverse() * offset, 0.0, 1.0, seconds)
	tween.tween_callback(func():
		if is_instance_valid(model):
			model.position = Vector3.ZERO)


# Brindle's scooter pops out of the catch and sails over the rim in slow motion: a copy, so
# the fight's own scooter (hidden at the catch) is left alone.
func _eject(at: float, seconds: float) -> void:
	var boss = ctx.get("boss")
	var arena = boss.get("arena") if boss != null else null
	var scooter = boss.get("scooter") if boss != null else null
	if not (arena is Node3D) or not is_instance_valid(arena):
		return
	var from: Vector3 = scooter.global_position if scooter is Node3D and is_instance_valid(scooter) else arena.global_position
	var prop := Node3D.new()
	prop.name = "RoutScooter"
	arena.add_child(prop)
	_world.append(prop)
	Requisition.dress_scooter(prop)
	if prop.get_child_count() == 0:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.0, 1.0, 2.8)
		box.mesh = mesh
		box.material_override = Palette.solid(Palette.BRASS, 0.8)
		prop.add_child(box)
	prop.global_position = from
	prop.visible = false
	var out := Vector3(from.x - arena.global_position.x, 0.0, from.z - arena.global_position.z)
	out = out.normalized() if out.length() > 0.5 else Vector3.FORWARD
	var tween := create_tween()
	tween.tween_interval(at)
	tween.tween_callback(func():
		if is_instance_valid(prop):
			prop.visible = true)
	tween.tween_method(func(t: float):
		if not is_instance_valid(prop):
			return
		var f := slow_mo(t)
		prop.global_position = from + out * EJECT_OUT * f + Vector3.UP * EJECT_UP * 4.0 * f * (1.0 - f)
		prop.rotation = Vector3(TAU * EJECT_TURNS * f, 0.0, PI * 0.5 * f), 0.0, 1.0, seconds)
	tween.tween_callback(func():
		if is_instance_valid(prop):
			prop.queue_free())


# Time through the eject with its middle slowed: the apex hangs, the launch and the fall
# move at speed. Monotonic for EJECT_SLOW under 1.
static func slow_mo(t: float) -> float:
	return t + EJECT_SLOW * sin(TAU * t) / TAU
