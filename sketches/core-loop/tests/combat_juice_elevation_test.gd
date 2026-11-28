extends SceneTree

const T := preload("res://tests/support/t.gd")
const Palette := preload("res://src/core/palette.gd")
const DefenceBars := preload("res://tests/support/defence_bars.gd")
const EventJuice := preload("res://src/presentation/event_juice.gd")
const DamageNumbers := preload("res://src/presentation/damage_numbers.gd")
const KillMark := preload("res://src/presentation/kill_mark.gd")
const Vfx := preload("res://src/presentation/vfx.gd")
const Streak := preload("res://src/presentation/streak.gd")
const ChainCounter := preload("res://src/ui/chain_counter.gd")
const FxBudget := preload("res://src/presentation/fx_budget.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const Density := preload("res://src/presentation/density.gd")
const WordBudget := preload("res://src/core/word_budget.gd")
const Comfort := preload("res://src/core/comfort.gd")

const FUSION_KEYS := ["arc+frost", "arc+kinetic", "frost+kinetic", "frost+heat", "arc+heat", "heat+kinetic"]
const POP_AGES := [0.0, 0.02, 0.0504, 0.08, 0.12, 0.139]
const POP_PINS := [
	[12.0, false, [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]],
	[40.0, false, [0.82, 1.1409296469033556, 1.24, 1.1020841637164651, 1.0105753967699607, 1.0000261388524454]],
	[20.0, true, [0.82, 1.2479061958711406, 1.38, 1.1616332592177363, 1.0167443782191048, 1.0000413865163722]],
	[80.0, true, [0.82, 1.2937532882859057, 1.44, 1.1871543001468527, 1.019388227411595, 1.0000479212294835]],
]

var _t := T.new("combat_juice_elevation_test")


func _initialize() -> void:
	_run.call_deferred()


func _make_vfx() -> Vfx:
	var vfx := Vfx.new()
	vfx.root = Node3D.new()
	root.add_child(vfx)
	root.add_child(vfx.root)
	vfx._build_glyphs()
	vfx._build_bursts()
	vfx._build_fx()
	return vfx


func _run() -> void:
	_check_damage_numbers()
	_check_fusions_and_shockwaves()
	_check_shift_over_and_budget()
	_check_streak_and_chain_counter()
	FlashGuard.on = false
	Density.live().reset()
	Comfort.reduced_motion = false
	quit(_t.verdict())


func _check_damage_numbers() -> void:
	_t.check("heat colour matches ff7a29 and all_types covers 4 elements",
		DamageNumbers.HEAT_COLOUR == Color("ff7a29")
		and DamageNumbers.all_types().size() == 4
		and "heat" in DamageNumbers.all_types()
		and DamageNumbers.effect_colour("heat", "player") == Color("ff7a29")
		and DamageNumbers.effect_colour("heat", "player", true) == Palette.BRASS
		and DamageNumbers.effect_colour("heat", "monster") == EventJuice.juice("player_hit")["color"])
	_t.check("heat kind aliases resolve to heat element",
		DamageNumbers.type_of_kind("heat") == "heat"
		and DamageNumbers.type_of_kind("burn") == "heat"
		and DamageNumbers.type_of_kind("thermal") == "heat"
		and DamageNumbers.type_of_kind("torch") == "heat"
		and DamageNumbers.type_of_kind("cinder") == "heat")

	var peak_age := DamageNumbers.POP_WINDOW_S * DamageNumbers.POP_PEAK_T
	var plain_pop := DamageNumbers.pop_scale(peak_age, 12.0, false)
	var big_pop := DamageNumbers.pop_scale(peak_age, DamageNumbers.BIG_FROM, false)
	var crit_pop := DamageNumbers.pop_scale(peak_age, 20.0, true)
	var big_crit_pop := DamageNumbers.pop_scale(peak_age, DamageNumbers.BIG_FROM * 2.0, true)
	var settled := DamageNumbers.pop_scale(DamageNumbers.POP_WINDOW_S, DamageNumbers.BIG_FROM * 2.0, true)
	Comfort.reduced_motion = true
	var still_pop := DamageNumbers.pop_scale(peak_age, DamageNumbers.BIG_FROM * 2.0, true)
	Comfort.reduced_motion = false
	_t.check("elastic pop curve overshoots on big hits and crits and settles by 0.14s",
		is_equal_approx(plain_pop, 1.0)
		and is_equal_approx(big_pop, DamageNumbers.BIG_POP_PEAK) and big_pop > 1.0
		and is_equal_approx(crit_pop, DamageNumbers.CRIT_POP_PEAK) and crit_pop > big_pop
		and is_equal_approx(big_crit_pop, DamageNumbers.BIG_CRIT_POP_PEAK) and big_crit_pop > crit_pop
		and is_equal_approx(settled, 1.0)
		and is_equal_approx(still_pop, 1.0),
		"plain %.2f big %.2f crit %.2f big_crit %.2f settled %.2f still %.2f" % [plain_pop, big_pop, crit_pop, big_crit_pop, settled, still_pop])
	_check_pop_follows_comfort()

	var plain_style := DamageNumbers.crit_outline_style(DamageNumbers.FONT, false)
	var crit_style := DamageNumbers.crit_outline_style(DamageNumbers.CRIT_FONT, true)
	_t.check("crit outline differentiates cleanly with outer ink and inner cream rim",
		int(plain_style["ink_px"]) == DamageNumbers.outline_px(DamageNumbers.FONT)
		and int(plain_style["rim_px"]) == 0
		and int(crit_style["ink_px"]) > DamageNumbers.outline_px(DamageNumbers.CRIT_FONT)
		and int(crit_style["rim_px"]) > 0
		and int(crit_style["rim_px"]) < int(crit_style["ink_px"])
		and crit_style["rim_color"] == Palette.LEDGER_CREAM)

	var layer := DamageNumbers.new()
	root.add_child(layer)
	var reticle := Rect2(Vector2(480.0, 340.0), Vector2(40.0, 40.0))
	var tag := Rect2(Vector2(460.0, 260.0), Vector2(80.0, 24.0))
	layer.keep_off = func() -> Dictionary: return {"ring": [reticle], "tags": [tag]}
	layer.add("e1", 55.0, Vector2(500.0, 360.0), "heat", "player", true)
	layer.add("e2", 45.0, Vector2(500.0, 360.0), "arc", "player", false)
	layer.add("e3", 20.0, Vector2(500.0, 360.0), "frost", "player", false)
	layer.add("e4", 18.0, Vector2(500.0, 360.0), "kinetic", "player", false)
	layer.add("e5", 5.0, Vector2(500.0, 360.0), "heat", "player", false)
	var paths := layer.path_rects()
	var kept_heat := layer.shown().any(func(n): return n["key"] == "e1" and n["type"] == "heat")
	var start_e1 := layer.start_rect(layer._numbers[0])
	_t.check("heat numbers respect MAX_VISIBLE and keep-clear rects",
		layer.visible_count() == DamageNumbers.MAX_VISIBLE
		and paths.size() == DamageNumbers.MAX_VISIBLE
		and kept_heat
		and not start_e1.intersects(reticle))
	layer.step(0.05)
	layer.clear()
	_t.eq("damage_numbers clear empties state", layer.visible_count(), 0)
	layer.queue_free()


func _check_pop_follows_comfort() -> void:
	for pin in POP_PINS:
		var off: Array = []
		var on: Array = []
		for age in POP_AGES:
			Comfort.reduced_motion = false
			off.append(DamageNumbers.pop_scale(age, pin[0], pin[1]))
			Comfort.reduced_motion = true
			on.append(DamageNumbers.pop_scale(age, pin[0], pin[1]))
		Comfort.reduced_motion = false
		var want: Array = pin[2]
		var same: bool = off.size() == want.size()
		for i in off.size():
			same = same and absf(float(off[i]) - float(want[i])) <= 1e-9
		_t.check("with reduced motion off, the pop of value %s crit %s matches the base curve" % [pin[0], pin[1]], same, str(off))
		_t.eq("with reduced motion on, the pop of value %s crit %s holds at 1.0" % [pin[0], pin[1]], on, [1.0, 1.0, 1.0, 1.0, 1.0, 1.0])


func _check_fusions_and_shockwaves() -> void:
	_t.eq("six fusion signatures defined", Vfx.FUSION_SIGNATURES.size(), 6)
	_t.eq("fusion_key normalizes element order", Vfx.fusion_key("kinetic+heat"), "heat+kinetic")
	_t.eq("fusion_signature matches reversed pair", Vfx.fusion_signature("heat+frost"), Vfx.fusion_signature("frost+heat"))

	var styles := {}
	var primaries := []
	var bad_cie := []
	for key in FUSION_KEYS:
		var sig := Vfx.fusion_signature(key)
		_t.check("fusion %s has complete signature" % key, not sig.is_empty() and sig.has("primary") and sig.has("accent") and sig.has("style"))
		styles[int(sig["style"])] = true
		var primary: Color = sig["primary"]
		var accent: Color = sig["accent"]
		for existing in primaries:
			if primary.is_equal_approx(existing):
				bad_cie.append("duplicate_primary:" + key)
		primaries.append(primary)
		var dp := DefenceBars.cie76(primary, Palette.HAZARD)
		var da := DefenceBars.cie76(accent, Palette.HAZARD)
		if dp < 35.0 or da < 35.0:
			bad_cie.append("%s(%.1f/%.1f)" % [key, dp, da])
	_t.check("all 6 fusion styles and primaries are distinct and hold CIE76 >= 35 from HAZARD",
		styles.size() == 6 and bad_cie.is_empty() and DefenceBars.cie76(Palette.HAZARD, Palette.ARC) >= 35.0,
		"styles=%d issues=%s" % [styles.size(), bad_cie])

	var vfx := _make_vfx()
	var slots_before := vfx.kill_mark._slots.size()
	for key in FUSION_KEYS:
		var fired := vfx.play_fusion(key, Vector3(2.0, 0.0, -6.0), 5.0)
		var last_idx: int = (vfx.kill_mark._next - 1 + KillMark.POOL) % KillMark.POOL
		var slot: Dictionary = vfx.kill_mark._slots[last_idx]
		var mat: ShaderMaterial = slot["mat"]
		_t.check("play_fusion %s fires MODE_FUSION style %d with tint and accent" % [key, int(fired["style"])],
			int(slot["mode"]) == KillMark.MODE_FUSION
			and int(mat.get_shader_parameter("style")) == int(fired["style"])
			and mat.get_shader_parameter("tint") == fired["primary"]
			and mat.get_shader_parameter("accent") == fired["accent"]
			and int(vfx.spawned.get("fusion_" + key, 0)) == 1)

	var slow_wave := vfx.impact_shockwave(Vector3.ZERO, 16.0, Vector3.UP, Palette.AMBER, "dunk_shockwave")
	var fast_wave := vfx.impact_shockwave(Vector3.ZERO, 34.0, Vector3.UP, Palette.AMBER, "dunk_shockwave")
	var wave_idx: int = (vfx.kill_mark._next - 1 + KillMark.POOL) % KillMark.POOL
	var wave_slot: Dictionary = vfx.kill_mark._slots[wave_idx]
	_t.check("high-speed dunk shockwave scales with speed and fires MODE_SHOCKWAVE",
		int(wave_slot["mode"]) == KillMark.MODE_SHOCKWAVE
		and float(fast_wave["radius"]) > float(slow_wave["radius"])
		and float(fast_wave["intensity"]) > float(slow_wave["intensity"])
		and int(vfx.kill_mark.spawned.get("shockwave", 0)) == 2
		and int(vfx.spawned.get("dunk_shockwave", 0)) == 2)
	var sw_start := KillMark.shape_at(0.05, KillMark.MODE_SHOCKWAVE, false)
	var sw_late := KillMark.shape_at(0.75, KillMark.MODE_SHOCKWAVE, false)
	var sw_still := KillMark.shape_at(0.5, KillMark.MODE_SHOCKWAVE, true)
	_t.check("shockwave expands over life and honours reduced motion",
		float(sw_late["scale"]) > float(sw_start["scale"])
		and float(sw_late["alpha"]) < float(sw_start["alpha"])
		and float(sw_still["scale"]) < float(KillMark.shape_at(0.5, KillMark.MODE_SHOCKWAVE, false)["scale"]))
	_t.eq("kill_mark allocates zero extra slots during fusions and shockwaves", vfx.kill_mark._slots.size(), slots_before)
	vfx.clear()
	vfx.root.queue_free()
	vfx.queue_free()


func _check_shift_over_and_budget() -> void:
	var vfx := _make_vfx()
	vfx.set_chain(6, 5)
	vfx.shift_over_kill(Vector3(0.0, 0.0, -5.0), 1.1, Palette.AMBER)
	var card_slot: Dictionary = vfx.kill_mark._slots[KillMark.POOL]
	var burst_idx: int = (vfx.kill_mark._next - 1 + KillMark.POOL) % KillMark.POOL
	var burst_slot: Dictionary = vfx.kill_mark._slots[burst_idx]
	_t.check("shift_over_kill stamps card slot and full-punch burst slot",
		int(card_slot["mode"]) == KillMark.MODE_CARD and float(card_slot["t"]) < 1.0
		and int(burst_slot["mode"]) == KillMark.MODE_BURST and is_equal_approx(float(burst_slot["punch"]), 1.0)
		and int(vfx.kill_mark.spawned.get("shift_over", 0)) == 1
		and int(vfx.spawned.get("shift_over", 0)) == 1)
	_t.check("fx_budget ceilings remain unchanged",
		Vfx.POOL == 48
		and Vfx.burst_ceiling() == 200
		and FxBudget.ceiling("hits_and_kills") == 800
		and FxBudget.ceiling("kill_bursts") == 200
		and FxBudget.ceiling("glyphs") == 48)
	vfx.clear()
	_t.check("vfx clear resets chain and pip state cleanly",
		vfx.chain_pips() == 0 and vfx._chain_rung == 0 and is_equal_approx(vfx._pip_pop, 0.0))
	vfx.root.queue_free()
	vfx.queue_free()


func _check_streak_and_chain_counter() -> void:
	var fast := Streak.for_kind("enemy_killed")
	var slow := Streak.for_kind("enemy_killed")
	var t_fast := 1000
	var t_slow := 1000
	for i in 4:
		fast.bump(t_fast)
		slow.bump(t_slow)
		t_fast += 200
		t_slow += 1200
	_t.check("fast streak builds fast_links, higher tier, tempo and momentum",
		fast.rung == 3 and slow.rung == 3
		and fast.fast_links >= 2 and slow.fast_links == 0
		and fast.tier() > slow.tier()
		and fast.tempo() > slow.tempo()
		and fast.momentum(t_fast - 150) > slow.momentum(t_slow - 150))
	fast.bump(t_fast + fast.window_ms + 50)
	_t.check("expired streak resets rung and fast_links cleanly",
		fast.rung == 0 and fast.length == 1 and fast.fast_links == 0 and fast.last_gap_ms == -1)
	fast.reset()
	_t.check("streak reset zeroes peak_rung and state",
		fast.rung == 0 and fast.length == 0 and fast.peak_rung == 0 and fast.fast_links == 0)

	var counter := ChainCounter.new()
	root.add_child(counter)
	counter.step(0.016, 2)
	var base_scale := counter.draw_scale()
	counter.step(0.12, 3)
	counter.step(0.12, 4)
	counter.step(0.12, 5)
	var fast_tier := counter.current_tier()
	counter.step(0.03, 6)
	var punch_scale := counter.draw_scale()
	_t.check("fast chain escalates momentum tier and rhythmic punch scale",
		fast_tier >= 2
		and counter.fast_links() >= 2
		and punch_scale > base_scale and punch_scale > 1.2
		and counter.text() == "6"
		and WordBudget.words_in(counter.text()) <= 1)

	var tier_cie_ok := true
	for tier in ChainCounter.TIER_COMBOS.size():
		if DefenceBars.cie76(ChainCounter.tier_color(tier), Palette.HAZARD) < 35.0:
			tier_cie_ok = false
	_t.check("chain counter tier colours stay CIE76 >= 35 from HAZARD", tier_cie_ok)

	Comfort.reduced_motion = true
	_t.check("reduced motion clamps chain counter scale to 1.0", is_equal_approx(counter.draw_scale(), 1.0))
	Comfort.reduced_motion = false

	counter.reset()
	_t.check("chain counter reset clears all momentum state",
		not counter.visible and counter.text() == "" and counter.current_tier() == 0 and counter.fast_links() == 0)
	counter.queue_free()
