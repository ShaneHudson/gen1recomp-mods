# Free Fly

A party member that knows FLY can carry you. A Pidgey waits in the middle
of Pallet Town: talk to it, take it, and it joins at L10 already knowing
FLY. Pick FREEFLY in its party submenu to take off; you ride the bird over
trees, water, fences and buildings, across route seams, and press B over
walkable ground to land.

Try it:

```sh
python3 tools/modkit.py validate mods/free_fly --base imported
love . --developer
# new game, walk to the town center, talk to the bird, then party > PIDGEY > FREEFLY
```

While airborne, wild grass encounters stop, trainers can't spot you, doors
don't pull you in, and saving is blocked until you land (so a save can
never strand you over water).

Known rough edges are listed in `mod.card`.

Pokémon is a trademark of Nintendo; the Gen 1 games are © Nintendo /
Creatures Inc. / GAME FREAK inc. Unofficial fan mod; no ROMs, no
copyrighted game content. See the repository NOTICE.md.
