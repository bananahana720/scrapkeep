extends SceneTree

const Harmony := preload("res://src/presentation/harmony.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Board := preload("res://tools/audio_board.gd")


const DEFAULT_OUT := "../../artifacts/local/au2"
const GAP_SECONDS := 0.4

const CUES := [
	"bet_roll", "bet_clunk", "bet_crack", "bet_refusal",
	"sunken_bell", "ally_hum_sable", "ally_hum_rivet", "ally_hum_kest", "ally_wake",
	"fight_arm_stamp", "near_miss_whip_sable", "near_miss_whip_rivet", "near_miss_whip_kest",
	"kill_chain_tier", "drop_landing", "door_tick", "return_launch_arpeggio",
	"lift_hiss", "crater_hold",
]


static func _take(id: String) -> Board.Take:
	var take := Board.Take.new()
	var buf := SfxBank.samples(id)
	take.add(buf, 0, 1.0)
	take.finish(buf.size())
	return take


func _initialize() -> void:
	var out := ProjectSettings.globalize_path("res://").path_join(DEFAULT_OUT).simplify_path()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	var gap := int(GAP_SECONDS * Harmony.RATE)
	var reel := Board.Take.new()
	var at := 0
	var failed := 0
	for id in CUES:
		var take := _take(id)
		var stats := Board.master(take)
		var name := "%s.wav" % id
		var err := Board.to_wav(take).save_to_wav(out.path_join(name))
		if err != OK:
			failed += 1
		print("%-24s %5.2f s  %6.1f LUFS  peak %5.1f dBFS  limiter %4.1f dB  %s" % [id, stats["seconds"], stats["lufs"],
			stats["peak_db"], stats["limit_db"], "written" if err == OK else "FAILED %d" % err])
		reel.add(take.left, at, 1.0)
		at += take.left.size() + gap
	reel.finish(at)
	var reel_stats := Board.master(reel)
	var reel_err := Board.to_wav(reel).save_to_wav(out.path_join("au2-board.wav"))
	if reel_err != OK:
		failed += 1
	print("au2-board.wav          %5.2f s  %6.1f LUFS  peak %5.1f dBFS  limiter %4.1f dB  %s" % [reel_stats["seconds"],
		reel_stats["lufs"], reel_stats["peak_db"], reel_stats["limit_db"], "written" if reel_err == OK else "FAILED %d" % reel_err])
	print("au2_board: %s to %s" % ["done" if failed == 0 else "FAIL (%d)" % failed, out])
	quit(0 if failed == 0 else 1)
