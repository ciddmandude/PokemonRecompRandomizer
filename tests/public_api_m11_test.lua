-- Remediation M11 immutable facades and active-run mutation isolation.
local function loadFactory(path, ...)
  local chunk, err = loadfile(path)
  assert(chunk, err)
  local value = chunk()
  if type(value) == "function" then return value(...) end
  return value
end

local PublicFacade = loadFactory("src/public_facade.lua")
local Spoiler = loadFactory("src/spoiler_log.lua")

local calls = 0
local generator = {
  interfaceVersion = 1,
  algorithmVersion = "TEST",
  available = true,
  foundationAvailable = true,
  hashVersion = "HASH",
  prngVersion = "PRNG",
  generate = function(request)
    calls = calls + 1
    return { request = request }
  end,
  validate = function() return true, {} end,
  emptyResult = function() return { mappings = {} } end,
  normalizeSeed = function(value) return value end,
  hashSeed = function(value) return "H:" .. value end,
  newStream = function() return {} end,
  stableSort = function(values) return values end,
  sortedKeys = function() return {} end,
  buildSpeciesManifest = function() return { entries = {} } end,
  speciesCandidates = function() return {}, {} end,
}
local facade = PublicFacade.generator(generator)
assert(facade.generate({ seed = "A" }).request.seed == "A")
assert(calls == 1)
local ok, err = pcall(function()
  facade.generate = function() return "replaced" end
end)
assert(not ok and tostring(err):find("read%-only"))
assert(generator.generate({ seed = "B" }).request.seed == "B")
assert(calls == 2, "facade assignment must not replace the internal generator")
assert(getmetatable(facade) == "read-only")

-- rawset can only shadow the caller's empty proxy; it still cannot mutate the
-- captured implementation used internally by the randomizer.
rawset(facade, "generate", function() return "shadow" end)
assert(facade.generate() == "shadow")
assert(generator.generate({ seed = "C" }).request.seed == "C")
assert(calls == 3)

local contracts = {
  categoryKeys = function() return { "wild" } end,
  mappingKeys = function() return { "wildGlobal" } end,
  validateGenerationRequest = function() return true, {} end,
  validateGenerationResult = function() return true, {} end,
}
local contractFacade = PublicFacade.contracts(contracts)
ok = pcall(function() contractFacade.mappingKeys = function() return {} end end)
assert(not ok, "contract facade must reject replacement")
local keys = contractFacade.mappingKeys()
keys[1] = "changed"
assert(contracts.mappingKeys()[1] == "wildGlobal")

local internalRun = {
  seed = { canonical = "SAFE SEED" },
  settings = {
    wild_pokemon = "global_map",
    race_mode = "on",
  },
  mappings = {
    wildGlobal = { PIDGEY = "RATTATA" },
    nested = { list = { "ONE", "TWO" } },
  },
  diagnostics = {
    warnings = {
      { code = "TEST", details = { value = 1 } },
    },
  },
  race = { secret = true },
  _speciesSet = { RATTATA = true },
}
local first = Spoiler.publicRun(internalRun)
assert(first.race == nil and first._speciesSet == nil)
assert(first.settings.race_mode == nil)
first.seed.canonical = "MUTATED"
first.settings.wild_pokemon = "off"
first.mappings.wildGlobal.PIDGEY = "MEW"
first.mappings.nested.list[1] = "CHANGED"
first.diagnostics.warnings[1].details.value = 999

assert(internalRun.seed.canonical == "SAFE SEED")
assert(internalRun.settings.wild_pokemon == "global_map")
assert(internalRun.mappings.wildGlobal.PIDGEY == "RATTATA")
assert(internalRun.mappings.nested.list[1] == "ONE")
assert(internalRun.diagnostics.warnings[1].details.value == 1)
local second = Spoiler.publicRun(internalRun)
assert(second.seed.canonical == "SAFE SEED")
assert(second.mappings.wildGlobal.PIDGEY == "RATTATA")
assert(second.diagnostics.warnings[1].details.value == 1)

print("public_api_m11_test: ok")
