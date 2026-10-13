extends SceneTree

const T := preload("res://tests/support/t.gd")
const Director := preload("res://src/world/director.gd")
const Park := preload("res://src/core/park_defs.gd")
const Parts := preload("res://src/build/parts.gd")
const Sheet := preload("res://src/build/build_sheet.gd")
const Game := preload("res://src/game.gd")
const RunState := preload("res://src/core/run_state.gd")
const Profile := preload("res://src/core/profile.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const ClassDef := preload("res://src/core/class_def.gd")

# Filled from the unchanged 5838892 production schedule and settlement fixture.
const BASE_SCHEDULE := ["103ee211a9f10f110261ec97d7515053ca38776fa32234bbc8643493d8b9daba", "ba514375350dfa9d97ed9cca9940248be251073988a8f6df5444436ef2e302b0", "3c268c7fcb1888b742ea226d1b367e87ff2c807249e23cbdf2978bbc0cfc600b", "1a27fa8fc836d0fc6e2430ee2e2d5248224e8515ca64dcc06cc9bb4e684d7500", "cd02a505dd7775c8476ff6e0b0686dac0c96593777c74fcbd9de11bc68456790", "84753cc960b2b0cd8bc3f2e8e50f24c7478c9af0983a3845460bb12d8f600144", "91bb6d575b3bdef35a298c4b1bbfe0de35e635b8c46c846219860443fa944f7f", "2eb2c3b137bb9d515dd608a054ec69a616d27ce961014bd91c84446ae9bf04b9", "516e315254cd364d9fac0c4587dad88708843bbcd93b05677e3b5877c4b55157", "1e01d1e016a29deb86a3f976721efef2ed194de913e8e0710c941797923e3333", "d7b8e25d69defb9abeafb61e890fc4d21b229ab9753461ee18396db8908ce9b1", "b02a9d435c18a111068af2312fc74d743eaf8695b0f778018e1d41aa227595e3", "cf273d16d5501e28a33b8a6af8e07a61b08908556cb1580e79a9b42697c9f43f", "f4b60c021f450d1c47c682bb83e43523228d478f1cf7b584cecd97019325a64a", "be708d7b28fb206f78f1ef225598c0576283c65d11f55868f41df558690b52a7", "d85809d7478eeffe0ab5c14ec825c8b624f674875854c1ff5c5a50f86f5fc1fe", "ea66c43dc6da3b3a78115c9213284b32d738515ae760d84338f4f6c6c4586614", "1e6fdfc53528e17b435f6d2411c1109173f3d7f680837c2362f986f7e35ebaf9", "8219a4fc0a9bd3241b25a84ea8357ef69ae01dae7c2cb0886558cd507702164a", "1bdde5e63474da977a236aab891fed900c4dd7304105a7e5787a72e4cd5e9f57"]
const BASE_RUN := ["79a3503ff647966f8a991fed7f9a0a555cbf7ef9c6166a1f071855145d3fd5ab", "025211015f867afdb95b3a72ae9b33e76edc584ac0948760fa10dfbf5af83f0a", "ac54504c1a122c253edcb3911020b29225b2c323e97f8301d273f33e132e00c6", "acb3225d88bdce56dc53fa490252d60265fcc6309bf9fe5f5885fd7888ebf866", "d2044d4947cad8539ac3a96f5f7febbd1d1ac1c1cad9ee2364a6422de0041c03", "a0b24da4d2f775a5ee69677316b9b776a0e8e38c6a6c0244bc343a77293bbdf2", "aa683c9d92ab96cff026107ceb186b12427a7d8e0e60dd180d48f3d870414fc7", "78feeccde89fddffd699230398fcc72036d69b2fc417f5d0a9093f99c30ca63e", "8246d7e77772a33a9d20584fe4e6ca57fac593b1dcf10802ecb847fbd07afad8", "9652f93f3eca3e7d53c22893ea0d38e8323e37402a4b636948970844a53b7506", "61639b03033b49d8bedce30a3c29e503151a0080ed82dbce2f9b50d97d68c888", "4410b46ca4d84247ce99e08789011799b4d110ae3b3eadfa007c759acc3a1ad8", "e6be474a035514ad8debdd0029a69ae0f8faca300b72658a1688c86a91ef6a1c", "1547d51ac513b18f7211c4598dec5273300b2ac52d91d4a5cdabece5c2996496", "daa8673cd3ccb70f1d2f0a92156c1eeb07a40533aa0775b99c0d3a0579fcd29c", "386f3f4a44a7a6a890415d34c64ed045d5b0e27de659b74cb91f2dc99a348338", "c4c8501a9e8addb33e5468cb0ca1ae11a01f9c5a65db180a55d198e3b19d270b", "2672751aca8d7162c9b8e3cb5323dc2ad244409552b94797958d90d97e94cb92", "4f60b4676e1698d45d5b5be2acce1695cf7438b5da5db0928dc64c3c854ff6d9", "830adaea20d62fd0afea7c9d811f19971c2fb53d8d238978662501132e633900"]
const SEEDS := 20
const DRAWS := 400
var t := T.new("run_tier_test")
var game
var record := false
var section := "all"
var only_seed := -1

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--record-base":
			record = true
		if arg.begins_with("--seed="):
			only_seed = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--section="):
			section = arg.trim_prefix("--section=")
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	call_deferred("_run")

func _hash(value) -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(var_to_bytes(value))
	return digest.finish().hex_encode()

func _schedule(d) -> Dictionary:
	var ball: Vector2 = d._park_map.beacon if d._park_map != null else Vector2.ZERO
	if d._park_map != null:
		d.play_rect = d._park_map.play_rect
	var schedule := []
	var members := 0
	for step in 1200:
		var due: Array = d.advance(0.5, 0, ball)
		members += due.size()
		if not due.is_empty():
			schedule.append([step, due])
	return {"schedule": schedule, "members": members, "cap": d.cap(), "interval": d.interval()}

func _component(seed_value: int, tier_value: int) -> Dictionary:
	var stages := []
	var members := 0
	for row in Park.DEFS:
		var d = Director.new(seed_value)
		if d.has_method("set_run_tier_reader"):
			d.set_run_tier_reader(func(): return tier_value)
		d.use_row(row)
		d.threat = row.threat
		d.authored = row.packs
		d.elite = row.elite
		d.elite_arrival = Park.ELITE_ARRIVAL
		var measured := _schedule(d)
		members += measured.members
		var pay := {"kill_scrap": row.kill_scrap, "source_rarities": Parts.SOURCE_RARITIES,
			"gate_rarities": [Parts.gate_rarities(0), Parts.gate_rarities(1), Parts.gate_rarities(2)],
			"milestones": Parts.MILESTONE_FOR_EVENT}
		if d._park_map != null:
			pay["park_rows"] = d._park_map.park.park_rows
		stages.append({"stage": row.stage, "mode": d.mode, "schedule": measured.schedule,
			"pay_rows": pay, "cap": measured.cap, "interval": measured.interval})
	return {"hash": _hash(stages), "members": members}

func _fresh_profile(won: bool):
	var p := Profile.new("user://run_tier_test/unused.json")
	p.load_profile()
	if won:
		p.earn("first_win", 1.0)
	return p

func _begin(seed_value: int, tier_value: int) -> void:
	game.ctx.profile = _fresh_profile(true)
	game.ctx.calm = true
	game.run.run_seed_override = seed_value
	game.ctx.rng.seed = seed_value
	game.flow._begin_run(ClassDef.all()[0])
	if tier_value != 0 and game.flow.has_method("choose_run_tier"):
		game.flow.choose_run_tier(tier_value)

func _settle(seed_value: int, tier_value: int) -> Dictionary:
	_begin(seed_value, tier_value)
	var measured := _schedule(game.world.director)
	var core_rows := []
	# Invoke the world consumer with committed event-win facts, as the event director does.
	for win in 8:
		game.world._publish([{"kind": "milestone", "id": "tier_fixture_%d" % win, "at": Vector2.ZERO}])
		core_rows.append(game.run.bonus_cores)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pay_rows := []
	var rare := 0
	for draw in DRAWS:
		var picks: Array = Parts.roll(rng, ["common", "rare"], game.run.class_id(), [], 1)
		pay_rows.append(picks)
		if not picks.is_empty() and Parts.rarity_of(picks[0]) == "rare":
			rare += 1
	var rare_share := float(rare) / DRAWS
	return {"hash": _hash([measured.schedule, measured.cap, measured.interval, core_rows, pay_rows,
		game.run.start_pick_options(), game.run.start_pick.get("taken", "")]),
		"threat": measured.members, "cores": game.run.bonus_cores, "rare_share": rare_share,
		"pay": game.run.bonus_cores + rare_share}

func _runtime() -> void:
	var tier_script = load("res://src/core/run_tier.gd") if ResourceLoader.exists("res://src/core/run_tier.gd") else null
	t.check("named pay cap is 1.5", tier_script != null and tier_script.get_script_constant_map().get("PAY_GAIN_CAP") == 1.5)
	for seed_value in SEEDS:
		if only_seed >= 0 and seed_value != only_seed:
			continue
		var a := _component(seed_value, 0)
		var base := _settle(seed_value, 0)
		if record:
			print("BASE " + JSON.stringify({"seed": seed_value, "schedule": a.hash, "run": base.hash}))
			continue
		var b := _component(seed_value, 1)
		var hard := _settle(seed_value, 1)
		t.check("bit-identical schedule seed %d" % seed_value, BASE_SCHEDULE.size() == SEEDS and a.hash == BASE_SCHEDULE[seed_value])
		t.check("bit-identical whole-run default seed %d" % seed_value, BASE_RUN.size() == SEEDS and base.hash == BASE_RUN[seed_value])
		t.check("higher threat seed %d" % seed_value, b.members > a.members and hard.threat > base.threat)
		t.check("higher pay seed %d" % seed_value, hard.pay > base.pay and hard.cores > base.cores and hard.rare_share > base.rare_share)
		t.check("pay cap seed %d" % seed_value, hard.pay / base.pay <= 1.5)
		print("MEASURE " + JSON.stringify({"seed": seed_value, "tier0": base, "tier1": hard, "ratio": hard.pay / base.pay,
			"schedule0": a.hash, "schedule1": b.hash, "measure": "settled event bonus cores + rare parts / 400 production draws"}))

func _card() -> void:
	_begin(701, 0)
	game.ctx.root.bot_driven = false
	if not game.flow.has_method("show_start_card"):
		t.check("production start card appears", false)
		return
	game.ctx.profile = _fresh_profile(false)
	game.flow.show_start_card()
	var card = game.flow.start_card
	t.check("production start card appears", card.is_inside_tree() and card.showing() and card.is_processing_input())
	t.check("locked tier not offered", card.offered_tiers() == [0])
	t.check("locked tier rejected at boundary", not game.flow.choose_run_tier(1) and game.run.selected_run_tier() == 0)
	game.ctx.profile.earn("first_win", 1.0)
	game.flow.show_start_card()
	t.check("win offers tier 1", card.offered_tiers() == [0, 1])
	var labels := []
	for node in card.get_children():
		if node is Label and node.visible:
			labels.append(node.text)
	t.check("rendered pre-choice threat/pay", "Threat: 25% more crowd, 20% shorter intervals" in labels
		and "Pay: 25% more event cores and rare weight; gain cap 1.5x" in labels and game.run.selected_run_tier() == 0)
	# Click the actual tier button, then use the card's keyboard route for a pick.
	card.tier_button(1).pressed.emit()
	t.eq("scripted tier click reaches RunState", game.run.selected_run_tier(), 1)
	t.eq("world director reads selected tier", game.world.director.run_tier(), 1)
	var first: Array = game.run.start_pick_options()
	card.reroll_button.pressed.emit()
	t.check("reroll click reaches RunState", game.run.start_pick_options() != first and game.run.start_pick.rerolls_left == 0)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_1
	card._input(key)
	t.check("scripted pick reaches RunState", game.run.start_pick.taken == game.run.start_pick_options()[0] and not card.showing())
	var doc: Dictionary = game.run.to_entrance_doc()
	var loaded := RunState.new(GameEvents.new(), 4)
	loaded.begin(ClassDef.all()[0])
	t.check("selected tier entrance load", loaded.from_entrance_doc(doc) and loaded.selected_run_tier() == 1)
	loaded.restore()
	t.eq("selected tier retry survives", loaded.selected_run_tier(), 1)
	game.flow.retry_stage()
	t.eq("actual flow retry preserves tier", game.run.selected_run_tier(), 1)
	game.ctx.root.bot_driven = true
	_begin(702, 0)
	t.check("bot default unchanged", game.run.selected_run_tier() == 0 and game.run.start_pick.taken == "" and not game.flow.start_card.showing())

func _variants() -> void:
	_begin(703, 0)
	var base: Resource = Parts.def("loose_trigger")
	var original: Dictionary = Parts.rows()["loose_trigger"].duplicate(true)
	if game.flow.has_method("choose_run_tier"):
		game.flow.choose_run_tier(1)
	var enhanced: Resource = Parts.def("loose_trigger")
	t.check("effective bonus improves", enhanced.mods.weapon_rate > base.mods.weapon_rate)
	t.check("variant id slot rarity preserved", enhanced.id == base.id and enhanced.family == base.family and enhanced.rarity == base.rarity)
	game.run.add_part("loose_trigger", "tier_test")
	game.run.add_part("loose_trigger@tier1", "tier_test")
	t.check("one-version acquisition", game.run.parts == ["loose_trigger"])
	var sheet = Sheet.from_parts(game.run.parts)
	t.near("one-version effective build", sheet.mods.weapon_rate, 1.15)
	var doc: Dictionary = game.run.to_entrance_doc()
	var loaded := RunState.new(GameEvents.new(), 8)
	loaded.begin(ClassDef.all()[0])
	t.check("enhanced reconstruction loads", loaded.from_entrance_doc(doc))
	t.check("one-version reconstruction", loaded.parts == ["loose_trigger"])
	t.near("reconstruction enhanced effect once", Sheet.from_parts(loaded.parts).mods.weapon_rate, 1.15)
	loaded.restore()
	t.near("retry enhanced effect once", Sheet.from_parts(loaded.parts).mods.weapon_rate, 1.15)
	# Deliberately attempt a second version through a save boundary.
	var invalid := doc.duplicate(true)
	invalid.parts.append("loose_trigger@tier1")
	t.check("both-version entrance rejected", not loaded.from_entrance_doc(invalid))
	loaded.begin(ClassDef.all()[0])
	t.near("tier-zero cache does not leak", Parts.def("loose_trigger").mods.weapon_rate, 1.1)
	t.check("cached base row immutable", Parts.rows()["loose_trigger"] == original)

func _run() -> void:
	if record or section in ["all", "runtime"]:
		_runtime()
	if not record and section in ["all", "card"]:
		_card()
	if not record and section in ["all", "variants"]:
		_variants()
	game.free()
	quit(0 if record else t.verdict())
