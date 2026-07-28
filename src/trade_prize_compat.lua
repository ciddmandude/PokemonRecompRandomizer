-- Public-API-2 runtime adapters for stock-v0.1.30 trades and Game Corner.
return function(Catalog)
  local Compat = {}
  local TRADE_COMMAND = "pokemon_randomizer:trade_m12"
  local PRIZE_SCREEN = "PokemonRandomizerGameCornerPrizes"

  local function mapping(activeRun, bucket, id)
    local run = activeRun()
    local mappings = type(run) == "table" and run.mappings
    local category = type(mappings) == "table" and mappings[bucket]
    local value = type(category) == "table" and category[id]
    if type(value) == "table" and type(run._speciesSet) == "table" then
      local missing = (type(value.species) == "string"
          and not run._speciesSet[value.species])
        or (type(value.requested) == "table"
          and not run._speciesSet[value.requested.species])
        or (type(value.received) == "table"
          and not run._speciesSet[value.received.species])
      if missing then return nil end
    end
    return type(value) == "table" and value or nil
  end

  local function shallowCopy(value)
    local copy = {}
    for key, child in pairs(value or {}) do copy[key] = child end
    return copy
  end

  local function tradeContributions()
    local output = {}
    for _, record in ipairs(Catalog.trades) do
      output[record.mapId] = output[record.mapId]
        or { priority = 100, talk = {} }
      output[record.mapId].talk[record.talkKey] = {
        { "face_player" },
        { TRADE_COMMAND, record.id, record.index, record.flag },
        { "label", "done" },
      }
    end
    return output
  end

  local function prizeRecords(game, activeRun)
    local version = game.save and game.save.version == "blue"
      and "blue" or "red"
    local output = {}
    for _, record in ipairs(Catalog.prizes[version]) do
      local saved = mapping(activeRun, "prizes", record.id)
      if saved and (type(saved.species) ~= "string"
          or type(saved.level) ~= "number"
          or type(saved.cost) ~= "number") then
        saved = nil
      end
      output[#output + 1] = {
        kind = "mon",
        id = record.id,
        species = saved and saved.species or record.species,
        level = saved and saved.level or record.level,
        cost = saved and saved.cost or record.cost,
        mapped = saved ~= nil,
      }
    end
    for _, record in ipairs(Catalog.prizeItems) do
      output[#output + 1] = shallowCopy(record)
    end
    return output
  end

  local function prizeCounter(mod, activeRun)
    return function(game, overworld, npc, done)
      local text = game.data.text or {}
      if not (game.save.inventory or {}).COIN_CASE then
        game.stack:push(mod.ui.TextBox.new(game,
          text._RequireCoinCaseText
            or "A COIN CASE is\nrequired!", done))
        return
      end
      game.stack:push(mod.ui.TextBox.new(game,
        text._ExchangeCoinsForPrizesText
          or "We exchange your\ncoins for prizes.",
        function()
          mod.ui.push(game, PRIZE_SCREEN, done)
        end))
    end
  end

  function Compat.install(mod, activeRun)
    assert(type(activeRun) == "function", "active-run provider is required")
    local commands = mod.content.commands
    local baseTrade = assert(commands:get("trade"), "trade command missing")
    local givePokemon = assert(
      commands:get("give_pokemon"), "give_pokemon command missing")

    commands:register(TRADE_COMMAND,
      function(ctx, id, tradeIndex, doneFlag)
        local saved = mapping(activeRun, "trades", id)
        if not saved then return baseTrade(ctx, tradeIndex, doneFlag) end
        local trades = ctx.game.data.field.trades
        local original = trades and trades[tradeIndex]
        if type(original) ~= "table"
            or type(saved.requested) ~= "table"
            or type(saved.received) ~= "table"
            or type(saved.requested.species) ~= "string"
            or type(saved.received.species) ~= "string" then
          return baseTrade(ctx, tradeIndex, doneFlag)
        end
        local replacement = shallowCopy(original)
        replacement.give = saved.requested.species
        replacement.get = saved.received.species
        trades[tradeIndex] = replacement
        local ok, err = pcall(baseTrade, ctx, tradeIndex, doneFlag)
        trades[tradeIndex] = original
        if not ok then error(err, 0) end
      end)

    mod.content.screens:register(PRIZE_SCREEN, {
      new = function(game, done)
        local version = game.save and game.save.version == "blue"
          and "blue" or "red"
        local items = {}
        for _, prize in ipairs(prizeRecords(game, activeRun)) do
          local label
          if prize.kind == "mon" then
            local species = game.data.pokemon[prize.species]
            label = ("%s L%d"):format(
              species and species.name or prize.species, prize.level)
          else
            local item = game.data.items[prize.item]
            label = item and item.name or prize.item
          end
          items[#items + 1] = {
            label = label,
            right = tostring(prize.cost),
            value = prize,
          }
        end

        local list
        list = mod.ui.ListMenu.new(game, "PRIZES (COINS)", items, {
          footer = ("COINS %d"):format(game.save.coins or 0),
          onChoose = function(item)
            local prize = item.value
            if (game.save.coins or 0) < prize.cost then
              list.footer = "Not enough coins!"
              return
            end
            if prize.kind == "mon" then
              local ctx = { save = game.save, game = game }
              if prize.mapped then
                givePokemon(ctx, prize.species, prize.level)
                if not ctx.lastCheck then
                  list.footer = "No room for Pokemon!"
                  return
                end
                game.save.coins = game.save.coins - prize.cost
              else
                -- Exact v0.1.30 vanilla order when the category is disabled.
                game.save.coins = game.save.coins - prize.cost
                givePokemon(ctx, prize.species, prize.level)
              end
            else
              game.save.coins = game.save.coins - prize.cost
              game.save.inventory[prize.item] =
                (game.save.inventory[prize.item] or 0) + 1
            end
            list.footer = ("Got it! COINS %d"):format(game.save.coins)
          end,
          onCancel = done,
        })
        return list
      end,
    })

    local contributions = tradeContributions()
    contributions.GAME_CORNER_PRIZE_ROOM = {
      priority = 100,
      talk = {
        TEXT_GAMECORNERPRIZEROOM_PRIZE_VENDOR_1 =
          prizeCounter(mod, activeRun),
        TEXT_GAMECORNERPRIZEROOM_PRIZE_VENDOR_2 =
          prizeCounter(mod, activeRun),
        TEXT_GAMECORNERPRIZEROOM_PRIZE_VENDOR_3 =
          prizeCounter(mod, activeRun),
      },
    }
    for mapId, contribution in pairs(contributions) do
      mod.content.map_scripts:register(mapId, contribution)
    end
    return contributions
  end

  Compat.tradeCommand = TRADE_COMMAND
  Compat.prizeScreen = PRIZE_SCREEN
  Compat.contributions = tradeContributions
  Compat.prizeRecords = prizeRecords
  return Compat
end
