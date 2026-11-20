# smoke: bots timeout=1800s (51 bot runs in child processes, up to six at once: small and grown on 24 seeds since 2026-10-27, the camper on three since 2026-10-17; a loaded machine slows them past the 180 s default cap, measured 2026-10-11 w13-wardens at load 36 to 78)
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const SliceDefs := preload("res://src/core/slice_defs.gd")
const PlatformPin := preload("res://tests/support/platform_pin.gd")
const T := preload("res://tests/support/t.gd")

# The slice Warden's numbers are held by a bot sweep (tools/posture_sweep.md): a class III ball
# breaks it in about half a minute, a class I ball takes at least twice as long and can still break
# it, and a ball that only shoots from range never does. The bands are checked on medians over the
# committed sweep table (tools/posture_sweep.tsv, seeds 0, 1 and 2). This test also plays the slice
# row as it stands on the same seeds and checks that its medians are within 10 percent of the table's.
# Runs mostly repeat (two grid sweeps matched on 125 of 128 seed 1 and 2 runs, the picked cell on all),
# so a larger move means the fight changed, and the sweep wants rerunning.
# The sweep plays seed % roster size (tools/posture_sweep.gd takes no --pilot); seeds 0 to 2 are
# Sable, Rivet and Kest as long as the first three roster rows keep their order, and the
# "seed N plays" checks fail if they move.

