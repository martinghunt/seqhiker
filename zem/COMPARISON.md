# Comparison engine

Seqhiker uses faqt v0.12.0 with `EndExtensionAdaptive`, `RedundancyNear`,
K=15/W=10, default scoring and a 20M raw-anchor budget. `RedundancyNear` merges
paths describing the same placement and removes nested alternatives whose
pairings other matches already report; distinct repeat copies remain.
Adaptive extension is an internal policy; it keeps full alignment of internal
gaps but can miss outward score recovery.
No alignment settings are added to the interface. Resource errors propagate to
the caller rather than becoming empty or truncated results.

Each genome caches a prepared faqt genome built from its raw contigs. Display
spacers, annotations, contig offsets and reversals remain application concerns.
Matches retain run-length encoded paths in raw contig coordinates. Detail
requests transform those paths to the current display, swapping I/D and reversing
operation order where required. Paths above the existing 200,000-column detail
budget retain their summaries and compressed operations but omit per-column wire
detail. Optional disk caches are keyed by engine policy and display sequences.

Session format 5 saves compressed paths. Formats 1–4 remain readable and mark
their comparisons pending for recomputation. Old Seqhiker versions cannot read
format 5. Reordering contigs invalidates pairs; reversing a contig remaps stored
raw coordinates and operations.

`build_zem_bins.sh` enables `GOEXPERIMENT=simd` by default with Go 1.27.2 or later,
`GOAMD64=v1` and cgo disabled. ARM64 uses NEON; amd64 selects AVX2 at runtime or
falls back to scalar. The distribution still has one binary per OS/architecture.
Use `GOEXPERIMENT=nosimd` for a scalar-only build. CI tests scalar and SIMD builds.

Validation commands, from `zem`:

```sh
go test ./...
GOEXPERIMENT=simd go test ./...
GOEXPERIMENT=simd go test -race ./...
SEQHIKER_COMPARISON_DATA=/path/to/Seqhiker_debug GOMAXPROCS=1 \
  GOEXPERIMENT=simd go test -run '^TestComparisonRealData$' -v -count=1
```

The optional real-data regression runs the original missing-match pair and the
repeat-rich pair through Seqhiker's engine. It checks region recovery, repeats
beyond the old 1,024-block cap, and operation replay for paths within the detail
budget. Synthetic integration tests exercise all combinations of match strand,
display reversals and input exchange, disk caches, session round trips, contig
movement, cancellation, resource errors and legacy-session recomputation.
