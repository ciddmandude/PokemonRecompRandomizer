-- Pokémon Gen 1 Randomizer entry point.
--
-- This file only assembles milestone-1 modules. Gameplay hooks are
-- intentionally deferred until their deterministic implementations exist.
return function(mod)
  local function loadModule(relative, ...)
    local source, readErr = mod:read(relative)
    assert(source, ("cannot read %s: %s"):format(relative, tostring(readErr)))

    local chunkName = "@" .. mod.path .. "/" .. relative
    local compile = loadstring or load
    local chunk, compileErr = compile(source, chunkName)
    assert(chunk, ("cannot compile %s: %s"):format(relative, tostring(compileErr)))

    local exported = chunk()
    if type(exported) == "function" then
      return exported(...)
    end
    return exported
  end

  local Constants = loadModule("src/constants.lua")
  local Contracts = loadModule("src/contracts.lua", Constants)
  local Generator = loadModule("src/generator.lua", Constants, Contracts)
  local Bootstrap = loadModule("src/bootstrap.lua", Constants, Contracts, Generator)

  return Bootstrap.start(mod)
end
