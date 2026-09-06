extends SceneTree

# Headless --script runs have no editor class cache, so class_name is not resolvable across files.
# An untyped preload constant carries the script class; a ": GDScript" annotation would hide its statics.
const SlotTreeDefinition = preload("res://proofs/tadr-003/definitions/slot_tree_definition.gd")
const ProofCatalogue = preload("res://proofs/tadr-003/definitions/catalogue.gd")
const TreeRules = preload("res://proofs/tadr-003/definitions/tree_rules.gd")

const FIXTURE_DIR: String = "res://proofs/tadr-003/fixtures"
const PLACEHOLDER_PATH: String = FIXTURE_DIR + "/placeholder_tree.tres"
const RENAMED_PATH: String = FIXTURE_DIR + "/renamed_copy/placeholder_tree_other_name.tres"
const MALFORMED_PATH: String = FIXTURE_DIR + "/candidate_bad/malformed_tree.tres"
const ROUNDTRIP_PATH: String = "user://s0-05-roundtrip.tres"
const PLACEHOLDER_ID: StringName = &"proof.tree.placeholder"
const MALFORMED_ID: StringName = &"proof.tree.malformed"
const FAULT_FLAG: String = "--inject-fault"

const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1
const EXIT_HARNESS: int = 3

var _inject_fault: bool = false
var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_inject_fault = OS.get_cmdline_user_args().has(FAULT_FLAG)
	var code: int = run()
	var summary: Dictionary = {
		"proof": "tadr-003",
		"engine": version_token(),
		"inject_fault": _inject_fault,
		"cases": _passed + _failed,
		"passed": _passed,
		"failed": _failed,
		"exit": code,
	}
	print(JSON.stringify(summary))
	quit(code)


func version_token() -> String:
	var info: Dictionary = Engine.get_version_info()
	var major: int = info["major"]
	var minor: int = info["minor"]
	var patch: int = info["patch"]
	var status: String = info["status"]
	var build: String = info["build"]
	var full_hash: String = info["hash"]
	return "%d.%d.%d.%s.%s.%s" % [major, minor, patch, status, build, full_hash.substr(0, 9)]


func run() -> int:
	var placeholder: SlotTreeDefinition = load_fixture(PLACEHOLDER_PATH)
	var renamed: SlotTreeDefinition = load_fixture(RENAMED_PATH)
	var malformed: SlotTreeDefinition = load_fixture(MALFORMED_PATH)
	if placeholder == null or renamed == null or malformed == null:
		return EXIT_HARNESS
	var catalogue: ProofCatalogue = ProofCatalogue.new()
	case_roundtrip(placeholder)
	case_identity(catalogue, placeholder, renamed)
	case_immutability(catalogue)
	case_prefix(catalogue)
	case_rule_accepts(placeholder)
	case_rule_rejects(placeholder, malformed)
	case_failed_reload(catalogue, placeholder, malformed)
	case_admission_exit(catalogue)
	return EXIT_FAIL if _failed > 0 else EXIT_PASS


func load_fixture(path: String) -> SlotTreeDefinition:
	var loaded: SlotTreeDefinition = ResourceLoader.load(path) as SlotTreeDefinition
	if loaded == null:
		print("HARNESS_ERROR fixture did not load as SlotTreeDefinition: %s" % path)
	return loaded


