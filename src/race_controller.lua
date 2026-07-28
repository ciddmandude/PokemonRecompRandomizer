-- Runtime race-state persistence, unlock policies, and spoiler actions.
return function(Constants, SaveState, Crypto, Spoiler)
  local Controller = {}

  local function entropy(game, extra)
    local random = ""
    if love and love.math and type(love.math.random) == "function" then
      random = tostring(love.math.random()) .. ":" .. tostring(love.math.random())
    end
    return table.concat({
      tostring(os.time()), tostring(os.clock()), tostring(game),
      tostring(extra or ""), random,
    }, "\0")
  end

  local function namespace(game)
    return type(game) == "table" and type(game.save) == "table"
      and type(game.save.modData) == "table"
      and game.save.modData[Constants.MOD_ID] or nil
  end

  local function persist(game, lifecycle, mutate, write)
    local current = namespace(game)
    if type(current) ~= "table" then return nil, "no active run" end
    local candidate = SaveState.clone(current)
    local changed, message = mutate(candidate)
    if not changed then return false, message end
    local stamped, errors = SaveState.stamp(candidate)
    if not stamped then
      return nil, errors[1] and errors[1].message
        or "race state validation failed"
    end
    game.save.modData[Constants.MOD_ID] = stamped
    lifecycle:replaceActive(stamped)
    if write and game.writeSave then game:writeSave() end
    return true, message
  end

  local function unlockFor(game, lifecycle, event)
    return persist(game, lifecycle, function(run)
      local race = run.race
      if type(race) ~= "table" or not race.enabled or race.unlocked
          or race.unlockPolicy ~= event then
        return false
      end
      race.unlocked = true
      return true, "SPOILERS UNLOCKED"
    end, event == "credits")
  end

  local function prompt(mod, game, title, done)
    game.stack:push(mod.ui.NamingScreen.new(game, {
      title = title,
      maxLen = 32,
      default = "",
      onDone = function(value)
        if value ~= nil then done(value) end
      end,
    }))
  end

  local function exportAction(mod, lifecycle)
    return function(game)
      local run = lifecycle:activeRun()
      if type(run) ~= "table" then return "NO ACTIVE RUN" end
      local function finish(passphrase)
        local material = entropy(game, passphrase)
        local result, err = Spoiler.export(run, {
          passphrase = passphrase,
          entropy = material,
        })
        if not result then
          mod.log:error("spoiler export failed: %s", tostring(err))
          return "EXPORT FAILED"
        end
        if result.encrypted then
          persist(game, lifecycle, function(candidate)
            candidate.race.encryptedSpoilerDigest = result.digest
            if candidate.race.unlockPolicy == "passphrase"
                and not candidate.race.passphraseVerifier then
              local salt = Crypto.randomMaterial(material, "verifier")
              candidate.race.passphraseSalt = salt
              candidate.race.passphraseVerifier =
                Crypto.passphraseVerifier(passphrase, salt)
            end
            return true
          end, true)
        end
        mod.ui.push(game, Constants.REVIEW_SCREEN_ID, {
          title = result.encrypted and "RACE EXPORT" or "SPOILER EXPORT",
          lines = {
            result.encrypted and "ENCRYPTED" or "PLAINTEXT",
            result.path,
          },
        })
        return result.encrypted and "ENCRYPTED EXPORTED"
          or "SPOILER EXPORTED"
      end
      if Spoiler.isLocked(run) then
        prompt(mod, game, "EXPORT PASSPHRASE?", finish)
        return "ENTER PASSPHRASE"
      end
      return finish(nil)
    end
  end

  local function unlockAction(mod, lifecycle)
    return function(game)
      local run = lifecycle:activeRun()
      if type(run) ~= "table" or type(run.race) ~= "table"
          or not run.race.enabled then return "NOT A RACE RUN" end
      if run.race.unlocked then return "ALREADY UNLOCKED" end
      if run.race.unlockPolicy ~= "passphrase" then
        return "AUTOMATIC UNLOCK"
      end
      if not run.race.passphraseSalt or not run.race.passphraseVerifier then
        return "EXPORT ENCRYPTED LOG FIRST"
      end
      prompt(mod, game, "UNLOCK PASSPHRASE?", function(value)
        local ok, verifier = pcall(
          Crypto.passphraseVerifier, value, run.race.passphraseSalt)
        if not ok or verifier ~= run.race.passphraseVerifier then return end
        local changed = persist(game, lifecycle, function(candidate)
          if candidate.race.unlocked then return false end
          candidate.race.unlocked = true
          return true
        end, true)
        if changed then
          mod.ui.push(game, Constants.REVIEW_SCREEN_ID, {
            title = "RACE MODE",
            lines = { "SPOILERS UNLOCKED", "THIS CANNOT BE UNDONE." },
          })
        end
      end)
      return "ENTER PASSPHRASE"
    end
  end

  function Controller.install(mod, lifecycle)
    local commands = mod.content.commands
    local base = assert(commands:get("record_hall_of_fame"),
      "record_hall_of_fame command missing")
    commands:override("record_hall_of_fame", function(ctx, ...)
      unlockFor(ctx.game, lifecycle, "hall_of_fame")
      local results = { base(ctx, ...) }
      unlockFor(ctx.game, lifecycle, "credits")
      return unpack(results)
    end)
    return {
      export_spoiler_log = exportAction(mod, lifecycle),
      unlock_spoilers = unlockAction(mod, lifecycle),
    }
  end

  Controller.unlockFor = unlockFor
  Controller.entropy = entropy
  return Controller
end
