"""Timing-only overlays: source pose tables and their image hashes stay immutable."""
import hashlib
import bpy

FPS = 30
FRAMES = {
    'rivet': [1, 5, 9, 13, 16, 22, 24, 26, 28, 40, 42, 44, 55, 56, 57, 66],
    'sable': [1, 5, 9, 12, 15, 21, 24, 27, 39, 41, 42, 44, 55, 56, 57, 66],
    'kest':  [1, 6, 10, 14, 17, 23, 25, 27, 39, 41, 43, 45, 56, 57, 58, 67],
}


def holds(pilot):
    f = FRAMES[pilot]
    peak = 9 if pilot == 'rivet' else 8
    return {4: 1, 5: 4, peak: 10, 12: 9}


def action(arm, rows, pilot, reference_dir, apply_row):
    scene = bpy.context.scene
    frames = FRAMES[pilot]
    scene.render.fps = FPS
    scene.frame_start, scene.frame_end = 1, frames[-1]
    events = []
    for row, frame in zip(rows, frames):
        assert hashlib.sha256((reference_dir / row['image']).read_bytes()).hexdigest() == row['image_sha256']
        events.append((frame, row))
        if row['key'] in holds(pilot):
            events.append((frame + holds(pilot)[row['key']], row))
    for frame, row in sorted(events, key=lambda item: item[0]):
        apply_row(arm, row)
        for bone in arm.pose.bones:
            for path in ('rotation_euler', 'location', 'scale'):
                bone.keyframe_insert(data_path=path, frame=frame, group=bone.name)
    act = arm.animation_data.action
    act.name = 'drop_land'
    peak = frames[8 if pilot == 'rivet' else 7]
    for layer in act.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    keys = curve.keyframe_points
                    secondary = any(name in curve.data_path for name in ('tail.', 'ear.', 'crest', 'hand.'))
                    for i, key in enumerate(keys):
                        key.interpolation = 'BEZIER'
                        key.handle_left_type = key.handle_right_type = 'FREE'
                        x, y = key.co
                        left = (x - keys[i-1].co.x) / 3 if i else 1
                        right = (keys[i+1].co.x - x) / 3 if i+1 < len(keys) else 1
                        key.handle_left = (x - left * (.65 if secondary else 1), y)
                        key.handle_right = (x + right * (1.55 if secondary else 1), y)
                        if x == peak and i and 'rotation_euler' in curve.data_path:
                            delta = y - keys[i-1].co.y
                            key.handle_left.y += delta * .08
                        if x in (frames[3] + 1, frames[4] + 4):
                            key.interpolation = 'LINEAR'
                    curve.update()
    return act


def receipt(pilot):
    f = FRAMES[pilot]
    peak = 9 if pilot == 'rivet' else 8
    return {'fps': FPS, 'duration_seconds': (f[-1]-1)/FPS, 'key_frames': f,
            'hold_frames': {str(k): [f[k-1], f[k-1]+n] for k,n in holds(pilot).items()},
            'beat_samples': {'brace': f[3]+.5, 'impact': f[4]+2,
                             'triumph': f[peak-1]+5, 'flourish': f[11]+4.5,
                             'settle': f[-1]},
            'settle_seconds': (f[-1]-f[-2])/FPS,
            'source_pose_values_unchanged': True,
            'easing': 'flat Bezier endpoints; accessory acceleration delayed within each interval; 8-percent incoming rotation handle overshoot at triumph; linear impact/rebound'}
