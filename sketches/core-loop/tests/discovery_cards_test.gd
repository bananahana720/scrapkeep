extends SceneTree

const Banner := preload("res://src/presentation/codex_banner.gd")
const UiProfile := preload("res://src/ui/ui_profile.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const WordBudget := preload("res://src/core/word_budget.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# --discovery=cards: the first time an id is discovered a picture card shows (a larger
# panel, a looping glyph in the EventKinds shape and colour, name and one line) and
# the id is recorded in the profile's discoveries_seen; the same id again shows nothing. The record survives a save and reload. Any input
# dismisses a card at once; Engine.time_scale and the pause state never change while
# one shows; the card sits in the toasts band inside the calm-screen word budget. With
# the flag off the banner is the old banner and the profile is untouched.

const DIR := "user://discovery_cards_test/"
const LINE := "Ram fast and everything ahead of you breaks."

var _failures := 0
var _step := 0
var _settle := 0
var _fake_ms := 50000
var _profile
var _cards
var _off
var _scale_before := 1.0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	DirAccess.remove_absolute(DIR + UiProfile.FILE)
	_profile = UiProfile.new(DIR)
	_cards = _banner(true, _profile)
	_off = _banner(false, null)
	_scale_before = Engine.time_scale


func _flag(args: Array) -> String:
	var tuning := Tuning.new()
	tuning.apply_args(PackedStringArray(args), "launch")
	return tuning.option(Tuning.DISCOVERY_KEY)


func _banner(cards: bool, profile) -> Control:
	var banner = Banner.new()
	banner.now_ms = func() -> int: return _fake_ms
	banner.cards = cards
	banner.profile = profile
	root.add_child(banner)
	return banner


func _process(_delta: float) -> bool:
	if _settle > 0:
		_settle -= 1
		return false
	match _step:
		0:
			_cards.show_discovery("Wrecking Ball", "build", LINE, "New synergy", "wrecking_ball")
			_off.show_discovery("Wrecking Ball", "build", LINE, "New synergy", "wrecking_ball")
			_check("first shows card", _cards.showing() and _cards.last_style == "card" and _cards.cards_shown == 1, "first discovery style '%s'" % _cards.last_style)
			_check("first recorded", _profile.discovered("wrecking_ball") and "wrecking_ball" in _profile.discoveries_seen, "discoveries_seen %s" % [_profile.discoveries_seen])
			_fake_ms += 500
			_step = 1
			_settle = 2
		1:
			var card: Rect2 = _cards._panel.get_global_rect()
			var banner_rect: Rect2 = _off._panel.get_global_rect()
			var band := ScreenRegions.rect("toasts", _cards.get_viewport_rect().size)
			_check("card larger than banner", card.size.y > banner_rect.size.y and card.size.x >= banner_rect.size.x and _cards._glyph.size.x > _off._icon.size.x * 2.0 and _cards._glyph.visible and not _cards._icon.visible, "card %s (glyph %s) vs banner %s (icon %s); the toast band caps width at 360 and height at 126" % [card.size, _cards._glyph.size, banner_rect.size, _off._icon.size])
			var centre := Rect2(400.0, band.end.y, 800.0, ScreenRegions.rect("prompts", _cards.get_viewport_rect().size).position.y - band.end.y)
			var clear := not card.intersects(centre) and not card.intersects(band) and not card.intersects(ScreenRegions.rect("top", _cards.get_viewport_rect().size)) and not card.intersects(ScreenRegions.rect("prompts", _cards.get_viewport_rect().size)) and Rect2(Vector2.ZERO, _cards.get_viewport_rect().size).encloses(card)
			_check("card clear of play area and bands", clear, "card %s clear of toasts %s and centre %s (full clearances in discovery_card_size_test)" % [card, band, centre])
			var words: int = WordBudget.count(_cards)["hud"]
			_check("card inside word budget", words > 0 and words <= 40, "%d words on the card (budget 40)" % words)
			var row := EventKinds.row("synergy_discovered")
			_check("glyph from EventKinds", _cards._glyph_shape == row["shape"] and _cards._glyph_color == row["color"], "glyph %s in %s" % [_cards._glyph_shape, _cards._glyph_color.to_html()])
			_check("off is banner", _off.last_style == "banner" and _off._icon.visible and not _off._glyph.visible, "flag off style '%s'" % _off.last_style)
			_check("time untouched while card", Engine.time_scale == _scale_before and not paused, "time_scale %s paused %s" % [Engine.time_scale, paused])
			_check("card holds past banner time", _cards.showing(), "still up 0.5 s in")
			_fake_ms += 3300
			_step = 2
			_settle = 2
		2:
			_check("card outlasts 3.3 s", _cards.showing(), "a card holds longer than the banner's 3 s")
			_check("time untouched late", Engine.time_scale == _scale_before and not paused, "time_scale %s paused %s" % [Engine.time_scale, paused])
			# Input dismisses: a release and an echo do not; a press does, unconsumed.
			var release := InputEventKey.new()
			release.keycode = KEY_SPACE
			release.pressed = false
			var echo := InputEventKey.new()
			echo.keycode = KEY_SPACE
			echo.pressed = true
			echo.echo = true
			_cards._input(release)
			_cards._input(echo)
			var stays: bool = _cards.showing()
			var press := InputEventKey.new()
			press.keycode = KEY_SPACE
			press.pressed = true
			_cards._input(press)
			_check("key dismisses", stays and not _cards.showing() and not _cards.visible, "release and echo kept it (%s); a key press cleared it" % stays)
			var results := []
			var kinds := [InputEventMouseButton.new(), InputEventJoypadButton.new()]
			for ev in kinds:
				ev.pressed = true
				_cards.cards = true
				_cards.show_discovery("Boarding Party", "build", LINE, "New synergy", "boarding_party_%d" % results.size())
				var was: bool = _cards.showing()
				_cards._input(ev)
				results.append(was and not _cards.showing())
			_check("mouse and pad dismiss", results == [true, true], "mouse %s, pad %s" % [results[0], results[1]])
			_check("time untouched on dismiss", Engine.time_scale == _scale_before and not paused, "time_scale %s paused %s" % [Engine.time_scale, paused])
			# Repeat: nothing.
			var cards_before: int = _cards.cards_shown
			_cards.show_discovery("Wrecking Ball", "build", LINE, "Synergy", "wrecking_ball")
			_check("repeat shows nothing", not _cards.showing() and _cards.queued() == 0 and _cards.cards_shown == cards_before, "showing %s, queued %d, cards %d" % [_cards.showing(), _cards.queued(), _cards.cards_shown])
			_fake_ms += 200
			_step = 3
			_settle = 2
		3:
			# Persistence: reload the profile, a new banner treats the id as seen.
			var text := FileAccess.get_file_as_string(DIR + UiProfile.FILE)
			var reloaded = UiProfile.new(DIR)
			_check("seen survives reload", reloaded.discovered("wrecking_ball") and "discoveries_seen" in text, "reloaded discoveries_seen %s" % [reloaded.discoveries_seen])
			var fresh = _banner(true, reloaded)
			fresh.show_discovery("Wrecking Ball", "build", LINE, "Synergy", "wrecking_ball")
			var old_is_nothing: bool = not fresh.showing() and fresh.cards_shown == 0
			fresh.dismiss()
			fresh.show_discovery("Magnet Well", "build", LINE, "New synergy", "magnet_well")
			_check("reloaded: old shows nothing, new cards", old_is_nothing and fresh.last_style == "card", "old shows nothing %s, new '%s'" % [old_is_nothing, fresh.last_style])
			_check("flag off leaves profile", _off.profile == null and not _profile.discovered("nothing") and _profile.discoveries_seen == ["wrecking_ball", "boarding_party_0", "boarding_party_1"], "profile %s" % [_profile.discoveries_seen])
			_check("flag parsed", _flag(["--music=ace", "--discovery=cards"]) == "cards" and _flag(["--discovery=banner"]) == "banner" and _flag([]) == "cards", "cards/banner/absent -> cards/banner/cards")
			# Queued behind a card and dropped: not recorded, so its card still comes.
			var dropped = _banner(true, reloaded)
			dropped.show_discovery("Front", "build", LINE, "New synergy", "front_card")
			dropped.show_discovery("Behind", "build", LINE, "New synergy", "behind_card")
			var queued: int = dropped.queued()
			var recorded_early: bool = reloaded.discovered("behind_card")
			dropped.dismiss(true)
			_check("queued then dropped stays unseen", queued == 1 and not recorded_early and not reloaded.discovered("behind_card") and reloaded.discovered("front_card"), "queued %d, behind recorded early %s, after drop %s" % [queued, recorded_early, reloaded.discovered("behind_card")])
			dropped.show_discovery("Behind", "build", LINE, "New synergy", "behind_card")
			_check("dropped one gets its card later", dropped.last_style == "card" and reloaded.discovered("behind_card"), "style '%s'" % dropped.last_style)
			# The same id twice before the first is gone: one card, no second.
			var twice = _banner(true, reloaded)
			twice.show_discovery("A", "build", LINE, "New synergy", "twice_id")
			twice.show_discovery("A", "build", LINE, "New synergy", "twice_id")
			var queued_twice: int = twice.queued()
			twice.dismiss(false)
			twice._next()
			_check("same id twice: one card", twice.cards_shown == 1 and queued_twice == 0 and not twice.showing(), "cards %d, queued behind %d" % [twice.cards_shown, queued_twice])
			# Two owners of one profile file keep each other's records.
			var other = UiProfile.new(DIR)
			other.mark_seen("callout_x")
			reloaded.mark_discovered("late_id")
			var merged = UiProfile.new(DIR)
			_check("profiles merge on save", merged.seen("callout_x") and merged.discovered("late_id") and merged.discovered("front_card"), "callouts %s discoveries %s" % [merged.callouts_seen, merged.discoveries_seen])
			DirAccess.remove_absolute(DIR + UiProfile.FILE)
			DirAccess.remove_absolute(DIR)
			print("discovery_cards_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			quit(0 if _failures == 0 else 1)
			return true
	return false


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
