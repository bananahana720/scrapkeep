# Asset registry fragments

Each asset unit owns one JSON file here. Use an `assets` array with the same rows
as `assets/registry.json`. This example copies the existing chunks row:

```json
{
 "assets": [
  {
   "path": "res://assets/models/chunks.glb",
   "class": "chunk",
   "ships": true,
   "loader": "src/presentation/hero_assets.gd:43"
  }
 ]
}
```

The example is a schema reference. Copying it into a fragment while that row
remains in the registry causes a duplicate error. Register new models in your
own fragment. An optional `id` names an asset; otherwise its `path` is its ID,
matching the current registry. Both IDs and paths must be unique.

Run from the repository root:

```sh
python3 sketches/core-loop/tools/fold_registry.py
```

The fold sorts rows by path, validates fragment GLB paths, and writes only after
all fragments pass. The generated `fragment_ids` field records which rows came
from fragments. Keep that field with the registry. A second fold replaces those
rows from their fragments and produces identical bytes. Editing or deleting a
fragment updates or removes its generated rows on the next fold. The coordinator
owns the folded registry; asset units write only their fragments.

Use `--root /path/to/core-loop` to fold a scratch project without changing this
worktree's registry. Check the fold with `node --test scripts/fold-registry.test.mjs`.
