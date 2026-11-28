extends SceneTree

const Banner := preload("res://src/presentation/codex_banner.gd")
const UiProfile := preload("res://src/ui/ui_profile.gd")
const ScreenRegions := preload("res://src/core/screen_regions.gd")
const Hud := preload("res://src/ui/hud.gd")
const CombatCodex := preload("res://src/combat/codex_entries.gd")
const BossCodex := preload("res://src/boss/codex_entries.gd")

# The first-discovery card is the bigger ceremony: at least twice the flag-off banner's
# height, on the right of the middle view, clear of the top, prompts and bottom bands,
# the HUD toast column and the centre play rect. The banner keeps the
# rect it had at base 39b0f3f (measured there, at 1600x900, line LINE). A long line (the
# Soaked card's, which a player's-eye film caught cut off at "lands as...") shows whole in
# the same card, and holds longer for its extra words. Every codex text fits the card whole.

const DIR := "user://discovery_card_size_test/"
const LINE := "Ram fast and everything ahead of you breaks."
const LONG_LINE := "Spillway crews come out of the channel soaked. Arc does 150% to them and everything else lands as normal."
# Line Drive's text before it was shortened: nine lines on the card, so the fit check can fail.
const OVER_LINE := "Pick 3 and click with a line on a machine: the winch kicks force down the cable and throws it into whatever stands behind. On a wall, the winch hauls you in and nothing can hold you. With no line, the next bite carries it."
const SCREEN := Vector2(1600.0, 900.0)
# Measured at base 39b0f3f.
const BASE_BANNER_SIZE := Vector2(360.0, 121.0)
const BASE_BANNER_REST := Vector2(1222.0, 135.0)

var _failures := 0
var _step := 0
var _settle := 0
var _fake_ms := 50000
var _profile
var _cards
var _off
var _card := Rect2()
var _banner_rect := Rect2()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	DirAccess.remove_absolute(DIR + UiProfile.FILE)
	_profile = UiProfile.new(DIR)
	_cards = _make(true, _profile)
	_off = _make(false, null)


