-- Standalone contract test:
--   lua tests/scaffold_test.lua
-- Run from the repository root.
local function loadFactory(path, ...)
  local chunk, err = loadfile(path)
  assert(chunk, err)
  local value = chunk()
  if type(value) == "function" then return value(...) end
  return value
end

local Constants = loadFactory("src/constants.lua")
local Contracts = loadFactory("src/contracts.lua", Constants)
local Generator = loadFactory("src/generator.lua", Constants, Contracts)

assert(Constants.MOD_API == 2)
assert(Constants.MOD_ID == "pokemon_randomizer")
assert(Generator.available == false)

local request = {
  contractVersion = 1,
  seed = { canonical = "MILESTONE ONE" },
  settings = {},
  species = {
    { id = "BULBASAUR" },
    { id = "CHARMANDER" },
    { id = "SQUIRTLE" },
  },
  sources = {},
}

local valid, errors = Generator.validate(request)
assert(valid, errors[1] and errors[1].message)

local result, unavailable = Generator.generate(request)
assert(result == nil)
assert(unavailable.code == "GENERATOR_UNAVAILABLE")

local invalid = {
  contractVersion = 1,
  seed = { canonical = "" },
  settings = {},
  species = { { id = "MEW" }, { id = "MEW" } },
}
valid, errors = Generator.validate(invalid)
assert(not valid)
assert(#errors == 2)

local empty = Generator.emptyResult()
valid, errors = Contracts.validateGenerationResult(empty)
assert(valid, errors[1] and errors[1].message)

io.write("scaffold_test: ok\n")
