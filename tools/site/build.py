#!/usr/bin/env python3
"""
Builds the website's language pages and its "What's new" section.

  python3 tools/site/build.py            fill docs/index.html's What's new, write docs/de, docs/fr, docs/es
                                         and the changelog pages (docs/changelog, docs/<lang>/changelog)
  python3 tools/site/build.py --missing  list the English text that has no translation yet

docs/index.html is the English page and the one to edit. The other pages are
made from it: its text is looked up in tools/site/i18n/<lang>.json (English ->
translation). Achievement names, descriptions and titles, and the What's new
items, come from the addon itself (Locales/*.lua and UI/Updates.lua), so they
read exactly as they do in game. Text with no translation stays in English.
"""
import html
import json
import os
import re
import sys
from html.parser import HTMLParser

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import changelog  # noqa: E402
import guilds  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DOCS = os.path.join(ROOT, "docs")
SITE = "https://warcrest-addon.com/"
NEWS_SHOWN = 3

LANGS = [  # code, locale file, html lang, og locale, name in its own language, short label
    ("en", None, "en", "en_US", "English", "EN"),
    ("de", "deDE", "de", "de_DE", "Deutsch", "DE"),
    ("fr", "frFR", "fr", "fr_FR", "Français", "FR"),
    ("es", "esES", "es", "es_ES", "Español", "ES"),
]
MONTHS = {
    "de": ["Jan.", "Feb.", "März", "Apr.", "Mai", "Juni", "Juli", "Aug.", "Sep.", "Okt.", "Nov.", "Dez."],
    "fr": ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."],
    "es": ["ene.", "feb.", "mar.", "abr.", "may.", "jun.", "jul.", "ago.", "sept.", "oct.", "nov.", "dic."],
}
EN_MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

INLINE = {"b", "strong", "em", "i", "code", "a", "span", "br", "small", "abbr", "input", "kbd"}
BLOCKISH = {"title", "h1", "h2", "h3", "h4", "p", "li", "figcaption", "option", "button", "td", "th", "summary"}
VOID = {"br", "img", "meta", "link", "input", "source", "hr", "path", "circle", "rect", "use", "polyline", "line"}
ATTRS = ("alt", "title", "placeholder", "aria-label")
META_TEXT = {"description", "og:title", "og:description", "og:image:alt"}


def lua_unescape(s):
    return re.sub(r'\\(.)', lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), s)


def norm(s):
    return " ".join(s.split())


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def addon_locale(code):
    """English -> translation, from the addon's own Locales file."""
    out = {}
    for m in re.finditer(r'^\s*\["((?:[^"\\]|\\.)*)"\] = "((?:[^"\\]|\\.)*)",\s*$', read(os.path.join(ROOT, "Locales", code + ".lua")), re.M):
        out[lua_unescape(m.group(1))] = lua_unescape(m.group(2))
    return out


def releases(limit=NEWS_SHOWN):
    """The newest entries of UI/Updates.lua's CHANGES: (version, date, [items])."""
    src = read(os.path.join(ROOT, "UI", "Updates.lua"))
    src = src[src.index("local CHANGES = {"):]
    out = []
    for m in re.finditer(r'\{ version = "([^"]+)", date = "([^"]+)", items = \{(.*?)\n  \} \}', src, re.S):
        items = [lua_unescape(x) for x in re.findall(r'^\s*"((?:[^"\\]|\\.)*)",\s*$', m.group(3), re.M)]
        out.append((m.group(1), m.group(2), items))
        if limit and len(out) >= limit:
            break
    return out


def local_date(lang, text):
    m = re.match(r"(\w+) (\d+), (\d+)", text)
    if not m or lang == "en":
        return text
    month, day, year = EN_MONTHS.index(m.group(1)[:3]), int(m.group(2)), m.group(3)
    name = MONTHS[lang][month]
    if lang == "de":
        return "%d. %s %s" % (day, name, year)
    return "%d %s %s" % (day, name, year)


def iso_date(text):
    m = re.match(r"(\w+) (\d+), (\d+)", text)
    return "%s-%02d-%02d" % (m.group(3), EN_MONTHS.index(m.group(1)[:3]) + 1, int(m.group(2))) if m else ""


