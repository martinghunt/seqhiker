# Seqhiker TCP Protocol (`zem`)

`zem` is the backend for seqhiker. It is not intended to be used as a
stand-alone tool.

All frames use little-endian binary encoding.

## Frame Header

- `uint32 length`: payload length in bytes
- `uint16 message_type`
- `uint16 request_id`

Then `length` bytes of payload.

## Message Types

- `1 MsgLoadGenome`
- `2 MsgLoadBAM`
- `3 MsgGetTile`
- `4 MsgGetCoverageTile`
- `5 MsgGetAnnotations`
- `6 MsgGetReferenceSlice`
- `7 MsgAck`
- `8 MsgError`
- `9 MsgShutdown`
- `10 MsgGetChromosomes`
- `11 MsgGetGCPlotTile`
- `12 MsgGetAnnotationCounts`
- `13 MsgGetLoadState`
- `14 MsgInspectInput`
- `15 MsgGetAnnotationTile`
- `16 MsgSearchDNAExact`
- `17 MsgGetStrandCoverageTile`
- `18 MsgDownloadGenome`
- `19 MsgGetVersion`
- `20 MsgGenerateTestData`
- `21 MsgAddComparisonGenome`
- `22 MsgListComparisonGenomes`
- `23 MsgListComparisonPairs`
- `24 MsgGetComparisonBlocks`
- `25 MsgGetComparisonBlocksByGenomes`
- `26 MsgGetComparisonAnnotations`
- `27 MsgSaveComparisonSession`
- `28 MsgLoadComparisonSession`
- `29 MsgResetComparisonState`
- `30 MsgGenerateComparisonTestData`
- `31 MsgGetComparisonReferenceSlice`
- `32 MsgGetComparisonBlockDetail`
- `33 MsgAddComparisonGenomeFiles`
- `34 MsgSearchComparisonDNAExact`
- `40 MsgLoadGenomeFiles`

## Common Encodings

### Path payload

- `uint16 path_len`
- `[]byte path`

Used by:
- `MsgLoadGenome`
- `MsgSaveComparisonSession`
- `MsgLoadComparisonSession`
- `MsgGenerateTestData`
- `MsgGenerateComparisonTestData`
- `MsgInspectInput`

### String-list payload

- `uint16 count`
- repeated `count` times:
  - `uint16 str_len`
  - `[]byte value`

Used by:
- `MsgAddComparisonGenomeFiles`
- `MsgLoadGenomeFiles`

Returned by:
- `MsgDownloadGenome`
- `MsgGenerateTestData`
- `MsgGenerateComparisonTestData`

### ACK / error payload

- `uint16 msg_len`
- `[]byte message`

Used by:
- `MsgAck`
- `MsgError`
- `MsgGetVersion`

## Request Payloads

### `MsgLoadGenome`

Path payload.

Accepts a single file or a directory containing supported files.

Supported formats:
- sequence: FASTA (`.fa`, `.fasta`, `.fna`, `.ffn`, `.frn`, `.faa`)
- annotation: GFF3 (`.gff`, `.gff3`), EMBL (`.embl`), GenBank (`.gb`, `.gbk`, `.genbank`)

Compressed files are supported for sequence/annotation inputs via `xopen`
(`.gz`, `.bgz`, `.bz2`, `.xz`, `.zst`, `.zstd`). Type routing falls back to
content sniffing when extensions are ambiguous.

### `MsgLoadGenomeFiles`

String-list payload.

Loads one single-genome session from multiple related genome / annotation
paths in one request, using the same snapshot merge behavior as
`MsgLoadGenome`.

### `MsgLoadBAM`

Two accepted payload forms:

Basic form:
- `uint16 path_len`
- `[]byte path`

Extended form:
- `uint8 marker` = `0xFF`
- `uint32 low_coverage_cutoff`
- `uint16 path_len`
- `[]byte path`

`MsgLoadBAM` requires an index file (`.bam.bai` or sibling `.bai`).

### `MsgGetTile`

Request supports an optional BAM source id.

Without source id:
- `uint16 chr_id`
- `uint8 zoom`
- `uint32 tile_index`

With source id:
- `uint16 source_id`
- `uint16 chr_id`
- `uint8 zoom`
- `uint32 tile_index`

Tile width = `1024 << zoom`, start = `tile_index * tile_width`.

### `MsgGetCoverageTile`

Same payload shape as `MsgGetTile`.

### `MsgGetStrandCoverageTile`

Same payload shape as `MsgGetTile`.

### `MsgGetGCPlotTile`

- `uint16 chr_id`
- `uint8 zoom`
- `uint32 tile_index`
- `uint32 window_len_bp`

### `MsgGetAnnotations`

