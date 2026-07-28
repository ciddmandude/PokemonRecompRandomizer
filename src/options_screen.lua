-- Paged custom Randomizer screen registered through content.screens.
return function(Constants)
  local Screen = {}
  Screen.__index = Screen
  Screen.isOpaque = true

  local function wrapHelp(text)
    local lines, current = {}, ""
    for word in tostring(text or ""):gmatch("%S+") do
      if current == "" then
        current = word
      elseif #current + #word + 1 <= 18 then
        current = current .. " " .. word
      else
        lines[#lines + 1] = current
        current = word
      end
    end
    if current ~= "" then lines[#lines + 1] = current end
    return { lines[1] or "", lines[2] or "" }
  end

  local function pressed(input, action)
    return input and input.wasPressed and input:wasPressed(action)
  end

  function Screen.new(game, preferences, ui, saveStatus, actions)
    local self = setmetatable({
      game = game,
      preferences = preferences,
      ui = ui,
      saveStatus = saveStatus,
      actions = actions or {},
      pages = preferences:pages(),
      page = 1,
      row = 1,
      notice = nil,
      resetPrompt = false,
    }, Screen)
    return self
  end

  function Screen:currentPage()
    return self.pages[self.page]
  end

  function Screen:currentRow()
    return self:currentPage().rows[self.row]
  end

  function Screen:move(direction)
    local page = self:currentPage()
    self.row = self.row + direction
    if self.row < 1 then
      self.page = self.page > 1 and self.page - 1 or #self.pages
      self.row = #self:currentPage().rows
    elseif self.row > #page.rows then
      self.page = self.page < #self.pages and self.page + 1 or 1
      self.row = 1
    end
    self.notice = nil
  end

  function Screen:changePage(direction)
    self.page = ((self.page - 1 + direction) % #self.pages) + 1
    self.row = math.min(self.row, #self:currentPage().rows)
    self.notice = nil
  end

  function Screen:confirmReset()
    if self.resetPrompt then return end
    self.resetPrompt = true
    local box = self.ui.ChoiceBox.new(self.game, function(confirmed)
      self.resetPrompt = false
      if confirmed then
        self.preferences:reset(self.game)
        self.notice = "DEFAULTS RESTORED"
        self.page, self.row = 1, 1
      else
        self.notice = "RESET CANCELLED"
      end
    end, { defaultNo = true })
    self.game.stack:push(box)
  end

  function Screen:edit(row)
    if row.kind == "action" and row.key == "reset_defaults" then
      self:confirmReset()
    elseif row.kind == "action" then
      local action = self.actions[row.key]
      if action then
        local notice = action(self.game)
        if type(notice) == "string" then self.notice = notice end
      end
    elseif row.type == "choice" then
      self.preferences:step(row, 1, self.game)
    elseif row.type == "number" then
      local box = self.ui.QuantityBox.new(self.game, {
        max = row.max,
        start = self.preferences:get(row.key, self.game),
        onDone = function(value)
          if value then
            value = math.max(row.min, math.min(row.max, value))
            self.preferences:set(row.key, value, self.game)
          end
        end,
      })
      self.game.stack:push(box)
    elseif row.type == "text" then
      local editor = self.ui.NamingScreen.new(self.game, {
        title = row.label .. "?",
        maxLen = row.maxLen,
        default = self.preferences:get(row.key, self.game),
        onDone = function(value)
          if value ~= nil then
            self.preferences:set(row.key, value, self.game)
          end
        end,
      })
      self.game.stack:push(editor)
    end
  end

  function Screen:update()
    local input = self.game.input
    if pressed(input, "up") then
      self:move(-1)
    elseif pressed(input, "down") then
      self:move(1)
    elseif pressed(input, "select") then
      self:changePage(1)
    elseif pressed(input, "left") or pressed(input, "right") then
      local row = self:currentRow()
      if row.type == "choice" or row.type == "number" then
        self.preferences:step(
          row, pressed(input, "left") and -1 or 1, self.game)
      end
    elseif pressed(input, "a") then
      self:edit(self:currentRow())
    elseif pressed(input, "start") then
      self:confirmReset()
    elseif pressed(input, "b") then
      self.game.stack:pop()
    end
  end

  function Screen:runLabel()
    local status = self.saveStatus and self.saveStatus() or {}
    if status.active then
      local run = status.run
      local raceLocked = run and run.race and run.race.enabled
        and not run.race.unlocked
      local identity = raceLocked
          and run.seed and run.seed.hash128
        or run and run.seed and run.seed.canonical
        or "RUN"
      return "LOCKED:" .. identity:sub(1, 8)
    end
    if status.phase == "quarantined" then return "ACTIVE:DISABLED" end
    if status.phase == "created-vanilla"
        or status.phase == "loaded-vanilla" then
      return "ACTIVE:VANILLA"
    end
    return "ACTIVE:NONE"
  end

  function Screen:draw()
    local Font, Theme = self.ui.Font, self.ui.Theme
    local page = self:currentPage()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    Font.drawBox(0, 0, 20, 5)
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(("%s %d/%d"):format(
      page.name, self.page, #self.pages), 8, 8)
    Font.draw(self:runLabel(), 8, 16)
    Font.draw("NEXT NEW GAME", 8, 24)

    for index, row in ipairs(page.rows) do
      local y = 40 + (index - 1) * 16
      Font.draw(row.label, 16, y)
      local value = row.kind == "action" and "A:OPEN"
        or self.preferences:display(row, self.game)
      Font.draw(value, 24, y + 8)
      if index == self.row then Font.drawCode(Theme.cursor, 8, y) end
    end

    love.graphics.setColor(1, 1, 1, 1)
    Font.drawBox(0, 13, 20, 5)
    love.graphics.setColor(0, 0, 0, 1)
    local help = self.resetPrompt and "RESET ALL NEXT-RUN OPTIONS?"
      or self.notice or self:currentRow().help
    local lines = wrapHelp(help)
    Font.draw(lines[1], 8, 112)
    Font.draw(lines[2], 8, 120)
    Font.draw("SEL:PAGE ST:RESET", 8, 128)
    love.graphics.setColor(1, 1, 1, 1)
  end

  return Screen
end
