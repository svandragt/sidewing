# Agents Guide

This repository contains `Sidewing`, a GTK4 desktop bar written in Vala. It runs local executable plugins, parses xbar-style output, and renders a slim bar window for multi-monitor Linux desktop setups.

## Current Scope

- Target platform: Linux desktop environments with X11
- Toolkit/language: GTK4 + Vala
- Build system: Meson + Ninja
- Plugin model: local unsandboxed scripts in the user data directory

The codebase is still an MVP.

## Important Paths

- `src/application.vala`: app startup and high-level wiring
- `src/bar-window.vala`: bar window rendering and placement
- `src/plugin-manager.vala`: plugin discovery and scheduling
- `src/plugin-runner.vala`: plugin execution
- `src/xbar-parser.vala`: xbar text parsing
- `src/menu-builder.vala`: GTK menu construction from parsed items
- `src/action-dispatcher.vala`: menu action handling
- `src/models.vala`: shared data models
- `src/desktop-integration.vala`: user desktop entry and autostart integration
- `examples/plugins/`: bundled example plugins
- `docs/sidewing-spec.md`: broader behavior/spec reference
- `docs/implementation-plan.md`: planned architecture/work
- `docs/TODO.md`: short outstanding task list

## Build And Run

```sh
meson setup build
meson compile -C build
./build/src/sidewing
```

If `build/` already exists, prefer:

```sh
meson compile -C build
```

## Verification

There is no dedicated automated test suite in this repo yet. For verification:

```sh
meson compile -C build
```

Then run the app and exercise plugin discovery, menu rendering, and action dispatching manually.

## Working Notes

- Preserve existing Vala style and naming in touched files.
- Legacy `STABA_*` plugin environment variables were renamed to `SIDEWING_*`.
- README documents user-facing behavior; check it before changing plugin semantics.
- Sidewing currently focuses on X11 placement. Do not assume Wayland support exists.
- Example plugins in `examples/plugins/` are part of the product surface and useful for manual verification.
