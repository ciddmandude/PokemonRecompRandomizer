-- Milestone-9 mod-only Oak's Lab starter compatibility tests.
local StarterOffer = assert(loadfile("src/starter_offer.lua"))()
local StarterCompat = assert(loadfile("src/starter_compat.lua"))()(
  StarterOffer)

local offer = {
  slotId = "LEFT",
  species = "CHARMANDER",
  level = 5,
  choseFlag = "EVENT_CHOSE_CHARMANDER",
  ballObject = "OAKSLAB_CHARMANDER_POKE_BALL",
  rivalBall = "OAKSLAB_SQUIRTLE_POKE_BALL",
}
local valid, err = StarterOffer.validate(offer)
assert(valid and err == nil)
local resolved = StarterOffer.resolve(offer, {
  slotId = "LEFT",
  mapId = "OAKS_LAB",
}, { enabled = true })
assert(resolved ~= offer, "valid offers must be copied")
for key, value in pairs(offer) do
  assert(resolved[key] == value, "M9 must preserve vanilla field " .. key)
end
resolved.species = "MEW"
assert(offer.species == "CHARMANDER",
  "the adapter must not mutate the engine offer")

local malformed = {
  slotId = "LEFT",
  species = "CHARMANDER",
  level = 0,
}
assert(not StarterOffer.validate(malformed))
assert(StarterOffer.resolve(malformed, {}, nil) == malformed,
  "malformed downstream offers must pass through for hook-chain recovery")

local game = {
  save = {},
  data = {
    pokemon = {
      CHARMANDER = {}, SQUIRTLE = {}, BULBASAUR = {},
    },
  },
}
local expected = {
  LEFT = {
    species = "CHARMANDER",
    flag = "EVENT_CHOSE_CHARMANDER",
    rivalBall = "OAKSLAB_SQUIRTLE_POKE_BALL",
    rivalSpecies = "SQUIRTLE",
  },
  MIDDLE = {
    species = "SQUIRTLE",
    flag = "EVENT_CHOSE_SQUIRTLE",
    rivalBall = "OAKSLAB_BULBASAUR_POKE_BALL",
    rivalSpecies = "BULBASAUR",
  },
  RIGHT = {
    species = "BULBASAUR",
    flag = "EVENT_CHOSE_BULBASAUR",
    rivalBall = "OAKSLAB_CHARMANDER_POKE_BALL",
    rivalSpecies = "CHARMANDER",
  },
}
for slotId, base in pairs(StarterCompat.offers) do
  local rows = StarterCompat.rows(base, game, nil)
  local want = expected[slotId]
  assert(#rows == 21)
  assert(rows[5][1] == "push_screen"
    and rows[5][3].species == want.species
    and rows[5][3].forceOwned == true)
  assert(rows[6][2] == base.askText)
  assert(rows[8][3].RAM == want.species)
  assert(rows[9][2] == want.species and rows[9][3] == 5)
  assert(rows[11][2] == want.flag)
  assert(rows[12][3] == base.ballObject)
  assert(rows[16][3] == want.rivalBall)
  assert(rows[17][3].RAM == want.rivalSpecies)
  assert(rows[19][1] == "label" and rows[19][2] == "blocked")
  assert(rows[21][1] == "label" and rows[21][2] == "done")
  for _, row in ipairs(rows) do
    if row[1] == "jump" or row[1] == "jump_if_true"
        or row[1] == "jump_if_false" then
      assert(type(row[2]) == "string",
        "starter script must use named jump targets")
    end
  end
end

local contribution = StarterCompat.contribution(function() return nil end)
assert(contribution.priority == 100)
local captured, completed = nil, false
contribution.talk.TEXT_OAKSLAB_CHARMANDER_POKE_BALL(
  game,
  { runner = { run = function(_, rows, extra)
      captured = rows
      assert(type(extra.onDone) == "function")
    end } },
  nil,
  function() completed = true end)
assert(captured and captured[9][2] == "CHARMANDER")
assert(not completed, "the engine runner owns completion after dispatch")

io.write("starter_seam_test: ok\n")
