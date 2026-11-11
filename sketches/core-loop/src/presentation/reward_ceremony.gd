extends Node

const EventKinds := preload("res://src/core/event_kinds.gd")
const Parts := preload("res://src/build/parts.gd")
const Relics := preload("res://src/build/relics.gd")
const Synergies := preload("res://src/build/synergies.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")
const SafeStore := preload("res://src/core/safe_store.gd")
const RewardView := preload("res://src/ui/reward_view.gd")
const WhyCallout := preload("res://src/ui/why_callout.gd")
const ScreenBusy := preload("res://src/ui/screen_busy.gd")

# The reward ceremony (v3 W13, playtest entry 8 follow-up: "treasure find ceremony").
# Every part_gained is presented at a tier, so a big find feels big and a small one stays
# out of the way. The tier's look, sound, timing and pause rule are its
# EventKinds.LOOT_ROWS reward_* row; which tier is tier_of(), the one place a part's
# rarity is read.
#
#   common    in the flow: juice's fountain and vfx's glyph pop, plus a rarity tick
#   rare      the same with a rising bell rung up the reward ladder, a ring flare in the
#             rarity colour and a hit-stop from juice's shared budget
#   reveal    rare-plus, a first find or a completed synergy: a salvaged
#             plate card with the glyph, the name, six words of what changes and, when
#             it completes or feeds a synergy, a wire snapped to the partner's glyph
#   ceremony  a Warden-break gate, Brindle's crest, a vault or cache, the cage, an
#             evolution: a crate shakes and cracks over a drum and bell build, bursts on
#             a resolving chord and seats the part in a hull slot
#
# A card or a ceremony opens only when the screen's one gate says so (may_show_card, through
# screen_busy.gd): quiet for the finds' hold, and the crate also takes the one slot like a card
# (_take_crate_slot), so it never opens over a card and no card shows over it. A first find that cannot yet is held, at most
# MAX_HELD of them, and opens in the order found; a part is seen when its card is shown, so a
# dropped one is still unseen. A repeat find shows no card; the name at the ball is all it
# says. A reveal card that is up when a Warden fight turns live closes at once; the part
# stays seen. A ceremony also waits for calm(): in play (or the victory roll), no committed
# threat or enemy near, on the ground and not launching, and it waits as long as that takes.
# A boss's own reward (source "boss") asks only calm() and the calm hold: the boss's death
# ends the fight, and the victory roll is shorter than the damage clock. The ball's
# velocity is exactly what it was when the pause began. Any key or click jumps to the
# reveal, a second closes it. The pause menu's "Ceremonies: short" presents every find at
# the rare tier. After a revealed or ceremonial part lands, the first time its effect
# fires the payoff flashes its glyph over the ball and rings its bell, once.

signal started(part_id: String)
signal revealed(part_id: String)
signal closed(part_id: String)

const SETTING := "ceremony"
const SEEN_FILE := "reward-finds.json"
# The first bus fact that shows a passive part at work, by the knob it turns. A triggered
# part waits for its own proc in build.item_procs() instead.
const PAYOFF_FACTS := ["enemy_struck", "shot_fired", "dashed", "slammed", "element_resolved", "grapple_fired",
	"boosted", "scrap_collected", "special_used", "player_hit"]
const PAYOFF_BY_MOD := {"weapon_rate": "shot_fired", "weapon_range": "shot_fired", "dash_impulse": "dashed",
	"rope_range": "grapple_fired", "cruise": "boosted"}
const MAX_HELD := 3
# The key the banner's card for a found part waits under (presentation.gd, _on_part): a crate's find card.
const FIND_CARD := "part:"
const CLOSE_SCREENS := ["title", "class_select", "summary", "dead"]

