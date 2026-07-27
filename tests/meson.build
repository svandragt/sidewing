bar_placement_source = configure_file(
  input: '../src/bar-placement.vala',
  output: 'bar-placement.vala',
  copy: true,
)

models_source = configure_file(
  input: '../src/models.vala',
  output: 'models.vala',
  copy: true,
)

bar_placement_test = executable(
  'test-bar-placement',
  [
    files('test-bar-placement.vala'),
    bar_placement_source,
    models_source,
  ],
  dependencies: [
    glib_dep,
    gobject_dep,
    gee_dep,
  ],
)

test('bar-placement', bar_placement_test)
