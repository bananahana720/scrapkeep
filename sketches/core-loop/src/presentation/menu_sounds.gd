extends RefCounted

# The sounds of moving through a menu with a pad or the keys, for every page at once: no page asks
# for them. audio.gd feeds it the viewport's focus changes and, each frame, which ui actions are
# held and whether a control holds focus.
#   move     focus changed while a direction (or tab) is held, so opening a page, which grabs focus
#            in code, and a mouse click stay quiet
#   confirm  ui_accept went down while a control held focus the frame before, so a pad A in play,
#            where nothing is focused, stays a game input and a page that closes on the press still counts
#   back     the same for ui_cancel
# Each plays at most once a frame. A held direction repeats the move with the focus; mix_rows.gd
# gives it a minimum gap.

const NAV := ["ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev"]

var _moves := 0
var _had_focus := false
var _nav_was := false
var _accept_was := false
var _cancel_was := false


func focus_moved() -> void:
	_moves += 1


# The menu sounds, as event kinds, for this frame. has_focus is read after the frame's input ran.
func step(nav: bool, accept: bool, cancel: bool, has_focus: bool) -> Array:
	var out: Array = []
	if accept and not _accept_was and _had_focus:
		out.append("menu_confirm")
	if cancel and not _cancel_was and _had_focus:
		out.append("menu_back")
	if _moves > 0 and (nav or _nav_was):
		out.append("menu_move")
	_moves = 0
	_nav_was = nav
	_accept_was = accept
	_cancel_was = cancel
	_had_focus = has_focus
	return out
