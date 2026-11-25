"""Guild rep: earned only by playing together, at most 1,000 a day, and it only goes up."""
from harness import Guild
from test_crafters import TAILOR, open_window

M = [("Alice", 1), ("Bob", 3), ("Cara", 3)]
DAY = 86400


def rep(client, name):
    total, today, rank, rank_name = client.ns.Rep(name)[:4]
    return total, today, rank, rank_name


def fake_raid_nights(client, times):
    """Raid nights for Alice at these times (instead of real raid sessions)."""
    client.lua.eval("""function(ns, times)
      local list = {}
      for i = 1, #times do list[i] = times[i] end
      ns.RaidNightsAttended = function(name) if ns.Key(name) == ns.Key("Alice") then return list end return {} end
      ns.ReindexLedger()
    end""")(client.ns, client.lua.table(*times))


def test_nothing_yet_is_neutral():
    guild = Guild(M)
    a = guild["Alice"]
    a.login()
    guild.run(5)
    assert rep(a, "Alice")[:4] == (0, 0, 1, "Neutral")
    assert not a.errors()


def test_grouped_time_counts_when_both_of_you_report_it():
    guild = Guild(M, raid=["Alice", "Bob"])
    for n in ("Alice", "Bob"):
        guild[n].login()
    guild.run(35 * 60, step=1)
    guild.set_raid([])            # the group ends: the rest is noted too
    guild.run(120, step=1)
    a, b = guild["Alice"], guild["Bob"]
    total = rep(a, "Alice")[0]
    assert 20 <= total <= 40      # about 35 minutes together: 10 rep per 10 minutes
    assert rep(b, "Alice")[0] == total          # everyone works out the same number
    assert rep(a, "Bob")[0] == rep(b, "Bob")[0] > 0
    assert rep(a, "Cara")[0] == 0               # not in the group
    assert not a.errors() and not b.errors()


def test_grouped_time_alone_doesnt_count():
    # Bob is in the group but has no Warcrest, so nobody confirms Alice's time.
    guild = Guild(M, raid=["Alice", "Bob"])
    guild["Alice"].login()
    guild["Bob"].online = False
    guild.run(40 * 60, step=1)
    a = guild["Alice"]
    assert len(list(a.ns.LedgerEntries("GR").values())) >= 1   # her time was noted
    assert rep(a, "Alice")[0] == 0


def test_at_most_1000_a_day_and_the_ranks():
    guild = Guild(M)
    a = guild["Alice"]
    a.login()
    guild.run(5)
    now = int(guild.clock)
    # 15 raid nights today (1,500 rep, capped) and 25 spread over 25 earlier days.
    fake_raid_nights(a, [now - 60 * i for i in range(15)] + [now - DAY * (i + 1) for i in range(25)])
    total, today, rank, name = rep(a, "Alice")
    assert today == 1000
    assert total == 1000 + 25 * 100
    assert (rank, name) == (2, "Friendly")
    assert a.ns.RepRank(42000)[1] == "Exalted"
    assert a.ns.RepRank(20999)[1] == "Honored"


def test_it_only_goes_up():
    guild = Guild(M)
    a = guild["Alice"]
    a.login()
    guild.run(5)
    now = int(guild.clock)
    fake_raid_nights(a, [now - DAY * i for i in range(4)])
    assert rep(a, "Alice")[0] == 400
    fake_raid_nights(a, [])          # the old records age out
    assert rep(a, "Alice")[0] == 400


def test_ranking_up_shows_a_banner():
    guild = Guild(M)
    a = guild["Alice"]
    a.login()
    guild.run(10)
    a.said()
    now = int(guild.clock)
    fake_raid_nights(a, [now - DAY * i for i in range(30)])
    a.ns.OnHistoryChanged()
    guild.run(5)
    assert a.said("You're now Friendly with the guild")
    assert a.ns.db.repRank == 2
    assert not a.errors()


def test_a_finished_crafting_order_gives_the_crafter_rep():
    guild = Guild(M)
    bob, cara = guild["Bob"], guild["Cara"]
    open_window(bob, "tradeSkill = " + TAILOR, "TRADE_SKILL_SHOW")
    guild.run(35)
    e = cara.ns.PlaceCraftOrder("Bob", "13858", True, "")
    guild.run(3)
    bob.ns.UpdateCraftOrder(e.id, "done")
    guild.run(3)
    assert rep(cara, "Bob")[0] == 25
    assert rep(bob, "Bob")[0] == 25
    assert rep(bob, "Cara")[0] == 0
