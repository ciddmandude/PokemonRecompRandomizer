# Round 3 Milestone 7 performance disposition

Measured on 2026-08-01 with PUC Lua 5.1.5 on Windows
`10.0.26200.0` and an Intel64 Family 6 Model 183 processor. Timings use
`os.clock()` and are comparative development measurements, not frame-time or
hardware guarantees.

Run the repeatable benchmark from the repository root:

```powershell
lua tools/benchmark-round3-m7.lua
```

The release script runs this benchmark after the complete test suite and
before packaging. Each evolution row uses the real `Evolution.generate`
implementation and a fixed seed. `representative` fixtures contain many
single evolutions plus periodic branches. `constrained` fixtures give all
edges only three stage-compatible destinations, deliberately forcing global
uniqueness relaxation while retaining distinct sibling branches.

## Evolution measurements

| Pool | Scenario | Edges | Seconds | RNG draws | Search nodes | Repeat relaxations | Soft relaxations | Result |
|---:|---|---:|---:|---:|---:|---:|---:|---|
| 151 | representative | 57 | 0.0660 | 8,550 | 69 | 0 | 0 | success, no fallback |
| 151 | constrained | 50 | 0.0590 | 7,500 | 9,035 | 47 | 0 | success, no fallback |
| 500 | representative | 190 | 0.7170 | 94,810 | 244 | 0 | 0 | success, no fallback |
| 500 | constrained | 168 | 0.6460 | 83,832 | 106,645 | 165 | 0 | success, no fallback |
| 1,000 | representative | 381 | 3.0070 | 380,619 | 479 | 0 | 0 | success, no fallback |
| 1,000 | constrained | 336 | 2.5960 | 335,664 | 417,730 | 333 | 0 | success, no fallback |

The 1,000-species cases completed without stack overflow. Every search stayed
below its existing explicit node budget; the largest measured search visited
417,730 nodes against a budget of 8,064,000. The large RNG counts confirm the
review's observation that independent per-edge shuffles dominate work, while
the low representative search-node counts show that backtracking is not the
normal cost driver.

## Mechanics baseline memory

The memory fixture is constructed before measurement. The reported delta is
Lua heap growth after `MechanicsRuntime.capture` and a full collection, so it
isolates the retained supported-field baseline rather than the source records.

| Fixture | Species | Moves | Capture seconds | Retained baseline |
|---|---:|---:|---:|---:|
| vanilla-shaped | 151 | 165 | 0.0020 | 456.8 KiB |
| merged-1000 | 1,000 | 1,000 | 0.0120 | 3,056.7 KiB |

The release benchmark uses review guardrails of 30 seconds per evolution case,
5 seconds per baseline capture, and 64 MiB retained baseline memory. These are
regression tripwires rather than engine guarantees. Both measured fixtures are
well below them.

## Decision

No algorithm optimization is accepted in Milestone 7. Reusing candidate
orders would reduce the measured draw count, but it would also change RNG draw
order and seeded mappings, requiring an algorithm-version increment and new
golden expectations. The measured 151-species cost is negligible, the
1,000-species stress cases terminate within the release guardrails, and the
largest mechanics baseline remains about 3 MiB. Those results do not justify
an output-changing rewrite.

The recursive assignment and cycle traversal are retained because the
1,000-species seeded fixtures complete safely and the search is explicitly
node-bounded. If future fixtures demonstrate a stack failure, cycle traversal
should be replaced with an output-equivalent iterative boolean traversal first;
candidate ordering must remain unchanged unless the algorithm version advances.

This disposition preserves algorithm `1.17.0-dev`, all named stream behavior,
and every existing golden mapping.
