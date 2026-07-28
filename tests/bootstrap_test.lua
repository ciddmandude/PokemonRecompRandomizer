-- Headless entry/bootstrap integration test with a minimal mod API-2 stub.
local callbacks = {}
local logs = {}
local saveBucket = {}
local options = {}

local mod = {
  id = "pokemon_randomizer",
  version = "0.3.0",
  path = ".",
  manifest = { api = 2 },
  content = {
    pokemon = {
      each = function()
        local yielded = false
        return function()
          if yielded then return nil end
          yielded = true
          return "TESTMON", {
            id = "TESTMON",
            dex = 1001,
            baseStats = {
              hp = 50, attack = 50, defense = 50, speed = 50, special = 50,
            },
            types = { "NORMAL" },
            growthRate = "MEDIUM",
            level1Moves = {},
            learnset = {},
            evolutions = {},
            spriteFront = "front.png",
            spriteBack = "back.png",
          }
        end
      end,
    },
  },
  exports = {},
  events = {
    on = function() return function() end end,
    once = function(_, name, callback)
      callbacks[name] = callback
      return function() callbacks[name] = nil end
    end,
  },
  hooks = {
    wrap = function() return function() end end,
  },
  save = {
    get = function(_, key, default)
      local value = saveBucket[key]
      if value == nil then return default end
      return value
    end,
    set = function(_, key, value) saveBucket[key] = value end,
  },
  options = {
    define = function() end,
    get = function(_, key) return options[key] end,
  },
  log = {
    info = function(_, format, ...)
      logs[#logs + 1] = format:format(...)
    end,
    warn = function() end,
    error = function() end,
  },
}

function mod:read(relative)
  local file, err = io.open(relative, "rb")
  if not file then return nil, err end
  local contents = file:read("*a")
  file:close()
  return contents
end

local entry = assert(loadfile("main.lua"))()
assert(type(entry) == "function")
entry(mod)

assert(mod.exports.contractVersion == 1)
assert(mod.exports.algorithmVersion == "1.0.0-dev")
assert(mod.exports.hashVersion == "fnv1a32x4-v1")
assert(mod.exports.prngVersion == "xoshiro128ss-v1")
assert(mod.exports.generator.foundationAvailable == true)
assert(type(mod.exports.registerSpeciesMeta) == "function")
assert(mod.exports.species.manifestVersion == 1)
assert(type(callbacks["mods.loaded"]) == "function")

mod.exports.registerSpeciesMeta("TESTMON", { legendary = true })
local manifest = mod.exports.species.buildManifest({ poolMode = "merged" })
assert(manifest.byId.TESTMON.legendary == true)
assert(not mod.exports.species.metadataFrozen())

local canonical = mod.exports.generator.normalizeSeed(" bootstrap  test ")
assert(canonical == "BOOTSTRAP TEST")
local stream = mod.exports.generator.newStream(canonical, "starters")
assert(type(stream:nextU32()) == "number")

callbacks["mods.loaded"]()
assert(#logs == 1)
assert(logs[1]:match("milestone 3 ready"))
assert(mod.exports.species.metadataFrozen())
local late = pcall(function()
  mod.exports.registerSpeciesMeta("LATE_MON", { legendary = false })
end)
assert(not late)

io.write("bootstrap_test: ok\n")
