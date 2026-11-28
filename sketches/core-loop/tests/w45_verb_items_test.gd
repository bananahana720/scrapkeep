extends SceneTree

# W45-B2 U7 (design-v3/ABILITY-MUTATIONS.md sections 7 C3 to C7, 8 and 10): the five verb items.
# Backwash lays a 4 m committed strip behind a dash or boost (0.4 of a weapon hit, once per machine
# per dash, the dash itself untouched). Barbed Reel jumps a reel-in impact once to the nearest other
# machine within 6 m at 0.7 through _chain. Faultline Cap cracks an 8 m lane ahead of a smash landing
# at 0.5 of the smash's punch and breaks props at three points down it at +1 tier, never +2. Second
# Bell rings a kit special's release once more 1.0 s later at half strength (Tally's Gather Plate as a
# half-radius gather that leaves the live plate alone), and never answers an active, an ultimate,
# Crater Slam or the plant's discharge. Long Leash doubles a line skill's load_seconds. Every
# follow-up strike is item_proc with no shot bits and starts nothing. Each rule carries a planted
# control: the naive version the rule exists to refuse, or the same scene without the item.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Combat := preload("res://src/combat/combat.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Augments := preload("res://src/movement/augments.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const ShotBits := preload("res://src/build/shot_bits.gd")
const Parts := preload("res://src/build/parts.gd")
const Items := preload("res://src/build/items.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const ItemEffects := preload("res://src/build/item_effects.gd")
const Triggers := preload("res://src/build/triggers.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const WordBudget := preload("res://src/core/word_budget.gd")
const T := preload("res://tests/support/t.gd")

const FIVE := ["backwash", "barbed_reel", "faultline_cap", "second_bell", "long_leash"]
const ROWS := {
	"backwash": ["spillway_works", "uncommon", "dash_wake"],
	"barbed_reel": ["redjaw", "rare", "reel_chain"],
	"faultline_cap": ["waking", "rare", "slam_crack"],
	"second_bell": ["mind_glass", "uncommon", "second_bell"],
	"long_leash": ["moss", "uncommon", "line_leash"],
}
# The numbers each card's text must carry, as the player reads them.
const NUMBERS := {
	"backwash": ["4 m", "40%"], "barbed_reel": ["70%", "6 m"], "faultline_cap": ["8 m", "50%"],
	"second_bell": ["1s", "50%"], "long_leash": ["8s", "4s"],
}
const GAUGE_PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "remembered_cannon"]

var _t := T.new("w45_verb_items_test")
var _game
var _combat
var _player
var _source := Intent.Scripted.new()
var _struck: Array = []
var _special_used: Array = []
var _released: Array = []
var _boosts: Array = []
var _smashed := 0
var _loaded: Array = []
var _expired: Array = []
var _ult_started := 0
var _active_fired := 0


# The module with every blast it is asked for kept, so the crack's three circles can be read.
class Spy extends Destructibles:
	var blasts: Array[Dictionary] = []

	func on_blast(at: Vector3, radius: float, source: String, tier_bonus: int = 1, heft_class: int = -1) -> void:
		blasts.append({"at": at, "radius": radius, "source": source, "bonus": tier_bonus, "heft": heft_class})
		super.on_blast(at, radius, source, tier_bonus, heft_class)


func _initialize() -> void:
	_check_rows()
	_check_effect_table()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	await _sim(0.4)
	var ev = _game.events
	ev.enemy_struck.connect(func(enemy: Node3D, kind: String, force: float): _struck.append([enemy.get_instance_id(), kind, force]))
	ev.special_used.connect(func(id: String, _at: Vector3): _special_used.append(id))
	ev.gauge_released.connect(func(id: String, _f: float): _released.append([id, _combat._clock]))
	ev.boosted.connect(func(dir: Vector3): _boosts.append(dir))
	ev.harpoon_smashed.connect(func(_e: Node3D, _at: Vector3, _s: float): _smashed += 1)
	ev.line_skill_loaded.connect(func(id: String, seconds: float): _loaded.append([id, seconds]))
	ev.line_skill_expired.connect(func(id: String): _expired.append(id))
	ev.ultimate_started.connect(func(_id: String, _path: String, _from: Vector3, _to: Vector3, _seconds: float): _ult_started += 1)
	ev.active_fired.connect(func(_id: String, _at: Vector3, _count: int): _active_fired += 1)
	await _check_shot_bits()
	await _check_backwash()
	await _check_barbed_reel()
	await _check_faultline_hits()
	await _check_faultline_props()
	await _check_bell_gauges()
	await _check_bell_gather()
	await _check_bell_echo()
	await _check_bell_clears()
	await _check_leash()
	await _check_bell_never()
	quit(_t.verdict())


# --- the data: five rows, their words, the admission ----------------------------------------

func _check_rows() -> void:
	for id in FIVE:
		var d: Resource = Parts.def(id)
		_t.check("%s row exists" % id, d != null and Items.TABLE.has(id), "")
		if d == null:
			continue
		var want: Array = ROWS[id]
		_t.eq("%s maker, authored rarity, stack and effect" % id, [d.maker, Items.TABLE[id]["rarity"], d.stack_rule, d.stack_cap,
			String(d.effect.get("do", ""))], [want[0], want[1], "capped", 1.0, want[2]])
		# An authored uncommon row settles on the green field-kit rung (ItemGen.RARITY_ALIASES); rare is cobalt.
		_t.eq("%s settles on its rung" % id, d.rarity, ItemGen.resolve_rarity(want[1]))
		_t.check("%s is green or cobalt, never a relic" % id, d.rarity in ["common", "rare"] and not d.rarity in ["relic", "rare_plus", "evolved"]
			and not Items.TABLE[id]["rarity"] in ["relic", "rare_plus"], d.rarity)
		_t.check("%s is admitted to the alpha table" % id, id in AlphaDefs.PARTS, "")
		_t.check("%s effect is a closed-table verb row" % id, ItemEffects.EFFECTS.has(want[2]) and want[2] in ItemEffects.VERB_EFFECTS
			and want[2] in ItemEffects.PASSIVE_EFFECTS and d.trigger == "", d.trigger)
		_t.check("%s card line is at most six words" % id, WordBudget.words_in(String(d.verb)) <= 6, String(d.verb))
		var text := String(d.text)
		_t.check("%s settled text fits the card cap unclipped" % id, WordBudget.words_in(text) <= ItemGen.MAX_WORDS and not "..." in text
			and not text.ends_with("."), text)
		_t.eq("%s settled text is the authored text" % id, text, String(Items.TABLE[id]["text"]))
		for number in NUMBERS[id]:
			_t.check("%s text carries %s" % [id, number], number in text, text)
		for banned in ["unleash", "enemies", "foes", "grapple", "rebound", "bite"]:
			_t.check("%s text and line avoid '%s'" % [id, banned], not banned in text.to_lower() and not banned in String(d.verb).to_lower(), "")
		_t.eq("%s adds no shot bits" % id, d.bits, 0)
		_t.eq("%s names its bits explicitly empty" % id, Items.TABLE[id].get("bits", null), [])
	_t.check("barbed reel and long leash say harpoon or line, faultline says smash", "Harpoon" in String(Parts.def("barbed_reel").text)
		and "line" in String(Parts.def("long_leash").text) and "Smash" in String(Parts.def("faultline_cap").text), "")
	# Planted controls: a ninth word is clipped with an ellipsis; a made-up effect is not in the table; a
	# verb row's tags without "bits": [] would carry shot bits.
	_t.check("planted: a nine-word text is clipped", "..." in ItemGen.clip("one two three four five six seven eight nine"), "")
	_t.check("planted: a made-up effect id is outside the closed table", not ItemEffects.EFFECTS.has("bell_unleash"), "")
	var mapped := 0
	for id in FIVE:
		if ShotBits.part_mask(Parts.def(id).tags) != 0:
			mapped += 1
	_t.eq("planted: four of the five rows' tags would map to shot bits without bits: []", mapped, 4)


func _check_effect_table() -> void:
	var fx = ItemEffects.new(null)
	fx.refresh(["second_bell", "long_leash"])
	_t.eq("a held verb item hands combat its row", fx.verb_row("second_bell"),
		{"do": "second_bell", "delay": 1.0, "mult": 0.5, "gather_scale": 0.5, "knock": 6.0})
	_t.eq("an unheld verb item hands combat nothing", fx.verb_row("dash_wake"), {})
	var row: Dictionary = fx.verb_row("line_leash")
	row["load_mult"] = 99.0
	_t.eq("verb_row is a copy, never the live row", float(fx.verb_row("line_leash")["load_mult"]), 2.0)
	fx.refresh([])
	_t.eq("dropping the item empties its row", fx.verb_row("line_leash"), {})


# --- helpers -----------------------------------------------------------------------------------

func _as(pilot: String) -> void:
	var def: Resource = ClassDef.by_id(pilot)
	_game.run.class_def = def
	_player.fit_class(def)
	_clear_machines()
	_source.hold = {}
	_source.press = {}
	_combat.heft_override = -1.0
	var at: Vector3 = _game.ctx.terrain.spawn_point(1)
	_player.reset_to(at)
	_player.body().global_position = at
	_player.kit.drop_line("reset")
	_player.chain.reset()
	_player.abilities.refill()
	_combat._start_attempt()
	_combat._reset_cards()
	_combat._line_load = {}
	_combat.last_bell = {}
	_combat.last_strip = {}
	_combat.last_reel_arc = {}
	_game.camera.snap(Vector3(0.0, 0.0, -1.0))
	_game.camera.pitch = 0.0
	_hold([])
	await _sim(0.3)
	_struck.clear()
	_special_used.clear()
	_released.clear()


func _hold(parts: Array) -> void:
	_game.run.parts.assign(parts)
	_game.ctx.build.recompute()


func _equip(slot: String, id: String) -> void:
	_player.abilities.swap(slot, id)
	_player.refit()


func _clear_machines() -> void:
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.queue_free()


func _spawn(flat: Vector3) -> Node3D:
	var ground: float = _game.ctx.terrain.height(flat.x, flat.z)
	var enemy: Node3D = _combat.spawn_enemy("chaser", Vector3(flat.x, ground + 1.5, flat.z))
	enemy.max_hp = 100000.0
	enemy.hp = 100000.0
	enemy.set_physics_process(false)
	return enemy


func _ball_flat() -> Vector3:
	var b: Vector3 = _player.ball_position()
	return Vector3(b.x, 0.0, b.z)


func _aim_flat() -> Vector3:
	var dir: Vector3 = _game.ctx.aim_forward()
	dir.y = 0.0
	return dir.normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD


func _side() -> Vector3:
	return _aim_flat().cross(Vector3.UP).normalized()


func _hits(enemy: Node3D, kind := Combat.SYNERGY) -> Array:
	var id := enemy.get_instance_id()
	return _struck.filter(func(s): return s[0] == id and s[1] == kind).map(func(s): return float(s[2]))


func _special_charges() -> int:
	return _player.abilities.slot(AbilityState.SPECIAL).charges


# --- shot bits: the five add none ----------------------------------------------------------------

func _check_shot_bits() -> void:
	await _as("pylon_engineer")
	_game.tuning.set_value("shot_bits_live", ShotBits.ALL)
	var build = _game.ctx.build
	_hold(["static_burr", "tracer_round"])
	var base: int = build.shot_bits()
	var dropped: Array = build.dropped_shot_bits()
	_t.check("precondition: the two plain parts carry live bits", base != 0, str(ShotBits.names(base)))
	_hold(["static_burr", "tracer_round"] + FIVE)
	_t.eq("holding all five leaves the shot's bits unchanged", build.shot_bits(), base)
	_t.eq("and drops nothing new", build.dropped_shot_bits(), dropped)
	_hold(FIVE)
	_t.eq("the five alone carry no bits", build.shot_bits(), 0)
	_hold(FIVE + ["static_burr", "tracer_round"])
	_t.eq("held first, they take no bit slot either", build.shot_bits(), base)
	# Planted control: a part whose tags map (anchor) does move the shot.
	_hold(["static_burr"])
	_t.check("planted: an anchor-tagged part without bits: [] moves the shot", build.shot_bits() != base, str(ShotBits.names(build.shot_bits())))
	_game.tuning.set_value("shot_bits_live", 17)
	_hold([])


# --- Backwash (C3) ----------------------------------------------------------------------------

# One boost from rest with or without Backwash, three machines placed round the start.
func _boost_run(parts: Array) -> Dictionary:
	await _as("pylon_engineer")
	_hold(parts)
	var aim := _aim_flat()
	var start := _ball_flat()
	var behind := _spawn(start - aim * 2.0)
	var far := _spawn(start - aim * 8.0)
	var side := _spawn(start - aim * 1.0 + _side() * 5.0)
	await _sim(0.1)
	_struck.clear()
	_boosts.clear()
	var p0: Vector3 = _player.ball_position()
	_source.press = {"boost_pressed": true}
	await physics_frame
	await physics_frame
	var out := {"v": _player.state.velocity, "cooldown": float(_player.state.boost_cooldown), "boosts": _boosts.size(),
		"strips": _combat._strips.size(), "strip": _combat.last_strip, "behind": behind, "far": far, "side": side,
		"dir": _boosts[0] if not _boosts.is_empty() else Vector3.ZERO, "aim": aim}
	await _sim(0.5)
	out["moved"] = _player.ball_position() - p0
	out["behind_hits"] = _hits(behind)
	out["far_hits"] = _hits(far)
	out["side_hits"] = _hits(side)
	return out


func _check_backwash() -> void:
	var plain := await _boost_run([])
	var wake := await _boost_run(["backwash"])
	_t.check("both runs boosted once", plain["boosts"] == 1 and wake["boosts"] == 1, "%d and %d" % [plain["boosts"], wake["boosts"]])
	_t.check("the boost left along the aim", (wake["dir"] as Vector3).dot(wake["aim"]) > 0.9, str(wake["dir"]))
	_t.check("dash speed is untouched", (wake["v"] as Vector3).distance_to(plain["v"]) < 0.01, "%s vs %s" % [wake["v"], plain["v"]])
	_t.near("dash cooldown is untouched", float(wake["cooldown"]), float(plain["cooldown"]), 0.0001)
	_t.check("dash distance is untouched", (wake["moved"] as Vector3).distance_to(plain["moved"]) < 0.05, "%s vs %s" % [wake["moved"], plain["moved"]])
	_t.eq("without Backwash no strip is laid", plain["strips"], 0)
	_t.eq("planted control: without Backwash nothing strikes the chaser", plain["behind_hits"], [])
	var strip: Dictionary = wake["strip"]
	_t.eq("one boost lays one strip", wake["strips"], 1)
	var shape: Dictionary = strip.get("shape", {})
	var from: Vector3 = shape.get("from", Vector3.ZERO)
	var to: Vector3 = shape.get("to", Vector3.ZERO)
	var dir: Vector3 = wake["dir"]
	_t.near("the strip is 4.0 m long", Vector2(to.x - from.x, to.z - from.z).length(), 4.0, 0.0001)
	_t.check("it lies behind the ball's path", (to - from).dot(dir) < -3.9, "%s" % [(to - from).dot(dir)])
	_t.eq("it is the record the indicator draws", is_same(_player.indicator.last_shape.get(strip["layer"], {}), shape), true)
	_t.eq("drawn in the pilot's colour", shape.get("color"), _player.class_color())
	_t.eq("it strikes as item_proc with no shot bits", [strip["source"], strip["bits"], strip["item"]], ["item_proc", 0, "dash_wake"])
	var weapon_hit: float = _combat._weapon_hit()
	_t.check("precondition: a weapon hit is worth something", weapon_hit > 0.0, str(weapon_hit))
	_t.near("the strip's damage is 0.4 of a weapon hit", float(strip["damage"]), 0.4 * weapon_hit, 0.0001)
	_t.eq("the chaser behind is struck once at that damage", (wake["behind_hits"] as Array).size(), 1)
	if not (wake["behind_hits"] as Array).is_empty():
		_t.near("its strike force is 0.4 of a weapon hit", float(wake["behind_hits"][0]), 0.4 * weapon_hit, 0.0001)
	_t.eq("a machine past the strip's end is not struck", wake["far_hits"], [])
	_t.eq("a machine off its side is not struck", wake["side_hits"], [])
	# The strip lives 1.5 s; the chaser standing in it is not struck twice.
	var behind: Node3D = wake["behind"]
	await _sim(0.6)
	_t.eq("the chaser is still struck once while it stands in the strip", _hits(behind).size(), 1)
	_t.eq("and the strip has laid no other strip", _combat._strips.size(), 1)
	await _sim(0.6)
	_t.check("after its 1.5 s the strip and its drawing are gone", _combat._strips.is_empty() and not _player.indicator.shapes.has(strip["layer"]), "")
	# A second dash is a new cause: one more strike, still once.
	_combat._on_wake_dash(dir)
	_t.eq("a second dash strikes the chaser once more", _hits(behind).size(), 2)
	_combat._on_wake_dash(dir)
	_t.eq("a dash and a boost in one frame lay one strip", _combat._strips.size(), 1)
	_combat._wake_frame = -1
	_combat._on_wake_dash(dir)
	_t.eq("planted control: without the one-per-frame guard the same frame lays a second", _combat._strips.size(), 2)
	# Proc depth 1: a SYNERGY strike never procs an item; a weapon kind would.
	_t.eq("the strip's strike kind procs no item", float(Triggers.STRIKE_PROC.get(Combat.SYNERGY, -1.0)), 0.0)
	_t.check("planted control: a weapon-kind strike would proc items", float(Triggers.STRIKE_PROC.get("runner", 0.0)) > 0.0, "")


# --- Barbed Reel (C4) ---------------------------------------------------------------------------

# A reel-in impact the way the ball lands one: the landed machine struck while it is the smash
# landing, then harpoon_smashed on the bus. Returns the landed machine's damage taken.
func _reel_in(landed: Node3D) -> float:
	var hp: float = landed.hp
	_player.smash_landing = landed
	_combat.strike(landed, "ram", 20.0)
	_player.smash_landing = null
	_game.events.harpoon_smashed.emit(landed, _player.ball_position(), 20.0)
	return hp - float(landed.hp)


func _check_barbed_reel() -> void:
	await _as("pylon_engineer")
	_hold(["barbed_reel"])
	var aim := _aim_flat()
	var a := _spawn(_ball_flat() + aim * 3.0)
	var b := _spawn(_ball_flat() + aim * 3.0 + _side() * 4.0)
	var c := _spawn(_ball_flat() + aim * 3.0 - _side() * 8.0)
	await physics_frame
	_struck.clear()
	_smashed = 0
	var hp_b: float = b.hp
	var dealt := _reel_in(a)
	_t.check("precondition: the reel-in impact dealt damage", dealt > 0.0, str(dealt))
	_t.near("the nearest other machine within 6 m takes 0.7 of it", hp_b - float(b.hp), 0.7 * dealt, 0.001)
	_t.eq("struck once, as SYNERGY", _hits(b).size(), 1)
	_t.eq("the machine 8 m off is untouched", _hits(c), [])
	_t.eq("the landed machine is not struck again", _hits(a), [])
	_t.eq("the arc names its target, item_proc, no bits", [_combat.last_reel_arc.get("target") == b, _combat.last_reel_arc.get("source"),
		_combat.last_reel_arc.get("bits")], [true, "item_proc", 0])
	var arcs: Array = _combat.effects._arcs
	_t.check("a short arc is drawn in the pilot's colour", not arcs.is_empty() and arcs[arcs.size() - 1]["color"] == _player.class_color(), "")
	_t.eq("the jump emits no harpoon_smashed of its own", _smashed, 1)
	_t.check("the jump's strike is never a reel impact, so nothing is pending", _combat._reel_hits.is_empty(), str(_combat._reel_hits))
	_t.check("planted control: SYNERGY is no reel impact while a ram on the landing is",
		not _combat.is_reel_impact(Combat.SYNERGY, true) and _combat.is_reel_impact("ram", true), "")
	# A second harpoon_smashed with no new reel-in impact jumps nothing.
	_struck.clear()
	_game.events.harpoon_smashed.emit(a, _player.ball_position(), 20.0)
	_t.eq("a smash fact with no reel-in impact this frame jumps nothing", _struck.size(), 0)
	# Only the far machine left: 8 m is past the reach.
	b.remove_from_group("enemy")
	await physics_frame
	_struck.clear()
	_reel_in(a)
	_t.eq("past 6 m nothing is struck", _hits(c), [])
	# Planted control: without the item the same landing strikes no one else.
	b.add_to_group("enemy")
	_hold([])
	await physics_frame
	_struck.clear()
	_reel_in(a)
	_t.eq("planted control: without Barbed Reel the neighbour is not struck", _hits(b), [])


# --- Faultline Cap (C5) -------------------------------------------------------------------------

func _check_faultline_hits() -> void:
	await _as("pylon_engineer")
	_hold(["faultline_cap"])
	_combat.heft_override = 2.0
	var aim := _aim_flat()
	var ahead := _spawn(_ball_flat() + aim * 5.0)
	var far := _spawn(_ball_flat() + aim * 12.0)
	var side := _spawn(_ball_flat() + aim * 4.0 + _side() * 4.0)
	var behind := _spawn(_ball_flat() - aim * 3.0)
	await physics_frame
	_struck.clear()
	var warden_before: int = _combat._warden_slam_hits
	_player._on_slammed(_player.ball_position(), 30.0, 1.0)
	var strength: float = _player.slam_strength(30.0, 1.0)
	var smash_punch: float = _combat.punch_of("slam", Augments.SLAM_KNOCK * strength)
	var want := 0.5 * smash_punch
	var strip: Dictionary = _combat.last_strip
	_t.eq("a smash landing lays one crack", [strip.get("item"), _combat._strips.size()], ["slam_crack", 1])
	var shape: Dictionary = strip.get("shape", {})
	var from: Vector3 = shape.get("from", Vector3.ZERO)
	var to: Vector3 = shape.get("to", Vector3.ZERO)
	_t.near("the crack runs 8.0 m", Vector2(to.x - from.x, to.z - from.z).length(), 8.0, 0.0001)
	_t.check("ahead along the ball's heading", (to - from).normalized().dot(aim) > 0.99, "")
	_t.eq("it is the record the indicator draws", is_same(_player.indicator.last_shape.get(strip.get("layer", ""), {}), shape), true)
	_t.check("the landing itself struck the machine ahead (a real smash)", not _hits(ahead, "slam").is_empty(), "")
	_t.eq("the crack strikes the machine ahead once", _hits(ahead).size(), 1)
	if not _hits(ahead).is_empty():
		_t.near("at 0.5 of the smash's punch", _hits(ahead)[0], want, 0.0001)
	_t.near("the door does not scale a SYNERGY strike again", float(_combat.resolve(ahead, Combat.SYNERGY, want)["punch"]), want, 0.0001)
	_t.check("planted control: a slam-kind strike of that force would be scaled by heft again",
		absf(_combat.punch_of("slam", want) - want) > 1.0, "%.2f vs %.2f" % [_combat.punch_of("slam", want), want])
	_t.eq("item_proc, no shot bits", [strip.get("source"), strip.get("bits")], ["item_proc", 0])
	_t.eq("past the crack's end nothing", _hits(far), [])
	_t.eq("off its side nothing", _hits(side), [])
	_t.eq("behind the landing nothing", _hits(behind), [])
	_t.eq("the crack counts no Warden slam hit", _combat._warden_slam_hits, warden_before)
	_t.near("and takes no dunk", _combat._dunk_bonus(ahead, Combat.SYNERGY), 0.0, 0.0)
	await _sim(0.3)
	_t.eq("the machine is still struck once while the crack stands", _hits(ahead).size(), 1)
	_t.eq("the crack lays nothing more and emits no smash", _combat._strips.size(), 1)
	await _sim(0.3)
	_t.check("after 0.5 s the crack and its drawing are gone", _combat._strips.is_empty() and not _player.indicator.shapes.has(strip.get("layer", "")), "")
	# A feeble landing (strength under 0.05) cracks nothing, like the slam itself.
	_struck.clear()
	_game.events.slammed.emit(_player.ball_position(), 0.01, 0.0)
	_t.eq("a landing too soft to slam cracks nothing", _combat._strips.size(), 0)
	_combat.heft_override = -1.0


func _check_faultline_props() -> void:
	await _as("pylon_engineer")
	_hold(["faultline_cap"])
	var hc: int = _game.run.heft_class()
	var aim := _aim_flat()
	var ball := _ball_flat()
	var rows := [
		_piece("near", hc + 1, ball + aim * 4.5),
		_piece("heavy", hc + 2, ball + aim * 7.0),
		_piece("aside", hc + 1, ball + aim * 4.5 + _side() * 7.0),
		_piece("beyond", hc + 1, ball + aim * 14.0),
	]
	var before = _game.ctx.destructibles
	var spy := Spy.new()
	spy.build({"destructible_rows": rows}, {"ctx": _game.ctx, "root": _game.ctx.root, "no_visuals": true})
	spy.finish_build()
	_game.ctx.destructibles = spy
	var at: Vector3 = _player.ball_position()
	_game.events.slammed.emit(at, 1.0, 1.0)
	var cracks: Array = spy.blasts.filter(func(b): return b["source"] == "faultline_cap")
	_t.eq("three blasts down the crack", cracks.size(), 3)
	var ground: Vector3 = _combat.ground_under(at)
	var spots: Array = cracks.map(func(b): return snappedf(Vector2(b["at"].x - ground.x, b["at"].z - ground.z).length(), 0.001))
	_t.eq("at 2.0, 4.5 and 7.0 m ahead", spots, [2.0, 4.5, 7.0])
	_t.check("each 2.5 m round at a +1 bonus", cracks.all(func(b): return is_equal_approx(float(b["radius"]), 2.5) and int(b["bonus"]) == 1), str(cracks))
	_t.eq("the heft class + 1 piece on the crack breaks", spy.state_of("near"), "shattered")
	_t.eq("the heft class + 2 piece on the crack holds (no +2)", spy.state_of("heavy"), "intact")
	_t.eq("a heft class + 1 piece off the crack holds", spy.state_of("aside"), "intact")
	_t.eq("a piece past the crack holds", spy.state_of("beyond"), "intact")
	# Planted control: asking the module for +2 still breaks only +1.
	spy.on_blast(spy.bounds_of("heavy").get_center(), 2.5, "planted", 2, hc)
	_t.eq("planted control: a +2 ask is clamped to +1", spy.state_of("heavy"), "intact")
	# Planted control: without the item the same landing fact breaks nothing.
	var rows2 := [_piece("near2", hc + 1, ball + aim * 4.5)]
	var spy2 := Spy.new()
	spy2.build({"destructible_rows": rows2}, {"ctx": _game.ctx, "root": _game.ctx.root, "no_visuals": true})
	spy2.finish_build()
	_game.ctx.destructibles = spy2
	_hold([])
	_game.events.slammed.emit(at, 1.0, 1.0)
	_t.eq("planted control: without Faultline Cap the piece holds", spy2.state_of("near2"), "intact")
	_game.ctx.destructibles = before
	for s in [spy, spy2]:
		s.teardown()
		s.queue_free()


func _piece(id: String, tier: int, flat: Vector3) -> Dictionary:
	var y: float = _game.ctx.terrain.height(flat.x, flat.z) + 1.0
	return {"id": id, "tier": tier, "at": [flat.x, y, flat.z], "size": [1.0, 2.0, 1.0], "yaw_deg": 0.0}


# --- Second Bell (C6) ---------------------------------------------------------------------------

func _release() -> void:
	_source.hold = {"special_held": true}
	_source.press = {"special_pressed": true}
	await _sim(0.4)
	_source.hold = {}
	await physics_frame
	await physics_frame


func _check_bell_gauges() -> void:
	for pilot in GAUGE_PILOTS:
		await _as(pilot)
		_hold(["second_bell"])
		var aim := _aim_flat()
		var near := _spawn(_ball_flat() + aim * 2.5)
		var near2 := _spawn(_ball_flat() + aim * 2.0 + _side() * 1.0)
		await physics_frame
		_struck.clear()
		_special_used.clear()
		_released.clear()
		var id: String = _player.abilities.id_of(AbilityState.SPECIAL)
		await _release()
		_t.eq("%s %s released once" % [pilot, id], _released.size(), 1)
		var released_at: float = float(_released[0][1]) if not _released.is_empty() else -1.0
		_t.eq("%s one bell waits" % pilot, _combat._bells.size(), 1)
		if _combat._bells.is_empty():
			continue
		var bell: Dictionary = _combat._bells[0]
		var burst: float = float(_combat.last_burst.get("damage", 0.0))
		_t.check("%s the release dealt damage" % pilot, burst > 0.0, str(_combat.last_burst))
		_t.eq("%s the footprint stays lit as the committed record" % pilot, is_same(_player.indicator.shapes.get(bell["layer"], {}), bell["shape"]), true)
		_t.eq("%s it is the pilot's colour" % pilot, bell["shape"].get("color"), _player.class_color())
		var charges: int = _special_charges()
		await _sim(0.85)
		_t.eq("%s not rung before 1.0 s" % pilot, [_combat._bells.size(), _combat.last_bell.is_empty()], [1, true])
		_struck.clear()
		await _sim(0.25)
		_t.eq("%s rung once" % pilot, [_combat._bells.size(), _combat.last_bell.is_empty()], [0, false])
		if _combat.last_bell.is_empty():
			continue
		_t.near("%s 1.0 s after the release" % pilot, float(_combat.last_bell["at"]) - released_at, 1.0, 0.0001)
		_t.near("%s at half the release's damage" % pilot, float(_combat.last_bell["damage"]), 0.5 * burst, 0.0001)
		_t.eq("%s item_proc, no shot bits" % pilot, [_combat.last_bell["source"], _combat.last_bell["bits"]], ["item_proc", 0])
		var strikes: Array = _struck.filter(func(s): return s[1] == Combat.SYNERGY)
		_t.check("%s the repeat struck inside the footprint" % pilot, int(_combat.last_bell["hits"]) > 0 and strikes.size() == int(_combat.last_bell["hits"]),
			"%d hits, %d strikes" % [int(_combat.last_bell["hits"]), strikes.size()])
		_t.check("%s each repeat strike is half the release" % pilot, strikes.all(func(s): return absf(float(s[2]) - 0.5 * burst) < 0.0001), str(strikes))
		_t.eq("%s the repeat spends and refills nothing" % pilot, _special_charges(), charges)
		_t.eq("%s the repeat publishes no special or release" % pilot, [_special_used.size(), _released.size()], [1, 1])
		_t.check("%s its drawing is gone" % pilot, not _player.indicator.shapes.has(bell["layer"]), "")
		await _sim(1.2)
		_t.eq("%s and it never rings again" % pilot, [_combat._bells.size(), float(_combat.last_bell.get("at", 0.0))], [0, float(bell["at"])])
	# Planted control: without the item a release queues nothing.
	await _as("pylon_engineer")
	_spawn(_ball_flat() + _aim_flat() * 2.5)
	await _release()
	_t.eq("planted control: without Second Bell a release rings nothing", _combat._bells.size(), 0)


func _check_bell_gather() -> void:
	await _as("tally")
	_hold(["second_bell"])
	var aim := _aim_flat()
	var p := _ball_flat() + aim * 5.0
	p.y = _game.ctx.terrain.height(p.x, p.z)
	var inside := _spawn(p + _side() * 1.5)
	var outside := _spawn(p + _side() * 3.2)
	await physics_frame
	var charges_before: int = _special_charges()
	_combat._tap(AbilityState.SPECIAL, "gather_plate", _combat._tap_gather, func(): return {"point": p, "valid": true})
	await _sim(0.4)
	_t.check("the gather plate landed", not _combat.plate.is_empty() and _special_used.has("gather_plate"), str(_combat.plate))
	_t.eq("one bell waits", _combat._bells.size(), 1)
	if _combat._bells.is_empty() or _combat.plate.is_empty():
		return
	var bell: Dictionary = _combat._bells[0]
	var plate: Dictionary = _combat.plate.duplicate()
	_t.eq("a gather bell at half the radius, on the plate", [bell["mode"], float(bell["shape"]["radius"]), bell["shape"]["centre"]],
		["gather", Weapons.GATHER_RADIUS * 0.5, plate["at"]])
	_t.eq("its ring is lit as the committed record", is_same(_player.indicator.shapes.get(bell["layer"], {}), bell["shape"]), true)
	var charges := _special_charges()
	_t.eq("the tap spent one charge", charges, charges_before - 1)
	# Wait to just before the bell, then across it: only the machine inside the half ring gains one extra pull.
	await _sim(maxf(0.0, float(bell["at"]) - _combat._clock - 0.05))
	var in_before: int = inside.knocks
	var out_before: int = outside.knocks
	var rings_before: int = _combat.effects._rings.size()
	await _sim(0.1)
	_t.eq("the bell rang once", [_combat._bells.size(), _combat.last_bell.get("mode", "")], [0, "gather"])
	_t.eq("the machine inside the half ring takes one extra pull", (inside.knocks - in_before) - (outside.knocks - out_before), 1)
	var rings: Array = _combat.effects._rings
	var drawn := rings.slice(rings_before).filter(func(r): return is_equal_approx(float(r["radius"]), Weapons.GATHER_RADIUS * 0.5))
	_t.eq("its half ring is drawn in Tally's colour", drawn.size() == 1 and drawn[0]["color"] == ClassDef.TALLY_COLOR, true)
	_t.eq("the live plate is never moved, reset or shortened", [_combat.plate.get("at"), _combat.plate.get("until")], [plate["at"], plate["until"]])
	_t.eq("the repeat spends and refills nothing", _special_charges(), charges)
	_t.eq("the repeat publishes no second special", _special_used.size(), 1)
	# Planted control: replaying the gather tap itself would reset the plate's clock.
	var until: float = float(_combat.plate["until"])
	_combat._run_gather(p, true)
	_t.check("planted control: a naive repeat through _run_gather resets the plate", float(_combat.plate["until"]) > until, "")


func _check_bell_echo() -> void:
	await _as("pylon_engineer")
	_hold(["second_bell"])
	_spawn(_ball_flat() + _aim_flat() * 2.5)
	_player.tree._knobs["special_echo"] = 0.5
	await physics_frame
	await _release()
	_t.check("the tree's echo and the bell both wait", not _combat._echo.is_empty() and _combat._bells.size() == 1, "")
	var tolls := 0
	var echoes := 0
	var bell_at := -1.0
	var echo_gone := false
	for i in roundi(3.0 * Engine.physics_ticks_per_second):
		var had_echo: bool = not _combat._echo.is_empty()
		await physics_frame
		if had_echo and _combat._echo.is_empty():
			echoes += 1
		if not _combat.last_bell.is_empty() and float(_combat.last_bell["rung_at"]) != bell_at:
			bell_at = float(_combat.last_bell["rung_at"])
			tolls += 1
		echo_gone = echo_gone or _combat._echo.is_empty()
	_t.eq("holding both gives one echo and one bell, neither starting the other", [echoes, tolls, _combat._bells.size(), _combat._echo.is_empty()],
		[1, 1, 0, true])
	_player.tree._knobs.erase("special_echo")
	# Planted control: a repeat that re-entered the release exit would queue another bell.
	_combat._ring_bell("detonation_gauge", _combat.last_committed["geometry"], {"burst": {}, "breaks": 0})
	_t.eq("planted control: re-entering the exit from a repeat queues a second bell", _combat._bells.size(), 1)
	_combat._clear_verb_items()


func _check_bell_clears() -> void:
	await _as("pylon_engineer")
	_hold(["second_bell"])
	_spawn(_ball_flat() + _aim_flat() * 2.5)
	await _release()
	_t.eq("a bell waits", _combat._bells.size(), 1)
	var layer: String = _combat._bells[0]["layer"] if not _combat._bells.is_empty() else ""
	_combat._start_attempt()
	_t.check("an attempt start clears the bell and its drawing", _combat._bells.is_empty() and not _player.indicator.shapes.has(layer), "")
	await _sim(1.3)
	_t.check("and it never rings", _combat.last_bell.is_empty(), str(_combat.last_bell))


func _check_bell_never() -> void:
	# Plant discharge: the free burst on mounting spends nothing through the kit exits.
	await _as("pylon_engineer")
	_hold(["second_bell"])
	_spawn(_ball_flat() + _aim_flat() * 2.5)
	_combat._on_mounted(_player.ball_position(), 20.0)
	_t.eq("plant discharge fired (special_used)", _special_used.size(), 1)
	await _sim(1.2)
	_t.check("plant discharge never rings the bell", _combat._bells.is_empty() and _combat.last_bell.is_empty(), "")
	_t.check("the run is still in play", _game.flow.in_play(), _game.flow.state_name())
	# Crater Slam: a smash that spends the special for a discharge.
	await _as("pylon_engineer")
	_hold(["second_bell"])
	var smash: String = _player.abilities.id_of(AbilityState.SMASH)
	_equip(AbilityState.SMASH, "crater_slam")
	_spawn(_ball_flat() + _aim_flat() * 2.5)
	_player.abilities.refill()
	var charges := _special_charges()
	_player._on_slammed(_player.ball_position(), 30.0, 1.0)
	_t.check("crater slam fired (spent the special)", _special_charges() == charges - 1 and _special_used.size() == 1, "%d" % _special_charges())
	await _sim(1.2)
	_t.check("crater slam never rings the bell", _combat._bells.is_empty() and _combat.last_bell.is_empty(), "")
	_t.check("the run is still in play", _game.flow.in_play(), _game.flow.state_name())
	_equip(AbilityState.SMASH, smash)
	# An F-key active.
	await _as("pylon_engineer")
	_hold(["second_bell"])
	_game.tuning.set_option("actives", "on")
	_spawn(_ball_flat() + _aim_flat() * 3.0)
	var rack = _combat.get("actives")
	_active_fired = 0
	if rack != null and rack.rack("quake_knock"):
		rack.charges = maxi(1, int(rack.charges))
		_source.press = {"active_pressed": true}
		await _sim(1.5)
	_t.check("the active fired", _active_fired >= 1, "%d" % _active_fired)
	_t.check("an F-key active never rings the bell", _combat._bells.is_empty() and _combat.last_bell.is_empty(), "")
	_t.check("the run is still in play", _game.flow.in_play(), _game.flow.state_name())
	# Planted control: the same pilot's own special release does ring it.
	await _as("pylon_engineer")
	_hold(["second_bell"])
	_spawn(_ball_flat() + _aim_flat() * 2.5)
	await _release()
	_t.eq("planted control: the kit release in the same scene rings it", _combat._bells.size(), 1)
	_combat._clear_verb_items()
	# The ultimate.
	await _as("pylon_engineer")
	_hold(["second_bell"])
	_spawn(_ball_flat() + _aim_flat() * 4.0)
	_ult_started = 0
	_special_used.clear()
	_combat.ultimate.meter.value = 100.0
	_combat.ultimate.press()
	# Watch every tick of the ultimate: no bell may be queued at any point, not only at the end.
	var queued := 0
	var phases := {}
	for i in roundi(6.0 * Engine.physics_ticks_per_second):
		await physics_frame
		queued = maxi(queued, _combat._bells.size())
		phases[_combat.ultimate.phase()] = true
		if _ult_started == 1 and not _combat.ultimate.active():
			break
	# Reaching recover means the flight landed and struck (ultimate.gd _land).
	_t.check("the ultimate ran through its landing to recover and back to idle", _ult_started == 1 and phases.has("recover")
		and not _combat.ultimate.active(), "%d started, %s" % [_ult_started, phases.keys()])
	_t.check("the ultimate never queues or rings the bell", queued == 0 and _combat.last_bell.is_empty(), str(_combat.last_bell))


# --- Long Leash (C7) ----------------------------------------------------------------------------

# One loaded line: cast with no line standing, then held. Returns what the load did.
func _load_run(pilot: String, line_id: String, leash: bool) -> Dictionary:
	await _as(pilot)
	if _player.abilities.id_of(AbilityState.LINE) != line_id:
		_equip(AbilityState.LINE, line_id)
	_hold(["long_leash"] if leash else [])
	_loaded.clear()
	_expired.clear()
	_combat._cast_line(line_id, 1.0)
	var slot = _player.abilities.slot(AbilityState.LINE)
	var out := {"seconds": float(_loaded[0][1]) if not _loaded.is_empty() else -1.0, "cooldown": float(slot.cooldown), "charges": int(slot.charges)}
	await _sim(4.2)
	out["alive_4"] = not _combat.line_load().is_empty()
	await _sim(4.0)
	out["alive_8"] = not _combat.line_load().is_empty()
	out["expired"] = _expired.duplicate()
	return out


# A loaded line biting the world: what the bite fired with.
func _bite_run(leash: bool) -> Dictionary:
	await _as("pylon_engineer")
	_hold(["long_leash"] if leash else [])
	var line_id: String = _player.abilities.id_of(AbilityState.LINE)
	_combat._cast_line(line_id, 1.0)
	var anchor := _ball_flat() + _aim_flat() * 6.0
	anchor.y = _game.ctx.terrain.height(anchor.x, anchor.z)
	_player.kit.hooked = true
	_player.kit.on_body = false
	_player.kit.anchor = anchor
	_combat._bite_load()
	await physics_frame
	var fired: Dictionary = _combat.last_line.duplicate()
	_player.kit.drop_line("reset")
	return {"id": fired.get("id"), "on": fired.get("on"), "fraction": fired.get("fraction"), "mult": fired.get("mult")}


func _check_leash() -> void:
	for pair in [["pylon_engineer", ""], ["tally", "link_clips"], ["tally", "link_double"]]:
		var pilot: String = pair[0]
		await _as(pilot)
		var line_id: String = pair[1] if pair[1] != "" else _player.abilities.id_of(AbilityState.LINE)
		var plain := await _load_run(pilot, line_id, false)
		var leash := await _load_run(pilot, line_id, true)
		_t.near("%s loads for 4.0 s without the leash" % line_id, float(plain["seconds"]), 4.0, 0.0001)
		_t.near("%s loads for 8.0 s with it" % line_id, float(leash["seconds"]), 8.0, 0.0001)
		_t.eq("planted control: %s without the leash has run out by 4.2 s" % line_id, [plain["alive_4"], plain["expired"]], [false, [line_id]])
		_t.eq("%s with the leash still waits at 4.2 s and runs out by 8.2 s" % line_id, [leash["alive_4"], leash["alive_8"], leash["expired"]],
			[true, false, [line_id]])
		_t.eq("%s cooldown and charges are unchanged" % line_id, [leash["cooldown"], leash["charges"]], [plain["cooldown"], plain["charges"]])
	var bite_plain := await _bite_run(false)
	var bite_leash := await _bite_run(true)
	_t.check("precondition: a loaded line bit the world", bite_plain["on"] == "world", str(bite_plain))
	_t.eq("the bite fires the same line, fraction and multiplier with the leash", bite_leash, bite_plain)
	_hold([])
	_t.near("the leash scale is 1 without the item", _combat.leash_scale(), 1.0, 0.0)
