extends RefCounted

# The look subjects: one row per named capture subject, read by look_harness.gd and its test.
# It extends capture_cameras.gd (LOOK, ASSET, BAY are the asset sheet's world-fixed views); these
# rows carry the w7 subjects of the wave 7 to 11 captures (w11/captures/_tools/w7_capture.gd) with
# the same eyes and targets, plus the wave 12 probe ports, so a wave 12 frame compares with w11.
#
# A row: {group, stage, kind, owner, cameras, tick, dead_frame, baseline} and optional anchor keys.
#   group   the boot sequence in look_harness.gd that stages the subject (several share one boot).
#   stage   the alpha stage it stands on (alpha_defs.gd row); boss subjects name the stage whose
#           world's boss they enter.
#   kind    actor or prop (the ball must be in every frame, beside the target), scene (ball beside
#           the target too), ui (the game's own camera and screen, no ball).
#   cameras [name, eye, target, fov] or [name, eye, target, fov, anchors]. eye and target are
#           offsets from the row's anchor point (Vector3.ZERO when the row names none), the eye
#           turned by the anchor node's basis when the row sets "basis": true, both multiplied by
#           the anchor's radius when it sets "scale": true. The fifth element names other anchors:
#           a String for both, or [eye anchor, target anchor].
#   tick    the physics tick since boot at which the tree pauses for the subject's first frame.
#   dead_frame  {black, sky}: a frame whose near-black share or flat share (the single most
#           common colour) is over the limit is dead and fails the run. A row overrides the
#           default only with a "dead_reason".
#   baseline  whether the subject joins the baseline set.
#
# Re-aimed rows (wave 12, push/w11/captures/DEAD-FRAMES.md) carry "reaim": the camera and why.
# A row may pin the ball for a camera whose rule points a visual-only mesh hides (look_harness
# ball_candidates): "ball": {camera: offset from the camera's target}, with "ball_reason".

const DEAD := {"black": 0.8, "sky": 0.6}
const STAGES := 6

