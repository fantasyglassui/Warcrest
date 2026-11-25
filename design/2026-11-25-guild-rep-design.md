# Guild rep — design

## Why
Members earn standing with the guild by playing together. It rewards showing up, not titles or DKP.
The user's rules: rep is earned **only by playing**, officers can't award or remove it, and it **only goes up**.

## How it's earned

| Playing together | Rep |
|---|---|
| 10 minutes grouped with a guildmate (both sides must report it) | +10 |
| A raid night attended | +100 |
| A guild boss kill | +25 |
| A guild event attended | +50 |
| A kill on an enemy player with a guildmate's assist | +5 |
| A revenge kill for a guildmate | +15 |
| A crafting order finished for a guildmate (goes to the crafter) | +25 |

- Each member can earn at most **1,000 rep a day**, counted by the day each thing happened.

## Ranks

| Rank | Rep needed |
|---|---|
| Neutral | 0 |
| Friendly | 3,000 |
| Honored | 9,000 |
| Revered | 21,000 |
| Exalted | 42,000 |

## How it works
- **Counted from records the guild already shares.** Everything except grouped time comes from records every client already has: raid nights, boss kills, events, kills and assists, revenge, and crafting orders.
  - Every client works rep out the same way, so everyone sees the same numbers.
  - Nothing new can be faked.
- **One new record: grouped time.** When you leave a group or log out, Warcrest adds `GT { mins, with }` to the shared record: how many minutes you were grouped and which guildmates were in the group.
  - Those minutes count only when a guildmate's own GT record names you for the same time. The overlap is what counts.
  - That way a member alone can't earn rep for grouped time.
  - Nothing goes in chat.
- **Only goes up.** Each client keeps every member's highest rep seen. Some records age out, such as crafting orders after 30 days and old kills. When they do, the rep shown is the higher of the kept value and the newly worked-out one.
- **Nobody can hand it out.** No officer award, no link to DKP, no way to lower it.
- **Full reset:** rep is part of "Everything shared", so a reset clears it with the rest.

## Where it shows
- **Player card:** the rank and a bar to the next rank.
- **Roster:** a "Rep" column you can sort.
- **Home:** a "Your guild rep" card showing today's rep, so you can see how close you are to the daily cap.
- **Banner:** a banner when you reach a new rank, in a colour of its own, so a guildmate's rank-up can also be announced to guild chat (using the existing guild-chat toggle).
- **Translations:** all text in German, French and Spanish.

## Not doing
- Fading over time.
- Spending rep.
- Officer awards.
- Rep on the website: the website reads Blizzard's API, which doesn't know about rep, and the add-on never goes online.

## Left to the builder
- Exact layout.
- Throttling the rep calculation, like the achievements recheck.
- Tests for each source, the daily cap, the only-goes-up rule, and grouped time needing both sides.
