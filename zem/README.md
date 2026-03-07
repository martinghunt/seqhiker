# Seqhiker TCP Protocol (zem)

zem is the backend for seqhiker. It is not intended to be used as a
stand-alone tool

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

## Request Payloads

### `MsgLoadGenome` / `MsgLoadBAM`

- `uint16 path_len`
- `[]byte path`

`MsgLoadGenome` accepts a single file or directory containing supported files.

Supported formats:
- sequence: FASTA (`.fa`, `.fasta`, `.fna`, `.ffn`, `.frn`, `.faa`)
- annotation: GFF3 (`.gff`, `.gff3`), EMBL (`.embl`), GenBank (`.gb`, `.gbk`, `.genbank`)

Compressed files are supported for sequence/annotation inputs via `xopen`
(for example `.gz`, `.bgz`, `.bz2`, `.xz`, `.zst`, `.zstd` suffixes).
Type routing falls back to content sniffing when extensions are ambiguous.

`MsgLoadBAM` requires an index file (`.bam.bai` or sibling `.bai`).

### `MsgGetChromosomes`

- empty payload

### `MsgGetTile` / `MsgGetCoverageTile`

- `uint16 chr_id`
- `uint8 zoom`
- `uint32 tile_index`

Tile width = `1024 << zoom`, start = `tile_index * tile_width`.

### `MsgGetGCPlotTile`

- `uint16 chr_id`
- `uint8 zoom`
- `uint32 tile_index`
- `uint32 window_len_bp`

Tile width = `1024 << zoom`, start = `tile_index * tile_width`.

### `MsgGetAnnotations`

- `uint16 chr_id`
- `uint32 start`
- `uint32 end`
- `uint16 max_records`

### `MsgGetReferenceSlice`

- `uint16 chr_id`
- `uint32 start`
- `uint32 end`

### `MsgShutdown`

- empty payload, returns ACK and shuts down the zem server process.

## Response Payloads

### `MsgAck`

- `uint16 msg_len`
- `[]byte message`

### `MsgError`

- `uint16 msg_len`
- `[]byte message`

### `MsgGetChromosomes`

- `uint16 count`
- repeated `count` times:
  - `uint16 id`
  - `uint32 length`
  - `uint16 name_len`
  - `[]byte name`

### `MsgGetTile` (alignment tile)

- `uint8 tile_type` (`2` for alignments)
- `uint32 start`
- `uint32 end`
- `uint32 record_count`
- repeated records:
  - `uint32 aln_start`
  - `uint32 aln_end`
  - `uint8 mapq`
  - `uint8 reverse` (`1` if reverse strand, else `0`)
  - `uint16 flags`
  - `uint32 mate_start` (`0xFFFFFFFF` when unavailable / different ref)
  - `uint32 mate_end` (`0xFFFFFFFF` when unavailable / different ref)
  - `uint32 fragment_len`
  - `uint16 name_len`
  - `[]byte name`
  - `uint16 cigar_len`
  - `[]byte cigar`
  - `uint16 snp_count`
  - repeated `snp_count` times:
    - `uint32 snp_pos_bp`
    - `uint8 snp_base`

Note: alignment records may be empty at low-detail zoom levels. The server only emits read-level records when zoomed in enough for bounded memory usage.
SNP entries are only populated at very detailed zoom levels.

### `MsgGetCoverageTile`

- `uint8 tile_type` (`1` for coverage)
- `uint32 start`
- `uint32 end`
- `uint32 bin_count`
- repeated `bin_count` times:
  - `uint16 depth`

### `MsgGetGCPlotTile`

- `uint8 tile_type` (`3` for GC plot)
- `uint32 start`
- `uint32 end`
- `uint32 window_len_bp`
- `uint32 value_count`
- repeated `value_count` times:
  - `float32 gc_fraction` (`-1.0` means no valid ATGC bases in window)

### `MsgGetAnnotations`

- `uint32 start`
- `uint32 end`
- `uint32 record_count`
- repeated records:
  - `uint32 feature_start`
  - `uint32 feature_end`
  - `uint8 strand`
  - `uint8 reserved` (0)
  - `uint16 seq_name_len`
  - `[]byte seq_name`
  - `uint16 source_len`
  - `[]byte source`
  - `uint16 type_len`
  - `[]byte type`
  - `uint16 attr_len`
  - `[]byte attributes`

### `MsgGetReferenceSlice`

- `uint32 start`
- `uint32 end`
- `uint32 seq_len`
- `[]byte sequence`