var ctx
var audio
var juice
var vfx
var view
# Short: every find at the rare tier. The pause menu's Ceremonies row flips it and saves
# it in settings.json (SETTING, a comfort level: 1 full, 0 short); it is read at launch.
var short := false
# Off in test mode, as the workshop's screens are, so the bots and older tests never
# pause; a ceremony then plays in the flow as a reveal card. Tests switch it on.
var pause_armed := true
# The real clock in milliseconds; tests may swap it.
var now_ms: Callable = Callable(Time, "get_ticks_msec")
# Every find presented: [part_id, tier, source, msec]; every payoff: [part_id, fact, msec].
var presented: Array = []
var payoffs: Array = []

var _seen := {}
var _seen_path := ""
var last_error := ""
var _save_blocked := false
var _queue: Array = []
var _cards: Array = []
# The screen_busy key of the reveal card now up (src/ui/screen_busy.gd), "" when none.
var _slot := ""
var _active := {}
var _calm_since := -1
var _armed: Array = []
var _paid := {}
var _held_velocity := Vector3.ZERO
var _held_state_velocity := Vector3.ZERO
var _holding := false


func setup(ctx_ref, audio_ref, juice_ref, vfx_ref) -> void:
	ctx = ctx_ref
	audio = audio_ref
	juice = juice_ref
	vfx = vfx_ref
	name = "RewardCeremony"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var game = ctx.root
	var dir: String = game.get("storage_dir") if game != null and game.get("storage_dir") != null else "user://"
	pause_armed = not (game != null and bool(game.get("test_mode")))
	short = float(SettingsStore.new(dir).comfort.get(SETTING, 1.0)) < 0.5
	_seen_path = dir.path_join(SEEN_FILE)
	_load_seen()
	if _busy() != null:
		_busy().add_source(active)
	var layer := CanvasLayer.new()
	layer.name = "RewardLayer"
	layer.layer = 41
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	view = RewardView.new()
	layer.add_child(view)
	var events = ctx.events
	events.part_gained.connect(_on_part_gained)
	events.run_started.connect(func(_class_id: String): _reset(true))
	events.player_died.connect(func(): _reset(false))
	events.stage_entered.connect(func(_stage: int, retry: bool):
		if retry:
			_reset(false))
	events.flow_changed.connect(func(state: String):
		if state in CLOSE_SCREENS:
			_reset(false))
	if events.has_signal("stage_content_cleared"):
		events.stage_content_cleared.connect(func(reason: String):
			if reason == "arena_retry":
				_reset(false))
	for fact in PAYOFF_FACTS:
		if events.has_signal(fact):
			events.connect(fact, _on_effect.bind(fact).unbind(_argc(events, fact)))


static func _argc(events: Object, signal_name: String) -> int:
	for info in events.get_signal_list():
		if info["name"] == signal_name:
			return (info["args"] as Array).size()
	return 0


# --- Tiers --------------------------------------------------------------------------------

# The one read of a part's rarity. The rarity ladder can remap parts in their rows
# without touching anything here.
static func rarity_of(part_id: String) -> String:
	var d: Resource = Parts.def(part_id)
	return String(d.rarity) if d != null else "common"


# The tier a find is presented at. context: source (part_gained's), first (never found
# before), synergy (the named synergy it completes), short (the pause menu's setting).
static func tier_of(part_id: String, context := {}) -> String:
	return tier_for(rarity_of(part_id), context)


static func tier_for(rarity: String, context := {}) -> String:
	if context.get("short", false):
		return "rare"
	if String(context.get("source", "")) in EventKinds.CEREMONY_SOURCES:
		return "ceremony"
	var tier: String = EventKinds.REWARD_TIER_BY_RARITY.get(rarity, "common")
	if tier == "ceremony":
		return tier
	if context.get("first", false) or String(context.get("synergy", "")) != "":
		return "reveal"
	return tier


# Rare and up flare (the ring, the bell and the stop); a common first find or synergy
# gets its card without stopping the play.
static func flares(rarity: String) -> bool:
	return EventKinds.REWARD_TIER_BY_RARITY.get(rarity, "common") != "common"


static func rung_pitch(rarity: String) -> float:
	return Harmony.ratio(Harmony.pentatonic_step(int(EventKinds.REWARD_RUNGS.get(rarity, 0))))


