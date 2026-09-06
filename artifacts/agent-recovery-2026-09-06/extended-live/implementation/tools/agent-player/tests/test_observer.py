import unittest

from observer import modal_candidate
from PIL import Image, ImageDraw


class MenuCueTests(unittest.TestCase):
    def panel(self, border, shift=0):
        image = Image.new("RGB", (1280, 900), (155, 145, 112))
        draw = ImageDraw.Draw(image)
        draw.rectangle((220, 180, 1059, 720), fill=(26, 60, 52))
        for x in (220 - shift, 1059 + shift):
            draw.line((x, 200, x, 700), fill=border)
        return image

    def test_native_and_focused_dialog_borders_both_stop_input(self):
        self.assertTrue(modal_candidate(self.panel((123, 149, 136))))
        self.assertTrue(modal_candidate(self.panel((253, 255, 254), 1)))

    def test_green_obstacle_without_both_dialog_edges_does_not_stop(self):
        image = self.panel((26, 60, 52))
        self.assertFalse(modal_candidate(image))
        ImageDraw.Draw(image).line((220, 200, 220, 700), fill="white")
        self.assertFalse(modal_candidate(image))

    def test_empty_scene_does_not_stop(self):
        self.assertFalse(
            modal_candidate(Image.new("RGB", (1280, 900), (155, 145, 112)))
        )
