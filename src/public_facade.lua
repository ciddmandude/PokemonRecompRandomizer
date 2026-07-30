-- Read-only export proxies. The proxy contains no raw fields, so ordinary
-- assignment cannot replace an internal function on Lua 5.1.
local Facade = {}

local function clone(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local output = {}
  seen[value] = output
  for key, child in pairs(value) do
    output[clone(key, seen)] = clone(child, seen)
  end
  return output
end

local function readonly(fields, name)
  local backing = {}
  for key, value in pairs(fields or {}) do backing[key] = value end
  return setmetatable({}, {
    __index = backing,
    __newindex = function(_, key)
      error(("%s is read-only; cannot replace %s")
        :format(name or "public facade", tostring(key)), 2)
    end,
    __metatable = "read-only",
  })
end

local function pack(...)
  return { n = select("#", ...), ... }
end

local function isolatedCall(callback, ...)
  local results = pack(callback(...))
  for index = 1, results.n do
    results[index] = clone(results[index])
  end
  return unpack(results, 1, results.n)
end

local function capture(callback)
  return function(...)
    return isolatedCall(callback, ...)
  end
end

local function dataFacade(fields, name)
  assert(type(fields) == "table", "public facade fields are required")
  local captured = {}
  for key, value in pairs(fields) do
    captured[key] = type(value) == "function"
      and capture(value) or clone(value)
  end
  return readonly(captured, name)
end

function Facade.generator(generator)
  assert(type(generator) == "table", "generator table is required")
  local generate = assert(generator.generate)
  local validate = assert(generator.validate)
  local emptyResult = assert(generator.emptyResult)
  local normalizeSeed = assert(generator.normalizeSeed)
  local hashSeed = assert(generator.hashSeed)
  local newStream = assert(generator.newStream)
  local stableSort = assert(generator.stableSort)
  local sortedKeys = assert(generator.sortedKeys)
  local buildSpeciesManifest = assert(generator.buildSpeciesManifest)
  local speciesCandidates = assert(generator.speciesCandidates)
  return readonly({
    interfaceVersion = generator.interfaceVersion,
    algorithmVersion = generator.algorithmVersion,
    available = generator.available,
    foundationAvailable = generator.foundationAvailable,
    hashVersion = generator.hashVersion,
    prngVersion = generator.prngVersion,
    generate = function(...) return generate(...) end,
    validate = function(...) return validate(...) end,
    emptyResult = function(...) return emptyResult(...) end,
    normalizeSeed = function(...) return normalizeSeed(...) end,
    hashSeed = function(...) return hashSeed(...) end,
    newStream = function(...) return newStream(...) end,
    stableSort = function(...) return stableSort(...) end,
    sortedKeys = function(...) return sortedKeys(...) end,
    buildSpeciesManifest =
      function(...) return buildSpeciesManifest(...) end,
    speciesCandidates = function(...) return speciesCandidates(...) end,
  }, "randomizer generator facade")
end

function Facade.contracts(contracts)
  assert(type(contracts) == "table", "contracts table is required")
  local categoryKeys = assert(contracts.categoryKeys)
  local mappingKeys = assert(contracts.mappingKeys)
  local validateRequest = assert(contracts.validateGenerationRequest)
  local validateResult = assert(contracts.validateGenerationResult)
  return readonly({
    categoryKeys = function(...) return categoryKeys(...) end,
    mappingKeys = function(...) return mappingKeys(...) end,
    validateGenerationRequest =
      function(...) return validateRequest(...) end,
    validateGenerationResult =
      function(...) return validateResult(...) end,
  }, "randomizer contracts facade")
end

function Facade.species(fields)
  return dataFacade(fields, "randomizer species facade")
end

function Facade.save(fields)
  return dataFacade(fields, "randomizer save facade")
end

function Facade.preferences(fields)
  return dataFacade(fields, "randomizer preferences facade")
end

function Facade.spoilers(fields)
  return dataFacade(fields, "randomizer spoilers facade")
end

Facade.readonly = readonly
return Facade