func _make(cards: bool, profile) -> Control:
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
			_fake_ms += 500
			_step = 1
			_settle = 2
		1:
			_card = _cards._panel.get_global_rect()
			_banner_rect = _off._panel.get_global_rect()
			var card_rest: Vector2 = _cards.rest_position()
			var banner_rest: Vector2 = _off.rest_position()
			print("screen %s stretch canvas_items; viewport %s" % [SCREEN, _cards.get_viewport_rect().size])
			_check("both laid out", _card.size.y > 0.0 and _banner_rect.size.y > 0.0, "card h %.1f, banner h %.1f" % [_card.size.y, _banner_rect.size.y])
			_check("card at least twice the banner", _card.size.y >= 2.0 * _banner_rect.size.y, "card %.1f vs 2 x banner %.1f = %.1f" % [_card.size.y, _banner_rect.size.y, 2.0 * _banner_rect.size.y])
			_check("card panel sits at its rest", _card.position.is_equal_approx(card_rest), "panel %s rest %s" % [_card.position, card_rest])
			var toasts := ScreenRegions.rect("toasts", SCREEN)
			var prompts := ScreenRegions.rect("prompts", SCREEN)
			var column_w := minf(Hud.TOAST_WIDTH, SCREEN.x - 2.0 * Hud.MARGIN)
			var column := Rect2((SCREEN.x - column_w) * 0.5, toasts.position.y, column_w, toasts.size.y)
			var centre := Rect2(column.position.x, toasts.end.y, column_w, prompts.position.y - toasts.end.y)
			var forbidden := {
				"top band": ScreenRegions.rect("top", SCREEN),
				"prompts band": prompts,
				"bottom band": ScreenRegions.rect("bottom", SCREEN),
				"HUD toast column": column,
				"centre play rect": centre,
			}
			print("card rect   %s" % _card)
			print("banner rect %s" % _banner_rect)
			for label in forbidden:
				var r: Rect2 = forbidden[label]
				var hit := _card.intersects(r)
				print("  %-17s %s intersects: %s" % [label, r, hit])
				_check("card clear of %s" % label, not hit, "card %s vs %s" % [_card, r])
			_check("reticle inside centre rect, not under card", centre.has_point(SCREEN * 0.5) and not _card.has_point(SCREEN * 0.5), "reticle %s" % (SCREEN * 0.5))
			_check("card on screen", Rect2(Vector2.ZERO, SCREEN).encloses(_card), "card %s in %s" % [_card, SCREEN])
			_check("banner unchanged", _banner_rect.size.is_equal_approx(BASE_BANNER_SIZE) and banner_rest.is_equal_approx(BASE_BANNER_REST), "banner size %s rest %s (base %s, %s)" % [_banner_rect.size, banner_rest, BASE_BANNER_SIZE, BASE_BANNER_REST])
			_cards.dismiss(true)
			_cards.show_discovery("Wrecking Ball", "build", LINE, "Synergy", "wrecking_ball")
			_fake_ms += 200
			_step = 2
			_settle = 2
		2:
			_check("a repeat shows nothing", not _cards.showing() and not _cards.visible and _cards.queued() == 0, "showing %s, visible %s, queued %d" % [_cards.showing(), _cards.visible, _cards.queued()])
			_cards.show_discovery("Soaked", "enemy", LONG_LINE, "New entry", "armour_wet")
			_fake_ms += 500
			_step = 3
			_settle = 2
		3:
			var body: Label = _cards._body
			var long_card: Rect2 = _cards._panel.get_global_rect()
			var short_hold: float = Banner.card_hold(LINE)
			_check("a long line shows whole", _cards.showing() and body.get_line_count() > 4 and body.get_visible_line_count() == body.get_line_count(), "showing %s, %d lines, %d shown" % [_cards.showing(), body.get_line_count(), body.get_visible_line_count()])
			_check("the long card is the same card", long_card.is_equal_approx(_card), "long %s vs %s" % [long_card, _card])
			_check("a short line holds as before", is_equal_approx(short_hold, Banner.CARD_HOLD), "%.2f s vs %.2f" % [short_hold, Banner.CARD_HOLD])
			_check("the long line holds longer, under the cap", _cards._hold > short_hold and _cards._hold <= Banner.CARD_HOLD_MAX and is_equal_approx(_cards._hold, Banner.card_hold(LONG_LINE)), "%.2f s (short %.2f, cap %.2f)" % [_cards._hold, short_hold, Banner.CARD_HOLD_MAX])
			_check("no line holds past the cap", is_equal_approx(Banner.card_hold(LONG_LINE + " " + LONG_LINE + " " + LONG_LINE), Banner.CARD_HOLD_MAX), "%.2f s" % Banner.card_hold(LONG_LINE + " " + LONG_LINE + " " + LONG_LINE))
			# Every codex text is written to fit the card whole, so none is cut with an ellipsis.
			var over := []
			var entries: Array = CombatCodex.ENTRIES + BossCodex.ENTRIES + BossCodex.WAKING + BossCodex.MIND
			for entry in entries:
				body.text = entry["text"]
				if body.get_line_count() > Banner.CARD_LINES:
					over.append(entry["id"])
			body.text = OVER_LINE
			_check("every codex text fits the card whole", over.is_empty() and entries.size() > 80 and body.get_line_count() > Banner.CARD_LINES,
				"%d texts, over %d lines: %s; the old Line Drive text counts %d" % [entries.size(), Banner.CARD_LINES, over, body.get_line_count()])
			DirAccess.remove_absolute(DIR + UiProfile.FILE)
			DirAccess.remove_absolute(DIR)
			print("discovery_card_size_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			quit(0 if _failures == 0 else 1)
			return true
	return false


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
