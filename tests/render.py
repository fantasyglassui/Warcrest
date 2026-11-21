"""
Draws the addon's interface as a picture, from the layout the addon's own code
sets up in the test stand-in (tests/wow.lua). A developer tool for checking the
look without the game; it's an approximation (no game textures, scroll bars or
tooltips), not a screenshot.

    python3 tests/render.py out-folder      # one PNG per panel tab and window
"""
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from harness import ROOT  # noqa: E402

MEDIA = os.path.join(ROOT, "Media")
LAYERS = ["BACKGROUND", "BORDER", "ARTWORK", "OVERLAY"]

H_OF = {"LEFT": 0, "CENTER": 0.5, "RIGHT": 1}
V_OF = {"TOP": 0, "CENTER": 0.5, "BOTTOM": 1}


def split_point(p):
    p = (p or "CENTER").upper()
    v = "TOP" if p.startswith("TOP") else "BOTTOM" if p.startswith("BOTTOM") else "CENTER"
    h = "LEFT" if p.endswith("LEFT") else "RIGHT" if p.endswith("RIGHT") else "CENTER"
    return h, v


def media_path(path):
    """A game texture path inside our addon, as a file here."""
    if not isinstance(path, str) or "Warcrest" not in path:
        return None
    rel = path.split("Warcrest\\", 1)[1].replace("\\", "/")
    for ext in ("", ".tga", ".png"):
        f = os.path.join(ROOT, rel + ext)
        if os.path.isfile(f):
            return f
    return None


