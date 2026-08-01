-- Builds the complete current request shared by the locked test and its
-- explicit expectation updater. No item or mechanics setting is stripped.
return function(Harness, vector)
  return Harness.request(
    vector.seed, vector.profile, vector.overrides, vector.sourceOverrides)
end
