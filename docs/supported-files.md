# Supported files

## Sequence files

A sequence file is required. Supported sequence inputs are:

- FASTA
- GenBank
- EMBL
- GFF3 (with sequence)

Without a sequence file, `seqhiker` cannot open a genome view.
If a file with sequence and annotation is used, the annotation will be loaded
together with the sequence.

## Annotation files

Supported annotation input:

- GFF3 (with or without sequence)


## Compressed files

Sequence/annotation files can be uncompressed, or compressed with any of gz, xz, zstd, bzip2.

## Read alignment files

Supported read alignment input:

- BAM

BAM files must be:

- coordinate-sorted
- indexed, with .bam.bai or .bai present

## Download by accession

`seqhiker` can also download genome data by accession from inside the app.

Use this when you want to fetch a reference and annotations without preparing local files first. The downloaded data is then loaded into the same browser view as manually dropped files.

## Typical combinations

Common ways to use `seqhiker`:

- FASTA + GFF3
- FASTA + BAM
- FASTA + GFF3 + BAM
- GenBank alone
- EMBL alone
