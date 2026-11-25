"""The guild site's data: asks Blizzard's API about every guild on the list and
their members, keeps a little history (firsts can only be dated from when they
were first seen), and writes the public JSON the guild pages read.

Run by .github/workflows/guild-site.yml every hour:

    python3 tools/guilds/update.py --state STATE_DIR --out OUT_DIR

STATE_DIR (kept on the guild-data branch) holds state.json; OUT_DIR gets
index.json and guilds/<slug>.json. Needs BLIZZARD_CLIENT_ID and
BLIZZARD_CLIENT_SECRET; GITHUB_TOKEN and GITHUB_REPOSITORY to read "Add a guild"
requests (issues labelled add-guild).

WoW: Forever has no realms: guilds and characters are looked up by slug alone
(characters as first-surname), in the profile-forever-us namespace.
"""
import argparse, concurrent.futures, json, os, re, sys, threading, time, urllib.error, urllib.parse, urllib.request

API = "https://us.api.blizzard.com"
PROFILE = "namespace=profile-forever-us&locale=en_US"
STATIC = "namespace=static-forever-us&locale=en_US"
MAX_CALLS = 20000          # per run (Blizzard allows 36,000 an hour)
STATS_EVERY = 24 * 3600    # refresh a member's statistics at least daily, more often when they've played
ACTIVE_DAYS = 7
MIN_LEVEL = 10             # characters only appear on the API from level 10
MAX_LEVEL = 60

CLASSES = {1: "Warrior", 2: "Paladin", 3: "Hunter", 4: "Rogue", 5: "Priest", 6: "Death Knight", 7: "Shaman",
           8: "Mage", 9: "Warlock", 10: "Monk", 11: "Druid", 12: "Demon Hunter", 13: "Evoker"}
# Raids (the rest of the boss kills are dungeons). Same names as the add-on's Raids/Bosses.lua.
RAIDS = {"Molten Core", "Onyxia's Lair", "Blackwing Lair", "Zul'Gurub", "Ruins of Ahn'Qiraj", "Temple of Ahn'Qiraj",
         "Naxxramas", "Hyjal Summit", "Barrow Deeps"}


def slugify(name):
    s = name.strip().lower().replace("'", "").replace("’", "")
    s = re.sub(r"\s+", "-", s)
    return re.sub(r"[^\w-]", "", s, flags=re.UNICODE)


class Blizzard:
    """The API, with a call budget and a few retries. fetch(path) -> dict or None (404 or failure)."""

    def __init__(self, client_id, secret, budget=MAX_CALLS):
        self.budget, self.calls, self.lock = budget, 0, threading.Lock()
        req = urllib.request.Request("https://oauth.battle.net/token", data=b"grant_type=client_credentials")
        cred = __import__("base64").b64encode(("%s:%s" % (client_id, secret)).encode()).decode()
        req.add_header("Authorization", "Basic " + cred)
        with urllib.request.urlopen(req, timeout=30) as r:
            self.token = json.load(r)["access_token"]

    def spent(self):
        with self.lock:
            return self.calls >= self.budget

    def fetch(self, path):
        with self.lock:
            if self.calls >= self.budget:
                return None
            self.calls += 1
        url = API + path
        for attempt in range(3):
            try:
                req = urllib.request.Request(url, headers={"Authorization": "Bearer " + self.token})
                with urllib.request.urlopen(req, timeout=30) as r:
                    return json.load(r)
            except urllib.error.HTTPError as e:
                if e.code == 404:
                    return None
                if e.code == 429:
                    time.sleep(1 + attempt)
                    continue
                if e.code >= 500:
                    time.sleep(1)
                    continue
                return None
            except Exception:
                time.sleep(1)
        return None