const SUBJECTS := {
	# ---------------------------------------------------------------- miniboss, swarm, vault (stage 1)
	"pmb_miniboss_stalk": {"group": "smalls", "stage": 1, "kind": "actor", "owner": "VX-FX", "anchor": "miniboss", "basis": true, "tick": 330,
		"cameras": [["front", Vector3(0, 3, -17), Vector3.ZERO, 55.0], ["three_q", Vector3(10.284602, 4, -12.256711), Vector3.ZERO, 55.0], ["side", Vector3(15, 2, 0), Vector3.ZERO, 55.0], ["rear", Vector3(0, 4, 16), Vector3.ZERO, 55.0]]},
	"pmb_miniboss_crouch": {"group": "smalls", "stage": 1, "kind": "actor", "owner": "VX-FX", "anchor": "miniboss", "basis": true, "tick": 360,
		"cameras": [["three_q", Vector3(10.284602, 4, -12.256711), Vector3.ZERO, 55.0], ["side", Vector3(15, 2, 0), Vector3.ZERO, 55.0]]},
	"pmb_miniboss_leap": {"group": "smalls", "stage": 1, "kind": "actor", "owner": "VX-FX", "anchor": "miniboss", "basis": true, "tick": 390,
		"cameras": [["three_q", Vector3(10.284602, 4, -12.256711), Vector3.ZERO, 55.0], ["side", Vector3(15, 2, 0), Vector3.ZERO, 55.0]]},
	"pmb_miniboss_charge_brace": {"group": "smalls", "stage": 1, "kind": "actor", "owner": "VX-FX", "anchor": "miniboss", "basis": true, "tick": 420,
		"cameras": [["three_q", Vector3(10.284602, 4, -12.256711), Vector3.ZERO, 55.0], ["side", Vector3(15, 2, 0), Vector3.ZERO, 55.0]]},
	"pmb_miniboss_vented": {"group": "smalls", "stage": 1, "kind": "actor", "owner": "VX-FX", "anchor": "miniboss", "basis": true, "tick": 450,
		"cameras": [["front", Vector3(0, 3, -17), Vector3.ZERO, 55.0], ["three_q", Vector3(10.284602, 4, -12.256711), Vector3.ZERO, 55.0], ["side", Vector3(15, 2, 0), Vector3.ZERO, 55.0], ["rear", Vector3(0, 4, 16), Vector3.ZERO, 55.0]]},
	"psv_swarm_remnant": {"group": "smalls", "stage": 1, "kind": "actor", "owner": "VX-FX", "anchor": "pack", "basis": true, "tick": 480,
		"cameras": [["pack_front", Vector3(0, 4, -9), Vector3.ZERO, 55.0], ["pack_three_q", Vector3(5.785088, 5, -6.8944), Vector3.ZERO, 55.0], ["pack_top", Vector3(1.368081, 11, -3.758770), Vector3.ZERO, 55.0],
			["one_front", Vector3(0, 1.2, -3.2), Vector3.ZERO, 55.0, "one"], ["one_three_q", Vector3(2.05692, 1.6, -2.451342), Vector3.ZERO, 55.0, "one"], ["one_side", Vector3(3.2, 0.8, 0), Vector3.ZERO, 55.0, "one"]]},
	"psv_swarm_remnant_scattered": {"group": "smalls", "stage": 1, "kind": "actor", "owner": "VX-FX", "anchor": "pack", "basis": true, "tick": 510,
		"cameras": [["pack_three_q", Vector3(5.785088, 5, -6.8944), Vector3.ZERO, 55.0], ["one_three_q", Vector3(2.05692, 1.6, -2.451342), Vector3.ZERO, 55.0, "one"], ["one_side", Vector3(3.2, 0.8, 0), Vector3.ZERO, 55.0, "one"]]},
	"psv_vault": {"group": "smalls", "stage": 1, "kind": "actor", "owner": "VX-FX", "anchor": "vault", "basis": true, "tick": 540,
		"cameras": [["front", Vector3(0, 4, -14), Vector3.ZERO, 55.0], ["three_q", Vector3(8.356239, 5, -9.958577), Vector3.ZERO, 55.0], ["side", Vector3(13, 3, 0), Vector3.ZERO, 55.0], ["rear", Vector3(0, 4, 13), Vector3.ZERO, 55.0]]},
	# ---------------------------------------------------------------- Brindle's pickups (bowl arena)
	"psv_brindle_pickup": {"group": "pickup", "stage": 1, "kind": "prop", "owner": "VX-FX", "anchor": "pickup", "tick": 300,
		"cameras": [["close_a", Vector3(0, 2.2, -5), Vector3.ZERO, 50.0], ["close_b", Vector3(5, 2.5, 3), Vector3.ZERO, 50.0], ["wide", Vector3(0, 6, -16), Vector3.ZERO, 55.0]]},
	# ---------------------------------------------------------------- Dig effects (stage 3)
	"fxd_grit_lamps": {"group": "dig_fx", "stage": 3, "kind": "scene", "owner": "VX-FX", "anchor": "face", "tick": 330,
		"cameras": [["face_close", Vector3(7, 2.5, 5), Vector3(0, 1, 0), 55.0], ["face_wide", Vector3(16, 8, 12), Vector3.ZERO, 60.0], ["lamps_dig_a", Vector3(-90, 22, 140), Vector3(-90, 25, 174), 60.0, ""]]},
	"fxd_rupture_mid": {"group": "dig_fx", "stage": 3, "kind": "scene", "owner": "VX-FX", "anchor": "plate", "tick": 360,
		"cameras": [["three_q", Vector3(18, 12, 18), Vector3(0, -1, 0), 55.0], ["side_low", Vector3(0, 4, 26), Vector3.ZERO, 55.0], ["top", Vector3(2, 34, 6), Vector3(0, -2, 0), 55.0], ["close", Vector3(9, 5, 9), Vector3.ZERO, 55.0]]},
	"fxd_unbroken_plate": {"group": "dig_fx", "stage": 3, "kind": "scene", "owner": "VX-FX", "anchor": "other_plate", "tick": 390,
		"cameras": [["three_q", Vector3(18, 12, 18), Vector3.ZERO, 55.0]]},
	# ---------------------------------------------------------------- Highdraft effects (stage 5)
	"fxh_thermal_occupied": {"group": "hd_fx", "stage": 5, "kind": "scene", "owner": "VX-FX", "anchor": "thermal_0", "tick": 360,
		"cameras": [["side", Vector3(-18, 12, 4), Vector3(0, 14, 0), 60.0], ["low_up", Vector3(-9, 2, 9), Vector3(0, 14, 0), 65.0], ["three_q", Vector3(14, 18, 20), Vector3(0, 12, 0), 60.0]]},
	"fxh_thermal_idle": {"group": "hd_fx", "stage": 5, "kind": "scene", "owner": "VX-FX", "anchor": "thermal_1", "tick": 420,
		"cameras": [["side", Vector3(-18, 12, 4), Vector3(0, 14, 0), 60.0], ["three_q", Vector3(14, 18, 20), Vector3(0, 12, 0), 60.0]]},
	"fxh_net_sag": {"group": "hd_fx", "stage": 5, "kind": "scene", "owner": "VX-FX", "anchor": "contact", "tick": 450,
		"cameras": [["above", Vector3(6, 9, 6), Vector3.ZERO, 55.0], ["low", Vector3(8, 2.5, 0), Vector3.ZERO, 55.0], ["wide", Vector3(0, 30, 24), Vector3.ZERO, 60.0]]},
	"fxh_clouds_sails": {"group": "hd_fx", "stage": 5, "kind": "scene", "owner": "VX-FX", "tick": 480,
		"cameras": [["cloud_deck", Vector3(0, 50, 80), Vector3(0, -20, -120), 70.0], ["cloud_low", Vector3(0, 30, 100), Vector3(180, -10, -150), 70.0], ["sail_spawn", Vector3(24, 34, 124), Vector3(11, 28, 112), 55.0]]},
	# ---------------------------------------------------------------- Highdraft scenery (stage 5)
	"hdr_island_bridge": {"group": "hd_redo", "stage": 5, "kind": "scene", "owner": "VX-GROUND", "tick": 210,
		"cameras": [["island_bridge", Vector3(0, 40, 150), Vector3(0, 26, 100), 60.0], ["bridge_mouth", Vector3(-6, 31, 78), Vector3(0, 27, 66), 60.0], ["island_beacon", Vector3(0, 40, -20), Vector3(0, 22, -58), 60.0], ["island_vault", Vector3(32, 40, 60), Vector3(70, 26, 40), 60.0], ["underside", Vector3(0, 6, 150), Vector3(0, 22, 118), 65.0]]},
	"hdr_anchors": {"group": "hd_redo", "stage": 5, "kind": "prop", "owner": "VX-GROUND", "anchor": "anchor_0", "tick": 240,
		"cameras": [["eye_close", Vector3(-8, 2, -6), Vector3.ZERO, 55.0], ["mast_side", Vector3(14, 8, 10), Vector3.ZERO, 55.0, ["mast_0", "mast_mid"]], ["anchor_1", Vector3(10, 0, -9), Vector3.ZERO, 55.0, "anchor_1"], ["anchor_2", Vector3(10, 0, -9), Vector3.ZERO, 55.0, "anchor_2"]]},
	"hdr_props": {"group": "hd_redo", "stage": 5, "kind": "prop", "owner": "VX-GROUND", "tick": 270,
		"cameras": [["prop_crate", Vector3(5, 3.5, 6), Vector3(0, 0.8, 0), 55.0, "prop_crate"], ["prop_spool", Vector3(5, 3.5, 6), Vector3(0, 0.8, 0), 55.0, "prop_spool"], ["prop_lamp_body", Vector3(5, 3.5, 6), Vector3(0, 0.8, 0), 55.0, "prop_lamp_body"],
			["prop_bearing", Vector3(5, 3.5, 6), Vector3(0, 0.8, 0), 55.0, "prop_bearing"], ["prop_clamp", Vector3(5, 3.5, 6), Vector3(0, 0.8, 0), 55.0, "prop_clamp"], ["prop_pot", Vector3(5, 3.5, 6), Vector3(0, 0.8, 0), 55.0, "prop_pot"]]},
	"hdr_sails": {"group": "hd_redo", "stage": 5, "kind": "prop", "owner": "VX-GROUND", "tick": 300,
		"cameras": [["sail_spawn", Vector3(14, 3, 14), Vector3(0, 2, 0), 55.0, "sail_spawn"], ["sail_vault", Vector3(14, 3, 14), Vector3(0, 2, 0), 55.0, "sail_vault"]]},
	"hdr_thermals": {"group": "hd_redo", "stage": 5, "kind": "prop", "owner": "VX-GROUND", "tick": 330,
		"cameras": [["thermal_a", Vector3(-16, 8, 14), Vector3(0, 8, 0), 60.0, "vent_a"], ["thermal_b", Vector3(-16, 8, 14), Vector3(0, 8, 0), 60.0, "vent_b"], ["thermal_c", Vector3(-16, 8, 14), Vector3(0, 8, 0), 60.0, "vent_c"]]},
	"hdr_net": {"group": "hd_redo", "stage": 5, "kind": "scene", "owner": "VX-GROUND", "tick": 360,
		"cameras": [["net_deck", Vector3(0, 45, -20), Vector3(0, 10, -10), 60.0], ["return_ramps", Vector3(-14, 30, -35), Vector3(-8, 15, -70), 60.0], ["net_low", Vector3(0, 14, 30), Vector3(0, 8, -30), 65.0]]},
	"hdr_sky": {"group": "hd_redo", "stage": 5, "kind": "scene", "owner": "VX-LIGHT", "tick": 390,
		"cameras": [["sky_loom", Vector3(0, 45, 60), Vector3(0, 10, -400), 70.0], ["sky_west", Vector3(0, 45, 60), Vector3(-400, 20, -200), 70.0], ["sky_east", Vector3(0, 45, 60), Vector3(400, 0, -200), 70.0], ["sky_south", Vector3(0, 45, 60), Vector3(-40, 30, 450), 70.0]]},
	# ---------------------------------------------------------------- boss arenas
	"arb_bowl": {"group": "arenas", "stage": 1, "kind": "scene", "owner": "VX-LIGHT", "anchor": "arena", "tick": 180,
		"cameras": [["overview", Vector3(0, 54, 45), Vector3(0, 0, -4), 60.0], ["rim_low", Vector3(72, 14, 40), Vector3(-10, 4, -6), 60.0], ["floor_level", Vector3(34, 3.5, -34), Vector3(-12, 3, 14), 60.0], ["top_down", Vector3(0.5, 120, 1), Vector3.ZERO, 55.0], ["ramp_mast", Vector3(-12, 12, 40), Vector3(-27, 8, -27), 60.0]],
		"reaim": {"overview": "w7 eye (0, 70, 105) looked over the bowl rim into open sky (flat share 0.714, 134,161,183), and the first re-aim (0, 95, 75) still framed the round bowl in a 16:9 frame with sky in every corner (0.575, over 0.6 on VX-LIGHT builds); 2026-10-09 moved to 70 m at 50 degrees, (0, 54, 45) on (0, 0, -4), so the bowl (bank radius 60, boss/arena.gd:15) fills the width and sky is the top corners (0.113)"}},
	"arw_pit": {"group": "arenas", "stage": 4, "kind": "scene", "owner": "VX-LIGHT", "anchor": "pit", "tick": 330,
		"cameras": [["rim_view", Vector3(0, 30, 54), Vector3(0, 2, 0), 60.0], ["down_shaft", Vector3(20, 55, 40), Vector3(0, -6, 0), 60.0], ["floor_level", Vector3(20, 6, 16), Vector3(-8, 2, -10), 66.0], ["side_stack", Vector3(0, -4, 90), Vector3(0, -8, 0), 60.0], ["lamps_wall", Vector3(-30, 8, 20), Vector3(20, 6, -10), 65.0]],
		"reaim": {"floor_level": "w7 eye (28, 3, 24) sat against the pit wall (flat share 0.919, 27,21,10); moved inside the wall ring and raised to read the floor", "rim_view": "w7 eye (0, 12, 66) sat 6 m inside the wall rock (WALL_RADIUS 60, rock bands at y -22 to 20, arena_waking_dress.gd:15,146), a frame of rock the flat-colour rule passes; 2026-10-09 moved inside the ring above the top band, (0, 30, 54) on (0, 2, 0), showing the stacked floor, the core and the lamp-lit wall"}},
	"arm_crown": {"group": "arenas", "stage": 6, "kind": "scene", "owner": "VX-LIGHT", "anchor": "pad", "tick": 480,
		"cameras": [["crown", Vector3(0, 18, 78), Vector3(0, 16, 0), 60.0], ["pad_level", Vector3(36, 4, 30), Vector3(-6, 6, -10), 60.0], ["edge_drop", Vector3(0, 9, 52), Vector3(0, -10, 24), 65.0], ["top_down", Vector3(1, 45, 1), Vector3.ZERO, 55.0], ["sky_far", Vector3(60, 14, 60), Vector3(-80, 2, -140), 70.0]],
		"reaim": {"top_down": "w7 eye 100 m above the pad framed mostly cloud floor (flat share 0.787, 195,195,192); lowered to 45 m so the pad fills the frame"}},
	"arw_pit_b": {"group": "arw2", "stage": 4, "kind": "actor", "owner": "VX-LIGHT", "anchor": "pit", "tick": 330,
		"cameras": [["over_shoulder", Vector3(0, 6, 14), Vector3.ZERO, 62.0, ["ball", "warden"]], ["boss_high", Vector3(34, 20, 34), Vector3(0, -2, 0), 62.0, "warden"], ["boss_low", Vector3(40, 3, 0), Vector3(0, 6, 0), 62.0, "warden"],
			["three_q", Vector3(-9, 4, 6), Vector3(0, 2, 0), 55.0, "warden"],
			["pit_top", Vector3(0, 46, 2), Vector3.ZERO, 60.0], ["pit_edge", Vector3(30, 30, 52), Vector3(-4, -8, 0), 66.0], ["ball_view", Vector3(10, 4, 10), Vector3.ZERO, 55.0, "ball"]]},
	# ---------------------------------------------------------------- devices, pylons, camp bay
	"gpd_cache": {"group": "devices", "stage": 2, "kind": "prop", "owner": "VX-SURF", "anchor": "cache", "tick": 240,
		"cameras": [["front", Vector3(0, 6.25, -22.5), Vector3.ZERO, 50.0], ["three_q", Vector3(7, 3, -6), Vector3.ZERO, 50.0], ["side", Vector3(23.4, 5.2, 0), Vector3.ZERO, 50.0], ["rear", Vector3(-12.5, 7.5, 17.5), Vector3.ZERO, 50.0]],
		"reaim": {"front": "dead on this base (flat share 0.809): the w7 eye (0, 2.5, -9) sits 3 m from the back wall of the 12 x 10 m cache shell (cracked_cache.gd:22-24) and sees only that wall; pulled out 2.5x on the same line", "side": "dead on this base (flat share 0.617): the w7 eye (9, 2, 0) sits 2 m from the side wall; pulled out 2.6x on the same line", "rear": "dead by framing on this base: the w7 eye (-5, 3, 7) sits 2 m outside the shell's +z wall (HALF_D 5) and sees one wall face; 2026-10-09 pulled out 2.5x on the same line like front and side"},
		"ball": {"front": Vector3(-3, 0, -8.5), "rear": Vector3(-3, 0, 8.5)},
		"ball_reason": "the rule's points beside the cache centre fall inside the 12 x 10 m shell (HALF_W 6, HALF_D 5), which has no collider for the rule's rays, so the render showed 0.04 and 0.0 of the ball; pinned 3.5 m outside the wall the camera faces"},
	"gpd_bet": {"group": "devices", "stage": 2, "kind": "prop", "owner": "VX-SURF", "anchor": "bet", "tick": 270,
		"cameras": [["front", Vector3(0, 2.5, -9), Vector3.ZERO, 50.0], ["three_q", Vector3(7, 3, -6), Vector3.ZERO, 50.0], ["side", Vector3(9, 2, 0), Vector3.ZERO, 50.0], ["rear", Vector3(-5, 3, 7), Vector3.ZERO, 50.0]]},
	"gpd_altar": {"group": "devices", "stage": 2, "kind": "prop", "owner": "VX-SURF", "anchor": "altar", "tick": 300,
		"cameras": [["front", Vector3(0, 2.5, -9), Vector3.ZERO, 50.0], ["three_q", Vector3(7, 3, -6), Vector3.ZERO, 50.0], ["side", Vector3(9, 2, 0), Vector3.ZERO, 50.0], ["rear", Vector3(-5, 3, 7), Vector3.ZERO, 50.0]]},
	"gpd_cache_fired": {"group": "devices", "stage": 2, "kind": "prop", "owner": "VX-SURF", "anchor": "cache", "tick": 390,
		"cameras": [["three_q", Vector3(7, 3, -6), Vector3.ZERO, 50.0], ["front", Vector3(0, 6.25, -22.5), Vector3.ZERO, 50.0]],
		"reaim": {"front": "dead on this base (flat share 0.809), the same eye as gpd_cache front; pulled out 2.5x on the same line"},
		"ball": {"front": Vector3(-3, 0, -8.5)},
		"ball_reason": "as gpd_cache front: the rule's point falls inside the shell; pinned 3.5 m outside the wall the camera faces"},
	"gpw_pylon_spillway": {"group": "props", "stage": 1, "kind": "prop", "owner": "VX-SURF", "anchor": "wall", "basis": true, "tick": 150,
		"cameras": [["face", Vector3(0, 1, -14), Vector3.ZERO, 55.0], ["three_q", Vector3(10, 3, -11), Vector3.ZERO, 55.0], ["edge", Vector3(14, 0, 2), Vector3.ZERO, 55.0], ["back", Vector3(0, 3, 14), Vector3.ZERO, 55.0]]},
	"gpw_pylon_reach_w": {"group": "props", "stage": 2, "kind": "prop", "owner": "VX-SURF", "anchor": "reach_w", "tick": 240,
		"cameras": [["face", Vector3(0, 1, -22), Vector3.ZERO, 55.0], ["three_q", Vector3(16, 4, -16), Vector3.ZERO, 55.0], ["side", Vector3(22, 2, 0), Vector3.ZERO, 55.0]]},
	"gpw_pylon_reach_e": {"group": "props", "stage": 2, "kind": "prop", "owner": "VX-SURF", "anchor": "reach_e", "tick": 270,
		"cameras": [["face", Vector3(0, 1, -22), Vector3.ZERO, 55.0], ["three_q", Vector3(16, 4, -16), Vector3.ZERO, 55.0], ["side", Vector3(22, 2, 0), Vector3.ZERO, 55.0]]},
	"cv2_camp_bay": {"group": "bay", "stage": 3, "kind": "prop", "owner": "VX-GROUND", "anchor": "bay", "scale": true, "tick": 0,
		"cameras": [["three_q", Vector3(0.7, 0.45, -0.7), Vector3.ZERO, 60.0], ["side", Vector3(1, 0.25, 0), Vector3.ZERO, 60.0], ["rear", Vector3(-0.7, 0.45, 0.7), Vector3.ZERO, 60.0], ["top", Vector3(0.1, 1.1, 0.1), Vector3.ZERO, 60.0], ["close", Vector3(0.35, 0.15, -0.35), Vector3.ZERO, 60.0]],
		"reaim": {"all": "alpha stage 1 has no bay dock (the bay never docks, aabb empty, every camera aimed at the origin under the map; rear and top flat 0.887 and 1.0); the subject moves to stage 3, the first stage after stage 2 where the bay docks, so it differs from cv2_camp_bay_stage2", "top": "w7 top eye (1, 1.1r, 1) is a unit offset on a radius scale; written as (0.1, 1.1, 0.1) of r, the same direction with no degenerate look-down"}},
	"cv2_camp_bay_stage2": {"group": "bay", "stage": 2, "kind": "prop", "owner": "VX-GROUND", "anchor": "bay", "scale": true, "tick": 0,
		"cameras": [["three_q", Vector3(0.7, 0.45, -0.7), Vector3.ZERO, 60.0], ["side", Vector3(1, 0.25, 0), Vector3.ZERO, 60.0], ["rear", Vector3(-0.7, 0.45, 0.7), Vector3.ZERO, 60.0], ["top", Vector3(0.1, 1.1, 0.1), Vector3.ZERO, 60.0], ["close", Vector3(0.35, 0.15, -0.35), Vector3.ZERO, 60.0]]},
	# ---------------------------------------------------------------- cages, scrap, finishes
	"cag_rivet_locked": {"group": "cages", "stage": 1, "kind": "prop", "owner": "VX-SURF", "anchor": "cage", "basis": true, "tick": 120,
		"cameras": [["front", Vector3(0, 2.5, -11), Vector3.ZERO, 55.0], ["three_q", Vector3(6.427876, 3, -7.660444), Vector3.ZERO, 55.0], ["side", Vector3(10, 2, 0), Vector3.ZERO, 55.0], ["rear", Vector3(0, 3, 10), Vector3.ZERO, 55.0]]},
	"cag_rivet_freeing": {"group": "cages", "stage": 1, "kind": "prop", "owner": "VX-SURF", "anchor": "cage", "basis": true, "tick": 180,
		"cameras": [["front", Vector3(0, 2.5, -11), Vector3.ZERO, 55.0], ["three_q", Vector3(6.427876, 3, -7.660444), Vector3.ZERO, 55.0], ["side", Vector3(10, 2, 0), Vector3.ZERO, 55.0], ["rear", Vector3(0, 3, 10), Vector3.ZERO, 55.0]]},
	"cag_rivet_freed": {"group": "cages", "stage": 1, "kind": "prop", "owner": "VX-SURF", "anchor": "cage", "basis": true, "tick": 240,
		"cameras": [["front", Vector3(0, 2.5, -11), Vector3.ZERO, 55.0], ["three_q", Vector3(6.427876, 3, -7.660444), Vector3.ZERO, 55.0], ["side", Vector3(10, 2, 0), Vector3.ZERO, 55.0], ["rear", Vector3(0, 3, 10), Vector3.ZERO, 55.0]]},
	"cag_dig_locked": {"group": "cages", "stage": 3, "kind": "prop", "owner": "VX-SURF", "anchor": "cage", "basis": true, "tick": 300,
		"cameras": [["front", Vector3(0, 2.5, -11), Vector3.ZERO, 55.0], ["three_q", Vector3(6.427876, 3, -7.660444), Vector3.ZERO, 55.0]]},
	"cag_dig_freeing": {"group": "cages", "stage": 3, "kind": "prop", "owner": "VX-SURF", "anchor": "cage", "basis": true, "tick": 360,
		"cameras": [["front", Vector3(0, 2.5, -11), Vector3.ZERO, 55.0], ["three_q", Vector3(6.427876, 3, -7.660444), Vector3.ZERO, 55.0]]},
	"scr_spillway_a": {"group": "scrap", "stage": 1, "kind": "prop", "owner": "VX-GROUND", "anchor": "scrap_a", "tick": 120,
		"cameras": [["close", Vector3(2.4, 1.6, -3), Vector3.ZERO, 45.0], ["three_q", Vector3(4, 2.5, 4), Vector3.ZERO, 50.0], ["cluster", Vector3(0, 5, -9), Vector3(0, -0.5, 4), 55.0]]},
	"scr_variants": {"group": "scrap", "stage": 1, "kind": "prop", "owner": "VX-GROUND", "tick": 150,
		"cameras": [["v_?", Vector3(2.2, 1.4, -2.6), Vector3.ZERO, 45.0, "v_?"], ["v_BentPlate", Vector3(2.2, 1.4, -2.6), Vector3.ZERO, 45.0, "v_BentPlate"], ["v_BoltCluster", Vector3(2.2, 1.4, -2.6), Vector3.ZERO, 45.0, "v_BoltCluster"],
			["v_GearSegment", Vector3(2.2, 1.4, -2.6), Vector3.ZERO, 45.0, "v_GearSegment"], ["v_PipeStub", Vector3(2.2, 1.4, -2.6), Vector3.ZERO, 45.0, "v_PipeStub"]]},
	"scr_dig": {"group": "scrap", "stage": 3, "kind": "prop", "owner": "VX-GROUND", "anchor": "scrap_dig", "tick": 240,
		"cameras": [["close", Vector3(2.4, 1.6, -3), Vector3.ZERO, 45.0], ["cluster", Vector3(0, 6, -10), Vector3(0, -0.5, 4), 55.0],
			# The haul cart at the Dig rim's foot (dig_scenery.gd _cart, the first cart on the south edge), world-fixed (VX-SWAP).
			["cart", Vector3(78, 7, 149), Vector3(88.5, 2, 161.5), 50.0, ""]]},
	"wog_spillway": {"group": "workshop", "stage": 1, "kind": "scene", "owner": "VX-SURF", "anchor": "ball", "tick": 120,
		"cameras": [["spawn_pad", Vector3(0, 7, -16), Vector3(0, 0, 10), 60.0], ["spawn_wide", Vector3(-40, 28, -50), Vector3(10, 0, 30), 65.0], ["beacon", Vector3(-80, 52, -45), Vector3(-46, 34, -12), 65.0, ""],
			["relay", Vector3(10, 60, -150), Vector3(10, 38, -84), 65.0, ""], ["benches", Vector3(10, 44, 56), Vector3(24, 28, 22), 65.0, ""],
			# The stage-1 beacon close-up (VX-SWAP): map_spillway.gd BEACON (-46, -12) on the 15 m bowl floor, eye 12 m out at three-quarter.
			["beacon_close", Vector3(-37.5, 21, -3.5), Vector3(-46, 24, -12), 70.0, ""]]},
	"wog_reach": {"group": "workshop", "stage": 2, "kind": "scene", "owner": "VX-SURF", "anchor": "ball", "tick": 240,
		"cameras": [["spawn_pad", Vector3(0, 8, -18), Vector3(0, 0, 10), 60.0], ["spawn_wide", Vector3(-45, 30, -55), Vector3(0, 0, 40), 65.0], ["tower_base", Vector3(60, 25, 60), Vector3(0, 20, 0), 60.0, "tower"],
			["tower_top", Vector3(70, 80, 70), Vector3(0, 60, 0), 60.0, "tower"], ["tunnels", Vector3(0, 60, 0), Vector3(40, 40, 70), 65.0, ""]]},
	# The Reach cache valve (SWAP-WAVE 12-F): map_reach.gd SECRET_VALVE (-100, 54), foot y 23.68, hub 1.6 m up; world-fixed
	# eyes on the door side (+z); mid and far look down over the cache pocket walls by the door at z 64. far is 45 m out,
	# past detail1's 32 m end plus its 4 m margin.
	"swp_valve_wheel": {"group": "workshop", "stage": 2, "kind": "prop", "owner": "SWAP-WAVE", "tick": 255,
		"cameras": [["close", Vector3(-94.5, 27.2, 59.5), Vector3(-100, 25, 54), 50.0], ["mid", Vector3(-92, 38, 66), Vector3(-100, 25, 54), 55.0],
			["far", Vector3(-84, 55, 84), Vector3(-100, 25, 54), 50.0]],
		"ball": {"close": Vector3(3.2, 0, 1.5), "mid": Vector3(3.5, 0, -0.5), "far": Vector3(3.5, 0, -0.5)},
		"ball_reason": "the scale mannequin stands beside the wheel on the door side, clear of the 1.9 m wheel radius, in every camera"},
	"cache_activity": {"group": "workshop", "stage": 2, "kind": "prop", "owner": "VX-SURF", "anchor": "cache", "tick": 270,
		"cameras": [["front", Vector3(0, 4, -13), Vector3.ZERO, 55.0], ["three_q", Vector3(10, 5, -10), Vector3.ZERO, 55.0], ["side", Vector3(14, 3, 0), Vector3.ZERO, 55.0], ["wide", Vector3(24, 22, -24), Vector3.ZERO, 60.0]],
		"reaim": {"wide": "dead by framing in every build (w11 capture the same): the w7 eye (0, 22, -34) sits beside the tall pylon by the cache, which fills the frame centre and hides the cache and the ball (render 0.0 of the ball); 2026-10-09 turned 45 degrees about the cache to (24, 22, -24), same height and distance class, so the cache, the white cache block and the ball read with the pylon at the edge"}},
	# ---------------------------------------------------------------- Dig deep floor (P-GROUND port)
	"dig_deep_floor": {"group": "dig_deep", "stage": 4, "kind": "scene", "owner": "VX-GROUND", "anchor": "spawn", "tick": 180,
		"cameras": [["floor", Vector3(-6, 9, -12), Vector3(4, 0, 10), 60.0]]},
	# ---------------------------------------------------------------- title, class select, ending, customize (the game's camera)
	"ttl_title": {"group": "title", "stage": 1, "kind": "ui", "owner": "VX-LIGHT", "tick": 60, "cameras": [["t0", Vector3.ZERO, Vector3.ZERO, 55.0]]},
	"ttl_title_b": {"group": "title", "stage": 1, "kind": "ui", "owner": "VX-LIGHT", "tick": 210, "cameras": [["t1", Vector3.ZERO, Vector3.ZERO, 55.0]]},
	"ttl_class_select": {"group": "title", "stage": 1, "kind": "ui", "owner": "VX-LIGHT", "tick": 270, "cameras": [["c0", Vector3.ZERO, Vector3.ZERO, 55.0]]},
	"ttl_stage_only": {"group": "title2", "stage": 1, "kind": "ui", "owner": "VX-LIGHT", "tick": 60, "cameras": [["t0", Vector3.ZERO, Vector3.ZERO, 55.0]],
		"dead_frame": {"black": 0.8, "sky": 0.9}, "dead_reason": "the title stage picture alone: the menu layers are hidden by design and the backdrop is one flat panel colour (31,57,66)"},
	"ttl_stage_sableshell": {"group": "title2", "stage": 1, "kind": "ui", "owner": "VX-LIGHT", "anchor": "SableShell", "tick": 0, "cameras": [["close", Vector3(1.2, 0.8, 3.4), Vector3.ZERO, 48.0]]},
	"ttl_stage_rivetshell": {"group": "title2", "stage": 1, "kind": "ui", "owner": "VX-LIGHT", "anchor": "RivetShell", "tick": 0, "cameras": [["close", Vector3(1.2, 0.8, 3.4), Vector3.ZERO, 48.0]]},
	"ttl_stage_kestshell": {"group": "title2", "stage": 1, "kind": "ui", "owner": "VX-LIGHT", "anchor": "KestShell", "tick": 0, "cameras": [["close", Vector3(1.2, 0.8, 3.4), Vector3.ZERO, 48.0]]},
	"ttl_stage_spil9": {"group": "title2", "stage": 1, "kind": "ui", "owner": "VX-LIGHT", "anchor": "SPIL9", "tick": 0, "cameras": [["close", Vector3(0.62, 0.15, 1.8), Vector3(0, -0.35, 0), 48.0]],
		"reaim": {"close": "w7 offset (1.8, 1.2, 5.2) left SPIL9 small on the flat title backdrop (flat share 0.679, 31,57,66; 0.651 at two thirds of the distance, 0.616 at a third with SPIL9 in the lower half); pulled in to a third of the distance and aimed 0.35 m lower so SPIL9 sits in the middle"}},
	"ttl_stage_ball": {"group": "title2", "stage": 1, "kind": "ui", "owner": "VX-LIGHT", "anchor": "Ball", "tick": 0, "cameras": [["close", Vector3(1.2, 0.8, 3.4), Vector3.ZERO, 48.0]],
		"reaim": {"close": "w7 offset (1.8, 1.2, 5.2) left the ball small on the flat title backdrop (flat share 0.615, 31,57,66); pulled in to two thirds of the distance on the same line"}},
	"end_spillway_establish": {"group": "ending", "stage": 1, "kind": "ui", "owner": "VX-LIGHT", "elapsed": 1.0, "tick": 0, "cameras": [["frame", Vector3.ZERO, Vector3.ZERO, 55.0]]},
	"end_spillway_copy": {"group": "ending", "stage": 1, "kind": "ui", "owner": "VX-LIGHT", "elapsed": 4.0, "tick": 0, "cameras": [["frame", Vector3.ZERO, Vector3.ZERO, 55.0]]},
	"end_dig_establish": {"group": "ending", "stage": 1, "kind": "ui", "owner": "VX-LIGHT", "elapsed": 14.5, "tick": 0, "cameras": [["frame", Vector3.ZERO, Vector3.ZERO, 55.0]]},
	"end_dig_copy": {"group": "ending", "stage": 1, "kind": "ui", "owner": "VX-LIGHT", "elapsed": 18.0, "tick": 0, "cameras": [["frame", Vector3.ZERO, Vector3.ZERO, 55.0]]},
	"end_highdraft_establish": {"group": "ending", "stage": 1, "kind": "ui", "owner": "VX-LIGHT", "elapsed": 26.5, "tick": 0, "cameras": [["frame", Vector3.ZERO, Vector3.ZERO, 55.0]]},
	"end_highdraft_copy": {"group": "ending", "stage": 1, "kind": "ui", "owner": "VX-LIGHT", "elapsed": 30.0, "tick": 0, "cameras": [["frame", Vector3.ZERO, Vector3.ZERO, 55.0]]},
	"end_credits_start": {"group": "ending", "stage": 1, "kind": "ui", "owner": "VX-LIGHT", "elapsed": 38.0, "tick": 0, "cameras": [["frame", Vector3.ZERO, Vector3.ZERO, 55.0]]},
	"end_credits_mid": {"group": "ending", "stage": 1, "kind": "ui", "owner": "VX-LIGHT", "elapsed": 48.0, "tick": 0, "cameras": [["frame", Vector3.ZERO, Vector3.ZERO, 55.0]]},
	"cus_page_default": {"group": "customize", "stage": 1, "kind": "ui", "owner": "VX-LIGHT", "tick": 0, "cameras": [["page", Vector3.ZERO, Vector3.ZERO, 55.0]],
		"dead_frame": {"black": 0.8, "sky": 0.85}, "dead_reason": "a UI page: the panel fill (35,44,44) is flat by design, so the flat share runs near 0.8"},
	"cus_page_equipped": {"group": "customize", "stage": 1, "kind": "ui", "owner": "VX-LIGHT", "tick": 0, "cameras": [["page", Vector3.ZERO, Vector3.ZERO, 55.0]],
		"dead_frame": {"black": 0.8, "sky": 0.85}, "dead_reason": "a UI page: the panel fill (35,44,44) is flat by design, so the flat share runs near 0.8"},
	"cus_page_decal": {"group": "customize", "stage": 1, "kind": "ui", "owner": "VX-LIGHT", "tick": 0, "cameras": [["page", Vector3.ZERO, Vector3.ZERO, 55.0]],
		"dead_frame": {"black": 0.8, "sky": 0.85}, "dead_reason": "a UI page: the panel fill (35,44,44) is flat by design, so the flat share runs near 0.8"},
}

