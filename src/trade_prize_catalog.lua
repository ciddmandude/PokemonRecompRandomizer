-- Stock-v0.1.30 NPC trade bindings and Celadon Game Corner prize data.
-- Trade table row 3 (BUTTERFREE -> BEEDRILL) has no NPC script in Red/Blue,
-- so it is intentionally absent from the supported trade catalog.
local Catalog = {}

Catalog.trades = {
  {
    id = "TRADE_01_TERRY", index = 1,
    mapId = "ROUTE_11_GATE_2F",
    talkKey = "TEXT_ROUTE11GATE2F_YOUNGSTER",
    flag = "EVENT_TRADED_NIDORINO_FOR_NIDORINA",
    give = "NIDORINO", get = "NIDORINA",
  },
  {
    id = "TRADE_02_MARCEL", index = 2,
    mapId = "ROUTE_2_TRADE_HOUSE",
    talkKey = "TEXT_ROUTE2TRADEHOUSE_GAMEBOY_KID",
    flag = "EVENT_TRADED_ABRA_FOR_MR_MIME",
    give = "ABRA", get = "MR_MIME",
  },
  {
    id = "TRADE_04_SAILOR", index = 4,
    mapId = "CINNABAR_LAB_FOSSIL_ROOM",
    talkKey = "TEXT_CINNABARLABFOSSILROOM_SCIENTIST2",
    flag = "EVENT_TRADED_PONYTA_FOR_SEEL",
    give = "PONYTA", get = "SEEL",
  },
  {
    id = "TRADE_05_DUX", index = 5,
    mapId = "VERMILION_TRADE_HOUSE",
    talkKey = "TEXT_VERMILIONTRADEHOUSE_LITTLE_GIRL",
    flag = "EVENT_TRADED_SPEAROW_FOR_FARFETCHD",
    give = "SPEAROW", get = "FARFETCHD",
  },
  {
    id = "TRADE_06_MARC", index = 6,
    mapId = "ROUTE_18_GATE_2F",
    talkKey = "TEXT_ROUTE18GATE2F_YOUNGSTER",
    flag = "EVENT_TRADED_SLOWBRO_FOR_LICKITUNG",
    give = "SLOWBRO", get = "LICKITUNG",
  },
  {
    id = "TRADE_07_LOLA", index = 7,
    mapId = "CERULEAN_TRADE_HOUSE",
    talkKey = "TEXT_CERULEANTRADEHOUSE_GAMBLER",
    flag = "EVENT_TRADED_POLIWHIRL_FOR_JYNX",
    give = "POLIWHIRL", get = "JYNX",
  },
  {
    id = "TRADE_08_DORIS", index = 8,
    mapId = "CINNABAR_LAB_TRADE_ROOM",
    talkKey = "TEXT_CINNABARLABTRADEROOM_GRAMPS",
    flag = "EVENT_TRADED_RAICHU_FOR_ELECTRODE",
    give = "RAICHU", get = "ELECTRODE",
  },
  {
    id = "TRADE_09_CRINKLES", index = 9,
    mapId = "CINNABAR_LAB_TRADE_ROOM",
    talkKey = "TEXT_CINNABARLABTRADEROOM_BEAUTY",
    flag = "EVENT_TRADED_VENONAT_FOR_TANGELA",
    give = "VENONAT", get = "TANGELA",
  },
  {
    id = "TRADE_10_SPOT", index = 10,
    mapId = "UNDERGROUND_PATH_ROUTE_5",
    talkKey = "TEXT_UNDERGROUNDPATHROUTE5_LITTLE_GIRL",
    flag = "EVENT_TRADED_NIDORAN_M_FOR_NIDORAN_F",
    give = "NIDORAN_M", get = "NIDORAN_F",
  },
}

Catalog.prizes = {
  red = {
    { id = "GAME_CORNER_RED_1", species = "ABRA", level = 9, cost = 180 },
    { id = "GAME_CORNER_RED_2", species = "CLEFAIRY", level = 8, cost = 500 },
    { id = "GAME_CORNER_RED_3", species = "NIDORINA", level = 17, cost = 1200 },
    { id = "GAME_CORNER_RED_4", species = "DRATINI", level = 18, cost = 2800 },
    { id = "GAME_CORNER_RED_5", species = "SCYTHER", level = 25, cost = 5500 },
    { id = "GAME_CORNER_RED_6", species = "PORYGON", level = 26, cost = 9999 },
  },
  blue = {
    { id = "GAME_CORNER_BLUE_1", species = "ABRA", level = 6, cost = 120 },
    { id = "GAME_CORNER_BLUE_2", species = "CLEFAIRY", level = 12, cost = 750 },
    { id = "GAME_CORNER_BLUE_3", species = "NIDORINO", level = 17, cost = 1200 },
    { id = "GAME_CORNER_BLUE_4", species = "PINSIR", level = 20, cost = 2500 },
    { id = "GAME_CORNER_BLUE_5", species = "DRATINI", level = 24, cost = 4600 },
    { id = "GAME_CORNER_BLUE_6", species = "PORYGON", level = 18, cost = 6500 },
  },
}

Catalog.prizeItems = {
  { kind = "item", item = "TM_DRAGON_RAGE", cost = 3300 },
  { kind = "item", item = "TM_HYPER_BEAM", cost = 5500 },
  { kind = "item", item = "TM_SUBSTITUTE", cost = 7700 },
}

return Catalog
