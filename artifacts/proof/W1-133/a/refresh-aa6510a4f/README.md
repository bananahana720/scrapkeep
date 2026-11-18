# W1-133a checks after the stage merge

PR head `aa6510a4fe93ae4fbeeb6d97c1716882f609d360` merges stage `c9d55d7c7f41910b9ae9e4f3bd6023f610779fc2`. Godot 4.7.2.stable.official.ed1daf0bf ran headlessly with isolated scratch homes. The run used Tarn, 13 shipped stage and pack combinations, seeds 1–8, straight, weaving and stopped passes, and 14 and 28 m/s. The stage’s authored routes supplied the positions.

| Check | Result |
| --- | --- |
| Per-PR fast check | Passed in 235 seconds against the exact stage parent. [Fast receipt](fast-checks.json) |
| Focused tests | All seven passed with zero skips. The matchup test exercises the on-line strike, the strike 3 m off-line, both ends of the trap window, duplicate rows and the grade controls. [Geometry fixtures](geometry-fixtures.txt) · [Focused receipt](focused-checks.json) |
| Live zero-lead control | 96 of 96 observed at least one strike and recorded zero threats. |
| Round zero | 720 of 720 runs completed, including 624 normal passes. 32 of 208 straight passes faced at least one committed threat. 208 of 208 stopped passes lost hull and met the doubled hull-loss rate. [Raw receipt](fast-threat.json) |
| Rider damage | 0 of 208 straight passes and 0 of 208 weaving passes lost hull. |
| Earlier stage comparison | On the same six inputs (stage, pack, pilot, seed, speed and pass), 0 of 624 threat counts changed and 0 of 624 hull-loss totals changed. |
| Previous weaving baseline | 0 of 208 matched weaving passes lost more hull than at `2df78cdb1`. The raw file is a fresh round zero for this stage, so its own grade lists the prior weave comparison as missing. |
| Staged winch | All six one-seed passes completed in the fallback elite pack. [Winch receipt](staged-winch.json) |
| Independent source review | GPT-6.2 Astra, high effort. Passed the merged head. The four PR files match the previously reviewed head byte for byte. |

The focused runner lists 11 untracked Godot import sidecars. These are outside the PR diff. macOS workers logged the renderer shutdown messages documented in `project-guide/handoff/DEVICES.md`.

Raw SHA256 `fc77cfafe960e4daa84e2ae9183a38a5af849c8ef326ccef14edb942ae117244`. The portable check files include the original receipt digests and shorten host paths.

Kinds that threatened straight riders on this run: ramp_flipper.

| Stage | Pack | Straight passes threatened at 14 m/s (of 8) | At 28 m/s (of 8) | Weaving passes that lost hull (of 16) |
| --- | --- | ---: | ---: | ---: |
| Dam | run_down | 0 | 0 | 0 |
| Dam | grounded | 0 | 0 | 0 |
| Dam | live_wire | 0 | 0 | 0 |
| Dam | sluice_line | 0 | 0 | 0 |
| Dam | flap_run | 8 | 8 | 0 |
| Dam | elite | 0 | 0 | 0 |
| Flume | run_down | 0 | 0 | 0 |
| Flume | grounded | 0 | 0 | 0 |
| Flume | shift_crew | 0 | 0 | 0 |
| Flume | crossed_wires | 0 | 0 | 0 |
| Flume | weir_strung | 0 | 0 | 0 |
| Flume | flap_line | 8 | 8 | 0 |
| Flume | elite | 0 | 0 | 0 |

W1-132a supplies the shared route and qualified look harness, W1-132e supplies the receipt tool, and W1-132g measures warning-edge contrast on matched frames. These checks cover the headless producer. The Gate owns admission and sitting-cadence guards.