# The six words of what changes: the part's verb, cut to the reveal row's word limit.
static func card_words(part_id: String) -> String:
	var d: Resource = Parts.def(part_id)
	var line: String = d.verb if d != null and d.verb != "" else (d.text if d != null else String(Parts.token(part_id).get("verb", "")))
	var words := line.split(" ", false)
	var limit := int(EventKinds.reward_row("reveal").get("words", 6))
	return " ".join(words.slice(0, mini(words.size(), limit)))


# The relic a part stands for, or "" for an ordinary part: a relic card names the relic.
static func relic_of(part_id: String) -> String:
	return Relics.relic_of(part_id)


static func icon_of(part_id: String) -> String:
	var d: Resource = Parts.def(part_id)
	return "cat_" + String(d.icon_category) if d != null and d.icon_category != "" else "cat_utility"


# The first bus fact that shows the part at work, or "proc" for a triggered part.
static func payoff_fact(part_id: String) -> String:
	var d: Resource = Parts.def(part_id)
	if d == null:
		return "enemy_struck"
	if d.trigger != "":
		return "proc"
	if not d.patterns.is_empty():
		return "shot_fired"
	if d.elements.has("dash"):
		return "dashed"
	if d.elements.has("slam"):
		return "slammed"
	if not d.elements.is_empty():
		return "element_resolved"
	if d.punch <= 0.0:
		for key in d.mods:
			if PAYOFF_BY_MOD.has(key):
				return PAYOFF_BY_MOD[key]
		if d.cooldown_scale != 1.0:
			return "boosted"
		if d.magnet != 1.0 or d.kill_scrap != 1.0:
			return "scrap_collected"
		if not d.charges.is_empty():
			return "special_used"
		if d.max_hp_bonus > 0.0:
			return "player_hit"
	return "enemy_struck"


# --- A find ---------------------------------------------------------------------------------

func _on_part_gained(part_id: String, source: String) -> void:
	present(find_of(part_id, source))


# A find as the ceremony sees it: its tier, whether it is a first, and the synergy it
# completes or feeds with that synergy's partner part.
func find_of(part_id: String, source: String) -> Dictionary:
	var held: Array = ctx.run.parts.duplicate() if ctx.run != null else []
	var before := held.duplicate()
	var at := before.rfind(part_id)
	if at >= 0:
		before.remove_at(at)
	var first := not _seen.has(part_id)
	var synergy := Parts.completed_by(part_id, before)
	var partner := ""
	var link := ""
	if synergy != "":
		link = "lit"
		partner = _partner(synergy, part_id, before)
	else:
		var fed := _fed(part_id, before)
		if not fed.is_empty():
			link = "hint"
			synergy = fed[0]
			partner = fed[1]
	var rarity := rarity_of(part_id)
	var tier := tier_for(rarity, {"source": source, "first": first, "synergy": synergy if link == "lit" else "", "short": short})
	return {"part": part_id, "source": source, "rarity": rarity, "tier": tier, "first": first, "synergy": synergy,
		"partner": partner, "link": link, "at": int(now_ms.call()), "held": held}


# The held part a completed synergy paired this one with.
static func _partner(synergy: String, part_id: String, before: Array) -> String:
	var row: Dictionary = Synergies.ROWS[synergy]
	if part_id != row["shown"]:
		return row["shown"]
	for other in before:
		if row["tags"][1] in Parts.tags_of(other):
			return other
	return ""


# [synergy, partner] for a named synergy this part feeds but does not yet complete: it is
# the shown part (partner unknown, the card shows a socket with a question mark), or it
# carries the hidden tag while the shown part is still out there.
static func _fed(part_id: String, before: Array) -> Array:
	var live := Synergies.active(before, Parts.tag_sets(before))
	for key in Synergies.ROWS:
		if key in live or not Synergies.in_play(key):
			continue
		var row: Dictionary = Synergies.ROWS[key]
		if part_id == row["shown"]:
			return [key, ""]
		if row["tags"][1] in Parts.tags_of(part_id) and not before.has(row["shown"]):
			return [key, row["shown"]]
	return []


