# staba Implementation Plan

## Objective

Build `staba` as a standalone Vala application for elementary OS 8 Classic Session on X11 that renders xbar-compatible plugin output in a secondary-display top bar.

This plan turns the product spec into a sequence of implementation phases with clear module ownership and MVP boundaries.

## Technical Direction

- Build system: Meson + Ninja
- Language: Vala
- UI: GTK4
- elementary integration: keep Granite optional; do not block the GTK4 build on Granite availability
- First target: X11 Classic Session
- First delivery shape: standalone desktop app with local config, plugin scanning, and a single bar window

## MVP Decisions

These decisions are treated as fixed for the first implementation pass:

- one bar on one selected monitor
- one visible title per plugin
- first pre-`---` line is the visible bar title in MVP
- protocol-level xbar compatibility, not macOS behavior compatibility
- unsupported xbar parameters are ignored safely
- plugin execution is unsandboxed and explicit
- monitor fallback attaches to primary monitor if the configured secondary monitor disappears

## Work Breakdown

## Phase 0: Project Skeleton

Goal:

- create a buildable Vala application with the core namespaces and modules from the spec

Deliverables:

- Meson build files
- `Staba.Application` entry point
- source tree for core modules
- placeholder runtime wiring

Exit criteria:

- `meson setup` and `meson compile` succeed on a development machine with GTK4 and Granite installed

## Phase 1: Configuration and Monitor Discovery

Goal:

- load persistent config and detect displays

Modules:

- `SettingsStore`
- `MonitorManager`

Implementation:

- define config/state file paths under `~/.config/staba/`
- define a monitor model with stable identifiers, geometry, and primary flag
- enumerate monitors via GDK
- persist selected monitor

Exit criteria:

- app can list monitors and resolve the selected monitor at startup

## Phase 2: Bar Window and Basic UI

Goal:

- show a monitor-bound bar window with placeholder items

Modules:

- `BarWindow`
- `MenuBuilder`

Implementation:

- create borderless top-edge application window
- size and place it on the selected monitor
- render a horizontal container for plugin titles
- support dropdown/popover attachment points

Exit criteria:

- window appears on the selected monitor and survives monitor re-evaluation

## Phase 3: Plugin Discovery and Scheduling

Goal:

- discover executable plugins and schedule runs from xbar-style filenames

Modules:

- `PluginManager`
- `PluginRunner`

Implementation:

- scan plugin directory
- validate executable files
- parse refresh intervals from filenames
- create one timer per plugin
- coalesce overlapping runs

Exit criteria:

- lightweight test plugins run and refresh on schedule without blocking the UI thread

## Phase 4: Parser and Item Model

Goal:

- parse plugin stdout into a normalized internal representation

Modules:

- `XbarParser`

Implementation:

- parse title lines
- split dropdown content at `---`
- parse line parameters after `|`
- track submenu depth from leading `--`
- retain per-line parse warnings

Exit criteria:

- xbar-style sample output produces stable item trees for rendering

## Phase 5: Rendering and Actions

Goal:

- render parsed plugin state and trigger actions

Modules:

- `MenuBuilder`
- `ActionDispatcher`

Implementation:

- show plugin title in the bar
- build dropdown menus from parsed items
- support separators, disabled items, and submenu nesting
- support `href`
- support `shell` + `paramN`
- support `refresh=true`

Exit criteria:

- clicking a plugin opens a populated menu and actions execute correctly

## Phase 6: Metadata, Variables, and Error Surfaces

Goal:

- expose plugin metadata and user-configurable variables

Modules:

- `VariablesStore`
- `SettingsStore`
- `LogService`

Implementation:

- parse metadata tags from plugin comments
- parse and persist `<xbar.var>` values
- export variable values as environment variables for plugin runs
- expose plugin errors and logs in UI

Exit criteria:

- variable-backed plugins are configurable and error states are visible

## Phase 7: X11 Polish and Packaging

Goal:

- improve panel behavior and package the app for local testing

Modules:

- `BarWindow`
- packaging files

Implementation:

- investigate dock window hints and struts under Gala
- add desktop file and app metadata
- add autostart integration

Exit criteria:

- app behaves like a stable secondary-display utility and is easy to launch on login

## Module Responsibilities

## `Application`

Responsibilities:

- process startup
- shared service initialization
- lifecycle wiring
- startup logging

Inputs:

- app ID
- command-line arguments
- service dependencies

Outputs:

- running GTK application

## `BarWindow`

Responsibilities:

- top-edge window creation
- bar layout container
- monitor placement
- plugin item widgets

Dependencies:

- `MonitorManager`
- `MenuBuilder`
- `SettingsStore`

## `MonitorManager`

Responsibilities:

- enumerate monitors
- track primary monitor
- resolve the configured secondary monitor
- handle monitor changes

Dependencies:

- GDK display APIs

## `PluginManager`

Responsibilities:

- plugin discovery
- plugin registry state
- refresh scheduling
- plugin enable/disable state

Dependencies:

- `PluginRunner`
- `XbarParser`
- `LogService`

## `PluginRunner`

Responsibilities:

- subprocess execution
- timeout handling
- stdout/stderr capture
- environment construction

Dependencies:

- GLib subprocess APIs
- `VariablesStore`

## `XbarParser`

Responsibilities:

- parse stdout into internal items
- preserve warnings
- map xbar metadata into normalized values

Dependencies:

- none beyond GLib

## `MenuBuilder`

Responsibilities:

- build GTK menu/popover content from parsed items
- attach menu actions to UI callbacks

Dependencies:

- GTK widgets
- `ActionDispatcher`

## `SettingsStore`

Responsibilities:

- config path resolution
- config load/save
- selected monitor persistence
- bar appearance settings

Dependencies:

- GLib file and JSON support

## `VariablesStore`

Responsibilities:

- load/save plugin variable sidecars
- map variable values into environment variables

Dependencies:

- GLib file and JSON support

## `ActionDispatcher`

Responsibilities:

- launch URLs
- launch plugin shell actions
- trigger refresh requests

Dependencies:

- GTK URI launcher or `xdg-open`
- `PluginManager`

## `LogService`

Responsibilities:

- structured runtime logging
- log file persistence
- recent error reporting for UI

Dependencies:

- GLib file APIs

## Suggested Data Models

- `MonitorInfo`
  - stable ID
  - connector or display name
  - geometry
  - primary flag

- `PluginDefinition`
  - absolute path
  - display name
  - interval
  - enabled flag
  - metadata

- `PluginRunResult`
  - stdout
  - stderr
  - exit code
  - duration
  - timed out flag

- `ParsedPluginState`
  - visible title
  - bar lines
  - menu items
  - warnings

- `ParsedItem`
  - title
  - depth
  - kind
  - parameters

## Initial Milestones

1. Buildable skeleton with all modules and a visible bar window.
2. Plugin directory scan with filename interval parsing.
3. Real subprocess execution and placeholder title rendering.
4. xbar parser wired into UI.
5. Menu actions and refresh support.
6. Settings, variables, and log viewer.

## Immediate Next Tasks

1. Scaffold the source tree and build system.
2. Add model classes shared by monitor, plugin, and parser modules.
3. Wire a placeholder `BarWindow` to a `MonitorManager`.
4. Add the example plugins directory as the default development plugin path.
5. Compile the skeleton and fix any toolchain issues.
