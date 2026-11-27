"""Titles and achievements update straight away, and titles are chosen on the
Achievements tab from a list of every title."""
from harness import Guild

M = [("Alice", 1), ("Bob", 3), ("Cara", 3), ("Dan", 3), ("Eve", 3), ("Finn", 3)]


def boss_kill(guild):
    for c in guild.clients.values():
        c.run('INSTANCE = { "Hyjal Summit", "raid" }')
    for n in ("Alice", "Bob", "Cara"):
        guild[n].fire("ENCOUNTER_END", 2001, "Rage Winterchill", 9, 20, 1)


def setup():
    guild = Guild(M, raid=[m[0] for m in M])
    for c in guild.clients.values():
        c.login()
    guild.run(12)
    return guild


def test_achievements_update_as_soon_as_the_kill_lands():
    guild = setup()
    a = guild["Alice"]
    assert not a.ns.HasAchievement("Bob", "kill1")
    guild["Bob"].ns.Send("K", "kill_world", "Ganker", "STV", int(guild.clock), "0.5", "60", "1")
    # The kill is merged after a short wait; read it the moment it's in the log.
    for _ in range(40):
        guild.run(0.1)
        if len(list(a.ns.db.killLog.values())) > 0:
            break
    assert a.ns.HasAchievement("Bob", "kill1")       # no waiting for the next check, no reload


def test_choose_a_title_from_the_list():
    guild = setup()
    a = guild["Alice"]
    boss_kill(guild)
    guild.run(8)
    a.ns.OpenPanel("achievements")
    a.ns.ShowTitleChooser()
    rows = a.lua.eval("WarcrestTitles").list
    items = list(rows["items"].values())
    assert items[0].id == ""                          # No title first
    pioneer = [r for r in items if r.id == "pioneer"][0]
    assert pioneer.earned
    locked = [r for r in items if not r.earned]
    assert locked                                     # titles still to earn are listed too
    # Click the earned one.
    a.lua.eval("""function(list, id)
      for i, r in ipairs(list.items) do
        if r.id == id then
          for _, row in ipairs(list.rows) do
            if row.item == r then row:GetScript("OnClick")(row) return end
          end
        end
      end
    end""")(rows, "pioneer")
    assert a.ns.TitleOf("Alice")[0] == "the Pioneer"
    guild.run(2)
    assert guild["Bob"].ns.TitleOf("Alice")[0] == "the Pioneer"
    a.said()
    # A locked one says how to earn it.
    a.lua.eval("""function(list)
      for _, row in ipairs(list.rows) do
        if row.item and not row.item.earned then row:GetScript("OnClick")(row) return end
      end
    end""")(rows)
    assert a.said("to use this title")
    assert a.ns.TitleOf("Alice")[0] == "the Pioneer"


def test_level_up_updates_max_level_achievement():
    guild = Guild([("Alice", 1, "MAGE", 59), ("Bob", 3)])
    a = guild["Alice"]
    assert not a.ns.HasAchievement("Alice", "maxlevel") if a.ns.Achievement("maxlevel") else True
    guild.members[0] = ("Alice", 1, True, "MAGE", 60)
    a.set_roster()
    a.ns.GetRoster()
    ids = [x.id for x in a.ns.ACHIEVEMENTS.values() if x.stat == "maxLevel"]
    assert ids and a.ns.HasAchievement("Alice", ids[0])


def own_kill(echo):
    from test_grey_kills import attack_and_kill
    guild = Guild(M, raid=[m[0] for m in M], echo=echo)
    for c in guild.clients.values():
        c.login()
    guild.run(40)
    bob = guild["Bob"]
    attack_and_kill(bob, "Ganker", 58)
    guild.run(6)
    return guild, bob


def test_your_own_kill_counts_at_once_when_the_game_doesnt_send_it_back():
    # WoW Forever doesn't send your own guild messages back to you: your kill
    # must still reach your own log and achievements straight away.
    guild, bob = own_kill(echo=False)
    assert len(bob.ns.db.killLog) == 1
    assert bob.ns.HasAchievement("Bob", "kill1")
    assert guild["Alice"].ns.HasAchievement("Bob", "kill1")
    assert len(bob.said("Bob earned First Blood!")) == 1


def test_a_game_that_does_send_it_back_doesnt_count_it_twice():
    guild, bob = own_kill(echo=True)
    assert len(bob.ns.db.killLog) == 1
    assert len(bob.said("Bob killed Ganker", clear=False)) == 1
    assert len(bob.said("Bob earned First Blood!")) == 1


def guild_chat(c):
    sent = c.lua.eval("chatSent")
    return [sent[i][1] for i in range(1, len(sent) + 1) if sent[i][2] == "GUILD"]


def test_your_achievements_are_posted_in_guild_chat_once():
    guild, bob = own_kill(echo=False)
    guild.run(5)
    lines = guild_chat(bob)
    assert len(lines) == 1 and "Bob earned First Blood" in lines[0], lines
    assert guild_chat(guild["Alice"]) == []          # only the one who earned it posts
    guild.run(60)
    assert len(guild_chat(bob)) == 1


def test_guild_chat_posts_can_be_turned_off():
    from test_grey_kills import attack_and_kill
    guild = Guild(M, raid=[m[0] for m in M])
    for c in guild.clients.values():
        c.login()
    guild.run(40)
    bob = guild["Bob"]
    bob.ns.db.show.achievement_chat = False
    attack_and_kill(bob, "Ganker", 58)
    guild.run(12)
    assert guild_chat(bob) == []
    assert bob.said("Bob earned First Blood!")       # the alert still shows


