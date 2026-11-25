"""The Blades: a secret achievement Sathryus earns by logging in."""
from harness import Guild

MEMBERS = [("Sathryus", 1), ("Bob", 3), ("Cara", 3)]


def earned(client, name):
    return {k for k, e in client.ns.MemberAchievements(name).items() if e.t is not None}


def tiles(client, cat="social"):
    return client.lua.eval("""function(ns, cat)
      local out = {}
      for _, a in ipairs(ns.ACHIEVEMENTS) do
        if a.cat == cat and (not a.secret or ns.HasAchievement(UnitName("player"), a.id)) then out[#out + 1] = a.id end
      end
      return out end""")(client.ns, cat)


def test_sathryus_earns_it_on_login_and_the_guild_sees_it():
    guild = Guild(MEMBERS)
    for c in guild.clients.values():
        c.login()
    guild.run(60)
    sath, bob = guild["Sathryus"], guild["Bob"]
    assert "blades" in earned(sath, "Sathryus")
    assert "blades" in earned(bob, "Sathryus")  # recorded with the guild
    assert "blades" not in earned(bob, "Bob")
    assert not sath.errors() and not bob.errors()


def test_it_stays_secret_for_everyone_else():
    guild = Guild(MEMBERS)
    for c in guild.clients.values():
        c.login()
    guild.run(30)
    bob = guild["Bob"]
    assert "blades" not in list(tiles(bob).values())
    assert bob.ns.ACHIEVEMENT_TOTAL == len(bob.ns.ACHIEVEMENTS) - 1
    bob.ns.OpenPanel("achievements", "social")
    sath = guild["Sathryus"]
    sath.ns.OpenPanel("achievements", "social")
    assert not bob.errors() and not sath.errors()
