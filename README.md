# seqhiker

Genome browser for FASTA, annotation, and BAM files, with a stacked genome comparison view.

Currently in beta. It is fairly stable. Feel free to give it a try.

Documentation: https://seqhiker.readthedocs.io/en/

<table>
  <tr>
    <td width="50%">
      <a href="docs/_static/seqhiker_screenshot_1.png">
        <img src="docs/_static/seqhiker_screenshot_1.png" alt="seqhiker screenshot 1" width="100%">
      </a>
    </td>
    <td width="50%">
      <a href="docs/_static/seqhiker_screenshot_2.png">
        <img src="docs/_static/seqhiker_screenshot_2.png" alt="seqhiker screenshot 2" width="100%">
      </a>
    </td>
  </tr>
</table>

# Quick Start

## Install

1. Go to the [latest release](../../releases/latest).
2. Download the build for your operating system and architecture.
3. Open the app.

## View genomes

1. Launch `seqhiker`.
2. Drag and drop your files into the window.

A sequence file must be included, for example FASTA, GenBank, EMBL, or a GFF3 file with embedded sequence.

Typical files:
- FASTA
- GenBank
- EMBL
- GFF3
- BAM (sorted and indexed)

`seqhiker` will load the files and open the matching genome view.

A standalone GFF3 with an embedded `##FASTA` section is treated as a sequence-bearing genome file.

You can also switch to `Comparison view` in the toolbar and add genomes one-by-one to compare them.
