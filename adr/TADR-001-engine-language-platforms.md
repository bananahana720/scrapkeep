# TADR-001. Production engine, language and platforms

Status: **Accepted engineering direction.** Andrew treated the architecture as settled and approved execution preparation on 6 September 2026. This is not authorization to build.

Date: 6 September 2026. Scope: future standalone production game.

## Context

The approved [Bible's game identity](../BIBLE.md#game-identity) calls for a solo-first, close-third-person action roguelite on standalone PC with controller support. [Movement, camera and active aim](../BIBLE.md#movement-camera-and-active-aim) requires rolling, jumps, rebounds and deliberate aim. [Render style](../BIBLE.md#ad-04-render-style-and-materials) and [composition](../BIBLE.md#ad-08-composition-scale-and-interface) require readable 3D mechanisms, growing silhouettes and navigable Southwest terrain. These are product requirements, not evidence of a particular engine's performance.

The [implementation handoff](../BIBLE.md#architecture-and-implementation-handoff) leaves the production engine undecided. The current Three.js/Vite JavaScript proofs already separate simulation from presentation. A native production engine would replace substantial implementation, not merely repackage it.

## Options

| Option | Disposition | Reason |
| --- | --- | --- |
| Godot with typed GDScript and native scene/Resource authoring | **Recommended** | Keeps physical gameplay, authoring and qualification in one runtime while supporting explicit typed ownership. |
| Godot .NET with C# and an engine-independent rules library | **Rejected for this baseline** | Strong independent testing and typing, but adds an SDK and a maintained physical-world adapter boundary. The Bible requires separated responsibilities, not an engine-free library. |
| Retain Three.js/Vite JavaScript and add a desktop wrapper | **Rejected for this baseline** | Preserves the most existing code, but leaves more scene authoring, asset iteration and desktop integration to the project. A wrapper is viable; PC delivery alone does not disqualify it. |

## Decision

Recommend **Godot 4.7.2 standard edition with typed GDScript**, with Windows 11 x64 and Linux x64 as the initial production qualification targets. Use the same gameplay rules on both. Keyboard/mouse and controller must cover the full game and menus. macOS, dedicated handheld certification, web, mobile and consoles are outside this proposed release scope. Linux distribution and graphics-driver support details remain for the Constraints section.

Godot's official archive lists [4.7.2 stable](https://godotengine.org/download/archive/4.7.2-stable/). Its [MIT license](https://godotengine.org/license/) fits the free local tool preference. Pin the editor and matching export templates before the first authorized implementation. No engine or export toolchain was installed or tested in this session.

Use typed function boundaries, domain records and collections, with applicable static warnings. GDScript's [typing documentation](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/static_typing.html) describes both typing facilities and remaining dynamic collection operations. Loaded data still requires validation. Do not add C#, C++ extensions or a second gameplay language without a measured need and an amended decision.

Use [TADR-002](TADR-002-runtime-model.md) for runtime ownership and [TADR-003](TADR-003-content-pipeline.md) for content ownership. Renderer/backend selection and numerical budgets wait for technical sections and later measurement. Availability of [desktop export tooling](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html) is not proof that this game exports or meets its targets.

## Consequences

This is a deliberate rewrite with reuse of product rules, test scenarios, geometry fixtures and visual direction. Browser controls, Three.js models/rendering and WebAudio integration need replacements. The two existing entries and their data remain governed by the prototype entry ADR (`../docs/adr/0001-two-playable-entries.md`) until Andrew explicitly approves consolidation. ADR approval authorizes engineering-document continuation, not the rewrite itself.

Workers gain one editor/runtime workflow and inherit engine dependence. Godot scenes, Resource schemas, scripts, materials, animation and UI would be costly to move to another engine. Headless rule checks still require Godot; they do not establish controller feel or correct physical-world behavior. The C# alternative remains worth reopening if independent rule execution becomes an actual product or engineering requirement.

## Later qualification and reconsideration

Before wider implementation, an explicitly authorized native slice must qualify clean-machine desktop exports, rolling/jumping/rebounds, obstruction and shared attack geometry, focus/input transitions and real controller operation. Representative mech growth and dense fights need measured rendering and memory evidence on named hardware. No frame-rate, memory, load-time or asset-size ceiling is claimed here.

Reconsider the engine or language if export qualification fails, measured budgets cannot be met, or engine-bound rules materially prevent required testing. A worker cannot make an engine change as an incidental task choice.
