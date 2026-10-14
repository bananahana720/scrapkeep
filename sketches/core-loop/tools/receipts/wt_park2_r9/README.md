# WT-PARK2 round 9 evaluator evidence

The two complete eight-case ideal batches agree in every fight and trace field. The pilot runs the real park Game through ordinary movement inputs, without changing production rules. Each trace now covers consecutive physics frames from the engagement boundary through the breaking tick. Fight records identify the engagement event, first sample, break event, terminal sample and sample count.

`park_reactor_ideal_check.py` independently derives sheet gain from the owning records, subtracts the gain already requested in the same frame, caps applied posture at FULL, and reconciles every contact and trace sample. It also verifies break time and complete cycle coverage before calculating phase durations.

The red completeness and applied-gain receipts precede their fixes. The final regression entry point has 14 controls. It checks valid duplicate batches and a valid zero-gain second contact in the same physics frame and rejects omitted samples, removed cycles, truncated endpoints, reversed timestamps, the gate's cycle-only trace, zeroed or doubled applied gain, inconsistent posture, premature shatter a wrong break timestamp and an unreduced second gain in the same frame. The final evaluator returns `PASS (8/8 complete identical cases)`.

Times remain 13.711667 s grown and 85.696111 s small for all four seeds. This is isolated mechanical feasibility and evaluator verification. It does not establish ordinary bot acceptance, human feel or rendered presentation. The round's scratch REPORT.md records the separate bounded bot attempts and failed criteria.