func check(card: String, case_name: String, ok: bool, detail: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("%s %s %s %s" % [card, case_name, "PASS" if ok else "FAIL", detail])


func expected_nodes() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for index: int in range(TreeRules.NODE_COUNT):
		out.append("n%d" % index)
	return out


func expected_edges() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for parent: int in range(TreeRules.NODE_COUNT - TreeRules.ENDPOINT_COUNT):
		out.append("n%d>n%d" % [parent, 2 * parent + 1])
		out.append("n%d>n%d" % [parent, 2 * parent + 2])
	return out


func matches_authored(def: SlotTreeDefinition) -> bool:
	return def.id == PLACEHOLDER_ID and def.content_revision == 0 and def.nodes == expected_nodes() and def.edges == expected_edges()


func case_roundtrip(placeholder: SlotTreeDefinition) -> void:
	var authored_ok: bool = matches_authored(placeholder)
	var save_error: Error = ResourceSaver.save(placeholder, ROUNDTRIP_PATH)
	var path_kept: bool = placeholder.resource_path == PLACEHOLDER_PATH
	var file: FileAccess = FileAccess.open(ROUNDTRIP_PATH, FileAccess.READ)
	var is_text: bool = file != null and file.get_as_text().begins_with("[gd_resource")
	var reloaded: SlotTreeDefinition = ResourceLoader.load(ROUNDTRIP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SlotTreeDefinition
	var reload_ok: bool = reloaded != null and reloaded != placeholder and matches_authored(reloaded)
	var ok: bool = authored_ok and save_error == OK and path_kept and is_text and reload_ok
	check("S0-05", "roundtrip", ok, "authored_fields=%s save_error=%d source_path_kept=%s saved_is_text=%s reloaded_equal=%s temp=%s" % [authored_ok, save_error, path_kept, is_text, reload_ok, ProjectSettings.globalize_path(ROUNDTRIP_PATH)])


func case_identity(catalogue: ProofCatalogue, placeholder: SlotTreeDefinition, renamed: SlotTreeDefinition) -> void:
	var distinct_files: bool = renamed != placeholder and renamed.resource_path != placeholder.resource_path and renamed.id == placeholder.id
	var first: Error = catalogue.register(placeholder)
	var second: Error = catalogue.register(renamed)
	var diagnostic: String = catalogue.diagnostics[0] if not catalogue.diagnostics.is_empty() else ""
	var names_id: bool = diagnostic.contains(String(PLACEHOLDER_ID)) and diagnostic.contains(renamed.resource_path)
	var resolved_first: bool = catalogue.resolve(PLACEHOLDER_ID) == placeholder
	var ok: bool = distinct_files and first == OK and second == ERR_ALREADY_EXISTS and names_id and resolved_first
	check("S0-05", "identity", ok, "distinct_files=%s first=%d second=%d expected_second=%d diagnostic_names_id=%s resolve_returns_first=%s" % [distinct_files, first, second, ERR_ALREADY_EXISTS, names_id, resolved_first])


func case_immutability(catalogue: ProofCatalogue) -> void:
	var cached: SlotTreeDefinition = catalogue.resolve(PLACEHOLDER_ID)
	var record: SlotTreeDefinition = cached.duplicate(true) as SlotTreeDefinition
	record.nodes[0] = "session"
	record.edges.append("session>edge")
	record.content_revision = 99
	var record_changed: bool = record.nodes[0] == "session" and record.edges.size() == TreeRules.EDGE_COUNT + 1 and record.content_revision == 99
	var cached_unchanged: bool = matches_authored(cached) and catalogue.resolve(PLACEHOLDER_ID) == cached
	var same_path: SlotTreeDefinition = ResourceLoader.load(PLACEHOLDER_PATH) as SlotTreeDefinition
	var cached_reload_unchanged: bool = same_path == cached and matches_authored(same_path)
	var fresh: SlotTreeDefinition = ResourceLoader.load(PLACEHOLDER_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SlotTreeDefinition
	var disk_unchanged: bool = fresh != cached and matches_authored(fresh)
	var shallow: SlotTreeDefinition = fresh.duplicate() as SlotTreeDefinition
	shallow.nodes[0] = "shared"
	var shallow_shares: bool = fresh.nodes[0] == "shared"
	var ok: bool = record_changed and cached_unchanged and cached_reload_unchanged and disk_unchanged
	check("S0-05", "immutability", ok, "deep_record_mutated=%s cached_definition_unchanged=%s cached_reload_unchanged=%s fresh_reload_unchanged=%s shallow_duplicate_shares_packed_arrays=%s" % [record_changed, cached_unchanged, cached_reload_unchanged, disk_unchanged, shallow_shares])


func case_prefix(catalogue: ProofCatalogue) -> void:
	var unprefixed: SlotTreeDefinition = SlotTreeDefinition.new()
	unprefixed.id = &"tree.unprefixed"
	unprefixed.nodes = expected_nodes()
	unprefixed.edges = expected_edges()
	var result: Error = catalogue.register(unprefixed)
	var diagnostic: String = catalogue.diagnostics[0] if not catalogue.diagnostics.is_empty() else ""
	var names_check: bool = diagnostic.contains("tree.unprefixed") and diagnostic.contains("id_prefix")
	var not_resolvable: bool = catalogue.resolve(&"tree.unprefixed") == null
	var ok: bool = result == ERR_INVALID_DATA and names_check and not_resolvable
	check("S0-05", "prefix", ok, "register=%d expected=%d diagnostic_names_check=%s resolve_is_null=%s" % [result, ERR_INVALID_DATA, names_check, not_resolvable])


func shape(def: SlotTreeDefinition) -> Dictionary:
	var child_counts: Dictionary[String, int] = {}
	for node: String in def.nodes:
		child_counts[node] = 0
	for edge: String in def.edges:
		var parent: String = edge.split(TreeRules.EDGE_SEPARATOR)[0]
		if child_counts.has(parent):
			child_counts[parent] += 1
	var endpoints: int = 0
	var two_children: bool = true
	for node: String in def.nodes:
		if child_counts[node] == 0:
			endpoints += 1
		elif child_counts[node] != TreeRules.CHILDREN_PER_NONTERMINAL:
			two_children = false
	return {"nodes": def.nodes.size(), "edges": def.edges.size(), "endpoints": endpoints, "two_children": two_children}


func case_rule_accepts(placeholder: SlotTreeDefinition) -> void:
	var diagnostics: PackedStringArray = TreeRules.validate(placeholder)
	check("S0-06", "rule_accepts", diagnostics.is_empty(), "diagnostics=%d" % diagnostics.size())


func case_rule_rejects(placeholder: SlotTreeDefinition, malformed: SlotTreeDefinition) -> void:
	var good: Dictionary = shape(placeholder)
	var good_nodes: int = good["nodes"]
	var good_edges: int = good["edges"]
	var good_endpoints: int = good["endpoints"]
	var good_two_children: bool = good["two_children"]
	var good_shape: bool = good_nodes == TreeRules.NODE_COUNT and good_edges == TreeRules.EDGE_COUNT and good_endpoints == TreeRules.ENDPOINT_COUNT and good_two_children
	var diagnostics: PackedStringArray = PackedStringArray() if _inject_fault else TreeRules.validate(malformed)
	var reconvergence: bool = false
	var unreachable: bool = false
	var names_id: bool = not diagnostics.is_empty()
	for diagnostic: String in diagnostics:
		names_id = names_id and diagnostic.begins_with(String(MALFORMED_ID))
		reconvergence = reconvergence or diagnostic.contains("reconvergence")
		unreachable = unreachable or diagnostic.contains("unreachable")
	var ok: bool = good_shape and names_id and reconvergence and unreachable
	var mode: String = "rule_bypassed_by_%s" % FAULT_FLAG if _inject_fault else "rule_applied"
	check("S0-06", "rule_rejects", ok, "%s good_tree=%d/%d/%d two_children=%s diagnostics=%d names_id=%s reconvergence=%s unreachable=%s" % [mode, good_nodes, good_edges, good_endpoints, good_two_children, diagnostics.size(), names_id, reconvergence, unreachable])
	for diagnostic: String in diagnostics:
		print("DIAG %s" % diagnostic)


func case_failed_reload(catalogue: ProofCatalogue, placeholder: SlotTreeDefinition, malformed: SlotTreeDefinition) -> void:
	var revision_before: int = catalogue.content_revision
	var bad_set: Array[SlotTreeDefinition] = [placeholder, malformed]
	var bad_result: Error = catalogue.stage(bad_set)
	var bad_diagnostics: int = catalogue.diagnostics.size()
	var kept: bool = catalogue.resolve(PLACEHOLDER_ID) == placeholder and catalogue.resolve(MALFORMED_ID) == null and catalogue.content_revision == revision_before
	var good_set: Array[SlotTreeDefinition] = [placeholder]
	var good_result: Error = catalogue.stage(good_set)
	var swapped: bool = catalogue.resolve(PLACEHOLDER_ID) == placeholder and catalogue.content_revision == revision_before + 1
	var ok: bool = bad_result == ERR_INVALID_DATA and bad_diagnostics > 0 and kept and good_result == OK and swapped
	check("S0-06", "failed_reload", ok, "bad_stage=%d expected=%d diagnostics=%d active_kept=%s good_stage=%d swapped=%s catalogue_revision=%d" % [bad_result, ERR_INVALID_DATA, bad_diagnostics, kept, good_result, swapped, catalogue.content_revision])


func case_admission_exit(catalogue: ProofCatalogue) -> void:
	var planned: int = EXIT_FAIL if _failed > 0 else EXIT_PASS
	var malformed_absent: bool = catalogue.resolve(MALFORMED_ID) == null
	check("S0-06", "admission_exit", malformed_absent, "malformed_absent_from_active=%s failed_cases=%d planned_exit=%d inject_fault=%s" % [malformed_absent, _failed, planned, _inject_fault])