# ---------------------------------------------------------------------------
# Reading what Blizzard sends
# ---------------------------------------------------------------------------
def read_statistics(doc):
    """achievements/statistics -> a flat dict of the numbers the site uses, and boss kills."""
    out, bosses = {}, {}

    def walk(cats, path):
        for c in cats or []:
            name = c.get("name", "")
            for s in c.get("statistics", []) or []:
                n, q = s.get("name", ""), s.get("quantity")
                if not isinstance(q, (int, float)):
                    continue
                if name == "Boss Kills":
                    m = re.match(r"^(.*?) kills? \((.*)\)$", n, re.I)
                    if m and q > 0:
                        bosses["%s|%s" % (m.group(1).strip(), m.group(2).strip())] = int(q)
                    continue
                out[n] = q
            walk(c.get("sub_categories"), path + [name])
    walk(doc.get("categories"), [])
    keep = {
        "quests": out.get("Quests completed"),
        "creatures": out.get("Creatures killed"),
        "deaths": out.get("Total deaths"),
        "hks": out.get("Total Honorable Kills"),
        "blows": out.get("Total Killing Blows"),
        "dungeons": out.get("Total 5-player dungeons entered"),
        "maxprof": out.get("Professions at maximum skill"),
        "pvpdeaths": out.get("Total deaths from other players"),
    }
    return {k: int(v) for k, v in keep.items() if v is not None}, bosses


def item_level(api, cache, item_id):
    key = str(item_id)
    if key not in cache:
        doc = api.fetch("/data/wow/item/%s?%s" % (item_id, STATIC))
        if doc is None:
            return None
        cache[key] = int(doc.get("level") or 0)
    return cache[key]


def read_equipment(api, cache, doc):
    """The average item level of what's equipped (shirts and tabards left out; a
    two-handed weapon counts for both hands)."""
    total = slots = 0
    for it in (doc or {}).get("equipped_items", []):
        if (it.get("slot") or {}).get("type", "") in ("SHIRT", "TABARD"):
            continue
        lvl = item_level(api, cache, (it.get("item") or {}).get("id"))
        if lvl and lvl > 1:
            w = 2 if (it.get("inventory_type") or {}).get("type") == "TWOHWEAPON" else 1
            total, slots = total + lvl * w, slots + w
    # (Some items aren't on the API yet: with fewer than 8 known, it would mislead.)
    return round(total / slots, 1) if slots >= 8 else None


# ---------------------------------------------------------------------------
# One guild
# ---------------------------------------------------------------------------
def update_guild(api, state, slug, now):
    g = api.fetch("/data/wow/guild/%s?%s" % (slug, PROFILE))
    roster = api.fetch("/data/wow/guild/%s/roster?%s" % (slug, PROFILE))
    if g is None or roster is None:
        return None
    chars = state.setdefault("chars", {})
    items = state.setdefault("items", {})
    members = []
    todo = []
    for m in roster.get("members", []):
        c = m.get("character", {})
        cslug = c.get("slug")
        if not cslug:
            continue
        members.append({"slug": cslug, "name": c.get("name"), "surname": c.get("surname", ""), "level": c.get("level", 0),
                        "class": CLASSES.get((c.get("playable_class") or {}).get("id"), ""), "rank": m.get("rank", 9)})
        if c.get("level", 0) >= MIN_LEVEL:
            todo.append(cslug)

    def one(cslug):
        known = chars.get(cslug, {})
        prof = api.fetch("/profile/wow/character/%s?%s" % (cslug, PROFILE))
        if prof is None:
            return cslug, None
        info = dict(known)
        info.update({"level": prof.get("level", 0), "last": (prof.get("last_login_timestamp") or 0) // 1000,
                     "race": (prof.get("race") or {}).get("name", ""), "faction": (prof.get("faction") or {}).get("type", ""),
                     "points": prof.get("achievement_points", 0)})
        stale = info["last"] > known.get("last", 0) or now - known.get("stats_at", 0) > STATS_EVERY
        if stale:
            st = api.fetch("/profile/wow/character/%s/achievements/statistics?%s" % (cslug, PROFILE))
            if st is not None:
                info["stats"], info["bosses"] = read_statistics(st)
                info["stats_at"] = now
            eq = api.fetch("/profile/wow/character/%s/equipment?%s" % (cslug, PROFILE))
            if eq is not None:
                info["ilvl"] = read_equipment(api, items, eq)
        return cslug, info

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        for cslug, info in pool.map(one, todo):
            if info is not None:
                before = chars.get(cslug, {})
                note_firsts(state, cslug, before, info, slug, g, now)
                chars[cslug] = info

    for m in members:
        info = chars.get(m["slug"], {})
        m.update({k: info[k] for k in ("last", "race", "ilvl", "stats", "points") if k in info})
        if info.get("level"):
            m["level"] = info["level"]
    return summarize(state, slug, g, members, now)


