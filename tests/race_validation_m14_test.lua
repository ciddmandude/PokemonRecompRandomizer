-- Milestone-14 race protection, repair, fallback, and property tests.
local function loadFactory(path, ...)
  local chunk, err = loadfile(path)
  assert(chunk, err)
  local value = chunk()
  if type(value) == "function" then return value(...) end
  return value
end

local Constants = loadFactory("src/constants.lua")
local UInt32 = loadFactory("src/uint32.lua")
local Hash128 = loadFactory("src/hash128.lua", Constants, UInt32)
local Sha256 = loadFactory("src/sha256.lua", UInt32)
local StableSort = loadFactory("src/stable_sort.lua")
local Canonical = loadFactory("src/canonical.lua", StableSort)
local Rng = loadFactory("src/rng.lua", Constants, UInt32, Hash128)
local Crypto = loadFactory("src/race_crypto.lua", Canonical, Sha256)
local Spoiler = loadFactory("src/spoiler_log.lua", Canonical, Crypto)
local Validation = loadFactory(
  "src/validation_category.lua", StableSort, Canonical)
local WildRuntime = loadFactory("src/wild_runtime.lua")
local TrainerRuntime = loadFactory("src/trainer_runtime.lua")

assert(Sha256.digest("abc").hex
  == "BA7816BF8F01CFEA414140DE5DAE2223"
    .. "B00361A396177A9CB410FF61F20015AD",
  "SHA-256 known vector")
assert(Sha256.hmac("key", "The quick brown fox jumps over the lazy dog").hex
  == "F7BC83F430538424B13298E6AA6FB143"
    .. "EF4D59A14946175997479DBC2D1A3CD8",
  "HMAC-SHA-256 known vector")

local run = {
  schemaVersion = 1,
  algorithmVersion = "1.0.0-dev",
  enabled = true,
  seed = { canonical = "RACE TEST", hash128 = ("A"):rep(32) },
  settings = { race_mode = "on" },
  compatibility = {
    settingsHash = ("B"):rep(32),
    poolHash = ("C"):rep(32),
  },
  mappings = {
    wildGlobal = { RAT = "CAT" },
    trainerParties = {
      OPP_FIX = { [1] = {{ species = "CAT", level = 5 }} },
    },
  },
  diagnostics = { warnings = {}, fallbackCount = 0 },
  race = {
    enabled = true, unlockPolicy = "passphrase", unlocked = false,
  },
}

local plaintext = Spoiler.text(run)
local envelope, digest = Crypto.encrypt(
  plaintext, "organizer passphrase", run, "fixed unique entropy")
assert(envelope:match("^PRRACE1\n") and #digest == 64,
  "encrypted envelope and authentication digest")
local decrypted, err = Crypto.decrypt(envelope, "organizer passphrase")
assert(decrypted == plaintext and err == nil,
  "correct passphrase decrypts the spoiler")
assert(Crypto.decrypt(envelope, "wrong passphrase") == nil,
  "wrong passphrase must fail")
local tampered = envelope:gsub("ciphertext=([0-9A-F])",
  function(first) return "ciphertext=" .. (first == "0" and "1" or "0") end, 1)
assert(Crypto.decrypt(tampered, "organizer passphrase") == nil,
  "modified ciphertext must fail authentication")

local public = Spoiler.publicRun(run)
assert(public.mappings == nil and public.seed.canonical == nil,
  "locked public run must redact seed and mappings")
run.race.unlocked = true
assert(Spoiler.publicRun(run).mappings.wildGlobal.RAT == "CAT",
  "unlocked run may expose mappings")
run.race.unlocked = false

local written = {}
local fs = {
  createDirectory = function() return true end,
  write = function(path, data)
    written.path, written.data = path, data
    return true
  end,
}
local exported = assert(Spoiler.export(run, {
  filesystem = fs,
  passphrase = "organizer passphrase",
  entropy = "export entropy",
}))
assert(exported.encrypted and written.data:match("^PRRACE1\n"),
  "locked race export must write only encrypted content")
assert(not written.data:find("MAPPINGS=", 1, true),
  "locked export must not leak plaintext mappings")

local mappings = {
  wildGlobal = { A = "CAT", B = "CAT" },
  wildAreaSlots = {}, fishing = {}, starters = {},
  starterFlags = {}, staticEncounters = {}, gifts = {},
  prizes = {}, trainerParties = {},
  trades = {
    TRADE = {
      requested = { species = "DOG" },
      received = { species = "BIRD" },
    },
  },
}
local repaired = Validation.apply(mappings, {
  catchability_guard = "on",
}, Rng.fromSeed("M14 REPAIR", "validation.swaps"))
assert(repaired.repairSwaps == 1,
  "unreachable trade request must be deterministically repaired")
local reach = Validation.reachableSpecies(mappings)
assert(reach[mappings.trades.TRADE.requested.species],
  "repaired requested species must be reachable")
assert(repaired.estimatedBytes < 1048576,
  "synthetic mapping remains within save-size budget")

local missingRun = {
  enabled = true,
  settings = { wild_pokemon = "global_map", wild_levels = "unchanged" },
  mappings = {
    wildGlobal = { RAT = "MISSING" },
    wildAreaSlots = {},
    trainerParties = {
      OPP_FIX = { [1] = {{ species = "MISSING", level = 9 }} },
    },
  },
  _speciesSet = { RAT = true, CAT = true },
}
local encounter = { species = "RAT", level = 4 }
assert(WildRuntime.resolve(encounter,
  { terrain = "grass", mapId = "MAP" }, missingRun) == encounter,
  "missing wild destination falls back without rewriting the mapping")
local party = {{ species = "RAT", level = 5 }}
assert(TrainerRuntime.party(
  party, "OPP_FIX", 1, missingRun) == party,
  "missing trainer destination falls back to the prior party")
assert(missingRun.mappings.wildGlobal.RAT == "MISSING",
  "runtime fallback must not rewrite saved mappings")

-- Bounded 10,000-seed property pass for each shipped preset profile.
for _, preset in ipairs({ "casual", "standard", "chaos" }) do
  for seedIndex = 1, 10000 do
    local rng = Rng.fromSeed(
      preset:upper() .. " " .. tostring(seedIndex), "validation.swaps")
    local level = rng:nextInt(2, 100)
    local size = rng:nextInt(1, 6)
    assert(level >= 2 and level <= 100 and size >= 1 and size <= 6)
  end
end

print("race_validation_m14_test: ok")
