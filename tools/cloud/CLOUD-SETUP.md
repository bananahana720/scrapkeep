# Cloud environment setup

Most of the setup travels with the repository. A cloud session clones the repo, and `.claude/hooks/session-start.sh` installs Godot 4.7.2, its Linux export templates, Blender 5.2.2 LTS (the PyPI `bpy` wheel) and the locked npm packages, then sets `GODOT_BIN` and puts `scripts/cloud` on `PATH`. A new account needs a few settings entered once.

## Set once in the new account

1. Connect GitHub at <https://claude.ai/connect-github> and make sure the Claude GitHub app is installed on `bananahana720/scrapkeep`.
2. Attach `bananahana720/scrapkeep` to the new project as its only repository. A session with several repositories does not run the repo's SessionStart hook.
3. Open the project's cloud environment settings (Project settings, then Cloud environment, then the gear beside the environment) and enter:

| Field | Value |
| --- | --- |
| Network access | **Trusted** (the default). It already allows `github.com`, `release-assets.githubusercontent.com`, `objects.githubusercontent.com`, `pypi.org`, `files.pythonhosted.org` and `registry.npmjs.org`, which is everything setup downloads. No extra allowed domains. |
| Environment variables | None. The hook sets `GODOT_BIN` and `PATH` itself. |
| Setup script | Paste the whole of [`setup.sh`](setup.sh). |

Context settings also travel with the repo. `.claude/settings.json` sets `env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` to `40`, `autoCompactEnabled` to `true` and `subagentPromptCacheTtl` to `1h`, matching Andrew's PC, so threads and their subagents compact at 40% and subagents keep a one-hour prompt cache. Don't put the compaction variable in the environment's variables field: the session's own value (80) overrides one set there, while the repo `env` block overrides the session's value.

The setup script is optional but recommended. The environment caches what it installs as a filesystem snapshot, so new sessions start with Godot and Blender already on disk instead of downloading about 300 MB each time (about 55 s saved per fresh session). Without it, the hook still installs everything at session start. The script finishes in about a minute, well under the five-minute limit for caching, and never fails the session start: on an error it prints a warning and the hook retries.

The cache rebuilds when the setup script or the network setting changes, and about every seven days. If `setup.sh` changes in the repo (a new Godot or Blender pin), paste the new version into the field.

## Check it worked

The first message of a new session shows the hook's line:

```text
scrapkeep cloud toolchain: 4.7.2.stable.official.ed1daf0bf, Blender 5.2.2 LTS
```

If that line is missing or names another version, the hook failed. Its error output names the step.

## Cloud limits

- Each session VM has 4 vCPU, about 15 GB of usable RAM, about 30 GB of disk and no GPU.
- Run at most about 8 Godot child processes at once. More than that risks out-of-memory kills, which look like timeouts. Rerun a full-sweep failure alone before you blame a change. `sketch-smoke` runs 2 slots by default; `SMOKE_SLOTS=4` uses all four CPUs.
- A paused VM keeps its files, but a reclaimed one loses `nohup` jobs. Run long work as a tracked background task.
- GPU work stays on Andrew's PC: frame-time captures, Eevee and Vulkan renders, the boss smoke, ACE-Step music, the real `npm run sketch:export` and playtests. See [the cloud sessions page](../../scripts/cloud/README.md) for what runs here.

Reference: <https://code.claude.com/docs/en/cloud-environments>.
