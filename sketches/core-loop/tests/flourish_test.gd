extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Rows := preload("res://src/presentation/flourish_rows.gd")
const FlourishPlayer := preload("res://src/presentation/flourish_player.gd")
const ScreenRegions := preload("res://src/core/screen_regions.gd")
const T := preload("res://tests/support/t.gd")
const Worlds := preload("res://src/core/worlds.gd")
const TitleIntros := preload("res://src/presentation/title_intros.gd")

# World 1's stage beats (unit 4) and the shared flourish player.
#   rows     every row's full form is 6 s or less and its short form 2.5 s or less; piece kinds and
#            slots are known; every line keeps the word cap and lore lines carry no exclamation mark
#   seeds    the same seed resolves the same words; across seeds the variant lines do vary
#   budget   the repeat run's short forms of world 1's rows add to 10 s or less (ledger: 30 s for all)
#   live     in a park Game: a fresh run's stage 1 entry plays cold_open in full, held at 0 s; it
#            stays out of the top, toast, prompts and bottom bands; a fresh press before SKIP_GRACE does
#            nothing, one after ends it and is not consumed; a paused tree hides it and stops its
#            clock; the run's "flourishes" meta records it; a second run plays the short form
#   order    a higher row ends a lower one; an equal or lower one waits and plays after
#   once     Brindle's rout is named once (ruling cx, FX-08): only the rout row's stamp says
#            ROUTED; the victory heading, the shift log after it and its lines never name the rout or
#            the Admiral; the arrival card shares no stat with the title reel's card
#   hooks    rescue_completed("rivet"), the meltdown Warden's engage, world 1's last unseal and
#            world 2's entry each start their row, and the title screen ends a row and its queue
# Evidence limit: headless rules and layout rectangles, not how it reads at the sitting.

const SEED := 23
const WORLD_ONE := ["cold_open", "rivet_freed", "flume_warden_reveal", "bowl_handoff", "spillway_clear", "brindle_chase"]

var _t := T.new("flourish_test")
var _game


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _run() -> void:
	_rows()
	_named_once()
	_seeds()
	_budget()
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.rng.seed = SEED
	_game.player.source = Intent.Scripted.new()
	var player = _game.presentation.flourish
	_t.check("10 presentation builds the player", player is FlourishPlayer, str(player))
	_stage_name_once()
	await _live(player)
	await _sweep(player)
	await _order(player)
	await _hooks(player)
	_game.free()
	await _frames(2)
	quit(_t.verdict())


func _rows() -> void:
	for id in Rows.ROWS:
		_t.check("01 %s full form within %s s" % [id, Rows.MAX_SECONDS], Rows.length(id, false) > 0.0 and Rows.length(id, false) <= Rows.MAX_SECONDS,
			"%.2f s" % Rows.length(id, false))
		_t.check("02 %s short form within %s s" % [id, Rows.MAX_SHORT_SECONDS], Rows.length(id, true) > 0.0 and Rows.length(id, true) <= Rows.MAX_SHORT_SECONDS,
			"%.2f s" % Rows.length(id, true))
		var bad: Array = []
		for form in ["full", "short"]:
			for piece in Rows.pieces(id, form == "short"):
				if not piece.kind in Rows.KINDS or (piece.has("slot") and not piece.slot in Rows.SLOTS):
					bad.append("%s %s" % [form, piece.kind])
		_t.eq("03 %s pieces have known kinds and slots" % id, bad, [])
		var long_lines: Array = Rows.lines(id).filter(func(line): return Rows.words(line) > Rows.LINE_WORD_CAP)
		_t.eq("04 %s lines within %d words" % [id, Rows.LINE_WORD_CAP], long_lines, [])
		var loud: Array = []
		for form in ["full", "short"]:
			for piece in Rows.pieces(id, form == "short"):
				if piece.kind in ["caption", "panels", "card"]:
					for line in Rows.lines(id):
						if line.contains("!") and not line in loud and _in_piece(piece, line):
							loud.append(line)
		_t.eq("05 %s lore lines are dry (no exclamation marks)" % id, loud, [])
	_t.eq("06 world 1's rows are all present", WORLD_ONE.filter(func(id): return Rows.has(id)), WORLD_ONE)


