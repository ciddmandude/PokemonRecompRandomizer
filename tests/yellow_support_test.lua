-- Yellow-version generation and public map-script compatibility tests.
local function loadFactory(path, ...)
  local chunk, err = loadfile(path)
  assert(chunk, err)
  local value = chunk()
  if type(value) == "function" then return value(...) end
  return value
end

local Constants = loadFactory("src/constants.lua")
local UInt32 = loadFactory("src/uint32.lua")
local Seed = loadFactory("src/seed.lua")
local Hash128 = loadFactory("src/hash128.lua", Constants, UInt32)
local StableSort = loadFactory("src/stable_sort.lua")
local Rng = loadFactory("src/rng.lua", Constants, UInt32, Hash128)
local Canonical = loadFactory("src/canonical.lua", StableSort)
local Contracts = loadFactory("src/contracts.lua", Constants)
local SaveState = loadFactory("src/save_state.lua",
  Constants, Seed, Hash128, Canonical, StableSort, Contracts)
local Matching = loadFactory("src/matching.lua", StableSort)
local Filters = loadFactory("src/species_filters.lua")
local StarterCategory = loadFactory("src/starter_category.lua", StableSort)
local StarterOffer = loadFactory("src/starter_offer.lua")
local StarterCompat = loadFactory("src/starter_compat.lua", StarterOffer)
local GiftCatalog = loadFactory("src/static_gift_catalog.lua")
local GiftCategory = loadFactory("src/static_gift_category.lua",
  StableSort, Filters, GiftCatalog, Matching)
local GiftCompat = loadFactory("src/static_gift_compat.lua", GiftCatalog)
local Progression = loadFactory("src/progression.lua", StableSort)

local function entry(id, typeId, evolution)
  return {
    id = id, bst = 300, types = { typeId or "NORMAL" },
    primaryType = typeId or "NORMAL", stage = "basic",
    legendary = false, evolutions = evolution and {
      { species = evolution },
    } or {},
  }
end

local entries = {
  entry("PIKACHU", "ELECTRIC"), entry("EEVEE", "NORMAL"),
  entry("BULBASAUR", "GRASS"), entry("CHARMANDER", "FIRE"),
  entry("SQUIRTLE", "WATER"), entry("PIDGEY", "FLYING"),
  entry("RATTATA", "NORMAL"), entry("ODDISH", "GRASS"),
  entry("SANDSHREW", "GROUND"), entry("MEOWTH", "NORMAL"),
  entry("PSYDUCK", "WATER"), entry("MANKEY", "FIGHTING"),
  entry("MAGIKARP", "WATER"), entry("HITMONLEE", "FIGHTING"),
  entry("HITMONCHAN", "FIGHTING"), entry("LAPRAS", "WATER"),
  entry("OMANYTE", "WATER"), entry("KABUTO", "ROCK"),
  entry("AERODACTYL", "ROCK"),
}
local manifest = { entries = entries, byId = {} }
for _, row in ipairs(entries) do manifest.byId[row.id] = row end

local starterSettings = {
  starters = "random", starter_stage = "basic_only", starter_level = 8,
  rival_counterpick = "type_advantage", legendaries = "exclude",
}
local function starterStreams(seed)
  return {
    starters = Rng.fromSeed(seed, "starters"),
    rival = Rng.fromSeed(seed, "rival.counterpick"),
  }
end
local yellowA = StarterCategory.generate(manifest, starterSettings,
  starterStreams("YELLOW STARTER"), nil, "yellow")
local yellowB = StarterCategory.generate(manifest, starterSettings,
  starterStreams("YELLOW STARTER"), nil, "yellow")
local offer = assert(yellowA.starters.YELLOW)
assert(offer.species == yellowB.starters.YELLOW.species
  and offer.rivalSpecies == yellowB.starters.YELLOW.rivalSpecies)
assert(offer.species ~= offer.rivalSpecies and offer.level == 8)
assert(offer.choseFlag == "EVENT_CHOSE_PIKACHU")
assert(yellowA.starterFlags.partyOffsetSlots[1] == "YELLOW"
  and yellowA.starterFlags.partyOffsetSlots[3] == "YELLOW")
