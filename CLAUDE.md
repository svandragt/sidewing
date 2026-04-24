# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build / Run

```sh
meson setup build          # first time only
meson compile -C build     # incremental build
./build/src/sidewing       # run
```

`Makefile` wraps the same commands (`make`, `make run`, `make rebuild`, `make distclean`).

There is no automated test suite. Verification is `meson compile -C build` plus manual exercise of plugin discovery, bar rendering, menu actions, and monitor placement.

Dependencies (pkg-config): `gtk4`, `gtk4-x11`, `gio-2.0`, `glib-2.0`, `gobject-2.0`, `gee-0.8`, `json-glib-1.0`, `x11`. Vala targets glib 2.68.

## Architecture

Sidewing is a GTK4 + Vala desktop bar for X11 multi-monitor setups. It loads local executable "plugins," parses xbar-style stdout, and renders a translucent bar with per-plugin popover menus.

Runtime flow (all wired in `src/application.vala`):

1. `MonitorManager` picks a monitor (prefers non-primary, falls back to primary) and watches maximized-window state on X11 to toggle the bar between translucent and opaque styles.
2. `PluginManager` scans `~/.local/share/sidewing/plugins/` for executables whose filenames encode refresh intervals (`name.10s.sh`, `name.5m.py`, etc.). Unmatched filenames are ignored. On first run the bundled `examples/plugins/` are copied in if the directory is empty.
3. For each plugin, `PluginManager` schedules a refresh timer that invokes `PluginRunner`. The runner sets `SIDEWING=1`, `XBAR=1`, `SIDEWING_PLUGIN_PATH`, `SIDEWING_PLUGIN_DIR`, merges in values from the plugin's `<plugin>.vars.json` sidecar (managed by `VariablesStore`, derived from xbar `<xbar.var>` metadata), and runs the plugin with its own directory as cwd.
4. `XbarParser` splits stdout on `---`: the first non-empty line before it becomes the bar title; lines after become menu items. `--` prefixes indent nested items. Pipe-delimited metadata supports `href=`, `shell=`, `paramN=`, `terminal=true`, `refresh=true`, `disabled=true`.
5. `MenuBuilder` turns the parsed model into a GTK popover menu; `ActionDispatcher` executes item actions (open URL, run shell command, trigger refresh). `terminal=true` is not implemented yet — commands currently run without a terminal.
6. `BarWindow` draws the bar, extends plugin/settings button hit targets to the top screen edge, and dismisses popovers on focus loss (X11 workaround). The app menu exposes: open plugins folder, install desktop entry, toggle autostart, toggle reserve-space, refresh all.
7. `DesktopIntegration` writes the desktop entry and autostart file. `SettingsStore` persists user config under `~/.config/sidewing/config.ini`. `LogService` is the shared logger. `CliRunner` handles non-GUI CLI invocations (e.g. running a single plugin from the terminal for debugging).

Shared types live in `src/models.vala`. `src/build-config.vala.in` is configured by Meson into `build-config.vala` and exposes build-time constants.

## Platform / Scope Constraints

- X11 only. Wayland is not supported — do not assume Wayland APIs exist. Maximized-window tracking, focus-loss dismissal, and reserve-space all use X11 paths.
- Plugin env vars were renamed `STABA_*` → `SIDEWING_*`; existing plugin scripts referencing `STABA_*` need updating.
- Plugin PATH resolution is tricky: user tools (e.g. `gh`) may only be on PATH from interactive zsh setup. Don't rely on `zsh -lc` alone — may need to merge env, login-shell, interactive-shell, and `.profile` sources.
- README.md documents user-facing plugin semantics; consult it before changing parser or runner behavior.
- Example plugins under `examples/plugins/` are shipped as product surface and useful for manual verification.

## Design Docs

- `docs/sidewing-spec.md` — broader behavior spec
- `docs/implementation-plan.md` — planned architecture / outstanding work
- `agents.md` — agent-oriented repo overview (overlaps with this file)
