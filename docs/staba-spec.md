# staba Specification

Status: MVP frozen

## Summary

`staba` is a Vala desktop application for elementary OS 8 that renders an xbar-compatible status bar on a secondary display in the X11 "Classic Session".

The product goal is simple:

- Run executable plugins from a local directory.
- Parse their stdout using an xbar-like text protocol.
- Render the primary line as a compact top bar item on a chosen non-primary monitor.
- Show the remaining lines as a dropdown menu.

Working title: `staba`

Tagline: Put the output from any script or program into your elementary OS top bar.

## Problem Statement

Wingpanel is designed as the system top panel, but in practice users with multiple displays may want a lightweight status bar on a secondary monitor showing custom status, actions, and menus driven by scripts.

`staba` fills that gap by providing:

- A dedicated top-edge bar window on a selected secondary monitor.
- Script-driven status items inspired by xbar.
- Good compatibility with existing xbar plugins where they do not rely on macOS-only commands, APIs, or menu bar features.

## Product Goals

- Be useful on elementary OS 8 without requiring Wingpanel plugin development.
- Prioritize elementary OS 8 X11 compatibility first.
- Support a large subset of the xbar plugin text protocol.
- Make common existing xbar plugins easy to port or run unchanged.
- Keep the app small, local-first, and script-friendly.
- Use Vala and native Linux desktop APIs appropriate for elementary OS.

## Non-Goals

- Full macOS menu bar feature parity.
- Compatibility with plugins that depend on macOS frameworks, commands, or behavior.
- First-release Wayland support.
- Acting as a Wingpanel replacement.
- Running untrusted plugins in a security sandbox.
- Bundling an online plugin marketplace in the MVP.

## Target Environment

- OS: elementary OS 8.x
- Session target for MVP: X11 Classic Session
- Display model: multi-monitor setups with one primary display and at least one secondary display
- Language: Vala
- UI stack: GTK4 + Granite if it improves integration with elementary OS
- Packaging target: native deb for development; Flatpak may be evaluated later, but is not the primary MVP target because unrestricted local script execution is central to the app

## References

- xbar README: https://github.com/matryer/xbar
- xbar plugin guide: https://github.com/matryer/xbar-plugins/blob/main/CONTRIBUTING.md
- xbar docs index: https://xbarapp.com/docs/index.html
- xbar variables article: https://xbarapp.com/docs/2021/03/14/variables-in-xbar.html
- elementary OS 8 announcement: https://blog.elementary.io/os-8-available-now/

## User Stories

- As a user, I can place a thin bar on a secondary monitor so it feels like that monitor has its own top status area.
- As a user, I can point `staba` at a plugins directory and see compatible plugins appear without writing app-specific code.
- As a user, I can click a status item to open a dropdown menu populated from plugin output.
- As a user, I can trigger plugin-defined actions from menu items.
- As a user, I can refresh one plugin or all plugins.
- As a user, I can choose which monitor hosts the `staba` bar.
- As a user, I can disable plugins that are broken or noisy without deleting them.
- As a user, I can copy or adapt bundled example plugins for common tasks like public IP, memory, disk space, and GitHub PR counts.
- As a plugin author, I can reuse the xbar mental model and most of its output format.

## Core Concepts

### 1. Bar

`staba` owns a borderless, always-on-top window anchored to the top edge of one selected secondary monitor.

The bar:

- spans the width of the selected monitor
- has a fixed height
- reserves no exclusive screen space in MVP unless straightforward on X11
- can optionally auto-hide in a future release

### 2. Plugin

A plugin is any executable file in the configured plugins directory whose filename encodes a refresh interval using the xbar convention:

`{name}.{interval}.{ext}`

Examples:

- `clock.1s.sh`
- `cpu.5s.py`
- `vpn.1m.rb`

`staba` discovers plugins by scanning configured directories on startup and when manually refreshed.

### 3. Item Model

Each plugin produces:

- one or more bar lines
- zero or more dropdown lines after a separator line `---`

Internally, `staba` parses plugin stdout into a normalized item tree:

- bar item lines
- menu items
- separators
- nested submenu items
- action metadata
- style metadata

### 4. Action

Menu items may:

- open a URL
- execute a command
- request plugin refresh after completion
- be disabled

## UI Specification

## Bar Layout

The MVP bar should support:

- left-aligned plugin items
- optional right alignment later; not required in MVP
- text-first presentation
- icon support where practical

Recommended MVP layout:

- A single horizontal row of plugin widgets
- Each plugin shows only its current bar title
- Clicking a plugin opens a popover/dropdown menu below the bar

If a plugin emits multiple pre-`---` lines, `staba` should cycle them like xbar only if the implementation cost is reasonable. Otherwise, the first line is shown in MVP and cycling is deferred.