def news_item(t, tr):
    t = html.escape(tr.get(t, t), quote=False)
    return re.sub(r"(/warcrest(?: [a-z]+)?)", r"<code>\1</code>", t)


def news_html(lang, tr):
    item = lambda t: news_item(t, tr)
    parts = []
    for version, date, items in releases():
        lis = "".join("<li>%s</li>" % item(t) for t in items)
        parts.append('<article class="release"><header><h3>%s</h3><time datetime="%s">%s</time></header><ul>%s</ul></article>'
                     % (version, iso_date(date), local_date(lang, date), lis))
    return "\n        ".join(parts)


class Units(HTMLParser):
    """Finds the page's pieces of text: each element that holds text, taken whole (with its inline markup)."""

    def __init__(self, src):
        super().__init__(convert_charrefs=False)
        self.src = src
        self.lines = [0]
        for line in src.split("\n"):
            self.lines.append(self.lines[-1] + len(line) + 1)
        self.stack = []   # [tag, inner start, has direct text, has block child, is unit candidate]
        self.units = []   # (start, end) of inner HTML
        self.tags = []    # (start, end) of start tags, for attributes
        self.skip = 0

    def here(self):
        line, col = self.getpos()
        return self.lines[line - 1] + col

    def handle_starttag(self, tag, attrs):
        start = self.here()
        text = self.get_starttag_text()
        self.tags.append((start, start + len(text)))
        if tag in ("script", "style", "svg"):
            self.skip += 1
        if self.stack and tag not in INLINE:
            self.stack[-1][3] = True
        if tag not in VOID:
            self.stack.append([tag, start + len(text), False, False])

    def handle_startendtag(self, tag, attrs):
        start = self.here()
        self.tags.append((start, start + len(self.get_starttag_text())))

    def handle_endtag(self, tag):
        end = self.here()
        while self.stack:
            t, inner, direct, block = self.stack.pop()
            if t == tag:
                break
        else:
            return
        if tag in ("script", "style", "svg"):
            self.skip -= 1
            return
        if self.skip:
            return
        body = self.src[inner:end]
        if not block and (direct or tag in BLOCKISH) and re.search(r"[A-Za-z]", re.sub(r"<[^>]*>", "", body)) and "<svg" not in body:
            # Keep only the outermost: drop units inside this one.
            self.units = [u for u in self.units if not (u[0] >= inner and u[1] <= end)]
            self.units.append((inner, end))
            for anc in self.stack:  # an ancestor holding this whole unit isn't one itself
                anc[3] = anc[3] or tag not in INLINE

    def handle_data(self, data):
        if self.stack and data.strip():
            self.stack[-1][2] = True


def script_bounds(src):
    a = src.index("<script>")
    return a, src.index("</script>", a)


class Used(dict):
    """A translation table that remembers which keys were looked up."""
    def __init__(self, *a):
        super().__init__(*a)
        self.used = set()

    def __contains__(self, k):
        hit = super().__contains__(k)
        if hit:
            self.used.add(k)
        return hit


