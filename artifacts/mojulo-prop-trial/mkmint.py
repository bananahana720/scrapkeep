import json, sys
from pathlib import Path
here = Path(__file__).resolve().parent
variant, out = sys.argv[1], sys.argv[2]
params = json.loads((here / "params-r2.json").read_text())
params["variant"] = variant
spec = {"units": "cm", "seed": 7 if variant == "a" else 8, "budgetMs": 60000, "params": params,
        "source": (here / "wheelhouse.js").read_text()}
Path(out).write_text(json.dumps({"kind": "code", "title": f"Dam wheelhouse {variant} (mojulo trial)", "spec": spec}))
