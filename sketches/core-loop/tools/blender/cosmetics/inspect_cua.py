"""Independent standard-library GLB/PNG inventory and rerun comparison.

python3 inspect_cua.py --compare /tmp/scrapkeep-cua-rerun --out <receipt.json>
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zlib

ASSETS = Path(__file__).resolve().parents[3]/"assets/cosmetics"
EXPECTED = ["salt_skip", "ink_stitch", "plum_curl", "forge_chips", "moth_tuft", "rose_wash",
            "sable_cable", "rivet_swarf", "kest_fuse_smoke", "tarn_claw_marks", "tally_punch_tape",
            "cannon_recital", "any_downbeat"]


def glb(path):
    data = path.read_bytes()
    assert data[:4] == b"glTF" and struct.unpack_from("<I",data,8)[0] == len(data), path
    n = struct.unpack_from("<I",data,12)[0]
    return json.loads(data[20:20+n])


def png(path):
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n",path
    pos,parts,size = 8,[],None
    while pos < len(data):
        n = struct.unpack_from(">I",data,pos)[0]
        kind,body = data[pos+4:pos+8],data[pos+8:pos+8+n]
        assert zlib.crc32(kind+body) == struct.unpack_from(">I",data,pos+8+n)[0],path
        if kind == b"IHDR":
            size = struct.unpack_from(">II",body)
        if kind == b"IDAT":
            parts.append(body)
        pos += 12+n
    assert max(size) <= 2048,path
    assert len(zlib.decompress(b"".join(parts))) == size[1]*(size[0]*4+1),path
    return size


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--compare",type=Path)
    parser.add_argument("--out",type=Path)
    parser.add_argument("--previews",type=Path)
    args = parser.parse_args()
    files,rows = [],[]
    for path in sorted(ASSETS.rglob("*")):
        if not path.is_file() or path.suffix in (".import",".uid"):
            continue
        rel = str(path.relative_to(ASSETS))
        row = {"path":rel,"bytes":path.stat().st_size,"sha256":hashlib.sha256(path.read_bytes()).hexdigest()}
        if args.compare:
            other = args.compare/rel
            assert other.is_file() and other.read_bytes() == path.read_bytes(),"rerun differs: "+rel
        if path.suffix == ".png":
            row["dimensions_px"] = png(path)
        files.append(row)
    assert len(files)==42,(len(files),"expected 42 authored assets")
    for name in EXPECTED:
        path = ASSETS/"trails"/("trail_"+name+".glb")
        data = glb(path)
        triangles = vertices = surfaces = 0
        for mesh in data["meshes"]:
            for prim in mesh["primitives"]:
                vertices += data["accessors"][prim["attributes"]["POSITION"]]["count"]
                triangles += data["accessors"][prim["indices"]]["count"]//3
                surfaces += 1
        assert (triangles,vertices,surfaces)==(2,4,1),path
        assert (triangles*24 <= 48 and vertices*24 <= 96 and surfaces <= 1),path
        assert len(data["materials"])==1 and data["materials"][0]["name"]=="fx_neutral",path
        assert data["materials"][0]["alphaMode"]=="BLEND",path
        assert len(data["images"])==1 and data["images"][0]["uri"]=="../textures/trail_atlas.png",path
        assert len(data["animations"])==1 and data["animations"][0]["channels"],path
        rows.append({"id":"trail_"+name,"triangles":triangles,"vertices":vertices,"surfaces":surfaces,
            "selected_24_triangles":triangles*24,"selected_24_vertices":vertices*24,"batched_draw_target":1,
            "clip":data["animations"][0]["name"]})
    previews = []
    if args.previews:
        for kind,count in [("trails",13),("decals",10),("paints",6)]:
            doc = json.loads((args.previews/("preview_"+kind+".json")).read_text())
            doc = [r for r in doc if r["id"].startswith("trail_" if kind=="trails" else "decal_" if kind=="decals" else "companion_paint_")]
            assert len(doc)==count,(kind,len(doc))
            for entry in doc:
                assert len(entry["images"])==(5 if kind=="trails" else 3),entry
                for name in entry["images"]:
                    path = args.previews/name
                    assert path.is_file() and path.stat().st_size>1000,path
                    previews.append({"path":name,"bytes":path.stat().st_size,"sha256":hashlib.sha256(path.read_bytes()).hexdigest()})
        assert len(previews)==113,len(previews)
    result = {"verdict":"PASS","asset_files":files,"budgets":rows,"rerun_identical":bool(args.compare),
        "previews":previews,"limits":"one draw requires later MultiMesh/card batching; shell/companion total budgets and native threat fade require the wiring unit"}
    if args.out:
        args.out.write_text(json.dumps(result,indent=2)+"\n")
    for row in files:
        print("FILE",row["path"],row["bytes"])
    for row in rows:
        print("BUDGET",row["id"],"2 T / 4 V / 1 surface; 24 cards 48 T / 96 V / 1 batched draw")
    print("CUA_INSPECT: PASS (%d files; rerun %s; %d previews)" % (len(files),"byte-identical" if args.compare else "not compared",len(previews)))


if __name__=="__main__":
    main()
