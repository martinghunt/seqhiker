#!/usr/bin/env python3

"""
Build a tiny reproducible BAM fixture for zem tests.

This script is meant to be run manually. It requires:
  - /opt/homebrew/bin/minimap2
  - /opt/homebrew/bin/samtools

It writes:
  - a random reference FASTA
  - one paired-end FASTQ pair
  - one singleton FASTQ
  - a merged, coordinate-sorted, indexed BAM

The tests should read only the committed BAM/BAI fixtures. This script exists
only so the fixtures can be regenerated reproducibly.
"""

from __future__ import annotations

import random
import subprocess
from pathlib import Path

MINIMAP2 = Path("/opt/homebrew/bin/minimap2")
SAMTOOLS = Path("/opt/homebrew/bin/samtools")

OUT_DIR = Path(__file__).resolve().parent
REF_NAME = "chrTest"
REF_LENGTH = 4000
RANDOM_SEED = 17

REF_FASTA = OUT_DIR / "test_reads.ref.fa"
PAIRED_R1_FASTQ = OUT_DIR / "test_reads_R1.fastq"
PAIRED_R2_FASTQ = OUT_DIR / "test_reads_R2.fastq"
SINGLES_FASTQ = OUT_DIR / "test_reads_single.fastq"
PAIRED_BAM = OUT_DIR / "test_reads.paired.bam"
SINGLES_BAM = OUT_DIR / "test_reads.single.bam"
MERGED_BAM = OUT_DIR / "test_reads.bam"
MERGED_BAI = OUT_DIR / "test_reads.bam.bai"


# Paired templates use FR orientation:
# - R1 is forward from left_start
# - R2 is reverse-complemented from right_start
PAIR_SPECS = [
    {
        "name": "pair1",
        "left_start": 200,
        "right_start": 420,
        "read_length": 125,
        "r1_mutate": {},
        "r2_mutate": {},
    },
]


SINGLE_SPECS = [
    {
        "name": "single_fwd",
        "start": 900,
        "length": 140,
        "reverse": False,
        "mutate": {25: "A", 61: "T"},
    },
    {
        "name": "single_rev",
        "start": 1500,
        "length": 135,
        "reverse": True,
        "mutate": {},
    },
    {
        "name": "indel_like",
        "start": 2200,
        "length": 150,
        "reverse": False,
        "mutate": {70: "CT", 110: ""},
    },
]


def reverse_complement(seq: str) -> str:
    table = str.maketrans("ACGT", "TGCA")
    return seq.translate(table)[::-1]


def random_dna(length: int, seed: int) -> str:
    rng = random.Random(seed)
    alphabet = "ACGT"
    return "".join(rng.choice(alphabet) for _ in range(length))


def wrap_fasta(seq: str, width: int = 80) -> str:
    return "\n".join(seq[i : i + width] for i in range(0, len(seq), width))


def apply_mutations(seq: str, mutate: dict[int, str]) -> str:
    bases = list(seq)
    for offset, base in mutate.items():
        if 0 <= offset < len(bases):
            bases[offset : offset + 1] = list(base.upper())
    return "".join(bases)


def slice_reference(ref_seq: str, start: int, length: int) -> str:
    end = start + length
    if start < 0 or end > len(ref_seq):
        raise ValueError(f"reference slice {start}:{end} is out of bounds")
    return ref_seq[start:end]


def build_single_sequence(ref_seq: str, spec: dict) -> str:
    seq = slice_reference(ref_seq, spec["start"], spec["length"])
    seq = apply_mutations(seq, spec.get("mutate", {}))
    if spec.get("reverse", False):
        seq = reverse_complement(seq)
    return seq


def build_pair_sequences(ref_seq: str, spec: dict) -> tuple[str, str]:
    read_length = spec["read_length"]
    left_seq = slice_reference(ref_seq, spec["left_start"], read_length)
    right_seq = slice_reference(ref_seq, spec["right_start"], read_length)
    r1 = apply_mutations(left_seq, spec.get("r1_mutate", {}))
    r2 = reverse_complement(apply_mutations(right_seq, spec.get("r2_mutate", {})))
    return r1, r2


