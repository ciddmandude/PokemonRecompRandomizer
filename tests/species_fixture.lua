local function stats(hp, attack, defense, speed, special)
  return {
    hp = hp,
    attack = attack,
    defense = defense,
    speed = speed,
    special = special,
  }
end

local function mon(id, dex, baseStats, types, evolution)
  local evolutions = {}
  if evolution then
    evolutions[1] = {
      method = "LEVEL",
      level = evolution.level,
      species = evolution.species,
    }
  end
  return {
    id = id,
    name = id,
    dex = dex,
    types = types,
    baseStats = baseStats,
    catchRate = 45,
    baseExp = 64,
    level1Moves = { "TACKLE" },
    growthRate = "MEDIUM_SLOW",
    learnset = {},
    evolutions = evolutions,
    spriteFront = "battle/front/" .. string.lower(id) .. ".png",
    spriteBack = "battle/back/" .. string.lower(id) .. "b.png",
    frontSize = 7,
  }
end

local records = {
  BULBASAUR = mon("BULBASAUR", 1, stats(45, 49, 49, 45, 65),
    { "GRASS", "POISON" }, { level = 16, species = "IVYSAUR" }),
  IVYSAUR = mon("IVYSAUR", 2, stats(60, 62, 63, 60, 80),
    { "GRASS", "POISON" }, { level = 32, species = "VENUSAUR" }),
  VENUSAUR = mon("VENUSAUR", 3, stats(80, 82, 83, 80, 100),
    { "GRASS", "POISON" }),
  CHARMANDER = mon("CHARMANDER", 4, stats(39, 52, 43, 65, 50),
    { "FIRE" }, { level = 16, species = "CHARMELEON" }),
  CHARMELEON = mon("CHARMELEON", 5, stats(58, 64, 58, 80, 65),
    { "FIRE" }, { level = 36, species = "CHARIZARD" }),
  CHARIZARD = mon("CHARIZARD", 6, stats(78, 84, 78, 100, 85),
    { "FIRE", "FLYING" }),
  MEW = mon("MEW", 151, stats(100, 100, 100, 100, 100),
    { "PSYCHIC" }),
  MODMON = mon("MODMON", 1001, stats(50, 50, 50, 50, 50),
    { "NORMAL" }),
  BROKENMON = mon("BROKENMON", 1002, stats(1, 1, 1, 1, 1),
    { "NORMAL" }),
}
records.BROKENMON.spriteBack = nil

return {
  records = records,
  cloneRecords = function()
    local copy = {}
    local ids = {
      "BROKENMON", "MODMON", "MEW", "CHARIZARD", "CHARMELEON",
      "CHARMANDER", "VENUSAUR", "IVYSAUR", "BULBASAUR",
    }
    for _, id in ipairs(ids) do copy[id] = records[id] end
    return copy
  end,
}
