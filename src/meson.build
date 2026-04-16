config = configuration_data()
config.set_quoted('PROJECT_SOURCE_ROOT', meson.project_source_root())

build_config = configure_file(
  input: 'build-config.vala.in',
  output: 'build-config.vala',
  configuration: config,
)

sidewing_sources = [
  build_config,
]

sidewing_sources += files(
  'main.vala',
  'application.vala',
  'models.vala',
  'bar-window.vala',
  'monitor-manager.vala',
  'plugin-manager.vala',
  'plugin-runner.vala',
  'xbar-parser.vala',
  'menu-builder.vala',
  'settings-store.vala',
  'desktop-integration.vala',
  'variables-store.vala',
  'action-dispatcher.vala',
  'log-service.vala',
)

executable(
  'sidewing',
  sidewing_sources,
  dependencies: [
    gtk_dep,
    gtk4_x11_dep,
    gio_dep,
    glib_dep,
    gobject_dep,
    gee_dep,
    json_glib_dep,
    x11_dep,
  ],
  install: false,
)