- `uint16 chr_id`
- `uint32 start`
- `uint32 end`
- `uint16 max_records`
- `uint32 min_feature_len_bp`

### `MsgGetAnnotationTile`

- `uint16 chr_id`
- `uint8 zoom`
- `uint32 tile_index`
- `uint16 max_records`
- `uint32 min_feature_len_bp`

### `MsgGetReferenceSlice`

- `uint16 chr_id`
- `uint32 start`
- `uint32 end`

### `MsgGetChromosomes`

Empty payload.

### `MsgGetAnnotationCounts`

Empty payload.

### `MsgGetLoadState`

Empty payload.

### `MsgInspectInput`

Path payload.

### `MsgSearchDNAExact`

- `uint16 chr_id`
- `uint16 max_hits`
- `uint8 include_reverse_complement`
- `uint16 pattern_len`
- `[]byte pattern`

### `MsgSearchComparisonDNAExact`

- `uint16 comparison_genome_id`
- `uint16 max_hits`
- `uint8 include_reverse_complement`
- `uint16 pattern_len`
- `[]byte pattern`

### `MsgDownloadGenome`

- `uint16 accession_len`
- `[]byte accession`
- `uint16 cache_dir_len`
- `[]byte cache_dir`
- `uint32 max_cache_bytes`

### `MsgShutdown`

Empty payload. Returns ACK and shuts down the `zem` server process.

### `MsgGenerateTestData`

Path payload. The path is the output root directory.

### `MsgAddComparisonGenome`

Path payload.

Adds one sequence-bearing input to comparison mode.

### `MsgAddComparisonGenomeFiles`

String-list payload.

Adds one comparison genome from multiple related files, for example
FASTA + GFF3.

### `MsgListComparisonGenomes`

Empty payload.

### `MsgListComparisonPairs`

Empty payload.

### `MsgGetComparisonBlocks`

- `uint16 pair_id`

### `MsgGetComparisonBlocksByGenomes`

- `uint16 query_genome_id`
- `uint16 target_genome_id`

### `MsgGetComparisonAnnotations`

- `uint16 genome_id`
- `uint32 start`
- `uint32 end`
- `uint16 max_records`
- `uint32 min_feature_len_bp`

### `MsgGetComparisonReferenceSlice`

- `uint16 genome_id`
- `uint32 start`
- `uint32 end`

### `MsgGetComparisonBlockDetail`

- `uint16 query_genome_id`
- `uint16 target_genome_id`
- `uint32 query_start`
- `uint32 query_end`
- `uint32 target_start`
- `uint32 target_end`
- `uint8 same_strand`

### `MsgSaveComparisonSession`

Path payload.

Saves a self-contained comparison session file. The on-disk file is content
identified by a seqhiker-specific magic header.

### `MsgLoadComparisonSession`

Path payload.

### `MsgResetComparisonState`

Empty payload.

### `MsgGenerateComparisonTestData`

Path payload. The path is the output root directory.

## Response Payloads

### `MsgAck`

ACK / error payload.

### `MsgError`

ACK / error payload.

### `MsgGetVersion`

ACK / error payload containing the backend version string.

### `MsgGetChromosomes`

- `uint16 count`
- repeated `count` times:
  - `uint16 id`
  - `uint32 length`
  - `uint16 name_len`
  - `[]byte name`

### `MsgGetAnnotationCounts`

- `uint16 count`
- repeated `count` times:
  - `uint16 id`
  - `uint32 count`

### `MsgGetLoadState`

- `uint8 has_sequence`
  - `1` if a reference sequence is loaded
  - `0` otherwise

### `MsgInspectInput`

- `uint8 flags`
  - bit 0: path contains sequence-bearing input
  - bit 1: path contains annotation input
  - bit 2: path is a seqhiker comparison session file

### `MsgSearchDNAExact` / `MsgSearchComparisonDNAExact`

- `uint8 truncated`
  - `1` if hits were truncated at `max_hits`
- `uint16 hit_count`
- repeated `hit_count` times:
  - `uint32 start`
  - `uint32 end`
  - `uint8 strand`
    - `'+'` for forward
    - `'-'` for reverse-complement

### `MsgDownloadGenome`

String-list payload containing installed file paths.

### `MsgGenerateTestData`

String-list payload containing generated file paths.

### `MsgGenerateComparisonTestData`

String-list payload containing generated file paths.

### `MsgGetTile` (alignment tile)

