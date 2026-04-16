staba_sources = files(
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
  'variables-store.vala',
  'action-dispatcher.vala',
  'log-service.vala',
)

executable(
  'staba',
  staba_sources,
  dependencies: [
    gtk_dep,
    gio_dep,
    glib_dep,
    gobject_dep,
    gee_dep,
  ],
  install: false,
)
