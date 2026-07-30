-- Pokémon Gen 1 Randomizer entry point.
--
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
  local Matching = loadModule("src/matching.lua", StableSort)
  local Progression = loadModule("src/progression.lua", StableSort)
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
  local WildGlobal = loadModule(
    "src/wild_global.lua", StableSort, SpeciesFilters, Matching)
  local WildCategory = loadModule(
    "src/wild_category.lua",
    StableSort, SpeciesFilters, WildGlobal, Matching, Progression)
  local WildRuntime = loadModule("src/wild_runtime.lua")
  local StarterCategory = loadModule(
    "src/starter_category.lua", StableSort)
  local StarterOffer = loadModule("src/starter_offer.lua")
  local StarterCompat = loadModule(
    "src/starter_compat.lua", StarterOffer)
  local StarterRuntime = loadModule("src/starter_runtime.lua")
  local StaticGiftCatalog = loadModule("src/static_gift_catalog.lua")
  local StaticGiftCategory = loadModule(
    "src/static_gift_category.lua",
    StableSort, SpeciesFilters, StaticGiftCatalog, Matching)
  local StaticGiftCompat = loadModule(
    "src/static_gift_compat.lua", StaticGiftCatalog)
  local TradePrizeCatalog = loadModule("src/trade_prize_catalog.lua")
  local TradePrizeCategory = loadModule(
    "src/trade_prize_category.lua",
    StableSort, SpeciesFilters, TradePrizeCatalog, Matching, Progression)
  local TradePrizeCompat = loadModule(
    "src/trade_prize_compat.lua", TradePrizeCatalog)
  local TrainerCategory = loadModule(
    "src/trainer_category.lua", StableSort, SpeciesFilters, Matching)
  local TrainerRuntime = loadModule("src/trainer_runtime.lua")
  local ValidationCategory = loadModule(
    "src/validation_category.lua",
    StableSort, Canonical, Progression, TradePrizeCatalog)
  local SpoilerLog = loadModule("src/spoiler_log.lua")
  local Generator = loadModule(
    "src/generator.lua",
    Constants, Contracts, Foundation, Species, WildCategory, StarterCategory,
    StaticGiftCategory, TradePrizeCategory, TrainerCategory,
    Progression, ValidationCategory)
  local SaveState = loadModule(
    "src/save_state.lua",
    Constants, Seed, Hash128, Canonical, StableSort, Contracts)
  local GeneralSettings = loadModule(
    "src/general_settings.lua", SaveState)
  local SaveLifecycle = loadModule(
    "src/save_lifecycle.lua", Constants, Generator, SaveState, GeneralSettings)
  local SpoilerController = loadModule(
    "src/spoiler_controller.lua", Constants, SpoilerLog)
  local OptionsSchema = loadModule("src/options_schema.lua")
  local Preferences = loadModule(
    "src/preferences.lua", Constants, OptionsSchema, GeneralSettings)
  local OptionsScreen = loadModule("src/options_screen.lua", Constants)
  local ReviewScreen = loadModule("src/review_screen.lua")
  local Options = {
    Schema = OptionsSchema,
    Preferences = Preferences,
    Screen = OptionsScreen,
    ReviewScreen = ReviewScreen,
    General = GeneralSettings,
  }
  local Bootstrap = loadModule(
    "src/bootstrap.lua",
    Constants, Contracts, Generator, Species, SaveState, SaveLifecycle,
    Options, WildRuntime, StarterOffer, StarterCompat, StarterRuntime,
    StaticGiftCompat, TradePrizeCompat, TrainerRuntime,
    SpoilerController, SpoilerLog)

  return Bootstrap.start(mod)
end
