extends RefCounted

var suite := ""
var checks := 0
var failures := 0


func _init(suite_name: String = "") -> void:
	suite = suite_name


func check(label: String, ok: bool, detail: String = "") -> bool:
	checks += 1
	if not ok:
		failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
	return ok


func eq(label: String, got, want) -> bool:
	return check(label, got == want, "got %s, want %s" % [var_to_str(got), var_to_str(want)])


func near(label: String, got: float, want: float, tolerance: float = 0.0001) -> bool:
	return check(label, absf(got - want) <= tolerance, "got %s, want %s within %s" % [got, want, tolerance])


func verdict() -> int:
	if failures == 0:
		print("%s: PASS (%d checks)" % [suite, checks])
		return 0
	print("%s: FAIL (%d of %d checks)" % [suite, failures, checks])
	return 1
