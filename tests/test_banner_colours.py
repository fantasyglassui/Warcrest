"""Every kind of alert banner has its own colour."""
from harness import Guild


def test_every_banner_kind_has_its_own_colour():
    guild = Guild([("Alice", 1)])
    kinds = guild["Alice"].ns.BANNER_KINDS
    seen = {}
    for k, v in kinds.items():
        c = tuple(round(x, 3) for x in (v.color[1], v.color[2], v.color[3]))
        assert c not in seen, (k, seen.get(c))
        seen[c] = k
    assert len(seen) == 16


def colour(client, kind):
    c = client.ns.BannerColor(kind)
    return tuple(round(c[i] * 255) for i in (1, 2, 3))


def test_you_can_pick_your_own_colour_for_a_banner():
    guild = Guild([("Alice", 1)])
    a = guild["Alice"]
    a.login()
    guild.run(2)
    assert colour(a, "kill") == (0x2e, 0xe3, 0x5a)
    a.ns.PickBannerColor("kill")
    a.run("ColorPickerFrame:Pick(1, 0, 0)")
    assert colour(a, "kill") == (255, 0, 0)
    assert a.ns.db.bannerColors["kill"] == "ff0000"
    # The banner shows in it.
    a.ns.ShowBanner("kill", "Test")
    bar = a.lua.eval("WarcrestBanners")
    assert bar is not None
    # Cancel puts back what was there before the picker opened.
    a.ns.PickBannerColor("kill")
    a.run("ColorPickerFrame:Pick(0, 0, 1)")
    a.run("ColorPickerFrame:Cancel()")
    assert colour(a, "kill") == (255, 0, 0)
    # Right-click or the reset button: Warcrest's colour again.
    a.ns.SetBannerColor("kill", None)
    assert colour(a, "kill") == (0x2e, 0xe3, 0x5a)
    a.ns.PickBannerColor("death")
    a.run("ColorPickerFrame:Pick(0, 1, 0)")
    a.ns.ResetBannerColors()
    assert colour(a, "death") == (0xe8, 0x46, 0x7c)
    assert not a.errors()

