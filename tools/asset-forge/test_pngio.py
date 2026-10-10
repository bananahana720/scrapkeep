import subprocess
import tempfile
import unittest
from pathlib import Path

import pngio

HERE = Path(__file__).resolve().parent


class PngIoTest(unittest.TestCase):
    def test_round_trip(self):
        rows = [[(x * 40, y * 60, (x + y) * 20, 255 if x % 2 else 0) for x in range(5)] for y in range(3)]
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "t.png"
            pngio.write(path, 5, 3, rows)
            self.assertEqual(pngio.read(path), (5, 3, rows))

    def test_reads_what_imagemagick_writes(self):
        # A filtered RGB image and a 16-bit greyscale one, each checked pixel by pixel against
        # ImageMagick's own reading of the same file.
        with tempfile.TemporaryDirectory() as tmp:
            for name, args in (("rgb.png", ["plasma:fractal", "-seed", "7", "PNG24:"]),
                               ("grey16.png", ["gradient:", "-colorspace", "Gray", "-depth", "16", "PNG48:"])):
                path = Path(tmp) / name
                spec, *rest = args
                subprocess.run(["magick", "-size", "9x7", spec, *rest[:-1], rest[-1] + str(path)], check=True)
                w, h, rows = pngio.read(path)
                self.assertEqual((w, h), (9, 7))
                txt = subprocess.run(["magick", str(path), "-depth", "8", "txt:-"], check=True,
                                     capture_output=True, text=True).stdout
                for line in txt.splitlines()[1:]:
                    xy, rest = line.split(":", 1)
                    x, y = map(int, xy.split(","))
                    hexcol = rest.split("#", 1)[1][:6]
                    want = tuple(int(hexcol[i:i + 2], 16) for i in (0, 2, 4))
                    self.assertEqual(rows[y][x][:3], want, (name, x, y))


if __name__ == "__main__":
    unittest.main()
