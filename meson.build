project(
  'staba',
  ['vala', 'c'],
  version: '0.1.0',
  meson_version: '>= 0.60.0',
  default_options: [
    'warning_level=2',
    'buildtype=debugoptimized',
  ],
)

gtk_dep = dependency('gtk4')
gio_dep = dependency('gio-2.0')
glib_dep = dependency('glib-2.0')
gobject_dep = dependency('gobject-2.0')
gee_dep = dependency('gee-0.8')

add_project_arguments(
  [
    '--target-glib=2.68',
  ],
  language: 'vala',
)

subdir('src')
