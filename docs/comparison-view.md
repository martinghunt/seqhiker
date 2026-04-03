# Comparison view

`seqhiker` can compare multiple genomes in a stacked view with pairwise matches drawn between neighboring genomes.

## Opening comparison view

- Click the view-switch button in the top toolbar to switch from the browser to `Comparison view`.
- With comparison view open:
  - drag genome files into the window one-by-one
  - or use the download button to fetch genomes directly into the comparison stack

When no genomes are loaded, the view shows an empty-state prompt.

## Loading genomes

Comparison mode accepts the same sequence and annotation sources as browser mode:

- FASTA
- GenBank
- EMBL
- GFF3 with embedded sequence
- FASTA plus companion GFF3

If you drop a sequence file together with its matching GFF3, the comparison genome is loaded with annotations.

## Layout

Each genome row shows:

- forward-strand annotations
- a contig map strip
- nucleotide letters when zoomed in enough
- coordinate axis
- reverse-strand annotations

Matches are drawn only between neighboring genomes in the stack.

## Core interactions

- Drag the "up/down arrow" button to reorder genomes.
- Use the lock buttons between rows to lock or unlock neighboring genomes.
- Locked genomes pan together.
- Double-click a match to align that match near the left side of the visible window.
- Click a match to select it and open details in the right panel.
- Click empty space to clear the selected match.

## Region selection

Click and drag across a genome row to select a region.

That:

- highlights the selected interval on that genome
- opens a `selected matches` panel on the right
- lists overlapping matches to the genome above and/or below

Selecting a result in that panel focuses the corresponding match in the main view.

## Search and Go

In comparison mode:

- `Search` includes a genome dropdown
- `Go` includes both a genome dropdown and a chromosome/contig dropdown

Search results include the matching genome name. Go ranges also adjust the comparison zoom when a range is entered.

## Zoomed-in detail

At high zoom, comparison mode shows:

- nucleotide letters
- per-base alignment connectors
- sine-wave SNP connectors in a contrasting theme color

Indels appear as non-parallel lines in the alignment.

## Saving and loading sessions

Comparison mode can save the current comparison session to a custom file.
These files can be dropped back into the app later to restore the comparison
genomes.

## Temporary view slots

Comparison mode has its own temporary view slots, separate from browser mode:

- `Shift+1` to `Shift+9` save slots
- `1` to `9` load slots

The saved state includes:

- row order
- per-genome offsets
- current zoom span

## Export

The screenshot button exports the current comparison viewport as SVG.

Only the currently visible comparison content is exported, and match geometry is clipped to the visible window.
