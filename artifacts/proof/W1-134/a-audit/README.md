# W1-134a ordinary-ride census

Two chasers expose a false pass on stage `4f9017c58537e6e6785c00f6d4d45cdcd6e6f1be`. Only the first chaser warns. It enters in view and accumulates 0.600 seconds on screen. The second chaser spawns behind the camera and dies before the next sample. Both runs record two spawns, one seen, one warning and zero pop-ins.

| Head | Crew coverage | Arrival promise | Record |
| --- | --- | --- | --- |
| Stage `4f9017c58` | Complete | Pass | [Before](before.png) · [Receipt](before.json) |
| Candidate `17bb1016f` | Incomplete | Fail | [After](after.png) · [Receipt](after.json) |

These strips display the recorded Godot 4.7.2 headless measurements. For the stage reproduction, the [fixture patch](stage-fixture.patch) supplies the same measured pair to each input of the original receipt aggregator. Those repeated rows represent one fixture. On the candidate the `ordinary_unseen` fixture runs the ordinary-ride receipt directly. Its one expected failure is the promise assertion. Eighteen controls pass, including the control that times the warning using six 0.1-second steps.

[Implementation and Gate handoff](https://github.com/bananahana720/scrapkeep/pull/1156)
