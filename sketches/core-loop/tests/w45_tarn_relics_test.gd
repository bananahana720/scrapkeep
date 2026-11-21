extends SceneTree

# W45-B2 U3 (design-v3/ABILITY-MUTATIONS.md sections 5 A and 8): Tarn's two World 1 kit swaps.
# Gutter Heart swaps the smash to rend_drag (machines no heavier than the ball slide to the crater,
# heavier ones hold, the ball's velocity is never touched). Rake Heart swaps the weapon to
# claw_rake, which fires through claw_sweep's pattern and returns the same arc once, 0.25 s later,
# mirrored, at 0.6 damage as item_proc with no bits. Each rule carries a planted control.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const ClassKit := preload("res://src/ui/class_kit.gd")
const Combat := preload("res://src/combat/combat.gd")
const Grip := preload("res://src/movement/grip.gd")
const Relics := preload("res://src/build/relics.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("w45_tarn_relics_test")
var _game
var _combat
var _player
var _source := Intent.Scripted.new()
var _steps := []
var _index := 0
var _ticks := 0
var _booted := false
var _shots: Array = []
var _fired_before := 0


func _initialize() -> void:
	_check_table()
	_check_proc_guard()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _booted:
		_boot()
		return false
	if _index >= _steps.size():
		quit(_t.verdict())
		return true
	var step: Array = _steps[_index]
	if _ticks == 0:
		(step[0] as Callable).call()
	_ticks += 1
	if _ticks >= int(step[1]):
		(step[2] as Callable).call()
		_index += 1
		_ticks = 0
	return false


func _boot() -> void:
	_booted = true
	_game.ctx.calm = true
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	_player = _game.player
	_game.events.shot_fired.connect(func(weapon_id: String, _from: Vector3, _to: Vector3): _shots.append(weapon_id))
	_steps = [
		[_noop, 1, _check_rake_resolves],
		[_noop, 1, _check_rake_return],
		[_noop, 1, _check_rake_transformer],
		[_live_start, 3, _live_release],
		[_noop, 30, _check_live],
		[_noop, 1, _check_drag],
	]


func _noop() -> void:
	pass


# --- the data: both relics, the words, the offer ---------------------------------------

func _check_table() -> void:
	_t.eq("the table validates", Relics.validate(), [])
	for id in ["gutter_heart", "rake_heart"]:
		var row := Relics.row(id)
		_t.check("%s is a World 1 Tarn row" % id, int(row["world"]) == 1 and row["pilots"] == ["tarn"],
			"world %s, pilots %s" % [row["world"], row["pilots"]])
		_t.check("%s name and text hold the caps" % id,
			String(row["name"]).split(" ", false).size() <= Relics.MAX_NAME_WORDS and String(row["text"]).split(" ", false).size() <= Relics.MAX_TEXT_WORDS,
			"%s / %s" % [row["name"], row["text"]])
		var swap := Relics.swap_of(id)
		_t.check("%s swaps to a row with a WORDS entry" % id, ClassKit.WORDS.has(swap) and AbilityState.ABILITIES.has(swap), swap)
	_t.eq("gutter heart is the smash swap", [Relics.slot_of("gutter_heart"), Relics.swap_of("gutter_heart"), Relics.row("gutter_heart")["maker"]],
		[AbilityState.SMASH, "rend_drag", "waking"])
	_t.eq("rake heart is the weapon swap", [Relics.slot_of("rake_heart"), Relics.swap_of("rake_heart"), Relics.row("rake_heart")["maker"]],
		[AbilityState.WEAPON, "claw_rake", "redjaw"])
	_t.check("the texts say machines", "machines" in String(Relics.row("gutter_heart")["text"]), Relics.row("gutter_heart")["text"])
	# Tally's and the cannon's swaps (U4, U5) join World 1 beside these; count the rest.
	var swaps := Relics.ids().filter(func(id): return int(Relics.row(id)["world"]) == 1 and Relics.swap_of(id) != "" and not Relics.fits(id, "tally") and not Relics.fits(id, "remembered_cannon"))
	_t.eq("World 1 has five swaps outside Tally and the cannon", swaps.size(), 5)
	var tarn := Relics.eligible("tarn", {}, null, 1)
	_t.check("tarn is offered both beside its cooldown relics",
		"gutter_heart" in tarn and "rake_heart" in tarn and "taut_cable" in tarn and "vice_heart" in tarn, str(tarn))
	_t.check("a held smash relic hides only its own slot", "rake_heart" in Relics.eligible("tarn", {AbilityState.SMASH: "gutter_heart"})
		and not "gutter_heart" in Relics.eligible("tarn", {AbilityState.SMASH: "gutter_heart"}), "one relic per held slot")
	# Planted controls: each of these must be refused.
	var ultimate: Dictionary = Relics.ROWS.duplicate(true)
	ultimate["rake_heart"]["slot"] = "ultimate"
	var wordy: Dictionary = Relics.ROWS.duplicate(true)
	wordy["gutter_heart"]["text"] = "one two three four five six seven eight nine"
	var wrong_slot: Dictionary = Relics.ROWS.duplicate(true)
	wrong_slot["gutter_heart"]["slot"] = AbilityState.WEAPON
	_t.check("planted ultimate relic is refused", not Relics.validate(ultimate).is_empty(), str(Relics.validate(ultimate)))
	_t.check("planted nine-word text is refused", not Relics.validate(wordy).is_empty(), str(Relics.validate(wordy)))
	_t.check("planted swap in the wrong slot is refused", not Relics.validate(wrong_slot).is_empty(), str(Relics.validate(wrong_slot)))


# Proc depth 1: the first sweep follows, the return pass (item_proc) never does. The planted
# control gives the return pass the weapon tag and the one-per-cause count runs away.
func _check_proc_guard() -> void:
	_t.check("a weapon press queues a return", Combat.rake_follows("weapon", "claw_rake"), "")
	_t.check("an item_proc volley queues none", not Combat.rake_follows("item_proc", "claw_rake"), "")
	_t.check("the plain sweep queues none", not Combat.rake_follows("weapon", ""), "")
	_t.eq("a real return chain is one return", _returns_after(5, "item_proc"), 1)
	_t.check("a planted weapon-tagged repeat loops and is caught", _returns_after(5, "weapon") > 1, "returns %d" % _returns_after(5, "weapon"))


func _returns_after(depth: int, tag: String) -> int:
	var returns := 0
	var source := "weapon"
	for i in depth:
		if not Combat.rake_follows(source, "claw_rake"):
			break
		returns += 1
		source = tag
	return returns


# --- Rake Heart in the running game ----------------------------------------------------

func _as_tarn() -> void:
	var def: Resource = ClassDef.by_id("tarn")
	_game.run.class_def = def
	_player.fit_class(def)
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.queue_free()
	_source.hold = {}
	_source.press = {}
	var at: Vector3 = _game.ctx.terrain.spawn_point(1)
	_player.reset_to(at)
	_player.body().global_position = at
	_player.abilities.refill()
	_game.camera.snap(Vector3(0.0, 0.0, -1.0))
	_game.camera.pitch = 0.0


func _equip_rake() -> void:
	_as_tarn()
	_player.abilities.swap(AbilityState.WEAPON, "claw_rake")
	_player._refit()
	_combat.bolts.clear()
	_combat._rakes.clear()


func _live_bolts() -> Array:
	return _combat.bolts._bolts


func _check_rake_resolves() -> void:
	_equip_rake()
	var raw: String = _player.abilities.id_of(AbilityState.WEAPON)
	_t.eq("the slot holds claw_rake", raw, "claw_rake")
	_t.eq("it fires as claw_sweep", _combat.active_weapon(), "claw_sweep")
	# Planted control: the raw swapped id has no pattern, so a lookup that skipped the resolution fires nothing.
	_t.check("an unresolved claw_rake would not fire", not _combat._patterns.has(raw) and _combat._patterns.has(_combat.active_weapon()),
		"patterns hold claw_rake: %s" % _combat._patterns.has(raw))
	_as_tarn()
	_t.eq("an unswapped Tarn still fires as claw_sweep", _combat.active_weapon(), "claw_sweep")


func _check_rake_return() -> void:
	_equip_rake()
	var first_fired: int = _combat.bolts.fired
	_combat._fire(_combat.active_weapon())
	var first: Array = _live_bolts().duplicate(true)
	var count: int = first.size()
	_t.check("the first sweep is the player's own weapon fire", count > 0 and first.all(func(b): return b["source"] == "weapon"),
		"%d bolts %s" % [count, first.map(func(b): return b["source"])])
	_t.eq("one return is queued", _combat._rakes.size(), 1)
	_t.near("it waits 0.25 s", float(_combat._rakes[0]["at"]) - _combat._clock, Combat.RAKE_DELAY, 0.0001)
	_t.eq("nothing returns early", _live_bolts().size(), count)
	var base_damage: float = float(first[0]["damage"])
	var forward: Vector3 = _combat._rakes[0]["forward"]
	_combat._clock = float(_combat._rakes[0]["at"]) - 0.01
	_combat._tick_rakes()
	_t.eq("still nothing 0.01 s early", _live_bolts().size(), count)
	_combat._clock += 0.02
	_combat._tick_rakes()
	var all: Array = _live_bolts()
	var back: Array = all.slice(count)
	_t.eq("the return is one more sweep", back.size(), count)
	_t.check("the return fires as item_proc with no bits", back.all(func(b): return b["source"] == "item_proc" and int(b["bits"]) == 0),
		str(back.map(func(b): return [b["source"], b["bits"]])))
	_t.near("at 0.6 damage", float(back[0]["damage"]), base_damage * Combat.RAKE_DAMAGE, 0.0001)
	_t.check("the return starts nothing", _combat._rakes.is_empty(), "queue %d" % _combat._rakes.size())
	_combat._clock += 10.0
	_combat._tick_rakes()
	_t.eq("one cause, two sweeps in all", _combat.bolts.fired - first_fired, count * 2)
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward).normalized()
	var mirrored := true
	for i in count:
		var a: Vector3 = first[i]["dir"]
		var b: Vector3 = back[i]["dir"]
		mirrored = mirrored and absf(a.dot(forward) - b.dot(forward)) < 0.001 and absf(a.dot(up) - b.dot(up)) < 0.001 \
			and absf(a.dot(right) + b.dot(right)) < 0.001
	_t.check("the arc comes back mirrored about the aim line", mirrored, "%d bolts" % count)
	# An item_proc volley (tree volley, Kick Shot) queues no return.
	_combat._rakes.clear()
	_combat._fire(_combat.active_weapon(), "item_proc")
	_t.check("an item_proc volley queues no return", _combat._rakes.is_empty(), "queue %d" % _combat._rakes.size())


