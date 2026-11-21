"""Spreading the word: who has Warcrest, the invite and share texts, and the
one guild-chat post Warcrest makes (only when an officer asks for it)."""
from harness import Guild

M = [("Gm", 0), ("Off", 1), ("Alice", 3), ("Bob", 3), ("Cara", 3), ("Dan", 3)]


def only_have(c, names):
    """Make the Who has Warcrest list say exactly these members have it."""
    c.ns.versions = c.lua.eval("{}")
    c.ns.db.addonUsers = c.lua.eval("{}")
    for n in names:
        c.ns.versions[c.ns.fullName(n)] = c.ns.version


def stub_roster(c, code):
    """Replace the roster with what `code` makes of the real one (a Lua function of the list)."""
    if not hasattr(c, "real_roster"):
        c.real_roster = c.ns.GetRoster
    c.lua.globals().__orig = c.real_roster
    c.ns.GetRoster = c.lua.eval("function() local f = %s; return f(__orig()) end" % code)


def guild_chat(c):
    return [l for l in c.lua.eval("chatSent").values() if l[2] == "GUILD"]


def test_counts_who_has_warcrest():
    guild = Guild(M)
    c = guild["Off"]
    only_have(c, ["Gm", "Off"])
    assert tuple(c.ns.WarcrestCount()) == (2, 6, 6)
    # Someone gone for a month is not an active member, with or without Warcrest.
    stub_roster(c, """function(list)
      for _, m in ipairs(list) do
        if m.name:find("^Dan") then m.online = false; m.offlineDays = 30 end
      end
      return list
    end""")
    assert tuple(c.ns.WarcrestCount()) == (2, 5, 6)
    c.ns.versions[c.ns.fullName("Dan")] = c.ns.version
    assert tuple(c.ns.WarcrestCount()) == (2, 5, 6)
    assert c.errors() == []


def test_counts_with_empty_roster():
    guild = Guild(M)
    c = guild["Off"]
    stub_roster(c, "function() return {} end")
    assert tuple(c.ns.WarcrestCount()) == (0, 0, 0)
    assert not c.ns.ShouldNudge()
    assert not c.ns.AloneInGuild()


def test_texts_fit_in_guild_chat():
    c = Guild(M)["Off"]
    invite, share = str(c.ns.InviteText()), str(c.ns.ShareText())
    assert len(invite) <= 255
    assert "CurseForge" in invite and "warcrest-addon.com" in invite
    assert "\n" not in share and "warcrest-addon.com" in share


def test_invite_posts_only_when_asked():
    guild = Guild(M)
    off = guild["Off"]
    guild.run(60)
    assert guild_chat(off) == []
    ok, why = off.ns.PostGuildInvite(off.ns.InviteText())
    assert ok
    assert len(guild_chat(off)) == 1
    assert off.ns.LastInvite() == int(guild.clock)


def test_invite_refused_for_members():
    guild = Guild(M)
    bob = guild["Bob"]
    ok, why = bob.ns.PostGuildInvite("Hello")
    assert (ok, why) == (False, "officer")
    assert guild_chat(bob) == []
    assert bob.ns.LastInvite() is None


def test_invite_escapes_and_trims():
    off = Guild(M)["Off"]
    off.ns.PostGuildInvite("|cff" + "x" * 297)
    sent = guild_chat(off)
    assert len(sent) == 1
    text = str(sent[0][1])
    assert len(text) <= 255 and "||cff" in text and "|cff" not in text.replace("||", "")


def test_invite_held_in_lockdown():
    guild = Guild(M)
    off = guild["Off"]
    off.lua.globals().chatLockdown = True
    ok, why = off.ns.PostGuildInvite("Come play")
    assert ok and why == "held"
    guild.run(2)
    assert guild_chat(off) == []
    off.lua.globals().chatLockdown = False
    guild.run(3)
    assert len(guild_chat(off)) == 1


