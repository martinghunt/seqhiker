# Vim Mode

Vim mode adds keyboard-driven navigation and commands. Enable it from the
settings panel with the `Vim Mode` toggle. When Vim mode is off, these Vim keys
are ignored and the normal app shortcuts keep their usual behavior.

When Vim mode is on, a single-line command bar is shown at the bottom of the
window. It is used for commands, searches, counts, and short status messages.

## Normal-mode keys

These keys work when Vim mode is enabled and the command bar is not actively
editing a `:` command or `/` search.

| Key | Action |
| --- | --- |
| `h` | Pan left by one pan step. |
| `l` | Pan right by one pan step. |
| `j` | Zoom out one step. |
| `k` | Zoom in one step. |
| `gg` | Jump to the start of the current sequence. |
| `<number>gg` | Jump to that 1-based position in the current sequence. For example, `500gg` jumps to position 500. |
| `G` | Jump to the end of the current sequence. |
| `gc`, `]c` | Jump to the start of the next contig. |
| `gC`, `[c` | Jump to the start of the previous contig. |
| `n` | Move to the next search hit. |
| `N` | Move to the previous search hit. |
| `w` | Move to the next annotation feature when a feature is selected. |
| `b` | Move to the previous annotation feature when a feature is selected. |
| `m<letter>` | Save the current view as a mark. For example, `ma` sets mark `a`. |
| `'<letter>` | Load a mark. For example, `'a` jumps to mark `a`. |
| `gv` | Toggle between single genome view and comparison view. |
| `ZZ` | Quit the app. |
| `:` | Open the Vim command prompt. |
| `/` | Open the Vim search prompt. |

The pan and zoom keys apply to the active view. Browser-only navigation, such as
`gg`, `G`, contig jumps, feature jumps, `go`, and Vim `/` search, requires the
single genome browser view.

## Counts

Counts can be typed before several normal-mode commands. The count is shown in
the command bar while it is being entered.

Supported counted commands:

| Command | Meaning |
| --- | --- |
| `<number>h` | Pan left by that many pan steps. |
| `<number>l` | Pan right by that many pan steps. |
| `<number>n` | Move forward by that many search hits. |
| `<number>N` | Move backward by that many search hits. |
| `<number>gg` | Jump to that position in the current sequence. |
| `<number>gc`, `<number>]c` | Jump forward by that many contigs. |
| `<number>gC`, `<number>[c` | Jump backward by that many contigs. |
| `<number>w` | Move forward by that many annotation features. |
| `<number>b` | Move backward by that many annotation features. |

Contig navigation clamps at the first or last contig. Feature navigation clamps
at the first or last feature. In concatenate view, feature navigation continues
across contig boundaries and skips contigs that have no annotation features.

## Marks

Marks save and restore view positions.

- `m<letter>` saves the current view to a mark.
- `'<letter>` loads that mark.

For example:

- `ma` saves mark `a`
- `'a` jumps to mark `a`

When a mark is saved, the command bar shows `mark <letter> set`. When a mark is
loaded, it shows `jumped to mark <letter>`.

Marks use the same view-state saving code as the numbered temporary view slots.
Browser view and comparison view keep separate saved-view banks.

## Annotation feature navigation

Feature navigation works after selecting an annotation feature.

- `w` selects the next annotation feature.
- `b` selects the previous annotation feature.
- Counts work, such as `5w` or `3b`.

In concatenate view, moving past the final feature of one contig continues to the
first feature of the next contig with annotations. Moving backward from the first
feature of a contig continues to the previous contig with annotations.

The command bar shows the selected feature label and its position within the
current contig's feature list, such as `geneA 12/80`. At the ends, it shows
`first feature` or `last feature`.

## Search result navigation

After using the search panel or Vim `/` search, use:

- `n` for the next hit
- `N` for the previous hit

Counts are supported, such as `5n` or `2N`.

The command bar shows the selected search result as `search hit x/y`. Clicking a
search result in the search panel also updates this Vim message.

## Command prompt

Press `:` to type a Vim command. Press `Enter` to run it. Press `Escape` to exit
the prompt without running it.

If a `:` command is active, `Escape` only exits the command prompt. It does not
also close panels. If the command prompt is not active, `Escape` keeps the app's
normal behavior.

Implemented commands:

| Command | Action |
| --- | --- |
| `:go <position>` | Jump to a 1-based position in the current sequence. |
| `:go <start>-<end>` | Jump to a range in the current sequence. |
| `:go <sequence>:<position>` | Jump to a position in a named sequence. |
| `:go <sequence>:<start>-<end>` | Jump to a range in a named sequence. |
| `:go <sequence> <position>` | Space-separated form for a named sequence. |
| `:go <sequence> <start>-<end>` | Space-separated range form for a named sequence. |
| `:open` | Open the native file picker, like pressing the open file button. |
| `:open <path>` | Open a file from a filesystem path. |
| `:colorscheme <theme>` | Switch to a theme. This uses standard Vim-style `colorscheme` syntax. |
| `:view single` | Switch to single genome view. |
| `:view comparison` | Switch to comparison view. |
| `:q` | Quit the app. |
| `:quit` | Quit the app. |

Position and range examples:

```text
:go 123
:go 100-250
:go contig1:123
:go contig1:100-250
:go sample:contig1:500
:go sample:contig1 500
```

The colon form is the preferred sequence syntax. The space-separated sequence
form is also available when it is clearer for sequence names that contain
colons.

Open examples:

```text
:open
:open /path/to/foo.fasta
:open "/path/to/foo bar.fasta"
```

## Search prompt

Press `/` to type a search. Press `Enter` to run it. Press `Escape` to exit the
prompt without running it.

Searches open the search panel with the results.

The first word chooses the search type:

- `annotation`, or any unambiguous prefix such as `a`, `an`, or `annot`
- `dna`, or any unambiguous prefix such as `d` or `dn`

Annotation search examples:

```text
/a gene1
/an contig1 gene1
/annot contig2 foo bar
```

DNA search examples:

```text
/d ACGT
/dna contig24 gtcgtacgtcag
```

If the search prompt contains a single word made only of `A`, `C`, `G`, and `T`
characters, it is treated as a whole-genome DNA search:

```text
/ACGT
```

For annotation and DNA searches, if the first word after the search type matches
a sequence name, the search is restricted to that sequence. Otherwise the search
runs across all sequences and the rest of the text is treated as the query.

## Completion and history

Press `Tab` in the command bar to cycle through available completions.

Completion is implemented for:

- `:` command names, such as `go`, `open`, `colorscheme`, `view`, `q`, and `quit`
- sequence names after `:go`
- theme names after `:colorscheme`
- `single` and `comparison` after `:view`
- sequence names after the search target in `/annotation` or `/dna` searches

Press `Up` and `Down` in the command bar to move through prompt history.
History is session-only, keeps the last 100 commands, and is stored separately
for `:` commands and `/` searches.
