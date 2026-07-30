-- Saved-run spoiler access, in-game viewing, and explicit file export.
return function(Constants, Spoiler)
  local Controller = {}

  local function access(run)
    if type(run) ~= "table" then return nil, "no active run" end
    if not run.enabled then return nil, "active run is not randomized" end
    if type(run.settings) ~= "table"
        or run.settings.generate_spoiler_log ~= "on" then
      return nil, "spoiler log is disabled for this run"
    end
    return run
  end

  local function lines(text)
    local output = {}
    for line in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
      output[#output + 1] = line
    end
    return output
  end

  local function unavailable(mod, game, err)
    local message = err == "spoiler log is disabled for this run"
      and "SPOILERS DISABLED" or "NO ACTIVE RUN"
    mod.ui.push(game, Constants.REVIEW_SCREEN_ID, {
      title = "SPOILER ACCESS",
      lines = {
        message,
        message == "SPOILERS DISABLED"
          and "ENABLE SPOILER LOG BEFORE STARTING A NEW GAME."
          or "LOAD OR START A RANDOMIZED GAME.",
      },
    })
    return message
  end

  function Controller.canAccess(run)
    local allowed, err = access(run)
    return allowed ~= nil, err
  end

  function Controller.text(run)
    local allowed, err = access(run)
    if not allowed then return nil, err end
    return Spoiler.text(allowed)
  end

  function Controller.lines(run)
    local text, err = Controller.text(run)
    if not text then return nil, err end
    return lines(text)
  end

  function Controller.export(run, filesystem)
    local allowed, err = access(run)
    if not allowed then return nil, err end
    return Spoiler.export(allowed, { filesystem = filesystem })
  end

  function Controller.viewAction(mod, lifecycle)
    return function(game)
      local content, err = Controller.lines(lifecycle:activeRun())
      if not content then return unavailable(mod, game, err) end
      mod.ui.push(game, Constants.REVIEW_SCREEN_ID, {
        title = "SPOILER LOG",
        lines = content,
      })
      return "SPOILER LOG"
    end
  end

  function Controller.exportAction(mod, lifecycle)
    return function(game)
      local result, err = Controller.export(lifecycle:activeRun())
      if not result then
        if err == "spoiler log is disabled for this run"
            or err == "no active run"
            or err == "active run is not randomized" then
          return unavailable(mod, game, err)
        end
        mod.log:error("spoiler export failed: %s", tostring(err))
        return "EXPORT FAILED"
      end
      mod.ui.push(game, Constants.REVIEW_SCREEN_ID, {
        title = "SPOILER EXPORT",
        lines = { "SPOILER EXPORTED", result.path },
      })
      return "SPOILER EXPORTED"
    end
  end

  return Controller
end