- `uint8 tile_type` = `2`
- `uint32 start`
- `uint32 end`
- `uint32 record_count`
- repeated `record_count` times:
  - `uint32 aln_start`
  - `uint32 aln_end`
  - `uint8 mapq`
  - `uint8 reverse`
  - `uint16 flags`
  - `uint32 mate_start`
    - `0xFFFFFFFF` when unavailable or different reference
  - `uint32 mate_end`
    - `0xFFFFFFFF` when unavailable or different reference
  - `uint32 fragment_len`
  - `uint32 mate_raw_start`
    - `0xFFFFFFFF` when unavailable
  - `uint32 mate_raw_end`
    - `0xFFFFFFFF` when unavailable
  - `uint32 mate_ref_id`
    - `0xFFFFFFFF` when unavailable
  - `uint16 name_len`
  - `[]byte name`
  - `uint16 cigar_len`
  - `[]byte cigar`
  - `uint16 left_soft_clip_len`
  - `[]byte left_soft_clip`
  - `uint16 right_soft_clip_len`
  - `[]byte right_soft_clip`
  - `uint16 snp_count`
  - repeated `snp_count` times:
    - `uint32 snp_pos_bp`
    - `uint8 snp_base`

Alignment records may be empty at low-detail zoom levels. The server only
emits read-level records when zoomed in enough for bounded memory usage.

### `MsgGetCoverageTile`

- `uint8 tile_type` = `1`
- `uint32 start`
- `uint32 end`
- `uint32 bin_count`
- repeated `bin_count` times:
  - `uint16 depth`

### `MsgGetStrandCoverageTile`

- `uint8 tile_type` = `4`
- `uint32 start`
- `uint32 end`
- `uint32 bin_count`
- repeated `bin_count` times:
  - `uint16 forward_depth`
- repeated `bin_count` times:
  - `uint16 reverse_depth`

### `MsgGetGCPlotTile`

- `uint8 tile_type` = `3`
- `uint32 start`
- `uint32 end`
- `uint32 window_len_bp`
- `uint32 value_count`
- repeated `value_count` times:
  - `float32 gc_fraction`
    - `-1.0` means no valid ATGC bases in the window

### `MsgGetAnnotations` / `MsgGetAnnotationTile` / `MsgGetComparisonAnnotations`

- `uint32 start`
- `uint32 end`
- `uint32 record_count`
- repeated `record_count` times:
  - `uint32 feature_start`
  - `uint32 feature_end`
  - `uint8 strand`
  - `uint8 reserved` = `0`
  - `uint16 seq_name_len`
  - `[]byte seq_name`
  - `uint16 source_len`
  - `[]byte source`
  - `uint16 type_len`
  - `[]byte type`
  - `uint16 attr_len`
  - `[]byte attributes`

### `MsgGetReferenceSlice` / `MsgGetComparisonReferenceSlice`

- `uint32 start`
- `uint32 end`
- `uint32 seq_len`
- `[]byte sequence`

### `MsgAddComparisonGenome` / `MsgListComparisonGenomes`

- `uint16 genome_count`
- repeated `genome_count` times:
  - `uint16 genome_id`
  - `uint32 genome_length`
  - `uint16 segment_count`
  - `uint32 feature_count`
  - `uint16 name_len`
  - `[]byte name`
  - `uint16 path_len`
  - `[]byte path`
  - repeated `segment_count` times:
    - `uint32 segment_start`
    - `uint32 segment_end`
    - `uint32 segment_feature_count`
    - `uint16 segment_name_len`
    - `[]byte segment_name`

### `MsgListComparisonPairs`

- `uint16 pair_count`
- repeated `pair_count` times:
  - `uint16 pair_id`
  - `uint16 top_genome_id`
  - `uint16 bottom_genome_id`
  - `uint32 block_count`
  - `uint8 status`

### `MsgGetComparisonBlocks` / `MsgGetComparisonBlocksByGenomes`

- `uint16 block_count`
- repeated `block_count` times:
  - `uint32 query_start`
  - `uint32 query_end`
  - `uint32 target_start`
  - `uint32 target_end`
  - `uint16 percent_identity_x100`
  - `uint8 same_strand`

### `MsgGetComparisonBlockDetail`

- `uint32 query_start`
- `uint32 query_end`
- `uint32 target_start`
- `uint32 target_end`
- `uint16 percent_identity_x100`
- `uint8 same_strand`
- `uint32 ops_len`
- `[]byte ops`
- `uint16 variant_count`
- repeated `variant_count` times:
  - `uint8 kind`
  - `uint32 query_pos`
  - `uint32 target_pos`
  - `uint16 ref_bases_len`
  - `uint16 alt_bases_len`
  - `[]byte ref_bases`
  - `[]byte alt_bases`

The `ops` string is the compact base-level alignment trace used by the
comparison detail renderer.

## Notes

- Comparison sessions are self-contained files owned by `zem`, not just UI
  snapshots.
- Comparison inputs and session files are detected by content where possible,
  not just filename extension.
- Comparison block detail is cached separately from coarse blocks.
