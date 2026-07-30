local function loadFactory(path, ...)
  local chunk, err = loadfile(path)
  assert(chunk, err)
  local value = chunk()
  if type(value) == "function" then return value(...) end
  return value
end

local StableSort = loadFactory("src/stable_sort.lua")
local Matching = loadFactory("src/matching.lua", StableSort)

local function identityRng()
  return {
    shuffle = function(_, input)
      local output = {}
      for index, value in ipairs(input) do output[index] = value end
      return output
    end,
  }
end

-- A greedy first choice would consume X for A and dead-end B. The
-- augmenting path moves A to Y, so the available perfect matching has no
-- reset.
local perfect = Matching.assign({
  { id = "A", source = "A", candidates = { "X", "Y" } },
  { id = "B", source = "B", candidates = { "X" } },
}, identityRng(), {
  category = "fixture.perfect",
  code = "FIXTURE_POOL_RESET",
})
assert(perfect.assignments.A == "Y")
assert(perfect.assignments.B == "X")
assert(#perfect.resets == 0)
assert(#perfect.unmatched == 0)

-- Two sources competing for one destination cannot fit one uniqueness pool.
-- The reset is deterministic and fully attributed.
local exhaustedUnits = {
  {
    id = "A", source = "SOURCE_A", candidates = { "X" },
    hardConstraints = { legendary = "exclude", progression = true },
  },
  {
    id = "B", source = "SOURCE_B", candidates = { "X" },
    hardConstraints = { legendary = "exclude", progression = true },
  },
}
local exhausted = Matching.assign(
  exhaustedUnits, identityRng(), {
    category = "fixture.exhausted",
    code = "FIXTURE_POOL_RESET",
  })
assert(exhausted.assignments.A == "X")
assert(exhausted.assignments.B == "X")
assert(#exhausted.resets == 1)
assert(exhausted.resets[1].category == "fixture.exhausted")
assert(exhausted.resets[1].exhaustedPoolSize == 1)
assert(exhausted.resets[1].affectedSource == "SOURCE_B")
assert(exhausted.resets[1].affectedId == "B")
assert(exhausted.resets[1].hardConstraints.legendary == "exclude")
assert(exhausted.resets[1].hardConstraints.progression == true)

local repeated = Matching.assign(
  exhaustedUnits, identityRng(), {
    category = "fixture.exhausted",
    code = "FIXTURE_POOL_RESET",
  })
assert(repeated.assignments.A == exhausted.assignments.A)
assert(repeated.assignments.B == exhausted.assignments.B)
assert(repeated.resets[1].affectedId == exhausted.resets[1].affectedId)

local missing = Matching.assign({
  {
    id = "NONE", source = "UNKNOWN", candidates = {},
    diagnostics = { error = { code = "NO_CANDIDATES" } },
  },
}, identityRng(), { category = "fixture.empty" })
assert(missing.assignments.NONE == nil)
assert(#missing.resets == 0)
assert(#missing.unmatched == 1)
assert(missing.unmatched[1].diagnostics.error.code == "NO_CANDIDATES")

-- The streaming facade used by trainer generation has identical augmenting
-- behavior and does not freeze a greedy provisional assignment.
local session = Matching.newSession(identityRng(), {
  category = "fixture.streaming",
})
session:add({ id = "A", source = "A", candidates = { "X", "Y" } })
session:add({ id = "B", source = "B", candidates = { "X" } })
local streamed = session:finish()
assert(streamed.assignments.A == "Y")
assert(streamed.assignments.B == "X")
assert(#streamed.resets == 0)

print("matching_test: ok")