class Renderer:
    def __init__(self, client, scale=2):
        self.c, self.scale = client, scale
        self.rects = {}
        self.truncated = set()  # one-line text cut short with "..."
        self.fonts = {}
        L = client.lua
        self.ui = L.eval("UIParent")
        L.execute("UIParent._layout = { points = {}, w = 1280, h = 760 }")

    # --- text ---------------------------------------------------------------
    def font_of(self, w):
        lay = w["_layout"]
        f = lay and lay["font"]
        size, path, color = 12, None, (1, 1, 1)
        if f is not None and f["_layout"] is not None:
            fl = f["_layout"]
            size = fl["size"] or 12
            path = fl["path"]
            if fl["textColor"] is not None:
                tc = fl["textColor"]
                color = (tc[1], tc[2], tc[3])
        if lay and lay["textColor"] is not None:
            tc = lay["textColor"]
            color = (tc[1], tc[2], tc[3])
        file = media_path(path) or os.path.join(MEDIA, "Fonts", "Inter-Regular.ttf")
        key = (file, size)
        if key not in self.fonts:
            self.fonts[key] = ImageFont.truetype(file, int(size * self.scale))
        return self.fonts[key], size, color

    @staticmethod
    def segments(text, color):
        """Text with |cffRRGGBB ... |r color codes, as (text, color) pieces."""
        text = re.sub(r"\|T.*?\|t", "", text)
        text = re.sub(r"\|H.*?\|h(.*?)\|h", r"\1", text)
        out, stack = [], [color]
        for part in re.split(r"(\|c[0-9a-fA-F]{8}|\|r)", text):
            if part.startswith("|c") and len(part) == 10:
                h = part[4:]
                stack.append(tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)))
            elif part == "|r":
                if len(stack) > 1:
                    stack.pop()
            elif part:
                out.append((part, stack[-1]))
        return out

    def text_lines(self, w):
        text = w["_GetText"]
        if text is None or text == "":
            return None
        font, size, color = self.font_of(w)
        segs = self.segments(str(text), color)
        lay = w["_layout"]
        width = lay["w"] if lay is not None else None
        # Word-wrap pieces into lines of (text, color) runs.
        lines, line, used = [], [], 0
        limit = width * self.scale if width else None
        if lay is not None and lay["nowrap"] and limit:
            # One line, cut short with an ellipsis like the game does.
            flat = "".join(s for s, _ in segs).replace("\n", " ")
            if font.getlength(flat) > limit:
                self.truncated.add(flat)
                while flat and font.getlength(flat + "...") > limit:
                    flat = flat[:-1]
                flat = flat.rstrip() + "..."
            # Keep the first piece's color for the whole line.
            return font, size, [[(flat, segs[0][1] if segs else color)]]
        for seg, col in segs:
            for i, chunk in enumerate(seg.split("\n")):
                if i > 0:
                    lines.append(line)
                    line, used = [], 0
                for word in re.findall(r"\S+\s*|\s+", chunk):
                    wlen = font.getlength(word)
                    if limit and used + wlen > limit and line:
                        lines.append(line)
                        line, used = [], 0
                        word = word.lstrip()
                        wlen = font.getlength(word)
                    line.append((word, col))
                    used += wlen
        lines.append(line)
        return font, size, lines

    def natural_size(self, w):
        kind = w["kind"]
        if kind == "FontString":
            t = self.text_lines(w)
            if not t:
                return 0, 0
            font, size, lines = t
            width = max(sum(font.getlength(s) for s, _ in ln) for ln in lines) / self.scale
            return width, len(lines) * size * 1.25
        return 0, 0

    # --- layout ---------------------------------------------------------------
    def rect(self, w, depth=0):
        """(left, top, right, bottom) in interface units, y downwards."""
        key = w["_uid"]
        if key in self.rects:
            return self.rects[key]
        if depth > 60:
            return (0, 0, 0, 0)
        lay = w["_layout"]
        if lay is None:
            parent = w["_parent"]
            r = self.rect(parent, depth + 1) if parent is not None else (0, 0, 1280, 760)
            self.rects[key] = r
            return r
        nat_w, nat_h = self.natural_size(w)
        width = lay["w"] if lay["w"] else (nat_w or None)
        height = lay["h"] if lay["h"] else (nat_h or None)
        parent = w["_parent"]
        xs, ys = {}, {}
        points = lay["points"]
        sp = w["_scrollParent"]
        if sp is not None:
            pr = self.rect(sp, depth + 1)
            xs["LEFT"], ys["TOP"] = pr[0], pr[1]
        elif points is not None and len(points) > 0:
            for i in range(1, len(points) + 1):
                p = points[i]
                rel = p["rel"] if p["rel"] is not None else parent
                rr = self.rect(rel, depth + 1) if rel is not None else (0, 0, 1280, 760)
                rh, rv = split_point(p["relPoint"])
                tx = rr[0] + (rr[2] - rr[0]) * H_OF[rh] + (p["x"] or 0)
                ty = rr[1] + (rr[3] - rr[1]) * V_OF[rv] - (p["y"] or 0)
                h, v = split_point(p["point"])
                xs[h], ys[v] = tx, ty
        else:
            pr = self.rect(parent, depth + 1) if parent is not None else (0, 0, 1280, 760)
            self.rects[key] = pr
            return pr

        def solve(d, size, a, b):
            if a in d and b in d:
                return d[a], d[b]
            size = size or 0
            if a in d:
                return d[a], d[a] + size
            if b in d:
                return d[b] - size, d[b]
            c = d.get("CENTER", 0)
            return c - size / 2, c + size / 2

        left, right = solve(xs, width, "LEFT", "RIGHT")
        top, bottom = solve(ys, height, "TOP", "BOTTOM")
        r = (left, top, right, bottom)
        self.rects[key] = r
        return r

    # --- drawing --------------------------------------------------------------
    def visible(self, w):
        return w["_IsShown"] is not False

    @staticmethod
    def region_shown(t):
        # A checkbox's tick only shows while it's ticked.
        if t["_disabledCheckOf"] is not None:
            return False
        owner = t["_checkedOf"]
        if owner is not None:
            return owner["_GetChecked"] is True
        return True

    def kids(self, w):
        k = w["_kids"]
        return [k[i] for i in range(1, len(k) + 1)] if k is not None else []

    def draw_region(self, img, w, clip, alpha):
        lay = w["_layout"]
        if lay is None:
            return
        l, t, r, b = self.rect(w)
        s = self.scale
        box = [int(round(l * s)), int(round(t * s)), int(round(r * s)), int(round(b * s))]
        if clip:
            box = [max(box[0], clip[0]), max(box[1], clip[1]), min(box[2], clip[2]), min(box[3], clip[3])]
        a = alpha * (lay["alpha"] if lay["alpha"] is not None else 1)
        if w["kind"] == "Texture":
            if box[2] <= box[0] or box[3] <= box[1]:
                return
            if lay["color"] is not None:
                c = lay["color"]
                layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
                ImageDraw.Draw(layer).rectangle([box[0], box[1], box[2] - 1, box[3] - 1],
                                                fill=(int(c[1] * 255), int(c[2] * 255), int(c[3] * 255), int(c[4] * 255 * a)))
                img.alpha_composite(layer)
            elif media_path(lay["tex"]):
                im = Image.open(media_path(lay["tex"])).convert("RGBA")
                size = (int(round((r - l) * s)), int(round((b - t) * s)))
                if size[0] <= 0 or size[1] <= 0:
                    return
                im = im.resize(size, Image.LANCZOS)
                if lay["tint"] is not None:
                    tc = lay["tint"]
                    px = Image.new("RGBA", im.size, (int(tc[1] * 255), int(tc[2] * 255), int(tc[3] * 255), 255))
                    px.putalpha(im.getchannel("A"))
                    im = px
                if a < 1:
                    im.putalpha(im.getchannel("A").point(lambda v: int(v * a)))
                layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
                layer.paste(im, (int(round(l * s)), int(round(t * s))))
                if clip:
                    mask = Image.new("L", img.size, 0)
                    ImageDraw.Draw(mask).rectangle(clip, fill=255)
                    layer.putalpha(Image.composite(layer.getchannel("A"), Image.new("L", img.size, 0), mask))
                img.alpha_composite(layer)
        elif w["kind"] == "FontString":
            tl = self.text_lines(w)
            if not tl:
                return
            font, size, lines = tl
            layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
            d = ImageDraw.Draw(layer)
            justify = (lay["justify"] or "LEFT").upper()
            y = t * s
            for ln in lines:
                lw = sum(font.getlength(x) for x, _ in ln)
                x = l * s
                if justify == "CENTER":
                    x = (l + r) / 2 * s - lw / 2
                elif justify == "RIGHT":
                    x = r * s - lw
                for word, col in ln:
                    d.text((x, y), word, font=font, fill=(int(col[0] * 255), int(col[1] * 255), int(col[2] * 255), int(255 * a)))
                    x += font.getlength(word)
                y += size * 1.25 * s
            if clip:
                mask = Image.new("L", img.size, 0)
                ImageDraw.Draw(mask).rectangle(clip, fill=255)
                layer.putalpha(Image.composite(layer.getchannel("A"), Image.new("L", img.size, 0), mask))
            img.alpha_composite(layer)

    def draw_frame(self, img, w, clip=None, alpha=1.0):
        if not self.visible(w):
            return
        lay = w["_layout"]
        a = alpha * (lay["alpha"] if lay is not None and lay["alpha"] is not None else 1)
        regions = [k for k in self.kids(w) if k["kind"] in ("Texture", "FontString") and self.visible(k)
                   and self.region_shown(k)]
        for layer in LAYERS:
            for k in regions:
                kl = k["_layout"]
                if kl is not None and (kl["layer"] or "ARTWORK") == layer:
                    self.draw_region(img, k, clip, a)
        if w["kind"] == "EditBox" and w["_GetText"]:
            # Typed text, inset like the real box.
            font, size, color = self.font_of(w)
            l, t, r, b = self.rect(w)
            s = self.scale
            layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
            ImageDraw.Draw(layer).text(((l + 7) * s, ((t + b) / 2 - size * 0.62) * s), str(w["_GetText"]), font=font,
                                       fill=(int(color[0] * 255), int(color[1] * 255), int(color[2] * 255), 255))
            img.alpha_composite(layer)
        child_clip = clip
        if lay is not None and lay["scrollChild"] is not None:
            l, t, r, b = self.rect(w)
            s = self.scale
            child_clip = [int(l * s), int(t * s), int(r * s), int(b * s)]
            if clip:
                child_clip = [max(child_clip[0], clip[0]), max(child_clip[1], clip[1]),
                              min(child_clip[2], clip[2]), min(child_clip[3], clip[3])]
        for k in self.kids(w):
            if k["kind"] not in ("Texture", "FontString"):
                self.draw_frame(img, k, child_clip, a)

    def render(self, frame, path, pad=24):
        self.rects = {}
        l, t, r, b = self.rect(frame)
        s = self.scale
        img = Image.new("RGBA", (1280 * s, 760 * s), (5, 7, 11, 255))
        self.draw_frame(img, frame)
        crop = (max(0, int((l - pad) * s)), max(0, int((t - pad) * s)),
                min(img.size[0], int((r + pad) * s)), min(img.size[1], int((b + pad) * s)))
        img.crop(crop).convert("RGB").save(path)
        return path


