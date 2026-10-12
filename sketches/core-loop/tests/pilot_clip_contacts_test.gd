extends SceneTree

const Hero := preload("res://src/presentation/hero_assets.gd")
const T := preload("res://tests/support/t.gd")
class CapturedHero extends Hero:
	var lines: Array = []
	func _warn_once(key: String, text: String) -> void:
		lines.append(text)
		super._warn_once(key, text)

var t := T.new("pilot_clip_contacts_test")

func _initialize() -> void:
	var hero := CapturedHero.new()
	var animator := AnimationPlayer.new()
	var library := AnimationLibrary.new()
	for clip in ["cast_special", "cast_line"]:
		var animation := Animation.new()
		animation.length = 0.5
		library.add_animation(clip, animation)
	animator.add_animation_library("", library)
	for pilot_class in Hero.PILOTS:
		var pilot := String(Hero.PILOTS[pilot_class]).get_file().trim_prefix("pilot_").trim_suffix("_anim.glb")
		var table: Dictionary = hero._pilot_table(pilot_class)
		for clip in ["cast_special", "cast_line"]:
			var contact: Dictionary = table.get("clips", {}).get(clip, {}).get("contact", {})
			var got: Dictionary = hero._contact_of({"class": pilot_class, "animator": animator}, clip)
			if contact.has("frame"):
				t.near("%s %s authored contact" % [pilot, clip], got.seconds, (float(contact.frame) - 1.0) / 30.0)
				t.eq("%s %s control" % [pilot, clip], got.control, contact.control)
			else:
				t.near("%s %s fallback" % [pilot, clip], got.seconds, 0.2)
				print("CONTACT_FALLBACK pilot=%s clip=%s table=%s" % [pilot, clip, "absent" if table.is_empty() else "no contact"])
	var rivet := hero._contact_of({"class": "runner_gunner", "animator": animator}, "cast_line")
	t.near("Rivet frame 6 rather than fallback frame 7", rivet.seconds * 30.0 + 1.0, 6.0)
	t.check("Rivet cast_line never warned", not hero._warned.has("contact:runner_gunner:cast_line"))
	# A malformed contact also takes the bounded fallback, and reports pilot, clip and table.
	hero._pilot_tables["runner_gunner"] = {"clips": {"cast_line": {"contact": {"frame": 6}}}}
	hero._contact_of({"class": "runner_gunner", "animator": animator}, "cast_line")
	var warning: String = hero.lines.back()
	t.check("fallback warning names pilot", "pilot rivet" in warning)
	t.check("fallback warning names clip", "cast_line" in warning)
	t.check("fallback warning names table", "src/presentation/clips/rivet.json" in warning)
	t.check("fallback warning states time", "0.200" in warning)
	# 2026-10-12 (W13 coordinator): 23 -> 25. Rivet and Tally ship tables (two more checks each);
	# Sable's eleven new clips are held out under the clip stop rule, so her two clips fall back.
	t.eq("stated check count", t.checks + 1, 25)
	hero.free()
	animator.free()
	quit(t.verdict())
