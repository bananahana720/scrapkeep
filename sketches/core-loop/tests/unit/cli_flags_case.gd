extends RefCounted

const CliFlags := preload("res://src/core/cli_flags.gd")


func run(t) -> void:
	var sample := PackedStringArray(["--boot-card", "--table=alpha", "--tune=a=1", "--tune=b=2", "--table=park", "positional"])
	t.check("has_flag matches exact flag", CliFlags.has_flag("--boot-card", false, sample))
	t.check("has_flag rejects prefix-only match", not CliFlags.has_flag("--table", false, sample))
	t.check("has_prefix matches key-value flag", CliFlags.has_prefix("--table=", false, sample))
	t.check("has_prefix rejects missing flag", not CliFlags.has_prefix("--missing=", false, sample))
	t.eq("value_of uses last matching flag without trailing equals", CliFlags.value_of("--table", "", false, sample), "park")
	t.eq("value_of uses last matching flag with trailing equals", CliFlags.value_of("--table=", "", false, sample), "park")
	t.eq("value_of falls back to default when absent", CliFlags.value_of("--missing", "fallback", false, sample), "fallback")
	t.eq("values_of preserves all occurrences in order", Array(CliFlags.values_of("--tune", false, sample)), ["a=1", "b=2"])
	t.eq("kv_pairs parses key-value arguments with last-wins", CliFlags.kv_pairs(false, sample), {"--table": "park", "--tune": "b=2"})
	var empty_val := PackedStringArray(["--frame-log="])
	t.check("has_prefix detects empty value", CliFlags.has_prefix("--frame-log=", false, empty_val))
	t.eq("value_of returns empty string when explicitly empty", CliFlags.value_of("--frame-log=", "fallback", false, empty_val), "")
