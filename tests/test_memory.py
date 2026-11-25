"""Warcrest mustn't keep making garbage: in game that showed as memory climbing
to 80 MB and the game lagging."""
from harness import Guild

MEMBERS = [("Thorne", 1, "WARRIOR"), ("Lyra", 3, "MAGE"), ("Mira", 3, "PRIEST")]


def alloc_kb(client, fn):
    L = client.lua
    L.execute('collectgarbage("collect"); collectgarbage("stop")')
    before = L.eval('collectgarbage("count")')
    fn()
    after = L.eval('collectgarbage("count")')
    L.execute('collectgarbage("restart")')
    return after - before


def test_a_burst_of_roster_updates_redraws_the_open_window_once():
    guild = Guild(MEMBERS)
    me = guild["Thorne"]
    for c in guild.clients.values():
        c.login()
    guild.run(5)
    me.ns.OpenPanel("roster")
    guild.run(1)
    draws = me.lua.eval('{ n = 0 }')
    me.lua.eval('function(ns, d) local old = ns.RefreshPlayerCard; ns.RefreshPlayerCard = function(...) d.n = d.n + 1; if old then return old(...) end end end')(me.ns, draws)
    for _ in range(50):
        me.fire("GUILD_ROSTER_UPDATE")
    assert draws.n <= 1
    guild.run(1)
    assert draws.n == 2  # the rest, drawn together a moment later
    assert not me.errors()


def test_idle_tickers_make_little_garbage():
    guild = Guild(MEMBERS)
    me = guild["Thorne"]
    for c in guild.clients.values():
        c.login()
    guild.run(60)
    kb = alloc_kb(me, lambda: guild.run(60))
    assert kb < 200, kb  # about 600 KB a minute before 4.3.0


def test_seeing_the_same_enemy_again_keeps_their_entry():
    guild = Guild(MEMBERS)
    me = guild["Thorne"]
    me.login()
    me.ns.NoteEnemyGuild("Ganker-Stormrage", "Bad Guys")
    first = me.ns.db.enemyGuilds[me.ns.Key("Ganker-Stormrage")]
    guild.run(5)
    me.ns.NoteEnemyGuild("Ganker-Stormrage", "Bad Guys")
    again = me.ns.db.enemyGuilds[me.ns.Key("Ganker-Stormrage")]
    assert me.lua.eval("rawequal")(first, again)
    me.ns.NoteEnemyGuild("Ganker-Stormrage", "Other Guys")
    assert me.ns.db.enemyGuilds[me.ns.Key("Ganker-Stormrage")].g == "Other Guys"
