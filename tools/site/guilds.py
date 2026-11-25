"""The guild pages of warcrest-addon.com (English): /guilds/ (boards, search and
firsts), /guilds/guild/?g=<slug> and /guilds/player/?c=<slug>. Built by
build.py from the main page's look; the data comes from /guilds/data/, written
every hour by tools/guilds/update.py (see .github/workflows/guild-site.yml).
"""
import os, re

SITE = "https://warcrest-addon.com/"
ADD_GUILD = "https://github.com/fantasyglassui/Warcrest/issues/new?template=add-guild.yml"

CSS = """
.gz { padding: 40px 0 72px; }
.gz h1 { font-family: var(--f-display); font-weight: 400; font-size: clamp(30px, 4vw, 44px); margin: 0 0 6px; }
.gz .sub { color: var(--muted); margin: 0 0 22px; }
.gz .muted { color: var(--muted); }
.gz .faint { color: var(--faint); }
.gz .card { background: var(--card); border: 1px solid var(--edge); border-radius: 4px; padding: 18px 20px; }
.gz .grid { display: grid; gap: 18px; }
.gz .cols { grid-template-columns: minmax(0, 2fr) minmax(0, 1fr); align-items: start; }
@media (max-width: 860px) { .gz .cols { grid-template-columns: minmax(0, 1fr); } }
.gz .tiles { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 12px; margin: 0 0 18px; }
.gz .tile { background: var(--card); border: 1px solid var(--edge); border-radius: 4px; padding: 14px 16px; }
.gz .tile b { display: block; font-size: 26px; font-weight: 600; color: var(--text); }
.gz .tile span { font-size: 12px; letter-spacing: .08em; text-transform: uppercase; color: var(--faint); }
.gz .tabs { display: flex; flex-wrap: wrap; gap: 4px; margin: 0 0 14px; }
.gz .tabs button { background: var(--panel); color: var(--muted); border: 1px solid var(--edge); border-radius: 3px; padding: 7px 12px;
  font: 500 14px var(--f-body); cursor: pointer; }
.gz .tabs button[aria-selected="true"] { color: var(--on-gold); background: var(--gold); border-color: var(--gold); }
.gz table { width: 100%; border-collapse: collapse; font-size: 15px; }
.gz th { text-align: left; font-size: 12px; letter-spacing: .08em; text-transform: uppercase; color: var(--faint); font-weight: 500;
  padding: 8px 10px; border-bottom: 1px solid var(--edge); cursor: default; white-space: nowrap; }
.gz th[data-k] { cursor: pointer; }
.gz th[data-k]:hover { color: var(--soft); }
.gz td { padding: 9px 10px; border-bottom: 1px solid var(--line); vertical-align: middle; }
.gz td.n, .gz th.n { text-align: right; font-variant-numeric: tabular-nums; }
.gz tr:hover td { background: rgba(255,255,255,.02); }
.gz a.g { color: var(--text); text-decoration: none; font-weight: 600; }
.gz a.g:hover { color: var(--gold); }
.gz .rank { color: var(--faint); width: 36px; }
.gz .crest { display: inline-grid; place-items: center; width: 26px; height: 26px; border-radius: 4px; margin-right: 10px; vertical-align: middle;
  font: 700 11px var(--f-body); border: 2px solid; }
.gz .badge { display: inline-block; margin-left: 8px; padding: 1px 7px; border-radius: 3px; font-size: 11px; letter-spacing: .06em;
  text-transform: uppercase; background: var(--gold-dim); color: var(--gold); vertical-align: middle; }
.gz .alliance { color: #6fa8ff; } .gz .horde { color: #ff6b6b; }
.gz .search { width: 100%; padding: 12px 14px; background: var(--panel); border: 1px solid var(--edge); border-radius: 4px; color: var(--text);
  font: 16px var(--f-body); margin: 0 0 8px; }
.gz .results a { display: block; padding: 8px 10px; border-bottom: 1px solid var(--line); color: var(--soft); text-decoration: none; }
.gz .results a:hover { background: var(--panel); color: var(--gold); }
.gz .feed li { list-style: none; padding: 9px 0; border-bottom: 1px solid var(--line); }
.gz .feed { padding: 0; margin: 0; }
.gz .feed time { display: block; font-size: 12px; color: var(--faint); }
.gz .note { font-size: 13px; color: var(--faint); margin-top: 14px; }
.gz .empty { color: var(--muted); padding: 18px 0; }
.gz .bar { height: 6px; background: var(--line); border-radius: 3px; overflow: hidden; }
.gz .bar i { display: block; height: 100%; background: var(--gold); }
.gz .classes span { display: inline-block; margin: 0 10px 6px 0; font-size: 14px; color: var(--soft); }
.gz .head { display: flex; align-items: center; gap: 16px; margin: 0 0 6px; }
.gz .head .crest { width: 54px; height: 54px; font-size: 18px; border-width: 3px; margin: 0; }
.gz .btn.small { padding: 7px 12px; font-size: 14px; }
"""

