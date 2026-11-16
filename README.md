# Markdown Reader — a KDE Plasma 6 widget

A small, read-only Markdown viewer for your desktop or panel.
Point it at a folder and flip through every Markdown file in it, one page at a time.

![Plasma 6](https://img.shields.io/badge/Plasma-6.8%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- Browse all `*.md` / `*.markdown` files in a folder, one document at a time
- Wraps around: next from the last file goes back to the first
- Sort by file name or by modification time
- Works on the desktop **and** in a panel (icon + popup, like the Notes widget)
- Keyboard: `←` `→` previous/next document, `↑` `↓` scroll
- Read-only Markdown rendering with Qt's built-in Markdown support
  (headings, emphasis, lists, quotes, code blocks, links, tables)
- Preserves the source file's line breaks and blank lines (see below)
- Auto-refreshes every 15 s without disturbing your scroll position
- Context menu: open the current folder in your **default terminal**
- No compilation, no Python, no extra dependencies — a single QML package
- UI in Korean when the system locale is Korean, English otherwise

## Requirements

- KDE Plasma 6.8 or newer (developed and tested on Plasma 6.8.2)
- KDE Frameworks 6 and Qt 6 (both already required by Plasma)
- `plasma5support` — shipped with Plasma; used to list files and read them

## Installation

```bash
git clone https://github.com/nemonein/plasma-markdownreader.git
cd plasma-markdownreader
./install.sh
systemctl --user restart plasma-plasmashell.service
OR,
kquitapp6 plasmashell && kstart plasmashell
```

The script installs the package to
`${XDG_DATA_HOME:-~/.local/share}/plasma/plasmoids/com.github.plasma-markdownreader`
using `kpackagetool6`, then prints the next steps.

If you prefer to do it by hand:

```bash
kpackagetool6 --type Plasma/Applet --install ./markdownreader
# upgrade an existing installation
kpackagetool6 --type Plasma/Applet --upgrade ./markdownreader
```

Restart the shell if the widget does not show up immediately:

```bash
kquitapp6 plasmashell && kstart plasmashell
```

## Usage

1. Right-click your desktop or panel → **Add Widgets** → _Markdown Reader_.
2. Open the widget's settings (gear icon in the header) and enter a folder,
   for example `~/Documents/notes`.
   When no folder is set yet, the path field is shown directly in the widget.
3. That's it — the first file opens automatically.

### Keyboard

| Key                          | Action                   |
| ---------------------------- | ------------------------ |
| `←` / `→`                    | previous / next document |
| `↑` / `↓`                    | scroll about three lines |
| mouse wheel, drag, scrollbar | free scrolling           |
| wheel up / down over the header | next / previous document |

In a panel, click the **MD** icon to open the popup; the document view takes
keyboard focus as soon as the popup is shown.

### Settings

All settings live inside the widget (gear button in the header):

| Setting   | Description                                            |
| --------- | ------------------------------------------------------ |
| Folder    | Markdown folder to read (`~` and `$HOME` are expanded) |
| Sort      | by file name, or by modification time (newest first)   |
| Font size | point size of the document text                        |

> The KDE configuration dialog intentionally has **no General page** for this
> widget: on current Plasma/Kirigami builds the category page can come up empty
> (`PageRow.initAndInsertPage` type error). Everything the widget needs is
> therefore available in its own UI.

### Open the folder in a terminal

Right-click the widget → **Open folder in terminal**. The folder is opened using
the terminal configured in _System Settings → Default Applications_, read from
`kdeglobals [General] TerminalApplication` / `TerminalService`, with
`xdg-terminal-exec`, `konsole`, and `x-terminal-emulator` as fallbacks.

## Localization

The widget picks its UI language from the system locale at runtime:

```qml
readonly property bool isKorean: String(Qt.locale().name).toLowerCase().indexOf("ko") === 0
function tr(ko, en) { return root.isKorean ? ko : en; }
```

Korean (`ko_*`) shows Korean strings; every other locale shows English.
The widget name and description in the _Add Widgets_ list follow the same rule
through the `Name[ko]` / `Description[ko]` entries in `metadata.json`.

`install.sh` uses the same rule (reading `LC_ALL`, then `LC_MESSAGES`, then
`LANG`) and prints Korean or English messages accordingly.

## Markdown rendering notes

Rendering uses Qt's `TextEdit.MarkdownText`, i.e. a CommonMark subset
(md4c). Two deliberate deviations from strict Markdown make it behave like a
plain document viewer:

- **Line breaks are preserved.** A single newline is normally collapsed into a
  space by CommonMark; here every line outside a fenced code block is turned
  into a hard line break.
- **Blank lines stay visible.** Each blank line becomes an explicit empty line,
  instead of relying on paragraph spacing (which can be zero).

Known limitations:

- Tables render, but complex tables may not line up perfectly.
- Relative image paths are not resolved; images generally do not display.
- Inline HTML, footnotes and other extensions are not supported.
- Very large files (several MB) may render slowly.
- Read-only: there is no editing or saving. Text selection and copying work.

## File layout

```
metadata.json                     KPackage metadata (Plasma/Applet)
contents/
├── config/main.xml               configuration entries
├── icons/markdown.svg            panel icon (tinted via isMask)
├── scripts/open-terminal.sh      default-terminal launcher
└── ui/main.qml                   the widget
install.sh                        installer
```

## Troubleshooting

**The widget is not in the widget list**

```bash
kpackagetool6 --type Plasma/Applet --list | grep markdown
```

If nothing is listed, install again with `./install.sh` and restart plasmashell.

**Nothing renders / QML errors**

```bash
journalctl --user -b -o cat | grep -iE 'markdownreader|main\.qml' | tail -30
```

**The terminal does not open**

```bash
kreadconfig6 --file kdeglobals --group General --key TerminalApplication
kreadconfig6 --file kdeglobals --group General --key TerminalService
```

Both empty means no default terminal is configured; the widget then falls back to
`xdg-terminal-exec`, `konsole`, `x-terminal-emulator`.

## Uninstall

```bash
kpackagetool6 --type Plasma/Applet --remove com.github.plasma-markdownreader
```

## Development

The widget is plain QML — no build step.

```bash
# edit contents/ui/main.qml, then
./install.sh
kquitapp6 plasmashell && kstart plasmashell
```

To watch QML warnings while iterating, run plasmashell from a terminal and read
its output, or use `journalctl --user -b -f`.

### Commit attribution

This repository ships a `commit-msg` hook that appends

```
Co-authored-by: DeepSeek <noreply@deepseek.com>
```

to every commit message. Enable it once per clone:

```bash
./setup-git.sh           # git config core.hooksPath .githooks
./setup-git.sh --unset   # turn it off again
```

The hook skips messages that already contain the trailer, and `git commit
--no-verify` bypasses it. Override the identity with the
`MARKDOWN_READER_COAUTHOR_NAME` / `MARKDOWN_READER_COAUTHOR_EMAIL`
environment variables. Since it is enabled through local git config, it applies
to your clone only — other contributors can opt in the same way.

## Attribution

- **Author / maintainer:** [nemonein](https://github.com/nemonein)
- **AI assistance:** DeepSeek (model `deepseek-flash`) — used for the initial QML
  implementation, iteration on Markdown rendering, keyboard focus handling and
  panel behaviour, plus the installer and terminal-launcher scripts.

AI-assisted commits are marked in the history with a `Co-authored-by` trailer:

```
Co-authored-by: DeepSeek <noreply@deepseek.com>
```

DeepSeek has no public GitHub account linked to this project, so it appears as a
plain co-author line rather than a linked profile in the GitHub UI. Every change
is reviewed, built and tested by the maintainer, who is responsible for the code
and its licensing.

## License

MIT.
