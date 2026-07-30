-- Plaintext spoiler generation and manual export actions.
return function(Constants, Spoiler)
  local Controller = {}

  function Controller.export(run, filesystem)
    if type(run) ~= "table" then return nil, "no active run" end
    return Spoiler.export(run, { filesystem = filesystem })
  end

  function Controller.exportAction(mod, lifecycle)
    return function(game)
      local result, err = Controller.export(lifecycle:activeRun())
      if not result then
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

  function Controller.autoExport(mod, run)
    if type(run) ~= "table" or not run.enabled
        or type(run.settings) ~= "table"
        or run.settings.generate_spoiler_log ~= "on" then
      return false
    end
    local result, err = Controller.export(run)
    if not result then
      mod.log:error("automatic spoiler generation failed: %s", tostring(err))
      return nil, err
    end
    mod.log:info("spoiler log generated: %s", result.path)
    return true, result
  end

  return Controller
end