# The order --all boots the groups in; every group a row names appears once.
const GROUPS := ["smalls", "pickup", "dig_fx", "hd_fx", "hd_redo", "arenas", "arw2", "devices", "props", "bay", "cages", "scrap", "workshop", "dig_deep", "title", "title2", "ending", "customize"]


static func names() -> Array:
	var out: Array = SUBJECTS.keys()
	out.sort()
	return out


static func in_group(group: String) -> Array:
	return names().filter(func(n): return SUBJECTS[n]["group"] == group)


static func dead_limits(subject: String) -> Dictionary:
	return SUBJECTS[subject].get("dead_frame", DEAD)


# Actor and prop frames must show the ball; scene frames place it beside the target too, but a
# distant scene camera may leave it under a pixel, so only actors and props fail without it.
static func needs_ball(subject: String) -> bool:
	return ["actor", "prop"].has(SUBJECTS[subject]["kind"])


static func places_ball(subject: String) -> bool:
	return SUBJECTS[subject]["kind"] != "ui"


# Eye and target of one camera row. anchors maps a name to {point, basis, radius}.
static func resolve(subject: String, shot: Array, anchors: Dictionary) -> Dictionary:
	var row: Dictionary = SUBJECTS[subject]
	var base := String(row.get("anchor", ""))
	var eye_anchor := base
	var target_anchor := base
	if shot.size() > 4:
		if shot[4] is Array:
			eye_anchor = String(shot[4][0])
			target_anchor = String(shot[4][1])
		else:
			eye_anchor = String(shot[4])
			target_anchor = String(shot[4])
	var ea: Dictionary = anchors.get(eye_anchor, {})
	var ta: Dictionary = anchors.get(target_anchor, {})
	var scale := float(ea.get("radius", 1.0)) if row.get("scale", false) else 1.0
	var turn: Basis = ea.get("basis", Basis.IDENTITY) if row.get("basis", false) else Basis.IDENTITY
	var eye: Vector3 = ea.get("point", Vector3.ZERO) + turn * (shot[1] * scale)
	var target: Vector3 = ta.get("point", Vector3.ZERO) + shot[2] * scale
	return {"name": shot[0], "eye": eye, "target": target, "fov": float(shot[3]), "eye_anchor": eye_anchor, "target_anchor": target_anchor}


