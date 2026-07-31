-- Stock-v0.1.30 compatibility seam for Oak's Lab.
--
-- API-2 map_scripts composition lets the mod replace only the three starter
-- ball talk handlers. The rest of Oak's Lab remains engine-owned.
return function(StarterOffer)
  local StarterCompat = {}

  local OFFERS = {
    LEFT = {
      slotId = "LEFT",
      askText = "_OaksLabYouWantCharmanderText",
      species = "CHARMANDER",
      level = 5,
      choseFlag = "EVENT_CHOSE_CHARMANDER",
      ballObject = "OAKSLAB_CHARMANDER_POKE_BALL",
      rivalBall = "OAKSLAB_SQUIRTLE_POKE_BALL",
    },
    MIDDLE = {
      slotId = "MIDDLE",
      askText = "_OaksLabYouWantSquirtleText",
      species = "SQUIRTLE",
      level = 5,
      choseFlag = "EVENT_CHOSE_SQUIRTLE",
      ballObject = "OAKSLAB_SQUIRTLE_POKE_BALL",
      rivalBall = "OAKSLAB_BULBASAUR_POKE_BALL",
    },
    RIGHT = {
      slotId = "RIGHT",
      askText = "_OaksLabYouWantBulbasaurText",
      species = "BULBASAUR",
      level = 5,
      choseFlag = "EVENT_CHOSE_BULBASAUR",
      ballObject = "OAKSLAB_BULBASAUR_POKE_BALL",
      rivalBall = "OAKSLAB_CHARMANDER_POKE_BALL",
    },
  }

  local OFFER_BY_BALL = {}
  local BALL_X = {
    OAKSLAB_CHARMANDER_POKE_BALL = 6,
    OAKSLAB_SQUIRTLE_POKE_BALL = 7,
    OAKSLAB_BULBASAUR_POKE_BALL = 8,
  }
  local YELLOW = {
    slotId = "YELLOW",
    species = "PIKACHU",
    level = 5,
    rivalSpecies = "EEVEE",
    choseFlag = "EVENT_CHOSE_PIKACHU",
    ballObject = "YELLOW_STARTER_GIFT",
    rivalBall = "OAKSLAB_EEVEE_POKE_BALL",
  }
  for _, offer in pairs(OFFERS) do
    OFFER_BY_BALL[offer.ballObject] = offer
  end

  local function copy(value)
    local output = {}
    for key, child in pairs(value) do output[key] = child end
    return output
  end

  local function validForLab(offer, game)
    local valid = StarterOffer.validate(offer)
    return valid
      and type(game) == "table"
      and type(game.data) == "table"
      and type(game.data.pokemon) == "table"
      and game.data.pokemon[offer.species] ~= nil
      and BALL_X[offer.ballObject] ~= nil
      and OFFER_BY_BALL[offer.rivalBall] ~= nil
  end

  local function resolve(base, game, activeRun)
    local resolved = StarterOffer.resolve(copy(base), {
      slotId = base.slotId,
      mapId = "OAKS_LAB",
      save = game and game.save,
      game = game,
    }, activeRun)
    if not validForLab(resolved, game) then return copy(base) end
    return resolved
  end

  function StarterCompat.rows(base, game, activeRun)
    local offer = resolve(base, game, activeRun)
    local rival = resolve(OFFER_BY_BALL[offer.rivalBall], game, activeRun)
    local askText = offer.species == base.species
        and (offer.askText or base.askText)
      or "So! You want\n{RAM}?"
    return {
      { "check_flag", "EVENT_GOT_STARTER" },
      { "jump_if_true", "blocked" },
      { "check_flag", "EVENT_FOLLOWED_OAK_INTO_LAB" },
      { "jump_if_false", "blocked" },
      { "push_screen", "DexEntryMenu",
        { species = offer.species, forceOwned = true } },
      { "ask", askText, { RAM = offer.species } },
      { "jump_if_false", "done" },
      { "show_text", "_OaksLabReceivedMonText",
        { RAM = offer.species } },
      { "give_pokemon", offer.species, offer.level },
      { "set_flag", "EVENT_GOT_STARTER" },
      { "set_flag", offer.choseFlag },
      { "hide_object", "OAKS_LAB", offer.ballObject },
      { "move_npc_to", 1, BALL_X[offer.rivalBall], 4 },
      { "face_object", 1, "up" },
      { "show_text", "_OaksLabRivalIllTakeThisOneText" },
      { "hide_object", "OAKS_LAB", offer.rivalBall },
      { "show_text", "_OaksLabRivalReceivedMonText",
        { RAM = rival.species } },
      { "jump", "done" },
      { "label", "blocked" },
      { "show_text", "_OaksLabThoseArePokeBallsText" },
      { "label", "done" },
    }
  end

  local function handler(base, activeRun)
    return function(game, overworld, npc, onDone)
      if type(overworld) ~= "table"
          or type(overworld.runner) ~= "table"
          or type(overworld.runner.run) ~= "function" then
        if onDone then onDone() end
        return
      end
      overworld.runner:run(
        StarterCompat.rows(base, game, activeRun()), {
          npc = npc,
          onDone = onDone,
        })
    end
  end

  local function yellowResolved(game, activeRun)
    local run = activeRun()
    local saved = type(run) == "table" and type(run.mappings) == "table"
      and type(run.mappings.starters) == "table"
      and run.mappings.starters.YELLOW or nil
    if type(saved) == "table"
        and type(saved.species) == "string"
        and type(saved.rivalSpecies) == "string"
        and type(saved.level) == "number"
        and type(game) == "table" and type(game.data) == "table"
        and type(game.data.pokemon) == "table"
        and game.data.pokemon[saved.species]
        and game.data.pokemon[saved.rivalSpecies] then
      return saved
    end
    return YELLOW
  end

  local function yellowHandler(activeRun)
    return function(game, overworld, npc, onDone)
      if type(overworld) ~= "table"
          or type(overworld.runner) ~= "table"
          or type(overworld.runner.run) ~= "function" then
        if onDone then onDone() end
        return
      end
      local flags = game.save.flags or {}
      if flags.EVENT_GOT_STARTER then
        if onDone then onDone() end
        return
      end
      if not flags.EVENT_OAK_ASKED_TO_CHOOSE_MON then
        overworld.runner:run({
          { "show_text", "_OaksLabThatsAPokeball" },
        }, { npc = npc, onDone = onDone })
        return
      end

      local offer = yellowResolved(game, activeRun)
      local rivalIndex, oakIndex = 1, 3
      local px, py = overworld.player.cellX, overworld.player.cellY
      local rows = { { "emote", rivalIndex, "shock" } }
      if py == 4 then
        rows[#rows + 1] = { "walk_npc", rivalIndex,
          { "down", "right", "right", "right" }, { wait = false } }
        rows[#rows + 1] = { "face_player_dir", "left" }
        rows[#rows + 1] = { "move_player", "right", 2 }
        rows[#rows + 1] = { "wait", 40 }
      else
        rows[#rows + 1] = { "move_npc_to", rivalIndex, 7, 4 }
      end
      rows[#rows + 1] = { "face_object", rivalIndex, "up" }
      rows[#rows + 1] = { "hide_object", "OAKS_LAB",
        "OAKSLAB_EEVEE_POKE_BALL" }
      rows[#rows + 1] = { "set_field", "rivalStarter", 1 }
      for index = 1, 5 do
        rows[#rows + 1] = { "show_text",
          "_OaksLabRivalTakesText" .. index,
          { RAM = offer.rivalSpecies } }
        if index == 1 then
          rows[#rows + 1] = { "play_sound", "Get_Key_Item" }
        end
      end
      if py == 4 then
        rows[#rows + 1] = { "walk_npc", "player",
          { "left", "down", "left", "left", "left", "up", "up" } }
      elseif px ~= 5 or py ~= 3 then
        rows[#rows + 1] = { "walk_npc", "player", { "left" } }
      end
      rows[#rows + 1] = { "face_player_dir", "up" }
      rows[#rows + 1] = { "face_object", oakIndex, "down" }
      rows[#rows + 1] = { "show_text", "_OaksLabOakGivesText",
        { RAM = offer.species } }
      rows[#rows + 1] = { "play_sound", "Get_Key_Item" }
      rows[#rows + 1] = { "show_text", "_OaksLabReceivedText",
        { RAM = offer.species } }
      rows[#rows + 1] = { "give_pokemon", offer.species, offer.level, true }
      rows[#rows + 1] = { "set_flag", "EVENT_GOT_STARTER" }
      rows[#rows + 1] = { "set_flag", "EVENT_CHOSE_PIKACHU" }
      overworld.runner:run(rows, { npc = npc, onDone = onDone })
    end
  end

  function StarterCompat.contribution(activeRun)
    assert(type(activeRun) == "function",
      "active-run provider is required")
    return {
      priority = 100,
      talk = {
        TEXT_OAKSLAB_CHARMANDER_POKE_BALL =
          handler(OFFERS.LEFT, activeRun),
        TEXT_OAKSLAB_SQUIRTLE_POKE_BALL =
          handler(OFFERS.MIDDLE, activeRun),
        TEXT_OAKSLAB_BULBASAUR_POKE_BALL =
          handler(OFFERS.RIGHT, activeRun),
        TEXT_OAKSLAB_EEVEE_POKE_BALL = yellowHandler(activeRun),
      },
    }
  end

  StarterCompat.offers = OFFERS
  StarterCompat.yellowOffer = YELLOW
  StarterCompat.ballX = BALL_X
  return StarterCompat
end