func present(find: Dictionary) -> void:
	if find["tier"] in ["reveal", "ceremony"] and not _may_hold(find):
		find["tier"] = "rare" if find["tier"] == "reveal" and flares(find["rarity"]) else "common"
	presented.append([find["part"], find["tier"], find["source"], find["at"]])
	match String(find["tier"]):
		"common":
			audio.play("reward_common", 0.0, rung_pitch(find["rarity"]))
			_rung_voice(find)
		"rare":
			_flare(find)
		"reveal":
			if flares(find["rarity"]):
				_flare(find)
			else:
				audio.play("reward_common", 0.0, rung_pitch(find["rarity"]))
			_hold_card(find)
		"ceremony":
			audio.play("reward_common", 0.0, rung_pitch(find["rarity"]))
			if pause_armed:
				_queue.append(find)
			else:
				_demote(find)


# Whether a find may wait for a card: a first find of a part nothing is already holding a
# card for, with fewer than MAX_HELD waiting. Anything else shows its name at the ball only.
func _may_hold(find: Dictionary) -> bool:
	return find["first"] and not _is_held(find["part"]) and _queue.size() + _cards.size() < MAX_HELD


func _is_held(part_id: String) -> bool:
	for find in _queue + _cards:
		if find["part"] == part_id:
			return true
	return not _active.is_empty() and _active["find"]["part"] == part_id


# The shared gate: the screen is quiet (screen_busy.gd) for the finds' longer hold.
func may_show_card() -> bool:
	return _busy() == null or _busy().settled(ScreenBusy.FIND_HOLD)


# A rung's own voice (EventKinds.REWARD_RUNG_CUES: cobalt's coil whine and click), played
# with the find's bell or tick, or with the crate's burst when the find waits for one.
func _rung_voice(find: Dictionary) -> void:
	var voice := String(EventKinds.REWARD_RUNG_CUES.get(find["rarity"], ""))
	if voice != "":
		audio.play("reward_rare", 0.0, 1.0, "SFX", voice)


func _flare(find: Dictionary) -> void:
	var row := EventKinds.reward_row("rare")
	audio.play("reward_rare", 0.0, rung_pitch(find["rarity"]))
	_rung_voice(find)
	if juice != null:
		if may_show_card():
			juice.request_hit_stop(float(row["stop_ms"]) / 1000.0, "reward_rare")
	if vfx != null and ctx.player != null:
		var ball: Vector3 = ctx.player.shown_position()
		var tint := RewardGates.rarity_color(find["rarity"])
		vfx.glyph("reward_rare", ball + Vector3.UP * 0.3, 1.0, float(row["ring_m"]), float(row["flare_s"]), Vector3.ZERO, "ring", tint)
		vfx.glyph("reward_rare", ball + Vector3.UP * 2.4, 0.4, 1.8, float(row["flare_s"]), Vector3.ZERO, "star", tint)


# A ceremony with no pause armed (test mode): the rare flare and the reveal card, in the flow.
func _demote(find: Dictionary) -> void:
	var shown := find.duplicate()
	shown["tier"] = "reveal"
	presented.append([shown["part"], "reveal", shown["source"], int(now_ms.call())])
	_flare(shown)
	_hold_card(shown)


func _hold_card(find: Dictionary) -> void:
	_cards.append(find)
	if _busy() != null:
		_busy().request("find:" + String(find["part"]))
	if view.card.is_empty() or view.card.get("ceremony", false) and _active.is_empty():
		_next_card()


# The head of the held cards opens when the gate allows, and the part is seen only now.
func _next_card() -> void:
	_release_slot()
	view.card = {}
	if _cards.is_empty() or not may_show_card() or not _take_slot(_cards[0]):
		return
	var find: Dictionary = _cards.pop_front()
	_mark_seen(find["part"])
	view.card = card_state(find, int(now_ms.call()), false)
	audio.play("reward_reveal", 0.0, rung_pitch(find["rarity"]))
	if find["link"] == "lit":
		audio.play("reward_reveal", -4.0, 1.0, "SFX", String(EventKinds.reward_row("reveal")["sound_snap"]))
	_arm(find)


