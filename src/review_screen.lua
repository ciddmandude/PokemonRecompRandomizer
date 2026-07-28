-- Scrollable text review used for next-run settings and clipboard fallback.
return function()
  local Review = {}
  Review.__index = Review
  Review.isOpaque = true

  local VISIBLE = 12

  local function wrap(text)
    local output = {}
    for source in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
      if source == "" then
        output[#output + 1] = ""
      else
        local current = ""
        for word in source:gmatch("%S+") do
          if #word > 18 then
            if current ~= "" then
              output[#output + 1], current = current, ""
            end
            local first = 1
            while first <= #word do
              output[#output + 1] = word:sub(first, first + 17)
              first = first + 18
            end
          elseif current == "" then
            current = word
          elseif #current + #word + 1 <= 18 then
            current = current .. " " .. word
          else
            output[#output + 1], current = current, word
          end
        end
        if current ~= "" then output[#output + 1] = current end
      end
    end
    return output
  end

  function Review.new(game, model, ui)
    model = type(model) == "table" and model or {}
    local lines = {}
    for _, line in ipairs(model.lines or {}) do
      local wrapped = wrap(line)
      for _, part in ipairs(wrapped) do lines[#lines + 1] = part end
    end
    if #lines == 0 then lines[1] = "NOTHING TO SHOW" end
    return setmetatable({
      game = game,
      ui = ui,
      title = tostring(model.title or "RANDOMIZER"),
      lines = lines,
      scroll = 0,
    }, Review)
  end

  function Review:update()
    local input = self.game.input
    if input:wasPressed("b") or input:wasPressed("a") then
      self.game.stack:pop()
    elseif input:wasPressed("up") then
      self.scroll = math.max(0, self.scroll - 1)
    elseif input:wasPressed("down") then
      self.scroll = math.min(
        math.max(0, #self.lines - VISIBLE), self.scroll + 1)
    elseif input:wasPressed("left") then
      self.scroll = math.max(0, self.scroll - VISIBLE)
    elseif input:wasPressed("right") then
      self.scroll = math.min(
        math.max(0, #self.lines - VISIBLE), self.scroll + VISIBLE)
    end
  end

  function Review:draw()
    local Font, Theme = self.ui.Font, self.ui.Theme
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    Font.drawBox(0, 0, 20, 18)
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(self.title:sub(1, 18), 8, 8)
    for slot = 1, VISIBLE do
      local line = self.lines[self.scroll + slot]
      if line then Font.draw(line, 8, 16 + slot * 8) end
    end
    if self.scroll > 0 then Font.drawCode(Theme.moreArrow, 144, 8) end
    if self.scroll + VISIBLE < #self.lines then
      Font.drawCode(Theme.moreArrow, 144, 120)
    end
    Font.draw("A/B:BACK", 8, 128)
    love.graphics.setColor(1, 1, 1, 1)
  end

  Review.wrap = wrap
  Review.visibleLines = VISIBLE
  return Review
end
