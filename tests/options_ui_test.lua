-- Standalone Milestone-5 preference and paged-screen behavior tests.
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

local Constants = loadFactory("src/constants.lua")
local Seed = loadFactory("src/seed.lua")
local Schema = loadFactory("src/options_schema.lua")
local General = loadFactory("src/general_settings.lua", {})
local Preferences = loadFactory(
  "src/preferences.lua", Constants, Schema, General, Seed)
local Screen = loadFactory("src/options_screen.lua", Constants)
local Review = loadFactory("src/review_screen.lua")

local stored = {}
local defined
local mod = {
  options = {
    define = function(_, rows) defined = rows return rows end,
    get = function(_, key) return stored[key] end,
  },
}
local preferences = Preferences.new(mod)
preferences:define()
equal(#defined, 57, "complete preference row count")
equal(#preferences:pages(), 19, "paged schema count")
for _, page in ipairs(preferences:pages()) do
  assert(#page.rows >= 1 and #page.rows <= 4, "page row limit")
  for _, row in ipairs(page.rows) do
    local lines, current = 0, ""
    for word in row.help:gmatch("%S+") do
      if current == "" then
        current = word
      elseif #current + #word + 1 <= 18 then
        current = current .. " " .. word
      else
        lines, current = lines + 1, word
      end
    end
    if current ~= "" then lines = lines + 1 end
    assert(lines <= 2, "help must fit two lines: " .. row.key)
  end
end

local writes = 0
local game = {
  save = { options = { modOptions = {} } },
  mods = { modOptions = {} },
  writeOptions = function() writes = writes + 1 end,
}

local defaults = preferences:snapshot()
assert(defaults.randomizer == nil,
  "the enable choice belongs to the New Game intro")
equal(defaults.preset, "standard", "preset default")
equal(defaults.seed_text, "", "seed text default")
equal(defaults.game_corner_pokemon, "randomized", "prize default")
equal(defaults.generate_spoiler_log, "on", "spoiler access default")
equal(defaults.rival_pokemon, "include", "rival mode default")
equal(defaults.rival_keep_pokemon, "yes", "rival continuity default")
equal(defaults.non_key_items, "vanilla", "ordinary item default")
equal(defaults.tms, "vanilla", "TM default")
equal(defaults.hms, "vanilla", "HM default")
equal(defaults.key_items, "vanilla", "key-item default")
equal(defaults.badges, "vanilla", "badge default")
equal(defaults.hidden_items, "vanilla", "hidden-item default")
equal(defaults.ensure_beatable, "on", "beatability default")
equal(defaults.shops, "vanilla", "shop default")
equal(defaults.shop_prices, "vanilla", "shop-price default")
local strengthRow, nonKeyRow, tmLocationRow, hmLocationRow, hiddenItemsRow
local starterStageRow, evolutionsRow
for _, row in ipairs(defined) do
  if row.key == "similar_strength" then strengthRow = row end
  if row.key == "starter_stage" then starterStageRow = row end
  if row.key == "evolutions" then evolutionsRow = row end
end
assert(strengthRow and strengthRow.choices[4][2] == "bst_50"
    and strengthRow.choices[5][2] == "bst_100"
    and strengthRow.choices[6][2] == "same_stage",
  "similar strength exposes BST ranges and SAME STAGE")
for _, row in ipairs({ strengthRow, starterStageRow, evolutionsRow }) do
  assert(row and row.help:find("ORIGINAL", 1, true),
    "stage-sensitive help must identify original lineage")
end

local function readFile(path)
  local file = assert(io.open(path, "rb"))
  local contents = file:read("*a")
  file:close()
  return contents
end

for _, path in ipairs({
  "README.md", "docs/randomizer-spec.md", "docs/manual-test-plan.txt",
}) do
  local contents = readFile(path):lower()
  assert(contents:find("original merged%-data lineage"),
    path .. " must define original merged-data lineage")
end
for _, row in ipairs(defined) do
  if row.key == "tms" then tmLocationRow = row end
  if row.key == "non_key_items" then nonKeyRow = row end
  if row.key == "hms" then hmLocationRow = row end
  if row.key == "hidden_items" then hiddenItemsRow = row end
end
equal(tmLocationRow and tmLocationRow.label, "TM LOCATION", "TM display label")
equal(nonKeyRow and nonKeyRow.choices[3][2], "mixed",
  "non-key items expose mixed locations")
equal(hmLocationRow and hmLocationRow.label, "HM LOCATION", "HM display label")
equal(hiddenItemsRow and hiddenItemsRow.label, "HIDDEN ITEMS",
  "hidden item display label")
equal(hiddenItemsRow and hiddenItemsRow.choices[3][2], "mixed",
  "hidden items expose mixed locations")

local legacyGame = { save = { options = { modOptions = {
  pokemon_randomizer = {
    non_key_items = "on", tms = "off", hms = "safe",
    key_items = "full_random", badges = "random", shops = "on",
    ensure_beatable = "off",
  },
} } } }
equal(preferences:get("non_key_items", legacyGame), "shuffled",
  "legacy ordinary-item value migrates")
equal(preferences:get("hms", legacyGame), "shuffled",
  "legacy safe HM value migrates")
equal(preferences:get("key_items", legacyGame), "shuffled",
  "legacy full-random key value migrates")
equal(preferences:get("badges", legacyGame), "mixed",
  "legacy random badge value migrates")
equal(preferences:get("shops", legacyGame), "randomized",
  "legacy shop value migrates")
equal(preferences:get("ensure_beatable", legacyGame), "on",
  "legacy safe mode enables progression safety")

assert(preferences:set("seed_mode", "manual", game))
equal(writes, 1, "single preference persistence")
equal(game.save.options.modOptions.pokemon_randomizer.seed_mode,
  "manual", "options.lua namespace write")
equal(game.mods.modOptions.pokemon_randomizer.seed_mode,
  "manual", "loader preference mirror")
equal(preferences:get("seed_mode", game), "manual", "live preference read")

local ok = preferences:set("starter_level", 99, game)
assert(not ok, "invalid preference rejected")
equal(writes, 1, "invalid preference not written")

local seedModeRow
for _, row in ipairs(defined) do
  if row.key == "seed_mode" then seedModeRow = row end
end
preferences:step(seedModeRow, 1, game)
equal(preferences:get("seed_mode", game), "auto", "choice wraps forward")
preferences:step(seedModeRow, -1, game)
equal(preferences:get("seed_mode", game), "manual", "choice wraps backward")

preferences:set("seed_text", "CUSTOM", game)
local beforeReset = writes
local reset = preferences:reset(game)
equal(writes, beforeReset + 1, "reset writes once")
equal(reset.seed_text, "", "reset clears manual seed")
equal(reset.preset, "standard", "reset restores standard")

preferences:set("seed_mode", "manual", game)
preferences:set("seed_text", "SAVED SEED", game)
preferences:set("generate_spoiler_log", "off", game)
preferences:set("wild_pokemon", "area_slots", game)
local savedPreset = assert(preferences:savePreset("my run", game, false))
equal(savedPreset, "saved:MY RUN", "saved preset token")
equal(preferences:get("preset", game), savedPreset,
  "saving marks current named preset")
equal(preferences:display({ key = "preset", type = "choice" }, game),
  "MY RUN", "saved preset display name")
equal(#preferences:savedPresets(game), 1, "saved preset persisted")
local duplicate, duplicateError = preferences:savePreset("MY RUN", game, false)
assert(not duplicate and duplicateError == "preset exists",
  "duplicate preset requires overwrite")

preferences:set("seed_text", "OTHER SEED", game)
equal(preferences:get("preset", game), "custom",
  "saved seed edit changes marker to custom")
preferences:set("preset", savedPreset, game)
equal(preferences:get("seed_mode", game), "manual",
  "loading saved preset restores seed mode")
equal(preferences:get("seed_text", game), "SAVED SEED",
  "loading saved preset restores seed text")
equal(preferences:get("generate_spoiler_log", game), "off",
  "loading saved preset restores spoiler option")
equal(preferences:get("wild_pokemon", game), "area_slots",
  "loading saved preset restores category option")
local presetPages = preferences:pages(game)
local foundSavedChoice = false
for _, page in ipairs(presetPages) do
  for _, row in ipairs(page.rows) do
    if row.key == "preset" then
      for _, choice in ipairs(row.choices) do
        if choice[1] == "MY RUN" and choice[2] == savedPreset then
          foundSavedChoice = true
        end
      end
    end
  end
end
assert(foundSavedChoice, "saved preset appears in existing preset list")
assert(preferences:deletePreset(savedPreset, game) == "MY RUN")
equal(#preferences:savedPresets(game), 0, "saved preset deleted")
equal(preferences:get("preset", game), "custom",
  "deleting active preset redetects current settings")
preferences:reset(game)

local beforePreset = writes
preferences:set("preset", "chaos", game)
equal(writes, beforePreset + 1, "preset applies in one write")
equal(preferences:get("preset", game), "chaos", "chaos selected")
equal(preferences:get("species_pool", game), "merged", "chaos pool")
equal(preferences:get("progression_guard", game), "off", "chaos guard")
preferences:set("wild_pokemon", "global_map", game)
equal(preferences:get("preset", game), "custom", "bundle edit is custom")
preferences:set("wild_pokemon", "area_slots", game)
equal(preferences:get("preset", game), "chaos", "matching bundle detected")
preferences:set("generate_spoiler_log", "off", game)
preferences:set("preset", "casual", game)
equal(preferences:get("generate_spoiler_log", game), "on",
  "casual enables spoilers")
preferences:set("generate_spoiler_log", "off", game)
preferences:set("preset", "chaos", game)
equal(preferences:get("generate_spoiler_log", game), "on",
  "chaos enables spoilers")
preferences:set("generate_spoiler_log", "off", game)
preferences:set("preset", "standard", game)
equal(preferences:get("generate_spoiler_log", game), "on",
  "standard enables spoilers")
preferences:reset(game)

local pressed = {}
game.input = {
  wasPressed = function(_, action) return pressed[action] == true end,
}
game.stack = {
  pushed = {},
  pops = 0,
  push = function(self, value) self.pushed[#self.pushed + 1] = value end,
  pop = function(self) self.pops = self.pops + 1 end,
}

local choiceCallback
local namingOptions
local quantityOptions
local listMenu
local ui = {
  ChoiceBox = {
    new = function(_, callback)
      choiceCallback = callback
      return { kind = "choice" }
    end,
  },
  NamingScreen = {
    new = function(_, options)
      namingOptions = options
      return { kind = "naming" }
    end,
  },
  QuantityBox = {
    new = function(_, options)
      quantityOptions = options
      return { kind = "quantity" }
    end,
  },
  ListMenu = {
    new = function(_, title, items, options)
      listMenu = {
        kind = "list", title = title, items = items,
        onChoose = options.onChoose,
      }
      return listMenu
    end,
  },
}

local screen = Screen.new(game, preferences, ui, function()
  return { active = false, phase = "idle" }
end)
equal(screen:currentPage().name, "GENERAL", "first page")
equal(screen:runLabel(), "ACTIVE:NONE", "no-run label")

pressed.right = true
screen:update()
pressed = {}
equal(preferences:get("preset", game), "chaos", "right steps value")
preferences:reset(game)

for _ = 1, 4 do
  pressed.down = true
  screen:update()
  pressed = {}
end
equal(screen.page, 2, "down crosses page")
equal(screen.row, 1, "cross-page cursor")

pressed.select = true
screen:update()
pressed = {}
equal(screen.page, 3, "select advances page")

screen.page, screen.row = 1, 3
screen:edit(screen:currentRow())
assert(namingOptions and namingOptions.maxLen == 32)
namingOptions.onDone("  my   seed  ")
equal(preferences:get("seed_text", game), "MY SEED",
  "text editor normalizes valid seed")
namingOptions.onDone("race_seed-01")
equal(preferences:get("seed_text", game), "RACE_SEED-01",
  "text editor uppercases valid seed")
namingOptions.onDone("MEW!")
equal(preferences:get("seed_text", game), "RACE_SEED-01",
  "text editor rejects invalid seed")
equal(screen.notice, "INVALID SEED", "invalid seed notice")
namingOptions.onDone("   ")
equal(preferences:get("seed_text", game), "",
  "whitespace-only seed clears field")
game.save.options.modOptions.pokemon_randomizer.seed_text = "OLD?"
equal(preferences:get("seed_text", game), "",
  "invalid legacy seed reads as blank")

screen:savePreset()
assert(namingOptions and namingOptions.maxLen == 16,
  "saved preset name editor uses readable limit")
namingOptions.onDone("forest run")
equal(preferences:get("preset", game), "saved:FOREST RUN",
  "save action activates named preset")
screen:deletePreset()
assert(listMenu and listMenu.title == "DELETE PRESET"
    and #listMenu.items == 1,
  "delete action opens saved preset selector")
listMenu.onChoose(listMenu.items[1])
assert(screen.presetPrompt, "delete action requests confirmation")
choiceCallback(true)
equal(#preferences:savedPresets(game), 0,
  "confirmed delete action removes preset")
equal(screen.notice, "PRESET DELETED", "delete confirmation notice")
game.stack.pops = 0

screen.page, screen.row = 4, 3
screen:edit(screen:currentRow())
assert(quantityOptions and quantityOptions.max == 20)
quantityOptions.onDone(1)
equal(preferences:get("starter_level", game), 2, "number editor clamps")

pressed.start = true
screen:update()
pressed = {}
assert(screen.resetPrompt)
equal(game.stack.pushed[#game.stack.pushed].kind,
  "choice", "reset confirmation pushed")
choiceCallback(true)
assert(not screen.resetPrompt)
equal(preferences:get("seed_text", game), "", "confirmed reset")
equal(screen.notice, "DEFAULTS RESTORED", "reset notice")

pressed.b = true
screen:update()
pressed = {}
equal(game.stack.pops, 1, "B returns")

local onboardingDone = false
local onboarding = Screen.new(game, preferences, ui, function()
  return { active = false, phase = "idle" }
end, nil, {
  onboarding = true,
  onDone = function() onboardingDone = true end,
})
equal(onboarding:runLabel(), "NEW GAME SETUP", "onboarding header")
local onboardingKeys = {}
for _, page in ipairs(onboarding.pages) do
  for _, row in ipairs(page.rows) do onboardingKeys[row.key] = true end
end
assert(not onboardingKeys.preset
    and not onboardingKeys.copy_active_seed
    and not onboardingKeys.view_spoiler_log
    and not onboardingKeys.export_spoiler_log,
  "custom New Game settings hide preset loading and active-run actions")
assert(onboardingKeys.save_preset and onboardingKeys.delete_preset
    and onboardingKeys.reset_defaults,
  "custom New Game settings retain preset management and reset")
pressed.b = true
onboarding:update()
pressed = {}
assert(onboarding.finishPrompt and not onboardingDone,
  "B asks before starting with custom settings")
choiceCallback(false)
assert(not onboarding.finishPrompt and not onboardingDone
    and onboarding.notice == "KEEP EDITING",
  "declining confirmation returns to settings")
pressed.b = true
onboarding:update()
pressed = {}
choiceCallback(true)
assert(onboardingDone and game.stack.pops == 2,
  "confirming custom settings returns to Oak and starts the run")

local locked = Screen.new(game, preferences, ui, function()
  return {
    active = true,
    phase = "loaded",
    run = { seed = { canonical = "LOCKED-SEED" } },
  }
end)
equal(locked:runLabel(), "LOCKED:LOCKED-S", "locked-run label")
local oldRaceSave = Screen.new(game, preferences, ui, function()
  return {
    active = true,
    run = {
      seed = { canonical = "SECRET", hash128 = "HASHED-SEED" },
      race = { enabled = true, unlocked = false },
    },
  }
end)
equal(oldRaceSave:runLabel(), "LOCKED:SECRET",
  "legacy race metadata no longer hides the active seed")

local drawn, rectangles = {}, {}
ui.Font = {
  drawBox = function(...) drawn[#drawn + 1] = { "box", ... } end,
  draw = function(text, x, y)
    drawn[#drawn + 1] = { "text", text, x, y }
  end,
  drawCode = function(code, x, y)
    drawn[#drawn + 1] = { "code", code, x, y }
  end,
}
ui.Theme = { cursor = 0xED }
love = {
  graphics = {
    setColor = function() end,
    rectangle = function(mode, x, y, width, height)
      rectangles[#rectangles + 1] = { mode, x, y, width, height }
    end,
  },
}
locked:draw()
equal(rectangles[1][1], "fill", "screen background fill")
equal(rectangles[1][4], 160, "screen background width")
equal(rectangles[1][5], 144, "screen background height")
assert(#drawn > 8, "screen draws header, rows, help, and controls")

local wrapped = Review.wrap(
  "R1-01234567-AABBCCDD-99887766")
assert(#wrapped >= 2, "long run code wraps for transcription")
local reviewLines = {}
for index = 1, 20 do reviewLines[index] = "LINE " .. index end
local review = Review.new(game, {
  title = "NEXT RUN",
  lines = reviewLines,
}, ui)
pressed.down = true
review:update()
pressed = {}
equal(review.scroll, 1, "review scrolls down")
pressed.right = true
review:update()
pressed = {}
assert(review.scroll > 1, "review page-scrolls")
review:draw()

io.write("options_ui_test: ok\n")
