"""Every tab draws, and nothing on it sticks out past the edges of the panel."""
import os

import pytest

pytest.importorskip("PIL")
from render import Renderer, demo_guild  # noqa: E402

TABS = ("roster", "events", "recruit", "raids", "raids:plan", "raids:group", "calendar", "raids:progress", "dkp", "wishlist", "kills", "wanted",
        "achievements", "achievements:hunt", "achievements:raid", "achievements:loot", "achievements:guild", "settings", "settings:sounds", "settings:general", "officers", "addon",
        "profiles", "crafters", "crafters:orders", "crafters:cooldowns", "worldbuffs", "groups", "settings:access")


def walk_text(rd, node):
    """Every visible piece of text under node."""
    for k in rd.kids(node):
        if not rd.visible(k):
            continue
        if k["kind"] == "FontString":
            yield k
        elif k["kind"] != "Texture":
            yield from walk_text(rd, k)


def sticking_out(rd, node, bounds, found, in_scroll=False):
    """Text and textures drawn outside bounds. Content in a scrolling area is
    clipped to that area, so it's allowed to run past."""
    for k in rd.kids(node):
        if not rd.visible(k) or not rd.region_shown(k):
            continue
        if k["kind"] in ("Texture", "FontString"):
            if in_scroll:
                continue
            l, t, r, b = rd.rect(k)
            if r - l <= 0 or b - t <= 0:
                continue
            if l < bounds[0] - 4 or t < bounds[1] - 4 or r > bounds[2] + 4 or b > bounds[3] + 4:
                found.append((k["kind"], k["_GetText"], (round(l), round(t), round(r), round(b))))
        else:
            lay = k["_layout"]
            scrolls = lay is not None and lay["scrollChild"] is not None
            sticking_out(rd, k, bounds, found, in_scroll or scrolls)


def outside_parent(rd, node, found, in_scroll=False):
    """Text that runs outside the frame it belongs to (a heading past its card's edge, say)."""
    for k in rd.kids(node):
        if not rd.visible(k) or not rd.region_shown(k):
            continue
        if k["kind"] == "FontString" and not in_scroll:
            l, t, r, b = rd.rect(k)
            pl, pt, pr, pb = rd.rect(node)
            if r - l > 0 and pr - pl > 20 and (l < pl - 4 or r > pr + 4 or t < pt - 4 or b > pb + 4):
                found.append((k["_GetText"], (l, t, r, b), (pl, pt, pr, pb)))
        outside_parent(rd, k, found, in_scroll or k["kind"] == "ScrollFrame")


@pytest.mark.parametrize("tab", TABS)
def test_tab_fits_in_panel(tab, tmp_path):
    guild, me = demo_guild()
    me.ns.OpenPanel(*tab.split(":"))
    rd = Renderer(me)
    panel = me.lua.eval("WarcrestPanel")
    rd.render(panel, os.path.join(tmp_path, tab.replace(":", "-") + ".png"))
    found = []
    sticking_out(rd, panel, rd.rect(panel), found)
    outside_parent(rd, panel, found)
    assert found == [], found
    # One-line text cut short with "...": only item names may be.
    assert [t for t in rd.truncated if "Thunderfury" not in t] == []
    assert me.errors() == []


@pytest.mark.parametrize("tab", TABS)
def test_tab_fits_in_a_bigger_window(tab, tmp_path):
    guild, me = demo_guild()
    me.ns.db.panelWidth, me.ns.db.panelHeight = 1300, 760   # dragged bigger from the corner
    me.ns.OpenPanel(*tab.split(":"))
    rd = Renderer(me)
    panel = me.lua.eval("WarcrestPanel")
    rd.render(panel, os.path.join(tmp_path, tab.replace(":", "-") + "-big.png"))
    l, t, r, b = rd.rect(panel)
    assert (r - l, b - t) == (1300, 760)
    found = []
    sticking_out(rd, panel, (l, t, r, b), found)
    outside_parent(rd, panel, found)
    assert found == [], found
    # One-line text cut short with "...": only item names may be.
    assert [t for t in rd.truncated if "Thunderfury" not in t] == []
    assert me.errors() == []


