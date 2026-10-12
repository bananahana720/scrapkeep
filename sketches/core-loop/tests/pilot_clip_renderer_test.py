"""Renderer regression checks; AST-load production functions without Blender."""
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools/blender'))
from check_pilot_clip_cells import renderer_functions


class Frames(unittest.TestCase):
    def setUp(self):
        self.pick = renderer_functions()['clip_frames']

    def test_held_contact_and_note_changes(self):
        poses = [0, 1, 2, 2, 2, 2, 3, 3, 3, 4, 4, 4, 4, 4, 0]
        keys = [{'frame': i, 'torso': {'pitch': pose}, 'note': 'observation %d' % i}
                for i, pose in enumerate(poses, 1)]
        table = {'clips': {'cast_line': {'keys': keys, 'contact': {'frame': 5}}}}
        self.assertEqual(self.pick('cast_line', SimpleNamespace(frame_range=(0, 14)), table, False), [1, 2, 3, 10, 15])

    def test_contact_note_without_metadata(self):
        keys = [{'frame': i, 'torso': {'pitch': i}, 'note': 'contact' if i == 3 else 'pose'}
                for i in range(1, 8)]
        table = {'clips': {'cast_line': {'keys': keys}}}
        self.assertIn(3, self.pick('cast_line', SimpleNamespace(frame_range=(0, 6)), table, False))

    def test_scarce_beats_keep_contact(self):
        keys = [{'frame': 1, 'pose': 'rest'}, {'frame': 6, 'torso': {'pitch': 8}},
                {'frame': 16, 'pose': 'rest'}]
        table = {'clips': {'cast_line': {'keys': keys, 'contact': {'frame': 6}}}}
        chosen = self.pick('cast_line', SimpleNamespace(frame_range=(0, 15)), table, False)
        self.assertEqual(len(chosen), 5)
        self.assertIn(6, chosen)
        self.assertEqual((chosen[0], chosen[-1]), (1, 16))

    def test_loops_hide_kind_and_show_seam(self):
        action = SimpleNamespace(frame_range=(0, 126))
        self.assertEqual(self.pick('idle_loop', action, None, True), [1, 33, 64, 95, 127])


class Images(unittest.TestCase):
    def test_bad_reads_name_file(self):
        # Fake the Blender image API, including a lazy-decoded image with no pixels.
        for kind in ('missing', 'empty_file', 'decode_failure', 'empty_image', 'wrong_size', 'no_pixels'):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as folder:
                path = Path(folder) / (kind + '.png')
                if kind != 'missing':
                    path.write_bytes(b'' if kind == 'empty_file' else b'bad png')
                removed = []
                image = SimpleNamespace(size=(480, 384), pixels=SimpleNamespace(
                    foreach_get=lambda values: None), channels=4, has_data=True)
                if kind == 'empty_image': image.size = (0, 0)
                if kind == 'wrong_size': image.size = (10, 10)
                if kind == 'no_pixels': image.has_data = False
                def read(_):
                    if kind == 'decode_failure': raise RuntimeError('decode failed')
                    return image
                scope = renderer_functions()
                scope['bpy'] = SimpleNamespace(data=SimpleNamespace(images=SimpleNamespace(load=read, remove=removed.append)))
                with self.assertRaisesRegex(RuntimeError, str(path)):
                    scope['load'](path)
                if kind in ('empty_image', 'wrong_size', 'no_pixels'):
                    self.assertEqual(removed, [image])


if __name__ == '__main__':
    unittest.main()
