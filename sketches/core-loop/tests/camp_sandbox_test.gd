extends SceneTree

const Game := preload("res://src/game.gd")
const Sandbox := preload("res://src/world/camp_sandbox.gd")
const Picker := preload("res://src/ui/camp_enemy_picker.gd")
const MetRecord := preload("res://src/core/met_record.gd")
const Scrapbook := preload("res://src/ui/camp_scrapbook.gd")
const Profile := preload("res://src/core/profile.gd")
const Roster := preload("res://src/combat/roster.gd")
const TuneRows := preload("res://src/core/tune_rows.gd")
const T := preload("res://tests/support/t.gd")

# The camp's any-enemy sandbox: the kind list, the picker page, and the yard against a real
# Game on the title state and the real camp hub (the walk is screens.toggle_camp; features
# attach by `Sandbox.attach(hub)`, which camp_hub.gd's FEATURES list calls once the hub is built).

var _t := T.new("camp_sandbox_test")
var _kills := 0
var _deaths := 0
var _hits := 0
var _discovered := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_pure()
	await _picker_page()
	await _yard()
	quit(_t.verdict())


# --- Pure: the kind list and the words -------------------------------------------------------

func _pure() -> void:
	var kinds := Sandbox.kinds()
	_t.check("the list opens with the three first kinds", kinds.slice(0, 3) == ["chaser", "lobber", "miniboss"], str(kinds.slice(0, 3)))
	_t.check("the stage Warden and the vault are not callable", not "warden" in kinds and not "vault" in kinds, str(kinds))
	_t.check("no boss piece is callable", kinds.all(func(k): return not Roster.is_boss_piece(k)), "roster kinds only")
	_t.check("every roster counter and ancient is callable", Roster.COUNTERS.all(func(k): return k in kinds) and Roster.ANCIENTS.all(func(k): return k in kinds), str(kinds.size()))
	_t.check("kinds are unique", kinds.size() == _unique(kinds).size(), str(kinds.size()))
	var banned := RegEx.create_from_string("(?i)placeholder|todo|coming soon|!")
	var wordy := true
	for kind in kinds:
		var words: String = Sandbox.where_met(kind) + Sandbox.name_of(kind)
		wordy = wordy and Sandbox.where_met(kind).length() > 12 and banned.search(words) == null
	_t.check("every kind says where it turns up, in plain words", wordy, "where_met")
	_t.eq("the horn enemy is the Shift Boss on screen, whatever its id", Sandbox.name_of("foreman"), "Shift Boss")
	_t.eq("a kind with no name of its own reads as its id in words", Sandbox.name_of("boom_tender"), "Boom Tender")
	_t.check("a kind with an old job says it before how to beat it", Sandbox.line_of("chaser").begins_with("Was a pipe pig") and Sandbox.line_of("chaser").ends_with(String(Roster.row("chaser")["line"])), Sandbox.line_of("chaser"))
	_t.eq("a kind with no job yet shows its line alone", Sandbox.line_of("miniboss"), String(Roster.row("miniboss")["line"]))
	var saved := Profile.new("user://camp_sandbox_test_unsaved.json")
	_t.eq("a fresh save has met nothing", MetRecord.met_kinds(saved, Sandbox.kinds()), [])
	_t.check("marking a kind met is news once", MetRecord.mark_met(saved, "hooker") and not MetRecord.mark_met(saved, "hooker"), "mark_met")
	_t.eq("the save now holds that kind", MetRecord.met_kinds(saved, Sandbox.kinds()), ["hooker"])
	_t.eq("the save keeps a met kind under met. and its id", saved.stat("met.hooker"), 1.0)
	_t.check("a kind the box cannot call is not read back", MetRecord.met_kinds(saved, Sandbox.kinds()).size() == 1 and saved.stat("met.warden") == 0.0, "met list")
	_t.check("a null save has met nothing", MetRecord.met_kinds(null, Sandbox.kinds()).is_empty() and not MetRecord.mark_met(null, "chaser"), "null")
	var rows := Picker.reading(["chaser"])
	_t.check("reading lists every kind with its met state", rows.size() == kinds.size() and rows[0]["met"] and not rows[1]["met"], str(rows.size()))


func _unique(list: Array) -> Dictionary:
	var out := {}
	for item in list:
		out[item] = true
	return out


# --- The picker page ----------------------------------------------------------------------------

