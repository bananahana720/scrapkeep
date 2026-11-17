extends RefCounted

var suite := ""
var checks := 0
var failures := 0
var skips := 0


func _init(suite_name: String = "") -> void:
	suite = suite_name


func check(label: String, ok: bool, detail: String = "") -> bool:
	checks += 1
	if not ok:
		failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
	return ok


# A check this run could not make (a gitignored asset, a device). It prints a SKIP line and
# the verdict counts it, so a pass with skips never reads as a full pass.
func skip(label: String, reason: String) -> void:
	skips += 1
	print("SKIP %s (%s)" % [label, reason])


func eq(label: String, got, want) -> bool:
	return check(label, got == want, "got %s, want %s" % [shown(got), shown(want)])


# var_to_str() writes an Object with every stored property, recursing into the objects those
# properties hold. On a live game node that walk fans out across the scene graph until Godot
# 4.7.2 segfaults inside its variant writer (SIGABRT core dumps from headless tests). A value
# that holds an Object prints with str(), which names each object without walking it.
func shown(value) -> String:
	if _holds_object(value, 0):
		return str(value)
	return var_to_str(value)


func _holds_object(value, depth: int) -> bool:
	if depth > 64:
		return true
	match typeof(value):
		TYPE_OBJECT:
			return true
		TYPE_ARRAY:
			for item in value:
				if _holds_object(item, depth + 1):
					return true
		TYPE_DICTIONARY:
			for key in value:
				if _holds_object(key, depth + 1) or _holds_object(value[key], depth + 1):
					return true
	return false


func near(label: String, got: float, want: float, tolerance: float = 0.0001) -> bool:
	return check(label, absf(got - want) <= tolerance, "got %s, want %s within %s" % [got, want, tolerance])


func verdict() -> int:
	if failures == 0:
		print("%s: PASS (%d checks%s)" % [suite, checks, ", %d skipped" % skips if skips > 0 else ""])
		return 0
	print("%s: FAIL (%d of %d checks%s)" % [suite, failures, checks, ", %d skipped" % skips if skips > 0 else ""])
	return 1