def test_nudge_and_dismissal():
    guild = Guild(M)
    off, bob = guild["Off"], guild["Bob"]
    only_have(off, ["Off"])
    assert off.ns.ShouldNudge()                       # 1 of 6
    assert off.ns.AloneInGuild()
    off.ns.DismissNudge()                              # 5 missing
    assert not off.ns.ShouldNudge()
    stub_roster(off, """function(list)
      for i = 1, 4 do list[#list + 1] = { name = "X" .. i, full = "X" .. i .. "-Realm", online = true, offlineDays = 0 } end
      return list
    end""")
    assert not off.ns.ShouldNudge()                    # 9 missing, 5 more needed
    only_have(off, ["Off"])
    stub_roster(off, """function(list)
      for i = 1, 5 do list[#list + 1] = { name = "X" .. i, full = "X" .. i .. "-Realm", online = true, offlineDays = 0 } end
      return list
    end""")
    assert off.ns.ShouldNudge()                        # 10 missing >= 5 + 5
    only_have(bob, ["Bob"])
    assert not bob.ns.ShouldNudge()                    # not an officer
    only_have(off, ["Gm", "Off", "Alice", "Bob"])
    off.ns.db.invite = off.lua.eval("{}")
    stub_roster(off, "function(list) return list end")
    assert not off.ns.ShouldNudge() and not off.ns.AloneInGuild()


def test_invite_refuses_empty_text():
    guild = Guild(M)
    off = guild["Off"]
    for text in ("", "   \n\t ", None):
        assert tuple(off.ns.PostGuildInvite(text)) == (False, "empty")
    assert guild_chat(off) == []
    assert off.ns.LastInvite() is None


def window(c, name):
    return c.lua.eval(name)


def test_invite_window_officer_and_member():
    guild = Guild(M)
    off, bob = guild["Off"], guild["Bob"]
    w = off.ns.ShowInvite()
    assert w.post.IsShown(w.post)
    assert str(w.box.GetText(w.box)) == str(off.ns.InviteText())
    assert not w.copy.IsShown(w.copy)
    w = bob.ns.ShowInvite()
    assert not w.post.IsShown(w.post)
    assert w.copy.IsShown(w.copy)
    assert str(w.copy.GetText(w.copy)) == str(bob.ns.InviteText())
    assert window(bob, "WarcrestInvite") is not None
    assert off.errors() == [] and bob.errors() == []


def test_invite_post_button_posts_and_closes():
    guild = Guild(M)
    off = guild["Off"]
    w = off.ns.ShowInvite()
    w.post.GetScript(w.post, "OnClick")(w.post)
    assert len(guild_chat(off)) == 1
    assert not w.IsShown(w)
    assert off.ns.LastInvite() is not None
    w = off.ns.ShowInvite()
    assert "Last posted" in str(w.last.GetText(w.last))


def test_share_command():
    c = Guild(M)["Off"]
    c.run('SlashCmdList.WARCREST("share")')
    w = window(c, "WarcrestShare")
    assert w.IsShown(w)
    assert str(w.box.GetText(w.box)) == str(c.ns.ShareText())
    c.ns.ShowShare("custom text")
    assert str(w.box.GetText(w.box)) == "custom text"
    c.run('SlashCmdList.WARCREST("invite")')
    assert window(c, "WarcrestInvite").IsShown(window(c, "WarcrestInvite"))
    assert c.errors() == []


def test_no_send_on_open():
    guild = Guild(M)
    for n in ("Off", "Bob"):
        c = guild[n]
        c.ns.ShowInvite()
        c.ns.ShowShare()
        c.run('SlashCmdList.WARCREST("invite")')
        c.run('SlashCmdList.WARCREST("share")')
    guild.run(60)
    assert guild_chat(guild["Off"]) == [] and guild_chat(guild["Bob"]) == []
    assert guild["Off"].ns.LastInvite() is None
