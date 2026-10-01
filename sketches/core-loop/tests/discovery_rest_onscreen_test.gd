extends SceneTree

const Banner := preload("res://src/presentation/codex_banner.gd")

# Every card and every repeat pop must rest fully on screen, at each supported size, whether
# it comes first, after a card or after another pop.

const LINE := "Ram fast and everything ahead of you breaks."
const SIZES := [Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(1280, 720)]

var _failures := 0


func _check(label: String, ok: bool, detail: String) -> void:
	if ok:
		print("ok   %s" % label)
	else:
		_failures += 1
		print("FAIL %s: %s" % [label, detail])


func _rest(banner) -> Rect2:
	banner._place(1.0)
	return Rect2(banner._panel.position, banner._panel.size)


func _on_screen(rect: Rect2, size: Vector2i) -> bool:
	return rect.position.x >= 0.0 and rect.position.y >= 0.0 and rect.end.x <= size.x and rect.end.y <= size.y


func _initialize() -> void:
	for size in SIZES:
		var view := SubViewport.new()
		view.size = size
		root.add_child(view)
		await process_frame
		var banner = Banner.new()
		banner.cards = true
		view.add_child(banner)
		var seen := banner.get_viewport_rect().size
		_check("viewport %s" % size, Vector2i(seen) == size, "viewport reads %s" % seen)
		banner.show_discovery("Wrecking Ball", "build", LINE, "New synergy", "wb")
		await process_frame
		await process_frame
		var card := _rest(banner)
		_check("%s card on screen" % size, banner.last_style == "card" and _on_screen(card, size), "%s rect %s" % [banner.last_style, card])
		banner.dismiss(false)
		banner.show_discovery("Wrecking Ball", "build", LINE, "Synergy", "wb")
		await process_frame
		await process_frame
		var pop := _rest(banner)
		_check("%s pop after card on screen" % size, banner.last_style == "pop" and _on_screen(pop, size), "%s rect %s" % [banner.last_style, pop])
		banner.dismiss(false)
		banner.show_discovery("Wrecking Ball", "build", LINE, "Synergy", "wb")
		await process_frame
		await process_frame
		var again := _rest(banner)
		_check("%s pop after pop on screen" % size, banner.last_style == "pop" and _on_screen(again, size), "%s rect %s" % [banner.last_style, again])
		view.free()
	print("discovery_rest_onscreen_test: %s" % ["FAIL" if _failures > 0 else "PASS"])
	quit(1 if _failures > 0 else 0)
