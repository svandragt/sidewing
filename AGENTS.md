# Agents Guide

This repository contains `Sidewing`, a GTK4 desktop bar written in Vala. It runs local executable plugins, parses xbar-style output, and renders a slim bar window for multi-monitor Linux desktop setups.

## Current Scope

- Target platform: Linux desktop environments with X11
- Toolkit/language: GTK4 + Vala
- Build system: Meson + Ninja
- Plugin model: local unsandboxed scripts in the user data directory

Dependencies (pkg-config): `gtk4`, `gtk4-x11`, `gio-2.0`, `glib-2.0`, `gobject-2.0`, `gee-0.8`, `json-glib-1.0`, `x11`. Vala targets glib 2.68.

## Build / Run

```sh
meson setup build          # first time only
meson compile -C build     # incremental build
./build/src/sidewing       # run
```

`Makefile` wraps the same commands (`make`, `make run`, `make rebuild`, `make distclean`, `make restart`).

There is no automated test suite. Verification is `meson compile -C build` plus manual exercise of plugin discovery, bar rendering, menu actions, variable editing, and monitor placement.

## Architecture

Sidewing loads local executable "plugins," parses xbar-style stdout, and renders a translucent bar with per-plugin popover menus.

Runtime flow (all wired in `src/application.vala`):

1. `MonitorManager` picks a monitor (prefers non-primary, falls back to primary) and watches maximized-window state on X11 to toggle the bar between translucent and opaque styles.
2. `PluginManager` scans `~/.local/share/sidewing/plugins/` for executables whose filenames encode refresh intervals (`name.10s.sh`, `name.5m.py`, etc.). Unmatched filenames are ignored. On first run the bundled `examples/plugins/` are copied in if the directory is empty.
3. For each plugin, `PluginManager` schedules a refresh timer that invokes `PluginRunner`. The runner sets `SIDEWING=1`, `XBAR=1`, `SIDEWING_PLUGIN_PATH`, `SIDEWING_PLUGIN_DIR`, merges in values from the plugin's `<plugin>.vars.json` sidecar (managed by `VariablesStore`, derived from xbar `<xbar.var>` metadata), and runs the plugin with its own directory as cwd.
4. `XbarParser` splits stdout on `---`: the first non-empty line before it becomes the bar title; lines after become menu items. `--` prefixes indent nested items. Pipe-delimited metadata supports `href=`, `shell=`, `paramN=`, `terminal=true`, `refresh=true`, `disabled=true`.
5. `MenuBuilder` turns the parsed model into a GTK popover menu; `ActionDispatcher` executes item actions (open URL, run shell command, trigger refresh). `terminal=true` launches the command inside a detected terminal emulator (`$TERMINAL`, then a fallback list: `x-terminal-emulator`, `gnome-terminal`, `konsole`, `xfce4-terminal`, `alacritty`, `kitty`, `wezterm`, `foot`, `tilix`, `xterm`); the wrapper waits on Enter so the user can read output before the window closes. Each plugin popover ends with a footer separator + `Refresh` button + (when the plugin declares `<xbar.var>`) `Edit Variables…` button. Items whose only effect is `refresh=true` (no `shell=`/`href=`) are hidden — the footer covers them.
6. `VariablesEditor` builds a generated form from `<xbar.var>` metadata: text fields for `string`/`number`, switch for `boolean`, dropdown for `select`. Variables whose name matches `TOKEN`/`SECRET`/`PASSWORD`/`API_KEY` are masked. Save writes via `VariablesStore.write_values` and triggers `plugin_manager.refresh_record`.
7. `BarWindow` draws the bar, extends plugin/settings button hit targets to the top screen edge, and dismisses popovers on focus loss (X11 workaround). The app menu exposes: open plugins folder, toggle autostart, toggle reserve-space, reload.
8. `DesktopIntegration` writes the desktop entry and autostart file (autostart goes through a systemd user unit). `SettingsStore` persists user config under `~/.config/sidewing/config.ini`. `LogService` is the shared logger. `CliRunner` handles non-GUI CLI invocations (e.g. running a single plugin from the terminal for debugging).

Shared types live in `src/models.vala`. `src/build-config.vala.in` is configured by Meson into `build-config.vala` and exposes build-time constants.

## Important Paths

- `src/application.vala`: app startup and high-level wiring
- `src/bar-window.vala`: bar window rendering and placement
- `src/plugin-manager.vala`: plugin discovery and scheduling
- `src/plugin-runner.vala`: plugin execution
- `src/xbar-parser.vala`: xbar text parsing
- `src/menu-builder.vala`: GTK menu construction from parsed items, including the popover footer (Refresh + Edit Variables…)
- `src/action-dispatcher.vala`: menu action handling, including `terminal=true` terminal-emulator launching
- `src/variables-store.vala`: read/write `<plugin>.vars.json` sidecars and export them as env vars
- `src/variables-editor.vala`: GTK form generated from `<xbar.var>` metadata
- `src/models.vala`: shared data models
- `src/desktop-integration.vala`: user desktop entry and autostart integration
- `examples/plugins/`: bundled example plugins
- `docs/sidewing-spec.md`: broader behavior/spec reference
- `docs/implementation-plan.md`: planned architecture / outstanding work

## Platform / Scope Constraints

- X11 only. Wayland is not supported — do not assume Wayland APIs exist. Maximized-window tracking, focus-loss dismissal, and reserve-space all use X11 paths.
- Plugin env vars were renamed `STABA_*` → `SIDEWING_*`; existing plugin scripts referencing `STABA_*` need updating.
- Plugin PATH resolution is tricky: user tools (e.g. `gh`) may only be on PATH from interactive zsh setup. Don't rely on `zsh -lc` alone — may need to merge env, login-shell, interactive-shell, and `.profile` sources.
- README.md documents user-facing plugin semantics; consult it before changing parser or runner behavior.
- Example plugins under `examples/plugins/` are shipped as product surface and useful for manual verification.

## Working Notes

- Preserve existing Vala style and naming in touched files.
- After rebuilding, use `make restart` to swap the running binary — the in-app "Reload" only re-runs plugins, it does not reload the binary.
- When debugging plugin shell commands, do not trust `zsh -lc` alone for `PATH`. User tools like `gh` may come from interactive shell setup in `.zshrc` or sourced files such as `shell.zsh`, so plugin PATH resolution may need to merge environment, login-shell, interactive-shell, and `.profile` sources.
