"""Run through Blender's --python with arguments after --."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import bpy
from mathutils import Vector
import kit


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def memory_scope():
    group = next(line.split(":", 2)[2] for line in Path("/proc/self/cgroup").read_text().splitlines() if line.startswith("0::"))
    root = Path("/sys/fs/cgroup") / group.lstrip("/")
    limits = {key: (root / key).read_text().strip() for key in ("memory.max", "memory.swap.max")}
    if any(value == "max" for value in limits.values()) or int(limits["memory.max"]) > 20 * 1024**3 or int(limits["memory.swap.max"]) > 2 * 1024**3:
        raise RuntimeError("Run Blender in the documented MemoryMax=20G / MemorySwapMax=2G user scope")
    return {"cgroup": group, **limits}


def reserve_output(destination):
    path = Path(destination).absolute()
    if os.path.lexists(path):
        raise FileExistsError(f"Output already exists; nothing changed: {path}")
    path.mkdir(parents=True, exist_ok=False)
    return path


def inspect_glb(file, budget):
    result = subprocess.run(["node", str(HERE.parents[1] / "scripts/asset-inspect.mjs"), str(file), "--max-tris", str(budget), "--json"], capture_output=True, text=True, check=False)
    if result.returncode:
        raise RuntimeError(f"AT-01 rejected {file}: {result.stdout} {result.stderr}")
    report = json.loads(result.stdout)
    if report["status"] != "pass":
        raise RuntimeError("AT-01 returned no budget pass")
    return report


def export(collection, directory, metadata):
    bpy.context.view_layer.update()
    measured = kit.geometry(collection)
    budget = 6000 if metadata["lod"] == "detailed" else 3000
    if measured["triangles"] > budget:
        raise RuntimeError(f"Generated geometry exceeds {budget}: {measured}")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = next(iter(collection.objects))
    stem = f'{metadata["fixture"]}-{metadata["lod"]}'
    blend = directory / (stem + ".blend")
    glb = directory / (stem + ".glb")
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_animations=False, export_skins=False, export_morph=False, export_extras=True, export_yup=True)
    report = inspect_glb(glb, budget)
    actual = report["assembly"]["triangles"]
    if actual != measured["triangles"]:
        raise RuntimeError(f"Export count changed: {actual} != {measured['triangles']}")
    (directory / (stem + ".inspection.json")).write_text(json.dumps(report, indent=2) + "\n")
    return {**metadata, **measured, "budget_triangles": budget, "exported_triangles": actual, "primitives": report["files"][0]["inventory"]["primitives"], "materials": report["files"][0]["inventory"]["materials"], "components": sorted(o.name for o in collection.objects), "blend": blend.name, "glb": glb.name}


def studio_material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = 0.8
    return mat


def contact_sheet(path, entries):
    kit.clear()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 6
    scene.render.resolution_x = 1500
    scene.render.resolution_y = 1500
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.10, 0.15, 0.16, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.5
    camera_data = bpy.data.cameras.new("Studio.Camera")
    camera = bpy.data.objects.new("Studio.Camera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = (0, -16, 8)
    camera.rotation_euler = (Vector((0, 0, 0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 11.0
    scene.camera = camera
    up = Vector((0, 1 / math.sqrt(5), 2 / math.sqrt(5)))
    facing = camera.rotation_euler.to_quaternion()
    ink = studio_material("Studio.Label", (0.85, 0.85, 0.7))
    muted = studio_material("Studio.Subtitle", (0.30, 0.60, 0.59))

    def label(body, x, vertical, size, mat):
        curve = bpy.data.curves.new("Studio.Label", "FONT")
        curve.body = body
        curve.size = size
        curve.align_x = "CENTER"
        curve.materials.append(mat)
        obj = bpy.data.objects.new("Studio.Label", curve)
        scene.collection.objects.link(obj)
        obj.location = Vector((x, 0, 0)) + up * vertical
        obj.rotation_euler = facing.to_euler()

    label("FORM / FIT", 0, 4.7, 0.36, ink)
    label("STATIC FUR + ACCESSORY KIT  /  TWO NEUTRAL FIXTURES", 0, 4.35, 0.12, muted)
    for entry in entries:
        collection, _ = kit.build(entry["fixture"], entry["lod"])
        x = -2.1 if entry["fixture"] == "broad" else 2.1
        vertical = 1.85 if entry["lod"] == "detailed" else -2.6
        pivot = bpy.data.objects.new("Studio.Placement", None)
        scene.collection.objects.link(pivot)
        pivot.location = Vector((x, 0, -1.55)) + up * vertical
        pivot.rotation_euler.z = math.radians(-18 if entry["fixture"] == "broad" else 18)
        for obj in collection.objects:
            obj.parent = pivot
        label(f'{entry["fixture"].upper()} / {entry["lod"].upper()}', x, vertical - 1.55, 0.17, ink)
        label(f'{entry["exported_triangles"]:,} TRIANGLES  |  STATIC MESH', x, vertical - 1.81, 0.11, muted)
    for name, location, energy in (("Key", (-5, -8, 10), 2.2), ("Fill", (6, -4, 4), 0.8), ("Rim", (0, 6, 6), 1.1)):
        data = bpy.data.lights.new("Studio." + name, "SUN")
        data.energy, data.angle = energy, 0.3
        obj = bpy.data.objects.new("Studio." + name, data)
        scene.collection.objects.link(obj)
        obj.location = location
        obj.rotation_euler = (-Vector(location)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def generate(destination):
    limits = memory_scope()
    output = reserve_output(destination)
    entries = []
    for fixture in kit.FIXTURES:
        for lod in kit.LODS:
            kit.clear()
            collection, metadata = kit.build(fixture, lod)
            entries.append(export(collection, output, metadata))
    for fixture in kit.FIXTURES:
        counts = {e["lod"]: e["exported_triangles"] for e in entries if e["fixture"] == fixture}
        if counts["reduced"] >= counts["detailed"]:
            raise RuntimeError("Reduced LOD must have fewer triangles")
    contact_sheet(output / "contact-sheet.png", entries)
    manifest = {"schema_version": 1, "blender": bpy.app.version_string, "units": "metres; Blender Z up, front -Y; glTF Y up", "memory_scope": limits, "provenance": "Original locally authored procedural geometry for Scrapkeep AT-02. No external assets or paid generation. No public license grant.", "limits": {"engine_import": "not_run", "human_acceptance": "not_measured", "performance": "not_measured", "fit": "Only the documented dimension envelope and two neutral fixtures; no rigging, deformation or universal garment fit."}, "assemblies": entries, "sources": {p.name: digest(p) for p in sorted(HERE.iterdir()) if p.suffix in (".py", ".md", ".sh")}, "files": {p.name: digest(p) for p in sorted(output.iterdir()) if p.is_file()}}
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("ASSET_KIT_OUTPUT", output)
    print("ASSET_KIT_COUNTS", json.dumps({f'{e["fixture"]}-{e["lod"]}': e["exported_triangles"] for e in entries}))
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    generate(args.output)
