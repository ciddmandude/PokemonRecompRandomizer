-- xoshiro128** with exact unsigned-32-bit arithmetic.
return function(Constants, UInt32, Hash128)
  local Rng = {}
  Rng.__index = Rng

  local function validateState(words)
    assert(type(words) == "table" and #words == 4,
      "PRNG state must contain four words")
    local allZero = true
    local copy = {}
    for index = 1, 4 do
      copy[index] = UInt32.normalize(words[index])
      if copy[index] ~= 0 then allZero = false end
    end
    assert(not allZero, "xoshiro128** state cannot be all zero")
    return copy
  end

  function Rng.fromState(words)
    return setmetatable({
      state = validateState(words),
      draws = 0,
    }, Rng)
  end

  function Rng.fromSeed(canonicalSeed, streamName)
    local root = Hash128.seed(canonicalSeed)
    local derived = Hash128.derive(root, streamName)
    local rng = Rng.fromState(derived.words)
    rng.rootHash = root
    rng.streamHash = derived
    rng.streamName = streamName
    return rng
  end

  function Rng:nextU32()
    local s = self.state
    local result = UInt32.mul(UInt32.rotl(UInt32.mul(s[2], 5), 7), 9)
    local temporary = UInt32.lshift(s[2], 9)

    s[3] = UInt32.xor(s[3], s[1])
    s[4] = UInt32.xor(s[4], s[2])
    s[2] = UInt32.xor(s[2], s[3])
    s[1] = UInt32.xor(s[1], s[4])
    s[3] = UInt32.xor(s[3], temporary)
    s[4] = UInt32.rotl(s[4], 11)

    self.draws = self.draws + 1
    return result
  end

  function Rng:nextInt(minimum, maximum)
    assert(UInt32.isInteger(minimum) and UInt32.isInteger(maximum),
      "integer range bounds are required")
    assert(minimum <= maximum, "minimum must not exceed maximum")

    local span = maximum - minimum + 1
    assert(span >= 1 and span <= UInt32.MODULUS,
      "integer range cannot exceed 2^32 values")
    if span == UInt32.MODULUS then
      return minimum + self:nextU32()
    end

    local limit = UInt32.MODULUS - (UInt32.MODULUS % span)
    local value
    repeat value = self:nextU32() until value < limit
    return minimum + (value % span)
  end

  function Rng:shuffle(input)
    assert(type(input) == "table", "shuffle input must be an array")
    local output = {}
    for index, value in ipairs(input) do output[index] = value end
    for index = #output, 2, -1 do
      local swap = self:nextInt(1, index)
      output[index], output[swap] = output[swap], output[index]
    end
    return output
  end

  function Rng:snapshot()
    return {
      self.state[1],
      self.state[2],
      self.state[3],
      self.state[4],
    }
  end

  Rng.version = Constants.PRNG_VERSION

  return Rng
end
