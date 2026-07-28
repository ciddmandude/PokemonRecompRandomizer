# Oak's Lab Starter Compatibility v1

Milestone 9 provides a mod-only starter-offer seam for stock recomp v0.1.30.
No custom app build or engine patch is required.

## Integration

The mod registers one `OAKS_LAB` contribution through the API-2
`map_scripts` compose registry. It supplies winners for only these talk keys:

- `TEXT_OAKSLAB_CHARMANDER_POKE_BALL`
- `TEXT_OAKSLAB_SQUIRTLE_POKE_BALL`
- `TEXT_OAKSLAB_BULBASAUR_POKE_BALL`

Oak, the rival, lab entry/step behavior, parcel delivery, Pokédex delivery,
the first rival battle trigger, and every other lab handler remain
engine-owned.

Each compatibility handler resolves one offer record before constructing the
script rows:

```lua
{
  slotId = "LEFT" | "MIDDLE" | "RIGHT",
  species = "CHARMANDER",
  level = 5,
  choseFlag = "EVENT_CHOSE_CHARMANDER",
  ballObject = "OAKSLAB_CHARMANDER_POKE_BALL",
  rivalBall = "OAKSLAB_SQUIRTLE_POKE_BALL",
}
```

The resolved offer drives the Pokédex preview, confirmation text, received
text, awarded species and level, projected choice flag, removed player ball,
rival movement, removed rival ball, and rival received-species text.

## Milestone 9 vanilla parity

With no saved M10 mapping, the adapter returns a validated copy of the
vanilla offer. The resulting command sequence retains:

- Charmander, Squirtle, and Bulbasaur at level 5;
- the original left/middle/right physical balls;
- the original choice flags;
- Squirtle/Bulbasaur/Charmander counterpick cycle;
- the original species-specific confirmation text IDs;
- the original early exits, nickname flow, movement, and object toggles.

Invalid future mapping output falls back to the slot's complete vanilla offer.

## Milestone 10 saved offers

An active M10 run resolves each physical ball through the checksum-protected
`mappings.starters` table. The same saved record drives the preview, question,
gift species and level, choice flag, ball removal, rival pickup, and received
text. Invalid or missing saved data falls back to the complete vanilla offer;
it never rerolls at interaction time.

## Compatibility tradeoff

This approach works with the released v0.1.30 app because it uses only public
API-2 content composition. It intentionally duplicates the small
`starterBall` command sequence from that release. The override is version
bounded by the manifest (`>=0.1.30 <0.2.0`) and its parity tests must be
reviewed whenever the supported recomp series changes.