def note_firsts(state, cslug, before, info, gslug, g, now):
    """Firsts are dated from when they were first seen: a character already 60 (or a boss
    already killed) the first time we look gets no date ("before tracking")."""
    f = state.setdefault("firsts", {"level60": {}, "bosses": {}})
    seen_before = bool(before)
    if info.get("level", 0) >= MAX_LEVEL and cslug not in f["level60"]:
        f["level60"][cslug] = {"t": now if seen_before and before.get("level", 0) < MAX_LEVEL else None, "guild": gslug}
    gb = f["bosses"].setdefault(gslug, {})
    for boss in (info.get("bosses") or {}):
        if boss not in gb:
            gb[boss] = {"t": now if seen_before and boss not in (before.get("bosses") or {}) else None, "by": cslug}


def summarize(state, slug, g, members, now):
    crest = g.get("crest", {})

    def rgba(part):
        c = ((crest.get(part) or {}).get("color") or {}).get("rgba") or {}
        return "#%02x%02x%02x" % (c.get("r", 60), c.get("g", 60), c.get("b", 60)) if c else None
    tracked = [m for m in members if m.get("level", 0) >= MIN_LEVEL]
    at60 = [m for m in members if m.get("level", 0) >= MAX_LEVEL]
    active = [m for m in members if m.get("last") and now - m["last"] <= ACTIVE_DAYS * 86400]
    gear = sorted((m["ilvl"] for m in members if m.get("ilvl")), reverse=True)[:10]
    total = lambda k: sum((m.get("stats") or {}).get(k, 0) for m in members)
    gb = state.get("firsts", {}).get("bosses", {}).get(slug, {})
    bosses = []
    for key, v in gb.items():
        boss, inst = key.split("|", 1)
        kills = sum((state["chars"].get(m["slug"], {}).get("bosses") or {}).get(key, 0) for m in members)
        bosses.append({"boss": boss, "instance": inst, "raid": inst in RAIDS, "kills": kills, "first": v.get("t"), "by": v.get("by")})
    bosses.sort(key=lambda b: (not b["raid"], b["instance"], b["boss"]))
    levels = sorted((m.get("level", 0) for m in members), reverse=True)
    return {
        "slug": slug, "name": g.get("name", slug), "faction": (g.get("faction") or {}).get("type", ""),
        "ruleset": (g.get("ruleset") or {}).get("name", ""), "created": (g.get("created_timestamp") or 0) // 1000,
        "crest": {"emblem": rgba("emblem"), "border": rgba("border"), "background": rgba("background")},
        "members": len(members), "tracked": len(tracked), "at60": len(at60), "active": len(active),
        "top10": round(sum(levels[:10]) / max(1, min(10, len(levels))), 1),
        "gear": round(sum(gear) / len(gear), 1) if gear else None,
        "quests": total("quests"), "creatures": total("creatures"), "hks": total("hks"), "deaths": total("deaths"),
        "bosses": len(bosses), "raidbosses": sum(1 for b in bosses if b["raid"]),
        "updated": now, "roster": members, "bossList": bosses,
    }


# ---------------------------------------------------------------------------
# "Add a guild" requests (GitHub issues labelled add-guild)
# ---------------------------------------------------------------------------
def github(method, path, body=None):
    token, repo = os.environ.get("GITHUB_TOKEN"), os.environ.get("GITHUB_REPOSITORY")
    if not token or not repo:
        return None
    req = urllib.request.Request("https://api.github.com/repos/%s%s" % (repo, path), method=method,
                                 data=json.dumps(body).encode() if body is not None else None)
    req.add_header("Authorization", "Bearer " + token)
    req.add_header("Accept", "application/vnd.github+json")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r)
    except Exception as e:
        print("GitHub:", method, path, e, file=sys.stderr)
        return None


def form_field(body, label):
    m = re.search(r"### %s\s*\n+(.*?)(?:\n###|\Z)" % re.escape(label), body or "", re.S)
    v = (m.group(1).strip() if m else "")
    return "" if v == "_No response_" else v


