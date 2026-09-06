# Native toolchain record

This page records the pinned Godot toolchain that [TADR-001](../../adr/TADR-001-engine-language-platforms.md) requires before the first authorized implementation, and the scaffold that proves it boots. It is a record and a proof host, not a design document. Everything below was observed on one developer machine under prepare-stage card S0-01. Nothing here is qualification evidence in the sense of TADR-001 lines 35 and 39. The `native/` path is provisional pending HF-01, which ratifies the native root and its path families.

## Pinned editor

| Field                 | Value                                                                                                                                                                                                  |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Editor version string | `4.7.2.stable.official.ed1daf0bf` (printed by `--version`)                                                                                                                                             |
| Download URL          | `https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip`                                                                                             |
| Zip size              | 77860424 bytes                                                                                                                                                                                         |
| Zip SHA512            | `9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65`, verified with `sha512sum -c` against the release `SHA512-SUMS.txt` |
| Binary SHA256         | `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`                                                                                                                                     |
| Install path          | `/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64`                                                                                                                               |
| Machine               | Arch Linux, kernel `7.1.9-arch1-2`, x86_64, host `ahana`                                                                                                                                               |
| Installed             | 2026-09-06 by the coordinator, official release binary, no package manager                                                                                                                             |

The editor is the standard build. No C# or custom build is pinned.

## Export templates

| Field       | Value                                                                                                                              |
| ----------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| Status      | Not installed, parked with S0-09                                                                                                   |
| Archive     | `Godot_v4.7.2-stable_export_templates.tpz` from the same release                                                                   |
| Archive URL | `https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz`                     |
| Size        | 1281349702 bytes                                                                                                                   |
| SHA512      | `ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079` |

The digest above comes from the release checksum list. The archive was not downloaded. S0-09 owns installing the templates and the export presets.

## Locating the binary

`scripts/native-smoke.mjs` reads `GODOT_BIN` from the environment. When the variable is unset it uses the install path recorded above. A missing binary is an internal error and exits 2. The runner reads `--version` from whichever binary it resolves, prints a NOTE when that differs from the pin, and records both strings in its report.

## Proof scaffold

The [native scaffold](../../native/README.md) holds `project.godot`, a typed smoke script and an untyped negative fixture. The proof command is documented in the [CONTRIBUTING verification table](../../CONTRIBUTING.md#verification):

```sh
npm run native:smoke
```

It proves four things on this host and nothing more. The pinned binary boots headless, parses a fully typed GDScript `SceneTree` script, prints `SCRAPKEEP_SMOKE 4.7.2.stable.official.ed1daf0bf typed` and exits 0. The same binary refuses a script with an untyped declaration under the project's warning settings and exits 1. No file under `native/` names a networking class. The positive boot repeats inside `unshare -rn`, a user namespace with no network interfaces, which is the offline method for [TADR-005](../../adr/TADR-005-networking-scope.md). Evidence goes to `artifacts/local/native-smoke/report.json`, which records each command, exit code, stdout excerpt, the engine version string, host identity and the sha256 of every file under `native/`.

The static-typing keys in `native/project.godot` and the documentation behind them are listed in the scaffold README. The 4.7 documentation names the warning families and states that each can be raised to Error in Project Settings; the numeric value 2 for Error and the key names were confirmed by running the engine, since the fetched excerpts do not print the text-format values.

## Limits

This is a headless boot on one Linux developer machine. It does not run a window, renderer, input device, scene, save or export. It says nothing about Windows, controllers, feel or performance. It does not replace the authorized native slice or the clean-machine export qualification in TADR-001. `npm run verify` does not run it and gains no stage; the reserved `check:godot` name stays reserved for the engineering handoff.
