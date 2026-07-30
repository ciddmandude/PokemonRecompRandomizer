# Deterministic Foundation v1

Status: locked by golden vectors  
Hash: `fnv1a32x4-v1`  
PRNG: `xoshiro128ss-v1`  
Algorithm build: `1.3.0-dev`

This document completely specifies milestone 2's deterministic behavior. A
conforming implementation must reproduce `tests/golden_vectors.lua` exactly.
Changing any result requires a new hash or PRNG version and must not regenerate
an existing saved run.

Remediation M4 adds 24 full-generator vectors in
`tests/generator_golden_vectors.lua` with literal expectations in
`tests/generator_golden_expected.lua`. They cover Casual, Standard, Chaos,
Blue-version prizes, themed and global trainers, scaled-level modes, and
targeted category toggles. Each vector locks:

- the complete generation-request hash;
- the canonical 151-species manifest and source-fixture hashes;
- all ten saved mapping-bucket hashes and their combined hash;
- ordered warning codes and fallback count;
- repair, reachability, node-count, and serialized-byte diagnostics.

Every bucket is nonempty in at least one vector. A representative full request
is also regenerated after recursively reversing map insertion order. Its
complete result hash must remain identical.

`tools/print-generator-vectors.lua` prints replacement literals after an
intentional algorithm change. Updating them requires an algorithm-version
decision and review; existing saves continue using their stored mappings.

Remediation M5 replaces greedy one-to-one selection with stable candidate
graphs, category-stream Fisher-Yates preferences, and deterministic
augmenting-path matching. Pool reuse is allowed only after matching proves the
next source cannot join the current uniqueness pool. Saved mappings remain
authoritative, so loading a run created by an earlier algorithm build never
regenerates it.

Remediation M9 advances the algorithm build because explicit map, terrain,
rod, story, badge, and trade-stage access rules can change both candidate
selection and deterministic repair swaps. The 24 full-generator expectations
were regenerated for `1.2.0-dev`; older saved runs still use their stored
mappings and are never regenerated.

Remediation M12 advances the algorithm build because an unsupported or
missing game-version source now retains vanilla Game Corner Pokémon prizes
instead of silently generating the Red catalog. Red and Blue mapping vectors
remain unchanged; older saves continue using their stored mappings.

## 1. Numeric model

All words are unsigned 32-bit integers in the inclusive range
`0..4294967295`. Arithmetic is reduced modulo `2^32`.

The Lua implementation uses IEEE-754 numbers but keeps every intermediate
below `2^53`, where integers are exactly representable:

- shifts discard bits before multiplication;
- 32-bit multiplication uses 16-bit limbs;
- XOR is evaluated nibble by nibble;
- rotation is the sum of non-overlapping left/right shifted fields.

It does not depend on a platform bit library, signed integer behavior, native
endianness, locale, or Lua table iteration order.

## 2. Seed normalization

Input is normalized in this order:

1. Require a Lua string.
2. Replace each run of ASCII whitespace matched by Lua `%s` with one byte
   `0x20`.
3. Remove leading and trailing spaces.
4. Apply Lua `string.upper`; accepted input is ASCII, so this is locale
   independent for valid seeds.
5. Require 1–32 bytes.
6. Permit only `A-Z`, `0-9`, space, hyphen, and underscore.

Examples:

| Input | Canonical |
|---|---|
| `  my   seed  ` | `MY SEED` |
| `race_seed-01` | `RACE_SEED-01` |

Canonical seeds are hashed as raw ASCII bytes.

## 3. Exact unsigned operations

Let `u32(x) = x mod 2^32`.

### Multiplication

For `a = ahi × 2^16 + alo` and `b = bhi × 2^16 + blo`:

```text
mul32(a, b) =
  (alo × blo + ((alo × bhi + ahi × blo) mod 2^16) × 2^16) mod 2^32
```

### Shifts and rotation

```text
lshift32(x, n) = (x mod 2^(32-n)) × 2^n, for 0 <= n < 32
rshift32(x, n) = floor(x / 2^n),             for 0 <= n < 32
rotl32(x, n)   = lshift32(x, n) + rshift32(x, 32-n)
```

Shift amounts at least 32 return zero. Rotation amounts are reduced modulo 32.

## 4. Hash `fnv1a32x4-v1`

