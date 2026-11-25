# Death Tracker

A WoW Forever addon that counts your deaths and shows what killed you. Get it on CurseForge:
https://www.curseforge.com/wow/addons/death-tracker-forever. Found a bug? Report it here:
https://github.com/ImCheesecake/DeathTracker/issues.

The version is in `DeathTracker.toc`; what changed is in `CHANGELOG.md`. `streamerbot/` holds the
C# inside the Streamer.bot import. MIT licensed (`LICENSE`); the embedded libraries keep their own
licenses (`Libs/README.md`).

## Why the code does what it does

Background that used to sit in the code's comments:

- **The counter without its panel** (`UI.Bare`): every text gets the game's hard dark outline,
  small text also a shadow, and grey text turns light, so it reads on snow and sand as well as at
  night. The bar keeps its border (`backdrop` lists what goes): its shape holds the tab together.
- **The bar's notch** (`UI.Notch`): a panel with a tab under it, joined by inward curves. The fill
  is see-through, so no two pieces may overlap or the overlap shows darker: the bar's bottom edge is
  two lines that stop where the curves start, and the curve textures (`dev/make_textures.py`) leave
  out the row the bar already fills and the column the tab fills.
- **Letter spacing** (`UI.Spaced`): game text has none, so a narrow space goes between letters. In
  Inter the "hair" space is 0.08em wide, the "thin" one 0.17em.
- **The nemesis takes 3 kills** (`ns.Nemesis`): two can be one bad pull.
- **Streamer.bot sending is off by default** (`ns.DEFAULTS`): it writes ~64 KB to General.log per
  death, which only helps someone who imported the Streamer.bot side.
