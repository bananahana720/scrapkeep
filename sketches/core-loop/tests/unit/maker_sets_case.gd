extends RefCounted

const MakerSets := preload("res://src/build/maker_sets.gd")
const Parts := preload("res://src/build/parts.gd")
const Items := preload("res://src/build/items.gd")
const Relics := preload("res://src/build/relics.gd")
const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")

# Maker sets (maker_sets.gd): every one of the 62 items names a known maker, the counts take
# distinct pieces from parts, relics and the racked active, a set turns its bonus on at its piece
# count, and the offer nudge leans 1.5x toward a maker once two of its pieces are held.


func run(t) -> void:
	t.eq("maker fields are sound", MakerSets.validate(), [])
	var items: Array = Items.TABLE.keys() + Parts.PATTERN_PARTS
	# 2026-11-21 (wave 45 U6): Slag Pike and Halo Rig; was 62.
	# 2026-11-21 (wave 45 U7): Backwash, Barbed Reel, Faultline Cap, Second Bell and Long Leash; was 64.
	t.eq("69 items", items.size(), 69)
	t.check("every item has a maker", items.all(func(id): return MakerSets.SETS.has(MakerSets.maker_of(id))))
	t.check("every active has a maker", ActiveDefs.ROWS.keys().all(func(id): return MakerSets.SETS.has(String(ActiveDefs.row(id).get("maker", "")))))
	t.eq("a generated recipe has no maker", MakerSets.maker_of("gen:weapon:rare:arc:on_hit"), "")
	var per := {}
	for id in items:
		per[MakerSets.maker_of(id)] = int(per.get(MakerSets.maker_of(id), 0)) + 1
	for maker in MakerSets.SETS:
		t.check("%s has pieces past its set" % maker, int(per.get(maker, 0)) > int(MakerSets.SETS[maker]["pieces"]), str(per.get(maker, 0)))

	# Counting: distinct pieces only, from every source.
	t.eq("two of one maker", MakerSets.counts(["tracer_round", "magnet_coil"]), {MakerSets.FLEET: 2})
	t.eq("a copy is not a second piece", MakerSets.counts(["tracer_round", "tracer_round", "tracer_round"]), {MakerSets.FLEET: 1})
	t.eq("live at three", MakerSets.live_bonuses(MakerSets.counts(["tracer_round", "magnet_coil", "rivet_seam"])), ["rounded_up"])
	t.eq("not live at two", MakerSets.live_bonuses(MakerSets.counts(["tracer_round", "magnet_coil"])), [])
	t.eq("Moss at two", MakerSets.live_bonuses(MakerSets.counts(["fast_hands", "cell_weapon"])), ["packed_a_spare"])
	t.eq("a relic counts", MakerSets.counts(["tracer_round", "magnet_coil", Relics.part_of("brace_pin")]), {MakerSets.FLEET: 3})
	t.eq("the racked active counts", MakerSets.counts(["quick_spool", "cap_relay"], [ActiveDefs.row(ActiveDefs.SCRAP_ROCKET)["maker"]]),
		{MakerSets.SPILLWAY: 3})
	t.eq("unknown ids are ignored", MakerSets.counts(["gen:weapon:rare:arc:on_hit", "no_such_part", "relic:no_relic"], ["nobody"]), {})
	var all_sets := ["tracer_round", "magnet_coil", "rivet_seam", "quick_spool", "cap_relay", "reserve_tank",
		"pin_setter", "ten_pin", "clean_break", "light_frame", "low_rider", "slipstream", "re_rack", "brace_frame",
		"ring_wave", "chain_arc", "static_burr", "synergy_lens", "fast_hands", "momentum_thief"]
	t.eq("every bonus live", MakerSets.live_bonuses(MakerSets.counts(all_sets)),
		["full_pressure", "rounded_up", "bench_teeth", "open_frame", "tremor", "noticed", "packed_a_spare"])

	# The nudge: 1.1x (1.5x before the pass D fold) on a maker's unheld pieces from two held, nothing at one.
	var pool := ["rivet_seam", "crush_guard", "quick_spool", "tracer_round"]
	t.eq("no nudge at one piece", Parts.maker_nudge(["tracer_round"], pool), {})
	t.eq("nudge at two pieces", Parts.maker_nudge(["tracer_round", "magnet_coil"], pool),
		{"rivet_seam": Parts.MAKER_NUDGE, "crush_guard": Parts.MAKER_NUDGE})
	t.near("nudge is 1.1x", Parts.MAKER_NUDGE, 1.1)
	# Seeded draws: inside one offer bucket the nudged piece shows more often; across buckets
	# each bucket keeps its weight, so the kit, shelf and pair shares hold.
	var lean := Parts.maker_nudge(["tracer_round", "magnet_coil"], ["rivet_seam", "deflect_plate", "quick_spool"])
	t.eq("rivet_seam and deflect_plate share the defence bucket", [Parts.bucket_of("rivet_seam"), Parts.bucket_of("deflect_plate")], ["defence", "defence"])
	t.near("a nudged piece takes 52% of its bucket", _share(["rivet_seam", "deflect_plate"], lean, "rivet_seam"), 1.1 / 2.1, 0.03)
	t.check("across buckets the nudge moves nothing", Parts.bucket_of("quick_spool") != "defence" \
		and absf(_share(["rivet_seam", "quick_spool"], lean, "rivet_seam") - 0.5) < 0.03)
	var raw := {"rivet_seam": 1.0, "deflect_plate": 1.0, "quick_spool": 2.0}
	var nudged := Parts._nudged(raw, lean)
	t.near("the defence bucket keeps its total", float(nudged["rivet_seam"]) + float(nudged["deflect_plate"]), 2.0)
	t.near("the nudged piece is 1.1x its neighbour", float(nudged["rivet_seam"]) / float(nudged["deflect_plate"]), 1.1)
	t.check("no nudge returns the weights unchanged", Parts._nudged(raw, {}) == raw)


func _share(bucket: Array, lean: Dictionary, want: String) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var hits := 0
	for i in 4000:
		if Parts._weighted(rng, bucket, {}, {}, lean) == want:
			hits += 1
	return hits / 4000.0
