# navx

A lightweight macOS menu bar app for keyboard-driven window management. navx lets you instantly jump to any app or window, navigate virtual workspaces, and search open windows with a Vim-style interface — all without ever touching the mouse.

![Preview](https://drive.google.com/uc?export=view&id=1-NI17CR6QnaVXbXbnwLZ9hG2cYra6A10)

## Features

### App Shortcuts
Bind a global hotkey to any running application or specific window. Press the hotkey and navx instantly brings that window to focus, launching the app if it isn't already running.

### Window Switcher (`⌥ /`)
A Spotlight-style panel that lists all open windows across every app. It ships with a Vim-inspired modal interface:

| Mode | Trigger | Navigation |
|------|---------|------------|
| **NORMAL** | Default on open | `j` / `↓` — move down · `k` / `↑` — move up · `i` — enter INSERT mode |
| **INSERT** | Press `i` | Type to search windows/apps in real time |

Press `↩ Enter` to switch to the selected window. Press `Escape` to dismiss the panel.

### Workspaces
Organize open windows into up to 4 virtual workspaces per monitor.

| Hotkey | Action |
|--------|--------|
| `⌥ N` | Assign the currently focused window to the active workspace |
| `⌥ J` | Switch to the next workspace (hides old windows, reveals new ones) |
| `⌥ K` | Switch to the previous workspace |

## Requirements

- macOS 13 Ventura or later
- **Accessibility permission** — required to read and raise windows
- **Screen Recording permission** — required to display window titles in the switcher

navx requests both permissions on first launch and guides you to System Settings if they need to be granted manually.

## Installation

1. Clone the repository and open `navx.xcodeproj` in Xcode.
2. Build and run the project (`⌘ R`).
3. navx appears as a window icon (`⬜`) in the macOS menu bar.
4. Grant Accessibility and Screen Recording permissions when prompted.

## Usage

### Setting up App Shortcuts
1. Click the navx menu bar icon → **Preference** (or press `⌘ ,`).
2. Open the **App Shortcuts** tab.
3. Click **Add Shortcut** to add a new row.
4. Click the row to pick a target app or window from the list of open windows.
5. Record a hotkey by clicking the key field and pressing your desired key combination.

### Using the Window Switcher
Press `⌥ /` from anywhere to open the panel. Start navigating immediately with `j`/`k`, or press `i` to search by name.

### Setting up Workspaces
1. Open the **Workspaces** tab in Preferences to view the current state of each workspace.
2. Focus a window you want to assign, then press `⌥ N`.
3. Use `⌥ J` / `⌥ K` to cycle between workspaces. Windows from the previous workspace are minimized automatically.

## License

[MIT](LICENSE)
