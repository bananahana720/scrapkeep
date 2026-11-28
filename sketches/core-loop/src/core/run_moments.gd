extends Node


signal page_ready(page: Dictionary)

const AppShell := preload("res://src/core/app_shell.gd")
const Worlds := preload("res://src/core/worlds.gd")
const SafeStore := preload("res://src/core/safe_store.gd")

const SCHEMA := 1
const DIR := "scrapbook"
const STORE_PATH := "res://src/core/scrapbook_store.gd"
const MIN_PANELS := 4
const MAX_PANELS := 6
const SHOT_WIDTH := 480
const SHOT_GAP := 1.0
const SHOT_CROP := Rect2(0.08, 0.12, 0.84, 0.66)
const BETTER_BY := 1.25
const OPENING_AFTER := 1.5
const NEAR_DEATH := 0.35
const FINALE_RUNUP := 3.0
const SAME_BEAT := 3.0
const SUMMARY_KINDS := ["top_speed", "ledger"]
const KINDS := ["opening", "key_item", "biggest_hit", "set_piece", "near_death", "boss_stagger", "top_speed", "ledger", "finale"]
const PRIORITY := ["boss_stagger", "biggest_hit", "near_death", "key_item", "set_piece", "top_speed", "ledger"]
const SIZES := {"opening": "wide", "finale": "wide", "boss_stagger": "tall"}

const CAPTIONS := {
	"opening": ["Meanwhile, at %s.", "%s. Another shift.", "Our story begins at %s. Again."],
	"key_item": ["%s acquired. It fit. Mostly.", "%s. Nobody read the manual.", "Found: %s. Signed for it."],
	"biggest_hit": ["Impact %s. Paperwork to follow.", "%s units of opinion.", "Hit %s. Somebody felt that."],
	"set_piece": ["%s caught in one go. Show-off.", "%s at once. Nobody counted. We counted."],
	"near_death": ["Hull at %s. This is the tense part.", "%s hull. Moss packed a spare.", "Down to %s. Totally fine."],
	"retried": ["Scrapped. Retried. Nobody mentions it.", "That didn't happen. Next take."],
	"boss_stagger": ["%s, staggered.", "%s wobbled. Write it down.", "%s, briefly reconsidering."],
	"top_speed": ["%s m/s. Over the posted limit.", "Clocked at %s m/s. No ticket issued."],
	"ledger": ["%s machines clocked out early.", "Ledger: %s off shift."],
	"won": ["And that was that. For now.", "Run complete. Somebody make tea.", "The end. Probably."],
	"lost": ["This is the sad part.", "Tragic, right?", "To be continued. Unfortunately."],
}
const SFX := {
	"opening": "", "key_item": "KA-CHUNK", "biggest_hit": "KLANG!", "set_piece": "KRA-KOOM!",
	"near_death": "CREAK", "retried": "clonk", "boss_stagger": "WOBBLE", "top_speed": "FWOOSH",
	"ledger": "", "won": "TA-DA", "lost": "fzzt",
}

var events
var run
var player
var flow
var stages
var storage_dir := "user://"
var stills := not ("--no-stills" in OS.get_cmdline_user_args())
var shots_taken := 0
var last_page := {}
var last_page_path := ""
var _save_task := -1
var _save_out := {}

var _best := {}
var _staggered := {}
var _pending_death := {}
var _boss_down := {}
var _opening_due := false
var _shot_wait := 0.0
var _grabs_pending := 0
var _top_speed := 0.0
var _part_info_fn := Callable()
var _warden_name_fn := Callable()


func setup(events_ref, run_ref, player_ref, flow_ref, stages_ref, dir: String, part_info_fn := Callable(), warden_name_fn := Callable()) -> void:
	name = "RunMoments"
	events = events_ref
	run = run_ref
	player = player_ref
	flow = flow_ref
	stages = stages_ref
	storage_dir = dir
	_part_info_fn = part_info_fn
	_warden_name_fn = warden_name_fn
	events.run_started.connect(func(_class_id: String): _reset())
	events.stage_entered.connect(_on_stage_entered)
	events.enemy_struck.connect(_on_enemy_struck)
	events.ultimate_landed.connect(_on_ultimate_landed)
	events.player_hit.connect(_on_player_hit)
	events.player_died.connect(_on_player_died)
	events.part_gained.connect(func(part_id: String, _source: String): _on_part(part_id, 0))
	events.evolution_fired.connect(func(part_id: String): _on_part(part_id, 1))
	events.posture_changed.connect(_on_posture_changed)
	events.boss_defeated.connect(_on_boss_defeated)
	events.run_ended.connect(_on_run_ended)


