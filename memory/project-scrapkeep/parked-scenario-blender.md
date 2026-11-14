---
name: parked-scenario-blender
description: "Scenario for Blender (scenario-labs/blender-plugin, add-on + MCP) parked 2026-10-15; revisit only if blockout or skybox work bottlenecks"
metadata:
  node_type: memory
  type: project
  originSessionId: a378854b-45dc-41f2-a699-338c45989aaa
  modified: 2026-10-15T20:54:28.667Z
---

Andrew parked Scenario for Blender (github.com/scenario-labs/blender-plugin) on 2026-10-15. It is a GPL-3.0 Blender 5.0+ add-on plus a loopback MCP server (`scenario-blender`, 127.0.0.1:9876), but every generation runs on Scenario's paid cloud (Creative Units, API key, Blender online access).

**Why:** it conflicts with the asset forge (network-less bwrap Blender, recipe-built models checked against `palette.gd` and the triangle band), AI meshes and PBR sets miss the flat low-poly look, and AGENTS.md bars paid services without owner approval.

**How to apply:** don't propose installing it. Revisit only if blockout (text-to-greybox layout) or 360 skybox work becomes a bottleneck; then propose a capped trial on a scratch .blend outside the forge promote path, with the credit cap named first. Related: [[parked-blender-asset-pipeline]], [[openverse-asset-source]].
