"""Guild > Roster: sort by any column and show only some members."""
from harness import Guild

MEMBERS = [("Thorne", 1, "WARRIOR"), ("Lyra", 3, "MAGE"), ("Mira", 3, "PRIEST", 58), ("Brakk", 2, "ROGUE")]


def names(me, q="", offline=True):
    rows = me.ns.RosterRows(me.ns.GetRoster(), q, offline)
    return [rows[i].name.split("-")[0] for i in range(1, len(rows) + 1)]


def setup():
    guild = Guild(MEMBERS)
    me = guild["Thorne"]
    for c in guild.clients.values():
        c.login()
    guild.run(30)
    me.ns.OpenPanel("roster")
    return guild, me


def test_sorted_by_rank_then_name_at_first():
    _, me = setup()
    assert names(me) == ["Thorne", "Brakk", "Lyra", "Mira"]


def test_click_a_heading_to_sort_and_again_to_reverse():
    _, me = setup()
    me.ns.SortRoster("name")
    assert names(me) == ["Brakk", "Lyra", "Mira", "Thorne"]
    me.ns.SortRoster("name")
    assert names(me) == ["Thorne", "Mira", "Lyra", "Brakk"]
    me.ns.SortRoster("level")  # highest first
    assert names(me)[-1] == "Mira"
    assert me.ns.db.rosterView.sort == "level"
    assert not me.errors()


def test_show_only_some_members():
    _, me = setup()
    me.ns.ShowRoster("max")
    assert "Mira" not in names(me)
    me.ns.ShowRoster("officers")
    assert names(me)[0] == "Thorne"
    me.ns.ShowRoster("all")
    assert names(me, "priest") == ["Mira"]  # search finds classes too
    assert not me.errors()