def demo_guild(guild_name=None, locale=None):
    """A small guild with some history, so every tab has something to show.
    guild_name: another guild than The Imperium (to show Warcrest's own look)."""
    from harness import Guild
    members = [("Thorne", 1, "WARRIOR"), ("Lyra", 3, "MAGE"), ("Mira", 3, "PRIEST"), ("Brakk", 3, "ROGUE"),
               ("Aldric", 3, "PALADIN"), ("Seren", 3, "DRUID", 58)]
    code = ('GUILD_NAME = "%s"; ' % guild_name if guild_name else "") + ('gameLocale = "%s"; ' % locale if locale else "")
    if os.environ.get("WARCREST_ACCESS"):   # e.g. "textSize = 130, contrast = true, colorblind = true"
        code += "WarcrestDB = { access = { %s } }" % os.environ["WARCREST_ACCESS"]
    setup = (lambda c: c.run(code)) if code else None
    guild = Guild(members, raid=["Thorne", "Lyra", "Mira", "Brakk"], setup=setup)
    me = guild["Thorne"]
    me.fire("GUILD_ROSTER_UPDATE")
    t = int(guild.clock)
    kills = [("Ganker", ["Thorne", "Lyra"]), ("Shadowstep", ["Lyra"]), ("Grimtusk", ["Brakk", "Thorne", "Mira"]),
             ("Venomfang", ["Mira"]), ("Bonecrusher", ["Thorne"]), ("Nightreaver", ["Lyra"])]
    for i, (victim, killers) in enumerate(kills):
        me.ns.MergeKill(me.lua.eval('{ t = %d, kind = "kill_world", victim = "%s", zone = "Stranglethorn Vale", killers = { %s } }'
                                    % (t - i * 3000, victim, ",".join('"%s"' % k for k in killers))))
    deaths = [("Lyra", "Ganker-Stormrage"), ("Lyra", "Ganker-Stormrage"), ("Mira", "Ganker-Stormrage"),
              ("Brakk", "Shadowfang-Stormrage"), ("Seren", "Shadowfang-Stormrage"), ("Brakk", "Shadowfang-Stormrage")]
    for i, (who, killer) in enumerate(deaths):
        me.ns.MergeDeath(me.lua.eval('{ t = %d, who = "%s", kind = "pvp", sub = "world", zone = "Stranglethorn Vale", killer = "%s" }'
                                     % (t - 20000 - i * 4000, who, killer)))
    me.lua.eval('function(ns, t) table.insert(ns.db.spotted, 1, { name = "Shadowfang", zone = "Booty Bay", by = "Thorne", t = t, mapID = 1434, x = 0.3, y = 0.7 }); ns.OnHistoryChanged() end')(me.ns, t - 600)
    me.lua.eval("""function(ns, t)
      local log = ns.db.audit
      local function add(dt, actor, action, target, detail)
        table.insert(log, 1, { t = t - dt, actor = actor, action = action, target = target, detail = detail or "" })
      end
      add(400000, "Seren", "join", "Seren")
      add(300000, "Thorne", "promote", "Lyra", "Officer")
      add(200000, "Thorne", "onote", "Brakk")
      add(90000, "Aldric", "join", "Aldric")
      add(40000, "Thorne", "motd")
      add(5000, "Thorne", "promote", "Mira", "Veteran")
    end""")(me.ns, t)
    items = [(19019, "Thunderfury, Blessed Blade of the Windseeker"), (16901, "Stormrage Legguards"),
             (17076, "Bonereaver's Edge"), (18814, "Choker of the Fire Lord"), (16922, "Leggings of Transcendence")]
    def link(i):
        return "|cffa335ee|Hitem:%d::::::::60:::::::|h[%s]|h|r" % items[i]
    for who, wishes in [("Lyra", [(0, "need"), (3, "want")]), ("Brakk", [(0, "need"), (2, "need")]),
                        ("Mira", [(4, "need"), (3, "need")]), ("Thorne", [(1, "want"), (2, "want"), (0, "want")])]:
        for i, prio in wishes:
            guild[who].ns.WishlistAdd(link(i), prio)
    guild.run(2)
    ev = me.ns.CreateRaid("Hyjal Summit", t + 3 * 86400, "Bring fire resistance gear.")
    me.ns.CreateRaid("Barrow Deeps", t + 6 * 86400, "")
    me.ns.CreateRaid("Hyjal Summit", t + 10 * 86400, "")
    guild.run(2)
    # Past raid nights and boss kills (backdated), for the calendar and progress.
    me.lua.eval("""function(ns, now)
      local everyone = "Thorne,Lyra,Mira,Brakk,Aldric,Seren"
      local function at(e, t) e.t = t; return e end
      local night = 0
      local function raid(daysAgo, title, kills)
        local start = now - daysAgo * 86400 - 3 * 3600
        at(ns.LedgerAdd("RS", { ref = "", onTime = 10, hourly = 10, title = title, boss = 15 }), start)
        for i, k in ipairs(kills) do
          at(ns.LedgerAdd("BK", { boss = k[1], name = k[2], raid = title, size = 6, names = everyone }), start + i * 1500)
        end
      end
      raid(18, "Barrow Deeps", { {3001, "Gravewarden Ulric"}, {3002, "The Hollow King"}, {3003, "Mistress Vael"} })
      raid(15, "Barrow Deeps", { {3001, "Gravewarden Ulric"}, {3002, "The Hollow King"}, {3003, "Mistress Vael"},
        {3004, "Rotfang"}, {3005, "Barrow Wight Lord"} })
      raid(11, "Barrow Deeps", { {3001, "Gravewarden Ulric"}, {3002, "The Hollow King"}, {3003, "Mistress Vael"},
        {3004, "Rotfang"}, {3005, "Barrow Wight Lord"}, {3006, "The Twin Shades"}, {3007, "Morbane"},
        {3008, "Ancient of Bones"} })
      raid(8, "Onyxia's Lair", { {1084, "Onyxia"} })
      raid(4, "Hyjal Summit", { {2001, "Rage Winterchill"}, {2002, "Anetheron"} })
      raid(1, "Hyjal Summit", { {2001, "Rage Winterchill"}, {2002, "Anetheron"}, {2003, "Kaz'rogal"}, {2004, "Azgalor"} })
    end""")(me.ns, t)
    guild.run(2)
    for n, role in [("Lyra", "dps"), ("Mira", "healer"), ("Brakk", "dps")]:
        guild[n].ns.SignUp(ev.id, "accept", role)
        guild.run(0.5)
    me.ns.SignUp(ev.id, "accept", "tank")
    guild.run(0.5)
    me.ns.AutoPlan(ev.id, 10)
    guild.run(1)
    me.ns.SetPlanGroup(ev.id, "Brakk", 2)
    guild.run(1)
    guild["Lyra"].ns.SetTitle("bounty")
    guild.run(1)
    me.ns.StartRaidSession(ev.id, "Hyjal Summit", 10, 10, 15)
    guild.run(3)
    me.ns.AwardDKP(me.lua.table_from(["Lyra", "Mira"]), 25, "Ragnaros bonus")
    guild.run(3)
    # Guild events, with answers.
    now = int(guild.clock)
    pvp = me.ns.CreateGuildEvent("pvp", "Tarren Mill raid", now + 26 * 3600, "Meet at the inn. Bring flasks.", 120)
    guild.run(1)
    guild["Lyra"].ns.CreateGuildEvent("worldboss", "Kazzak hunt", now + 50 * 3600, "", 90)
    guild.run(1)
    for n, st in (("Lyra", "going"), ("Mira", "maybe"), ("Brakk", "going"), ("Thorne", "going")):
        guild[n].ns.EventSignUp(pvp.id, st)
        guild.run(0.5)
    # Profiles.
    def profile(c, spec, role, days, hours, bday, note, ilvl):
        c.run('equipped = {} itemLevels = {} for slot = 1, 18 do if slot ~= 4 then '
              'equipped[slot] = "i" .. slot itemLevels["i" .. slot] = { %d } end end' % ilvl)
        t = c.lua.eval("{}")
        t["spec"], t["role"], t["hours"], t["bday"], t["note"] = spec, role, hours, bday, note
        t["days"] = c.lua.table_from(days)
        c.ns.SaveMyProfile(t)
        guild.run(0.5)
    weekdays = [True] * 5 + [False] * 2
    profile(me, "Protection", "tank", weekdays, "19:00-23:00", "03-14", "Main tank, raid lead on Thursdays", 66)
    profile(guild["Lyra"], "Frost", "dps", [False, False, True, True, False, True, True], "20:00-00:00", "", "", 63)
    profile(guild["Mira"], "Holy", "healer", weekdays, "18:00-22:00", "", "Loves Alterac Valley", 61)
    profile(guild["Brakk"], "Combat", "dps", [False] * 5 + [True] * 2, "14:00-18:00", "", "", 58)
    # Recruits.
    me.ns.SetRecruit("Jaina", me.lua.eval('{ class = "MAGE", level = 60, note = "Frost mage, raided Naxx before" }'))
    guild.run(0.5)
    me.ns.SetRecruit("Valeera", me.lua.eval('{ class = "ROGUE", level = 58, status = "contacted" }'))
    guild.run(0.5)
    me.ns.SetRecruit("Brakk", me.lua.eval('{ status = "trial" }'))
    guild.run(0.5)
    me.fire("CHAT_MSG_WHISPER", "hey, is your guild recruiting healers?", "Anduin-Realm")
    guild.run(1)
    # Enemy guilds and a rival.
    for c in guild.clients.values():
        for victim, g in (("Ganker", "Bloodfang"), ("Shadowstep", "Bloodfang"), ("Grimtusk", "Iron Horde")):
            c.ns.NoteEnemyGuild(victim, g)
    me.ns.SetRival("Bloodfang", True)
    guild.run(1)
    # Crafters.
    names = {14155: "Mooncloth Bag", 13858: "Runecloth Robe", 14156: "Felcloth Bag", 13442: "Mighty Rage Potion",
             13445: "Elixir of Superior Defense", 12360: "Arcanite Bar", 13444: "Major Mana Potion", 16904: "Bloodfang Hood"}
    for c in guild.clients.values():
        c.run("; ".join('itemNames[%d] = "%s"' % kv for kv in names.items()))
    def crafts(c, prof, rank, ids):
        rec = ", ".join('{ "%s", "optimal", "|Hitem:%d|h[%s]|h" }' % (names[i], i, names[i]) for i in ids)
        c.run('tradeSkill = { name = "%s", rank = %d, max = 300, recipes = { %s } }' % (prof, rank, rec))
        c.fire("TRADE_SKILL_SHOW")
        guild.run(1.5)
    crafts(guild["Lyra"], "Tailoring", 300, [14155, 13858, 14156])
    crafts(guild["Mira"], "Alchemy", 285, [13442, 13445, 12360, 13444])
    crafts(me, "Alchemy", 300, [13442, 13444, 12360])
    guild.run(35)
    # Attunements.
    for name, quests in (("Thorne", (7848, 6602, 7761, 4743)), ("Lyra", (7848, 6502, 4743, 5505)), ("Mira", (7848,)),
                         ("Brakk", (7848, 6602, 4743)), ("Aldric", ())):
        c = guild[name]
        c.run("; ".join("questsDone[%d] = true" % q for q in quests) or "x = 1")
        c.ns.CheckAttunements(True)
    guild.run(2)
    # Raid assignments.
    me.ns.SaveAssignment("Molten Core", "Ragnaros", "Tanks: Thorne on Ragnaros, Brakk on the sons\n"
                         "Healers: Mira on Thorne, Lyra on groups 1-3\nDecurse: Lyra\nEveryone: melee back out at knockback")
    me.ns.SaveAssignment("Molten Core", "Lucifron", "Tanks: Thorne on Lucifron, Brakk and Aldric on the adds\nDecurse: Lyra, Mira")
    guild.run(3)
    # Boss pulls.
    for boss, secs, ok, back in (("Lucifron", 140, False, 9000), ("Lucifron", 118, True, 8800), ("Ragnaros", 300, False, 5000),
                                 ("Ragnaros", 280, False, 4800), ("Ragnaros", 412, True, 4600)):
        me.ns.LedgerAdd("BP", me.lua.table_from({"raid": "Molten Core", "enc": boss, "ok": "1" if ok else "0", "secs": secs}))
        guild.run(70)
    for boss, secs, ok in (("Rage Winterchill", 96, False), ("Rage Winterchill", 214, True), ("Rage Winterchill", 188, True),
                           ("Anetheron", 160, False), ("Anetheron", 131, False), ("Anetheron", 247, True), ("Anetheron", 239, True),
                           ("Kaz'rogal", 305, True), ("Azgalor", 122, False), ("Azgalor", 296, True)):
        me.ns.LedgerAdd("BP", me.lua.table_from({"raid": "Hyjal Summit", "enc": boss, "ok": "1" if ok else "0", "secs": secs}))
        guild.run(65)
    # A poll and crafting orders.
    me.ns.StartPoll("Which night for Blackwing Lair?", me.lua.table_from(["Thursday", "Friday", "Sunday"]), 3)
    guild.run(2)
    poll = me.ns.Polls()[1]
    for name, choice in (("Thorne", 1), ("Lyra", 2), ("Mira", 2), ("Brakk", 3)):
        guild[name].ns.VotePoll(poll.id, choice)
    guild["Lyra"].ns.PlaceCraftOrder("Thorne", "13444", True, "20 please")
    me.ns.PlaceCraftOrder("Lyra", "14155", False, "")
    guild.run(3)
    # Guild goals.
    me.ns.AddGoal("kills", 50, "week")
    me.ns.AddGoal("bosses", 3, "week")
    me.ns.AddGoal("raidnights", 8, "month")
    guild.run(1)
    return guild, me


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "render"
    os.makedirs(out, exist_ok=True)
    guild, me = demo_guild(guild_name=os.environ.get("WARCREST_GUILD"), locale=os.environ.get("WARCREST_LOCALE"))
    rd = Renderer(me)
    panel = None
    for tab in ("home", "roster", "raids", "events", "calendar", "recruit", "dkp", "wishlist", "kills", "wanted", "achievements", "settings", "officers", "addon"):
        me.ns.OpenPanel(tab)
        me.ns.RefreshPanel()
        panel = me.lua.eval("WarcrestPanel")
        print(rd.render(panel, os.path.join(out, "panel-%s.png" % tab)))
    for tab, view in (("settings", "sounds"), ("settings", "general"), ("settings", "access"), ("achievements", "hunt"), ("achievements", "raid"), ("achievements", "loot"), ("achievements", "social"), ("achievements", "guild"),
                      ("raids", "plan"), ("raids", "progress"), ("wanted", "guilds"),
                      ("events", "polls"), ("officers", "inactive")):
        me.ns.OpenPanel(tab, view)
        print(rd.render(panel, os.path.join(out, "panel-%s-%s.png" % (tab, view))))
    me.ns.OpenPanel("settings", "alerts")
    me.ns.ShowAltsWindow()
    print(rd.render(me.lua.eval("WarcrestAlts"), os.path.join(out, "window-alts.png")))
    me.ns.ShowPlayerCard("Lyra")
    print(rd.render(me.lua.eval("WarcrestPlayerCard"), os.path.join(out, "window-player-card.png")))
    me.ns.ShowPlayerCard(me.name)
    print(rd.render(me.lua.eval("WarcrestPlayerCard"), os.path.join(out, "window-player-card-me.png")))
    me.ns.ShowProfileEditor()
    print(rd.render(me.lua.eval("WarcrestProfile"), os.path.join(out, "window-profile.png")))
    me.ns.ShowProfiles()
    print(rd.render(panel, os.path.join(out, "panel-profiles.png")))
    me.ns.ShowCrafters()
    print(rd.render(panel, os.path.join(out, "panel-crafters.png")))
    me.ns.ShowHelp()
    print(rd.render(me.lua.eval("WarcrestHelp"), os.path.join(out, "window-help.png")))
    me.ns.ShowBugReport()
    print(rd.render(me.lua.eval("WarcrestReport"), os.path.join(out, "window-report.png")))
    me.ns.ShowAttunements()
    print(rd.render(me.lua.eval("WarcrestAttunements"), os.path.join(out, "window-attunements.png")))
    me.ns.ShowAssignments("Molten Core", "Ragnaros")
    print(rd.render(me.lua.eval("WarcrestAssignments"), os.path.join(out, "window-assignments.png")))
    guild["Lyra"].ns.ShowAssignments("Molten Core", "Ragnaros")
    print(rd.render(guild["Lyra"].lua.eval("WarcrestAssignments"), os.path.join(out, "window-assignments-member.png")))
    me.ns.ShowCrafters(None, "orders")
    print(rd.render(panel, os.path.join(out, "panel-crafters-orders.png")))
    me.ns.ShowCrafters(None, "recipes")
    me.ns.ShowGettingStarted()
    print(rd.render(me.lua.eval("WarcrestGettingStarted"), os.path.join(out, "window-getting-started.png")))
    for step in (2, 3):
        me.ns.ShowWelcome(step)
        print(rd.render(me.lua.eval("WarcrestWelcome"), os.path.join(out, "window-welcome-%d.png" % step)))
    me.ns.UI.NewGuildEvent()
    print(rd.render(panel, os.path.join(out, "panel-events-new.png")))
    me.ns.OpenPanel("achievements")
    me.ns.ShowTitleChooser()
    print(rd.render(me.lua.eval("WarcrestTitles"), os.path.join(out, "window-titles.png")))
    print("truncated:", rd.truncated)
