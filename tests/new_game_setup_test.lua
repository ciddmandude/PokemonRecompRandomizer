local function loadFactory(path, ...)
  local value = assert(loadfile(path))()
  return type(value) == "function" and value(...) or value
end

local Setup = loadFactory("src/new_game_setup.lua")

local function fixture()
  local pushed, pops = {}, 0
  local questions, picker = {}, nil
  local setCalls = {}
  local completed, settingsDone
  local game = {
    save = {},
    stack = {
      push = function(_, value) pushed[#pushed + 1] = value end,
      pop = function() pops = pops + 1 end,
    },
  }
  local ui = {
    TextBox = {
      new = function(_, text, _, options)
        local row = { kind = "question", text = text, options = options }
        questions[#questions + 1] = row
        return row
      end,
    },
    ListMenu = {
      new = function(_, title, items, options)
        picker = { title = title, items = items, options = options }
        return picker
      end,
    },
  }
  local preferences = {
    presetChoices = function()
      return {
        { "CUSTOM", "custom" },
        { "CASUAL", "casual" },
        { "STANDARD", "standard" },
        { "CHAOS", "chaos" },
        { "FOREST RUN", "saved:FOREST RUN" },
      }
    end,
    set = function(_, key, value)
      setCalls[#setCalls + 1] = { key = key, value = value }
      return value
    end,
  }
  Setup.start({
    game = game,
    ui = ui,
    preferences = preferences,
    complete = function(enabled) completed = enabled end,
    openSettings = function(onDone) settingsDone = onDone end,
  })
  return {
    game = game,
    questions = questions,
    pushed = pushed,
    pops = function() return pops end,
    picker = function() return picker end,
    setCalls = setCalls,
    completed = function() return completed end,
    settingsDone = function() return settingsDone end,
  }
end

local disabled = fixture()
assert(disabled.questions[1].text == "TURN ON THE\nRANDOMIZER?"
    and disabled.questions[1].options.defaultNo == true,
  "New Game asks whether to enable the randomizer and defaults safely to No")
disabled.questions[1].options.choice(false)
assert(disabled.completed() == false,
  "declining the randomizer completes setup as vanilla")

local preset = fixture()
preset.questions[1].options.choice(true)
assert(preset.questions[2].text == "USE A SETTINGS\nPRESET?",
  "enabled setup asks whether to use a preset")
preset.questions[2].options.choice(true)
local picker = preset.picker()
assert(picker.title == "RANDOMIZER PRESET" and #picker.items == 4
    and picker.items[1].value == "casual"
    and picker.items[4].value == "saved:FOREST RUN",
  "preset picker includes built-ins and named presets but excludes Custom")
picker.options.onChoose(picker.items[4])
assert(preset.pops() == 1
    and preset.setCalls[1].value == "saved:FOREST RUN"
    and preset.completed() == true,
  "selecting a preset loads it and completes randomized setup")

local custom = fixture()
custom.questions[1].options.choice(true)
custom.questions[2].options.choice(false)
assert(custom.setCalls[1].key == "preset"
    and custom.setCalls[1].value == "custom"
    and type(custom.settingsDone()) == "function"
    and custom.completed() == nil,
  "declining presets opens custom settings without completing early")
custom.settingsDone()()
assert(custom.completed() == true,
  "finishing custom settings completes randomized setup")

local cancelled = fixture()
cancelled.questions[1].options.choice(true)
cancelled.questions[2].options.choice(true)
cancelled.picker().options.onCancel()
assert(#cancelled.questions == 3
    and cancelled.questions[3].text == "USE A SETTINGS\nPRESET?",
  "backing out of the picker returns to the preset question")

io.write("new_game_setup_test: ok\n")