func _in_piece(piece: Dictionary, line: String) -> bool:
	return str(piece.get("text", "")).contains(line) or str(piece.get("texts", "")).contains(line) or str(piece.get("card", "")).contains(line)


# The stage card owns the stage's name, so the cold open's captions do not open with it.
func _stage_name_once() -> void:
	var names: Array = [String(_game.ctx.stages.of(1)["name"]), String(Worlds.ROWS[0]["name"])]
	var begins: Array = []
	var seen := 0
	for piece in Rows.pieces("cold_open", false).filter(func(p): return p.kind == "caption"):
		var variants: Array = piece.text if piece.text is Array else [piece.text]
		for line in variants:
			seen += 1
			if names.any(func(n): return String(line).begins_with(n)):
				begins.append(line)
	_t.check("c1 no cold open caption begins with the stage's name", seen > 0 and begins.is_empty(), "%d lines, names %s, begin with one: %s" % [seen, names, begins])


func _named_once() -> void:
	var boss: Dictionary = Worlds.BOSSES["brindle"]
	var stamps := Rows.pieces("brindle_rout", false).filter(func(p): return p.kind == "stamp")
	_t.eq("23 the rout row stamps ROUTED", stamps.map(func(p): return p.text), ["ROUTED"])
	var after := [String(boss.title), String(boss.victory)]
	after.append_array(Rows.lines("spillway_clear"))
	var named := after.filter(func(line): return String(line).to_lower().contains("rout") or String(line).to_lower().contains("admiral"))
	_t.eq("24 the victory card and the shift log never name the rout again", named, [])
	var title_card: Array = TitleIntros.row("brindle").card
	var arrival: Array = Rows.pieces("brindle_arrival", false).filter(func(p): return p.kind == "card")[0].card
	var shared := arrival.slice(2).filter(func(field): return field in title_card.slice(2))
	_t.eq("25 the arrival card's stats are not the title reel's", shared, [])


func _seeds() -> void:
	_t.eq("20 the same seed gives the same words", Rows.resolve("spillway_clear", false, 7), Rows.resolve("spillway_clear", false, 7))
	var seen := {}
	for s in 16:
		seen[Rows.resolve("spillway_clear", false, s)[2].text] = true
	_t.check("21 sixteen seeds show more than one crew-log line", seen.size() > 1, "%d distinct" % seen.size())
	var piece: Dictionary = Rows.resolve("rivet_freed", false, 3)[1]
	_t.check("22 every panel resolves to a line", piece.texts.size() == 3 and piece.texts.all(func(x): return x is String and x != ""), str(piece.texts))


func _budget() -> void:
	var total := 0.0
	for id in WORLD_ONE:
		total += Rows.length(id, true)
	_t.check("30 world 1's repeat-run beats are 10 s or less on screen", total <= 10.0, "%.2f s" % total)


