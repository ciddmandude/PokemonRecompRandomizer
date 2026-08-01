-- Mandatory New Game chooser shown before Oak's first intro line.
return function()
  local Setup = {}

  local function pushQuestion(ui, game, text, defaultNo, callback)
    game.stack:push(ui.TextBox.new(game, text, nil, {
      defaultNo = defaultNo,
      choice = callback,
    }))
  end

  function Setup.start(context)
    assert(type(context) == "table", "New Game setup context is required")
    local game = assert(context.game, "New Game setup game is required")
    local ui = assert(context.ui, "New Game setup UI is required")
    local preferences = assert(context.preferences,
      "New Game setup preferences are required")
    assert(type(context.complete) == "function",
      "New Game setup completion callback is required")
    assert(type(context.openSettings) == "function",
      "New Game settings opener is required")

    local finished = false
    local function complete(enabled)
      if finished then return end
      finished = true
      context.complete(enabled == true)
    end

    local askPreset
    local function openPresetPicker()
      local items = {}
      for _, choice in ipairs(preferences:presetChoices(game)) do
        if choice[2] ~= "custom" then
          items[#items + 1] = { label = choice[1], value = choice[2] }
        end
      end
      local picker = ui.ListMenu.new(game, "RANDOMIZER PRESET", items, {
        onChoose = function(item)
          game.stack:pop()
          local selected = item and preferences:set(
            "preset", item.value, game)
          if selected then complete(true) else askPreset() end
        end,
        onCancel = function() askPreset() end,
      })
      game.stack:push(picker)
    end

    local function openCustomSettings()
      preferences:set("preset", "custom", game)
      context.openSettings(function() complete(true) end)
    end

    askPreset = function()
      pushQuestion(ui, game, "USE A SETTINGS\nPRESET?", false,
        function(usePreset)
          if usePreset then openPresetPicker() else openCustomSettings() end
        end)
    end

    pushQuestion(ui, game, "TURN ON THE\nRANDOMIZER?", true,
      function(enabled)
        if enabled then askPreset() else complete(false) end
      end)
  end

  return Setup
end
