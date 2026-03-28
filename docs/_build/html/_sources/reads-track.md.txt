# Reads track

## Detailed and summary views

The reads track changes with zoom level.

When zoomed in, `seqhiker` shows individual reads.
When zoomed further out, it switches to summary representations such as coverage and strand summaries.

## Read views

The reads track supports multiple view modes:

- stack
- strand stack
- paired
- fragment

These can be changed in the read-track settings.

## BAM display

At close zoom, the reads track can show:

- individual read rectangles
- SNP markers and nucleotide letters
- deletions
- optional soft-clipped overhangs
- optional pileup logo

## Pileup logo

When enabled at base-level zoom, the pileup logo summarizes the visible read pileup per genomic position.

- In most read views, it is drawn as a band inside the reads track
- In strand stack mode, separate logos are shown for forward and reverse strands

## Soft-clipped bases

When enabled, soft-clipped read ends are shown as overhang blocks beyond the aligned read body.

At high enough zoom, the clipped bases themselves are drawn as letters.


## Read details

Double-click a read to inspect it in the right-hand panel.

For paired reads, the panel can also expose mate-jump actions when mate coordinates are available.
