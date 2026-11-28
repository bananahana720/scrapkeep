extends SceneTree

const Game := preload("res://src/game.gd")
const UiProfile := preload("res://src/ui/ui_profile.gd")

var _t := preload("res://tests/support/t.gd").new("ui_profile_one_owner_test")
var _game


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	for i in 3:
		await process_frame
	var banner = _game.presentation.banner
	_t.check("the discovery banner is in card mode", banner.cards, "")
	banner.show_discovery("One owner", "build", "", "New synergy", "one_owner_shown")
	banner.dismiss(true)
	var owned = _game.ctx.get("ui_profile")
	var hud_profile = _game.hud.profile
	var banner_profile = banner.profile
	_t.check("the game holds one ui profile", owned is UiProfile, str(owned))
	_t.check("the hud reads the game's profile", owned != null and is_same(hud_profile, owned), "hud %s, game %s" % [hud_profile, owned])
	_t.check("the banner reads the game's profile", owned != null and is_same(banner_profile, owned), "banner %s, game %s" % [banner_profile, owned])
	_t.check("the hud and the banner hold the same profile", hud_profile != null and is_same(hud_profile, banner_profile), "hud %s, banner %s" % [hud_profile, banner_profile])
	if hud_profile != null and banner_profile != null:
		hud_profile.glyph_uses["one_owner_probe"] = 7
		_t.eq("a use set through the hud reads through the banner without a save", banner_profile.uses("one_owner_probe"), 7)
		banner_profile.discoveries_seen.append("one_owner_card")
		_t.check("a card marked through the banner reads through the hud without a save", hud_profile.discovered("one_owner_card"), "")
		var on_disk := UiProfile.new(_game.storage_dir)
		_t.check("neither mark reached the disk", on_disk.uses("one_owner_probe") == 0 and not on_disk.discovered("one_owner_card"),
			"disk uses %d, card %s" % [on_disk.uses("one_owner_probe"), on_disk.discovered("one_owner_card")])
	_game.free()
	quit(_t.verdict())
