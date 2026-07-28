-- Stock-v0.1.30 records that can be safely replaced through public API-2
-- map_scripts and commands composition. This is intentionally not a claim
-- that every engine static/gift path is exposed.
local Catalog = {}

Catalog.statics = {
  {
    id = "POWER_PLANT_VOLTORB_0", mapId = "POWER_PLANT",
    talkKey = "TEXT_POWERPLANT_VOLTORB1", species = "VOLTORB", level = 40,
    flag = "EVENT_BEAT_POWER_PLANT_VOLTORB_0", style = "power_ball",
  },
  {
    id = "POWER_PLANT_VOLTORB_1", mapId = "POWER_PLANT",
    talkKey = "TEXT_POWERPLANT_VOLTORB2", species = "VOLTORB", level = 40,
    flag = "EVENT_BEAT_POWER_PLANT_VOLTORB_1", style = "power_ball",
  },
  {
    id = "POWER_PLANT_VOLTORB_2", mapId = "POWER_PLANT",
    talkKey = "TEXT_POWERPLANT_VOLTORB3", species = "VOLTORB", level = 40,
    flag = "EVENT_BEAT_POWER_PLANT_VOLTORB_2", style = "power_ball",
  },
  {
    id = "POWER_PLANT_ELECTRODE_3", mapId = "POWER_PLANT",
    talkKey = "TEXT_POWERPLANT_ELECTRODE1",
    species = "ELECTRODE", level = 43,
    flag = "EVENT_BEAT_POWER_PLANT_VOLTORB_3", style = "power_ball",
  },
  {
    id = "POWER_PLANT_VOLTORB_4", mapId = "POWER_PLANT",
    talkKey = "TEXT_POWERPLANT_VOLTORB4", species = "VOLTORB", level = 40,
    flag = "EVENT_BEAT_POWER_PLANT_VOLTORB_4", style = "power_ball",
  },
  {
    id = "POWER_PLANT_VOLTORB_5", mapId = "POWER_PLANT",
    talkKey = "TEXT_POWERPLANT_VOLTORB5", species = "VOLTORB", level = 40,
    flag = "EVENT_BEAT_POWER_PLANT_VOLTORB_5", style = "power_ball",
  },
  {
    id = "POWER_PLANT_ELECTRODE_6", mapId = "POWER_PLANT",
    talkKey = "TEXT_POWERPLANT_ELECTRODE2",
    species = "ELECTRODE", level = 43,
    flag = "EVENT_BEAT_POWER_PLANT_VOLTORB_6", style = "power_ball",
  },
  {
    id = "POWER_PLANT_VOLTORB_7", mapId = "POWER_PLANT",
    talkKey = "TEXT_POWERPLANT_VOLTORB6", species = "VOLTORB", level = 40,
    flag = "EVENT_BEAT_POWER_PLANT_VOLTORB_7", style = "power_ball",
  },
  {
    id = "ZAPDOS", mapId = "POWER_PLANT",
    talkKey = "TEXT_POWERPLANT_ZAPDOS", species = "ZAPDOS", level = 50,
    flag = "EVENT_BEAT_ZAPDOS", style = "legend",
    battleText = "_PowerPlantZapdosBattleText",
  },
  {
    id = "MEWTWO", mapId = "CERULEAN_CAVE_B1F",
    talkKey = "TEXT_CERULEANCAVEB1F_MEWTWO",
    species = "MEWTWO", level = 70,
    flag = "EVENT_BEAT_MEWTWO", style = "legend",
    battleText = "_MewtwoBattleText",
  },
  {
    id = "ARTICUNO", mapId = "SEAFOAM_ISLANDS_B4F",
    talkKey = "TEXT_SEAFOAMISLANDSB4F_ARTICUNO",
    species = "ARTICUNO", level = 50,
    flag = "EVENT_BEAT_ARTICUNO", style = "legend",
    battleText = "_SeafoamIslandsB4FArticunoBattleText",
  },
  {
    id = "MOLTRES", mapId = "VICTORY_ROAD_2F",
    talkKey = "TEXT_VICTORYROAD2F_MOLTRES",
    species = "MOLTRES", level = 50,
    flag = "EVENT_BEAT_MOLTRES", style = "legend",
    battleText = "_VictoryRoad2FMoltresBattleText",
  },
  {
    id = "SNORLAX_ROUTE_12", mapId = "ROUTE_12",
    talkKey = "TEXT_ROUTE12_SNORLAX", species = "SNORLAX", level = 30,
    flag = "EVENT_BEAT_ROUTE12_SNORLAX", style = "snorlax",
    object = "ROUTE12_SNORLAX",
    wokeText = "{RAM} woke up!",
    calmedText = "{RAM} calmed down!",
    sleepingText = "_Route12SnorlaxText",
    vanillaWokeText = "_Route12SnorlaxWokeUpText",
    vanillaCalmedText = "_Route12SnorlaxCalmedDownText",
  },
  {
    id = "SNORLAX_ROUTE_16", mapId = "ROUTE_16",
    talkKey = "TEXT_ROUTE16_SNORLAX", species = "SNORLAX", level = 30,
    flag = "EVENT_BEAT_ROUTE16_SNORLAX", style = "snorlax",
    object = "ROUTE16_SNORLAX",
    wokeText = "{RAM} woke up!",
    calmedText = "{RAM} returned to\nthe mountains!",
    sleepingText = "_Route16Text7",
    vanillaWokeText = "_Route16SnorlaxWokeUpText",
    vanillaCalmedText = "_Route16SnorlaxReturnedToMountainsText",
  },
}