def test_lists_grow_with_the_window():
    guild, me = demo_guild()
    me.ns.db.panelWidth, me.ns.db.panelHeight = 1300, 760
    me.ns.OpenPanel("officers")
    rd = Renderer(me)
    lists = [k for k in rd.kids(me.lua.eval("WarcrestPanel")) if k["kind"] == "Frame"]
    # The officer log's list fills the extra room: 390 wider and 206 taller than normal
    # (the window is at least 554 high, 34 of it the row of views over the page; its
    # table card is 500 x 412; the scroll area inside is 446 x 383 without the scroll bar).
    page_lists = []
    def walk(node):
        for k in rd.kids(node):
            if k["_template"] == "UIPanelScrollFrameTemplate" and rd.visible(k):
                page_lists.append(k)
            walk(k)
    for f in lists:
        walk(f)
    sizes = {(round(rd.rect(f)[2] - rd.rect(f)[0]), round(rd.rect(f)[3] - rd.rect(f)[1])) for f in page_lists}
    assert (446 + 390, 383 + 206) in sizes, sizes


def test_window_size_setting_scales_panel_and_windows():
    guild, me = demo_guild()
    me.ns.OpenPanel("roster")
    me.ns.ShowAltsWindow()
    me.ns.SetPanelScale(1.25)
    assert me.ns.db.panelScale == 1.25
    me.ns.SetPanelScale(5)      # kept within limits
    assert me.ns.db.panelScale == 1.5
    me.ns.ResetPanelSize()
    assert me.ns.db.panelScale == 1 and me.ns.db.panelWidth is None


def test_kill_columns_can_be_resized():
    guild, me = demo_guild()
    me.ns.OpenPanel("kills")
    rd = Renderer(me)
    me.ns.SetKillColumnWidth("victim", 130)
    assert me.ns.db.killColumns.victim == 130
    me.ns.SetKillColumnWidth("killer", 10)           # can't be squeezed to nothing
    assert me.ns.db.killColumns.killer == 50
    me.ns.SetKillColumnWidth("killer", 900)          # nor push Where (90 at least) off the table
    assert me.ns.db.killColumns.killer == 452 - 12 - 130 - 16 - 92 - 90
    me.ns.SetKillColumnWidth("killer", 100)
    # Rows follow: the victim starts right after the killer column.
    panel = me.lua.eval("WarcrestPanel")
    victim = [fs for fs in walk_text(rd, panel) if fs["_GetText"] == "Ganker"][0]
    # sidebar 150 + 10 margin + 1 card edge + 12 + killer 100 + gap 8
    assert round(rd.rect(victim)[0] - rd.rect(panel)[0]) == 150 + 10 + 1 + 12 + 100 + 8
    found = []
    sticking_out(rd, panel, rd.rect(panel), found)
    assert found == [], found
    assert me.errors() == []


@pytest.mark.parametrize("locale", ("deDE", "frFR", "esES"))
@pytest.mark.parametrize("tab", TABS)
def test_tab_fits_translated(tab, locale, tmp_path):
    """German, French and Spanish text is longer; it still has to fit."""
    guild, me = demo_guild(locale=locale)
    me.ns.OpenPanel(*tab.split(":"))
    rd = Renderer(me)
    panel = me.lua.eval("WarcrestPanel")
    rd.render(panel, os.path.join(tmp_path, tab.replace(":", "-") + ".png"))
    found = []
    sticking_out(rd, panel, rd.rect(panel), found)
    outside_parent(rd, panel, found)
    assert found == [], found
    # One-line text cut short with "...": only item names may be.
    assert [t for t in rd.truncated if "Thunderfury" not in t] == []
    assert me.errors() == []
