# Navigation

## Mouse and wheel

- Mouse wheel: zoom in and out
- Shift + mouse wheel: pan left and right
- Horizontal mouse wheel: pan left and right
- Drag on the map track: move the current viewport
- Click on the map track outside the current viewport: jump to that region
- Double-click empty space in the genome or annotation tracks: center that position in the window

In comparison view:

- double-click in a genome axis/coordinate band to center that position in the visible genome area
- double-click a match to align that match in the view
- click and drag across a genome row to select a comparison interval
- right-click a contig in a map strip to reverse-complement or reorder that contig

## Trackpad

- Horizontal two-finger swipe: pan
- Pinch: zoom
- Vertical swipe zoom can also be enabled in settings

Trackpad and wheel sensitivity can be changed in the settings panel.

## Toolbar controls

The toolbar at the top provides (keyboard shortcuts in brackets):

- open/close settings panel (s)
- switch between browser and comparison view
- jump to start (shift-left arrow)
- pan left (left arrow)
- pan right (right arrow)
- jump to end (shift-right arrow)
- zoom out (-)
- zoom in (+)
- search (ctl/cmd-f)
- go to position (ctl/cmd-g)
- screenshot export as SVG
- clear current browser/comparison state

The shortcut are shown also shown in the tooltips (ie on mouse hover) inside the app.

## Selection

- Click a feature to select it
- Click a read to select it
- Click a variant to select it
- Double-click a feature or read to open its detailed panel action
- Double-click a variant to open its detailed panel action
- Click and drag across the genome / annotation area to select a genomic region
- In comparison view, click a match to select it
- In comparison view, click and drag across a genome row to select a region and list overlapping matches

Selection in genome view just selects the region for now; in future it will
allow for things like copying and pasting highlighted sequence.


## Temporary save/jump views

Pressing shift+1 will save the current position and zoom level.
Pressing 1 later will jump back to that position/zoom. This works for the
numbers 1-9, giving nine save slots.

Browser mode and comparison mode keep separate temporary slot banks.

## Contig menus

Contig map strips also support a right-click menu for contig-level actions.

See [Contig Actions](contig-actions.md) for reverse-complement and reorder
operations in browser mode and comparison view.