def translate_page(lang, src, tr, ach, missing):
    """The English page in another language."""
    def t(s):
        key = norm(html.unescape(s)) if "<" not in s else norm(s)
        if key in tr:
            return tr[key]
        if re.search(r"[A-Za-z]{2}", re.sub(r"<[^>]*>", "", key)):
            missing.add(key)
        return None

    sa, sb = script_bounds(src)
    head, script, tail = src[:sa], src[sa:sb], src[sb:]

    def html_part(part, base):
        p = Units(part)
        p.feed(part)
        edits = []
        for a, b in p.units:
            new = t(part[a:b])
            if new is not None:
                edits.append((a, b, new))
        for a, b in p.tags:
            tagtext = part[a:b]
            new = tagtext
            for attr in ATTRS:
                m = re.search(r'\s%s="([^"]*)"' % attr, new)
                if m and not new.startswith("<option"):
                    v = t(m.group(1))
                    if v is not None:
                        new = new[:m.start(1)] + html.escape(v) + new[m.end(1):]
            m = re.match(r'<meta (?:name|property)="([^"]+)" content="([^"]*)"', new)
            if m and m.group(1) in META_TEXT:
                v = t(m.group(2))
                if v is not None:
                    new = new[:m.start(2)] + html.escape(v) + new[m.end(2):]
            if new != tagtext:
                edits.append((a, b, new))
        edits.sort(reverse=True)
        last = None
        for a, b, new in edits:
            if last is not None and b > last:
                continue  # overlapping (an attribute inside a unit already replaced)
            part = part[:a] + new + part[b:]
            last = a
        return part

    head = html_part(head, 0)
    tail = html_part(tail, 0)

    # The script: achievements from the addon, then any string listed in the translations.
    def js(m):
        s = json.loads('"' + m.group(1) + '"')
        if s in tr:
            return json.dumps(tr[s], ensure_ascii=False)
        if re.search(r"[A-Z][a-z]+ [a-z]", s):
            missing.add(s)
        return m.group(0)
    lines = []
    for line in script.split("\n"):
        st = line.strip()
        if st.startswith("var A = "):
            A = json.loads(st[len("var A = "):].rstrip(";"))
            A = [[a[0]] + [ach.get(x, x) if x else x for x in a[1:]] for a in A]
            line = line[:line.index("var A = ")] + "var A = " + json.dumps(A, ensure_ascii=False, separators=(",", ":")) + ";"
        elif st.startswith("var FEATURED = "):
            F = json.loads(st[len("var FEATURED = "):].rstrip(";"))
            line = line[:line.index("var FEATURED = ")] + "var FEATURED = " + json.dumps([ach.get(x, x) for x in F], ensure_ascii=False) + ";"
        elif not st.startswith("//"):
            line = re.sub(r'"((?:[^"\\]|\\.)*)"', js, line)
        lines.append(line)
    script = "\n".join(lines)
    return head + script + tail


def links(src, lang):
    """hreflang links, the language menu and the footer list, for the page in `lang`."""
    url = lambda c: SITE + ("" if c == "en" else c + "/")
    alt = "\n".join('<link rel="alternate" hreflang="%s" href="%s">' % (c, url(c)) for c, *_ in LANGS)
    alt += '\n<link rel="alternate" hreflang="x-default" href="%s">' % SITE
    src = re.sub(r'(?:<link rel="alternate" hreflang="[^"]+" href="[^"]+">\n)*(<link rel="canonical"[^>]*>)',
                 lambda m: alt + "\n" + m.group(1), src, count=1)
    rel = lambda c: ("/" if c == "en" else "/" + c + "/")
    cur = lambda c: ' aria-current="page"' if c == lang else ""
    menu = "".join('<li><a href="%s" hreflang="%s" lang="%s"%s>%s</a></li>' % (rel(c), c, h, cur(c), name)
                   for c, _, h, _, name, _ in LANGS)
    src = re.sub(r"<ul><!--langmenu-->.*?</ul>", "<ul><!--langmenu-->" + menu + "</ul>", src, count=1, flags=re.S)
    foot = "".join('<a href="%s" hreflang="%s" lang="%s"%s>%s</a>' % (rel(c), c, h, cur(c), name) for c, _, h, _, name, _ in LANGS)
    src = re.sub(r"<!--langs-->.*?</div>", "<!--langs-->" + foot + "</div>", src, count=1, flags=re.S)
    short = [x for x in LANGS if x[0] == lang][0][5]
    src = re.sub(r"(</svg>)(EN|DE|FR|ES)(</summary>)", r"\g<1>" + short + r"\3", src, count=1)
    return src


def fill_news(src, lang, tr):
    return re.sub(r"<!--news-->.*?<!--/news-->", lambda m: "<!--news-->" + news_html(lang, tr) + "<!--/news-->", src, count=1, flags=re.S)


