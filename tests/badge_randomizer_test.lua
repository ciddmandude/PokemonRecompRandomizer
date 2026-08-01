local function loadFactory(path, ...)
  local chunk, err = loadfile(path)
  assert(chunk, err)
  local value = chunk()
  return type(value) == "function" and value(...) or value
end

local StableSort = loadFactory("src/stable_sort.lua")
local Progression = loadFactory("src/progression.lua", StableSort)
local Category = loadFactory("src/item_category.lua", StableSort, Progression)

local BADGES = {
  { "brock", "PEWTER_GYM", "BOULDERBADGE" },
  { "misty", "CERULEAN_GYM", "CASCADEBADGE" },
  { "surge", "VERMILION_GYM", "THUNDERBADGE" },
  { "erika", "CELADON_GYM", "RAINBOWBADGE" },
  { "koga", "FUCHSIA_GYM", "SOULBADGE" },
  { "sabrina", "SAFFRON_GYM", "MARSHBADGE" },
  { "blaine", "CINNABAR_GYM", "VOLCANOBADGE" },
  { "giovanni", "VIRIDIAN_GYM", "EARTHBADGE" },
}

local items, scripted = { POTION = { name = "POTION" } }, {}
for _, badge in ipairs(BADGES) do
  items[badge[3]] = { name = badge[3], keyItem = true }
  scripted[#scripted + 1] = {
    id = badge[1] .. "_badge", mapId = badge[2], item = badge[3],
    flag = "BEAT_" .. badge[1]:upper(), battle = true,
    command = false, badge = true,
  }
end

local objects = {}
for index = 1, 12 do
  objects[index] = { index = index, item = "POTION" }
end
local sources = {
  items = items,
  maps = { ROUTE_1 = { objects = objects } },
  field = { hiddenItems = {} },
  startingPcItems = { POTION = 1 },
  scriptedItems = scripted,
  gameVersion = "red",
}

local rng = {
  value = 0,
  nextU32 = function(self) self.value = self.value + 1 return self.value end,
  nextInt = function(_, _, last) return last end,
  shuffle = function(_, values)
    local output = {}
    for index = #values, 1, -1 do output[#output + 1] = values[index] end
    return output
  end,
}

local generated = Category.generate(sources, {
  non_key_items = "off", tms = "off", hms = "off", key_items = "off",
  badges = "random", ensure_beatable = "on", shops = "off",
}, rng)
assert(#generated.warnings == 0, "supported badge pool should be provably beatable")

local counts, fieldRows = {}, 0
for _, row in ipairs(generated.placements) do
  if row.kind == "visible" then fieldRows = fieldRows + 1 end
  if items[row.item] and row.item:find("BADGE$") then
    counts[row.item] = (counts[row.item] or 0) + 1
    assert(row.kind ~= "shop", "badges must remain one-time acquisitions")
  end
end
for _, badge in ipairs(BADGES) do
  assert(counts[badge[3]] == 1, badge[3] .. " must appear exactly once")
end
assert(fieldRows == #objects,
  "mixed mode includes supported field-item checks in the shared pool")

local unrestricted = Category.generate(sources, {
  non_key_items = "off", tms = "off", hms = "off", key_items = "off",
  badges = "random", ensure_beatable = "off", shops = "off",
}, rng)
local sawPcCheck = false
for _, row in ipairs(unrestricted.placements) do
  if row.kind == "pc" then sawPcCheck = true end
end
assert(sawPcCheck, "starting PC storage participates in unrestricted MIXED mode")

local shuffled = Category.generate(sources, {
  non_key_items = "off", tms = "off", hms = "off", key_items = "off",
  badges = "shuffled", ensure_beatable = "on", shops = "off",
}, rng)
assert(#shuffled.placements == 8 and #shuffled.warnings == 0,
  "beatable shuffled mode keeps all badges among the eight Gym rewards")
for _, row in ipairs(shuffled.placements) do
  assert(row.kind == "scripted" and row.badge == true,
    "shuffled badges must remain Gym rewards")
end

io.write("badge_randomizer_test: ok\n")
