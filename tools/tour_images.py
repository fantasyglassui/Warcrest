"""The welcome window's tour pictures, made from the website's screenshots.

Each docs/img/<name>.webp (1400x880) is cropped to its top 2:1 part (where the
section's content is) and scaled to 512x256, then saved as an uncompressed
24-bit TGA in Media/Tour/, the format the game reads.

    python3 tools/tour_images.py
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NAMES = ["home", "kills", "raids", "dkp", "profiles"]
W, H = 512, 256


def main():
    out_dir = os.path.join(ROOT, "Media", "Tour")
    os.makedirs(out_dir, exist_ok=True)
    total = 0
    for name in NAMES:
        im = Image.open(os.path.join(ROOT, "docs", "img", name + ".webp")).convert("RGB")
        w, h = im.size
        im = im.crop((0, 0, w, min(h, w // 2))).resize((W, H), Image.LANCZOS)
        path = os.path.join(out_dir, name + ".tga")
        im.save(path, compression=None)
        total += os.path.getsize(path)
        print(path, os.path.getsize(path))
    print("total", total)


if __name__ == "__main__":
    main()
