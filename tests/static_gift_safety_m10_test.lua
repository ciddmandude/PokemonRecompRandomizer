-- Remediation M10 label control-flow and award-safety fixtures.
local function loadFactory(path, ...)
  local chunk, err = loadfile(path)
  assert(chunk, err)
  local value = chunk()
  if type(value) == "function" then return value(...) end
  return value
end

local Catalog = loadFactory("src/static_gift_catalog.lua")
local Compat = loadFactory("src/static_gift_compat.lua", Catalog)
local CMD = Compat.commands

local active = {
  mappings = {
    gifts = {
      CELADON_EEVEE = { species = "TEST_EEVEE", level = 15 },
      MAGIKARP_SALE = { species = "TEST_FISH", level = 15 },
      DOJO_LEFT = { species = "TEST_DOJO", level = 15 },
      SILPH_LAPRAS = { species = "TEST_LAPRAS", level = 15 },
      FOSSIL_HELIX = { species = "TEST_FOSSIL", level = 15 },
    },
  },
}

local ui = {
  TextBox = {
    new = function(_, text, onDone, opts)
      return { text = text, onDone = onDone, opts = opts }
    end,
  },
  ListMenu = {
    new = function(_, title, items, opts)
      return { title = title, items = items, opts = opts }
    end,
  },
}
local contributions = Compat.contributions(function() return active end, ui)

local function validateLabels(rows)
  local labels = {}
  for index, row in ipairs(rows) do
    assert(type(row) == "table" and type(row[1]) == "string",
      "invalid script row " .. tostring(index))
    if row[1] == "label" then
      assert(type(row[2]) == "string" and not labels[row[2]],
        "invalid or duplicate label at row " .. tostring(index))
      labels[row[2]] = index
    end
  end
  for index, row in ipairs(rows) do
    if row[1] == "jump" or row[1] == "jump_if_true"
        or row[1] == "jump_if_false" then
      assert(type(row[2]) == "string",
        "numeric jump remains at row " .. tostring(index))
      assert(row[2] == "end" or labels[row[2]],
        "missing jump label " .. tostring(row[2]))
    end
  end
  return labels
end

