extends RefCounted

const SourceScan := preload("res://tests/support/source_scan.gd")

const CORE_ROOT := "res://src/core"
const UNSEEN_PATTERN := "[\"'](res://src/(?:build|combat|boss|world|movement|presentation|ui)/(?![^\"'%]*\\.gd[\"'])[^\"']+)[\"']"


func run(t) -> void:
	var found: Array[String] = []
	var hits: Dictionary = SourceScan.captures(t, [CORE_ROOT], UNSEEN_PATTERN)
	for path in hits:
		for row in hits[path]:
			found.append("%s -> %s" % [path, row[1]])
	found.sort()
	t.eq("src/core names no higher-layer path that lint rule L20 cannot see", found, [] as Array[String])
