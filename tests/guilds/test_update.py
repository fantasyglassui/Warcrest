"""The guild site's data job, against answers saved from Blizzard's API."""
import json, os, sys, types
HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, "..", "..", "tools", "guilds"))
import update  # noqa: E402

FIX = os.path.join(HERE, "fixtures")


def load(name):
    return json.load(open(os.path.join(FIX, name)))


class FakeAPI:
    """Answers from the saved files; every character is given Sathryus's profile and statistics."""
    def __init__(self, level=None):
        self.calls, self.level = 0, level

    def spent(self):
        return False

    def fetch(self, path):
        self.calls += 1
        if path.startswith("/data/wow/guild/the-imperium/roster"):
            return load("roster-the-imperium.json")
        if path.startswith("/data/wow/guild/the-imperium"):
            return load("guild-the-imperium.json")
        if path.startswith("/data/wow/item/"):
            return load("item-8348.json")
        if "/achievements/statistics" in path:
            return load("statistics-sathryus-wraithblade.json")
        if "/equipment" in path:
            return load("equipment-sathryus-wraithblade.json")
        if path.startswith("/profile/wow/character/"):
            p = load("character-sathryus-wraithblade.json")
            slug = path.split("/")[4].split("?")[0]
            if self.level is not None:
                p["level"] = self.level.get(slug, p["level"])
            return p
        return None


def test_statistics_are_read():
    stats, bosses = update.read_statistics(load("statistics-sathryus-wraithblade.json"))
    assert stats["quests"] > 0 and stats["creatures"] > 0 and "deaths" in stats
    assert any(k.endswith("|Deadmines") for k in bosses)


def test_a_guild_is_summarized_and_firsts_are_dated_from_when_seen():
    state = {"guilds": {"the-imperium": {}}}
    api = FakeAPI(level={"bambo-dreadborne": 60})
    s = update.update_guild(api, state, "the-imperium", 1000)
    assert s["name"] == "THE IMPERIUM" and s["ruleset"] == "PvP" and s["members"] == 5
    assert s["tracked"] == 3 and s["at60"] == 1
    assert s["bosses"] > 0 and s["gear"] == 50.0  # every slot is the same test item (level 50)
    assert state["firsts"]["level60"]["bambo-dreadborne"]["t"] is None  # already 60 the first time: no date
    # Next run, Luna reaches 60: dated.
    api = FakeAPI(level={"bambo-dreadborne": 60, "luna-miko": 60})
    update.update_guild(api, state, "the-imperium", 5000)
    assert state["firsts"]["level60"]["luna-miko"]["t"] == 5000
    idx = update.public_index(state, {"the-imperium": s}, 5000)
    assert idx["guilds"][0]["slug"] == "the-imperium"
    assert any(p["s"] == "sathryus-wraithblade" and p["u"] == "Wraithblade" for p in idx["players"])
    assert idx["firsts"][0]["kind"] == "level60" and idx["firsts"][0]["t"] == 5000


def test_quiet_members_are_not_fetched_again():
    state = {"guilds": {"the-imperium": {}}}
    update.update_guild(FakeAPI(), state, "the-imperium", 1000)
    api = FakeAPI()
    update.update_guild(api, state, "the-imperium", 2000)
    # Guild + roster + one profile per member level 10+, no statistics or equipment again.
    assert api.calls == 2 + 3


def test_slugs():
    assert update.slugify("The Imperium") == "the-imperium"
    assert update.slugify("Dragon's  Hoard") == "dragons-hoard"


def test_add_guild_form_fields():
    body = "### Guild name\n\nThe Imperium\n\n### Warcrest\n\n- [X] We use Warcrest"
    assert update.form_field(body, "Guild name") == "The Imperium"
    assert "[x]" in update.form_field(body, "Warcrest").lower()
