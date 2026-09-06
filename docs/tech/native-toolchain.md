# Native toolchain record

This page records the pinned Godot toolchain that [TADR-001](../../adr/TADR-001-engine-language-platforms.md) requires before the first authorized implementation, and the scaffold that proves it boots. It is a record and a proof host, not a design document. S0-01 recorded the editor pin. Authorized operational card S0-09 adds internal exports and a manually dispatched local-runner workflow. Nothing here is qualification evidence in the sense of TADR-001 lines 35 and 39. The `native/` path is provisional pending HF-01, which ratifies the native root and its path families.

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
| Status      | Downloaded, checksum verified and selected Linux/Windows x64 templates extracted for S0-09                                         |
| Archive     | `Godot_v4.7.2-stable_export_templates.tpz` from the same release                                                                   |
| Archive URL | `https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz`                     |
| Size        | 1281349702 bytes                                                                                                                   |
| SHA512      | `ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079` |

The digest above comes from the release checksum list. S0-09 verified the downloaded archive against it and extracted the x64 templates into temporary storage at `/tmp/scrapkeep-s0-toolchain/godot/export_templates/4.7.2.stable`. The local invocation sets `XDG_DATA_HOME=/tmp/scrapkeep-s0-toolchain`. The coordinator also installed the verified subset under `/home/andrew/.local/share/godot/export_templates/4.7.2.stable`. Both installations contain Linux debug/release x86_64, Windows debug/release x86_64 and `version.txt`; other target templates were not extracted.

| Extracted file               | SHA256                                                             |
| ---------------------------- | ------------------------------------------------------------------ |
| `linux_release.x86_64`       | `d9f79ab89b5ae369aeed11c6052d402e8218cd503bf85b4a235f9c30c46a7c63` |
| `windows_release_x86_64.exe` | `d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562` |
| `version.txt`                | `38885c88f75abbc797a1db7559719800279a00cfb9fa8b2e2868a7f6f84bad2e` |

## Locating the binary

`scripts/native-smoke.mjs` reads `GODOT_BIN` from the environment. When the variable is unset it uses the install path recorded above. A missing binary is an internal error and exits 2. The runner records `--version` and the binary SHA256. Its engine-pin check fails when either differs from this record. Subprocess errors and timeouts cannot pass as expected negative results.

## Proof scaffold