func _picker_page() -> void:
	var page := Picker.new()
	root.add_child(page)
	await process_frame
	var chosen: Array = []
	var cleared := [0]
	var closed := [0]
	page.kind_chosen.connect(func(k): chosen.append(k))
	page.clear_chosen.connect(func(): cleared[0] += 1)
	page.closed.connect(func(): closed[0] += 1)
	page.refresh(["chaser", "hooker"], 1)
	_t.eq("the page has one row per kind", page.kinds().size(), Sandbox.kinds().size())
	_t.check("the count line reads the manifest", page.get_child(1).text == "Met 2 of %d" % Sandbox.kinds().size(), page.get_child(1).text)
	_t.eq("the yard is drawn as one pip in four", page.yard_pips(), Vector2i(1, 4))
	_t.check("a met row is a plain name", page.row("chaser").text == "Chaser" and page.row("chaser").met, page.row("chaser").text)
	_t.check("an unmet row is a dim name, not a question mark", page.row("lobber").text == "Lobber" and not page.row("lobber").met, page.row("lobber").text)
	page.row("lobber").pressed.emit()
	_t.check("pressing an unmet row calls nothing and says where it is met", chosen.is_empty() and page.note_text().begins_with("Not met yet.") and page.note_text().contains("Spillway"), page.note_text())
	page.row("hooker").pressed.emit()
	_t.eq("pressing a met row picks it", chosen, ["hooker"])
	page.refresh(["chaser", "hooker"], 4)
	page.row("chaser").pressed.emit()
	_t.check("a full yard blocks the pick and says so", chosen == ["hooker"] and page.note_text().contains("full"), page.note_text())
	# The note keeps to the list's width and never changes the page's height under a focus.
	await process_frame
	var note: Label = page._note
	var heights := {}
	var widest := 0.0
	for kind in page.kinds():
		for state in [[[], 0], [[kind], 0], [[kind], 4]]:
			page.refresh(state[0], state[1])
			page.row(kind).pressed.emit()
			await process_frame
			heights[note.size.y] = true
			widest = maxf(widest, note.size.x)
			if note.get_line_count() * note.get_line_height() + (note.get_line_count() - 1) * note.get_theme_constant("line_spacing") > note.size.y + 0.5:
				heights[-1.0] = true
	_t.check("every note fits the note's box at the list's width, and the box never changes height", heights.size() == 1 and not heights.has(-1.0)
			and widest <= Picker.NOTE_W + 0.5 and widest <= page._grid.size.x + 0.5, "heights %s, widest %.0f of grid %.0f" % [heights.keys(), widest, page._grid.size.x])
	page.refresh(["chaser", "hooker"], 4)
	_t.check("Clear yard is live when something is there", not page.clear_button.disabled, "enabled")
	page.clear_button.pressed.emit()
	page.back_button.pressed.emit()
	_t.check("Clear yard and Back signal", cleared[0] == 1 and closed[0] == 1, "%s %s" % [cleared, closed])
	page.refresh([], 0)
	_t.check("Clear yard is off with an empty yard", page.clear_button.disabled, "disabled")
	page.free()


# --- The yard -----------------------------------------------------------------------------------

