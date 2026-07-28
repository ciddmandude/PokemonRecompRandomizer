-- Plaintext and locked-race spoiler serialization/export.
return function(Canonical, Crypto)
  local Spoiler = {}

  local function locked(run)
    return type(run) == "table" and type(run.race) == "table"
      and run.race.enabled == true and run.race.unlocked ~= true
  end

  function Spoiler.isLocked(run)
    return locked(run)
  end

  function Spoiler.text(run)
    assert(type(run) == "table", "active run is required")
    return table.concat({
      "POKEMON GEN 1 RECOMP RANDOMIZER SPOILER V1",
      "SEED=" .. tostring(run.seed and run.seed.canonical or ""),
      "SEED_HASH=" .. tostring(run.seed and run.seed.hash128 or ""),
      "ALGORITHM=" .. tostring(run.algorithmVersion or ""),
      "SETTINGS_HASH="
        .. tostring(run.compatibility and run.compatibility.settingsHash or ""),
      "POOL_HASH="
        .. tostring(run.compatibility and run.compatibility.poolHash or ""),
      "SETTINGS=" .. Canonical.encode(run.settings or {}),
      "MAPPINGS=" .. Canonical.encode(run.mappings or {}),
      "DIAGNOSTICS=" .. Canonical.encode(run.diagnostics or {}),
      "",
    }, "\n")
  end

  local function filesystem(fs)
    fs = fs or (love and love.filesystem)
    if not (fs and type(fs.write) == "function") then
      return nil, "filesystem export is unavailable"
    end
    return fs
  end

  local function filename(run, suffix)
    local seed = tostring(run.seed and run.seed.hash128 or "UNKNOWN"):sub(1, 8)
    return "pokemon_randomizer/spoilers/" .. seed .. suffix
  end

  function Spoiler.export(run, options)
    options = options or {}
    local fs, fsError = filesystem(options.filesystem)
    if not fs then return nil, fsError end
    if fs.createDirectory then
      local ok, err = fs.createDirectory("pokemon_randomizer/spoilers")
      if ok == false then return nil, tostring(err) end
    end
    local content, path, digest
    if locked(run) then
      if type(options.passphrase) ~= "string"
          or #options.passphrase < 4 then
        return nil, "a passphrase of at least four characters is required"
      end
      if type(options.entropy) ~= "string" or options.entropy == "" then
        return nil, "cryptographic entropy is unavailable"
      end
      local ok, encrypted, auth = pcall(Crypto.encrypt,
        Spoiler.text(run), options.passphrase, run, options.entropy)
      if not ok then return nil, "encrypted export initialization failed" end
      content, digest = encrypted, auth
      path = filename(run, ".race")
    else
      content = Spoiler.text(run)
      path = filename(run, ".txt")
    end
    local ok, err = fs.write(path, content)
    if not ok then return nil, tostring(err or "spoiler write failed") end
    return { path = path, digest = digest, encrypted = locked(run) }, nil
  end

  function Spoiler.publicRun(run)
    if type(run) ~= "table" then return nil end
    if not locked(run) then
      local output = {}
      for key, value in pairs(run) do
        if type(key) ~= "string" or key:sub(1, 1) ~= "_" then
          output[key] = value
        end
      end
      return output
    end
    return {
      schemaVersion = run.schemaVersion,
      algorithmVersion = run.algorithmVersion,
      enabled = run.enabled,
      seed = {
        mode = run.seed and run.seed.mode,
        hash128 = run.seed and run.seed.hash128,
      },
      settings = run.settings,
      compatibility = run.compatibility,
      mappings = nil,
      diagnostics = {
        warningCount = type(run.diagnostics) == "table"
          and #(run.diagnostics.warnings or {}) or 0,
        fallbackCount = type(run.diagnostics) == "table"
          and run.diagnostics.fallbackCount or 0,
      },
      race = run.race,
    }
  end

  return Spoiler
end