func _live(player) -> void:
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _frames(3)
	_t.check("40 a fresh run's stage 1 entry plays cold_open", player.playing and player.id == "cold_open", "%s %s" % [player.playing, player.id])
	_t.check("41 first play is the full form", not player.short, "short %s" % player.short)
	_t.check("42 the profile is not marked until the row has shown", not _game.ctx.profile.is_seen(Rows.SEEN_PREFIX + "cold_open"), "")
	player.advance(1.6)
	await _frames(1)
	var size: Vector2 = root.get_visible_rect().size
	var clashes: Array = []
	for node in player.live_nodes():
		if not node is Control:
			continue
		var rect: Rect2 = node.get_global_rect()
		for band in ["top", "toasts", "prompts", "bottom"]:
			if rect.intersects(ScreenRegions.rect(band, size)):
				clashes.append("%s over %s" % [node.name, band])
	_t.check("43 nothing over the top, toast, prompts or bottom bands", clashes.is_empty() and player.live_nodes().size() >= 3,
		"%d pieces; %s" % [player.live_nodes().size(), clashes])
	paused = true
	var before: float = player.clock
	await _frames(3)
	_t.check("44 a paused tree hides the row and stops its clock", not player._layer.visible and player.clock == before, "clock %.3f -> %.3f" % [before, player.clock])
	paused = false
	await _frames(1)
	player.stop_all()
	_t.check("42b a full row cut before SEEN_SHARE stays unseen", not _game.ctx.profile.is_seen(Rows.SEEN_PREFIX + "cold_open"), "")
	_game.run.set_meta("flourishes", [])
	player.play("cold_open")
	var press := InputEventKey.new()
	press.keycode = KEY_SPACE
	press.pressed = true
	root.push_input(press)
	_t.check("45 a press inside the grace leaves the row up", player.playing, "clock %.2f" % player.clock)
	player.advance(FlourishPlayer.SKIP_GRACE)
	var steer := InputEventKey.new()
	steer.keycode = KEY_W
	steer.physical_keycode = KEY_W
	steer.pressed = true
	root.push_input(steer)
	_t.check("45b steering after the grace leaves the row up", player.playing, "")
	var steer_up := steer.duplicate()
	steer_up.pressed = false
	root.push_input(steer_up)
	var heard := [false]
	var listener := Listener.new()
	listener.heard = heard
	root.add_child(listener)
	var press2 := InputEventKey.new()
	press2.keycode = KEY_SPACE
	press2.pressed = true
	root.push_input(press2)
	_t.check("46 a press after the grace ends the row", not player.playing, "playing %s" % player.playing)
	_t.check("47 and the press still reaches play", heard[0], "")
	listener.free()
	var log: Array = _game.run.get_meta("flourishes", [])
	_t.check("48 the run's flourishes meta records it", log.size() == 1 and log[0].id == "cold_open" and log[0].skipped and log[0].cut == "skipped"
		and log[0].held == 0.0 and log[0].full, str(log))
	player.play("cold_open")
	_t.check("48b an early skip leaves the full form for next time", not player.short, "")
	player.advance(Rows.length("cold_open", false) + 0.01)
	_t.check("48c a row shown out marks the profile", _game.ctx.profile.is_seen(Rows.SEEN_PREFIX + "cold_open"), "")
	player.play("cold_open")
	_t.check("49 a seen row plays its short form", player.short, "")
	player.advance(Rows.length("cold_open", true) + 0.01)
	_t.check("50 it ends on its own after its length", not player.playing and player.played.back().skipped == false, str(player.played.back()))


# Every world 1 row in both forms, sampled at each piece's start: no piece over a reserved band,
# and no two column pieces (cards, captions, panels) on top of each other.
func _sweep(player) -> void:
	var size: Vector2 = root.get_visible_rect().size
	var clashes: Array = []
	for id in WORLD_ONE:
		for form in ["full", "short"]:
			player.stop_all()
			player.play(id, SEED, {}, form)
			var times: Array = Rows.pieces(id, form == "short").map(func(p): return float(p.at) + 0.05)
			times.sort()
			for at in times:
				player.advance(at - player.clock)
				await _frames(1)
				var column: Array = []
				for node in player.live_nodes():
					if not node is Control:
						continue
					var rect: Rect2 = node.get_global_rect()
					for band in ["top", "toasts", "prompts", "bottom"]:
						if rect.intersects(ScreenRegions.rect(band, size)):
							clashes.append("%s %s %s over %s" % [id, form, node.name, band])
					if not String(node.get_meta("flourish_kind", "")) in ["stamp", "sfx_word"]:
						for other in column:
							if rect.intersects(other.get_global_rect()):
								clashes.append("%s %s %s on %s" % [id, form, node.name, other.name])
						column.append(node)
	_t.eq("55 every row's pieces keep their bands and do not stack", clashes, [])
	player.stop_all()


