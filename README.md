# navx

A lightweight macOS menu bar app for keyboard-driven window management. navx lets you instantly jump to any app or window, navigate virtual workspaces, and search open windows with a Vim-style interface — all without ever touching the mouse.

![Live Demo](https://github.com/user-attachments/assets/202efe64-3cad-45f0-a408-f63c329555bc)

## Features

### App Shortcuts
Bind a global hotkey to any running application or specific window. Press the hotkey and navx instantly brings that window to focus, launching the app if it isn't already running.

### Multi-Window App Shortcuts
When you have multiple windows open from the same app — across different spaces or monitors — navx makes it effortless to jump between them. Instead of hunting through Mission Control or clicking the Dock repeatedly, you can bind shortcuts directly to individual windows of the same app and switch between them instantly.

- **Jump between multiple windows of the same app** with dedicated per-window hotkeys — no more cycling through windows one by one.
- **Works across different workspaces** — even if your windows are spread across multiple virtual spaces, navx reaches them all.
- **See a list of all windows from the same app** so you always know what's open and where — pick the one you want in a single keypress.
- Say goodbye to the headache of managing dozens of windows from the same app. navx keeps everything organized and one shortcut away.

### New Window Detection *(optional)*
navx can watch for newly opened windows in the background. When a new window appears, it immediately prompts you to register it as a shortcut — so you never have to manually go into Preferences to add it.

- **Automatic detection** — navx listens for new windows the moment they open, across any app.
- **Instant registration prompt** — a lightweight prompt appears asking if you want to assign a hotkey to the new window. Accept to register it, dismiss to skip.
- **Completely opt-in** — this feature is disabled by default. Enable it in Preferences under **App Shortcuts → "Prompt to register new windows"** whenever you want it.
- Perfect for power users who frequently open new windows and want every one of them shortcut-ready without any extra steps.

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
3. navx appears as a window icon ![](https://github.com/syns2191/navx/blob/main/navx/Assets.xcassets/TrayIcon.imageset/16%201.png) in the macOS menu bar.
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
