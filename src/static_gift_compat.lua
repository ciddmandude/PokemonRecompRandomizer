-- Public-API-2 runtime adapters for the explicitly scoped mod-only M11 set.
return function(Catalog)
  local Compat = {}

  local CMD = {
    show = "pokemon_randomizer:show_m11_species",
    ask = "pokemon_randomizer:ask_m11_species",
    cry = "pokemon_randomizer:play_m11_cry",
    battle = "pokemon_randomizer:static_m11_battle",
    give = "pokemon_randomizer:give_m11_pokemon",
    finishFossil = "pokemon_randomizer:finish_fossil_restoration",
  }

  local fossilByItem = {}
  local fossilBySpecies = {}
  for _, record in ipairs(Catalog.giftsFor("yellow")) do
    if record.style == "fossil" then
      fossilByItem[record.fossilItem] = record
      fossilBySpecies[record.species] = record
    end
  end

  local function offer(activeRun, category, id, source, level)
    local run = activeRun()
    local mappings = type(run) == "table" and run.mappings
    local bucket = type(mappings) == "table" and mappings[category]
    local saved = type(bucket) == "table" and bucket[id]
    if type(saved) == "table" and type(saved.species) == "string"
        and type(saved.level) == "number"
        and not (type(run._speciesSet) == "table"
          and not run._speciesSet[saved.species]) then
      return saved, true
    end
    return { species = source, level = level }, false
  end

  local function runnerHandler(rows)
    return function(game, overworld, npc, onDone)
      if type(overworld) ~= "table" or type(overworld.runner) ~= "table"
          or type(overworld.runner.run) ~= "function" then
        if onDone then onDone() end
        return
      end
      overworld.runner:run(rows, { npc = npc, onDone = onDone })
    end
  end

  local function currentMapId(gift)
    local ctx = type(gift) == "table" and gift.ctx
    local overworld = type(ctx) == "table" and ctx.overworld
    local map = type(overworld) == "table" and overworld.map
    return type(map) == "table" and (map.id
      or type(map.def) == "table" and map.def.label) or nil
  end

  local function matchingGift(gift)
    if type(gift) ~= "table" or type(gift.species) ~= "string"
        or type(gift.ctx) ~= "table"
        or gift.ctx.randomizerGiftResolved then
      return nil
    end
    local mapId = currentMapId(gift)
    if not mapId then return nil end
    local game = gift.ctx.game
    local version = type(game) == "table" and type(game.save) == "table"
      and game.save.version or "red"
    for _, record in ipairs(Catalog.giftsFor(version)) do
      if record.mapId == mapId and record.species == gift.species
          and (type(gift.level) ~= "number"
            or gift.level == record.level) then
        return record
      end
    end
    return nil
  end

  local function fillText(text, values)
    text = tostring(text or "")
    text = text:gsub("{PLAYER}", tostring(values.player or ""))
    text = text:gsub("{RAM:wNameBuffer}", tostring(values.item or ""))
    text = text:gsub("{RAM:wStringBuffer}", tostring(values.species or ""))
    text = text:gsub("{RAM:x}", tostring(values.species or ""))
    text = text:gsub("{RAM}", tostring(values.species or ""))
    return text
  end

  local function speciesName(game, species)
    local def = game.data and game.data.pokemon
      and game.data.pokemon[species]
    return def and def.name or species
  end

  local function itemName(game, item)
    local def = game.data and game.data.items and game.data.items[item]
    return def and def.name or item
  end

  local function staticRows(record)
    if record.style == "power_ball" then
      return {
        { "show_text", "_PowerPlantVoltorbBattleText" },
        { "check_flag", record.flag },
        { "jump_if_true", "done" },
        { CMD.battle, record.id, record.species, record.level, record.flag },
        { "label", "done" },
      }
    end
    if record.style == "legend" then
      return {
        { CMD.cry, "staticEncounters",
          record.id, record.species, record.level },
        { CMD.show, "staticEncounters",
          record.id, record.species, record.level,
          "{RAM}!", record.battleText },
        { "check_flag", record.flag },
        { "jump_if_true", "done" },
        { CMD.battle, record.id, record.species, record.level, record.flag },
        { "label", "done" },
      }
    end
  end

  local function snorlaxContribution(record)
    return {
      priority = 100,
      talk = {
        [record.talkKey] = {
          { CMD.show, "staticEncounters", record.id,
            record.species, record.level,
            "A sleeping\n{RAM} blocks the way.", record.sleepingText },
        },
      },
      snorlaxWake = {
        objName = record.object,
        beatFlag = record.flag,
        script = {
          { CMD.show, "staticEncounters", record.id,
            record.species, record.level,
            record.wokeText, record.vanillaWokeText },
          { "hide_object", record.mapId, record.object },
          { CMD.battle, record.id, record.species, record.level, record.flag },
          { "check_battle_result", "win", "run" },
          { "jump_if_false", "done" },
          { CMD.show, "staticEncounters", record.id,
            record.species, record.level,
            record.calmedText, record.vanillaCalmedText },
          { "label", "done" },
        },
      },
    }
  end

  local function eeveeRows(record)
    return {
      { "check_flag", record.flag },
      { "jump_if_false", "offer" },
      { "hide_object", record.mapId, record.object },
      { "jump", "done" },
      { "label", "offer" },
      { CMD.give, record.id, record.species, record.level },
      { "jump_if_false", "full" },
      { "play_sound", "Get_Item1" },
      { CMD.show, "gifts", record.id, record.species, record.level,
        "_GotMonText" },
      { "set_flag", record.flag },
      { "hide_object", record.mapId, record.object },
      { "jump", "done" },
      { "label", "full" },
      { "show_text", "_BoxIsFullText" },
      { "label", "done" },
    }
  end

  local function saleHandler(record, activeRun)
    return function(game, overworld, npc, onDone)
      local flags = game.save.flags or {}
      local rows
      if flags[record.flag] then
        rows = {
          { "show_text",
            "_MtMoonPokecenterMagikarpSalesmanNoRefundsText" },
        }
      elseif (game.save.money or 0) < record.price then
        rows = {
          { CMD.ask, "gifts", record.id, record.species, record.level,
            "{RAM}! A steal at\n¥500! Want one?",
            "_MtMoonPokecenterMagikarpSalesmanOfferText" },
          { "jump_if_false", "declined" },
          { "show_text",
            "_MtMoonPokecenterMagikarpSalesmanNoMoneyText" },
          { "jump", "done" },
          { "label", "declined" },
          { "show_text", "_MtMoonPokecenterMagikarpSalesmanNoText" },
          { "label", "done" },
        }
      else
        rows = {
          { CMD.ask, "gifts", record.id, record.species, record.level,
            "{RAM}! A steal at\n¥500! Want one?",
            "_MtMoonPokecenterMagikarpSalesmanOfferText" },
          { "jump_if_false", "declined" },
          { CMD.give, record.id, record.species, record.level },
          { "jump_if_false", "full" },
          { "give_money", -record.price },
          { "set_flag", record.flag },
          { "play_sound", "Get_Item1" },
          { CMD.show, "gifts", record.id, record.species, record.level,
            "{PLAYER} got\n{RAM}!" },
          { "jump", "done" },
          { "label", "full" },
          { "show_text", "_BoxIsFullText" },
          { "jump", "done" },
          { "label", "declined" },
          { "show_text", "_MtMoonPokecenterMagikarpSalesmanNoText" },
          { "label", "done" },
        }
      end
      return runnerHandler(rows)(game, overworld, npc, onDone)
    end
  end

  local function dojoHandler(record, activeRun)
    return function(game, overworld, npc, onDone)
      local flags = game.save.flags or {}
      local rows
      if flags.EVENT_GOT_HITMONLEE or flags.EVENT_GOT_HITMONCHAN then
        rows = {{ "show_text", "_FightingDojoBetterNotGetGreedyText" }}
      elseif not flags.EVENT_BEAT_KARATE_MASTER then
        rows = {{ "show_text", "You'll have to\nbeat the master\nfirst!" }}
      else
        rows = {
          { CMD.ask, "gifts", record.id, record.species, record.level,
            "You want\n{RAM}?", record.askText },
          { "jump_if_false", "declined" },
          { CMD.give, record.id, record.species, record.level },
          { "jump_if_false", "full" },
          { "set_flag", record.flag },
          { "set_flag", "EVENT_DEFEATED_FIGHTING_DOJO" },
          { "hide_object", record.mapId, record.object },
          { CMD.show, "gifts", record.id, record.species, record.level,
            "{PLAYER} got\n{RAM}!" },
          { "jump", "done" },
          { "label", "full" },
          { "show_text", "_BoxIsFullText" },
          { "jump", "done" },
          { "label", "declined" },
          { "label", "done" },
        }
      end
      return runnerHandler(rows)(game, overworld, npc, onDone)
    end
  end

  local function laprasHandler(record, activeRun)
    return function(game, overworld, npc, onDone)
      local flags = game.save.flags or {}
      local rows
      if flags[record.flag] then
        rows = {
          { CMD.show, "gifts", record.id, record.species, record.level,
            "How is {RAM}\ndoing?",
            "_SilphCo7FSilphWorkerM1LaprasDescriptionText" },
        }
      else
        rows = {
          { CMD.show, "gifts", record.id, record.species, record.level,
            "Thank you for\nsaving us!\fI want you to\nhave this {RAM}!",
            "_SilphCo7FSilphWorkerM1ThankYouText" },
          { CMD.give, record.id, record.species, record.level },
          { "jump_if_false", "full" },
          { "set_flag", record.flag },
          { "play_sound", "Get_Item1" },
          { CMD.show, "gifts", record.id, record.species, record.level,
            "{PLAYER} got\n{RAM}!" },
          { CMD.show, "gifts", record.id, record.species, record.level,
            "It's a good\nswimmer!",
            "_SilphCo7FSilphWorkerM1LaprasDescriptionText" },
          { "jump", "done" },
          { "label", "full" },
          { "show_text", "_BoxIsFullText" },
          { "label", "done" },
        }
      end
      return runnerHandler(rows)(game, overworld, npc, onDone)
    end
  end

  local function yellowBulbasaurHandler(record, activeRun)
    return function(game, overworld, npc, onDone)
      local flags = game.save.flags or {}
      local run = activeRun()
      local randomizedStarter = type(run) == "table"
        and type(run.settings) == "table"
        and run.settings.starters ~= nil
        and run.settings.starters ~= "off"
      local rows = { { "face_player" } }
      if flags[record.flag] then
        rows[#rows + 1] = { "show_text", "MelanieText4" }
      elseif not randomizedStarter
          and (game.save.pikachuHappiness or 90) < 147 then
        rows[#rows + 1] = { "show_text", "MelanieText1" }
      else
        rows[#rows + 1] = { "show_text", "MelanieText1" }
        rows[#rows + 1] = { CMD.ask, "gifts", record.id,
          record.species, record.level, "Will you take\n{RAM}?", "MelanieText2" }
        rows[#rows + 1] = { "jump_if_false", "declined" }
        rows[#rows + 1] = { CMD.give, record.id, record.species, record.level }
        rows[#rows + 1] = { "jump_if_false", "done" }
        rows[#rows + 1] = { "set_flag", record.flag }
        rows[#rows + 1] = { "hide_object", record.mapId, record.object }
        rows[#rows + 1] = { "show_text", "MelanieText3" }
        rows[#rows + 1] = { "jump", "done" }
        rows[#rows + 1] = { "label", "declined" }
        rows[#rows + 1] = { "show_text", "MelanieText5" }
      end
      rows[#rows + 1] = { "label", "done" }
      return runnerHandler(rows)(game, overworld, npc, onDone)
    end
  end

  local function yellowCharmanderHandler(record, activeRun)
    return function(game, overworld, npc, onDone)
      local flags = game.save.flags or {}
      local rows = { { "face_player" } }
      if flags[record.flag] then
        rows[#rows + 1] = { "show_text", "_Route24DamianText4" }
      else
        rows[#rows + 1] = { CMD.ask, "gifts", record.id,
          record.species, record.level, "Will you take\n{RAM}?",
          "_Route24DamianText1" }
        rows[#rows + 1] = { "jump_if_false", "declined" }
        rows[#rows + 1] = { CMD.give, record.id, record.species, record.level }
        rows[#rows + 1] = { "jump_if_false", "done" }
        rows[#rows + 1] = { "set_flag", record.flag }
        rows[#rows + 1] = { "show_text", "_Route24DamianText2" }
        rows[#rows + 1] = { "jump", "done" }
        rows[#rows + 1] = { "label", "declined" }
        rows[#rows + 1] = { "show_text", "_Route24DamianText3" }
      end
      rows[#rows + 1] = { "label", "done" }
      return runnerHandler(rows)(game, overworld, npc, onDone)
    end
  end

  local function yellowSquirtleHandler(record, activeRun)
    return function(game, overworld, npc, onDone)
      local flags = game.save.flags or {}
      local inventory = game.save.inventory or {}
      local rows = { { "face_player" } }
      if flags[record.flag] then
        rows[#rows + 1] = { "show_text", "_OfficerJennyText5" }
      elseif not inventory.THUNDERBADGE then
        rows[#rows + 1] = { "show_text", "_OfficerJennyText1" }
      else
        rows[#rows + 1] = { CMD.ask, "gifts", record.id,
          record.species, record.level, "Will you take\n{RAM}?",
          "_OfficerJennyText2" }
        rows[#rows + 1] = { "jump_if_false", "declined" }
        rows[#rows + 1] = { CMD.give, record.id, record.species, record.level }
        rows[#rows + 1] = { "jump_if_false", "done" }
        rows[#rows + 1] = { "set_flag", record.flag }
        rows[#rows + 1] = { "show_text", "_OfficerJennyText3" }
        rows[#rows + 1] = { "jump", "done" }
        rows[#rows + 1] = { "label", "declined" }
        rows[#rows + 1] = { "show_text", "_OfficerJennyText4" }
      end
      rows[#rows + 1] = { "label", "done" }
      return runnerHandler(rows)(game, overworld, npc, onDone)
    end
  end

  local function fossilHandler(activeRun, ui)
    return function(game, overworld, npc, onDone)
      local save = game.save
      local flags = save.flags or {}
      save.flags = flags
      local text = game.data.text or {}
      local function pushText(value, done, opts)
        game.stack:push(ui.TextBox.new(game, value, done, opts))
      end
      local function resolved(record)
        return offer(activeRun, "gifts", record.id,
          record.species, record.level)
      end
      local function comeAgain()
        pushText(text._CinnabarLabFossilRoomScientist1ComeAgainText
          or "Aiyah! You come\nagain!", onDone)
      end

      if flags.EVENT_GAVE_FOSSIL_TO_LAB then
        if flags.EVENT_LAB_STILL_REVIVING_FOSSIL then
          pushText(text._CinnabarLabFossilRoomScientist1GoForAWalkText
            or "I take a little\ntime!\fYou go for walk a\nlittle while!",
            onDone)
          return
        end

        local source = save.labFossilMon
        local record = fossilBySpecies[source]
        if not record then
          -- A foreign mod may put another valid species in the fossil slot.
          -- Leave that award under the engine's normal gift command.
          local rows = {
            { "give_pokemon", source, 30 },
            { "jump_if_false", "full" },
            { CMD.finishFossil },
            { "jump", "done" },
            { "label", "full" },
            { "show_text", "_BoxIsFullText" },
            { "label", "done" },
          }
          return runnerHandler(rows)(game, overworld, npc, onDone)
        end

        local mapped = resolved(record)
        flags.EVENT_LAB_HANDING_OVER_FOSSIL_MON = true
        pushText(fillText(
          text._CinnabarLabFossilRoomScientist1FossilIsBackToLifeText
            or "Where were you?\fYour fossil is\nback to life!"
              .. "\fIt was {RAM:x}\nlike I think!",
          {
            player = save.player and save.player.name,
            species = speciesName(game, mapped.species),
          }), function()
            runnerHandler({
              { CMD.give, record.id, record.species, record.level },
              { "jump_if_false", "full" },
              { CMD.finishFossil },
              { "jump", "done" },
              { "label", "full" },
              { "show_text", "_BoxIsFullText" },
              { "label", "done" },
            })(game, overworld, npc, onDone)
          end)
        return
      end

      pushText(text._CinnabarLabFossilRoomScientist1Text
        or "Hiya!\fI am important\ndoctor!\fI study here rare"
          .. "\nPOKEMON fossils!\fYou! Have you a\nfossil for me?",
        function()
          local items = {}
          for _, fossilItem in ipairs({
            "DOME_FOSSIL", "HELIX_FOSSIL", "OLD_AMBER",
          }) do
            local record = fossilByItem[fossilItem]
            if record and (save.inventory[fossilItem] or 0) > 0 then
              items[#items + 1] = {
                label = itemName(game, fossilItem),
                value = record,
              }
            end
          end
          if #items == 0 then
            pushText(text._CinnabarLabFossilRoomScientist1NoFossilsText
              or "No! Is too bad!", onDone)
            return
          end

          local list
          list = ui.ListMenu.new(game, "FOSSIL", items, {
            onCancel = comeAgain,
            onChoose = function(item)
              game.stack:pop()
              local record = item.value
              local mapped = resolved(record)
              local values = {
                player = save.player and save.player.name,
                item = itemName(game, record.fossilItem),
                species = speciesName(game, mapped.species),
              }
              pushText(fillText(
                text._CinnabarLabFossilRoomScientist1SeesFossilText
                  or "Oh! That is\n{RAM:wNameBuffer}!\fIt is fossil of"
                    .. "\n{RAM:wStringBuffer}, a\nPOKEMON that is"
                    .. "\nalready extinct!\fMy Resurrection Machine"
                    .. "\nwill make that\nPOKEMON live again!",
                values), nil, {
                  choice = function(yes)
                    if not yes then comeAgain() return end
                    local count = save.inventory[record.fossilItem] or 0
                    if count <= 1 then
                      save.inventory[record.fossilItem] = nil
                    else
                      save.inventory[record.fossilItem] = count - 1
                    end
                    -- Keep the vanilla source in the quest state.  The
                    -- saved randomizer mapping resolves it at handover,
                    -- while removing the mod safely restores vanilla.
                    save.labFossilMon = record.species
                    flags.EVENT_GAVE_FOSSIL_TO_LAB = true
                    flags.EVENT_LAB_STILL_REVIVING_FOSSIL = true
                    pushText(fillText(
                      text._CinnabarLabFossilRoomScientist1TakesFossilText
                        or "So! You hurry and\ngive me that!"
                          .. "\f{PLAYER} handed\nover {RAM:wNameBuffer}!",
                      values), function()
                        pushText(
                          text._CinnabarLabFossilRoomScientist1GoForAWalkText2
                            or "I take a little\ntime!"
                              .. "\fYou go for walk a\nlittle while!",
                          onDone)
                      end)
                  end,
                })
            end,
          })
          game.stack:push(list)
        end)
    end
  end

  local function contributionMap(activeRun, ui, version)
    activeRun = activeRun or function() return nil end
    local output = {}
    local function mapRecord(mapId)
      output[mapId] = output[mapId] or { priority = 100, talk = {} }
      return output[mapId]
    end
    for _, record in ipairs(Catalog.statics) do
      if record.style == "snorlax" then
        output[record.mapId] = snorlaxContribution(record)
      else
        mapRecord(record.mapId).talk[record.talkKey] = staticRows(record)
      end
    end
    for _, record in ipairs(Catalog.giftsFor(version)) do
      local handler
      if record.style == "eevee" then
        handler = eeveeRows(record)
      elseif record.style == "sale" then
        handler = saleHandler(record, activeRun)
      elseif record.style == "dojo" then
        handler = dojoHandler(record, activeRun)
      elseif record.style == "lapras" then
        handler = laprasHandler(record, activeRun)
      elseif record.style == "fossil" and ui then
        handler = fossilHandler(activeRun, ui)
      elseif record.style == "yellow_bulbasaur" then
        handler = yellowBulbasaurHandler(record, activeRun)
      elseif record.style == "yellow_charmander" then
        handler = yellowCharmanderHandler(record, activeRun)
      elseif record.style == "yellow_squirtle" then
        handler = yellowSquirtleHandler(record, activeRun)
      end
      if handler then
        mapRecord(record.mapId).talk[record.talkKey] = handler
      end
    end
    return output
  end

  function Compat.install(mod, activeRun)
    assert(type(activeRun) == "function", "active-run provider is required")
    local commands = mod.content.commands
    local show = assert(commands:get("show_text"), "show_text command missing")
    local ask = assert(commands:get("ask"), "ask command missing")
    local cry = assert(commands:get("play_cry"), "play_cry command missing")
    local battle = assert(
      commands:get("static_battle"), "static_battle command missing")
    local give = assert(
      commands:get("give_pokemon"), "give_pokemon command missing")

    commands:register(CMD.show,
      function(ctx, category, id, source, level, text, vanillaText)
        local resolved, mapped =
          offer(activeRun, category, id, source, level)
        return show(ctx,
          (not mapped and vanillaText) or text,
          { RAM = resolved.species })
      end)
    commands:register(CMD.ask,
      function(ctx, category, id, source, level, text, vanillaText)
        local resolved, mapped =
          offer(activeRun, category, id, source, level)
        return ask(ctx,
          (not mapped and vanillaText) or text,
          { RAM = resolved.species })
      end)
    commands:register(CMD.cry,
      function(ctx, category, id, source, level)
        local resolved = offer(activeRun, category, id, source, level)
        return cry(ctx, resolved.species)
      end)
    commands:register(CMD.battle,
      function(ctx, id, source, level, flag)
        local resolved = offer(
          activeRun, "staticEncounters", id, source, level)
        return battle(ctx, resolved.species, resolved.level, flag)
      end)
    commands:register(CMD.give,
      function(ctx, id, source, level)
        local resolved = offer(activeRun, "gifts", id, source, level)
        local previous = ctx.randomizerGiftResolved
        ctx.randomizerGiftResolved = true
        local result = give(ctx, resolved.species, resolved.level)
        ctx.randomizerGiftResolved = previous
        return result
      end)
    commands:register(CMD.finishFossil, function(ctx)
      local flags = ctx.save.flags or {}
      ctx.save.labFossilMon = nil
      flags.EVENT_GAVE_FOSSIL_TO_LAB = nil
      flags.EVENT_LAB_STILL_REVIVING_FOSSIL = nil
      flags.EVENT_LAB_HANDING_OVER_FOSSIL_MON = nil
    end)

    mod.events:on("pokemon.before_give", function(gift)
      local record = matchingGift(gift)
      if not record then return end
      local resolved, mapped = offer(activeRun, "gifts",
        record.id, record.species, record.level)
      if not mapped then return end
      gift.species = resolved.species
      gift.level = resolved.level
      gift.randomizerGiftId = record.id
    end)

    local maps = mod.content.maps
    local yellow = type(maps) == "table" and type(maps.get) == "function"
      and maps:get("CERULEAN_MELANIES_HOUSE") ~= nil
    local contributions = contributionMap(
      activeRun, mod.ui, yellow and "yellow" or "red")
    for mapId, contribution in pairs(contributions) do
      mod.content.map_scripts:register(mapId, contribution)
    end
    return contributions
  end

  Compat.commands = CMD
  Compat.contributions = contributionMap
  return Compat
end