# A transformer on claw_sweep reaches the return: the cross comes back as a cross.
func _check_rake_transformer() -> void:
	_equip_rake()
	var plain: Resource = _combat._patterns["claw_sweep"]
	var crossed: Resource = Weapons.base("claw_sweep").transformed(["cross_split"])
	crossed.rotation_deg = 30.0
	_combat._patterns["claw_sweep"] = crossed
	_combat._fire(_combat.active_weapon())
	var count: int = _live_bolts().size()
	_combat._clock += 1.0
	_combat._tick_rakes()
	var back: Array = _live_bolts().slice(count)
	_combat._patterns["claw_sweep"] = plain
	_t.check("a crossed sweep returns crossed", count > 1 and back.size() == count, "first %d, return %d" % [count, back.size()])
	_t.check("the crossed return is still one item_proc pass", back.all(func(b): return b["source"] == "item_proc") and _combat._rakes.is_empty(), "")


# End to end: held fire through the real tick fires claw_sweep and every press returns once.
func _live_start() -> void:
	_equip_rake()
	_shots.clear()
	_fired_before = _combat.bolts.fired
	_source.hold = {"fire_held": true}


func _live_release() -> void:
	_source.hold = {}


func _check_live() -> void:
	var per: int = _combat.last_shot["bolts"]
	_t.check("held fire fires claw_sweep through the pattern", not _shots.is_empty() and _shots.all(func(w): return w == "claw_sweep"), str(_shots))
	_t.eq("each press returned exactly once", _combat.bolts.fired - _fired_before, _shots.size() * per * 2)
	_t.check("no return is left waiting", _combat._rakes.is_empty(), "queue %d" % _combat._rakes.size())


