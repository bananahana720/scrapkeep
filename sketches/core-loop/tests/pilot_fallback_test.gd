extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const MusicPhrases := preload("res://src/presentation/music_phrases.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const ClassKit := preload("res://src/ui/class_kit.gd")
const AbilitySlots := preload("res://src/ui/ability_slots.gd")
const T := preload("res://tests/support/t.gd")

# A pilot row the per-pilot tables do not know (T0; the seventh since the six-pilot roster, wave 15). The probe is Rivet's row under a
# new id, name and motif; it joins flow.classes here and never ClassDef.all(). The run
# selects it from class select, plays stage 1 to the Warden's break and the reward, and
# opens the workshop. The ability bar, the tree pick, the class card row, sound and music
# must run for it with no script error, and each lookup that falls back warns once.

const PROBE_ID := "probe_fourth"
const PROBE_MOTIF := "probe"
const SETTLE := 20

var _t := T.new("pilot_fallback_test")
var _game
var _ws
var _source := Intent.Scripted.new()
var _offers: Array = []
var _chosen := ""


static func probe_row() -> Resource:
	var def: Resource = ClassDef.by_id("runner_gunner").duplicate()
	def.id = PROBE_ID
	def.display_name = "Probe"
	def.motif = PROBE_MOTIF
	return def


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	var probe := probe_row()
	_t.check("probe stays out of the roster", not _roster_ids().has(PROBE_ID) and ClassDef.by_id(PROBE_ID) == null,
		"ClassDef.all() holds %d rows and does not know %s" % [ClassDef.all().size(), PROBE_ID])
	var flow = _game.flow
	_ws = _game.get_node("Workshop")
	_ws.armed = true
	_game.ctx.calm = true
	flow.force_warden = true
	_game.player.source = _source
	_game.events.reward_offered.connect(func(offers: Array): _offers = offers)
	_game.events.reward_chosen.connect(func(part_id: String): _chosen = part_id)
	flow.classes.append(probe)
	flow.press_start()
	_t.check("class select lists the roster and the probe", flow.state_name() == "class_select" and flow.classes.size() == ClassDef.all().size() + 1,
		"state %s, %d classes" % [flow.state_name(), flow.classes.size()])
	await _frames(2)
	flow.choose_class(flow.classes.size() - 1)
	# The ball fits its kit from ClassDef.by_id on run_started (player_ball.gd), which does
	# not know the probe; a real pilot is in ClassDef.all(), so the test fits it by hand.
	_game.player.fit_class(probe)
	_game.player.tree.open_checkpoint()
	await _frames(SETTLE)
	_t.check("probe selected", _game.run.class_id() == PROBE_ID and _game.run.class_def == probe and flow.state_name() in ["stage", "beacon"],
		"run class %s in state %s" % [_game.run.class_id(), flow.state_name()])
	_game.run.set_max_hp(99999.0)

	# The tree: no table for the id, so an empty tree, warned once.
	var tree = _game.player.tree
	_t.check("tree reads the probe's id", tree.class_id == PROBE_ID, "tree class %s" % tree.class_id)
	var empty: Array = UpgradeTree.nodes(PROBE_ID)
	var again: Array = UpgradeTree.nodes(PROBE_ID, true)
	_t.check("empty tree for an unknown pilot", empty.is_empty() and again.is_empty() and tree != null and not tree.pending(),
		"%d nodes, %d in world one, tree pending %s" % [empty.size(), again.size(), tree.pending() if tree != null else "?"])
	_t.check("tree warns once", UpgradeTree.unknown_warned.keys() == [PROBE_ID],
		"warned for %s" % [UpgradeTree.unknown_warned.keys()])

	# The ability bar, the class card row, and the tree pick screen.
	await _frames(5)
	var slots: Array = AbilitySlots.new().slots(_game)
	_game.hud.ability_bar.update_slots(slots, probe.color, probe.shape)
	# Re-pinned 4 -> 5 on 2026-10-10 (wave 13 unit B2): the skill bar publishes three numbered
	# slots and two chips (design-v3/SKILL-BAR.md section 1).
	# Re-pinned 5 -> 6 on 2026-10-24 (#445, actives on by default): the racked active's F chip
	# follows them.
	_t.check("ability bar takes the probe's slots", slots.size() == 6 and AbilitySlots.valid(slots) and _game.hud.ability_bar.slots.size() == 6
		and String(slots[5].get("key", "")) == "key_f",
		"%d published slots, %d on the bar" % [slots.size(), _game.hud.ability_bar.slots.size()])
	var keys: Array = ClassKit.card_keys(probe)
	_t.check("class card row", keys.size() >= 4 and ClassKit.fantasy(probe) != "" and ClassKit.difficulty(probe) > 0,
		"%d key rows, fantasy \"%s\", difficulty %d" % [keys.size(), ClassKit.fantasy(probe), ClassKit.difficulty(probe)])
	_ws.open_pick()
	_t.check("tree pick stays shut without nodes", not _ws.pick.is_open(), "pick open %s" % _ws.pick.is_open())

	# Sound and music: the motif has no row in harmony.gd, so every reader falls back.
	_t.check("harmony has no probe row", Harmony.motif(PROBE_MOTIF).is_empty(), "motif row %s" % [Harmony.motif(PROBE_MOTIF)])
	var rendered := {
		"ready": SfxBank._ready_pulse(PROBE_MOTIF), "free": SfxBank._break_free(PROBE_MOTIF),
		"whip": SfxBank._near_miss_whip(PROBE_MOTIF)}
	_t.check("class cues render for an unknown motif", rendered.values().all(func(w): return w.size() > 0),
		"samples %s" % [rendered.keys().map(func(k): return "%s %d" % [k, rendered[k].size()])])
	# audio.gd resolves a run's motif through ClassDef.by_id, which cannot see the probe
	# row, so the engine is handed the class id as its motif; both ids are unknown here.
	var warned: Array = Harmony.unknown_warned.keys()
	_t.check("harmony warns for the unknown ids only", PROBE_MOTIF in warned and warned.all(func(k): return k in [PROBE_MOTIF, PROBE_ID]),
		"warned for %s" % [warned])
	var audio = _game.presentation.get("audio") if _game.presentation != null else null
	var engine = audio.get("engine") if audio != null else null
	_t.check("music engine takes the motif", engine != null and engine.class_motif in [PROBE_MOTIF, PROBE_ID],
		"engine motif %s" % [engine.class_motif if engine != null else "no engine"])
	if engine != null:
		var counter := MusicPhrases.make_class_counter(engine.class_motif, engine._progression())
		_t.check("music engine plays no class counter-line for an unknown motif", counter.is_empty(),
			"counter-line for %s has %d notes" % [engine.class_motif, counter.size()])

	# Stage 1 to the Warden's break, the reward and the launch out of it.
	await _frames(SETTLE)
	var warden = flow.warden
	_t.check("warden stands", flow.sealed and is_instance_valid(warden), "sealed %s, warden %s" % [flow.sealed, warden])
	if is_instance_valid(warden):
		warden._die()
	await _frames(SETTLE)
	_t.check("break opens the gates", flow.state_name() == "gates" and not _offers.is_empty() and not flow.sealed,
		"state %s, %d offers" % [flow.state_name(), _offers.size()])
	if not _offers.is_empty():
		_game.build.gates.emit_signal("chosen", _offers[0]["part_id"])
	await _frames(SETTLE)
	_t.check("reward taken", _chosen != "" and _game.run.parts.has(_chosen) and flow.state_name() == "launch",
		"took %s, parts %s, state %s" % [_chosen, _game.run.parts, flow.state_name()])

	# The workshop: the barge's counter opens for the probe.
	var shop = _game.build.shop
	shop.enter()
	_game.run.scrap = 400
	_ws.open_counter()
	await _frames(SETTLE)
	_t.check("workshop opens", _ws.counter.is_open() and shop.inside, "counter open %s, inside %s" % [_ws.counter.is_open(), shop.inside])
	_ws.close_counter()
	_t.check("tree still warned once", UpgradeTree.unknown_warned.keys() == [PROBE_ID],
		"warned for %s" % [UpgradeTree.unknown_warned.keys()])
	_finish()


func _finish() -> void:
	print("pilot_fallback_test: %d checks" % _t.checks)
	_game.free()
	quit(_t.verdict())


func _roster_ids() -> Array:
	return ClassDef.all().map(func(def): return def.id)
