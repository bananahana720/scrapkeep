extends RefCounted

const SourceScan := preload("res://tests/support/source_scan.gd")
const ROW := '^"([a-z0-9_]+)"\\s*:\\s*\\{|"id":\\s*"([a-z0-9_]+)"'

# The row ids inside a shared table's pilot blocks: from a "# --- ... P-C ... ---" opening
# marker to its "# --- end ... ---". Each P-C kit appends its rows there, so a shared count
# or "every row" check holds the shared rows to their pin while each pilot's own tests count
# and open that pilot's rows (2026-10-12, W13 coordinator: every kit merge re-pinned the
# shared counts by hand until then).

static func ids(t, path: String) -> Array:
	var out := []
	var inside := false
	for line in SourceScan.text(t, path).split("\n"):
		var s := line.strip_edges()
		if s.begins_with("# --- end "):
			inside = false
		elif s.begins_with("# --- ") and "P-C" in s:
			inside = true
		elif inside:
			var found := SourceScan.search(t, s, ROW)
			if not found.is_empty():
				var m := found[0]
				var id := m.get_string(1) if m.get_string(1) != "" else m.get_string(2)
				if not id in out:
					out.append(id)
	return out


# The ids a shared check should hold to its pin: every id minus the pilot blocks' ids.
static func shared(t, all_ids: Array, path: String) -> Array:
	var pilot := ids(t, path)
	return all_ids.filter(func(id): return not id in pilot)
