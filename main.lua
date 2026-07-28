-- Pokémon Gen 1 Randomizer entry point.
--
-- This file only assembles milestone-1 modules. Gameplay hooks are
-- intentionally deferred until their deterministic implementations exist.
return function(mod)
  local function loadModule(relative, ...)
    local source, readErr = mod:read(relative)
    assert(source, ("cannot read %s: %s"):format(relative, tostring(readErr)))

    local chunkName = "@" .. mod.path .. "/" .. relative
    local compile = loadstring or load
    local chunk, compileErr = compile(source, chunkName)
    assert(chunk, ("cannot compile %s: %s"):format(relative, tostring(compileErr)))

    local exported = chunk()
    if type(exported) == "function" then
      return exported(...)
    end
    return exported
  end

  local Constants = loadModule("src/constants.lua")
  local UInt32 = loadModule("src/uint32.lua")
  local Seed = loadModule("src/seed.lua")
  local Hash128 = loadModule("src/hash128.lua", Constants, UInt32)
  local StableSort = loadModule("src/stable_sort.lua")
  local Rng = loadModule("src/rng.lua", Constants, UInt32, Hash128)
  local Canonical = loadModule("src/canonical.lua", StableSort)
  local VanillaSpecies = loadModule("src/vanilla_species.lua")
  local Metadata = loadModule("src/species_metadata.lua", StableSort)
  local SpeciesManifest = loadModule(
    "src/species_manifest.lua",
    Constants, StableSort, Canonical, Hash128, VanillaSpecies)
  local SpeciesFilters = loadModule("src/species_filters.lua")
  local Contracts = loadModule("src/contracts.lua", Constants)
  local Foundation = {
    UInt32 = UInt32,
    Seed = Seed,
    Hash128 = Hash128,
    StableSort = StableSort,
    Rng = Rng,
    Canonical = Canonical,
  }
  local Species = {
    Metadata = Metadata.new(),
    Manifest = SpeciesManifest,
    Filters = SpeciesFilters,
    VanillaSpecies = VanillaSpecies,
  }
  local Generator = loadModule(
    "src/generator.lua", Constants, Contracts, Foundation, Species)
  local Bootstrap = loadModule(
    "src/bootstrap.lua", Constants, Contracts, Generator, Species)

  return Bootstrap.start(mod)
end