func _order(player) -> void:
	player.stop_all()
	player.play("cold_open")
	player.play("rivet_freed")
	_t.eq("60 a higher row ends a lower one", player.id, "rivet_freed")
	_t.check("61 the ended one is logged skipped", player.played.back().id == "cold_open" and player.played.back().skipped, str(player.played.back()))
	player.play("spillway_clear")
	_t.eq("62 a lower row waits", player.queued(), ["spillway_clear"])
	player.advance(Rows.length("rivet_freed", player.short) + 0.01)
	_t.eq("63 and plays after", player.id, "spillway_clear")
	player.stop_all()
	_t.check("64 stop_all ends it and empties the queue", not player.playing and player.queued().is_empty(), "")
	var chain := func(done: String, _skipped: bool):
		if done == "cold_open":
			player.play("bowl_handoff")
	player.finished.connect(chain)
	player.play("cold_open")
	player.play("rivet_freed")
	_t.check("65 a row a finished listener starts during a preempt keeps playing; the preempting row waits",
		player.id == "bowl_handoff" and player.queued() == ["rivet_freed"] and player.live_kinds().all(func(k): return k in ["stamp", "caption", "sfx_word"]),
		"%s %s %s" % [player.id, player.queued(), player.live_kinds()])
	player.finished.disconnect(chain)
	player.stop_all()
	var cage := Node3D.new()
	root.add_child(cage)
	player.play("rivet_freed", SEED, {"cage": cage}, "full")
	player.advance(0.1)
	cage.free()
	player.advance(0.2)
	_t.check("66 a freed anchor leaves the row running", player.playing and player.id == "rivet_freed", player.id)
	player.stop_all()
	var blocker := Control.new()
	blocker.add_to_group(FlourishPlayer.AVOID_GROUP)
	var size: Vector2 = root.get_visible_rect().size
	blocker.position = Vector2(0.25, 0.17) * size
	blocker.size = Vector2(0.5, 0.23) * size
	var layer := CanvasLayer.new()
	root.add_child(layer)
	layer.add_child(blocker)
	var over: Array = []
	for at in [0.7, 1.5, 4.3]:
		player.play("cold_open", SEED, {}, "full")
		player.advance(at)
		# Let the three-frame overshoot settle; the rectangle is read at rest.
		await _frames(6)
		for node in player.live_nodes():
			if node is Control and node.get_global_rect().intersects(blocker.get_global_rect()):
				over.append("%s at %.1f" % [node.get_meta("flourish_kind"), at])
		player.stop_all()
	_t.eq("67 nothing lands on a visible avoided Control (the start pick card)", over, [])
	player.play("cold_open", SEED, {}, "full")
	player.advance(1.5)
	await _frames(6)
	var card: Control = null
	var stamp: Control = null
	for node in player.live_nodes():
		match String(node.get_meta("flourish_kind", "")):
			"card": card = node
			"stamp": stamp = node
	var cover := card.get_global_rect().intersection(stamp.get_global_rect()).size.x if card != null and stamp != null else -1.0
	_t.check("68 squeezed by the pick card, the stamp shrinks rather than cover the punch card", card != null and stamp != null
		and cover <= stamp.size.x * FlourishPlayer.STAMP_OVERLAP + 2.0, "covers %.0f of %.0f px" % [cover, stamp.size.x if stamp else 0.0])
	player.stop_all()
	layer.free()


