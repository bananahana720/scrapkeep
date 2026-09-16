# Product sections

Admitted product documentation sections, one per prepare-stage design card, written in the same seven-heading form as [the technical sections](../../tech/sections/README.md): Sources, Contract, Scenarios, Unresolved questions, Re-verification triggers, Procedure performed, Evidence limits. Each section states the SHA256 of every repository file it depends on in its Sources bullets; `npm run check:drift` scans this directory as well as the technical sections, resolving each stated dependency from the citing section's own directory and then from `docs/tech/sections`, reporting a mismatch or a link it cannot bind in the same DRIFT form a technical section's gets and reporting a section that states no hash at all as unbound; this index states none by design and is exempt. The coordinator owns this index and adds one line per admitted section.

- [PD-01: Production art acceptance brief](PD-01-art-acceptance.md).
- [PD-02: Production interface states and acceptance](PD-02-interface-states.md).
