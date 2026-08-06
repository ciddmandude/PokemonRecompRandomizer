# Test discovery and two-OS release qualification v2

Round 2 Milestone 6 removes the manually maintained Lua test list from
`tools/test.ps1`.

## Automatic discovery

`tools/test-discovery.ps1` selects only files directly under `tests/` whose
names end with the exact lowercase suffix `_test.lua`. It sorts absolute paths
with `StringComparer.Ordinal`, rejects a zero-test result, and rejects
filenames that collide under invariant case-folding. Harnesses, fixtures, and
golden-vector data do not match the suffix and are not executed.

`tools/test.ps1` launches each discovered path in a separate Lua 5.1 process.
Any nonzero exit code fails immediately with the test filename. Its final
summary reports both the discovered test count and the total recursively
syntax-checked Lua file count.

`tools/release.ps1` then runs `tools/benchmark-round3-m7.lua` before building
the release artifact. The benchmark reports seeded evolution time, RNG draws,
search nodes, relaxation counts, success/fallback state, and mechanics
baseline memory for the required 151-, 500-, and 1,000-species fixtures. Its
measured disposition is recorded in `docs/round3-m7-performance.md`.

The discovery self-test creates a temporary directory containing one
`sentinel_test.lua` and one helper. It proves that only the sentinel is
selected and executed, then separately proves that empty input and synthetic
case-colliding paths fail. Temporary cleanup verifies its resolved path is
inside the system temporary directory before recursive removal.

## Portability regressions

`tools/portability-test.ps1` invokes the real scaffold validator with both LF
and CRLF `.gitignore` content. `tools/package-test.ps1` builds and validates
two archives and explicitly opens the hidden `.modkit/pack.json` entry from
each one. The package validator also rejects backslashes, unsafe paths,
case-colliding entries, ledger omissions, and hash or byte-count mismatches.

## CI matrix

`.github/workflows/package-validation.yml` runs on `windows-latest` and
`ubuntu-latest`. Each job:

1. installs stock Lua 5.1.5;
2. runs automatic discovery, every Lua test, scaffold validation, and repeated
   package validation;
3. builds and validates a release archive again; and
4. natively extracts it and checks required runtime paths.

The local Windows qualification for mod `0.33.0` discovered 23 tests and
syntax-checked 76 Lua files. Remote Windows and Ubuntu status must be confirmed
from the GitHub Actions run after the branch is pushed; the repository cannot
truthfully claim a future remote run is green before it executes.
