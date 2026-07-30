# Race mode, validation, and compatibility v1

Milestone 14 implements the race, final-validation, missing-content, and budget
requirements for mod version `0.14.0` on gen1recomp v0.1.30.

## Race state and visibility

A new save copies `race_mode` and `spoiler_unlock` into the checksummed run.
Non-race runs begin unlocked. Race runs begin locked and add `-R` to the run
code. While locked:

- the active-run public export omits the canonical seed and all mappings;
- Copy Active Seed shows the seed hash and run code instead of the seed;
- plaintext spoiler export is unavailable;
- diagnostics exposed by the public view contain counts, not mapping keys or
  species details.

Unlocking is one-way and never modifies mappings. `HALL OF FAME` unlocks when
the stock `record_hall_of_fame` command begins; `CREDITS` unlocks after that
command resumes from the credits; `PASSPHRASE` verifies an organizer
passphrase; and `NEVER` has no in-game unlock path. The implementation wraps
the public command registry and delegates to the exact prior command.

Race Mode deters accidental spoilers. Local saves, exported files, mod source,
and client memory remain inspectable, so it is not server-grade anti-cheat.

## Spoiler exports

`EXPORT SPOILERS` writes under LÖVE's save directory:

- unlocked/non-race: `pokemon_randomizer/spoilers/SEEDHASH.txt`;
- locked race: `pokemon_randomizer/spoilers/SEEDHASH.race`.

Plaintext exports use readable format V2. Run metadata and settings appear
first, followed by separate sections for wild mappings, fishing, starters,
static encounters, gifts, trades, Game Corner prizes, trainer parties, and
diagnostics. Internal identifiers are converted to display names where
possible, and location-based entries show readable map names. Empty categories
are explicitly marked instead of being serialized as compact table data.

Locked export always prompts for a passphrase and never falls back to
plaintext. The versioned `PRRACE1` envelope contains authenticated algorithm,
settings, pool, and seed hashes. It uses:

- a unique 256-bit salt and nonce derived from per-action process entropy;
- a 256-block, two-pass memory-mixing password KDF;
- an HMAC-SHA-256 counter keystream;
- encrypt-then-HMAC-SHA-256 authentication with constant-work tag comparison.

SHA-256 and HMAC have known-vector tests. Correct-passphrase, wrong-passphrase,
and modified-ciphertext tests cover the complete envelope. The passphrase and
derived keys are never stored. For the `PASSPHRASE` unlock policy, the first
encrypted export saves only a salted verifier and the most recent encrypted
file authentication digest.

The manifest requests only `filesystem`, because export is the sole privileged
operation. Failure to initialize the filesystem, entropy, KDF, encryption, or
write reports `EXPORT FAILED`; no plaintext is written.

## Final cross-category validation

After all category generators finish, the independent `validation.swaps`
stream builds a reachability set from wild encounters, fishing, starters,
supported statics/gifts, and Game Corner Pokémon. If a requested NPC-trade
species is unreachable, the validator swaps it with a duplicate reachable wild
destination. This preserves mapping counts and the generated species multiset.
If no safe donor exists, it records `TRADE_REACHABILITY_UNSATISFIED` without
an unbounded retry.

Saved diagnostics include:

- deterministic repair-swap count;
- reachable species count;
- mapping node count;
- canonical serialized mappings byte count;
- canonical serialized complete randomizer namespace byte count.

The authoritative complete-namespace budget is 256 KiB (262,144 bytes).
Exceeding it records an attributed validation warning containing both the
measured and budget byte counts. Mappings are retained intact.

## Missing merged content

Load validation separates structural/checksum failures from missing species.
Structural damage still quarantines the session. If only mapped species are
missing, the checksummed namespace remains untouched and active:

- wild encounters return the prior encounter;
- starter offers return the physical ball's vanilla offer;
- supported statics, gifts, trades, and prizes use their recorded stock source;
- trainer parties return the complete prior-hook party;
- rival starter projection is skipped when its saved species is unavailable.

The stored mapping is never silently rewritten. Restoring the missing content
therefore restores the original randomized lookup.

## Compatibility fingerprints and migration

Relevant mods are sorted and saved as `{id, version, fingerprint}`. The
fingerprint hashes ID, version, and API using the repository's canonical
compatibility hash. The v0.14.0 migration adds these fingerprints and derives
race state from the already-saved M13 settings without regenerating mappings.

## Test and performance budgets

The M4 property suite runs six complete 151-species generations for each of
Casual, Standard, and Chaos, plus five stream-isolation generations. This
bounded set replaced the old 30,000-case loop, which sampled PRNG integers but
never invoked the generator. On the reference Lua 5.1.5 environment the real
property pass takes about 2.4 seconds and has a conservative 45-second CI
ceiling; the 24 golden vectors take about 17 seconds with a 60-second ceiling.

Properties verify mapped IDs, integer levels, starter uniqueness, trainer
party bounds, hard legendary/stage rules, uniqueness before fixture-pool
exhaustion, Catchability Guard failure attribution, canonical encode/decode
round trips, termination, and named-stream isolation. Authenticated-envelope
tamper tests, repair invariants, missing-content fallbacks, and save-size
checks remain in the complete suite.
