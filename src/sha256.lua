-- Pure Lua 5.1 SHA-256 and HMAC-SHA-256 for race spoiler authentication.
return function(UInt32)
  local Sha256 = {}
  local K = {
    0x428A2F98,0x71374491,0xB5C0FBCF,0xE9B5DBA5,0x3956C25B,0x59F111F1,
    0x923F82A4,0xAB1C5ED5,0xD807AA98,0x12835B01,0x243185BE,0x550C7DC3,
    0x72BE5D74,0x80DEB1FE,0x9BDC06A7,0xC19BF174,0xE49B69C1,0xEFBE4786,
    0x0FC19DC6,0x240CA1CC,0x2DE92C6F,0x4A7484AA,0x5CB0A9DC,0x76F988DA,
    0x983E5152,0xA831C66D,0xB00327C8,0xBF597FC7,0xC6E00BF3,0xD5A79147,
    0x06CA6351,0x14292967,0x27B70A85,0x2E1B2138,0x4D2C6DFC,0x53380D13,
    0x650A7354,0x766A0ABB,0x81C2C92E,0x92722C85,0xA2BFE8A1,0xA81A664B,
    0xC24B8B70,0xC76C51A3,0xD192E819,0xD6990624,0xF40E3585,0x106AA070,
    0x19A4C116,0x1E376C08,0x2748774C,0x34B0BCB5,0x391C0CB3,0x4ED8AA4A,
    0x5B9CCA4F,0x682E6FF3,0x748F82EE,0x78A5636F,0x84C87814,0x8CC70208,
    0x90BEFFFA,0xA4506CEB,0xBEF9A3F7,0xC67178F2,
  }

  local function add(...)
    local value = 0
    for index = 1, select("#", ...) do
      value = (value + select(index, ...)) % UInt32.MODULUS
    end
    return value
  end

  local function ror(value, amount)
    return UInt32.rotl(value, 32 - amount)
  end

  local function xor3(a, b, c)
    return UInt32.xor(UInt32.xor(a, b), c)
  end

  local function rawDigest(message)
    local length = #message
    local bitLength = length * 8
    local high = math.floor(bitLength / UInt32.MODULUS)
    local low = bitLength % UInt32.MODULUS
    local padding = "\128"
      .. string.rep("\0", (55 - length) % 64)
      .. UInt32.toBytesBE(high) .. UInt32.toBytesBE(low)
    local bytes = message .. padding
    local h = {
      0x6A09E667,0xBB67AE85,0x3C6EF372,0xA54FF53A,
      0x510E527F,0x9B05688C,0x1F83D9AB,0x5BE0CD19,
    }
    for offset = 1, #bytes, 64 do
      local w = {}
      for index = 0, 15 do
        local first = offset + index * 4
        w[index + 1] = bytes:byte(first) * 16777216
          + bytes:byte(first + 1) * 65536
          + bytes:byte(first + 2) * 256
          + bytes:byte(first + 3)
      end
      for index = 17, 64 do
        local x, y = w[index - 15], w[index - 2]
        local s0 = xor3(ror(x, 7), ror(x, 18), UInt32.rshift(x, 3))
        local s1 = xor3(ror(y, 17), ror(y, 19), UInt32.rshift(y, 10))
        w[index] = add(w[index - 16], s0, w[index - 7], s1)
      end
      local a,b,c,d,e,f,g,hh =
        h[1],h[2],h[3],h[4],h[5],h[6],h[7],h[8]
      for index = 1, 64 do
        local s1 = xor3(ror(e, 6), ror(e, 11), ror(e, 25))
        local choice = UInt32.xor(
          UInt32.band(e, f), UInt32.band(UInt32.bnot(e), g))
        local t1 = add(hh, s1, choice, K[index], w[index])
        local s0 = xor3(ror(a, 2), ror(a, 13), ror(a, 22))
        local majority = xor3(
          UInt32.band(a, b), UInt32.band(a, c), UInt32.band(b, c))
        local t2 = add(s0, majority)
        hh,g,f,e,d,c,b,a = g,f,e,add(d,t1),c,b,a,add(t1,t2)
      end
      h[1],h[2],h[3],h[4] =
        add(h[1],a),add(h[2],b),add(h[3],c),add(h[4],d)
      h[5],h[6],h[7],h[8] =
        add(h[5],e),add(h[6],f),add(h[7],g),add(h[8],hh)
    end
    local output = {}
    for index = 1, 8 do output[index] = UInt32.toBytesBE(h[index]) end
    return table.concat(output)
  end

  local function hex(bytes)
    return (bytes:gsub(".", function(value)
      return ("%02X"):format(value:byte())
    end))
  end

  function Sha256.digest(message)
    assert(type(message) == "string", "SHA-256 input must be a string")
    local raw = rawDigest(message)
    return { raw = raw, hex = hex(raw) }
  end

  function Sha256.hmac(key, message)
    assert(type(key) == "string" and type(message) == "string",
      "HMAC key and message must be strings")
    if #key > 64 then key = rawDigest(key) end
    key = key .. string.rep("\0", 64 - #key)
    local inner, outer = {}, {}
    for index = 1, 64 do
      inner[index] = string.char(UInt32.xor(key:byte(index), 0x36))
      outer[index] = string.char(UInt32.xor(key:byte(index), 0x5C))
    end
    local raw = rawDigest(
      table.concat(outer) .. rawDigest(table.concat(inner) .. message))
    return { raw = raw, hex = hex(raw) }
  end

  return Sha256
end
