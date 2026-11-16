extends RefCounted

# The sounds of moving through a menu with a pad or the keys, for every page at once: no page asks
# for them. audio.gd feeds it the viewport's focus changes and, each frame, which ui actions are
# held and whether a control holds focus.
#   move     focus changed while a direction (or tab) is held, and either a control already held focus
#            or the direction went down this frame or last (a d-pad press that takes focus from nothing).
#            So opening a page, which grabs focus in code, stays quiet even while the stick is still held
#            from play, and a mouse click stays quiet
#   confirm  ui_accept went down while a control held focus the frame before, so a pad A in play,
#            where nothing is focused, stays a game input and a page that closes on the press still counts
#   back     the same for ui_cancel
# A press the page refused (a *_refused fact, Moss's grumble at an unaffordable buy) plays its own no,
# so that frame's confirm is dropped: one press, one voice.
# Each plays at most once a frame. A held direction repeats the move with the focus; mix_rows.gd
# gives it a minimum gap.

const NAV := ["ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev"]

var _moves := 0
var _had_focus := false
var _nav_was := false
var _accept_was := false
var _cancel_was := false
var _fresh_was := false
var _refused := false


func focus_moved() -> void:
	_moves += 1


# A refusal sounded this frame (audio.gd play of a *_refused fact).
func refused() -> void:
	_refused = true


# The menu sounds, as event kinds, for this frame. has_focus is read after the frame's input ran.
func step(nav: bool, accept: bool, cancel: bool, has_focus: bool) -> Array:
	var out: Array = []
	if accept and not _accept_was and _had_focus and not _refused:
		out.append("menu_confirm")
	if cancel and not _cancel_was and _had_focus:
		out.append("menu_back")
	var fresh := nav and not _nav_was
	if _moves > 0 and (nav or _nav_was) and (_had_focus or fresh or _fresh_was):
		out.append("menu_move")
	_moves = 0
	_refused = false
	_fresh_was = fresh
	_nav_was = nav
	_accept_was = accept
	_cancel_was = cancel
	_had_focus = has_focus
	return out