Catalog.gifts = {
  {
    id = "CELADON_EEVEE", mapId = "CELADON_MANSION_ROOF_HOUSE",
    talkKey = "TEXT_CELADONMANSION_ROOF_HOUSE_EEVEE_POKEBALL",
    species = "EEVEE", level = 25, style = "eevee",
    flag = "EVENT_GOT_EEVEE",
    object = "CELADONMANSION_ROOF_HOUSE_EEVEE_POKEBALL",
  },
  {
    id = "MAGIKARP_SALE", mapId = "MT_MOON_POKECENTER",
    talkKey = "TEXT_MTMOONPOKECENTER_MAGIKARP_SALESMAN",
    species = "MAGIKARP", level = 5, style = "sale",
    flag = "EVENT_BOUGHT_MAGIKARP", price = 500,
  },
  {
    id = "DOJO_LEFT", mapId = "FIGHTING_DOJO",
    talkKey = "TEXT_FIGHTINGDOJO_HITMONLEE_POKE_BALL",
    species = "HITMONLEE", level = 30, style = "dojo",
    flag = "EVENT_GOT_HITMONLEE",
    object = "FIGHTINGDOJO_HITMONLEE_POKE_BALL",
    choiceGroup = "FIGHTING_DOJO",
    askText = "_FightingDojoHitmonleePokeBallText",
  },
  {
    id = "DOJO_RIGHT", mapId = "FIGHTING_DOJO",
    talkKey = "TEXT_FIGHTINGDOJO_HITMONCHAN_POKE_BALL",
    species = "HITMONCHAN", level = 30, style = "dojo",
    flag = "EVENT_GOT_HITMONCHAN",
    object = "FIGHTINGDOJO_HITMONCHAN_POKE_BALL",
    choiceGroup = "FIGHTING_DOJO",
    askText = "_FightingDojoHitmonchanPokeBallText",
  },
  {
    id = "SILPH_LAPRAS", mapId = "SILPH_CO_7F",
    talkKey = "TEXT_SILPHCO7F_SILPH_WORKER_M1",
    species = "LAPRAS", level = 15, style = "lapras",
    flag = "EVENT_GOT_LAPRAS",
  },
}

Catalog.exclusions = {
  "FOSSIL_RESTORATION",
  "POKEMON_TOWER_GHOST",
  "GAME_CORNER_PRIZES",
  "GENERIC_OBJECT_EVENT_STATICS",
  "CATCHING_TUTORIAL",
}

return Catalog
