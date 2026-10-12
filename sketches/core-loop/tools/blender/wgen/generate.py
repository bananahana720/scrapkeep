"""Seeded Blender curve -> existing Scrapkeep stamp/recipe rows. No mesh import required."""
import argparse
import json
import math
from pathlib import Path
import random
import sys

import bpy
from mathutils import Vector


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n")


def row(name, element, landform, at, size, stamp="", verb="roll", fact="", recipe=None, yaw=0):
    return dict(id=name, element=element, landform=landform, society="none", at=at,
                size=size, stamp=stamp, verb=verb, ride_fact=fact,
                recipe=("" if element == "ground" else "greybox:" + element) if recipe is None else recipe,
                yaw_deg=yaw, y=None, home="", hole=False, budget="landform",
                routes=[], fragment="")


def build(seed, revision):
    rng = random.Random(seed)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    amplitude = rng.uniform(240, 330)
    descent = rng.uniform(48, 78)
    phase = rng.uniform(-0.18, 0.18)
    wash_width = 36 if revision == 2 else 64
    bowl_width = 44 if revision == 2 else 150
    runout_width = 40 if revision == 2 else 90
    lip_indices = (2, 4, 6, 8, 10, 12, 14) if revision == 2 else (3, 8, 13)
    controls = 17
    curve = bpy.data.curves.new("wash_spine", "CURVE")
    curve.dimensions = "3D"
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(controls - 1)
    for i, point in enumerate(spline.bezier_points):
        t = i / (controls - 1)
        angle = 2 * math.pi * t + phase
        x = amplitude * (math.sin(angle) - math.sin(phase))
        z = -690 + 1280 * t
        y = 24 + descent * (800 - z) / 1600
        tangent = Vector((amplitude * 2 * math.pi * math.cos(angle), -descent * .8, 1280)) / (controls - 1) / 3
        point.co = Vector((x, y, z))
        point.handle_left_type = point.handle_right_type = "FREE"
        point.handle_left = point.co - tangent
        point.handle_right = point.co + tangent
    obj = bpy.data.objects.new("wash_spine", curve)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.update()
    points = [[round(p.co.x, 3), round(p.co.z, 3)] for p in spline.bezier_points]
    rows = [row("plain", "ground", "slickrock", [0, 0], [1600, 24, 1600], "plateau"),
            row("bajada", "ground", "slickrock", [0, 0], [1600, round(descent, 3), 1600], "ramp")]
    # The pieces overlap their open ends; the broad floor remains rollable at each join.
    for i, (a, b) in enumerate(zip(points, points[1:])):
        dx, dz = b[0] - a[0], b[1] - a[1]
        center = [round((a[0] + b[0]) / 2, 3), round((a[1] + b[1]) / 2, 3)]
        rows.append(row(f"wash_{i:02}", "flow_line", "arroyo", center,
                        [round(math.hypot(dx, dz) + 36, 3), 1.5, wash_width], "wash", fact="ride_chute",
                        yaw=round(math.degrees(math.atan2(dx, dz)), 3)))
    # Both a broad, shallow bowl and a drop use the shipped stamp-only greybox rule.
    for i in (5, 10):
        rows.append(row(f"bowl_{i}", "bowl", "slickrock", points[i], [180, 2.0, bowl_width], "bowl", "pump", "ride_bowl"))
    for i in lip_indices:
        a, b = points[i-1], points[i+1]
        yaw = math.degrees(math.atan2(b[0]-a[0], b[1]-a[1]))
        size = [80, 12, 50] if revision == 2 else [44, 2.2, 24]
        rows.append(row(f"lip_{i}", "kicker", "mesa_rim", points[i], size, "spire", "launch", "kicker_launch", yaw=round(yaw, 3)))
    for i in (6, 11):
        rows.append(row(f"runout_{i}", "drop", "dry_wash", points[i], [100, 1.8, runout_width], "bowl", "drop", "ride_drop"))
    # Side mesas never intersect the reserved wash envelope.
    for side in (-1, 1):
        for k in range(4):
            z = -550 + 340 * k + rng.uniform(-35, 35)
            x = side * rng.uniform(525, 645)
            rows.append(row(f"mesa_{side+1}_{k}", "bank", "mesa_rim", [round(x,3),round(z,3)],
                            [rng.randrange(140,210), rng.randrange(25,55), rng.randrange(130,190)], "mesa", "bank", "ride_bowl"))
    if revision == 2:
        # This base has no landmark recipe asset or landmark placement. A ground stamp
        # supplies the actual skyline mass instead of relying on the header's sight point.
        rows.append(row("hero_spire", "ground", "spire", [points[-1][0], points[-1][1]+90], [60,160,60], "spire"))
    # Genuine post fields cover the outskirts too; density ignores the plain and bajada.
    for iz,z in enumerate((-600,-200,200,600)):
        for ix,x in enumerate((-600,-200,200,600)):
            rows.append(row(f"hoodoos_{ix}_{iz}", "anchor_field", "hoodoo_field", [x,z], [380,18,380], verb="swing"))
    marks = ["drop_in", "wash_05", "wash_10", "landmark"]
    routes = [dict(id="main", **{"from":"drop_in","to":"landmark"}, via=[f"wash_{i:02}" for i in range(16)])]
    for r in rows:
        if r["id"].startswith("wash_"): r["routes"] = ["main"]
    homes = []
    for i,enemy,pack in [(4,"chaser","run_down"),(9,"lobber","grounded"),(14,"mag_trapper","grounded")]:
        site=rows[2+i]
        site["home"]=f"home_{i}"
        homes.append(dict(id=f"home_{i}", enemy=enemy,site=site["id"],landform=site["landform"],
                          advantage="The wash aims arrivals down a long lunge lane.",
                          counter="Bank out onto the open bajada and return from the side.",
                          reinforce=dict(from_tier=1,every_s=30,max_alive=4,pack=pack),
                          **{"break":dict(by="ram",hp=60,scrap=12)},stops_kind=True,dormant=False))
    beacon=points[-1]
    spire_z = beacon[1] + 90
    sight_height = round(24 + descent * (800-spire_z) / 1600 + 160, 3) if revision == 2 else 220
    landmark=dict(id="survey_spire",kind="spire",at=[beacon[0],beacon[1]+90],size=[36,160,36],yaw_deg=0,
                  recipe="landmark_spire",budget="hero_landmark",sight_top=[beacon[0],sight_height,spire_z],sight_share=.85,
                  beacon=beacon,reach_m=30,warden=dict(family="reactor",mounting="dam_face",anchor=[beacon[0],40,beacon[1]],
                  path=[],hardpoints=3,harpoon_anchor=True),bay_dock=dict(at=[beacon[0],beacon[1]-100],facing_deg=0),
                  gate_slots=[dict(at=[beacon[0]+d,beacon[1]-60],facing_deg=0) for d in (-16,0,16)],
                  light="ancient_beam",music="landmark_hum",fragment="")
    # Off-line event footprints keep the measured line open.
    events=[]
    for name,kind,family,site in [("mesa_slough","collapse","natural","mesa_0_0"),
                                  ("vent_burst","boiler_burst","industrial","mesa_2_2")]:
        events.append(dict(id=name,kind=kind,family=family,site=site,trigger=dict(on="clock_tier",value=3),weight=1,
                           telegraph=dict(lead_s=6,form="boiler_pressure" if family=="industrial" else "cave_dust",on_bar=True),
                           live_s=12,effect=dict(depth_m=2) if kind=="collapse" else dict(hazard="steam_cone",hazard_m=[16,8],damage=6),
                           route_change=dict(closes=[],opens=[]),hold_clear_m=20,cooldown_s=90,once=True,
                           music_cue=dict(telegraph="riser_natural",land="drop_flood")))
    activities=[dict(id="wash_camp",activity="enemy_camp",site="wash_05",at=rows[7]["at"],pack=["chaser"]*3,pay=dict(rarities=["common"])),
                dict(id="west_cache",activity="cracked_cache",site="mesa_0_1",at=[-545,-190],pack=[],pay=dict(rarities=["rare"])),
                dict(id="east_altar",activity="ambush_altar",site="mesa_2_2",at=[545,210],pack=[],pay=dict(rarities=["common","rare"]))]
    park=dict(schema="scrapkeep-park/1",map=f"park_wgen_s{seed}",size_m=1600,time_of_day="golden",
              spawn=dict(at=points[0],heading_deg=round(math.degrees(math.atan2(points[1][0]-points[0][0],80)),3)),
              play_rect=[-780,-780,1560,1560],landmark=landmark,waymarks=marks,routes=routes,park_rows=rows,
              home_rows=homes,event_rows=events,contraption_rows=[],weather_rows=[dict(id="clear",kind="clear",trigger=dict(on="always"),
              lead_s=0,live_s=0,gap_s=0,fog=dict(density=.0005,color="#c69c73"),sky="clear",sound="",music_layer="",event_odds={},handling="none")],
              activity_rows=activities)
    # All six schema-required entries share two generated route variants. Only rivet/kest are measured.
    lines=dict(map=park["map"],stage=1,pilots={})
    for pilot,offset in [("sable",-18),("rivet",-18),("kest",18),("tarn",-18),("tally",18),("cannon",18),("floor",0)]:
        path=["drop_in"]
        for i,p in enumerate(points[1:-1],1):
            path.append([round(p[0]+offset*math.sin(math.pi*i/16),3),p[1]])
            if i in (5,10): path.append(f"wash_{i:02}")
        path.append("landmark")
        if pilot=="floor": lines["floor"]=dict(waypoints=path)
        else: lines["pilots"][pilot]=dict(waypoints=path,bar=dict(band="PARK.md section 8",airborne_share=[.12,.45]))
    return park,lines,dict(seed=seed,revision=revision,amplitude_m=round(amplitude,3),descent_m=round(descent,3),
                           phase_rad=round(phase,4),blender=bpy.app.version_string,curve_controls=controls,curve_samples=len(points),
                           wash_width_m=wash_width,bowl_width_m=bowl_width,runout_width_m=runout_width,launch_lips=len(lip_indices),
                           note="Blender curve control anchors place both stamps and bot waypoints; handles do not affect this export.")


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--seed",type=int,required=True)
    parser.add_argument("--out",type=Path,required=True)
    parser.add_argument("--lines-out",type=Path)
    parser.add_argument("--meta-out",type=Path)
    parser.add_argument("--revision",type=int,choices=[1,2],default=1)
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    park,lines,meta=build(args.seed,args.revision)
    write_json(args.out,park)
    write_json(args.lines_out or args.out.with_name(args.out.stem+"_lines.json"),lines)
    if args.meta_out: write_json(args.meta_out,meta)
    print(f"wgen: seed {args.seed} revision {args.revision}, {len(park['park_rows'])} rows -> {args.out}")


if __name__=="__main__": main()