func _reset() -> void:
	saved_path()
	_best.clear()
	_staggered.clear()
	_pending_death = {}
	_boss_down = {}
	_opening_due = false
	_shot_wait = 0.0
	_top_speed = 0.0
	last_page = {}
	last_page_path = ""


func _physics_process(delta: float) -> void:
	if _save_task >= 0 and WorkerThreadPool.is_task_completed(_save_task):
		saved_path()
	_shot_wait = maxf(0.0, _shot_wait - delta)
	if run == null or run.over or run.class_def == null:
		return
	if _opening_due and run.stage_time >= OPENING_AFTER:
		_opening_due = false
		_offer("opening", 1.0, {}, true)
	if player != null and player.state != null:
		var v: Vector3 = player.state.velocity
		var planar := Vector2(v.x, v.z).length()
		if planar > _top_speed:
			_top_speed = planar
			_offer("top_speed", planar, {"speed": snappedf(planar, 0.1)})


func still_pending() -> bool:
	return _grabs_pending > 0


func _on_stage_entered(stage: int, retry: bool) -> void:
	if retry and not _pending_death.is_empty():
		_pending_death["caption_kind"] = "retried"
		_keep("near_death", _pending_death)
	_pending_death = {}
	if not _best.has("opening") and stage == _first_stage():
		_opening_due = true


func _on_enemy_struck(_enemy: Node3D, kind: String, force: float) -> void:
	_offer("biggest_hit", force, {"force": roundi(force), "strike": kind})


func _on_ultimate_landed(ultimate_id: String, _at: Vector3, hits: int, damage: float) -> void:
	if hits >= 2:
		_offer("set_piece", float(hits), {"hits": hits, "damage": roundi(damage), "ultimate": ultimate_id})


func _on_player_hit(_amount: float, _source: String) -> void:
	if run.max_hp <= 0.0 or run.hp <= 0.0:
		return
	var share: float = run.hp / run.max_hp
	if share <= NEAR_DEATH:
		_offer("near_death", 1.0 - share, {"hull": roundi(share * 100.0)})


func _on_player_died() -> void:
	_pending_death = _moment("near_death", 1.0, {"hull": 0})
	_grab_into(_pending_death, true)


func _on_part(part_id: String, evolved: int) -> void:
	var info: Dictionary = _part_info_fn.call(part_id) if _part_info_fn.is_valid() else {}
	var tier: int = int(info.get("tier", 1))
	var label := String(info.get("name", part_id.replace("_", " ").capitalize()))
	_offer("key_item", float(tier + evolved * 3), {"part": part_id, "name": label, "tier": tier, "evolved": evolved == 1})


func _on_posture_changed(enemy: Node3D, _posture: float, staggered: bool) -> void:
	if enemy == null:
		return
	var id := enemy.get_instance_id()
	var was: bool = _staggered.get(id, false)
	_staggered[id] = staggered
	if not staggered or was:
		return
	var boss := flow != null and bool(flow.get("in_arena"))
	_offer("boss_stagger", (200.0 if boss else 100.0) + _world_of(int(run.stage)), {"boss": boss, "who": _stagger_name(enemy, boss)}, true)


func _on_boss_defeated() -> void:
	_boss_down = _moment("finale", 1.0, {"boss": _boss_name()})
	_grab_into(_boss_down, true)


func _on_run_ended(won: bool) -> void:
	if _grabs_pending > 0:
		await RenderingServer.frame_post_draw
	var finale: Dictionary
	if won:
		finale = _boss_down if not _boss_down.is_empty() else _moment("finale", 1.0, {})
	else:
		finale = _pending_death if not _pending_death.is_empty() else _moment("finale", 1.0, {})
	finale = finale.duplicate()
	finale["kind"] = "finale"
	finale["caption_kind"] = "won" if won else "lost"
	if not won and _best.has("near_death") and float(finale["t"]) - float(_best["near_death"]["t"]) < FINALE_RUNUP:
		_best.erase("near_death")
	var ledger := _moment("ledger", 1.0, {"kills": int(run.kills), "scrap": int(run.scrap)})
	ledger["t"] = minf(float(ledger["t"]), float(finale["t"]))
	_keep("ledger", ledger)
	last_page = build_page(won, finale)
	_save_later(last_page)
	page_ready.emit(last_page)