def handle_requests(api, state):
    issues = github("GET", "/issues?labels=add-guild&state=open&per_page=50") or []
    for issue in issues:
        title = issue.get("title", "")
        name = form_field(issue.get("body"), "Guild name") or re.sub(r"^\s*Add guild( \(Warcrest\))?:\s*", "", title, flags=re.I)
        # From the add-on's button the title says "(Warcrest)"; on the form, the box is ticked.
        warcrest = "[x]" in form_field(issue.get("body"), "Warcrest").lower() or "(warcrest)" in title.lower()
        slug = slugify(name)
        g = api.fetch("/data/wow/guild/%s?%s" % (slug, PROFILE)) if slug else None
        if g:
            entry = state["guilds"].setdefault(slug, {"added": int(time.time())})
            entry["warcrest"] = entry.get("warcrest") or warcrest
            msg = "Added **%s** (%s, %s). It shows on https://warcrest-addon.com/guilds/ within the hour." % (
                g.get("name", name), (g.get("ruleset") or {}).get("name", "?"), (g.get("faction") or {}).get("name", "?"))
        else:
            msg = ("Couldn't find a WoW: Forever guild called **%s** on Blizzard's armory. Check the spelling "
                   "(and that at least one member is level 10 and has logged out since joining), then open a new request." % name)
        github("POST", "/issues/%s/comments" % issue["number"], {"body": msg})
        github("PATCH", "/issues/%s" % issue["number"], {"state": "closed"})


# ---------------------------------------------------------------------------
def public_index(state, guilds, now):
    out = {"updated": now, "guilds": [], "players": [], "firsts": []}
    for slug, s in guilds.items():
        row = {k: v for k, v in s.items() if k not in ("roster", "bossList")}
        row["warcrest"] = bool(state["guilds"].get(slug, {}).get("warcrest"))
        out["guilds"].append(row)
        for m in s["roster"]:
            if m.get("level", 0) >= MIN_LEVEL:
                out["players"].append({"s": m["slug"], "n": m["name"], "u": m.get("surname", ""), "l": m.get("level", 0),
                                       "c": m.get("class", ""), "g": slug})
    f = state.get("firsts", {})
    names = {p["s"]: p for p in out["players"]}
    for cslug, v in f.get("level60", {}).items():
        p = names.get(cslug)
        if p:
            out["firsts"].append({"kind": "level60", "t": v.get("t"), "who": cslug, "name": "%s %s" % (p["n"], p["u"]), "guild": p["g"]})
    for gslug, bosses in f.get("bosses", {}).items():
        if gslug not in guilds:
            continue
        for key, v in bosses.items():
            boss, inst = key.split("|", 1)
            out["firsts"].append({"kind": "raid" if inst in RAIDS else "dungeon", "t": v.get("t"), "boss": boss,
                                  "instance": inst, "guild": gslug, "who": v.get("by")})
    out["firsts"].sort(key=lambda e: -(e["t"] or 0))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--state", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    os.makedirs(args.state, exist_ok=True)
    path = os.path.join(args.state, "state.json")
    state = json.load(open(path)) if os.path.exists(path) else {}
    state.setdefault("guilds", {})
    seeds = json.load(open(os.path.join(os.path.dirname(__file__), "guilds.json")))
    for g in seeds:
        state["guilds"].setdefault(g["slug"], {"added": int(time.time())}).update({k: v for k, v in g.items() if k != "slug"})
    api = Blizzard(os.environ["BLIZZARD_CLIENT_ID"], os.environ["BLIZZARD_CLIENT_SECRET"])
    handle_requests(api, state)
    now = int(time.time())
    # Guilds not refreshed for longest go first, so a run that runs out of calls carries on next time.
    order = sorted(state["guilds"], key=lambda s: state["guilds"][s].get("updated", 0))
    os.makedirs(os.path.join(args.out, "guilds"), exist_ok=True)
    guilds = {}
    for slug in order:
        old = os.path.join(args.out, "guilds", slug + ".json")
        s = None if api.spent() else update_guild(api, state, slug, now)
        if s is None and os.path.exists(old):
            s = json.load(open(old))  # keep the last good data
        if s is None:
            continue
        if s.get("updated") == now:
            state["guilds"][slug]["updated"] = now
        guilds[slug] = s
        json.dump(s, open(old, "w"), separators=(",", ":"))
    json.dump(public_index(state, guilds, now), open(os.path.join(args.out, "index.json"), "w"), separators=(",", ":"))
    json.dump(state, open(path, "w"), separators=(",", ":"))
    print("guilds: %d, calls: %d" % (len(guilds), api.calls))


if __name__ == "__main__":
    main()