## Monitor Placement

The app must:

- list available monitors
- identify the primary monitor
- allow the user to select a non-primary monitor as the host
- remember this selection

If the configured monitor disappears:

- fallback to the first available non-primary monitor
- if none exists, either attach to the primary monitor or suspend the bar, based on user preference

Recommended MVP fallback: attach to primary monitor with a warning in settings/logs.

## Dropdown Behavior

Dropdowns should:

- appear directly below the clicked plugin item
- close when focus is lost or escape is pressed
- support separators
- support nested submenus
- support disabled items
- support keyboard navigation if GTK widgets provide it naturally

## Settings

MVP settings:

- plugins directory path
- selected monitor
- bar height
- background style: translucent or solid
- autostart on login
- refresh all
- open plugins folder
- show logs / plugin errors

Future settings:

- font overrides
- padding and spacing
- item alignment zones
- bar exclusivity / strut reservation on X11

## Bundled Example Plugins

The project should include a small set of example plugins in-repo so users can test `staba` immediately and authors have Linux-oriented reference implementations.

Initial example set:

- public IP address
- available memory
- available disk space
- number of open GitHub pull requests assigned to the current user

Example plugin requirements:

- use Linux-compatible commands and APIs
- avoid macOS-specific binaries and libraries
- be readable and short enough to serve as documentation
- prefer POSIX shell for simple cases
- clearly document external dependencies when they exist

GitHub example notes:

- should prefer `gh` CLI if available
- should fail gracefully when `gh` is missing or not authenticated
- should make the authentication requirement explicit in comments/output

Recommended repo location:

- `examples/plugins/`

## Plugin Compatibility Specification

## Compatibility Goal

`staba` aims for "xbar text protocol compatibility", not "macOS behavior compatibility".

That means:

- The stdout menu syntax should be as close as practical to xbar.
- The metadata tags should be recognized where useful.
- macOS-specific runtime assumptions are out of scope.

## File Naming and Refresh Intervals

Support xbar-style intervals in filenames:

- `Ns` seconds
- `Nm` minutes
- `Nh` hours
- `Nd` days

Examples:

- `weather.5m.sh`
- `disk.1h.py`

If no valid interval is present:

- plugin is ignored in MVP, or
- plugin defaults to manual refresh only

Recommended MVP behavior: ignore invalid filenames and surface them in logs.

## Executability Rules

A plugin must:

- be a regular file
- be executable
- have a valid interpreter via shebang or be directly executable binary/script

If a file is not executable, `staba` should mark it invalid and show the reason in logs/settings.

## Supported xbar Syntax

`staba` MVP should support these xbar behaviors:

- plain text lines
- `---` as dropdown separator boundary
- leading `--` for submenu nesting
- `|` parameter separator
- `href=...`
- `color=...`
- `font=...` if GTK-side font override is practical
- `size=...`
- `shell=...`
- `param1=...`, `param2=...`, etc.
- `refresh=true`
- `dropdown=false`
- `length=...`
- `trim=true|false`
- `alternate=true`
- `ansi=false`
- `emojize=false` may be parsed but can default to no-op in MVP
- `disabled=true`

## Explicitly Unsupported or Deferred xbar Parameters

These should be treated as unsupported in MVP and ignored safely:

- `templateImage=...`
- `image=...` in xbar's macOS-oriented encoded-image sense, unless GTK icon/image support is added later
- macOS shortcut semantics such as `CmdOrCtrl` mappings, unless a Linux-native accelerator model is introduced
- parameters whose only meaning depends on macOS menu bar internals

Unsupported parameters must not crash parsing.

## Metadata Support

`staba` should parse xbar metadata tags from comments near the top of plugin files:

- `<xbar.title>`
- `<xbar.version>`
- `<xbar.author>`
- `<xbar.author.github>`
- `<xbar.desc>`
- `<xbar.image>`
- `<xbar.dependencies>`
- `<xbar.abouturl>`
- `<xbar.var>`

MVP uses of metadata:

- display plugin title/description in settings
- show dependency hints
- parse variables declarations
- offer "about plugin" links where available

## Variables Support

`staba` should support xbar-style variables metadata for user-configurable plugin settings.

Supported variable types:

- `string`
- `number`
- `boolean`
- `select`

Storage model:

- Store variable values in a sidecar JSON file adjacent to the plugin, matching xbar's general approach.
- Filename pattern: `<plugin filename>.vars.json`

Runtime model:

- Export each configured variable as an environment variable before launching the plugin.

Compatibility note:

- Matching xbar's sidecar naming is desirable because it improves plugin portability.

## Plugin Execution Model

## Scheduling

Each plugin has an independent timer based on its filename interval.

Rules:

