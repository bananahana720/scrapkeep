# Frozen writer handoff

REPORT.md, PLAN.md, manifest.json and the test log preserve the writer's pre-native handoff. Their pending native status is historical. The parent qualification and stationary-live/report.json own subsequent acceptance.

The original incremental candidate.patch is retained as candidate.patch.gz. Decompress it before applying; its uncompressed SHA-256 matches manifest.json. The base is the 71-test source snapshot retained under ../../extended-live/implementation/. The accepted implementation now lives in tools/agent-player and this qualification's Git commit.

The writer's approximate full-sweep rationale is a command/cadence estimate, not measured angular coverage. Native camera calibration showed turning between different views, not exact yaw delivery.
