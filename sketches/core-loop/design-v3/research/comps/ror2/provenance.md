# Provenance: what Risk of Rain 2 is built on, and what is free upstream

Evidence: inventory of library, plugin, bundle and font names, read as names only (level 2). License labels marked "known" come from general knowledge of the named project, not from a license file in the game; only one license text ships with the game (Noto Sans, OFL 1.1). Nothing from the game is fetched or copied; a "yes" below means the original project can be obtained from its own source under its own license, through the admission rule in `docs/project/ASSETS.md`.

## What it does

The game's third-party layer answers a design question for us: which problems Hopoo chose not to solve themselves. Input remapping, audio middleware, platform SDKs, decals, water, soft shadows, UI translucency and a performance overlay were all bought or borrowed. The engine-independent lesson is the list of roles, not the products.

## Parameters

| Role | Product in the game | License | Free upstream usable for Scrapkeep | Godot equivalent of the role |
| --- | --- | --- | --- | --- |
| Input remapping | Rewired | known: commercial | no | `InputMap` plus a remap screen |
| Audio middleware | Wwise (`AK.*` assemblies, `wwise_assets_all`) | known: proprietary | no | `AudioStreamPlayer` buses, `AudioStreamInteractive` and `AudioStreamSynchronized` for layered music |
| Steam integration | Facepunch.Steamworks | known: MIT | yes for a C# project; Scrapkeep is GDScript, so GodotSteam (MIT) is the matching source | GodotSteam |
| Epic, PlayFab, Discord, Sony, Xbox | EOS SDK, PlayFab, Discord Game SDK, SonyNP, PartyXboxLive | proprietary or unverified | no | not needed for the alpha |
| JSON | SimpleJSON | unverified (believed public domain) | not needed | built-in `JSON` |
| Virtual filesystem | Zio | known: BSD-2-Clause | C# only | not needed |
| Performance overlay | Graphy (`Tayx.Graphy`) wrapped by a developer class | unverified (believed MIT) | Unity-only | `Performance` singleton and a debug overlay |
| Character controller | KinematicCharacterController | unverified | Unity-only | `CharacterBody3D` |
| Decals, water, soft shadows, UI translucency | Decalicious, Calm Water, NGSS, Translucent Image | unverified, Asset Store | Unity-only | `Decal` node, a water shader, shadow settings, a blur shader |
| Screen-space reflections | developer's own (`HopooSSR`) | developer code | no | SDFGI or screen-space reflections in the environment |
| UI text | TextMesh Pro | Unity package terms | Unity-only | `Label` with `LabelSettings` and SDF fonts |
| Body font | Noto Sans, Noto Sans CJK | OFL 1.1 (license text ships with the game) | yes, from Google Fonts, under OFL with the Reserved Font Name clause | `FontFile` |
| UI fallback font | Liberation Sans | known: OFL 1.1 | yes, from the Liberation Fonts project | `FontFile` |
| Display fonts | a developer font plus four named display faces | unverified | check each face's own license before use; do not take from the game | depends on the face |

## Why it works

Buying the middleware let a three-person studio spend its hours on the director, the items and the stages. Every row above is a role Scrapkeep also needs; Godot covers most of them natively, which is the point of the engine choice in `adr/TADR-001-engine-language-platforms.md`.

## What Scrapkeep borrows

- **The role list, as a checklist for the native build.** Each row's Godot column is the thing to confirm exists in `native/` before alpha. Bible section: production conventions (`docs/tech/sections/HF-01-production-conventions.md`).
- **Noto Sans and Liberation Sans as candidate fonts**, fetched from their upstream projects with license evidence, if the current Barlow, DM Sans and IBM Plex Mono set (already OFL, `docs/project/ASSETS.md`) needs a CJK fallback.
- **Layered music through the engine, not middleware.** The music note (`progression-and-music.md`) describes the state machine; Godot's interactive audio streams carry it without Wwise.

## What it must not copy

No library, plugin, bundle, font file or shader from the game folder. The display fonts in particular: a face seen in the game is identified, then licensed from its foundry or not used.

## Lab measure

Not a lab item. The check is the admission record: every font and library in `native/` has a source URL, license evidence and the actual use recorded, per `docs/project/ASSETS.md`.
