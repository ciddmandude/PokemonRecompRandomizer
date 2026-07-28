-- Standalone milestone-2 deterministic-foundation test:
--   lua tests/foundation_test.lua
-- Run from the repository root.
local function loadFactory(path, ...)
  local chunk, err = loadfile(path)
  assert(chunk, err)
  local value = chunk()
  if type(value) == "function" then return value(...) end
  return value
end

local function equal(actual, expected, label)
  assert(actual == expected,
    ("%s: expected %s, got %s"):format(
      label, tostring(expected), tostring(actual)))
end

local function equalArray(actual, expected, label)
  equal(#actual, #expected, label .. " length")
  for index = 1, #expected do
    equal(actual[index], expected[index],
      ("%s[%d]"):format(label, index))
  end
end

local Constants = loadFactory("src/constants.lua")
local UInt32 = loadFactory("src/uint32.lua")
local Seed = loadFactory("src/seed.lua")
local Hash128 = loadFactory("src/hash128.lua", Constants, UInt32)
local StableSort = loadFactory("src/stable_sort.lua")
local Rng = loadFactory("src/rng.lua", Constants, UInt32, Hash128)
local Vectors = loadFactory("tests/golden_vectors.lua")

-- Seed canonicalization.
equal(Seed.normalize("  my   seed  "), "MY SEED", "normalize spaces")
equal(Seed.normalize("race_seed-01"), "RACE_SEED-01", "normalize case")
local value, err = Seed.normalize("")
equal(value, nil, "empty seed rejected")
equal(err.code, "EMPTY", "empty seed error")
value, err = Seed.normalize("MEW!")
equal(value, nil, "punctuation rejected")
equal(err.code, "INVALID_CHARACTER", "punctuation error")
value, err = Seed.normalize(string.rep("A", 33))
equal(value, nil, "long seed rejected")
equal(err.code, "TOO_LONG", "long seed error")

-- Exact unsigned arithmetic.
equal(UInt32.xor(4294967295, 305419896), 3989547399, "xor32")
equal(UInt32.mul(4294967295, 4294967295), 1, "mul32")
equal(UInt32.rotl(305419896, 8), 878082066, "rotl32")
equal(UInt32.toHex(4294967295), "FFFFFFFF", "hex32")

-- Hash vectors.
local digest = Hash128.digest("")
equalArray(digest.words, Vectors.hash.digestEmpty.words, "digest empty words")
equal(digest.hex, Vectors.hash.digestEmpty.hex, "digest empty hex")

local root = Hash128.seed("MY SEED")
equalArray(root.words, Vectors.hash.seedMySeed.words, "seed hash words")
equal(root.hex, Vectors.hash.seedMySeed.hex, "seed hash hex")

local race = Hash128.seed("RACE_SEED-01")
equalArray(race.words, Vectors.hash.seedRace.words, "race hash words")
equal(race.hex, Vectors.hash.seedRace.hex, "race hash hex")

local wild = Hash128.derive(root, "wild.global")
equalArray(wild.words, Vectors.streams.wildGlobal.words, "wild stream words")
equal(wild.hex, Vectors.streams.wildGlobal.hex, "wild stream hex")
local starters = Hash128.derive(root, "starters")
equalArray(starters.words, Vectors.streams.starters.words, "starter stream words")
equal(starters.hex, Vectors.streams.starters.hex, "starter stream hex")
assert(wild.hex ~= starters.hex, "named streams must differ")

local streamHashes = {}
for _, name in ipairs(Constants.STREAM_NAMES) do
  local streamHash = Hash128.derive(root, name).hex
  assert(not streamHashes[streamHash],
    ("stream collision between %s and %s"):format(
      name, tostring(streamHashes[streamHash])))
  streamHashes[streamHash] = name
end

-- xoshiro128** output and unbiased ranges.
local rng = Rng.fromSeed("MY SEED", "wild.global")
local output = {}
for index = 1, #Vectors.nextU32 do output[index] = rng:nextU32() end
equalArray(output, Vectors.nextU32, "nextU32")

rng = Rng.fromSeed("MY SEED", "wild.global")
output = {}
for index = 1, #Vectors.nextInt151 do
  output[index] = rng:nextInt(1, 151)
end
equalArray(output, Vectors.nextInt151, "nextInt151")

-- The first draw is above this range's acceptance limit, so this vector
-- proves rejection and a second draw rather than modulo-only sampling.
rng = Rng.fromSeed("MY SEED", "wild.global")
equal(rng:nextInt(0, 2147483648), 2052928304, "rejection sampling")
equal(rng.draws, 2, "rejection draw count")

rng = Rng.fromSeed("MY SEED", "wild.global")
local source = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
local shuffled = rng:shuffle(source)
equalArray(shuffled, Vectors.shuffle10, "shuffle10")
equalArray(source, { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
  "shuffle does not mutate input")

-- Stable sort and deterministic mixed key order.
local records = {
  { score = 2, id = "A" },
  { score = 1, id = "B" },
  { score = 2, id = "C" },
  { score = 1, id = "D" },
}
local sorted = StableSort.sort(records, function(a, b)
  return a.score < b.score
end)
equal(sorted[1].id, "B", "stable sort first")
equal(sorted[2].id, "D", "stable sort equal order 1")
equal(sorted[3].id, "A", "stable sort equal order 2")
equal(sorted[4].id, "C", "stable sort last")
equalArray(StableSort.keys({ b = true, [3] = true, a = true, [1] = true }),
  { 1, 3, "a", "b" }, "sorted keys")

io.write("foundation_test: ok\n")