- Initial run occurs shortly after app startup.
- Only one instance of a given plugin may run at a time.
- If a scheduled refresh fires while the previous run is still executing, the new run should be skipped, coalesced, or queued.

Recommended MVP behavior:

- coalesce overlapping runs into one pending refresh

## Execution Environment

Each plugin process receives:

- inherited user environment
- configured plugin variables
- `STABA=1`
- `STABA_PLUGIN_PATH=/absolute/path/to/plugin`
- `STABA_PLUGIN_DIR=/absolute/path/to/plugins/dir`
- `STABA_MONITOR_NAME=<display name if known>`
- `XDG_CURRENT_DESKTOP=Pantheon` if already present in session

Optional compatibility env vars:

- `XBAR=1` for plugins that only check for xbar-like execution
- `XBARDarkMode=true|false` equivalent if `staba` tracks current appearance

This is an intentional compatibility shim.

## Working Directory

Recommended default:

- plugin working directory is the directory containing the plugin file

This improves relative-path compatibility for existing scripts.

## Timeout and Failure Rules

Each plugin should have:

- configurable execution timeout
- captured stdout and stderr
- recorded exit status

Recommended MVP defaults:

- soft timeout: 5 seconds
- hard kill timeout after grace period: 1 second

Failure handling:

- last successful output remains visible until replaced
- plugin errors are logged
- repeated failures can mark plugin as unhealthy in settings

## Action Execution

When a menu item specifies `shell=...`:

- execute the requested command as a child process
- pass parameters in order from `param1`, `param2`, etc.
- optionally suppress terminal windows; on Linux this means run detached without launching a terminal emulator unless explicitly requested

`terminal=true|false` mapping for Linux:

- `false`: execute directly in background
- `true`: launch using a configurable terminal command in a future release

Recommended MVP:

- support `terminal=false`
- treat `terminal=true` as best-effort or unsupported, documented clearly

## Parser Specification

## Line Processing

Plugin stdout is split by newline.

Parsing rules:

- lines before first `---` are bar lines
- lines after first `---` are dropdown lines
- a line that is exactly `---` inside dropdown content becomes a visual separator
- leading `--` increments submenu nesting level by one per two dashes

Example:

```text
CPU 14%
---
Refresh | refresh=true
--Details
----Core 1: 10%
----Core 2: 18%
```

## Parameter Parsing

The parser must:

- treat text before the first unescaped pipe as the item title
- parse subsequent whitespace-delimited `key=value` tokens
- preserve quoted values
- handle malformed parameters without aborting the whole plugin

Recommendation:

- implement a permissive parser and record per-line parse warnings

## Rendering Rules

- `color` maps to GTK text color where possible
- `font` and `size` map to Pango/GTK attributes where possible
- `length` truncates rendered title
- `trim` defaults to `true`
- `alternate=true` may be deferred if GTK menu model does not support the same interaction affordance

## Linux and elementary OS Divergences

These are intentional divergences from xbar/macOS:

- No dependence on macOS APIs such as NSStatusItem.
- No assumption that the system panel itself is extensible for third-party items.
- `open` should map to `xdg-open` or GTK URI launching rather than macOS `open`.
- Apple-specific commands like `pmset`, `osascript`, `defaults`, `networksetup`, `ioreg`, and `scutil` are outside compatibility scope.
- Encoded menu bar images are lower priority than text and symbolic icon support.
- Keyboard shortcut semantics should be Linux-native if implemented at all.

## Security Model

`staba` executes arbitrary local plugins as the current user.

Therefore:

- The app must clearly state that plugins are trusted code.
- The UI should distinguish plugin parse errors from execution errors.
- The app should never execute plugins from remote URLs directly.
- The default plugins directory should live in the user's home directory.

Recommended default path:

- `~/.local/share/staba/plugins`

Recommended config path:

- `~/.config/staba/`

## Storage Layout

Recommended layout:

- `~/.config/staba/config.json`
- `~/.config/staba/state.json`
- `~/.cache/staba/` for transient runtime data
- `~/.local/share/staba/plugins/` for user plugins

Optional later:

- `~/.local/share/staba/plugins-disabled/`

## Architecture

Suggested internal modules:

- `Application`
  - GTK application lifecycle
- `BarWindow`
  - top-edge monitor-bound window
- `MonitorManager`
  - display discovery and monitor selection
- `PluginManager`
  - discovery, enable/disable, scheduling
- `PluginRunner`
  - subprocess launch, timeout, stdout/stderr capture
- `XbarParser`
  - stdout to item model parsing
- `MenuBuilder`
  - GTK menu/popover construction
- `SettingsStore`
  - config and state persistence
- `VariablesStore`
  - plugin variable read/write sidecar JSON