COMMON_JS = r"""
const $ = (s, el = document) => el.querySelector(s);
const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({"&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"}[c]));
const num = n => n == null ? "-" : Number(n).toLocaleString("en-US");
const CLASS_COLOURS = {Warrior: "#c69b6d", Paladin: "#f48cba", Hunter: "#aad372", Rogue: "#fff468", Priest: "#ffffff", Shaman: "#2459ff",
  Mage: "#3fc7eb", Warlock: "#8788ee", Druid: "#ff7c0a", "Death Knight": "#c41e3a", Monk: "#00ff98", "Demon Hunter": "#a330c9", Evoker: "#33937f"};
const cls = c => `<span style="color:${CLASS_COLOURS[c] || "inherit"}">${esc(c)}</span>`;
function ago(t) {
  if (!t) return "before tracking";
  const s = Date.now() / 1000 - t;
  if (s < 3600) return Math.max(1, Math.round(s / 60)) + " min ago";
  if (s < 86400) return Math.round(s / 3600) + " h ago";
  if (s < 86400 * 60) return Math.round(s / 86400) + " days ago";
  return new Date(t * 1000).toLocaleDateString("en-US", {month: "short", day: "numeric", year: "numeric"});
}
function crest(g, size) {
  const c = g.crest || {};
  const initials = (g.name || "?").split(/\s+/).filter(w => !/^(the|of|and)$/i.test(w)).map(w => w[0]).join("").slice(0, 2).toUpperCase();
  return `<span class="crest" style="background:${c.background || "#232323"};border-color:${c.border || "#555"};color:${c.emblem || "#e0b94c"}">${esc(initials || "?")}</span>`;
}
const guildLink = g => `<a class="g" href="/guilds/guild/?g=${encodeURIComponent(g.slug)}">${crest(g)}${esc(titleCase(g.name))}</a>${g.warcrest ? '<span class="badge" title="This guild uses the Warcrest add-on">Warcrest</span>' : ""}`;
function titleCase(s) { return s && s === s.toUpperCase() ? s.toLowerCase().replace(/(^|[\s-])(\p{L})/gu, (m, a, b) => a + b.toUpperCase()) : s; }
async function data(path) {
  const r = await fetch("/guilds/data/" + path, {cache: "no-cache"});
  if (!r.ok) throw new Error(r.status);
  return r.json();
}
function sortable(table, rows, cols, render, start) {
  let key = start.key, desc = start.desc;
  const draw = () => {
    const list = rows.slice().sort((a, b) => {
      const x = cols[key](a), y = cols[key](b);
      if (x === y) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return (x < y ? -1 : 1) * (desc ? -1 : 1);
    });
    table.tBodies[0].innerHTML = list.map(render).join("");
    table.querySelectorAll("th[data-k]").forEach(th => th.setAttribute("aria-sort", th.dataset.k === key ? (desc ? "descending" : "ascending") : "none"));
  };
  table.querySelectorAll("th[data-k]").forEach(th => th.addEventListener("click", () => {
    if (key === th.dataset.k) desc = !desc; else { key = th.dataset.k; desc = true; }
    draw();
  }));
  draw();
}
"""