func _busy():
	return ctx.get("screen_busy") if ctx != null else null


# A reveal card waits its turn with the other cards that can wait (screen_busy.gd): quiet screen, oldest first.
func _take_slot(find: Dictionary) -> bool:
	if _busy() == null:
		return true
	var key := "find:" + String(find["part"])
	if not _busy().may_show(key, ScreenBusy.FIND_HOLD):
		return false
	_slot = key
	return true


func _release_slot() -> void:
	if _slot != "" and _busy() != null:
		_busy().done(_slot)
	_slot = ""


func card_state(find: Dictionary, start: int, in_ceremony: bool) -> Dictionary:
	var row := EventKinds.reward_row("reveal")
	var d: Resource = Parts.def(find["part"])
	var rarity: String = find["rarity"]
	var stamps: Dictionary = row["stamps"]
	var stamp: String = stamps.get(rarity, "")
	if find["first"] and rarity in ["common", "rare"]:
		stamp = "%s %s" % [stamps["first"], stamp]
	# A run token (Parts.TOKENS) is no rung of the item ladder: it wears its own stamp.
	stamp = String(Parts.token(find["part"]).get("stamp", stamp))
	var element := String(d.element) if d != null else ""
	var relic := relic_of(find["part"])
	var title: String = Relics.name_of(relic) if relic != "" else Parts.display_name(find["part"])
	var body: String = String(Relics.row(relic).get("text", "")) if relic != "" else card_words(find["part"])
	return {"part": find["part"], "name": title, "verb": body, "stamp": stamp,
		"icon": icon_of(find["part"]), "element_icon": "el_" + element if element != "" else "",
		"tint": RewardGates.rarity_color(rarity), "heart": row["heart"] if rarity == "relic" else false,
		"partner_icon": icon_of(find["partner"]) if String(find["partner"]) != "" else "", "link": find["link"],
		"class_color": _class_color(), "start_ms": start, "in_s": row["in_s"], "hold_s": row["hold_s"], "out_s": row["out_s"],
		"snap_s": row["snap_s"], "seed": absi(String(find["part"]).hash()), "ceremony": in_ceremony, "find": find}


func _class_color() -> Color:
	if ctx.player != null and ctx.player.has_method("class_color"):
		return ctx.player.class_color()
	return EventKinds.reward_row("ceremony")["color"]


# --- Calm and the pause ---------------------------------------------------------------------

# True when a ceremony may stop the world: in play or the victory roll, not launching,
# nothing else holding the tree, on the ground, and no committed threat or enemy near.
func calm() -> bool:
	var row := EventKinds.reward_row("ceremony")
	var game = ctx.root
	var state: String = ctx.flow.state_name()
	if not (ctx.flow.in_play() or state == "victory") or state == "launch":
		return false
	if get_tree().paused or (game != null and game.menu_held()) or ctx.player.frozen():
		return false
	var st = ctx.player.state
	if not st.grounded and absf(st.velocity.y) > float(row["fall_speed"]):
		return false
	# The tick's place: this is a rule that stops the world, read against threats at the tick.
	var at: Vector3 = ctx.player.ball_position()
	for node in get_tree().get_nodes_in_group("threat"):
		if not node.has_method("threat_at") and not node is Node3D:
			continue
		var where: Vector3 = node.threat_at() if node.has_method("threat_at") else (node as Node3D).global_position
		if where.distance_to(at) < float(row["threat_m"]):
			return false
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and enemy.is_inside_tree() and not enemy.is_queued_for_deletion() \
				and not (enemy.has_method("is_dead") and enemy.is_dead()) \
				and (enemy as Node3D).global_position.distance_to(at) < float(row["enemy_m"]):
			return false
	return true


func queued() -> int:
	return _queue.size()


func active() -> bool:
	return not _active.is_empty()


func phase() -> String:
	return String(_active.get("phase", ""))


