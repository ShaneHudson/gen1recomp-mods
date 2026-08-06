# shared/

Build-time shared Lua. Anything here (besides this README) is copied into
each mod as `lib/shared/` by `scripts/pack.sh` and the release workflow,
so packed zips stay self-contained.

Candidates waiting to move in: the icon-class-to-walker-sheet mount
resolver and the dex-height scale formula, currently duplicated in both
mods.