INDEX_MAIN = """
<main id="top" class="gz"><div class="wrap">
  <h1>WoW: Forever guilds</h1>
  <p class="sub" id="summary">Guild boards, race to 60 and firsts, from Blizzard's armory, updated every hour.</p>
  <input class="search" id="q" type="search" placeholder="Find a guild or player by name" autocomplete="off" aria-label="Find a guild or player">
  <div class="results" id="results"></div>
  <div class="grid cols" style="margin-top:18px">
    <section class="card">
      <div class="tabs" role="tablist" id="tabs"></div>
      <div id="board"></div>
      <p class="note" id="boardnote"></p>
    </section>
    <aside class="grid" style="align-content:start">
      <section class="card">
        <h2 style="margin:0 0 6px;font-size:18px">Latest firsts</h2>
        <ul class="feed" id="feed"><li class="empty">Loading...</li></ul>
      </section>
      <section class="card">
        <h2 style="margin:0 0 6px;font-size:18px">Missing a guild?</h2>
        <p class="muted" style="margin:0 0 12px">Any WoW: Forever guild can be added. Guilds that use Warcrest get the Warcrest badge: officers can add theirs from the add-on (Guild &gt; Who has Warcrest).</p>
        <a class="btn gold small" href="%s" target="_blank" rel="noopener">Add a guild</a>
        <a class="btn small" href="https://discord.gg/qeSMwQWyPR" target="_blank" rel="noopener" style="margin-left:6px">Ask on Discord</a>
      </section>
    </aside>
  </div>
  <p class="note">Fan-made, not made by or connected to Blizzard Entertainment. Characters show from level 10, once they've logged out. Firsts are dated from when they were first seen here; ones from before a guild was added say "before tracking".</p>
</div></main>
""" % ADD_GUILD

INDEX_JS = r"""
const BOARDS = [
  {id: "race", label: "Race to 60", value: g => g.at60, fmt: g => num(g.at60) + " at 60", note: "Most members at level 60, then the highest average level of the top 10."},
  {id: "progress", label: "Raid progress", value: g => g.raidbosses * 1000 + g.bosses, fmt: g => `${num(g.raidbosses)} raid · ${num(g.bosses - g.raidbosses)} dungeon bosses`, note: "Different raid bosses killed by members, then dungeon bosses."},
  {id: "gear", label: "Gear", value: g => g.gear, fmt: g => g.gear == null ? "-" : "item level " + g.gear, note: "Average item level of the 10 best-geared members."},
  {id: "active", label: "Most active", value: g => g.active, fmt: g => num(g.active) + " this week", note: "Members who logged in during the last 7 days."},
  {id: "quests", label: "Quests", value: g => g.quests, fmt: g => num(g.quests), note: "Quests completed by all members."},
  {id: "creatures", label: "Monsters slain", value: g => g.creatures, fmt: g => num(g.creatures), note: "Creatures killed by all members."},
  {id: "pvp", label: "PvP", value: g => g.hks, fmt: g => num(g.hks) + " honorable kills", note: "Honorable kills by all members."},
  {id: "size", label: "Biggest", value: g => g.members, fmt: g => num(g.members) + " members", note: "Members in the guild."},
];
let index;
function drawBoard(id) {
  const b = BOARDS.find(x => x.id === id) || BOARDS[0];
  $("#tabs").querySelectorAll("button").forEach(x => x.setAttribute("aria-selected", x.dataset.id === b.id));
  const list = index.guilds.slice().sort((x, y) => (b.value(y) ?? -1) - (b.value(x) ?? -1) || (y.top10 - x.top10));
  $("#board").innerHTML = list.length ? `<table><thead><tr><th>#</th><th>Guild</th><th>Ruleset</th><th class="n">${esc(b.label)}</th></tr></thead><tbody>` +
    list.map((g, i) => `<tr><td class="rank">${i + 1}</td><td>${guildLink(g)}</td><td class="muted">${esc(g.ruleset)} · <span class="${g.faction.toLowerCase()}">${esc(titleCase(g.faction))}</span></td><td class="n">${b.fmt(g)}</td></tr>`).join("") +
    "</tbody></table>" : '<p class="empty">No guilds yet.</p>';
  $("#boardnote").textContent = b.note;
  try { history.replaceState(null, "", "#" + b.id); } catch (e) {}
}
function drawFeed() {
  const names = Object.fromEntries(index.guilds.map(g => [g.slug, g]));
  const items = index.firsts.filter(f => f.t).slice(0, 15);
  $("#feed").innerHTML = items.length ? items.map(f => {
    const g = names[f.guild];
    const gl = g ? `<a class="g" href="/guilds/guild/?g=${encodeURIComponent(g.slug)}">${esc(titleCase(g.name))}</a>` : "";
    const text = f.kind === "level60"
      ? `<a class="g" href="/guilds/player/?c=${encodeURIComponent(f.who)}">${esc(f.name)}</a> reached level 60 ${gl ? "(" + gl + ")" : ""}`
      : `${gl} killed <b>${esc(f.boss)}</b> for the first time <span class="muted">(${esc(f.instance)})</span>`;
    return `<li>${text}<time>${ago(f.t)}</time></li>`;
  }).join("") : '<li class="empty">Firsts show here as they happen: the first members to 60 and every guild\'s first boss kills.</li>';
}
function search(q) {
  q = q.trim().toLowerCase();
  if (q.length < 2) { $("#results").innerHTML = ""; return; }
  const g = index.guilds.filter(x => x.name.toLowerCase().includes(q)).slice(0, 6)
    .map(x => `<a href="/guilds/guild/?g=${encodeURIComponent(x.slug)}">${crest(x)}${esc(titleCase(x.name))} <span class="faint">guild · ${num(x.members)} members</span></a>`);
  const p = index.players.filter(x => (x.n + " " + x.u).toLowerCase().includes(q)).slice(0, 8)
    .map(x => `<a href="/guilds/player/?c=${encodeURIComponent(x.s)}">${esc(x.n)} ${esc(x.u)} <span class="faint">level ${x.l} ${esc(x.c)}</span></a>`);
  $("#results").innerHTML = [...g, ...p].join("") || '<p class="empty">Nobody by that name yet.</p>';
}
(async () => {
  try { index = await data("index.json"); }
  catch (e) { $("#board").innerHTML = '<p class="empty">The guild data is on its way: it updates every hour.</p>'; $("#feed").innerHTML = ""; return; }
  const people = index.guilds.reduce((n, g) => n + g.members, 0);
  $("#summary").textContent = `${num(index.guilds.length)} guilds · ${num(people)} members · updated ${ago(index.updated)}`;
  $("#tabs").innerHTML = BOARDS.map(b => `<button role="tab" data-id="${b.id}">${esc(b.label)}</button>`).join("");
  $("#tabs").addEventListener("click", e => { const b = e.target.closest("button"); if (b) drawBoard(b.dataset.id); });
  drawBoard(location.hash.slice(1));
  drawFeed();
  $("#q").addEventListener("input", e => search(e.target.value));
})();
"""

