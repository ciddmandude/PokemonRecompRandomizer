-- Self-contained authenticated race-spoiler envelope.
--
-- This is intentionally a local accidental-spoiler safeguard. The memory
-- mixing and keyed stream/MAC are versioned so the format can be upgraded;
-- they are not a substitute for a server-controlled competitive race system.
return function(Canonical, Sha256)
  local Crypto = {}
  local BLOCKS = 256
  local PASSES = 2

  local function hexToBytes(hex)
    assert(type(hex) == "string" and #hex % 2 == 0
      and hex:match("^[0-9A-Fa-f]*$"), "invalid hexadecimal data")
    return (hex:gsub("..", function(pair)
      return string.char(tonumber(pair, 16))
    end))
  end

  local function bytesToHex(bytes)
    return (bytes:gsub(".", function(byte)
      return ("%02X"):format(string.byte(byte))
    end))
  end

  local function mixIndex(hex)
    return (tonumber(hex:sub(1, 8), 16) % BLOCKS) + 1
  end

  function Crypto.derive(passphrase, salt)
    assert(type(passphrase) == "string" and #passphrase >= 4,
      "passphrase must contain at least four characters")
    assert(type(salt) == "string" and salt:match("^[0-9A-F]+$"),
      "salt must be uppercase hexadecimal")
    local memory = {}
    memory[1] = Sha256.digest(
      "pokemon_randomizer\0mhkdf-v1\0" .. salt .. "\0" .. passphrase).hex
    for index = 2, BLOCKS do
      memory[index] = Sha256.digest(
        memory[index - 1] .. "\0" .. passphrase .. "\0"
          .. salt .. "\0" .. tostring(index)).hex
    end
    for pass = 1, PASSES do
      for index = 1, BLOCKS do
        local other = memory[mixIndex(memory[index])]
        memory[index] = Sha256.digest(
          "mix\0" .. tostring(pass) .. "\0" .. tostring(index)
            .. "\0" .. memory[index] .. other .. passphrase).hex
      end
    end
    local folded = table.concat(memory)
    return Sha256.digest("enc\0" .. folded).hex
      .. Sha256.digest("mac\0" .. folded).hex
  end

  local function xorBytes(plain, key, nonce)
    local output, offset, counter = {}, 1, 0
    while offset <= #plain do
      local block = Sha256.hmac(key,
        "pokemon_randomizer\0stream-v1\0" .. key .. "\0"
          .. nonce .. "\0" .. tostring(counter)).raw
      local count = math.min(#block, #plain - offset + 1)
      local bytes = {}
      for index = 1, count do
        local a = string.byte(plain, offset + index - 1)
        local b = string.byte(block, index)
        local value, place = 0, 1
        for _ = 1, 8 do
          if a % 2 ~= b % 2 then value = value + place end
          a, b, place = math.floor(a / 2), math.floor(b / 2), place * 2
        end
        bytes[index] = string.char(value)
      end
      output[#output + 1] = table.concat(bytes)
      offset, counter = offset + count, counter + 1
    end
    return table.concat(output)
  end

  local function metadata(run)
    return {
      format = "pokemon-randomizer-race-v1",
      algorithmVersion = run.algorithmVersion,
      settingsHash = run.compatibility and run.compatibility.settingsHash,
      poolHash = run.compatibility and run.compatibility.poolHash,
      seedHash = run.seed and run.seed.hash128,
    }
  end

  local function tag(key, metadataBytes, salt, nonce, ciphertext)
    return Sha256.hmac(key,
      "pokemon_randomizer\0auth-v1\0" .. key .. "\0"
        .. metadataBytes .. "\0" .. salt .. "\0" .. nonce .. "\0"
        .. ciphertext).hex
  end

  local function same(a, b)
    if type(a) ~= "string" or type(b) ~= "string" or #a ~= #b then
      return false
    end
    local different = 0
    for index = 1, #a do
      if a:byte(index) ~= b:byte(index) then different = different + 1 end
    end
    return different == 0
  end

  function Crypto.randomMaterial(entropy, domain)
    assert(type(entropy) == "string" and entropy ~= "",
      "entropy must be a non-empty string")
    return Sha256.digest(
      "pokemon_randomizer\0random-material-v1\0"
        .. tostring(domain) .. "\0" .. entropy).hex
  end

  function Crypto.encrypt(plaintext, passphrase, run, entropy)
    assert(type(plaintext) == "string", "plaintext must be a string")
    assert(type(run) == "table", "run metadata is required")
    local salt = Crypto.randomMaterial(entropy, "salt")
    local nonce = Crypto.randomMaterial(entropy .. "\0" .. salt, "nonce")
    local keys = Crypto.derive(passphrase, salt)
    local encryptionKey, authenticationKey =
      keys:sub(1, 64), keys:sub(65, 128)
    local metadataBytes = Canonical.encode(metadata(run))
    local ciphertext = xorBytes(plaintext, encryptionKey, nonce)
    local ciphertextHex = bytesToHex(ciphertext)
    local auth = tag(authenticationKey, metadataBytes,
      salt, nonce, ciphertextHex)
    return table.concat({
      "PRRACE1",
      "metadata=" .. bytesToHex(metadataBytes),
      "salt=" .. salt,
      "nonce=" .. nonce,
      "ciphertext=" .. ciphertextHex,
      "tag=" .. auth,
      "",
    }, "\n"), auth
  end

  function Crypto.decrypt(envelope, passphrase)
    if type(envelope) ~= "string"
        or envelope:sub(1, 8) ~= "PRRACE1\n" then
      return nil, "unsupported encrypted spoiler format"
    end
    local fields = {}
    for key, value in envelope:gmatch("\n([a-z]+)=([^\n]*)") do
      fields[key] = value
    end
    for _, key in ipairs({
      "metadata", "salt", "nonce", "ciphertext", "tag",
    }) do
      if type(fields[key]) ~= "string"
          or not fields[key]:match("^[0-9A-F]*$") then
        return nil, "encrypted spoiler is malformed"
      end
    end
    local ok, keys = pcall(Crypto.derive, passphrase, fields.salt)
    if not ok then return nil, "invalid passphrase" end
    local expected = tag(keys:sub(65, 128), hexToBytes(fields.metadata),
      fields.salt, fields.nonce, fields.ciphertext)
    if not same(expected, fields.tag) then
      return nil, "authentication failed"
    end
    local plaintext = xorBytes(
      hexToBytes(fields.ciphertext), keys:sub(1, 64), fields.nonce)
    return plaintext, nil
  end

  function Crypto.passphraseVerifier(passphrase, salt)
    local keys = Crypto.derive(passphrase, salt)
    return Sha256.hmac(keys:sub(65, 128),
      "pokemon_randomizer\0passphrase-verifier-v1").hex
  end

  Crypto.format = "pokemon-randomizer-race-v1"
  Crypto.kdf = "mhkdf-hash128-256x2-v1"
  return Crypto
end
