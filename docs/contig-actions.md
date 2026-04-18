# Contig Actions

`seqhiker` lets you adjust contig orientation and contig order from the
right-click menu on a contig map strip.

This works in both:

- browser mode, for the loaded genome
- comparison view, for each genome row independently

## Opening the menu

- In browser mode, right-click a contig in the map track.
- In comparison view, right-click a contig in that genome row's contig map strip.

## Available actions

The contig menu currently includes:

- `Reverse complement contig`
- `Restore contig forward`
- `Reverse complement all contigs`
- `Restore all contigs forward`
- `Move contig 1 to left`
- `Move contig 1 to right`
- `Move contig to start of genome`
- `Move contig to end of genome`

Some actions are disabled when they would have no effect, for example moving the
leftmost contig further left.

## Browser mode behavior

In browser mode, contig actions update the loaded genome layout immediately.

That includes:

- the concatenated genome layout in concat mode
- the contig list used by `Go`
- the map strip and viewport overlay
- annotations
- read/depth/gc/variant tracks

Reverse-complementing a contig also flips feature orientation and updates the
displayed reference sequence for that contig.

## Comparison view behavior

In comparison view, contig actions apply only to the selected genome row.

When a contig is reverse-complemented or moved, `seqhiker` rebuilds that row's
concatenated coordinates and refreshes:

- annotations on that genome
- pairwise matches connected to neighboring genomes
- comparison detail lookups for affected blocks

Genome row order is separate from contig order:

- drag the row handle to reorder whole genomes
- use the contig right-click menu to reorder contigs within one genome

## Notes

- Browser mode and comparison mode keep separate state.
