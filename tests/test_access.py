"""Settings > Accessibility: text size, colour-blind colours, high contrast, banner timing and motion."""
from harness import Guild


def one():
    guild = Guild([("Alice", 1), ("Bob", 3)])
    return guild, guild["Bob"]


def font_size(c, key):
    return c.lua.eval('function(UI, k) local _, size = UI.Fonts[k]:GetFont(); return size end')(c.ns.UI, key)


def test_off_by_default():
    _, bob = one()
    a = bob.ns.Access()
    assert (a.textSize, a.colorblind, a.contrast, a.bannerHold, a.reduceMotion) == (100, False, False, "normal", False)
    assert font_size(bob, "Body") == 12


def test_text_size_changes_every_font_at_once():
    _, bob = one()
    bob.ns.SetAccess("textSize", 120)
    assert font_size(bob, "Body") == 14 and font_size(bob, "Title") == 20
    bob.ns.SetAccess("textSize", 100)
    assert font_size(bob, "Body") == 12


def test_colours_and_contrast():
    _, bob = one()
    C = bob.ns.UI.C
    green, muted = (C.good[1], C.good[2], C.good[3]), C.muted[1]
    bob.ns.SetAccess("colorblind", True)
    assert round(C.good[3], 2) == round(0xe9 / 255, 2)           # good news is blue
    assert bob.ns.AccessKindColor("raid") is not None
    assert bob.ns.AccessChatColor("kill") == "|cff56b4e9"
    assert bob.said("/reload")
    bob.ns.SetAccess("contrast", True)
    assert C.muted[1] > muted
    bob.ns.SetAccess("colorblind", False)
    bob.ns.SetAccess("contrast", False)
    assert (C.good[1], C.good[2], C.good[3]) == green and C.muted[1] == muted
    assert bob.ns.AccessKindColor("raid") is None


def test_saved_colours_apply_before_windows_are_built():
    guild = Guild([("Alice", 1), ("Bob", 3)],
                  setup=lambda c: c.run('WarcrestDB = { access = { colorblind = true, textSize = 120 } }'))
    bob = guild["Bob"]
    assert round(bob.ns.UI.C.bad[1], 2) == round(0xf0 / 255, 2)
    assert font_size(bob, "Body") == 14


def test_banners_can_stay_until_dismissed_and_skip_motion():
    guild, bob = one()
    bob.ns.SetAccess("bannerHold", "sticky")
    bob.ns.SetAccess("reduceMotion", True)
    b = bob.ns.ShowBanner("kill", "Bob killed a ganker")
    assert b.GetAlpha(b) == 1                       # no fade in
    guild.run(60)
    assert len(bob.ns.ShownBanners()) == 1          # still there
    b.GetScript(b, "OnClick")(b, "RightButton")
    guild.run(0.2)
    assert len(bob.ns.ShownBanners()) == 0          # gone at once, no fade
    bob.ns.SetAccess("bannerHold", "long")
    bob.ns.ShowBanner("kill", "again")
    guild.run(8)
    assert len(bob.ns.ShownBanners()) == 1          # 10 seconds instead of 5
    guild.run(3)
    assert len(bob.ns.ShownBanners()) == 0


def test_the_settings_view():
    _, bob = one()
    bob.run('SlashCmdList.WARCREST("access")')
    tab = bob.lua.eval('function(UI) for _, t in ipairs(UI.tabs) do if t.id == "settings" then return t end end end')(bob.ns.UI)
    assert tab.view.value == "access"
    assert not bob.errors()


def font_of(c, key):
    return c.lua.eval('function(UI, k) local w = UI.Fonts[k]; return rawget(w, "_layout") and rawget(w, "_layout").path end')(c.ns.UI, key)


def test_bigger_text_and_other_fonts():
    _, bob = one()
    bob.ns.SetAccess("textSize", 130)
    assert font_size(bob, "Body") == 16
    bob.ns.SetAccess("font", "plain")
    assert font_of(bob, "Body") == "Fonts\\ARIALN.TTF"
    bob.ns.SetAccess("font", "game")
    assert font_of(bob, "Body") == "Fonts\\FRIZQT__.TTF"
    bob.ns.SetAccess("font", "warcrest")
    assert "Inter" in font_of(bob, "Body")
    bob.ns.SetAccess("outline", True)
    bob.ns.SetAccess("spacing", True)
    assert not bob.errors()


def test_alerts_read_aloud_only_when_turned_on():
    guild, bob = one()
    spoken = bob.lua.eval('{}')
    bob.lua.eval('function(s) C_VoiceChat = { SpeakText = function(voice, text, rate, volume) s[#s + 1] = text end } end')(spoken)
    bob.ns.ShowBanner("kill", "|cffff0000Lyra|r killed |Hplayer:Ganker|hGanker|h")
    assert len(spoken) == 0
    bob.ns.SetAccess("speak", True)
    bob.ns.ShowBanner("kill", "|cffff0000Lyra|r killed |Hplayer:Ganker|hGanker|h")
    assert len(spoken) == 1
    assert spoken[1].endswith("Lyra killed Ganker") and "|" not in spoken[1]
    assert not bob.errors()


def test_bigger_banners():
    _, bob = one()
    bob.ns.SetAccess("bannerSize", 150)
    bob.ns.ShowBanner("kill", "Lyra killed Ganker")
    assert bob.ns.BannerScale() == 1.5
    flashes = bob.lua.eval('{ n = 0 }')
    bob.lua.eval('function(f) FlashClientIcon = function() f.n = f.n + 1 end end')(flashes)
    bob.ns.ShowBanner("kill", "Lyra killed Ganker")
    assert flashes.n == 0
    bob.ns.SetAccess("flash", True)
    bob.ns.ShowBanner("kill", "Lyra killed Ganker")
    assert flashes.n == 1
    assert not bob.errors()


def test_a_key_binding_opens_the_window():
    import os
    xml = open(os.path.join(os.path.dirname(__file__), "..", "Bindings.xml")).read()
    assert 'name="WARCREST_TOGGLE"' in xml and "Warcrest_OnAddonCompartmentClick()" in xml
    _, bob = one()
    assert bob.lua.eval("BINDING_NAME_WARCREST_TOGGLE")
