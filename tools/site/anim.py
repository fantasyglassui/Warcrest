"""docs/img/tour.webp: a looping animation of the main window for the
website's "For guild leaders" section. Renders the demo guild from
tests/render.py (as "Ashen Vanguard") on six pages, 2 seconds each.

    python3 tools/site/anim.py
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tests"))
os.chdir(os.path.join(ROOT, "tests"))

from PIL import Image  # noqa: E402
from render import demo_guild, Renderer  # noqa: E402

PAGES = [("home", None), ("kills", None), ("raids", None), ("dkp", None), ("profiles", None), ("crafters", "recipes")]
SIZE = (1000, 628)
OUT = os.path.join(ROOT, "docs", "img", "tour.webp")


def main():
    guild, me = demo_guild(guild_name="Ashen Vanguard")
    rd = Renderer(me)
    frames = []
    tmp = "/tmp/warcrest-anim.png"
    for tab, view in PAGES:
        me.ns.OpenPanel(tab, view)
        rd.render(me.lua.eval("WarcrestPanel"), tmp)
        frames.append(Image.open(tmp).convert("RGB").resize(SIZE, Image.LANCZOS))
    frames[0].save(OUT, save_all=True, append_images=frames[1:], duration=2000, loop=0, quality=80, method=6)
    print(OUT, os.path.getsize(OUT))


if __name__ == "__main__":
    main()
