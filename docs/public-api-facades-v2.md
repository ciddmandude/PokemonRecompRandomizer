# Public API facades v2

Round 2 Milestone 5 completes ordinary-assignment protection for all six
structured public exports:

- `mod.exports.generator`;
- `mod.exports.contracts`;
- `mod.exports.species`;
- `mod.exports.save`;
- `mod.exports.preferences`; and
- `mod.exports.spoilers`.

Each export is an empty proxy whose metatable reads from a private backing
table and rejects ordinary assignment. The backing table captures the
implementation callback present when the facade is created. Replacing a field
on the source implementation table later therefore does not redirect calls
through an already-published facade.

## Mutable return isolation

The species, save, preferences, and spoiler facades recursively copy every
table returned by a captured callback, including secondary return values such
as validation-error arrays. This covers:

- species manifests, candidate results, metadata snapshots, and metadata
  diagnostics;
- save validation errors, active-run views, and lifecycle status;
- option schemas, pages, settings snapshots, presets, and behavior settings;
  and
- structured spoiler-export results.

Changing any returned nested table cannot alter a later result or the
randomizer's internal settings, metadata, lifecycle session, or saved run.
Scalar strings, numbers, booleans, and `nil` retain their existing shapes.
Existing callable names and multi-return behavior are unchanged.

## Scope

This is an accidental-mutation boundary, not a Lua sandbox or security
boundary. Ordinary assignment such as:

```lua
mod.exports.save.status = replacement
```

fails. Deliberate use of `rawset`, debug-library facilities, metatable
tampering available through a hostile host, or wholesale replacement of the
engine-owned `mod.exports` root is outside the guarantee. A `rawset` can shadow
a key on the caller-visible empty proxy, but it cannot replace the captured
implementation used internally by the randomizer.
