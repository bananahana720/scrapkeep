"""Rebuild every basename recipe in a separate headless Blender and compare bytes.

python sketches/core-loop/tools/blender/dig_mechanical/verify_exports.py
"""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

HERE=Path(__file__).resolve().parent
SKETCH=HERE.parents[2]
MODELS=SKETCH/"assets/models/dig_mechanical"
RECEIPTS=SKETCH.parents[1]/"artifacts/local/dress-preview/MDM"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    manifest=json.loads((MODELS/"manifest.json").read_text())
    rows=[]
    with tempfile.TemporaryDirectory(prefix="mdm-rerun-") as tmp:
        for name in sorted(manifest["assets"]):
            original=MODELS/(name+".glb")
            recipe=HERE/(name+".py")
            target=Path(tmp)/(name+".glb")
            cmd=["blender","-b","--threads","2","--python-exit-code","1","-P",str(recipe),"--","--out",str(target)]
            proc=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
            ok=proc.returncode==0 and target.is_file() and original.read_bytes()==target.read_bytes()
            row={"asset":name,"same_bytes":ok,"exit_code":proc.returncode,"sha256":sha(original),"command":cmd,"recipe_sha256":sha(recipe),"kit_sha256":sha(HERE/"kit.py"),"helper_sha256":sha(HERE.parent/"common.py")}
            if not ok:
                row["output"]=proc.stdout
            rows.append(row)
            print("MDM_RERUN",name,"PASS" if ok else "FAIL",flush=True)
    RECEIPTS.mkdir(parents=True,exist_ok=True)
    (RECEIPTS/"determinism-receipt.json").write_text(json.dumps(rows,indent=2)+"\n")
    ok=len(rows)==26 and all(r["same_bytes"] for r in rows)
    print("MDM_DETERMINISM:","PASS" if ok else "FAIL",len(rows),"recipes",flush=True)
    raise SystemExit(0 if ok else 1)


if __name__=="__main__":
    main()
