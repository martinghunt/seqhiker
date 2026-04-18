# Theme Editor

`seqhiker` includes a built-in theme editor for creating and adjusting custom
color themes.

The editor works on user themes. If you open the editor while a built-in theme
is selected, `seqhiker` first creates an editable user copy of that theme.

## Opening the editor

Open the theme editor from the settings panel.

When the editor opens:

- the main view stays visible for live preview
- the right-hand panel switches to theme controls
- the selected theme becomes the active preview immediately

## What you can edit

The theme editor lets you change the color roles used across the app, including
track colors, panel colors, feature colors, comparison colors, and other UI
elements.

Clicking a role name highlights where that role is used in the preview.

Changing a color updates the live preview immediately.

## Theme management

The editor supports:

- renaming the current user theme
- duplicating the current theme
- undoing recent color changes during the current edit session
- resetting the current theme back to how it looked when the editor was opened
- deleting the current user theme

Changes are saved immediately to the current user theme as you edit.

## Import and export

Themes can be exported to JSON and imported back later.

This is useful for:

- backing up a custom theme
- sharing a theme between machines
- starting a new theme from an exported JSON file

### Importing a theme from the editor

To import a theme JSON while the theme editor is open:

1. Open the theme editor.
2. Click `Import`.
3. Choose a `.json` theme file.
4. Confirm the file selection.

Importing a theme JSON creates or updates a user theme and switches the editor
to that imported theme.

### Importing a theme by drag and drop

You can also import a theme without opening the editor first:

1. Drag a `.json` theme file onto the main `seqhiker` window.
2. `seqhiker` imports the theme and switches the active theme to the imported one.
3. If the theme editor is already open, it also switches the editor to that imported theme.

## Notes

- Built-in themes are not edited in place. They are copied to a user theme
  first.
- The editor only allows deleting a user theme when another user theme remains
  available.
- Closing the editor returns the right-hand panel to its normal feature/details
  behavior.
