# Sprint 0 closure evidence — retained copies

Byte-identical retained copies of the nine distinct files pinned by the tracked Sprint 0 closure receipt, [closure.json](../../docs/project/sprint-0/closure.json). The receipt's 12 `path` + `sha256` evidence entries name the files in this directory, so the tracked authority record no longer depends on the gitignored, disposable `artifacts/local/` tree. This is the mitigation for audit finding H-01 under [AR-02](../../BACKLOG.md#ar-02) (audit-repair lane, owner Verification).

## Source

- Sprint `operational-s0-2026-09-06`, integrated commit `e54e429c76f3d83641c0127b4e44fe7eb8b2098f`.
- Originals: `artifacts/local/sprint-0/closed/` — the location the closure gates wrote to, ignored by [.gitignore](../../.gitignore) line 7 and called disposable by [AGENTS.md](../../AGENTS.md) and [artifacts/README.md](../README.md).
- Copies taken on 2026-09-10 during card AR-02 attempt A1, from base commit `641f09f54a37af15da2ea35ced7f281f60959d13`.
- Source bytes verified before copying: all nine originals reproduced the `sha256` values below.

## Method

Each file was copied unchanged and verified twice: `cmp` reported no difference against the original, and `sha256sum` reproduced the hash recorded in the receipt. Copying was used deliberately — no original was moved, edited or deleted.

A read-only `path` + `sha256` walk over the receipt, which additionally requires every pinned path to be tracked by Git, reports `present+match=12 missing=0 hash-mismatch=0 untracked=0`. The walk script and its recorded output are kept in `artifacts/local/tasks/AR-02/` as the card directs; that location is itself disposable scratch.

## Files

| File | sha256 | Receipt gate citations |
| --- | --- | --- |
| `docs.log` | `ec6fb1d6ea417337444eacb76cad0c42eafa1dc3dd24f736824636149cc7a439` | `docs` |
| `project.log` | `cf6a6119eceeb807262e3a2ed16a4a24987b72a9377e0d893edbf6d60443d8a4` | `project` |
| `integrated-review.md` | `1c269139cc2b9507deffb6679a856b5322a0a8858310679af74f74a92a6ea213` | `scenario-review`, `fresh-integrated-review` |
| `native-report.json` | `9360ba38365de88f37e3acd8a2352d2c00f4972ab9e83d69fa0f770c1cf6559e` | `adr-harness`, `linux-export`, `windows-export` |
| `visible-receipt.json` | `09abf7bfbd9dfc99a7ae5fabe66495af706c424846dd1de192891d5999aeb89e` | `linux-local` |
| `ci-native-report.json` | `a1dc6bb304e8abfa13662aaeee9381b2cff4a755778d2a842c7c749c155b6c7e` | `linux-ci` |
| `verify.log` | `0cefb3bceec863223794750258aaf739e6ba0fe903fe7ff8ace2bf451a81f8cd` | `browser-proof-preservation` |
| `coverage-review.md` | `d7e062ea253b420ed1550967fe31bfcc71c8e6d65c5e987e8fcbc2dac2ffea4e` | `fresh-review-coverage` |
| `runner-cleanup.json` | `e184c6f384140a58cd7e37562392daf966f353d824b05532753cb74de850c831` | `runner-cleanup` |

Nine files, 12 citations. The two large export binaries whose hashes `native-report.json` records are **not** copied here; only the JSON that records their hashes is pinned by the receipt.

## Limits

- These are copies of evidence produced at the integrated commit, not new evidence. No closure gate was re-run, and no gate status, result or `sha256` value was changed. The recorded outcomes remain the ones the receipt names.
- Copying preserves the recorded bytes so the receipt checker can be replayed from a clean clone. It does not authenticate the recorded statements, does not show the recorded runs were correct, and grants no dispatch authority.
- The originals remain at `artifacts/local/sprint-0/closed/` until a separate cleanup is authorised. This directory is a second copy, not a replacement.
- Windows execution, human playtest and Bible Pillars/enjoyment qualification remain untested, exactly as the receipt's own `limits` fields state.

## Owners

[closure.json](../../docs/project/sprint-0/closure.json) owns the pins. [The Sprint 0 handoff](../../docs/project/sprint-0/README.md) owns the sprint record. [artifacts/README.md](../README.md) owns the artifact-retention policy.
