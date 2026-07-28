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
      { "jump_if_true", 20 },
      { "check_flag", "EVENT_FOLLOWED_OAK_INTO_LAB" },
      { "jump_if_false", 20 },
      { "push_screen", "DexEntryMenu",
        { species = offer.species, forceOwned = true } },
      { "ask", askText, { RAM = offer.species } },
      { "jump_if_false", 21 },
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
      { "jump", 21 },
      { "jump", 21 },
      { "show_text", "_OaksLabThoseArePokeBallsText" },
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
      },
    }
  end

  StarterCompat.offers = OFFERS
  StarterCompat.ballX = BALL_X
  return StarterCompat
end