func _process(delta: float) -> void:
	var now := int(now_ms.call())
	view.now = now
	if not _active.is_empty():
		_step_ceremony(now)
	elif not _queue.is_empty():
		_step_queue(now)
	if view.card.is_empty() and not _cards.is_empty() and _active.is_empty():
		_next_card()
	if not view.card.is_empty() and not view.card.get("ceremony", false) and WhyCallout.warden_fight_live(ctx.flow):
		_release_slot()
		view.card = {}
	if not view.card.is_empty() and not view.card.get("ceremony", false):
		var c: Dictionary = view.card
		if now - int(c["start_ms"]) > int((float(c["in_s"]) + float(c["hold_s"]) + float(c["out_s"])) * 1000.0):
			_next_card()
	view.flashes = view.flashes.filter(func(f: Dictionary): return now - int(f["start_ms"]) < int(float(f["life_s"]) * 1000.0))
	_step_payoffs()


func _step_queue(now: int) -> void:
	var row := EventKinds.reward_row("ceremony")
	if _busy() != null:
		_busy().request(crate_key(_queue[0]["part"]), true)
	# A boss's own reward does not wait on the damage clock: its death ends the fight.
	var gate: bool = String(_queue[0]["source"]) == "boss" or may_show_card()
	if not gate or not calm():
		_calm_since = -1
		return
	if _calm_since < 0:
		_calm_since = now
	if now - _calm_since >= int(float(row["calm_hold_s"]) * 1000.0) and _take_crate_slot(_queue[0]):
		_calm_since = -1
		_begin(_queue.pop_front())


# The crate's place in the screen's one line (screen_busy.gd); it asks first, ahead of cards waiting.
static func crate_key(part_id: String) -> String:
	return "crate:" + part_id


# The crate takes the screen like a card: never over another card, and given back when it closes.
# Its find card (the banner's card for the same part, FIND_CARD) is the same beat: when that card holds
# the screen the crate opens beside it, and while it waits in line the crate lets it go up first. A
# boss's crate does not wait for quiet, so it takes the slot at the front (ScreenBusy.take) and its
# find card follows it. The wait is bounded by the holder's own life, a run end or a reset.
func _take_crate_slot(find: Dictionary) -> bool:
	var gate = _busy()
	if gate == null:
		return true
	var beat: String = FIND_CARD + String(find["part"])
	if gate.showing() == beat:
		return true
	var key := crate_key(find["part"])
	if String(find["source"]) == "boss":
		return gate.take(key)
	if gate.waiting().has(beat):
		return false
	return gate.may_show(key, ScreenBusy.FIND_HOLD)


func _release_crate(find: Dictionary) -> void:
	if _busy() != null:
		_busy().done(crate_key(find["part"]))


func _begin(find: Dictionary) -> void:
	var row := EventKinds.reward_row("ceremony")
	var now := int(now_ms.call())
	var burst := now + int((float(row["in_s"]) + float(row["build_s"])) * 1000.0)
	_active = {"find": find, "phase": "build", "start": now, "burst": burst}
	_hold(true)
	var hull: Array = []
	for part in (find["held"] as Array):
		var icon := icon_of(part)
		if part != find["part"]:
			hull.append(icon)
	var slots := int(row["hull_slots"])
	hull = hull.slice(maxi(0, hull.size() - (slots - 1)))
	hull.append(icon_of(find["part"]))
	view.set_ceremony({"start_ms": now, "burst_ms": -1, "close_ms": -1, "in_s": row["in_s"], "build_s": row["build_s"],
		"hold_s": row["hold_s"], "out_s": row["out_s"], "tint": RewardGates.rarity_color(find["rarity"]),
		"class_color": _class_color(), "seed": absi(String(find["part"]).hash()), "hull": hull})
	if not view.card.is_empty() and not view.card.get("ceremony", false):
		_cards.push_front(view.card["find"])
		# The card the crate pushed off keeps its place in line, first.
		if _busy() != null and _slot != "":
			_busy().give_back(_slot)
		_slot = ""
	_mark_seen(find["part"])
	view.card = card_state(find, now, true)
	audio.play("reward_ceremony")
	started.emit(find["part"])