func _hooks(player) -> void:
	var events = _game.events
	events.rescue_completed.emit("rivet")
	_t.eq("70 rescue_completed rivet plays rivet_freed", player.id, "rivet_freed")
	player.stop_all()
	events.rescue_completed.emit("dig")
	_t.check("71 another quest plays nothing", not player.playing, player.id)
	var last := 1
	while not _game.ctx.stages.is_world_last(last):
		last += 1
	events.beacon_unsealed.emit(last)
	_t.eq("72 world 1's last unseal plays bowl_handoff", player.id, "bowl_handoff")
	player.advance(1.0)
	player.stop_all()
	events.beacon_unsealed.emit(1 if last != 1 else 0)
	_t.check("73 another stage's unseal plays nothing", not player.playing, player.id)
	_game.flow.warden = VariantStub.new("meltdown")
	root.add_child(_game.flow.warden)
	events.warden_sighted.emit(last)
	_t.eq("74 the meltdown Warden's sighting plays flume_warden_reveal", player.id, "flume_warden_reveal")
	player.advance(1.0)
	events.warden_engaged.emit(last)
	_t.check("74b the Warden's engagement ends the reveal: no card inside a fight", not player.playing and player.played.back().id == "flume_warden_reveal"
		and player.played.back().cut == "stopped", str(player.played.back()))
	events.warden_sighted.emit(last)
	_t.check("75 once per run", not player.playing, player.id)
	_game.flow.warden.free()
	_game.flow.warden = null
	player.stop_all()
	var gone := Node3D.new()
	root.add_child(gone)
	player.play("rivet_freed", SEED, {}, "short")
	player.play("flume_warden_reveal", SEED, {"warden": gone})
	gone.free()
	player.advance(Rows.length("rivet_freed", true) + 0.01)
	_t.check("75c a queued row whose anchor is gone is dropped and logged expired",
		not player.playing and player.played.back().id == "flume_warden_reveal" and player.played.back().cut == "expired", str(player.played.back()))
	events.beacon_unsealed.emit(last)
	_t.check("75b the hand-off plays once per run", not player.playing, player.id)
	events.world_entered.emit(2)
	_t.check("76a world 2's entry without Brindle beaten plays nothing (a Continue)", not player.playing, player.id)
	# The cards earlier checks raised would queue ahead of the shift log; this check is about the world card.
	_game.hud.clear_achievement_toasts()
	events.boss_defeated.emit()
	events.world_entered.emit(2)
	# The shift log takes its turn behind the world card (screen_busy.gd): it starts when the card is gone.
	var waited := 0.0
	while player.id != "spillway_clear" and waited < 20.0:
		await process_frame
		waited += _game.get_process_delta_time()
	_t.eq("76 world 2's entry after Brindle's defeat plays spillway_clear (after the world card)", player.id, "spillway_clear")
	events.stage_entered.emit(1, true)
	_t.check("76b a retry ends the row", not player.playing, player.id)
	player.play("cold_open")
	events.flow_changed.emit("title")
	_t.check("77 the title screen ends the row and its queue", not player.playing and player.queued().is_empty(), "")
	player.play("cold_open")
	player.advance(1.0)
	events.warden_engaged.emit(1)
	_t.check("78 a Warden's engagement ends the cold open: no card inside a fight", not player.playing and player.played.back().id == "cold_open"
		and player.played.back().cut == "stopped", str(player.played.back()))
	var was_engaged: bool = _game.flow._engaged
	var was_sealed: bool = _game.flow.sealed
	_game.flow._engaged = true
	_game.flow.sealed = true
	events.rescue_completed.emit("rivet")
	_t.check("79 a beat that lands inside a Warden fight waits", not player.playing, player.id)
	_game.flow._engaged = was_engaged
	_game.flow.sealed = was_sealed
	events.beacon_unsealed.emit(1 if last != 1 else 0)
	_t.eq("79b it plays on the unseal", player.id, "rivet_freed")
	player.stop_all()


class VariantStub extends Node3D:
	var variant := ""

	func _init(value: String) -> void:
		variant = value


# Sees every key press that reaches the tree's unhandled input, as the ball's input does.
class Listener extends Node:
	var heard: Array

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed:
			heard[0] = true
