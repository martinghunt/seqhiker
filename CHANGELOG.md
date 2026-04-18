# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Theme editor with live preview, and JSON import/export of themes
- Options to reverse complement and move contigs via right-click menu
- Comparison mode: allow panning past end of genome, and zoom out a bit more than full genome width

### Fixed
- Bug where genomes in comparison mode couldn't be reordered, press button and drag did nothing.
- Reverse complement nucleotide colours were wrong, and now nucleotide colours work in comparison mode.
- Improved matches in comparison mode, previously very low percent identity matches are now split into more accurate higher percent identity matches.
- Some matches incorrectly reported as low, when actually high. Zooming in showed no match lines in these cases, but now also fixed.
- Comparison mode bug where matches could be missing at repeats, noticeable in order genomes were added or when trying to compare genome to itself
- Windows icon in file manager shows seqhiker icon instead of Godot default icon

## [1.0.0] - "Total Perspective" - 2026-04-05

### Added
- VCF support - shows variants from VCF in a dedicated track.
- Genome comparison view with per-genome rows, locking, reordering, toolbar actions, and comparison session save/load.
- Match selection, double-click navigation, region selection, selected-match lists, and comparison-mode search/go integration.
- Nucleotide-level comparison detail rendering with per-base connectors, SNP styling, and SVG export for comparison screenshots.
- Comparison view slots, empty-state prompts, viewport label updates, and comparison-specific loading/clear interactions.
- Support for standalone GFF3 files with embedded `##FASTA`, including annotation-only merge when a matching genome is already loaded.
- Built-in test reads for soft-clipped overhangs at contig edges.
- Optional Artemis-style stop-codon overview markers in the AA / annotation track.
- Optional UI sounds

### Changed
- The Go panel, top bar, and context panel logic were extracted into dedicated controllers to reduce `main.gd` complexity.
- SVG exports now write explicit pixel units so saved screenshots open at sensible sizes in external tools.
- Windows release packaging now produces `.zip` archives instead of bare `.exe` artifacts.
- Linux release packaging now produces `.tar.gz` archives instead of bare executables.
- Settings now always show both built-in test-data buttons, with the single-genome button renamed and each button switching to the appropriate view before loading data.

### Fixed
- Handle FASTA inputs without line breaks.
- Browser clear now fully resets viewport state instead of leaving stale zoom/axis artifacts visible.
- Comparison loading now handles first-genome add, grouped FASTA+annotation inputs, downloads, and runtime row reuse more reliably.
- Comparison rows now respect font/theme settings more consistently, including sequence-letter font choice.
- Screenshot button now does nothing when the active view is empty, and no longer stays visually highlighted after being pressed.
- Soft-clipped reads can now display past the start/end of a contig in single-sequence view, and concat mode now adds extra inter-contig spacing when needed.
- BAM loading now checks for coordinate sorting first and shows native guidance when a BAM is unsorted or missing its index.
- Always hide autoplay speed setting, while the underlying code remains in place, in case reinstated in future.

## [0.42.0] - 2026-03-28

Release `v0.42.0` ("Mostly Harmless"), before changelog tracking started in this file.

[Unreleased]: https://github.com/martinghunt/seqhiker/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/martinghunt/seqhiker/compare/v0.42.0...v1.0.0
[0.42.0]: https://github.com/martinghunt/seqhiker/releases/tag/v0.42.0
