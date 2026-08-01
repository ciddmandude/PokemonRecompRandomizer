-- Interactive Pokémon/map spoiler browser for the 160x144 game screen.
return function(Constants, Browser)
  local Screen = {}
  Screen.__index = Screen
  Screen.isOpaque = true

  local LIST_ROWS = 7
  local SPACED_ROWS = 4
  local DETAIL_ROWS = 12
  local SEARCH_FOOTER = "SEARCH:SELECT"
  local backgroundCache = {}
  local backgroundStats = {
    imageBuilds = 0,
    quadBuilds = 0,
    hits = 0,
    failures = 0,
  }

  local function copyArray(source)
    local output = {}
    for index, value in ipairs(source or {}) do output[index] = value end
    return output
  end

  -- Town-map coordinates occupy a 16x16 grid beginning two tiles from the
  -- left and one tile below the screen origin.
  local function markerXY(area)
    return area.x * 8 + 16, area.y * 8 + 8
  end

  local function cursorColors(blink)
    if (tonumber(blink) or 0) % 16 < 8 then
      return { 0, 0, 0, 1 }, { 1, 1, 1, 1 }
    end
    return { 1, 1, 1, 1 }, { 0, 0, 0, 1 }
  end

  local function cursorFrames(x, y)
    return {
      { x = x + 0.5, y = y + 0.5, width = 7, height = 7 },
      { x = x + 1.5, y = y + 1.5, width = 5, height = 5 },
    }
  end

  local function listLayout(spaced)
    if spaced then
      return {
        rows = SPACED_ROWS,
        firstY = 24,
        stride = 24,
        secondaryOffset = 10,
      }
    end
    return {
      rows = LIST_ROWS,
      firstY = 30,
      stride = 14,
      secondaryOffset = 7,
    }
  end

  local function spacedMode(mode)
    return mode == "locations"
      or mode == "item_locations"
      or mode == "location_entries"
      or mode == "tabs"
  end

  local function availableTabs(index, map)
    local result = {}
    for _, tab in ipairs(index.tabs or {}) do
      local rows = map and map.tabs and map.tabs[tab]
      if type(rows) == "table" and #rows > 0 then
        result[#result + 1] = tab
      end
    end
    return result
  end

  local function isEncounterTab(tab)
    return tab == "grass" or tab == "surf"
      or tab == "old_rod" or tab == "good_rod" or tab == "super_rod"
  end

  local function isInlineTab(tab)
    return isEncounterTab(tab) or tab == "trades"
      or tab == "starters" or tab == "gifts" or tab == "items"
  end

  local function pressed(input, action)
    return input and type(input.wasPressed) == "function"
      and input:wasPressed(action)
  end

  local function clip(text, length)
    text = tostring(text or "")
    return #text > length and text:sub(1, length) or text
  end

  local LOCATION_ABBREVIATIONS = {
    POKEMON = "PKMN",
    UNDERGROUND = "UG",
    DEPARTMENT = "Dept.",
    BUILDING = "Bldg.",
    MANSION = "Mans.",
    CENTER = "Ctr.",
    HOUSE = "Hse.",
    ENTRANCE = "Ent.",
    FOREST = "Frst.",
    TUNNEL = "Tun.",
    ISLAND = "Isl.",
    PLATEAU = "Plat.",
    LABORATORY = "Lab",
    COMPANY = "Co.",
    ROAD = "Rd.",
    FLOOR = "Fl.",
    PRIZE = "Pr.",
    ROOM = "Rm.",
    FISHABLE = "Fish.",
  }

  local function locationLength(words)
    local length = math.max(0, #words - 1)
    for _, word in ipairs(words) do length = length + #word end
    return length
  end

  local function abbreviateLocation(text)
    text = tostring(text or "")
    if #text <= 16 then return text end
    local words = {}
    for word in text:gmatch("%S+") do
      words[#words + 1] = LOCATION_ABBREVIATIONS[word:upper()] or word
    end
    while locationLength(words) > 16 do
      local best, bestLength
      for index, word in ipairs(words) do
        local plain = word:gsub("%.$", "")
        if #plain > 4 and (not bestLength or #plain > bestLength) then
          best, bestLength = index, #plain
        end
      end
      if not best then break end
      words[best] = words[best]:sub(1, 3) .. "."
    end
    if locationLength(words) > 16 then
      for index, word in ipairs(words) do
        local plain = word:gsub("%.$", "")
        words[index] = #plain > 3 and plain:sub(1, 3) or plain
      end
    end
    while locationLength(words) > 16 do
      local best, bestLength
      for index, word in ipairs(words) do
        if #word > 1 and (not bestLength or #word > bestLength) then
          best, bestLength = index, #word
        end
      end
      if not best then break end
      words[best] = words[best]:sub(1, #words[best] - 1)
    end
    return table.concat(words, " ")
  end

  local function percent(value)
    local rounded = math.floor((tonumber(value) or 0) * 10 + 0.5) / 10
    if rounded == math.floor(rounded) then return tostring(math.floor(rounded)) end
    return ("%.1f"):format(rounded)
  end

  local function levelText(row)
    if row.minLevel then
      if row.minLevel == row.maxLevel then return "LV." .. tostring(row.minLevel) end
      return ("LV.%s-%s"):format(row.minLevel, row.maxLevel)
    end
    return row.level and ("LV." .. tostring(row.level)) or ""
  end

  local EVOLUTION_ITEM_ABBREVIATIONS = {
    FIRE_STONE = "FIRE ST.",
    LEAF_STONE = "LEAF ST.",
    MOON_STONE = "MOON ST.",
    THUNDER_STONE = "THUNDER ST.",
    WATER_STONE = "WATER ST.",
  }

  local function evolutionTrigger(evolution)
    if evolution.level ~= nil then
      return "LV." .. tostring(evolution.level)
    end
    if type(evolution.item) == "string" then
      return EVOLUTION_ITEM_ABBREVIATIONS[evolution.item]
        or Browser.words(evolution.item):upper()
    end
    local method = tostring(evolution.method or ""):upper()
    if method == "" then return "UNKNOWN" end
    return Browser.words(method):upper()
  end

  local function wrap(lines)
    local output = {}
    for _, source in ipairs(lines or {}) do
      source = tostring(source or "")
      if source == "" then
        output[#output + 1] = ""
      else
        local current = ""
        for word in source:gmatch("%S+") do
          if #word > 18 then
            if current ~= "" then output[#output + 1], current = current, "" end
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

  local function nameOf(self, id)
    return self.index.names[id] or Browser.words(id)
  end

  local function rowLabel(self, row)
    if row.kind == "fishing_no_bite" then
      return "NO BITE"
    elseif row.kind == "wild" then
      return nameOf(self, row.species)
    elseif row.kind == "trainer" then
      return row.label
    elseif row.kind == "trade" then
      return nameOf(self, row.received)
    elseif row.kind == "item" then
      return row.label
    end
    return row.label or nameOf(self, row.species)
  end

  local function rowSecondary(self, row)
    if row.kind == "fishing_no_bite" then
      return percent(row.chance) .. " PCT " .. row.method
    elseif row.kind == "wild" then
      local level = levelText(row)
      local chance = percent(row.chance) .. " PCT"
      return row.category ~= "grass" and row.category ~= "surf"
        and (chance .. " " .. row.method)
        or (chance .. (level ~= "" and (" " .. level) or ""))
    elseif row.kind == "trainer" then
      return ("%d POKEMON"):format(#(row.party or {}))
    elseif row.kind == "trade" then
      return nameOf(self, row.requested)
        .. " -> " .. nameOf(self, row.received)
    elseif row.kind == "starter" or row.kind == "gift" then
      return nameOf(self, row.species)
        .. " LV. " .. tostring(row.level or "?")
    elseif row.kind == "item" then
      if row.sourceKind == "prize_tms" then
        return "PRIZE " .. tostring(row.price or "?") .. " COINS"
      elseif row.sourceKind == "vending" then
        return "VENDING Y" .. tostring(row.price or "?")
      elseif row.sourceKind == "shop" then
        return "SHOP Y" .. tostring(row.price or "?")
      elseif row.sourceKind == "gym" then
        return "GYM REWARD"
      elseif row.sourceKind == "gift" then
        return "GIFT"
      end
      return row.storage and "PC STORAGE"
        or row.hidden and "HIDDEN" or "ITEM BALL"
    elseif row.species then
      return nameOf(self, row.species)
    end
    return ""
  end

  local function encounterLines(row)
    if row.kind == "fishing_no_bite" then
      return { percent(row.chance) .. " PCT" }
    end
    local chances = {}
    for _, slot in ipairs(row.slots or {}) do
      local level = tonumber(slot.level)
      if level then
        chances[level] = (chances[level] or 0) + (tonumber(slot.chance) or 0)
      end
    end
    if next(chances) == nil and row.minLevel then
      chances[tonumber(row.minLevel)] = tonumber(row.chance) or 0
    end
    local levels = {}
    for level in pairs(chances) do levels[#levels + 1] = level end
    table.sort(levels)
    local lines = {}
    for _, level in ipairs(levels) do
      lines[#lines + 1] = ("%s PCT LV. %s"):format(
        percent(chances[level]), tostring(level))
    end
    return lines
  end

  local function encounterBlockHeight(row)
    return (#encounterLines(row) + 1) * 8 + 8
  end

  local function locationLines(self, location)
    local lines = {}
    local inline = false
    for _, row in ipairs(location.rows or {}) do
      if row.kind == "wild" then
        inline = true
        lines[#lines + 1] = row.method
        for _, line in ipairs(encounterLines(row)) do
          lines[#lines + 1] = line
        end
      elseif row.kind == "trade" then
        inline = true
        lines[#lines + 1] = row.label
        lines[#lines + 1] = "REQUESTED"
        lines[#lines + 1] = nameOf(self, row.requested)
        lines[#lines + 1] = "RECEIVED"
        lines[#lines + 1] = nameOf(self, row.received)
      elseif row.kind == "prize" then
        inline = true
        lines[#lines + 1] = row.label
        lines[#lines + 1] = nameOf(self, row.species)
        lines[#lines + 1] = "LV. " .. tostring(row.level)
        lines[#lines + 1] = tostring(row.cost) .. " COINS"
      elseif row.kind == "starter" or row.kind == "gift" then
        inline = true
        lines[#lines + 1] = row.label
        lines[#lines + 1] = nameOf(self, row.species)
          .. " LV. " .. tostring(row.level or "?")
      end
    end
    if not inline and location.summary and location.summary ~= "" then
      lines[1] = location.summary
    end
    return lines
  end

  local function locationBlockHeight(self, location)
    return (#locationLines(self, location) + 1) * 8 + 8
  end

  local function pokemonRowHeight(self, row)
    if row.section or row.evolution or row.empty then return 16 end
    return locationBlockHeight(self, row.location or {})
  end

  local function tradeLines(self, row)
    local heading = tostring(row.label or ""):gsub("^Trade%s+", "")
    return {
      heading,
      "REQUESTED",
      nameOf(self, row.requested),
      "RECEIVED",
      nameOf(self, row.received),
    }
  end

  local function detailsFor(self, row)
    local lines = {}
    if row.kind == "fishing_no_bite" then
      lines[#lines + 1] = row.method
      lines[#lines + 1] = "NO BITE"
      lines[#lines + 1] = percent(row.chance) .. " PCT PER CAST"
    elseif row.kind == "wild" then
      lines[#lines + 1] = row.method
      lines[#lines + 1] = nameOf(self, row.species)
      lines[#lines + 1] =
        levelText(row) .. "  TOTAL " .. percent(row.chance) .. " PCT"
      lines[#lines + 1] = ""
      lines[#lines + 1] = "INDIVIDUAL SLOTS"
      for _, slot in ipairs(row.slots or {}) do
        lines[#lines + 1] = ("SLOT %s  %s PCT"):format(
          tostring(slot.slot), percent(slot.chance))
        lines[#lines + 1] = nameOf(self, slot.species)
          .. " LV." .. tostring(slot.level)
      end
    elseif row.kind == "trainer" then
      lines[#lines + 1] = ""
      for index, member in ipairs(row.party or {}) do
        lines[#lines + 1] = ("%d. %s LV.%s"):format(
          index, nameOf(self, member.species),
          tostring(member.level or "?"))
      end
    elseif row.kind == "trade" then
      lines[#lines + 1] = "REQUESTED"
      lines[#lines + 1] = nameOf(self, row.requested)
      lines[#lines + 1] = "RECEIVED"
      lines[#lines + 1] = nameOf(self, row.received)
    elseif row.kind == "prize" then
      lines[#lines + 1] = row.label
      lines[#lines + 1] = nameOf(self, row.species)
      lines[#lines + 1] = "LV." .. tostring(row.level)
      lines[#lines + 1] = tostring(row.cost) .. " COINS"
    else
      lines[#lines + 1] = row.label or string.upper(row.kind or "ENTRY")
      lines[#lines + 1] = nameOf(self, row.species)
      if row.level then lines[#lines + 1] = "LV." .. tostring(row.level) end
      if row.price then lines[#lines + 1] = "$" .. tostring(row.price) end
    end
    return wrap(lines)
  end

  local function validDimensions(width, height)
    return type(width) == "number" and type(height) == "number"
      and width > 0 and height > 0
      and width == math.floor(width) and height == math.floor(height)
      and width % 8 == 0 and height % 8 == 0
  end

  local function validTileMap(map, tileCount)
    if type(map) ~= "table" or #map == 0 then return false end
    for _, tile in ipairs(map) do
      if type(tile) ~= "number" or tile ~= math.floor(tile)
          or tile < 0 or tile >= tileCount then
        return false
      end
    end
    return true
  end

  local function backgroundKey(tiles)
    return table.concat({
      tostring(tiles.path),
      tostring(tiles.identity or tiles.revision or tiles),
      tostring(tiles.width or ""),
      tostring(tiles.height or ""),
    }, "\0")
  end

  local function loadBackground(index)
    local bg = index.townMap and index.townMap.background
    local loveApi = rawget(_G, "love")
    local graphics = type(loveApi) == "table" and loveApi.graphics or nil
    if not (type(bg) == "table" and type(bg.map) == "table"
        and type(bg.tiles) == "table"
        and type(bg.tiles.path) == "string" and bg.tiles.path ~= ""
        and type(graphics) == "table"
        and type(graphics.newImage) == "function"
        and type(graphics.newQuad) == "function") then
      return nil
    end
    local key = backgroundKey(bg.tiles)
    local cached = backgroundCache[key]
    if cached then
      backgroundStats.hits = backgroundStats.hits + 1
      if cached.failed
          or not validTileMap(bg.map, cached.tileCount) then return nil end
      return {
        image = cached.image,
        quads = cached.quads,
        map = copyArray(bg.map),
      }
    end

    backgroundStats.imageBuilds = backgroundStats.imageBuilds + 1
    local ok, image = pcall(graphics.newImage, bg.tiles.path)
    if not ok or not image or type(image.getDimensions) ~= "function" then
      backgroundCache[key] = { failed = true }
      backgroundStats.failures = backgroundStats.failures + 1
      return nil
    end
    local dimensionsOk, width, height =
      pcall(image.getDimensions, image)
    if not dimensionsOk or not validDimensions(width, height) then
      backgroundCache[key] = { failed = true }
      backgroundStats.failures = backgroundStats.failures + 1
      return nil
    end
    local perRow = width / 8
    local tileCount = perRow * (height / 8)
    if not validTileMap(bg.map, tileCount) then
      backgroundStats.failures = backgroundStats.failures + 1
      return nil
    end
    local quads = {}
    for i = 0, tileCount - 1 do
      local quadOk, quad = pcall(graphics.newQuad,
        (i % perRow) * 8, math.floor(i / perRow) * 8,
        8, 8, width, height)
      if not quadOk or not quad then
        backgroundCache[key] = { failed = true }
        backgroundStats.failures = backgroundStats.failures + 1
        return nil
      end
      backgroundStats.quadBuilds = backgroundStats.quadBuilds + 1
      quads[i] = quad
    end
    backgroundCache[key] = {
      image = image,
      quads = quads,
      width = width,
      height = height,
      tileCount = tileCount,
    }
    return { image = image, quads = quads, map = copyArray(bg.map) }
  end

  function Screen.backgroundCacheStats()
    return {
      imageBuilds = backgroundStats.imageBuilds,
      quadBuilds = backgroundStats.quadBuilds,
      hits = backgroundStats.hits,
      failures = backgroundStats.failures,
    }
  end

  function Screen.clearBackgroundCache()
    backgroundCache = {}
    backgroundStats = {
      imageBuilds = 0,
      quadBuilds = 0,
      hits = 0,
      failures = 0,
    }
  end

  function Screen.new(game, model, ui)
    assert(type(model) == "table" and type(model.index) == "table",
      "spoiler browser index is required")
    return setmetatable({
      game = game,
      ui = ui,
      index = model.index,
      mode = "root",
      rows = {
        { label = "POKEMON", value = "pokemon" },
        { label = "ITEMS", value = "items" },
        { label = "MAP", value = "map" },
      },
      selection = 1,
      scroll = 0,
      history = {},
      search = "",
      itemSearch = "",
      blink = 0,
      background = loadBackground(model.index),
    }, Screen)
  end

  function Screen:saveState()
    self.history[#self.history + 1] = {
      mode = self.mode, rows = self.rows, selection = self.selection,
      scroll = self.scroll, area = self.area, map = self.map,
      mapTabs = self.mapTabs, tabIndex = self.tabIndex,
      detailTitle = self.detailTitle,
    }
  end

  function Screen:setMode(mode, rows)
    self.mode, self.rows = mode, rows or {}
    self.selection, self.scroll = 1, 0
  end

  function Screen:back()
    local previous = self.history[#self.history]
    if not previous then
      self.game.stack:pop()
      return
    end
    self.history[#self.history] = nil
    for key, value in pairs(previous) do self[key] = value end
    self.detailTitle = previous.detailTitle
  end

  function Screen:speciesRows()
    local rows, query = {}, self.search:upper()
    for _, species in ipairs(self.index.species) do
      if query == "" or species.name:upper():find(query, 1, true) then
        rows[#rows + 1] = {
          label = species.dex and ("#%03d %s"):format(
            species.dex, species.name) or ("#--- " .. species.name),
          species = species,
        }
      end
    end
    return rows
  end

  function Screen:itemRows()
    local rows, query = {}, self.itemSearch:upper()
    for _, item in ipairs(self.index.items or {}) do
      if query == "" or item.name:upper():find(query, 1, true) then
        rows[#rows + 1] = { label = item.name, item = item }
      end
    end
    return rows
  end

  function Screen:openSearch(kind)
    local items = kind == "items"
    self.game.stack:push(self.ui.NamingScreen.new(self.game, {
      title = items and "ITEM SEARCH" or "POKEMON SEARCH",
      maxLen = 12,
      onDone = function(value)
        local query = tostring(value or ""):upper():gsub("^%s+", "")
          :gsub("%s+$", "")
        if items then
          self.itemSearch = query
          self.rows = self:itemRows()
        else
          self.search = query
          self.rows = self:speciesRows()
        end
        self.selection, self.scroll = 1, 0
      end,
    }))
  end

  function Screen:openArea(area)
    self:saveState()
    self.area = area
    if #area.maps == 1 then
      self:openTabs(area.maps[1], true)
      return
    end
    local rows = {}
    for _, map in ipairs(area.maps) do
      rows[#rows + 1] = { label = map.label, map = map }
    end
    self:setMode("areas", rows)
  end

  function Screen:openTabs(map, stateAlreadySaved)
    if not stateAlreadySaved then self:saveState() end
    self.map = map
    self.mapTabs = availableTabs(self.index, map)
    self.tabIndex = 1
    local tab = self.mapTabs[1]
    self:setMode("tabs", tab and map.tabs[tab] or {})
  end

  function Screen:changeTab(delta)
    local count = #(self.mapTabs or {})
    if count == 0 then return end
    self.tabIndex = ((self.tabIndex - 1 + delta) % count) + 1
    local tab = self.mapTabs[self.tabIndex]
    self.rows = self.map.tabs[tab] or {}
    self.selection, self.scroll = 1, 0
  end

  function Screen:openDetails(title, lines)
    self:saveState()
    self.detailTitle = title
    self:setMode("details", lines)
  end

  function Screen:move(delta, page)
    local count = #self.rows
    if count == 0 then return end
    local amount = page and LIST_ROWS or 1
    local previousSelection = self.selection
    self.selection = math.max(1,
      math.min(count, self.selection + delta * amount))
    local currentTab = self.mode == "tabs"
      and self.mapTabs and self.mapTabs[self.tabIndex]
    if isEncounterTab(currentTab) then
      if self.selection <= self.scroll then
        self.scroll = self.selection - 1
      end
      while self.scroll < self.selection - 1 do
        local height = 0
        for index = self.scroll + 1, self.selection do
          height = height + encounterBlockHeight(self.rows[index])
        end
        if height <= 96 then break end
        self.scroll = self.scroll + 1
      end
      return
    end
    if self.mode == "locations" then
      local direction = delta < 0 and -1 or 1
      local candidate = self.selection
      while candidate >= 1 and candidate <= count
          and not self.rows[candidate].location do
        candidate = candidate + direction
      end
      if candidate >= 1 and candidate <= count then
        self.selection = candidate
      else
        self.selection = previousSelection
      end
      if self.selection <= self.scroll then
        self.scroll = self.selection - 1
      end
      while self.scroll < self.selection - 1 do
        local height = 0
        for index = self.scroll + 1, self.selection do
          height = height + pokemonRowHeight(self, self.rows[index])
        end
        if height <= 104 then break end
        self.scroll = self.scroll + 1
      end
      return
    end
    local visible = self.mode == "details" and DETAIL_ROWS
      or listLayout(spacedMode(self.mode)).rows
    if self.selection - self.scroll > visible then
      self.scroll = self.selection - visible
    elseif self.selection - self.scroll < 1 then
      self.scroll = self.selection - 1
    end
  end

  function Screen:moveMap(dx, dy)
    local current = self.index.areas[self.selection]
    if not current then return end
    local best, score
    for index, area in ipairs(self.index.areas) do
      if index ~= self.selection then
        local x, y = area.x - current.x, area.y - current.y
        local forward = x * dx + y * dy
        local sideways = math.abs(x * dy) + math.abs(y * dx)
        local candidate = forward > 0 and (forward + sideways * 3) or nil
        if candidate and (not score or candidate < score) then
          best, score = index, candidate
        end
      end
    end
    if best then self.selection = best end
  end

  function Screen:choose()
    local row = self.rows[self.selection]
    if self.mode == "root" then
      self:saveState()
      if row.value == "pokemon" then
        self:setMode("pokemon", self:speciesRows())
      elseif row.value == "items" then
        self:setMode("items", self:itemRows())
      else
        self.mode, self.rows, self.selection, self.scroll =
          "map", {}, 1, 0
      end
    elseif self.mode == "pokemon" and row then
      self:saveState()
      local locations = self.index.locationsBySpecies[row.species.id] or {}
      local rows = { { label = "EVOLUTIONS", section = true } }
      if #(row.species.evolutions or {}) == 0 then
        rows[#rows + 1] = { label = "NONE", evolution = true }
      else
        for _, evolution in ipairs(row.species.evolutions) do
          rows[#rows + 1] = {
            label = nameOf(self, evolution.species),
            right = evolutionTrigger(evolution),
            evolution = evolution,
          }
        end
      end
      rows[#rows + 1] = { label = "LOCATIONS", section = true }
      local firstLocation
      for _, location in ipairs(locations) do
        rows[#rows + 1] = {
          label = location.label,
          right = location.summary,
          location = location,
        }
        firstLocation = firstLocation or #rows
      end
      if not firstLocation then
        rows[#rows + 1] = { label = "NOT FOUND", empty = true }
      end
      self.selectedSpecies = row.species
      self:setMode("locations", rows)
      self.selection = firstLocation or #rows
    elseif self.mode == "items" and row then
      self:saveState()
      self.selectedItem = row.item
      local rows = {}
      for _, location in ipairs(self.index.locationsByItem[row.item.id] or {}) do
        rows[#rows + 1] = {
          label = location.location,
          right = rowSecondary(self, location),
          itemLocation = location,
        }
      end
      if #rows == 0 then rows[1] = { label = "NOT FOUND", empty = true } end
      self:setMode("item_locations", rows)
    elseif self.mode == "locations" and row and row.location then
      self.selectedLocation = row.location
      local results = row.location.rows or {}
      local staticOnly, wildOnly, tradeOnly, prizeOnly, starterOnly, giftOnly =
        #results > 0, #results > 0, #results > 0, #results > 0,
        #results > 0, #results > 0
      for _, result in ipairs(results) do
        if result.kind ~= "static" then staticOnly = false break end
      end
      for _, result in ipairs(results) do
        if result.kind ~= "wild" then wildOnly = false break end
      end
      for _, result in ipairs(results) do
        if result.kind ~= "trade" then tradeOnly = false break end
      end
      for _, result in ipairs(results) do
        if result.kind ~= "prize" then prizeOnly = false break end
      end
      for _, result in ipairs(results) do
        if result.kind ~= "starter" then starterOnly = false break end
      end
      for _, result in ipairs(results) do
        if result.kind ~= "gift" then giftOnly = false break end
      end
      if staticOnly or wildOnly or tradeOnly or prizeOnly
          or starterOnly or giftOnly then
        return
      elseif #results == 1 then
        local result = results[1]
        self:openDetails(result.label or rowLabel(self, result),
          detailsFor(self, result))
      else
        self:saveState()
        self:setMode("location_entries", row.location.rows)
      end
    elseif self.mode == "location_entries" and row then
      self:openDetails(row.label or rowLabel(self, row),
        detailsFor(self, row))
    elseif self.mode == "map" then
      local area = self.index.areas[self.selection]
      if area then self:openArea(area) end
    elseif self.mode == "areas" and row then
      self:openTabs(row.map)
    elseif self.mode == "tabs" and row
        and not isInlineTab(
          self.mapTabs and self.mapTabs[self.tabIndex]) then
      self:openDetails(row.label or rowLabel(self, row),
        detailsFor(self, row))
    end
  end

  function Screen:update()
    self.blink = (self.blink + 1) % 32
    local input = self.game.input
    if self.mode == "details"
        and (pressed(input, "a") or pressed(input, "b")) then
      self:back()
    elseif pressed(input, "b") then
      self:back()
    elseif self.mode == "map" then
      if pressed(input, "up") then self:moveMap(0, -1)
      elseif pressed(input, "down") then self:moveMap(0, 1)
      elseif pressed(input, "left") then self:moveMap(-1, 0)
      elseif pressed(input, "right") then self:moveMap(1, 0)
      elseif pressed(input, "a") then self:choose() end
    elseif self.mode == "tabs" then
      if pressed(input, "left") then self:changeTab(-1)
      elseif pressed(input, "right") then self:changeTab(1)
      elseif pressed(input, "up") then self:move(-1)
      elseif pressed(input, "down") then self:move(1)
      elseif pressed(input, "a")
          and not isInlineTab(
            self.mapTabs and self.mapTabs[self.tabIndex]) then
        self:choose()
      end
    else
      if (self.mode == "pokemon" or self.mode == "items")
          and pressed(input, "select") then
        self:openSearch(self.mode)
      elseif pressed(input, "up") then self:move(-1)
      elseif pressed(input, "down") then self:move(1)
      elseif pressed(input, "left") then self:move(-1, true)
      elseif pressed(input, "right") then self:move(1, true)
      elseif pressed(input, "a") then self:choose() end
    end
  end

  function Screen:drawList(title, formatter, footer, spaced)
    local Font, Theme = self.ui.Font, self.ui.Theme
    local layout = listLayout(spaced)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    Font.drawBox(0, 0, 20, 18)
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(clip(title, 18), 8, 8)
    if #self.rows == 0 then
      Font.draw("NO CONTENT", 16, 64)
    end
    for slot = 1, layout.rows do
      local index = self.scroll + slot
      local row = self.rows[index]
      if not row then break end
      local label, right = formatter(row)
      local y = layout.firstY + (slot - 1) * layout.stride
      if index == self.selection then Font.drawCode(Theme.cursor, 8, y) end
      Font.draw(clip(label, 17), 20, y)
      if right and right ~= "" then
        Font.draw(clip(right, 17), 20, y + layout.secondaryOffset)
      end
    end
    if footer and footer ~= "" then
      Font.draw(clip(footer, 18), 8, 128)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  function Screen:drawEncounterList(title)
    local Font, Theme = self.ui.Font, self.ui.Theme
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    Font.drawBox(0, 0, 20, 18)
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(clip(title, 18), 8, 8)
    local y = 24
    for index = self.scroll + 1, #self.rows do
      local row = self.rows[index]
      local lines = encounterLines(row)
      local height = (#lines + 1) * 8 + 8
      if y + height > 128 and index > self.scroll + 1 then break end
      if index == self.selection then Font.drawCode(Theme.cursor, 8, y) end
      Font.draw(clip(rowLabel(self, row), 17), 20, y)
      for lineIndex, line in ipairs(lines) do
        Font.draw(clip(line, 17), 20, y + lineIndex * 8)
      end
      y = y + height
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  function Screen:drawLocationsList(title)
    local Font, Theme = self.ui.Font, self.ui.Theme
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    Font.drawBox(0, 0, 20, 18)
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(clip(title, 18), 8, 8)
    local y = 24
    for index = self.scroll + 1, #self.rows do
      local row = self.rows[index]
      local height = pokemonRowHeight(self, row)
      if y + height > 128 and index > self.scroll + 1 then break end
      if row.section then
        Font.draw(clip(row.label, 18), 8, y)
      elseif row.evolution then
        local line = row.label
        if row.right and row.right ~= "" then line = line .. " " .. row.right end
        Font.draw(clip(line, 18), 8, y)
      elseif row.empty then
        Font.draw(clip(row.label, 17), 20, y)
      else
        local location = row.location or {}
        local lines = locationLines(self, location)
        if index == self.selection then Font.drawCode(Theme.cursor, 8, y) end
        Font.draw(abbreviateLocation(row.label), 20, y)
        for lineIndex, line in ipairs(lines) do
          Font.draw(clip(line, 17), 20, y + lineIndex * 8)
        end
      end
      y = y + height
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  function Screen:drawTradesList(title)
    local Font = self.ui.Font
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    Font.drawBox(0, 0, 20, 18)
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(clip(title, 18), 8, 8)
    local y = 24
    for _, row in ipairs(self.rows) do
      local lines = tradeLines(self, row)
      if y + #lines * 8 > 128 then break end
      for lineIndex, line in ipairs(lines) do
        Font.draw(clip(line, 18), 8, y + (lineIndex - 1) * 8)
      end
      y = y + #lines * 8 + 8
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  function Screen:drawMap()
    local Font, Theme = self.ui.Font, self.ui.Theme
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    local selected = self.index.areas[self.selection]
    if self.background then
      for i, tile in ipairs(self.background.map) do
        local col, row = (i - 1) % 20, math.floor((i - 1) / 20)
        love.graphics.draw(self.background.image,
          self.background.quads[tile], col * 8, row * 8)
      end
    else
      Font.drawBox(0, 0, 20, 18)
      for _, area in ipairs(self.index.areas) do
        local x, y = markerXY(area)
        love.graphics.setColor(0.25, 0.25, 0.25, 1)
        love.graphics.rectangle("fill", x + 1, y + 1, 6, 6)
      end
    end
    if selected then
      local x, y = markerXY(selected)
      local outer, inner = cursorColors(self.blink)
      local frames = cursorFrames(x, y)
      love.graphics.setColor(
        outer[1], outer[2], outer[3], outer[4])
      love.graphics.rectangle("line",
        frames[1].x, frames[1].y, frames[1].width, frames[1].height)
      love.graphics.setColor(
        inner[1], inner[2], inner[3], inner[4])
      love.graphics.rectangle("line",
        frames[2].x, frames[2].y, frames[2].width, frames[2].height)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 8)
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(selected and abbreviateLocation(selected.name) or "KANTO", 8, 0)
    Font.drawCode(Theme.cursor, 144, 0)
    love.graphics.setColor(1, 1, 1, 1)
  end

  function Screen:drawDetails()
    local Font = self.ui.Font
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    Font.drawBox(0, 0, 20, 18)
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(clip(self.detailTitle or "DETAILS", 18), 8, 8)
    for slot = 1, DETAIL_ROWS do
      local line = self.rows[self.scroll + slot]
      if line then Font.draw(clip(line, 18), 8, 16 + slot * 8) end
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  function Screen:draw()
    if self.mode == "map" then return self:drawMap() end
    if self.mode == "details" then return self:drawDetails() end
    if self.mode == "root" then
      return self:drawList("SPOILER LOG", function(row)
        return row.label
      end)
    elseif self.mode == "pokemon" then
      local suffix = self.search ~= "" and (" [" .. self.search .. "]") or ""
      return self:drawList("POKEMON" .. suffix, function(row)
        return row.label
      end, SEARCH_FOOTER)
    elseif self.mode == "items" then
      local suffix = self.itemSearch ~= ""
        and (" [" .. self.itemSearch .. "]") or ""
      return self:drawList("ITEMS" .. suffix, function(row)
        return row.label
      end, SEARCH_FOOTER)
    elseif self.mode == "item_locations" then
      return self:drawList(self.selectedItem and self.selectedItem.name or "ITEM",
        function(row)
          return abbreviateLocation(row.label), row.right
        end, nil, true)
    elseif self.mode == "locations" then
      return self:drawLocationsList(self.selectedSpecies.name)
    elseif self.mode == "location_entries" then
      return self:drawList(abbreviateLocation(self.selectedLocation.label),
        function(row)
        if row.kind == "wild" then
          return row.method .. " " .. levelText(row),
            percent(row.chance) .. " PCT"
        elseif row.kind == "trade" then
          return "TRADE", nameOf(self, row.requested)
            .. " -> " .. nameOf(self, row.received)
        end
        return string.upper(row.kind or "ENTRY"),
          nameOf(self, row.species)
            .. (row.level and (" LV." .. tostring(row.level)) or "")
      end, nil, true)
    elseif self.mode == "areas" then
      return self:drawList(abbreviateLocation(self.area.name), function(row)
        return abbreviateLocation(row.label)
      end)
    elseif self.mode == "tabs" then
      local tabs = self.mapTabs or {}
      local tab = tabs[self.tabIndex]
      if not tab then
        return self:drawList("NO CONTENT", function(row)
          return rowLabel(self, row), rowSecondary(self, row)
        end, nil, true)
      end
      local title = ("< %s %d/%d >"):format(
        self.index.tabLabels[tab], self.tabIndex, #tabs)
      if isEncounterTab(tab) then
        return self:drawEncounterList(title)
      elseif tab == "trades" then
        return self:drawTradesList(title)
      end
      return self:drawList(title, function(row)
        return rowLabel(self, row), rowSecondary(self, row)
      end, nil, true)
    end
  end

  Screen.markerXY = markerXY
  Screen.searchFooter = SEARCH_FOOTER
  Screen.cursorColors = cursorColors
  Screen.cursorFrames = cursorFrames
  Screen.availableTabs = availableTabs
  Screen.encounterLines = encounterLines
  Screen.locationLines = locationLines
  Screen.evolutionTrigger = evolutionTrigger
  Screen.isEncounterTab = isEncounterTab
  Screen.isInlineTab = isInlineTab
  Screen.tradeLines = tradeLines
  Screen.abbreviateLocation = abbreviateLocation
  Screen.listLayout = listLayout
  Screen.rowSecondary = rowSecondary
  return Screen
end