# --- Gutter Heart ----------------------------------------------------------------------

func _spawn(kind: String, flat: Vector3) -> Node3D:
	var ground: float = _game.ctx.terrain.height(flat.x, flat.z)
	return _combat.spawn_enemy(kind, Vector3(flat.x, ground + 1.5, flat.z))


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _check_drag() -> void:
	_as_tarn()
	_player.abilities.swap(AbilityState.SMASH, "rend_drag")
	_player._refit()
	_t.eq("rend_drag keeps the rend flavour", _player.kit.smash_flavour, "rend")
	var ball: Vector3 = _player.ball_position()
	var at := _flat(ball)
	var light: Node3D = _spawn("swarm_remnant", at + Vector3(4.0, 0.0, 0.0))
	var heavy: Node3D = _spawn("chaser", at + Vector3(-4.0, 0.0, 0.0))
	var light_from := _flat(light.global_position)
	var heavy_from := _flat(heavy.global_position)
	var heft: float = _player.heft()
	_t.check("the swarm machine is lighter and the chaser heavier than the ball",
		Grip.heft_of(light) <= heft and Grip.heft_of(heavy) > heft, "ball %.2f, light %.2f, heavy %.2f" % [heft, Grip.heft_of(light), Grip.heft_of(heavy)])
	var velocity: Vector3 = _player.state.velocity
	_player._smash_rend(ball, 30.0)
	# A swarm remnant spawns with its swarm, so "lighter" is every body that is no heavier than the ball.
	var sliding: Array = _player._drags.keys().map(func(id): return instance_from_id(id))
	_t.check("the lighter machine slides and the heavier one does not",
		_player._drags.has(light.get_instance_id()) and not _player._drags.has(heavy.get_instance_id())
		and sliding.all(func(e): return Grip.heft_of(e) <= heft), "%d sliding" % sliding.size())
	for i in 30:
		_player._step_drags(1.0 / 60.0)
	_t.check("the lighter machine ends at the crater centre in 0.4 s", _flat(light.global_position).distance_to(at) < 0.35 and _player._drags.is_empty(),
		"from %.2f m to %.2f m, drags %d" % [light_from.distance_to(at), _flat(light.global_position).distance_to(at), _player._drags.size()])
	_t.check("the heavier machine holds", _flat(heavy.global_position).distance_to(heavy_from) < 0.01,
		"moved %.3f m" % _flat(heavy.global_position).distance_to(heavy_from))
	_t.check("the ball's velocity is untouched", _player.state.velocity == velocity, "%s vs %s" % [_player.state.velocity, velocity])
	# Even with the ball is a drag too: heft <= heft.
	var even := Grip.heft_of(heavy)
	_player.heft_of = func(): return even
	heavy.global_position = Vector3(heavy_from.x, heavy.global_position.y, heavy_from.z)
	_player._smash_rend(ball, 30.0)
	_t.check("a machine exactly as heavy as the ball slides", _player._drags.has(heavy.get_instance_id()), str(_player._drags.keys()))
	_player._drags.clear()
	# Planted control: the base rend_slam row never drags, so the lighter machine stays put.
	_player.abilities.swap(AbilityState.SMASH, "rend_slam")
	_player._refit()
	light.global_position = Vector3(light_from.x, light.global_position.y, light_from.z)
	_player._smash_rend(ball, 30.0)
	_t.check("the plain rend_slam drags nothing", _player._drags.is_empty(), str(_player._drags.keys()))