func _step_ceremony(now: int) -> void:
	if _holding and not get_tree().paused:
		get_tree().paused = true
	match String(_active["phase"]):
		"build":
			if now >= int(_active["burst"]):
				_burst(now)
		"reveal":
			var row := EventKinds.reward_row("ceremony")
			if now >= int(_active["burst"]) + int(float(row["hold_s"]) * 1000.0):
				_close(now)
		"out":
			if now >= int(_active["close"]) + int(float(EventKinds.reward_row("ceremony")["out_s"]) * 1000.0):
				var find: Dictionary = _active["find"]
				_active = {}
				_release_crate(find)
				view.set_ceremony({})
				view.card = {}
				_next_card()
				closed.emit(find["part"])


func _burst(now: int) -> void:
	var row := EventKinds.reward_row("ceremony")
	var find: Dictionary = _active["find"]
	_active["phase"] = "reveal"
	_active["burst"] = now
	view.ceremony["burst_ms"] = now
	view.card["start_ms"] = now - int(float(EventKinds.reward_row("reveal")["in_s"]) * 1000.0)
	audio.stop(String(row["sound"]))
	audio.play("reward_ceremony", 0.0, 1.0, "SFX", String(row["sound_burst"]))
	_rung_voice(find)
	if find["link"] == "lit":
		audio.play("reward_reveal", -4.0, 1.0, "SFX", String(EventKinds.reward_row("reveal")["sound_snap"]))
	revealed.emit(find["part"])


# The world moves again as the overlay fades, so the run never waits on the fade.
func _close(now: int) -> void:
	_active["phase"] = "out"
	_active["close"] = now
	view.ceremony["close_ms"] = now
	_hold(false)
	_arm(_active["find"])


# Any key or click: during the build, straight to the reveal; during the reveal, close.
func skip() -> void:
	if _active.is_empty():
		return
	var now := int(now_ms.call())
	match String(_active["phase"]):
		"build":
			_burst(now)
		"reveal":
			_close(now)


func _input(event: InputEvent) -> void:
	if _active.is_empty() or String(_active["phase"]) == "out":
		return
	var pressed := false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo
	elif event is InputEventMouseButton or event is InputEventJoypadButton:
		pressed = event.pressed
	if pressed:
		skip()
		get_viewport().set_input_as_handled()


# Holds the tree paused with the player's keys off, or lets it go. Velocity is captured
# at the pause and handed back exactly, as the tree pick's pause does.
func _hold(on: bool) -> void:
	var game = ctx.root
	var body: RigidBody3D = ctx.player.body()
	if on:
		_holding = true
		_held_velocity = body.linear_velocity
		_held_state_velocity = ctx.player.state.velocity
		get_tree().paused = true
		if game != null:
			game.set_menu_held(true)
			if game.get("keyboard") != null:
				game.keyboard.enabled = false
		return
	if not _holding:
		return
	_holding = false
	if game != null:
		game.set_menu_held(false)
		get_tree().paused = game.pause_toggled() or game.notes_held() if game.has_method("pause_toggled") else false
		if game.get("keyboard") != null:
			game.keyboard.enabled = ctx.flow.in_play()
	else:
		get_tree().paused = false
	if body.linear_velocity != _held_velocity or ctx.player.state.velocity != _held_state_velocity:
		ctx.player.set_velocity_now(_held_velocity)


func held_velocity() -> Vector3:
	return _held_velocity


# --- The payoff -----------------------------------------------------------------------------

func _arm(find: Dictionary) -> void:
	var part: String = find["part"]
	if _paid.has(part):
		return
	for armed in _armed:
		if armed["part"] == part:
			return
	var fact := payoff_fact(part)
	var base := 0
	if fact == "proc":
		base = int(_procs().get(part, 0))
	_armed.append({"part": part, "fact": fact, "base": base, "rarity": find["rarity"]})


func armed() -> Array:
	return _armed.map(func(a: Dictionary): return a["part"])


