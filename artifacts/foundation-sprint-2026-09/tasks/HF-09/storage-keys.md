# HF-09 browser storage records, resolved 2026-09-12 at base d98803c

- src/campaign.js:111-146 parseProfile and :115 version predicate (version 1 profile shape); the profile is persisted by src/progress-store.js under the key passed by src/collection.js:29-38 (storageKey).
- src/progress-store.js:8 createProgressStore(storage, key); :45 version predicate on read.
- src/collection.js:29-31: storageKey is "scrapkeep.collection.v1", or "scrapkeep.qa.collection.v1" when the qa query flag is present; :38 creates the store with it.
- src/main.js:48,141: bestKey best-wave record. src/orchard/main.js:20,106: 'orchard-settings' key (orchard proof settings, not campaign progress).