def changelog_pages(pages):
    """docs/changelog/ and docs/<lang>/changelog/. pages: lang -> its built main page."""
    all_releases = releases(limit=None)
    dates = {v: d for v, d, _ in all_releases}
    notes = {v: items for v, _, items in all_releases}
    detail = changelog.markdown_releases(read(os.path.join(ROOT, "CHANGELOG.md")))
    version = re.search(r"## Version: (\S+)", read(os.path.join(ROOT, "Warcrest.toc"))).group(1)
    for code, loc, *_ in LANGS:
        if code == "en":
            entries = [(v, body, False) for v, body in detail]
        else:
            addon = addon_locale(loc)
            entries = []
            for v, _ in detail:
                items = notes.get(v)
                body = "<ul>%s</ul>" % "".join("<li>%s</li>" % news_item(t, addon) for t in items) if items else ""
                entries.append((v, body, not items))
        out = changelog.page(code, pages[code], entries, dates, version, local_date, iso_date)
        write(os.path.join(DOCS, *([] if code == "en" else [code]), "changelog", "index.html"), out)


def main():
    show_missing = "--missing" in sys.argv
    prune = "--prune" in sys.argv  # drop translations the page no longer uses
    index = os.path.join(DOCS, "index.html")
    src = links(fill_news(read(index), "en", {}), "en")
    write(index, src)
    pages = {"en": src}
    for code, loc, hl, ogl, name, short in LANGS[1:]:
        tr_path = os.path.join(os.path.dirname(__file__), "i18n", code + ".json")
        raw = json.load(open(tr_path, encoding="utf-8"))
        tr = Used({norm(k): v for k, v in raw.items()})
        addon = addon_locale(loc)
        missing = set()
        page = re.sub(r"<!--news-->.*?<!--/news-->", "<!--news--><!--/news-->", src, count=1, flags=re.S)
        page = re.sub(r"<!--langs-->.*?</div>", "<!--langs--></div>", page, count=1, flags=re.S)
        page = re.sub(r"<ul><!--langmenu-->.*?</ul>", "<ul><!--langmenu--></ul>", page, count=1, flags=re.S)
        page = translate_page(code, page, tr, addon, missing)
        page = links(fill_news(page, code, addon), code)
        page = page.replace('<html lang="en">', '<html lang="%s">' % hl, 1)
        page = page.replace('<link rel="canonical" href="%s">' % SITE, '<link rel="canonical" href="%s%s/">' % (SITE, code), 1)
        page = page.replace('<meta property="og:url" content="%s">' % SITE, '<meta property="og:url" content="%s%s/">' % (SITE, code), 1)
        page = page.replace('<meta property="og:locale" content="en_US">', '<meta property="og:locale" content="%s">' % ogl, 1)
        page = page.replace('value="%s#thanks"' % SITE, 'value="%s%s/#thanks"' % (SITE, code), 1)
        page = page.replace('href="/changelog/"', 'href="/%s/changelog/"' % code)
        page = re.sub(r'(src|href)="img/', r'\1="../img/', page)
        page = page.replace('"img/"', '"../img/"')
        write(os.path.join(DOCS, code, "index.html"), page)
        unused = [k for k in raw if norm(k) not in tr.used]
        if unused:
            print("%s: %d unused%s" % (code, len(unused), ", removed" if prune else " (--prune removes them)"))
            if prune:
                with open(tr_path, "w", encoding="utf-8") as f:
                    json.dump({k: v for k, v in raw.items() if k not in unused}, f, ensure_ascii=False, indent=1)
                    f.write("\n")
        pages[code] = page
        if show_missing or missing:
            print("%s: %d missing" % (code, len(missing)))
            if show_missing:
                for m in sorted(missing):
                    print("   ", json.dumps(m, ensure_ascii=False))
    changelog_pages(pages)
    guilds.build(DOCS, pages["en"], re.search(r"## Version: (\S+)", read(os.path.join(ROOT, "Warcrest.toc"))).group(1))
    urls = [SITE] + [SITE + c + "/" for c, *_ in LANGS[1:]]
    urls += [SITE + "changelog/"] + [SITE + c + "/changelog/" for c, *_ in LANGS[1:]]
    urls += [SITE + "guilds/"]
    write(os.path.join(DOCS, "sitemap.xml"), '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
          + "".join("  <url><loc>%s</loc></url>\n" % u for u in urls) + "</urlset>\n")
    write(os.path.join(DOCS, "robots.txt"), "User-agent: *\nAllow: /\nSitemap: %ssitemap.xml\n" % SITE)


if __name__ == "__main__":
    main()
