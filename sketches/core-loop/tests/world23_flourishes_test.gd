extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Rows := preload("res://src/presentation/flourish_rows.gd")
const Cues := preload("res://src/presentation/flourish_cues.gd")
const FlourishPlayer := preload("res://src/presentation/flourish_player.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const Flow := preload("res://src/core/flow.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const TitleIntros := preload("res://src/presentation/title_intros.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const T := preload("res://tests/support/t.gd")

const SEED := 37
const WORLD_TWO_THREE := [
	"dig_clear",
	"waking_arrival",
	"waking_phase_2",
	"waking_phase_3",
	"waking_rout",
	"highdraft_clear",
	"mind_arrival",
	"mind_phase_2",
	"mind_phase_3",
	"mind_hired",
]

var _t := T.new("world23_flourishes_test")
var _game


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _run() -> void:
	_row_contracts()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.rng.seed = SEED
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	var player = _game.presentation.flourish
	await _layout_sweep(player)
	await _waking_live(player)
	await _mind_live(player)
	await _skip_and_nonblocking(player)
	_game.free()
	await _frames(2)
	quit(_t.verdict())


func _row_contracts() -> void:
	_t.eq("01 all World 2 and 3 flourish rows exist", WORLD_TWO_THREE.filter(func(id): return Rows.has(id)), WORLD_TWO_THREE)
	for id in WORLD_TWO_THREE:
		var full_len := Rows.length(id, false)
		var short_len := Rows.length(id, true)
		_t.check("02 %s full form within %.1f s" % [id, Rows.MAX_SECONDS], full_len > 0.0 and full_len <= Rows.MAX_SECONDS, "%.2f s" % full_len)
		_t.check("03 %s short form within %.1f s" % [id, Rows.MAX_SHORT_SECONDS], short_len > 0.0 and short_len <= Rows.MAX_SHORT_SECONDS, "%.2f s" % short_len)
		var long_lines: Array = Rows.lines(id).filter(func(line): return Rows.words(line) > Rows.LINE_WORD_CAP)
		_t.eq("04 %s lines within %d words" % [id, Rows.LINE_WORD_CAP], long_lines, [])
		var loud: Array = Rows.lines(id).filter(func(line): return String(line).contains("!"))
		_t.eq("05 %s lines carry zero exclamation marks" % id, loud, [])
	for id in ["waking_arrival", "mind_arrival"]:
		var full_len := Rows.length(id, false)
		_t.check("06 %s fits inside boss intro" % id, full_len > 0.0 and full_len <= Rules.INTRO_SECONDS, "%.2f s" % full_len)
		var slow: Array = Cues.world_beats(id, false).filter(func(b): return b.get("kind") == "slow")
		var insets: Array = Rows.pieces(id, false).filter(func(p): return p.kind == "inset")
		var short_clean: bool = not Cues.world_beats(id, true).any(func(b): return b.get("kind") == "slow") \
			and not Rows.pieces(id, true).any(func(p): return p.kind == "inset")
		_t.check("07 %s full has freeze-frame inset and slow beat; short has neither" % id,
			slow.size() == 1 and insets.size() == 1 and short_clean, "slow=%s insets=%d" % [slow, insets.size()])
	for id in ["waking_phase_2", "waking_phase_3", "mind_phase_2", "mind_phase_3"]:
		var full_len := Rows.length(id, false)
		_t.check("08 %s fits inside transition beat" % id, full_len > 0.0 and full_len < 2.0, "%.2f s" % full_len)
		for form in ["full", "short"]:
			var kinds := Rows.pieces(id, form == "short").map(func(p): return String(p.kind))
			_t.check("09 %s %s uses caption only over combat" % [id, form],
				kinds.has("caption") and not kinds.has("stamp") and not kinds.has("sfx_word"), str(kinds))
	for id in ["waking_rout", "mind_hired"]:
		_t.check("10 %s full fits inside victory window with zero hold" % id,
			Rows.length(id, false) <= Flow.VICTORY_SECONDS, "%.2f s" % Rows.length(id, false))
	var waking_title: Array = TitleIntros.row("waking").card
	var waking_card: Array = Rows.pieces("waking_arrival", false).filter(func(p): return p.kind == "card")[0].card
	var waking_shared := waking_card.slice(2).filter(func(field): return field in waking_title.slice(2))
	_t.eq("11 waking_arrival card stats are fresh vs title reel", waking_shared, [])
	for form in [false, true]:
		var mind_card: Array = Rows.pieces("mind_arrival", form).filter(func(p): return p.kind == "card")[0].card
		var has_likes_you := false
		for i in range(2, mind_card.size() - 1, 2):
			if String(mind_card[i]) == "Likes" and String(mind_card[i + 1]) == "you":
				has_likes_you = true
		_t.check("12 mind_arrival (%s) includes Likes -> you" % ("short" if form else "full"), has_likes_you, str(mind_card))
	var hired_stamps := Rows.pieces("mind_hired", false).filter(func(p): return p.kind == "stamp").map(func(p): return p.text)
	_t.eq("13 mind_hired stamps HIRED", hired_stamps, ["HIRED"])
	var hired_captions: Array = Rows.pieces("mind_hired", false).filter(func(p): return p.kind == "caption")[0].text
	_t.check("14 mind_hired captions carry the deadpan humbled to announce wink",
		hired_captions.size() >= 2 and hired_captions.all(func(line): return String(line).to_lower().contains("humbled to announce")),
		str(hired_captions))
	var waking_stamps := Rows.pieces("waking_rout", false).filter(func(p): return p.kind == "stamp").map(func(p): return p.text)
	_t.eq("15 waking_rout stamps STILLED", waking_stamps, ["STILLED"])
	var seen_dig := {}
	var seen_hd := {}
	for s in 16:
		seen_dig[Rows.resolve("dig_clear", false, s)[2].text] = true
		seen_hd[Rows.resolve("highdraft_clear", false, s)[2].text] = true
	_t.check("16 clear panels vary across seeds", seen_dig.size() > 1 and seen_hd.size() > 1,
		"dig=%d highdraft=%d" % [seen_dig.size(), seen_hd.size()])


func _layout_sweep(player) -> void:
	var size: Vector2 = root.get_visible_rect().size
	var clashes: Array = []
	for id in WORLD_TWO_THREE:
		for form in ["full", "short"]:
			player.stop_all()
			player.play(id, SEED, {}, form)
			var times: Array = Rows.pieces(id, form == "short").map(func(p): return float(p.at) + 0.05)
			times.sort()
			for at in times:
				player.advance(at - player.clock)
				await _frames(6)
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
	_t.eq("20 every World 2 and 3 flourish keeps HUD bands clear and avoids column overlap", clashes, [])
	player.stop_all()


func _waking_live(player) -> void:
	Harness.boot(_game)
	player.stop_all()
	Harness.enter_world(_game, 2)
	var mod = Harness.module(_game, 2)
	_t.check("30 Waking arena opens on waking_arrival in full",
		player.playing and player.id == "waking_arrival" and not player.short, "%s short=%s" % [player.id, player.short])
	var dress = mod._arena_dress
	_t.check("31 Waking arena dressing carries heightened lamp and hatch contrast",
		dress != null and dress._materials["glass"].emission_energy_multiplier >= 0.9
		and dress._materials["ancient_light"].emission_energy_multiplier >= 2.8,
		"glass=%.2f ancient=%.2f" % [dress._materials["glass"].emission_energy_multiplier if dress != null else 0.0,
			dress._materials["ancient_light"].emission_energy_multiplier if dress != null else 0.0])
	var lines_control: Control = player._lines
	_t.eq("31b waking_arrival activates speed lines", String(lines_control.get("mode")), "speed")
	var redraws := [0]
	var on_draw := func(): redraws[0] += 1
	lines_control.draw.connect(on_draw)
	player.advance(Rows.length("waking_arrival", false) + 0.01)
	await _frames(2)
	lines_control.draw.disconnect(on_draw)
	_t.check("31c waking_arrival finish clears speed lines and triggers redraw",
		String(lines_control.get("mode")) == "" and redraws[0] >= 1,
		"mode=%s redraws=%d" % [lines_control.get("mode"), redraws[0]])
	_t.check("32 waking_arrival marks profile seen after full play",
		_game.ctx.profile.is_seen(Rows.SEEN_PREFIX + "waking_arrival"), "")
	_game.events.boss_phase_changed.emit(2, "Seam")
	_t.eq("33 Waking phase 2 plays waking_phase_2", player.id, "waking_phase_2")
	player.advance(Rows.length("waking_phase_2", false) + 0.01)
	_game.events.boss_phase_changed.emit(3, "Bedrock")
	_t.eq("34 Waking phase 3 plays waking_phase_3", player.id, "waking_phase_3")
	_game.events.boss_defeated.emit()
	_t.check("35 Waking defeat plays waking_rout with zero extra victory hold",
		player.playing and player.id == "waking_rout" and is_equal_approx(_game.flow._victory_hold, 0.0)
		and is_equal_approx(_game.flow.victory_veil, Rows.length("waking_rout", false)),
		"id=%s hold=%.2f veil=%.2f" % [player.id, _game.flow._victory_hold, _game.flow.victory_veil])
	player.stop_all()
	_game.hud.clear_achievement_toasts()
	_game.flow.physics_step(Flow.VICTORY_SECONDS + 0.1)
	var waited := 0.0
	while player.id != "dig_clear" and waited < 20.0:
		await process_frame
		waited += _game.get_process_delta_time()
	_t.eq("36 entering World 3 after Waking defeat plays dig_clear", player.id, "dig_clear")
	player.stop_all()
	mod.exit_arena()


func _mind_live(player) -> void:
	player.stop_all()
	var w3_last: int = _game.ctx.stages.last_of(3)
	_game.events.beacon_unsealed.emit(w3_last)
	_t.eq("40 unsealing World 3 last beacon plays highdraft_clear", player.id, "highdraft_clear")
	player.stop_all()
	_game.events.beacon_unsealed.emit(w3_last)
	_t.check("41 highdraft_clear plays once per run", not player.playing, player.id)
	Harness.enter_world(_game, 3)
	var mod = Harness.module(_game, 3)
	_t.check("42 Mind arena opens on mind_arrival in full",
		player.playing and player.id == "mind_arrival" and not player.short, "%s short=%s" % [player.id, player.short])
	var dress = mod._arena_dress
	var inlays := dress.get_node_or_null("DeckInlays") as MeshInstance3D if dress != null else null
	var inlay_mat := inlays.mesh.surface_get_material(0) as StandardMaterial3D if inlays != null else null
	_t.check("43 Mind arena dressing carries heightened architectural inlays with zero emission",
		inlay_mat != null and not inlay_mat.emission_enabled and inlay_mat.metallic >= 0.5,
		"metallic=%.2f" % [inlay_mat.metallic if inlay_mat != null else 0.0])
	player.advance(Rows.length("mind_arrival", false) + 0.01)
	_game.events.boss_phase_changed.emit(2, "Adapt")
	_t.eq("44 Mind phase 2 plays mind_phase_2", player.id, "mind_phase_2")
	player.advance(Rows.length("mind_phase_2", false) + 0.01)
	_game.events.boss_phase_changed.emit(3, "Finale")
	_t.eq("45 Mind phase 3 plays mind_phase_3", player.id, "mind_phase_3")
	_game.events.boss_defeated.emit()
	_t.check("46 Mind defeat plays mind_hired with HIRED stamp and zero victory hold",
		player.playing and player.id == "mind_hired" and player.live_kinds().has("stamp")
		and is_equal_approx(_game.flow._victory_hold, 0.0),
		"id=%s kinds=%s hold=%.2f" % [player.id, player.live_kinds(), _game.flow._victory_hold])
	player.stop_all()
	mod.exit_arena()


func _skip_and_nonblocking(player) -> void:
	player.stop_all()
	player.play("mind_arrival", SEED, {}, "full")
	player.advance(FlourishPlayer.SKIP_GRACE)
	var steer := InputEventKey.new()
	steer.keycode = KEY_W
	steer.physical_keycode = KEY_W
	steer.pressed = true
	root.push_input(steer)
	_t.check("50 play verbs never skip World 2 and 3 boss flourishes", player.playing, "")
	var steer_up := steer.duplicate()
	steer_up.pressed = false
	root.push_input(steer_up)
	var skip_press := InputEventKey.new()
	skip_press.keycode = KEY_Q
	skip_press.pressed = true
	root.push_input(skip_press)
	_t.check("51 non-verb press after grace skips mind_arrival cleanly", not player.playing and player.played.back().skipped, str(player.played.back()))
