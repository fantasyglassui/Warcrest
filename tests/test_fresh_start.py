"""4.3.0: a full reset of everything shared, once, keeping personal and guild settings."""
from harness import Guild


def test_shared_data_goes_and_settings_stay():
    seed = ('WarcrestDB = { releaseReset = "2.1.0", killLog = { { t = 1795000000, victim = "Old", killers = { "Bob" }, '
            'kind = "kill_world" } }, ledger = { x = { t = 1795000000 } }, achievements = { bob = { kill1 = 1 } }, '
            'cooldowns = { bob = {} }, alertStyle = "chat", access = { textSize = 120 }, minimap = { hide = true }, '
            'cfg = { dkp = false }, cfgGuild = "The Imperium" }')
    guild = Guild([("Alice", 1), ("Bob", 3)], setup=lambda c: c.run(seed) if c.name == "Bob" else None)
    bob = guild["Bob"]
    db = bob.ns.db
    assert db.releaseReset == "4.3.0"
    assert len(db.killLog) == 0 and next(iter(db.ledger.items()), None) is None
    assert db.achievements is None or len(list(db.achievements.items())) == 0
    assert db.alertStyle == "chat" and db.access.textSize == 120 and db.minimap.hide
    assert db.cfg.dkp is False


def test_old_data_from_older_versions_is_refused():
    guild = Guild([("Alice", 1), ("Bob", 3)])
    bob = guild["Bob"]
    assert bob.ns.BeforeRelease(1795000000)
    assert not bob.ns.BeforeRelease(1796000000)


def test_it_happens_only_once():
    guild = Guild([("Alice", 1), ("Bob", 3)])
    bob = guild["Bob"]
    assert bob.ns.db.releaseReset == "4.3.0"
