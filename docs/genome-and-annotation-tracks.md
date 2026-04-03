# Genome and annotation tracks

## Genome track

The genome track shows:

- the current genomic axis
- coordinate ticks
- base letters when zoomed in enough
- annotation features over the genome

At close zoom, individual bases can be drawn directly on the reference track.

## Annotation track

The annotation track shows genome features in a dedicated lane above the genome track.

This is useful when you want a cleaner feature view without the genome-axis overlay.

When you are zoomed out beyond nucleotide level, the `AA / Annotation` track can also
show six-frame stop-codon overview markers. These appear as theme-coloured vertical
markers under the annotation rectangles, similar to the overview in Artemis. Stop-free
stretches are left clear, so likely ORFs stand out by eye.

You can turn this on in the `AA / Annotation` track settings with `Show stop codons`.

## Multi-exon features

For multi-exon genes:

- the annotation track shows separate exon blocks connected across the intron
- the genome track shows full-height exons with reduced-height introns between them

This makes exon structure visible at a glance.

## Interaction

You can:

- click features to select them
- double-click features to activate them
- double-click empty space to recenter the view

Selected features can be inspected in the right-hand panel.
