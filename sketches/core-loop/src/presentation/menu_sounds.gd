extends RefCounted

const NAV := ["ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev"]
const WASD := [KEY_W, KEY_A, KEY_S, KEY_D]

var _moves := 0
var _had_focus := false
var _nav_was := false
var _accept_was := false
var _cancel_was := false
var _fresh_was := false
var _refused := false
var _nav_noted := false


func focus_moved() -> void:
	_moves += 1


func nav_noted() -> void:
	_nav_noted = true


func refused() -> void:
	_refused = true


func step(nav: bool, accept: bool, cancel: bool, has_focus: bool) -> Array:
	var out: Array = []
	if accept and not _accept_was and _had_focus and not _refused:
		out.append("menu_confirm")
	if cancel and not _cancel_was and _had_focus:
		out.append("menu_back")
	var moved_nav := nav or _nav_noted
	var fresh := moved_nav and not _nav_was
	if _moves > 0 and (moved_nav or _nav_was) and (_had_focus or fresh or _fresh_was):
		out.append("menu_move")
	_moves = 0
	_refused = false
	_nav_noted = false
	_fresh_was = fresh
	_nav_was = nav
	_accept_was = accept
	_cancel_was = cancel
	_had_focus = has_focus
	return out
