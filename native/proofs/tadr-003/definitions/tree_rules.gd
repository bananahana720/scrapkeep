class_name TreeRules
extends RefCounted

const SlotTreeDefinition = preload("res://proofs/tadr-003/definitions/slot_tree_definition.gd")

const NODE_COUNT: int = 15
const EDGE_COUNT: int = 14
const ENDPOINT_COUNT: int = 8
const CHILDREN_PER_NONTERMINAL: int = 2
const EDGE_SEPARATOR: String = ">"


static func validate(def: SlotTreeDefinition) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var id: String = String(def.id)
	var nodes: PackedStringArray = def.nodes
	if nodes.size() != NODE_COUNT:
		out.append("%s: node_count: expected %d, found %d" % [id, NODE_COUNT, nodes.size()])
	var seen: Dictionary[String, bool] = {}
	for node: String in nodes:
		if seen.has(node):
			out.append("%s: node_unique: %s appears twice" % [id, node])
		seen[node] = true
	if def.edges.size() != EDGE_COUNT:
		out.append("%s: edge_count: expected %d, found %d" % [id, EDGE_COUNT, def.edges.size()])
	var children: Dictionary[String, PackedStringArray] = {}
	var parent_count: Dictionary[String, int] = {}
	for node: String in nodes:
		children[node] = PackedStringArray()
		parent_count[node] = 0
	for edge: String in def.edges:
		var parts: PackedStringArray = edge.split(EDGE_SEPARATOR)
		if parts.size() != 2 or parts[0].is_empty() or parts[1].is_empty():
			out.append("%s: edge_format: %s is not parent>child" % [id, edge])
			continue
		if not seen.has(parts[0]) or not seen.has(parts[1]):
			out.append("%s: edge_endpoint: %s names an unknown node" % [id, edge])
			continue
		children[parts[0]].append(parts[1])
		parent_count[parts[1]] += 1
	var roots: PackedStringArray = PackedStringArray()
	for node: String in nodes:
		if parent_count[node] > 1:
			out.append("%s: reconvergence: node %s has %d parents" % [id, node, parent_count[node]])
		if parent_count[node] == 0:
			roots.append(node)
	if roots.size() != 1:
		out.append("%s: root_count: expected 1, found %d (%s)" % [id, roots.size(), ", ".join(roots)])
	var endpoints: int = 0
	for node: String in nodes:
		var child_count: int = children[node].size()
		if child_count == 0:
			endpoints += 1
		elif child_count != CHILDREN_PER_NONTERMINAL:
			out.append("%s: child_count: node %s has %d children" % [id, node, child_count])
	if endpoints != ENDPOINT_COUNT:
		out.append("%s: endpoint_count: expected %d, found %d" % [id, ENDPOINT_COUNT, endpoints])
	if not roots.is_empty():
		var reached: Dictionary[String, bool] = {}
		var frontier: PackedStringArray = PackedStringArray([roots[0]])
		while not frontier.is_empty():
			var current: String = frontier[frontier.size() - 1]
			frontier.remove_at(frontier.size() - 1)
			if reached.has(current):
				continue
			reached[current] = true
			frontier.append_array(children[current])
		for node: String in nodes:
			if not reached.has(node):
				out.append("%s: unreachable: node %s cannot be reached from root %s" % [id, node, roots[0]])
	var remaining: Dictionary[String, int] = parent_count.duplicate()
	var ready: PackedStringArray = roots.duplicate()
	var ordered: int = 0
	while not ready.is_empty():
		var current: String = ready[ready.size() - 1]
		ready.remove_at(ready.size() - 1)
		ordered += 1
		for child: String in children[current]:
			remaining[child] -= 1
			if remaining[child] == 0:
				ready.append(child)
	if ordered != nodes.size():
		out.append("%s: acyclic: %d nodes lie on or behind a cycle" % [id, nodes.size() - ordered])
	return out