func _yard() -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	await process_frame
	await physics_frame
	_t.eq("the walk runs on the title state", game.flow.state_name(), "title")
	var hub = game.camp_hub
	hub.ensure_built()
	var sandbox: Node = hub.root.get_node("CampSandbox")
	var yard: Vector3 = hub.piece("camp_sandbox_yard").global_position
	var entry: Vector3 = hub.socket("camp_sandbox_yard", "entry").origin
	var box: Vector3 = hub.socket("camp_call_box", "interact").origin
	_t.check("the yard and the call box are placed", yard != Vector3.ZERO and box != Vector3.ZERO and entry != Vector3.ZERO and hub.socket("camp_sandbox_yard", "enemy_spawn_3").origin != Vector3.ZERO, str(yard))
	_t.check("the call box is inside the fence", Vector2(box.x - yard.x, box.z - yard.z).length() < 21.0, str(box))
	game.events.enemy_killed.connect(func(_k, _a, _s): _kills += 1)
	game.events.player_died.connect(func(): _deaths += 1)
	game.events.player_hit.connect(func(_a, _s): _hits += 1)
	game.events.synergy_discovered.connect(func(_i, _c, _f): _discovered += 1)
	# The jukebox files the title's tune, and the radio premieres its late set, once the title
	# has played long enough, wherever the ball is. That is the title screen's doing and lands
	# mid-test on a slow machine, so the ear is told it knows every record: the save can then
	# only change by something the yard did.
	for id in TuneRows.ids():
		game.audio().knows_tune(id)
	var run_before := _run_reading(game)
	var save_before := var_to_str(game.ctx.profile._doc)
	sandbox.met_override = Sandbox.kinds()

	_t.eq("no spawn before the walk starts", sandbox.refusal("chaser"), "away")
	game.screens.toggle_camp()
	await physics_frame
	_t.check("the walk is on", hub.walking and sandbox.walking, "walking")
	_t.eq("a ball on the plaza may not call", sandbox.refusal("chaser"), "away")
	await _put(game, yard + Vector3(0.0, 1.5, 5.0))
	_t.eq("a ball in the yard may call", sandbox.refusal("chaser"), "")
	_t.eq("an unknown kind is refused", sandbox.refusal("brindle"), "unknown")
	_t.eq("the Warden is refused", sandbox.refusal("warden"), "unknown")
	sandbox.met_override = ["chaser"]
	_t.eq("a kind not yet met is refused", sandbox.refusal("lobber"), "locked")
	sandbox.met_override = Sandbox.kinds()

	# Each kind spawns, lives a moment, and clears.
	for kind in Sandbox.kinds():
		var enemy: Node3D = sandbox.spawn(kind)
		if not _t.check("%s spawns" % kind, enemy != null, "spawn"):
			continue
		for i in 20:
			await physics_frame
		_t.check("%s is a live enemy in the yard" % kind, is_instance_valid(enemy) and enemy.is_in_group("enemy") and enemy.global_position.distance_to(yard) < 30.0 and enemy.global_position.y > -5.0, str(enemy.global_position))
		sandbox.clear()
		await process_frame
		await process_frame
	_t.eq("clearing leaves no enemy in the tree", get_nodes_in_group("enemy").size(), 0)

	# The cap.
	var first: Array = []
	for i in 4:
		first.append(sandbox.spawn("chaser"))
	_t.check("four live at once", sandbox.live_count() == 4 and first.all(func(e): return e != null), str(sandbox.live_count()))
	_t.eq("a fifth is refused as full", sandbox.refusal("lobber"), "full")
	_t.check("a fifth does not spawn", sandbox.spawn("lobber") == null and sandbox.live_count() == 4, "cap")
	var spots := {}
	for e in first:
		spots[Vector2(snappedf(e.global_position.x, 0.5), snappedf(e.global_position.z, 0.5))] = true
	_t.check("each takes its own grate", spots.size() == 4, str(spots.keys()))
	_t.check("four called enemies stand in the enemy group", get_nodes_in_group("enemy").size() == 4, "group")

	# A kill in the yard counts for nothing.
	var victim: Node3D = first[0]
	game.combat.strike(victim, "slam", 900.0)
	_t.check("a slam kills a chaser in the yard", victim.is_dead(), "dead")
	await physics_frame
	await physics_frame
	_t.eq("the kill is not a run kill", game.run.kills, run_before["kills"])
	_t.eq("no enemy_killed went out", _kills, 0)
	# A ram on a winding-up chaser is the counter_ram trick; in the yard it marks nothing.
	var winder: Node3D = first[1]
	winder.state = 1
	_t.eq("the chaser is winding up", winder.state_name(), "windup")
	game.combat.strike(winder, "ram", 5.0)
	await physics_frame
	_t.check("the trick found nothing in the yard", game.combat.discovered.is_empty() and game.combat.discovery_log.is_empty(),
		str(game.combat.discovered))
	_t.eq("no synergy_discovered went out for the yard's ram", _discovered, 0)
	_t.eq("a dead enemy frees its grate", sandbox.live_count(), 3)
	_t.check("a freed grate is called again", sandbox.spawn("lobber") != null and sandbox.live_count() == 4, "recall")

	# Clearing.
	sandbox.clear()
	await process_frame
	await process_frame
	_t.check("Clear yard despawns them all", sandbox.live_count() == 0 and get_nodes_in_group("enemy").is_empty(), str(get_nodes_in_group("enemy").size()))

	# A wrecked ball is back at the entry, free.
	await _put(game, yard + Vector3(4.0, 1.5, 0.0))
	var hp_before: float = game.run.hp
	sandbox._on_hit(60.0, Vector3.ZERO, "chaser")
	_t.eq("a hit takes hull", sandbox.hull, 40.0)
	sandbox._on_hit(60.0, Vector3.ZERO, "chaser")
	await physics_frame
	await physics_frame
	var at: Vector3 = game.player.ball_position()
	_t.eq("a wreck is counted", sandbox.wrecks, 1)
	_t.check("the wrecked ball is at the entry", Vector2(at.x - entry.x, at.z - entry.z).length() < 1.5, str(at))
	_t.eq("the hull is whole again", sandbox.hull, Sandbox.HULL)
	_t.eq("the run's health is untouched", game.run.hp, hp_before)
	_t.eq("no player_died and no player_hit went out", _deaths + _hits, 0)

	# A fight with the real thing: a chaser's lunge costs hull, never the run.
	var lunger: Node3D = sandbox.spawn("chaser")
	_t.check("a chaser is called for the fight", lunger != null, "chaser")
	await _put(game, lunger.global_position + (yard - lunger.global_position).normalized() * 6.0 + Vector3(0.0, 1.0, 0.0))
	for i in 360:
		await physics_frame
	_t.check("the fight changed nothing in the run", _run_reading(game) == run_before, str(_run_reading(game)))

	# The picker through the box, on the sandbox's own layer.
	sandbox.clear()
	await process_frame
	await _put(game, box + Vector3(0.0, 1.0, 0.0))
	for i in 6:
		await physics_frame
	_t.check("the ball is in the call box's zone", hub.inside("sandbox_call_box") and hub.prompt_words().has("Call box"), str(hub.inside_ids()))
	_t.check("E at the call box opens the picker", hub.press_key(KEY_E) and sandbox.page_open and is_instance_valid(sandbox._page), "page")
	await process_frame
	_t.check("the walk hands the page over its veil", game.screens.walk_page() == sandbox._page and not game.screens.walk_live(), "walk page")
	var caption: Control = Scrapbook.show_line(game.screens, "Fire pit lit.")
	game.screens._sync_walk()
	var under_page: bool = caption.visible
	sandbox._page.row("chaser").pressed.emit()
	_t.eq("a pick on the page calls the enemy", sandbox.live_count(), 1)
	_t.check("the enemies wait while the page is up", not sandbox._is_live(), "paused")
	sandbox._page.clear_button.pressed.emit()
	_t.eq("Clear yard on the page clears", sandbox.live_count(), 0)
	sandbox._page.back_button.pressed.emit()
	await process_frame
	_t.check("Back closes the page and returns to the walk", not sandbox.page_open and game.screens.walk_page() == null and game.screens.walk_live(), "closed")
	_t.check("the camp's caption card is down while the page is read and back with the walk", not under_page and caption.visible, "under the page %s, after %s" % [under_page, caption.visible])
	caption.queue_free()

	# Leaving the yard despawns.
	sandbox.spawn("lobber")
	sandbox.spawn("chaser")
	await _put(game, hub.spawn_position())
	await physics_frame
	await physics_frame
	await process_frame
	_t.check("leaving the yard despawns everything", sandbox.live_count() == 0 and get_nodes_in_group("enemy").is_empty(), str(sandbox.live_count()))
	_t.eq("a ball outside the yard may not call", sandbox.refusal("chaser"), "away")

	# Leaving the walk despawns.
	await _put(game, yard + Vector3(0.0, 1.5, 5.0))
	await physics_frame
	sandbox.spawn("chaser")
	game.screens.toggle_camp()
	await process_frame
	await process_frame
	_t.check("leaving the walk despawns everything", sandbox.live_count() == 0 and get_nodes_in_group("enemy").is_empty(), "walk_left")

	# A run in progress is not the camp.
	var state: int = game.flow.state
	game.flow.state = game.flow.STAGE
	_t.eq("no spawn during a run", sandbox.refusal("chaser"), "in_run")
	game.flow.state = state

	# Nothing counted.
	_t.eq("the run is as it was", _run_reading(game), run_before)
	_t.eq("the saved stats are as they were", var_to_str(game.ctx.profile._doc), save_before)
	_t.check("the run log opened no record", game.run_log._record.is_empty(), "run log")
	_t.eq("no enemy_killed, player_died or player_hit went out", _kills + _deaths + _hits, 0)
	_t.eq("no codex entry was found by the yard's play", _discovered, 0)
	game.queue_free()
	await process_frame


func _run_reading(game) -> Dictionary:
	return {"kills": game.run.kills, "hp": game.run.hp, "stage": game.run.stage, "mass": game.run.mass, "state": game.flow.state_name()}


func _put(game, at: Vector3) -> void:
	game.player.reset_to(at)
	game.player.body().global_position = at
	await physics_frame
	await physics_frame