# Row problems, empty when the table is sound. stage_count is alpha_defs COUNT.
static func problems(stage_count: int) -> Array:
	var out: Array = []
	for n in SUBJECTS:
		var row: Dictionary = SUBJECTS[n]
		for key in ["group", "stage", "kind", "owner", "cameras", "tick"]:
			if not row.has(key):
				out.append("%s lacks %s" % [n, key])
		if not GROUPS.has(row.get("group", "")):
			out.append("%s group %s is not in GROUPS" % [n, row.get("group", "")])
		if not ["actor", "prop", "scene", "ui"].has(row.get("kind", "")):
			out.append("%s kind %s" % [n, row.get("kind", "")])
		var stage := int(row.get("stage", 0))
		if stage < 1 or stage > stage_count:
			out.append("%s stage %d is not an alpha stage (1..%d)" % [n, stage, stage_count])
		if row.has("dead_frame") and String(row.get("dead_reason", "")).is_empty():
			out.append("%s overrides dead_frame without a dead_reason" % n)
		var seen := {}
		for shot in row.get("cameras", []):
			if not (shot is Array) or shot.size() < 4 or shot.size() > 5:
				out.append("%s camera row %s is not [name, eye, target, fov(, anchors)]" % [n, shot])
				continue
			if not (shot[0] is String) or not (shot[1] is Vector3) or not (shot[2] is Vector3) or not (shot[3] is float):
				out.append("%s camera %s types" % [n, shot[0]])
				continue
			if seen.has(shot[0]):
				out.append("%s camera %s twice" % [n, shot[0]])
			seen[shot[0]] = true
			if shot[3] < 20.0 or shot[3] > 100.0:
				out.append("%s camera %s fov %.1f" % [n, shot[0], shot[3]])
			if row["kind"] != "ui" and shot[1] == shot[2] and String(row.get("anchor", "")) == "" and shot.size() == 4:
				out.append("%s camera %s eye equals target" % [n, shot[0]])
		if (row.get("cameras", []) as Array).is_empty():
			out.append("%s has no camera" % n)
		for cam_name in row.get("ball", {}):
			if not seen.has(cam_name) or not (row["ball"][cam_name] is Vector3):
				out.append("%s ball pin %s names no camera or is not a Vector3" % [n, cam_name])
		if row.has("ball") and String(row.get("ball_reason", "")).is_empty():
			out.append("%s pins the ball without a ball_reason" % n)
	return out


# The blind-pair coin: which side shows the baseline. Seeded by the subject and camera
# alone, so a re-run deals the same pairs and nothing else can move it.
static func coin(subject: String, camera: String) -> bool:
	var h := (subject + "/" + camera).sha256_buffer()
	return (h[0] & 1) == 1
