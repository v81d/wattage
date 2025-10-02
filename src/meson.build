ampere_sources = [
  'main.vala',
  'application.vala',
  'window.vala',
  'battery_manager.vala',
]

ampere_deps = [
  config_dep,
  dependency('gtk4'),
  dependency('libadwaita-1', version: '>= 1.4'),
  dependency('gee-0.8')
]

ampere_sources += gnome.compile_resources('ampere-resources',
  'ampere.gresource.xml',
  c_name: 'ampere'
)

executable('ampere', ampere_sources,
  dependencies: ampere_deps,
  include_directories: config_inc,
  install: true,
)
