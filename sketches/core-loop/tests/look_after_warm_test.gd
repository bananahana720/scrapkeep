extends SceneTree

# Rule (technicals, 10 November 2026): no new look after the stage warm. For every kind world 1 can
# send, once BakeWarm has stood it (the spawn frame, then glow_warm's frame), a live one of the kind
# draws nothing the warm did not: at rest, mid hit-flash, plated live (amber) and glancing (slate)
# with its cracks shown, and dying at rest, mid-flash and plated. A look is what tools/look_census.gd
# keys (draw class, vertex format, skin, shadow, fade, every material switch): a new one is a render
# pipeline the 4080 builds on that frame. The elite plated brute's lit plates built two at its
# landing (76 to 86 ms, seed 40317 f4344, the #724 read) while the warm stood it only at rest.
# Control: the same kinds stood without glow_warm's copies leave the brute's lit plates new, so the
# test can fail.

const T := preload("res://tests/support/t.gd")
const BakeWarm := preload("res://src/presentation/bake_warm.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const Director := preload("res://src/world/director.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const LookCensus := preload("res://tools/look_census.gd")

var t := T.new("look_after_warm_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var sent := _sent()
	var kits := BakeWarm.WORLD_KITS[1].filter(func(kit): return BakeWarm.kind_of(kit) in sent)
	t.check("every kind world 1 can send is under test", kits.size() == sent.size() and sent.has("plated_brute"), "%d of %d" % [kits.size(), sent.size()])
	for on_screen in [false, true]:
		EnemyMotion.headless_idle = on_screen
		var rig := " on screen" if on_screen else ""
		for kit in kits:
			var kind := BakeWarm.kind_of(kit) + rig
			var census := LookCensus.new()
			await _stand(kit, stage, census, true)
			var news := await _play(kit, stage, census)
			t.check("%s: nothing new in play after the warm" % kind, news.is_empty(), "; ".join(news.slice(0, 4)))
	# The control: without glow_warm's frame (the spawn frame and the death debris only, as before
	# 10 November 2026), the brute's lit plates are a look the warm never drew.
	EnemyMotion.headless_idle = false
	var brute: Script = kits.filter(func(kit): return BakeWarm.kind_of(kit) == "plated_brute")[0]
	var bare := LookCensus.new()
	await _stand(brute, stage, bare, false)
	var missed := await _play(brute, stage, bare)
	t.check("control: stood without glow_warm, the brute's lit plates are new in play", missed.any(func(line: String) -> bool: return line.contains("BrutePlates") and line.contains("emission_enabled=true")), "; ".join(missed.slice(0, 4)))
	stage.free()
	await process_frame
	quit(t.verdict())


# BakeWarm's two frames for one kind, each absorbed by the census as the renderer would see them.
func _stand(kit: Script, stage: Node3D, census, glow: bool) -> void:
	var holder := BakeWarm.spawn_view(kit, stage, null, null)
	await process_frame
	census.absorb(holder)
	if glow:
		BakeWarm.glow_warm(holder)
	else:
		BakeWarm.death_warm(holder)
	census.absorb(holder)
	holder.free()


# A live one of the kind through the states play puts it in; returns each new look as text.
func _play(kit: Script, stage: Node3D, census) -> Array:
	var news := []
	for moment in ["rest", "flash", "amber", "slate", "die_rest", "die_flash", "die_amber"]:
		var holder := BakeWarm.spawn_view(kit, stage, null, null)
		await process_frame
		var enemy: Node3D = holder.get_child(0)
		if moment.ends_with("flash"):
			enemy.flash()
			enemy._update_flash(0.016)
		elif moment.ends_with("amber") or moment == "slate":
			enemy.set_tint("slate" if moment == "slate" else "amber")
		if moment.begins_with("die_"):
			EnemyMotion.scatter(enemy, enemy.kind, Vector3.FORWARD)
		for row in census.scan(holder, 0):
			news.append("%s %s %s" % [moment, row.path, row.key])
		holder.free()
	return news


func _sent() -> Array:
	var out := []
	for row: Dictionary in ParkDefs.DEFS:
		if int(row["world"]) == 1:
			for kind in Director.kinds_sent(row, ParkDefs):
				if not out.has(kind):
					out.append(kind)
	return out
