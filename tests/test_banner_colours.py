"""Every kind of alert banner has its own colour."""
from harness import Guild


def test_every_banner_kind_has_its_own_colour():
    guild = Guild([("Alice", 1)])
    kinds = guild["Alice"].ns.BANNER_KINDS
    seen = {}
    for k, v in kinds.items():
        c = tuple(round(x, 3) for x in (v.color[1], v.color[2], v.color[3]))
        assert c not in seen, (k, seen.get(c))
        seen[c] = k
    assert len(seen) == 16
