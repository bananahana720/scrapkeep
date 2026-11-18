# W1-134a ordinary-ride census

Two chasers expose a false pass on stage `4f9017c58537e6e6785c00f6d4d45cdcd6e6f1be`. Only the first chaser warns. It enters in view and accumulates 0.600 seconds on screen. The second chaser spawns behind the camera and dies before the next sample. Both runs record two spawns, one seen, one warning and zero pop-ins.

| Head | Crew coverage | Arrival promise | Record |
| --- | --- | --- | --- |
| Stage `4f9017c58` | Complete | Pass | [Before](before.png) · [Receipt](before.json) |
| Candidate `bfa18f399` | Incomplete | Fail | [After](after.png) · [Receipt](after.json) |

These strips display the recorded Godot 4.7.2 headless measurements. For the stage reproduction, the [fixture patch](stage-fixture.patch) supplies the same measured pair to each input of the original receipt aggregator. Those repeated rows represent one fixture. On the candidate the `ordinary_unseen` fixture runs the ordinary-ride receipt directly. Its one expected failure is the promise assertion. Eighteen controls pass, including the control that times the warning using six 0.1-second steps.

[Implementation and Gate handoff](https://github.com/bananahana720/scrapkeep/pull/1156)

## Natural rides and yard waves

The refreshed PR at `bfa18f399cbb6d8ec70182dfe39b54041de2d3e5` includes stage `09be3186b392da09ab6913ce008621ff142394f8`. That stage and the before capture share the same complete Godot game tree (`e6c2e79d2`). The after strip and all current-head readings use the refreshed PR.

The [full census](rides.json) contains 1,216 ordinary crew records. It retains all 220 unseen crews, including 34 deaths, 156 removals and 30 crews present when their ride ended. The eight ordinary rides counted 996 pop-ins. The two staged yard scenes counted another 53. Of those, 42 came from the 44 lock members across 12 waves. Minimum measured warning lead was 0.000 s. The game floor is zero pop-ins and at least 0.600 s on screen before a crew’s first warning.

The [live-ahead plant](live-ahead.json) registered one pop-in. The [check results](checks.json) record the head, planted failures, named guard tests, skipped controls and the fast check. The census measures collider projection through the chase camera with a terrain-occlusion ray. Pixel visibility and human feel require separate evidence.
