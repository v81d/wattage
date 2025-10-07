wattage_sources = [
  'main.vala',
  'application.vala',
  'window.vala',
  'utils/battery_manager.vala',
]

wattage_deps = [
  config_dep,
  dependency('gtk4'),
  dependency('libadwaita-1', version: '>= 1.8.0'),
  dependency('gee-0.8')
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