The [native scaffold](../../native/README.md) holds `project.godot`, a typed smoke script and an untyped negative fixture. The proof command is documented in the [CONTRIBUTING verification table](../../CONTRIBUTING.md#verification):

```sh
npm run native:smoke
```

It proves four things on this host and nothing more. The pinned binary boots headless, parses a fully typed GDScript `SceneTree` script, prints `SCRAPKEEP_SMOKE 4.7.2.stable.official.ed1daf0bf typed` and exits 0. The same binary refuses a script with an untyped declaration under the project's warning settings and exits 1. No file under `native/` names a networking class. The positive boot repeats inside `unshare -rn`, a user namespace with no network interfaces, which is the offline method for [TADR-005](../../adr/TADR-005-networking-scope.md). Evidence goes to `artifacts/local/native-smoke/report.json`, which records each command, exit code, stdout excerpt, the engine version string, host identity and the sha256 of every file under `native/`.

The static-typing keys in `native/project.godot` and the documentation behind them are listed in the scaffold README. The 4.7 documentation names the warning families and states that each can be raised to Error in Project Settings; the numeric value 2 for Error and the key names were confirmed by running the engine, since the fetched excerpts do not print the text-format values.

## Internal exports and local CI

`native/export_presets.cfg` contains exactly `Linux x64` and `Windows x64`. Both embed the project resources in the executable, retain the default renderer, and exclude the deliberately untyped negative fixture. Windows resource modification and signing are disabled for this internal proof. The presets use the documented [Linux exporter properties](https://docs.godotengine.org/en/4.7/classes/class_editorexportplatformlinuxbsd.html) and [Windows exporter properties](https://docs.godotengine.org/en/4.7/classes/class_editorexportplatformwindows.html). Other smoke scripts remain in the exports. Q-E13 and TH-26 own their later disposition.

```sh
XDG_DATA_HOME=/tmp/scrapkeep-s0-toolchain \
XDG_CACHE_HOME=/tmp/scrapkeep-s0-cache \
GODOT_TEMPLATES_ARCHIVE=/tmp/scrapkeep-4.7.2-templates.tpz \
node scripts/native-smoke.mjs --export
```

The harness copies native sources into a fresh `artifacts/local/native-smoke/run-*/native/` directory before any Godot process runs. It omits the generated `.godot` directory and `.import` files and checks original source hashes afterward. Editor import and export therefore cannot generate UID or cache files beside tracked sources. Save directories also remain beneath the fresh run directory. Each Godot process receives isolated XDG data/cache paths there. Export mode links the selected installed templates into that isolated data root for read access. Existing proof `user://` writes therefore remain disposable.

Export mode retains the positive and negative ADR proofs, imports the copied project, and runs the integrated main scene in editor stage, resume, stage-fault and resume-fault processes. It exports to fresh absolute paths under `artifacts/local/native-export/linux/` and `artifacts/local/native-export/windows/`, checks each executable's presence, nonzero size and SHA256, and repeats the integrated cases with the Linux executable. An available `unshare -rn` repeats Linux execution without network interfaces. An unavailable namespace produces `skip`, which supplies no offline execution evidence. Resume and resume-fault runs must preserve the committed save SHA256. Stage faults must leave no committed save.

The command is noninteractive. Normal processes have a 60-second timeout and receive SIGKILL on expiry. Required success/failure markers, summary consistency, exit codes, script errors and export errors determine check results. Any failed check exits 1. Missing tools and internal harness errors exit 2 and produce a failing report. Unit tests execute child processes to exercise missing markers, script errors, expected fault exits, timeout and spawn failures. Export-result tests reject failed, absent, empty and unhashed outputs.

The report remains at `artifacts/local/native-smoke/report.json`. Schema `scrapkeep-native-smoke/2` records `sourceCommit`, dirty-source status, source-file hashes, host and pinned engine identity, checks with argument arrays, integrated summaries, installed template hashes, and exported file paths, byte sizes and SHA256 values. `GODOT_TEMPLATES_ARCHIVE` adds a checked archive SHA512 when supplied. The workflow supplies it. This report contains the exact commands for reproducing a specific run. It does not turn a successful export into Windows execution evidence.

For a manual window check, launch the reported Linux executable without `--headless` or `--auto-exit`. In the isolated Wayland desktop on this host, add `--display-driver wayland`. This is a launch option, not a project setting. Inspect the reported stage result and activate **Exit**. A separate receipt must record the executable SHA and observed input; the automated report makes no visible-window claim.

The [manual workflow](../../.github/workflows/native-smoke.yml) has one job, a 20-minute limit, and only `workflow_dispatch`. It requests `[self-hosted, linux, x64, scrapkeep-s0]` and requires a separately authorized temporary runner configured for one job. Registration and dispatch are external operations; the workflow itself creates neither. The runner needs Git, curl, Python 3, Node satisfying `package.json`, npm and standard checksum tools.

Checkout uses `actions/checkout` pinned to commit `11bd71901bbe5b1630ceea73d27597364c9af683`, with credential persistence disabled. The job downloads the exact editor and template URLs above, verifies both archive SHA512 values before extraction, and verifies the editor SHA256. Dependencies install with `npm ci`. The job runs documentation/project checks, harness unit tests and real exports. It prints the JSON report to the job log and appends it to the job summary, including after failure. It has no hosted job, uploaded artifact, binary publication or cache-storage action. CI execution remains pending a separately approved runner registration and a recorded successful manual run.

## Limits

The original S0-01 receipt is a headless boot on one Linux developer machine. The separate S0-09 report extends evidence to synthetic scene/save execution and internal exports. The automated report does not exercise a visible window or physical input. It says nothing about Windows, controllers, feel or performance. It does not replace the authorized native slice or the clean-machine export qualification in TADR-001. `npm run verify` does not run it and gains no stage; the reserved `check:godot` name stays reserved for the engineering handoff.
