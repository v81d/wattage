blueprints = custom_target('blueprints',
  input: files(
    'ui/shortcuts-dialog.blp',
    'ui/preferences-dialog.blp',
    'ui/window.blp',
  ),
  output: '.',
  command: [find_program('blueprint-compiler'), 'batch-compile', '@OUTPUT@', '@CURRENT_SOURCE_DIR@', '@INPUT@'],
)

wattage_sources = [
  'main.vala',
  'application.vala',
  'window.vala',
  'utils/numeric-toolkit.vala',
  'utils/device-manager.vala',
  'utils/chart-drawer.vala',
  'interfaces/dbus-upower.vala'
]

wattage_deps = [
  config_dep,
  dependency('gtk4', version: '>= 4.18.0'),
  dependency('libadwaita-1', version: '>= 1.8.0'),
  dependency('gee-0.8'),
  dependency('cairo', version: '>= 1.18.4')
]

wattage_sources += gnome.compile_resources('wattage-resources',
  'wattage.gresource.xml',
  c_name: 'wattage',
  dependencies: blueprints,
)

executable('wattage', wattage_sources,
  dependencies: wattage_deps,
  include_directories: config_inc,
  install: true,
)