def titled_bob():
    from test_achievements import live_death
    from test_streaks import live_kill
    guild = Guild(M)
    for _ in range(3):
        live_death(guild, "Alice", "Ganker-Stormrage")
        guild.jump(600)
    live_kill(guild, "Bob", "Ganker")
    guild.run(3)
    assert guild["Bob"].ns.SetTitle("bounty")
    guild.run(3)
    for c in guild.clients.values():
        c.ns.SetChatTitles(True)
    return guild


def test_titles_show_in_chat_for_guildmates():
    guild = titled_bob()
    cara = guild["Cara"]
    show = cara.lua.eval("ShowChat")
    gold = "|cffd4af37(the Bounty Hunter)|r "
    assert show("CHAT_MSG_GUILD", "anyone for STV?", "Bob-Realm") == gold + "anyone for STV?"
    assert show("CHAT_MSG_SAY", "hi", "Bob-Realm") == gold + "hi"
    assert show("CHAT_MSG_GUILD", "hello", "Alice-Realm") == "hello"          # no title
    assert show("CHAT_MSG_SAY", "hello", "Stranger-Realm") == "hello"         # not a guildmate
    cara.ns.SetChatTitles(False)
    assert show("CHAT_MSG_GUILD", "hi", "Bob-Realm") == "hi"                  # turned off


def test_kill_alerts_show_the_killers_title():
    from test_streaks import live_kill
    guild = titled_bob()
    cara = guild["Cara"]
    cara.said()
    live_kill(guild, "Bob", "Enemy")
    assert cara.said("Bob the Bounty Hunter killed Enemy")


def test_streak_and_revenge_alerts_show_the_title():
    from test_streaks import live_kill, live_death
    guild = titled_bob()
    cara = guild["Cara"]
    cara.said()
    for i in range(4):   # Bob's kill of Ganker already started the streak
        live_kill(guild, "Bob", "Enemy%d" % i)
        guild.jump(300)
    lines = cara.said("kills in a row")
    assert "Bob the Bounty Hunter is on a Killing Spree!" in lines[0]
    assert "Bob the Bounty Hunter is on a Rampage!" in lines[1]
    live_death(guild, "Bob", "Avenger-Stormrage")
    assert cara.said("Bob the Bounty Hunter's 5-kill streak was ended by Avenger.")
    live_kill(guild, "Bob", "Avenger")
    assert cara.said("Revenge! Bob the Bounty Hunter paid Avenger back")


def newer_chat_api(c):
    """WoW: Forever: ChatFrameUtil.AddMessageEventFilter, and no ChatFrame_AddMessageEventFilter."""
    c.lua.execute("ChatFrameUtil = ChatFrameUtil or {} "
                  "ChatFrameUtil.AddMessageEventFilter = ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter "
                  "ChatFrame_AddMessageEventFilter = nil")


def test_titles_show_in_chat_on_newer_clients():
    from test_achievements import live_death
    from test_streaks import live_kill
    guild = Guild(M, setup=newer_chat_api, realm_space=True)
    for _ in range(3):
        live_death(guild, "Alice", "Ganker-Stormrage")
        guild.jump(600)
    live_kill(guild, "Bob", "Ganker")
    guild.run(3)
    assert guild["Bob"].ns.SetTitle("bounty")
    guild.run(3)
    guild["Cara"].ns.SetChatTitles(True)
    show = guild["Cara"].lua.eval("ShowChat")
    assert show("CHAT_MSG_GUILD", "anyone for STV?", "Bob Realm") == "|cffd4af37(the Bounty Hunter)|r anyone for STV?"


def test_the_bug_report_says_why_a_title_did_or_didnt_show_in_chat():
    guild = titled_bob()
    cara = guild["Cara"]
    show = cara.lua.eval("ShowChat")
    show("CHAT_MSG_GUILD", "hi", "Bob-Realm")
    report = cara.ns.ChatTitleReport()
    assert "Titles in chat: on, filter added with" in report
    assert 'Last chat line: CHAT_MSG_GUILD from "Bob-Realm" (title shown)' in report
    show("CHAT_MSG_GUILD", "hi", "Stranger-Realm")
    assert "(not found in the roster)" in cara.ns.ChatTitleReport()
    show("CHAT_MSG_GUILD", "hi", "Alice-Realm")
    assert "(no title chosen or earned)" in cara.ns.ChatTitleReport()
    # Added only once, even if both of the game's filter lists run.
    once = show("CHAT_MSG_GUILD", "|cffd4af37(the Bounty Hunter)|r hi", "Bob-Realm")
    assert once.count("Bounty Hunter") == 1


def test_titles_in_chat_are_off_until_you_turn_them_on():
    guild = titled_bob()
    dan = Guild(M)["Cara"]          # a fresh install
    dan.login()
    assert dan.ns.db.chatTitles is False
    assert "filter added with nothing" in dan.ns.ChatTitleReport()
    show = dan.lua.eval("ShowChat")
    assert show("CHAT_MSG_GUILD", "hi", "Bob-Realm") == "hi"
    # Upgrading from 4.5.2, where it was on: off once.
    old = Guild(M, setup=lambda c: c.run("WarcrestDB = { chatTitles = true }"))["Cara"]
    old.login()
    assert old.ns.db.chatTitles is False
    assert guild["Cara"].ns.db.chatTitles is True   # turned on stays on


def test_a_blocked_chat_action_is_explained_once():
    guild = titled_bob()
    cara = guild["Cara"]
    cara.said()
    for _ in range(3):
        cara.fire("ADDON_ACTION_BLOCKED", "Warcrest", "ChatFrame1:Show()")
    lines = cara.said("blocked")
    assert len(lines) == 1 and "Show titles in chat" in lines[0]
