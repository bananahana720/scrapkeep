"""Shared pilot-v1 hand targets, sourced from the shipped shell in Pod space.

The shell GLB is the exported CONTROLS layout, including recipe-specific bank names
and LapBar children. Pose-table control_points are deliberately ignored.
"""
from functools import lru_cache
import json
from pathlib import Path
import struct

from mathutils import Matrix, Quaternion, Vector

SKETCH = Path(__file__).resolve().parents[2]
STANDINS = set()


def grip(side):
    return Vector((.32 if side == 'R' else -.32, .40, .05))


@lru_cache(maxsize=None)
def controls(pilot):
    roster = json.loads((SKETCH / 'src/presentation/clips/roster.json').read_text())
    path = SKETCH / roster['pilots'][pilot]['shell']
    blob = path.read_bytes()
    doc = json.loads(blob[20:20 + struct.unpack_from('<I', blob, 12)[0]])
    nodes = doc['nodes']
    parents = {child: i for i, node in enumerate(nodes) for child in node.get('children', [])}

    def local(node):
        if 'matrix' in node:
            return Matrix([node['matrix'][i:i + 4] for i in range(0, 16, 4)]).transposed()
        q = node.get('rotation', (0, 0, 0, 1))
        return Matrix.LocRotScale(Vector(node.get('translation', (0, 0, 0))),
                                  Quaternion((q[3], *q[:3])), Vector(node.get('scale', (1, 1, 1))))

    found = {}
    for i, node in enumerate(nodes):
        name = node.get('name', '')
        if not (name.startswith('Control.') or name in ('LapBar.R', 'LapBar.L')):
            continue
        matrix = local(node)
        parent = parents.get(i)
        while parent is not None and nodes[parent].get('name') != 'Pod':
            matrix = local(nodes[parent]) @ matrix
            parent = parents.get(parent)
        if parent is None:
            raise ValueError('%s: control %s is not under Pod' % (path, name))
        at = matrix.translation
        found[name.removeprefix('Control.')] = Vector((at.x, -at.z, at.y))
    return found


def control(pilot, name, side='R'):
    points = controls(pilot)
    if name in points:
        return points[name].copy()
    token = (pilot, name)
    if token not in STANDINS:
        print('PILOT_CLIPS_STANDIN %s %s' % token)
        STANDINS.add(token)
    return grip('L' if name.endswith('.L') else side)


def target(pilot, hand, side):
    if 'at' in hand:
        return Vector(hand['at'])
    return control(pilot, hand['control'], side) + Vector(hand.get('offset', (0, 0, 0)))


def planted_targets(pilot, clip, table):
    first = min(clip.get('keys', [{'frame': 1}]), key=lambda key: key['frame'])
    anchor = table.get('anchors', {}).get(first.get('pose'), {})
    start = dict(anchor) if isinstance(anchor, dict) else {}
    start.update(first)
    return {side: target(pilot, start['hand.' + side], side) if 'hand.' + side in start else grip(side)
            for side in clip.get('planted', [])}


@lru_cache(maxsize=None)
def solver(pilot):
    import anim_rivet_drop
    import pilot_tally
    import pilot_cannon
    return {'rivet': anim_rivet_drop.solve_arm, 'sable': anim_rivet_drop.solve_arm,
            'kest': anim_rivet_drop.solve_arm, 'tarn': anim_rivet_drop.solve_arm,
            'tally': pilot_tally.solve_tally_arm, 'cannon': pilot_cannon.shared.solve_arm}[pilot]


def solve(pilot, arm, side, at, wrist=None):
    import bpy
    from anim_rivet_drop import world_hand
    bpy.context.view_layer.update()
    solve_arm = solver(pilot)
    for _ in range(16):
        if (arm.pose.bones['hand.' + side].head - at).length < .00001:
            break
        solve_arm(arm, side, at)
    if wrist is not None:
        world_hand(arm, side, wrist)
    return (arm.pose.bones['hand.' + side].head - at).length