func _procs() -> Dictionary:
	var build = ctx.build_module() if ctx.has_method("build_module") else null
	return build.item_procs() if build != null and build.has_method("item_procs") else {}


func _on_effect(fact: String) -> void:
	if _armed.is_empty() or not _active.is_empty():
		return
	for armed in _armed.duplicate():
		if armed["fact"] == fact:
			_pay(armed, fact)


func _step_payoffs() -> void:
	if not _active.is_empty():
		return
	var procs := {}
	for armed in _armed.duplicate():
		if armed["fact"] != "proc":
			continue
		if procs.is_empty():
			procs = _procs()
		if int(procs.get(armed["part"], 0)) > int(armed["base"]):
			_pay(armed, "proc")


# The "there it is": the part's glyph flashes over the ball and its bell rings, once.
func _pay(armed: Dictionary, fact: String) -> void:
	_armed.erase(armed)
	var part: String = armed["part"]
	_paid[part] = true
	var now := int(now_ms.call())
	payoffs.append([part, fact, now])
	var row := EventKinds.reward_row("payoff")
	audio.play("reward_payoff", 0.0, rung_pitch(armed["rarity"]))
	var tint := RewardGates.rarity_color(armed["rarity"])
	var ball: Vector3 = ctx.player.shown_position()
	if vfx != null:
		vfx.glyph("reward_payoff", ball + Vector3.UP * 0.3, 1.0, 3.5, float(row["flash_s"]), Vector3.ZERO, "ring", _class_color())
	var cam = ctx.camera.cam if ctx.camera != null else null
	var at := Vector2(800.0, 450.0)
	if cam != null and cam.is_inside_tree() and not cam.is_position_behind(ball):
		at = cam.unproject_position(ball + Vector3.UP * 1.6)
	view.flashes.append({"icon": icon_of(part), "tint": tint, "class_color": _class_color(), "at": at, "start_ms": now,
		"life_s": row["flash_s"]})


# --- Settings, finds and resets ---------------------------------------------------------------

func _load_seen() -> void:
	_seen = {}
	if not FileAccess.file_exists(_seen_path):
		return
	var parsed = SafeStore.parse(FileAccess.get_file_as_string(_seen_path), TYPE_ARRAY)
	if parsed != null and not SafeStore.is_strings(parsed):
		parsed = null
	if parsed == null:
		var kept := SafeStore.quarantine(_seen_path)
		if kept.is_empty():
			_save_blocked = true
			last_error = "unreadable %s and could not be moved aside; not saving this session" % _seen_path
		else:
			last_error = "unreadable %s; kept as %s" % [_seen_path, kept]
		return
	_save_blocked = false
	for id in parsed:
		_seen[String(id)] = true


func _mark_seen(part_id: String) -> void:
	if _seen.has(part_id):
		return
	_seen[part_id] = true
	if _save_blocked:
		return
	var err := SafeStore.write_atomic(_seen_path, JSON.stringify(_seen.keys()))
	if err != OK:
		last_error = "cannot save %s: %s" % [_seen_path, error_string(err)]


func seen(part_id: String) -> bool:
	return _seen.has(part_id)


# A run start clears everything; a death, a retry or a screen drops what is waiting and
# lets go of the tree, and keeps the payoffs of parts the run still holds.
func _reset(new_run: bool) -> void:
	for find in _queue:
		_release_crate(find)
	_queue.clear()
	if _busy() != null:
		for find in _cards:
			_busy().done("find:" + String(find["part"]))
	_cards.clear()
	_calm_since = -1
	if not _active.is_empty():
		_release_crate(_active["find"])
		_hold(false)
		_active = {}
		audio.stop(String(EventKinds.reward_row("ceremony")["sound"]))
	view.set_ceremony({})
	_release_slot()
	view.card = {}
	if new_run:
		_armed.clear()
		_paid.clear()
		return
	var held: Array = ctx.run.parts if ctx.run != null else []
	_armed = _armed.filter(func(a: Dictionary): return held.has(a["part"]))