GUILD_MAIN = """
<main id="top" class="gz"><div class="wrap">
  <p style="margin:0 0 14px"><a href="/guilds/" class="muted">&larr; All guilds</a></p>
  <div id="page"><p class="empty">Loading...</p></div>
</div></main>
"""

GUILD_JS = r"""
(async () => {
  const slug = new URLSearchParams(location.search).get("g") || "";
  let g, index;
  try { [g, index] = await Promise.all([data("guilds/" + encodeURIComponent(slug) + ".json"), data("index.json")]); }
  catch (e) { $("#page").innerHTML = `<h1>Guild not found</h1><p class="muted">It isn't on the list yet. <a href="/guilds/">See all guilds</a> or add it there.</p>`; return; }
  const row = index.guilds.find(x => x.slug === slug) || g;
  document.title = titleCase(g.name) + " · WoW: Forever guild · Warcrest";
  const classes = {};
  g.roster.forEach(m => { if (m.class) classes[m.class] = (classes[m.class] || 0) + 1; });
  const levels = [0, 0, 0, 0, 0, 0];
  g.roster.forEach(m => { levels[Math.min(5, Math.floor((m.level || 1) / 10))]++; });
  const maxL = Math.max(1, ...levels);
  const bosses = g.bossList || [];
  $("#page").innerHTML = `
    <div class="head">${crest(g)}<div><h1 style="margin:0">${esc(titleCase(g.name))}${row.warcrest ? '<span class="badge">Uses Warcrest</span>' : ""}</h1>
      <p class="sub" style="margin:0"><span class="${g.faction.toLowerCase()}">${esc(titleCase(g.faction))}</span> · ${esc(g.ruleset)} ruleset${g.created ? " · founded " + new Date(g.created * 1000).toLocaleDateString("en-US", {month: "short", day: "numeric", year: "numeric"}) : ""} · updated ${ago(g.updated)}</p></div></div>
    <div class="tiles" style="margin-top:18px">
      <div class="tile"><b>${num(g.members)}</b><span>Members</span></div>
      <div class="tile"><b>${num(g.at60)}</b><span>At level 60</span></div>
      <div class="tile"><b>${num(g.active)}</b><span>Active this week</span></div>
      <div class="tile"><b>${g.gear ?? "-"}</b><span>Gear (top 10)</span></div>
      <div class="tile"><b>${num(g.raidbosses)}</b><span>Raid bosses</span></div>
      <div class="tile"><b>${num(g.bosses - g.raidbosses)}</b><span>Dungeon bosses</span></div>
    </div>
    <div class="grid cols">
      <section class="card"><h2 style="margin:0 0 10px;font-size:18px">Members</h2>
        <table id="members"><thead><tr><th data-k="name">Name</th><th data-k="level" class="n">Level</th><th data-k="cls">Class</th><th data-k="ilvl" class="n">Gear</th><th data-k="quests" class="n">Quests</th><th data-k="last" class="n">Last seen</th></tr></thead><tbody></tbody></table>
      </section>
      <aside class="grid" style="align-content:start">
        <section class="card"><h2 style="margin:0 0 10px;font-size:18px">Levels</h2>
          ${["1-9", "10-19", "20-29", "30-39", "40-49", "50-60"].map((l, i) => `<div style="display:grid;grid-template-columns:56px 1fr 34px;gap:10px;align-items:center;margin:6px 0"><span class="muted">${l}</span><div class="bar"><i style="width:${100 * levels[i] / maxL}%"></i></div><span class="n">${levels[i]}</span></div>`).join("")}
        </section>
        <section class="card"><h2 style="margin:0 0 10px;font-size:18px">Classes</h2><div class="classes">${Object.entries(classes).sort((a, b) => b[1] - a[1]).map(([c, n]) => `<span>${cls(c)} ${n}</span>`).join("")}</div></section>
        <section class="card"><h2 style="margin:0 0 10px;font-size:18px">Boss kills</h2>
          ${bosses.length ? '<table><tbody>' + bosses.map(b => `<tr><td>${esc(b.boss)}<div class="faint" style="font-size:13px">${esc(b.instance)}${b.raid ? " · raid" : ""}</div></td><td class="n muted" style="font-size:13px">${b.first ? "first " + ago(b.first) : ""}</td></tr>`).join("") + "</tbody></table>"
            : '<p class="empty">No boss kills seen yet.</p>'}
        </section>
      </aside>
    </div>`;
  const rows = g.roster.filter(m => m.level >= 1);
  sortable($("#members"), rows, {
    name: m => (m.name || "").toLowerCase(), level: m => m.level, cls: m => m.class, ilvl: m => m.ilvl ?? null,
    quests: m => (m.stats || {}).quests ?? null, last: m => m.last ?? null,
  }, m => `<tr><td>${m.level >= 10 ? `<a class="g" href="/guilds/player/?c=${encodeURIComponent(m.slug)}">${esc(m.name)} <span class="faint">${esc(m.surname)}</span></a>` : `${esc(m.name)} <span class="faint">${esc(m.surname)}</span>`}</td>
     <td class="n">${m.level}</td><td>${cls(m.class)}</td><td class="n">${m.ilvl ?? "-"}</td><td class="n">${num((m.stats || {}).quests)}</td><td class="n muted">${m.last ? ago(m.last) : "-"}</td></tr>`,
    {key: "level", desc: true});
})();
"""

