# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Genome comparison view with per-genome rows, locking, reordering, toolbar actions, and comparison session save/load.
- Match selection, double-click navigation, region selection, selected-match lists, and comparison-mode search/go integration.
- Nucleotide-level comparison detail rendering with per-base connectors, SNP styling, and SVG export for comparison screenshots.
- Comparison view slots, empty-state prompts, viewport label updates, and comparison-specific loading/clear interactions.
- Support for standalone GFF3 files with embedded `##FASTA`, including annotation-only merge when a matching genome is already loaded.
- Built-in test reads for soft-clipped overhangs at contig edges.

### Changed
- The Go panel, top bar, and context panel logic were extracted into dedicated controllers to reduce `main.gd` complexity.
- SVG exports now write explicit pixel units so saved screenshots open at sensible sizes in external tools.

### Fixed
- Handle FASTA inputs without line breaks.
- Browser clear now fully resets viewport state instead of leaving stale zoom/axis artifacts visible.
- Comparison loading now handles first-genome add, grouped FASTA+annotation inputs, downloads, and runtime row reuse more reliably.
- Comparison rows now respect font/theme settings more consistently, including sequence-letter font choice.
- Soft-clipped reads can now display past the start/end of a contig in single-sequence view, and concat mode now adds extra inter-contig spacing when needed.

## [0.42.0] - 2026-03-28

Release `v0.42.0` ("Mostly Harmless"), before changelog tracking started in this file.

[Unreleased]: https://github.com/martinghunt/seqhiker/compare/v0.42.0...HEAD
[0.42.0]: https://github.com/martinghunt/seqhiker/releases/tag/v0.42.0