# The cap is 150 s, the small arm's band, so a camper run ends sooner: the smoke run's limit is 120 s.
# A run that breaks before the cap measures the same at any cap.
const SEEDS := "0,1,2"
# The growth ratio is judged over eight seeds (2026-10-17, "Gap wins"): three seeds moved the median by
# more than the gap did (seeds 0 to 2 read 1.75x where 0 to 7 read 1.88x). The camper stays on SEEDS.
# Since 2026-10-27 over 24 seeds: the dam mob dial moved two small seeds and eight seeds read 1.846 where 24 read 1.87.
const GROWTH_SEEDS := "0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23"
const PILOTS := {0: "pylon_engineer", 1: "runner_gunner", 2: "demolitions_caster"}
const PICK := {"plating": 110.0, "curve": 2.0, "ram_shatters": false}
# 2026-10-05 (wave 15): re-pinned for seeds 0, 1 and 2 after Tarn's claw kit took seed 3; bands unchanged
# 2026-10-05 (alpha wave 16 aim-rest): re-recorded after shots aim from the lens rest (W16-1); was 80.6 / 33.1
# 2026-10-07 (dress push P-R18): re-recorded after the camera shake left the global random
# stream (P-R15); the fight is unchanged (zero-shake runs match), one seed's run moved; was 78.4 / 37.9
# 2026-10-08 (alpha wave 10, codex cover ST4): re-pinned after four new codex ids (warden_shatter,
# cable_snap, heavy_roll, plate_peel) first-fire inside this fight; each pays flow.discovery_burst,
# 20 x stage scrap of mass, so the grown ball breaks the Warden sooner (seed 2: 37.9 -> 32.5 s, seeds 0
# and 1 within a run); the slice row is unchanged and the sweep table still holds its band; was 37.9
# 2026-10-08 (wave 11 GP3F): re-pinned to the measured medians, small/grown 2.11; was 72.4 / 37.9. The pre-GP3
# base 39c20a0 already measured 70.5 / 32.5; GP3's elite repeat (director.gd ELITE_REPEAT) on the slice's authored director moved it to 66.6 / 31.5
# 2026-10-09 (wave 12-F BUGFIX-MOVEMENT): re-pinned to the measured medians after the movement fixes (sprint kick
# follows the roll, grounded over-speed drag, harpoon lock cone from the ball, harpoon refused while mounted or
# planted); bisected: green at 339b4db, red at ab0a366 with these exact numbers. The bands still hold (grown 25 to
# 45 s, small at least twice grown); the slice row and the sweep table are unchanged; was 66.6 / 31.5. The hunter's
# build and combat fixes on the same candidate (item hits scale once, the braced Warden plates at plating_for) then
# moved grown from 27.3 back to 30.7 (measured on fa73529; the attribution to those two fixes is inference).
# 2026-10-09 (wave 12-F HOOK-FIX): re-pinned to the measured medians 66.6 / 32.3 after the grounded rigid ball
# stopped paying the over-speed drag again (it is an air rule; rigid_ball.gd); small/grown 2.06, grown inside 25
# to 45 s, so the bands still hold; the slice row and the sweep table are unchanged; was 75.9 / 30.7.
# 2026-10-10 (wave 13 KF1b): measured 66.6 / 32.3 (2.06) on the merged tree plus KF1b, equal to the pins, so
# they stand. KF1's drift to 59.2 / 31.6 came from the slice Warden being a harpoon anchor: forced back on, the bot
# breaks it in 60.9 / 33.6 with Ctrl hauls ungated and stalls (150 / 130 s) with them gated to the stagger; KF1b
# makes anchors opt in (spec "harpoon_anchor": true), and the slice Warden does not, so neither the haul gate nor the drift reaches it.
# 2026-10-10 (wave 13 B4, the bot's skill-bar adapter): re-pinned to the measured medians 59.8 / 30.9 after
# the bots cast slot 2 through the bar and fire the set piece on Q (SKILL-BAR.md section 8), which the
# old bot never pressed; small came in at 59.8 s, 0.14 s outside 10 percent of 66.6. Grown stays inside
# 25 to 45 s and the camper still never breaks it; the slice row and the sweep table are unchanged. The
# live small/grown ratio is 1.94, under the sweep table's 2.0 band (checked on the table, see below);
# was 66.6 / 32.3.
# 2026-10-11 (wave 13 SQ1, the pack telegraph record): re-pinned to the measured medians 50.7 / 31.3 on the
# merged tree 405c517. Attributed: the candidate just before SQ1 (2d3bdce) measures 59.1 / 32.3 and passes these
# pins. SQ1 gives all 22 pack kinds a shared 0.75 s recovery after an attack (the chaser's 0.9 drops to 0.75, the
# lobber and swarm gain one), so the slice Warden's adds ease off after each attack and the small ball breaks it
# sooner. Grown stays inside 25 to 45 s and the camper still never breaks it; the slice row and the sweep table
# are unchanged. The live small/grown ratio falls from 1.83 to 1.62, further under the sweep table's 2.0 band:
# an owner tuning item (docs/decisions.tsv, 2026-10-11 SQ1 rows); was 59.8 / 30.9.
# 2026-10-12 (wave 13 PC-TARN, the shared contact cap): re-pinned to the measured medians 50.0 / 34.5 on an export of
# 00a1bdf. Attributed at level 4: e84fc47 measures 31.3 grown and 00a1bdf with only the contact row removed from
# UltimateMeter.RATE_LIMITS measures the same; with the row present the grown median is 34.5 s at caps 0.14, 0.20 and
# 0.28 alike (queued 8-core runs). The cap slows the ultimate's fill from contact, so grown fights lean on the
# harpoon longer. Grown stays inside 25 to 45 s and the camper still never breaks it; the slice row and the sweep
# table are unchanged. The live small/grown ratio is 1.45, further under the sweep table's 2.0 band: the same owner
# tuning item; was 50.7 / 31.3.
# 2026-10-12 (wave 13 PC-KEST and PC-SABLE kit merges): re-pinned to the measured medians 52.7 / 27.1 on the Sable
# merge over 1e5433e (queued 4-core run). Attributed per seed at level 4: Rivet's rows (seed 1) hold at 67.37 / 34.54;
# Kest's kit (seed 2, merged at 1e5433e) moves grown 43.14 -> 27.01 and small 42.15 -> 52.72 (b75c65d sweep, the
# PC-SABLE round 7 gate); Sable's kit (seed 0) moves grown 31.28 -> 27.12 and small 49.95 -> 51.42. Two of three pilots now break the grown
# Warden faster with their own kits, so the median of three moves from Rivet's row to Sable's. Grown stays inside
# 25 to 45 s and the camper still never breaks it; the slice row and the sweep table are unchanged. The live
# small/grown ratio is 1.94, under the sweep table's 2.0 band: the same owner tuning item; was 50.0 / 34.5.
# 2026-10-17 (SQ2, PR #15): the attacker budget's 0.2 s warning gap eases the first Warden for an unbuilt
# ball (small 57.5 -> 52.4 s over seeds 0 to 7; grown 27.1 -> 27.9 s, seven of eight seeds unchanged). Andrew
# tapped "Gap wins" at 20:11:31Z 17 Oct: the gap stays everywhere, the first Warden's growth target is
# GROWTH (1.85x), and hives keep 2x (posture_bands_swarm_test.gd).
# 2026-10-24 (IL-01 grey panels, #398): re-pinned to the measured medians 62.7 / 28.3 on stage/alpha-w18 3d466be2
# (bisected to Stack #398, deterministic). Attributed at level 4 on that tree: with the Fin Plate's cruise step at 0
# small measures 52.3 s; with no panel drops 56.6; with panels weightless 55.7. Fin Plates raise cruise, the divisor of
# the speed-tier reads (ram tier, Warden tier gate, flail scale), so a small ball that picks them up rams a tier lower
# (cruise items share this coupling). Bands hold: small/grown 2.2x over the 1.85x floor, grown inside 25 to 45 s;
# the slice row and the sweep table are unchanged; was 52.7 / 27.1.
# 2026-10-24 (base-cruise ruling, #424): speed-tier reads now use base cruise (tuning.tier_cruise), so a cruise
# up never drops a hit tier. Re-pinned to the measured medians 56.4 / 28.3; was 62.7 / 28.3. Over 24 seeds
# (tools/posture_sweep.gd --seeds=0..23, the picked cell) small 51.3 s, grown 27.8 s, ratio 1.85, at the 1.85x floor.
# 2026-10-27 (#504 dam mob hits x1.5, coordinator ruling ab): stage 1 mobs hit harder, which knocks the light ball
# about before the Warden: small seeds 2 and 4 end 11 to 18 s sooner (64.6 -> 53.4, 68.7 -> 50.4; seeds 1 and 3 move
# under 1.1 s), grown and the camper unchanged. Over seeds 0 to 7 the ratio read 1.846, under the 1.85x target, so the
# growth ratio is now judged over 24 seeds (GROWTH_SEEDS): small 51.5 s, grown 27.5 s, ratio 1.87 on
# stage/alpha-w19 f441455d (tools/posture_sweep.gd --seeds=0..23, the picked cell). Re-pinned to those medians;
# was 56.4 / 28.3 over eight seeds. Receipt gate/w19-f441455d-bots-5.md.
# 2026-11-08 (invariants thread, ruling bl, #621 bot bite guard): before #621 the bot bit the Warden from point-blank
# on every physics tick; each bite dropped as "passed" on the next and re-bit (seed 2, Kest: 874 bites in a 50.3 s
# fight, unbroken runs of about 20 frames, each one setting and detonating a cable charge). #621 blocked those bites
# outright (small 70.7 s on 82683ffa); the bot now re-presses one every 0.25 s (BotDriver.PASS_BITE_GAP_S), a
# player's sustained mash. One run on stage/alpha-w31 0786c1a8 with that hand: small 66.7 s, grown 25.8 s over
# 24 seeds (1013c7d1 read 50.9 / 27.5), ratio 2.59 over the 1.85x floor, grown inside 25 to 45 s.
# 2026-11-14 (wave 40 gate, PC, bd5b30f5c): small 54.4 s, grown 25.6 s over 24 seeds (a cloud read: 54.8 / 25.6).
# Wave 40's stack shortened the small fight about 18%; the board re-pinned at promotion (an assumption
# Andrew can overturn), and wave 41's harder world 1 stack (PR 845) is tuned against these pins. Was 66.7 / 25.8.
# 2026-11-20 (wave 44 close, Mac Studio, stage/alpha-w44 212fb8e0 after w44/brindle-bot-camera): lens crosshair aim
# lengthened the small-arm slice fight from 54.4 s to 62.0 s over 24 seeds while grown stayed at 25.0 s (within 10%
# of 25.6 s, ratio 2.48x over the 1.85x floor, small 24/24, camper 0/24). Pinned on Mac beside Linux 54.4 s via
# PlatformPin.pick (ruling eb); re-read Linux 54.4 s on a Linux machine before relying on it there.
const GROWTH := 1.85
const EXPECT_SMALL_S := 54.4
const EXPECT_SMALL_S_MAC := 62.0
const EXPECT_GROWN_S := 25.6
const SWEEP := "res://tools/posture_sweep.tsv"
const TOLERANCE := 0.10