PLAYER_MAIN = GUILD_MAIN.replace("&larr; All guilds", "&larr; All guilds")

PLAYER_JS = r"""
(async () => {
  const slug = new URLSearchParams(location.search).get("c") || "";
  let index, g, m;
  try {
    index = await data("index.json");
    const p = index.players.find(x => x.s === slug);
    if (!p) throw new Error("not found");
    g = await data("guilds/" + encodeURIComponent(p.g) + ".json");
    m = g.roster.find(x => x.slug === slug);
    if (!m) throw new Error("not found");
  } catch (e) { $("#page").innerHTML = `<h1>Player not found</h1><p class="muted">Only members of guilds on the list show, from level 10. <a href="/guilds/">See all guilds</a>.</p>`; return; }
  document.title = `${m.name} ${m.surname} · WoW: Forever · Warcrest`;
  const s = m.stats || {};
  const row = index.guilds.find(x => x.slug === g.slug) || g;
  const kills = (g.bossList || []).filter(b => b.by === slug);
  $("#page").innerHTML = `
    <h1 style="margin:0">${esc(m.name)} <span class="muted">${esc(m.surname)}</span></h1>
    <p class="sub">Level ${m.level} ${esc(m.race || "")} ${cls(m.class)} · ${guildLink(row)} · last seen ${m.last ? ago(m.last) : "-"}</p>
    <div class="tiles">
      <div class="tile"><b>${m.level}</b><span>Level</span></div>
      <div class="tile"><b>${m.ilvl ?? "-"}</b><span>Gear (item level)</span></div>
      <div class="tile"><b>${num(s.quests)}</b><span>Quests</span></div>
      <div class="tile"><b>${num(s.creatures)}</b><span>Monsters slain</span></div>
      <div class="tile"><b>${num(s.dungeons)}</b><span>Dungeons entered</span></div>
      <div class="tile"><b>${num(s.hks)}</b><span>Honorable kills</span></div>
      <div class="tile"><b>${num(s.blows)}</b><span>Killing blows</span></div>
      <div class="tile"><b>${num(s.deaths)}</b><span>Deaths</span></div>
      <div class="tile"><b>${num(s.maxprof)}</b><span>Professions maxed</span></div>
    </div>
    ${kills.length ? `<section class="card"><h2 style="margin:0 0 10px;font-size:18px">First guild kills</h2><table><tbody>${kills.map(b => `<tr><td>${esc(b.boss)} <span class="faint">${esc(b.instance)}</span></td><td class="n muted">${b.first ? ago(b.first) : "before tracking"}</td></tr>`).join("")}</tbody></table></section>` : ""}
    <p class="note">From Blizzard's armory, updated every hour while they play.</p>`;
})();
"""


