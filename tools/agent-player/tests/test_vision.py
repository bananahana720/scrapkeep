import unittest
from pathlib import Path

from PIL import Image, ImageDraw
from vision import detect


class EyeColourTests(unittest.TestCase):
    def synthetic_face(self, eyes):
        image = Image.new("RGB", (1280, 900), (170, 190, 150))
        draw = ImageDraw.Draw(image)
        draw.rectangle((400, 400, 460, 425), fill=(20, 30, 25))
        for x in (416, 442):
            draw.ellipse((x - 3, 410, x + 3, 416), fill=eyes)
        return image

    def test_warm_eyes_survive_but_neutral_and_blue_letters_do_not(self):
        self.assertTrue(detect(self.synthetic_face((250, 231, 161))))
        self.assertFalse(detect(self.synthetic_face((210, 210, 210))))
        self.assertFalse(detect(self.synthetic_face((180, 170, 210))))

    def test_real_nameplate_is_not_an_eye_target(self):
        image = Image.open(Path(__file__).parent / "fixtures/nameplate.jpg")
        targets = detect(image)
        self.assertFalse(
            any(674 <= t["x"] <= 753 and 483 <= t["y"] <= 523 for t in targets)
        )

    def test_four_visible_worker_faces_remain_detectable(self):
        image = Image.open(Path(__file__).parent / "fixtures/workers.jpg")
        targets = detect(image)
        for x, y in ((355.5, 438.5), (429, 445.25), (344.75, 481), (416.75, 478)):
            self.assertTrue(
                any(abs(t["x"] - x) < 3 and abs(t["y"] - y) < 3 for t in targets)
            )
