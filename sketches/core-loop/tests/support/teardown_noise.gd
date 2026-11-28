extends RefCounted

# The two lines the macOS headless engine prints at shutdown on runs that end clean on Linux: dummy-renderer RID leaks
# and resources still in use at exit. Only macOS skips them; on Linux an exit-leak line has named real faults and counts. The same rule as TEARDOWN_NOISE in
# scripts/sketch-smoke.mjs, for a test that reads a child Godot's output itself. Any other ERROR line still counts.

const PATTERN := "^ERROR: \\d+ (?:RID allocations of type '\\w*RendererDummy\\w*' were leaked|resources still in use) at exit\\b"

static var _line: RegEx = RegEx.create_from_string(PATTERN)


static func reset_for_tests() -> void:
	_line = null


static func is_noise(line: String) -> bool:
	if _line == null:
		_line = RegEx.create_from_string(PATTERN)
	return OS.get_name() == "macOS" and _line.search(line.strip_edges(false, true)) != null


# text without its teardown-noise lines.
static func strip(text: String) -> String:
	return "\n".join(Array(text.split("\n")).filter(func(line: String) -> bool: return not is_noise(line)))
