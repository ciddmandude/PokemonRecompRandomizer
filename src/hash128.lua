-- pokemon_randomizer hash128, version fnv1a32x4-v1.
--
-- Four independently salted FNV-1a/32 lanes followed by the Murmur3 fmix32
-- avalanche. This is a stable content hash, not a cryptographic hash.
return function(Constants, UInt32)
  local Hash128 = {}

  local FNV_OFFSET = 2166136261
  local FNV_PRIME = 16777619
  local LANE_SALTS = {
    0,
    2654435769, -- 0x9E3779B9
    608135816,  -- 0x243F6A88
    3084996962, -- 0xB7E15162
  }

  local function update(state, byte)
    return UInt32.mul(UInt32.xor(state, byte), FNV_PRIME)
  end

  local function avalanche(value)
    value = UInt32.xor(value, UInt32.rshift(value, 16))
    value = UInt32.mul(value, 2246822507) -- 0x85EBCA6B
    value = UInt32.xor(value, UInt32.rshift(value, 13))
    value = UInt32.mul(value, 3266489909) -- 0xC2B2AE35
    return UInt32.xor(value, UInt32.rshift(value, 16))
  end

  local function result(words)
    return {
      version = Constants.HASH_VERSION,
      words = words,
      hex = UInt32.toHex(words[1]) .. UInt32.toHex(words[2])
        .. UInt32.toHex(words[3]) .. UInt32.toHex(words[4]),
    }
  end

  function Hash128.digest(bytes)
    assert(type(bytes) == "string", "hash input must be a byte string")
    local words = {}
    for lane = 1, 4 do
      words[lane] = UInt32.xor(FNV_OFFSET, LANE_SALTS[lane])
    end

    for index = 1, #bytes do
      local byte = string.byte(bytes, index)
      for lane = 1, 4 do words[lane] = update(words[lane], byte) end
    end

    -- Lane index and message length are finalized into every lane so empty
    -- and short inputs retain full domain separation.
    local length = #bytes
    for lane = 1, 4 do
      words[lane] = update(words[lane], lane)
      words[lane] = update(words[lane], length % 256)
      words[lane] = update(words[lane], math.floor(length / 256) % 256)
      words[lane] = avalanche(words[lane])
    end
    return result(words)
  end

  function Hash128.seed(canonicalSeed)
    assert(type(canonicalSeed) == "string" and canonicalSeed ~= "",
      "canonical seed must be a non-empty string")
    return Hash128.digest("pokemon_randomizer\0seed\0" .. canonicalSeed)
  end

  function Hash128.derive(rootHash, streamName)
    assert(type(rootHash) == "table" and type(rootHash.words) == "table"
        and #rootHash.words == 4, "root hash must contain four words")
    assert(type(streamName) == "string" and streamName ~= "",
      "stream name must be a non-empty string")
    assert(streamName:match("^[a-z][a-z0-9._%-]*$"),
      "stream name must use lowercase ASCII identifiers")

    local rootBytes = ""
    for lane = 1, 4 do
      rootBytes = rootBytes .. UInt32.toBytesBE(rootHash.words[lane])
    end
    return Hash128.digest(
      "pokemon_randomizer\0stream\0" .. rootBytes .. "\0" .. streamName)
  end

  Hash128.version = Constants.HASH_VERSION

  return Hash128
end
