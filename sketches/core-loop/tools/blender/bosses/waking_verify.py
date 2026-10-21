"""Inspect exported budgets; make disposable missing-node/clip GLB fixtures.

python sketches/core-loop/tools/blender/bosses/waking_verify.py --fixtures /tmp/wak-fixtures
Add --rebuild /tmp/waking-rebuild to require byte-identical headless rebuilds.
Add --previews artifacts/local/dress-preview/WAK/accepted to require every view/clip.
Add --preview-rebuild PATH to compare rendered PNGs except Blender timing text.
Writes only the explicit scratch fixture directory, never a source GLB.
"""

import argparse
import hashlib
import json
from pathlib import Path
import struct

ROOT=Path(__file__).resolve().parents[5]
DEFAULT=ROOT/"sketches/core-loop/assets/models/bosses"
FILES=("boss_waking_base.glb","boss_waking_kit.glb")
CLIPS={"sleeping","wake","pulse_warn","pulse","floor_warn","floor_drop",
       "floor_warn_seam","floor_drop_seam","floor_warn_bedrock","floor_drop_bedrock",
       "core_open","pit_defeat"}
VOLATILE_PNG_TEXT={b"Date",b"RenderTime",b"cycles.ViewLayer.total_time",
                   b"cycles.ViewLayer.render_time",b"cycles.ViewLayer.synchronization_time"}


def stable_png(blob):
    """Compare all encoded pixels and PNG fields except Blender's timing text."""
    assert blob[:8]==b"\x89PNG\r\n\x1a\n"
    stable=bytearray(blob[:8])
    at=8
    while at<len(blob):
        size=struct.unpack_from(">I",blob,at)[0]
        kind=blob[at+4:at+8]
        data=blob[at+8:at+8+size]
        if not (kind==b"tEXt" and data.split(b"\0",1)[0] in VOLATILE_PNG_TEXT):
            stable.extend(blob[at:at+12+size])
        at+=12+size
    assert at==len(blob)
    return bytes(stable)


def decode(blob):
    assert struct.unpack_from("<III",blob,0)==(0x46546c67,2,len(blob))
    size=struct.unpack_from("<I",blob,12)[0]
    return json.loads(blob[20:20+size]),blob[20+size:]


def encode(gltf,binary_chunk):
    text=json.dumps(gltf,separators=(",",":"),ensure_ascii=False).encode()
    text+=b" "*((-len(text))%4)
    return struct.pack("<III",0x46546c67,2,20+len(text)+len(binary_chunk))+struct.pack("<II",len(text),0x4e4f534a)+text+binary_chunk


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--models",type=Path,default=DEFAULT)
    parser.add_argument("--fixtures",type=Path)
    parser.add_argument("--rebuild",type=Path)
    parser.add_argument("--previews",type=Path)
    parser.add_argument("--preview-rebuild",type=Path)
    args=parser.parse_args()
    if args.preview_rebuild and not args.previews:
        parser.error("--preview-rebuild requires --previews")
    for index,name in enumerate(FILES):
        blob=(args.models/name).read_bytes()
        gltf,_=decode(blob)
        assert {a["name"] for a in gltf["animations"]}==CLIPS
        assert len({n["name"] for n in gltf["nodes"]})==len(gltf["nodes"])
        assert {m["name"] for m in gltf.get("materials",[])}<={"ancient_enamel","dark_joint","glass","signal_surface"}
        counts=[0,0,0]
        for node in gltf["nodes"]:
            if "mesh" not in node: continue
            for p in gltf["meshes"][node["mesh"]]["primitives"]:
                counts[0]+=gltf["accessors"][p["indices"]]["count"]//3
                counts[1]+=gltf["accessors"][p["attributes"]["POSITION"]]["count"]
                counts[2]+=1
        caps=(10000,9600,32) if index==0 else (4000,4000,18)
        assert all(0<n<=cap for n,cap in zip(counts,caps))
        print("WAK_VERIFY",name,"bytes="+str(len(blob)),"T/V/D="+str(counts),"sha256="+hashlib.sha256(blob).hexdigest())
        if args.rebuild:
            assert blob==(args.rebuild/name).read_bytes(),name+" rebuild changed bytes"
            print("WAK_REBUILD",name,"BYTE_IDENTICAL")
    if args.fixtures:
        for variant in ("positive","missing-node","missing-clip"):
            target=args.fixtures/variant
            target.mkdir(parents=True,exist_ok=True)
            for name in FILES:
                blob=(args.models/name).read_bytes()
                if name==FILES[1] and variant!="positive":
                    gltf,binary=decode(blob)
                    if variant=="missing-node":
                        selected=[n for n in gltf["nodes"] if n["name"]=="CoreShutter1"]
                        assert len(selected)==1
                        selected[0]["name"]="BROKEN_CoreShutter1"
                    else:
                        gltf["animations"]=[a for a in gltf["animations"] if a["name"]!="pulse_warn"]
                        assert len(gltf["animations"])==11
                    blob=encode(gltf,binary)
                (target/name).write_bytes(blob)
            print("WAK_FIXTURE",variant,target)
    if args.previews:
        manifest=json.loads((args.previews/"manifest.json").read_text())
        assert manifest["renderer"]=="Blender Cycles CPU" and manifest["samples"]==8
        assert manifest["reference_ball_diameter_metres"]==2 and manifest["arena_radius_metres"]==36
        for record in manifest["models"]:
            assert hashlib.sha256((args.models/record["file"]).read_bytes()).hexdigest()==record["sha256"]
        for frame in manifest["frames"]:
            path=args.previews/frame["image"]
            assert path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest()==frame["sha256"]
            if frame["clip"] is None and "floor_metres" not in frame:
                for name,control in frame["controls"].items():
                    if name.startswith("Collar"):
                        assert abs(abs(control["quaternion"][0])-1)<1e-5 and max(abs(v) for v in control["quaternion"][1:])<1e-5, "Stale collar rotation: "+frame["image"]
                    if name.startswith("CoreLive"):
                        assert max(control["scale"])<.002, "Idle mint exposed: "+frame["image"]
            if frame["clip"]=="pulse_warn":
                assert abs(frame["controls"]["PressureLip0"]["location"][2]-1.55)<.002
            if frame["clip"]=="core_open":
                assert abs(frame["controls"]["CoreLive"]["scale"][0]-1)<.002
        for name in FILES:
            for view in ("front","side","three_quarter"):
                assert any(f["image"]==Path(name).stem+"_"+view+".png" for f in manifest["frames"])
            actual={f["clip"] for f in manifest["frames"] if f["assets"]==[name] and f["clip"]}
            assert actual==CLIPS,(name,actual)
        assert {f.get("floor_metres") for f in manifest["frames"] if "floor_metres" in f}=={12,8,4,0}
        print("WAK_PREVIEWS",len(manifest["frames"]),"HASHED_FRAMES_ALL_GLB_VIEWS_AND_CLIPS")
        if args.preview_rebuild:
            byte_identical=0
            for frame in manifest["frames"]:
                original=(args.previews/frame["image"]).read_bytes()
                rebuilt=(args.preview_rebuild/frame["image"]).read_bytes()
                byte_identical+=original==rebuilt
                assert stable_png(original)==stable_png(rebuilt), "Preview rebuild changed pixels or stable fields: "+frame["image"]
            print("WAK_PREVIEW_REBUILD",len(manifest["frames"]),"IDENTICAL_PIXELS_AND_STABLE_FIELDS", "byte_identical="+str(byte_identical), "allowed_difference=Blender_Date_and_render_timing_text")
    print("waking_verify: PASS")


if __name__=="__main__":
    main()