func build_page(won: bool, finale: Dictionary) -> Dictionary:
	var middle: Array = []
	var taken: Array = [float(finale["t"])]
	for kind in PRIORITY:
		if _best.has(kind) and middle.size() < MAX_PANELS - 2:
			var t := float(_best[kind]["t"])
			if kind not in SUMMARY_KINDS and taken.any(func(other: float): return absf(other - t) < SAME_BEAT):
				continue
			taken.append(t)
			middle.append(_best[kind])
	if middle.size() < MIN_PANELS - 2 and not _best.has("top_speed"):
		middle.append(_moment("top_speed", 0.0, {"speed": snappedf(_top_speed, 0.1)}))
	middle.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	var rows: Array = []
	if _best.has("opening"):
		rows.append(_best["opening"])
	else:
		rows.append(_moment("opening", 1.0, {}).merged({"t": 0.0, "stage": _first_stage(), "world": _world_of(_first_stage())}, true))
	if not middle.is_empty() and float(middle[0]["t"]) < float(rows[0]["t"]):
		rows[0] = rows[0].merged({"t": float(middle[0]["t"])}, true)
	rows.append_array(middle)
	rows.append(finale)
	var panels: Array = []
	for row in rows:
		panels.append(_panel(row))
	var world := _world_of(int(run.stage))
	return {
		"schema": SCHEMA,
		"run_id": String(run.run_id),
		"ended_unix": Time.get_unix_time_from_system(),
		"pilot": run.class_id(),
		"pilot_name": _pilot_name(),
		"won": won,
		"outcome": "won" if won else "lost",
		"stage_reached": int(run.stage),
		"world": world,
		"world_name": _world_name(world),
		"title": _title(world, won),
		"panels": panels,
	}


func _panel(row: Dictionary) -> Dictionary:
	var kind := String(row["kind"])
	var said := String(row.get("caption_kind", kind))
	return {
		"kind": kind,
		"t": snappedf(float(row["t"]), 0.01),
		"stage": int(row["stage"]),
		"world": int(row["world"]),
		"world_name": _world_name(int(row["world"])),
		"caption": _caption(said, row),
		"sfx": String(SFX.get(said, "")),
		"size": String(SIZES.get(kind, "square")),
		"facts": row["facts"],
		"shot": row.get("shot"),
	}


func saved_path() -> String:
	if _save_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_save_task)
		_save_task = -1
		last_page_path = String(_save_out.get("path", ""))
		_save_out = {}
	return last_page_path


func _save_later(page: Dictionary) -> void:
	saved_path()
	var store = load(STORE_PATH).new(storage_dir) if ResourceLoader.exists(STORE_PATH) else null
	var copy := page.duplicate(true)
	var out := {}
	_save_out = out
	_save_task = WorkerThreadPool.add_task(func(): out["path"] = save(copy, store), false, "run_moments save")


func _exit_tree() -> void:
	saved_path()


func save(page: Dictionary, store = null) -> String:
	if store == null and ResourceLoader.exists(STORE_PATH):
		store = load(STORE_PATH).new(storage_dir)
	if store != null:
		var saved := String(store.save(page))
		if saved == "":
			push_warning("run_moments: scrapbook refused the page: %s" % store.last_error)
		return saved
	var id := String(page.get("run_id", "")).validate_filename()
	var dir := storage_dir.path_join(DIR)
	if id == "" or DirAccess.make_dir_recursive_absolute(dir) != OK:
		push_warning("run_moments: could not save page %s in %s" % [id, dir])
		return ""
	var doc := page.duplicate(true)
	for i in doc["panels"].size():
		var panel: Dictionary = doc["panels"][i]
		var shot = page["panels"][i].get("shot")
		panel["shot"] = ""
		if shot is Image and (shot as Image).save_png(dir.path_join("%s_%d.png" % [id, i])) == OK:
			panel["shot"] = "%s_%d.png" % [id, i]
	var path := dir.path_join(id + ".json")
	if SafeStore.write_atomic(path, JSON.stringify(doc, "\t")) != OK:
		push_warning("run_moments: could not write %s" % path)
		return ""
	return path