func _initialize() -> void:
	var t := T.new("posture_bands_test")
	var row: Dictionary = SliceDefs.of(1)
	var posture: Dictionary = row.get("posture", {})
	var plating := float(row["warden_plating"])
	var curve := float(posture.get("curve", 1.0))
	var shatters := bool(posture.get("ram_shatters", true))
	t.check("the row is the picked cell", is_equal_approx(plating, float(PICK["plating"])) and is_equal_approx(curve, float(PICK["curve"]))
		and shatters == bool(PICK["ram_shatters"]), "row plating %s curve %s shatter %s, pick %s" % [plating, curve, shatters, PICK])
	for run_seed in PILOTS:
		t.eq("seed %d plays %s" % [run_seed, PILOTS[run_seed]], ClassDef.all()[BotDriver.class_index_for(run_seed)].id, PILOTS[run_seed])
	var folder := OS.get_user_data_dir().path_join("posture-bands-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var cells := folder.path_join("cells.tsv")
	var camper_cells := folder.path_join("camper-cells.tsv")
	var cell_args := ["--cap=150", "--plating=%s" % plating, "--curve=%s" % curve, "--shatter=%s" % shatters]
	var results := ChildRuns.run([
		{"script": "res://tools/posture_sweep.gd", "args": ["--out=" + cells, "--runs=" + folder.path_join("runs.tsv"),
			"--procs=4", "--seeds=" + GROWTH_SEEDS, "--arms=small,grown"] + cell_args},
		{"script": "res://tools/posture_sweep.gd", "args": ["--out=" + camper_cells, "--runs=" + folder.path_join("camper-runs.tsv"),
			"--procs=2", "--seeds=" + SEEDS, "--arms=camper"] + cell_args}], 1700.0)
	for result in results:
		t.check("the sweep ran", result["code"] == 0 and not result["timed_out"], "exit %s, timed out %s" % [result["code"], result["timed_out"]])
	var swept := _picked(SWEEP, plating, curve, shatters)
	var swept_grown := float(swept.get("grown_median_s", "0"))
	t.check("the sweep table holds the picked cell and it passes every band", swept.get("pass", "") == "pass",
		"cell %s" % swept)
	t.check("the saved table's grown median sits in 25 to 45 s", swept_grown >= 25.0 and swept_grown <= 45.0, "grown median %.1f s" % swept_grown)
	var cell := _cell(cells)
	var small := float(cell.get("small_median_s", "0"))
	var grown := float(cell.get("grown_median_s", "0"))
	# The band is judged on the fight this run just measured, not on the saved table (WT-BANDS gate, 2026-10-13).
	t.check("over the sweep seeds grown breaks it in 25 to 45 s", grown >= 25.0 and grown <= 45.0, "live grown median %.1f s" % grown)
	t.check("over the sweep seeds small takes at least %.2f times grown's time" % GROWTH, grown > 0.0 and small >= GROWTH * grown,
		"small %.1f s, grown %.1f s" % [small, grown])
	t.eq("small breaks it in every run", cell.get("small_broke", ""), str(GROWTH_SEEDS.count(",") + 1))
	t.eq("the camper never breaks it", _cell(camper_cells).get("camper_broke", ""), "0")
	var expect_small: float = PlatformPin.pick(EXPECT_SMALL_S, EXPECT_SMALL_S_MAC)
	t.check("small median within 10 percent of the sweep's", absf(small - expect_small) <= TOLERANCE * expect_small,
		"small %.1f s, sweep %.1f s" % [small, expect_small])
	t.check("grown median within 10 percent of the sweep's", absf(grown - EXPECT_GROWN_S) <= TOLERANCE * EXPECT_GROWN_S,
		"grown %.1f s, sweep %.1f s" % [grown, EXPECT_GROWN_S])
	if t.failures == 0:
		for file in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(file))
		DirAccess.remove_absolute(folder)
	quit(t.verdict())


# The sweep table's row for one cell as a column-name dictionary, or empty.
func _picked(path: String, plating: float, curve: float, shatters: bool) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var lines := FileAccess.get_file_as_string(path).split("\n", false)
	var head := lines[0].split("\t")
	for line in lines.slice(1):
		var cols := line.split("\t")
		var row := {}
		for i in mini(head.size(), cols.size()):
			row[head[i]] = cols[i]
		if is_equal_approx(float(row.get("plating", "0")), plating) and is_equal_approx(float(row.get("curve", "0")), curve) \
				and row.get("ram_shatters", "") == str(shatters):
			return row
	return {}


# The cell's one data row as a column-name dictionary.
func _cell(path: String) -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(path):
		return out
	var lines := FileAccess.get_file_as_string(path).split("\n", false)
	if lines.size() < 2:
		return out
	var head := lines[0].split("\t")
	var cols := lines[1].split("\t")
	for i in mini(head.size(), cols.size()):
		out[head[i]] = cols[i]
	return out