def page(main_page, path, title, description, main, js):
    style = re.search(r"<style>.*?</style>", main_page, re.S).group(0).replace("</style>", CSS + "</style>")
    header = re.search(r'<header class="top">.*?\n</header>', main_page, re.S).group(0)
    footer = re.search(r"<footer>.*?</footer>", main_page, re.S).group(0)

    def relink(part):
        part = re.sub(r'href="#([a-z-]*)"', lambda m: 'href="/%s"' % ("#" + m.group(1) if m.group(1) != "top" else ""), part)
        part = part.replace('aria-label="Warcrest, back to top"', 'aria-label="Warcrest"')
        # English only for now: the language menu points at each language's home page.
        return part
    header, footer = relink(header), relink(footer)
    header = header.replace('<a href="/guilds/">', '<a href="/guilds/" aria-current="page">')
    url = SITE + path
    head = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>%s</title>
<meta name="description" content="%s">
<link rel="canonical" href="%s">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Warcrest">
<meta property="og:title" content="%s">
<meta property="og:description" content="%s">
<meta property="og:url" content="%s">
<meta property="og:image" content="%sog.jpg">
<meta name="twitter:card" content="summary_large_image">
<meta name="theme-color" content="#e0b94c">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Marcellus&family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@500&display=swap">
%s
<link rel="icon" href="/img/crest.png">
</head>
<body>""" % (title, description, url, title, description, url, SITE, style)
    return "%s\n%s\n%s\n%s\n<script>%s%s</script>\n</body>\n</html>\n" % (head, header, main, footer, COMMON_JS, js)


def build(docs, main_page, version=None):
    """Writes docs/guilds/... from the built English main page."""
    if version:
        main_page = re.sub(r'data-version="">[^<]*<', 'data-version="">%s<' % version, main_page)
    pages = [
        ("guilds/", "WoW: Forever guilds · Warcrest", "Guild boards for WoW: Forever: race to 60, raid progress, gear and firsts, from Blizzard's armory, updated every hour.", INDEX_MAIN, INDEX_JS),
        ("guilds/guild/", "Guild · WoW: Forever · Warcrest", "A WoW: Forever guild: members, levels, classes, gear and boss kills.", GUILD_MAIN, GUILD_JS),
        ("guilds/player/", "Player · WoW: Forever · Warcrest", "A WoW: Forever character: level, gear, quests, boss kills and more.", PLAYER_MAIN, PLAYER_JS),
    ]
    for path, title, desc, main, js in pages:
        out = os.path.join(docs, *path.strip("/").split("/"), "index.html")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, "w", encoding="utf-8") as f:
            f.write(page(main_page, path, title, desc, main, js))
