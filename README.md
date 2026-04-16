# Sidewing

Sidewing is a GTK4 desktop bar for elementary OS-style multi-monitor setups. It runs local executable plugins, parses [xbar-style](https://github.com/matryer/xbar) output, and renders the result in a slim bar window on a selected display.

Current target:

- elementary OS 8 / Linux desktop environments with X11
- GTK4 + Vala
- local, unsandboxed script plugins

The current codebase is an MVP-in-progress. It already discovers and runs plugins, schedules refreshes from xbar-style filenames, renders a bar window, and opens plugin menus. Several planned features are still not implemented yet.

<img width="531" height="257" alt="image" src="https://github.com/user-attachments/assets/430e3cce-cd05-4bf9-ada2-eced9fa48f63" />


## What It Does

- Scans a plugins directory for executable files with xbar-style refresh intervals such as `clock.5s.sh` or `disk.1m.py`
- Runs each plugin on its own refresh schedule
- Uses the first pre-`---` line as the visible bar label
- Uses lines after `---` as menu items
- Supports menu separators, disabled items, basic nested indentation, `href=...`, `shell=...`, `paramN=...`, and `refresh=true`
- Adds a right-aligned app menu with plugin-folder, desktop-entry, autostart, reserve-space, and refresh-all actions
- Seeds the user plugin directory with bundled example plugins on first launch
- Prefers a non-primary monitor and falls back to the primary monitor if needed
- Uses a Wingpanel-inspired translucent bar that becomes opaque when the active window on that monitor is maximized

## Current Limitations

The implementation is narrower than the long-term spec.

- X11 placement is implemented; Wayland support is not
- There is no full settings UI yet
- `terminal=true` command launching is not implemented yet; command actions currently run without a terminal
- Unsupported xbar metadata is ignored
- Only the first bar line is shown as the visible title
- Plugin variables are loaded from `<plugin>.vars.json`; there is no in-app variables editor yet

## Build Requirements

You need:

- `meson`
- `ninja`
- `valac`
- GTK4 development files
- `gtk4-x11`
- `glib-2.0`
- `gio-2.0`
- `gobject-2.0`
- `gee-0.8`
- `x11`

On Debian/Ubuntu-based systems that usually means packages along these lines:

```sh
sudo apt install meson ninja-build valac libgtk-4-dev libgee-0.8-dev libx11-dev
```

If `gtk4-x11` is packaged separately on your distro, install that too.

## Build

```sh
meson setup build
meson compile -C build
```

## Run

```sh
./build/src/sidewing
```

The app stores its state under:

- Config: `~/.config/sidewing/config.ini`
- Autostart entry: `~/.config/autostart/com.vandragt.sidewing.desktop`
- User data: `~/.local/share/sidewing/`
- Desktop entry: `~/.local/share/applications/com.vandragt.sidewing.desktop`
- Plugins directory: `~/.local/share/sidewing/plugins/`

On first launch, `Sidewing` copies the example plugins from [`examples/plugins`](./examples/plugins/) into the user plugins directory if that directory is empty.

From the bar app menu you can:

- install a user desktop entry
- enable or disable autostart for the current user session
- toggle whether the bar should reserve space for maximized windows on X11
- refresh all plugins

## Plugin Naming

Plugins must be executable files whose filenames encode the refresh interval:

```text
name.10s.sh
name.5m.py
name.1h.rb
name.1d.sh
```

Supported interval suffixes:

- `s` seconds
- `m` minutes
- `h` hours
- `d` days

If the filename does not match that pattern, the file is ignored.

## Plugin Output

Sidewing follows the xbar text protocol loosely.

Basic structure:

```text
Visible title
---
Menu item
Another item | href=https://example.com
Refresh now | refresh=true
Disabled item | disabled=true
--Indented child
```

Current behavior:

- The first non-empty line before `---` becomes the bar title
- Lines after `---` become menu items
- `---` inside the menu becomes a separator
- Leading `--` increases indentation depth for menu items
- Metadata is parsed from the `|` section

Currently recognized metadata:

- `href="..."`
- `shell="..."`
- `param1="..."`, `param2="..."`, ...
- `terminal=true`
- `refresh=true`
- `disabled=true`

Environment variables set for plugins:

- configured `<xbar.var>` values from `<plugin>.vars.json`
- `SIDEWING=1`
- `XBAR=1`
- `SIDEWING_PLUGIN_PATH`
- `SIDEWING_PLUGIN_DIR`

This renamed the older `STABA_*` variables. Existing plugins that read those names need to be updated.

Plugins run with their own directory as the current working directory.

## Plugin Variables

Sidewing supports xbar-style variable metadata in plugin comments:

```text
# <xbar.var>string(VAR_NAME="Sidewing"): Display name.</xbar.var>
# <xbar.var>number(VAR_COUNT=3): Number of rows.</xbar.var>
# <xbar.var>boolean(VAR_VERBOSE=false): Show extra detail?</xbar.var>
# <xbar.var>select(VAR_STYLE="normal"): Style preset. [compact, normal, loud]</xbar.var>
```

When a plugin with variables is discovered, Sidewing creates a sidecar file next to it:

```text
plugin.1m.sh.vars.json
```

That JSON file stores the current values and Sidewing exports them as environment variables before each plugin run. Variable values are user-configurable by editing the sidecar JSON file and refreshing the plugin.

## Examples

Bundled examples live in [`examples/plugins`](./examples/plugins/):

- [`action-demo.30s.sh`](./examples/plugins/action-demo.30s.sh)
- [`available-memory.10s.sh`](./examples/plugins/available-memory.10s.sh)
- [`available-disk-space.1m.sh`](./examples/plugins/available-disk-space.1m.sh)
- [`public-ip.5m.sh`](./examples/plugins/public-ip.5m.sh)
- [`github-assigned-prs.5m.sh`](./examples/plugins/github-assigned-prs.5m.sh)
- [`variable-demo.1m.sh`](./examples/plugins/variable-demo.1m.sh)

The GitHub example requires the `gh` CLI and an authenticated session.

## Project Layout

```text
src/
  application.vala
  bar-window.vala
  monitor-manager.vala
  plugin-manager.vala
  plugin-runner.vala
  xbar-parser.vala
  menu-builder.vala
  action-dispatcher.vala
examples/plugins/
docs/
```

## Status

Related design and planning docs:

- [`docs/sidewing-spec.md`](./docs/sidewing-spec.md)
- [`docs/implementation-plan.md`](./docs/implementation-plan.md)
- [`docs/TODO.md`](./docs/TODO.md)