local function interpret(rows, state)
  state = state or {}
  state.flags = state.flags or {}
  state.hidden = state.hidden or {}
  state.money = state.money or 0
  state.answer = state.answer ~= false
  state.giveSuccess = state.giveSuccess ~= false
  state.battleResult = state.battleResult or "win"
  state.awards = state.awards or 0
  state.doneCalls = state.doneCalls or 0
  local labels = validateLabels(rows)
  local lastCheck = false
  local pc, steps = 1, 0
  while pc <= #rows do
    steps = steps + 1
    assert(steps <= #rows * 4 + 4, "script did not terminate")
    local row, jump = rows[pc]
    local command = row[1]
    if command == "check_flag" then
      lastCheck = state.flags[row[2]] == true
    elseif command == "check_battle_result" then
      lastCheck = false
      for index = 2, #row do
        if row[index] == state.battleResult then lastCheck = true end
      end
    elseif command == CMD.ask or command == "ask" then
      lastCheck = state.answer
    elseif command == CMD.give or command == "give_pokemon" then
      lastCheck = state.giveSuccess
      if lastCheck then state.awards = state.awards + 1 end
    elseif command == "give_money" then
      state.money = state.money + row[2]
    elseif command == "set_flag" then
      state.flags[row[2]] = true
    elseif command == "hide_object" then
      state.hidden[tostring(row[2]) .. ":" .. tostring(row[3])] = true
    elseif command == CMD.finishFossil then
      state.labFossilMon = nil
      state.flags.EVENT_GAVE_FOSSIL_TO_LAB = nil
      state.flags.EVENT_LAB_STILL_REVIVING_FOSSIL = nil
      state.flags.EVENT_LAB_HANDING_OVER_FOSSIL_MON = nil
    elseif command == "jump" then
      jump = row[2]
    elseif command == "jump_if_true" and lastCheck then
      jump = row[2]
    elseif command == "jump_if_false" and not lastCheck then
      jump = row[2]
    end
    if jump == "end" then
      pc = math.huge
    elseif type(jump) == "string" then
      pc = assert(labels[jump])
    else
      pc = pc + 1
    end
  end
  state.doneCalls = state.doneCalls + 1
  assert(state.doneCalls == 1, "completion callback must run exactly once")
  return state
end

local function capture(handler, game)
  local rows
  local done = 0
  handler(game, {
    runner = {
      run = function(_, value, context)
        rows = value
        assert(type(context.onDone) == "function")
      end,
    },
  }, {}, function() done = done + 1 end)
  assert(rows, "handler did not submit a script")
  assert(done == 0, "handler completed before its script")
  return rows
end

local function game(flags, money)
  return { save = { flags = flags or {}, money = money or 0 } }
end

local sale = contributions.MT_MOON_POKECENTER.talk
  .TEXT_MTMOONPOKECENTER_MAGIKARP_SALESMAN
local dojo = contributions.FIGHTING_DOJO.talk
  .TEXT_FIGHTINGDOJO_HITMONLEE_POKE_BALL
local lapras = contributions.SILPH_CO_7F.talk
  .TEXT_SILPHCO7F_SILPH_WORKER_M1
local eevee = contributions.CELADON_MANSION_ROOF_HOUSE.talk
  .TEXT_CELADONMANSION_ROOF_HOUSE_EEVEE_POKEBALL

local function assertSaleSafety(mapped)
  active.mappings.gifts.MAGIKARP_SALE = mapped and
    { species = "TEST_FISH", level = 15 } or nil
  local rows = capture(sale, game({}, 500))
  local failed = interpret(rows, {
    money = 500, giveSuccess = false, flags = {}, hidden = {},
  })
  assert(failed.money == 500 and failed.awards == 0)
  assert(not failed.flags.EVENT_BOUGHT_MAGIKARP)

  local retried = interpret(rows, {
    money = 500, giveSuccess = true, flags = {}, hidden = {},
  })
  assert(retried.money == 0 and retried.awards == 1)
  assert(retried.flags.EVENT_BOUGHT_MAGIKARP)

  local declined = interpret(rows, {
    money = 500, answer = false, flags = {}, hidden = {},
  })
  assert(declined.money == 500 and declined.awards == 0)
end

local function assertDojoSafety(mapped)
  active.mappings.gifts.DOJO_LEFT = mapped and
    { species = "TEST_DOJO", level = 15 } or nil
  local flags = { EVENT_BEAT_KARATE_MASTER = true }
  local rows = capture(dojo, game(flags))
  local failed = interpret(rows, {
    giveSuccess = false,
    flags = { EVENT_BEAT_KARATE_MASTER = true }, hidden = {},
  })
  assert(not failed.flags.EVENT_GOT_HITMONLEE)
  assert(not failed.flags.EVENT_DEFEATED_FIGHTING_DOJO)
  assert(next(failed.hidden) == nil and failed.awards == 0)

  local retried = interpret(rows, {
    giveSuccess = true,
    flags = { EVENT_BEAT_KARATE_MASTER = true }, hidden = {},
  })
  assert(retried.flags.EVENT_GOT_HITMONLEE)
  assert(retried.flags.EVENT_DEFEATED_FIGHTING_DOJO)
  assert(next(retried.hidden) and retried.awards == 1)
end

local function assertLaprasSafety(mapped)
  active.mappings.gifts.SILPH_LAPRAS = mapped and
    { species = "TEST_LAPRAS", level = 15 } or nil
  local rows = capture(lapras, game({}))
  local failed = interpret(rows, {
    giveSuccess = false, flags = {}, hidden = {},
  })
  assert(not failed.flags.EVENT_GOT_LAPRAS and failed.awards == 0)
  local retried = interpret(rows, {
    giveSuccess = true, flags = {}, hidden = {},
  })
  assert(retried.flags.EVENT_GOT_LAPRAS and retried.awards == 1)
end

assertSaleSafety(true)
assertSaleSafety(false)
assertDojoSafety(true)
assertDojoSafety(false)
assertLaprasSafety(true)
assertLaprasSafety(false)

local eeveeFailed = interpret(eevee, {
  giveSuccess = false, flags = {}, hidden = {},
})
assert(not eeveeFailed.flags.EVENT_GOT_EEVEE)
assert(next(eeveeFailed.hidden) == nil and eeveeFailed.awards == 0)
local eeveeSuccess = interpret(eevee, {
  giveSuccess = true, flags = {}, hidden = {},
})
assert(eeveeSuccess.flags.EVENT_GOT_EEVEE)
assert(next(eeveeSuccess.hidden) and eeveeSuccess.awards == 1)
local eeveeAlreadyOwned = interpret(eevee, {
  flags = { EVENT_GOT_EEVEE = true }, hidden = {},
})
assert(next(eeveeAlreadyOwned.hidden) and eeveeAlreadyOwned.awards == 0)

-- Non-award branches also terminate exactly once.
interpret(capture(sale, game({ EVENT_BOUGHT_MAGIKARP = true }, 500)),
  { flags = { EVENT_BOUGHT_MAGIKARP = true }, hidden = {} })
interpret(capture(sale, game({}, 499)),
  { money = 499, flags = {}, hidden = {} })
interpret(capture(dojo, game({})), { flags = {}, hidden = {} })
interpret(capture(dojo, game({
  EVENT_BEAT_KARATE_MASTER = true,
  EVENT_GOT_HITMONCHAN = true,
})), {
  flags = {
    EVENT_BEAT_KARATE_MASTER = true,
    EVENT_GOT_HITMONCHAN = true,
  },
  hidden = {},
})
interpret(capture(lapras, game({ EVENT_GOT_LAPRAS = true })), {
  flags = { EVENT_GOT_LAPRAS = true }, hidden = {},
})

-- Static, Snorlax, and all table-backed scripts use valid labels.
for _, map in pairs(contributions) do
  for _, rows in pairs(map.talk or {}) do
    if type(rows) == "table" and type(rows[1]) == "table" then
      validateLabels(rows)
      interpret(rows, { flags = {}, hidden = {} })
      interpret(rows, {
        flags = setmetatable({}, { __index = function() return true end }),
        hidden = {},
      })
    end
  end
  if map.snorlaxWake then
    validateLabels(map.snorlaxWake.script)
    for _, result in ipairs({ "win", "run", "lose" }) do
      interpret(map.snorlaxWake.script, {
        battleResult = result, flags = {}, hidden = {},
      })
    end
  end
end

-- Fossil handover clears quest state only after a successful award.
local stack = { values = {} }
function stack:push(value) self.values[#self.values + 1] = value end
function stack:pop() return table.remove(self.values) end
local fossilTalk = contributions.CINNABAR_LAB_FOSSIL_ROOM.talk
  .TEXT_CINNABARLABFOSSILROOM_SCIENTIST1
local fossilGame = {
  save = {
    flags = {
      EVENT_GAVE_FOSSIL_TO_LAB = true,
      EVENT_LAB_HANDING_OVER_FOSSIL_MON = true,
    },
    inventory = {},
    labFossilMon = "OMANYTE",
  },
  data = {
    text = {},
    pokemon = {
      OMANYTE = { name = "OMANYTE" },
      TEST_FOSSIL = { name = "TEST FOSSIL" },
    },
    items = {},
  },
  stack = stack,
}
local fossilRows
fossilTalk(fossilGame, {
  runner = { run = function(_, rows) fossilRows = rows end },
}, {}, function() end)
local revived = assert(stack.values[#stack.values])
assert(type(revived.onDone) == "function")
revived.onDone()
assert(fossilRows)
local fossilFailed = interpret(fossilRows, {
  giveSuccess = false,
  flags = {
    EVENT_GAVE_FOSSIL_TO_LAB = true,
    EVENT_LAB_HANDING_OVER_FOSSIL_MON = true,
  },
  labFossilMon = "OMANYTE",
  hidden = {},
})
assert(fossilFailed.labFossilMon == "OMANYTE")
assert(fossilFailed.flags.EVENT_GAVE_FOSSIL_TO_LAB)
local fossilSuccess = interpret(fossilRows, {
  giveSuccess = true,
  flags = {
    EVENT_GAVE_FOSSIL_TO_LAB = true,
    EVENT_LAB_HANDING_OVER_FOSSIL_MON = true,
  },
  labFossilMon = "OMANYTE",
  hidden = {},
})
assert(fossilSuccess.labFossilMon == nil)
assert(not fossilSuccess.flags.EVENT_GAVE_FOSSIL_TO_LAB)

-- Without a runner, handlers still complete once and make no mutation.
local missingRunnerDone = 0
sale(game({}, 500), {}, {}, function()
  missingRunnerDone = missingRunnerDone + 1
end)
assert(missingRunnerDone == 1)

print("static_gift_safety_m10_test: ok")
