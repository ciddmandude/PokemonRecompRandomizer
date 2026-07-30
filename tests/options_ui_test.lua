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
equal(#defined, 35, "complete preference row count")
equal(#preferences:pages(), 13, "paged schema count")
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
equal(defaults.randomizer, "on", "randomizer default")
equal(defaults.preset, "standard", "preset default")
equal(defaults.seed_text, "", "seed text default")
equal(defaults.game_corner_pokemon, "randomized", "prize default")
equal(defaults.generate_spoiler_log, "on", "spoiler access default")
equal(defaults.rival_pokemon, "include", "rival mode default")
equal(defaults.rival_keep_pokemon, "yes", "rival continuity default")
local strengthRow
for _, row in ipairs(defined) do
  if row.key == "similar_strength" then strengthRow = row break end
end
assert(strengthRow and strengthRow.choices[4][2] == "same_stage",
  "similar strength exposes SAME STAGE")

assert(preferences:set("randomizer", "off", game))
equal(writes, 1, "single preference persistence")
equal(game.save.options.modOptions.pokemon_randomizer.randomizer,
  "off", "options.lua namespace write")
equal(game.mods.modOptions.pokemon_randomizer.randomizer,
  "off", "loader preference mirror")
equal(preferences:get("randomizer", game), "off", "live preference read")

local ok = preferences:set("starter_level", 99, game)
assert(not ok, "invalid preference rejected")
equal(writes, 1, "invalid preference not written")

local randomizerRow = defined[1]
preferences:step(randomizerRow, 1, game)
equal(preferences:get("randomizer", game), "on", "choice wraps forward")
preferences:step(randomizerRow, -1, game)
equal(preferences:get("randomizer", game), "off", "choice wraps backward")

preferences:set("seed_text", "CUSTOM", game)
local beforeReset = writes
local reset = preferences:reset(game)
equal(writes, beforeReset + 1, "reset writes once")
equal(reset.randomizer, "on", "reset randomizer")
equal(reset.seed_text, "", "reset clears manual seed")
equal(reset.preset, "standard", "reset restores standard")

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
}

local screen = Screen.new(game, preferences, ui, function()
  return { active = false, phase = "idle" }
end)
equal(screen:currentPage().name, "GENERAL", "first page")
equal(screen:runLabel(), "ACTIVE:NONE", "no-run label")

pressed.right = true
screen:update()
pressed = {}
equal(preferences:get("randomizer", game), "off", "right steps value")

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

screen.page, screen.row = 1, 4
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

screen.page, screen.row = 5, 3
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