def write_reference(ref_seq: str) -> None:
    REF_FASTA.write_text(f">{REF_NAME}\n{wrap_fasta(ref_seq)}\n", encoding="ascii")


def write_fastq_record(name: str, seq: str) -> str:
    qual = "I" * len(seq)
    return f"@{name}\n{seq}\n+\n{qual}\n"


def write_inputs(ref_seq: str) -> None:
    r1_records: list[str] = []
    r2_records: list[str] = []
    single_records: list[str] = []

    for spec in PAIR_SPECS:
        r1, r2 = build_pair_sequences(ref_seq, spec)
        r1_records.append(write_fastq_record(spec["name"], r1))
        r2_records.append(write_fastq_record(spec["name"], r2))

    for spec in SINGLE_SPECS:
        seq = build_single_sequence(ref_seq, spec)
        single_records.append(write_fastq_record(spec["name"], seq))

    PAIRED_R1_FASTQ.write_text("".join(r1_records), encoding="ascii")
    PAIRED_R2_FASTQ.write_text("".join(r2_records), encoding="ascii")
    SINGLES_FASTQ.write_text("".join(single_records), encoding="ascii")


def run(cmd: list[str]) -> None:
    print("+", " ".join(str(part) for part in cmd))
    subprocess.run(cmd, check=True)


def run_pipeline(cmd1: list[str], cmd2: list[str]) -> None:
    print(
        "+",
        " ".join(str(part) for part in cmd1),
        "|",
        " ".join(str(part) for part in cmd2),
    )
    with subprocess.Popen(cmd1, stdout=subprocess.PIPE) as p1:
        with subprocess.Popen(cmd2, stdin=p1.stdout) as p2:
            assert p1.stdout is not None
            p1.stdout.close()
            rc2 = p2.wait()
            rc1 = p1.wait()
    if rc1 != 0 or rc2 != 0:
        raise SystemExit(f"pipeline failed: first={rc1} second={rc2}")


def ensure_tools() -> None:
    missing = [str(p) for p in (MINIMAP2, SAMTOOLS) if not p.exists()]
    if missing:
        raise SystemExit(f"missing required tools: {', '.join(missing)}")


def remove_if_exists(path: Path) -> None:
    if path.exists():
        path.unlink()


def build_bam() -> None:
    for path in (PAIRED_BAM, SINGLES_BAM, MERGED_BAM, MERGED_BAI):
        remove_if_exists(path)

    run_pipeline(
        [
            str(MINIMAP2),
            "-a",
            "-x",
            "sr",
            str(REF_FASTA),
            str(PAIRED_R1_FASTQ),
            str(PAIRED_R2_FASTQ),
        ],
        [
            str(SAMTOOLS),
            "sort",
            "-o",
            str(PAIRED_BAM),
            "-",
        ],
    )

    run_pipeline(
        [
            str(MINIMAP2),
            "-a",
            "-x",
            "sr",
            str(REF_FASTA),
            str(SINGLES_FASTQ),
        ],
        [
            str(SAMTOOLS),
            "sort",
            "-o",
            str(SINGLES_BAM),
            "-",
        ],
    )

    run(
        [
            str(SAMTOOLS),
            "merge",
            "-f",
            str(MERGED_BAM),
            str(PAIRED_BAM),
            str(SINGLES_BAM),
        ]
    )
    run([str(SAMTOOLS), "index", str(MERGED_BAM)])
    run([str(SAMTOOLS), "flagstat", str(MERGED_BAM)])


def main() -> None:
    ensure_tools()
    ref_seq = random_dna(REF_LENGTH, RANDOM_SEED)
    write_reference(ref_seq)
    write_inputs(ref_seq)
    build_bam()
    print(f"wrote {REF_FASTA}")
    print(f"wrote {PAIRED_R1_FASTQ}")
    print(f"wrote {PAIRED_R2_FASTQ}")
    print(f"wrote {SINGLES_FASTQ}")
    print(f"wrote {MERGED_BAM}")
    print(f"wrote {MERGED_BAI}")


if __name__ == "__main__":
    main()