- `ActionDispatcher`
  - handle href and shell actions
- `LogService`
  - structured logging and surfaced errors

## X11 Implementation Notes

For MVP on X11:

- Create a borderless top-level window positioned at the selected monitor's origin.
- Keep it above normal windows.
- Mark it sticky across workspaces if that matches expected panel behavior.
- Consider EWMH hints for dock/panel style windows.

Desirable X11 hints to investigate:

- `_NET_WM_WINDOW_TYPE_DOCK`
- `_NET_WM_STRUT_PARTIAL`
- `_NET_WM_STATE_ABOVE`
- skip taskbar/pager hints

Open technical question:

- whether reserving top-edge space behaves well with Gala in elementary OS 8 Classic Session

If strut reservation is unreliable, MVP should still function as a visual overlay bar.

## Performance Requirements

- Idle CPU use should be negligible when no plugins are refreshing.
- Slow plugins must not block the UI thread.
- Parsing and UI updates must be performed without freezing the bar.
- The app should scale to at least 20 lightweight plugins in MVP.

## Error Handling Requirements

- Broken plugins do not crash the app.
- Parser errors degrade gracefully per line.
- Action execution errors are surfaced in logs.
- Missing interpreters or dependencies are visible in settings.

## Logging

At minimum, log:

- plugin discovery results
- plugin launches
- execution duration
- exit code
- stderr output
- timeout events
- parse warnings
- action launches

Recommended log destination:

- file under `~/.cache/staba/`
- optional in-app viewer in settings/about window

## MVP Scope

The MVP should include:

- single bar on one selected monitor
- one visible bar title per plugin
- plugin directory scanning
- xbar-style filename interval parsing
- independent plugin scheduling
- text output parsing
- dropdown menus
- visual submenu indentation
- `href` support
- `shell` + `paramN` support
- `refresh=true` support
- basic plugin metadata parsing
- onboarding that seeds the user plugin directory with example plugins when empty
- persisted monitor selection
- logging and basic error surfacing
- bundled example plugins for Linux-friendly common tasks

## Post-MVP

- Wayland support where feasible
- multiple bars across multiple monitors
- multiple independently visible bar items emitted by one plugin
- exact xbar-style bar-line cycling
- true nested submenu widgets instead of indentation-only submenu display
- full xbar variables sidecar JSON support
- monitor selection UI
- autostart option
- richer image/icon support
- drag-and-drop plugin management
- plugin gallery/import UX
- per-plugin manual refresh button in UI
- plugin health badges
- configurable alignment zones
- CSS/theme customization
- DBus control API

## Resolved MVP Decisions

- `staba` shows one visible bar title per plugin in MVP.
- If a plugin emits multiple pre-`---` lines, the first line is used as the visible title in MVP.
- `alternate=true` is deferred and may be parsed as a no-op.
- `terminal=true` is deferred; Linux terminal launching is not part of the MVP contract.
- Invalid or non-executable plugins are ignored by the runtime and surfaced through logs/error UI rather than shown in the bar.
- If monitor hotplug invalidates the stored target, `staba` may move automatically to the next best monitor based on the existing fallback rules.

## Recommended Decisions for Initial Build

- Target elementary OS 8 Classic Session on X11 first.
- Use a standalone dock-type window instead of trying to integrate into Wingpanel.
- Preserve xbar file naming, menu syntax, metadata tags, and variables where practical.
- Ignore unsupported macOS-specific features safely.
- Keep plugin execution unsandboxed but explicit.
- Optimize for compatibility with shell, Python, Ruby, and other CLI-driven plugins that already work on Linux.

## Deferred Decisions

- Whether to emulate exact xbar bar-title cycling behavior after MVP.
- Which Linux terminal launcher should back `terminal=true`.
- Whether invalid plugins should eventually appear as disabled rows in a settings UI.
- Whether monitor hotplug should become user-configurable instead of automatic.

## Acceptance Criteria

`staba` MVP is successful when:

- A user can place an executable plugin in the plugins directory and see it appear after refresh.
- A valid plugin like `date.1m.sh` renders output in the bar.
- Clicking the plugin opens a dropdown menu parsed from stdout.
- Menu items with `href` open in the default browser.
- Menu items with `shell` run commands with `paramN` arguments.
- Plugin variables declared with `<xbar.var>` are editable and become environment variables at runtime.
- Plugin refresh timing follows filename intervals.
- Broken or macOS-specific plugins fail visibly but do not break other plugins or the app.
- The repository includes working example plugins for public IP, memory, disk space, and assigned GitHub PR count.

## Short Positioning Statement

`staba` is "xbar for a secondary display on elementary OS Classic Session": a small Vala app that runs local plugins and renders their output as a scriptable top bar on X11.
