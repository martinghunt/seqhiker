# VCF track

## Supported variant files

The browser view can load variant calls from:

- VCF
- compressed VCF such as `.vcf.gz`, `.vcf.xz`, and `.vcf.zst`

When one or more VCF files are loaded, `seqhiker` shows a shared `VCF` track.

## Layout

The VCF track shows:

- one row per sample
- all loaded VCF files combined into the same track
- empty rows except at variant sites

For now, the track renders:

- SNPs
- insertions
- deletions
- complex replacement variants

## Rendering

SNPs are shown as coloured blocks with genotype text when there is enough room.

Genotype colours are grouped into three classes:

- reference call (`0/0`)
- heterozygous call (`0/1`, `1/2`, `1/3`, and similar)
- homozygous ALT call (`1/1`)

For heterozygous SNPs, the text shows both alleles, for example:

- `A/G`
- `G/T`

For homozygous calls, the text shows only the called allele.

Deletions and insertions use compact glyphs similar to the read track.
Complex replacement variants use a wave-like glyph.

## Interaction

You can:

- click a variant to select it
- if the right-hand panel is already open, clicking a variant updates it
- double-click a variant to open its details in the right-hand panel

The right-hand panel shows:

- sample
- file
- type
- CHROM / POS / ID
- REF / ALT / QUAL / FILTER / INFO
- genotype fields for the selected sample
