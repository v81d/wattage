wattage_sources = [
  'main.vala',
  'application.vala',
  'window.vala',
  'utils/numeric-toolkit.vala',
  'utils/device-manager.vala',
  'interfaces/dbus-upower.vala'
]

wattage_deps = [
  config_dep,
  dependency('gtk4'),
  dependency('libadwaita-1', version: '>= 1.8.0'),
  dependency('gee-0.8'),
  dependency('livechart')
]

wattage_sources += gnome.compile_resources('wattage-resources',
  'wattage.gresource.xml',
  c_name: 'wattage'
)

executable('wattage', wattage_sources,
  dependencies: wattage_deps,
  include_directories: config_inc,
  install: true,
)
