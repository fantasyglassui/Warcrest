"""New guilds: the welcome and guild setup, DKP on or off, and the help window."""
from harness import Guild

MEMBERS = [("Alice", 0), ("Bob", 3)]   # Alice is the Guild Master


def ready(guild):
    for c in guild.clients.values():
        c.login()
    guild.run(15)


def shown(client, frame):
    f = client.lua.eval(frame)
    return f is not None and f.IsShown(f)


def test_getting_started_shows_once_for_a_new_install():
    guild = Guild(MEMBERS)
    ready(guild)
    assert shown(guild["Bob"], "WarcrestGettingStarted")
    assert not shown(guild["Bob"], "WarcrestWelcome")
    assert guild["Bob"].ns.db.welcomed
    assert not guild["Bob"].errors()


def test_getting_started_ticks_itself_off():
    guild = Guild(MEMBERS)
    ready(guild)
    bob = guild["Bob"]
    done, n, total = bob.ns.StartedSteps()
    assert (n, total) == (0, 5)
    bob.ns.OpenPanel("roster")
    ev = guild["Alice"].ns.CreateRaid("Molten Core", bob.lua.eval("time()") + 86400, "")
    guild.run(3)
    bob.ns.SignUp(ev.id, "accept", "tank")
    bob.ns.SaveMyProfile(bob.lua.table_from({"spec": "Protection", "role": "tank"}))
    bob.ns.NoteMyRecipes("Mining", 1, 75, bob.lua.table_from({"i2770": "Copper Ore"}))
    guild.run(3)
    done, n, _ = bob.ns.StartedSteps()
    assert n == 4 and not done.title
    assert bob.ns.db.started.signup        # stays done, even if the raid goes
    w = bob.lua.eval("WarcrestGettingStarted")
    bob.ns.RefreshGettingStarted()
    assert w.rows[5].primary.IsShown(w.rows[5].primary)     # the one left is highlighted
    assert not w.rows[1].button.IsShown(w.rows[1].button)
    assert not w.setup.IsShown(w.setup)                      # members: no guild setup
    assert not bob.errors()


def test_getting_started_from_the_slash_command_and_help():
    guild = Guild(MEMBERS)
    for c in guild.clients.values():
        c.ns.db.welcomed = True
    ready(guild)
    alice = guild["Alice"]
    assert not shown(alice, "WarcrestGettingStarted")
    alice.run('SlashCmdList.WARCREST("start")')
    w = alice.lua.eval("WarcrestGettingStarted")
    assert shown(alice, "WarcrestGettingStarted") and w.setup.IsShown(w.setup)   # officers get the guild setup
    w.setup.GetScript(w.setup, "OnClick")(w.setup)
    assert shown(alice, "WarcrestWelcome")
    alice.ns.ShowHelp(1)
    h = alice.lua.eval("WarcrestHelp")
    h.checklist.GetScript(h.checklist, "OnClick")(h.checklist)
    assert shown(alice, "WarcrestGettingStarted")
    assert not alice.errors()


def test_no_welcome_for_players_who_already_had_it():
    guild = Guild(MEMBERS, setup=lambda c: c.run('WarcrestDB = { minimap = {} }'))
    for c in guild.clients.values():
        c.ns.cfg.stamp = 5                      # the guild was set up already
    ready(guild)
    assert not shown(guild["Bob"], "WarcrestWelcome")


def test_guild_without_dkp():
    guild = Guild(MEMBERS, raid=["Alice", "Bob"])
    ready(guild)
    alice, bob = guild["Alice"], guild["Bob"]
    types = alice.lua.table_from({})
    for k, v in alice.ns.cfg.types.items():
        types[k] = v
    assert alice.ns.PushConfig(alice.lua.table_from({"enabled": True, "types": types, "officerRank": 1, "dkp": False}))
    guild.run(3)
    assert not bob.ns.UsesDKP()
    # The DKP tab is hidden; auctions are refused; raid nights give no DKP.
    bob.ns.OpenPanel("roster")
    bob.ns.OpenPanel("wishlist")
    views = list(bob.lua.eval("""function(UI)
      local out = {}
      for _, s in ipairs(UI.SECTIONS) do
        if s.id == "loot" then
          for i, b in ipairs(s.switch.buttons) do if b:IsShown() then out[#out + 1] = s.items[i].tab end end
        end
      end
      return out end""")(bob.ns.UI).values())
    assert views == ["wishlist"]                 # Loot shows only the wishlist
    bob.ns.OpenPanel("dkp")
    assert bob.ns.PanelSection() != ("loot", "dkp")
    alice.ns.StartAuction("|cffa335ee|Hitem:1:|h[Thing]|h|r", 5, 20)
    assert alice.said("DKP is turned off")
    alice.ns.StartRaidSession("", "Hyjal Summit", 10, 10, 15)
    guild.run(3)
    assert bob.ns.Balance("Bob") == 0
    assert alice.said("Attendance recorded")
    # Turned back on later.
    assert alice.ns.PushConfig(alice.lua.table_from({"enabled": True, "types": types, "officerRank": 1, "dkp": True}))
    guild.run(3)
    assert bob.ns.UsesDKP()


