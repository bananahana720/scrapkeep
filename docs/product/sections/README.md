# Product sections

Admitted product documentation sections, one per prepare-stage design card, written in the same seven-heading form as [the technical sections](../../tech/sections/README.md): Sources, Contract, Scenarios, Unresolved questions, Re-verification triggers, Procedure performed, Evidence limits. Each section states the SHA256 of every repository file it depends on in its Sources bullets; `npm run check:drift` scans only the technical sections today, so a product section's stated hashes are proved by its retained paper check until that scan is widened. The coordinator owns this index and adds one line per admitted section.

- [PD-01: Production art acceptance brief](PD-01-art-acceptance.md).
