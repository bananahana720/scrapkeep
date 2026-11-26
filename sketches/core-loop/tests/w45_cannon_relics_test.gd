extends SceneTree

# W45-B2 U5 (design-v3/ABILITY-MUTATIONS.md sections 5 A and 8): the remembered cannon's two World 1 kit swaps.
# Walking Lane swaps the weapon to cannon_lane_walk, which fires through cannon_lane's pattern and walks a
# second lane within 2 s up to 6 m further from where the first ended; the chain is two links, so a third
# call starts fresh. Rush Wake swaps the smash to cannon_rush_wake, which keeps the rush flavour and lays one
# half-damage item_proc lane back along the rush's travel line, never another. Neither touches the ball's
# velocity. Each rule carries a planted control.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const ClassKit := preload("res://src/ui/class_kit.gd")
const Combat := preload("res://src/combat/combat.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const Palette := preload("res://src/core/palette.gd")
const Relics := preload("res://src/build/relics.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("w45_cannon_relics_test")
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
		[_noop, 1, _check_walk_resolves],
		[_noop, 1, _check_walk_chain],
		[_noop, 1, _check_walk_march_overdrive],
		[_noop, 1, _check_walk_window],
		[_noop, 1, _check_walk_plain],
		[_noop, 1, _check_walk_reset],
		[_live_start, 3, _live_release],
		[_noop, 30, _check_live],
		[_noop, 1, _check_wake_row],
		[_noop, 1, _check_wake_lane],
		[_noop, 1, _check_wake_edges],
		[_noop, 1, _check_wake_plain],
	]


func _noop() -> void:
	pass


# --- the data: both relics, the words, the offer ---------------------------------------

func _check_table() -> void:
	_t.eq("the table validates", Relics.validate(), [])
	for id in ["walking_lane", "rush_wake"]:
		var row := Relics.row(id)
		_t.check("%s is a World 1 cannon row" % id, int(row["world"]) == 1 and row["pilots"] == ["remembered_cannon"],
			"world %s, pilots %s" % [row["world"], row["pilots"]])
		_t.check("%s name and text hold the caps" % id,
			String(row["name"]).split(" ", false).size() <= Relics.MAX_NAME_WORDS and String(row["text"]).split(" ", false).size() <= Relics.MAX_TEXT_WORDS,
			"%s / %s" % [row["name"], row["text"]])
		var swap := Relics.swap_of(id)
		_t.check("%s swaps to a row with a WORDS entry" % id, ClassKit.WORDS.has(swap) and AbilityState.ABILITIES.has(swap), swap)
	_t.eq("walking lane is the weapon swap", [Relics.slot_of("walking_lane"), Relics.swap_of("walking_lane"), Relics.row("walking_lane")["maker"],
		Relics.row("walking_lane")["text"]], [AbilityState.WEAPON, "cannon_lane_walk", "mind_glass", "Second call walks the lane further out"])
	_t.eq("rush wake is the smash swap", [Relics.slot_of("rush_wake"), Relics.swap_of("rush_wake"), Relics.row("rush_wake")["maker"],
		Relics.row("rush_wake")["text"]], [AbilityState.SMASH, "cannon_rush_wake", "waking", "Rush landings leave a lane behind"])
	_t.eq("the swap rows' icons", [AbilityState.ABILITIES["cannon_lane_walk"]["icon"], AbilityState.ABILITIES["cannon_rush_wake"]["icon"]],
		["ab_cannon_weapon", "ab_cannon_smash"])
	var lane: Dictionary = AbilityState.ABILITIES["cannon_lane_walk"]
	_t.check("the walking row mirrors the lane and borrows its pattern",
		lane["pattern"] == "cannon_lane" and lane["family"] == "lane" and lane["mutation"] == "cannon_lane_walk", str(lane))
	var rush: Dictionary = AbilityState.ABILITIES["cannon_rush_wake"]
	_t.check("the wake row keeps the rush flavour and family",
		rush["flavour"] == "rush" and rush["family"] == "rush" and rush["mutation"] == "cannon_rush_wake", str(rush))
	var cannon := Relics.eligible("remembered_cannon", {}, null, 1)
	_t.check("the cannon is offered both beside its cooldown relics",
		"walking_lane" in cannon and "rush_wake" in cannon and "kick_spring" in cannon and "brace_pin" in cannon, str(cannon))
	_t.check("neither is offered to another pilot", not Relics.fits("walking_lane", "tarn") and not Relics.fits("rush_wake", "tally"), "")
	_t.check("a held smash relic hides only its own slot", "walking_lane" in Relics.eligible("remembered_cannon", {AbilityState.SMASH: "rush_wake"})
		and not "rush_wake" in Relics.eligible("remembered_cannon", {AbilityState.SMASH: "rush_wake"}), "one relic per held slot")
	# Planted controls: each of these must be refused.
	var ultimate: Dictionary = Relics.ROWS.duplicate(true)
	ultimate["walking_lane"]["slot"] = "ultimate"
	var wordy: Dictionary = Relics.ROWS.duplicate(true)
	wordy["rush_wake"]["text"] = "one two three four five six seven eight nine"
	var wrong_slot: Dictionary = Relics.ROWS.duplicate(true)
	wrong_slot["rush_wake"]["slot"] = AbilityState.WEAPON
	_t.check("planted ultimate relic is refused", not Relics.validate(ultimate).is_empty(), str(Relics.validate(ultimate)))
	_t.check("planted nine-word text is refused", not Relics.validate(wordy).is_empty(), str(Relics.validate(wordy)))
	_t.check("planted swap in the wrong slot is refused", not Relics.validate(wrong_slot).is_empty(), str(Relics.validate(wrong_slot)))


# Proc depth 1: only the player's own landing lays a wake; the wake lane (item_proc) never does. The
# planted control gives the wake lane the landing tag and the one-per-cause count runs away.
func _check_proc_guard() -> void:
	_t.check("a rush landing lays a wake", Combat.wake_follows("drop_or_slam", "cannon_rush_wake"), "")
	_t.check("an item_proc lane lays none", not Combat.wake_follows("item_proc", "cannon_rush_wake"), "")
	_t.check("the plain rush lays none", not Combat.wake_follows("drop_or_slam", "cannon_rush"), "")
	_t.eq("a real wake chain is one lane", _wakes_after(5, "item_proc"), 1)
	_t.check("a planted landing-tagged repeat loops and is caught", _wakes_after(5, "drop_or_slam") > 1, "wakes %d" % _wakes_after(5, "drop_or_slam"))
	var end := Vector3(3.0, 0.0, 0.0)
	_t.check("walking needs the walking mutation", not Combat.walk_extends("cannon_lane", {"end": end, "at": 0.0}, 0.5)
		and not Combat.walk_extends("", {"end": end, "at": 0.0}, 0.5), "")
	_t.check("walking needs an open link", not Combat.walk_extends("cannon_lane_walk", {}, 0.5), "")
	_t.check("the window is closed at exactly 2 s and shut after", Combat.walk_extends("cannon_lane_walk", {"end": end, "at": 0.0}, Combat.WALK_WINDOW)
		and not Combat.walk_extends("cannon_lane_walk", {"end": end, "at": 0.0}, Combat.WALK_WINDOW + 0.01), "")


func _wakes_after(depth: int, tag: String) -> int:
	var wakes := 0
	var source := "drop_or_slam"
	for i in depth:
		if not Combat.wake_follows(source, "cannon_rush_wake"):
			break
		wakes += 1
		source = tag
	return wakes


# --- the running game ------------------------------------------------------------------

func _as_cannon() -> void:
	var def: Resource = ClassDef.by_id("remembered_cannon")
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
	_player.kit.slamming = false
	_combat._free_cannon()


func _equip_walk() -> void:
	_as_cannon()
	_player.abilities.swap(AbilityState.WEAPON, "cannon_lane_walk")
	_player._refit()
	_combat._free_cannon()


func _equip_wake() -> void:
	_as_cannon()
	_player.abilities.swap(AbilityState.SMASH, "cannon_rush_wake")
	_player._refit()
	_combat._free_cannon()


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _lane(entry: Dictionary):
	return entry["hazards"][0]


func _end_of(h) -> Vector3:
	return h.centre + h.heading * h.length


# The lanes the cannon has committed so far, in order.
func _lanes(source: String = "") -> Array:
	return _combat._cannon.filter(func(e): return e["family"] == "lane" and (source == "" or e["source"] == source))


func _fire_walk() -> Dictionary:
	_combat._fire_cannon_lane(_combat.active_weapon())
	return _combat._cannon.back()


# --- Walking Lane -----------------------------------------------------------------------

func _check_walk_resolves() -> void:
	_equip_walk()
	var raw: String = _player.abilities.id_of(AbilityState.WEAPON)
	_t.eq("the slot holds cannon_lane_walk", raw, "cannon_lane_walk")
	_t.eq("it fires as cannon_lane", _combat.active_weapon(), "cannon_lane")
	# Planted control: the raw swapped id has no pattern, so a lookup that skipped the resolution fires nothing.
	_t.check("an unresolved cannon_lane_walk would not fire", not _combat._patterns.has(raw) and _combat._patterns.has(_combat.active_weapon()),
		"patterns hold cannon_lane_walk: %s" % _combat._patterns.has(raw))
	_t.eq("the walking row is a lane weapon", _player.abilities.cap(AbilityState.WEAPON, "family", ""), "lane")
	_as_cannon()
	_t.eq("an unswapped cannon still fires as cannon_lane", _combat.active_weapon(), "cannon_lane")


func _check_walk_chain() -> void:
	_equip_walk()
	var velocity: Vector3 = _player.state.velocity
	var ball: Vector3 = _player.ball_position()
	var first := _fire_walk()
	var h1 = _lane(first)
	var reach: float = Weapons.CANNON_LANE_REACH * _game.ctx.tuning.mod("weapon_range")
	_t.check("the first lane is the ordinary lane from the ball",
		first["family"] == "lane" and first["source"] == "weapon" and _flat(h1.centre).distance_to(_flat(ball)) < 0.01
		and is_equal_approx(h1.length, reach - MindAttacks.LANE_HALF), "centre %s, length %.2f" % [h1.centre, h1.length])
	_t.check("it is committed geometry drawn before the strike, in the pilot colour, never HAZARD",
		h1.warn_seconds >= Hazard.MIN_WARN and is_equal_approx(h1.warn_seconds, MindAttacks.LANE_WARN)
		and h1.color == ClassDef.CANNON_COLOR and h1.color != Palette.HAZARD, "warn %.2f" % h1.warn_seconds)
	_t.check("one link is open after it", not _combat._walk.is_empty() and _combat._walk["end"] == _end_of(h1), str(_combat._walk))
	var end1 := _end_of(h1)
	_combat._clock += 1.5
	var second := _fire_walk()
	var h2 = _lane(second)
	_t.check("a call inside 2 s starts where the last lane ended",
		_flat(h2.centre).distance_to(_flat(end1)) < 0.01, "starts %s, last ended %s" % [h2.centre, end1])
	_t.near("and runs 6 m further", h2.length, Combat.WALK_REACH, 0.001)
	_t.check("along the same aim", h2.heading.dot(h1.heading) > 0.9999, "dot %.5f" % h2.heading.dot(h1.heading))
	_t.check("each link is its own committed lane in the pilot colour",
		second["source"] == "weapon" and h2.warn_seconds >= Hazard.MIN_WARN and h2.color == ClassDef.CANNON_COLOR and h2.color != Palette.HAZARD
		and _lanes().size() == 2, "%d lanes" % _lanes().size())
	_t.check("the walk resets after two links", _combat._walk.is_empty(), str(_combat._walk))
	# The third call starts fresh at the ball. Planted control: an un-reset walk would extend from link 2's end.
	var end2 := _end_of(h2)
	_combat._clock += 0.5
	_t.check("planted: an un-reset walk would extend a third call past link 2",
		Combat.walk_extends("cannon_lane_walk", {"end": end2, "at": _combat._clock - 0.5}, _combat._clock), "")
	var third := _fire_walk()
	var h3 = _lane(third)
	_t.check("a third call does not extend: it starts at the ball and runs the full lane",
		_flat(h3.centre).distance_to(_flat(ball)) < 0.01 and _flat(h3.centre).distance_to(_flat(end2)) > 5.0
		and is_equal_approx(h3.length, reach - MindAttacks.LANE_HALF), "starts %s, link 2 ended %s" % [h3.centre, end2])
	_t.check("and opens a fresh chain", not _combat._walk.is_empty() and _combat._walk["end"] == _end_of(h3), str(_combat._walk))
	_t.check("the ball's velocity is untouched", _player.state.velocity == velocity, "%s vs %s" % [_player.state.velocity, velocity])


func _check_walk_march_overdrive() -> void:
	var march_od := Relics.overdrive_of("march_lane")
	_t.near("World 2 march_lane carries 1.3 overdrive", march_od, 1.3, 0.0001)
	_t.near("World 1 walking_lane keeps 1.0 overdrive", Relics.overdrive_of("walking_lane"), 1.0, 0.0001)
	_as_cannon()
	var run = _game.ctx.run
	var build = _game.ctx.build
	run.parts.clear()
	run.add_part(Relics.part_of("walking_lane"), "test")
	build.sync_relics()
	_combat._free_cannon()
	var w1_first := _fire_walk()
	_combat._clock += 0.5
	var w1_second := _fire_walk()
	var w1_h2 = _lane(w1_second)
	_t.near("World 1 walking_lane walked length stays WALK_REACH", w1_h2.length, Combat.WALK_REACH, 0.001)
	_t.near("World 1 walking_lane walked damage stays baseline", float(w1_second["damage"]), float(w1_first["damage"]), 0.001)
	_t.near("World 1 walking_lane records 1.0 overdrive", float(_combat.last_shot["overdrive"]), 1.0, 0.001)

	run.parts.clear()
	run.add_part(Relics.part_of("march_lane"), "test")
	build.sync_relics()
	_combat._free_cannon()
	var m_first := _fire_walk()
	var m_h1 = _lane(m_first)
	_t.near("World 2 march_lane first link stays baseline damage", float(m_first["damage"]), float(w1_first["damage"]), 0.001)
	_t.near("World 2 march_lane first link records 1.0 overdrive", float(_combat.last_shot["overdrive"]), 1.0, 0.001)
	var m_end1 := _end_of(m_h1)
	_combat._clock += 0.5
	var m_second := _fire_walk()
	var m_h2 = _lane(m_second)
	_t.check("World 2 march_lane second link still starts where link 1 ended",
		_flat(m_h2.centre).distance_to(_flat(m_end1)) < 0.01, "starts %s, last ended %s" % [m_h2.centre, m_end1])
	_t.near("World 2 march_lane overdrives walked reach by 1.3x", m_h2.length, Combat.WALK_REACH * march_od, 0.001)
	_t.near("World 2 march_lane overdrives walked damage by 1.3x", float(m_second["damage"]), float(m_first["damage"]) * march_od, 0.001)
	_t.near("World 2 march_lane records 1.3 overdrive on walked shot", float(_combat.last_shot["overdrive"]), march_od, 0.001)
	_t.check("World 2 march_lane resets the chain after two links", _combat._walk.is_empty(), str(_combat._walk))

	run.parts.clear()
	_player.abilities.swap(AbilityState.WEAPON, "cannon_lane_walk")
	_player._refit()
	_combat._free_cannon()
	var p_first := _fire_walk()
	_combat._clock += 0.5
	var p_second := _fire_walk()
	_t.near("planted: removing march_lane drops walked length back to WALK_REACH", _lane(p_second).length, Combat.WALK_REACH, 0.001)
	_t.near("planted: removing march_lane drops walked damage back to baseline", float(p_second["damage"]), float(p_first["damage"]), 0.001)
	_t.near("planted: removing march_lane drops recorded overdrive back to 1.0", float(_combat.last_shot["overdrive"]), 1.0, 0.001)


func _check_walk_window() -> void:
	_equip_walk()
	var ball: Vector3 = _player.ball_position()
	var first := _fire_walk()
	var end1 := _end_of(_lane(first))
	_combat._clock += Combat.WALK_WINDOW - 0.001
	var edge := _fire_walk()
	_t.check("a call just inside 2 s still walks", _flat(_lane(edge).centre).distance_to(_flat(end1)) < 0.01, "%s" % _lane(edge).centre)
	_combat._free_cannon()
	first = _fire_walk()
	end1 = _end_of(_lane(first))
	_combat._clock += Combat.WALK_WINDOW + 0.05
	var late := _fire_walk()
	var h = _lane(late)
	_t.check("a call after 2 s starts fresh at the ball",
		_flat(h.centre).distance_to(_flat(ball)) < 0.01 and _flat(h.centre).distance_to(_flat(end1)) > 5.0, "%s" % h.centre)
	_t.check("and a fresh link is open for the next call", not _combat._walk.is_empty() and _combat._walk["at"] == _combat._clock, str(_combat._walk))


func _check_walk_plain() -> void:
	_as_cannon()
	var ball: Vector3 = _player.ball_position()
	var a := _fire_walk()
	_combat._clock += 0.2
	var b := _fire_walk()
	_t.check("the plain cannon_lane never walks: both lanes start at the ball",
		_flat(_lane(a).centre).distance_to(_flat(ball)) < 0.01 and _flat(_lane(b).centre).distance_to(_flat(ball)) < 0.01
		and is_equal_approx(_lane(b).length, _lane(a).length), "%s and %s" % [_lane(a).centre, _lane(b).centre])
	_t.check("and keeps no link", _combat._walk.is_empty(), str(_combat._walk))


# A stage entry, an attempt and a run start leave no walk or wake behind.
func _check_walk_reset() -> void:
	_equip_walk()
	_fire_walk()
	_t.check("a link is open", not _combat._walk.is_empty(), "")
	_combat._on_stage_entered(1, true)
	_t.check("a stage entry or retry clears the walk and the lanes", _combat._walk.is_empty() and _combat._cannon.is_empty(),
		"walk %s, lanes %d" % [_combat._walk, _combat._cannon.size()])
	_fire_walk()
	_combat._free_cannon()
	_t.check("a run reset clears the walk", _combat._walk.is_empty(), str(_combat._walk))
	_equip_walk()
	_fire_walk()
	_combat._wake = {"from": Vector3.ZERO, "until": INF}
	_combat._start_attempt()
	_t.check("an attempt start clears the walk and the wake", _combat._walk.is_empty() and _combat._wake.is_empty(),
		"walk %s, wake %s" % [_combat._walk, _combat._wake])


# End to end: press-hold-release fire through the real tick fires cannon_lane's pattern.
func _live_start() -> void:
	_equip_walk()
	_shots.clear()
	_fired_before = _combat.volleys
	_source.press = {"fire_pressed": true}
	_source.hold = {"fire_held": true}


func _live_release() -> void:
	_source.hold = {}
	_source.press = {"fire_released": true}


func _check_live() -> void:
	_t.check("held fire fires the lane through the pattern", not _shots.is_empty() and _shots.all(func(w): return w == "cannon_lane"), str(_shots))
	_t.eq("every shot is a committed lane", _lanes("weapon").size(), _combat.volleys - _fired_before)


# --- Rush Wake --------------------------------------------------------------------------

func _check_wake_row() -> void:
	_equip_wake()
	_t.eq("rush_wake keeps the rush flavour", _player.kit.smash_flavour, "rush")
	_t.eq("and the rush family", _player.abilities.cap(AbilityState.SMASH, "family", ""), "rush")
	_t.eq("the slot holds cannon_rush_wake", _player.abilities.id_of(AbilityState.SMASH), "cannon_rush_wake")


# A slam from A lands at B: the rush ring and one half-damage lane back toward A.
func _check_wake_lane() -> void:
	_equip_wake()
	var velocity: Vector3 = _player.state.velocity
	var start: Vector3 = _player.ball_position()
	_player.kit.slamming = true
	_combat._track_wake()
	_t.check("the slam's start is recorded", not _combat._wake.is_empty() and _combat._wake["from"] == start, str(_combat._wake))
	var landing: Vector3 = _combat._floor_at(start + Vector3(9.0, 0.0, 0.0) + Vector3.UP)
	_player.body().global_position = landing + Vector3.UP
	_combat._clock += 0.5
	_player.kit.slamming = false
	_combat._track_wake()
	_combat._on_cannon_slammed(landing, 1.0, 1.0)
	_t.eq("a landing commits the rush and one lane", _combat._cannon.map(func(e): return e["family"]), ["rush", "lane"])
	var rush: Dictionary = _combat._cannon[0]
	var wake: Dictionary = _combat._cannon[1]
	var h = _lane(wake)
	_t.check("the rush ring is the plain landing", rush["source"] == "drop_or_slam" and is_equal_approx(rush["damage"], Weapons.RUSH_DAMAGE),
		"%s %.1f" % [rush["source"], rush["damage"]])
	_t.eq("the wake is an item_proc lane", wake["source"], "item_proc")
	_t.near("at half the lane's damage", float(wake["damage"]), Weapons.LANE_DAMAGE * Combat.WAKE_DAMAGE, 0.0001)
	_t.near("half is 0.5", Combat.WAKE_DAMAGE, 0.5, 0.0001)
	_t.check("it starts at the landing", _flat(h.centre).distance_to(_flat(landing)) < 0.01, "%s vs %s" % [h.centre, landing])
	var travel := _flat(start - landing).normalized()
	_t.check("and runs back along the rush's travel line", h.heading.dot(travel) > 0.9999, "heading %s, travel %s" % [h.heading, travel])
	_t.check("with the lane's own telegraph and pilot colour, never HAZARD",
		is_equal_approx(h.warn_seconds, MindAttacks.LANE_WARN) and h.warn_seconds >= Hazard.MIN_WARN and h.color == ClassDef.CANNON_COLOR and h.color != Palette.HAZARD,
		"warn %.2f" % h.warn_seconds)
	_t.check("the start is spent", _combat._wake.is_empty(), str(_combat._wake))
	_t.check("the wake never opens a walk", _combat._walk.is_empty(), str(_combat._walk))
	_t.check("the ball's velocity is untouched", _player.state.velocity == velocity, "%s vs %s" % [_player.state.velocity, velocity])
	# One repeat only: striking the wake lays nothing, and the item_proc lane is no landing.
	var count: int = _combat._cannon.size()
	var enemy: Node3D = _combat.spawn_enemy("chaser", _flat(landing) + travel * 4.0 + Vector3.UP * (landing.y + 1.0))
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var before: int = _combat._cannon_count
	_combat._cannon_strike(wake, h, [enemy])
	_t.check("the wake's strike lays no further lane", _combat._cannon.size() == count and _combat._cannon_count == before
		and _combat._walk.is_empty() and _combat._wake.is_empty(), "%d entries, was %d" % [_combat._cannon.size(), count])
	_t.check("the strike is an item_proc hit", wake["struck"].size() == 1, "%d struck" % wake["struck"].size())


func _check_wake_edges() -> void:
	_equip_wake()
	var landing: Vector3 = _combat._floor_at(_player.ball_position() + Vector3.UP)
	# No recorded start: nothing laid.
	_combat._on_cannon_slammed(landing, 1.0, 1.0)
	_t.eq("a landing with no recorded slam lays only the rush", _combat._cannon.map(func(e): return e["family"]), ["rush"])
	# A start gone stale: nothing laid.
	_combat._free_cannon()
	_combat._wake = {"from": landing + Vector3(9.0, 0.0, 0.0), "until": _combat._clock - 0.1}
	_combat._on_cannon_slammed(landing, 1.0, 1.0)
	_t.eq("a stale start lays only the rush", _combat._cannon.map(func(e): return e["family"]), ["rush"])
	_t.check("and is dropped", _combat._wake.is_empty(), str(_combat._wake))
	# A straight drop: the lane goes back along the aim.
	_combat._free_cannon()
	_player.kit.slamming = true
	_combat._track_wake()
	_player.kit.slamming = false
	_combat._track_wake()
	_t.check("a slam that ended is held for the grace", float(_combat._wake["until"]) == _combat._clock + Combat.WAKE_GRACE, str(_combat._wake))
	_combat._on_cannon_slammed(_combat._floor_at(_player.ball_position() + Vector3.UP), 1.0, 1.0)
	var lanes := _lanes("item_proc")
	_t.check("a straight drop lays its wake back along the aim", lanes.size() == 1 and _lane(lanes[0]).heading.dot(-_combat._flat_aim()) > 0.9999,
		"%d lanes" % lanes.size())
	# A later slam overwrites a slam that never landed.
	_combat._free_cannon()
	_player.kit.slamming = true
	_combat._track_wake()
	var first: Vector3 = _combat._wake["from"]
	_player.kit.slamming = false
	_combat._track_wake()
	_player.body().global_position += Vector3(5.0, 0.0, 0.0)
	_player.kit.slamming = true
	_combat._track_wake()
	_t.check("a new slam replaces one that never landed", _flat(_combat._wake["from"]).distance_to(_flat(first)) > 4.0, "%s vs %s" % [_combat._wake["from"], first])
	_player.kit.slamming = false
	# Planted control: the landing event of a depth-2 chain would lay a second lane; the guard stops it.
	_combat._free_cannon()
	_combat._wake = {"from": landing + Vector3(9.0, 0.0, 0.0), "until": INF}
	_combat._on_cannon_slammed(landing, 1.0, 1.0)
	var wake := _lanes("item_proc")
	_combat._on_cannon_slammed(landing, 1.0, 1.0)
	_t.eq("one start lays exactly one wake", wake.size(), 1)
	_t.eq("a second landing on the spent start lays no second wake", _lanes("item_proc").size(), 1)


# The plain rush lays no trailing lane, and the row never walks a weapon lane.
func _check_wake_plain() -> void:
	_as_cannon()
	_t.eq("an unswapped cannon smash is cannon_rush", _player.abilities.id_of(AbilityState.SMASH), "cannon_rush")
	var start: Vector3 = _player.ball_position()
	_player.kit.slamming = true
	_combat._track_wake()
	_t.check("the plain rush records no start", _combat._wake.is_empty(), str(_combat._wake))
	var landing: Vector3 = _combat._floor_at(start + Vector3(9.0, 0.0, 0.0) + Vector3.UP)
	_player.kit.slamming = false
	_combat._on_cannon_slammed(landing, 1.0, 1.0)
	_t.eq("the plain rush lays only its ring", _combat._cannon.map(func(e): return e["family"]), ["rush"])
	# Planted control: forcing a start on the plain rush still lays nothing, since the row carries no mutation.
	_combat._free_cannon()
	_combat._wake = {"from": start, "until": INF}
	_combat._on_cannon_slammed(landing, 1.0, 1.0)
	_t.eq("a planted start on the plain rush lays nothing", _combat._cannon.map(func(e): return e["family"]), ["rush"])
	_t.check("a rush landing never walks the weapon lane", _combat._walk.is_empty(), str(_combat._walk))
