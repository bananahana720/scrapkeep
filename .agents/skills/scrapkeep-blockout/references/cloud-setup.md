# Running mojulo in a cloud session

Learned from the 2026-10-22 split lab: the local PC against a Claude Code cloud box in environment `scrap`.

## What the box has

- **Node:** 22.22, which meets mojulo's floor of 22.14. `npx -y mojulo@3.0.0 orient` installs and runs in about 13 s.
- **Godot and Blender:** none installed. The lab brief tells the agent to try one portable install and to record a gap if it fails. That the install works is not yet verified.
- **Mojulo access:** CLI only. MCP servers configured in local Claude Code, such as the mojulo plugin, cannot attach to a cloud routine. Only claude.ai connectors can.

## How to start one

1. Commit and push the brief and its inputs first. The box clones the repository and checks out the branch the prompt names.
2. A Remote Control message cannot start a session, and a `start_session` card cannot choose the cloud environment. What worked is a one-time routine:
   - `RemoteTrigger` with `action: "create"` and `run_once_at` a minute ahead.
   - `job_config.ccr.environment_id` set to the `scrap` environment.
   - `session_context.model` set to `claude-opus-5-5`, and `sources` set to the repository.
   - Find the current environment id with the `schedule` skill, which lists environments.
3. The prompt must be self-contained. It says:
   - The branch to check out and a new branch under scratch/ to push to.
   - The spec file to read.
   - The acceptance list.
   - The output folder.
4. Check the run with `RemoteTrigger list_runs`, then `get_run_log`. A run that stops shows `worker_status: requires_action`.

## The stall to avoid

The 2026-10-22 cloud run stopped 2 minutes in on a permission prompt: "A variable in this command can't be checked before it runs". The command used `$HTTPS_PROXY`. A routine runs unattended, so any permission prompt stops it until Andrew approves it in the browser.

- Tell the agent in the prompt: "Never put shell variables, `$(...)` or backticks in a Bash command. Write literal paths, and put values in files."
- Name the expected tools in `allowed_tools`.
- Tell Andrew the session link as soon as it starts, in case it needs an approval.

## What to compare between the two sides

- The geometry hashes from `geomhash.py`, not the glb hashes, for determinism across machines.
- Mint and export times. The cloud box is likely to have fewer cores, so expect slower exports.
- Whether Godot and Blender run there at all. Until they do, ball proofs and stills stay on the PC.