assert(yellowA.starters.LEFT == nil,
  "Yellow must save one forced starter rather than three ball choices")

local speciesSet, speciesRows = {}, {}
for _, row in ipairs(entries) do
  speciesSet[row.id] = true
  speciesRows[#speciesRows + 1] = { id = row.id }
end
local generated = Contracts.newGenerationResult()
generated.mappings.starters = yellowA.starters
generated.mappings.starterFlags = yellowA.starterFlags
local namespace = assert(SaveState.create({
  seed = assert(SaveState.makeSeed("manual", "YELLOW SAVE")),
  settings = starterSettings,
  compatibility = SaveState.compatibility({
    version = "yellow", meta = { engine = "0.1.45" },
  }, "YELLOW-POOL", starterSettings),
  species = speciesRows,
  speciesSet = speciesSet,
  sources = {},
}, function() return generated end))
local valid, errors = SaveState.validate(namespace, speciesSet, true)
assert(valid, errors[1] and errors[1].message)
local damaged = SaveState.clone(namespace)
damaged.mappings.starters.YELLOW.rivalSpecies =
  damaged.mappings.starters.YELLOW.species
local stamped, structuralErrors = SaveState.stamp(damaged, speciesSet)
assert(not stamped and #structuralErrors > 0,
  "Yellow saves must reject identical player and rival starters")

local captured
local contribution = StarterCompat.contribution(function()
  return { mappings = { starters = yellowA.starters } }
end)
local game = {
  save = { flags = { EVENT_OAK_ASKED_TO_CHOOSE_MON = true } },
  data = { pokemon = manifest.byId },
}
local overworld = {
  player = { cellX = 9, cellY = 4 },
  runner = { run = function(_, rows) captured = rows end },
}
contribution.talk.TEXT_OAKSLAB_EEVEE_POKE_BALL(
  game, overworld, {}, function() end)
local gavePlayer, namedRival = false, false
for _, row in ipairs(captured) do
  if row[1] == "give_pokemon" then
    gavePlayer = row[2] == offer.species and row[3] == offer.level
  elseif row[1] == "show_text" and type(row[3]) == "table"
      and row[3].RAM == offer.rivalSpecies then
    namedRival = true
  end
end
assert(gavePlayer and namedRival,
  "Yellow lab script must award and display the saved starter pair")

local giftSettings = {
  static_pokemon = "off", gift_pokemon = "randomized",
  gift_levels = "unchanged", gift_uniqueness = "unique",
  similar_strength = "off", legendaries = "allow",
  duplicate_policy = "allow",
}
local gifts = GiftCategory.generate(manifest, giftSettings, {
  staticSpecies = Rng.fromSeed("YELLOW GIFTS", "static.encounters"),
  staticLevels = Rng.fromSeed("YELLOW GIFTS", "static.levels"),
  giftSpecies = Rng.fromSeed("YELLOW GIFTS", "gifts"),
  giftLevels = Rng.fromSeed("YELLOW GIFTS", "gift.levels"),
}, { gameVersion = "yellow" })
assert(gifts.gifts.YELLOW_BULBASAUR
  and gifts.gifts.YELLOW_CHARMANDER
  and gifts.gifts.YELLOW_SQUIRTLE,
  "all three Yellow-only gifts must be generated")

local ui = {
  TextBox = { new = function() return {} end },
  ListMenu = { new = function() return {} end },
}
local yellowContributions = GiftCompat.contributions(
  function() return { settings = starterSettings, mappings = gifts } end,
  ui, "yellow")
assert(yellowContributions.CERULEAN_MELANIES_HOUSE
  and yellowContributions.ROUTE_24
  and yellowContributions.VERMILION_CITY)
local redContributions = GiftCompat.contributions(
  function() return nil end, ui, "red")
assert(redContributions.CERULEAN_MELANIES_HOUSE == nil,
  "Yellow-only map scripts must not be registered for Red/Blue")

assert(Progression.access("ROUTE_1", "walk", nil, "yellow").available)
assert(Progression.access(
  "CERULEAN_MELANIES_HOUSE", "walk", nil, "yellow").available)

io.write("yellow_support_test: ok\n")