This is a stable non-cryptographic 128-bit content hash composed of four
independently salted FNV-1a/32 lanes followed by Murmur3's `fmix32` avalanche.
It is not the standardized FNV-1a/128 algorithm and must not be used for
passwords, authentication, or encryption.

Constants:

```text
FNV_OFFSET = 2166136261
FNV_PRIME  = 16777619
LANE_SALTS = [0, 2654435769, 608135816, 3084996962]
```

Initialize lane `i` (one-based):

```text
h[i] = FNV_OFFSET XOR LANE_SALTS[i]
```

For every input byte `b`, in byte order:

```text
h[i] = mul32(h[i] XOR b, FNV_PRIME)
```

Finalize each lane by applying the same update operation to:

1. the one-based lane number;
2. `length mod 256`;
3. `floor(length / 256) mod 256`.

Then apply:

```text
h = h XOR (h >> 16)
h = mul32(h, 2246822507)
h = h XOR (h >> 13)
h = mul32(h, 3266489909)
h = h XOR (h >> 16)
```

The 128-bit display is four uppercase, zero-padded, eight-digit hexadecimal
words concatenated in lane order.

### Root seed hash

```text
digest("pokemon_randomizer" || 0x00 || "seed" || 0x00 || canonicalSeed)
```

### Named stream hash

Serialize the four root words as 16 big-endian bytes, then:

```text
digest(
  "pokemon_randomizer" || 0x00 || "stream" || 0x00 ||
  rootBytes || 0x00 || streamName
)
```

Stream names are nonempty lowercase ASCII identifiers matching:

```text
^[a-z][a-z0-9._-]*$
```

Each category uses a separate stream. Adding draws to one stream cannot alter
another category.

Locked v1 stream names are:

```text
wild.global
wild.area
wild.levels
starters
rival.counterpick
static.encounters
static.levels
gifts
gift.levels
trades
prizes
trainers.species
trainers.levels
trainers.sizes
validation.swaps
```

## 5. PRNG `xoshiro128ss-v1`

The four words of a named stream hash are the initial xoshiro128** state
`s[0]..s[3]`. The all-zero state is invalid.

Each `nextU32` call is:

```text
result = mul32(rotl32(mul32(s[1], 5), 7), 9)
t = lshift32(s[1], 9)

s[2] = s[2] XOR s[0]
s[3] = s[3] XOR s[1]
s[1] = s[1] XOR s[2]
s[0] = s[0] XOR s[3]
s[2] = s[2] XOR t
s[3] = rotl32(s[3], 11)

return result
```

Assignments occur in the displayed order.

## 6. Unbiased integer sampling

For inclusive integer bounds `minimum..maximum`:

```text
span  = maximum - minimum + 1
limit = 2^32 - (2^32 mod span)

repeat:
  value = nextU32()
until value < limit

return minimum + (value mod span)
```

If `span = 2^32`, return `minimum + nextU32()` directly. Modulo-only sampling
is forbidden because it biases ranges that do not divide `2^32`.

## 7. Fisher–Yates shuffle

Copy the input dense array. For `i` descending from its length to 2:

```text
j = nextInt(1, i)
swap(output[i], output[j])
```

The source array is not mutated.

## 8. Stable sorting

Stable sorting uses top-down merge sort. During merge, choose the right value
only when `less(right, left)` is true; equal values therefore retain source
order.

Deterministic map keys support only numbers and strings:

1. numbers sort before strings;
2. numbers sort ascending;
3. strings sort by Lua bytewise `<`.

No generated result may depend on `pairs()` traversal order.

## 9. Golden-vector provenance

The locked vectors in `tests/golden_vectors.lua` were calculated independently
in JavaScript using unsigned `Uint32` behavior and `Math.imul`, then verified
against stock Lua 5.1.5. They cover:

- empty-input digest;
- two canonical seed hashes;
- two named streams from the same root;
- ten consecutive xoshiro128** outputs;
- ten unbiased selections in `1..151`;
- a forced rejection-sampling case;
- a ten-element Fisher–Yates shuffle;
- stable duplicate ordering and mixed numeric/string keys.

The combined vectors execute the production generator and serve as
implementation-level change detection. Their source fixture and expected
values are stored separately so changing an input cannot silently bless new
outputs.

The complete suite runs with:

```powershell
./tools/test.ps1
```