def test_help_window_every_topic():
    guild = Guild(MEMBERS)
    bob = guild["Bob"]
    for i in range(1, 10):
        bob.ns.ShowHelp(i)
    bob.ns.ShowHelp("wishlists")
    bob.run('SlashCmdList.WARCREST("help")')
    assert shown(bob, "WarcrestHelp")
    assert not bob.errors()


def test_officers_set_up_the_guild_alerts_in_the_welcome():
    guild = Guild(MEMBERS)
    ready(guild)
    alice, bob = guild["Alice"], guild["Bob"]
    # Members skip the officers' page: three steps; officers get four.
    bob.ns.ShowWelcome()
    assert len(bob.lua.eval("WarcrestWelcome").dots) >= 3
    alice.run('SlashCmdList.WARCREST("setup")')
    assert shown(alice, "WarcrestWelcome")
    # Turn off the celebrations and the guild chat posts, and save it for everyone.
    alice.lua.eval("""function(ns)
      local w = WarcrestWelcome
      w.next:GetScript("OnClick")(w.next)            -- to "What the guild hears"
    end""")(alice.ns)
    alice.lua.eval("""function()
      local page
      for _, p in ipairs(WarcrestWelcome.pages) do
        if p:IsShown() and p.officerOnly then page = p end
      end
      assert(page, "no alerts page")
      for _, c in ipairs(page.checks) do
        if c.group == "celebrate" then c:SetChecked(false) end
      end
      page.chat:SetChecked(false)
      page.save:GetScript("OnClick")(page.save)
    end""")()
    guild.run(3)
    for c in (alice, bob):
        assert not c.ns.cfg.types.level_ten and not c.ns.cfg.types.level_all
        assert not c.ns.cfg.types.achievement_chat
        assert c.ns.cfg.types.kill_world and c.ns.cfg.stamp > 0
    assert not alice.errors() and not bob.errors()


def test_officers_are_reminded_when_nobody_has_set_up_the_guild():
    guild = Guild(MEMBERS)
    for c in guild.clients.values():
        c.ns.db.welcomed = True
    ready(guild)
    guild.run(100)
    assert guild["Alice"].said("isn't set up for your guild")
    assert not guild["Bob"].said("isn't set up for your guild")


def test_bug_report_and_discord():
    guild = Guild(MEMBERS)
    bob = guild["Bob"]
    bob.run('SlashCmdList.WARCREST("report")')
    assert shown(bob, "WarcrestReport")
    text = bob.ns.BugReport()
    assert text.startswith("Warcrest ") and "Guild: 2 members" in text and "Errors: none" in text
    assert "Bob" not in text and "Alice" not in text           # no names
    # An error shows up in the next report.
    bob.lua.eval("""function(ns) ns.OnEvent("WARCREST_TEST_BOOM", function() error("boom") end) end""")(bob.ns)
    bob.fire("WARCREST_TEST_BOOM")
    bob.fire("WARCREST_TEST_BOOM")
    text = bob.ns.BugReport()
    assert "boom" in text and "x2" in text
    bob.run('SlashCmdList.WARCREST("discord")')
    assert bob.said("discord.gg/qeSMwQWyPR")
    assert shown(bob, "WarcrestHelp")
    assert not [e for e in bob.errors() if "boom" not in e]


def test_tour_pages():
    guild = Guild(MEMBERS)
    ready(guild)
    bob = guild["Bob"]
    bob.ns.ShowTour()
    assert shown(bob, "WarcrestWelcome")
    tour = bob.lua.eval("WarcrestWelcome.tour")
    assert tour.IsShown(tour)
    def pic():
        return str(tour.pic["_layout"]["tex"])
    assert pic().endswith("Media\\Tour\\home")
    seen = []
    for _ in range(5):
        tour.nextPic.GetScript(tour.nextPic, "OnClick")(tour.nextPic)
        seen.append(pic().rsplit("\\", 1)[1])
    assert seen == ["kills", "raids", "dkp", "profiles", "home"]
    assert not bob.errors()