func _offer(kind: String, score: float, facts: Dictionary, rare := false) -> void:
	var held: Dictionary = _best.get(kind, {})
	if not held.is_empty():
		var stilled: bool = held.get("shot") != null or held.get("grabbing", false)
		var need := float(held["score"]) * (BETTER_BY if stilled and not rare else 1.0)
		if score <= need:
			return
	var row := _moment(kind, score, facts)
	_keep(kind, row)
	_grab_into(row, rare)


func _keep(kind: String, row: Dictionary) -> void:
	_best[kind] = row


func _moment(kind: String, score: float, facts: Dictionary) -> Dictionary:
	var stage := int(run.stage)
	return {"kind": kind, "score": score, "t": float(run.run_time), "stage": stage, "world": _world_of(stage),
		"facts": facts, "shot": null}


func _grab_into(row: Dictionary, rare := false) -> void:
	if not stills or (_shot_wait > 0.0 and not rare) or AppShell.headless() or not is_inside_tree():
		return
	_shot_wait = SHOT_GAP
	_grabs_pending += 1
	row["grabbing"] = true
	RenderingServer.frame_post_draw.connect(func():
		_grabs_pending = maxi(0, _grabs_pending - 1)
		row.erase("grabbing")
		if not is_inside_tree():
			return
		var image := get_viewport().get_texture().get_image()
		shots_taken += 1
		if image == null or image.is_empty():
			return
		var size := Vector2(image.get_size())
		image = image.get_region(Rect2i(Vector2i(size * SHOT_CROP.position), Vector2i(size * SHOT_CROP.size)))
		var h := maxi(1, roundi(float(SHOT_WIDTH) * image.get_height() / maxf(1.0, image.get_width())))
		image.resize(SHOT_WIDTH, h, Image.INTERPOLATE_BILINEAR)
		row["shot"] = image, CONNECT_ONE_SHOT)


func _caption(said: String, row: Dictionary) -> String:
	var pool: Array = CAPTIONS.get(said, [""])
	var line: String = pool[absi(hash(String(run.run_id) + said)) % pool.size()]
	if not line.contains("%s"):
		return line
	var facts: Dictionary = row["facts"]
	match said:
		"opening":
			return line % _world_name(int(row["world"]))
		"key_item":
			return line % String(facts.get("name", "A part"))
		"biggest_hit":
			return line % str(facts.get("force", 0))
		"set_piece":
			return line % ("%d machines" % int(facts.get("hits", 0)))
		"near_death":
			return line % ("%d%%" % int(facts.get("hull", 0)))
		"boss_stagger":
			return line % String(facts.get("who", "The Warden"))
		"top_speed":
			return line % str(facts.get("speed", 0))
		"ledger":
			return line % str(facts.get("kills", 0))
	return line.replace("%s", "")


func _title(world: int, won: bool) -> String:
	var place := _world_name(world).to_upper().trim_prefix("THE ")
	var count := 1 + absi(hash(String(run.run_id))) % 99
	return "SCRAPKEEP #%d: %s" % [count, ("THE %s JOB" % place) if won else ("TROUBLE AT %s" % place)]


func _stagger_name(enemy: Node3D, boss: bool) -> String:
	if boss:
		return _boss_name()
	var family = enemy.get("family")
	if family == null or String(family) == "" or not _warden_name_fn.is_valid():
		return "The Warden"
	var variant = enemy.get("variant")
	return "The %s" % String(_warden_name_fn.call(String(family), String(variant) if variant != null else ""))


func _boss_name() -> String:
	var world := _world_of(int(run.stage))
	var row: Dictionary = flow.boss_row(world) if flow != null and flow.has_method("boss_row") else Worlds.boss_of(world)
	return String(row.get("name", "The boss"))


func _pilot_name() -> String:
	var def: Resource = run.class_def
	return String(def.display_name) if def != null and String(def.display_name) != "" else run.class_id().capitalize()


func _first_stage() -> int:
	return int(stages.DEFS[0]["stage"]) if stages != null and not stages.DEFS.is_empty() else 1


func _world_of(stage: int) -> int:
	return int(stages.world_of(stage)) if stages != null else 1


func _world_name(world: int) -> String:
	for row in Worlds.ROWS:
		if int(row["id"]) == world:
			return String(row["name"])
	return "the works"
